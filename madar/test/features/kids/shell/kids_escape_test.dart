// THE ESCAPE-HATCH SUITE of «مدار الصغار» (PLAN Part 16, DoD).
//
// With kids mode ON, try every way out of the shell and assert it lands INSIDE
// `/kids/**` (or at the PIN gate), never in the adult app:
//
// * every `AppRoutes` constant, by `go` and by `push` – and a test that FAILS if
//   a constant is added to routes.dart without being added to the list below;
// * every `...Of(...)` location builder;
// * a notification tap for every namespace (warm, cold launch, while a section
//   is open); a share intent; a search result; a widget link; a platform deep
//   link; a restored route; the app killed and relaunched; recents;
// * the system Back (also pressed over and over);
// * the app lock interplay;
// * each of the six areas named by the owner (health, medication, the wallet,
//   the family planet, the chat, the work board), by route, deep link,
//   notification tap and search;
// * the gate: a wrong PIN does not open it, the PIN and the fingerprint do.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/data/biometric_auth.dart'
    show BiometricOutcome;
import 'package:madar/core/routing/system_route_pages.dart'
    show SystemNav, searchTargetOf;
import 'package:madar/features/ai_bridge/ai_bridge.dart'
    show
        SharedPlanPayload,
        ShareIntake,
        pendingSharedPlanProvider,
        shareIntakeProvider;
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/kids/shell/kids_shell.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/search/search.dart' show SearchDoc;
import 'package:madar/features/settings/settings_screen.dart';
import 'package:madar/features/widgets/widgets.dart'
    show widgetOpenLocationProvider;

import '../../../helpers/test_app.dart';
import 'kids_test_utils.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

/// `:param` placeholders of a route pattern filled with a plain id.
String _fill(String pattern) =>
    pattern.replaceAllMapped(RegExp(r':\w+'), (_) => 'x');

