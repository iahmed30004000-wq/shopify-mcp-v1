import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Bezier constant for a quarter circle drawn with one cubic.
const double kArc = 0.5522847498;

/// An affine "pen" that writes path verbs into a [Path] through a transform
/// stack, so a character can be drawn in its own design space (facing right,
/// feet at the origin) and still land in the final space with squash,
/// stretch, lean and mirroring baked in.
///
/// It never allocates after construction: the target path is swapped with
/// [target], the transform lives in plain doubles and a fixed stack.
final class InkPen {
  Path _path = Path();
  double _a = 1, _b = 0, _c = 0, _d = 1, _tx = 0, _ty = 0;
  final Float64List _stack = Float64List(6 * 32);
  int _sp = 0;

  /// Subsequent verbs go into [path].
  void target(Path path) => _path = path;

  Path get path => _path;

  /// Identity transform, empty stack.
  void reset() {
    _a = 1;
    _b = 0;
    _c = 0;
    _d = 1;
    _tx = 0;
    _ty = 0;
    _sp = 0;
  }

  void save() {
    if (_sp + 6 > _stack.length) return;
    _stack[_sp] = _a;
    _stack[_sp + 1] = _b;
    _stack[_sp + 2] = _c;
    _stack[_sp + 3] = _d;
    _stack[_sp + 4] = _tx;
    _stack[_sp + 5] = _ty;
    _sp += 6;
  }

  void restore() {
    if (_sp < 6) return;
    _sp -= 6;
    _a = _stack[_sp];
    _b = _stack[_sp + 1];
    _c = _stack[_sp + 2];
    _d = _stack[_sp + 3];
    _tx = _stack[_sp + 4];
    _ty = _stack[_sp + 5];
  }

  void translate(double x, double y) {
    _tx += _a * x + _c * y;
    _ty += _b * x + _d * y;
  }

  void scale(double sx, [double? sy]) {
    final ky = sy ?? sx;
    _a *= sx;
    _b *= sx;
    _c *= ky;
    _d *= ky;
  }

  void rotate(double radians) {
    if (radians == 0) return;
    final cs = math.cos(radians), sn = math.sin(radians);
    final a = _a * cs + _c * sn;
    final b = _b * cs + _d * sn;
    final c = -_a * sn + _c * cs;
    final d = -_b * sn + _d * cs;
    _a = a;
    _b = b;
    _c = c;
    _d = d;
  }

  /// Horizontal shear: x' = x + k·y (a lean when y points up the body).
  void shearX(double k) {
    _c += _a * k;
    _d += _b * k;
  }

  /// Rotates about ([px], [py]).
  void rotateAbout(double radians, double px, double py) {
    translate(px, py);
    rotate(radians);
    translate(-px, -py);
  }

  /// Maps a design-space point to final space.
  double x(double x, double y) => _a * x + _c * y + _tx;
  double y(double x, double y) => _b * x + _d * y + _ty;

  /// Maps a direction (no translation).
  double dx(double x, double y) => _a * x + _c * y;
  double dy(double x, double y) => _b * x + _d * y;

  /// Average linear scale of the current transform.
  double get scaleFactor => math.sqrt((_a * _d - _b * _c).abs());

  /// True when the transform mirrors (winding flips).
  bool get mirrored => _a * _d - _b * _c < 0;

  void moveTo(double x, double y) => _path.moveTo(this.x(x, y), this.y(x, y));

  void lineTo(double x, double y) => _path.lineTo(this.x(x, y), this.y(x, y));

  void quadTo(double cx, double cy, double x, double y) =>
      _path.quadraticBezierTo(this.x(cx, cy), this.y(cx, cy), this.x(x, y), this.y(x, y));

  void cubicTo(double c1x, double c1y, double c2x, double c2y, double x, double y) =>
      _path.cubicTo(this.x(c1x, c1y), this.y(c1x, c1y), this.x(c2x, c2y), this.y(c2x, c2y), this.x(x, y), this.y(x, y));

  void close() => _path.close();

  /// Ellipse centred at ([cx], [cy]), optionally rotated by [rot].
  void ellipse(double cx, double cy, double rx, double ry, [double rot = 0]) {
    if (rot != 0) {
      save();
      translate(cx, cy);
      rotate(rot);
      _ellipse(0, 0, rx, ry);
      restore();
    } else {
      _ellipse(cx, cy, rx, ry);
    }
  }

