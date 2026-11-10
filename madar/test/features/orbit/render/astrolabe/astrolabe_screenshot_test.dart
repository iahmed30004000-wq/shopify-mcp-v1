@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'astrolabe_fixtures.dart';

/// Full-bleed backdrop the astrolabe is judged on (the theme's deepest
/// space; the live scene puts the real sky here).
class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.tokens.space0, child: child);
}

/// Renders the astrolabe alone at [logical]² and writes
/// `screenshots/<name>.png`.
Future<void> shoot(
  WidgetTester tester,
  String name, {
  required AstrolabeState state,
  MadarThemeId theme = MadarThemeId.lapis,
  double logical = 400,
  double dpr = 2.5,
  AstrolabeTilt? tilt,
  ValueNotifier<AstrolabeState>? states,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  await tester.runAsync(AstrolabePrograms.load);
  final notifier = states ?? ValueNotifier(state);
  await captureScreen(
    tester,
    madarScreenshotApp(
      theme: theme,
      locale: Locale(state.labels.l10n.localeName),
      home: CelebrationOverlay(
        child: _Stage(
          child: ValueListenableBuilder<AstrolabeState>(
            valueListenable: notifier,
            builder: (context, s, _) => AstrolabeLayer(state: s, tilt: tilt),
          ),
        ),
      ),
    ),
    name,
    logicalSize: Size(logical, logical),
    dpr: dpr,
    settle: settle,
    beforeCapture: beforeCapture,
  );
}

void main() {
  const lit1 = {Prayer.dhuhr};
  const lit3 = {Prayer.fajr, Prayer.dhuhr, Prayer.asr};
  const lit5 = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};
  final dawn = AmmanDay.at(5, 41, 12);
  final noon = AmmanDay.at(13, 7, 5);
  final maghrib = AmmanDay.at(18, 49, 20);
  final night = AmmanDay.at(21, 12, 40);

  group('400', () {
    testWidgets('ar lapis dawn, nothing lit', (tester) async {
      await shoot(tester, 'astrolabe_ar_lapis_dawn_400', state: AmmanDay.state(dawn));
    });
    testWidgets('ar lapis noon, Dhuhr lit, Fajr missed', (tester) async {
      await shoot(tester, 'astrolabe_ar_lapis_noon_400', state: AmmanDay.state(noon, prayed: lit1));
    });
    testWidgets('ar lapis maghrib, three lit', (tester) async {
      await shoot(tester, 'astrolabe_ar_lapis_maghrib_400', state: AmmanDay.state(maghrib, prayed: lit3));
    });
    testWidgets('ar lapis night, five lit', (tester) async {
      await shoot(tester, 'astrolabe_ar_lapis_night_400', state: AmmanDay.state(night, prayed: lit5, balance: 0.95));
    });
    testWidgets('en lapis noon', (tester) async {
      await shoot(
        tester,
        'astrolabe_en_lapis_noon_400',
        state: AmmanDay.state(noon, lang: 'en', prayed: lit1),
      );
    });
    testWidgets('en pearl dawn', (tester) async {
      await shoot(
        tester,
        'astrolabe_en_pearl_dawn_400',
        state: AmmanDay.state(dawn, lang: 'en'),
        theme: MadarThemeId.pearl,
      );
    });
    testWidgets('ar pearl maghrib, three lit', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_pearl_maghrib_400',
        state: AmmanDay.state(maghrib, prayed: lit3),
        theme: MadarThemeId.pearl,
      );
    });
    testWidgets('en pearl night, five lit', (tester) async {
      await shoot(
        tester,
        'astrolabe_en_pearl_night_400',
        state: AmmanDay.state(night, lang: 'en', prayed: lit5, balance: 0.95),
        theme: MadarThemeId.pearl,
      );
    });
    testWidgets('ar pearl noon, neglected (tarnished)', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_pearl_noon_400',
        state: AmmanDay.state(noon, prayed: lit1, balance: 0.3),
        theme: MadarThemeId.pearl,
      );
    });
  });

  group('1200', () {
    testWidgets('ar lapis maghrib', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_lapis_maghrib_1200',
        state: AmmanDay.state(maghrib, prayed: lit3),
        logical: 1200,
        dpr: 1.5,
      );
    });
    testWidgets('en lapis dawn', (tester) async {
      await shoot(
        tester,
        'astrolabe_en_lapis_dawn_1200',
        state: AmmanDay.state(dawn, lang: 'en'),
        logical: 1200,
        dpr: 1.5,
      );
    });
    testWidgets('en pearl night, five lit', (tester) async {
      await shoot(
        tester,
        'astrolabe_en_pearl_night_1200',
        state: AmmanDay.state(night, lang: 'en', prayed: lit5, balance: 0.95),
        theme: MadarThemeId.pearl,
        logical: 1200,
        dpr: 1.5,
      );
    });
    testWidgets('ar pearl noon', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_pearl_noon_1200',
        state: AmmanDay.state(noon, prayed: lit1),
        theme: MadarThemeId.pearl,
        logical: 1200,
        dpr: 1.5,
      );
    });
  });

  group('variants', () {
    testWidgets('tilted by the gyro', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_lapis_tilted_400',
        state: AmmanDay.state(maghrib, prayed: lit3),
        tilt: const AstrolabeTilt(pitch: 0.26, yaw: -0.18),
      );
    });
    testWidgets('home size: lit window arc, fires, cartouches, two-band countdown', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_lapis_home_185',
        state: AmmanDay.state(AmmanDay.at(16, 40, 5), prayed: {Prayer.fajr, Prayer.dhuhr}),
        logical: 185,
        dpr: 2.625,
      );
      await shoot(
        tester,
        'astrolabe_en_pearl_home_185',
        state: AmmanDay.state(AmmanDay.at(12, 30, 0), lang: 'en', prayed: {Prayer.fajr, Prayer.dhuhr}),
        theme: MadarThemeId.pearl,
        logical: 185,
        dpr: 2.625,
      );
    });
    testWidgets('zoomed out: medium and minimal detail', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_lapis_small_150',
        state: AmmanDay.state(maghrib, prayed: lit3),
        logical: 150,
        dpr: 3,
      );
      await shoot(
        tester,
        'astrolabe_ar_lapis_tiny_70',
        state: AmmanDay.state(maghrib, prayed: lit3),
        logical: 70,
        dpr: 3,
      );
    });
    testWidgets('Arabic with Western digits', (tester) async {
      await shoot(
        tester,
        'astrolabe_ar_lapis_western_400',
        state: AmmanDay.state(noon, prayed: lit1, digits: DigitStyle.western),
      );
    });
    testWidgets('Asr igniting after it is logged', (tester) async {
      final before = AmmanDay.state(AmmanDay.at(16, 2, 30), prayed: const {Prayer.fajr, Prayer.dhuhr});
      final states = ValueNotifier(before);
      await shoot(
        tester,
        'astrolabe_ar_lapis_igniting_400',
        state: before,
        states: states,
        beforeCapture: (tester) async {
          states.value = AmmanDay.state(AmmanDay.at(16, 2, 31), prayed: lit3);
          await tester.pump(const Duration(milliseconds: 16));
        },
      );
    });
    testWidgets('battery saver still (same painter, one frame)', (tester) async {
      await tester.runAsync(() async {
        await loadMadarFonts();
        await AstrolabePrograms.load();
        final image = await AstrolabeStill.render(
          state: AmmanDay.state(maghrib, prayed: lit3),
          palette: AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis)),
          size: const Size(400, 400),
          pixelRatio: 2,
          makersMark: AmmanDay.labels('ar').l10n.astrolabeMakersMark,
        );
        try {
          expect(image.width, 800);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('screenshots/astrolabe_ar_lapis_still_400.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    });
    testWidgets('neglected life: tarnished brass, dim star', (tester) async {
      await shoot(tester, 'astrolabe_ar_lapis_neglected_400', state: AmmanDay.state(noon, balance: 0.12));
    });
  });
}