/// EVERY `AppRoutes` constant, written out. [routesCoverTheFile] fails when
/// routes.dart gains a constant that is missing here.
final Map<String, String> allRoutes = {
  'home': AppRoutes.home,
  'onboarding': AppRoutes.onboarding,
  'settings': AppRoutes.settings,
  'appearance': AppRoutes.appearance,
  'sound': AppRoutes.sound,
  'licenses': AppRoutes.licenses,
  'import': AppRoutes.import,
  'gallery': AppRoutes.gallery,
  'prayerTimes': AppRoutes.prayerTimes,
  'prayerSettings': AppRoutes.prayerSettings,
  'adhanSettings': AppRoutes.adhanSettings,
  'iqamaSettings': AppRoutes.iqamaSettings,
  'fasting': AppRoutes.fasting,
  'ramadan': AppRoutes.ramadan,
  'security': AppRoutes.security,
  'prayerTracker': AppRoutes.prayerTracker,
  'prayerTrackerHistory': AppRoutes.prayerTrackerHistory,
  'adhkar': AppRoutes.adhkar,
  'tasbeeh': AppRoutes.tasbeeh,
  'adhkarSet': _fill(AppRoutes.adhkarSet),
  'planet': _fill(AppRoutes.planet),
  'quran': AppRoutes.quran,
  'quranReader': AppRoutes.quranReader,
  'quranSearch': AppRoutes.quranSearch,
  'wird': AppRoutes.wird,
  'hifz': AppRoutes.hifz,
  'hifzReview': AppRoutes.hifzReview,
  'hifzPlan': AppRoutes.hifzPlan,
  'hifzMap': AppRoutes.hifzMap,
  'hifzGoals': AppRoutes.hifzGoals,
  'hifzFind': AppRoutes.hifzFind,
  'qibla': AppRoutes.qibla,
  'nowPlaying': AppRoutes.nowPlaying,
  'quranSettings': AppRoutes.quranSettings,
  'recitationSettings': AppRoutes.recitationSettings,
  'recitationDownloads': AppRoutes.recitationDownloads,
  'reminders': AppRoutes.reminders,
  'meds': AppRoutes.meds,
  'record': AppRoutes.record,
  'labTest': _fill(AppRoutes.labTest),
  'appointments': AppRoutes.appointments,
  'wellbeing': AppRoutes.wellbeing,
  'breathing': AppRoutes.breathing,
  'healthSettings': AppRoutes.healthSettings,
  'ledger': AppRoutes.ledger,
  'wallet': _fill(AppRoutes.wallet),
  'transactions': AppRoutes.transactions,
  'currencies': AppRoutes.currencies,
  'budget': AppRoutes.budget,
  'goals': AppRoutes.goals,
  'jar': _fill(AppRoutes.jar),
  'work': AppRoutes.work,
  'workBoard': _fill(AppRoutes.workBoard),
  'workProjects': AppRoutes.workProjects,
  'workProject': _fill(AppRoutes.workProject),
  'family': AppRoutes.family,
  'familyPerson': _fill(AppRoutes.familyPerson),
  'travel': AppRoutes.travel,
  'travelTrip': _fill(AppRoutes.travelTrip),
  'travelTemplate': _fill(AppRoutes.travelTemplate),
  'growth': AppRoutes.growth,
  'growthGoal': _fill(AppRoutes.growthGoal),
  'body': AppRoutes.body,
  'gymExercise': _fill(AppRoutes.gymExercise),
  'gymSession': AppRoutes.gymSession,
  'gymTemplates': AppRoutes.gymTemplates,
  'foodLibrary': AppRoutes.foodLibrary,
  'foodPlan': AppRoutes.foodPlan,
  'foodRules': AppRoutes.foodRules,
  'foodInsights': AppRoutes.foodInsights,
  'modules': AppRoutes.modules,
  'module': _fill(AppRoutes.module),
  'sufraPantry': AppRoutes.sufraPantry,
  'sufraRecipes': AppRoutes.sufraRecipes,
  'sufraRecipe': _fill(AppRoutes.sufraRecipe),
  'sufraTonight': AppRoutes.sufraTonight,
  'sufraRules': AppRoutes.sufraRules,
  'sufraHistory': AppRoutes.sufraHistory,
  'recordListsAll': AppRoutes.recordListsAll,
  'recordLists': _fill(AppRoutes.recordLists),
  'recordList': _fill(AppRoutes.recordList),
  'cinema': AppRoutes.cinema,
  'cinemaGame': _fill(AppRoutes.cinemaGame),
  'savedGames': AppRoutes.savedGames,
  'search': AppRoutes.search,
  'notifications': AppRoutes.notifications,
  'notificationSettings': AppRoutes.notificationSettings,
  'dataCentre': AppRoutes.dataCentre,
  'plans': AppRoutes.plans,
  'planImport': AppRoutes.planImport,
  'plan': _fill(AppRoutes.plan),
  'dataRestore': AppRoutes.dataRestore,
  'dayChat': AppRoutes.dayChat,
  'ai': AppRoutes.ai,
  'aiChats': AppRoutes.aiChats,
  'aiChat': _fill(AppRoutes.aiChat),
  'aiSettings': AppRoutes.aiSettings,
  'ondeviceSettings': AppRoutes.ondeviceSettings,
  'widgetsSettings': AppRoutes.widgetsSettings,
  'together': AppRoutes.together,
  'togetherHallOfFame': AppRoutes.togetherHallOfFame,
  'togetherKnowMe': AppRoutes.togetherKnowMe,
  'togetherWeekly': AppRoutes.togetherWeekly,
  'togetherGoal': AppRoutes.togetherGoal,
  // The kids shell's own: allowed, and still inside.
  'kids': AppRoutes.kids,
  'kidsSection': _fill(AppRoutes.kidsSection),
};

