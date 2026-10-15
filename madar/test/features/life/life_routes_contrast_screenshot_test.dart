// Life UX sweep (art director + accessibility lens; from the Life UX
// finder's probe). Renders every
// Life route screen inside the real app (router, AppGate, lock, real fonts
// and shaders) in Arabic and English across Lapis, Pearl and Aurora, with
// the packages' realistic sample data and with no data at all; writes PNGs
// to madar/screenshots/phase6/ux/routes/ and FAILS when a painted text
// misses WCAG AA contrast (rendered pixels, not declared tokens) or the
// layout overflows. Each screen is shot at the top and one page further
// down (`_p2`).
//
//   scratchpad/ft --tags screenshot test/features/life/life_routes_contrast_screenshot_test.dart --plain-name 'route work'
@Tags(['screenshot'])
@Timeout(Duration(minutes: 60))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/custom_modules/custom_modules.dart' show ModuleTemplateKey;
import 'package:madar/features/prayer/prayer.dart' show cityDatabaseProvider;

import '../../core/design/rendered_contrast.dart';
import '../body/body_harness.dart' show bodyTestNow;
import '../body/body_seed.dart';
import '../custom_modules/custom_harness.dart' show customTestNow, seedCustom;
import '../family/family_seed.dart';
import '../growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../travel/travel_harness.dart' show seedTravelScenario, travelTestCities, travelTestNow;
import '../work/work_harness.dart' as wh;
import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';

const _dir = 'phase6/ux/routes';

/// A route of a Life world: its name, the package's sample "now", and a
/// seed that fills the database and returns the location to open.
typedef _Route = ({String name, DateTime now, Future<String> Function(MadarDatabase db, String lang) seed});

Future<wh.WorkSeed> _work(MadarDatabase db, String lang) =>
    wh.seedWork(wh.WorkTestEnv(db, wh.RecordingHaptics(), SilentSoundService(), wh.workTestNow), lang: lang);

final List<_Route> _routes = [
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
  (
    name: 'travel',
    now: travelTestNow,
    seed: (db, lang) async => (await seedTravelScenario(db, lang: lang), AppRoutes.travel).$2,
  ),
  (
    name: 'travel_documents',
    now: travelTestNow,
    seed: (db, lang) async => (await seedTravelScenario(db, lang: lang), AppRoutes.travelOf(tab: 'documents')).$2,
  ),
  (
    name: 'travel_templates',
    now: travelTestNow,
    seed: (db, lang) async => (await seedTravelScenario(db, lang: lang), AppRoutes.travelOf(tab: 'templates')).$2,
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

/// The list screens, opened with no data at all (their empty states).
const List<String> _emptyRoutes = [
  AppRoutes.work,
  AppRoutes.workProjects,
  AppRoutes.family,
  AppRoutes.travel,
  '/travel?tab=documents',
  '/travel?tab=templates',
  AppRoutes.growth,
  AppRoutes.body,
  '/body?tab=plan',
  '/body?tab=fasting',
  '/body?tab=water',
  '/body?tab=avoid',
  AppRoutes.modules,
];

String _emptyName(String loc) => loc.substring(1).replaceAll('?tab=', '_').replaceAll('/', '_');

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Text worth measuring (a separator is a few anti-aliased pixels).
final RegExp _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);

Future<void> _save(WidgetTester tester, GlobalKey boundary, String name) async {
  await tester.runAsync(() async {
    final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 2.625);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// The route's main vertical scrollable (the largest one on screen).
ScrollableState? _mainScrollable(WidgetTester tester) {
  ScrollableState? best;
  var bestArea = 0.0;
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.axisDirection != AxisDirection.down) continue;
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final area = box.size.width * box.size.height;
    if (area > bestArea) {
      bestArea = area;
      best = s;
    }
  }
  return best;
}

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required String lang,
  required MadarThemeId theme,
  required DateTime now,
  required Future<String> Function(MadarDatabase db) seed,
  double textScale = 1,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await preloadOrbitShaders(tester);
  // The location is known only once the data is seeded (ids are random):
  // open and seed the database first, then start the app on that location.
  final db = await openTestDatabase(tester, languageCode: lang);
  final location = (await tester.runAsync(() => seed(db)))!;
  final rebuilt = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: location,
    now: now,
    database: false,
    overrides: [
      databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)),
      ...LockFixture.empty().overrides,
      cityDatabaseProvider.overrideWith((ref) async => travelTestCities()),
    ],
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  final file = '$_dir/${name}_${lang}_${theme.name}$suffix';
  final boundary = GlobalKey();
  final misses = <String>[];
  final icons = <String>[];
  Future<void> measure(String where) async {
    for (final r in await measureRenderedContrast(tester, boundary)) {
      if (r.passes || !_readable.hasMatch(r.text) && !r.icon) continue;
      (r.icon ? icons : misses).add('$where $r');
    }
  }

  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: rebuilt.app),
    file,
    settle: const Duration(milliseconds: 1600),
    beforeCapture: (tester) async {
      await _frames(tester, 10);
      await measure('top');
    },
    trailingFrames: 2,
  );
  final overflowTop = tester.takeException();
  // One page further down.
  final scroll = _mainScrollable(tester);
  Object? overflowDown;
  if (scroll != null && scroll.position.maxScrollExtent > 40) {
    scroll.position.jumpTo((scroll.position.pixels + 640).clamp(0, scroll.position.maxScrollExtent));
    await _frames(tester, 16);
    await measure('p2');
    await _save(tester, boundary, '${file}_p2');
    overflowDown = tester.takeException();
  }
  // Unmount before any expectation (see the a11y probe).
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
  final report = [
    if (overflowTop != null) 'OVERFLOW top: $overflowTop',
    if (overflowDown != null) 'OVERFLOW p2: $overflowDown',
    ...misses,
  ];
  if (icons.isNotEmpty) {
    // ignore: avoid_print
    print('ICON CONTRAST $file:\n  ${icons.join('\n  ')}');
  }
  if (report.isNotEmpty) {
    // ignore: avoid_print
    print('FAIL $file:\n  ${report.join('\n  ')}');
  }
  expect(report, isEmpty, reason: '$file: text below WCAG AA or a layout overflow');
}

void main() {
  const themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
  for (final r in _routes) {
    for (final lang in ['ar', 'en']) {
      for (final theme in themes) {
        testWidgets('route ${r.name} $lang ${theme.name} seeded', (tester) async {
          await _shot(tester, name: r.name, lang: lang, theme: theme, now: r.now, seed: (db) => r.seed(db, lang));
        });
      }
      testWidgets('route ${r.name} $lang x1.3 seeded', (tester) async {
        await _shot(
          tester,
          name: r.name,
          lang: lang,
          theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
          now: r.now,
          seed: (db) => r.seed(db, lang),
          textScale: 1.3,
        );
      });
    }
  }
  for (final loc in _emptyRoutes) {
    for (final lang in ['ar', 'en']) {
      for (final theme in themes) {
        testWidgets('empty ${_emptyName(loc)} $lang ${theme.name}', (tester) async {
          await _shot(
            tester,
            name: 'empty_${_emptyName(loc)}',
            lang: lang,
            theme: theme,
            now: testNow,
            seed: (db) async => loc,
          );
        });
      }
    }
  }
}
