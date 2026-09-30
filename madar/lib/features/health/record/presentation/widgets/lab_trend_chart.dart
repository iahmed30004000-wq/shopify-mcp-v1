import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/lab_flags.dart';
import '../../domain/lab_series.dart';
import '../record_ui.dart';

/// A lab test's trend (fl_chart): the user's reference range as a shaded
/// band with dashed limits, the readings as a line with dots coloured by
/// their neutral flag, and a tappable selection.
///
/// Time runs in the reading direction: in Arabic the oldest reading is on
/// the right and the value axis sits on the right (start) side.
class LabTrendChart extends StatelessWidget {
  const LabTrendChart({
    super.key,
    required this.points,
    required this.range,
    required this.today,
    this.from,
    this.decimals = 0,
    this.unit,
    this.selectedId,
    this.onSelected,
    this.height = 230,
  });

  /// Readings in the period, oldest first (qualitative ones are skipped).
  final List<LabPoint> points;
  final LabRange range;
  final DateTime today;

  /// Period start (null = from the first reading).
  final DateTime? from;
  final int decimals;
  final String? unit;
  final String? selectedId;
  final ValueChanged<LabPoint>? onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final numeric = [
      for (final p in points)
        if (p.value != null) p,
    ];
    if (numeric.isEmpty) {
      return SizedBox(
        height: height * 0.5,
        child: Center(
          child: Text(
            l.recordLabChartEmpty,
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: t.textTertiary),
          ),
        ),
      );
    }
    final axis = ChartTimeAxis.covering(numeric.map((p) => p.date), rtl: rtl, from: from, to: today);
    final scale = LabChartScale.of(numeric.map((p) => p.value!), range: range);
    final spots = [for (final p in numeric) FlSpot(axis.x(p.date), p.value!)];
    final order = List<int>.generate(numeric.length, (i) => i)..sort((a, b) => spots[a].x.compareTo(spots[b].x));
    final sortedPoints = [for (final i in order) numeric[i]];
    final sortedSpots = [for (final i in order) spots[i]];
    final selectedIndex = sortedPoints.indexWhere((p) => p.id == selectedId);
    final (lo, hi) = range.ordered;
    final bandLow = lo == null ? scale.minY : math.max(lo, scale.minY);
    final bandHigh = hi == null ? scale.maxY : math.min(hi, scale.maxY);
    final labelStyle = text.labelSmall!.copyWith(
      color: t.textTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String num(double v) => fmt.formatNumber(v, maxDecimals: math.max(decimals, LabDecimals.of(scale.interval)));

    final bar = LineChartBarData(
      spots: sortedSpots,
      isCurved: sortedSpots.length > 2,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      barWidth: 2.4,
      isStrokeCapRound: true,
      gradient: LinearGradient(colors: [t.accent.withValues(alpha: 0.75), t.accent]),
      showingIndicators: selectedIndex >= 0 ? [selectedIndex] : const [],
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.accent.withValues(alpha: t.isDark ? 0.22 : 0.14),
            t.accent.withValues(alpha: 0),
          ],
        ),
      ),
      dotData: FlDotData(
        getDotPainter: (spot, _, _, index) {
          final p = sortedPoints[index];
          final selected = index == selectedIndex;
          return FlDotCirclePainter(
            radius: selected ? 6 : 4.2,
            color: RecordColors.dot(t, p.flag),
            strokeWidth: selected ? 3 : 2,
            strokeColor: t.space1,
          );
        },
      ),
    );

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: axis.span,
        minY: scale.minY,
        maxY: scale.maxY,
        clipData: const FlClipData.horizontal(),
        lineBarsData: [bar],
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (lo != null || hi != null)
              HorizontalRangeAnnotation(
                y1: bandLow,
                y2: bandHigh,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RecordColors.band(t).withValues(alpha: t.isDark ? 0.16 : 0.12),
                    RecordColors.band(t).withValues(alpha: t.isDark ? 0.09 : 0.07),
                  ],
                ),
              ),
          ],
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            for (final b in [?lo, ?hi])
              if (b >= scale.minY && b <= scale.maxY)
                HorizontalLine(
                  y: b,
                  color: RecordColors.band(t).withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: const [5, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: rtl ? Alignment.topLeft : Alignment.topRight,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    style: labelStyle.copyWith(color: RecordColors.band(t), fontSize: 10),
                    labelResolver: (line) => num(line.y),
                  ),
                ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: scale.interval,
          getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.45), strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          leftTitles: rtl ? const AxisTitles() : _valueTitles(scale, labelStyle, num),
          rightTitles: rtl ? _valueTitles(scale, labelStyle, num) : const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: math.max(1, axis.span / 4),
              getTitlesWidget: (value, meta) {
                // Three inner dates; the edges would be clipped.
                if (value <= meta.min + 0.5 || value >= meta.max - axis.span * 0.1) return const SizedBox.shrink();
                final d = axis.dateAt(value);
                final label = axis.span > 100 ? texts.monthYear(d) : texts.dayMonthShort(d);
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(label, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchSpotThreshold: 24,
          getTouchedSpotIndicator: (barData, indexes) => [
            for (final i in indexes)
              TouchedSpotIndicatorData(
                FlLine(
                  color: RecordColors.dot(t, sortedPoints[i].flag).withValues(alpha: 0.5),
                  strokeWidth: 1.2,
                  dashArray: const [3, 3],
                ),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 6.5,
                    color: RecordColors.dot(t, sortedPoints[i].flag),
                    strokeWidth: 3,
                    strokeColor: t.space1,
                  ),
                ),
              ),
          ],
          touchCallback: (event, response) {
            if (onSelected == null || !event.isInterestedForInteractions) return;
            final spot = response?.lineBarSpots?.firstOrNull;
            if (spot == null) return;
            final p = sortedPoints[spot.spotIndex];
            if (p.id != selectedId) {
              Fx.fire(Sfx.countTick, volume: 0.6);
              onSelected!(p);
            }
          },
        ),
      ),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
    );

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: Space.s),
        child: chart,
      ),
    );
  }

  AxisTitles _valueTitles(LabChartScale scale, TextStyle style, String Function(double) num) => AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 42,
      interval: scale.interval,
      getTitlesWidget: (value, meta) {
        if (value == meta.max || value == meta.min) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(num(value), style: style),
        );
      },
    ),
  );
}
