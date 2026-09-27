import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/astro/star_catalog.dart';
import '../../../../core/design/painters/girih_rosette_painter.dart';
import 'astrolabe_geometry.dart';

/// A bright star carried by the rete: its pointer tip (rete-local unit
/// coordinates), the anchor on the rete it sprouts from, and its names.
class ReteStar {
  const ReteStar({
    required this.tip,
    required this.base,
    required this.bend,
    required this.nameAr,
    required this.nameEn,
  });

  final Offset tip;
  final Offset base;

  /// Side the flame curls toward (±1).
  final double bend;
  final String nameAr;
  final String nameEn;
}

/// The rete (the rotating openwork star map) in unit coordinates (R = 1,
/// centre at the origin, before rotation).
class ReteModel {
  ReteModel._({
    required this.rings,
    required this.straps,
    required this.overs,
    required this.flames,
    required this.stars,
    required this.eclipticCenter,
    required this.eclipticRadius,
  });

  /// Circle centre lines stroked [ringWidth] wide (Capricorn + ecliptic).
  final Path rings;

  /// Strapwork centre lines stroked [strapWidth] wide: the interlaced
  /// 8-fold girih rosette, the equinoctial bar and the upper equator arc.
  final Path straps;

  /// Short pieces of the "over" strands at every rosette crossing, redrawn
  /// on top so the lattice weaves over and under.
  final Path overs;

  /// Filled shapes: the flame-shaped star pointers and their bosses.
  final Path flames;
  final List<ReteStar> stars;
  final Offset eclipticCenter;
  final double eclipticRadius;

  static const ringWidth = 0.019;
  static const eclipticWidth = 0.034;
  static const strapWidth = 0.0125;

  /// Radius of the 8-fold lattice rosette's outer star tips: a star-shaped
  /// crown around the hub.
  static const latticeRadius = 0.435;
}

/// Pure path builders of the astrolabe (unit or pixel coordinates as noted).
abstract final class AstrolabePaths {
  static const _tau = 2 * math.pi;

  // --- girih ------------------------------------------------------------------

  /// Line segments of an 8-fold girih star pattern (the 4.8.8 octagon–square
  /// tiling traced with Hankin's polygons-in-contact method) covering a disc
  /// of [radius] around the origin, cell size [spacing].
  static List<(Offset, Offset)> girihSegments({
    double radius = 1,
    double spacing = 0.2,
    double contactDeg = 67.5,
  }) {
    final s = spacing;
    final e = s * (math.sqrt2 - 1); // octagon / square edge length
    final theta = contactDeg * math.pi / 180;
    final out = <(Offset, Offset)>[];
    final n = (radius / s).ceil() + 1;
    final limit = radius + s;

    void polygon(Offset c, int sides, double apothem, double phase) {
      if (c.distance > limit) return;
      final mids = <Offset>[];
      final ts = <Offset>[];
      final ns = <Offset>[];
      for (var k = 0; k < sides; k++) {
        final phi = phase + k * _tau / sides;
        final dir = Offset(math.cos(phi), math.sin(phi));
        mids.add(c + dir * apothem);
        ts.add(Offset(-dir.dy, dir.dx));
        ns.add(-dir);
      }
      for (var k = 0; k < sides; k++) {
        final k1 = (k + 1) % sides;
        final a = mids[k];
        final da = ts[k] * math.cos(theta) + ns[k] * math.sin(theta);
        final b = mids[k1];
        final db = ts[k1] * -math.cos(theta) + ns[k1] * math.sin(theta);
        final p = _intersectRays(a, da, b, db);
        if (p == null) continue;
        out
          ..add((a, p))
          ..add((b, p));
      }
    }

    for (var i = -n; i <= n; i++) {
      for (var j = -n; j <= n; j++) {
        polygon(Offset(i * s, j * s), 8, s / 2, 0);
        polygon(Offset((i + 0.5) * s, (j + 0.5) * s), 4, e / 2, math.pi / 4);
      }
    }
    return out;
  }

  static Offset? _intersectRays(Offset a, Offset da, Offset b, Offset db) {
    final den = da.dx * db.dy - da.dy * db.dx;
    if (den.abs() < 1e-9) return null;
    final w = b - a;
    final t = (w.dx * db.dy - w.dy * db.dx) / den;
    return a + da * t;
  }

