// The life worlds' pages (Work, Family, Travel, Growth, Body) carry their
// hubs: the packages' "today" cards and a row of tools, in both languages,
// every card and tool opening its screen as a route. Every world's page
// lists its own trackers (custom worlds included, filtered by world);
// Faith, Health and Money show no empty "create one" prompt and still
// render their own hubs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/family/family.dart';
import 'package:madar/features/growth/growth.dart';
import 'package:madar/features/health/hub/health_hub.dart';
import 'package:madar/features/money/hub/money_hub.dart';
import 'package:madar/features/orbit/data/planet_customization_service.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/life_hubs.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/travel/travel.dart';
import 'package:madar/features/work/work.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<TestApp> _page(
  WidgetTester tester,
  String? planetKey, {
  String lang = 'en',
  Future<void> Function(MadarDatabase db)? seed,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: planetKey == null ? AppRoutes.home : AppRoutes.planetOf(planetKey),
    beforePump: seed,
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

final Finder _sheet = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

/// Scrolls the planet page's sheet until [finder] is built and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _sheet);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// A tool tile of [hub], by its semantics ("title. hint").
Finder _tool(Type hub, String title) =>
    find.descendant(of: find.byType(hub), matching: find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. ')));

ModuleDefinition _tracker(String name, String planetKey) =>
    ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name).copyWith(name: name, planetKey: planetKey);

typedef _Hub = ({
  String key,
  Type hub,
  List<Type> cards,
  List<(String Function(L10n), String)> tools,
  List<(String, void Function(WidgetTester))> opens,
});

/// A hung frame loop fails in minutes, not after the default ten.
void _testWidgets(String description, WidgetTesterCallback body) =>
    testWidgets(description, body, timeout: const Timeout(Duration(minutes: 3)));

void main() {
  test('the hubs cover the five life worlds only', () {
    expect(LifeHubs.keys, {'work', 'family', 'travel', 'growth', 'body'});
    for (final k in LifeHubs.keys) {
      expect(LifeHubs.has(k), isTrue);
    }
    for (final k in ['faith', 'health', 'money', 'custom_0123456789']) {
      expect(LifeHubs.has(k), isFalse);
    }
    expect(LifeHubs.of('work'), isA<WorkHub>());
    expect(LifeHubs.of('family'), isA<FamilyHub>());
    expect(LifeHubs.of('travel'), isA<TravelHub>());
    expect(LifeHubs.of('growth'), isA<GrowthHub>());
    expect(LifeHubs.of('body'), isA<BodyHub>());
  });

  final hubs = <_Hub>[
    (
      key: 'work',
      hub: WorkHub,
      cards: [Top3Card, WorkTodayCard],
      tools: [((l) => l.workBoards, AppRoutes.work), ((l) => l.workProjects, AppRoutes.workProjects)],
      opens: [
        (
          AppRoutes.work,
          (t) => t.widget<WorkTodayCard>(find.byType(WorkTodayCard)).onOpen!(t.element(find.byType(WorkTodayCard))),
        ),
      ],
    ),
    (
      key: 'family',
      hub: FamilyHub,
      cards: [FamilyTodayCard],
      tools: [((l) => l.lifeHubPeople, AppRoutes.family)],
      opens: [
        (
          AppRoutes.family,
          (t) =>
              t.widget<FamilyTodayCard>(find.byType(FamilyTodayCard)).onOpen!(t.element(find.byType(FamilyTodayCard))),
        ),
        (
          '/family/person/p1',
          (t) => t.widget<FamilyTodayCard>(find.byType(FamilyTodayCard)).onOpenPerson!(
            t.element(find.byType(FamilyTodayCard)),
            'p1',
          ),
        ),
      ],
    ),
    (
      key: 'travel',
      hub: TravelHub,
      cards: [TravelTodayCard],
      tools: [
        ((l) => l.travelTabTrips, AppRoutes.travel),
        ((l) => l.travelTabDocuments, '/travel?tab=documents'),
        ((l) => l.travelTabTemplates, '/travel?tab=templates'),
      ],
      opens: [
        (
          AppRoutes.travel,
          (t) =>
              t.widget<TravelTodayCard>(find.byType(TravelTodayCard)).onOpen!(t.element(find.byType(TravelTodayCard))),
        ),
        (
          '/travel/trip/t1',
          (t) => t.widget<TravelTodayCard>(find.byType(TravelTodayCard)).onOpenTrip!(
            t.element(find.byType(TravelTodayCard)),
            't1',
          ),
        ),
      ],
    ),
    (
      key: 'growth',
      hub: GrowthHub,
      cards: [GrowthTodayCard],
      tools: [((l) => l.growthCardOpenAll, AppRoutes.growth), ((l) => l.workProjects, AppRoutes.workProjects)],
      opens: [
        (
          AppRoutes.growth,
          (t) =>
              t.widget<GrowthTodayCard>(find.byType(GrowthTodayCard)).onOpen!(t.element(find.byType(GrowthTodayCard))),
        ),
      ],
    ),
    (
      key: 'body',
      hub: BodyHub,
      cards: [BodyTodayCard, FastingCard, WaterCard],
      tools: [((l) => l.bodyTabPlan, '/body?tab=plan'), ((l) => l.bodyTabAvoid, '/body?tab=avoid')],
      opens: [
        (AppRoutes.body, (t) => t.widget<BodyTodayCard>(find.byType(BodyTodayCard)).onOpen!()),
        ('/body?tab=fasting', (t) => t.widget<FastingCard>(find.byType(FastingCard)).onOpen!()),
        ('/body?tab=water', (t) => t.widget<WaterCard>(find.byType(WaterCard)).onOpen!()),
      ],
    ),
  ];

  for (final lang in ['ar', 'en']) {
    for (final h in hubs) {
      _testWidgets('$lang ${h.key}: the hub\'s cards and tools lead to routes', (tester) async {
        final app = await _page(tester, h.key, lang: lang);
        final l = lookupL10n(Locale(lang));
        expect(find.byType(h.hub), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(h.hub))),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        for (final card in h.cards) {
          await _reveal(tester, find.byType(card));
          expect(find.byType(card), findsOneWidget, reason: '$card');
        }
        // Every world gets its trackers (the empty invitation here).
        await _reveal(tester, find.byType(CustomModulesCard));
        expect(find.text(l.cmodCardEmpty), findsOneWidget);

        for (final (title, location) in h.tools) {
          final tile = _tool(h.hub, title(l));
          await _reveal(tester, tile);
          app.sound.played.clear();
          await tester.tap(tile);
          await settleApp(tester);
          expect(app.router.state.uri.toString(), location, reason: title(l));
          expect(app.sound.played, contains(Sfx.navigate));
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(h.hub), findsOneWidget);
        }
        for (final (location, open) in h.opens) {
          await _reveal(tester, find.byType(h.cards.first));
          open(tester);
          await settleApp(tester);
          expect(app.router.state.uri.toString(), location);
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(h.hub), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }

  _testWidgets("Family's reminders tool opens the reach-out settings sheet", (tester) async {
    final app = await _page(tester, 'family');
    final l = lookupL10n(const Locale('en'));
    final tile = _tool(FamilyHub, l.familyRemindersTitle);
    await _reveal(tester, tile);
    app.sound.played.clear();
    await tester.tap(tile);
    await settleApp(tester);
    expect(find.byType(FamilySettingsSheet), findsOneWidget);
    expect(app.sound.played, contains(Sfx.sheetOpen));
    expect(app.location, AppRoutes.planetOf('family'), reason: 'a sheet, not a page');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(FamilySettingsSheet), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  _testWidgets('a world lists only its own trackers; one opens as its route', (tester) async {
    late String standup;
    final app = await _page(
      tester,
      'work',
      seed: (db) async {
        final modules = CustomModulesService(Repositories(db));
        standup = (await modules.createModule(_tracker('Standup notes', 'work'))).id;
        await modules.createModule(_tracker('Watering', 'family'));
      },
    );
    await _reveal(tester, find.byType(CustomModulesCard));
    final card = find.byType(CustomModulesCard);
    expect(find.descendant(of: card, matching: find.textContaining('Standup notes')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('Watering')), findsNothing);
    await tester.tap(find.descendant(of: card, matching: find.textContaining('Standup notes')));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.moduleOf(standup));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    final l = lookupL10n(const Locale('en'));
    await _reveal(tester, find.byType(CustomModulesCard));
    await tester.tap(find.descendant(of: find.byType(CustomModulesCard), matching: find.text(l.cmodCardSeeAll)));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.modules);
    await tester.pump(const Duration(seconds: 6));
  });

  _testWidgets("a custom world's page lists its trackers (no life hub)", (tester) async {
    late String key;
    final app = await _page(
      tester,
      null,
      seed: (db) async {
        final repos = Repositories(db);
        final (row, _) = await PlanetCustomizationService(repos)
            .addPlanet(name: 'Garden', archetype: PlanetArchetype.values.first);
        key = row.key;
        await CustomModulesService(repos).createModule(_tracker('Watering', key));
      },
    );
    app.router.go(AppRoutes.planetOf(key));
    await _frames(tester, 60);
    await settleApp(tester);
    expect(key, startsWith('custom_'));
    for (final hub in [WorkHub, FamilyHub, TravelHub, GrowthHub, BodyHub]) {
      expect(find.byType(hub), findsNothing);
    }
    await _reveal(tester, find.byType(CustomModulesCard));
    expect(
      find.descendant(of: find.byType(CustomModulesCard), matching: find.textContaining('Watering')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  for (final (key, hub) in [('faith', FaithHub), ('health', HealthHub), ('money', MoneyHub)]) {
    _testWidgets('$key keeps its hub and shows no empty tracker prompt', (tester) async {
      await _page(tester, key);
      expect(find.byType(hub), findsOneWidget);
      expect(find.byType(CustomModulesCard, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  _testWidgets('faith lists a tracker attached to it', (tester) async {
    await _page(
      tester,
      'faith',
      seed: (db) => CustomModulesService(Repositories(db)).createModule(_tracker('Night prayer', 'faith')),
    );
    expect(find.byType(FaithHub), findsOneWidget);
    await _reveal(tester, find.byType(CustomModulesCard));
    expect(
      find.descendant(of: find.byType(CustomModulesCard), matching: find.textContaining('Night prayer')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  });
}
