@Tags(['screenshot'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'astrolabe_fixtures.dart';

/// Full-bleed backdrop the astrolabe is judged on (the theme's deepest
/// space; the live scene puts the real sky here).
class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).colorScheme;
    return ColoredBox(color: t.surface, child: child);
  }
}

Future<void> shoot(
  WidgetTester tester,
  String name, {
  required AstrolabeState state,
  MadarThemeId theme = MadarThemeId.lapis,
  double logical = 400,
  double dpr = 2.5,
  AstrolabeTilt? tilt,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  await tester.runAsync(() async {
    await AstrolabePrograms.load();
  });
  await captureScreen(
    tester,
    madarScreenshotApp(
      theme: theme,
      locale: Locale(state.labels.l10n.localeName),
      home: _Stage(child: AstrolabeLayer(state: state, tilt: tilt)),
    ),
    name,
    logicalSize: Size(logical, logical),
    dpr: dpr,
    settle: settle,
  );
}

void main() {
  const lit3 = {Prayer.fajr, Prayer.dhuhr, Prayer.asr};
  const lit5 = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};

  testWidgets('dawn, nothing lit, Arabic, Lapis, 400', (tester) async {
    await shoot(tester, 'astrolabe_ar_lapis_dawn_400', state: AmmanDay.state(AmmanDay.at(5, 41, 12)));
  });

  testWidgets('maghrib, three lit, Arabic, Lapis, 400', (tester) async {
    await shoot(tester, 'astrolabe_ar_lapis_maghrib_400', state: AmmanDay.state(AmmanDay.at(18, 49, 20), prayed: lit3));
  });

  testWidgets('night, five lit, Arabic, Lapis, 1200', (tester) async {
    await shoot(
      tester,
      'astrolabe_ar_lapis_isha_1200',
      state: AmmanDay.state(AmmanDay.at(21, 12, 40), prayed: lit5, balance: 0.95),
      logical: 1200,
      dpr: 1.5,
    );
  });

  testWidgets('noon, fajr missed, English, Pearl, 400', (tester) async {
    await shoot(
      tester,
      'astrolabe_en_pearl_noon_400',
      state: AmmanDay.state(AmmanDay.at(13, 7, 5), lang: 'en', balance: 0.4),
      theme: MadarThemeId.pearl,
    );
  });

  // Keeps ui imported for future image assertions.
  test('noop', () => expect(ui.FilterQuality.low, isNotNull));
}
