import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'astrolabe_cache.dart';
import 'astrolabe_controller.dart';
import 'astrolabe_geometry.dart';
import 'astrolabe_painter.dart';
import 'astrolabe_palette.dart';
import 'astrolabe_shaders.dart';
import 'astrolabe_state.dart';

/// Renders the astrolabe into an image with the very same painter as the
/// live layer – for battery-saver stills (the scene shows a pre-rendered
/// frame instead of animating) and share cards.
abstract final class AstrolabeStill {
  /// Paints [state] at [size] logical pixels × [pixelRatio]. Uses the loaded
  /// [AstrolabePrograms] when available (gradient fallbacks otherwise);
  /// [time] is the shader clock of the frozen frame.
  static Future<ui.Image> render({
    required AstrolabeState state,
    required AstrolabePalette palette,
    required Size size,
    double pixelRatio = 1,
    AstrolabeTilt tilt = AstrolabeTilt.flat,
    String? makersMark,
    AstrolabePrograms? programs,
    double time = 12,
  }) async {
    final controller = AstrolabeController(state: state, initialTime: time)..tilt = tilt;
    final cache = AstrolabeRenderCache();
    final loaded = programs ?? AstrolabePrograms.instance;
    final shaders = loaded == null ? null : AstrolabeShaderSet(loaded);
    final painter = AstrolabePainter(
      controller: controller,
      palette: palette,
      cache: cache,
      shaders: shaders,
      devicePixelRatio: pixelRatio,
      makersMark: makersMark,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage((size.width * pixelRatio).ceil(), (size.height * pixelRatio).ceil());
    } finally {
      picture.dispose();
      cache.dispose();
      shaders?.dispose();
      controller.dispose();
    }
  }
}