/// EVERY `AppRoutes.xxxOf(...)` builder, called once. [routesCoverTheFile]
/// fails when routes.dart gains one that is missing here.
final Map<String, String> allBuilders = {
  'adhkarSetOf': AppRoutes.adhkarSetOf('afterPrayer', prayer: 'asr'),
  'planetOf': AppRoutes.planetOf('health', item: 'people:x'),
  'quranReaderOf': AppRoutes.quranReaderOf(page: 42),
  'wirdOf': AppRoutes.wirdOf('p'),
  'hifzReviewOf': AppRoutes.hifzReviewOf('c'),
  'hifzFindOf': AppRoutes.hifzFindOf('q'),
  'recitationDownloadsOf': AppRoutes.recitationDownloadsOf('r'),
  'medsOf': AppRoutes.medsOf(tab: 'courses'),
  'recordOf': AppRoutes.recordOf(tab: 'labs'),
  'labTestOf': AppRoutes.labTestOf('x'),
  'appointmentsOf': AppRoutes.appointmentsOf(highlightId: 'x'),
  'wellbeingOf': AppRoutes.wellbeingOf(tab: 'worries'),
  'breathingOf': AppRoutes.breathingOf(pattern: 'box'),
  'walletOf': AppRoutes.walletOf('x'),
  'transactionsOf': AppRoutes.transactionsOf({
    'wallet': ['x'],
  }),
  'budgetOf': AppRoutes.budgetOf(tab: 'spending'),
  'goalsOf': AppRoutes.goalsOf(debt: 'x'),
  'jarOf': AppRoutes.jarOf('x'),
  'workBoardOf': AppRoutes.workBoardOf('x'),
  'workProjectOf': AppRoutes.workProjectOf('x'),
  'familyPersonOf': AppRoutes.familyPersonOf('x'),
  'travelOf': AppRoutes.travelOf(tab: 'documents'),
  'travelTripOf': AppRoutes.travelTripOf('x'),
  'travelTemplateOf': AppRoutes.travelTemplateOf('x'),
  'growthGoalOf': AppRoutes.growthGoalOf('x'),
  'bodyOf': AppRoutes.bodyOf(tab: 'food'),
  'gymExerciseOf': AppRoutes.gymExerciseOf('x'),
  'moduleOf': AppRoutes.moduleOf('x'),
  'sufraRecipeOf': AppRoutes.sufraRecipeOf('x'),
  'recordListsOf': AppRoutes.recordListsOf('budget_items', 'x'),
  'recordListOf': AppRoutes.recordListOf('x'),
  'cinemaGameOf': AppRoutes.cinemaGameOf('x'),
  'savedGamesOf': AppRoutes.savedGamesOf(sharedText: 'https://example.com'),
  'searchOf': AppRoutes.searchOf(query: 'x'),
  'notificationsOf': AppRoutes.notificationsOf(tab: 'recent'),
  'planOf': AppRoutes.planOf('x', tab: 'list'),
  'dayChatOf': AppRoutes.dayChatOf(draft: 'x'),
  'aiOf': AppRoutes.aiOf(draft: 'x'),
  'aiChatOf': AppRoutes.aiChatOf('x'),
  'kidsSectionOf': AppRoutes.kidsSectionOf('x'),
};

/// The six areas the owner locked out of «مدار الصغار», each as the locations
/// that open it.
final Map<String, List<String>> forbiddenAreas = {
  'health': [
    AppRoutes.planetOf('health'),
    AppRoutes.record,
    AppRoutes.recordOf(tab: 'conditions'),
    AppRoutes.labTestOf('x'),
    AppRoutes.appointments,
    AppRoutes.wellbeing,
    AppRoutes.breathing,
    AppRoutes.healthSettings,
    AppRoutes.body,
    AppRoutes.gymSession,
  ],
  'medication': [
    AppRoutes.meds,
    AppRoutes.medsOf(tab: 'meds'),
    AppRoutes.medsOf(tab: 'courses'),
  ],
  'wallet and money': [
    AppRoutes.planetOf('money'),
    AppRoutes.ledger,
    AppRoutes.walletOf('x'),
    AppRoutes.transactions,
    AppRoutes.currencies,
    AppRoutes.budget,
    AppRoutes.goals,
    AppRoutes.jarOf('x'),
  ],
  'the family planet': [
    AppRoutes.planetOf('family'),
    AppRoutes.family,
    AppRoutes.familyPersonOf('x'),
    AppRoutes.together,
    AppRoutes.togetherHallOfFame,
  ],
  'the chat': [
    AppRoutes.dayChat,
    AppRoutes.dayChatOf(tab: 'summary'),
    AppRoutes.ai,
    AppRoutes.aiChats,
    AppRoutes.aiChatOf('x'),
    AppRoutes.aiSettings,
  ],
  'the work board': [
    AppRoutes.planetOf('work'),
    AppRoutes.work,
    AppRoutes.workBoardOf('x'),
    AppRoutes.workProjects,
    AppRoutes.workProjectOf('x'),
  ],
};

