import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'astrolabe_geometry.dart';

/// The bright stars carried by the rete: the classic astrolabe star list,
/// chosen so their pointers are spread around the whole sky (J2000 right
/// ascension / declination in degrees; every one lies between the rete's
/// hub and its Capricorn ring).
enum ReteStarId {
  denebKaitos(10.897, -17.987),
  menkar(45.570, 4.090),
  aldebaran(68.980, 16.509),
  rigel(78.634, -8.202),
  betelgeuse(88.793, 7.407),
  sirius(101.287, -16.716),
  procyon(114.825, 5.225),
  alphard(141.897, -8.659),
  regulus(152.093, 11.967),
  denebola(177.265, 14.572),
  spica(201.298, -11.161),
  arcturus(213.915, 19.183),
  unukalhai(236.067, 6.426),
  rasAlhague(263.734, 12.560),
  altair(297.696, 8.868),
  denebAlgedi(326.760, -16.127),
  markab(346.190, 15.205);

  const ReteStarId(this.ra, this.dec);

  /// Right ascension (degrees).
  final double ra;

  /// Declination (degrees).
  final double dec;
}

/// A star pointer of the rete: its tip (the star, rete-local unit
/// coordinates) and the point on the rete's metal it sprouts from.
@immutable
class ReteStar {
  const ReteStar({required this.id, required this.tip, required this.base, required this.bend});

  final ReteStarId id;
  final Offset tip;
  final Offset base;

  /// Side the flame curls toward (±1).
  final double bend;
}

/// The rete (the rotating openwork star map) in unit coordinates (R = 1,
/// centre at the origin, before rotation; RA grows counter-clockwise, the
/// summer solstice points up).
@immutable
class ReteModel {
  const ReteModel({
    required this.rings,
    required this.straps,
    required this.overs,
    required this.overEdges,
    required this.strapLines,
    required this.overLines,
    required this.flames,
    required this.bosses,
    required this.ribs,
    required this.stars,
    required this.eclipticCenter,
    required this.eclipticRadius,
  });

  /// Circle centre lines stroked [ringWidth] wide: the Capricorn ring and
  /// the slender ring around the hub.
  final Path rings;

  /// The strapwork as filled ribbons (unit coordinates): the woven 8-fold
  /// rosette of curved ogee straps – swelling in the middle, slimming where
  /// they join the rings – and the equinoctial bar.
  final Path straps;

  /// The "over" strand's ribbon at every crossing, redrawn on top so the
  /// straps weave over and under; [overEdges] are its two long sides (the
  /// dark edges that cross the strand beneath – never its cut ends).
  final Path overs;
  final Path overEdges;

  /// Centre lines of the straps (the engraved groove down each one), and
  /// those of the over pieces.
  final Path strapLines;
  final Path overLines;

  /// The flame-shaped star pointers (filled).
  final Path flames;

  /// Round bosses where the pointers are riveted to the rete (filled).
  final Path bosses;

  /// The engraved mid-rib of every flame (stroked).
  final Path ribs;
  final List<ReteStar> stars;
  final Offset eclipticCenter;
  final double eclipticRadius;

  static const ringWidth = 0.021;
  static const eclipticWidth = 0.05;

  /// Nominal strap width; a rosette strap swells to 1.3× in its middle and
  /// slims to 0.7× where it meets a ring.
  static const strapWidth = 0.018;
  static const flameWidth = 0.03;
  static const bossRadius = 0.012;

  /// The slender ring the lattice hangs from, just outside the hub.
  static const innerRing = 0.307;
}

/// Pure path builders of the astrolabe (unit or pixel coordinates as noted).
abstract final class AstrolabePaths {
  static const _tau = 2 * math.pi;

  // --- girih ------------------------------------------------------------------

