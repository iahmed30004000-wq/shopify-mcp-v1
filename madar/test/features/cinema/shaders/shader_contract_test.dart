import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

/// The uniform contract between the Dart writers (shader_uniforms.dart,
/// CinemaShader.floats/samplers) and the GLSL bodies the FX / stage agents
/// write. Fails when a shader's uniform list drifts from its contract.
void main() {
  late Map<CinemaShader, ui.FragmentProgram> programs;
  late ui.Image image;

  setUpAll(() async {
    programs = {for (final s in CinemaShader.values) s: await ui.FragmentProgram.fromAsset(s.asset)};
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
    image = recorder.endRecording().toImageSync(2, 2);
  });

  test('every slot is registered in pubspec.yaml and documents its uniforms', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final s in CinemaShader.values) {
      expect(pubspec, contains('- ${s.asset}'), reason: s.asset);
      final src = File(s.asset).readAsStringSync();
      expect(src, contains('#include "lib/cinema.glsl"'), reason: s.asset);
      expect(src, contains('Uniforms (float indices'), reason: '${s.asset} header must document the uniform layout');
      expect(src, contains('Owner:'), reason: s.asset);
    }
  });

  for (final s in CinemaShader.values) {
    test('${s.file}: exactly ${s.floats} floats, ${s.samplers} sampler(s)', () {
      final shader = programs[s]!.fragmentShader();
      shader.setFloat(s.floats - 1, 0);
      expect(() => shader.setFloat(s.floats, 0), throwsRangeError);
      for (var i = 0; i < s.samplers; i++) {
        shader.setImageSampler(i, image);
      }
      shader.dispose();
    });
  }

  test('the Dart writers fill exactly the contracted floats', () {
    ui.FragmentShader make(CinemaShader s) => programs[s]!.fragmentShader();
    final skin = EraSkins.of(Era.rubberHose);
    final clock = FilmClock()..advance(0.5);
    const rect = ui.Rect.fromLTWH(0, 0, 100, 200);
    // UniformCursor.end asserts the count in debug (tests run with asserts).
    FilmGradeUniforms.write(
      make(CinemaShader.filmGrade),
      rect: rect,
      image: image,
      clock: clock,
      palette: skin.palette,
      grade: skin.grade,
      frame: FilmFrame(),
    );
    VhsUniforms.write(
      make(CinemaShader.vhs),
      rect: rect,
      image: image,
      clock: clock,
      grade: EraSkins.of(Era.vhs).grade,
      frame: FilmFrame(),
    );
    HalftoneUniforms.write(
      make(CinemaShader.halftone),
      from: ui.Offset.zero,
      to: const ui.Offset(10, 10),
      ink: skin.palette.ink,
      style: skin.halftone,
    );
    CrosshatchUniforms.write(
      make(CinemaShader.crosshatch),
      from: ui.Offset.zero,
      to: const ui.Offset(10, 10),
      ink: skin.palette.ink,
      style: skin.hatch,
    );
    InkLineUniforms.write(make(CinemaShader.inkLine), ink: skin.palette.ink, dryness: 0.2);
    PaperUniforms.write(make(CinemaShader.paper), rect: rect, paper: skin.palette.paper, stain: skin.palette.shadow);
    IrisUniforms.write(make(CinemaShader.iris), rect: rect, centre: rect.center, radius: 40, color: skin.palette.ink);
    BurnUniforms.write(
      make(CinemaShader.burn),
      rect: rect,
      progress: 0.5,
      origin: rect.center,
      edgeColor: skin.palette.footlight,
      holeColor: skin.palette.paper,
    );
    CurtainUniforms.write(
      make(CinemaShader.curtain),
      rect: rect,
      palette: skin.palette,
      panel: CurtainPanel.left,
      clock: clock,
    );
    SpotlightUniforms.write(
      make(CinemaShader.spotlight),
      rect: rect,
      source: ui.Offset.zero,
      target: rect.center,
      color: skin.palette.footlight,
      time: 1,
    );
  });

  test('shader pool reuses instances per tick', () async {
    await CinemaShaders.preload();
    final pool = ShaderPool(CinemaShader.halftone, maxInstances: 3);
    final clock = FilmClock()..advance(0.016);
    final a = pool.next(clock), b = pool.next(clock);
    expect(identical(a, b), isFalse);
    clock.advance(0.016);
    expect(identical(pool.next(clock), a), isTrue, reason: 'new tick restarts the pool');
    expect(pool.allocated, 2);
    pool.dispose();
  });
}
