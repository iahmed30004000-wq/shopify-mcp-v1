// Every Life route screen with the packages' realistic sample data (the
// settings accessibility_test only opens the six top-level Life screens
// with no data) and every Life world's planet hub, in Arabic and English,
// scrolled end to end with real fonts:
// * each tappable is at least 48×48 dp (Android) and carries a label;
// * no tappable reads the same line twice (a custom label plus the merged
//   text it describes);
// * at 1.3× text nothing overflows.
// Fails with the offending semantics nodes (rect, label, actions).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/custom_modules/custom_modules.dart' show ModuleTemplateKey;
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart' show cityDatabaseProvider;

import '../body/body_harness.dart' show bodyTestNow;
import '../body/body_seed.dart';
import '../custom_modules/custom_harness.dart' show customTestNow, seedCustom;
import '../family/family_seed.dart';
import '../growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../lock/lock_test_utils.dart';
import '../travel/travel_harness.dart' show seedTravelScenario, travelTestCities, travelTestNow;
import '../work/work_harness.dart' as wh;
import '../../helpers/screenshot_harness.dart' show loadMadarFonts;
import '../../helpers/test_app.dart';

typedef _Case = ({String name, DateTime now, Future<String> Function(MadarDatabase db, String lang) seed});

Future<wh.WorkSeed> _work(MadarDatabase db, String lang) =>
    wh.seedWork(wh.WorkTestEnv(db, wh.RecordingHaptics(), SilentSoundService(), wh.workTestNow), lang: lang);

Future<void> _allLife(MadarDatabase db, String lang) async {
  await _work(db, lang);
  await seedFamily(db, arabic: lang == 'ar');
  await seedTravelScenario(db, lang: lang);
  await seedScenario(db, lang: lang);
  await seedBody(db, BodySeed.full, now: bodyTestNow, arabic: lang == 'ar');
  await seedCustom(db, languageCode: lang);
}

final List<_Case> _routes = [
  (name: 'work', now: wh.workTestNow, seed: (db, lang) async => (await _work(db, lang), AppRoutes.work).$2),
  (
    name: 'work_board',
    now: wh.workTestNow,
    seed: (db, lang) async => AppRoutes.workBoardOf((await _work(db, lang)).store.id),
  ),
  (
    name: 'work_projects',
    now: wh.workTestNow,
    seed: (db, lang) async => (await _work(db, lang), AppRoutes.workProjects).$2,
  ),
  (
    name: 'work_project',
    now: wh.workTestNow,
    seed: (db, lang) async => AppRoutes.workProjectOf((await _work(db, lang)).project.id),
  ),
  (
    name: 'family',
    now: familyTestNow,
    seed: (db, lang) async => (await seedFamily(db, arabic: lang == 'ar'), AppRoutes.family).$2,
  ),
  (
    name: 'family_person',
    now: familyTestNow,
    seed: (db, lang) async => AppRoutes.familyPersonOf((await seedFamily(db, arabic: lang == 'ar'))['mother']!.id),
  ),
  for (final tab in ['trips', 'documents', 'templates'])
    (
      name: tab == 'trips' ? 'travel' : 'travel_$tab',
      now: travelTestNow,
      seed: (db, lang) async => (await seedTravelScenario(db, lang: lang), AppRoutes.travelOf(tab: tab)).$2,
    ),
  (
    name: 'travel_trip',
    now: travelTestNow,
    seed: (db, lang) async => AppRoutes.travelTripOf((await seedTravelScenario(db, lang: lang)).istanbul),
  ),
  (
    name: 'travel_template',
    now: travelTestNow,
    seed: (db, lang) async => AppRoutes.travelTemplateOf((await seedTravelScenario(db, lang: lang)).essentials),
  ),
  (
    name: 'growth',
    now: growthTestNow,
    seed: (db, lang) async => (await seedScenario(db, lang: lang), AppRoutes.growth).$2,
  ),
  (
    name: 'growth_goal',
    now: growthTestNow,
    seed: (db, lang) async => AppRoutes.growthGoalOf((await seedScenario(db, lang: lang)).book.id),
  ),
  for (final tab in ['today', 'plan', 'fasting', 'water', 'avoid'])
    (
      name: tab == 'today' ? 'body' : 'body_$tab',
      now: bodyTestNow,
      seed: (db, lang) async {
        await seedBody(db, BodySeed.full, now: bodyTestNow, arabic: lang == 'ar');
        return AppRoutes.bodyOf(tab: tab);
      },
    ),
  (
    name: 'modules',
    now: customTestNow,
    seed: (db, lang) async => (await seedCustom(db, languageCode: lang), AppRoutes.modules).$2,
  ),
  (
    name: 'modules_module',
    now: customTestNow,
    seed: (db, lang) async =>
        AppRoutes.moduleOf((await seedCustom(db, languageCode: lang))[ModuleTemplateKey.dailyHabit]!),
  ),
];

