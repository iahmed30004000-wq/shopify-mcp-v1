import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'book_direction.dart';

/// How the paper looks.
@immutable
class PaperOptions {
  const PaperOptions({
    this.tint = const Color(0xFFF7F0E0),
    this.grainStrength = 0.5,
    this.gutterShade = 0.12,
    this.seed = 7,
  }) : assert(grainStrength >= 0 && grainStrength <= 1),
       assert(gutterShade >= 0 && gutterShade <= 1);

  /// Page colour (the texture is neutral, so any tint works, light or dark).
  final Color tint;

  /// 0 = smooth, 1 = clearly grainy. The fine grain and faint fibres are one
  /// small generated image, so the cost does not depend on the strength.
  final double grainStrength;

  /// Soft darkening towards the spine, like the curve of a bound page.
  final double gutterShade;

  /// Same seed, same paper, on every launch.
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is PaperOptions &&
      other.tint == tint &&
      other.grainStrength == grainStrength &&
      other.gutterShade == gutterShade &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(tint, grainStrength, gutterShade, seed);
}

/// Procedural paper: fine grain plus faint fibres, generated once into a
/// small seamless tile (no asset, no shader file).
class PaperTexture {
  const PaperTexture._();

  /// Tile edge in device pixels.
  static const int tileSize = 256;

  /// RGBA bytes (premultiplied, so the same bytes read right either way) of
  /// the tile. Pure Dart and deterministic: the same [seed] and [strength]
  /// always give the same bytes.
  static Uint8List pixels({required int seed, required double strength, int size = tileSize}) {
    final out = Uint8List(size * size * 4);
    if (strength <= 0) return out;
    final rnd = math.Random(seed);
    // The strongest grain pixel stays under ~12% opacity at full strength.
    final maxAlpha = 255 * 0.12 * strength.clamp(0.0, 1.0);

    for (var i = 0; i < size * size; i++) {
      final r = rnd.nextDouble();
      final o = i * 4;
      if (r < 0.45) {
        // Dark speck (neutral warm grey).
        final a = (rnd.nextDouble() * maxAlpha).round();
        out[o] = (a * 0.28).round();
        out[o + 1] = (a * 0.24).round();
        out[o + 2] = (a * 0.2).round();
        out[o + 3] = a;
      } else if (r < 0.7) {
        // Light speck.
        final a = (rnd.nextDouble() * maxAlpha * 0.7).round();
        out[o] = a;
        out[o + 1] = a;
        out[o + 2] = a;
        out[o + 3] = a;
      }
    }

    // Faint fibres: short curving strokes, wrapped so the tile repeats.
    final fibres = (size * size / 1400).round();
    for (var f = 0; f < fibres; f++) {
      var x = rnd.nextDouble() * size;
      var y = rnd.nextDouble() * size;
      var ang = rnd.nextDouble() * math.pi * 2;
      final len = 8 + rnd.nextInt(22);
      final bend = (rnd.nextDouble() - 0.5) * 0.18;
      final a = (maxAlpha * (0.45 + rnd.nextDouble() * 0.4)).round();
      for (var s = 0; s < len; s++) {
        final px = x.floor() % size, py = y.floor() % size;
        final o = (py * size + px) * 4;
        if (a > out[o + 3]) {
          out[o] = (a * 0.35).round();
          out[o + 1] = (a * 0.28).round();
          out[o + 2] = (a * 0.2).round();
          out[o + 3] = a;
        }
        ang += bend;
        x += math.cos(ang) * 0.8;
        y += math.sin(ang) * 0.8;
        if (x < 0) x += size;
        if (y < 0) y += size;
      }
    }
    return out;
  }

  static final Map<int, Future<ui.Image>> _cache = <int, Future<ui.Image>>{};

  /// The tile as an image, generated once per (seed, strength) and shared.
  static Future<ui.Image> load({required int seed, required double strength}) {
    final key = Object.hash(seed, (strength * 20).round());
    return _cache.putIfAbsent(key, () {
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels(seed: seed, strength: (strength * 20).round() / 20),
        tileSize,
        tileSize,
        ui.PixelFormat.rgba8888,
        c.complete,
      );
      return c.future;
    });
  }

  @visibleForTesting
  static void debugClearCache() => _cache.clear();
}

/// A tiling grain [Paint] for one device pixel ratio: made once, reused by
/// every page painter (a shader per frame would be wasted work).
class GrainPaint {
  GrainPaint(ui.Image tile, double dpr)
    : paint = Paint()
        ..shader = ui.ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          // One tile pixel = one device pixel.
          Float64List.fromList(<double>[1 / dpr, 0, 0, 0, 0, 1 / dpr, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        );

  final Paint paint;

  void dispose() => paint.shader = null;
}

/// Paper look laid over a page: the soft darkening towards the spine and the
/// grain. The page's own colour is a plain box below, so this stays cheap.
class PaperOverlayPainter extends CustomPainter {
  PaperOverlayPainter({required this.grain, required this.gutterShade, required this.gutter});

  final Paint? grain;
  final double gutterShade;

  /// Which edge of this page is the spine (null = none, e.g. a blank page).
  final SpineSide? gutter;

  double _gutterWidth = -1;
  Paint? _gutterPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final g = gutter;
    if (g != null && gutterShade > 0 && size.width > 0) {
      final w = size.width * 0.07;
      if (_gutterPaint == null || w != _gutterWidth) {
        _gutterWidth = w;
        final shade = Color.fromRGBO(0, 0, 0, gutterShade.clamp(0.0, 1.0));
        _gutterPaint = Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), <Color>[shade, shade.withValues(alpha: 0)]);
      }
      canvas.save();
      if (g == SpineSide.right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), _gutterPaint!);
      canvas.restore();
    }
    final gp = grain;
    if (gp != null) canvas.drawRect(Offset.zero & size, gp);
  }

  @override
  bool shouldRepaint(PaperOverlayPainter old) =>
      old.grain != grain || old.gutterShade != gutterShade || old.gutter != gutter;
}

/// One page of paper: tint, the page content, then the paper look on top.
class PaperPage extends StatelessWidget {
  const PaperPage({
    super.key,
    required this.tint,
    required this.grain,
    required this.gutterShade,
    required this.gutter,
    this.child,
  });

  final Color tint;
  final Paint? grain;
  final double gutterShade;
  final SpineSide? gutter;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: tint),
        if (child != null) ClipRect(child: child),
        IgnorePointer(
          child: CustomPaint(
            painter: PaperOverlayPainter(grain: grain, gutterShade: gutterShade, gutter: gutter),
          ),
        ),
      ],
    );
  }
}
