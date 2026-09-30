import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../custom_texts.dart';
import '../../domain/module_charts.dart';
import '../../domain/module_schema.dart';
import 'module_visuals.dart';

/// A module's chart with its controls: style (line / bars / calendar /
/// streak) and period (7 / 30 / 90 days), plus the numbers that matter for
/// the plotted field (total, average, active days, streaks).
///
/// Time runs in the reading direction: today at the reading end (on the
/// left in Arabic, on the right in English).
class ModuleChartCard extends StatelessWidget {
  const ModuleChartCard({
    super.key,
    required this.module,
    required this.entries,
    required this.today,
    this.onConfigChanged,
    this.height = 180,
  });

  final ModuleDefinition module;
  final List<ModuleEntry> entries;
  final DateTime today;

  /// Persists a style / period change (null = read-only).
  final ValueChanged<ModuleChartConfig>? onConfigChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final config = module.effectiveChart;
    final data = ModuleCharts.build(module: module, entries: entries, today: today, config: config);
    final c = ModuleColors.of(module.colorArgb, t);
    final title = data.field?.label ?? l.cmodChartEntries;

    void change(ModuleChartConfig next) {
      Fx.fire(Sfx.tap);
      onConfigChanged?.call(next);
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(ModuleIcons.chart(data.config.type), size: 18, color: c.ink),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(tx.name(title), style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (onConfigChanged != null)
                for (final type in ModuleChartType.values)
                  _IconToggle(
                    icon: ModuleIcons.chart(type),
                    label: tx.chartType(type),
                    selected: data.config.type == type,
                    color: c,
                    onTap: () => change(data.config.copyWith(type: type)),
                  ),
            ],
          ),
          const SizedBox(height: Space.m),
          Semantics(
            container: true,
            label: _summary(tx, data, title),
            child: SizedBox(
              height: data.config.type == ModuleChartType.heat && data.config.range == 90 ? height + 20 : height,
              child: data.isEmpty && data.config.type != ModuleChartType.streak
                  ? _EmptyChart(color: c, label: l.cmodChartEmpty)
                  : switch (data.config.type) {
                      ModuleChartType.line => _LineView(data: data, colors: c, tx: tx),
                      ModuleChartType.bar => _BarView(data: data, colors: c, tx: tx),
                      ModuleChartType.heat => _HeatView(data: data, colors: c, tx: tx),
                      ModuleChartType.streak => _StreakView(data: data, colors: c, tx: tx),
                    },
            ),
          ),
          if (onConfigChanged != null) ...[
            const SizedBox(height: Space.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final r in ModuleChartConfig.ranges)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xs),
                    child: _RangeChip(
                      label: tx.range(r),
                      semanticLabel: tx.range(r),
                      selected: data.config.range == r,
                      color: c,
                      onTap: () => change(data.config.copyWith(range: r)),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.m),
          Divider(height: 1, color: t.glassBorder),
          const SizedBox(height: Space.m),
          _Stats(data: data, tx: tx, colors: c),
        ],
      ),
    );
  }

  static String _summary(CustomTexts tx, ModuleChartData d, String title) {
    final parts = <String>[
      tx.name(title),
      tx.lastDays(d.config.range),
      tx.activeDays(d.activeDays),
      if (d.aggregate == ChartAggregate.sum || d.aggregate == ChartAggregate.count) tx.total(tx.number(_r(d.total))),
      if (d.average case final double a when d.aggregate != ChartAggregate.any) tx.average(tx.number(_r(a))),
      tx.streak(d.currentStreak, d.bestStreak),
    ];
    return parts.join(tx.arabic ? '، ' : ', ');
  }
}

double _r(double v) => (v * 10).roundToDouble() / 10;

// ---------------------------------------------------------------- views --

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.color, required this.label});

  final ModuleColors color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _BaselinePainter(t.glassBorder)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_rounded, color: color.ink.withValues(alpha: 0.6), size: 30),
            const SizedBox(height: Space.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary)),
          ],
        ),
      ],
    );
  }
}

class _BaselinePainter extends CustomPainter {
  _BaselinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.55, 0.85]) {
      final y = size.height * f;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), p);
      }
    }
  }

  @override
  bool shouldRepaint(_BaselinePainter old) => old.color != color;
}

/// Shared axis pieces of the line and bar views.
class _Axes {
  _Axes(this.data, this.tx, this.t, this.rtl);

  final ModuleChartData data;
  final CustomTexts tx;
  final MadarTokens t;
  final bool rtl;

  int get n => data.days.length;

  /// x of day [i] (0 = oldest): today at the reading end.
  double xOf(int i) => rtl ? (n - 1 - i).toDouble() : i.toDouble();
  int indexOf(double x) => rtl ? n - 1 - x.round() : x.round();

