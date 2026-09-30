import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'boil.dart';
import 'ink_pen.dart';

/// A sampled curve in FINAL space (after the pen's transform), used where
/// the shape itself matters: hand-inked wobble, brush ribbons (thick-to-thin
/// strokes), shading crescents and bounds.
///
/// Fixed capacity, reused every drawing – no allocation after construction.
final class Contour {
  Contour([int capacity = 96]) : _x = Float64List(capacity), _y = Float64List(capacity), _n = Float64List(capacity * 2);

  final Float64List _x, _y;
  // Scratch: normals (x, y interleaved).
  final Float64List _n;
  int length = 0;
  bool closed = true;

  int get capacity => _x.length;
  double xAt(int i) => _x[i];
  double yAt(int i) => _y[i];

  void clear({bool closed = true}) {
    length = 0;
    this.closed = closed;
  }

  void add(double x, double y) {
    if (length >= _x.length) return;
    _x[length] = x;
    _y[length] = y;
    length++;
  }

  /// Adds a design-space point through [pen].
  void addPen(InkPen pen, double x, double y) => add(pen.x(x, y), pen.y(x, y));

  /// Samples an ellipse (design space through [pen]); starts at the top.
  void ellipse(InkPen pen, double cx, double cy, double rx, double ry, {int samples = 28}) {
    final n = math.min(samples, capacity - length);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      addPen(pen, cx + math.cos(a) * rx, cy + math.sin(a) * ry);
    }
  }

  /// A cartoon body silhouette: an ellipse (half-sizes [rx], [ry]) whose
  /// width grows toward the bottom by [taper] (pear > 0, egg/cone < 0),
  /// whose middle bulges forward by [bend] (a bean's belly) and whose sides
  /// flatten toward a rounded box by [box] (0 = ellipse, 1 = boxy).
  void blob(
    InkPen pen,
    double cx,
    double cy,
    double rx,
    double ry, {
    double taper = 0,
    double bend = 0,
    double box = 0,
    int samples = 32,
  }) {
    final n = math.min(samples, capacity - length);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      var c = math.cos(a), s = math.sin(a);
      if (box > 0) {
        // Superellipse: |c|^(2/p) keeps the sign.
        final p = 2 + box * 3;
        c = c.sign * math.pow(c.abs(), 2 / p).toDouble();
        s = s.sign * math.pow(s.abs(), 2 / p).toDouble();
      }
      final w = 1 + taper * s;
      final x = cx + c * rx * w + bend * rx * (1 - s * s);
      addPen(pen, x, cy + s * ry);
    }
  }

  /// Samples a cubic bezier (design space). Skips the first point when
  /// [skipFirst] (to chain segments).
  void cubic(
    InkPen pen,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3, {
    int samples = 10,
    bool skipFirst = false,
  }) {
    for (var i = skipFirst ? 1 : 0; i <= samples; i++) {
      final t = i / samples, m = 1 - t;
      final a = m * m * m, b = 3 * m * m * t, c = 3 * m * t * t, d = t * t * t;
      addPen(pen, a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3);
    }
  }

  /// Samples a quadratic bezier (design space).
  void quad(
    InkPen pen,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2, {
    int samples = 8,
    bool skipFirst = false,
  }) {
    for (var i = skipFirst ? 1 : 0; i <= samples; i++) {
      final t = i / samples, m = 1 - t;
      addPen(pen, m * m * x0 + 2 * m * t * x1 + t * t * x2, m * m * y0 + 2 * m * t * y1 + t * t * y2);
    }
  }

  /// Samples a quadratic bezier given in FINAL space.
  void quadFinal(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2, {
    int samples = 8,
    bool skipFirst = false,
  }) {
    for (var i = skipFirst ? 1 : 0; i <= samples; i++) {
      final t = i / samples, m = 1 - t;
      add(m * m * x0 + 2 * m * t * x1 + t * t * x2, m * m * y0 + 2 * m * t * y1 + t * t * y2);
    }
  }

  void _normals() {
    final n = length;
    var sign = 1.0;
    if (closed) sign = signedArea() >= 0 ? 1.0 : -1.0;
    for (var i = 0; i < n; i++) {
      int i0, i1;
      if (closed) {
        i0 = (i - 1 + n) % n;
        i1 = (i + 1) % n;
      } else {
        i0 = math.max(0, i - 1);
        i1 = math.min(n - 1, i + 1);
      }
      final tx = _x[i1] - _x[i0], ty = _y[i1] - _y[i0];
      final l = math.sqrt(tx * tx + ty * ty);
      if (l < 1e-9) {
        _n[i * 2] = 0;
        _n[i * 2 + 1] = 0;
      } else {
        _n[i * 2] = sign * ty / l;
        _n[i * 2 + 1] = -sign * tx / l;
      }
    }
  }

  /// Shoelace area (sign = orientation).
  double signedArea() {
    var a = 0.0;
    for (var i = 0, j = length - 1; i < length; j = i++) {
      a += _x[j] * _y[i] - _x[i] * _y[j];
    }
    return a / 2;
  }

  /// Hand-inked wobble: displaces points along their normals by a smooth,
  /// low-frequency function re-rolled each boil [frame] (lines "crawl" like
  /// a traced drawing, they don't fizz).
  void wobble(double amp, int frame, int seed, int salt) {
    if (amp == 0 || length < 3) return;
    _normals();
    final p1 = boilNoise(frame, seed, salt) * math.pi;
    final p2 = boilNoise(frame, seed, salt + 1) * math.pi;
    final a1 = 0.6 + 0.4 * boilNoise(frame, seed, salt + 2);
    final a2 = 0.4 * boilNoise(frame, seed, salt + 3);
    final n = length;
    for (var i = 0; i < n; i++) {
      final t = closed ? i / n : i / (n - 1);
      var d = a1 * math.sin(t * math.pi * 4 + p1) + a2 * math.sin(t * math.pi * 6 + p2);
      if (!closed) d *= math.sin(t * math.pi);
      _x[i] += _n[i * 2] * d * amp;
      _y[i] += _n[i * 2 + 1] * d * amp;
    }
  }

  /// Offsets every point by ([dx], [dy]).
  void shift(double dx, double dy) {
    for (var i = 0; i < length; i++) {
      _x[i] += dx;
      _y[i] += dy;
    }
  }

  /// Smooth curve through the samples (quadratics through midpoints).
  void writeSmooth(Path p) {
    final n = length;
    if (n < 2) return;
    if (closed) {
      p.moveTo((_x[n - 1] + _x[0]) / 2, (_y[n - 1] + _y[0]) / 2);
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n;
        p.quadraticBezierTo(_x[i], _y[i], (_x[i] + _x[j]) / 2, (_y[i] + _y[j]) / 2);
      }
      p.close();
    } else {
      p.moveTo(_x[0], _y[0]);
      for (var i = 1; i < n - 1; i++) {
        p.quadraticBezierTo(_x[i], _y[i], (_x[i] + _x[i + 1]) / 2, (_y[i] + _y[i + 1]) / 2);
      }
      p.lineTo(_x[n - 1], _y[n - 1]);
    }
  }

  static void _smoothLoop(Path p, Float64List xs, Float64List ys, int n, bool reverse) {
    final a = reverse ? 0 : n - 1, b = reverse ? n - 1 : 0;
    p.moveTo((xs[a] + xs[b]) / 2, (ys[a] + ys[b]) / 2);
    for (var k = 0; k < n; k++) {
      final i = reverse ? n - 1 - k : k;
      final k1 = (k + 1) % n;
      final j = reverse ? n - 1 - k1 : k1;
      p.quadraticBezierTo(xs[i], ys[i], (xs[i] + xs[j]) / 2, (ys[i] + ys[j]) / 2);
    }
    p.close();
  }

  // Scratch for offset loops.
  late final Float64List _ox = Float64List(capacity), _oy = Float64List(capacity);

  /// The shaded side of a closed shape: a crescent hugging the contour
  /// where it faces away from the light, [depth] deep at its darkest point,
  /// tapering to nothing at the terminator. ([sx], [sy]) is the direction
  /// toward the shadow (unit), [threshold] where shade starts (-1..1).
  ///
  /// Written as an outer loop plus a reversed inner loop (non-zero winding
  /// leaves only the crescent) – no path boolean ops, no clip.
  void writeCrescent(Path p, double sx, double sy, double depth, {double threshold = 0.05, double power = 0.8}) {
    final n = length;
    if (!closed || n < 3) return;
    _normals();
    for (var i = 0; i < n; i++) {
      final nx = _n[i * 2], ny = _n[i * 2 + 1];
      final dot = nx * sx + ny * sy;
      var w = ((dot - threshold) / (1 - threshold)).clamp(0.0, 1.0);
      w = math.pow(w * w * (3 - 2 * w), power).toDouble();
      _ox[i] = _x[i] - nx * depth * w;
      _oy[i] = _y[i] - ny * depth * w;
    }
    _smoothLoop(p, _x, _y, n, false);
    _smoothLoop(p, _ox, _oy, n, true);
  }

  /// A brush stroke along an OPEN contour: [width] at full pressure, tapering
  /// to [minWidth]·[width] at the ends ([taperIn]/[taperOut] = fraction of
  /// the length used to taper). [press] > 0 lays the brush down heavy and
  /// lifts it thin (the classic ink "swell").
  void writeBrush(
    Path p,
    double width, {
    double taperIn = 0.3,
    double taperOut = 0.3,
    double minWidth = 0.18,
    double press = 0,
  }) {
    final n = length;
    if (n < 2) return;
    final wasClosed = closed;
    closed = false;
    _normals();
    closed = wasClosed;
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      var w = 1.0;
      if (taperIn > 0 && t < taperIn) w = math.min(w, _ease(t / taperIn));
      if (taperOut > 0 && t > 1 - taperOut) w = math.min(w, _ease((1 - t) / taperOut));
      w = minWidth + (1 - minWidth) * w;
      w *= 1 + press * (0.5 - t);
      final hw = width * w / 2;
      _ox[i] = _x[i] + _n[i * 2] * hw;
      _oy[i] = _y[i] + _n[i * 2 + 1] * hw;
      // Store the other side in the normal buffer (reuse: normals no longer needed).
      _n[i * 2] = _x[i] - _n[i * 2] * hw;
      _n[i * 2 + 1] = _y[i] - _n[i * 2 + 1] * hw;
    }
    // Left side forward.
    p.moveTo(_ox[0], _oy[0]);
    for (var i = 1; i < n - 1; i++) {
      p.quadraticBezierTo(_ox[i], _oy[i], (_ox[i] + _ox[i + 1]) / 2, (_oy[i] + _oy[i + 1]) / 2);
    }
    p.lineTo(_ox[n - 1], _oy[n - 1]);
    // Round end cap.
    final ex = _x[n - 1] - _x[n - 2], ey = _y[n - 1] - _y[n - 2];
    final el = math.max(1e-9, math.sqrt(ex * ex + ey * ey));
    final ew = math.sqrt(math.pow(_ox[n - 1] - _n[(n - 1) * 2], 2) + math.pow(_oy[n - 1] - _n[(n - 1) * 2 + 1], 2)) / 2;
    p.quadraticBezierTo(
      _x[n - 1] + ex / el * ew * 1.3,
      _y[n - 1] + ey / el * ew * 1.3,
      _n[(n - 1) * 2],
      _n[(n - 1) * 2 + 1],
    );
    // Right side back.
    for (var i = n - 2; i > 0; i--) {
      p.quadraticBezierTo(
        _n[i * 2],
        _n[i * 2 + 1],
        (_n[i * 2] + _n[(i - 1) * 2]) / 2,
        (_n[i * 2 + 1] + _n[(i - 1) * 2 + 1]) / 2,
      );
    }
    p.lineTo(_n[0], _n[1]);
    final sx = _x[0] - _x[1], sy = _y[0] - _y[1];
    final sl = math.max(1e-9, math.sqrt(sx * sx + sy * sy));
    final sw = math.sqrt(math.pow(_ox[0] - _n[0], 2) + math.pow(_oy[0] - _n[1], 2)) / 2;
    p
      ..quadraticBezierTo(_x[0] + sx / sl * sw * 1.3, _y[0] + sy / sl * sw * 1.3, _ox[0], _oy[0])
      ..close();
  }

  static double _ease(double t) {
    final c = t.clamp(0.0, 1.0);
    return math.sin(c * math.pi / 2);
  }

  /// Axis-aligned bounds of the samples.
  Rect get bounds {
    if (length == 0) return Rect.zero;
    var l = _x[0], r = _x[0], t = _y[0], b = _y[0];
    for (var i = 1; i < length; i++) {
      l = math.min(l, _x[i]);
      r = math.max(r, _x[i]);
      t = math.min(t, _y[i]);
      b = math.max(b, _y[i]);
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}