  /// [girihSegments] as one path scaled by [scale].
  static Path girih({required double scale, double radius = 1, double spacing = 0.2, double contactDeg = 67.5}) {
    final path = Path();
    for (final (a, b) in girihSegments(radius: radius, spacing: spacing, contactDeg: contactDeg)) {
      path
        ..moveTo(a.dx * scale, a.dy * scale)
        ..lineTo(b.dx * scale, b.dy * scale);
    }
    return path;
  }

  // --- prayer pointer -----------------------------------------------------------

  /// An 8-point star (radius [radius], px) centred at [center] whose point
  /// facing [angle] is drawn out into a blade of length [tipLength].
  static Path pointerStar({
    required Offset center,
    required double radius,
    required double angle,
    required double tipLength,
    double innerRatio = 0.46,
  }) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = angle + i * math.pi / 8;
      final r = i == 0 ? tipLength : (i.isEven ? radius : radius * innerRatio);
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  // --- sun glyph -----------------------------------------------------------------

  /// A radiant sun ("sun in splendour") around the origin: eight long pointed
  /// rays alternating with eight short flame-like rays. [radius] is the disc.
  static Path sunRays(double radius) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 - math.pi / 2;
      final long = i.isEven;
      final len = radius * (long ? 2.05 : 1.55);
      final half = (long ? 0.2 : 0.16);
      final d = Offset(math.cos(a), math.sin(a));
      final n = Offset(-d.dy, d.dx);
      final b0 = d * (radius * 0.85) + n * (radius * half);
      final b1 = d * (radius * 0.85) - n * (radius * half);
      final tip = d * len;
      path.moveTo(b0.dx, b0.dy);
      if (long) {
        path.lineTo(tip.dx, tip.dy);
      } else {
        // a gently curved (flame) ray
        final c = d * (radius * 1.25) + n * (radius * 0.22);
        path.quadraticBezierTo(c.dx, c.dy, tip.dx, tip.dy);
      }
      path
        ..lineTo(b1.dx, b1.dy)
        ..close();
    }
    return path;
  }

  // --- rete ------------------------------------------------------------------------

  /// A flame-shaped rete pointer from [base] to the sharp [tip] (px or unit):
  /// a slender S-curved blade, narrow at its neck, swelling into a teardrop
  /// body and tapering into a long point; [bend] (±1) picks the curl side.
  static Path flamePointer(Offset base, Offset tip, {required double width, double bend = 1, int samples = 18}) {
    final d = tip - base;
    final len = d.distance;
    if (len < 1e-9) return Path();
    final dir = d / len;
    final nrm = Offset(-dir.dy, dir.dx);
    final c1 = base + d * 0.28 + nrm * (len * 0.2 * bend);
    final c2 = base + d * 0.72 - nrm * (len * 0.1 * bend);
    Offset curve(double t) {
      final u = 1 - t;
      return base * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + tip * (t * t * t);
    }

    Offset tangent(double t) {
      final u = 1 - t;
      final g = (c1 - base) * (3 * u * u) + (c2 - c1) * (6 * u * t) + (tip - c2) * (3 * t * t);
      final l = g.distance;
      return l < 1e-9 ? dir : g / l;
    }

    double half(double t) {
      const peak = 0.3;
      final body = t < peak
          ? math.pow(t / peak, 0.55).toDouble()
          : math.pow((1 - t) / (1 - peak), 1.35).toDouble();
      return width / 2 * math.max(body, 0.34 * (1 - t / peak));
    }

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final p = curve(t);
      final g = tangent(t);
      final n = Offset(-g.dy, g.dx);
      final h = half(t);
      left.add(p + n * h);
      right.add(p - n * h);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// Stars carried by the rete (bright, named, well spread in right
  /// ascension and between the tropics so their pointers stay on the rete).
  static const reteStarNames = <String>[
    'Aldebaran',
    'Rigel',
    'Betelgeuse',
    'Sirius',
    'Procyon',
    'Regulus',
    'Spica',
    'Arcturus',
    'Altair',
    'Pleiades',
  ];

  static ReteModel? _rete;

  /// The rete model (memoised; unit coordinates).
  static ReteModel rete() => _rete ??= _buildRete();

  static ReteModel _buildRete() {
    const cap = AstrolabeRadii.capricorn;
    final ecl = AstrolabeProjection.ecliptic;

    final rings = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: cap))
      ..addOval(Rect.fromCircle(center: ecl.center, radius: ecl.radius));

    // 8-fold interlaced girih rosette (outer {8/2} + inner {8/3} strands).
    final geo = GirihRosetteGeometry.of(8);
    const scale = ReteModel.latticeRadius / GirihRosetteGeometry.outerRadius;
    Offset map(Offset u) => Offset(u.dx, u.dy) * scale;
    final straps = Path();
    final segments = <(Offset, Offset)>[];
    for (final strand in geo.strands) {
      final pts = strand.map(map).toList();
      straps.addPolygon(pts, true);
      for (var i = 0; i < pts.length; i++) {
        segments.add((pts[i], pts[(i + 1) % pts.length]));
      }
    }
    final overs = Path();
    const half = ReteModel.strapWidth * 2.2;
    for (final x in geo.crossings) {
      final p = map(x.point);
      final a = p - x.overDirection * half;
      final b = p + x.overDirection * half;
      overs
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    // Equinoctial bar (the equator's diameter through the equinoxes).
    final barEnd = cap - ReteModel.ringWidth * 0.3;
    straps
      ..moveTo(-barEnd, 0)
      ..lineTo(barEnd, 0);
    segments.add((Offset(-barEnd, 0), Offset(barEnd, 0)));
    // Lower meridian bar from the hub to where the ecliptic meets Capricorn.
    straps
      ..moveTo(0, AstrolabeRadii.hubOuter)
      ..lineTo(0, cap);
    segments.add((const Offset(0, AstrolabeRadii.hubOuter), const Offset(0, cap)));

    // Star pointers.
    final flames = Path();
    final stars = <ReteStar>[];
    final catalog = {for (final s in kArabicStarNames) s.en: s};
    for (final name in reteStarNames) {
      final s = catalog[name];
      if (s == null) continue;
      final tip = AstrolabeProjection.reteLocal(s.ra, s.dec);
      final base = _anchorFor(tip, ecl.center, ecl.radius, segments);
      if (base == null) continue;
      // Curl away from the centre line between base and tip, alternating
      // with the side of the dial for a balanced, hand-made look.
      final cross = base.dx * tip.dy - base.dy * tip.dx;
      final bend = cross >= 0 ? 1.0 : -1.0;
      flames.addPath(flamePointer(base, tip, width: 0.036, bend: bend), Offset.zero);
      flames.addOval(Rect.fromCircle(center: base, radius: 0.011));
      stars.add(ReteStar(tip: tip, base: base, bend: bend, nameAr: s.ar, nameEn: s.en));
    }
    return ReteModel._(
      rings: rings,
      straps: straps,
      overs: overs,
      flames: flames,
      stars: stars,
      eclipticCenter: ecl.center,
      eclipticRadius: ecl.radius,
    );
  }

  /// Where a star's pointer is riveted: the nearest rete element that is
  /// neither too close (the flame must show) nor too far.
  static Offset? _anchorFor(Offset tip, Offset eclC, double eclR, List<(Offset, Offset)> segments) {
    const minLen = 0.095;
    const maxLen = 0.26;
    final candidates = <Offset>[];
    void circle(Offset c, double r) {
      final d = tip - c;
      final l = d.distance;
      if (l < 1e-9) return;
      candidates.add(c + d / l * r);
    }

    circle(Offset.zero, AstrolabeRadii.capricorn - ReteModel.ringWidth / 2);
    circle(eclC, eclR);
    circle(Offset.zero, AstrolabeRadii.hubOuter);
    for (final (a, b) in segments) {
      final ab = b - a;
      final t = (((tip - a).dx * ab.dx + (tip - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(0.0, 1.0);
      candidates.add(a + ab * t);
    }
    Offset? best;
    var bestD = double.infinity;
    for (final c in candidates) {
      final d = (c - tip).distance;
      if (d >= minLen && d <= maxLen && d < bestD) {
        best = c;
        bestD = d;
      }
    }
    if (best != null) return best;
    // Everything is too close: step back along the nearest element's normal.
    Offset? nearest;
    var nd = double.infinity;
    for (final c in candidates) {
      final d = (c - tip).distance;
      if (d < nd) {
        nd = d;
        nearest = c;
      }
    }
    if (nearest == null) return null;
    final away = tip.distance > 1e-9 ? tip / tip.distance : const Offset(0, -1);
    return tip - away * minLen;
  }
}
