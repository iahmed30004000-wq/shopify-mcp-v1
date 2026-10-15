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

/// Paints [scene] through a [ReelFilmFx] at a fixed film time.
class _Graded extends CustomPainter {
  _Graded(this.fx, this.clock, this.film, this.scene, this.dpr);

  final ReelFilmFx fx;
  final FilmClock clock;
  final FilmFrame film;
  final void Function(Canvas canvas, Size size) scene;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)..scale(dpr * fx.resolutionScale);
    scene(c, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync((size.width * dpr * fx.resolutionScale).ceil(), (size.height * dpr * fx.resolutionScale).ceil());
    picture.dispose();
    fx.apply(canvas, image, Offset.zero & size, clock, film);
    image.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Five film frames side by side, each graded by its own FilmFx (a shader
/// instance's uniforms are shared by all draws in one picture).
class _Strip extends CustomPainter {
  _Strip(this.fxs, this.scene, this.dpr);

  final List<ReelFilmFx> fxs;
  final void Function(Canvas canvas, Size size) scene;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / fxs.length;
    final cell = Size(w - 6, size.height - 6);
    for (var i = 0; i < fxs.length; i++) {
      final fx = fxs[i];
      final clock = FilmClock(projectionFps: 18, seed: 7);
      final t = 3.0 + i / 18;
      for (var s = 0.0; s < t; s += 1 / 60) {
        clock.advance(1 / 60);
        fx.update(1 / 60, clock);
      }
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder)..scale(dpr);
      c.scale(cell.width / 412, cell.height / 915);
      scene(c, const Size(412, 915));
      final picture = recorder.endRecording();
      final image = picture.toImageSync((cell.width * dpr).ceil(), (cell.height * dpr).ceil());
      picture.dispose();
      fx.apply(canvas, image, Rect.fromLTWH(i * w + 3, 3, cell.width, cell.height), clock, FilmFrame());
      image.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Raw material swatches: one row per era (halftone sphere, crosshatched
/// sphere, a dry-brush ink stroke, a paper card).
class _Materials extends CustomPainter {
  final ShaderPool _ht = ShaderPool(CinemaShader.halftone);
  final ShaderPool _ch = ShaderPool(CinemaShader.crosshatch);
  final ShaderPool _ink = ShaderPool(CinemaShader.inkLine);
  final ShaderPool _paper = ShaderPool(CinemaShader.paper);

  @override
  void paint(Canvas canvas, Size size) {
    final clock = FilmClock()..advance(0.5);
    final rowH = size.height / Era.values.length;
    final colW = size.width / 4;
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final era in Era.values) {
      final skin = EraSkins.of(era);
      final pal = skin.palette;
      final y0 = era.index * rowH;
      canvas.drawRect(Rect.fromLTWH(0, y0, size.width, rowH), fill..color = pal.paper);
      final r = rowH * 0.36;
      for (var k = 0; k < 2; k++) {
        final c = Offset(colW * (k + 0.5), y0 + rowH / 2);
        canvas.drawCircle(c, r, fill..color = pal.midtone);
        final s = (k == 0 ? _ht : _ch).next(clock)!;
        if (k == 0) {
          HalftoneUniforms.write(s, from: c - Offset(r * 0.4, r * 0.4), to: c + Offset(r * 0.9, r * 0.9), ink: pal.ink, style: skin.halftone, toneFrom: -0.2, toneTo: 1, radial: true);
        } else {
          CrosshatchUniforms.write(s, from: c - Offset(r * 0.4, r * 0.4), to: c + Offset(r * 0.9, r * 0.9), ink: pal.ink, style: skin.hatch, toneFrom: -0.2, toneTo: 1, radial: true);
        }
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)))
          ..drawRect(Rect.fromCircle(center: c, radius: r), Paint()..shader = s)
          ..restore()
          ..drawCircle(c, r, stroke..color = pal.ink);
      }
      final ink = _ink.next(clock)!;
      InkLineUniforms.write(ink, ink: pal.ink, dryness: skin.ink.dryness + 0.25, seed: era.index * 3.0);
      final brush = Path();
      BoilPen(amplitude: 0.6)
        ..begin(brush, 1)
        ..brush(Offset(colW * 2.1, y0 + rowH * 0.75), Offset(colW * 2.5, y0 + rowH * 0.05), Offset(colW * 2.9, y0 + rowH * 0.7), 16, taper: 0.8);
      canvas.drawPath(brush, Paint()..shader = ink);
      final card = Rect.fromLTWH(colW * 3.08, y0 + rowH * 0.1, colW * 0.84, rowH * 0.8);
      final paper = _paper.next(clock)!;
      PaperUniforms.write(paper, rect: card, paper: pal.paper, stain: pal.shadow, age: 0.6, seed: era.index.toDouble());
      canvas
        ..drawRect(card, Paint()..shader = paper)
        ..drawRect(card, stroke..color = pal.ink);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders [scene] (or the calibration card) through the era's film look.
Future<void> _shot(
  WidgetTester tester,
  Era era,
  String name, {
  double time = 2.37,
  FilmQuality quality = FilmQuality.full,
  bool reduced = false,
  double intensity = 1,
  void Function(ReelFilmFx fx, FilmClock clock)? setup,
  void Function(Canvas canvas, Size size, FilmClock clock, L10n ar, L10n en)? scene,
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
  final ar = await L10n.delegate.load(const Locale('ar'));
  final en = await L10n.delegate.load(const Locale('en'));
  final card = FilmTestCardPainter(
    title: ar.cinemaFxTestCard,
    subtitle: 'CALIBRATION · ${era.name.toUpperCase()}',
    caption: era.label(ar),
  );
  await captureScreen(
    tester,
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LayoutBuilder(
        builder: (context, _) => CustomPaint(
          painter: _Graded(
            fx,
            clock,
            film,
            scene == null ? card.paint : (c, size) => scene(c, size, clock, ar, en),
            MediaQuery.devicePixelRatioOf(context),
          ),
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

Future<void> _card(
  WidgetTester tester,
  Era era,
  String name, {
  FilmQuality quality = FilmQuality.full,
  bool reduced = false,
  double intensity = 1,
  void Function(ReelFilmFx fx, FilmClock clock)? setup,
}) => _shot(tester, era, name, quality: quality, reduced: reduced, intensity: intensity, setup: setup);

/// One bilingual intertitle per era (Arabic headline, English line).
IntertitleCard _intertitleFor(Era era, L10n ar, L10n en) => switch (era) {
  Era.silent => IntertitleCard(text: ar.cinemaMetropolisTitle, subtitle: en.cinemaMetropolisTitle),
  Era.rubberHose => IntertitleCard(text: ar.cinemaFlappyOrbitTitle, subtitle: en.cinemaFlappyOrbitTitle),
  Era.noir => IntertitleCard(text: ar.cinemaNoirTitle, subtitle: en.cinemaNoirTitle, kind: IntertitleKind.chapter),
  Era.technicolor => IntertitleCard(text: ar.cinemaCaravanTitle, subtitle: en.cinemaCaravanTitle),
  Era.grindhouse => IntertitleCard(text: ar.cinemaGameOver, subtitle: en.cinemaGameOver, kind: IntertitleKind.gameOver),
  Era.vhs => IntertitleCard(text: ar.cinemaNeonSoukTitle, subtitle: en.cinemaNeonSoukTitle),
};

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

  group('intertitles', () {
    for (final era in Era.values) {
      testWidgets('intertitle – ${era.name}', (tester) async {
        final painter = IntertitlePainter(skin: EraSkins.of(era));
        await _shot(
          tester,
          era,
          'intertitle_${era.name}',
          scene: (canvas, size, clock, ar, en) => painter.paint(canvas, Offset.zero & size, _intertitleFor(era, ar, en), clock),
        );
      });
    }
  });

  group('transitions', () {
    const shots = [
      (Era.silent, IrisShape.heart),
      (Era.rubberHose, IrisShape.circle),
      (Era.noir, IrisShape.keyhole),
      (Era.technicolor, IrisShape.star),
    ];
    for (final (era, shape) in shots) {
      testWidgets('iris – ${era.name} ${shape.name}', (tester) async {
        final iris = IrisPainter(skin: EraSkins.of(era));
        final card = FilmTestCardPainter(title: 'مدار', subtitle: 'IRIS · ${shape.name.toUpperCase()}');
        await _shot(
          tester,
          era,
          'iris_${era.name}_${shape.name}',
          scene: (canvas, size, clock, ar, en) {
            card.paint(canvas, size);
            iris.paint(canvas, Offset.zero & size, 0.32, clock, shape: shape, focus: Offset(size.width / 2, size.height * 0.43));
          },
        );
      });
    }
    testWidgets('burn – grindhouse', (tester) async {
      final burn = BurnPainter(skin: EraSkins.of(Era.grindhouse));
      final card = FilmTestCardPainter(title: 'مدار', subtitle: 'BURN');
      await _shot(
        tester,
        Era.grindhouse,
        'burn_grindhouse',
        scene: (canvas, size, clock, ar, en) {
          card.paint(canvas, size);
          burn.paint(canvas, Offset.zero & size, 0.42, clock, seed: 2);
        },
      );
    });
    testWidgets('leader – silent', (tester) async {
      final leader = LeaderPainter(skin: EraSkins.of(Era.silent));
      await _shot(
        tester,
        Era.silent,
        'leader_silent',
        scene: (canvas, size, clock, ar, en) => leader.paint(canvas, Offset.zero & size, '٣', 0.36, caption: reelCaption(ar, '١')),
      );
    });
  });

  testWidgets('filmstrip – five consecutive silent film frames (grain, weave, flicker, dust)', (tester) async {
    final skin = EraSkins.of(Era.silent);
    final fxs = [for (var i = 0; i < 5; i++) ReelFilmFx(CinemaEnv(skin: skin, seed: 7), quality: FilmQuality.full)];
    for (final fx in fxs) {
      await fx.load();
    }
    final ar = await L10n.delegate.load(const Locale('ar'));
    final card = FilmTestCardPainter(title: ar.cinemaFxTestCard, subtitle: 'FRAMES');
    await captureScreen(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LayoutBuilder(
          builder: (context, _) => CustomPaint(
            painter: _Strip(fxs, card.paint, MediaQuery.devicePixelRatioOf(context)),
            size: Size.infinite,
          ),
        ),
      ),
      'cinema/fx/filmstrip_silent',
      logicalSize: const Size(1100, 480),
      dpr: 1.5,
      settle: const Duration(milliseconds: 100),
      trailingFrames: 0,
    );
    for (final fx in fxs) {
      fx.dispose();
    }
  });

  testWidgets('materials – halftone, crosshatch, ink line and paper per era (raw)', (tester) async {
    await captureScreen(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CustomPaint(painter: _Materials(), size: Size.infinite),
      ),
      'cinema/fx/materials',
      logicalSize: const Size(640, 960),
      dpr: 2,
      settle: const Duration(milliseconds: 100),
      trailingFrames: 0,
    );
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
