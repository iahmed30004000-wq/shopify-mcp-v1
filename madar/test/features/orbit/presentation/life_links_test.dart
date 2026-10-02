// Life records open their own pages from the orbit: the pure table of
// where every life table leads (one source of truth for reasons, moons and
// search), the record opener's rules, a reason row on the Work page, and
// the moon sheets of a person, a board, a trip and a tracker with their
// "Open …" button – also when the page was reached through a moon link
// (the home-screen widget's `/planet/work?item=boards:<id>`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/orbit/presentation/planet/record_open.dart';
import 'package:madar/features/travel/travel.dart';
import 'package:madar/features/work/work.dart';

import '../../../helpers/test_app.dart';
import '../../family/family_seed.dart' show seedPerson;
import '../../lock/lock_test_utils.dart';

final _en = lookupL10n(const Locale('en'));

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<TestApp> _page(WidgetTester tester, String location, Future<void> Function(MadarDatabase db) seed) async {
  final app = await pumpMadarApp(
    tester,
    settings: const AppSettings(onboarded: true, languageCode: 'en'),
    initialLocation: location,
    beforePump: seed,
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

final Finder _sheet = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

/// A hung frame loop fails in minutes, not after the default ten.
void _testWidgets(String description, WidgetTesterCallback body) =>
    testWidgets(description, body, timeout: const Timeout(Duration(minutes: 3)));

void main() {
  group('where a life record leads (pure)', () {
    test('every table, with and without its id', () {
      String? at(String table, [String? id, Map<String, Object?> extra = const {}]) =>
          LifeRecordLinks.locationOf(table, id, extra: extra);
      final rows = <(String, String?, Map<String, Object?>, String?)>[
        ('people', 'p 1', const {}, '/family/person/p%201'),
        ('people', null, const {}, '/family'),
        ('contact_logs', 'c1', const {'personId': 'p1'}, '/family/person/p1'),
        ('contact_logs', 'c1', const {}, '/family'),
        ('boards', 'b1', const {}, '/work/board/b1'),
        ('boards', null, const {}, '/work'),
        ('board_cards', 'k1', const {'boardId': 'b1', 'columnId': 'todo'}, '/work/board/b1'),
        ('board_cards', 'k1', const {}, '/work'),
        ('projects', 'p/1', const {}, '/work/project/p%2F1'),
        ('projects', null, const {}, '/work/projects'),
        ('project_items', 'i1', const {'projectId': 'p1'}, '/work/project/p1'),
        ('project_items', 'i1', const {}, '/work/projects'),
        ('trips', 't1', const {}, '/travel/trip/t1'),
        ('trips', null, const {}, '/travel'),
        ('trip_items', 'x1', const {'tripId': 't1'}, '/travel/trip/t1'),
        ('trip_items', 'x1', const {}, '/travel'),
        ('travel_documents', 'd1', const {}, '/travel?tab=documents'),
        ('travel_documents', null, const {}, '/travel?tab=documents'),
        ('packing_templates', 'k1', const {}, '/travel/template/k1'),
        ('packing_templates', null, const {}, '/travel?tab=templates'),
        ('learning_goals', 'g1', const {}, '/growth/goal/g1'),
        ('learning_goals', null, const {}, '/growth'),
        ('goal_logs', 'l1', const {'goalId': 'g1'}, '/growth/goal/g1'),
        ('goal_logs', 'l1', const {}, '/growth'),
        ('exercises', null, const {}, '/body?tab=plan'),
        ('exercises', 'e1', const {}, '/body?tab=plan'),
        ('workout_logs', 'w1', const {'exerciseId': 'e1'}, '/body?tab=plan'),
        ('fasting_sessions', 'f1', const {}, '/body?tab=fasting'),
        ('water_logs', 'w1', const {}, '/body?tab=water'),
        ('avoid_items', 'a1', const {}, '/body?tab=avoid'),
        ('custom_modules', 'm1', const {}, '/modules/module/m1'),
        ('custom_modules', null, const {}, '/modules'),
        ('custom_entries', 'e1', const {'moduleId': 'm1'}, '/modules/module/m1'),
        ('custom_entries', 'e1', const {}, '/modules'),
        // Not life's.
        ('tasks', 't1', const {}, null),
        ('wallets', 'w1', const {}, null),
        ('medications', null, const {}, null),
      ];
      for (final (table, id, extra, location) in rows) {
        expect(at(table, id, extra), location, reason: '$table:$id $extra');
      }
      expect(LifeRecordLinks.locationOf(null, 'x'), isNull);
      expect(LifeRecordLinks.locationOf('people', ''), '/family', reason: 'an empty id is no id');
      expect(at('board_cards', 'k1', const {'boardId': ''}), '/work', reason: 'an empty parent is no parent');
      expect(at('contact_logs', 'c1', const {'personId': 42}), '/family', reason: 'a parent must be a string');
      for (final table in LifeRecordLinks.tables) {
        expect(at(table), isNotNull, reason: table);
      }
    });

    test('the record opener knows life records (a reason without an id too)', () {
      expect(RecordOpener.canOpen('projects', 'p1', const []), isTrue);
      expect(RecordOpener.canOpen('learning_goals', 'g', const []), isTrue);
      expect(RecordOpener.canOpen('travel_documents', 'd', const []), isTrue);
      expect(RecordOpener.canOpen('exercises', null, const []), isTrue, reason: 'the training plan');
      expect(RecordOpener.canOpen('custom_modules', 'm1', const []), isTrue);
      expect(RecordOpener.canOpen('budgets', 'b1', const []), isFalse);
      expect(RecordOpener.lifeLocation('projects:p1'), '/work/project/p1');
      expect(RecordOpener.lifeLocation('exercises'), '/body?tab=plan');
      expect(RecordOpener.lifeLocation('custom_modules:a:b'), '/modules/module/a%3Ab');
      expect(RecordOpener.lifeLocation('tasks:t1'), isNull);
      expect(RecordOpener.lifeLocation('medications'), isNull);
    });

    test('the orbit and Work read the archived boards from the same key', () {
      expect(WorkService.archivedKey, 'work.archivedBoards');
    });
  });

  _testWidgets("a Work reason about a project's overdue items opens the project", (tester) async {
    late String projectId;
    final app = await _page(tester, AppRoutes.planetOf('work'), (db) async {
      final work = WorkService(Repositories(db), clock: () => testNow);
      final p = await work.createProject(const ProjectDraft(name: 'Launch plan'));
      projectId = p.id;
      await work.addItem(p.id, 'Print the flyers', dueDate: testNow.subtract(const Duration(days: 4)));
    });
    final reason = find.textContaining('Launch plan');
    await tester.scrollUntilVisible(reason, 250, scrollable: _sheet);
    await tester.pumpAndSettle();
    expect(reason, findsOneWidget);
    app.sound.played.clear();
    await tester.tap(reason);
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.workProjectOf(projectId));
    expect(find.byType(ProjectScreen), findsOneWidget);
    expect(app.sound.played, contains(Sfx.tap));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.planetOf('work'));
    await tester.pump(const Duration(seconds: 6));
  });

  final moons =
      <(String, String, String Function(L10n), Future<String> Function(MadarDatabase), String Function(String))>[
        (
          'family',
          'people',
          (l) => l.lifeHubMoonOpenPerson,
          (db) async => (await seedPerson(Repositories(db), name: 'Salma', rhythm: 7, moon: true)).id,
          AppRoutes.familyPersonOf,
        ),
        (
          'work',
          'boards',
          (l) => l.lifeHubMoonOpenBoard,
          (db) async => (await WorkService(Repositories(db), clock: () => testNow).createBoard(name: 'Shop')).id,
          AppRoutes.workBoardOf,
        ),
        (
          'travel',
          'trips',
          (l) => l.lifeHubMoonOpenTrip,
          (db) async => (await TravelService(Repositories(db), clock: () => testNow).addTrip(
            TripDraft(destination: 'Aqaba', startDate: DateTime(2026, 10, 20), endDate: DateTime(2026, 10, 24)),
          )).id,
          AppRoutes.travelTripOf,
        ),
        (
          'growth',
          'custom_modules',
          (l) => l.lifeHubMoonOpenModule,
          (db) async => (await CustomModulesService(Repositories(db)).createModule(
            ModuleTemplates.build(
              ModuleTemplateKey.readingLog,
              (t) => t.name,
            ).copyWith(name: 'Reading', planetKey: 'growth'),
          )).id,
          AppRoutes.moduleOf,
        ),
      ];

  for (final (planet, table, label, seed, route) in moons) {
    _testWidgets("a $table moon's sheet opens its record's page", (tester) async {
      late String id;
      final app = await _page(tester, AppRoutes.home, (db) async => id = await seed(db));
      // A moon link (the home-screen widget's, the orbit's) lands on the
      // world with that moon's sheet up.
      app.router.go(AppRoutes.planetOf(planet, item: '$table:$id'));
      await _frames(tester, 90);
      await settleApp(tester);
      final open = find.text(label(_en));
      expect(open, findsOneWidget, reason: 'the moon sheet offers to open it');
      if (table == 'people') {
        expect(find.text(_en.orbitUiMoonInTouch), findsOneWidget, reason: '"in touch" stays first');
        expect(tester.getTopLeft(find.text(_en.orbitUiMoonInTouch)).dy, lessThan(tester.getTopLeft(open).dy));
      }
      app.sound.played.clear();
      await tester.tap(open);
      await settleApp(tester);
      expect(app.router.state.uri.toString(), route(id));
      expect(app.sound.played, contains(Sfx.navigate));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.router.state.uri.toString(), startsWith('/planet/$planet'));
      await tester.pump(const Duration(seconds: 6));
    });
  }

  _testWidgets('an archived board is no moon: its link opens the board itself', (tester) async {
    late String id;
    final app = await _page(tester, AppRoutes.home, (db) async {
      final work = WorkService(Repositories(db), clock: () => testNow);
      id = (await work.createBoard(name: 'Old shop')).id;
      await work.setArchived(id, true);
    });
    app.router.go(AppRoutes.planetOf('work', item: 'boards:$id'));
    await _frames(tester, 90);
    await settleApp(tester);
    expect(find.text(_en.lifeHubMoonOpenBoard), findsNothing, reason: 'no moon sheet');
    expect(app.router.state.uri.toString(), AppRoutes.workBoardOf(id));
    expect(find.byType(BoardScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
