import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../data/body_providers.dart';
import '../../domain/training.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../widgets/body_charts.dart';
import '../widgets/body_widgets.dart';

/// Opens an exercise's history: a progress chart (weight / volume / reps /
/// minutes per training day) and every log, editable and deletable.
Future<void> showExerciseHistorySheet(BuildContext context, String exerciseId) =>
    showInteractionSheet<void>(context, builder: (_) => ExerciseHistorySheet(exerciseId: exerciseId));

class ExerciseHistorySheet extends ConsumerStatefulWidget {
  const ExerciseHistorySheet({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseHistorySheet> createState() => _ExerciseHistorySheetState();
}

class _ExerciseHistorySheetState extends ConsumerState<ExerciseHistorySheet> {
  ProgressMetric? _metric;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final exercise = ref.watch(bodyExercisesProvider.select((l) => l.where((e) => e.id == widget.exerciseId).firstOrNull));
    final progress = ref.watch(bodyExerciseProgressProvider(widget.exerciseId));
    final available = progress.available;
    final metric = _metric != null && available.contains(_metric) ? _metric! : progress.preferred;
    final points = metric == null ? const <ProgressPoint>[] : progress.of(metric);
    final best = metric == null ? null : progress.best(metric);
    final change = metric == null ? null : progress.change(metric);
    return InteractionSheetFrame(
      title: exercise?.name ?? l.bodyExerciseHistory,
      subtitle: l.bodyExerciseHistory,
      icon: Icons.insights_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.bodyLogs, body: l.bodyHistoryEmpty, illustrationSize: 120),
            )
          else ...[
            if (available.length > 1) ...[
              ChoicePills<ProgressMetric>.single(
                options: [for (final m in available) ChoiceOption(value: m, label: tx.metric(m))],
                selected: metric,
                dense: true,
                onChanged: (m) => setState(() => _metric = m),
              ),
              const SizedBox(height: Space.m),
            ],
            Row(
              children: [
                Expanded(
                  child: _MiniStat(label: l.bodyBest, value: best == null ? l.bodyNotSet : tx.metricValue(metric!, best), color: p.training),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: _MiniStat(
                    label: l.bodyChange,
                    value: change == null
                        ? l.bodyNotSet
                        : tx.signed(change, (v) => tx.metricValue(metric!, v)),
                    color: change == null || change == 0 ? t.textSecondary : (change > 0 ? t.success : t.warning),
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: _MiniStat(label: l.bodySessions, value: tx.fmt.formatInt(progress.logs.length), color: t.gold),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            if (points.length >= 2)
              ProgressLineChart(
                key: ValueKey(metric),
                points: points,
                color: metric == ProgressMetric.minutes ? p.eating : p.training,
                valueLabel: (v) => tx.metricValue(metric, v),
                semanticLabel: tx.metric(metric!),
              )
            else
              BodyHint(l.bodyHistoryOneDay, icon: Icons.show_chart_rounded),
            if (metric == ProgressMetric.volume) ...[
              const SizedBox(height: Space.xs),
              BodyHint(l.bodyVolumeHint, icon: Icons.functions_rounded),
            ],
            BodySectionTitle(l.bodyLogs, icon: Icons.history_rounded),
            for (var i = 0; i < progress.logs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: StaggerItem(
                  index: i,
                  child: _LogTile(entry: progress.logs[i]),
                ),
              ),
          ],
          SizedBox(height: text.bodySmall?.fontSize ?? 0),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder),
        ),
        child: Column(
          children: [
            Text(label, style: text.labelSmall?.copyWith(color: t.textTertiary), maxLines: 1),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final summary = tx.workoutSummary(entry);
    final volume = entry.volume;
    final when = tx.fmt.formatDate(entry.at, style: MadarDateStyle.weekdayDayMonth);
    return ActionableItem(
      semanticLabel: '$when. $summary',
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => BodyActions.editWorkout(context, ref, entry.id),
      actions: ItemActions(
        onEdit: () => BodyActions.editWorkout(context, ref, entry.id),
        onDelete: () => BodyActions.deleteWorkout(context, ref, entry.id),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => BodyActions.deleteWorkout(context, ref, entry.id),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
        borderRadius: BorderRadius.circular(t.radiusM),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(when, style: text.labelMedium?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: 2),
                  Text(summary.isEmpty ? entry.name : summary, style: text.titleSmall),
                  if (entry.notes != null) ...[
                    const SizedBox(height: 2),
                    Text(entry.notes!, style: text.bodySmall?.copyWith(color: t.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (volume != null)
              BodyPill(label: l.bodyKg(tx.fmt.formatNumber(volume, maxDecimals: 0)), icon: Icons.stacked_bar_chart_rounded, color: BodyPalette(t).training, dense: true),
          ],
        ),
      ),
    );
  }
}
