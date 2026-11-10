import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/breathing.dart';
import '../../domain/wellbeing_data.dart';
import '../../domain/wellbeing_stats.dart';
import '../sheets/mood_check_in_sheet.dart';
import '../sheets/pain_log_sheet.dart';
import '../wellbeing_actions.dart';
import '../wellbeing_screen.dart';
import '../wellbeing_texts.dart';
import '../widgets/mood_face.dart';
import '../widgets/support_banner.dart';
import '../widgets/wb_charts.dart';
import '../widgets/wb_palette.dart';
import '../widgets/wb_widgets.dart';

/// Today: the support banner (when it applies), today's check-in, quick
/// pain / breathing entries, trends of every metric and the check-in
/// history.
class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key, this.onBreathe});

  final VoidCallback? onBreathe;

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> {
  int _days = 30;
  WellMetric _metric = WellMetric.mood;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final entries = ref.watch(moodEntriesProvider).value ?? const <MoodEntryRow>[];
    final shown = _showAll ? entries : entries.take(10).toList();
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, wbTabBottomPadding),
      children: [
        const SupportBanner(padding: EdgeInsets.only(bottom: Space.m)),
        const StaggerItem(index: 0, child: _CheckInCard()),
        const SizedBox(height: Space.m),
        StaggerItem(index: 1, child: _QuickRow(onBreathe: widget.onBreathe)),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 2,
          child: _TrendsCard(
            days: _days,
            metric: _metric,
            onDays: (d) => setState(() => _days = d),
            onMetric: (m) => setState(() => _metric = m),
          ),
        ),
        const SizedBox(height: Space.l),
        SectionHeader(
          title: l.wbHistoryCheckIns,
          actionLabel: entries.length > 10 ? (_showAll ? l.wbShowLess : l.wbShowAll) : null,
          onAction: () => setState(() => _showAll = !_showAll),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.m),
            child: WbHint(l.wbHistoryEmpty),
          )
        else
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: StaggerItem(
                index: 3 + i,
                child: CheckInTile(entry: shown[i]),
              ),
            ),
      ],
    );
  }
}

class _CheckInCard extends ConsumerWidget {
  const _CheckInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final today = ref.watch(wellbeingTodayProvider);
    final entry = ref.watch(todayCheckInProvider);
    if (entry == null) {
      return WbCard(
        title: l.wbMoodQuestion,
        icon: Icons.wb_twilight_rounded,
        seed: 1.2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoodFacePicker(
              value: null,
              labels: tx.moodLabels,
              size: 46,
              onChanged: (m) => showMoodCheckInSheet(context, initialMood: m),
            ),
            const SizedBox(height: Space.m),
            Text(l.wbCheckInPrompt, style: text.bodySmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.m),
            MadarButton(
              label: l.wbCheckInFull,
              icon: Icons.tune_rounded,
              variant: MadarButtonVariant.secondary,
              sfx: Sfx.sheetOpen,
              expand: true,
              onPressed: () => showMoodCheckInSheet(context),
            ),
          ],
        ),
      );
    }
    return WbCard(
      title: l.wbTodayCheckIn,
      icon: Icons.wb_twilight_rounded,
      seed: 1.2,
      trailing: MadarButton(
        label: l.wbEdit,
        icon: Icons.edit_outlined,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: Sfx.sheetOpen,
        onPressed: () => showMoodCheckInSheet(context, entry: entry),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (entry.mood != null) ...[
                MoodFace(mood: entry.mood!, size: 60, selected: true),
                const SizedBox(width: Space.l),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.mood != null ? tx.moodLabel(entry.mood!) : l.wbCheckedIn, style: text.titleLarge),
                    Text(tx.dayTime(entry.at, today), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          CheckInValues(entry: entry),
          if (entry.notes != null) ...[
            const SizedBox(height: Space.s),
            Text(
              entry.notes!,
              style: text.bodySmall?.copyWith(color: t.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Space.m),
          MadarButton(
            label: l.wbCheckInAnother,
            icon: Icons.add_rounded,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetOpen,
            onPressed: () => showMoodCheckInSheet(context),
          ),
        ],
      ),
    );
  }
}

