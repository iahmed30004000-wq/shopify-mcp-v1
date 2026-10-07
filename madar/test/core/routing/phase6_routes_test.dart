// Every Phase 6 (life) route builds its screen in Arabic and English inside
// the full app (router, gates, adhan host, app lock), with the app's shared-
// axis transition; the parameters (a board, a project, a person, a trip, a
// learning goal, a tracker, the travel and body tabs) reach the screens;
// back leaves each page and returns to its parent; the packages' own links
// (Work's boards and projects, a learning goal, a person, a tracker) open as
// routes; the location helpers are exact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/orbit_loader.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/family/family.dart';
import 'package:madar/features/growth/growth.dart';
import 'package:madar/features/travel/travel.dart';
import 'package:madar/features/work/work.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('ids and tabs are encoded; the home tab is the plain path', () {
      expect(AppRoutes.work, '/work');
      expect(AppRoutes.workBoardOf('a b/c'), '/work/board/a%20b%2Fc');
      expect(AppRoutes.workProjects, '/work/projects');
      expect(AppRoutes.workProjectOf('p/1'), '/work/project/p%2F1');
      expect(AppRoutes.family, '/family');
      expect(AppRoutes.familyPersonOf('ا ب'), '/family/person/%D8%A7%20%D8%A8');
      expect(AppRoutes.travelOf(), '/travel');
      expect(AppRoutes.travelOf(tab: 'trips'), '/travel');
      expect(AppRoutes.travelOf(tab: 'documents'), '/travel?tab=documents');
      expect(AppRoutes.travelOf(tab: 'templates'), '/travel?tab=templates');
      expect(AppRoutes.travelTripOf('t 1'), '/travel/trip/t%201');
      expect(AppRoutes.travelTemplateOf('k/2'), '/travel/template/k%2F2');
      expect(AppRoutes.growth, '/growth');
      expect(AppRoutes.growthGoalOf('g/1'), '/growth/goal/g%2F1');
      expect(AppRoutes.bodyOf(), '/body');
      expect(AppRoutes.bodyOf(tab: 'today'), '/body');
      expect(AppRoutes.bodyOf(tab: 'fasting'), '/body?tab=fasting');
      expect(AppRoutes.modules, '/modules');
      expect(AppRoutes.moduleOf('m 1'), '/modules/module/m%201');
      // Learning goals never share Money's savings goals' paths.
      expect(AppRoutes.growthGoalOf('x'), isNot(startsWith(AppRoutes.goals)));
    });

    test('unknown tab names fall back', () {
      expect(TravelRoutePage.tabOf('documents'), TravelTab.documents);
      expect(TravelRoutePage.tabOf('nope'), TravelTab.trips);
      expect(TravelRoutePage.tabOf(null), TravelTab.trips);
      expect(BodyRoutePage.tabOf('water'), BodyTab.water);
      expect(BodyRoutePage.tabOf(null), BodyTab.today);
      expect(BodyRoutePage.tabOf('Fasting'), BodyTab.today, reason: 'names are exact');
    });

    test('the life locations need onboarding like every page', () {
      for (final loc in [AppRoutes.work, AppRoutes.family, AppRoutes.travel, AppRoutes.body, AppRoutes.modules]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.work, WorkScreen),
    (AppRoutes.workBoardOf('missing'), BoardScreen),
    (AppRoutes.workProjects, ProjectsScreen),
    (AppRoutes.workProjectOf('missing'), ProjectScreen),
    (AppRoutes.family, FamilyScreen),
    (AppRoutes.familyPersonOf('missing'), PersonScreen),
    (AppRoutes.travel, TravelScreen),
    (AppRoutes.travelOf(tab: 'documents'), TravelScreen),
    (AppRoutes.travelOf(tab: 'templates'), TravelScreen),
    (AppRoutes.travelTripOf('missing'), TripScreen),
    (AppRoutes.growth, GrowthScreen),
    (AppRoutes.growthGoalOf('missing'), GoalScreen),
    (AppRoutes.body, BodyScreen),
    (AppRoutes.bodyOf(tab: 'fasting'), BodyScreen),
    (AppRoutes.bodyOf(tab: 'water'), BodyScreen),
    (AppRoutes.bodyOf(tab: 'avoid'), BodyScreen),
    (AppRoutes.modules, CustomModulesScreen),
    (AppRoutes.moduleOf('missing'), ModuleScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home (or its world's page): back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          await tester.pump(const Duration(seconds: 6));
        });
      }

      testWidgets('a packing template builds its screen', (tester) async {
        late String id;
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          overrides: LockFixture.empty().overrides,
          beforePump: (db) async => id = (await TravelService(
            Repositories(db),
          ).addTemplate('Umrah', const [PackingTemplateItem('Ihram')])).id,
        );
        app.router.go(AppRoutes.travelTemplateOf(id));
        await settleApp(tester);
        expect(find.byType(PackingTemplateScreen), findsOneWidget);
        expect(tester.widget<PackingTemplateScreen>(find.byType(PackingTemplateScreen)).templateId, id);
        expect(find.text('Umrah'), findsWidgets);
        expect(tester.takeException(), isNull);
        expect(
          ModalRoute.of(tester.element(find.byType(PackingTemplateScreen)))!.settings,
          isA<MadarTransitionPage<void>>(),
        );
        // Nested under Travel: back returns there.
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(app.location, AppRoutes.travel);
        await tester.pump(const Duration(seconds: 6));
      });

      // A deleted list's stale search hit or link (C1) ends in a page.
      testWidgets('a link to a packing template that is gone says so', (tester) async {
        // settle: false – a page that loaded forever would never settle.
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.travelTemplateOf('gone'),
          overrides: LockFixture.empty().overrides,
          settle: false,
        );
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 500));
        }
        final location = app.router.state.uri.toString();
        final screens = find.byType(PackingTemplateScreen).evaluate().length;
        final spinning = find.byType(OrbitLoader).evaluate().isNotEmpty;
        final gone = find.text(lookupL10n(Locale(lang)).travelTemplateNotFound).evaluate().length;
        // Take the app down before the checks (a loader never settles).
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
        expect(location, '/travel/template/gone');
        expect(screens, 1);
        expect(spinning, isFalse, reason: 'still spinning after 5 s for a deleted template');
        expect(gone, 1);
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  }

  testWidgets('the parameters reach the screens; back returns to the world\'s page', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.workBoardOf('b-7'),
      overrides: LockFixture.empty().overrides,
    );
    expect(tester.widget<BoardScreen>(find.byType(BoardScreen)).boardId, 'b-7');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.work, reason: 'a board is nested under Work');

    Future<T> at<T extends Widget>(String location) async {
      app.router.go(location);
      await settleApp(tester);
      return tester.widget<T>(find.byType(T));
    }

    expect((await at<ProjectScreen>(AppRoutes.workProjectOf('p-1'))).projectId, 'p-1');
    expect((await at<PersonScreen>(AppRoutes.familyPersonOf('u-2'))).personId, 'u-2');
    expect((await at<TravelScreen>(AppRoutes.travelOf(tab: 'templates'))).initialTab, TravelTab.templates);
    expect((await at<TravelScreen>(AppRoutes.travelOf(tab: 'documents'))).initialTab, TravelTab.documents);
    expect((await at<TripScreen>(AppRoutes.travelTripOf('t-3'))).tripId, 't-3');
    expect((await at<BodyScreen>(AppRoutes.bodyOf(tab: 'avoid'))).initialTab, BodyTab.avoid);
    expect((await at<BodyScreen>(AppRoutes.bodyOf(tab: 'nonsense'))).initialTab, BodyTab.today);
    expect((await at<ModuleScreen>(AppRoutes.moduleOf('m-5'))).moduleId, 'm-5');
    expect((await at<GoalScreen>(AppRoutes.growthGoalOf('g-4'))).goalId, 'g-4');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.growth, reason: 'a learning goal is nested under Growth');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the packages' own links open as routes; back returns", (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.work,
      overrides: LockFixture.empty().overrides,
    );
    expect(app.container.read(workRoutesProvider), isA<RoutedWorkRoutes>());

    // Work: its navigation goes through the router.
    final work = tester.element(find.byType(WorkScreen));
    final ref = work as WidgetRef;
    WorkNavigation.toBoard(work, ref, 'b1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/work/board/b1');
    expect(find.byType(BoardScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.work);
    WorkNavigation.toProjects(tester.element(find.byType(WorkScreen)), ref);
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.workProjects);
    WorkNavigation.toProject(tester.element(find.byType(ProjectsScreen)), ref, 'p1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/work/project/p1');
    expect(find.byType(ProjectScreen), findsOneWidget);

    // Growth: a learning goal.
    app.router.go(AppRoutes.growth);
    await settleApp(tester);
    final open = app.container.read(growthOpenGoalProvider);
    expect(open, isNotNull);
    open!(tester.element(find.byType(GrowthScreen)), 'g1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/growth/goal/g1');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.growth);

    // Family: a person from the list.
    app.router.go(AppRoutes.family);
    await settleApp(tester);
    final family = tester.widget<FamilyScreen>(find.byType(FamilyScreen));
    expect(family.onOpenPerson, isNotNull);
    family.onOpenPerson!(tester.element(find.byType(FamilyScreen)), 'u1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/family/person/u1');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.family);

    // Custom modules: a tracker from the list.
    app.router.go(AppRoutes.modules);
    await settleApp(tester);
    final modules = tester.widget<CustomModulesScreen>(find.byType(CustomModulesScreen));
    expect(modules.onOpenModule, isNotNull);
    modules.onOpenModule!(tester.element(find.byType(CustomModulesScreen)), 'm1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/modules/module/m1');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.modules);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
