import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'astrolabe_ticks_painter.dart';
import 'islamic_star_painter.dart';

/// Colours used by the empty-state illustrations (resolved from tokens by
/// the widget layer, so the painters stay theme-agnostic).
@immutable
class EmptyIllustrationColors {
  const EmptyIllustrationColors({
    required this.gold,
    required this.brass,
    required this.brassDark,
    required this.glow,
    required this.star,
    required this.line,
    required this.glass,
    required this.accent,
  });

  final Color gold;
  final Color brass;
  final Color brassDark;
  final Color glow;
  final Color star;
  final Color line;
  final Color glass;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is EmptyIllustrationColors &&
      other.gold == gold &&
      other.brass == brass &&
      other.brassDark == brassDark &&
      other.glow == glow &&
      other.star == star &&
      other.line == line &&
      other.glass == glass &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(gold, brass, brassDark, glow, star, line, glass, accent);
}

double _wave(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t);

void _sparkle(Canvas canvas, Offset c, double r, Color color, {double glow = 0}) {
  if (glow > 0) {
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.35 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.4),
    );
  }
  canvas.drawPath(
    IslamicGeometry.starPath(center: c, radius: r, points: 4, innerRatio: 0.28),
    Paint()..color = color,
  );
}

/// Base class: every illustration loops on [phase] (0..1) and repaints
/// itself from the animation (no widget rebuilds).
abstract class EmptyIllustrationPainter extends CustomPainter {
  EmptyIllustrationPainter({required this.phase, required this.colors, this.textDirection = TextDirection.rtl})
      : super(repaint: phase);

  final Animation<double> phase;
  final EmptyIllustrationColors colors;
  final TextDirection textDirection;

  @override
  bool shouldRepaint(covariant EmptyIllustrationPainter old) =>
      old.phase != phase || old.colors != colors || old.textDirection != textDirection;
}

/// Empty list: a golden crescent rocking gently while small stars drift
/// past, with a moonlet tracing a faint orbit.
class CrescentStarsPainter extends EmptyIllustrationPainter {
  CrescentStarsPainter({required super.phase, required super.colors, super.textDirection});

  static const _stars = <(double, double, double, double)>[
    // x, y (0..1), size, phase offset
    (0.16, 0.22, 1.0, 0.00),
    (0.82, 0.16, 0.8, 0.31),
    (0.90, 0.58, 1.1, 0.57),
    (0.10, 0.70, 0.7, 0.12),
    (0.30, 0.90, 0.9, 0.73),
    (0.72, 0.88, 0.6, 0.44),
    (0.58, 0.08, 0.7, 0.86),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = phase.value;
    final s = size.shortestSide;
    final c = size.center(Offset.zero) + Offset(0, s * 0.02);
    final r = s * 0.27;

    // Halo.
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()..shader = ui.Gradient.radial(c, r * 1.9, [colors.glow.withValues(alpha: 0.32), colors.glow.withValues(alpha: 0)]),
    );

    // Orbit ellipse with a travelling moonlet.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.21);
    final orbit = Rect.fromCenter(center: Offset.zero, width: s * 0.94, height: s * 0.3);
    canvas.drawOval(
      orbit,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, s * 0.006),
    );
    final oa = 2 * math.pi * t;
    final moonlet = Offset(math.cos(oa) * orbit.width / 2, math.sin(oa) * orbit.height / 2);
    final behind = math.sin(oa) < 0;
    canvas.restore();

    void drawMoonlet() {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.21);
      canvas.drawCircle(
        moonlet,
        s * 0.022,
        Paint()..color = colors.star.withValues(alpha: behind ? 0.35 : 0.95),
      );
      canvas.restore();
    }

    if (behind) drawMoonlet();

    // Crescent, rocking slowly.
    final rock = math.sin(2 * math.pi * t) * 0.09;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rock - 0.35);
    final outer = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    final bite = Path()..addOval(Rect.fromCircle(center: Offset(r * 0.42, -r * 0.1), radius: r * 0.84));
    final crescent = Path.combine(PathOperation.difference, outer, bite);
    canvas.drawPath(
      crescent,
      Paint()
        ..color = colors.glow.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..shader = ui.Gradient.linear(Offset(-r, -r), Offset(r * 0.2, r), [colors.gold, colors.brass]),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..color = colors.star.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, s * 0.005),
    );
    // The star held in the crescent's embrace.
    final pulse = 0.85 + 0.15 * _wave(t * 3);
    final starC = Offset(r * 0.5, -r * 0.08);
    canvas.drawCircle(
      starC,
      r * 0.34,
      Paint()
        ..color = colors.glow.withValues(alpha: 0.4 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
    );
    canvas.drawPath(
      IslamicGeometry.starPath(center: starC, radius: r * 0.2 * pulse, points: 8, rotation: -rock + 0.35),
      Paint()..color = colors.star,
    );
    canvas.restore();

    if (!behind) drawMoonlet();

    // Drifting stars: each rises and fades on its own loop.
    for (final star in _stars) {
      final local = (t * 2 + star.$4) % 1;
      final fade = math.sin(math.pi * local);
      final p = Offset(star.$1 * size.width, star.$2 * size.height) + Offset(-s * 0.05 * local, -s * 0.08 * local);
      _sparkle(canvas, p, s * 0.028 * star.$3 * (0.7 + 0.3 * fade), colors.star.withValues(alpha: 0.9 * fade), glow: fade);
    }
  }
}

