import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../domain/fasting.dart';
import 'body_widgets.dart';

/// Ring geometry of the fasting clock (pure).
///
/// The ring is one day (24 h) for fasts shorter than a day: the fasting
/// segment from the top, clockwise, then the eating window after it. For
/// fasts of a day or more the whole ring is the fast.
abstract final class FastingRingGeometry {
  /// Hours the full ring stands for.
  static double cycleHours(Duration target) => math.max(24, target.inMinutes / 60);

  /// Share of the ring taken by the fast.
  static double fastShare(Duration target) => (target.inMinutes / 60) / cycleHours(target);

  /// Where the progress arc starts and ends (0‥1 of the ring, clockwise
  /// from the top) for [status].
  static ({double from, double to}) progress(FastingStatus status) {
    final share = fastShare(status.target);
    switch (status.phase) {
      case FastingPhase.fasting:
        final hours = status.elapsed.inSeconds / 3600;
        return (from: 0, to: (hours / cycleHours(status.target)).clamp(0.0, 1.0));
      case FastingPhase.eating:
        return (from: share, to: share + (1 - share) * status.progress.clamp(0.0, 1.0));
      case FastingPhase.waiting:
        return (from: 0, to: 0);
    }
  }
}

/// The fasting clock: tracks for the fast and the eating window, hour
/// ticks, the goal marker and a luminous progress arc with a glowing head.
class FastingRing extends StatelessWidget {
  const FastingRing({super.key, required this.status, this.size = 236, this.strokeWidth = 14, this.child, this.ticks = true});

  final FastingStatus status;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final bool ticks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = BodyPalette(t);
    final arc = FastingRingGeometry.progress(status);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: arc.from, end: arc.from),
        duration: context.motion(MadarMotion.medium),
        builder: (context, from, _) => TweenAnimationBuilder<double>(
          tween: Tween(begin: arc.to, end: arc.to),
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          builder: (context, to, _) => CustomPaint(
            painter: FastingRingPainter(
              share: FastingRingGeometry.fastShare(status.target),
              from: from,
              to: to,
              phase: status.phase,
              reached: status.reached,
              fastColor: p.fasting,
              fastEndColor: p.fastingEnd,
              eatColor: p.eating,
              track: t.glassBorder,
              tickColor: t.textTertiary,
              headColor: t.textPrimary,
              holeColor: t.space1,
              strokeWidth: strokeWidth,
              ticks: ticks,
              dark: t.isDark,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class FastingRingPainter extends CustomPainter {
  FastingRingPainter({
    required this.share,
    required this.from,
    required this.to,
    required this.phase,
    required this.reached,
    required this.fastColor,
    required this.fastEndColor,
    required this.eatColor,
    required this.track,
    required this.tickColor,
    required this.headColor,
    required this.holeColor,
    required this.strokeWidth,
    required this.ticks,
    required this.dark,
  });

  final double share;
  final double from;
  final double to;
  final FastingPhase phase;
  final bool reached;
  final Color fastColor;
  final Color fastEndColor;
  final Color eatColor;
  final Color track;
  final Color tickColor;
  final Color headColor;
  final Color holeColor;
  final double strokeWidth;
  final bool ticks;
  final bool dark;

  static const double _top = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - strokeWidth / 2 - 6;
    final rect = Rect.fromCircle(center: c, radius: r);
    const full = 2 * math.pi;
    const gap = 0.018;

    // Tracks.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      _top + gap,
      math.max(0.001, full * share - 2 * gap),
      false,
      trackPaint..color = fastColor.withValues(alpha: dark ? 0.16 : 0.18),
    );
    if (share < 1) {
      canvas.drawArc(
        rect,
        _top + full * share + gap,
        math.max(0.001, full * (1 - share) - 2 * gap),
        false,
        trackPaint..color = eatColor.withValues(alpha: dark ? 0.14 : 0.16),
      );
    }

    // Hour ticks just inside the ring.
    if (ticks) {
      const cycle = 24;
      final tick = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < cycle; i++) {
        final a = _top + full * i / cycle;
        final major = i % 6 == 0;
        final inner = r - strokeWidth / 2 - (major ? 9 : 6);
        final outer = r - strokeWidth / 2 - 3;
        tick
          ..color = tickColor.withValues(alpha: major ? 0.7 : 0.35)
          ..strokeWidth = major ? 1.6 : 1;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * inner, c + Offset(math.cos(a), math.sin(a)) * outer, tick);
      }
    }

    // Progress.
    final sweep = (to - from) * full;
    if (sweep > 0.0005) {
      final start = _top + from * full;
      final eating = phase == FastingPhase.eating;
      final a = eating ? eatColor.withValues(alpha: 0.75) : fastColor;
      final b = eating ? eatColor : (reached ? eatColor : fastEndColor);
      // The gradient starts half a stroke before the arc so the round start
      // cap takes the first colour (the sweep wraps behind it, not on it).
      final cap = strokeWidth / 2 / r;
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep + cap * 2, 0.01),
        colors: [a, a, b],
        stops: [0, cap / (sweep + cap * 2), 1],
        transform: GradientRotation(start - cap),
      ).createShader(rect);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.saveLayer(rect.inflate(strokeWidth + 40), Paint()..color = Colors.white.withValues(alpha: dark ? 0.5 : 0.3));
      canvas.drawArc(rect, start, sweep, false, glow);
      canvas.restore();
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
      // Luminous head.
      final ha = start + sweep;
      final head = c + Offset(math.cos(ha), math.sin(ha)) * r;
      canvas.drawCircle(head, strokeWidth * 0.9, Paint()..color = b.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(head, strokeWidth * 0.34, Paint()..color = headColor);
    }

    // Goal marker (end of the fast segment) and the start mark.
    if (share < 1) {
      final ga = _top + full * share;
      final goal = c + Offset(math.cos(ga), math.sin(ga)) * r;
      canvas.drawCircle(goal, strokeWidth * 0.52, Paint()..color = reached || phase == FastingPhase.eating ? eatColor : fastColor.withValues(alpha: 0.9));
      canvas.drawCircle(goal, strokeWidth * 0.22, Paint()..color = holeColor);
    }
    final s = c + Offset(0, -r);
    canvas.drawCircle(s, strokeWidth * 0.18, Paint()..color = fastColor.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(FastingRingPainter old) =>
      old.share != share ||
      old.from != from ||
      old.to != to ||
      old.phase != phase ||
      old.reached != reached ||
      old.fastColor != fastColor ||
      old.fastEndColor != fastEndColor ||
      old.eatColor != eatColor ||
      old.track != track ||
      old.tickColor != tickColor ||
      old.headColor != headColor ||
      old.holeColor != holeColor ||
      old.strokeWidth != strokeWidth ||
      old.ticks != ticks ||
      old.dark != dark;
}
