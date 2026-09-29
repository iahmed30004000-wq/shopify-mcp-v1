import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/body_week.dart';
import '../../domain/training.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../sheets/exercise_history_sheet.dart';
import '../widgets/body_widgets.dart';
import '../widgets/fasting_card.dart';
import '../widgets/water_card.dart';

/// Today on the Body planet: the session for today's weekday (tick or swipe
/// to log with the planned values, tap to log the actual ones), extra
/// workouts, the fasting clock, water and the avoid list at a glance.
class BodyTodayTab extends ConsumerWidget {
  const BodyTodayTab({super.key, this.onOpenPlan, this.onOpenFasting, this.onOpenWater, this.onOpenAvoid});

  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenFasting;
  final VoidCallback? onOpenWater;
  final VoidCallback? onOpenAvoid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final day = ref.watch(bodyTrainingTodayProvider);
    final hasPlan = ref.watch(bodyExercisesProvider).isNotEmpty;
    final avoid = ref.watch(bodyAvoidRowsProvider).value ?? const <AvoidItemRow>[];
    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, child: child);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      children: [
        if (hasPlan) stagger(const _SessionHeader()),
        if (!hasPlan)
          stagger(
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.bodyNoPlanTitle,
                body: l.bodyNoPlanBody,
                actionLabel: l.bodyOpenPlan,
                actionIcon: Icons.event_note_rounded,
                onAction: onOpenPlan,
                illustrationSize: 120,
              ),
            ),
          ),
        for (final item in day.items)
          stagger(
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: SessionTile(item: item),
            ),
          ),
        if (day.extras.isNotEmpty) ...[
          stagger(BodySectionTitle(l.bodyAlsoToday, icon: Icons.add_task_rounded)),
          for (final w in day.extras)
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _ExtraTile(entry: w),
              ),
            ),
        ],
        const SizedBox(height: Space.l),
        stagger(FastingCard(compact: true, onOpen: onOpenFasting)),
        const SizedBox(height: Space.s),
        stagger(WaterCard(compact: true, onOpen: onOpenWater)),
        if (avoid.isNotEmpty) ...[
          const SizedBox(height: Space.s),
          stagger(_AvoidGlance(items: avoid, onOpen: onOpenAvoid)),
        ],
      ],
    );
  }
}

