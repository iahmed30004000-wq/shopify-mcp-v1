import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'particle_pool.dart';
import 'particle_system.dart';

/// The particle sprite sheet, painted procedurally at start-up (no image
/// assets): white, alpha-shaped sprites that are tinted per particle with
/// `BlendMode.modulate` in `drawRawAtlas`.
class ParticleAtlas implements SpriteRects {
  ParticleAtlas._(this.image, this._rects);

  /// Paints the atlas synchronously (`Picture.toImageSync`).
  factory ParticleAtlas.create() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rects = Float32List(ParticleSprite.values.length * 4);
    void put(ParticleSprite s, ui.Rect r) {
      final o = s.index * 4;
      rects[o] = r.left;
      rects[o + 1] = r.top;
      rects[o + 2] = r.right;
      rects[o + 3] = r.bottom;
    }

    const glow = ui.Rect.fromLTWH(0, 0, 64, 64);
    const sparkle = ui.Rect.fromLTWH(68, 0, 64, 64);
    const streak = ui.Rect.fromLTWH(136, 0, 16, 96);
    const ember = ui.Rect.fromLTWH(156, 0, 32, 32);
    _paintGlow(canvas, glow);
    _paintSparkle(canvas, sparkle);
    _paintStreak(canvas, streak);
    _paintEmber(canvas, ember);
    put(ParticleSprite.glow, glow);
    put(ParticleSprite.sparkle, sparkle);
    put(ParticleSprite.streak, streak);
    put(ParticleSprite.ember, ember);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return ParticleAtlas._(image, rects);
  }

  static const int width = 192;
  static const int height = 96;

  final ui.Image image;
  final Float32List _rects;

  @override
  double left(int sprite) => _rects[sprite * 4];
  @override
  double top(int sprite) => _rects[sprite * 4 + 1];
  @override
  double right(int sprite) => _rects[sprite * 4 + 2];
  @override
  double bottom(int sprite) => _rects[sprite * 4 + 3];
  @override
  double spriteWidth(int sprite) => right(sprite) - left(sprite);
  @override
  double spriteHeight(int sprite) => bottom(sprite) - top(sprite);

  bool _disposed = false;
  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image.dispose();
  }

  // Sprites are pure-white alpha masks; the per-particle colour (from theme
  // tokens) tints them at draw time.
  static const _white = ui.Color(0xFFFFFFFF);
  static ui.Color _w(double a) => _white.withValues(alpha: a);

  static void _paintGlow(ui.Canvas canvas, ui.Rect r) {
    final c = r.center;
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(
        c,
        r.width / 2,
        [_w(1), _w(0.62), _w(0.24), _w(0.07), _w(0)],
        const [0, 0.16, 0.42, 0.7, 1],
      );
    canvas.drawCircle(c, r.width / 2, paint);
  }

  static void _paintSparkle(ui.Canvas canvas, ui.Rect r) {
    final c = r.center;
    final half = r.width / 2;
    // Halo.
    canvas.drawCircle(
      c,
      half * 0.62,
      ui.Paint()..shader = ui.Gradient.radial(c, half * 0.62, [_w(0.55), _w(0.12), _w(0)], const [0, 0.45, 1]),
    );
    // Four rays: long horizontal/vertical, short diagonals.
    void ray(double angle, double length, double thickness, double a) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final rect = ui.Rect.fromCenter(center: ui.Offset.zero, width: length, height: thickness);
      canvas.drawOval(
        rect,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            ui.Offset(-length / 2, 0),
            ui.Offset(length / 2, 0),
            [_w(0), _w(a), _w(0)],
            const [0, 0.5, 1],
          )
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.8),
      );
      canvas.restore();
    }

    ray(0, r.width * 0.98, 3.2, 1);
    ray(math.pi / 2, r.height * 0.98, 3.2, 1);
    ray(math.pi / 4, r.width * 0.5, 2.2, 0.6);
    ray(-math.pi / 4, r.width * 0.5, 2.2, 0.6);
    // Hot core.
    canvas.drawCircle(
      c,
      half * 0.16,
      ui.Paint()..shader = ui.Gradient.radial(c, half * 0.16, [_w(1), _w(0)], const [0.3, 1]),
    );
  }

  static void _paintStreak(ui.Canvas canvas, ui.Rect r) {
    final cx = r.center.dx;
    // Faint wide body.
    final body = ui.Rect.fromCenter(center: ui.Offset(cx, r.center.dy), width: r.width * 0.55, height: r.height - 4);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(body, ui.Radius.circular(body.width / 2)),
      ui.Paint()
        ..shader = ui.Gradient.linear(body.topCenter, body.bottomCenter, [_w(0), _w(0.18), _w(0.5)], const [0, 0.6, 1])
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
    );
    // Bright thin core.
    final core = ui.Rect.fromCenter(center: ui.Offset(cx, r.center.dy + 4), width: 2, height: r.height - 14);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(core, const ui.Radius.circular(1)),
      ui.Paint()
        ..shader = ui.Gradient.linear(core.topCenter, core.bottomCenter, [_w(0), _w(0.5), _w(1)], const [0, 0.55, 1]),
    );
    // Glowing head.
    final head = ui.Offset(cx, r.bottom - 8);
    canvas.drawCircle(head, 6, ui.Paint()..shader = ui.Gradient.radial(head, 6, [_w(0.9), _w(0)]));
  }

  static void _paintEmber(ui.Canvas canvas, ui.Rect r) {
    final c = r.center;
    canvas.drawCircle(
      c,
      r.width / 2,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          c,
          r.width / 2,
          [_w(1), _w(0.92), _w(0.4), _w(0.1), _w(0)],
          const [0, 0.12, 0.3, 0.6, 1],
        ),
    );
  }
}
