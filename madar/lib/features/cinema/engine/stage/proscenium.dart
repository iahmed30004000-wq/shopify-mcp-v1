import 'dart:math' as math;
import 'dart:ui';

import '../core/era_skin.dart';
import '../core/film_clock.dart';
import 'bulb_atlas.dart';
import 'stage_layout.dart';
import 'stage_materials.dart';
import 'stage_ornaments.dart';

/// The architecture around the stage opening, per [ProsceniumStyle]:
///
/// | style | era | look |
/// |---|---|---|
/// | picturePalace | 1920s | plaster and gilt: segmental arch with beading, coffered header with rosettes, a cartouche crest in laurels, fluted pilasters |
/// | artDeco | 1930s | black lacquer and chrome: stepped corners, a sunburst fan behind a medallion, speed lines, bulb columns |
/// | noirArch | 1940s | a shadowy round arch, venetian-blind light across the wall, two sconces |
/// | atomic | 1950s | turquoise and gold: a starburst crest, boomerangs and sparkles, chasing bulbs |
/// | marquee | 1970s | peeling paint, 70s stripes, a dense frame of chasing bulbs (some dead) |
/// | neon | 1980s | a synthwave sun and grid, flickering neon tubes |
///
/// Everything static is recorded ONCE per layout into a [Picture] (a
/// proscenium is a painted background: it does not boil). Only the bulbs,
/// sconces and neon are painted live, batched through a [BulbAtlas].
class ProsceniumPainter {
  ProsceniumPainter({required this.skin, required this.materials, this.reducedMotion = false});

  final EraSkin skin;
  final StageMaterials materials;
  final bool reducedMotion;

  StageLayout? _layout;
  Picture? _picture;

  /// Marquee bulbs (centre, radius, chase index) laid out per style.
  final List<Offset> _bulbs = [];
  final List<double> _bulbR = [];
  final List<int> _bulbIndex = [];

  /// Footlight bulbs.
  final List<Offset> _foot = [];

  // Live paths (neon): rebuilt on layout only.
  final Path _neonOuter = Path();
  final Path _neonInner = Path();
  final Path _neonSides = Path();
  final Path _neonFoot = Path();

  ProsceniumStyle get style => skin.stage.proscenium;
  StageStyle get stage => skin.stage;

  double _lw = 1.6;

  void layout(StageLayout layout) {
    _layout = layout;
    _picture?.dispose();
    _picture = null;
    _lw = (1.5 * layout.width / 412).clamp(1.1, 2.4);
    _layoutBulbs(layout);
    _layoutNeon(layout);
  }

  /// Static architecture (cached picture).
  void paintStatic(Canvas canvas) {
    final l = _layout;
    if (l == null) return;
    canvas.drawPicture(_picture ??= _record(l));
  }

  /// Bulbs, sconces and neon for this frame. [pulse] 0..1 brightens the
  /// footlights (hits, big scores).
  void paintLive(Canvas canvas, FilmClock clock, BulbAtlas atlas, {double pulse = 0}) {
    final l = _layout;
    if (l == null) return;
    final t = reducedMotion ? 0.0 : clock.time;
    final m = materials;
    atlas.begin();
    // Marquee bulbs.
    for (var i = 0; i < _bulbs.length; i++) {
      final lit = _chase(_bulbIndex[i], t);
      atlas.add(_bulbs[i], _bulbR[i], lit, m.bulb, m.bulbOff, halo: m.glow, haloRadius: _bulbR[i] * 4.6);
    }
    // Footlights.
    final flick = reducedMotion ? 0.0 : stage.footlightFlicker;
    for (var i = 0; i < _foot.length; i++) {
      final f = 1 - flick * 0.45 * (0.5 + 0.5 * math.sin(t * 9.3 + i * 2.3) * math.sin(t * 3.1 + i * 1.7));
      final lit = (0.78 + 0.22 * pulse) * f;
      final r = l.foot * 0.12;
      if (style == ProsceniumStyle.neon) {
        atlas.addHalo(_foot[i], l.foot * (1.1 + 0.5 * pulse), m.neonA.withValues(alpha: 0.35 * lit));
      } else {
        atlas.add(_foot[i], r, lit, m.bulb, m.bulbOff, halo: m.glow, haloRadius: l.foot * (1.05 + 0.6 * pulse));
      }
    }
    // Noir sconces.
    if (style == ProsceniumStyle.noirArch) {
      final y = l.hdr + l.drop + 34;
      for (final x in [l.pil * 0.5, l.width - l.pil * 0.5]) {
        final f = reducedMotion ? 1.0 : 0.85 + 0.15 * math.sin(t * 7 + x);
        atlas.addHalo(Offset(x, y - 10), 34, m.glow.withValues(alpha: 0.32 * f));
        atlas.addHalo(Offset(x, y - 4), 12, m.bulb.withValues(alpha: 0.75 * f));
      }
    }
    atlas.flush(canvas);
    if (style == ProsceniumStyle.neon) _paintNeon(canvas, l, t, pulse);
  }

