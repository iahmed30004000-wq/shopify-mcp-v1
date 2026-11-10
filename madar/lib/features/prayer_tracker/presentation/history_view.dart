import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/tracker_providers.dart';
import '../domain/tracker_days.dart';
import '../domain/tracker_prayers.dart';
import '../domain/tracker_stats.dart';
import 'charts/breakdown_bars.dart';
import 'charts/month_heatmap.dart';
import 'charts/segment_ring.dart';
import 'day_sheet.dart';
import 'tracker_actions.dart';
import 'tracker_labels.dart';

/// The History tab: streaks, the last seven days, the month heatmap with
/// its totals and per-prayer bars, and the qada ledger.
class TrackerHistoryView extends ConsumerWidget {
  const TrackerHistoryView({
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(trackerHistoryProvider).value;
    if (history == null) return const Center(child: OrbitLoader(size: 40));
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final month = ref.watch(trackerMonthProvider);
    final totals = history.monthToDate(month.year, month.month);
    final monthName = trackerMonthTitle(fmt, month);
    EdgeInsetsGeometry header([double top = Space.xl]) =>
        EdgeInsetsDirectional.fromSTEB(Space.xs, top, Space.xs, Space.m);
    return ListView(
      padding: padding,
      children: [
        StaggerItem(index: 0, child: StreakCards(streaks: history.streaks)),
        StaggerItem(
          index: 1,
          child: SectionHeader(title: l.trackerWeekTitle, padding: header()),
        ),
        StaggerItem(index: 2, child: WeekStrip(history: history)),
        StaggerItem(
          index: 3,
          child: SectionHeader(title: l.trackerHeatmapTitle, padding: header()),
        ),
        StaggerItem(
          index: 4,
          child: MonthHeatmapCard(history: history, month: month),
        ),
        StaggerItem(
          index: 5,
          child: SectionHeader(title: l.trackerTotalsTitle(monthName), padding: header()),
        ),
        StaggerItem(index: 6, child: TotalsCard(totals: totals)),
        StaggerItem(
          index: 7,
          child: SectionHeader(title: l.trackerBreakdownTitle, padding: header()),
        ),
        StaggerItem(index: 8, child: BreakdownCard(totals: totals)),
        StaggerItem(
          index: 9,
          child: SectionHeader(
            title: l.trackerQadaTitle,
            subtitle: fmt.localizeDigits(l.trackerQadaOutstanding(history.qada.outstanding.length)),
            padding: header(),
          ),
        ),
        StaggerItem(index: 10, child: QadaLedgerView(ledger: history.qada)),
      ],
    );
  }
}

/// "September 2026" / "سبتمبر ٢٠٢٦".
String trackerMonthTitle(MadarFormatter fmt, DateTime month) {
  String format(String locale) => DateFormat.yMMMM(locale).format(month);
  String s;
  try {
    s = format(fmt.languageCode);
  } catch (_) {
    s = format('en');
  }
  return fmt.localizeDigits(s);
}

// ------------------------------------------------------------- streaks --

class StreakCards extends StatelessWidget {
  const StreakCards({super.key, required this.streaks});

