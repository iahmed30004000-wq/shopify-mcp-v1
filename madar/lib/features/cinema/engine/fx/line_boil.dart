import 'dart:math' as math;
import 'dart:ui';

import '../core/film_clock.dart';

/// The 12 fps "line boil" of hand-inked animation, as a toolkit.
///
/// In a drawn cartoon every frame is re-inked, so outlines shimmer a little
/// "on twos" (12 drawings a second). Everything that boils seeds its jitter
/// from `FilmClock.boilFrame`, so all drawings on screen re-ink together,
/// and paths are rebuilt only when the boil frame changes
/// (`FilmClock.boilChanged`): 12 Hz, never 60 or 120.
///
/// * [LineBoil.jitter] / [LineBoil.offset] – the deterministic noise.
/// * [BoilPen] – draws into a [Path] with boiled control points, plus
///   hand-drawn primitives (wobbly ellipses, bowed lines, tapered brush
///   strokes).
/// * [BoiledPath] – a cached path that rebuilds itself only on new boil
///   frames.
abstract final class LineBoil {
  /// Deterministic value in [-1, 1] for ([seed], [index], [frame]); the same
  /// inputs always give the same value (stable within a boil frame).
  static double jitter(int seed, int index, int frame) {
    var h = (seed * 0x27d4eb2d + index * 0x165667b1 + frame * 0x61c88647) & 0x7fffffff;
    h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0x7fffffff;
    h = ((h ^ (h >> 12)) * 0x297a2d39) & 0x7fffffff;
    h ^= h >> 15;
    return (h & 0xffff) / 32767.5 - 1;
  }

  /// A 2D jitter of length ≤ [amplitude]·√2.
  static Offset offset(int seed, int index, int frame, double amplitude) =>
      Offset(jitter(seed, index * 2, frame) * amplitude, jitter(seed, index * 2 + 1, frame) * amplitude);

  /// The boil frame for [clock], or a frozen frame when [enabled] is false
  /// (reduced motion: lines keep their hand-drawn wobble but stop moving).
  static int frameOf(FilmClock clock, {bool enabled = true}) => enabled ? clock.boilFrame : 0;
}

/// Draws into a [Path] with every control point nudged by the line boil.
///
/// Reuse one pen: call [begin] each rebuild (it resets the point counter so
/// the same shape gets the same jitter sequence). Allocation-free.
class BoilPen {
  BoilPen({this.amplitude = 0.8, this.seed = 0});

  /// Jitter amplitude in the path's units (InkStyle.boilAmplitude).
  double amplitude;
  int seed;

  late Path _path;
  int _frame = 0;
  int _i = 0;

  Path get path => _path;

  /// Starts drawing into [path] for boil [frame]. Does not reset the path.
  void begin(Path path, int frame) {
    _path = path;
    _frame = frame;
    _i = 0;
  }

  double _jx() => LineBoil.jitter(seed, _i++, _frame) * amplitude;

  void moveTo(double x, double y) => _path.moveTo(x + _jx(), y + _jx());

  void lineTo(double x, double y) => _path.lineTo(x + _jx(), y + _jx());

  void quadTo(double cx, double cy, double x, double y) => _path.quadraticBezierTo(cx + _jx(), cy + _jx(), x + _jx(), y + _jx());

  void cubicTo(double c1x, double c1y, double c2x, double c2y, double x, double y) =>
      _path.cubicTo(c1x + _jx(), c1y + _jx(), c2x + _jx(), c2y + _jx(), x + _jx(), y + _jx());

  void close() => _path.close();

  /// A hand-drawn ellipse: four boiled cubic arcs whose ends overshoot a
  /// hair, like a quick brush circle.
  void ellipse(Rect r) {
    const k = 0.5523;
    final cx = r.center.dx, cy = r.center.dy;
    final rx = r.width / 2, ry = r.height / 2;
    moveTo(cx + rx, cy);
    cubicTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
    cubicTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
    cubicTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
    cubicTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
    close();
  }

  void circle(Offset c, double radius) => ellipse(Rect.fromCircle(center: c, radius: radius));