/// No data yet: a tiny brass astrolabe whose alidade sweeps the scale while
/// the rete turns slowly.
class AstrolabeNeedlePainter extends EmptyIllustrationPainter {
  AstrolabeNeedlePainter({required super.phase, required super.colors, super.textDirection});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = phase.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.44;

    // Soft glow and mater (the body).
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()..shader = ui.Gradient.radial(c, r * 1.25, [colors.glow.withValues(alpha: 0.22), colors.glow.withValues(alpha: 0)]),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c - Offset(r * 0.3, r * 0.35),
          r * 1.4,
          [colors.brass.withValues(alpha: 0.28), colors.brassDark.withValues(alpha: 0.18)],
        ),
    );
    // Throne (the hanging ring) at the top.
    final throne = c - Offset(0, r * 1.08);
    canvas.drawCircle(
      throne,
      r * 0.09,
      Paint()
        ..color = colors.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035,
    );
    // Metallic limb.
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..shader = ui.Gradient.sweep(
          c,
          [colors.gold, colors.brassDark, colors.gold, colors.brass, colors.gold],
          const [0, 0.3, 0.55, 0.8, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05,
    );
    AstrolabeTicksPainter.paintScale(
      canvas,
      center: c,
      radius: r * 0.94,
      color: colors.brass,
      majorColor: colors.gold,
      minorStep: 5,
      midStep: 15,
      majorStep: 45,
      showNumerals: false,
    );

    // Rete: a star web turning slowly.
    final reteRot = 2 * math.pi * t;
    final rete = Paint()
      ..color = colors.gold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.018);
    canvas.drawPath(
      IslamicGeometry.starPath(center: c, radius: r * 0.62, points: 8, rotation: reteRot),
      rete,
    );
    canvas.drawCircle(c + Offset(math.cos(reteRot) * r * 0.16, math.sin(reteRot) * r * 0.16), r * 0.4, rete..color = colors.gold.withValues(alpha: 0.45));

    // Alidade: sweeps back and forth with an eased swing.
    final swing = math.sin(2 * math.pi * t * 2);
    final eased = swing * (1.2 - 0.2 * swing.abs());
    final a = -math.pi / 2 + eased * 1.05;
    final dir = Offset(math.cos(a), math.sin(a));
    final n = Offset(-dir.dy, dir.dx);
    final len = r * 0.86;
    final needle = Path()
      ..moveTo(c.dx + dir.dx * len, c.dy + dir.dy * len)
      ..lineTo(c.dx + n.dx * r * 0.05, c.dy + n.dy * r * 0.05)
      ..lineTo(c.dx - dir.dx * len * 0.55, c.dy - dir.dy * len * 0.55)
      ..lineTo(c.dx - n.dx * r * 0.05, c.dy - n.dy * r * 0.05)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = colors.brassDark.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
    canvas.drawPath(
      needle,
      Paint()..shader = ui.Gradient.linear(c + dir * len, c - dir * len * 0.55, [colors.gold, colors.brass]),
    );
    // Glowing sight at the needle tip.
    final tip = c + dir * len * 0.93;
    canvas.drawCircle(
      tip,
      r * 0.09,
      Paint()
        ..color = colors.glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );
    canvas.drawCircle(tip, r * 0.035, Paint()..color = colors.star);

    // Pin.
    canvas.drawCircle(c, r * 0.07, Paint()..color = colors.brassDark);
    canvas.drawCircle(c, r * 0.045, Paint()..color = colors.gold);
  }
}

/// No search results: a brass lens drifting over a starfield, magnifying
/// the stars beneath it with a reticle.
class TelescopeScanPainter extends EmptyIllustrationPainter {
  TelescopeScanPainter({required super.phase, required super.colors, super.textDirection});

