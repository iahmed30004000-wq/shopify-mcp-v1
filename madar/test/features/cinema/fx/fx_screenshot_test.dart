@Tags(['screenshot'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';
import 'package:madar/features/cinema/games/demo/demo_screen.dart';

import '../../../helpers/screenshot_harness.dart';

// The FX agent's visual checks (screenshots/cinema/fx/*.png): every era's
// film stock on a still calibration card and on the live demo scene, the
// reel events, reduced motion / low power, and the intertitle cards.
// LOOK at them after every FX change.

/// Paints the calibration card through a [ReelFilmFx] at a fixed film time.
class _GradedCard extends CustomPainter {
  _GradedCard(this.fx, this.clock, this.film, this.card, this.dpr);

  final ReelFilmFx fx;
  final FilmClock clock;
  final FilmFrame film;
  final FilmTestCardPainter card;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)..scale(dpr * fx.resolutionScale);
    card.paint(c, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync((size.width * dpr * fx.resolutionScale).ceil(), (size.height * dpr * fx.resolutionScale).ceil());
    picture.dispose();
    fx.apply(canvas, image, Offset.zero & size, clock, film);
    image.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Future<void> _card(
  WidgetTester tester,
  Era era,
  String name, {
  double time = 2.37,
  FilmQuality quality = FilmQuality.full,
  bool reduced = false,
  double intensity = 1,
  void Function(ReelFilmFx fx, FilmClock clock)? setup,
}) async {
  final skin = EraSkins.of(era);
  final fx = ReelFilmFx(CinemaEnv(skin: skin, seed: 7), quality: quality);
  await fx.load();
  final clock = FilmClock(projectionFps: skin.grade.projectionFps, boilFps: skin.ink.boilFps, seed: 7);
  // Run the projector up to [time] so events and weave are mid-reel.
  const dt = 1 / 60;
  for (var t = 0.0; t < time; t += dt) {
    clock.advance(dt);
    fx.update(dt, clock);
  }
  setup?.call(fx, clock);
  final film = FilmFrame()
    ..reduceFlicker = reduced
    ..intensity = intensity;
  final l10n = await L10n.delegate.load(const Locale('ar'));
  final card = FilmTestCardPainter(
    title: l10n.cinemaFxTestCard,
    subtitle: 'CALIBRATION · ${era.name.toUpperCase()}',
    caption: era.label(l10n),
  );
  await captureScreen(
    tester,
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LayoutBuilder(
        builder: (context, _) => CustomPaint(
          painter: _GradedCard(fx, clock, film, card, MediaQuery.devicePixelRatioOf(context)),
          size: Size.infinite,
        ),
      ),
    ),
    'cinema/fx/$name',
    settle: const Duration(milliseconds: 100),
    trailingFrames: 0,
  );
  fx.dispose();
}

void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
    await FxShaders.preload();
  });

  group('still card', () {
    for (final era in Era.values) {
      testWidgets('card – ${era.name}', (tester) => _card(tester, era, 'card_${era.name}'));
    }
    testWidgets('card – grindhouse reel change (cue mark, splice, hair)', (tester) async {
      await _card(
        tester,
        Era.grindhouse,
        'card_grindhouse_reel_change',
        setup: (fx, clock) {
          fx.events
            ..cueNow()
            ..spliceNow(y: 0.62, slip: 0.18)
            ..hair = 1
            ..hairX = 0
            ..hairY = 0.3
            ..hairAngle = 0.3;
        },
      );
    });
    testWidgets('card – silent, reduced motion + low power', (tester) async {
      await _card(tester, Era.silent, 'card_silent_reduced_lowpower', reduced: true, quality: FilmQuality.lowPower);
    });
    testWidgets('card – noir at half intensity', (tester) async {
      await _card(tester, Era.noir, 'card_noir_half', intensity: 0.5);
    });
  });

  group('demo scene', () {
    for (final era in Era.values) {
      testWidgets('demo – ${era.name}', (tester) async {
        await captureScreen(
          tester,
          ProviderScope(
            child: madarScreenshotApp(
              home: CinemaDemoScreen(initialEra: era, autoplay: true, showEraPicker: false),
            ),
          ),
          'cinema/fx/demo_${era.name}',
          settle: const Duration(milliseconds: 2150),
        );
      });
    }
  });
}
