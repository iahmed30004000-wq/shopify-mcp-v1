import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';

/// The FX agent's own shader contract (film_stock.frag is not a core slot):
/// registered, documented, and its compiled uniform count matches the Dart
/// writer.
void main() {
  late ui.FragmentProgram program;
  late ui.Image image;

  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset(FxShader.filmStock.asset);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
    image = recorder.endRecording().toImageSync(2, 2);
  });

  test('film_stock.frag is registered next to every core slot and documents its layout', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final s in FxShader.values) {
      expect(pubspec, contains('- ${s.asset}'), reason: s.asset);
      final src = File(s.asset).readAsStringSync();
      expect(src, contains('#include "lib/cinema.glsl"'));
      expect(src, contains('#include "lib/film.glsl"'));
      expect(src, contains('Uniforms (float indices'));
      expect(src, contains('Owner: FX agent'));
      expect(src, contains('${s.floats - 4}-${s.floats - 1}'), reason: 'header documents the last vec4');
    }
    for (final s in CinemaShader.values) {
      expect(pubspec, contains('- ${s.asset}'), reason: 'core slot ${s.asset} must stay registered');
    }
  });

  test('film_stock: exactly ${FxShader.filmStock.floats} floats and one sampler', () {
    final shader = program.fragmentShader();
    shader.setFloat(FxShader.filmStock.floats - 1, 0);
    expect(() => shader.setFloat(FxShader.filmStock.floats, 0), throwsRangeError);
    shader.setImageSampler(0, image);
    shader.dispose();
  });

  test('the writer fills exactly the contracted floats for every era', () {
    for (final era in Era.values) {
      final skin = EraSkins.of(era);
      final shader = program.fragmentShader();
      FilmStockUniforms.write(
        shader,
        rect: const ui.Rect.fromLTWH(0, 0, 100, 200),
        image: image,
        clock: FilmClock()..advance(0.5),
        palette: skin.palette,
        grade: skin.grade,
        look: eraLook(era),
        frame: FilmFrame()..kick(flash: 0.5, damage: 0.4),
        events: FilmEvents(seed: 3)..cueNow(),
        mix: FilmMix(),
      );
      expect(FilmStockUniforms.lastWritten, FxShader.filmStock.floats, reason: era.name);
      shader.dispose();
    }
  });

  test('film_grade stays the contract-level fallback and shares the film library', () {
    final src = File(CinemaShader.filmGrade.asset).readAsStringSync();
    expect(src, contains('#include "lib/film.glsl"'));
    expect(File('shaders/cinema/lib/film.glsl').readAsStringSync(), isNot(contains('sampler2D')), reason: 'the library must stay ALU only');
  });
}