/// A check-in's numbers as quiet pills, plus its factor tags.
class CheckInValues extends StatelessWidget {
  const CheckInValues({super.key, required this.entry, this.dense = false});

  final MoodEntryRow entry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    String outOf10(int v) => l.wbOutOf(fmt.formatInt(v), fmt.formatInt(10));
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        if (entry.stress != null)
          WbValuePill(
            label: '${l.wbMetricStress} ${outOf10(entry.stress!)}',
            color: WbPalette.metric(t, WellMetric.stress),
          ),
        if (entry.anxiety != null)
          WbValuePill(
            label: '${l.wbMetricAnxiety} ${outOf10(entry.anxiety!)}',
            color: WbPalette.metric(t, WellMetric.anxiety),
          ),
        if (entry.energy != null)
          WbValuePill(
            label: '${l.wbMetricEnergy} ${outOf10(entry.energy!)}',
            color: WbPalette.metric(t, WellMetric.energy),
          ),
        if (entry.sleepHours != null)
          WbValuePill(
            label: tx.hours(entry.sleepHours!),
            icon: Icons.bedtime_outlined,
            color: WbPalette.metric(t, WellMetric.sleep),
          ),
        if (entry.caffeineCups != null)
          WbValuePill(
            label: tx.cups(entry.caffeineCups!),
            icon: Icons.coffee_outlined,
            color: WbPalette.metric(t, WellMetric.caffeine),
          ),
        if (!dense)
          for (final f in entry.factors) WbValuePill(label: f, icon: Icons.label_outline_rounded, color: t.brass),
      ],
    );
  }
}

class _QuickRow extends ConsumerWidget {
  const _QuickRow({this.onBreathe});

  final VoidCallback? onBreathe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    final pains = ref.watch(todayPainProvider);
    final latest = pains.firstOrNull;
    final pattern = ref.watch(wellbeingSettingsProvider).value?.pattern;
    Widget tile({
      required IconData icon,
      required Color color,
      required String title,
      required String sub,
      required VoidCallback onTap,
      required Sfx sfx,
    }) => Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        semanticLabel: '$title. $sub',
        onTap: () {
          Fx.fire(sfx);
          onTap();
        },
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    sub,
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile(
          icon: Icons.healing_rounded,
          color: WbPalette.pain(t, latest?.score ?? 3),
          title: l.wbLogPain,
          sub: latest == null
              ? l.wbNoPainToday
              : l.wbLastPain(l.wbOutOf(fmt.formatInt(latest.score), fmt.formatInt(10)), tx.time(latest.at)),
          sfx: Sfx.sheetOpen,
          onTap: () => showPainLogSheet(context),
        ),
        const SizedBox(width: Space.s),
        tile(
          icon: Icons.air_rounded,
          color: t.accent,
          title: l.wbBreatheShort,
          sub: pattern == null
              ? tx.patternName(BreathingPattern.fourSevenEight)
              : '${tx.patternName(pattern)} · ${tx.patternRhythm(pattern)}',
          sfx: Sfx.navigate,
          onTap: onBreathe ?? () {},
        ),
      ],
    );
  }
}

class _TrendsCard extends ConsumerWidget {
  const _TrendsCard({required this.days, required this.metric, required this.onDays, required this.onMetric});

  final int days;
  final WellMetric metric;
  final ValueChanged<int> onDays;
  final ValueChanged<WellMetric> onMetric;

