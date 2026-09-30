import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/chart_scale.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_math.dart';
import '../ledger_ui.dart';

/// One slice of [SpendingDonut].
class DonutSlice {
  const DonutSlice({
    required this.key,
    required this.label,
    required this.milli,
    required this.share,
    required this.color,
    this.icon,
  });

  final String key;
  final String label;
  final int milli;
  final double share;
  final Color color;
  final IconData? icon;
}

/// A donut of spending slices (fl_chart) with the total in the middle and a
/// legend of amounts and shares under it. Tapping a slice or a legend row
/// highlights it.
class SpendingDonut extends StatefulWidget {
  const SpendingDonut({
    super.key,
    required this.slices,
    required this.totalText,
    required this.totalLabel,
    required this.format,
    required this.currency,
    this.onSliceTap,
    this.size = 190,
  });

  final List<DonutSlice> slices;
  final String totalText;
  final String totalLabel;
  final LedgerMoneyFormat format;
  final String currency;
  final ValueChanged<DonutSlice>? onSliceTap;
  final double size;

  @override
  State<SpendingDonut> createState() => _SpendingDonutState();
}

class _SpendingDonutState extends State<SpendingDonut> {
  int? _touched;

  void _select(int? i) {
    if (i == _touched) return;
    if (i != null) Fx.fire(Sfx.countTick, volume: 0.6);
    setState(() => _touched = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = MadarFormatter.of(context);
    final slices = widget.slices;
    final selected = _touched == null || _touched! >= slices.length ? null : slices[_touched!];
    final radius = widget.size / 2;
    final ring = radius * 0.24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: slices.length > 1 ? 2.5 : 0,
                  centerSpaceRadius: radius - ring - 6,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final i = response?.touchedSection?.touchedSectionIndex;
                      if (i == null || i < 0) return;
                      _select(i);
                      if (event is FlTapUpEvent) widget.onSliceTap?.call(slices[i]);
                    },
                  ),
                  sections: [
                    for (final (i, s) in slices.indexed)
                      PieChartSectionData(
                        value: math.max(s.milli.toDouble(), 0.0001),
                        color: _touched == null || _touched == i ? s.color : s.color.withValues(alpha: 0.35),
                        radius: _touched == i ? ring + 6 : ring,
                        showTitle: false,
                        borderSide: BorderSide(color: t.space1.withValues(alpha: 0.5), width: 0.5),
                      ),
                  ],
                ),
                duration: context.motion(MadarMotion.medium),
                curve: MadarMotion.standard,
              ),
              IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ring + 18),
                  child: AnimatedSwitcher(
                    duration: context.motion(MadarMotion.short),
                    child: Column(
                      key: ValueKey(selected?.key),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selected?.label ?? widget.totalLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: text.labelMedium?.copyWith(color: t.textTertiary),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            selected == null ? widget.totalText : widget.format.amount(selected.milli, widget.currency),
                            style: LedgerStyle.amount(t, size: 18, color: t.textPrimary, weight: FontWeight.w700),
                          ),
                        ),
                        if (selected != null)
                          Text(
                            f.formatPercent(selected.share),
                            style: LedgerStyle.amount(t, size: 12, color: selected.color, weight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        for (final (i, s) in slices.indexed)
          _LegendRow(
            slice: s,
            amount: widget.format.amount(s.milli, widget.currency),
            share: f.formatPercent(s.share),
            active: _touched == null || _touched == i,
            onTap: () {
              _select(_touched == i ? null : i);
              widget.onSliceTap?.call(s);
            },
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.slice,
    required this.amount,
    required this.share,
    required this.active,
    required this.onTap,
  });

  final DonutSlice slice;
  final String amount;
  final String share;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SpringPress(
      onTap: onTap,
      sfx: null,
      pressScale: 0.985,
      semanticLabel: BidiIsolate.strip('${slice.label}، $amount، $share'),
      child: AnimatedOpacity(
        duration: context.motion(MadarMotion.short),
        opacity: active ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs + 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slice.color,
                      boxShadow: [BoxShadow(color: slice.color.withValues(alpha: 0.5), blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: BidiIsolate.directionOf(slice.label),
                      textAlign: TextAlign.start,
                      style: text.bodyMedium?.copyWith(color: t.textPrimary),
                    ),
                  ),
                  Text(
                    amount,
                    style: LedgerStyle.amount(t, size: 13, color: t.textPrimary, weight: FontWeight.w600),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      share,
                      textAlign: TextAlign.end,
                      style: LedgerStyle.amount(t, size: 12, color: t.textTertiary, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 18),
                child: LayoutBuilder(
                  builder: (context, c) => Container(
                    height: 4,
                    alignment: AlignmentDirectional.centerStart,
                    decoration: BoxDecoration(
                      color: t.textTertiary.withValues(alpha: t.isDark ? 0.14 : 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Container(
                      width: c.maxWidth * slice.share.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(colors: [slice.color.withValues(alpha: 0.65), slice.color]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One period of [TrendBars].
class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.incomeMilli,
    required this.expenseMilli,
    required this.semantics,
  });

  final String label;
  final int incomeMilli;
  final int expenseMilli;
  final String semantics;
}

/// Grouped income / spending bars per period (fl_chart). Time runs in the
/// reading direction (oldest on the right in Arabic); the value axis sits on
/// the start side.
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.points,
    required this.format,
    required this.currency,
    required this.incomeColor,
    required this.expenseColor,
    this.thousand = 'K',
    this.million = 'M',
    this.height = 190,
  });

  final List<TrendPoint> points;
  final LedgerMoneyFormat format;

  /// Currency of the amounts (the base currency).
  final String currency;
  final Color incomeColor;
  final Color expenseColor;
  final String thousand;
  final String million;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final ordered = rtl ? points.reversed.toList() : points;
    var top = 0;
    for (final p in points) {
      top = math.max(top, math.max(p.incomeMilli, p.expenseMilli));
    }
    final scale = ChartScale.of(0, top / 1000);
    // Secondary, not tertiary: small axis labels over glass need AA.
    final labelStyle = text.labelSmall!.copyWith(
      color: t.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: scale.interval,
        getTitlesWidget: (value, meta) {
          // The zero line and the padded top edge carry no label.
          if (value == meta.min || value == meta.max) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 4,
            child: Text(
              format.compact((value * 1000).round(), thousand: thousand, million: million),
              style: labelStyle,
            ),
          );
        },
      ),
    );
    final barWidth = points.length > 8 ? 6.0 : 9.0;
    return Semantics(
      container: true,
      label: points.map((p) => p.semantics).join('. '),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              // A hair above the top tick, so its grid line is drawn too.
              maxY: scale.max + scale.interval * 0.002,
              minY: 0,
              extraLinesData: ExtraLinesData(
                horizontalLines: [HorizontalLine(y: 0, color: t.glassBorder.withValues(alpha: 0.8), strokeWidth: 1)],
              ),
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
                  tooltipBorderRadius: BorderRadius.circular(t.radiusS),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    format.amount((rod.toY * 1000).round(), currency),
                    LedgerStyle.amount(t, size: 12, color: rod.color ?? t.textPrimary),
                  ),
                ),
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent && response?.spot != null) Fx.fire(Sfx.countTick, volume: 0.6);
                },
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: scale.interval,
                getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.45), strokeWidth: 0.8),
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
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= ordered.length) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(ordered[i].label, style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, p) in ordered.indexed)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      for (final (milli, color)
                          in rtl
                              ? [(p.expenseMilli, expenseColor), (p.incomeMilli, incomeColor)]
                              : [(p.incomeMilli, incomeColor), (p.expenseMilli, expenseColor)])
                        BarChartRodData(
                          toY: milli / 1000,
                          width: barWidth,
                          color: color,
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [color.withValues(alpha: 0.55), color],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(show: false),
                        ),
                    ],
                  ),
              ],
            ),
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
          ),
        ),
      ),
    );
  }
}