/// The search documents that open each of the six areas.
List<SearchDoc> searchDocsFor(String area) {
  SearchDoc doc(String table, {String id = 'x', String planet = 'health'}) =>
      SearchDoc(
        id: id,
        refTable: table,
        refId: id,
        title: 't',
        planetKey: planet,
      );
  return switch (area) {
    'health' => [
      doc('conditions'),
      doc('lab_tests'),
      doc('health_alerts'),
      doc('appointments'),
      doc('worries'),
    ],
    'medication' => [doc('medications'), doc('med_courses'), doc('med_doses')],
    'wallet and money' => [
      doc('wallets', planet: 'money'),
      doc('jars', planet: 'money'),
      doc('debts', planet: 'money'),
    ],
    'the family planet' => [doc('planets', id: 'family', planet: 'family')],
    'the work board' => [doc('planets', id: 'work', planet: 'work')],
    _ => const [],
  };
}

/// A notification tap for [ns] carrying every key any of the app's taps reads.
RawNotificationTap tapFor(NotificationNamespace ns, {bool launch = false}) =>
    RawNotificationTap(
      id: ns.first,
      fromLaunch: launch,
      payload: NotificationEnvelope.encode(
        NotificationRequest(
          namespace: ns,
          id: ns.first,
          channelId: 'madar.test',
          title: 'T',
          body: '',
          at: kidsNow,
          data: const {
            'set': 'morning',
            'plan': 'p',
            'k': 'dose',
            'doc': 'd',
            'person': 'p',
            'appointment': 'a',
            'id': 'x',
            'module': 'm',
          },
        ),
      ),
    );

class _FakeShareIntake implements ShareIntake {
  _FakeShareIntake({this.launch});

  final SharedPlanPayload? launch;
  final StreamController<SharedPlanPayload> controller =
      StreamController.broadcast();

  @override
  Future<SharedPlanPayload?> takeLaunchShare() async => launch;

  @override
  Stream<SharedPlanPayload> get shares => controller.stream;
}

/// Asserts the app is inside the kids shell and no adult screen is built.
void expectInside(WidgetTester tester, TestApp app, String what) {
  final path = pathOf(app);
  expect(
    path == AppRoutes.kids || path.startsWith('${AppRoutes.kids}/'),
    isTrue,
    reason: '$what -> $path',
  );
  expect(
    find.byType(HomeScreen),
    findsNothing,
    reason: '$what showed the adult home',
  );
  expect(
    find.byType(SettingsScreen),
    findsNothing,
    reason: '$what showed Settings',
  );
  expect(
    _key('kids-home'),
    findsOneWidget,
    reason: '$what: the kids home is not showing',
  );
}

