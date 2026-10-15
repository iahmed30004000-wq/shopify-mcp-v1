import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/stage/stage_kit.dart';

/// The picture palace's own colours (the lobby is Madar Cinema's house
/// style; the posters bring each era's look).
abstract final class Lobby {
  static const wall = Color(0xFF2B0E14);
  static const wallDeep = Color(0xFF14060A);
  static const velvet = Color(0xFF8E1B2A);
  static const gold = Color(0xFFE4B862);
  static const goldLight = Color(0xFFFFE6A6);
  static const goldDark = Color(0xFF8A5A1E);
  static const cream = Color(0xFFF6E8C8);
  static const ink = Color(0xFF140A08);
  static const bulb = Color(0xFFFFF3CF);
  static const bulbOff = Color(0xFF6E4A2A);
  static const glow = Color(0xFFFFC46B);

  static const title = 'ReemKufi';
  static const body = 'PlexArabic';

  static TextStyle heading(double size, {Color color = cream}) =>
      TextStyle(fontFamily: title, fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.2);

  static TextStyle text(double size, {Color color = cream, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: weight, color: color, height: 1.4);
}

/// Damask-and-deco wallpaper of the lobby (static – paint it once behind a
/// RepaintBoundary): fans of gold between velvet stripes, a dado rail and a
/// dark wainscot at the foot, and a warm vignette.
class LobbyWallpaperPainter extends CustomPainter {
  const LobbyWallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          [Lobby.wallDeep, Lobby.wall, Lobby.wallDeep],
          const [0, 0.35, 1],
        ),
    );
    // Velvet stripes.
    final stripe = Paint()..color = const Color(0x14FF6A7A);
    for (var x = 0.0; x < size.width; x += 56) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 22, size.height), stripe);
    }
    // Deco fans in a half-drop repeat.
    final fan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Lobby.gold.withValues(alpha: 0.09);
    for (var row = 0; row * 64.0 < size.height + 64; row++) {
      for (var col = -1; col * 56.0 < size.width + 56; col++) {
        final c = Offset(col * 56.0 + (row.isOdd ? 28 : 0) + 11, row * 64.0 + 40);
        for (var k = 1; k <= 3; k++) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: k * 7.0), math.pi, math.pi, false, fan);
        }
        for (var k = 0; k < 5; k++) {
          final a = math.pi + math.pi * (k + 0.5) / 5;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 21, fan);
        }
      }
    }
    // Vignette.
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          r.center,
          size.longestSide * 0.75,
          [const Color(0x00000000), const Color(0xAA000000)],
          const [0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant LobbyWallpaperPainter oldDelegate) => false;
}

/// The palace's marquee: a deco sign with a stepped crest and the orbit
/// emblem, ringed with chasing bulbs, and searchlights sweeping the night
/// behind it. [t] = seconds (0 under reduced motion: bulbs steady).
class MarqueeSignPainter extends CustomPainter {
  MarqueeSignPainter({required this.t, required this.signRect, super.repaint});

  final ValueGetter<double> t;