  final TrackerStreaks streaks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StreakCard(
                  label: l.trackerStreakCurrent,
                  value: streaks.current,
                  icon: TrackerIcons.streak,
                  color: streaks.current > 0 ? c.onTime : t.textTertiary,
                  lit: streaks.current > 0,
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: _StreakCard(
                  label: l.trackerStreakBest,
                  value: streaks.best,
                  icon: Icons.workspace_premium_rounded,
                  color: streaks.best > 0 ? t.accent : t.textTertiary,
                  lit: false,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.xs, 0),
          child: Text(l.trackerStreakRule, style: text.bodySmall!.copyWith(color: t.textTertiary)),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.lit,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: l.trackerValueOf(label, fmt.localizeDigits(l.trackerStreakDays(value))),
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m + 2, Space.m, Space.m + 2),
        glow: lit,
        glowColor: lit ? color.withValues(alpha: 0.35) : null,
        borderColor: lit ? color.withValues(alpha: 0.5) : null,
        child: ExcludeSemantics(
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                  boxShadow: lit && t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)] : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 24, color: color),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium!.copyWith(color: t.textSecondary, height: 1.25),
                    ),
                    const SizedBox(height: Space.xs),
                    // No run yet: words, not a lone "٠" (which reads as a
                    // dot in Arabic-Indic digits).
                    if (value == 0)
                      Text(
                        l.trackerStreakDays(0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(color: t.textSecondary, height: 1.3),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          RollingNumber(
                            value: value,
                            formatter: (n) => fmt.formatInt(n.round()),
                            style: text.headlineLarge!.copyWith(color: lit ? color : t.textPrimary, height: 1.0),
                          ),
                          const SizedBox(width: Space.xs + 2),
                          Flexible(
                            child: Text(
                              l.trackerDaysUnit(value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium!.copyWith(color: t.textSecondary),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- week strip --

/// The last seven prayer days, oldest at the reading start, each a small
/// ring of five with its date; tap a day to open it.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.history});

  final TrackerHistory history;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    final days = history.lastDays(7);
    return GlassCard(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xs, vertical: Space.m),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: MadarPressable(
                // The sheet plays its own opening sound.
                onTap: () => showTrackerDaySheet(context, d.day),
                sfx: null,
                semanticLabel: _daySemantics(l, fmt, d),
                excludeChildSemantics: true,
                focusRadius: BorderRadius.circular(t.radiusS),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      narrow[MonthGrid.weekdayIndex(d.day)],
                      style: text.labelSmall!.copyWith(
                        color: TrackerDays.sameDay(d.day, history.today) ? t.accent : t.textTertiary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    SegmentRing(
                      segments: RingSegment.ofSummary(d, c),
                      size: 40,
                      strokeWidth: 3.6,
                      complete: d.complete,
                      child: Text(
                        fmt.formatInt(d.day.day),
                        style: text.labelMedium!.copyWith(
                          color: d.complete ? c.onTime : t.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    SizedBox(
                      height: 6,
                      child: TrackerDays.sameDay(d.day, history.today)
                          ? DecoratedBox(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent),
                              child: const SizedBox.square(dimension: 5),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _daySemantics(L10n l, MadarFormatter fmt, DaySummary d) => l.trackerDaySemantics(
  fmt.formatDate(d.day, style: MadarDateStyle.weekdayDayMonth),
  fmt.formatInt(d.fardPrayed),
  fmt.formatInt(TrackerPrayers.obligatory.length),
  fmt.formatInt(d.jamaah),
);

// ------------------------------------------------------------- heatmap --

class MonthHeatmapCard extends ConsumerWidget {
  const MonthHeatmapCard({super.key, required this.history, required this.month});

  final TrackerHistory history;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final dir = Directionality.of(context);
    final first = loc.firstDayOfWeekIndex;
    final controller = ref.read(trackerMonthProvider.notifier);
    final canForward = month.isBefore(DateTime(history.today.year, history.today.month));
    final cells = MonthHeatmapPainter.cellsFor(
      month: month,
      history: history,
      firstDayOfWeek: first,
      label: (d) => fmt.formatInt(d.day),
      semantics: (d, s) => _daySemantics(l, fmt, s),
    );
    final rows = cells.length ~/ 7;
    void open(DateTime d) => showTrackerDaySheet(context, d);

    return GlassCard(
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(trackerMonthTitle(fmt, month), style: text.titleMedium!.copyWith(color: t.textPrimary)),
              ),
              MadarButton.icon(
                icon: Icons.chevron_left_rounded,
                semanticLabel: l.trackerPrevMonth,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.swipe,
                // Material chevrons follow the reading direction: in RTL
                // "previous" points right.
                onPressed: controller.previous,
              ),
              const SizedBox(width: Space.xs),
              MadarButton.icon(
                icon: Icons.chevron_right_rounded,
                semanticLabel: l.trackerNextMonth,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.swipe,
                onPressed: canForward ? controller.next : null,
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final (i, w) in MonthGrid.weekdayOrder(first).indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            loc.narrowWeekdays[w],
                            textAlign: TextAlign.center,
                            style: text.labelSmall!.copyWith(color: t.textTertiary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  TweenAnimationBuilder<double>(
                    key: ValueKey(month),
                    tween: Tween(begin: 0, end: 1),
                    duration: context.motion(MadarMotion.long),
                    curve: MadarMotion.decelerate,
                    builder: (context, reveal, _) {
                      final painter = MonthHeatmapPainter(
                        cells: cells,
                        tokens: t,
                        textDirection: dir,
                        textStyle: MadarTypography.numerals(t, size: 13),
                        reveal: reveal,
                        onTap: open,
                      );
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Screen readers get one labelled target per day
                        // from the painter's semantics instead.
                        excludeFromSemantics: true,
                        onTapUp: (d) {
                          final layout = painter.layoutFor(Size(width, HeatmapLayout.heightFor(width, rows)));
                          final i = layout.indexAt(d.localPosition);
                          if (i == null || i >= cells.length) return;
                          final cell = cells[i];
                          if (cell == null || cell.future) return;
                          open(cell.day);
                        },
                        child: CustomPaint(size: Size(width, HeatmapLayout.heightFor(width, rows)), painter: painter),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.m),
          _HeatLegend(colors: c),
        ],
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend({required this.colors});

  final TrackerColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final style = text.labelSmall!.copyWith(color: t.textTertiary);
    Widget swatch(double completion) => Container(
      width: 14,
      height: 14,
      margin: const EdgeInsetsDirectional.only(end: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Color.lerp(t.space2, colors.onTime, MonthHeatmapPainter.strengthOf(completion)),
        border: Border.all(color: t.glassHighlight.withValues(alpha: 0.3)),
      ),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.m,
      runSpacing: Space.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(l.trackerLegendLess, style: style)),
            const SizedBox(width: Space.xs),
            for (final s in const [0.2, 0.4, 0.6, 0.8, 1.0]) swatch(s),
            const SizedBox(width: Space.xs),
            Flexible(child: Text(l.trackerLegendMore, style: style)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsetsDirectional.only(end: 2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.jamaah),
              ),
            const SizedBox(width: Space.xs),
            Flexible(child: Text(l.trackerLegendJamaah, style: style)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.missed),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: Space.xs),
            Flexible(child: Text(l.trackerStatusMissed, style: style)),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- totals --

class TotalsCard extends StatelessWidget {
  const TotalsCard({super.key, required this.totals});

  final TrackerTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    if (totals.isEmpty) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.insights_rounded, color: t.textTertiary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(l.trackerNoMonthData, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
          ],
        ),
      );
    }
    final metrics = [
      (l.trackerTotalOnTime, totals.onTimeShare, c.onTime, TrackerIcons.prayed),
      (l.trackerTotalJamaah, totals.jamaahShare, c.jamaah, TrackerIcons.jamaah),
      (l.trackerTotalMosque, totals.mosqueShare, c.mosque, TrackerIcons.mosque),
    ];
    return GlassCard(
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (label, share, color, icon)) in metrics.indexed) ...[
                if (i > 0) const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    children: [
                      ProgressRing(
                        value: share,
                        size: 70,
                        strokeWidth: 6,
                        color: color,
                        semanticLabel: label,
                        semanticValue: fmt.formatPercent(share),
                        child: Text(
                          fmt.formatPercent(share),
                          style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1),
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium!.copyWith(color: t.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.l),
          Divider(height: 1, color: t.glassBorder),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Count(label: l.trackerTotalCompleteDays, value: totals.completeDays, color: c.onTime),
              _Count(label: l.trackerTotalRawatib, value: totals.rawatib, color: t.textPrimary),
              _Count(label: l.trackerDuha, value: totals.voluntaryOf(Prayer.duha), color: t.textPrimary),
              _Count(label: l.trackerWitr, value: totals.voluntaryOf(Prayer.witr), color: t.textPrimary),
              _Count(label: l.trackerQiyam, value: totals.voluntaryOf(Prayer.qiyam), color: t.textPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        label: l.trackerValueOf(label, fmt.formatInt(value)),
        excludeSemantics: true,
        child: Column(
          children: [
            Text(fmt.formatInt(value), style: text.titleLarge!.copyWith(color: color, height: 1.1)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall!.copyWith(color: t.textTertiary, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- breakdown --

class BreakdownCard extends StatelessWidget {
  const BreakdownCard({super.key, required this.totals});

  final TrackerTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final dir = Directionality.of(context);
    final days = totals.days;
    return GlassCard(
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in TrackerPrayers.obligatory)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.m),
              child: Builder(
                builder: (context) {
                  final b = totals.breakdownOf(p);
                  final prayed = b.onTime + b.late + b.madeUp;
                  final label = l.trackerPrayerName(p);
                  return Semantics(
                    label: [
                      l.trackerValueOf(l.trackerStatusPrayed, fmt.formatInt(b.onTime)),
                      l.trackerValueOf(l.trackerStatusLate, fmt.formatInt(b.late)),
                      l.trackerValueOf(l.trackerStatusQada, fmt.formatInt(b.madeUp)),
                      l.trackerValueOf(l.trackerStatusMissed, fmt.formatInt(b.missed)),
                    ].fold<String>(label, (a, b) => l.trackerMarks(a, b)),
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge!.copyWith(color: t.textPrimary),
                          ),
                        ),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: context.motion(MadarMotion.long),
                            curve: MadarMotion.decelerate,
                            builder: (context, v, _) => CustomPaint(
                              size: const Size.fromHeight(12),
                              painter: BreakdownBarPainter(
                                breakdown: b,
                                days: days,
                                tokens: t,
                                textDirection: dir,
                                reveal: v,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        SizedBox(
                          width: 44,
                          child: Text(
                            fmt.formatInt(prayed),
                            textAlign: TextAlign.end,
                            style: MadarTypography.numerals(t, size: 13, color: t.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.xs,
            children: [
              for (final (label, color) in [
                (l.trackerStatusPrayed, c.onTime),
                (l.trackerStatusLate, c.late),
                (l.trackerStatusQada, c.qada),
                (l.trackerStatusMissed, c.missed),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(label, style: text.labelSmall!.copyWith(color: t.textSecondary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- qada --

/// Missed prayers still owed, filterable by prayer; each can be made up
/// (tap the button or swipe right), keeping the day it was missed. A long
/// backlog (an imported history) is shown [pageSize] rows at a time, so the
/// History tab never builds hundreds of rows at once; "made them all up"
/// still covers every entry of the filter.
class QadaLedgerView extends ConsumerStatefulWidget {
  const QadaLedgerView({super.key, required this.ledger});

  final QadaLedger ledger;

  /// Rows shown at first and added by each "show more".
  static const pageSize = 12;

  @override
  ConsumerState<QadaLedgerView> createState() => _QadaLedgerViewState();
}

class _QadaLedgerViewState extends ConsumerState<QadaLedgerView> {
  int _shown = QadaLedgerView.pageSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final ledger = widget.ledger;
    final filter = ref.watch(qadaFilterProvider);
    final counts = ledger.countsByPrayer;
    final entries = ledger.filtered(filter);
    final visible = entries.length > _shown ? entries.sublist(0, _shown) : entries;
    final hidden = entries.length - visible.length;
    final actions = TrackerActions(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ledger.isEmpty || filter != null)
          ChoicePills<Prayer?>.single(
            options: [
              ChoiceOption(value: null, label: '${l.trackerFilterAll} ${fmt.formatInt(ledger.outstanding.length)}'),
              for (final p in TrackerPrayers.obligatory)
                ChoiceOption(value: p, label: '${l.trackerPrayerName(p)} ${fmt.formatInt(counts[p] ?? 0)}'),
            ],
            selected: filter,
            onChanged: (p) {
              setState(() => _shown = QadaLedgerView.pageSize);
              ref.read(qadaFilterProvider.notifier).select(p);
            },
            scrollable: true,
            dense: true,
            padding: EdgeInsetsDirectional.zero,
          ),
        if (!ledger.isEmpty || filter != null) const SizedBox(height: Space.m),
        if (entries.isEmpty)
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: c.jamaah),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    filter == null ? l.trackerQadaEmpty : l.trackerQadaEmptyFiltered(l.trackerPrayerName(filter)),
                    style: text.bodyMedium!.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final e in visible)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: _QadaRow(key: ValueKey(e.log.id), entry: e, actions: actions),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
              child: MadarButton(
                label: fmt.localizeDigits(
                  l.trackerQadaShowMore(hidden < QadaLedgerView.pageSize ? hidden : QadaLedgerView.pageSize),
                ),
                icon: Icons.expand_more_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.tap,
                onPressed: () => setState(() => _shown += QadaLedgerView.pageSize),
              ),
            ),
          if (entries.length > 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs),
              child: MadarButton(
                label: l.trackerActionMakeUpAll(entries.length),
                icon: TrackerIcons.qada,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.levelUp,
                onPressed: () async => actions.toast(
                  await actions.makeUpAll([for (final e in entries) (e.day, e.prayer)], feedback: false),
                ),
              ),
            ),
        ],
        const SizedBox(height: Space.m),
        Text(
          l.trackerQadaMadeUpSoFar(fmt.formatInt(ledger.madeUp)),
          style: text.bodySmall!.copyWith(color: t.textTertiary),
        ),
      ],
    );
  }
}

class _QadaRow extends StatelessWidget {
  const _QadaRow({super.key, required this.entry, required this.actions});

  final QadaEntry entry;
  final TrackerActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final name = l.trackerPrayerName(entry.prayer);
    final date = fmt.formatDate(entry.day, style: MadarDateStyle.weekdayDayMonth);
    Future<void> makeUp() async => actions.toast(await actions.makeUp(entry.day, entry.prayer, feedback: false));
    return ActionableItem(
      onCompleteSwipe: () => actions.makeUp(entry.day, entry.prayer, feedback: false),
      completeIcon: TrackerIcons.qada,
      completeLabel: l.trackerActionMadeUp,
      semanticLabel: l.trackerMarks(name, l.trackerQadaMissedOn(date)),
      actions: ItemActions(
        extra: [
          ItemAction(
            icon: TrackerIcons.qada,
            label: l.trackerActionMadeUp,
            tone: ActionTone.info,
            onSelected: () => actions.makeUp(entry.day, entry.prayer),
          ),
          ItemAction(
            icon: TrackerIcons.prayed,
            label: l.trackerActionPrayed,
            tone: ActionTone.accent,
            onSelected: () => actions.setStatus(entry.day, entry.prayer, PrayerStatus.prayed),
          ),
          ItemAction(
            icon: TrackerIcons.clear,
            label: l.trackerActionClear,
            onSelected: () => actions.clear(entry.day, entry.prayer),
          ),
        ],
      ),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.s),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.missed.withValues(alpha: 0.12),
                border: Border.all(color: c.missed.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(TrackerIcons.of(entry.prayer), size: 18, color: c.missed),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.3)),
                  Text(
                    l.trackerQadaMissedOn(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            // Very large text: the round icon button (same action, same
            // label for screen readers) so the row never overflows.
            if (MediaQuery.textScalerOf(context).scale(1) > 1.4)
              MadarButton.icon(
                icon: TrackerIcons.qada,
                semanticLabel: l.trackerActionMadeUp,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.complete,
                onPressed: makeUp,
              )
            else
              MadarButton(
                label: l.trackerActionMadeUp,
                icon: TrackerIcons.qada,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.complete,
                onPressed: makeUp,
              ),
          ],
        ),
      ),
    );
  }
}
