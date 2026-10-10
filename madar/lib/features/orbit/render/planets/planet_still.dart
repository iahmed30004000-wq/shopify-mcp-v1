import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../orbit_shaders.dart';
import 'planet_painters.dart';
import 'planet_renderer.dart';
import 'planet_scene_controller.dart';

/// Battery saver: the planet layer rendered once into an image with the
/// same painters as the live scene (guides, worlds, moons, labels at their
/// resting opacity). Show it in place of the live layer; re-render only when
/// the snapshot, theme or viewport changes.
abstract final class PlanetStill {
  static Future<ui.Image> render({
    required PlanetSceneController controller,
    required Size size,
    required PlanetLayerStyle style,
    required TextDirection textDirection,
    double pixelRatio = 1,
    bool guides = true,
    bool labels = true,
  }) async {
    final shaders = await OrbitShaders.load();
    final renderer = PlanetRenderer(shaders);
    final labelCache = PlanetLabelCache();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    try {
      if (guides) {
        OrbitGuidesPainter(controller: controller, style: style, cache: OrbitGuideCache()).paint(canvas, size);
      }
      PlanetBodiesPainter(controller: controller, renderer: renderer, retain: false).paint(canvas, size);
      if (labels) {
        PlanetLabelsPainter(
          controller: controller,
          style: style,
          cache: labelCache,
          textDirection: textDirection,
          snap: true,
        ).paint(canvas, size);
      }
      final picture = recorder.endRecording();
      try {
        return await picture.toImage((size.width * pixelRatio).ceil(), (size.height * pixelRatio).ceil());
      } finally {
        picture.dispose();
      }
    } finally {
      renderer.dispose();
      labelCache.clear();
    }
  }
}