  // ---------------------------------------------------------------------------
  // Bulb choreography.

  double _chase(int i, double t) {
    if (reducedMotion) return 0.9;
    switch (style) {
      case ProsceniumStyle.picturePalace:
        // A slow warm swell running round the arch.
        final v = 0.5 + 0.5 * math.cos(math.pi * 2 * (i / 7 - t * 0.45));
        return 0.55 + 0.45 * v * v;
      case ProsceniumStyle.artDeco:
        return ((i + (t * 5).floor()) % 3 == 0) ? 1 : 0.42;
      case ProsceniumStyle.atomic:
        final tw = _hash(i * 3.1 + (t * 6).floor() * 0.37);
        return ((i + (t * 7).floor()) % 4 == 0) ? 1 : (tw > 0.8 ? 0.9 : 0.5);
      case ProsceniumStyle.marquee:
        final h = _hash(i * 7.7);
        if (h > 0.93) return 0.05; // dead bulbs
        if (h > 0.86) return _hash(i + (t * 14).floor() * 1.3) > 0.4 ? 0.9 : 0.15; // loose ones
        return ((i + (t * 8).floor()) % 3 == 0) ? 1 : 0.3;
      case ProsceniumStyle.noirArch || ProsceniumStyle.neon:
        return 0.8;
    }
  }

  static double _hash(double x) {
    final s = math.sin(x * 12.9898 + 78.233) * 43758.5453;
    return s - s.floorToDouble();
  }

  void _layoutBulbs(StageLayout l) {
    _bulbs.clear();
    _bulbR.clear();
    _bulbIndex.clear();
    _foot.clear();
    final w = l.width;
    final u = w / 412;
    void add(Offset c, double r) {
      _bulbIndex.add(_bulbs.length);
      _bulbs.add(c);
      _bulbR.add(r);
    }

    switch (style) {
      case ProsceniumStyle.picturePalace:
        const n = 13;
        for (var i = 0; i < n; i++) {
          final x = l.pil + 14 * u + (w - 2 * l.pil - 28 * u) * i / (n - 1);
          if ((x - w / 2).abs() < 36 * u) continue;
          add(Offset(x, l.rimTopAt(x) - 7 * u), 2.7 * u);
        }
      case ProsceniumStyle.artDeco:
        for (var y = l.hdr + l.drop * 3 + 16 * u; y < l.footTop - 12 * u; y += 27 * u) {
          add(Offset(l.pil * 0.5, y), 3.1 * u);
        }
        for (var y = l.hdr + l.drop * 3 + 16 * u; y < l.footTop - 12 * u; y += 27 * u) {
          add(Offset(w - l.pil * 0.5, y), 3.1 * u);
        }
        for (var x = l.pil + l.drop * 3 + 10 * u; x < w - l.pil - l.drop * 3 - 6 * u; x += 21 * u) {
          if ((x - w / 2).abs() < l.hdr * 1.05) continue;
          add(Offset(x, l.hdr - 6 * u), 2.4 * u);
        }
      case ProsceniumStyle.atomic:
        for (var x = l.pil + l.drop + 8 * u; x < w - l.pil - l.drop - 4 * u; x += 19 * u) {
          if ((x - w / 2).abs() < l.hdr * 0.95) continue;
          add(Offset(x, l.hdr - 6 * u), 2.5 * u);
        }
        // Star tips of the crest.
        final c = Offset(w / 2, l.hdr * 0.5);
        final r = l.hdr * 0.62;
        for (var i = 0; i < 12; i++) {
          final a = -math.pi / 2 + math.pi * 2 * i / 12;
          if (math.sin(a) > 0.3) continue;
          add(c + Offset(math.cos(a), math.sin(a)) * r, 2.2 * u);
        }
      case ProsceniumStyle.marquee:
        for (var x = l.pil + 10 * u; x < w - l.pil - 6 * u; x += 17 * u) {
          if ((x - w / 2).abs() < l.hdr * 0.6) continue;
          add(Offset(x, l.hdr - 6 * u), 2.8 * u);
        }
        for (var y = l.hdr + 10 * u; y < l.footTop - 8 * u; y += 19 * u) {
          add(Offset(l.pil * 0.5, y), 2.8 * u);
          add(Offset(w - l.pil * 0.5, y), 2.8 * u);
        }
      case ProsceniumStyle.noirArch || ProsceniumStyle.neon:
        break;
    }
    // Footlights.
    final n = math.max(3, stage.footlights);
    for (var i = 0; i < n; i++) {
      final x = w * (i + 0.5) / n;
      _foot.add(Offset(x, l.footTop + l.foot * (style == ProsceniumStyle.neon ? 0.2 : 0.34)));
    }
  }