final List<_Case> _hubs = [
  for (final (key, now) in [
    ('work', wh.workTestNow),
    ('family', familyTestNow),
    ('travel', travelTestNow),
    ('growth', growthTestNow),
    ('body', bodyTestNow),
  ])
    (
      name: 'hub_$key',
      now: now,
      seed: (db, lang) async {
        await _allLife(db, lang);
        return AppRoutes.planetOf(key);
      },
    ),
];

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The largest downward scrollable of the current route.
ScrollableState? _mainScrollable(WidgetTester tester, {bool planet = false}) {
  ScrollableState? best;
  var bestArea = 0.0;
  final Iterable<Element> candidates = planet
      ? find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).evaluate()
      : find.byType(Scrollable).evaluate();
  for (final e in candidates) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.axisDirection != AxisDirection.down) continue;
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final area = box.size.width * box.size.height;
    if (area > bestArea) {
      bestArea = area;
      best = s;
    }
  }
  return best;
}

/// Tappable semantics nodes whose label says the same line twice (a custom
/// label plus the merged text it describes): a screen reader reads it twice.
List<String> _echoedLabels(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final tappable = data.hasAction(SemanticsAction.tap) || data.hasAction(SemanticsAction.longPress);
    if (tappable && !node.isMergedIntoParent) {
      final lines = [
        for (final line in data.label.split('\n'))
          if (line.replaceAll(RegExp('[\u2066-\u2069]'), '').trim() case final l when l.isNotEmpty) l,
      ];
      if (lines.toSet().length < lines.length) out.add('[label read twice] "${data.label.replaceAll('\n', ' | ')}"');
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return out;
}

Future<void> _probe(
  WidgetTester tester,
  _Case c,
  String lang, {
  bool planet = false,
  double textScale = 1,
  bool labels = false,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final handle = textScale == 1 || labels ? tester.ensureSemantics() : null;
  usePhoneSurface(tester);
  final db = await openTestDatabase(tester, languageCode: lang);
  final location = (await tester.runAsync(() => c.seed(db, lang)))!;
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: location,
    now: c.now,
    database: false,
    overrides: [
      databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)),
      ...LockFixture.empty().overrides,
      cityDatabaseProvider.overrideWith((ref) async => travelTestCities()),
    ],
  );
  await tester.pumpWidget(setup.app);
  await _frames(tester, 40);
  final problems = <String>{};
  final scroll = _mainScrollable(tester, planet: planet);
  for (var step = 0; step < 16; step++) {
    if (labels) {
      problems.addAll(_echoedLabels(tester));
    } else if (textScale == 1) {
      for (final g in [androidTapTargetGuideline, labeledTapTargetGuideline]) {
        final r = await g.evaluate(tester);
        if (!r.passed) {
          problems.addAll(
            r.reason!.split('\n').where((s) => s.startsWith('SemanticsNode')).map((s) => '[${g.description}] $s'),
          );
        }
      }
    }
    final e = tester.takeException();
    if (e != null) problems.add('EXCEPTION at scroll ${scroll?.position.pixels}: $e');
    if (scroll == null) break;
    final p = scroll.position;
    if (p.pixels >= p.maxScrollExtent - 1) break;
    p.jumpTo(math.min(p.pixels + 420, p.maxScrollExtent));
    await _frames(tester, 12);
  }
  handle?.dispose();
  // Unmount before any expectation: a failure with the app still mounted
  // leaves the database's teardown waiting forever.
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
  if (problems.isNotEmpty) {
    // ignore: avoid_print
    print('FAIL ${c.name} $lang x$textScale:\n  ${problems.join('\n  ')}');
  }
  expect(problems, isEmpty);
}

void main() {
  setUpAll(loadMadarFonts);
  for (final lang in ['ar', 'en']) {
    for (final c in _routes) {
      testWidgets('a11y route ${c.name} $lang: 48dp + labels', (tester) => _probe(tester, c, lang));
      testWidgets('a11y route ${c.name} $lang: x1.3 no overflow', (tester) => _probe(tester, c, lang, textScale: 1.3));
    }
    for (final c in _hubs) {
      testWidgets('a11y ${c.name} $lang: 48dp + labels', (tester) => _probe(tester, c, lang, planet: true));
    }
    for (final c in [..._routes, ..._hubs]) {
      testWidgets(
        'a11y labels ${c.name} $lang: each said once',
        (tester) => _probe(tester, c, lang, planet: c.name.startsWith('hub_'), labels: true),
      );
    }
  }
}