class _SessionHeader extends ConsumerWidget {
  const _SessionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final day = ref.watch(bodyTrainingTodayProvider);
    final exercises = ref.watch(bodyExercisesProvider);
    final today = ref.watch(bodyTodayProvider);
    final fraction = tx.fmt.localizeDigits(l.bodyFraction(tx.fmt.formatInt(day.done), tx.fmt.formatInt(day.planned)));
    String subtitle;
    if (day.isRestDay) {
      final next = _nextSession(exercises, today);
      subtitle = next == null ? l.bodyRestDayBody : l.bodyNextSession(tx.day(next, today));
    } else if (day.complete) {
      subtitle = l.bodySessionDone;
    } else {
      subtitle = l.bodySessionKeepGoing;
    }
    final minutes = day.minutes;
    return BodyCard(
      seed: 1.4,
      glowColor: day.complete ? p.training.withValues(alpha: 0.28) : null,
      child: Row(
        children: [
          ProgressRing(
            value: day.progress,
            size: 84,
            strokeWidth: 8,
            color: p.training,
            gradientEnd: p.trainingEnd,
            semanticLabel: l.bodyTodaySession,
            semanticValue: day.isRestDay ? l.bodyRestDay : fraction,
            child: day.isRestDay
                ? Icon(Icons.self_improvement_rounded, color: t.textSecondary, size: 30)
                : day.complete
                ? Icon(Icons.local_fire_department_rounded, color: p.training, size: 32)
                : Text(fraction, style: text.titleMedium),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bodyTodayLine(context, today), style: text.labelMedium?.copyWith(color: t.textTertiary)),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(day.isRestDay ? l.bodyRestDay : l.bodyTodaySession, style: text.titleLarge),
                ),
                const SizedBox(height: Space.xxs),
                Text(subtitle, style: text.bodySmall?.copyWith(color: day.complete ? p.training : t.textSecondary)),
                if (!day.isRestDay) ...[
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      BodyPill(
                        label: tx.fmt.localizeDigits(l.bodyExercisesCount(day.planned, tx.fmt.formatInt(day.planned))),
                        icon: Icons.fitness_center_rounded,
                        color: p.training,
                        dense: true,
                      ),
                      if (minutes > 0)
                        BodyPill(label: tx.minutes(minutes), icon: Icons.timer_outlined, color: t.gold, dense: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _nextSession(List<PlannedExercise> exercises, DateTime today) {
    DateTime? best;
    for (final e in exercises) {
      if (!e.active) continue;
      final n = BodyWeek.nextOn(e.weekdays, today.add(const Duration(days: 1)));
      if (n != null && (best == null || n.isBefore(best))) best = n;
    }
    return best;
  }
}

/// One exercise of today's session: the orb logs it with the planned
/// values (undo in the toast), a tap opens the log sheet, swipe right logs /
/// un-logs, long-press edits the exercise or opens its history.
class SessionTile extends ConsumerWidget {
  const SessionTile({super.key, required this.item});

  final SessionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = item.exercise;
    final done = item.done;
    final latest = item.latest;
    final plan = tx.planSummary(e);
    final logged = latest == null ? '' : tx.workoutSummary(latest);
    final line = done ? (logged.isEmpty ? l.bodyStateDone : l.bodyLogged(logged)) : plan;

    Future<UndoableAction?> toggle() =>
        done ? BodyActions.deleteWorkout(context, ref, latest!.id, unmark: true) : BodyActions.quickLog(context, ref, e);

    return ActionableItem(
      key: ValueKey('body.session.${e.id}'),
      semanticLabel: '${e.name}. ${done ? l.bodyStateDone : l.bodyStateOpen}. $line',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => done && latest != null
          ? BodyActions.editWorkout(context, ref, latest.id)
          : BodyActions.logWithDetails(context, ref, exercise: e),
      completeLabel: done ? l.bodyUnmark : l.bodyMarkDone,
      completeIcon: done ? Icons.undo_rounded : Icons.check_rounded,
      onCompleteSwipe: toggle,
      actions: ItemActions(
        onEdit: () => BodyActions.editExercise(context, ref, e.id),
        extra: [
          ItemAction(
            icon: Icons.edit_note_rounded,
            label: l.bodyLogDetails,
            tone: ActionTone.accent,
            onSelected: () async {
              await BodyActions.logWithDetails(context, ref, exercise: e);
              return null;
            },
          ),
          ItemAction(
            icon: Icons.insights_rounded,
            label: l.bodyExerciseHistory,
            tone: ActionTone.info,
            onSelected: () async {
              await showExerciseHistorySheet(context, e.id);
              return null;
            },
          ),
          if (done)
            ItemAction(
              icon: Icons.undo_rounded,
              label: l.bodyUnmark,
              tone: ActionTone.warning,
              onSelected: toggle,
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
          icon: Icons.edit_note_rounded,
          label: l.bodyLogDetails,
          onPressed: () async {
            await BodyActions.logWithDetails(context, ref, exercise: e);
            return null;
          },
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.m, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: done,
        glowColor: p.training.withValues(alpha: 0.22),
        borderColor: done ? p.training.withValues(alpha: 0.55) : null,
        child: Row(
          children: [
            _CheckOrb(
              done: done,
              color: p.training,
              label: done ? l.bodyUnmark : l.bodyMarkDone,
              onTap: () async {
                final undo = await toggle();
                if (undo != null && context.mounted) await showUndoToast(context, undo);
              },
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: text.titleSmall?.copyWith(
                      color: done ? t.textSecondary : t.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: t.textTertiary,
                    ),
                  ),
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: done ? p.training : t.textSecondary)),
                  ],
                  if (e.notes != null && !done) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.notes!,
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (latest?.volume case final v?)
              BodyPill(label: l.bodyKg(tx.fmt.formatNumber(v, maxDecimals: 0)), icon: Icons.stacked_bar_chart_rounded, color: p.training, dense: true)
            else
              Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }
}

class _CheckOrb extends StatelessWidget {
  const _CheckOrb({required this.done, required this.color, required this.label, required this.onTap});

  final bool done;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MadarPressable(
      onTap: onTap,
      sfx: done ? Sfx.toggleOff : Sfx.complete,
      semanticLabel: label,
      pressScale: 0.86,
      excludeChildSemantics: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SpringBuilder(
            value: done ? 1 : 0,
            spring: MadarMotion.bouncy,
            builder: (context, v, _) {
              final f = v.clamp(0.0, 1.0);
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(t.glassFill, color, f * 0.92),
                  border: Border.all(color: Color.lerp(t.glassBorder, color, f)!, width: 1.6),
                  boxShadow: v > 0.5 ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)] : null,
                ),
                child: Transform.scale(
                  scale: v.clamp(0.0, 1.2),
                  child: Icon(Icons.check_rounded, size: 20, color: t.isDark ? t.space0 : t.textOnAccent),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExtraTile extends ConsumerWidget {
  const _ExtraTile({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final summary = tx.workoutSummary(entry);
    return ActionableItem(
      semanticLabel: '${entry.name}. $summary',
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
            Icon(Icons.directions_run_rounded, color: p.training, size: 20),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: text.titleSmall),
                  if (summary.isNotEmpty) Text(summary, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            Text(tx.fmt.formatTime(entry.at), style: text.labelSmall?.copyWith(color: t.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _AvoidGlance extends StatelessWidget {
  const _AvoidGlance({required this.items, this.onOpen});

  final List<AvoidItemRow> items;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    return BodyCard(
      title: l.bodyAvoidReminder,
      icon: Icons.do_not_disturb_on_outlined,
      iconColor: p.avoid,
      onTap: onOpen,
      seed: 4.2,
      trailing: Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [for (final a in items.take(6)) BodyPill(label: a.body, color: p.avoid, dense: true)],
      ),
    );
  }
}
