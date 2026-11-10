import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'star_field.dart';

/// The procedural star sprite atlas (no image files): three white cells
/// of [StarSpriteLayout.cell]² premultiplied pixels –
///  0: a crisp core in a soft halo (most stars),
///  1: the same with four thin diffraction spikes (bright stars),
///  2: eight spikes, the diagonals shorter and fainter (the brightest).
/// Stars are tinted per instance through `drawRawAtlas` colours
/// (`BlendMode.modulate`) and added to the sky with `BlendMode.plus`.
abstract final class StarSprite {
  static const int width = StarSpriteLayout.cell * StarSpriteLayout.cells;
  static const int height = StarSpriteLayout.cell;

  /// Intensity 0..1 of cell [kind] at cell-relative position (u, v) in
  /// [-1, 1]².
  static double intensity(int kind, double u, double v) {
    final r = math.sqrt(u * u + v * v);
    final core = math.exp(-math.pow(r / 0.12, 2));
    final halo = 0.36 * math.exp(-math.pow(r / 0.26, 2)) + 0.1 * math.exp(-r / 0.34);
    var spikes = 0.0;
    if (kind >= StarSpriteLayout.spikes4) {
      double spike(double along, double across, double length, double width) =>
          math.exp(-math.pow(across / width, 2)) * math.exp(-along.abs() / length);
      spikes += 0.62 * (spike(u, v, 0.26, 0.018) + spike(v, u, 0.26, 0.018));
      if (kind == StarSpriteLayout.spikes8) {
        const s = math.sqrt1_2;
        final a = (u + v) * s, b = (u - v) * s;
        spikes += 0.3 * (spike(a, b, 0.16, 0.016) + spike(b, a, 0.16, 0.016));
      }
    }
    // Fade to exactly zero at the cell edge (no clipped square corners).
    final edge = 1 - _smooth(0.78, 0.98, r);
    final edgeAxis = 1 - _smooth(0.86, 0.99, math.max(u.abs(), v.abs()));
    return ((core + halo + spikes) * edge * edgeAxis).clamp(0.0, 1.0);
  }

  /// Premultiplied RGBA pixels of the whole atlas.
  static Uint8List pixels() {
    const c = StarSpriteLayout.cell;
    final out = Uint8List(width * height * 4);
    for (var k = 0; k < StarSpriteLayout.cells; k++) {
      for (var y = 0; y < c; y++) {
        final v = (y + 0.5 - c / 2) / (c / 2);
        for (var x = 0; x < c; x++) {
          final u = (x + 0.5 - c / 2) / (c / 2);
          final i = (intensity(k, u, v) * 255).round();
          final o = (y * width + k * c + x) * 4;
          out[o] = i;
          out[o + 1] = i;
          out[o + 2] = i;
          out[o + 3] = i;
        }
      }
    }
    return out;
  }

  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  /// The shared GPU atlas (created once).
  static ui.Image? get imageOrNull => _image;

  static Future<ui.Image> image() {
    final cached = _image;
    if (cached != null) return Future.value(cached);
    return _pending ??= _create().then((img) => _image = img);
  }

  static Future<ui.Image> _create() {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels(), width, height, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