  /// The board's rect inside the painter.
  final Rect Function(Size size) signRect;
  final BulbAtlas _atlas = BulbAtlas(capacity: 120);
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final time = t();
    final r = Offset.zero & size;
    // Night sky with a few stars.
    canvas.drawRect(
      r,
      _p
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          [const Color(0xFF07040E), const Color(0xFF1A0A18), const Color(0x002B0E14)],
          const [0, 0.6, 1],
        ),
    );
    _p.shader = null;
    final rnd = math.Random(5);
    for (var i = 0; i < 36; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.55);
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(time * (1 + rnd.nextDouble() * 2) + i));
      _p.color = Lobby.cream.withValues(alpha: 0.6 * tw);
      canvas.drawCircle(o, 0.6 + rnd.nextDouble(), _p);
    }
    // Searchlights.
    for (final side in const [-1.0, 1.0]) {
      final base = Offset(size.width / 2 + side * size.width * 0.42, size.height);
      final a = -math.pi / 2 + side * (0.35 + 0.25 * math.sin(time * 0.5 + (side > 0 ? 1.7 : 0)));
      canvas
        ..save()
        ..translate(base.dx, base.dy)
        ..rotate(a + math.pi / 2);
      final beam = Path()
        ..moveTo(-5, 0)
        ..lineTo(-38, -size.height * 1.3)
        ..lineTo(38, -size.height * 1.3)
        ..lineTo(5, 0)
        ..close();
      _p
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, -size.height * 1.3), [
          const Color(0x55FFE9B8),
          const Color(0x00FFE9B8),
        ])
        ..blendMode = BlendMode.plus;
      canvas.drawPath(beam, _p);
      _p
        ..shader = null
        ..blendMode = BlendMode.srcOver;
      canvas.restore();
    }
    final b = signRect(size);
    // Stepped crest.
    final crest = Path()
      ..moveTo(b.center.dx - 58, b.top + 2)
      ..lineTo(b.center.dx - 58, b.top - 12)
      ..lineTo(b.center.dx - 38, b.top - 12)
      ..lineTo(b.center.dx - 38, b.top - 24)
      ..lineTo(b.center.dx - 18, b.top - 24)
      ..lineTo(b.center.dx - 18, b.top - 34)
      ..lineTo(b.center.dx + 18, b.top - 34)
      ..lineTo(b.center.dx + 18, b.top - 24)
      ..lineTo(b.center.dx + 38, b.top - 24)
      ..lineTo(b.center.dx + 38, b.top - 12)
      ..lineTo(b.center.dx + 58, b.top - 12)
      ..lineTo(b.center.dx + 58, b.top + 2)
      ..close();
    Ornaments.inked(canvas, crest, Lobby.gold, Lobby.ink, 1.6);
    Ornaments.sunburst(
      canvas,
      Offset(b.center.dx, b.top - 2),
      10,
      30,
      11,
      math.pi,
      math.pi,
      a: Lobby.goldLight,
      b: Lobby.goldDark,
      ink: Lobby.ink,
      lineWidth: 0.8,
    );
    // Board.
    final board = RRect.fromRectAndRadius(b, const Radius.circular(14));
    _p.color = Lobby.ink;
    canvas.drawRRect(board.shift(const Offset(0, 5)), _p);
    _p.shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [const Color(0xFF6A1422), const Color(0xFF3C0A12)]);
    canvas.drawRRect(board, _p);
    _p.shader = null;
    Ornaments.line(canvas, Path()..addRRect(board), Lobby.ink, 7);
    Ornaments.line(canvas, Path()..addRRect(board), Lobby.gold, 4);
    Ornaments.line(canvas, Path()..addRRect(board.deflate(11)), Lobby.goldDark, 1.2);
    // Emblem medallion on the crest.
    final med = Offset(b.center.dx, b.top - 6);
    Ornaments.inked(canvas, Path()..addOval(Rect.fromCircle(center: med, radius: 17)), Lobby.cream, Lobby.ink, 1.6);
    Ornaments.orbitEmblem(
      canvas,
      med,
      10.5,
      ring: Lobby.velvet,
      planet: Lobby.gold,
      ink: Lobby.ink,
      light: Lobby.goldLight,
      lineWidth: 1,
    );
    // Chasing bulbs round the board.
    _atlas.begin();
    final rr = b.deflate(5.5);
    final per = 2 * (rr.width + rr.height);
    final n = (per / 17).floor();
    for (var i = 0; i < n; i++) {
      var d = per * i / n;
      Offset c;
      if (d < rr.width) {
        c = Offset(rr.left + d, rr.top);
      } else if ((d -= rr.width) < rr.height) {
        c = Offset(rr.right, rr.top + d);
      } else if ((d -= rr.height) < rr.width) {
        c = Offset(rr.right - d, rr.bottom);
      } else {
        d -= rr.width;
        c = Offset(rr.left, rr.bottom - d);
      }
      final lit = time == 0 ? 0.9 : (((i + (time * 7).floor()) % 3 == 0) ? 1.0 : 0.4);
      _atlas.add(c, 3.3, lit, Lobby.bulb, Lobby.bulbOff, halo: Lobby.glow, haloRadius: 3.3 * (2.6 + 3 * lit));
    }
    _atlas.flush(canvas);
  }

  @override
  bool shouldRepaint(covariant MarqueeSignPainter oldDelegate) => false;

  /// Frees the bulb sprite.
  void dispose() => _atlas.dispose();
}