  /// A rectangle with slightly bowed, boiled edges.
  void rect(Rect r, {double bow = 0.012}) {
    final bx = r.width * bow, by = r.height * bow;
    moveTo(r.left, r.top);
    quadTo(r.center.dx, r.top - by, r.right, r.top);
    quadTo(r.right + bx, r.center.dy, r.right, r.bottom);
    quadTo(r.center.dx, r.bottom + by, r.left, r.bottom);
    quadTo(r.left - bx, r.center.dy, r.left, r.top);
    close();
  }

  /// An open line from [a] to [b] with a gentle hand bow (for strokes).
  void line(Offset a, Offset b, {double bow = 0.04}) {
    final m = Offset.lerp(a, b, 0.5)!;
    final d = b - a;
    final n = Offset(-d.dy, d.dx) * bow;
    moveTo(a.dx, a.dy);
    quadTo(m.dx + n.dx, m.dy + n.dy, b.dx, b.dy);
  }

  /// A filled brush stroke along the quadratic [a] → [control] → [b]:
  /// [width] at the belly, tapering towards both ends by [taper] (0 = a
  /// uniform line, 1 = needle-sharp ends) – the rubber-hose ink line.
  /// Adds one closed contour of 2 × [segments] points.
  void brush(Offset a, Offset control, Offset b, double width, {double taper = 0.6, int segments = 10}) {
    final n = math.max(2, segments);
    // Left edge forward.
    for (var s = 0; s <= n; s++) {
      _brushPoint(a, control, b, width, taper, s / n, 1, first: s == 0);
    }
    // Right edge back.
    for (var s = n; s >= 0; s--) {
      _brushPoint(a, control, b, width, taper, s / n, -1, first: false);
    }
    close();
  }

  void _brushPoint(Offset a, Offset c, Offset b, double width, double taper, double t, double side, {required bool first}) {
    final u = 1 - t;
    final x = u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx;
    final y = u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy;
    // Derivative of the quadratic for the normal.
    var tx = 2 * u * (c.dx - a.dx) + 2 * t * (b.dx - c.dx);
    var ty = 2 * u * (c.dy - a.dy) + 2 * t * (b.dy - c.dy);
    final len = math.sqrt(tx * tx + ty * ty);
    if (len > 1e-6) {
      tx /= len;
      ty /= len;
    } else {
      tx = 1;
      ty = 0;
    }
    final e = (2 * t - 1).abs();
    final w = width * 0.5 * (1 - taper * e * e) + width * 0.04;
    final px = x - ty * w * side;
    final py = y + tx * w * side;
    if (first) {
      moveTo(px, py);
    } else {
      lineTo(px, py);
    }
  }
}

/// A path that re-inks itself only when the boil frame changes.
///
/// ```dart
/// final head = BoiledPath((pen) => pen.circle(Offset.zero, 30), amplitude: 0.8);
/// // in render:
/// canvas.drawPath(head.at(clock.boilFrame), ink);
/// ```
class BoiledPath {
  BoiledPath(this.draw, {double amplitude = 0.8, int seed = 0}) : _pen = BoilPen(amplitude: amplitude, seed: seed);

  /// Draws the shape with the pen (called once per boil frame).
  final void Function(BoilPen pen) draw;
  final BoilPen _pen;
  final Path _path = Path();
  int _frame = -1;

  /// Rebuild count (tests: it must follow the boil rate, not the display).
  int get builds => _builds;
  int _builds = 0;

  double get amplitude => _pen.amplitude;
  set amplitude(double v) {
    if (v == _pen.amplitude) return;
    _pen.amplitude = v;
    _frame = -1;
  }

  /// The path for boil [frame] (rebuilt only when it changed).
  Path at(int frame) {
    if (frame != _frame) {
      _frame = frame;
      _path.reset();
      _pen.begin(_path, frame);
      draw(_pen);
      _builds++;
    }
    return _path;
  }

  /// Forces a rebuild on the next [at] (e.g. the shape's size changed).
  void invalidate() => _frame = -1;
}
