// Madar Cinema's door on the Growth world's page, in the real app with a
// realistic Growth (learning goals in progress), in Arabic and English on
// every theme. Writes screenshots/cinema/wiring/growth_card_<lang>_<theme>.png
// (the page scrolled to the card) and FAILS when text painted on the card
// misses WCAG AA (rendered pixels) or the layout overflows. LOOK at them.
//
//   scratchpad/ft --tags screenshot test/features/orbit/presentation/cinema_entry_card_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 30))
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/presentation/planet/cinema_entry_card.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../../core/design/rendered_contrast.dart';
import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import '../../growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../../lock/lock_test_utils.dart';
import 'orbit_scene_fixtures.dart' show preloadOrbitShaders;

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _planetSheet() => find.descendant(
  of: find.byType(PlanetModulePage),
  matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
);

/// Scrolls the planet sheet so [target]'s top sits a little below the
/// sheet's top.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 120}) async {
  final scrollable = _planetSheet().first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + 300).clamp(position.minScrollExtent, position.maxScrollExtent));
    await _frames(tester, 2);
  }
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target.first).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

Future<void> _shot(WidgetTester tester, String lang, MadarThemeId theme) async {
  await preloadOrbitShaders(tester);
  final db = await openTestDatabase(tester, languageCode: lang);
  await tester.runAsync(() => seedScenario(db, lang: lang));
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: AppRoutes.planetOf('growth'),
    now: growthTestNow,
    database: false,
    overrides: [databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)), ...LockFixture.empty().overrides],
  );
  final boundary = GlobalKey();
  final misses = <String>[];
  Object? error;
  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    'cinema/wiring/growth_card_${lang}_${theme.name}',
    settle: const Duration(milliseconds: 1400),
    beforeCapture: (tester) async {
      final card = find.byType(CinemaEntryCard);
      await _sheetTo(tester, card);
      // Let the bulbs' one chase finish.
      await _frames(tester, 36);
      final area = tester.getRect(card);
      for (final r in await measureRenderedContrast(tester, boundary)) {
        if (!area.contains(r.rect.center) || r.passes) continue;
        misses.add(r.toString());
      }
      error = tester.takeException();
    },
    trailingFrames: 2,
  );
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
  expect(error, isNull, reason: 'layout overflow or error on the Growth page');
  expect(misses, isEmpty, reason: 'text on the cinema card below WCAG AA ($lang ${theme.name})');
}

void main() {
  for (final (lang, theme) in [
    ('ar', MadarThemeId.lapis),
    ('en', MadarThemeId.lapis),
    ('ar', MadarThemeId.pearl),
    ('en', MadarThemeId.pearl),
    ('ar', MadarThemeId.aurora),
    ('ar', MadarThemeId.emerald),
    ('ar', MadarThemeId.desert),
  ]) {
    testWidgets('growth card $lang ${theme.name}', (tester) => _shot(tester, lang, theme));
  }
}
