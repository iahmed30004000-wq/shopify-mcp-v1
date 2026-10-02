import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../domain/body_clock.dart';
import '../../domain/training.dart';
import '../body_texts.dart';
import 'body_widgets.dart';

/// Seven daily water totals as glowing columns with the target as a dashed
/// line. Time runs in the reading direction (today at the reading end: on
/// the left in Arabic, on the right in English).
class WaterWeekChart extends StatefulWidget {
  const WaterWeekChart({super.key, required this.days, required this.target, required this.today, this.height = 150});

  final List<({DateTime day, int ml})> days;
  final int target;
  final DateTime today;
  final double height;

  @override
  State<WaterWeekChart> createState() => _WaterWeekChartState();
}

class _WaterWeekChartState extends State<WaterWeekChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final top = math.max(widget.target, widget.days.fold<int>(0, (m, d) => math.max(m, d.ml))) * 1.12;
    const labelH = 22.0, valueH = 18.0;
    final barArea = widget.height - labelH - valueH;
    final targetY = barArea * (widget.target / top);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Target line.
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: labelH + targetY,
              child: ExcludeSemantics(child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(p.waterEnd.withValues(alpha: 0.6)))),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < widget.days.length; i++)
                  Expanded(
                    child: _WaterColumn(
                      entry: widget.days[i],
                      index: i,
                      fraction: widget.days[i].ml / top,
                      barArea: barArea,
                      labelHeight: labelH,
                      valueHeight: valueH,
                      met: widget.days[i].ml >= widget.target,
                      isToday: BodyDays.same(widget.days[i].day, widget.today),
                      selected: _selected == i,
                      label: tx.weekdayShort(widget.days[i].day.weekday),
                      semanticLabel: '${tx.day(widget.days[i].day, widget.today)}: ${tx.ml(widget.days[i].ml)}',
                      valueText: tx.fmt.formatInt(widget.days[i].ml),
                      onTap: () {
                        bodyTick();
                        setState(() => _selected = _selected == i ? null : i);
                      },
                      style: text,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterColumn extends StatelessWidget {
  const _WaterColumn({
    required this.entry,
    required this.index,
    required this.fraction,
    required this.barArea,
    required this.labelHeight,
    required this.valueHeight,
    required this.met,
    required this.isToday,
    required this.selected,
    required this.label,
    required this.semanticLabel,
    required this.valueText,
    required this.onTap,
    required this.style,
  });

  final ({DateTime day, int ml}) entry;
  final int index;
  final double fraction;
  final double barArea;
  final double labelHeight;
  final double valueHeight;
  final bool met;
  final bool isToday;
  final bool selected;
  final String label;
  final String semanticLabel;
  final String valueText;
  final VoidCallback onTap;
  final TextTheme style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = BodyPalette(t);
    final showValue = selected || isToday;
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: valueHeight,
              child: AnimatedOpacity(
                opacity: showValue && entry.ml > 0 ? 1 : 0,
                duration: context.motion(MadarMotion.short),
                child: FittedBox(
                  child: Text(valueText, style: style.labelSmall?.copyWith(color: isToday ? p.water : t.textSecondary)),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: context.motion(MadarMotion.long + MadarMotion.staggerStep * index),
              curve: MadarMotion.decelerate,
              builder: (context, f, _) => Container(
                width: 18,
                height: math.max(4, barArea * f),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: entry.ml == 0
                      ? null
                      : LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: met
                              ? [p.water, p.waterEnd]
                              : [p.water.withValues(alpha: 0.45), p.water.withValues(alpha: 0.75)],
                        ),
                  color: entry.ml == 0 ? t.glassBorder.withValues(alpha: 0.35) : null,
                  border: selected ? Border.all(color: t.textPrimary.withValues(alpha: 0.7)) : null,
                  boxShadow: met ? [BoxShadow(color: p.water.withValues(alpha: 0.35), blurRadius: 10)] : null,
                ),
              ),
            ),
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Text(
                  label,
                  style: style.labelSmall?.copyWith(
                    color: isToday ? t.textPrimary : t.textTertiary,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0, gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// An exercise's daily values (heaviest weight, volume …) as a soft line
/// with a glow fill. Time runs in the reading direction; the value scale
/// sits at the reading start.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.valueLabel,
    this.height = 190,
    this.semanticLabel,
  });

  final List<ProgressPoint> points;
  final Color color;
  final String Function(double v) valueLabel;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (points.isEmpty) return SizedBox(height: height);
    final from = points.first.day, to = points.last.day;
    final span = math.max(1, BodyDays.between(from, to)).toDouble();
    double xOf(DateTime d) {
      final x = BodyDays.between(from, d).toDouble();
      return rtl ? span - x : x;
    }

    DateTime dayOf(double x) => BodyDays.add(from, (rtl ? span - x : x).round());

    final values = points.map((p) => p.value);
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.18, hi * 0.06 + 0.5);
    final step = _nice((hi - lo + 2 * pad) / 3);
    // Bounds on whole steps, so every grid line has a round label.
    final minY = math.max(0.0, ((lo - pad) / step).floorToDouble() * step);
    final maxY = ((hi + pad) / step).ceilToDouble() * step;
    final labelStyle = (text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: t.textTertiary);
    final dateFormat = DateFormat.MMMd(fmt.languageCode);
    final spots = [for (final p in points) FlSpot(xOf(p.day), p.value)]..sort((a, b) => a.x.compareTo(b.x));

    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: step,
        getTitlesWidget: (value, meta) {
          final onStep = ((value / step) - (value / step).roundToDouble()).abs() < 0.001;
          if (!onStep || value < minY - 0.001 || value > maxY + 0.001) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 6,
            child: Text(fmt.formatNumber(value, maxDecimals: 1), style: labelStyle),
          );
        },
      ),
    );

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: span,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.none(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.22,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.6,
            isStrokeCapRound: true,
            shadow: Shadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: t.isDark ? 0.26 : 0.16), color.withValues(alpha: 0)],
              ),
            ),
            dotData: FlDotData(
              show: spots.length <= 40,
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 3.4, color: color, strokeWidth: 1.6, strokeColor: t.space1),
            ),
          ),
        ],
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
              interval: span,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                child: Text(fmt.localizeDigits(dateFormat.format(dayOf(value))), style: labelStyle),
              ),
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
                LineTooltipItem(
                  '${fmt.localizeDigits(dateFormat.format(dayOf(s.x)))}\n',
                  labelStyle,
                  children: [
                    TextSpan(text: valueLabel(s.y), style: (text.titleSmall ?? const TextStyle()).copyWith(color: color)),
                  ],
                ),
            ],
          ),
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots?.isNotEmpty == true) bodyTick();
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

  static double _nice(double raw) {
    if (raw <= 0) return 1;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
    return nice * exp;
  }
}
