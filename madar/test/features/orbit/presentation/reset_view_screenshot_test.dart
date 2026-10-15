// "Reset view" on home, rendered for review: the default overview, the view
// after a drag + pinch (and after minutes of orbiting, worlds overlapping),
// and the view after the reset – which must match the default:
//   flutter test --tags screenshot test/features/orbit/presentation/reset_view_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';

import '../../../helpers/test_app.dart';
import '../data/orbit_fixtures.dart';
import 'orbit_scene_fixtures.dart';

const _dir = 'hotfix';

/// How long each state is left to settle before its shot – the same after
/// the start and after the reset, so the two shots are directly comparable
/// (the drift's breath and the orbits run the same time in both).
const _settle = Duration(milliseconds: 2200);

Future<SceneShots> _home(WidgetTester tester, {required MadarThemeId theme, required String lang}) async {
  final now = DateTime(2026, 9, 27, 12, 30);
  final setup = await buildMadarTestApp(
    tester,
    now: now,
    settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang),
    beforePump: (MadarDatabase db) async {
      final r = Repositories(db);
      await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
      await seedLivedIn(r, now: now, thriving: true, arabic: lang == 'ar');
    },
  );
  final shots = SceneShots(tester);
  await shots.start(setup.app, settle: _settle);
  return shots;
}

SceneController _scene(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene)).controller;

Finder _pill(String lang) => find.bySemanticsLabel(lookupL10n(Locale(lang)).orbitUiRecenter);

/// The pill in the live semantics tree (what a screen reader meets).
FinderBase<SemanticsNode> _pillNode(String lang) => find.semantics.byLabel(lookupL10n(Locale(lang)).orbitUiRecenter);

/// A real one-finger drag, then a real two-finger pinch on the dial.
Future<void> _dragAndPinch(WidgetTester tester, SceneShots shots) async {
  final c = _scene(tester);
  final start = Offset(c.viewport.width * 0.2, c.sceneRect.top + 70);
  final g = await tester.startGesture(start);
  for (var i = 0; i < 14; i++) {
    await g.moveBy(const Offset(14, 7));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await shots.frames(const Duration(milliseconds: 500));
  final focal = c.coreCenter;
  final a = await tester.startGesture(focal - const Offset(24, 0));
  final b = await tester.startGesture(focal + const Offset(24, 0));
  for (var i = 1; i <= 12; i++) {
    await a.moveTo(focal - Offset(24 + 3.5 * i, 0));
    await b.moveTo(focal + Offset(24 + 3.5 * i, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await shots.frames(const Duration(milliseconds: 900));
}

/// Where every world sits on screen (centre, radius).
Map<String, (Offset, double)> _discs(SceneController c) => {
  for (final b in c.planets.bodies) b.key: ?c.planetDisc(b.key),
};

void main() {
  for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
    for (final lang in ['ar', 'en']) {
      final tag = '${lang}_${theme.name}';

      testWidgets('default → drag + pinch → reset – $tag', (tester) async {
        final shots = await _home(tester, theme: theme, lang: lang);
        try {
          final c = _scene(tester);
          await shots.snap('$_dir/orbit_1_default_$tag');
          final overview = c.camera;
          final discs = _discs(c);
          // How long the orbits (and the drift) have run since the start.
          final sinceStart = c.planets.secondsSinceHome;
          expect(_pillNode(lang), findsNothing, reason: 'nothing to reset on a fresh start');

          await _dragAndPinch(tester, shots);
          expect(c.rig.isAway, isTrue);
          expect(_pill(lang), findsOneWidget);
          expect(_pillNode(lang), findsOne);
          expect(tester.getSize(_pill(lang)).height, greaterThanOrEqualTo(44));
          await shots.snap('$_dir/orbit_2_dragged_pinched_$tag');

          await tester.tap(_pill(lang));
          final resetAt = c.planets.time;
          await tester.pump();
          await shots.frames(const Duration(milliseconds: 500));
          await shots.snap('$_dir/orbit_3_resetting_$tag');
          // Shoot after exactly as much orbit time since the reset as the
          // default had since the start: the two must then show the same sky.
          for (var i = 0; i < 400 && c.planets.time - resetAt < sinceStart; i++) {
            await tester.pump(const Duration(milliseconds: 8));
          }
          await shots.snap('$_dir/orbit_4_after_reset_$tag');
          expect((c.rig.yaw, c.rig.tilt, c.rig.zoom), (0, 0, 0));
          expect(c.camera.distance, closeTo(overview.distance, 1e-9));
          expect(c.camera.azimuth, closeTo(overview.azimuth, 1e-3));
          expect(c.camera.elevation, closeTo(overview.elevation, 1e-3));
          // Every world where the default shot has it.
          final after = _discs(c);
          expect(after.keys, unorderedEquals(discs.keys));
          for (final e in discs.entries) {
            expect((after[e.key]!.$1 - e.value.$1).distance, lessThan(2), reason: e.key);
            expect(after[e.key]!.$2, closeTo(e.value.$2, 1), reason: e.key);
          }
          expect(_pillNode(lang), findsNothing, reason: 'nothing left to reset');
          expect(c.resetCue, isFalse);
        } finally {
          shots.finish();
        }
      }, timeout: const Timeout(Duration(minutes: 40)));
    }
  }

  for (final (theme, lang) in [(MadarThemeId.lapis, 'ar'), (MadarThemeId.pearl, 'en')]) {
    final tag = '${lang}_${theme.name}';

    testWidgets('worlds drifted into each other → reset – $tag', (tester) async {
      final shots = await _home(tester, theme: theme, lang: lang);
      try {
        final c = _scene(tester);
        for (var s = 0; s < 900 && !c.planets.crowded(c.viewport); s++) {
          c.planets.advanceSeconds(1);
        }
        // A little further in, so the overlap is plain to see.
        c.planets.advanceSeconds(20);
        c.refresh();
        await tester.tap(find.byType(OrbitScene), warnIfMissed: false);
        await shots.frames(const Duration(milliseconds: 1500));
        await shots.snap('$_dir/orbit_5_drifted_$tag');
        await tester.tap(_pill(lang));
        await tester.pump();
        await shots.frames(_settle);
        await shots.snap('$_dir/orbit_6_drifted_after_reset_$tag');
        expect(c.planets.crowded(c.viewport), isFalse);
      } finally {
        shots.finish();
      }
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}
