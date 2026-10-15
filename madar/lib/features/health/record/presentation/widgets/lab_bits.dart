import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../domain/lab_flags.dart';
import '../../domain/lab_series.dart';
import '../record_ui.dart';

/// A neutral flag label: "Low ↓", "Borderline ↑", "In range".
class LabFlagChip extends StatelessWidget {
  const LabFlagChip({super.key, required this.flag, this.full = false, this.dense = false});

  final LabFlag flag;

  /// "Near high limit" instead of "Borderline".
  final bool full;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (flag == LabFlag.qualitative) return const SizedBox.shrink();
    final t = context.tokens;
    final texts = context.recordTexts;
    final color = RecordColors.flag(t, flag);
    final icon = RecordIcons.flag(flag);
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(
      color: flag.isFlagged ? RecordColors.onWash(t, color, 0.14) : t.textSecondary,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(dense ? 6 : 8, 2, dense ? 6 : 8, 2),
      decoration: BoxDecoration(
        color: flag.isFlagged ? color.withValues(alpha: 0.14) : t.glassFill,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: flag.isFlagged ? color.withValues(alpha: 0.4) : t.glassBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 11 : 12, color: color), const SizedBox(width: 2)],
          Flexible(
            child: Text(
              full ? texts.flag(flag) : texts.flagShort(flag),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny trend line for list rows: the reference band, the line and
/// flag-coloured dots. Time runs in the reading direction (newest at the
/// end side).
class LabSparkline extends StatelessWidget {
  const LabSparkline({super.key, required this.points, required this.range, this.width = 72, this.height = 30});

  final List<LabPoint> points;
  final LabRange range;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final numeric = [
      for (final p in points)
        if (p.value != null) p,
    ];
    if (numeric.length < 2) return SizedBox(width: width, height: height);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _SparkPainter(points: numeric, range: range, rtl: rtl, tokens: context.tokens),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.points, required this.range, required this.rtl, required this.tokens});

  final List<LabPoint> points;
  final LabRange range;
  final bool rtl;
  final MadarTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = ChartTimeAxis.covering(points.map((p) => p.date), rtl: rtl, padFraction: 0);
    final scale = LabChartScale.of(points.map((p) => p.value!), range: range);
    const pad = 4.0;
    final span = scale.maxY - scale.minY;
    double y(double v) => size.height - pad - (v - scale.minY) / span * (size.height - 2 * pad);
    double x(DateTime d) => pad + axis.fraction(d) * (size.width - 2 * pad);
    final (lo, hi) = range.ordered;
    if (lo != null || hi != null) {
      final top = y(math.min(hi ?? scale.maxY, scale.maxY));
      final bottom = y(math.max(lo ?? scale.minY, scale.minY));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(0, top, size.width, bottom), const Radius.circular(3)),
        Paint()..color = RecordColors.band(tokens).withValues(alpha: tokens.isDark ? 0.18 : 0.14),
      );
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].date), y(points[i].value!));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tokens.accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in points) {
      final o = Offset(x(p.date), y(p.value!));
      final last = identical(p, points.last);
      canvas.drawCircle(o, last ? 3.2 : 2.2, Paint()..color = RecordColors.dot(tokens, p.flag));
      if (last) {
        canvas.drawCircle(
          o,
          4.6,
          Paint()
            ..color = RecordColors.dot(tokens, p.flag).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.points != points || old.range != range || old.rtl != rtl || old.tokens != tokens;
}