  // ---------------------------------------------------------------------------
  // Static art.

  Picture _record(StageLayout l) {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    _apron(c, l);
    switch (style) {
      case ProsceniumStyle.picturePalace:
        _palace(c, l);
      case ProsceniumStyle.artDeco:
        _deco(c, l);
      case ProsceniumStyle.noirArch:
        _noir(c, l);
      case ProsceniumStyle.atomic:
        _atomic(c, l);
      case ProsceniumStyle.marquee:
        _marquee(c, l);
      case ProsceniumStyle.neon:
        _neonStatic(c, l);
    }
    _footHoods(c, l);
    return rec.endRecording();
  }

  final Paint _p = Paint()..isAntiAlias = true;

  void _fill(Canvas c, Path path, Shader shader) {
    _p
      ..shader = shader
      ..style = PaintingStyle.fill;
    c.drawPath(path, _p);
    _p.shader = null;
  }

  Shader _vertical(StageLayout l, List<Color> colors, [List<double>? stops]) =>
      Gradient.linear(Offset.zero, Offset(0, l.footTop), colors, stops);

  /// Body fill + the cast shadow the frame throws onto the stage.
  void _body(Canvas c, StageLayout l, List<Color> colors, [List<double>? stops]) {
    // Soft shadow inside the opening (depth).
    c
      ..save()
      ..translate(0, 3);
    Ornaments.line(c, l.rim, materials.ink.withValues(alpha: 0.28), 12 * l.width / 412);
    Ornaments.line(c, l.rim, materials.ink.withValues(alpha: 0.2), 6 * l.width / 412);
    c.restore();
    _fill(c, l.body, _vertical(l, colors, stops));
  }

  /// A bevelled rod along the opening.
  void _moulding(Canvas c, StageLayout l, double width, {Color? dark, Color? mid, Color? light}) {
    final m = materials;
    Ornaments.line(c, l.rim, m.ink, width + _lw * 2);
    Ornaments.line(c, l.rim, dark ?? m.giltDark, width);
    c
      ..save()
      ..translate(-width * 0.12, -width * 0.12);
    Ornaments.line(c, l.rim, mid ?? m.gilt, width * 0.62);
    c.translate(-width * 0.1, -width * 0.1);
    Ornaments.line(c, l.rim, (light ?? m.giltLight).withValues(alpha: 0.9), width * 0.2);
    c.restore();
  }

  /// Vertical rule down a pilaster.
  void _vrule(Canvas c, double x, double top, double bottom, Color color, double width) {
    Ornaments.line(c, Path()
      ..moveTo(x, top)
      ..lineTo(x, bottom), color, width, cap: StrokeCap.butt);
  }

  // --- 1920s picture palace ----------------------------------------------------