/// A lit poster case: gilt frame, glass sheen, corner bulbs and a pool of
/// light below. [lit] 0..1 (the centred poster of a carousel is lit).
class PosterCasePainter extends CustomPainter {
  PosterCasePainter({this.lit = 1, this.inset = 10});

  final double lit;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint();
    // Glow on the wall.
    p.shader = ui.Gradient.radial(r.center, size.longestSide * 0.62, [
      Lobby.glow.withValues(alpha: 0.28 * lit),
      Lobby.glow.withValues(alpha: 0),
    ]);
    canvas.drawRect(r.inflate(24), p);
    p.shader = null;
    final frame = RRect.fromRectAndRadius(r, const Radius.circular(6));
    p.color = Lobby.ink;
    canvas.drawRRect(frame.shift(const Offset(0, 6)), p);
    p.shader = ui.Gradient.linear(
      r.topLeft,
      r.bottomRight,
      [Lobby.goldLight, Lobby.gold, Lobby.goldDark, Lobby.gold],
      const [0, 0.3, 0.7, 1],
    );
    canvas.drawRRect(frame, p);
    p.shader = null;
    Ornaments.line(canvas, Path()..addRRect(frame), Lobby.ink, 1.6);
    Ornaments.line(canvas, Path()..addRRect(frame.deflate(inset - 2)), Lobby.ink, 1.6);
    Ornaments.line(canvas, Path()..addRRect(frame.deflate(3)), Lobby.goldLight.withValues(alpha: 0.7), 0.8);
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final o = c + Offset(c.dx < r.center.dx ? inset / 2 : -inset / 2, c.dy < r.center.dy ? inset / 2 : -inset / 2);
      p.color = Lobby.glow.withValues(alpha: 0.5 * lit);
      canvas.drawCircle(o, 7, p);
      p.color = Color.lerp(Lobby.bulbOff, Lobby.bulb, lit)!;
      canvas.drawCircle(o, 3.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant PosterCasePainter old) => old.lit != lit || old.inset != inset;
}

/// Glass sheen over a poster.
class GlassSheenPainter extends CustomPainter {
  const GlassSheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.2, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(r.topLeft, r.centerRight, [const Color(0x22FFFFFF), const Color(0x00FFFFFF)]),
    );
  }

  @override
  bool shouldRepaint(covariant GlassSheenPainter oldDelegate) => false;
}

/// A ticket-stub shape (notched ends) for chips and the ticket book.
class TicketPainter extends CustomPainter {
  const TicketPainter({
    required this.fill,
    required this.ink,
    this.notch = 6,
    this.perforation = true,
    this.shadow = true,
  });

  final Color fill;
  final Color ink;
  final double notch;
  final bool perforation;
  final bool shadow;

  static Path shape(Rect r, double notch) {
    final n = notch;
    return Path()
      ..moveTo(r.left + 5, r.top)
      ..lineTo(r.right - 5, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + 5)
      ..lineTo(r.right, r.center.dy - n)
      ..arcToPoint(Offset(r.right, r.center.dy + n), radius: Radius.circular(n), clockwise: false)
      ..lineTo(r.right, r.bottom - 5)
      ..quadraticBezierTo(r.right, r.bottom, r.right - 5, r.bottom)
      ..lineTo(r.left + 5, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 5)
      ..lineTo(r.left, r.center.dy + n)
      ..arcToPoint(Offset(r.left, r.center.dy - n), radius: Radius.circular(n), clockwise: false)
      ..lineTo(r.left, r.top + 5)
      ..quadraticBezierTo(r.left, r.top, r.left + 5, r.top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1);
    final path = shape(r, notch);
    final p = Paint();
    if (shadow) {
      p.color = Lobby.ink.withValues(alpha: 0.6);
      canvas.drawPath(path.shift(const Offset(0, 3)), p);
    }
    p.color = fill;
    canvas.drawPath(path, p);
    Ornaments.line(canvas, path, ink, 1.4);
    if (perforation && size.width > 60) {
      p.color = ink.withValues(alpha: 0.45);
      for (final x in [r.left + 10.0, r.right - 10.0]) {
        for (var y = r.top + 5; y < r.bottom - 3; y += 5) {
          if ((y - r.center.dy).abs() < notch + 1) continue;
          canvas.drawCircle(Offset(x, y), 0.9, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TicketPainter old) => old.fill != fill || old.ink != ink || old.notch != notch;
}
