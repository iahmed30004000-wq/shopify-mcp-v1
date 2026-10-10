import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/domain/body_clock.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/food_log.dart';
import '../../domain/nutrition_insights.dart';
import '../nutrition_texts.dart';
import '../widgets/nutrition_widgets.dart';

/// The days of the insight window, each with its markers and its numbers –
/// what every observation is counted over, so a tap can open the days
/// behind any number.
final nutritionInsightDaysProvider = Provider.family<List<NutritionDay>, String>((ref, lateLabel) {
  final metrics = ref.watch(nutritionMetricRowsProvider).value;
  if (metrics == null) return const [];
  return NutritionInsights.buildDays(
    entries: ref.watch(nutritionEntriesProvider),
    today: ref.watch(nutritionTodayProvider),
    foodsById: ref.watch(nutritionFoodsByIdProvider),
    pains: metrics.pains,
    moods: metrics.moods,
    waters: metrics.waters,
    fasts: metrics.fasts,
    clock: ref.watch(nutritionWallClockProvider),
  );
});

/// Plain observations over his own data.
///
/// Two things this screen refuses to do: speak before there is enough data
/// (it shows the progress toward the minimum instead), and word a count as
/// a cause. Every number can be opened to see the days behind it.
class NutritionInsightsScreen extends ConsumerWidget {
  const NutritionInsightsScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final lateLabel = l.nutritionLateMealLabel;
    final insights = ref.watch(nutritionInsightsProvider(lateLabel));
    final readiness = ref.watch(nutritionReadinessProvider);
    final window = tx.fmt.formatInt(NutritionInsights.windowDays);

    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, fade: false, child: child);

    return MadarScaffold(
      title: l.nutritionInsightsTitle,
      backdropSeed: 10.3,
      animateBackdrop: animateBackdrop,
      body: EntranceChoreo(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl),
          children: [
            stagger(
              BodyCard(
                title: l.nutritionInsightsTitle,
                icon: Icons.insights_rounded,
                iconColor: p.insight,
                seed: 10.3,
                child: Text(
                  l.nutritionInsightsLead,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: Space.m),

            if (!readiness.ready) ...[
              stagger(ReadinessCard(readiness: readiness)),
              const SizedBox(height: Space.m),
              stagger(
                BodyCard(
                  key: const ValueKey('nutrition.insights.whatWeLookAt'),
                  title: l.nutritionWhatWeLookAt,
                  icon: Icons.visibility_outlined,
                  iconColor: p.insight,
                  seed: 11.4,
                  child: Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      for (final m in NutritionMetric.values)
                        BodyPill(label: tx.metric(m), color: p.insight, dense: true),
                    ],
                  ),
                ),
              ),
            ]
            else if (insights.isEmpty)
              stagger(
                AnimatedEmptyState(
                  key: const ValueKey('nutrition.insights.nothing'),
                  kind: EmptyStateKind.noData,
                  title: l.nutritionInsightsEmptyTitle,
                  body: l.nutritionInsightsEmptyBody,
                ),
              )
            else ...[
              if (insights.overlaps.isNotEmpty) ...[
                stagger(BodySectionTitle(l.nutritionWorstDaysTitle, icon: Icons.trending_down_rounded)),
                for (final o in insights.overlaps)
                  stagger(
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: ObservationCard(
                        itemKey: 'overlap.${o.metric.name}.${o.marker.key}',
                        line: l.nutritionWorstDaysLine(
                          tx.fmt.formatInt(o.worstDays),
                          tx.metric(o.metric),
                          tx.name(o.marker.label),
                          tx.fmt.formatInt(o.inWorst),
                          tx.fmt.formatInt(o.otherDays),
                          tx.fmt.formatInt(o.inOther),
                        ),
                        window: l.nutritionWindowNote(window),
                        onOpenDays: () => showInsightDaysSheet(
                          context,
                          lateLabel: lateLabel,
                          metric: o.metric,
                          markerKey: o.marker.key,
                          markerLabel: o.marker.label,
                        ),
                      ),
                    ),
                  ),
              ],
              if (insights.means.isNotEmpty) ...[
                stagger(BodySectionTitle(l.nutritionMeansTitle, icon: Icons.compare_arrows_rounded)),
                for (final m in insights.means)
                  stagger(
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: ObservationCard(
                        itemKey: 'means.${m.metric.name}.${m.marker.key}',
                        line: l.nutritionMeansLine(
                          tx.name(m.marker.label),
                          tx.fmt.formatInt(m.daysWith),
                          tx.metric(m.metric),
                          tx.metricValue(m.metric, m.meanWith),
                          tx.fmt.formatInt(m.daysWithout),
                          tx.metricValue(m.metric, m.meanWithout),
                        ),
                        window: l.nutritionWindowNote(window),
                        onOpenDays: () => showInsightDaysSheet(
                          context,
                          lateLabel: lateLabel,
                          metric: m.metric,
                          markerKey: m.marker.key,
                          markerLabel: m.marker.label,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// How far his log is from the first observation – a progress ring and the
/// plain sentence, never a number pretending to be an insight.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, required this.readiness});

  final NutritionReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    return BodyCard(
      key: const ValueKey('nutrition.insights.readiness'),
      title: l.nutritionNotReadyTitle,
      icon: Icons.hourglass_bottom_rounded,
      iconColor: p.insight,
      seed: 10.9,
      child: Row(
        children: [
          ProgressRing(
            value: readiness.progress,
            size: 62,
            strokeWidth: 6,
            color: p.insight,
            semanticLabel: l.nutritionNotReadyTitle,
            semanticValue: tx.fmt.formatPercent(readiness.progress),
            child: Text(
              tx.fmt.formatInt(readiness.daysLogged),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  key: const ValueKey('nutrition.insights.notReady'),
                  l.nutritionNotReadyBody(
                    tx.fmt.formatInt(readiness.daysNeeded),
                    tx.fmt.formatInt(readiness.daysLogged),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  l.nutritionNotReadyMore(tx.fmt.formatInt(readiness.daysLeft)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One observation: the sentence, the window it was counted over, and a way
/// into the days behind it.
class ObservationCard extends StatelessWidget {
  const ObservationCard({
    super.key,
    required this.itemKey,
    required this.line,
    required this.window,
    required this.onOpenDays,
  });

  final String itemKey;
  final String line;
  final String window;
  final VoidCallback onOpenDays;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      key: ValueKey('nutrition.insight.$itemKey'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(line, style: text.bodyMedium),
          const SizedBox(height: Space.xs),
          Text(window, style: text.labelSmall?.copyWith(color: t.textTertiary)),
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: l.nutritionOpenDays,
              icon: Icons.calendar_month_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: onOpenDays,
            ),
          ),
        ],
      ),
    );
  }
}

/// The days behind a number: which days carried the marker, which did not,
/// what each day's number was, and what he ate on it.
Future<void> showInsightDaysSheet(
  BuildContext context, {
  required String lateLabel,
  required NutritionMetric metric,
  required String markerKey,
  required String markerLabel,
}) => showInteractionSheet<void>(
  context,
  builder: (_) => InsightDaysSheet(
    lateLabel: lateLabel,
    metric: metric,
    markerKey: markerKey,
    markerLabel: markerLabel,
  ),
);

/// The body of [showInsightDaysSheet].
class InsightDaysSheet extends ConsumerWidget {
  const InsightDaysSheet({
    super.key,
    required this.lateLabel,
    required this.metric,
    required this.markerKey,
    required this.markerLabel,
  });

  final String lateLabel;
  final NutritionMetric metric;
  final String markerKey;
  final String markerLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final days = ref.watch(nutritionInsightDaysProvider(lateLabel));
    final entries = ref.watch(nutritionEntriesProvider);
    final clock = ref.watch(nutritionWallClockProvider);
    final rated = [
      for (final d in days)
        if (d.hasFood && d.metrics.containsKey(metric)) d,
    ].reversed.toList();
    final with_ = [
      for (final d in rated)
        if (d.markers.contains(markerKey)) d,
    ];
    final without = [
      for (final d in rated)
        if (!d.markers.contains(markerKey)) d,
    ];

    Widget group(String title, List<NutritionDay> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BodySectionTitle(title),
        if (list.isEmpty)
          BodyHint(l.nutritionDayNothing, color: t.textTertiary)
        else
          for (final d in list)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _DayRow(
                day: d,
                metric: metric,
                names: [for (final e in FoodLogStats.onDay(entries, d.day, clock: clock)) e.name],
              ),
            ),
      ],
    );

    return InteractionSheetFrame(
      title: l.nutritionDaysBehindTitle,
      subtitle: tx.metric(metric),
      icon: Icons.calendar_month_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group(l.nutritionDaysWith(tx.name(markerLabel)), with_),
          group(l.nutritionDaysWithout, without),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.metric, required this.names});

  final NutritionDay day;
  final NutritionMetric metric;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final value = day.metrics[metric];
    final ate = tx.plannedFoods(names);
    return GlassCard(
      key: ValueKey('nutrition.insightDay.${BodyDays.key(day.day)}'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
      borderRadius: BorderRadius.circular(t.radiusM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tx.fmt.formatDate(day.day, style: MadarDateStyle.weekdayDayMonth),
                  style: text.titleSmall,
                ),
              ),
              if (value != null)
                BodyPill(label: tx.metricValue(metric, value), color: p.insight, dense: true),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ate ?? tx.fmt.localizeDigits(l.nutritionDayEntries(day.entries, tx.fmt.formatInt(day.entries))),
            style: text.bodySmall?.copyWith(color: t.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