  void _palace(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.3, 1]);
    // Coffered header panels with rosettes.
    final top = l.hdr * 0.16, bottom = l.hdr * 0.62;
    final crestHalf = 58 * u;
    for (final side in const [-1, 1]) {
      final from = side < 0 ? l.pil + 6 * u : w / 2 + crestHalf;
      final to = side < 0 ? w / 2 - crestHalf : w - l.pil - 6 * u;
      final n = math.max(1, ((to - from) / (54 * u)).round());
      final pw = (to - from) / n;
      for (var i = 0; i < n; i++) {
        final r = Rect.fromLTWH(from + pw * i + 3 * u, top, pw - 6 * u, bottom - top);
        final rr = RRect.fromRectAndRadius(r, Radius.circular(3 * u));
        Ornaments.inked(c, Path()..addRRect(rr), m.wallDark, m.ink, _lw * 0.6);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * u
          ..color = m.gilt;
        c.drawRRect(rr.deflate(2.2 * u), _p);
        _p.style = PaintingStyle.fill;
        Ornaments.rosette(c, r.center, math.min(r.height, r.width) * 0.3, 8, fill: m.gilt, ink: m.ink, boss: m.giltLight, lineWidth: _lw * 0.5);
      }
    }
    // Egg-and-dart band under the panels.
    final band = Path();
    for (var x = l.pil + 4 * u; x < w - l.pil - 4 * u; x += 8 * u) {
      if ((x - w / 2).abs() < crestHalf - 6 * u) continue;
      band.addOval(Rect.fromCenter(center: Offset(x, l.hdr * 0.78), width: 5 * u, height: 6.5 * u));
    }
    Ornaments.inked(c, band, m.gilt, m.ink, _lw * 0.4);
    // Fluted pilasters with capitals and bases.
    for (final side in const [0, 1]) {
      final x0 = side == 0 ? 0.0 : w - l.pil;
      final r = Rect.fromLTRB(x0, l.hdr + l.drop - 4 * u, x0 + l.pil, l.footTop);
      for (var k = 1; k <= 3; k++) {
        final x = r.left + r.width * k / 4;
        _vrule(c, x + 0.8 * u, r.top + 18 * u, r.bottom - 16 * u, m.wallLight.withValues(alpha: 0.7), 1.4 * u);
        _vrule(c, x, r.top + 18 * u, r.bottom - 16 * u, m.wallDark, 1.6 * u);
      }
      final cap = Rect.fromLTWH(r.left - 1, r.top, r.width + 2, 14 * u);
      Ornaments.inked(c, Path()..addRect(cap), m.gilt, m.ink, _lw * 0.6);
      final vo = side == 0 ? 1.0 : -1.0;
      Ornaments.line(c, Ornaments.volute(Offset(cap.center.dx - 3 * u * vo, cap.center.dy + 1), 5 * u, vo), m.ink, 1.3 * u);
      final base = Rect.fromLTWH(r.left - 1, r.bottom - 14 * u, r.width + 2, 14 * u);
      Ornaments.inked(c, Path()..addRect(base), m.giltDark, m.ink, _lw * 0.6);
      _vrule(c, base.left, base.top + 4 * u, base.top + 4 * u, m.gilt, 1);
    }
    _moulding(c, l, 6.5 * u);
    // Beads just inside the arch.
    final beads = Path();
    for (var x = l.pil + 8 * u; x < w - l.pil - 8 * u; x += 7 * u) {
      if ((x - w / 2).abs() < 30 * u) continue;
      beads.addOval(Rect.fromCircle(center: Offset(x, l.rimTopAt(x) + 6.5 * u), radius: 1.5 * u));
    }
    Ornaments.inked(c, beads, m.giltLight, m.ink, _lw * 0.35);
    // Cartouche crest with laurels.
    final cc = Offset(w / 2, l.hdr * 0.62);
    for (final side in const [-1.0, 1.0]) {
      Ornaments.laurel(
        c,
        cc + Offset(side * 20 * u, 10 * u),
        cc + Offset(side * 58 * u, -4 * u),
        side * 0.18,
        6,
        fill: m.gilt,
        ink: m.ink,
        lineWidth: _lw * 0.6,
      );
    }
    final shield = Path()..addOval(Rect.fromCenter(center: cc, width: 44 * u, height: 40 * u));
    Ornaments.inked(c, shield, m.giltDark, m.ink, _lw);
    Ornaments.inked(c, Path()..addOval(Rect.fromCenter(center: cc, width: 36 * u, height: 32 * u)), m.wallDark, m.ink, _lw * 0.5);
    Ornaments.orbitEmblem(c, cc, 12 * u, ring: m.giltLight, planet: m.gilt, ink: m.ink, light: m.giltLight, lineWidth: 1.1 * u);
    // Keystone scrolls.
    Ornaments.line(c, Ornaments.volute(cc + Offset(-24 * u, 14 * u), 6 * u, -1), m.gilt, 2 * u);
    Ornaments.line(c, Ornaments.volute(cc + Offset(24 * u, 14 * u), 6 * u, 1), m.gilt, 2 * u);
  }

  // --- 1930s art deco ----------------------------------------------------------

  void _deco(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.25, 1]);
    // Speed lines across the header.
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < 3; k++) {
        final y = l.hdr * (0.26 + k * 0.17);
        final x0 = side < 0 ? l.pil * 0.4 : w / 2 + l.hdr * 1.12 + k * 6 * u;
        final x1 = side < 0 ? w / 2 - l.hdr * 1.12 - k * 6 * u : w - l.pil * 0.4;
        Ornaments.line(c, Path()
          ..moveTo(x0, y)
          ..lineTo(x1, y), m.ink, 3.4 * u, cap: StrokeCap.butt);
        Ornaments.line(c, Path()
          ..moveTo(x0, y)
          ..lineTo(x1, y), k == 1 ? m.giltLight : m.gilt, 1.6 * u, cap: StrokeCap.butt);
      }
    }
    // Stepped chrome fins on the pilasters.
    for (final side in const [0, 1]) {
      final x0 = side == 0 ? 0.0 : w - l.pil;
      final r = Rect.fromLTRB(x0, l.hdr + l.drop * 3, x0 + l.pil, l.footTop);
      _vrule(c, r.left + r.width * 0.16, r.top, r.bottom, m.gilt, 1.6 * u);
      _vrule(c, r.right - r.width * 0.16, r.top, r.bottom, m.gilt, 1.6 * u);
      _vrule(c, r.left + r.width * 0.16 + 1.2 * u, r.top, r.bottom, m.giltLight.withValues(alpha: 0.6), 0.7 * u);
      // Ziggurat cap.
      final zig = Path()
        ..moveTo(r.left, r.top + 12 * u)
        ..lineTo(r.left + r.width * 0.2, r.top + 12 * u)
        ..lineTo(r.left + r.width * 0.2, r.top + 6 * u)
        ..lineTo(r.left + r.width * 0.4, r.top + 6 * u)
        ..lineTo(r.left + r.width * 0.4, r.top)
        ..lineTo(r.right - r.width * 0.4, r.top)
        ..lineTo(r.right - r.width * 0.4, r.top + 6 * u)
        ..lineTo(r.right - r.width * 0.2, r.top + 6 * u)
        ..lineTo(r.right - r.width * 0.2, r.top + 12 * u)
        ..lineTo(r.right, r.top + 12 * u)
        ..lineTo(r.right, r.top + 16 * u)
        ..lineTo(r.left, r.top + 16 * u)
        ..close();
      Ornaments.inked(c, zig, m.gilt, m.ink, _lw * 0.6);
    }
    _moulding(c, l, 5.5 * u);
    // Sunburst fan and medallion at the apex.
    final cc = Offset(w / 2, l.hdr);
    Ornaments.sunburst(c, cc, l.hdr * 0.5, l.hdr * 1.02, 13, math.pi, math.pi, a: m.gilt, b: m.wallLight, ink: m.ink, lineWidth: _lw);
    final arc = Path()..addArc(Rect.fromCircle(center: cc, radius: l.hdr * 1.02), math.pi, math.pi);
    Ornaments.line(c, arc, m.ink, _lw * 2);
    final med = Path()..addOval(Rect.fromCircle(center: cc, radius: l.hdr * 0.46));
    Ornaments.inked(c, med, m.paper, m.ink, _lw * 1.4);
    Ornaments.line(c, Path()..addOval(Rect.fromCircle(center: cc, radius: l.hdr * 0.38)), m.ink, 1.2 * u);
    Ornaments.orbitEmblem(c, cc, l.hdr * 0.27, ring: m.paper, planet: m.gilt, ink: m.ink, light: m.giltLight, lineWidth: 1.2 * u);
    // Chevrons under the medallion.
    for (var k = 0; k < 2; k++) {
      final y = cc.dy + l.hdr * 0.5 + k * 5 * u;
      final chev = Path()
        ..moveTo(cc.dx - 10 * u, y)
        ..lineTo(cc.dx, y + 5 * u)
        ..lineTo(cc.dx + 10 * u, y);
      Ornaments.line(c, chev, m.ink, 3 * u);
      Ornaments.line(c, chev, m.gilt, 1.4 * u);
    }
  }

  // --- 1940s noir ---------------------------------------------------------------

  void _noir(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.35, 1]);
    // Venetian-blind light falling across the wall from the top left.
    c
      ..save()
      ..clipPath(l.body);
    final slat = Paint()..color = m.paper.withValues(alpha: 0.13);
    for (var k = 0; k < 9; k++) {
      final y = -30 * u + k * 16 * u;
      final p = Path()
        ..moveTo(-20 * u, y)
        ..lineTo(w * 0.62, y + w * 0.22)
        ..lineTo(w * 0.62, y + w * 0.22 + 8 * u)
        ..lineTo(-20 * u, y + 8 * u)
        ..close();
      c.drawPath(p, slat);
    }
    c.restore();
    // Sconces.
    for (final x in [l.pil * 0.5, w - l.pil * 0.5]) {
      final y = l.hdr + l.drop + 34 * u;
      final shade = Path()
        ..moveTo(x - 8 * u, y - 12 * u)
        ..lineTo(x + 8 * u, y - 12 * u)
        ..lineTo(x + 5 * u, y)
        ..lineTo(x - 5 * u, y)
        ..close();
      Ornaments.inked(c, shade, m.giltDark, m.ink, _lw * 0.6);
      _vrule(c, x, y, y + 10 * u, m.gilt, 1.6 * u);
    }
    _moulding(c, l, 4 * u);
    Ornaments.line(c, l.rim, m.gilt.withValues(alpha: 0.5), 0.8 * u);
    // A plain moderne medallion with long hairlines.
    final cc = Offset(w / 2, l.hdr * 0.56);
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < 2; k++) {
        final y = cc.dy - 3 * u + k * 6 * u;
        Ornaments.line(c, Path()
          ..moveTo(cc.dx + side * 24 * u, y)
          ..lineTo(cc.dx + side * (w * 0.36 - k * 14 * u), y), m.gilt.withValues(alpha: 0.8), 1.1 * u);
      }
    }
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: cc, radius: 18 * u)), m.wallDark, m.gilt, 1 * u);
    Ornaments.orbitEmblem(c, cc, 11 * u, ring: m.giltLight, planet: m.gilt, ink: m.ink, light: m.giltLight, lineWidth: 1 * u);
  }

  // --- 1950s atomic -------------------------------------------------------------

  void _atomic(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    final pal = skin.palette;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.4, 1]);
    // Boomerangs and sparkles on the wall (deterministic scatter).
    c
      ..save()
      ..clipPath(l.body);
    final rnd = math.Random(19);
    for (var k = 0; k < 16; k++) {
      final onHeader = k < 10;
      final x = onHeader ? l.pil + rnd.nextDouble() * (w - 2 * l.pil) : (k.isEven ? l.pil * 0.5 : w - l.pil * 0.5);
      final y = onHeader ? 6 * u + rnd.nextDouble() * (l.hdr - 14 * u) : l.hdr + 40 * u + rnd.nextDouble() * (l.footTop - l.hdr - 80 * u);
      if (onHeader && (x - w / 2).abs() < l.hdr * 0.95) continue;
      if (k.isEven) {
        final b = Path()
          ..moveTo(x - 7 * u, y + 2 * u)
          ..quadraticBezierTo(x, y - 7 * u, x + 7 * u, y + 2 * u)
          ..quadraticBezierTo(x, y - 2 * u, x - 7 * u, y + 2 * u)
          ..close();
        Ornaments.inked(c, b, k % 4 == 0 ? pal.accent : m.gilt, m.ink, _lw * 0.4);
      } else {
        Ornaments.inked(c, Ornaments.starPath(Offset(x, y), 5 * u, 1.3 * u, 4), m.paper, m.ink, _lw * 0.3);
      }
    }
    c.restore();
    // Coral band inside the gold rim.
    c
      ..save()
      ..translate(0, 0);
    Ornaments.line(c, l.rim, pal.accent, 10 * u);
    c.restore();
    _moulding(c, l, 5 * u);
    // Starburst crest with the orbit.
    final cc = Offset(w / 2, l.hdr * 0.5);
    Ornaments.inked(c, Ornaments.starPath(cc, l.hdr * 0.62, l.hdr * 0.3, 12), m.gilt, m.ink, _lw);
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: cc, radius: l.hdr * 0.3)), m.paper, m.ink, _lw);
    Ornaments.orbitEmblem(c, cc, l.hdr * 0.24, ring: pal.accent2, planet: pal.accent, ink: m.ink, light: m.paper, lineWidth: 1.2 * u);
    // Pilaster stripes.
    for (final x in [l.pil * 0.5, w - l.pil * 0.5]) {
      _vrule(c, x, l.hdr + l.drop + 8 * u, l.footTop - 6 * u, m.ink, 4.2 * u);
      _vrule(c, x, l.hdr + l.drop + 8 * u, l.footTop - 6 * u, pal.accent, 2.4 * u);
    }
  }

  // --- 1970s marquee ------------------------------------------------------------

  void _marquee(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    final pal = skin.palette;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.3, 1]);
    // 70s stripes across the header.
    final bands = [pal.accent, m.gilt, pal.accent2];
    for (var k = 0; k < 3; k++) {
      final r = Rect.fromLTRB(-2, l.hdr * (0.18 + k * 0.17), w + 2, l.hdr * (0.18 + k * 0.17) + l.hdr * 0.13);
      _p.color = bands[k];
      c.drawRect(r, _p);
    }
    // Peeling paint and scratches (deterministic).
    c
      ..save()
      ..clipPath(l.body);
    final rnd = math.Random(70);
    for (var k = 0; k < 14; k++) {
      final side = k.isEven;
      final x = k < 6 ? rnd.nextDouble() * w : (side ? rnd.nextDouble() * l.pil : w - rnd.nextDouble() * l.pil);
      final y = k < 6 ? rnd.nextDouble() * l.hdr : l.hdr + rnd.nextDouble() * (l.footTop - l.hdr);
      final r = (4 + rnd.nextDouble() * 7) * u;
      final chip = Path();
      for (var i = 0; i < 9; i++) {
        final a = math.pi * 2 * i / 9;
        final rr = r * (0.55 + 0.45 * rnd.nextDouble());
        final px = x + math.cos(a) * rr, py = y + math.sin(a) * rr * 0.7;
        i == 0 ? chip.moveTo(px, py) : chip.lineTo(px, py);
      }
      chip.close();
      Ornaments.inked(c, chip, m.wallLight.withValues(alpha: 0.85), m.wallDark, 0.6 * u);
    }
    final scratch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7 * u
      ..color = m.paper.withValues(alpha: 0.18);
    for (var k = 0; k < 10; k++) {
      final x = rnd.nextDouble() * w, y = rnd.nextDouble() * l.footTop;
      c.drawLine(Offset(x, y), Offset(x + (rnd.nextDouble() - 0.5) * 30 * u, y + 20 * u + rnd.nextDouble() * 40 * u), scratch);
    }
    c.restore();
    _moulding(c, l, 4.5 * u);
    // A "feature" badge crest.
    final cc = Offset(w / 2, l.hdr * 0.5);
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: cc, radius: l.hdr * 0.44)), pal.accent, m.ink, _lw);
    Ornaments.inked(c, Ornaments.starPath(cc, l.hdr * 0.33, l.hdr * 0.14, 5), m.paper, m.ink, _lw * 0.7);
  }

  // --- 1980s neon ---------------------------------------------------------------

  void _neonStatic(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width;
    final u = w / 412;
    _body(c, l, [m.wallLight, m.wall, m.wallDark], const [0, 0.3, 1]);
    // Synthwave sun on the horizon at the apex.
    final cc = Offset(w / 2, l.hdr - 1);
    final r = l.hdr * 0.78;
    c
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, w, l.hdr - 1));
    final sun = Paint()
      ..shader = Gradient.linear(cc - Offset(0, r), cc, [const Color(0xFFFFE08A), m.neonA, const Color(0xFF7A1FA8)], const [0, 0.55, 1]);
    c.drawCircle(cc, r, sun);
    // Cut stripes.
    final cut = Paint()..color = m.wall;
    for (var k = 0; k < 4; k++) {
      final y = cc.dy - r * (0.08 + k * 0.16);
      c.drawRect(Rect.fromLTRB(cc.dx - r, y - (1 + k * 0.7) * u, cc.dx + r, y + (1 + k * 0.7) * u), cut);
    }
    c.restore();
    // Perspective grid on the header.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * u
      ..color = m.neonB.withValues(alpha: 0.3);
    c
      ..save()
      ..clipPath(l.body);
    for (var k = 1; k < 4; k++) {
      final y = l.hdr * (0.2 + k * 0.2);
      c
        ..drawLine(Offset(0, y), Offset(cc.dx - r - 4 * u, y), grid)
        ..drawLine(Offset(cc.dx + r + 4 * u, y), Offset(w, y), grid);
    }
    for (var k = 0; k < 9; k++) {
      final x = w * k / 8;
      if ((x - w / 2).abs() < r + 4 * u) continue;
      c.drawLine(Offset(x, l.hdr), Offset(w / 2 + (x - w / 2) * 0.55, 0), grid);
    }
    c.restore();
    // Tube mounts (dark channels the tubes sit in).
    Ornaments.line(c, l.rim, const Color(0xFF000000).withValues(alpha: 0.6), 9 * u);
  }

  void _layoutNeon(StageLayout l) {
    _neonOuter.reset();
    _neonInner.reset();
    _neonSides.reset();
    _neonFoot.reset();
    if (style != ProsceniumStyle.neon) return;
    final u = l.width / 412;
    _neonOuter.addPath(l.rim, Offset(0, -3 * u));
    _neonInner.addPath(l.rim, Offset(0, 3 * u));
    for (final x in [l.pil * 0.5, l.width - l.pil * 0.5]) {
      _neonSides
        ..moveTo(x, l.hdr + 16 * u)
        ..lineTo(x, l.footTop - 10 * u);
    }
    _neonFoot
      ..moveTo(0, l.footTop + 4 * u)
      ..lineTo(l.width, l.footTop + 4 * u);
  }

  void _paintNeon(Canvas c, StageLayout l, double t, double pulse) {
    final m = materials;
    final u = l.width / 412;
    // Tubes buzz: a rare quick dip, per tube.
    double buzz(double seed) {
      if (reducedMotion) return 1;
      final k = (t * 11 + seed).floor();
      final h = _hash(k * 1.37 + seed);
      return h > 0.955 ? 0.35 : 0.92 + 0.08 * math.sin(t * 40 + seed);
    }

    // Clip the rim tubes so they read as bent glass inside the frame.
    Ornaments.neon(c, _neonOuter, m.neonA, 1.6 * u, intensity: buzz(1));
    Ornaments.neon(c, _neonInner, m.neonB, 1.4 * u, intensity: buzz(5));
    Ornaments.neon(c, _neonSides, m.neonA, 1.5 * u, intensity: buzz(9));
    Ornaments.neon(c, _neonFoot, m.neonB, 1.6 * u, intensity: (0.85 + 0.35 * pulse) * buzz(13));
    Ornaments.orbitEmblem(
      c,
      Offset(l.width / 2, l.hdr * 0.46),
      l.hdr * 0.3,
      ring: m.neonB,
      planet: m.neonA,
      ink: m.ink,
      lineWidth: 1.3 * u,
      neon: true,
    );
  }

  // --- The footlight lip --------------------------------------------------------

  void _apron(Canvas c, StageLayout l) {
    final m = materials;
    final w = l.width, h = l.height;
    final u = w / 412;
    final r = Rect.fromLTRB(0, l.footTop, w, h);
    _p.shader = Gradient.linear(r.topCenter, r.bottomCenter, [m.wall, m.wallDark]);
    c.drawRect(r, _p);
    _p.shader = null;
    // Stage floor lip.
    Ornaments.line(c, Path()
      ..moveTo(0, l.footTop + 1)
      ..lineTo(w, l.footTop + 1), m.ink, 4 * u, cap: StrokeCap.butt);
    if (style != ProsceniumStyle.neon) {
      Ornaments.line(c, Path()
        ..moveTo(0, l.footTop + 1)
        ..lineTo(w, l.footTop + 1), m.gilt, 2 * u, cap: StrokeCap.butt);
      // Apron front panel rule.
      Ornaments.line(c, Path()
        ..moveTo(0, l.footTop + l.foot * 0.78)
        ..lineTo(w, l.footTop + l.foot * 0.78), m.giltDark, 1.2 * u, cap: StrokeCap.butt);
    }
  }

  void _footHoods(Canvas c, StageLayout l) {
    if (style == ProsceniumStyle.neon) return;
    final m = materials;
    final u = l.width / 412;
    final n = _foot.length;
    final hw = math.min(l.width / n * 0.36, 17 * u);
    for (final b in _foot) {
      // A shell reflector opening upward, the bulb peeking over its lip.
      final base = Offset(b.dx, l.footTop + l.foot * 0.66);
      final shell = Path()
        ..moveTo(base.dx - hw, b.dy + 1 * u)
        ..quadraticBezierTo(base.dx - hw, base.dy + 5 * u, base.dx, base.dy + 5 * u)
        ..quadraticBezierTo(base.dx + hw, base.dy + 5 * u, base.dx + hw, b.dy + 1 * u)
        ..quadraticBezierTo(base.dx, b.dy + 5 * u, base.dx - hw, b.dy + 1 * u)
        ..close();
      Ornaments.inked(
        c,
        shell,
        m.gilt,
        m.ink,
        _lw * 0.7,
        shader: Gradient.linear(Offset(base.dx, b.dy), Offset(base.dx, base.dy + 5 * u), [m.giltLight, m.gilt, m.giltDark], const [0, 0.45, 1]),
      );
      // Ribs.
      for (var k = -2; k <= 2; k++) {
        Ornaments.line(c, Path()
          ..moveTo(base.dx + k * hw * 0.3, b.dy + 3.2 * u)
          ..lineTo(base.dx + k * hw * 0.12, base.dy + 3.6 * u), m.giltDark, 0.9 * u);
      }
    }
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
