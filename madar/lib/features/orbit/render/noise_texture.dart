import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Procedural noise texture shared by every orbit shader (no image files).
///
/// 256×256 RGBA8 whose content is periodic with period 255: column/row 255
/// duplicates column/row 0, so shaders sampling `mod(cell, 255)` with linear
/// filtering never see a seam even though Flutter samplers clamp to edge.
///
/// Channels: R = white value noise, G = R shifted by (37, 17) (two z-slices for
/// 3D value noise, see shaders/orbit/lib/common.glsl), B = independent white
/// noise for sparkles / star twinkle, A = 255 (opaque, so the engine's
/// premultiplication can never alter the colour channels).
abstract final class NoiseTexture {
  static const size = 256;
  static const period = 255;

  /// Deterministic RGBA bytes (seeded).
  static Uint8List generatePixels({int seed = 0x6D616461}) {
    final rng = math.Random(seed);
    final r = Uint8List(period * period);
    final b = Uint8List(period * period);
    for (var i = 0; i < r.length; i++) {
      r[i] = rng.nextInt(256);
      b[i] = rng.nextInt(256);
    }
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      final py = y % period;
      for (var x = 0; x < size; x++) {
        final px = x % period;
        final o = (y * size + x) * 4;
        out[o] = r[py * period + px];
        final gx = (px - 37) % period;
        final gy = (py - 17) % period;
        out[o + 1] = r[gy * period + gx];
        out[o + 2] = b[py * period + px];
        out[o + 3] = 255;
      }
    }
    return out;
  }

  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  /// The shared GPU image (created once).
  static Future<ui.Image> image() {
    final cached = _image;
    if (cached != null) return Future.value(cached);
    return _pending ??= _create().then((img) {
      _image = img;
      return img;
    });
  }

  static ui.Image? get imageOrNull => _image;

  static Future<ui.Image> _create() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(generatePixels(), size, size, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }
}
