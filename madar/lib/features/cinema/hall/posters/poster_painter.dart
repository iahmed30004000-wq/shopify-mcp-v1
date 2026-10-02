import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import '../../engine/stage/stage_kit.dart';

/// A movie one-sheet for a programme entry, drawn in code in its era's
/// style and starring its cast member from the rig kit:
///
/// | era | poster |
/// |---|---|
/// | 1920s | sepia card, stepped towers and crossing searchlights, a great clock face, ornate frame, title on a dark band |
/// | 1930s | halftone sky, ringed planets and winking stars, the hero mid-flap, a cartoon title ribbon |
/// | 1940s | night, a huge moon over rooftops, rain and blind-slat light, a hairline title |
/// | 1950s | sunburst over dunes, a far caravan, block-shadowed Technicolor title |
/// | 1970s | faded, creased print, bold slanted title over stripes |
/// | 1980s | VHS sleeve: neon grid, striped sun, souk arches in neon, chrome title, rainbow spine |
///
/// Unplayable entries wear a "coming soon" sash; a best score shows as a
/// gold seal. Painted in a 300 × 450 design space scaled to the size – the
/// painter allocates freely (it runs once behind a RepaintBoundary).
class PosterPainter extends CustomPainter {
  PosterPainter({
    required this.entry,
    required this.l10n,
    this.best,
    this.direction = TextDirection.rtl,
    this.compact = false,
  });

  final GameCatalogEntry entry;
  final L10n l10n;

  /// Formatted best score (null hides the seal).
  final String? best;
  final TextDirection direction;

  /// Small shelf poster: no tagline, bigger title.
  final bool compact;

  static const Size design = Size(300, 450);

