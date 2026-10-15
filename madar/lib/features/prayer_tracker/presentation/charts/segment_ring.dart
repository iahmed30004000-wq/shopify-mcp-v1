import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../domain/tracker_day.dart';
import '../../domain/tracker_prayers.dart';
import '../../domain/tracker_stats.dart';
import '../../domain/tracker_timing.dart';
import '../tracker_actions.dart';

/// One arc of a [SegmentRingPainter]: its colour (null = only the track)
/// and whether it glows (a prayer prayed).
@immutable
class RingSegment {
  const RingSegment(this.color, {this.lit = false, this.dim = false});

  final Color? color;
  final bool lit;

  /// Drawn thinner and fainter (a prayer due or not logged).
  final bool dim;

  @override
  bool operator ==(Object other) =>
      other is RingSegment && other.color == color && other.lit == lit && other.dim == dim;

  @override
  int get hashCode => Object.hash(color, lit, dim);

  /// The five segments of a day view: one per obligatory prayer.
  static List<RingSegment> ofDay(TrackerDayView view, TrackerColors c) => [
    for (final s in view.obligatory) ofSlot(s, c),
  ];

  static RingSegment ofSlot(TrackerSlot s, TrackerColors c) {
    final status = s.status;
    if (status != null) return RingSegment(c.status(status), lit: status.counts);
    return switch (s.timing) {
      SlotTiming.open => RingSegment(c.due, dim: true),
      SlotTiming.closed => RingSegment(c.idle, dim: true),
      SlotTiming.upcoming => const RingSegment(null),
    };
  }

  /// The five segments of a summarised past day.
  static List<RingSegment> ofSummary(DaySummary d, TrackerColors c) => [
    for (final p in TrackerPrayers.obligatory)
      switch (d.statusOf(p)) {
        final PrayerStatus s => RingSegment(c.status(s), lit: s.counts),
        null => const RingSegment(null),
      },
  ];
}

/// A ring cut into equal arcs (the five prayers of a day), starting at the
/// top and running clockwise like a clock face in both reading directions.
/// Lit arcs glow; [sweep] (0..1) reveals the arcs for an entrance.
class SegmentRingPainter extends CustomPainter {
  SegmentRingPainter({
    required this.segments,
    required this.track,
    required this.glowColor,
    this.strokeWidth = 6,
    this.gapDegrees = 7,
    this.sweep = 1,
    this.glow = true,
    this.complete = false,
  });

  final List<RingSegment> segments;
  final Color track;
  final Color glowColor;
  final double strokeWidth;
  final double gapDegrees;
  final double sweep;
  final bool glow;

  /// All segments lit: the gaps close into one golden ring.
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final n = segments.length;
    if (n == 0 || size.isEmpty) return;
    final radius = (size.shortestSide - strokeWidth) / 2 - (glow ? strokeWidth * 0.6 : 0);
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gap = complete ? 0.0 : gapDegrees * math.pi / 180;
    final slice = 2 * math.pi / n;
    final arc = math.max(0.0, slice - gap);
    final reveal = sweep.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = complete ? StrokeCap.butt : StrokeCap.round
      ..color = track;

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * slice + gap / 2;
      canvas.drawArc(rect, start, arc, false, trackPaint);
    }

    for (var i = 0; i < n; i++) {
      final seg = segments[i];
      final color = seg.color;
      if (color == null) continue;
      // Segments reveal one after another as [sweep] grows.
      final local = ((reveal * n) - i).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final start = -math.pi / 2 + i * slice + gap / 2;
      final length = arc * local;
      final width = seg.dim ? strokeWidth * 0.55 : strokeWidth;
      if (seg.lit && glow) {
        canvas.drawArc(
          rect,
          start,
          length,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 1.9
            ..strokeCap = StrokeCap.round
            ..color = glowColor.withValues(alpha: 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.9),
        );
      }
      canvas.drawArc(
        rect,
        start,
        length,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = complete ? StrokeCap.butt : StrokeCap.round
          ..color = seg.dim ? color.withValues(alpha: 0.55) : color,
      );
    }
  }

  @override
  bool shouldRepaint(SegmentRingPainter old) =>
      old.track != track ||
      old.glowColor != glowColor ||
      old.strokeWidth != strokeWidth ||
      old.gapDegrees != gapDegrees ||
      old.sweep != sweep ||
      old.glow != glow ||
      old.complete != complete ||
      !_sameSegments(old.segments, segments);

  static bool _sameSegments(List<RingSegment> a, List<RingSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A [SegmentRingPainter] as a widget, springing its segments in once.
class SegmentRing extends StatelessWidget {
  const SegmentRing({
    super.key,
    required this.segments,
    this.size = 40,
    this.strokeWidth = 4,
    this.gapDegrees = 9,
    this.complete = false,
    this.glow = true,
    this.child,
  });

  final List<RingSegment> segments;
  final double size;
  final double strokeWidth;
  final double gapDegrees;
  final bool complete;
  final bool glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SegmentRingPainter(
          segments: segments,
          track: t.textTertiary.withValues(alpha: t.isDark ? 0.22 : 0.2),
          glowColor: t.gold,
          strokeWidth: strokeWidth,
          gapDegrees: gapDegrees,
          complete: complete,
          glow: glow,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}
