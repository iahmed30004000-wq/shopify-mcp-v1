import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../data/body_providers.dart';
import '../../domain/body_clock.dart';
import '../../domain/body_week.dart';
import '../../domain/training.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../sheets/exercise_history_sheet.dart';
import '../widgets/body_widgets.dart';

/// The training plan: this week at a glance, then every exercise with its
/// days (drag to reorder; tap to edit; long-press for history, pause,
/// duplicate, delete with undo).
class BodyPlanTab extends ConsumerWidget {
  const BodyPlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final exercises = ref.watch(bodyExercisesProvider);
    final ordered = [
      for (final e in exercises)
        if (e.active) e,
      for (final e in exercises)
        if (!e.active) e,
    ];
    return ReorderableGlassList<PlannedExercise>(
      items: ordered,
      itemKey: (e) => e.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      spacing: Space.s,
      header: Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: exercises.isEmpty ? const SizedBox.shrink() : const WeekStripCard(),
      ),
      footer: exercises.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.bodyPlanEmptyTitle,
                body: l.bodyPlanEmptyBody,
                actionLabel: l.bodyAddExercise,
                actionIcon: Icons.add_rounded,
                onAction: () => BodyActions.addExercise(context, ref),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: BodyHint(l.bodyPlanHint, icon: Icons.drag_indicator_rounded),
            ),
      onReorder: (order) => ref.read(bodyServiceProvider).reorderExercises([for (final e in order) e.id]),
      itemBuilder: (context, e, index, grip) => ExerciseTile(exercise: e, grip: grip),
    );
  }
}

/// The display week (Saturday first in Arabic): per day, how many planned
/// exercises and how many were done.
class WeekStripCard extends ConsumerWidget {
  const WeekStripCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final week = ref.watch(bodyWeekAdherenceProvider);
    final today = ref.watch(bodyTodayProvider);
    return BodyCard(
      title: l.bodyPlanWeek,
      icon: Icons.calendar_view_week_rounded,
      seed: 7.2,
      trailing: week.expected == 0
          ? null
          : BodyPill(
              label: tx.fmt.localizeDigits(l.bodyFraction(tx.fmt.formatInt(week.done), tx.fmt.formatInt(week.expected))),
              icon: Icons.check_circle_outline_rounded,
              color: week.done >= week.expected ? t.success : p.training,
            ),
      child: Row(
        children: [
          for (final d in week.days)
            Expanded(
              child: _DayColumn(
                letter: tx.weekdayShort(d.day.weekday),
                semantic: '${tx.weekdayName(d.day.weekday)}: ${tx.fmt.localizeDigits(l.bodyFraction(tx.fmt.formatInt(d.done), tx.fmt.formatInt(d.planned)))}',
                planned: d.planned,
                done: d.done,
                isToday: BodyDays.same(d.day, today),
                past: d.day.isBefore(today),
                color: p.training,
                count: tx.fmt.formatInt(d.planned),
                style: text,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.letter,
    required this.semantic,
    required this.planned,
    required this.done,
    required this.isToday,
    required this.past,
    required this.color,
    required this.count,
    required this.style,
  });

  final String letter;
  final String semantic;
  final int planned;
  final int done;
  final bool isToday;
  final bool past;
  final Color color;
  final String count;
  final TextTheme style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final complete = planned > 0 && done >= planned;
    final missed = past && planned > 0 && done < planned;
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            letter,
            style: style.labelMedium?.copyWith(
              color: isToday ? t.textPrimary : t.textTertiary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: Space.xs),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: t.textPrimary.withValues(alpha: 0.8), width: 1.4) : null,
            ),
            padding: const EdgeInsets.all(2),
            child: planned == 0
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: t.glassBorder),
                    ),
                  )
                : ProgressRing(
                    value: done / planned,
                    size: 30,
                    strokeWidth: 3,
                    glow: complete,
                    color: complete ? t.success : color,
                    trackColor: missed ? t.warning.withValues(alpha: 0.35) : null,
                    child: complete
                        ? Icon(Icons.check_rounded, size: 15, color: t.success)
                        : Text(count, style: style.labelSmall?.copyWith(color: missed ? t.warning : t.textSecondary)),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One exercise of the plan.
class ExerciseTile extends ConsumerWidget {
  const ExerciseTile({super.key, required this.exercise, this.grip});

  final PlannedExercise exercise;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final summary = tx.planSummary(e);
    final perWeek = BodyWeek.perWeek(e.weekdays);
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    final days = e.weekdays.isEmpty ? l.bodyNoDays : tx.weekdayList(BodyWeek.inDisplayOrder(e.weekdays, start));
    return ActionableItem(
      key: ValueKey('body.exercise.${e.id}'),
      semanticLabel: [e.name, if (!e.active) l.bodyPaused, days, if (summary.isNotEmpty) summary].join('. '),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => BodyActions.editExercise(context, ref, e.id),
      actions: ItemActions(
        onEdit: () => BodyActions.editExercise(context, ref, e.id),
        onDuplicate: () => BodyActions.duplicateExercise(context, ref, e.id),
        onDelete: () => BodyActions.deleteExercise(context, ref, e.id),
        extra: [
          ItemAction(
            icon: Icons.insights_rounded,
            label: l.bodyExerciseHistory,
            tone: ActionTone.info,
            onSelected: () async {
              await showExerciseHistorySheet(context, e.id);
              return null;
            },
          ),
          ItemAction(
            icon: e.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: e.active ? l.bodyPause : l.bodyResume,
            tone: e.active ? ActionTone.warning : ActionTone.success,
            onSelected: () => BodyActions.toggleExerciseActive(context, ref, e.id),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.insights_rounded,
          label: l.bodyExerciseHistory,
          tone: ActionTone.info,
          onPressed: () async {
            await showExerciseHistorySheet(context, e.id);
            return null;
          },
        ),
        QuickAction(
          icon: e.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: e.active ? l.bodyPause : l.bodyResume,
          tone: ActionTone.warning,
          onPressed: () => BodyActions.toggleExerciseActive(context, ref, e.id),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => BodyActions.deleteExercise(context, ref, e.id),
        ),
      ],
      child: AnimatedOpacity(
        opacity: e.active ? 1 : 0.55,
        duration: context.motion(MadarMotion.short),
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
          borderRadius: BorderRadius.circular(t.radiusL),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [p.training.withValues(alpha: 0.35), p.training.withValues(alpha: 0.08)]),
                  border: Border.all(color: p.training.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  e.durationMin != null && e.reps == null ? Icons.timer_outlined : Icons.fitness_center_rounded,
                  size: 20,
                  color: p.training,
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(e.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        if (!e.active) ...[
                          const SizedBox(width: Space.xs),
                          BodyPill(label: l.bodyPaused, icon: Icons.pause_rounded, color: t.warning, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    WeekdayDots(weekdays: e.weekdays, color: p.training, size: 19, dimmed: !e.active),
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        if (summary.isNotEmpty) summary,
                        tx.fmt.localizeDigits(l.bodyPerWeek(perWeek, tx.fmt.formatInt(perWeek))),
                      ].join(tx.sep),
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                    if (e.notes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.notes!,
                        style: text.bodySmall?.copyWith(color: t.textTertiary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}