  /// The data's top (a rating's scale, 1 for check-ins).
  double get _top {
    final m = switch (data.aggregate) {
      ChartAggregate.average => data.field?.ratingMax.toDouble() ?? data.maxValue,
      ChartAggregate.any => 1.0,
      _ => data.maxValue,
    };
    return m <= 0 ? 1 : m;
  }

  /// A round grid step giving about three lines.
  double get stepY {
    final m = _top;
    if (data.aggregate == ChartAggregate.any) return 0.5;
    if (m <= 3) return 1;
    final raw = m / 3;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm <= 1 ? 1 : (norm <= 2 ? 2 : (norm <= 2.5 ? 2.5 : (norm <= 5 ? 5 : 10)));
    return nice * mag;
  }

  /// The axis top: a whole number of steps above the data.
  double get maxY {
    if (data.aggregate == ChartAggregate.any) return 1;
    final step = stepY;
    return (_top * 1.05 / step).ceil() * step;
  }

  TextStyle get labelStyle => TextStyle(color: t.textTertiary, fontSize: 10.5, height: 1.1);

  String dayLabel(DateTime d) {
    final lang = tx.fmt.languageCode;
    final f = data.config.range <= 7 ? DateFormat.E(lang) : DateFormat.MMMd(lang);
    return tx.fmt.localizeDigits(f.format(d));
  }

  bool showsLabel(int i) {
    final r = data.config.range;
    if (r <= 7) return true;
    final every = r <= 30 ? 7 : 30;
    return (n - 1 - i) % every == 0;
  }

  FlTitlesData titles() {
    final values = AxisTitles(
      sideTitles: SideTitles(
        showTitles: data.aggregate != ChartAggregate.any,
        reservedSize: 34,
        interval: stepY,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          space: 4,
          child: Text(tx.fmt.formatNumber(value, maxDecimals: 1), style: labelStyle),
        ),
      ),
    );
    return FlTitlesData(
      topTitles: const AxisTitles(),
      leftTitles: rtl ? const AxisTitles() : values,
      rightTitles: rtl ? values : const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = indexOf(value);
            if (i < 0 || i >= n || !showsLabel(i) || value != value.roundToDouble()) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              space: 5,
              fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
              child: Text(dayLabel(data.days[i].day), style: labelStyle),
            );
          },
        ),
      ),
    );
  }

  FlGridData grid() => FlGridData(
    drawVerticalLine: false,
    horizontalInterval: stepY,
    getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.45), strokeWidth: 0.8),
  );

  String tooltip(int i) {
    final d = data.days[i];
    final v = d.value;
    final value = v == null ? '—' : _valueText(tx, data, v);
    return '${dayLabelLong(d.day)}\n$value';
  }

  String dayLabelLong(DateTime d) => tx.fmt.localizeDigits(DateFormat.MMMEd(tx.fmt.languageCode).format(d));
}

String _valueText(CustomTexts tx, ModuleChartData data, double v) {
  final f = data.field;
  switch (data.aggregate) {
    case ChartAggregate.count:
      return tx.entries(v.round());
    case ChartAggregate.any:
      return v > 0 ? tx.l.cmodChecked : tx.l.cmodUnchecked;
    case ChartAggregate.average:
      return '${tx.number(_r(v))}/${tx.count(f?.ratingMax ?? 5)}';
    case ChartAggregate.sum:
      final n = tx.number(_r(v));
      if (f == null) return n;
      if (f.type == FieldType.currency) return '$n ${f.currencyCode}';
      return f.unit == null ? n : '$n ${f.unit}';
  }
}

class _LineView extends StatelessWidget {
  const _LineView({required this.data, required this.colors, required this.tx});

  final ModuleChartData data;
  final ModuleColors colors;
  final CustomTexts tx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final a = _Axes(data, tx, t, rtl);
    // Days without entries: 0 for counts and check-ins, skipped (the line
    // joins the logged days) for sums and averages.
    final gaps = data.aggregate == ChartAggregate.average || data.aggregate == ChartAggregate.sum;
    final spots = <FlSpot>[
      for (var i = 0; i < a.n; i++)
        if (data.days[i].value != null || !gaps) FlSpot(a.xOf(i), data.days[i].value ?? 0),
    ]..sort((p, q) => p.x.compareTo(q.x));
    final color = colors.base;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (a.n - 1).toDouble(),
        minY: 0,
        maxY: a.maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.4,
            isStrokeCapRound: true,
            shadow: Shadow(color: colors.glow, blurRadius: 8),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: t.isDark ? 0.3 : 0.18), color.withValues(alpha: 0)],
              ),
            ),
            dotData: FlDotData(
              show: data.config.range <= 30,
              checkToShowDot: (spot, _) => (data.days[a.indexOf(spot.x)].value ?? 0) > 0,
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 2.8, color: color, strokeWidth: 1.2, strokeColor: t.space1),
            ),
          ),
        ],
        gridData: a.grid(),
        borderData: FlBorderData(show: false),
        titlesData: a.titles(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
            tooltipBorder: BorderSide(color: t.glassBorder),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(a.tooltip(a.indexOf(s.x)), TextStyle(color: t.textPrimary, fontSize: 12, height: 1.3)),
            ],
          ),
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots?.isNotEmpty == true) Fx.fire(Sfx.countTick, volume: 0.5);
          },
        ),
      ),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
    );
  }
}

