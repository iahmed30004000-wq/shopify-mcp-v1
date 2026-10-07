// PROBE (Life UX finder; art director + accessibility lens). The five Life
// worlds' planet pages (Work, Family, Travel, Growth, Body) inside the real
// app, in Arabic and English across Lapis, Pearl and Aurora, with every
// Life package's realistic sample data and with no data at all. Three
// stops down the sheet: the hub's first card, its tools, the world's
// trackers. Writes PNGs to madar/screenshots/probes/life_ux/hubs/ and FAILS
// when painted text misses WCAG AA (rendered pixels; text scrolled under
// the planet is ignored) or the layout overflows.
//
//   scratchpad/ft --tags screenshot test/probes/life_ux_hubs_shots_test.dart --name 'hub work ar'
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
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/body/body.dart' show BodyTodayCard;
import 'package:madar/features/custom_modules/custom_modules.dart' show CustomModulesCard;
import 'package:madar/features/family/family.dart' show FamilyTodayCard;
import 'package:madar/features/growth/growth.dart' show GrowthTodayCard;
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart' show cityDatabaseProvider;
import 'package:madar/features/travel/travel.dart' show TravelTodayCard;
import 'package:madar/features/work/work.dart' show Top3Card;

import '../core/design/rendered_contrast.dart';
import '../features/body/body_harness.dart' show bodyTestNow;
import '../features/body/body_seed.dart';
import '../features/custom_modules/custom_harness.dart' show seedCustom;
import '../features/family/family_seed.dart';
import '../features/growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../features/travel/travel_harness.dart' show seedTravelScenario, travelTestCities, travelTestNow;
import '../features/work/work_harness.dart' as wh;
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

const _dir = 'probes/life_ux/hubs';

typedef _World = ({String key, DateTime now, Type first, Future<void> Function(MadarDatabase db, String lang) seed});

final List<_World> _worlds = [
  (
    key: 'work',
    now: wh.workTestNow,
    first: Top3Card,
    seed: (db, lang) async {
      await wh.seedWork(wh.WorkTestEnv(db, wh.RecordingHaptics(), SilentSoundService(), wh.workTestNow), lang: lang);
      await seedCustom(db, languageCode: lang, now: wh.workTestNow);
    },
  ),
  (
    key: 'family',
    now: familyTestNow,
    first: FamilyTodayCard,
    seed: (db, lang) async {
      await seedFamily(db, arabic: lang == 'ar');
      await seedCustom(db, languageCode: lang, now: familyTestNow);
    },
  ),
  (
    key: 'travel',
    now: travelTestNow,
    first: TravelTodayCard,
    seed: (db, lang) async {
      await seedTravelScenario(db, lang: lang);
      await seedCustom(db, languageCode: lang, now: travelTestNow);
    },
  ),
  (
    key: 'growth',
    now: growthTestNow,
    first: GrowthTodayCard,
    seed: (db, lang) async {
      await seedScenario(db, lang: lang);
      await seedCustom(db, languageCode: lang, now: growthTestNow);
    },
  ),
  (
    key: 'body',
    now: bodyTestNow,
    first: BodyTodayCard,
    seed: (db, lang) async {
      await seedBody(db, BodySeed.full, now: bodyTestNow, arabic: lang == 'ar');
      await seedCustom(db, languageCode: lang, now: bodyTestNow);
    },
  ),
];

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _planetSheet() => find.descendant(
  of: find.byType(PlanetModulePage),
  matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
);

Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 16}) async {
  final scrollable = _planetSheet().first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + 300).clamp(position.minScrollExtent, position.maxScrollExtent));
    await _frames(tester, 2);
  }
  if (target.evaluate().isEmpty) return;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target.first).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

List<Rect> _clippedUnderPlanet(WidgetTester tester) {
  final sheet = _planetSheet();
  if (sheet.evaluate().isEmpty) return const [];
  final top = tester.getTopLeft(sheet.first).dy;
  return [
    for (final e in find.descendant(of: sheet.first, matching: find.byType(RichText)).evaluate())
      if (e.renderObject case final RenderBox box when box.attached && box.hasSize)
        if ((box.localToGlobal(Offset.zero) & box.size) case final rect when rect.top < top - 0.5) rect,
  ];
}

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

Future<void> _hub(WidgetTester tester, _World w, String lang, MadarThemeId theme, {required bool seeded}) async {
  final l = lookupL10n(Locale(lang));
  await preloadOrbitShaders(tester);
  final db = await openTestDatabase(tester, languageCode: lang);
  if (seeded) await tester.runAsync(() => w.seed(db, lang));
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: AppRoutes.planetOf(w.key),
    now: w.now,
    database: false,
    overrides: [
      databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)),
      ...LockFixture.empty().overrides,
      cityDatabaseProvider.overrideWith((ref) async => travelTestCities()),
    ],
  );
  final name = '$_dir/${w.key}_${seeded ? 'seeded' : 'empty'}_${lang}_${theme.name}';
  final boundary = GlobalKey();
  final misses = <String>[];
  final overflows = <String>[];
  Future<void> measure(String where) async {
    final clipped = _clippedUnderPlanet(tester);
    for (final r in await measureRenderedContrast(tester, boundary)) {
      if (r.passes || r.icon || !_readable.hasMatch(r.text)) continue;
      if (clipped.any((c) => c.inflate(1).contains(r.rect.center))) continue;
      misses.add('$where $r');
    }
    final e = tester.takeException();
    if (e != null) overflows.add('$where $e');
  }

  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    name,
    settle: const Duration(milliseconds: 1400),
    beforeCapture: (tester) async {
      await _sheetTo(tester, find.byType(w.first));
      await _frames(tester, 8);
      await measure('cards');
    },
    trailingFrames: 2,
  );
  await _sheetTo(tester, find.text(l.lifeHubToolsTitle));
  await measure('tools');
  await _save(tester, boundary, '${name}_tools');
  await _sheetTo(tester, find.byType(CustomModulesCard));
  await measure('modules');
  await _save(tester, boundary, '${name}_modules');
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
  final report = [...overflows, ...misses];
  if (report.isNotEmpty) {
    // ignore: avoid_print
    print('FAIL $name:\n  ${report.join('\n  ')}');
  }
  expect(report, isEmpty, reason: '$name: text below WCAG AA or a layout overflow');
}

void main() {
  const themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
  for (final w in _worlds) {
    for (final lang in ['ar', 'en']) {
      for (final theme in themes) {
        for (final seeded in [true, false]) {
          testWidgets(
            'hub ${w.key} $lang ${theme.name} ${seeded ? 'seeded' : 'empty'}',
            (tester) => _hub(tester, w, lang, theme, seeded: seeded),
          );
        }
      }
    }
  }
}
