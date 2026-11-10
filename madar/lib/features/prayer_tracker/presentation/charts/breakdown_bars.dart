import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/tracker_stats.dart';
import '../tracker_actions.dart';

/// One stacked bar: how a prayer went over a span of [days] (on time, late,
/// made up, missed; the rest of the track is days without a log).
class BreakdownBarPainter extends CustomPainter {
  BreakdownBarPainter({
    required this.breakdown,
    required this.days,
    required this.tokens,
    required this.textDirection,
    this.reveal = 1,
  });

  final PrayerBreakdown breakdown;
  final int days;
  final MadarTokens tokens;
  final TextDirection textDirection;

  /// Entrance (0..1): the bar grows from the reading start.
  final double reveal;

  /// Space between two status segments.
  static const segmentGap = 1.5;

  /// The segment widths (fractions of the track) in drawing order.
  static List<double> fractions(PrayerBreakdown b, int days) {
    final total = math.max(days, b.total);
    if (total <= 0) return const [0, 0, 0, 0];
    return [b.onTime / total, b.late / total, b.madeUp / total, b.missed / total];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = TrackerColors.from(tokens);
    final h = size.height;
    final radius = Radius.circular(h / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = tokens.textTertiary.withValues(alpha: tokens.isDark ? 0.16 : 0.14));
    final parts = fractions(breakdown, days);
    final colors = [c.onTime, c.late, c.qada, c.missed];
    canvas.save();
    canvas.clipRRect(track);
    var x = 0.0;
    final width = size.width * reveal.clamp(0.0, 1.0);
    for (var i = 0; i < parts.length; i++) {
      final w = parts[i] * width;
      if (w <= 0) continue;
      // A hairline gap before every segment but the first keeps
      // neighbouring statuses apart (late and missed are close hues on
      // Pearl's deep inks).
      final gap = x > 0 ? math.min(segmentGap, w / 2) : 0.0;
      final left = textDirection == TextDirection.rtl ? size.width - x - w : x + gap;
      final rect = Rect.fromLTWH(left, 0, w - gap, h);
      canvas.drawRect(rect, Paint()..color = colors[i]);
      // Soft sheen on top so the bar reads as a lit groove.
      canvas.drawRect(
        Rect.fromLTWH(rect.left, 0, rect.width, h * 0.45),
        Paint()..color = tokens.glassHighlight.withValues(alpha: tokens.isDark ? 0.14 : 0.2),
      );
      x += w;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BreakdownBarPainter old) =>
      old.breakdown.onTime != breakdown.onTime ||
      old.breakdown.late != breakdown.late ||
      old.breakdown.madeUp != breakdown.madeUp ||
      old.breakdown.missed != breakdown.missed ||
      old.days != days ||
      old.tokens != tokens ||
      old.textDirection != textDirection ||
      old.reveal != reveal;
}
