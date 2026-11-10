import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';
import 'package:madar/features/cinema/engine/fx/fx_entry.dart';

const _size = 64;

ui.Image _flat(ui.Color colour) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, _size * 1.0, _size * 1.0), ui.Paint()..color = colour);
  return recorder.endRecording().toImageSync(_size, _size);
}

/// Grades a flat [colour] frame through [fx] and returns the RGBA bytes.
Future<Uint8List> _grade(ReelFilmFx fx, ui.Color colour, {FilmFrame? film, FilmClock? clock}) async {
  final frame = _flat(colour);
  final recorder = ui.PictureRecorder();
  fx.apply(
    ui.Canvas(recorder),
    frame,
    const ui.Rect.fromLTWH(0, 0, _size * 1.0, _size * 1.0),
    clock ?? (FilmClock(seed: 1)..advance(0.25)),
    film ?? FilmFrame(),
  );
  final out = recorder.endRecording().toImageSync(_size, _size);
  final bytes = (await out.toByteData())!.buffer.asUint8List();
  out.dispose();
  frame.dispose();
  return bytes;
}

/// Mean colour of the centre 16×16 (away from the vignette).
(double r, double g, double b) _mean(Uint8List px) {
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  for (var y = 24; y < 40; y++) {
    for (var x = 24; x < 40; x++) {
      final i = (y * _size + x) * 4;
      r += px[i];
      g += px[i + 1];
      b += px[i + 2];
      n++;
    }
  }
  return (r / n / 255, g / n / 255, b / n / 255);
}

ReelFilmFx _fx(Era era, {FilmLook? look}) =>
    ReelFilmFx(CinemaEnv(skin: EraSkins.of(era), seed: 3), quality: FilmQuality.full, look: look, adaptive: false);