  EraSkin get skin => EraSkins.of(entry.era);
  StageMaterials get m => StageMaterials.of(skin);
  EraPalette get pal => skin.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / design.width;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(4 * k)))
      ..scale(k, size.height / design.height);
    final art = _artId();
    switch (entry.era) {
      case Era.silent:
        _silent(canvas, art, k);
      case Era.rubberHose:
        _rubberHose(canvas, art, k);
      case Era.noir:
        _noir(canvas, art, k);
      case Era.technicolor:
        _technicolor(canvas, art, k);
      case Era.grindhouse:
        _grindhouse(canvas, art, k);
      case Era.vhs:
        _vhs(canvas, art, k);
    }
    if (best != null) _seal(canvas, best!);
    if (!entry.isPlayable) _sash(canvas);
    canvas.restore();
  }

  String _artId() => entry.id;

  // ---------------------------------------------------------------------------
  // Shared pieces.

  final Paint _p = Paint()..isAntiAlias = true;

  void _fill(Canvas c, Rect r, Shader shader) {
    _p.shader = shader;
    c.drawRect(r, _p);
    _p.shader = null;
  }

  TextPainter _text(
    String text,
    TextStyle style, {
    double maxWidth = 270,
    int maxLines = 2,
    TextAlign align = TextAlign.center,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Paints [tp] centred at [c].
  void _center(Canvas c, TextPainter tp, Offset at) => tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));

  String get _title => entry.title(l10n);
  String get _tagline => entry.tagline(l10n);

  /// The star of the picture from the rig cast (or a genre motif).
  void _star(
    Canvas c,
    Offset feet,
    double height,
    RigAction action,
    double k, {
    RigExpression? expression,
    double facing = 1,
    double t = 0.42,
  }) {
    CastMember? member;
    for (final mbr in RigCast.all) {
      if (mbr.gameId == entry.id) member = mbr;
    }
    if (member == null) {
      _motif(c, feet - Offset(0, height / 2), height);
      return;
    }
    final rig = member.build(height: height);
    rig
      ..facing = facing
      ..act(action);
    if (expression != null) rig.expression = expression;
    for (var i = 0; i < 6; i++) {
      rig.update(t / 6);
    }
    final clock = FilmClock(boilFps: 12, projectionFps: skin.grade.projectionFps, seed: 3)..advance(3 / 12 + 0.01);
    final ctx = RigPaintContext(skin: skin, clock: clock)..pixelScale = k;
    c
      ..save()
      ..translate(feet.dx, feet.dy);
    rig.paint(c, ctx);
    c.restore();
    rig.dispose();
  }

  /// Motif for entries without a cast member (Tier 2 genres).
  void _motif(Canvas c, Offset centre, double size) {
    final ink = m.ink;
    final lw = 2.4;
    switch (entry.genre) {
      case GameGenre.card:
        for (var i = -1; i <= 1; i++) {
          c
            ..save()
            ..translate(centre.dx, centre.dy + size * 0.2)
            ..rotate(i * 0.3)
            ..translate(0, -size * 0.25);
          final card = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: size * 0.42, height: size * 0.6),
            const Radius.circular(8),
          );
          Ornaments.inked(c, Path()..addRRect(card), pal.paper, ink, lw);
          final suit = i == 0
              ? Ornaments.starPath(Offset.zero, size * 0.1, size * 0.045, 4)
              : (Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: size * 0.07)));
          Ornaments.inked(c, suit, i == 0 ? pal.accent : ink, ink, 0);
          c.restore();
        }
      case GameGenre.board:
        final r = Rect.fromCenter(center: centre, width: size * 0.8, height: size * 0.8);
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < 4; x++) {
            _p.color = (x + y).isEven ? pal.paper : pal.shadow;
            c.drawRect(
              Rect.fromLTWH(r.left + r.width * x / 4, r.top + r.height * y / 4, r.width / 4, r.height / 4),
              _p,
            );
          }
        }
        Ornaments.line(c, Path()..addRect(r), ink, lw);
      case GameGenre.word:
        final letters = ['م', 'د', 'ا', 'ر'];
        for (var i = 0; i < 4; i++) {
          final tile = Rect.fromCenter(
            center: centre + Offset((i - 1.5) * size * 0.26, (i.isEven ? -1 : 1) * size * 0.05),
            width: size * 0.23,
            height: size * 0.23,
          );
          Ornaments.inked(
            c,
            Path()..addRRect(RRect.fromRectAndRadius(tile, const Radius.circular(5))),
            pal.paper,
            ink,
            lw,
          );
          _center(
            c,
            _text(letters[i], TextStyle(fontFamily: 'ReemKufi', fontSize: size * 0.15, color: ink)),
            tile.center,
          );
        }
      default:
        Ornaments.orbitEmblem(
          c,
          centre,
          size * 0.4,
          ring: m.gilt,
          planet: pal.accent,
          ink: ink,
          light: pal.highlight,
          lineWidth: 3,
        );
    }
  }

  /// A gold seal with the best score.
  void _seal(Canvas c, String score) {
    final centre = Offset(direction == TextDirection.rtl ? 250 : 50, 392);
    Ornaments.inked(c, Ornaments.starPath(centre, 38, 32, 18), m.gilt, m.ink, 1.6);
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: centre, radius: 27)), m.giltLight, m.ink, 1);
    final tp = _text(
      l10n.cinemaHallBestBadge(score),
      TextStyle(fontFamily: 'PlexArabic', fontSize: 12.5, fontWeight: FontWeight.w700, color: m.ink, height: 1.1),
      maxWidth: 50,
    );
    _center(c, tp, centre);
  }

  /// "Coming soon" sash across the bottom end corner (clear of the title).
  void _sash(Canvas c) {
    final rtl = direction == TextDirection.rtl;
    c
      ..save()
      ..translate(rtl ? 58 : 242, 392)
      ..rotate(rtl ? math.pi / 4 : -math.pi / 4);
    final band = Rect.fromCenter(center: Offset.zero, width: 250, height: 34);
    _p.color = m.ink.withValues(alpha: 0.5);
    c.drawRect(band.shift(const Offset(0, 3)), _p);
    _p.color = skin.era.isMonochrome ? m.paper : pal.accent;
    c.drawRect(band, _p);
    Ornaments.line(
      c,
      Path()
        ..moveTo(band.left, band.top + 4)
        ..lineTo(band.right, band.top + 4)
        ..moveTo(band.left, band.bottom - 4)
        ..lineTo(band.right, band.bottom - 4),
      m.ink,
      1.2,
    );
    final color = skin.era.isMonochrome ? m.ink : pal.paper;
    _center(
      c,
      _text(
        l10n.cinemaComingSoon,
        TextStyle(fontFamily: 'ReemKufi', fontSize: 17, fontWeight: FontWeight.w700, color: color),
      ),
      Offset.zero,
    );
    c.restore();
  }

  /// Studio billing: the orbit emblem and the house name.
  void _billing(Canvas c, Offset at, Color ink, {Color? accent}) {
    Ornaments.orbitEmblem(
      c,
      at - const Offset(0, 1),
      7,
      ring: accent ?? ink,
      planet: ink,
      ink: ink.withValues(alpha: 0),
      lineWidth: 1,
    );
    final tp = _text(
      '${l10n.cinemaTitle}  ·  ${entry.era.label(l10n)}',
      TextStyle(fontFamily: 'PlexArabic', fontSize: 9.5, color: ink, letterSpacing: 0.2),
    );
    _center(c, tp, at + const Offset(0, 14));
  }

  void _grainVignette(Canvas c, {double strength = 0.45, Color? tint}) {
    final r = Offset.zero & design;
    _fill(
      c,
      r,
      ui.Gradient.radial(
        r.center,
        300,
        [const Color(0x00000000), (tint ?? m.ink).withValues(alpha: strength)],
        const [0.55, 1],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1920s silent.

  void _silent(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    _fill(
      c,
      r,
      ui.Gradient.linear(
        r.topCenter,
        r.bottomCenter,
        [const Color(0xFFEFDDB6), const Color(0xFFD7BD8E), const Color(0xFFB99A6C)],
        const [0, 0.6, 1],
      ),
    );
    // Searchlights crossing behind the towers.
    for (final (x, a) in const [(60.0, -0.35), (240.0, 0.4), (150.0, 0.05)]) {
      c
        ..save()
        ..translate(x, 330)
        ..rotate(a);
      final beam = Path()
        ..moveTo(-6, 0)
        ..lineTo(-46, -330)
        ..lineTo(46, -330)
        ..lineTo(6, 0)
        ..close();
      _p.shader = ui.Gradient.linear(Offset.zero, const Offset(0, -330), [
        const Color(0x88FFF6DE),
        const Color(0x00FFF6DE),
      ]);
      c.drawPath(beam, _p);
      _p.shader = null;
      c.restore();
    }
    // A great clock face.
    final clockC = const Offset(150, 150);
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: clockC, radius: 92)), const Color(0xFFE9D8B2), m.ink, 2);
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + math.pi * 2 * i / 10;
      final d = Offset(math.cos(a), math.sin(a));
      Ornaments.line(
        c,
        Path()
          ..moveTo(clockC.dx + d.dx * 78, clockC.dy + d.dy * 78)
          ..lineTo(clockC.dx + d.dx * 88, clockC.dy + d.dy * 88),
        m.ink,
        i == 0 ? 4 : 2,
      );
    }
    // Stepped towers.
    final rnd = math.Random(27);
    for (var layer = 0; layer < 2; layer++) {
      final base = layer == 0 ? 300.0 : 330.0;
      final color = layer == 0 ? const Color(0xFF8C6E4C) : const Color(0xFF4A3524);
      var x = -10.0;
      while (x < 310) {
        final w = 26 + rnd.nextDouble() * 34;
        final h = (layer == 0 ? 120 : 70) + rnd.nextDouble() * (layer == 0 ? 110 : 80);
        final top = base - h;
        final tower = Path()
          ..moveTo(x, base + 40)
          ..lineTo(x, top + 18)
          ..lineTo(x + w * 0.18, top + 18)
          ..lineTo(x + w * 0.18, top + 8)
          ..lineTo(x + w * 0.36, top + 8)
          ..lineTo(x + w * 0.36, top)
          ..lineTo(x + w * 0.64, top)
          ..lineTo(x + w * 0.64, top + 8)
          ..lineTo(x + w * 0.82, top + 8)
          ..lineTo(x + w * 0.82, top + 18)
          ..lineTo(x + w, top + 18)
          ..lineTo(x + w, base + 40)
          ..close();
        Ornaments.inked(c, tower, color, m.ink, 1);
        _p.color = const Color(0xFFFFE9B0).withValues(alpha: layer == 0 ? 0.55 : 0.8);
        for (var wy = top + 26; wy < base - 4; wy += 11) {
          for (var wx = x + 5; wx < x + w - 6; wx += 8) {
            if (rnd.nextDouble() < 0.45) c.drawRect(Rect.fromLTWH(wx, wy, 3, 5), _p);
          }
        }
        x += w + 2;
      }
    }
    _star(c, const Offset(150, 342), 236, RigAction.taunt, k, expression: RigExpression.angry);
    _grainVignette(c, strength: 0.5, tint: const Color(0xFF2B1B10));
    // Title band.
    final band = const Rect.fromLTWH(0, 340, 300, 110);
    _p.color = const Color(0xF22B1B10);
    c.drawRect(band, _p);
    Ornaments.line(
      c,
      Path()
        ..moveTo(16, 348)
        ..lineTo(284, 348),
      const Color(0xFFE9D3A0),
      1.2,
    );
    final title = _text(
      _title,
      TextStyle(
        fontFamily: 'Amiri',
        fontSize: compact ? 40 : 34,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF3E4C0),
        height: 1.15,
      ),
    );
    _center(c, title, Offset(150, compact ? 392 : 380));
    if (!compact) {
      _center(
        c,
        _text(_tagline, const TextStyle(fontFamily: 'Amiri', fontSize: 12.5, color: Color(0xFFD9C29A))),
        const Offset(150, 412),
      );
      _billing(c, const Offset(150, 426), const Color(0xFFBFA57C));
    }
    // Ornate double frame with corner fleurons.
    final f1 = const Rect.fromLTWH(7, 7, 286, 436);
    Ornaments.line(c, Path()..addRect(f1), const Color(0xFF2B1B10), 3);
    Ornaments.line(c, Path()..addRect(f1.deflate(5)), const Color(0xFFE9D3A0), 1);
    for (final corner in [f1.topLeft, f1.topRight, f1.bottomLeft, f1.bottomRight]) {
      Ornaments.inked(c, Ornaments.starPath(corner, 9, 3, 4), const Color(0xFFE9D3A0), const Color(0xFF2B1B10), 1);
    }
  }

  // ---------------------------------------------------------------------------
  // 1930s rubber hose.

  void _rubberHose(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    final ink = m.ink;
    _fill(c, r, ui.Gradient.linear(r.topCenter, r.bottomCenter, [const Color(0xFFF7F3E8), const Color(0xFFDCD6C8)]));
    _halftone(c, r, const Offset(150, 470), const Offset(150, 40), 0.75, 0.05, k);
    if (art == 'demo') {
      _demoSet(c, k);
    } else {
      // A planet's curved horizon below, ringed planets and stars above,
      // the hero mid-flap with speed lines.
      final horizon = Path()
        ..moveTo(-10, 450)
        ..lineTo(-10, 356)
        ..quadraticBezierTo(150, 300, 310, 356)
        ..lineTo(310, 450)
        ..close();
      Ornaments.inked(c, horizon, pal.midtone, ink, 3);
      c
        ..save()
        ..clipPath(horizon);
      _p.color = pal.shadow;
      for (final (o, rr) in const [
        (Offset(60, 380), 16.0),
        (Offset(200, 372), 11.0),
        (Offset(250, 410), 20.0),
        (Offset(110, 430), 12.0),
      ]) {
        c.drawOval(Rect.fromCenter(center: o, width: rr * 2.4, height: rr), _p);
      }
      c.restore();
      _planet(c, const Offset(58, 140), 36, 0.2, k);
      _planet(c, const Offset(252, 232), 25, -0.4, k);
      _planet(c, const Offset(240, 128), 11, 0.1, k, ring: false);
      for (final (p, s) in const [
        (Offset(124, 118), 11.0),
        (Offset(34, 262), 9.0),
        (Offset(278, 300), 8.0),
        (Offset(190, 150), 7.0),
        (Offset(96, 330), 7.0),
      ]) {
        Ornaments.inked(c, Ornaments.starPath(p, s, s * 0.45, 5), pal.paper, ink, 2);
      }
      for (var i = 0; i < 4; i++) {
        final y = 232.0 + i * 15;
        Ornaments.line(
          c,
          Path()
            ..moveTo(40 + i * 7, y)
            ..lineTo(92 + i * 5, y),
          ink,
          3.4,
        );
      }
      _star(c, const Offset(162, 318), 168, RigAction.jump, k, expression: RigExpression.happy);
    }
    // Cartoon title ribbon at the top.
    _ribbon(c, _title, top: 22, ink: ink, face: pal.paper);
    if (!compact) {
      _center(c, _text(_tagline, TextStyle(fontFamily: 'ReemKufi', fontSize: 13, color: ink)), const Offset(150, 404));
      _billing(c, const Offset(150, 420), ink);
    }
    // Rounded white border, thick ink.
    final f = RRect.fromRectAndRadius(r.deflate(6), const Radius.circular(18));
    final outer = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(r)
      ..addRRect(f);
    _p.color = pal.paper;
    c.drawPath(outer, _p);
    Ornaments.line(c, Path()..addRRect(f), ink, 4);
    _grainVignette(c, strength: 0.3);
  }

  void _halftone(Canvas c, Rect r, Offset from, Offset to, double toneFrom, double toneTo, double k) {
    final program = CinemaShaders.program(CinemaShader.halftone);
    if (program == null) return;
    final s = program.fragmentShader();
    HalftoneUniforms.write(
      s,
      from: from,
      to: to,
      ink: m.ink.withValues(alpha: 0.5),
      style: skin.halftone,
      toneFrom: toneFrom,
      toneTo: toneTo,
      pixelScale: k,
    );
    _p
      ..shader = s
      ..color = const Color(0xFFFFFFFF);
    c.drawRect(r, _p);
    _p.shader = null;
    s.dispose();
  }

  void _planet(Canvas c, Offset o, double r, double tilt, double k, {bool ring = true}) {
    final ink = m.ink;
    final body = Path()..addOval(Rect.fromCircle(center: o, radius: r));
    if (ring) {
      c
        ..save()
        ..translate(o.dx, o.dy)
        ..rotate(tilt);
      final back = Path()
        ..addArc(Rect.fromCenter(center: Offset.zero, width: r * 3.4, height: r * 0.9), math.pi, math.pi);
      Ornaments.line(c, back, ink, 7);
      Ornaments.line(c, back, pal.midtone, 3.5);
      c.restore();
    }
    Ornaments.inked(c, body, pal.midtone, ink, 2.4);
    // Shadow crescent.
    c
      ..save()
      ..clipPath(body);
    _p.color = pal.shadow;
    c.drawCircle(o + Offset(r * 0.45, r * 0.4), r, _p);
    _p.color = pal.highlight;
    c.drawCircle(o - Offset(r * 0.35, r * 0.4), r * 0.18, _p);
    c.restore();
    Ornaments.line(c, body, ink, 2.4);
    if (ring) {
      c
        ..save()
        ..translate(o.dx, o.dy)
        ..rotate(tilt);
      final front = Path()..addArc(Rect.fromCenter(center: Offset.zero, width: r * 3.4, height: r * 0.9), 0, math.pi);
      Ornaments.line(c, front, ink, 7);
      Ornaments.line(c, front, pal.paper, 3.5);
      c.restore();
    }
  }

  void _demoSet(Canvas c, double k) {
    final ink = m.ink;
    // A little stage with a spotlight pool and two barrels.
    _p.shader = ui.Gradient.radial(const Offset(150, 300), 120, [
      pal.highlight.withValues(alpha: 0.9),
      pal.highlight.withValues(alpha: 0),
    ]);
    c.drawOval(Rect.fromCenter(center: const Offset(150, 300), width: 250, height: 70), _p);
    _p.shader = null;
    Ornaments.line(
      c,
      Path()
        ..moveTo(10, 300)
        ..lineTo(290, 300),
      ink,
      3,
    );
    for (final (x, rot) in const [(58.0, 0.3), (246.0, -0.2)]) {
      c
        ..save()
        ..translate(x, 280)
        ..rotate(rot);
      final barrel = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 20));
      Ornaments.inked(c, barrel, pal.midtone, ink, 2.4);
      for (var i = 0; i < 6; i++) {
        final a = math.pi * i / 3;
        Ornaments.line(
          c,
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a) * 18, math.sin(a) * 18),
          ink,
          1.6,
        );
      }
      c.restore();
    }
    _star(c, const Offset(150, 300), 150, RigAction.cheer, k, expression: RigExpression.happy);
  }

  /// A curved ribbon banner carrying the title.
  void _ribbon(Canvas c, String text, {required double top, required Color ink, required Color face}) {
    final tp = _text(
      text,
      TextStyle(
        fontFamily: 'ReemKufi',
        fontSize: compact ? 38 : 32,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.1,
      ),
      maxWidth: 230,
    );
    final h = tp.height + 18;
    final band = Path()
      ..moveTo(28, top + 10)
      ..quadraticBezierTo(150, top - 6, 272, top + 10)
      ..lineTo(272, top + 10 + h)
      ..quadraticBezierTo(150, top - 6 + h, 28, top + 10 + h)
      ..close();
    for (final side in const [-1.0, 1.0]) {
      final x = side < 0 ? 28.0 : 272.0;
      final tail = Path()
        ..moveTo(x, top + 22)
        ..lineTo(x + side * 22, top + 22)
        ..lineTo(x + side * 12, top + 22 + h * 0.5)
        ..lineTo(x + side * 22, top + 22 + h)
        ..lineTo(x, top + 22 + h)
        ..close();
      Ornaments.inked(c, tail, pal.midtone, ink, 2.4);
    }
    Ornaments.inked(c, band.shift(const Offset(0, 4)), ink, ink, 0);
    Ornaments.inked(c, band, face, ink, 2.6);
    _center(c, tp, Offset(150, top + 4 + h / 2));
  }

  // ---------------------------------------------------------------------------
  // 1940s noir.

  void _noir(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    _fill(c, r, ui.Gradient.linear(r.topCenter, r.bottomCenter, [const Color(0xFF2A2A31), const Color(0xFF0B0B0E)]));
    // The moon.
    _p.shader = ui.Gradient.radial(const Offset(196, 130), 120, [const Color(0x55F1ECDD), const Color(0x00F1ECDD)]);
    c.drawCircle(const Offset(196, 130), 120, _p);
    _p.shader = null;
    _p.color = const Color(0xFFEDE8DA);
    c.drawCircle(const Offset(196, 130), 62, _p);
    _p.color = const Color(0xFFD6D1C3);
    for (final (o, rr) in const [(Offset(176, 116), 9.0), (Offset(214, 148), 13.0), (Offset(206, 104), 5.0)]) {
      c.drawCircle(o, rr, _p);
    }
    // Rooftops.
    final roofs = Path()
      ..moveTo(0, 330)
      ..lineTo(0, 262)
      ..lineTo(46, 262)
      ..lineTo(46, 240)
      ..lineTo(60, 240)
      ..lineTo(60, 262)
      ..lineTo(98, 262)
      ..lineTo(122, 238)
      ..lineTo(146, 262)
      ..lineTo(168, 262)
      ..lineTo(168, 250)
      ..lineTo(232, 250)
      ..lineTo(232, 214)
      ..lineTo(238, 214)
      ..lineTo(238, 250)
      ..lineTo(300, 250)
      ..lineTo(300, 330)
      ..close();
    _p.color = const Color(0xFF050506);
    c.drawPath(roofs, _p);
    // Water tower.
    final tower = Path()
      ..addRect(const Rect.fromLTWH(254, 196, 30, 30))
      ..moveTo(252, 196)
      ..lineTo(269, 184)
      ..lineTo(286, 196)
      ..close()
      ..addRect(const Rect.fromLTWH(258, 226, 3, 24))
      ..addRect(const Rect.fromLTWH(277, 226, 3, 24));
    c.drawPath(tower, _p);
    // A few lit windows.
    _p.color = const Color(0xFFE9E2C8);
    for (final w in const [
      Rect.fromLTWH(14, 280, 6, 9),
      Rect.fromLTWH(182, 272, 6, 9),
      Rect.fromLTWH(206, 290, 6, 9),
      Rect.fromLTWH(74, 296, 6, 9),
    ]) {
      c.drawRect(w, _p);
    }
    _star(c, const Offset(118, 262), 108, RigAction.walk, k, expression: RigExpression.sly);
    // Rain.
    final rain = Paint()
      ..color = const Color(0x55DADAE2)
      ..strokeWidth = 1;
    final rnd = math.Random(40);
    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * 320 - 10, y = rnd.nextDouble() * 330;
      c.drawLine(Offset(x, y), Offset(x - 5, y + 16), rain);
    }
    // Blind-slat light across.
    final slat = Paint()..color = const Color(0x16FFFFFF);
    for (var i = 0; i < 7; i++) {
      final y = 20.0 + i * 26;
      c.drawPath(
        Path()
          ..moveTo(-10, y)
          ..lineTo(310, y + 90)
          ..lineTo(310, y + 102)
          ..lineTo(-10, y + 12)
          ..close(),
        slat,
      );
    }
    // Title.
    _p.color = const Color(0xFF09090B);
    c.drawRect(const Rect.fromLTWH(0, 330, 300, 120), _p);
    final title = _text(
      _title,
      TextStyle(
        fontFamily: 'ReemKufi',
        fontSize: compact ? 38 : 32,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFEDE8DA),
      ),
    );
    _center(c, title, Offset(150, compact ? 385 : 368));
    Ornaments.line(
      c,
      Path()
        ..moveTo(40, compact ? 414 : 393)
        ..lineTo(260, compact ? 414 : 393),
      const Color(0xFFBDBAB0),
      0.8,
    );
    if (!compact) {
      _center(
        c,
        _text(_tagline, const TextStyle(fontFamily: 'PlexArabic', fontSize: 11.5, color: Color(0xFFAAA8A0))),
        const Offset(150, 408),
      );
      _billing(c, const Offset(150, 424), const Color(0xFF8E8C86));
    }
    Ornaments.line(c, Path()..addRect(r.deflate(8)), const Color(0x88EDE8DA), 0.8);
    _grainVignette(c, strength: 0.55, tint: const Color(0xFF000000));
  }

  // ---------------------------------------------------------------------------
  // 1950s Technicolor.

  void _technicolor(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    final ink = m.ink;
    // Sunburst.
    const sun = Offset(150, 250);
    _fill(c, r, ui.Gradient.linear(r.topCenter, r.bottomCenter, [const Color(0xFFFFB347), const Color(0xFFFF7A3D)]));
    for (var i = 0; i < 24; i++) {
      if (i.isOdd) continue;
      final a0 = math.pi * 2 * i / 24, a1 = math.pi * 2 * (i + 1) / 24;
      final ray = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(a0) * 520, sun.dy + math.sin(a0) * 520)
        ..lineTo(sun.dx + math.cos(a1) * 520, sun.dy + math.sin(a1) * 520)
        ..close();
      _p.color = const Color(0x55FFE08A);
      c.drawPath(ray, _p);
    }
    Ornaments.inked(c, Path()..addOval(Rect.fromCircle(center: sun, radius: 58)), const Color(0xFFFFE08A), ink, 2.4);
    // Dunes.
    final far = Path()
      ..moveTo(0, 262)
      ..quadraticBezierTo(80, 222, 160, 258)
      ..quadraticBezierTo(240, 290, 300, 246)
      ..lineTo(300, 450)
      ..lineTo(0, 450)
      ..close();
    Ornaments.inked(c, far, const Color(0xFFE9A15A), ink, 2.2);
    // A caravan far away.
    _p.color = ink;
    for (var i = 0; i < 4; i++) {
      final x = 196.0 + i * 16;
      final y = 262.0 + i * 2;
      c
        ..drawOval(Rect.fromCenter(center: Offset(x, y), width: 11, height: 6), _p)
        ..drawRect(Rect.fromLTWH(x - 4, y + 2, 1.4, 6), _p)
        ..drawRect(Rect.fromLTWH(x + 3, y + 2, 1.4, 6), _p)
        ..drawCircle(Offset(x + 6, y - 4), 2, _p);
    }
    final near = Path()
      ..moveTo(0, 318)
      ..quadraticBezierTo(110, 286, 200, 318)
      ..quadraticBezierTo(262, 338, 300, 312)
      ..lineTo(300, 450)
      ..lineTo(0, 450)
      ..close();
    Ornaments.inked(c, near, const Color(0xFFF6C27A), ink, 2.4);
    // A palm.
    final trunk = Path()
      ..moveTo(40, 318)
      ..quadraticBezierTo(30, 260, 50, 214);
    Ornaments.line(c, trunk, ink, 7);
    Ornaments.line(c, trunk, const Color(0xFF9C6B3C), 4);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * 0.95 + i * 0.45;
      final leaf = Path()
        ..moveTo(50, 214)
        ..quadraticBezierTo(
          50 + math.cos(a) * 30,
          214 + math.sin(a) * 30 - 10,
          50 + math.cos(a) * 46,
          214 + math.sin(a) * 46 + 6,
        );
      Ornaments.line(c, leaf, ink, 6);
      Ornaments.line(c, leaf, pal.accent2, 3.5);
    }
    _star(c, const Offset(168, 344), 124, RigAction.run, k, expression: RigExpression.determined);
    // Block-shadowed title.
    final style = TextStyle(
      fontFamily: 'ReemKufi',
      fontSize: compact ? 42 : 38,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final shadow = _text(_title, style.copyWith(color: pal.accent2));
    final outline = _text(
      _title,
      style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..color = ink,
      ),
    );
    final face = _text(_title, style.copyWith(color: pal.accent));
    final at = Offset(150, compact ? 70 : 62);
    for (var i = 5; i >= 1; i--) {
      _center(c, shadow, at + Offset(i * 1.0, i * 1.2));
    }
    _center(c, outline, at);
    _center(c, face, at);
    if (!compact) {
      final tag = const Rect.fromLTWH(30, 392, 240, 26);
      Ornaments.inked(c, Path()..addRRect(RRect.fromRectAndRadius(tag, const Radius.circular(13))), pal.paper, ink, 2);
      _center(
        c,
        _text(
          _tagline,
          TextStyle(fontFamily: 'PlexArabic', fontSize: 11.5, fontWeight: FontWeight.w600, color: ink),
          maxWidth: 226,
          maxLines: 1,
        ),
        tag.center,
      );
      _billing(c, const Offset(150, 426), ink, accent: pal.accent);
    }
    final f = r.deflate(6);
    final border = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(r)
      ..addRRect(RRect.fromRectAndRadius(f, const Radius.circular(10)));
    _p.color = pal.paper;
    c.drawPath(border, _p);
    Ornaments.line(c, Path()..addRRect(RRect.fromRectAndRadius(f, const Radius.circular(10))), pal.accent, 2.6);
    _grainVignette(c, strength: 0.18);
  }

  // ---------------------------------------------------------------------------
  // 1970s grindhouse.

  void _grindhouse(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    final ink = m.ink;
    _fill(c, r, ui.Gradient.linear(r.topLeft, r.bottomRight, [const Color(0xFFE9C9A0), const Color(0xFFC98A5A)]));
    for (var i = 0; i < 3; i++) {
      _p.color = [pal.accent, m.gilt, pal.accent2][i];
      c
        ..save()
        ..translate(150, 200)
        ..rotate(-0.25)
        ..drawRect(Rect.fromLTWH(-260, -120.0 + i * 26, 520, 18), _p)
        ..restore();
    }
    _star(c, const Offset(150, 330), 150, RigAction.taunt, k);
    final style = TextStyle(
      fontFamily: 'PlexArabic',
      fontSize: compact ? 40 : 36,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );
    c
      ..save()
      ..translate(150, 380)
      ..rotate(-0.07);
    _center(c, _text(_title, style.copyWith(color: ink)), const Offset(3, 3));
    _center(c, _text(_title, style.copyWith(color: pal.paper)), Offset.zero);
    c.restore();
    // Creases and torn corners.
    final crease = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.5;
    c
      ..drawLine(const Offset(150, 0), const Offset(150, 450), crease)
      ..drawLine(const Offset(0, 225), const Offset(300, 225), crease);
    _p.color = const Color(0xFF1E120C);
    c.drawPath(
      Path()
        ..moveTo(300, 0)
        ..lineTo(262, 0)
        ..lineTo(276, 12)
        ..lineTo(284, 10)
        ..lineTo(300, 36)
        ..close(),
      _p,
    );
    _grainVignette(c, strength: 0.5, tint: const Color(0xFF3A1A0A));
  }

  // ---------------------------------------------------------------------------
  // 1980s VHS sleeve.

  void _vhs(Canvas c, String art, double k) {
    final r = Offset.zero & design;
    _fill(
      c,
      r,
      ui.Gradient.linear(
        r.topCenter,
        r.bottomCenter,
        [const Color(0xFF07030F), const Color(0xFF1B0B3A), const Color(0xFF07030F)],
        const [0, 0.55, 1],
      ),
    );
    // Stars.
    final rnd = math.Random(80);
    _p.color = const Color(0xCCFFFFFF);
    for (var i = 0; i < 40; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * 300, rnd.nextDouble() * 200), rnd.nextDouble() * 1.1 + 0.2, _p);
    }
    // Striped sun on the horizon.
    const horizon = 262.0;
    const sun = Offset(150, horizon);
    c
      ..save()
      ..clipRect(const Rect.fromLTWH(0, 0, 300, horizon));
    _p.shader = ui.Gradient.linear(
      const Offset(150, horizon - 96),
      const Offset(150, horizon),
      [const Color(0xFFFFE08A), m.neonA, const Color(0xFF7A1FA8)],
      const [0, 0.55, 1],
    );
    c.drawCircle(sun, 96, _p);
    _p.shader = null;
    _p.color = const Color(0xFF14082B);
    for (var i = 0; i < 6; i++) {
      final y = horizon - 8 - i * 13.0;
      c.drawRect(Rect.fromLTWH(40, y - (3.5 - i * 0.5), 220, 7 - i * 1.0), _p);
    }
    c.restore();
    // Souk arches in neon on both sides.
    for (final (x, w, h) in const [(24.0, 44.0, 96.0), (78.0, 36.0, 76.0), (276.0, 44.0, 96.0), (222.0, 36.0, 76.0)]) {
      final arch = Path()
        ..moveTo(x - w / 2, horizon)
        ..lineTo(x - w / 2, horizon - h * 0.55)
        ..quadraticBezierTo(x - w / 2, horizon - h * 0.95, x, horizon - h)
        ..quadraticBezierTo(x + w / 2, horizon - h * 0.95, x + w / 2, horizon - h * 0.55)
        ..lineTo(x + w / 2, horizon);
      _p.color = const Color(0xFF0B0518);
      c.drawPath(Path.from(arch)..close(), _p);
      Ornaments.neon(c, arch, x < 150 ? m.neonB : m.neonA, 1.4);
    }
    // Neon grid floor.
    final grid = Paint()
      ..color = m.neonA.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      final y = horizon + (450 - horizon) * t * t;
      c.drawLine(Offset(0, y), Offset(300, y), grid);
    }
    for (var i = -8; i <= 8; i++) {
      c.drawLine(Offset(150 + i * 6.0, horizon), Offset(150 + i * 60.0, 450), grid);
    }
    _star(c, const Offset(150, 340), 120, RigAction.run, k, expression: RigExpression.determined);
    // Chrome title.
    final style = TextStyle(
      fontFamily: 'PlexArabic',
      fontSize: compact ? 38 : 32,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final glow = _text(
      _title,
      style.copyWith(
        color: m.neonA,
        shadows: [Shadow(color: m.neonA, blurRadius: 14)],
      ),
      maxWidth: 232,
    );
    final chrome = _text(
      _title,
      style.copyWith(
        foreground: Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 40),
            const Offset(0, 100),
            [const Color(0xFFFFFFFF), const Color(0xFF8FE9FF), const Color(0xFF2A1060), const Color(0xFFFFB6F0)],
            const [0, 0.45, 0.5, 1],
          ),
      ),
      maxWidth: 232,
    );
    final at = Offset(150, compact ? 76 : 70);
    _center(c, glow, at);
    _center(c, chrome, at);
    if (!compact) {
      _center(
        c,
        _text(_tagline, TextStyle(fontFamily: 'PlexArabic', fontSize: 11.5, color: m.neonB)),
        const Offset(150, 404),
      );
      _billing(c, const Offset(150, 422), m.neonB, accent: m.neonA);
    }
    // Rainbow spine at the start edge.
    final rtl = direction == TextDirection.rtl;
    final bars = [const Color(0xFFFF2E97), const Color(0xFFFF9F1C), const Color(0xFFFFE066), const Color(0xFF19E3FF)];
    for (var i = 0; i < 4; i++) {
      _p.color = bars[i];
      c.drawRect(Rect.fromLTWH(rtl ? 300 - 6.0 * (i + 1) : 6.0 * i, 0, 6, 450), _p);
    }
    _grainVignette(c, strength: 0.4, tint: const Color(0xFF000000));
  }

  @override
  bool shouldRepaint(covariant PosterPainter old) =>
      old.entry.id != entry.id ||
      old.best != best ||
      old.l10n != l10n ||
      old.direction != direction ||
      old.compact != compact;
}

