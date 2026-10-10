// The second half of the Phase 9 wiring, checked inside the real app:
//
// 1. «بياناتك» – every export format carries the six food tables, and a
//    restore keeps a safety copy of what it replaced and re-plans the
//    reminders of the restored data;
// 2. the AI chat – not one byte leaves the phone without a tap: opening the
//    app, every AI page and the hubs' "Ask about …" card make no request;
// 3. "Delete all data" – the AI keys, the widgets' data, the games' site
//    data, Together's online project, every scheduled alarm and the
//    restore's safety copies are all gone afterwards;
// 4. Together Mode – its two transports are registered app-wide and its
//    alert ids are its own block;
// 5. the new Settings rows open the right screens.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/data/data.dart';
import 'package:madar/features/family/family.dart' show FamilyNotificationIds;
import 'package:madar/features/data/domain/data_areas.dart' show DataArea, DataAreas;
import 'package:madar/features/notification_center/notification_center.dart'
    show NotificationCenterScreen, NotificationSettingsSummary;
import 'package:madar/features/saved_games/saved_games.dart' show GameWebDataCleaner, gameWebDataCleanerProvider;
import 'package:madar/features/together/pairing/pairing.dart'
    show OnlineConfigStore, OnlineRoomLedger, TogetherNotifications, togetherSecretsProvider;
import 'package:madar/features/together/together.dart'
    show PlayMode, TogetherHomeScreen, togetherTransportFactoriesProvider;
import 'package:madar/features/widgets/widgets.dart' show MethodChannelWidgetPlatform, WidgetsSettingsScreen;

import '../features/ai_chat/ai_chat_fakes.dart' show FakeTransport;
import '../features/data/data_harness.dart' show fastTestCodec;
import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));

/// Records whether the saved games' site data was cleared.
class _RecordingGameCleaner implements GameWebDataCleaner {
  int cleared = 0;

  @override
  Future<bool> clearAll() async {
    cleared++;
    return true;
  }
}

/// The six food tables, filled with his own words.
Future<void> _seedFood(MadarDatabase db) async {
  final repos = Repositories(db);
  await repos.foods.insert(
    FoodsCompanion.insert(
      id: const Value('f1'),
      name: 'مقلوبة',
      tags: const Value(['نشويات', 'مقلي']),
      defaultPortion: const Value(1.5),
      unit: const Value('طبق'),
    ),
  );
  await repos.conditions.insert(ConditionsCompanion.insert(id: const Value('c1'), name: 'الضغط'));
  await repos.foodLogs.insert(
    FoodLogsCompanion.insert(
      id: const Value('l1'),
      foodId: const Value('f1'),
      name: 'مقلوبة',
      at: DateTime(2026, 9, 29, 13, 30),
      portion: const Value(2),
      unit: const Value('طبق'),
      slotId: const Value('s1'),
      note: const Value('بيت الوالدة'),
    ),
  );
  await repos.mealPlans.insert(
    MealPlansCompanion.insert(id: const Value('p1'), name: 'خطة رمضان', active: const Value(true)),
  );
  await repos.mealSlots.insert(
    MealSlotsCompanion.insert(
      id: const Value('s1'),
      planId: 'p1',
      name: 'فطور',
      timeMinutes: 480,
      weekdays: const Value([1, 3, 5]),
    ),
  );
  await repos.mealSlotFoods.insert(
    MealSlotFoodsCompanion.insert(slotId: 's1', foodId: const Value('f1'), name: 'مقلوبة'),
  );
  await repos.foodRules.insert(
    FoodRulesCompanion.insert(
      conditionId: const Value('c1'),
      target: const Value(FoodRuleTarget.tag),
      tag: const Value('مقلي'),
      weight: const Value(RiskWeight.high),
      note: const Value('المقلي يتعبني'),
    ),
  );
}

const _foodTables = ['foods', 'food_logs', 'meal_plans', 'meal_slots', 'meal_slot_foods', 'food_rules'];