class _BarView extends StatelessWidget {
  const _BarView({required this.data, required this.colors, required this.tx});

  final ModuleChartData data;
  final ModuleColors colors;
  final CustomTexts tx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final a = _Axes(data, tx, t, rtl);
    final width = switch (data.config.range) {
      <= 7 => 18.0,
      <= 30 => 6.0,
      _ => 2.4,
    };
    final color = colors.base;
    final groups = [
      for (var i = 0; i < a.n; i++)
        BarChartGroupData(
          x: a.xOf(i).round(),
          barRods: [
            BarChartRodData(
              toY: data.days[i].value ?? 0,
              width: width,
              borderRadius: BorderRadius.vertical(top: Radius.circular(width / 2.2)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: i == a.n - 1
                    ? [color.withValues(alpha: 0.85), HSLColor.fromColor(color).withLightness(0.72).toColor()]
                    : [color.withValues(alpha: 0.35), color.withValues(alpha: 0.75)],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: data.config.range <= 7,
                toY: a.maxY,
                color: t.glassBorder.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
    ]..sort((p, q) => p.x.compareTo(q.x));
    return BarChart(
      BarChartData(
        maxY: a.maxY,
        minY: 0,
        barGroups: groups,
        alignment: BarChartAlignment.spaceAround,
        gridData: a.grid(),
        borderData: FlBorderData(show: false),
        titlesData: a.titles(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
            tooltipBorder: BorderSide(color: t.glassBorder),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, _, _, _) =>
                BarTooltipItem(a.tooltip(a.indexOf(group.x.toDouble())), TextStyle(color: t.textPrimary, fontSize: 12, height: 1.3)),
          ),
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.spot != null) Fx.fire(Sfx.countTick, volume: 0.5);
          },
        ),
      ),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
    );
  }
}

/// The heat calendar: one row of seven days for a week, else weeks as
/// columns (oldest at the reading start) and weekdays as rows.
class _HeatView extends StatelessWidget {
  const _HeatView({required this.data, required this.colors, required this.tx});

  final ModuleChartData data;
  final ModuleColors colors;
  final CustomTexts tx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final firstWeekday = tx.arabic ? DateTime.saturday : DateTime.sunday;
    final weekdayFmt = DateFormat.E(tx.fmt.languageCode);
    final labelStyle = TextStyle(color: t.textTertiary, fontSize: 10, height: 1.1);
    Color cellColor(ChartDay? d) {
      if (d == null) return Colors.transparent;
      final k = data.intensity(d);
      if (d.value == null || k <= 0) return t.textPrimary.withValues(alpha: t.isDark ? 0.07 : 0.06);
      return Color.lerp(colors.base.withValues(alpha: 0.25), colors.base, k)!;
    }

