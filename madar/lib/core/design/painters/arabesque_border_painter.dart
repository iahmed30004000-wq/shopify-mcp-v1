import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Pure tiling of the arabesque band (unit-tested).
abstract final class ArabesqueLayout {
  /// Number of motif tiles for a band of [width] × [height]. Always even
  /// (a full wave period is two tiles) and at least 2, so the vine meets
  /// both ends of the band at the same phase.
  static int tileCount(double width, double height, {double aspect = 1.6}) {
    if (width <= 0 || height <= 0) return 0;
    final ideal = width / (height * aspect);
    final pairs = math.max(1, (ideal / 2).round());
    return pairs * 2;
  }

  /// Width of each tile once the count is fitted exactly to [width].
  static double tileWidth(double width, double height, {double aspect = 1.6}) {
    final n = tileCount(width, height, aspect: aspect);
    return n == 0 ? 0 : width / n;
  }
}

/// A repeating arabesque border band: double rails enclosing a flowing vine
/// with spiral tendrils, almond leaves and buds. The vine flows in the
/// reading direction ([textDirection]); [phase] (0..1) scrolls it one full
/// period for ambient motion.
class ArabesqueBorderPainter extends CustomPainter {
  const ArabesqueBorderPainter({
    required this.color,
    this.leafColor,
    this.railColor,
    this.strokeWidth,
    this.textDirection = TextDirection.rtl,
    this.phase = 0,
    this.aspect = 1.6,
    this.rails = true,
  });

  final Color color;
  final Color? leafColor;
  final Color? railColor;
  final double? strokeWidth;
  final TextDirection textDirection;
  final double phase;
  final double aspect;
  final bool rails;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height;
    final sw = strokeWidth ?? math.max(0.8, h * 0.045);
    final count = ArabesqueLayout.tileCount(size.width, h, aspect: aspect);
    final tw = size.width / count;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final railPaint = Paint()
      ..color = railColor ?? color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.8;
    final inset = sw * 0.6;
    final railGap = math.max(sw * 1.6, h * 0.09);
    if (rails) {
      for (final y in [inset, inset + railGap, h - inset, h - inset - railGap]) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), railPaint..strokeWidth = y == inset || y == h - inset ? sw * 0.8 : sw * 0.45);
      }
    }

    final top = rails ? inset + railGap + sw * 1.2 : sw;
    final bottom = rails ? h - inset - railGap - sw * 1.2 : h - sw;
    final cy = (top + bottom) / 2;
    final amp = (bottom - top) / 2 * 0.62;

    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    final tendril = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.75
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = leafColor ?? color;

    final shift = (phase % 1) * tw * 2;
    // Draw one extra period on the leading side so scrolling never shows a gap.
    for (var i = -2; i < count + 2; i++) {
      final x0 = i * tw + shift;
      if (x0 > size.width + tw || x0 + tw < -tw) continue;
      final s = i.isEven ? 1.0 : -1.0;
      // Stem hump (alternating up/down → continuous wave).
      final path = Path()
        ..moveTo(x0, cy)
        ..cubicTo(x0 + tw * 0.28, cy - s * amp * 1.33, x0 + tw * 0.72, cy - s * amp * 1.33, x0 + tw, cy);
      canvas.drawPath(path, stem);

      // Spiral tendril curling into the hump's concavity.
      final start = Offset(x0 + tw * 0.3, cy - s * amp * 0.86);
      final c1 = Offset(x0 + tw * 0.5, cy + s * amp * 0.1);
      final r0 = amp * 0.62;
      final spiral = Path()..moveTo(start.dx, start.dy);
      spiral.quadraticBezierTo(x0 + tw * 0.34, cy + s * amp * 0.1, c1.dx - r0 * 0.1, c1.dy + s * r0 * 0.55);
      _spiral(spiral, Offset(c1.dx + r0 * 0.12, c1.dy + s * r0 * 0.15), r0 * 0.45, s);
      canvas.drawPath(spiral, tendril);
      final budAt = Offset(c1.dx + r0 * 0.12, c1.dy + s * r0 * 0.15);
      canvas.drawCircle(budAt, sw * 0.9, leaf);

      // Almond leaf springing forward from the descending side.
      final base = Offset(x0 + tw * 0.74, cy - s * amp * 0.8);
      final tip = Offset(x0 + tw * 0.98, cy - s * amp * 1.28);
      canvas.drawPath(_almond(base, tip, amp * 0.34), leaf);

      // Tiny trefoil bud where the vine crosses the centre line.
      final bud = Offset(x0, cy);
      canvas.drawCircle(bud, sw * 0.7, leaf);
    }
    canvas.restore();
  }

  /// Appends a smooth inward spiral (1¼ turns) around [center].
  static void _spiral(Path path, Offset center, double radius, double s) {
    const steps = 28;
    const turns = 1.25;
    final startAngle = s > 0 ? math.pi * 0.95 : -math.pi * 0.95;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = startAngle - s * t * turns * 2 * math.pi;
      final r = radius * (1 - 0.78 * t);
      path.lineTo(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
    }
  }

  static Path _almond(Offset base, Offset tip, double width) {
    final d = tip - base;
    final n = Offset(-d.dy, d.dx) / d.distance * width;
    final mid = base + d * 0.45;
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
      ..close();
  }

  @override
  bool shouldRepaint(ArabesqueBorderPainter old) =>
      old.color != color ||
      old.leafColor != leafColor ||
      old.railColor != railColor ||
      old.strokeWidth != strokeWidth ||
      old.textDirection != textDirection ||
      old.phase != phase ||
      old.aspect != aspect ||
      old.rails != rails;
}
