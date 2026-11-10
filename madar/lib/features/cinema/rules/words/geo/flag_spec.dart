/// Code-drawable flag specifications (no images).
///
/// A [FlagSpec] is data from assets/games/countries.json: an aspect ratio
/// and a list of drawing elements, painted in order. Units: `x` is a
/// fraction of the flag WIDTH (0 = hoist / left edge), `y` a fraction of the
/// HEIGHT (0 = top); radii, sizes, stroke and band widths are fractions of
/// the HEIGHT. Flags are never mirrored for right-to-left layouts.
///
/// [FlagSpec.shapes] compiles the elements to pixel-space primitives
/// ([FlagPolygon], [FlagCircle], [FlagRing], [FlagCrescent], [FlagText]) for
/// a painter: fill polygons (or stroke them when [FlagPolygon.strokeWidth]
/// is set), draw circles, rings (annulus) and crescents (outer disc minus
/// inner disc, e.g. with `Path.combine(PathOperation.difference, …)`), and
/// text centred on its point. Clip everything to the flag rectangle (Nepal's
/// polygons define its non-rectangular outline; draw no background there).
///
/// Element types: fill, hs / vs (stripes, optional weights w), rect, poly
/// (optional stroke sw), circle, ring, crescent (dx, dy = inner-disc offset
/// in height units), star (n points, inner ratio ir, rotation rot in
/// degrees, 0 = a point straight up), sun (rays + disc), pentagram
/// (interlaced outline), cross (full-width Nordic / centred cross), plus
/// (Greek cross), saltire, band (thick segment), uj (Union Jack in a
/// rectangle), text, emblem (approximated arms: disc, oval, shield, eagle,
/// bird, crown, tree) and wheel (ring with spokes).
library;

import 'dart:math' as math;

/// A point in pixels.
final class FlagPoint {
  /// Creates a point.
  const FlagPoint(this.x, this.y);

  /// X (pixels from the left edge).
  final double x;

  /// Y (pixels from the top).
  final double y;

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// A compiled drawing primitive.
sealed class FlagShape {
  const FlagShape(this.color);

  /// ARGB colour.
  final int color;
}

/// A filled (or, with [strokeWidth], outlined) polygon.
final class FlagPolygon extends FlagShape {
  /// Creates a polygon.
  const FlagPolygon(this.points, super.color, {this.strokeWidth});

  /// Vertices.
  final List<FlagPoint> points;

  /// Outline width in pixels (null = filled).
  final double? strokeWidth;
}

/// A filled disc.
final class FlagCircle extends FlagShape {
  /// Creates a disc.
  const FlagCircle(this.center, this.radius, super.color);

  /// Centre.
  final FlagPoint center;

  /// Radius in pixels.
  final double radius;
}

/// An annulus.
final class FlagRing extends FlagShape {
  /// Creates a ring.
  const FlagRing(this.center, this.radius, this.innerRadius, super.color);

  /// Centre.
  final FlagPoint center;

  /// Outer radius.
  final double radius;

  /// Inner radius.
  final double innerRadius;
}

/// Outer disc minus inner disc.
final class FlagCrescent extends FlagShape {
  /// Creates a crescent.
  const FlagCrescent(this.center, this.radius, this.innerCenter, this.innerRadius, super.color);

  /// Outer centre.
  final FlagPoint center;

  /// Outer radius.
  final double radius;

  /// Centre of the removed disc.
  final FlagPoint innerCenter;

  /// Radius of the removed disc.
  final double innerRadius;
}

/// Text centred on a point (Arabic script, e.g. the shahada).
final class FlagText extends FlagShape {
  /// Creates text.
  const FlagText(this.text, this.center, this.fontSize, super.color);

  /// The text.
  final String text;

  /// Centre.
  final FlagPoint center;

  /// Font size in pixels.
  final double fontSize;
}

/// Parses `#RRGGBB` to opaque ARGB.
int parseFlagColor(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length != 6) throw FormatException('bad colour', hex);
  return 0xFF000000 | int.parse(h, radix: 16);
}