  void _ellipse(double cx, double cy, double rx, double ry) {
    final kx = rx * kArc, ky = ry * kArc;
    moveTo(cx + rx, cy);
    cubicTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
    cubicTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
    cubicTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
    cubicTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
    close();
  }

  void circle(double cx, double cy, double r) => _ellipse(cx, cy, r, r);

  /// A stadium from ([x0], [y0]) to ([x1], [y1]) with radius [r0] at the
  /// start and [r1] at the end (a tapered sausage – fingers, feathers,
  /// fingers of steam).
  void capsule(double x0, double y0, double x1, double y1, double r0, [double? r1]) {
    final re = r1 ?? r0;
    var ux = x1 - x0, uy = y1 - y0;
    final len = math.sqrt(ux * ux + uy * uy);
    if (len < 1e-6) {
      circle(x0, y0, math.max(r0, re));
      return;
    }
    ux /= len;
    uy /= len;
    final nx = -uy, ny = ux;
    moveTo(x0 + nx * r0, y0 + ny * r0);
    lineTo(x1 + nx * re, y1 + ny * re);
    // Half circle around the end.
    cubicTo(
      x1 + nx * re + ux * re * kArc,
      y1 + ny * re + uy * re * kArc,
      x1 + ux * re + nx * re * kArc,
      y1 + uy * re + ny * re * kArc,
      x1 + ux * re,
      y1 + uy * re,
    );
    cubicTo(
      x1 + ux * re - nx * re * kArc,
      y1 + uy * re - ny * re * kArc,
      x1 - nx * re + ux * re * kArc,
      y1 - ny * re + uy * re * kArc,
      x1 - nx * re,
      y1 - ny * re,
    );
    lineTo(x0 - nx * r0, y0 - ny * r0);
    cubicTo(
      x0 - nx * r0 - ux * r0 * kArc,
      y0 - ny * r0 - uy * r0 * kArc,
      x0 - ux * r0 - nx * r0 * kArc,
      y0 - uy * r0 - ny * r0 * kArc,
      x0 - ux * r0,
      y0 - uy * r0,
    );
    cubicTo(
      x0 - ux * r0 + nx * r0 * kArc,
      y0 - uy * r0 + ny * r0 * kArc,
      x0 + nx * r0 - ux * r0 * kArc,
      y0 + ny * r0 - uy * r0 * kArc,
      x0 + nx * r0,
      y0 + ny * r0,
    );
    close();
  }

  /// Rounded rectangle (corner radius [r]).
  void roundRect(double l, double t, double r, double b, double radius) {
    final rr = math.min(radius, math.min((r - l) / 2, (b - t) / 2));
    final k = rr * (1 - kArc);
    moveTo(l + rr, t);
    lineTo(r - rr, t);
    cubicTo(r - k, t, r, t + k, r, t + rr);
    lineTo(r, b - rr);
    cubicTo(r, b - k, r - k, b, r - rr, b);
    lineTo(l + rr, b);
    cubicTo(l + k, b, l, b - k, l, b - rr);
    lineTo(l, t + rr);
    cubicTo(l, t + k, l + k, t, l + rr, t);
    close();
  }

  /// A star with [points] tips, outer radius [ro], inner radius [ri] and
  /// rounded ("puffy") tips when [round] > 0.
  void star(double cx, double cy, int points, double ro, double ri, {double rot = -math.pi / 2, double round = 0}) {
    final n = points * 2;
    for (var i = 0; i <= n; i++) {
      final k = i % n;
      final a = rot + k * math.pi / points;
      final r = k.isEven ? ro : ri;
      final px = cx + math.cos(a) * r, py = cy + math.sin(a) * r;
      if (i == 0) {
        moveTo(px, py);
      } else if (round > 0) {
        // Pull the edge's midpoint outward a little: soft, inflated edges.
        final am = rot + (k - 0.5) * math.pi / points;
        final rm = (ro + ri) * 0.5 + round * (ro - ri);
        quadTo(cx + math.cos(am) * rm, cy + math.sin(am) * rm, px, py);
      } else {
        lineTo(px, py);
      }
    }
    close();
  }

  /// Polygon through the given flat xy list (design space), closed.
  void polygon(List<double> xy) {
    for (var i = 0; i + 1 < xy.length; i += 2) {
      if (i == 0) {
        moveTo(xy[0], xy[1]);
      } else {
        lineTo(xy[i], xy[i + 1]);
      }
    }
    close();
  }
}
