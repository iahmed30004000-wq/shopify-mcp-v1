import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/family/family.dart';

import 'family_harness.dart';
import 'family_seed.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

/// Finds text ignoring bidi isolates (names are isolated in sentences).
Finder textContaining(String s) => find.byWidgetPredicate((w) {
  if (w is Text) return BidiIsolate.strip(w.data ?? w.textSpan?.toPlainText() ?? '').contains(s);
  if (w is RichText) return BidiIsolate.strip(w.text.toPlainText()).contains(s);
  return false;
});

/// Lets the database write land without pumpAndSettle (which would run the
/// undo toast's countdown out).
Future<void> settleData(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
  finder,
  300,
  scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
);

Future<List<ContactLogRow>> _logsOf(WidgetTester tester, MadarDatabase db, String personId) async =>
    (await tester.runAsync(() => Repositories(db).contactLogs.getAll(where: (t) => t.personId.equals(personId))))!;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Map<String, PersonRow> people;

  Future<void> seedAr(MadarDatabase db) async => people = await seedFamily(db);
  Future<void> seedEn(MadarDatabase db) async => people = await seedFamily(db, arabic: false);

  group('Family screen', () {
    testWidgets('lists people most urgent first, in sections', (tester) async {
      await pumpFamilyApp(tester, home: const FamilyScreen(), beforePump: seedAr);
      expect(find.text(_ar.familyTitle), findsOneWidget);
      expect(find.text('٣ أشخاص ينتظرون سؤالك'), findsOneWidget);
      expect(find.text(_ar.familyGroupOverdue), findsOneWidget);
      expect(find.text(_ar.familyGroupDueToday), findsOneWidget);
      expect(textContaining('فات الموعد بـ٣ أيام'), findsWidgets);
      final mum = tester.getTopLeft(textContaining('أمي').first).dy;
      final brother = tester.getTopLeft(textContaining('أخي أحمد').first).dy;
      expect(mum, lessThan(brother));
    });

    testWidgets('one tap on the heart logs a contact with a chime, and undo takes it back', (tester) async {
      final env = await pumpFamilyApp(tester, home: const FamilyScreen(), beforePump: seedAr);
      final mumId = people['mother']!.id;
      final before = (await _logsOf(tester, env.db, mumId)).length;

      await tester.tap(find.byType(ContactedButton).first);
      await settleData(tester);
      expect(env.sound.played, contains(Sfx.complete));
      final logs = await _logsOf(tester, env.db, mumId);
      expect(logs, hasLength(before + 1));
      final newest = logs.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
      expect(newest.at, familyTestNow);
      expect(newest.channel, ContactChannel.call); // her usual channel
      final acts = (await tester.runAsync(
        () => Repositories(env.db).activity.since(DateTime(2026), planetKey: 'family'),
      ))!;
      expect(acts.map((a) => a.refId), contains(newest.id));
      expect(textContaining(BidiIsolate.strip(_ar.familyContactedToast('أمي'))), findsWidgets);

      await tester.tap(find.text(_ar.actionUndo));
      await settleData(tester);
      expect(await _logsOf(tester, env.db, mumId), hasLength(before));
      final mum = (await tester.runAsync(() => Repositories(env.db).people.byId(mumId)))!;
      expect(mum.lastContact, daysAgo(5, hour: 20));
    });

    testWidgets('swiping a row right marks the person contacted', (tester) async {
      final env = await pumpFamilyApp(tester, home: const FamilyScreen(), beforePump: seedAr);
      final samId = people['friend']!.id;
      final row = find.ancestor(of: textContaining('سامي').first, matching: find.byType(ActionableItem)).first;
      await tester.drag(row, const Offset(260, 0));
      await settleFamily(tester);
      final logs = await _logsOf(tester, env.db, samId);
      expect(logs.where((l) => l.at == familyTestNow), hasLength(1));
      expect(env.haptics.fired, contains(Haptic.success));
    });

    testWidgets('adding a person: relation suggestion fills the rhythm', (tester) async {
      final env = await pumpFamilyApp(tester, home: const FamilyScreen());
      expect(find.text(_ar.familyEmptyTitle), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(_ar.familyAddPerson).first);
      await settleFamily(tester);
      await tester.enterText(find.byType(TextField).first, 'سعاد');
      await tester.tap(find.text(_ar.familyRelMother));
      await tester.pump();
      await tester.tap(find.text(_ar.familySave));
      await settleFamily(tester);
      final rows = (await tester.runAsync(() => Repositories(env.db).people.getAll()))!;
      expect(rows, hasLength(1));
      expect(rows.single.name, 'سعاد');
      expect(rows.single.relation, 'mother');
      expect(rows.single.rhythmDays, 2);
      expect(rows.single.showAsMoon, isTrue);
      expect(find.text(_ar.familyGroupInTouch), findsNothing);
      expect(textContaining('سعاد'), findsWidgets);
    });

    testWidgets('manual order shows drag grips', (tester) async {
      await pumpFamilyApp(
        tester,
        home: const FamilyScreen(),
        beforePump: (db) async {
          await seedAr(db);
          await FamilyService(Repositories(db)).saveSettings(const FamilySettings(sortMode: FamilySortMode.manual));
        },
      );
      expect(find.byType(ReorderGrip), findsWidgets);
      expect(find.text(_ar.familyGroupOverdue), findsNothing);
    });

    testWidgets('renders with reduced motion', (tester) async {
      await pumpFamilyApp(
        tester,
        home: const FamilyScreen(),
        beforePump: seedEn,
        locale: const Locale('en'),
        reducedMotion: true,
      );
      expect(find.text('3 people are waiting to hear from you'), findsOneWidget);
    });
  });

  group('Person screen', () {
    testWidgets('call / SMS / WhatsApp open on explicit tap only', (tester) async {
      late String id;
      final env = await pumpFamilyApp(
        tester,
        home: Builder(builder: (_) => PersonScreen(personId: id)),
        locale: const Locale('en'),
        beforePump: (db) async {
          await seedEn(db);
          id = people['mother']!.id;
        },
      );
      expect(env.launcher.opened, isEmpty);
      await tester.tap(find.bySemanticsLabel(_en.familyCall).first);
      await tester.tap(find.bySemanticsLabel(_en.familySms).first);
      await tester.tap(find.bySemanticsLabel(_en.familyWhatsApp).first);
      await settleFamily(tester);
      expect(env.launcher.opened.map((u) => u.toString()), [
        'tel:+962790000000',
        'sms:+962790000000',
        'https://wa.me/962790000000',
      ]);
      // Launching logs nothing by itself.
      expect(await _logsOf(tester, env.db, id), hasLength(15));
    });

    testWidgets('contacted with details: channel, yesterday, note', (tester) async {
      late String id;
      final env = await pumpFamilyApp(
        tester,
        home: Builder(builder: (_) => PersonScreen(personId: id)),
        locale: const Locale('en'),
        beforePump: (db) async {
          await seedEn(db);
          id = people['brother']!.id;
        },
      );
      expect(find.text(_en.familyStatsEmpty), findsOneWidget);
      await tester.tap(find.text(_en.familyContactedDetails));
      await settleFamily(tester);
      await tester.tap(find.text(_en.familyChannelVisit));
      await tester.tap(find.text(_en.familyWhenYesterday));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Eid visit');
      await tester.tap(find.text(_en.familyLog));
      await settleFamily(tester);
      final logs = await _logsOf(tester, env.db, id);
      final added = logs.firstWhere((l) => l.note == 'Eid visit');
      expect(added.channel, ContactChannel.visit);
      expect(added.at, DateTime(2026, 9, 28, 20));
      final adam = (await tester.runAsync(() => Repositories(env.db).people.byId(id)))!;
      expect(adam.lastContact, DateTime(2026, 9, 28, 20));
      await scrollTo(tester, find.text('Eid visit'));
      expect(find.text('Eid visit'), findsOneWidget);
    });

    testWidgets('stats: average gap vs rhythm and the history timeline', (tester) async {
      late String id;
      await pumpFamilyApp(
        tester,
        home: Builder(builder: (_) => PersonScreen(personId: id)),
        locale: const Locale('en'),
        beforePump: (db) async {
          await seedEn(db);
          id = people['mother']!.id;
        },
      );
      expect(find.text(_en.familyStatAverage), findsOneWidget);
      expect(find.text('Rhythm: Every 2 days'), findsOneWidget);
      expect(find.byType(IntervalBars), findsOneWidget);
      await scrollTo(tester, find.text(_en.familyBirthdayTitle));
      expect(find.text(_en.familyBirthdayTitle), findsOneWidget);
    });
  });

  group('Family today card', () {
    testWidgets('due people with one-tap contacted, and upcoming birthdays', (tester) async {
      final env = await pumpFamilyApp(
        tester,
        home: const Scaffold(body: SafeArea(child: FamilyTodayCard())),
        locale: const Locale('en'),
        beforePump: seedEn,
      );
      expect(textContaining('Mum'), findsWidgets);
      expect(textContaining("Lily's birthday in 2 days"), findsWidgets);
      expect(find.byType(ContactedButton), findsNWidgets(3));
      await tester.tap(find.byType(ContactedButton).at(1));
      await settleData(tester);
      final logs = await _logsOf(tester, env.db, people['friend']!.id);
      expect(logs.where((l) => l.at == familyTestNow), hasLength(1));
      // Sam is in touch now: only two left.
      expect(find.byType(ContactedButton), findsNWidgets(2));
    });

    testWidgets('empty: invites to add someone', (tester) async {
      await pumpFamilyApp(tester, home: const Scaffold(body: FamilyTodayCard()));
      expect(find.text(_ar.familyCardEmpty), findsOneWidget);
    });
  });

  group('reminder sync', () {
    testWidgets('the sync provider plans the digest and follows a contact', (tester) async {
      final env = await pumpFamilyApp(
        tester,
        home: const FamilyScreen(),
        locale: const Locale('en'),
        beforePump: seedEn,
      );
      final sync = env.container.read(familyReminderSyncProvider.notifier);
      await tester.runAsync(sync.syncNow);
      FakeScheduled digestOf(DateTime at) =>
          env.notifications.scheduled.values.firstWhere((s) => s.request.data['k'] == 'digest' && s.request.at == at);
      final tonight = DateTime(2026, 9, 29, 20);
      expect(BidiIsolate.strip(digestOf(tonight).request.body), startsWith('Mum, Sam, Adam'));

      await tester.tap(find.byType(ContactedButton).first);
      await settleData(tester);
      await tester.runAsync(sync.syncNow);
      expect(BidiIsolate.strip(digestOf(tonight).request.body), startsWith('Sam, Adam'));
      // Leave nothing pending (the debounce timer of the listeners).
      env.container.invalidate(familyReminderSyncProvider);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('editing a person with a free-text relation is not dirty until changed', (tester) async {
      late PersonRow row;
      await pumpFamilyApp(
        tester,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showPersonSheet(context, person: row),
              child: const Text('open'),
            ),
          ),
        ),
        locale: const Locale('en'),
        beforePump: (db) async => row = await seedPerson(Repositories(db), name: 'Ali', relation: 'Cousin', rhythm: 10),
      );
      await tester.tap(find.text('open'));
      await settleFamily(tester);
      expect(find.widgetWithText(TextField, 'Cousin'), findsOneWidget);
      expect(find.text(_en.familyRhythmCustom), findsOneWidget);
      await tester.tap(find.text(_en.actionCancel));
      await settleFamily(tester);
      // Closed straight away: no "discard changes?" bar.
      expect(find.text('Ali'), findsNothing);
    });
  });

  group('texts and links', () {
    test('typed relations map to suggestion keys in either language', () {
      expect(FamilyTexts.relationKeyFor('أمي'), 'mother');
      expect(FamilyTexts.relationKeyFor(' Brother '), 'brother');
      expect(FamilyTexts.relationKeyFor('Cousin Ali'), isNull);
      final ar = FamilyTexts.forLanguage('ar');
      expect(ar.relation('mother'), 'أمي');
      expect(ar.relation('ابن خالتي'), 'ابن خالتي');
      expect(ar.relationBeside('أخي أحمد', 'brother'), isNull);
      expect(ar.relationBeside('سامي', 'friend'), 'صديقي');
      expect(ar.rhythm(7), 'أسبوعيًا');
      expect(ar.rhythm(3), 'كل ٣ أيام');
      expect(ar.rhythm(11), 'كل ١١ يومًا');
      expect(FamilyTexts.forLanguage('en').rhythm(1), 'Daily');
    });

    test('deep links: digits normalised, WhatsApp without + or 00', () {
      expect(ContactUris.uri(ContactLaunch.call, '+962 (79) 123-4567').toString(), 'tel:+962791234567');
      expect(ContactUris.uri(ContactLaunch.sms, '٠٧٩١٢٣٤٥٦٧').toString(), 'sms:0791234567');
      expect(ContactUris.uri(ContactLaunch.whatsapp, '00962791234567').toString(), 'https://wa.me/962791234567');
      expect(ContactUris.uri(ContactLaunch.whatsapp, '+962 79 123 4567').toString(), 'https://wa.me/962791234567');
      expect(ContactUris.uri(ContactLaunch.call, 'n/a'), isNull);
      expect(ContactUris.uri(ContactLaunch.call, null), isNull);
    });
  });
}