/// A flag specification.
final class FlagSpec {
  /// Creates a spec.
  const FlagSpec({required this.ratioWidth, required this.ratioHeight, required this.elements});

  /// Parses `{"ratio": [w, h], "e": [...]}`.
  factory FlagSpec.fromJson(Map<String, Object?> j) {
    final r = j['ratio']! as List<Object?>;
    return FlagSpec(
      ratioWidth: (r[0]! as num).toDouble(),
      ratioHeight: (r[1]! as num).toDouble(),
      elements: List.unmodifiable([for (final e in j['e']! as List<Object?>) Map<String, Object?>.unmodifiable(e! as Map)]),
    );
  }

  /// Width part of the aspect ratio.
  final double ratioWidth;

  /// Height part of the aspect ratio.
  final double ratioHeight;

  /// Raw elements (see the library comment).
  final List<Map<String, Object?>> elements;

  /// Width / height.
  double get aspectRatio => ratioWidth / ratioHeight;

  /// Compiles to primitives for a [width] × [height] canvas (use a size of
  /// [aspectRatio] for undistorted flags).
  List<FlagShape> shapes(double width, double height) {
    final c = _Compiler(width, height);
    for (final e in elements) {
      c.element(e);
    }
    return List.unmodifiable(c.out);
  }
}

double _d(Map<String, Object?> e, String k, [double fallback = 0]) => (e[k] as num?)?.toDouble() ?? fallback;

final class _Compiler {
  _Compiler(this.w, this.h);

  final double w, h;
  final List<FlagShape> out = [];

  FlagPoint _pt(double x, double y) => FlagPoint(x * w, y * h);

  void _rect(int color, double x, double y, double rw, double rh) {
    out.add(FlagPolygon([_pt(x, y), _pt(x + rw, y), _pt(x + rw, y + rh), _pt(x, y + rh)], color));
  }

  static List<double> _weights(Map<String, Object?> e, int n) {
    final raw = e['w'] as List<Object?>?;
    final ws = raw == null ? List<double>.filled(n, 1) : [for (final v in raw) (v! as num).toDouble()];
    final total = ws.fold<double>(0, (a, b) => a + b);
    return [for (final v in ws) v / total];
  }

  List<FlagPoint> _starPoints(double cx, double cy, double r, int n, double ir, double rotDeg) {
    final pts = <FlagPoint>[];
    for (var i = 0; i < n * 2; i++) {
      final rad = (i.isEven ? r : r * ir);
      final a = (rotDeg - 90 + 180.0 * i / n) * math.pi / 180;
      pts.add(FlagPoint(cx + rad * math.cos(a), cy + rad * math.sin(a)));
    }
    return pts;
  }

