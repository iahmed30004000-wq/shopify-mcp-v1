// The Health world's page is the hub of the body's care: the standing
// alerts pinned above everything; "today's care" (the day's doses, wellbeing
// today with its check-in and breathing, the pain right now – one tap logs
// it with undo); "with your doctor" (the next appointment, the open
// questions, the lab flags); "tools" – in both languages, every part
// opening its screen as a route. Reasons of the Neglect Radar about doses
// open today's doses. The hub's small decisions are pure.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/hub/health_hub.dart';
import 'package:madar/features/health/hub/health_hub_logic.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/orbit/presentation/planet/record_open.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../../orbit/presentation/orbit_scene_fixtures.dart';
import 'hub_seed.dart';

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _fresh(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

Future<TestApp> _healthPage(
  WidgetTester tester, {
  String lang = 'ar',
  Future<void> Function(MadarDatabase db)? seed,
  String? location,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: location ?? AppRoutes.planetOf('health'),
    now: hubTestNow,
    beforePump: seed ?? _fresh,
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

Scrollable _sheet(WidgetTester tester) => tester.widget<Scrollable>(_sheetFinder);

final Finder _sheetFinder = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

/// Scrolls the planet page's sheet until [finder] is built and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _sheetFinder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// A tool tile of the grid, by its semantics ("title. hint").
Finder _tool(String title) => find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. '));

void main() {
  group('pure', () {
    test('open questions keep their order; answered ones leave', () {
      DoctorQuestionRow q(String id, bool answered) => DoctorQuestionRow(
        id: id,
        createdAt: hubTestNow,
        updatedAt: hubTestNow,
        sortOrder: 0,
        question: id,
        answered: answered,
      );
      expect(HealthHubLogic.openQuestions([q('a', false), q('b', true), q('c', false)]).map((e) => e.id), ['a', 'c']);
      expect(HealthHubLogic.openQuestions(const []), isEmpty);
    });

    test("today's pain: count and highest, null when none", () {
      PainEntryRow p(int score) => PainEntryRow(
        id: '$score',
        createdAt: hubTestNow,
        updatedAt: hubTestNow,
        at: hubTestNow,
        score: score,
        locations: const [],
        triggers: const [],
        bodyPoints: const [],
      );
      expect(HealthHubLogic.painToday(const []), isNull);
      expect(HealthHubLogic.painToday([p(3), p(7), p(2)]), (count: 3, highest: 7));
    });

    test('health records open their screens; other worlds keep theirs', () {
      expect(HealthRecordLinks.locationOf('medications', null, planetKey: 'health'), AppRoutes.meds);
      expect(HealthRecordLinks.locationOf('medications', 'm1'), AppRoutes.meds);
      expect(HealthRecordLinks.locationOf('habits', 'h1', planetKey: 'health'), '/wellbeing?tab=habits');
      expect(HealthRecordLinks.locationOf('habits', 'h1', planetKey: 'body'), isNull);
      expect(HealthRecordLinks.locationOf('appointments', 'a1'), '/record/appointments?highlight=a1');
      expect(HealthRecordLinks.locationOf('lab_tests', 't1'), '/record/lab/t1');
      expect(HealthRecordLinks.locationOf('pain_entries', 'p'), '/wellbeing?tab=pain');
      expect(HealthRecordLinks.locationOf('budget_items', 'b'), isNull);
      expect(HealthRecordLinks.locationOf(null, null), isNull);
      // The planet page and the radar: a reason about several medications
      // (no id) opens too.
      expect(RecordOpener.canOpen('medications', null, const [], planetKey: 'health'), isTrue);
      expect(RecordOpener.healthLocation('medications', planetKey: 'health'), AppRoutes.meds);
      expect(RecordOpener.healthLocation('medications:m1', planetKey: 'health'), AppRoutes.meds);
      expect(RecordOpener.canOpen('debts', 'd', const [], planetKey: 'money'), isFalse);
    });
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang fresh install: calm cards, no alerts, questions or labs; tools lead to routes', (tester) async {
      final app = await _healthPage(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      expect(find.byType(HealthHub), findsOneWidget);
      expect(find.byType(HealthAlertsBanner), findsNothing);
      expect(find.byType(TodayDosesCard), findsOneWidget);
      expect(find.text(l.healthHubTodayTitle), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(HealthHub))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await _reveal(tester, find.byType(HealthPainCard));
      expect(find.text(l.healthHubPainNone), findsOneWidget);
      await _reveal(tester, find.byType(NextAppointmentCard));
      expect(find.text(l.recordAppointmentsEmpty), findsOneWidget);
      expect(find.byType(HealthQuestionsCard), findsNothing);
      expect(find.byType(LabFlagsCard), findsNothing);
      await _reveal(tester, find.byType(HealthTools));

      // Every tool opens its screen as a route.
      final tools = <(String, String)>[
        (l.healthHubToolMeds, AppRoutes.medsOf(tab: 'meds')),
        (l.healthHubToolLabs, AppRoutes.record),
        (l.healthHubToolAppointments, AppRoutes.appointments),
        (l.healthHubToolWellbeing, AppRoutes.wellbeing),
        (l.healthHubToolBreathe, AppRoutes.breathing),
      ];
      for (final (title, location) in tools) {
        app.sound.played.clear();
        await tester.tap(_tool(title));
        await settleApp(tester);
        expect(app.router.state.uri.toString(), location, reason: title);
        expect(app.sound.played, contains(Sfx.navigate));
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(find.byType(HealthHub), findsOneWidget);
      }
      // The doctor summary is a sheet over the page.
      await tester.tap(_tool(l.healthHubToolReport));
      await settleApp(tester);
      expect(find.byType(DoctorReportSheet), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('lived in: alerts pinned first, the three movements in order, open questions only', (tester) async {
    await _healthPage(
      tester,
      lang: 'en',
      seed: (db) => seedHealthHub(db, lang: 'en'),
    );
    final l = lookupL10n(const Locale('en'));
    expect(find.byType(HealthAlertsBanner), findsOneWidget);
    expect(find.text('No cortisone in any form'), findsOneWidget);
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(find.byType(HealthAlertsBanner)), lessThan(y(find.text(l.healthHubTodayTitle))));
    expect(y(find.text(l.healthHubTodayTitle)), lessThan(y(find.byType(TodayDosesCard))));

    await _reveal(tester, find.byType(HealthQuestionsCard));
    expect(y(find.text(l.healthHubDoctorTitle)), lessThan(y(find.byType(NextAppointmentCard))));
    final questions = find.byType(HealthQuestionsCard);
    expect(find.descendant(of: questions, matching: find.text(l.healthHubQuestionsCount(3, '3'))), findsOneWidget);
    expect(find.descendant(of: questions, matching: find.text('Should the thyroid pill move?')), findsOneWidget);
    expect(find.descendant(of: questions, matching: find.text('Do I keep taking iron?')), findsNothing);
    await _reveal(tester, find.byType(LabFlagsCard));
    expect(find.descendant(of: find.byType(LabFlagsCard), matching: find.text('Ferritin')), findsOneWidget);
    expect(_sheet(tester), isNotNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('one tap on the pain scale logs it now, with an undo that removes it', (tester) async {
    final app = await _healthPage(tester, lang: 'en');
    final l = lookupL10n(const Locale('en'));
    await _reveal(tester, find.byType(HealthPainCard));
    app.sound.played.clear();
    await tester.tap(find.bySemanticsLabel(l.healthHubPainLogScore('4', '10')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await _frames(tester, 20);
    final repos = Repositories(app.db);
    var rows = (await tester.runAsync(() => repos.painEntries.getAll()))!;
    expect(rows.single.score, 4);
    expect(rows.single.at, hubTestNow);
    expect(app.sound.played, containsAll([Sfx.countTick, Sfx.complete]));
    // Logged on the Health world.
    final activity = (await tester.runAsync(() => repos.activity.since(DateTime(2026, 9, 29), planetKey: 'health')))!;
    expect(activity.map((a) => a.kind), contains('health.pain'));
    expect(find.text(l.healthHubPainToday(1, '1', '4')), findsOneWidget);

    expect(find.text(l.wbPainLogged('4')), findsOneWidget);
    await tester.tap(find.text(l.actionUndo));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await _frames(tester, 20);
    rows = (await tester.runAsync(() => repos.painEntries.getAll()))!;
    expect(rows, isEmpty);
    expect(find.text(l.healthHubPainNone), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the doses card, wellbeing and the questions open their screens as routes", (tester) async {
    final app = await _healthPage(
      tester,
      lang: 'en',
      seed: (db) => seedHealthHub(db, lang: 'en'),
    );
    final l = lookupL10n(const Locale('en'));
    await tester.tap(find.descendant(of: find.byType(TodayDosesCard), matching: find.bySemanticsLabel(l.medsTitle)));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.meds);
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    await _reveal(tester, find.byType(WellbeingTodayCard));
    await tester.tap(find.descendant(of: find.byType(WellbeingTodayCard), matching: find.bySemanticsLabel(l.wbOpen)));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.wellbeing);
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    await _reveal(tester, find.byType(HealthQuestionsCard));
    await tester.tap(find.text(l.healthHubQuestionsTitle));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.recordOf(tab: 'questions'));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a radar link to a medication opens today\'s doses once the world has landed', (tester) async {
    late String medId;
    final app = await _healthPage(
      tester,
      lang: 'en',
      location: AppRoutes.planetOf('health', item: 'medications:placeholder'),
      seed: (db) async {
        await _fresh(db);
        medId = (await MedsService(
          Repositories(db),
          clock: () => hubTestNow,
        ).saveMed(const MedDraft(name: 'Metformin', dose: '500 mg', slots: [MedSlot(ClockHm(8, 0))]))).id;
      },
    );
    expect(medId, isNotEmpty);
    expect(app.router.state.uri.toString(), AppRoutes.meds);
    expect(find.byType(MedsScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