  /// Line segments of an 8-fold girih star pattern (the 4.8.8 octagon–square
  /// tiling traced with Hankin's polygons-in-contact method) covering a disc
  /// of [radius] around the origin, cell size [spacing].
  static List<(Offset, Offset)> girihSegments({double radius = 1, double spacing = 0.2, double contactDeg = 67.5}) {
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
      final half = long ? 0.2 : 0.16;
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

  /// A flame-shaped rete pointer from [base] to the needle-sharp [tip] (px or
  /// unit): a slender blade that leaves its boss through a narrow neck,
  /// swells into a teardrop body curling toward [bend] (±1) and tapers into
  /// a long point that licks back the other way.
  static Path flamePointer(Offset base, Offset tip, {required double width, double bend = 1, int samples = 22}) {
    final d = tip - base;
    final len = d.distance;
    if (len < 1e-9) return Path();
    final (c1, c2) = _flameControls(base, tip, bend);
    Offset curve(double t) => _cubic(base, c1, c2, tip, t);

    Offset tangent(double t) {
      final u = 1 - t;
      final g = (c1 - base) * (3 * u * u) + (c2 - c1) * (6 * u * t) + (tip - c2) * (3 * t * t);
      final l = g.distance;
      return l < 1e-9 ? d / len : g / l;
    }

    double half(double t) {
      const peak = 0.34;
      final neck = 0.42 + 0.58 * math.pow(t / peak, 0.7);
      final body = t < peak ? neck : math.pow((1 - t) / (1 - peak), 1.5).toDouble();
      return width / 2 * body;
    }

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      // denser samples toward the needle point
      final t = 1 - math.pow(1 - i / samples, 1.4).toDouble();
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
    for (final p in right.reversed.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static (Offset, Offset) _flameControls(Offset base, Offset tip, double bend) {
    final d = tip - base;
    final nrm = Offset(-d.dy, d.dx);
    return (base + d * 0.3 + nrm * (0.26 * bend), base + d * 0.78 - nrm * (0.12 * bend));
  }

  static Offset _cubic(Offset p0, Offset c1, Offset c2, Offset p1, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + p1 * (t * t * t);
  }

  /// The engraved mid-rib of [flamePointer] (from the neck most of the way
  /// to the point), as an open polyline path.
  static Path flameRib(Offset base, Offset tip, {double bend = 1, double from = 0.14, double to = 0.78}) {
    final (c1, c2) = _flameControls(base, tip, bend);
    final path = Path();
    const n = 12;
    for (var i = 0; i <= n; i++) {
      final p = _cubic(base, c1, c2, tip, from + (to - from) * i / n);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  static ReteModel? _rete;

  /// The rete model (memoised; unit coordinates).
  static ReteModel rete() => _rete ??= buildRete();

  /// Rete-local unit position of a rete star.
  static Offset starPosition(ReteStarId s) => AstrolabeProjection.reteLocal(s.ra, s.dec);

  /// Builds the rete: Capricorn ring, eccentric ecliptic ring, a multifoil
  /// ring around the hub, the equinoctial bar, the woven 8-fold rosette of
  /// curved straps ([rosetteStrands]) and a flame pointer for every
  /// [ReteStarId], riveted to the nearest piece of metal.
  static ReteModel buildRete() {
    const cap = AstrolabeRadii.capricorn;
    const inner = ReteModel.innerRing;
    final ecl = AstrolabeProjection.ecliptic;

    final rings = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: cap));

    // The multifoil (polylobed) ring the rosette hangs from – the
    // Andalusian cusped arch wrapped around the hub.
    final lobed = lobedRing(inner, lobes: 16, sagitta: 0.014);
    // Equinoctial bar: the equator's diameter through the equinoxes (its
    // middle hides under the hub).
    final bars = <List<Offset>>[
      [const Offset(inner, 0), const Offset(cap, 0)],
      [const Offset(-inner, 0), const Offset(-cap, 0)],
    ];
    final strands = rosetteStrands();

    final straps = Path();
    final strapLines = Path()..addPolygon(lobed, true);
    // The lobed ring is a narrow strap of constant width.
    straps.addPath(ribbon([...lobed, lobed.first], (_) => ReteModel.strapWidth * 0.36), Offset.zero);
    for (final b in bars) {
      straps.addPath(ribbon(b, (_) => ReteModel.strapWidth * 0.42), Offset.zero);
      strapLines.addPolygon(b, false);
    }
    for (final s in strands) {
      straps.addPath(ribbon(s, strapHalfWidth), Offset.zero);
      strapLines.addPolygon(s, false);
    }
    final weave = weaveRibbons(strands, halfWidth: strapHalfWidth, reach: ReteModel.strapWidth * 1.7);

    // Metal the star pointers can be riveted to (sampled).
    final metal = <Offset>[];
    void sampleCircle(Offset c, double r) {
      final n = (r * 400).ceil();
      for (var i = 0; i < n; i++) {
        final a = i / n * _tau;
        metal.add(c + Offset(math.cos(a), math.sin(a)) * r);
      }
    }

    sampleCircle(Offset.zero, cap - ReteModel.ringWidth * 0.2);
    sampleCircle(ecl.center, ecl.radius);
    for (final s in [
      ...strands,
      ...bars,
      [...lobed, lobed.first],
    ]) {
      for (var i = 0; i + 1 < s.length; i++) {
        final a = s[i], b = s[i + 1];
        final n = math.max(1, ((b - a).distance * 400).ceil());
        for (var k = 0; k < n; k++) {
          metal.add(Offset.lerp(a, b, k / n)!);
        }
      }
    }

    final flames = Path();
    final bosses = Path();
    final ribs = Path();
    final stars = <ReteStar>[];
    for (final id in ReteStarId.values) {
      final tip = starPosition(id);
      final base = anchorFor(tip, metal);
      // Curl away from the centre line between base and tip, so flames on
      // either side of a strap mirror each other.
      final cross = base.dx * tip.dy - base.dy * tip.dx;
      final bend = cross >= 0 ? 1.0 : -1.0;
      flames.addPath(flamePointer(base, tip, width: ReteModel.flameWidth, bend: bend), Offset.zero);
      bosses.addOval(Rect.fromCircle(center: base, radius: ReteModel.bossRadius));
      ribs.addPath(flameRib(base, tip, bend: bend), Offset.zero);
      stars.add(ReteStar(id: id, tip: tip, base: base, bend: bend));
    }
    return ReteModel(
      rings: rings,
      straps: straps,
      overs: weave.fills,
      overEdges: weave.edges,
      strapLines: strapLines,
      overLines: weave.lines,
      flames: flames,
      bosses: bosses,
      ribs: ribs,
      stars: List.unmodifiable(stars),
      eclipticCenter: ecl.center,
      eclipticRadius: ecl.radius,
    );
  }

  /// Half-width of a rosette strap at [t] (0 at the hub ring … 1 at the
  /// Capricorn ring): 0.7× the nominal width at its ends, 1.3× in the
  /// middle – a calligraphic swell, not a constant-width wire.
  static double strapHalfWidth(double t) =>
      ReteModel.strapWidth / 2 * (0.7 + 0.6 * math.sin(math.pi * t.clamp(0.0, 1.0)));

  /// Centre lines (unit coordinates) of the woven rosette: [folds]-fold
  /// symmetric ogee straps from the multifoil hub ring out to the Capricorn
  /// ring. From every junction on the hub ring one strap curls out to each
  /// side, reaching the Capricorn ring one sector over (leaving the hub
  /// radially, arriving almost tangentially – an S-curved ogee), so the
  /// straps of neighbouring junctions cross once in every sector and meet
  /// again in pointed arches on both rings.
  static List<List<Offset>> rosetteStrands({int folds = 8, int samples = 36}) {
    const ri = ReteModel.innerRing;
    const ro = AstrolabeRadii.capricorn - ReteModel.ringWidth * 0.25;
    final span = _tau / folds;
    Offset polar(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);
    final out = <List<Offset>>[];
    for (var k = 0; k < folds; k++) {
      final th = k * span + span / 2;
      for (final hand in const [1.0, -1.0]) {
        final p0 = polar(ri, th);
        final p1 = polar(ri + (ro - ri) * 0.46, th + hand * span * 0.04);
        final p2 = polar(ro - (ro - ri) * 0.16, th + hand * span * 0.74);
        final p3 = polar(ro, th + hand * span);
        out.add([for (var i = 0; i <= samples; i++) _cubic(p0, p1, p2, p3, i / samples)]);
      }
    }
    return out;
  }

  /// A filled ribbon along the polyline [line], [halfWidth] of its relative
  /// position t (0..1 by arc length) either side.
  static Path ribbon(List<Offset> line, double Function(double t) halfWidth) {
    if (line.length < 2) return Path();
    final lengths = <double>[0];
    for (var i = 1; i < line.length; i++) {
      lengths.add(lengths.last + (line[i] - line[i - 1]).distance);
    }
    final total = lengths.last <= 0 ? 1.0 : lengths.last;
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < line.length; i++) {
      final a = line[i == 0 ? 0 : i - 1], b = line[i == line.length - 1 ? i : i + 1];
      final d = b - a;
      final l = d.distance;
      final n = l < 1e-12 ? Offset.zero : Offset(-d.dy / l, d.dx / l);
      final h = halfWidth(lengths[i] / total);
      left.add(line[i] + n * h);
      right.add(line[i] - n * h);
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// The weave of [strands]: at every crossing the "over" strand (alternating
  /// along each strand) is redrawn as a short ribbon [reach] either side of
  /// the crossing – its fill, its two long edges and its centre line.
  static ({Path fills, Path edges, Path lines}) weaveRibbons(
    List<List<Offset>> strands, {
    required double Function(double t) halfWidth,
    required double reach,
  }) {
    final fills = Path(), edges = Path(), lines = Path();
    for (final c in _crossings(strands)) {
      final s = strands[c.over];
      // arc length along the over strand
      final lengths = <double>[0];
      for (var i = 1; i < s.length; i++) {
        lengths.add(lengths.last + (s[i] - s[i - 1]).distance);
      }
      final total = lengths.last;
      final i0 = c.t.floor().clamp(0, s.length - 2);
      final at = lengths[i0] + (s[i0 + 1] - s[i0]).distance * (c.t - i0);
      final from = math.max(0.0, at - reach), to = math.min(total, at + reach);
      final piece = <Offset>[];
      final ts = <double>[];
      Offset pointAt(double d) {
        for (var i = 1; i < s.length; i++) {
          if (lengths[i] >= d) {
            final seg = lengths[i] - lengths[i - 1];
            final u = seg <= 0 ? 0.0 : (d - lengths[i - 1]) / seg;
            return Offset.lerp(s[i - 1], s[i], u)!;
          }
        }
        return s.last;
      }

      const n = 8;
      for (var k = 0; k <= n; k++) {
        final d = from + (to - from) * k / n;
        piece.add(pointAt(d));
        ts.add(total <= 0 ? 0 : d / total);
      }
      final left = <Offset>[], right = <Offset>[];
      for (var i = 0; i < piece.length; i++) {
        final a = piece[i == 0 ? 0 : i - 1], b = piece[i == piece.length - 1 ? i : i + 1];
        final d = b - a;
        final l = d.distance;
        final nrm = l < 1e-12 ? Offset.zero : Offset(-d.dy / l, d.dx / l);
        final h = halfWidth(ts[i]);
        left.add(piece[i] + nrm * h);
        right.add(piece[i] - nrm * h);
      }
      fills.addPolygon([...left, ...right.reversed], true);
      edges
        ..addPolygon(left, false)
        ..addPolygon(right, false);
      lines.addPolygon(piece, false);
    }
    return (fills: fills, edges: edges, lines: lines);
  }

  /// Crossings of [strands] with the over strand (index) and its polyline
  /// parameter there (segment index + fraction); over / under alternates
  /// along every strand.
  static List<({Offset point, int over, double t})> _crossings(List<List<Offset>> strands) {
    final hits = <({int sa, int sb, double ta, double tb, Offset p})>[];
    for (var sa = 0; sa < strands.length; sa++) {
      for (var sb = sa + 1; sb < strands.length; sb++) {
        final a = strands[sa], b = strands[sb];
        for (var i = 0; i + 1 < a.length; i++) {
          for (var j = 0; j + 1 < b.length; j++) {
            final hit = _segmentHit(a[i], a[i + 1], b[j], b[j + 1]);
            if (hit == null) continue;
            hits.add((sa: sa, sb: sb, ta: i + hit.$1, tb: j + hit.$2, p: hit.$3));
          }
        }
      }
    }
    final along = <int, List<(double t, int hit, bool first)>>{};
    for (var h = 0; h < hits.length; h++) {
      along.putIfAbsent(hits[h].sa, () => []).add((hits[h].ta, h, true));
      along.putIfAbsent(hits[h].sb, () => []).add((hits[h].tb, h, false));
    }
    final firstOver = List<bool>.filled(hits.length, true);
    for (final e in along.entries) {
      final list = e.value..sort((x, y) => x.$1.compareTo(y.$1));
      for (var k = 0; k < list.length; k++) {
        if (list[k].$3) firstOver[list[k].$2] = (k + e.key).isEven;
      }
    }
    return [
      for (var h = 0; h < hits.length; h++)
        firstOver[h]
            ? (point: hits[h].p, over: hits[h].sa, t: hits[h].ta)
            : (point: hits[h].p, over: hits[h].sb, t: hits[h].tb),
    ];
  }

  /// Where a star at [tip] is riveted: the nearest sampled point of [metal]
  /// at least [minLength] away (so the flame always shows); with no metal at
  /// all, the hub ring straight below the star.
  static Offset anchorFor(Offset tip, List<Offset> metal, {double minLength = 0.1}) {
    Offset? best;
    var bestD = double.infinity;
    for (final m in metal) {
      final d = (m - tip).distance;
      if (d >= minLength && d < bestD) {
        best = m;
        bestD = d;
      }
    }
    if (best != null) return best;
    final l = tip.distance;
    return (l < 1e-9 ? const Offset(0, -1) : tip / l) * ReteModel.innerRing;
  }

  /// A closed multifoil ring around the origin: [lobes] arcs whose cusps lie
  /// on [radius], each rising [sagitta] outward above the chord between its
  /// cusps (unit coordinates).
  static List<Offset> lobedRing(double radius, {required int lobes, required double sagitta, int samples = 10}) {
    final out = <Offset>[];
    for (var k = 0; k < lobes; k++) {
      final a0 = k * _tau / lobes;
      final a1 = (k + 1) * _tau / lobes;
      final arc = _arc(
        Offset(math.cos(a0), math.sin(a0)) * radius,
        Offset(math.cos(a1), math.sin(a1)) * radius,
        sagitta: -sagitta,
        samples: samples,
      );
      out.addAll(arc.take(arc.length - 1));
    }
    return out;
  }

  /// Centre lines (polylines, unit coordinates) of the 8-fold star lattice:
  /// a Rub el Hizb – two interlaced squares with their eight points riveted
  /// to the Capricorn ring, on the solstitial and equinoctial axes.
  static List<List<Offset>> latticeStrands() {
    const cap = AstrolabeRadii.capricorn - ReteModel.ringWidth * 0.25;
    Offset polar(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);
    return [
      for (final phase in [0.0, math.pi / 4]) [for (var k = 0; k <= 4; k++) polar(cap, phase + k * math.pi / 2)],
    ];
  }

  /// A circular arc from [a] to [b] bulging [sagitta] (unit length, signed)
  /// to the left of a→b, as a polyline.
  static List<Offset> _arc(Offset a, Offset b, {required double sagitta, int samples = 28}) {
    final d = b - a;
    final len = d.distance;
    final n = Offset(-d.dy, d.dx) / len;
    final s = sagitta;
    if (s.abs() < 1e-6) return [a, b];
    // circle through a, b and the sagitta point
    final r = (len * len / 4 + s * s) / (2 * s.abs());
    final mid = (a + b) / 2;
    final c = mid + n * (s > 0 ? -(r - s.abs()) : (r - s.abs()));
    final a0 = math.atan2(a.dy - c.dy, a.dx - c.dx);
    var a1 = math.atan2(b.dy - c.dy, b.dx - c.dx);
    var sweep = a1 - a0;
    // take the short way round
    while (sweep > math.pi) {
      sweep -= _tau;
    }
    while (sweep < -math.pi) {
      sweep += _tau;
    }
    a1 = a0 + sweep;
    return [
      for (var i = 0; i <= samples; i++)
        c + Offset(math.cos(a0 + sweep * i / samples), math.sin(a0 + sweep * i / samples)) * r,
    ];
  }

  /// Short pieces of the "over" strand at every crossing of [strands]
  /// (alternating over / under along each strand), [halfLength] each side.
  static Path weaveOvers(List<List<Offset>> strands, {required double halfLength}) {
    final crossings = latticeCrossings(strands);
    final path = Path();
    for (final c in crossings) {
      final a = c.point - c.overDirection * halfLength;
      final b = c.point + c.overDirection * halfLength;
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }

  /// Every proper crossing between (or within) [strands] with an over/under
  /// assignment that alternates along each strand.
  static List<({Offset point, Offset overDirection})> latticeCrossings(List<List<Offset>> strands) {
    final hits = <({int sa, int sb, double ta, double tb, Offset p, Offset da, Offset db})>[];
    for (var sa = 0; sa < strands.length; sa++) {
      for (var sb = sa; sb < strands.length; sb++) {
        final a = strands[sa], b = strands[sb];
        for (var i = 0; i + 1 < a.length; i++) {
          for (var j = sa == sb ? i + 2 : 0; j + 1 < b.length; j++) {
            final hit = _segmentHit(a[i], a[i + 1], b[j], b[j + 1]);
            if (hit == null) continue;
            final da = a[i + 1] - a[i], db = b[j + 1] - b[j];
            hits.add((
              sa: sa,
              sb: sb,
              ta: i + hit.$1,
              tb: j + hit.$2,
              p: hit.$3,
              da: da / da.distance,
              db: db / db.distance,
            ));
          }
        }
      }
    }
    // Walk every strand and alternate over / under at its crossings; the
    // walk of the crossing's first strand decides who passes over.
    final along = <int, List<(double t, int hit, bool first)>>{};
    for (var h = 0; h < hits.length; h++) {
      along.putIfAbsent(hits[h].sa, () => []).add((hits[h].ta, h, true));
      along.putIfAbsent(hits[h].sb, () => []).add((hits[h].tb, h, false));
    }
    final firstOver = List<bool>.filled(hits.length, true);
    for (final e in along.entries) {
      final list = e.value..sort((x, y) => x.$1.compareTo(y.$1));
      for (var k = 0; k < list.length; k++) {
        if (list[k].$3) firstOver[list[k].$2] = (k + e.key).isEven;
      }
    }
    return [
      for (var h = 0; h < hits.length; h++) (point: hits[h].p, overDirection: firstOver[h] ? hits[h].da : hits[h].db),
    ];
  }

  static (double, double, Offset)? _segmentHit(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denom = d1.dx * d2.dy - d1.dy * d2.dx;
    if (denom.abs() < 1e-9) return null;
    final w = p3 - p1;
    final t = (w.dx * d2.dy - w.dy * d2.dx) / denom;
    final u = (w.dx * d1.dy - w.dy * d1.dx) / denom;
    const m = 1e-6;
    if (t < m || t > 1 - m || u < m || u > 1 - m) return null;
    return (t, u, p1 + d1 * t);
  }
}
