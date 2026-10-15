import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/habit_streaks.dart';
import '../wellbeing_actions.dart';
import '../wellbeing_screen.dart';
import '../widgets/wb_widgets.dart';

/// Today's stress-reduction checklist: tap or swipe to tick, drag to
/// reorder, long-press to rename, pause or delete (with undo). Each habit
/// shows its streak and the last seven days.
class HabitsTab extends ConsumerWidget {
  const HabitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final habits = ref.watch(wellbeingHabitsProvider).value ?? const <HabitRow>[];
    final progress = ref.watch(habitProgressProvider);
    final ordered = [
      for (final h in habits)
        if (h.active) h,
      for (final h in habits)
        if (!h.active) h,
    ];
    return ReorderableGlassList<HabitRow>(
      items: ordered,
      itemKey: (h) => h.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, wbTabBottomPadding),
      spacing: Space.s,
      header: Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: const _HabitsHeader(),
      ),
      footer: habits.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.wbHabitsEmptyTitle,
                body: l.wbHabitsEmptyBody,
                actionLabel: l.wbHabitAddTitle,
                actionIcon: Icons.add_task_rounded,
                onAction: () => WellbeingActions.addHabit(context, ref),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: WbHint(l.wbHabitsHint),
            ),
      onReorder: (order) => ref.read(wellbeingServiceProvider).reorderHabits([for (final h in order) h.id]),
      itemBuilder: (context, habit, index, grip) =>
          HabitTile(habit: habit, progress: progress[habit.id] ?? HabitProgress.empty, grip: grip),
    );
  }
}

class _HabitsHeader extends ConsumerWidget {
  const _HabitsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final counts = ref.watch(habitTodayCountProvider);
    final progress = ref.watch(habitProgressProvider);
    final best = progress.values.fold<int>(0, (m, p) => p.streak > m ? p.streak : m);
    final value = counts.total == 0 ? 0.0 : counts.done / counts.total;
    return WbCard(
      seed: 6.1,
      child: Row(
        children: [
          ProgressRing(
            value: value,
            size: 76,
            strokeWidth: 7,
            color: t.success,
            gradientEnd: t.gold,
            semanticLabel: l.wbHabitsToday,
            semanticValue: fmt.localizeDigits(l.wbFraction(fmt.formatInt(counts.done), fmt.formatInt(counts.total))),
            child: Text(
              fmt.localizeDigits(l.wbFraction(fmt.formatInt(counts.done), fmt.formatInt(counts.total))),
              style: text.titleMedium,
            ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.wbHabitsToday, style: text.titleMedium),
                const SizedBox(height: Space.xxs),
                Text(
                  counts.total > 0 && counts.done == counts.total ? l.wbHabitsAllDone : l.wbHabitsSubtitle,
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                ),
                if (best > 1) ...[
                  const SizedBox(height: Space.xs),
                  WbValuePill(
                    label: fmt.localizeDigits(l.wbBestStreakNow(best, fmt.formatInt(best))),
                    icon: Icons.local_fire_department_outlined,
                    color: t.gold,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One checklist habit.
class HabitTile extends ConsumerWidget {
  const HabitTile({super.key, required this.habit, required this.progress, this.grip});

  final HabitRow habit;
  final HabitProgress progress;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final done = progress.doneToday;
    final active = habit.active;
    final streakText = progress.streak > 0
        ? fmt.localizeDigits(l.wbStreak(progress.streak, fmt.formatInt(progress.streak)))
        : l.wbStreakNone;
    return ActionableItem(
      semanticLabel: '${habit.name}. ${done ? l.wbHabitDoneState : l.wbHabitOpenState}. $streakText',
      borderRadius: BorderRadius.circular(t.radiusL),
      enabled: true,
      onTap: active
          ? () => _toggle(context, ref, !done)
          : () => WellbeingActions.toggleHabitActive(context, ref, habit),
      completeLabel: done ? l.wbHabitUndo : l.wbHabitMarkDone,
      completeIcon: done ? Icons.undo_rounded : Icons.check_rounded,
      onCompleteSwipe: active ? () => WellbeingActions.toggleHabit(context, ref, habit, done: !done) : null,
      actions: ItemActions(
        onEdit: () => WellbeingActions.renameHabit(context, ref, habit),
        onDelete: () => WellbeingActions.deleteHabit(context, ref, habit),
        extra: [
          ItemAction(
            icon: active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: active ? l.wbHabitPause : l.wbHabitResume,
            tone: active ? ActionTone.warning : ActionTone.success,
            onSelected: () => WellbeingActions.toggleHabitActive(context, ref, habit),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: active ? l.wbHabitPause : l.wbHabitResume,
          tone: ActionTone.warning,
          onPressed: () => WellbeingActions.toggleHabitActive(context, ref, habit),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.wbDelete,
          tone: ActionTone.danger,
          onPressed: () => WellbeingActions.deleteHabit(context, ref, habit),
        ),
      ],
      child: AnimatedOpacity(
        opacity: active ? 1 : 0.55,
        duration: context.motion(MadarMotion.short),
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
          borderRadius: BorderRadius.circular(t.radiusL),
          glow: done,
          glowColor: t.success.withValues(alpha: 0.25),
          borderColor: done ? t.success.withValues(alpha: 0.55) : null,
          child: Row(
            children: [
              _CheckOrb(done: done, active: active),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: text.titleSmall?.copyWith(
                        color: done ? t.textSecondary : t.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: t.textTertiary,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Row(
                      children: [
                        _WeekDots(days: progress.last7, color: t.success, track: t.glassBorder),
                        const SizedBox(width: Space.s),
                        Flexible(
                          child: Text(
                            active ? streakText : l.wbHabitPausedState,
                            style: text.labelSmall?.copyWith(color: progress.streak > 0 ? t.gold : t.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool done) async {
    final action = await WellbeingActions.toggleHabit(context, ref, habit, done: done);
    if (action != null && context.mounted && !done) await showUndoToast(context, action);
  }
}

class _CheckOrb extends StatelessWidget {
  const _CheckOrb({required this.done, required this.active});

  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SpringBuilder(
      value: done ? 1 : 0,
      spring: MadarMotion.bouncy,
      builder: (context, v, _) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(t.glassFill, t.success, v.clamp(0.0, 1.0) * 0.9),
          border: Border.all(color: Color.lerp(t.glassBorder, t.success, v.clamp(0.0, 1.0))!, width: 1.6),
          boxShadow: v > 0.5 ? [BoxShadow(color: t.success.withValues(alpha: 0.35), blurRadius: 10)] : null,
        ),
        child: Transform.scale(
          scale: v.clamp(0.0, 1.2),
          child: Icon(Icons.check_rounded, size: 18, color: t.isDark ? t.space0 : t.textOnAccent),
        ),
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.days, required this.color, required this.track});

  /// Oldest first; today last (at the reading end).
  final List<bool> days;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < days.length; i++)
          Container(
            width: i == days.length - 1 ? 9 : 7,
            height: i == days.length - 1 ? 9 : 7,
            margin: const EdgeInsetsDirectional.only(end: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: days[i] ? color : track.withValues(alpha: 0.4),
              border: i == days.length - 1 ? Border.all(color: color.withValues(alpha: 0.8)) : null,
            ),
          ),
      ],
    );
  }
}
