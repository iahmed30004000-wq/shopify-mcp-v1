import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../domain/goal_chart_data.dart';
import '../../domain/goal_math.dart';
import '../../domain/growth_goal.dart';
import '../growth_texts.dart';

/// A goal's trajectory (fl_chart): the running total as a glowing line
/// with a soft area, the straight-line plan to the deadline (dashed), the
/// target (dashed gold) and the projection at the recent pace (dotted).
///
/// Time runs in the reading direction: in Arabic the first day is on the
/// right and the value axis sits on the right (start) side.
class GoalChart extends StatelessWidget {
  const GoalChart({super.key, required this.goal, required this.now, this.height = 220});

  final GrowthGoal goal;
  final DateTime now;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final fmt = texts.fmt;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final color = GrowthColors.goal(t, goal.color);
    final data = GoalChartData.build(goal.stats, [
      for (final log in goal.logs) GoalEntry(amount: log.amount, at: log.at),
    ], now: now);
    double mx(double x) => GoalChartData.mirror(x, data.maxX, rtl: rtl);
    FlSpot spot(ChartXY p) => FlSpot(mx(p.x), p.y);
    final labelStyle = text.labelSmall!.copyWith(
      color: t.textTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final planColor = t.textTertiary;
    final targetColor = t.gold;

    // fl_chart walks spots in order: keep them left to right after mirroring.
    List<FlSpot> spots(List<ChartXY> points) {
      final list = [for (final p in points) spot(p)];
      return rtl ? list.reversed.toList() : list;
    }

    final actualSpots = spots(data.actual);
    final last = spot(data.actual.last);
    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: actualSpots,
        isCurved: actualSpots.length > 2,
        curveSmoothness: 0.16,
        preventCurveOverShooting: true,
        barWidth: 3,
        isStrokeCapRound: true,
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), GrowthColors.glow(t, color)]),
        shadow: Shadow(color: color.withValues(alpha: t.isDark ? 0.55 : 0.25), blurRadius: 10),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: t.isDark ? 0.28 : 0.16),
              color.withValues(alpha: 0),
            ],
          ),
        ),
        dotData: FlDotData(
          checkToShowDot: (s, _) => s == last,
          getDotPainter: (_, _, _, _) =>
              FlDotCirclePainter(radius: 5.5, color: GrowthColors.glow(t, color), strokeWidth: 3, strokeColor: color),
        ),
      ),
      if (data.plan.isNotEmpty)
        LineChartBarData(
          spots: spots(data.plan),
          barWidth: 1.4,
          color: planColor.withValues(alpha: 0.8),
          dashArray: const [6, 5],
          dotData: const FlDotData(show: false),
        ),
      if (data.projection.isNotEmpty)
        LineChartBarData(
          spots: spots(data.projection),
          barWidth: 2,
          color: color.withValues(alpha: 0.7),
          dashArray: const [2, 5],
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
    ];

    final maxY = data.maxY;
    final interval = data.yInterval;
    String yLabel(double v) => fmt.formatNumber(v, maxDecimals: interval < 1 ? 2 : 0);
    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: interval,
        getTitlesWidget: (value, meta) {
          if (value > maxY - interval * 0.35) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 6,
            child: Text(yLabel(value), style: labelStyle),
          );
        },
      ),
    );

    final xInterval = math.max(data.maxX / 3, 1e-3);
    final shortDate = DateFormat.MMMd(Localizations.localeOf(context).languageCode);
    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: data.maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: bars,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: data.target,
              color: targetColor.withValues(alpha: 0.75),
              strokeWidth: 1.2,
              dashArray: const [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: rtl ? Alignment.topRight : Alignment.topLeft,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                style: labelStyle.copyWith(color: targetColor, fontWeight: FontWeight.w600),
                labelResolver: (line) => '${l.growthChartTarget} ${yLabel(line.y)}',
              ),
            ),
          ],
          verticalLines: [
            if (data.nowX < data.maxX - 0.05)
              VerticalLine(x: mx(data.nowX), color: t.glassBorder, strokeWidth: 1, dashArray: const [2, 4]),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              reservedSize: 26,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final x = GoalChartData.mirror(value, data.maxX, rtl: rtl);
                final d = data.dateAt(math.min(x, data.maxX - 1e-6));
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(fmt.localizeDigits(shortDate.format(d)), style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchSpotThreshold: 22,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: color.withValues(alpha: 0.5), strokeWidth: 1.2, dashArray: const [3, 3]),
                FlDotData(
                  getDotPainter: (_, _, _, _) =>
                      FlDotCirclePainter(radius: 6, color: color, strokeWidth: 3, strokeColor: t.space1),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
            tooltipBorder: BorderSide(color: t.glassBorder),
            tooltipBorderRadius: BorderRadius.circular(t.radiusS),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 180,
            getTooltipItems: (spots) => [
              for (final s in spots)
                s.barIndex == 0
                    ? LineTooltipItem(
                        '${fmt.formatDate(data.dateAt(GoalChartData.mirror(s.x, data.maxX, rtl: rtl)), style: MadarDateStyle.dayMonth)}\n'
                        '${texts.amount(goal.unit, s.y)}',
                        text.labelMedium!.copyWith(color: t.textPrimary),
                        textDirection: Directionality.of(context),
                      )
                    : null,
            ],
          ),
        ),
      ),
      duration: context.motion(MadarMotion.long),
      curve: MadarMotion.emphasized,
    );

    return Semantics(
      label: l.growthChartSemantics(texts.number(goal.stats.current), texts.amount(goal.unit, goal.row.target)),
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.s, end: Space.xs),
                child: chart,
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          ExcludeSemantics(
            child: Wrap(
              spacing: Space.l,
              runSpacing: Space.xs,
              alignment: WrapAlignment.center,
              children: [
                _Legend(label: l.growthChartActual, color: color),
                if (data.plan.isNotEmpty) _Legend(label: l.growthChartPlan, color: planColor, dash: const [4, 3]),
                _Legend(label: l.growthChartTarget, color: targetColor, dash: const [4, 3]),
                if (data.projection.isNotEmpty)
                  _Legend(label: l.growthChartProjection, color: color.withValues(alpha: 0.75), dash: const [1.5, 3]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color, this.dash});

  final String label;
  final Color color;
  final List<double>? dash;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 8),
          painter: _LegendLine(color: color, dash: dash),
        ),
        const SizedBox(width: Space.xs),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}

class _LegendLine extends CustomPainter {
  _LegendLine({required this.color, this.dash});

  final Color color;
  final List<double>? dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dash == null ? 3 : 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final d = dash;
    if (d == null) {
      canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), paint);
      return;
    }
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final len = d[i % d.length];
      if (i.isEven) canvas.drawLine(Offset(x, y), Offset(math.min(x + len, size.width), y), paint);
      x += len;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LegendLine old) => old.color != color || old.dash != dash;
}