MadarDatabase _memoryDb() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// Nothing may reach a real socket, a real share sheet or the phone's own
/// secure storage from a full-app test.
List<Override> _systemOverrides({
  required FakeTransport transport,
  MemorySecretStore? aiVault,
  MemorySecretStore? togetherVault,
}) => [
  aiTransportProvider.overrideWithValue(transport),
  aiSecretStoreProvider.overrideWithValue(aiVault ?? MemorySecretStore()),
  togetherSecretsProvider.overrideWithValue(togetherVault ?? MemorySecretStore()),
  dataFileBridgeProvider.overrideWithValue(RecordingDataFileBridge()),
];

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Frames that also let real file and database work run.
Future<void> _asyncFrames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // ------------------------------------------------------------------ 1 --
  group('«بياناتك»', () {
    late MadarDatabase db;
    late Directory safety;
    late DataExportRepository repo;
    late BackupService backups;
    final now = DateTime(2026, 9, 30, 10);

    setUp(() async {
      db = _memoryDb();
      await db.customSelect('SELECT 1').get();
      await _seedFood(db);
      safety = Directory.systemTemp.createTempSync('madar_p9b_safety_');
      repo = DataExportRepository(db, useIsolate: false);
      backups = BackupService(db, codec: fastTestCodec, safetyDirectory: () async => safety, clock: () => now);
    });
    tearDown(() async {
      await db.close();
      if (safety.existsSync()) safety.deleteSync(recursive: true);
    });

    test('the full JSON holds every one of the six food tables', () async {
      final file = await repo.jsonExport(now);
      final decoded = jsonDecode(utf8.decode(file.bytes)) as Map<String, Object?>;
      final tables = decoded['tables']! as Map<String, Object?>;
      for (final name in _foodTables) {
        expect(tables[name], isA<List<Object?>>().having((l) => l.length, name, 1));
      }
      final text = utf8.decode(file.bytes);
      expect(text, contains('مقلوبة'));
      expect(text, contains('خطة رمضان'));
      expect(text, contains('المقلي يتعبني'), reason: 'the full export is everything, notes included');
    });

    test('the restore preview counts the food under the Body area', () async {
      final counts = await backups.currentCounts();
      for (final name in _foodTables) {
        expect(counts[name], 1, reason: name);
        expect(DataAreas.of(name), DataArea.body, reason: name);
      }
      expect(DataAreas.totals(counts)[DataArea.body], greaterThanOrEqualTo(6));
    });

    test('the AI-ready summary describes the food in his own words, never his notes', () async {
      final input = await repo.loadSummaryInput(now);
      for (final lang in ['ar', 'en']) {
        final summary = AiSummaryBuilder(lookupL10n(Locale(lang)), languageCode: lang).build(input);
        final body = summary.sections.firstWhere((s) => s.id == SummarySectionId.body).body;
        expect(body, contains('مقلوبة'), reason: '$lang: the food he logged');
        expect(body, contains('مقلي'), reason: '$lang: his own word');
        expect(body, contains('خطة رمضان'), reason: '$lang: his meal plan');
        expect(body, contains('فطور'), reason: '$lang: the meal');
        expect(body, contains('08:00'), reason: '$lang: its time');
        expect(body, contains('الضغط'), reason: '$lang: the condition his rule is about');
        expect(body, isNot(contains('المقلي يتعبني')), reason: '$lang: a note never travels');
        expect(body, isNot(contains('بيت الوالدة')), reason: '$lang: nor an entry\'s note');
        expect(body, isNot(contains('food_rules')), reason: '$lang: never a raw table or key');
        expect(body, isNot(contains('anyFood')));
      }
    });

    test('the CSV of what he ate is a row per entry, in both languages', () async {
      for (final l in [_ar, lookupL10n(const Locale('en'))]) {
        final table = await repo.csvTable(DataCsvKind.food, l);
        expect(table.rows, hasLength(1));
        final line = table.encode();
        expect(line, contains('مقلوبة'));
        expect(line, contains('2026-09-29'));
        expect(line, contains('طبق'));
        expect(line, contains('فطور'), reason: 'the meal of the plan it filled');
        expect(line, contains('بيت الوالدة'), reason: 'the CSV is his own full record');
      }
      expect((await repo.csvCounts())[DataCsvKind.food], 1);
    });

    test('the encrypted backup carries the food, and restoring it keeps a safety copy', () async {
      final file = await backups.create('a long enough passphrase ٢٠٢٦');
      expect(file.encrypted, isTrue);

      // The food he had before the restore, which the safety copy must hold.
      final opened = await backups.open(file.bytes, 'a long enough passphrase ٢٠٢٦');
      expect(opened.counts['food_logs'], 1);
      // Something else is in the database when the restore runs.
      await Repositories(db).foodLogs.insert(FoodLogsCompanion.insert(name: 'شي تاني', at: now));
      expect((await backups.currentCounts())['food_logs'], 2);

      final result = await backups.restore(opened);
      expect(result.previousRecords, greaterThan(result.restoredRecords));
      expect(result.safetyCopy.file.existsSync(), isTrue, reason: 'the data it replaced is kept');
      expect((await backups.currentCounts())['food_logs'], 1, reason: 'the backup replaced it');
      expect(await backups.safetyCopies(), hasLength(1));

      // The safety copy undoes the restore: it opens with the same
      // passphrase and holds the two entries.
      final undo = await backups.open(await result.safetyCopy.file.readAsBytes(), 'a long enough passphrase ٢٠٢٦');
      expect(undo.counts['food_logs'], 2);
    });
  });

  // ------------------------------------------------------------------ 2 --
  group('the AI chat', () {
    testWidgets('no call is made without a tap – not at startup, not on any AI page', (tester) async {
      final transport = FakeTransport();
      // A key is saved, so nothing is held back by a missing key.
      final vault = MemorySecretStore({AiKeyStore.storageKey(AiProviderId.anthropic): 'sk-ant-${'x' * 40}'});
      final app = await pumpMadarApp(
        tester,
        settle: false,
        overrides: [
          ...LockFixture.empty().overrides,
          ..._systemOverrides(transport: transport, aiVault: vault),
        ],
      );
      await _frames(tester, 30);
      expect(transport.requests, isEmpty, reason: 'starting Madar must never call a service');

      for (final location in [AppRoutes.ai, AppRoutes.aiChats, AppRoutes.aiSettings, AppRoutes.aiOf(draft: 'سؤال')]) {
        app.router.go(location);
        await _frames(tester, 24);
        expect(tester.takeException(), isNull, reason: location);
        expect(transport.requests, isEmpty, reason: '$location sent something without a tap');
      }

      // Back in the background for a while: still nothing.
      app.router.go(AppRoutes.home);
      await _frames(tester, 40);
      expect(transport.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('"Ask about this world" only types the question in', (tester) async {
      final transport = FakeTransport();
      final vault = MemorySecretStore({AiKeyStore.storageKey(AiProviderId.anthropic): 'sk-ant-${'x' * 40}'});
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.planetOf('money'),
        settle: false,
        overrides: [
          ...LockFixture.empty().overrides,
          ..._systemOverrides(transport: transport, aiVault: vault),
        ],
      );
      await _frames(tester, 30);
      final card = find.text(_ar.aiChatAskAbout(_ar.planetMoney));
      await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).last);
      await _frames(tester, 6);
      await Scrollable.ensureVisible(tester.element(card.last), alignment: 0.5);
      await _frames(tester, 6);
      await tester.tap(card.last);
      await _frames(tester, 24);
      expect(find.byType(AiChatScreen), findsOneWidget);
      expect(app.location, AppRoutes.ai);
      expect(
        tester.widget<AiChatScreen>(find.byType(AiChatScreen)).initialDraft,
        _ar.systemShellAskMoneyPrompt,
        reason: 'his question is typed, not sent',
      );
      expect(transport.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  // ------------------------------------------------------------------ 3 --
  group('delete all data', () {
    testWidgets('leaves no AI key, no widget data, no Together key and no armed alarm', (tester) async {
      // The real file deletion, pointed at a temporary folder.
      final dir = Directory.systemTemp.createTempSync('madar_p9b_reset_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
        return dir.path;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null),
      );
      final widgetCalls = <String>[];
      messenger.setMockMethodCallHandler(const MethodChannel(MethodChannelWidgetPlatform.channelName), (call) async {
        widgetCalls.add(call.method);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(const MethodChannel(MethodChannelWidgetPlatform.channelName), null),
      );
      final dbFile = File('${dir.path}/madar.db')..writeAsStringSync('the old, encrypted data');

      final vault = MemorySecretStore({
        DatabaseKeyStore.storageKey: 'the database key',
        AiKeyStore.storageKey(AiProviderId.anthropic): 'sk-ant-${'x' * 40}',
        AiKeyStore.storageKey(AiProviderId.openai): 'sk-${'y' * 40}',
      });
      final togetherVault = MemorySecretStore({
        OnlineConfigStore.key: '{"projectId":"x"}',
        OnlineRoomLedger.key: '["123456"]',
      });
      final games = _RecordingGameCleaner();

      // What the old data had planned, still armed with the system.
      final platform = FakeNotificationPlatform();
      final dose = NotificationRequest(
        namespace: NotificationNamespaces.meds,
        id: 120042,
        channelId: 'madar.meds.doses',
        title: 'دواء الضغط',
        body: '',
        at: DateTime(2026, 9, 27, 20),
      );
      await platform.schedule(dose, NotificationEnvelope.encode(dose), timing: dose.timing);

      // A safety copy of an earlier restore, which must go too.
      final safety = Directory('${dir.path}/safety')..createSync();
      File('${safety.path}/old.madarbackup').writeAsStringSync('an encrypted copy of his old data');

      final app = await pumpMadarApp(
        tester,
        settle: false,
        notifications: platform,
        overrides: [
          ...LockFixture.empty().overrides,
          ..._systemOverrides(transport: FakeTransport(), aiVault: vault, togetherVault: togetherVault),
          databaseKeyStoreProvider.overrideWithValue(DatabaseKeyStore(store: vault)),
          gameWebDataCleanerProvider.overrideWithValue(games),
          safetyCopiesDirectoryProvider.overrideWithValue(() async => safety),
        ],
      );
      await _frames(tester, 20);

      // The gate's "start fresh", exactly as the recovery screen calls it.
      await tester.runAsync(() => app.container.read(databaseResetProvider)());
      await _asyncFrames(tester);

      expect(dbFile.existsSync(), isFalse, reason: 'the encrypted file');
      expect(vault.values, isEmpty, reason: 'the database key AND both AI keys');
      expect(togetherVault.values, isEmpty, reason: 'Together\'s online project and its room codes');
      expect(widgetCalls, contains('clearAll'), reason: 'every widget back to "Open Madar"');
      expect(games.cleared, 1, reason: 'the saved games\' site data');
      expect(platform.cancelled, contains(dose.id), reason: 'an alarm of deleted data must never fire');
      expect(platform.scheduled, isEmpty);
      expect(safety.existsSync(), isFalse, reason: 'the encrypted safety copies of a restore');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  // ------------------------------------------------------------------ 4 --
  group('Together Mode', () {
    testWidgets('both two-phone transports are registered app-wide', (tester) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.together,
        settle: false,
        overrides: [
          ...LockFixture.empty().overrides,
          ..._systemOverrides(transport: FakeTransport()),
        ],
      );
      await _frames(tester, 20);
      expect(find.byType(TogetherHomeScreen), findsOneWidget);
      final factories = app.container.read(togetherTransportFactoriesProvider);
      expect(factories.keys, containsAll([PlayMode.nearby, PlayMode.online]));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    test('the "your turn" alert has its own id block, 170000–170999', () {
      expect(NotificationNamespaces.together, TogetherNotifications.namespace);
      expect((TogetherNotifications.namespace.first, TogetherNotifications.namespace.last), (170000, 170999));
      expect(NotificationNamespaces.all, contains(TogetherNotifications.namespace));
      expect(NotificationNamespaces.owning(TogetherNotifications.yourTurnId), TogetherNotifications.namespace);
      for (final other in NotificationNamespaces.all) {
        if (other.name == 'together') continue;
        expect(
          other.last < 170000 || other.first > 170999,
          isTrue,
          reason: '${other.name} reaches into Together\'s block',
        );
      }
    });
  });

  // ------------------------------------------------------------------ 5 --
  group('Settings', () {
    Future<void> openFrom(WidgetTester tester, String title, Type screen, String location) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: AppRoutes.settings,
        settle: false,
        overrides: [
          ...LockFixture.empty().overrides,
          ..._systemOverrides(transport: FakeTransport()),
        ],
      );
      await _frames(tester, 20);
      final row = find.text(title);
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await _frames(tester, 6);
      // Centred, so the glass app bar over the list cannot swallow the tap.
      await Scrollable.ensureVisible(tester.element(row.last), alignment: 0.5);
      await _frames(tester, 6);
      await tester.tap(row.last);
      await _frames(tester, 24);
      expect(find.byType(screen), findsOneWidget, reason: title);
      expect(app.location, location, reason: title);
      expect(tester.takeException(), isNull, reason: title);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }

    testWidgets('the notification centre row opens the centre', (tester) async {
      await openFrom(tester, _ar.systemShellNotificationCenterRow, NotificationCenterScreen, AppRoutes.notifications);
    });

    testWidgets('"what each part sends" opens Settings › Notifications', (tester) async {
      await openFrom(
        tester,
        _ar.systemShellNotificationGroupsRow,
        NotificationSettingsSummary,
        AppRoutes.notificationSettings,
      );
    });

    testWidgets('the widgets row opens the widgets settings', (tester) async {
      await openFrom(tester, _ar.systemShellWidgetsRowHint, WidgetsSettingsScreen, AppRoutes.widgetsSettings);
    });

    testWidgets('the Together row opens Together Mode', (tester) async {
      await openFrom(tester, _ar.systemShellTogetherRowHint, TogetherHomeScreen, AppRoutes.together);
    });

    testWidgets('the AI row opens Settings › AI', (tester) async {
      await openFrom(tester, _ar.aiChatSettingsRowSubtitle, AiSettingsScreen, AppRoutes.aiSettings);
    });

    testWidgets('«بياناتك» opens the data centre', (tester) async {
      await openFrom(tester, _ar.systemShellDataRow, DataCentreScreen, AppRoutes.dataCentre);
    });
  });

  // ------------------------------------------------------------------ 6 --
  testWidgets('after a restore, the reminders of the restored data are re-planned', (tester) async {
    final platform = FakeNotificationPlatform();
    final app = await pumpMadarApp(
      tester,
      settle: false,
      notifications: platform,
      overrides: [
        ...LockFixture.empty().overrides,
        ..._systemOverrides(transport: FakeTransport()),
      ],
    );
    // The app's own services settle first (they reconcile their blocks at
    // start), so what is armed next can only be cancelled by the restore's
    // own re-plan.
    await _asyncFrames(tester, 20);
    final stale = NotificationRequest(
      namespace: NotificationNamespaces.reminders,
      id: FamilyNotificationIds.digestFirst + 2,
      channelId: 'madar.reminders',
      title: 'سؤال عن شخص انحذف مع الاستعادة',
      body: '',
      at: DateTime(2026, 10, 5, 20),
      data: const {'k': 'digest'},
    );
    await tester.runAsync(() => platform.schedule(stale, NotificationEnvelope.encode(stale), timing: stale.timing));
    await _frames(tester, 4);
    expect(platform.scheduled.containsKey(stale.id), isTrue, reason: 'armed as the replaced data had it');

    final safety = Directory.systemTemp.createTempSync('madar_p9b_restored_');
    addTearDown(() => safety.deleteSync(recursive: true));
    final copy = File('${safety.path}/x.madarbackup')..writeAsStringSync('x');
    final hooks = app.container.read(systemReplanHooksProvider);
    expect(hooks.namespaces, isNotEmpty, reason: 'every namespace registers a re-plan hook');

    // Started like the restore screen starts it (and not awaited inside
    // `runAsync`: the re-plans need frames to run, the way they do in the
    // app).
    var finished = false;
    unawaited(
      app.container
          .read(afterRestoreProvider)(
            RestoreResult(
              safetyCopy: SafetyCopy(file: copy, createdAt: DateTime(2026, 9, 27), size: 1),
              restoredRecords: 10,
              previousRecords: 4,
            ),
          )
          .then((_) => finished = true),
    );
    await _asyncFrames(tester, 30);
    expect(finished, isTrue, reason: 'the re-planning finished');
    expect(
      platform.scheduled.containsKey(stale.id),
      isFalse,
      reason: 'the restored data\'s re-plan cancelled what the old data had armed',
    );
    expect(platform.cancelled, contains(stale.id));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