/// A wallet's balance over time (fl_chart): a soft gradient line, the zero
/// line when the balance crosses it; time in the reading direction.
class BalanceLine extends StatelessWidget {
  const BalanceLine({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    required this.currency,
    required this.dateLabel,
    this.thousand = 'K',
    this.million = 'M',
    this.height = 180,
  });

  final List<BalancePoint> points;
  final Color color;
  final LedgerMoneyFormat format;
  final String currency;
  final String Function(DateTime day) dateLabel;
  final String thousand;
  final String million;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (points.isEmpty) return SizedBox(height: height);
    final n = points.length;
    double xOf(int i) => rtl ? (n - 1 - i).toDouble() : i.toDouble();
    var lo = points.first.balanceMilli, hi = lo;
    for (final p in points) {
      lo = math.min(lo, p.balanceMilli);
      hi = math.max(hi, p.balanceMilli);
    }
    final scale = ChartScale.of(lo / 1000, hi / 1000);
    // Secondary, not tertiary: small axis labels over glass need AA.
    final labelStyle = text.labelSmall!.copyWith(
      color: t.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final spots = [for (var i = 0; i < n; i++) FlSpot(xOf(i), points[i].balanceMilli / 1000)]
      ..sort((a, b) => a.x.compareTo(b.x));
    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: scale.interval,
        getTitlesWidget: (value, meta) {
          if (value == meta.max) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 4,
            child: Text(
              format.compact((value * 1000).round(), thousand: thousand, million: million),
              style: labelStyle,
            ),
          );
        },
      ),
    );
    final last = points.last;
    final first = points.first;
    return Semantics(
      container: true,
      label: BidiIsolate.strip(
        '${dateLabel(first.day)}: ${format.amount(first.balanceMilli, currency)} – '
        '${dateLabel(last.day)}: ${format.amount(last.balanceMilli, currency)}',
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, n - 1).toDouble(),
              minY: scale.min,
              // A hair above the top tick, so its grid line and label show.
              maxY: scale.max + scale.interval * 0.002,
              // No clipping: the scale always contains the data, and today's
              // dot sits on the edge (fl_chart clips every side otherwise).
              clipData: const FlClipData.none(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isStepLineChart: true,
                  lineChartStepData: LineChartStepData(
                    stepDirection: rtl
                        ? LineChartStepData.stepDirectionBackward
                        : LineChartStepData.stepDirectionForward,
                  ),
                  barWidth: 2.2,
                  isStrokeCapRound: true,
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                  dotData: FlDotData(
                    checkToShowDot: (spot, _) => spot.x == xOf(n - 1),
                    getDotPainter: (_, _, _, _) =>
                        FlDotCirclePainter(radius: 4.5, color: color, strokeWidth: 2.5, strokeColor: t.space1),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: t.isDark ? 0.26 : 0.16),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (scale.min < 0)
                    HorizontalLine(
                      y: 0,
                      color: t.danger.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                ],
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: scale.interval,
                getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.4), strokeWidth: 0.8),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
                  tooltipBorderRadius: BorderRadius.circular(t.radiusS),
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      () {
                        final i = rtl ? n - 1 - s.x.round() : s.x.round();
                        final p = points[i.clamp(0, n - 1)];
                        return LineTooltipItem(
                          '${dateLabel(p.day)}\n${format.amount(p.balanceMilli, currency)}',
                          LedgerStyle.amount(t, size: 12, color: t.textPrimary),
                        );
                      }(),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: rtl ? const AxisTitles() : valueTitles,
                rightTitles: rtl ? valueTitles : const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    // First, middle and last day: with four labels the last
                    // two collided once the edge date was nudged inside
                    // ("August 29September 29").
                    interval: math.max(1, (n - 1) / 2).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final i = rtl ? n - 1 - value.round() : value.round();
                      if (i < 0 || i >= n || n < 2) return const SizedBox.shrink();
                      // Edge dates are nudged inside the chart instead of
                      // being clipped.
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                        child: Text(dateLabel(points[i].day), style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
            ),
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
          ),
        ),
      ),
    );
  }
}