void main() {
  group('the list of routes is complete', () {
    final source = File('lib/core/routing/routes.dart').readAsStringSync();

    test('routesCoverTheFile: every AppRoutes constant and builder is in this suite', () {
      final constants = RegExp(r'static const String (\w+) =')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .where((n) => n != 'beforeOnboarding')
          .toSet();
      final builders = RegExp(r'static String (\w+)\(')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .where((n) => !n.startsWith('_'))
          .toSet();
      expect(constants, isNotEmpty);
      expect(builders, isNotEmpty);
      expect(
        constants.difference(allRoutes.keys.toSet()),
        isEmpty,
        reason: 'a new AppRoutes constant: add it to `allRoutes` so the escape suite tries it',
      );
      expect(
        builders.difference(allBuilders.keys.toSet()),
        isEmpty,
        reason: 'a new AppRoutes builder: add it to `allBuilders` so the escape suite tries it',
      );
      expect(
        allRoutes.keys.toSet().difference(constants),
        isEmpty,
        reason: 'stale entry in allRoutes',
      );
      expect(
        allBuilders.keys.toSet().difference(builders),
        isEmpty,
        reason: 'stale entry in allBuilders',
      );
    });

    test(
      'every location in the lists is a plain location (no pattern left in it)',
      () {
        for (final e in {...allRoutes, ...allBuilders}.entries) {
          expect(e.value.startsWith('/'), isTrue, reason: e.key);
          expect(
            e.value.contains(':'),
            isFalse,
            reason: '${e.key}: ${e.value}',
          );
        }
      },
    );
  });

  group('every route, pushed while kids mode is on', () {
    testWidgets(
      'go: ${allRoutes.length} constants and ${allBuilders.length} builders land inside /kids',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          sections: [testSection('maths')],
        );
        final app = await pumpKids(tester, h);
        for (final e in {...allRoutes, ...allBuilders}.entries) {
          app.router.go(e.value);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'go ${e.key} (${e.value})');
        }
        expect(app.container.read(kidsModeProvider).on, isTrue);
      },
    );

    testWidgets(
      'push: the same, over the stack (and Back still stays inside)',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          sections: [testSection('maths')],
        );
        final app = await pumpKids(tester, h);
        for (final e in {...allRoutes, ...allBuilders}.entries) {
          unawaited(app.router.push<void>(e.value));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'push ${e.key} (${e.value})');
          while (app.router.canPop()) {
            app.router.pop();
            await tester.pump();
          }
        }
        expect(app.container.read(kidsModeProvider).on, isTrue);
      },
    );

    testWidgets(
      'a context.push / SystemNav.to from inside the shell is held too',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        final context = tester.element(_key('kids-home'));
        for (final loc in [
          AppRoutes.ledger,
          AppRoutes.planetOf('health'),
          AppRoutes.meds,
          AppRoutes.search,
        ]) {
          SystemNav.to(context, loc);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'SystemNav.to $loc');
          while (app.router.canPop()) {
            app.router.pop();
            await tester.pump();
          }
        }
      },
    );

    testWidgets(
      'turning kids mode on moves whatever page is open into the shell at once',
      (tester) async {
        final h = await KidsHarness.create();
        final app = await pumpKids(
          tester,
          h,
          initialLocation: AppRoutes.ledger,
        );
        expect(find.byType(HomeScreen), findsNothing);
        expect(_key('kids-home'), findsNothing);
        app.container.read(kidsModeProvider.notifier).enter();
        await tester.pumpAndSettle();
        expectInside(tester, app, 'switching on at /ledger');
      },
    );

    testWidgets(
      'CONTROL: with kids mode OFF the same locations DO open the adult app',
      (tester) async {
        final h = await KidsHarness.create();
        final app = await pumpKids(tester, h);
        for (final loc in [
          AppRoutes.ledger,
          AppRoutes.meds,
          AppRoutes.family,
          AppRoutes.work,
          AppRoutes.dayChat,
        ]) {
          app.router.go(loc);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            pathOf(app),
            Uri.parse(loc).path,
            reason:
                'without kids mode $loc is reachable, so the suite measures something',
          );
        }
        unawaited(app.router.push<void>(AppRoutes.ledger));
        await tester.pump();
        expect(pathOf(app), AppRoutes.ledger);
      },
    );

    testWidgets('with kids mode OFF the shell is closed: /kids goes home', (
      tester,
    ) async {
      final h = await KidsHarness.create();
      final app = await pumpKids(tester, h);
      app.router.go(AppRoutes.kids);
      await tester.pumpAndSettle();
      expect(pathOf(app), '/');
      app.router.go(AppRoutes.kidsSectionOf('x'));
      await tester.pumpAndSettle();
      expect(pathOf(app), '/');
    });
  });

  group('notifications', () {
    testWidgets(
      'a tap for each of the ${NotificationNamespaces.all.length} namespaces lands in the kids home',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        for (final ns in NotificationNamespaces.all) {
          app.notifications.tap(tapFor(ns));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'a ${ns.name} notification');
        }
      },
    );

    testWidgets(
      'CONTROL: with kids mode OFF the same adhkar tap does open its page',
      (tester) async {
        final h = await KidsHarness.create();
        final app = await pumpKids(tester, h);
        app.notifications.tap(tapFor(NotificationNamespaces.adhkar));
        await tester.pumpAndSettle();
        expect(pathOf(app), '/adhkar/morning');
      },
    );

    testWidgets(
      'a notification that arrives while a section is open lands in the kids home',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          sections: [testSection('maths')],
        );
        final app = await pumpKids(tester, h);
        await tester.tap(_key('kids-tile-maths'));
        await tester.pumpAndSettle();
        expect(pathOf(app), '/kids/s/maths');
        app.notifications.tap(tapFor(NotificationNamespaces.adhkar));
        await tester.pumpAndSettle();
        expectInside(tester, app, 'an adhkar tap over a section');
      },
    );

    testWidgets(
      'a notification that LAUNCHED the app (cold start) lands in the kids home',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpMadarApp(
          tester,
          settings: const AppSettings(onboarded: true, lockEnabled: false),
          overrides: h.overrides,
          notifications: FakeNotificationPlatform(
            launch: tapFor(NotificationNamespaces.adhkar, launch: true),
          ),
        );
        await tester.pumpAndSettle();
        expectInside(tester, app, 'a launch notification');
      },
    );

    testWidgets(
      'the location every namespace maps to is held (pure check over the known ones)',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        for (final loc in [
          AppRoutes.adhkarSetOf('morning'),
          AppRoutes.wirdOf('p'),
          AppRoutes.medsOf(tab: 'meds'),
          AppRoutes.appointmentsOf(highlightId: 'a'),
          AppRoutes.wellbeingOf(tab: 'worries'),
          AppRoutes.goalsOf(debt: 'd'),
          AppRoutes.family,
          AppRoutes.familyPersonOf('p'),
          AppRoutes.travelOf(tab: 'documents'),
          AppRoutes.bodyOf(tab: 'fasting'),
          AppRoutes.moduleOf('m'),
          AppRoutes.fasting,
          AppRoutes.prayerTracker,
          AppRoutes.nowPlaying,
        ]) {
          app.router.go(loc);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'notification target $loc');
        }
      },
    );
  });

  group('shares, widgets, deep links, search, restored routes', () {
    testWidgets('a share intent is dropped and the kids home stays', (
      tester,
    ) async {
      final share = _FakeShareIntake();
      addTearDown(share.controller.close);
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, lockEnabled: false),
        overrides: [
          ...h.overrides,
          shareIntakeProvider.overrideWithValue(share),
        ],
      );
      share.controller.add(
        const SharedPlanPayload('{"plan": 1}', name: 'plan.json'),
      );
      await tester.pumpAndSettle();
      expectInside(tester, app, 'a shared plan');
      expect(
        app.container.read(pendingSharedPlanProvider),
        isNull,
        reason: 'not even parked',
      );
    });

    testWidgets(
      'CONTROL: with kids mode OFF the same share does open the import screen',
      (tester) async {
        final share = _FakeShareIntake();
        addTearDown(share.controller.close);
        final h = await KidsHarness.create();
        final app = await pumpMadarApp(
          tester,
          settings: const AppSettings(onboarded: true, lockEnabled: false),
          overrides: [
            ...h.overrides,
            shareIntakeProvider.overrideWithValue(share),
          ],
        );
        share.controller.add(
          const SharedPlanPayload('{"plan": 1}', name: 'plan.json'),
        );
        await tester.pumpAndSettle();
        expect(pathOf(app), AppRoutes.planImport);
      },
    );

    testWidgets('a share that LAUNCHED the app is dropped too', (tester) async {
      final share = _FakeShareIntake(
        launch: const SharedPlanPayload('{"plan": 1}'),
      );
      addTearDown(share.controller.close);
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, lockEnabled: false),
        overrides: [
          ...h.overrides,
          shareIntakeProvider.overrideWithValue(share),
        ],
      );
      await tester.pumpAndSettle();
      expectInside(tester, app, 'a launch share');
      expect(app.container.read(pendingSharedPlanProvider), isNull);
    });

    testWidgets('a home-screen widget link lands in the kids home', (
      tester,
    ) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpKids(tester, h);
      for (final loc in [
        AppRoutes.meds,
        AppRoutes.ledger,
        AppRoutes.prayerTimes,
        AppRoutes.dayChat,
        AppRoutes.work,
      ]) {
        app.container.read(widgetOpenLocationProvider)(loc);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expectInside(tester, app, 'widget link $loc');
      }
    });

    testWidgets(
      'a platform deep link (an intent with a location) lands in the kids home',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        for (final loc in [
          '/meds',
          '/ledger/wallet/x',
          '/planet/health',
          '/family',
          '/day',
        ]) {
          await app.router.routeInformationProvider.didPushRouteInformation(
            RouteInformation(uri: Uri.parse(loc)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'deep link $loc');
        }
      },
    );

    testWidgets(
      'a restored route (the app comes back at a deep location) lands in the kids home',
      (tester) async {
        for (final loc in [
          '/settings/security',
          '/ledger',
          '/planet/money',
          '/day',
          '/kids/../settings',
        ]) {
          final h = await KidsHarness.create(initial: KidsHarness.on());
          final app = await pumpKids(tester, h, initialLocation: loc);
          expectInside(tester, app, 'restored $loc');
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('the app killed and relaunched', () {
    testWidgets('kids mode ON survives: the relaunch lands INSIDE the shell', (
      tester,
    ) async {
      final h = await KidsHarness.create();
      var app = await pumpKids(tester, h, initialLocation: AppRoutes.settings);
      app.container.read(kidsModeProvider.notifier).enter();
      await tester.pumpAndSettle();
      expect(h.store.state.on, isTrue);
      // Killed: the whole app goes; only the storage stays.
      await tester.pumpWidget(const SizedBox());
      app = await pumpKids(tester, h);
      expectInside(tester, app, 'relaunch');
      expect(
        _key('kids-pin-offer'),
        findsNothing,
        reason: 'the offer is for the entry only',
      );
    });

    testWidgets(
      'relaunch, kill and relaunch again, many times: never the adult app',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        for (var i = 0; i < 4; i++) {
          final app = await pumpKids(
            tester,
            h,
            initialLocation: i.isEven ? '/' : AppRoutes.ledger,
          );
          expectInside(tester, app, 'relaunch $i');
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'leaving is also remembered: after the PIN a relaunch opens the adult app',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '2580');
        await tester.pumpAndSettle();
        await tester.tap(_key('kids-corner-leave'));
        await tester.pumpAndSettle();
        expect(pathOf(app), '/');
        await tester.pumpWidget(const SizedBox());
        final again = await pumpKids(tester, h);
        expect(pathOf(again), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'recents: leaving and returning many times never opens the adult app',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h, lockEnabled: true);
        for (var i = 0; i < 4; i++) {
          leaveForeground(tester);
          await tester.pump();
          h.clock.advance(const Duration(minutes: 10));
          returnToForeground(tester);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expectInside(tester, app, 'resume $i');
        }
        expect(find.byType(LockScreen), findsNothing);
      },
    );
  });

  group('the system Back', () {
    testWidgets('pressed over and over (a held Back) never leaves the shell', (
      tester,
    ) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        sections: [testSection('maths')],
      );
      final app = await pumpKids(tester, h);
      for (var i = 0; i < 30; i++) {
        expect(
          await tester.binding.handlePopRoute(),
          isTrue,
          reason: 'Back $i was not consumed by the shell',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          pathOf(app).startsWith('/kids'),
          isTrue,
          reason: 'Back $i left: ${pathOf(app)}',
        );
      }
      expect(app.container.read(kidsModeProvider).on, isTrue);
    });

    testWidgets(
      'Back inside a section, then at the root, then again: up, gate, close, gate...',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          sections: [testSection('maths')],
        );
        final app = await pumpKids(tester, h);
        await tester.tap(_key('kids-tile-maths'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(pathOf(app), '/kids');
        expect(_key('kids-parent-gate'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('kids-parent-gate'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('kids-parent-gate'), findsNothing);
      },
    );

    testWidgets('Back at the root with the app lock armed still never leaves', (
      tester,
    ) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        biometrics: true,
      );
      final app = await pumpKids(tester, h, lockEnabled: true);
      for (var i = 0; i < 6; i++) {
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
      }
      expectInside(tester, app, 'Back with the lock armed');
    });
  });

  group('the app lock and the kids gate', () {
    testWidgets(
      'relaunch with the lock armed: no lock screen, no fingerprint prompt, the kids home',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          biometrics: true,
        );
        final app = await pumpKids(tester, h, lockEnabled: true);
        expect(find.byType(LockScreen), findsNothing);
        expect(
          h.lock.bio.prompts,
          isEmpty,
          reason: 'the astrolabe must not even start a prompt',
        );
        expectInside(tester, app, 'cold start with an armed lock');
      },
    );

    testWidgets(
      'the kids PIN does not leave the adult app exposed or double-locked',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h, lockEnabled: true);
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '2580');
        await tester.pumpAndSettle();
        await tester.tap(_key('kids-corner-leave'));
        await tester.pumpAndSettle();
        expect(
          find.byType(LockScreen),
          findsNothing,
          reason: 'the owner just proved himself',
        );
        expect(pathOf(app), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(app.container.read(kidsModeProvider).on, isFalse);
      },
    );
  });

  group('the six locked-out areas', () {
    for (final area in forbiddenAreas.keys) {
      testWidgets(
        '$area: unreachable by route, push, deep link, widget link, notification and search',
        (tester) async {
          final h = await KidsHarness.create(initial: KidsHarness.on());
          final app = await pumpKids(tester, h);
          for (final loc in forbiddenAreas[area]!) {
            app.router.go(loc);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expectInside(tester, app, '$area: go $loc');

            unawaited(app.router.push<void>(loc));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expectInside(tester, app, '$area: push $loc');
            while (app.router.canPop()) {
              app.router.pop();
              await tester.pump();
            }

            await app.router.routeInformationProvider.didPushRouteInformation(
              RouteInformation(uri: Uri.parse(loc)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expectInside(tester, app, '$area: deep link $loc');

            app.container.read(widgetOpenLocationProvider)(loc);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expectInside(tester, app, '$area: widget $loc');
          }
          // A notification tap of every namespace (their targets are in the lists).
          for (final ns in NotificationNamespaces.all) {
            app.notifications.tap(tapFor(ns));
            await tester.pump();
            expectInside(tester, app, '$area: ${ns.name} notification');
          }
          // A search result that would open the area.
          final context = tester.element(_key('kids-home'));
          for (final doc in searchDocsFor(area)) {
            final target = searchTargetOf(doc);
            expect(target, isNotNull, reason: '${doc.refTable} has a target');
            SystemNav.to(context, target!);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expectInside(
              tester,
              app,
              '$area: search ${doc.refTable} -> $target',
            );
            while (app.router.canPop()) {
              app.router.pop();
              await tester.pump();
            }
          }
        },
      );
    }

    testWidgets(
      'and nothing of them is visible on the kids home or in its corner',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          sections: [testSection('maths', label: 'الحساب')],
        );
        await pumpKids(tester, h);
        // The only tiles are the registered sections; no adult world is offered.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('kids-tile-'),
          ),
          findsOneWidget,
        );
        for (final word in [
          'الصحة',
          'الدواء',
          'المال',
          'العائلة',
          'المحادثة',
          'العمل',
          'الإعدادات',
          'Health',
          'Money',
          'Family',
          'Work',
          'Settings',
        ]) {
          expect(find.textContaining(word), findsNothing, reason: word);
        }
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '2580');
        await tester.pumpAndSettle();
        for (final word in [
          'الصحة',
          'الدواء',
          'المال',
          'العائلة',
          'المحادثة',
          'Health',
          'Money',
          'Family',
        ]) {
          expect(
            find.textContaining(word),
            findsNothing,
            reason: 'in the corner: $word',
          );
        }
      },
    );
  });

  group('the gate is the only way out', () {
    testWidgets(
      'wrong PINs and a cancelled fingerprint never leave; the PIN does; the fingerprint does',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          biometrics: true,
        );
        h.lock.bio.fallback = BiometricOutcome.cancelled;
        final app = await pumpKids(tester, h);
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '0000');
        await typeKidsPin(tester, '1234');
        await tester.tap(_key('kids-key-fingerprint'));
        await tester.pumpAndSettle();
        expect(_key('kids-parent-corner'), findsNothing);
        expect(app.container.read(kidsModeProvider).on, isTrue);
        expectInside(tester, app, 'failed attempts');

        // The fingerprint, once it is a real one.
        h.lock.bio.fallback = BiometricOutcome.success;
        await tester.tap(_key('kids-key-fingerprint'));
        await tester.pumpAndSettle();
        expect(_key('kids-parent-corner'), findsOneWidget);
        await tester.tap(_key('kids-corner-leave'));
        await tester.pumpAndSettle();
        expect(pathOf(app), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'the 4-digit PIN is checked against the app lock\'s own PIN, not a copy',
      (tester) async {
        final h = await KidsHarness.create(
          initial: KidsHarness.on(),
          pin: '7391',
        );
        await pumpKids(tester, h);
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '2580');
        expect(_key('kids-parent-corner'), findsNothing);
        await typeKidsPin(tester, '7391');
        await tester.pumpAndSettle();
        expect(_key('kids-parent-corner'), findsOneWidget);
      },
    );

    testWidgets(
      'the lock state is untouched by a wrong kids PIN except through its own back-off',
      (tester) async {
        final h = await KidsHarness.create(initial: KidsHarness.on());
        final app = await pumpKids(tester, h);
        await tester.tap(_key('kids-lock'));
        await tester.pumpAndSettle();
        await typeKidsPin(tester, '1111');
        expect(
          app.container.read(lockControllerProvider).failures,
          1,
          reason: 'the app lock counts it as well',
        );
      },
    );
  });
}