void main() {
  setUpAll(() async {
    await CinemaShaders.preload();
    await FxShaders.preload();
  });

  test('the standard kit gets the real film stock, ready once its programs load', () async {
    for (final era in Era.values) {
      final fx = createFilmFx(CinemaEnv(skin: EraSkins.of(era)));
      expect(fx, isA<ReelFilmFx>());
      expect(fx.isReady, isFalse, reason: 'nothing loaded yet: CinemaGame draws ungraded');
      await fx.load();
      expect(fx.isReady, isTrue, reason: era.name);
      fx.dispose();
      expect(fx.isReady, isFalse);
    }
  });

  test('createFilmFx starts every game at the player\'s film settings', () {
    addTearDown(() => FilmSettings.current = const FilmSettings());
    final env = CinemaEnv(skin: EraSkins.of(Era.noir));
    final auto = createFilmFx(env) as ReelFilmFx;
    expect(auto.quality, FilmQuality.balanced);
    expect(auto.strength, 1);

    FilmSettings.current = const FilmSettings(batterySaver: true, strength: 0.5);
    final saver = createFilmFx(env) as ReelFilmFx;
    expect(saver.quality, FilmQuality.lowPower);
    expect(saver.adaptive, isFalse);
    expect(saver.strength, 0.5);

    FilmSettings.current = const FilmSettings(quality: FilmQuality.full, strength: 3);
    final full = createFilmFx(env) as ReelFilmFx;
    expect(full.quality, FilmQuality.full);
    expect(full.adaptive, isFalse, reason: 'a fixed choice is respected');
    expect(full.strength, 1, reason: 'clamped');
    expect(FilmSettings.current.copyWith(clearQuality: true), const FilmSettings(strength: 3));
    for (final fx in [auto, saver, full]) {
      fx.dispose();
    }
  });

  test('film eras grade with film_stock, the 1980s with vhs, and nothing loaded means a plain blit', () async {
    for (final era in Era.values) {
      final fx = _fx(era);
      await fx.load();
      await _grade(fx, const ui.Color(0xFF808080));
      expect(fx.lastPass, era == Era.vhs ? FilmPass.vhs : FilmPass.stock, reason: era.name);
      fx.dispose();
    }
    final unloaded = _fx(Era.silent);
    await _grade(unloaded, const ui.Color(0xFF808080));
    expect(unloaded.lastPass, FilmPass.blit);
  });

  test('monochrome stocks map grey onto their dyes: sepia silent, neutral ink-and-paper 1930s', () async {
    final silent = _fx(Era.silent, look: FilmLook.clean);
    await silent.load();
    final (sr, sg, sb) = _mean(await _grade(silent, const ui.Color(0xFF9A9A9A)));
    expect(sr, greaterThan(sg));
    expect(sg, greaterThan(sb));
    expect(sr - sb, greaterThan(0.08), reason: 'silent grey must read as sepia');

    final hose = _fx(Era.rubberHose, look: FilmLook.clean);
    await hose.load();
    final (hr, hg, hb) = _mean(await _grade(hose, const ui.Color(0xFF9A9A9A)));
    expect((hr - hb).abs(), lessThan(0.08), reason: '1930s grey stays (warm) neutral');
    expect((hr - hg).abs(), lessThan(0.05));
  });

  test('Technicolor saturates, the grindhouse print fades warm', () async {
    const red = ui.Color(0xFFB04040);
    final tech = _fx(Era.technicolor);
    await tech.load();
    final (tr, tg, tb) = _mean(await _grade(tech, red));
    final techSat = tr - (tg + tb) / 2;
    expect(techSat, greaterThan(0.69 - 0.25 + 0.05), reason: 'three-strip dyes push the red');

    final grind = _fx(Era.grindhouse);
    await grind.load();
    final (gr, _, gb) = _mean(await _grade(grind, const ui.Color(0xFF808080)));
    expect(gr, greaterThan(gb + 0.05), reason: 'a faded print is warm');
  });

  test('flash goes to paper, fade goes to ink', () async {
    final fx = _fx(Era.rubberHose, look: FilmLook.clean);
    await fx.load();
    final (fr, _, _) = _mean(await _grade(fx, const ui.Color(0xFF303030), film: FilmFrame()..flash = 1));
    expect(fr, greaterThan(0.85));
    final (dr, _, _) = _mean(await _grade(fx, const ui.Color(0xFFD0D0D0), film: FilmFrame()..fade = 1));
    expect(dr, lessThan(0.1));
  });

  test('reduced motion: no exposure flicker between film frames', () async {
    // Grain, dust and scratches off, so only the exposure can move.
    final skin = EraSkins.of(Era.silent).copyWith(
      grade: const FilmGrade(projectionFps: 18, saturation: 0, grain: 0, dust: 0, scratches: 0, flicker: 0.7, gateWeave: 0),
    );
    final fx = ReelFilmFx(CinemaEnv(skin: skin, seed: 3), quality: FilmQuality.full, look: FilmLook.clean, adaptive: false);
    await fx.load();
    Future<double> lumaAt(double t, {required bool reduced}) async {
      final clock = FilmClock(projectionFps: 18, seed: 1)..advance(t);
      final (r, g, b) = _mean(
        await _grade(fx, const ui.Color(0xFF909090), clock: clock, film: FilmFrame()..reduceFlicker = reduced),
      );
      return (r + g + b) / 3;
    }

    final flick = <double>[];
    final calm = <double>[];
    for (var i = 0; i < 8; i++) {
      flick.add(await lumaAt(i / 18 + 0.01, reduced: false));
      calm.add(await lumaAt(i / 18 + 0.01, reduced: true));
    }
    double spread(List<double> v) => v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);
    expect(spread(flick), greaterThan(0.03), reason: 'the silent projector flickers');
    expect(spread(calm), lessThan(0.01), reason: 'reduced motion steadies it');
  });

  test('quality drives the resolution; an explicit scale wins until quality changes', () {
    final fx = _fx(Era.noir);
    expect(fx.resolutionScale, FilmQuality.full.resolutionScale);
    fx.quality = FilmQuality.lowPower;
    expect(fx.resolutionScale, FilmQuality.lowPower.resolutionScale);
    fx.resolutionScale = 0.7;
    expect(fx.resolutionScale, 0.7);
    fx.quality = FilmQuality.balanced;
    expect(fx.resolutionScale, FilmQuality.balanced.resolutionScale);
    expect(FilmQuality.full.cheaper, FilmQuality.balanced);
    expect(FilmQuality.lowPower.cheaper, FilmQuality.lowPower);
  });

  test('adaptive LOD steps down after sustained slow frames, never on a smooth run', () {
    final clock = FilmClock();
    final smooth = ReelFilmFx(CinemaEnv(skin: EraSkins.of(Era.noir)), quality: FilmQuality.full, adaptive: true);
    for (var i = 0; i < 60 * 12; i++) {
      clock.advance(1 / 60);
      smooth.update(1 / 60, clock);
    }
    expect(smooth.quality, FilmQuality.full);

    final slow = ReelFilmFx(CinemaEnv(skin: EraSkins.of(Era.noir)), quality: FilmQuality.full, adaptive: true);
    for (var i = 0; i < 30 * 6; i++) {
      clock.advance(1 / 30);
      slow.update(1 / 30, clock);
    }
    expect(slow.quality, FilmQuality.balanced);
    for (var i = 0; i < 30 * 8; i++) {
      clock.advance(1 / 30);
      slow.update(1 / 30, clock);
    }
    expect(slow.quality, FilmQuality.lowPower);
  });

  test('strength 0 leaves a clean print: no reel events', () {
    final fx = ReelFilmFx(CinemaEnv(skin: EraSkins.of(Era.grindhouse)), strength: 0, adaptive: false);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final frame = _flat(const ui.Color(0xFF808080));
    final clock = FilmClock();
    for (var i = 0; i < 60 * 30; i++) {
      clock.advance(1 / 60);
      fx.update(1 / 60, clock);
      if (i % 30 == 0) fx.apply(canvas, frame, const ui.Rect.fromLTWH(0, 0, 64, 64), clock, FilmFrame());
      expect(fx.events.splice + fx.events.frameSlip + fx.events.cue + fx.events.blotch, 0);
    }
    recorder.endRecording().dispose();
    frame.dispose();
  });

  test('every era table is complete and damage-free where it should be', () {
    for (final era in Era.values) {
      final g = EraSkins.of(era).grade;
      expect(g.grain, inInclusiveRange(0, 1), reason: era.name);
      expect(g.vignette, inInclusiveRange(0, 1), reason: era.name);
    }
    final vhs = EraSkins.of(Era.vhs).grade;
    expect(vhs.process, FilmProcess.vhs);
    expect(vhs.dust + vhs.scratches + vhs.gateWeave, 0, reason: 'tape has no film dirt');
    expect(EraSkins.of(Era.silent).grade.projectionFps, 18);
  });
}
