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
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          railPaint..strokeWidth = y == inset || y == h - inset ? sw * 0.8 : sw * 0.45,
        );
      }
    }

    final top = rails ? inset + railGap + sw * 1.4 : sw;
    final bottom = rails ? h - inset - railGap - sw * 1.4 : h - sw;
    final cy = (top + bottom) / 2;
    final amp = (bottom - top) / 2 * 0.7;

    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 1.15
      ..strokeCap = StrokeCap.round;
    final tendril = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.8
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = leafColor ?? color;

    Offset cubic(double x0, double s, double t) {
      final u = 1 - t;
      final x = x0 + tw * (3 * u * u * t * 0.28 + 3 * u * t * t * 0.72 + t * t * t);
      final y = cy - s * amp * 1.33 * (3 * u * u * t + 3 * u * t * t);
      return Offset(x, y);
    }

    final shift = (phase % 1) * tw * 2;
    // Draw extra tiles on both sides so scrolling never shows a gap.
    for (var i = -2; i < count + 2; i++) {
      final x0 = i * tw + shift;
      if (x0 > size.width + tw || x0 + tw < -tw) continue;
      final s = i.isEven ? 1.0 : -1.0;
      // Stem hump (alternating up/down → continuous wave).
      canvas.drawPath(
        Path()
          ..moveTo(x0, cy)
          ..cubicTo(x0 + tw * 0.28, cy - s * amp * 1.33, x0 + tw * 0.72, cy - s * amp * 1.33, x0 + tw, cy),
        stem,
      );

      // Rinceau scroll: peels off the rising stem, runs under the crest and
      // curls inward into the hump's hollow, ending in a bud.
      final p0 = cubic(x0, s, 0.2);
      final r0 = amp * 0.84;
      const theta0 = -1.9;
      final c = p0 + Offset(-math.cos(theta0) * r0, -math.sin(theta0) * r0 * s);
      final scroll = Path()..moveTo(p0.dx, p0.dy);
      const steps = 36;
      const turns = 1.3;
      Offset end = p0;
      for (var k = 1; k <= steps; k++) {
        final u = k / steps;
        final th = theta0 + u * turns * 2 * math.pi;
        final r = r0 * (1 - 0.74 * u);
        end = c + Offset(math.cos(th) * r, math.sin(th) * r * s);
        scroll.lineTo(end.dx, end.dy);
      }
      canvas.drawPath(scroll, tendril);
      canvas.drawCircle(end, sw * 1.05, leaf);

      // Half-palmette springing from the descending stem toward the rail.
      final base = cubic(x0, s, 0.7);
      final tip = base + Offset(tw * 0.2, -s * amp * 0.95);
      canvas.drawPath(_almond(base, tip, amp * 0.4), leaf);
      // A smaller leaf on the other side of the stem.
      final base2 = cubic(x0, s, 0.86);
      final tip2 = base2 + Offset(tw * 0.1, s * amp * 0.62);
      canvas.drawPath(_almond(base2, tip2, amp * 0.28), leaf);

      // Trefoil bud where the vine crosses the centre line.
      final bud = Offset(x0, cy);
      canvas.drawCircle(bud, sw * 0.95, leaf);
    }
    canvas.restore();
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
