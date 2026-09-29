import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/motion/motion_kit.dart';

/// A savings ring drawn as an astrolabe's mater: an engraved degree scale,
/// a luminous progress arc that ends in a small star, and – when the jar
/// has a deadline – the alidade: a brass pointer on the rim showing where a
/// straight-line plan says the jar should be today.
///
/// Clockwise from 12 o'clock in both directions (rings read as dials).
/// The arc sweeps in on first build and springs to new values; under
/// reduced motion it jumps.
class AstrolabeProgressRing extends StatelessWidget {
  const AstrolabeProgressRing({
    super.key,
    required this.progress,
    this.expected,
    this.color,
    this.size = 200,
    this.child,
    this.reached = false,
    this.dense = false,
    this.semanticLabel,
  });

  /// 0..1.
  final double progress;

  /// Where the plan says the jar should be (0..1), or null.
  final double? expected;

  /// Arc colour (the jar's colour; the theme accent by default).
  final Color? color;
  final double size;
  final Widget? child;

  /// Target reached: the arc turns to gold and the rim glows.
  final bool reached;

  /// Small tile variant: fewer ticks, no inner rete.
  final bool dense;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final target = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final arc = reached ? t.metalGold : (color ?? t.accent);
    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: context.motion(dense ? MadarMotion.long : MadarMotion.cinematic),
      curve: MadarMotion.emphasized,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: AstrolabeProgressRingPainter(
          progress: v,
          expected: expected,
          arc: arc,
          track: t.glassBorder,
          scale: t.brass,
          pointer: t.metalGold,
          glow: reached ? t.metalGold : arc,
          background: t.glassFill,
          shine: t.isDark ? t.textPrimary : t.glassHighlight,
          dark: t.isDark,
          dense: dense,
          reached: reached,
        ),
        child: SizedBox.square(
          dimension: size,
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: ExcludeSemantics(excluding: semanticLabel != null, child: ring),
    );
  }
}

/// Paints [AstrolabeProgressRing] (public for tests and previews).
class AstrolabeProgressRingPainter extends CustomPainter {
  const AstrolabeProgressRingPainter({
    required this.progress,
    required this.expected,
    required this.arc,
    required this.track,
    required this.scale,
    required this.pointer,
    required this.glow,
    required this.background,
    required this.shine,
    required this.dark,
    this.dense = false,
    this.reached = false,
  });

  final double progress;
  final double? expected;
  final Color arc, track, scale, pointer, glow, background;

  /// The near-white of the arc's head (a token: text on night themes).
  final Color shine;
  final bool dark, dense, reached;

  static const double _top = -math.pi / 2;

  /// Canvas angle of [fraction] of a turn from 12 o'clock, clockwise.
  static double angleOf(double fraction) => _top + fraction.clamp(0.0, 1.0) * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = dense ? math.max(4.0, r * 0.16) : math.max(6.0, r * 0.085);
    final arcR = r - stroke / 2 - (dense ? 1 : r * 0.13);

    // Mater: a soft disc with an engraved rim.
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            background.withValues(alpha: 0.0),
            background.withValues(alpha: dark ? 0.55 : 0.8),
          ],
          stops: const [0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dense ? 1 : 1.2
        ..color = scale.withValues(alpha: dark ? 0.55 : 0.7),
    );

    // Degree scale between the rim and the arc.
    if (!dense) {
      final outer = r - 3;
      for (var i = 0; i < 72; i++) {
        final a = _top + i * 2 * math.pi / 72;
        final major = i % 18 == 0;
        final mid = i % 6 == 0;
        final len = major ? r * 0.085 : (mid ? r * 0.06 : r * 0.032);
        final p = Paint()
          ..strokeWidth = major ? 1.6 : (mid ? 1.1 : 0.7)
          ..strokeCap = StrokeCap.round
          ..color = scale.withValues(alpha: major ? 0.85 : (mid ? 0.6 : 0.38));
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * outer, c + dir * (outer - len), p);
      }
      // Inner engraved circles (the rete's tropics).
      final faint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = scale.withValues(alpha: dark ? 0.22 : 0.3);
      canvas.drawCircle(c, arcR - stroke * 1.1, faint);
      _dashedCircle(canvas, c, arcR - stroke * 1.1 - r * 0.07, faint, 48);
    }

    // Track.
    canvas.drawCircle(
      c,
      arcR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track.withValues(alpha: dark ? 0.38 : 0.6),
    );

    final p = progress.clamp(0.0, 1.0);
    if (p > 0.0005) {
      final sweep = p * 2 * math.pi;
      final rect = Rect.fromCircle(center: c, radius: arcR);
      // Glow under the arc.
      canvas.drawArc(
        rect,
        _top,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.6
          ..strokeCap = StrokeCap.round
          ..color = glow.withValues(alpha: dark ? (reached ? 0.45 : 0.32) : 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.9),
      );
      // The arc: a sweep gradient that brightens towards its head.
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [arc.withValues(alpha: 0.45), arc, Color.lerp(arc, shine, dark ? 0.35 : 0.1)!],
        stops: [0, math.max(0.001, p * 0.85), math.max(0.002, p)],
        transform: const GradientRotation(_top),
      ).createShader(rect);
      canvas.drawArc(
        rect,
        _top,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
      // The head: a four-pointed star.
      final head = c + Offset(math.cos(_top + sweep), math.sin(_top + sweep)) * arcR;
      final s = stroke * (dense ? 0.55 : 0.85);
      canvas.drawCircle(
        head,
        s * 1.3,
        Paint()
          ..color = glow.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s),
      );
      canvas.drawPath(_star(head, s, s * 0.32), Paint()..color = Color.lerp(arc, shine, dark ? 0.7 : 0.45)!);
    }

    // The alidade: where the plan says the jar should be today.
    final e = expected;
    if (e != null && !reached) {
      final a = angleOf(e);
      final dir = Offset(math.cos(a), math.sin(a));
      final tip = c + dir * (arcR - stroke * 0.5 - 1);
      final base = c + dir * (r - (dense ? 1 : 2));
      final normal = Offset(-dir.dy, dir.dx);
      final w = dense ? 3.2 : 5.0;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx * w, base.dy + normal.dy * w)
        ..lineTo(base.dx - normal.dx * w, base.dy - normal.dy * w)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = pointer.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawPath(path, Paint()..color = pointer);
      if (!dense) {
        // A faint sight line across the arc.
        canvas.drawLine(
          c + dir * (arcR - stroke * 0.9),
          c + dir * (arcR + stroke * 0.9),
          Paint()
            ..strokeWidth = 1.2
            ..color = pointer.withValues(alpha: 0.8),
        );
      }
    }

    // A fixed zero mark at 12 o'clock.
    final zero = Offset(c.dx, c.dy - r + (dense ? 1.5 : 3));
    canvas.drawPath(_star(zero, dense ? 2.4 : 4, dense ? 1 : 1.6), Paint()..color = scale);
  }

  static void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint, int dashes) {
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * step, step * 0.45, false, paint);
    }
  }

  static Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final rr = i.isEven ? outer : inner;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(AstrolabeProgressRingPainter old) =>
      old.progress != progress ||
      old.expected != expected ||
      old.arc != arc ||
      old.track != track ||
      old.scale != scale ||
      old.pointer != pointer ||
      old.glow != glow ||
      old.background != background ||
      old.shine != shine ||
      old.dark != dark ||
      old.dense != dense ||
      old.reached != reached;
}