  /// A thick segment in pixels (extended by half its width at both ends).
  List<FlagPoint> _band(FlagPoint a, FlagPoint b, double width, {bool extend = true}) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return [a, a, a];
    final ux = dx / len, uy = dy / len;
    final ext = extend ? width / 2 : 0.0;
    final ax = a.x - ux * ext, ay = a.y - uy * ext, bx = b.x + ux * ext, by = b.y + uy * ext;
    final nx = -uy * width / 2, ny = ux * width / 2;
    return [FlagPoint(ax + nx, ay + ny), FlagPoint(bx + nx, by + ny), FlagPoint(bx - nx, by - ny), FlagPoint(ax - nx, ay - ny)];
  }

  /// Sutherland–Hodgman clip of [poly] to an axis-aligned rectangle.
  static List<FlagPoint> _clip(List<FlagPoint> poly, double x0, double y0, double x1, double y1) {
    List<FlagPoint> edge(List<FlagPoint> input, bool Function(FlagPoint) inside, FlagPoint Function(FlagPoint, FlagPoint) cut) {
      final res = <FlagPoint>[];
      for (var i = 0; i < input.length; i++) {
        final cur = input[i], prev = input[(i + input.length - 1) % input.length];
        if (inside(cur)) {
          if (!inside(prev)) res.add(cut(prev, cur));
          res.add(cur);
        } else if (inside(prev)) {
          res.add(cut(prev, cur));
        }
      }
      return res;
    }

    FlagPoint atX(FlagPoint a, FlagPoint b, double x) => FlagPoint(x, a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x));
    FlagPoint atY(FlagPoint a, FlagPoint b, double y) => FlagPoint(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y), y);
    var p = poly;
    p = edge(p, (q) => q.x >= x0, (a, b) => atX(a, b, x0));
    if (p.isEmpty) return p;
    p = edge(p, (q) => q.x <= x1, (a, b) => atX(a, b, x1));
    if (p.isEmpty) return p;
    p = edge(p, (q) => q.y >= y0, (a, b) => atY(a, b, y0));
    if (p.isEmpty) return p;
    return edge(p, (q) => q.y <= y1, (a, b) => atY(a, b, y1));
  }

  void _clippedBand(int color, FlagPoint a, FlagPoint b, double width, double x0, double y0, double x1, double y1) {
    final poly = _clip(_band(a, b, width), x0, y0, x1, y1);
    if (poly.length >= 3) out.add(FlagPolygon(poly, color));
  }

  void _unionJack(double x, double y, double rw, double rh) {
    const blue = 0xFF012169, red = 0xFFC8102E, white = 0xFFFFFFFF;
    final x0 = x * w, y0 = y * h, x1 = (x + rw) * w, y1 = (y + rh) * h;
    final uh = y1 - y0; // Union Jack proportions follow its height
    out.add(FlagPolygon([FlagPoint(x0, y0), FlagPoint(x1, y0), FlagPoint(x1, y1), FlagPoint(x0, y1)], blue));
    final tl = FlagPoint(x0, y0), tr = FlagPoint(x1, y0), bl = FlagPoint(x0, y1), br = FlagPoint(x1, y1);
    _clippedBand(white, tl, br, uh * 0.2, x0, y0, x1, y1);
    _clippedBand(white, tr, bl, uh * 0.2, x0, y0, x1, y1);
    // Counterchanged red diagonals, approximated by thin offset bands.
    final off = uh * 0.033;
    _clippedBand(red, FlagPoint(tl.x, tl.y + off), FlagPoint(br.x, br.y + off), uh * 0.066, x0, y0, (x0 + x1) / 2, (y0 + y1) / 2);
    _clippedBand(red, FlagPoint(tl.x, tl.y - off), FlagPoint(br.x, br.y - off), uh * 0.066, (x0 + x1) / 2, (y0 + y1) / 2, x1, y1);
    _clippedBand(red, FlagPoint(tr.x, tr.y + off), FlagPoint(bl.x, bl.y + off), uh * 0.066, (x0 + x1) / 2, y0, x1, (y0 + y1) / 2);
    _clippedBand(red, FlagPoint(tr.x, tr.y - off), FlagPoint(bl.x, bl.y - off), uh * 0.066, x0, (y0 + y1) / 2, (x0 + x1) / 2, y1);
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final cw = uh * 1 / 3, rwid = uh * 1 / 5;
    out
      ..add(FlagPolygon([FlagPoint(cx - cw / 2, y0), FlagPoint(cx + cw / 2, y0), FlagPoint(cx + cw / 2, y1), FlagPoint(cx - cw / 2, y1)], white))
      ..add(FlagPolygon([FlagPoint(x0, cy - cw / 2), FlagPoint(x1, cy - cw / 2), FlagPoint(x1, cy + cw / 2), FlagPoint(x0, cy + cw / 2)], white))
      ..add(FlagPolygon([FlagPoint(cx - rwid / 2, y0), FlagPoint(cx + rwid / 2, y0), FlagPoint(cx + rwid / 2, y1), FlagPoint(cx - rwid / 2, y1)], red))
      ..add(FlagPolygon([FlagPoint(x0, cy - rwid / 2), FlagPoint(x1, cy - rwid / 2), FlagPoint(x1, cy + rwid / 2), FlagPoint(x0, cy + rwid / 2)], red));
  }

  /// Unit templates (x, y in [-1, 1], y down) for approximated emblems.
  static const Map<String, List<List<double>>> _templates = {
    'shield': [[-0.8, -0.9], [0.8, -0.9], [0.8, 0.1], [0.5, 0.6], [0, 0.95], [-0.5, 0.6], [-0.8, 0.1]],
    'eagle': [
      [0, -0.9], [0.15, -0.6], [0.3, -0.55], [0.95, -0.8], [0.8, -0.3], [0.55, 0.05], [0.25, 0.1], [0.35, 0.6], //
      [0.1, 0.45], [0, 0.95], [-0.1, 0.45], [-0.35, 0.6], [-0.25, 0.1], [-0.55, 0.05], [-0.8, -0.3], [-0.95, -0.8],
      [-0.3, -0.55], [-0.15, -0.6],
    ],
    'bird': [
      [-0.9, -0.2], [-0.5, -0.35], [-0.2, -0.8], [0.05, -0.3], [0.5, -0.4], [0.9, -0.55], [0.6, -0.1], [0.3, 0.1], //
      [0.4, 0.8], [0.15, 0.2], [-0.2, 0.25], [-0.6, 0.05],
    ],
    'crown': [[-0.8, 0.6], [-0.8, -0.4], [-0.4, 0.0], [0, -0.7], [0.4, 0.0], [0.8, -0.4], [0.8, 0.6]],
    'tree': [
      [0, -0.95], [0.35, -0.45], [0.2, -0.45], [0.6, 0.05], [0.35, 0.05], [0.85, 0.5], [0.1, 0.5], [0.1, 0.9], //
      [-0.1, 0.9], [-0.1, 0.5], [-0.85, 0.5], [-0.35, 0.05], [-0.6, 0.05], [-0.2, -0.45], [-0.35, -0.45],
    ],
  };

  void _emblem(int color, String shape, FlagPoint c, double r) {
    switch (shape) {
      case 'disc':
        out.add(FlagCircle(c, r, color));
      case 'oval':
        out.add(FlagPolygon([
          for (var i = 0; i < 32; i++)
            FlagPoint(c.x + r * 0.7 * math.cos(2 * math.pi * i / 32), c.y + r * math.sin(2 * math.pi * i / 32)),
        ], color));
      default:
        final t = _templates[shape] ?? _templates['shield']!;
        out.add(FlagPolygon([for (final p in t) FlagPoint(c.x + p[0] * r, c.y + p[1] * r)], color));
    }
  }

  void element(Map<String, Object?> e) {
    final t = e['t']! as String;
    final colors = e['c'];
    final color = colors is String ? parseFlagColor(colors) : 0xFF000000;
    switch (t) {
      case 'fill':
        _rect(color, 0, 0, 1, 1);
      case 'hs' || 'vs':
        final cs = [for (final v in colors! as List<Object?>) parseFlagColor(v! as String)];
        final ws = _weights(e, cs.length);
        var pos = 0.0;
        for (var i = 0; i < cs.length; i++) {
          if (t == 'hs') {
            _rect(cs[i], 0, pos, 1, ws[i]);
          } else {
            _rect(cs[i], pos, 0, ws[i], 1);
          }
          pos += ws[i];
        }
      case 'rect':
        _rect(color, _d(e, 'x'), _d(e, 'y'), _d(e, 'w'), _d(e, 'h'));
      case 'poly':
        final pts = [
          for (final p in e['p']! as List<Object?>)
            if (p case [final num x, final num y]) _pt(x.toDouble(), y.toDouble()),
        ];
        final sw = e['sw'] as num?;
        out.add(FlagPolygon(pts, color, strokeWidth: sw == null ? null : sw * h));
      case 'circle':
        out.add(FlagCircle(_pt(_d(e, 'x'), _d(e, 'y')), _d(e, 'r') * h, color));
      case 'ring':
        out.add(FlagRing(_pt(_d(e, 'x'), _d(e, 'y')), _d(e, 'r') * h, _d(e, 'ir') * h, color));
      case 'crescent':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        out.add(FlagCrescent(c, _d(e, 'r') * h, FlagPoint(c.x + _d(e, 'dx') * h, c.y + _d(e, 'dy') * h), _d(e, 'ir') * h, color));
      case 'star':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        out.add(FlagPolygon(
          _starPoints(c.x, c.y, _d(e, 'r') * h, (e['n'] as int?) ?? 5, _d(e, 'ir', 0.382), _d(e, 'rot')),
          color,
        ));
      case 'sun':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        final r = _d(e, 'r') * h, ir = _d(e, 'ir', 0.6);
        out
          ..add(FlagPolygon(_starPoints(c.x, c.y, r, e['n']! as int, ir, _d(e, 'rot')), color))
          ..add(FlagCircle(c, r * ir, color));
      case 'pentagram':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        final r = _d(e, 'r') * h, sw = _d(e, 'sw') * h;
        final tips = [
          for (var i = 0; i < 5; i++) FlagPoint(c.x + r * math.cos((-90 + 72 * i) * math.pi / 180), c.y + r * math.sin((-90 + 72 * i) * math.pi / 180)),
        ];
        for (var i = 0; i < 5; i++) {
          out.add(FlagPolygon(_band(tips[i], tips[(i + 2) % 5], sw, extend: false), color));
        }
      case 'cross':
        final x = _d(e, 'x') * w, y = _d(e, 'y') * h, bw = _d(e, 'w') * h;
        out
          ..add(FlagPolygon([FlagPoint(x - bw / 2, 0), FlagPoint(x + bw / 2, 0), FlagPoint(x + bw / 2, h), FlagPoint(x - bw / 2, h)], color))
          ..add(FlagPolygon([FlagPoint(0, y - bw / 2), FlagPoint(w, y - bw / 2), FlagPoint(w, y + bw / 2), FlagPoint(0, y + bw / 2)], color));
      case 'plus':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        final s = _d(e, 's') * h / 2, bw = _d(e, 'w') * h / 2;
        out
          ..add(FlagPolygon([FlagPoint(c.x - bw, c.y - s), FlagPoint(c.x + bw, c.y - s), FlagPoint(c.x + bw, c.y + s), FlagPoint(c.x - bw, c.y + s)], color))
          ..add(FlagPolygon([FlagPoint(c.x - s, c.y - bw), FlagPoint(c.x + s, c.y - bw), FlagPoint(c.x + s, c.y + bw), FlagPoint(c.x - s, c.y + bw)], color));
      case 'saltire':
        final bw = _d(e, 'w') * h;
        _clippedBand(color, const FlagPoint(0, 0), FlagPoint(w, h), bw, 0, 0, w, h);
        _clippedBand(color, FlagPoint(w, 0), FlagPoint(0, h), bw, 0, 0, w, h);
      case 'band':
        _clippedBand(color, _pt(_d(e, 'x1'), _d(e, 'y1')), _pt(_d(e, 'x2'), _d(e, 'y2')), _d(e, 'w') * h, 0, 0, w, h);
      case 'uj':
        _unionJack(_d(e, 'x'), _d(e, 'y'), _d(e, 'w', 1), _d(e, 'h', 1));
      case 'text':
        out.add(FlagText(e['v']! as String, _pt(_d(e, 'x'), _d(e, 'y')), _d(e, 's') * h, color));
      case 'emblem':
        _emblem(color, e['shape']! as String, _pt(_d(e, 'x'), _d(e, 'y')), _d(e, 'r') * h);
      case 'wheel':
        final c = _pt(_d(e, 'x'), _d(e, 'y'));
        final r = _d(e, 'r') * h, sw = _d(e, 'sw') * h, n = e['n']! as int;
        out.add(FlagRing(c, r, r - sw * 1.6, color));
        for (var i = 0; i < n; i++) {
          final a = 2 * math.pi * i / n;
          out.add(FlagPolygon(_band(c, FlagPoint(c.x + r * math.cos(a), c.y + r * math.sin(a)), sw, extend: false), color));
        }
        out.add(FlagCircle(c, sw * 1.8, color));
      default:
        throw FormatException('unknown flag element', t);
    }
  }
}
