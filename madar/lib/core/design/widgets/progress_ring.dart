import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../i18n/formatters.dart';
import '../../motion/motion.dart';
import '../tokens.dart';

/// Pure arc geometry of [ProgressRing] (unit-tested).
abstract final class ProgressRingGeometry {
  /// Clamped progress (NaN → 0).
  static double normalize(double value) => value.isNaN ? 0 : value.clamp(0.0, 1.0);

  /// Sweep in radians for [value] (0..1).
  static double sweep(double value) => normalize(value) * 2 * math.pi;

  /// Canvas angle of the arc head: starts at 12 o'clock, clockwise (or
  /// counter-clockwise when [clockwise] is false).
  static double headAngle(double value, {bool clockwise = true}) => -math.pi / 2 + sweep(value) * (clockwise ? 1 : -1);
}

/// Animated progress arc with a luminous head and optional centre child.
///
/// Rings stay clockwise in RTL (they read as clocks, which do not mirror);
/// set [clockwise] to false to reverse.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 8,
    this.color,
    this.gradientEnd,
    this.trackColor,
    this.glow = true,
    this.clockwise = true,
    this.child,
    this.semanticLabel,
    this.semanticValue,
  });

  /// 0..1 (clamped).
  final double value;
  final double size;
  final double strokeWidth;

  /// Arc colour (defaults to the theme accent).
  final Color? color;

  /// Optional colour the arc blends toward at its head.
  final Color? gradientEnd;
  final Color? trackColor;
  final bool glow;
  final bool clockwise;
  final Widget? child;
  final String? semanticLabel;

  /// Defaults to the rounded percentage.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = ProgressRingGeometry.normalize(value);
    final arc = color ?? t.accent;
    return Semantics(
      label: semanticLabel,
      // Read in the user's digits (٤٢٪ / 42%).
      value: semanticValue ?? MadarFormatter.of(context).formatPercent(v),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: context.motion(MadarMotion.long),
        curve: MadarMotion.decelerate,
        builder: (context, animated, child) => CustomPaint(
          painter: ProgressRingPainter(
            value: animated,
            color: arc,
            gradientEnd: gradientEnd ?? Color.lerp(arc, t.starTint, 0.45)!,
            trackColor: trackColor ?? t.glassBorder.withValues(alpha: t.glassBorder.a * 0.7),
            strokeWidth: strokeWidth,
            glow: glow,
            clockwise: clockwise,
            headColor: t.starTint,
          ),
          child: child,
        ),
        child: SizedBox.square(
          dimension: size,
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  const ProgressRingPainter({
    required this.value,
    required this.color,
    required this.gradientEnd,
    required this.trackColor,
    required this.strokeWidth,
    required this.headColor,
    this.glow = true,
    this.clockwise = true,
  });

  final double value;
  final Color color;
  final Color gradientEnd;
  final Color trackColor;
  final double strokeWidth;
  final Color headColor;
  final bool glow;
  final bool clockwise;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - strokeWidth / 2 - (glow ? 3 : 0);

    // Track with a faint inner groove.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );
    canvas.drawCircle(
      c,
      r - strokeWidth / 2 - 2.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = trackColor.withValues(alpha: trackColor.a * 0.6),
    );

    final v = ProgressRingGeometry.normalize(value);
    if (v <= 0.0005) return;
    final sweep = ProgressRingGeometry.sweep(v) * (clockwise ? 1 : -1);
    const start = -math.pi / 2;

    // Gradient along the arc. Rotated back by the cap angle so the round
    // start cap is inside the gradient (no seam), mirrored for
    // counter-clockwise rings.
    final cap = strokeWidth / 2 / r;
    final length = sweep.abs();
    final shader = ui.Gradient.sweep(
      Offset.zero,
      [color, gradientEnd],
      const [0, 1],
      TileMode.clamp,
      0,
      math.min(2 * math.pi, length + cap * 2),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(start - (clockwise ? cap : -cap));
    if (!clockwise) canvas.scale(1, -1);
    final local = Rect.fromCircle(center: Offset.zero, radius: r);
    if (glow) {
      canvas.drawArc(
        local,
        cap,
        length,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.4
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: color.a * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.9),
      );
    }
    canvas.drawArc(
      local,
      cap,
      length,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    canvas.restore();

    // Luminous head.
    final a = ProgressRingGeometry.headAngle(v, clockwise: clockwise);
    final head = c + Offset(math.cos(a), math.sin(a)) * r;
    if (glow) {
      canvas.drawCircle(
        head,
        strokeWidth * 1.1,
        Paint()
          ..color = gradientEnd.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.8),
      );
    }
    canvas.drawCircle(head, strokeWidth * 0.3, Paint()..color = headColor);
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.gradientEnd != gradientEnd ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.headColor != headColor ||
      old.glow != glow ||
      old.clockwise != clockwise;
}