  static final List<(double, double, double)> _field = () {
    final rnd = math.Random(11);
    return List.generate(26, (_) => (rnd.nextDouble(), rnd.nextDouble(), 0.4 + rnd.nextDouble() * 0.6));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = phase.value;
    final s = size.shortestSide;
    final rtl = textDirection == TextDirection.rtl;

    Offset starAt((double, double, double) st) =>
        Offset(size.width * (0.08 + st.$1 * 0.84), size.height * (0.1 + st.$2 * 0.8));

    // Background field.
    for (var i = 0; i < _field.length; i++) {
      final st = _field[i];
      final tw = 0.55 + 0.45 * _wave(t * 3 + i * 0.137);
      canvas.drawCircle(starAt(st), s * 0.008 * st.$3 + 0.4, Paint()..color = colors.star.withValues(alpha: 0.55 * tw * st.$3));
    }

    // Lens path: a slow lissajous sweep.
    final lr = s * 0.23;
    final lc = Offset(
      size.width / 2 + size.width * 0.17 * math.sin(2 * math.pi * t) * (rtl ? -1 : 1),
      size.height * 0.46 + size.height * 0.1 * math.sin(4 * math.pi * t + math.pi / 3),
    );

    // Handle (bottom-end).
    final hd = Offset(rtl ? -0.7071 : 0.7071, 0.7071);
    final h0 = lc + hd * lr * 1.02;
    final h1 = lc + hd * lr * 1.95;
    canvas.drawLine(
      h0,
      h1,
      Paint()
        ..shader = ui.Gradient.linear(h0, h1, [colors.brass, colors.brassDark])
        ..strokeWidth = lr * 0.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      h0 + hd * lr * 0.1,
      h0 + hd * lr * 0.22,
      Paint()
        ..color = colors.gold
        ..strokeWidth = lr * 0.26
        ..strokeCap = StrokeCap.butt,
    );

    // Lens interior: glass tint + magnified stars.
    final lens = Path()..addOval(Rect.fromCircle(center: lc, radius: lr));
    canvas.save();
    canvas.clipPath(lens);
    canvas.drawCircle(
      lc,
      lr,
      Paint()..shader = ui.Gradient.radial(lc - Offset(lr * 0.3, lr * 0.3), lr * 1.3, [colors.glass, colors.glass.withValues(alpha: 0.05)]),
    );
    const mag = 1.9;
    for (var i = 0; i < _field.length; i++) {
      final st = _field[i];
      final p = lc + (starAt(st) - lc) * mag;
      if ((p - lc).distance > lr * 1.1) continue;
      final tw = 0.7 + 0.3 * _wave(t * 3 + i * 0.137);
      _sparkle(canvas, p, (s * 0.012 * st.$3 + 1.2) * mag, colors.star.withValues(alpha: 0.95 * tw), glow: 0.8);
    }
    // Reticle.
    final ret = Paint()
      ..color = colors.accent.withValues(alpha: 0.55)
      ..strokeWidth = math.max(0.5, s * 0.004);
    canvas.drawLine(lc - Offset(lr * 0.75, 0), lc - Offset(lr * 0.18, 0), ret);
    canvas.drawLine(lc + Offset(lr * 0.18, 0), lc + Offset(lr * 0.75, 0), ret);
    canvas.drawLine(lc - Offset(0, lr * 0.75), lc - Offset(0, lr * 0.18), ret);
    canvas.drawLine(lc + Offset(0, lr * 0.18), lc + Offset(0, lr * 0.75), ret);
    canvas.drawCircle(lc, lr * 0.08, ret..style = PaintingStyle.stroke);
    canvas.restore();

    // Scanning glint sweeping round the rim.
    final sweep = 2 * math.pi * t * 3;
    canvas.drawArc(
      Rect.fromCircle(center: lc, radius: lr * 1.18),
      sweep,
      1.1,
      false,
      Paint()
        ..shader = ui.Gradient.sweep(
          lc,
          [colors.glow.withValues(alpha: 0), colors.glow.withValues(alpha: 0.7)],
          const [0, 1],
          TileMode.clamp,
          sweep,
          sweep + 1.1,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.012)
        ..strokeCap = StrokeCap.round,
    );

    // Brass rim with a specular highlight.
    canvas.drawCircle(
      lc,
      lr,
      Paint()
        ..shader = ui.Gradient.sweep(lc, [colors.gold, colors.brassDark, colors.brass, colors.gold], const [0, 0.35, 0.7, 1])
        ..style = PaintingStyle.stroke
        ..strokeWidth = lr * 0.13,
    );
    canvas.drawArc(
      Rect.fromCircle(center: lc, radius: lr * 0.8),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..color = colors.star.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lr * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }
}