  static const metrics = [
    WellMetric.mood,
    WellMetric.stress,
    WellMetric.anxiety,
    WellMetric.energy,
    WellMetric.sleep,
    WellMetric.caffeine,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final today = ref.watch(wellbeingTodayProvider);
    final series = ref.watch(wellbeingSeriesProvider((metric, days)));
    final factors = ref.watch(moodFactorCountsProvider(days));
    final hasAny = (ref.watch(moodEntriesProvider).value ?? const []).isNotEmpty;
    final color = WbPalette.metric(t, metric);
    final mean = WellbeingStats.mean(series);
    final top = series.isEmpty ? metric.max : series.map((p) => p.value).reduce(math.max);
    final maxY = switch (metric) {
      WellMetric.sleep => math.max(10.0, (top + 1).ceilToDouble()),
      WellMetric.caffeine => math.max(4.0, (top + 1).ceilToDouble()),
      _ => metric.max,
    };
    return WbCard(
      title: l.wbTrends,
      icon: Icons.show_chart_rounded,
      seed: 2.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasAny)
            WbHint(l.wbTrendsNone, icon: Icons.show_chart_rounded)
          else ...[
            WbRangePills(values: const [7, 30, 90], value: days, onChanged: onDays),
            const SizedBox(height: Space.s),
            ChoicePills<WellMetric>.single(
              scrollable: true,
              dense: true,
              options: [
                for (final m in metrics) ChoiceOption(value: m, label: tx.metricName(m), color: WbPalette.metric(t, m)),
              ],
              selected: metric,
              onChanged: (m) {
                if (m != null) onMetric(m);
              },
            ),
            const SizedBox(height: Space.s),
            if (series.length < 2)
              SizedBox(
                height: 120,
                child: Center(child: WbHint(l.wbTrendsEmpty(tx.metricName(metric)), icon: Icons.show_chart_rounded)),
              )
            else
              WbLineChart(
                series: series,
                from: WbDays.add(today, -(days - 1)),
                to: today,
                minY: metric.min,
                maxY: maxY,
                color: color,
                interval: metric == WellMetric.mood ? 1 : null,
                semanticLabel: l.wbChartSemantics(tx.metricName(metric), tx.daysShort(days)),
              ),
            if (mean != null) ...[
              const SizedBox(height: Space.s),
              Text(
                l.wbAverageOver(tx.metricValue(metric, mean), tx.dayCount(series.length)),
                style: text.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
            if (factors.isNotEmpty) ...[
              const MadarDivider(ornament: false, height: Space.xl),
              Text(l.wbFactorsFrequent, style: text.titleSmall),
              const SizedBox(height: Space.s),
              WbFrequencyBars(items: factors, color: t.brass, max: 5),
            ],
          ],
        ],
      ),
    );
  }
}

/// A past check-in: tap to edit, long-press / swipe to delete (with undo).
class CheckInTile extends ConsumerWidget {
  const CheckInTile({super.key, required this.entry});

  final MoodEntryRow entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final today = ref.watch(wellbeingTodayProvider);
    final title = entry.mood != null ? tx.moodLabel(entry.mood!) : l.wbCheckedIn;
    return ActionableItem(
      semanticLabel: '$title, ${tx.dayTime(entry.at, today)}',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => showMoodCheckInSheet(context, entry: entry),
      actions: ItemActions(
        onEdit: () => showMoodCheckInSheet(context, entry: entry),
        onDelete: () => WellbeingActions.deleteMood(context, ref, entry),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.wbDelete,
          tone: ActionTone.danger,
          onPressed: () => WellbeingActions.deleteMood(context, ref, entry),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.mood != null)
              MoodFace(mood: entry.mood!, size: 36, selected: true)
            else
              SizedBox.square(dimension: 36, child: Icon(Icons.edit_note_rounded, color: t.textTertiary)),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: text.titleSmall)),
                      Text(tx.dayTime(entry.at, today), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  CheckInValues(entry: entry, dense: true),
                  if (entry.factors.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      entry.factors.join(l.wbListSeparator),
                      style: text.labelSmall?.copyWith(color: t.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (entry.notes != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      entry.notes!,
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
