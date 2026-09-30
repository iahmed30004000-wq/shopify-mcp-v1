import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/wellbeing_data.dart';

/// Daily values over a date range as a soft line with a glow fill.
///
/// Time runs in the reading direction (the same rule as the lab charts): in
/// Arabic the oldest day is on the right and today on the left, with the
/// value scale at the reading start (right); in English the reverse.
class WbLineChart extends StatelessWidget {
  const WbLineChart({
    super.key,
    required this.series,
    required this.from,
    required this.to,
    required this.minY,
    required this.maxY,
    required this.color,
    this.secondary,
    this.secondaryColor,
    this.height = 184,
    this.interval,
    this.valueLabel,
    this.semanticLabel,
    this.bandFrom,
    this.bandTo,
  });

  final List<MetricPoint> series;

  /// Drawn dashed and thinner (e.g. the daily mean under the daily max).
  final List<MetricPoint>? secondary;
  final Color? secondaryColor;
  final DateTime from;
  final DateTime to;
  final double minY;
  final double maxY;
  final Color color;
  final double height;
  final double? interval;
  final String Function(double v)? valueLabel;
  final String? semanticLabel;

  /// Optional quiet band (e.g. the user's usual range) – purely visual.
  final double? bandFrom;
  final double? bandTo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final span = math.max(1, WbDays.between(from, to)).toDouble();
    double xOf(DateTime d) {
      final x = WbDays.between(from, d).toDouble();
      return rtl ? span - x : x;
    }

    DateTime dayOf(double x) => WbDays.add(from, (rtl ? span - x : x).round());

    final labelStyle = (text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: t.textTertiary);
    final showDots = series.length <= 31;

    LineChartBarData bar(List<MetricPoint> pts, Color c, {bool dashed = false}) {
      final spots = [for (final p in pts) FlSpot(xOf(p.day), p.value)]..sort((a, b) => a.x.compareTo(b.x));
      return LineChartBarData(
        spots: spots,
        isCurved: spots.length > 2,
        curveSmoothness: 0.22,
        preventCurveOverShooting: true,
        color: c,
        barWidth: dashed ? 1.6 : 2.6,
        dashArray: dashed ? const [5, 4] : null,
        isStrokeCapRound: true,
        shadow: dashed
            ? const Shadow(color: Colors.transparent)
            : Shadow(color: c.withValues(alpha: 0.45), blurRadius: 8),
        belowBarData: BarAreaData(
          show: !dashed,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: t.isDark ? 0.26 : 0.16),
              c.withValues(alpha: 0),
            ],
          ),
        ),
        dotData: FlDotData(
          show: !dashed && showDots,
          getDotPainter: (spot, _, _, _) =>
              FlDotCirclePainter(radius: 3.4, color: c, strokeWidth: 1.6, strokeColor: t.space1),
        ),
      );
    }

    final step = interval ?? _niceInterval(maxY - minY);
    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: step,
        getTitlesWidget: (value, meta) {
          if (value < minY - 0.001 || value > maxY + 0.001) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 6,
            child: Text(valueLabel?.call(value) ?? fmt.formatNumber(value, maxDecimals: 1), style: labelStyle),
          );
        },
      ),
    );
    final dateFormat = DateFormat.MMMd(fmt.languageCode);

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: span,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.none(),
        lineBarsData: [
          if (secondary != null && secondary!.isNotEmpty)
            bar(secondary!, secondaryColor ?? t.textTertiary, dashed: true),
          bar(series, color),
        ],
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (bandFrom != null && bandTo != null)
              HorizontalRangeAnnotation(y1: bandFrom!, y2: bandTo!, color: color.withValues(alpha: 0.07)),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.4), strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          leftTitles: rtl ? const AxisTitles() : valueTitles,
          rightTitles: rtl ? valueTitles : const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: span / 2,
              getTitlesWidget: (value, meta) {
                final d = dayOf(value);
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                  child: Text(fmt.localizeDigits(dateFormat.format(d)), style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
            tooltipBorder: BorderSide(color: t.glassBorder),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                s.barIndex == (secondary != null && secondary!.isNotEmpty ? 1 : 0)
                    ? LineTooltipItem(
                        '${fmt.localizeDigits(dateFormat.format(dayOf(s.x)))}\n',
                        labelStyle,
                        children: [
                          TextSpan(
                            text: valueLabel?.call(s.y) ?? fmt.formatNumber(s.y, maxDecimals: 1),
                            style: (text.titleSmall ?? const TextStyle()).copyWith(color: color),
                          ),
                        ],
                      )
                    : null,
            ],
          ),
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots?.isNotEmpty == true) {
              Fx.fire(Sfx.countTick, volume: 0.5);
            }
          },
        ),
      ),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
    );
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.s, end: Space.xs),
          child: chart,
        ),
      ),
    );
  }

  static double _niceInterval(double range) {
    if (range <= 5) return 1;
    if (range <= 10) return 2.5;
    if (range <= 16) return 4;
    return (range / 4).ceilToDouble();
  }
}

/// Labelled horizontal bars, most frequent first, growing from the reading
/// start (trigger / location / factor frequency).
class WbFrequencyBars extends StatelessWidget {
  const WbFrequencyBars({super.key, required this.items, required this.color, this.max = 6, this.countLabel});

  final List<(String, int)> items;
  final Color color;
  final int max;

  /// "3 times" for a count (defaults to the number).
  final String Function(int count)? countLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final shown = items.take(max).toList();
    final top = shown.isEmpty ? 1 : shown.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Semantics(
              label: '${shown[i].$1}: ${countLabel?.call(shown[i].$2) ?? fmt.formatInt(shown[i].$2)}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      shown[i].$1,
                      style: text.bodySmall?.copyWith(color: t.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.glassBorder.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: shown[i].$2 / top),
                            duration: context.motion(MadarMotion.long + MadarMotion.staggerStep * i),
                            curve: MadarMotion.decelerate,
                            builder: (context, f, _) => Container(
                              width: math.max(10, c.maxWidth * f),
                              height: 10,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.centerStart,
                                  end: AlignmentDirectional.centerEnd,
                                  colors: [color.withValues(alpha: 0.55), color],
                                ),
                                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  SizedBox(
                    width: 28,
                    child: Text(
                      fmt.formatInt(shown[i].$2),
                      textAlign: TextAlign.end,
                      style: text.labelMedium?.copyWith(color: t.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
