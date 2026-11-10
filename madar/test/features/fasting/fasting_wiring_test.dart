// «تذكير الصيام» wired into the app: the scheduler is watched at the root
// right after the notification centre (one gate, the owner's mutes already
// in it), a Prayer (Faith) mute holds the reminders and an un-mute re-arms
// them, a restore re-plans from the restored data, a tap on the body opens
// «صيامي», and «ناوي» answered while Madar runs writes the same single
// record the background isolate would. The iqama's wiring test is the pattern.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_services.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/data/data.dart' show RestoreResult, SafetyCopy;
import 'package:madar/features/fasting/fasting.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import 'package:madar/features/wird/domain/calendar_days.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import 'fasting_test_support.dart';

Future<void> _asyncFrames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Records the order providers are first created in.
final class _StartOrder extends ProviderObserver {
  _StartOrder(this.watched);

  final Map<ProviderBase<Object?>, String> watched;
  final List<String> started = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = watched[context.provider];
    if (name != null && !started.contains(name)) started.add(name);
  }
}

Iterable<FakeScheduled> _fastingAlarms(FakeNotificationPlatform platform) =>
    platform.scheduled.values.where((s) => NotificationNamespaces.fasting.contains(s.request.id) && s.request.data['day'] != null);

RawNotificationTap _tap({String? action, String day = '2026-09-28'}) {
  const id = 200010;
  return RawNotificationTap(
    id: id,
    actionId: action,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: NotificationNamespaces.fasting,
        id: id,
        channelId: FastingNotifications.channelId,
        title: 'تذكير الصيام · الاثنين',
        body: 'بكرة الاثنين: ناوي تصوم؟',
        at: DateTime(2026, 9, 27, 19, 50),
        data: {'day': day, 'kind': 'monday', 'l': 'ar', 'g': 'auto'},
      ),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('the notification centre sees «تذكير الصيام»', () {
    testWidgets('the app starts with the scheduler watched at the root, after the centre, and the next 21 days are armed', (tester) async {
      final order = _StartOrder({
        notificationCenterProvider: 'centre',
        fastingRegistrationProvider: 'registration',
        fastingSyncProvider: 'sync',
        fastingBridgeProvider: 'bridge',
      });
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        settle: false,
        observers: [order],
        notifications: platform,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);

      expect(order.started, containsAll(['centre', 'registration', 'sync', 'bridge']));
      expect(order.started.indexOf('centre'), 0, reason: 'the mutes are in the gate before anything re-plans');
      expect(order.started.indexOf('registration'), lessThan(order.started.indexOf('sync')), reason: order.started.join(','));

      final alarms = _fastingAlarms(platform).toList();
      expect(alarms, isNotEmpty, reason: 'the app planned the next weeks on its own');
      final today = DateTime(2026, 9, 27);
      for (final s in alarms) {
        expect(s.request.at.isAfter(DateTime(2026, 9, 27, 13, 10)), isTrue);
        expect(s.request.at.isBefore(DateTime(today.year, today.month, today.day + 22)), isTrue);
        expect(s.request.namespace, NotificationNamespaces.fasting);
      }
      expect(platform.channels.containsKey(FastingNotifications.channelId), isTrue);
      // The result the screen and the tests read.
      expect(app.container.read(fastingSyncProvider).last?.plan, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a restore (and an un-mute) re-plans the reminders: the namespace has its hook', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      final hooks = app.container.read(systemReplanHooksProvider);
      expect(hooks.namespaces, contains(NotificationNamespaces.fasting.name));
      await expectLater(hooks[NotificationNamespaces.fasting.name]!(), completes);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('they belong to Prayer: one Faith mute holds them with the adhan, and un-muting re-arms them', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        gated: true,
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
        beforePump: (MadarDatabase db) => NotificationCenterStore(Repositories(db).keyValues).savePolicy(
          // Muted well past the whole 21-day plan.
          CenterPolicy.empty.mute(NotificationGroup.prayer, testNow.add(const Duration(days: 60))),
        ),
      );
      await _asyncFrames(tester, 20);

      final registry = app.container.read(notificationDescribersProvider);
      final notice = CenterNotice(
        id: 200010,
        namespace: NotificationNamespaces.fasting.name,
        at: DateTime(2026, 9, 27, 19, 50).toUtc(),
        data: const {'day': '2026-09-28', 'kind': 'monday'},
      );
      expect(registry.groupOf(notice), NotificationGroup.prayer);
      final gate = app.container.read(notificationGateProvider);
      expect(gate.withholds(notice), isTrue, reason: 'Prayer is muted');
      expect(
        gate.withholds(CenterNotice(id: 110500, namespace: 'adhkar', at: notice.at, data: const {'set': 'morning'})),
        isFalse,
        reason: 'only the muted group is held',
      );
      // The sync ran (it planned) but not one reminder reached the plugin.
      expect(app.container.read(fastingSyncProvider).last?.plan, isNotEmpty);
      expect(_fastingAlarms(platform), isEmpty, reason: 'held back by the gate');

      // Un-mute: what the gate held is armed.
      await tester.runAsync(() => gate.setPolicy(CenterPolicy.empty));
      await _asyncFrames(tester, 12);
      expect(_fastingAlarms(platform), isNotEmpty, reason: 'un-muting brings the reminders back');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('it re-plans by itself', () {
    testWidgets('when the Hijri day shift changes in the prayer settings: the white days move, the old ones are cancelled', (tester) async {
      final year = HijriYearView(1448);
      final d = year.civil(2, 11, 0); // the window holds the 13th, 14th and 15th of Safar
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        now: DateTime(d.year, d.month, d.day, 12),
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      List<String> whites() => [
        for (final s in _fastingAlarms(platform))
          if (s.request.data['kind'] == 'whiteDay') s.request.data['day']! as String,
      ]..sort();
      List<String> expected(int offset) => [for (final n in [13, 14, 15]) CalendarDays.key(year.civil(2, n, offset))];
      expect(whites(), expected(0));

      await tester.runAsync(() => app.container.read(prayerSettingsControllerProvider.notifier).setHijriOffset(1));
      await _asyncFrames(tester, 20);
      expect(whites(), expected(1), reason: 'one setting: the prayer settings\' shift moved every reminder');
      expect(app.container.read(fastingConfigProvider).hijriOffset, 1);

      await tester.runAsync(() => app.container.read(prayerSettingsControllerProvider.notifier).setHijriOffset(-1));
      await _asyncFrames(tester, 20);
      expect(whites(), expected(-1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('when the day changes at midnight: the next 21 days are planned again from the new day', (tester) async {
      var now = DateTime(2026, 11, 10, 23, 59);
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        clock: () => now,
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      expect(CalendarDays.same(app.container.read(fastingSyncProvider).last!.at, DateTime(2026, 11, 10)), isTrue);

      now = DateTime(2026, 11, 11, 0, 0, 30);
      await tester.pump(const Duration(seconds: 70)); // OrbitToday's midnight timer
      await _asyncFrames(tester, 10);
      final last = app.container.read(fastingSyncProvider).last!;
      expect(CalendarDays.same(last.at, DateTime(2026, 11, 11)), isTrue, reason: 're-planned for the new day');
      // The new window starts the next morning: nothing is left of yesterday's.
      expect(last.plan.every((p) => p.at.isAfter(now)), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('restore', () {
    testWidgets('after a restore the reminders are re-planned from the restored data', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      Set<String> kinds() => {for (final s in _fastingAlarms(platform)) s.request.data['kind']! as String};
      expect(kinds(), anyOf(contains('monday'), contains('thursday')), reason: 'a fresh install reminds Mondays and Thursdays');
      final oldIds = _fastingAlarms(platform).where((s) => const {'monday', 'thursday'}.contains(s.request.data['kind'])).map((s) => s.request.id).toSet();

      // The backup he restores was made with the weekly reminders off.
      final other = testDatabase();
      addTearDown(() => tester.runAsync(other.close));
      final snapshot = await tester.runAsync(() async {
        await FastingRepository(Repositories(other).keyValues).saveConfig(FastKindGroup.weekly.set(const FastingConfig(), false));
        return exportSnapshot(other);
      });
      await tester.runAsync(() => restoreSnapshot(app.db, snapshot!));

      final safety = Directory.systemTemp.createTempSync('madar_fasting_restore_');
      addTearDown(() => safety.deleteSync(recursive: true));
      final copy = File('${safety.path}/x.madarbackup')..writeAsStringSync('x');
      var finished = false;
      unawaited(
        app.container
            .read(afterRestoreProvider)(
              RestoreResult(safetyCopy: SafetyCopy(file: copy, createdAt: DateTime(2026, 9, 27), size: 1), restoredRecords: 3, previousRecords: 1),
            )
            .then((_) => finished = true),
      );
      await _asyncFrames(tester, 40);
      expect(finished, isTrue);

      expect(kinds(), isNot(contains('monday')), reason: 'the restored data has no Monday reminders');
      expect(kinds(), isNot(contains('thursday')));
      for (final id in oldIds) {
        expect(platform.scheduled.containsKey(id), isFalse, reason: 'the old data\'s alarm $id was cancelled');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('taps', () {
    test('the body of a reminder leads to «صيامي»; its two buttons lead nowhere', () {
      NotificationTap tap({String? action, Map<String, Object?> data = const {'day': '2026-09-28', 'kind': 'monday'}}) =>
          NotificationTap(id: 200010, namespace: 'fasting', data: data, actionId: action);
      expect(AppNotificationRouter.locationOf(tap()), AppRoutes.fasting);
      expect(AppRoutes.fasting, '/faith/fasting');
      expect(AppNotificationRouter.locationOf(tap(action: FastingActions.yes)), isNull);
      expect(AppNotificationRouter.locationOf(tap(action: FastingActions.no)), isNull);
      // The "open Madar to renew" notice opens the same screen.
      expect(AppNotificationRouter.locationOf(tap(data: const {'t': 'runway'})), AppRoutes.fasting);
      // Another feature's tap is not ours.
      expect(AppNotificationRouter.locationOf(NotificationTap(id: 1, namespace: 'iqama', data: const {})), isNot(AppRoutes.fasting));
      expect(centerLocationOf(tap()), AppRoutes.fasting, reason: 'a row in the centre opens it too');
    });

    testWidgets('a tap on the body while Madar runs opens the screen; back returns', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      app.notifications.tap(_tap());
      await settleApp(tester);
      expect(app.location, AppRoutes.fasting);
      expect(find.byType(FastingScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('«ناوي» answered while Madar runs writes exactly one record, and does not navigate', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      await tester.runAsync(() => app.container.read(notificationServiceProvider).init());
      app.notifications.tap(_tap(action: FastingActions.yes));
      app.notifications.tap(_tap(action: FastingActions.yes)); // a double tap
      await _asyncFrames(tester, 8);
      final rows = await tester.runAsync(() => FastingRepository(app.repos.keyValues).intentions());
      expect(rows, hasLength(1));
      expect(rows!.single.day, DateTime(2026, 9, 28));
      expect(rows.single.choice, FastIntentionChoice.yes);
      expect(app.location, AppRoutes.home, reason: 'the button never opens the app');
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