    Widget cell(ChartDay? d, double size) {
      final today = d != null && ModuleCharts.dayOf(d.day) == ModuleCharts.dayOf(data.days.last.day);
      return Tooltip(
        message: d == null ? '' : '${tx.dayLabel(d.day, data.days.last.day)} · ${d.value == null ? '—' : _valueText(tx, data, d.value!)}',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cellColor(d),
            borderRadius: BorderRadius.circular(size * 0.28),
            border: today ? Border.all(color: t.metalGold, width: 1.4) : null,
            boxShadow: d != null && data.intensity(d) > 0.75 ? [BoxShadow(color: colors.glow, blurRadius: 6)] : null,
          ),
        ),
      );
    }

    if (data.config.range <= 7) {
      return LayoutBuilder(
        builder: (context, box) {
          final size = math.min(40.0, (box.maxWidth - 6 * Space.s) / 7);
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in data.days)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tx.fmt.localizeDigits(weekdayFmt.format(d.day)), style: labelStyle),
                      const SizedBox(height: Space.xs),
                      cell(d, size),
                      const SizedBox(height: Space.xs),
                      Text(tx.fmt.formatInt(d.day.day), style: labelStyle),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    }

    final weeks = ModuleCharts.heatWeeks(data.days, firstWeekday: firstWeekday);
    final order = ModuleCharts.weekdayOrder(firstWeekday: firstWeekday);
    return LayoutBuilder(
      builder: (context, box) {
        const labelW = 30.0;
        const gap = 3.0;
        final size = math.min(22.0, (box.maxWidth - labelW - gap * weeks.length) / weeks.length);
        final rowH = math.min(size + gap, (box.maxHeight - 2) / 7);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelW,
              child: Column(
                children: [
                  for (var r = 0; r < 7; r++)
                    SizedBox(
                      height: rowH,
                      child: r.isEven
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                tx.fmt.localizeDigits(weekdayFmt.format(DateTime(2026, 6, order[r])) /* 1 Jun 2026 is a Monday */),
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final w in weeks)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: gap),
                      child: Column(
                        children: [
                          for (var r = 0; r < 7; r++)
                            SizedBox(height: rowH, child: Center(child: cell(w[r], math.min(size, rowH - gap)))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The current streak as a flame, the best one, the check-in rate as a
/// ring and the last fortnight as dots.
class _StreakView extends StatelessWidget {
  const _StreakView({required this.data, required this.colors, required this.tx});

  final ModuleChartData data;
  final ModuleColors colors;
  final CustomTexts tx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = tx.l;
    final last = data.days.length > 14 ? data.days.sublist(data.days.length - 14) : data.days;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 34,
                      color: data.currentStreak > 0 ? t.gold : t.textTertiary,
                      shadows: data.currentStreak > 0 ? [Shadow(color: t.gold.withValues(alpha: 0.6), blurRadius: 14)] : null,
                    ),
                    Text(
                      tx.count(data.currentStreak),
                      style: text.displaySmall!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700, height: 1.05),
                    ),
                    Text(
                      '${l.cmodStatStreak} · ${tx.days(data.currentStreak)}',
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 70, color: t.glassBorder),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ProgressRing(
                      value: data.activeRate,
                      size: 74,
                      strokeWidth: 6,
                      color: colors.base,
                      semanticLabel: l.cmodStatRate,
                      semanticValue: tx.fmt.formatPercent(data.activeRate),
                      child: Text(tx.fmt.formatPercent(data.activeRate), style: text.titleSmall!.copyWith(color: colors.ink)),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${l.cmodStatBest}: ${tx.days(data.bestStreak)}',
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in last)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: d.active ? colors.base : Colors.transparent,
                    border: Border.all(color: d.active ? colors.base : t.glassBorder, width: 1.4),
                    boxShadow: d.active ? [BoxShadow(color: colors.glow, blurRadius: 6)] : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- stats --

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.tx, required this.colors});

  final ModuleChartData data;
  final CustomTexts tx;
  final ModuleColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = tx.l;
    final avg = data.average;
    final items = <(String, String)>[
      switch (data.aggregate) {
        ChartAggregate.sum || ChartAggregate.count => (l.cmodStatTotal, _valueText(tx, data, _r(data.total))),
        ChartAggregate.average => (l.cmodStatAverage, avg == null ? '—' : _valueText(tx, data, avg)),
        ChartAggregate.any => (l.cmodStatRate, tx.fmt.formatPercent(data.activeRate)),
      },
      if (data.aggregate == ChartAggregate.sum)
        (l.cmodStatAverage, avg == null ? '—' : _valueText(tx, data, avg))
      else if (data.config.type != ModuleChartType.streak)
        (l.cmodStatStreak, tx.count(data.currentStreak)),
      (l.cmodStatActive, tx.count(data.activeDays)),
    ];
    return Row(
      children: [
        for (final (label, value) in items)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: text.titleSmall!.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: text.labelSmall!.copyWith(color: t.textTertiary), maxLines: 1),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- controls --

class _IconToggle extends StatelessWidget {
  const _IconToggle({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final ModuleColors color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          radius: 20,
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion(MadarMotion.short),
            width: 32,
            height: 32,
            margin: const EdgeInsetsDirectional.only(start: 2),
            decoration: BoxDecoration(
              color: selected ? color.soft : Colors.transparent,
              borderRadius: BorderRadius.circular(t.radiusS),
              border: Border.all(color: selected ? color.base.withValues(alpha: 0.6) : Colors.transparent),
            ),
            child: Icon(icon, size: 18, color: selected ? color.ink : t.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final ModuleColors color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkResponse(
        radius: 22,
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          constraints: const BoxConstraints(minWidth: 64),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.base : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? color.base : t.glassBorder),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: selected ? color.onBase : t.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