/// What a locked slot promises (a glyph over its drawn curtains).
enum LockedGlyph { star, cards, board, arcade, puzzle, word }

/// A locked "coming attraction" slot: a poster case with its little
/// curtains drawn (velvet from curtain.frag), a glyph of the kind of show
/// that is coming, and a plaque.
class LockedSlotPainter extends CustomPainter {
  LockedSlotPainter({
    required this.label,
    required this.seed,
    this.glyph = LockedGlyph.star,
    this.direction = TextDirection.rtl,
  });

  final String label;
  final int seed;
  final LockedGlyph glyph;
  final TextDirection direction;

  static const _eras = [Era.technicolor, Era.grindhouse, Era.vhs];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final skin = EraSkins.of(_eras[seed % _eras.length]);
    final m = StageMaterials.of(EraSkins.of(Era.technicolor));
    final p = Paint();
    final program = CinemaShaders.program(CinemaShader.curtain);
    final clock = FilmClock(seed: seed.toDouble())..advance(0.2);
    void panel(Rect rect, CurtainPanel side, int folds) {
      if (program != null) {
        final s = program.fragmentShader();
        CurtainUniforms.write(
          s,
          rect: rect,
          palette: skin.palette,
          panel: side,
          clock: clock,
          folds: folds,
          swayPhase: seed * 1.3,
          sheen: 0.6,
          footlight: 0.5,
        );
        p.shader = s;
        canvas.drawRect(rect, p);
        p.shader = null;
        s.dispose();
      } else {
        p.color = skin.palette.curtain;
        canvas.drawRect(rect, p);
      }
    }

    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    panel(Rect.fromLTWH(0, 0, size.width / 2 + 2, size.height), CurtainPanel.left, 4);
    panel(Rect.fromLTWH(size.width / 2 - 2, 0, size.width / 2 + 2, size.height), CurtainPanel.right, 4);
    panel(Rect.fromLTWH(0, -4, size.width, size.height * 0.16), CurtainPanel.valance, 3);
    // Glyph medallion.
    final gc = r.center - Offset(0, size.height * 0.2);
    Ornaments.inked(
      canvas,
      Path()..addOval(Rect.fromCircle(center: gc, radius: 22)),
      m.ink.withValues(alpha: 0.55),
      m.gilt,
      1.2,
    );
    _glyph(canvas, gc, m);
    // Plaque.
    final plaque = Rect.fromCenter(
      center: r.center + Offset(0, size.height * 0.08),
      width: size.width * 0.8,
      height: 28,
    );
    Ornaments.inked(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(plaque, const Radius.circular(6))),
      m.gilt,
      m.ink,
      1.4,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'ReemKufi',
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1D1A2B),
        ),
      ),
      textDirection: direction,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: plaque.width - 10);
    tp.paint(canvas, plaque.center - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }

  void _glyph(Canvas c, Offset o, StageMaterials m) {
    final gold = m.giltLight;
    final ink = m.ink;
    switch (glyph) {
      case LockedGlyph.star:
        Ornaments.inked(c, Ornaments.starPath(o, 13, 6, 5), gold, ink, 1.2);
      case LockedGlyph.cards:
        for (var i = -1; i <= 1; i++) {
          c
            ..save()
            ..translate(o.dx, o.dy + 10)
            ..rotate(i * 0.35)
            ..translate(0, -10);
          Ornaments.inked(
            c,
            Path()..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 13, height: 18),
                const Radius.circular(2),
              ),
            ),
            gold,
            ink,
            1,
          );
          c.restore();
        }
        Ornaments.inked(c, Ornaments.starPath(o + const Offset(0, -1), 4, 1.8, 4), ink, ink, 0);
      case LockedGlyph.board:
        final p = Paint();
        for (var y = 0; y < 3; y++) {
          for (var x = 0; x < 3; x++) {
            p.color = (x + y).isEven ? gold : ink;
            c.drawRect(Rect.fromLTWH(o.dx - 12 + x * 8, o.dy - 12 + y * 8, 8, 8), p);
          }
        }
        Ornaments.line(c, Path()..addRect(Rect.fromCenter(center: o, width: 24, height: 24)), ink, 1.2);
      case LockedGlyph.arcade:
        final snake = Path();
        const cells = [(-2, -1), (-1, -1), (0, -1), (0, 0), (1, 0), (2, 0), (2, 1)];
        for (final (x, y) in cells) {
          snake.addRect(Rect.fromLTWH(o.dx + x * 6 - 3, o.dy + y * 6 - 3, 5.5, 5.5));
        }
        Ornaments.inked(c, snake, gold, ink, 0.6);
        Ornaments.inked(
          c,
          Path()..addOval(Rect.fromCircle(center: o + const Offset(-10, 9), radius: 2.5)),
          m.neonA,
          ink,
          0.6,
        );
      case LockedGlyph.puzzle:
        for (var i = 0; i < 3; i++) {
          final x = i % 2, y = i ~/ 2;
          Ornaments.inked(
            c,
            Path()..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(o.dx - 11 + x * 11, o.dy - 11 + y * 11, 10, 10),
                const Radius.circular(2),
              ),
            ),
            gold,
            ink,
            0.8,
          );
        }
      case LockedGlyph.word:
        Ornaments.inked(
          c,
          Path()..addRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 22, height: 22), const Radius.circular(3)),
          ),
          gold,
          ink,
          1,
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: 'ض',
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1A2B),
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        tp.paint(c, o - Offset(tp.width / 2, tp.height / 2 + 1));
    }
  }

  @override
  bool shouldRepaint(covariant LockedSlotPainter old) => old.label != label || old.seed != seed || old.glyph != glyph;
}
