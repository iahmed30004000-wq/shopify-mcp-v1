// Global search: every kind of result must open its own screen.
//
// Three layers:
// 1. the pure mapping, one case per open key (table-driven);
// 2. a guard: every refTable the search really produces (loaded from the
//    fixtures through BuiltInSearchSources, plus the Quran's ayat and the
//    planets) has a target – a new source without a mapping fails here;
// 3. the real app: a money result pushes (back returns to the results), a
//    planet or task result goes (home stays underneath), and a kind with no
//    screen says so instead of doing nothing.
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/routing/system_route_pages.dart';
import 'package:madar/features/search/search.dart';

import '../core/db/fixtures.dart';
import '../helpers/test_app.dart';

SearchDoc _doc(
  String refTable, {
  String refId = 'r1',
  String planetKey = 'work',
  Map<String, String> extra = const {},
  String? openKey,
}) => SearchDoc(
  id: refId,
  refTable: refTable,
  refId: refId,
  title: 'x',
  planetKey: planetKey,
  extra: extra,
  openKey: openKey,
);

void main() {
  // ---------------------------------------------------------------- 1
  group('searchTargetOf', () {
    final cases = <({String name, SearchDoc doc, String target})>[
      (name: 'a task opens its planet page on the task', doc: _doc('tasks', refId: 't1'), target: '/planet/work?item=tasks%3At1'),
      (name: 'a planet opens its page', doc: _doc('planets', refId: 'health'), target: '/planet/health'),
      (name: 'a prayer log opens the tracker history', doc: _doc('prayer_logs'), target: AppRoutes.prayerTrackerHistory),
      (
        name: 'a Quran bookmark opens the reader at its ayah',
        doc: _doc('quran_bookmarks', extra: {'surah': '2', 'ayah': '255'}),
        target: '/quran/read?ayah=2%3A255',
      ),
      (
        name: 'an ayah opens the reader at itself',
        doc: _doc('quran_ayat', refId: '2:255', openKey: 'quran.ayah'),
        target: '/quran/read?ayah=2%3A255',
      ),
      (
        name: 'a broken ayah still opens the reader',
        doc: _doc('quran_ayat', refId: 'nonsense', openKey: 'quran.ayah'),
        target: AppRoutes.quranReader,
      ),
      (name: 'a wird plan opens the wird on it', doc: _doc('wird_plans', refId: 'p1'), target: '/wird?plan=p1'),
      (name: 'a Hifz card opens Hifz', doc: _doc('hifz_items'), target: AppRoutes.hifz),
      (name: 'a standing alert opens the Health world', doc: _doc('health_alerts'), target: '/planet/health'),
      (name: 'a condition opens the record', doc: _doc('conditions'), target: '/record?tab=conditions'),
      (name: 'a medication opens My meds', doc: _doc('medications'), target: '/meds?tab=meds'),
      (name: 'a course opens the courses', doc: _doc('med_courses'), target: '/meds?tab=courses'),
      (name: 'a dose opens today', doc: _doc('med_doses'), target: AppRoutes.meds),
      (name: 'a lab test opens itself', doc: _doc('lab_tests', refId: 'l1'), target: '/record/lab/l1'),
      (
        name: 'a reading opens its test',
        doc: _doc('lab_readings', extra: {'testId': 'l1'}),
        target: '/record/lab/l1',
      ),
      (name: 'a reading with no test opens the record', doc: _doc('lab_readings'), target: AppRoutes.record),
      (
        name: 'an appointment opens lit',
        doc: _doc('appointments', refId: 'a1'),
        target: '/record/appointments?highlight=a1',
      ),
      (
        name: 'a question opens its appointment',
        doc: _doc('doctor_questions', extra: {'appointmentId': 'a1'}),
        target: '/record/appointments?highlight=a1',
      ),
      (name: 'a loose question opens the questions', doc: _doc('doctor_questions'), target: '/record?tab=questions'),
      (name: 'a pain entry opens pain', doc: _doc('pain_entries'), target: '/wellbeing?tab=pain'),
      (name: 'a mood entry opens wellbeing', doc: _doc('mood_entries'), target: AppRoutes.wellbeing),
      (name: 'a habit opens the habits', doc: _doc('habits'), target: '/wellbeing?tab=habits'),
      (name: 'a worry opens the worries', doc: _doc('worries'), target: '/wellbeing?tab=worries'),
      (name: 'a wallet opens itself', doc: _doc('wallets', refId: 'w1'), target: '/ledger/wallet/w1'),
      (
        name: 'an entry opens its wallet\'s list',
        doc: _doc('transactions', extra: {'walletId': 'w1'}),
        target: '/ledger/transactions?wallet=w1',
      ),
      (name: 'an entry with no wallet opens the ledger', doc: _doc('transactions'), target: AppRoutes.ledger),
      (name: 'a budget item opens the plan', doc: _doc('budget_items'), target: AppRoutes.budget),
      (name: 'a jar opens itself', doc: _doc('jars', refId: 'j1'), target: '/goals/jar/j1'),
      (name: 'a deposit opens its jar', doc: _doc('jar_deposits', extra: {'jarId': 'j1'}), target: '/goals/jar/j1'),
      (name: 'a debt opens its sheet', doc: _doc('debts', refId: 'd1'), target: AppRoutes.goalsOf(debt: 'd1')),
      (
        name: 'a payment opens its debt',
        doc: _doc('debt_payments', extra: {'debtId': 'd1'}),
        target: AppRoutes.goalsOf(debt: 'd1'),
      ),
      (
        name: 'an obligation opens its sheet',
        doc: _doc('obligations', refId: 'o1'),
        target: AppRoutes.goalsOf(obligation: 'o1'),
      ),
      // The life worlds go through LifeRecordLinks (one source of truth).
      (name: 'a person opens their page', doc: _doc('people', refId: 'p1'), target: '/family/person/p1'),
      (
        name: 'a contact log opens the person',
        doc: _doc('contact_logs', extra: {'personId': 'p1'}),
        target: '/family/person/p1',
      ),
      (name: 'a board opens itself', doc: _doc('boards', refId: 'b1'), target: '/work/board/b1'),
      (name: 'a card opens its board', doc: _doc('board_cards', extra: {'boardId': 'b1'}), target: '/work/board/b1'),
      (name: 'a project opens itself', doc: _doc('projects', refId: 'pr1'), target: '/work/project/pr1'),
      (
        name: 'a project item opens its project',
        doc: _doc('project_items', extra: {'projectId': 'pr1'}),
        target: '/work/project/pr1',
      ),
      (name: 'a trip opens itself', doc: _doc('trips', refId: 'tr1'), target: '/travel/trip/tr1'),
      (name: 'a trip item opens its trip', doc: _doc('trip_items', extra: {'tripId': 'tr1'}), target: '/travel/trip/tr1'),
      (name: 'a document opens the documents', doc: _doc('travel_documents'), target: '/travel?tab=documents'),
      (
        name: 'a packing template opens itself',
        doc: _doc('packing_templates', refId: 'pt1'),
        target: '/travel/template/pt1',
      ),
      (name: 'a learning goal opens itself', doc: _doc('learning_goals', refId: 'g1'), target: '/growth/goal/g1'),
      (name: 'a goal log opens its goal', doc: _doc('goal_logs', extra: {'goalId': 'g1'}), target: '/growth/goal/g1'),
      (name: 'an exercise opens the plan', doc: _doc('exercises'), target: '/body?tab=plan'),
      (name: 'a workout opens the plan', doc: _doc('workout_logs'), target: '/body?tab=plan'),
      (name: 'an avoid item opens the avoid list', doc: _doc('avoid_items'), target: '/body?tab=avoid'),
      (name: 'a fast opens the fasting tab', doc: _doc('fasting_sessions'), target: '/body?tab=fasting'),
      (name: 'a tracker opens itself', doc: _doc('custom_modules', refId: 'm1'), target: '/modules/module/m1'),
      (
        name: 'a tracker entry opens its tracker',
        doc: _doc('custom_entries', extra: {'moduleId': 'm1'}),
        target: '/modules/module/m1',
      ),
      // Nutrition: indexed by the five food sources (Part 2, second half).
      (name: 'a food opens the library', doc: _doc('foods'), target: AppRoutes.foodLibrary),
      (name: 'a food log opens the food of the day', doc: _doc('food_logs'), target: '/body?tab=food'),
      (name: 'a meal plan opens the plan', doc: _doc('meal_plans'), target: AppRoutes.foodPlan),
      (name: 'a meal of a plan opens the plan', doc: _doc('meal_slots', refId: 's1'), target: AppRoutes.foodPlan),
      (
        name: 'a planned food opens the plan too',
        doc: _doc('meal_slot_foods', refId: 'sf1'),
        target: AppRoutes.foodPlan,
      ),
      (name: 'a food rule opens the rules', doc: _doc('food_rules'), target: AppRoutes.foodRules),
    ];

    for (final c in cases) {
      test(c.name, () => expect(searchTargetOf(c.doc), c.target));
    }

    test('a kind with no screen has no target', () {
      expect(searchTargetOf(_doc('something_new')), isNull);
      expect(searchTargetOf(_doc('tasks', refId: '')), isNull, reason: 'a task with no id opens nothing');
    });
  });

  // ---------------------------------------------------------------- 2
  test('every refTable the search produces has a route', () async {
    await initializeDateFormatting('en');
    final db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    addTearDown(db.close);
    await populateAllTables(db);
    final ctx = SearchLoadContext(
      repos: Repositories(db),
      l10n: lookupL10n(const Locale('en')),
      formatter: const MadarFormatter(languageCode: 'en'),
      surahName: (_) => null,
    );
    final docs = <SearchDoc>[
      for (final source in BuiltInSearchSources.all())
        for (final d in await source.load(ctx)) d.withSource(source.id),
      // The Quran's ayat are searched live, not loaded from a table.
      _doc('quran_ayat', refId: '2:255', openKey: 'quran.ayah'),
    ];
    expect(docs, isNotEmpty);
    final unopenable = <String>{
      for (final d in docs)
        if (searchTargetOf(d) == null) '${d.openKey} (${d.refId})',
    };
    expect(unopenable, isEmpty, reason: 'these results would say "can\'t be opened from here yet"');
  });

  // ---------------------------------------------------------------- 3
  group('in the real app', () {
    testWidgets('a money result is pushed, and back returns to the results', (tester) async {
      final app = await pumpMadarApp(tester, initialLocation: AppRoutes.search);
      final context = tester.element(find.byType(GlobalSearchScreen));
      final opener = app.container.read(searchOpenerProvider)!;

      expect(await opener(context, _doc('wallets', refId: 'w1', planetKey: 'money')), isTrue);
      await settleApp(tester);
      expect(app.location, '/ledger/wallet/w1');

      app.router.pop();
      await settleApp(tester);
      expect(app.location, AppRoutes.search, reason: 'back must return to the results');
    });

    testWidgets('a planet result goes, so home stays underneath', (tester) async {
      final app = await pumpMadarApp(tester, initialLocation: AppRoutes.search);
      final context = tester.element(find.byType(GlobalSearchScreen));
      final opener = app.container.read(searchOpenerProvider)!;

      expect(await opener(context, _doc('planets', refId: 'faith', planetKey: 'faith')), isTrue);
      await settleApp(tester);
      expect(app.location, '/planet/faith');
      expect(find.byType(GlobalSearchScreen), findsNothing, reason: 'the planet route replaces the search');
    });

    testWidgets('a result with no screen is reported, not swallowed', (tester) async {
      final app = await pumpMadarApp(tester, initialLocation: AppRoutes.search);
      final context = tester.element(find.byType(GlobalSearchScreen));
      final opener = app.container.read(searchOpenerProvider)!;
      expect(await opener(context, _doc('something_new')), isFalse);
      await settleApp(tester);
      expect(app.location, AppRoutes.search);
    });
  });
}
