import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/goal_math.dart';
import '../../domain/growth_goal.dart';
import '../growth_texts.dart';
import 'growth_widgets.dart';

/// One goal in a list: its ring, name, progress and pace line, a quick "+"
/// and (optionally) a drag grip. Tap opens it; long-press for the menu;
/// swipe right logs the usual amount; swipe left for pause / delete.
class GoalTile extends StatelessWidget {
  const GoalTile({
    super.key,
    required this.goal,
    required this.onOpen,
    required this.onLog,
    required this.onQuickLog,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onTogglePause,
    this.grip,
  });

  final GrowthGoal goal;
  final VoidCallback onOpen;

  /// Opens the log sheet.
  final FutureOr<void> Function() onLog;

  /// Logs [GrowthGoal.usualAmount] at once (the swipe).
  final FutureOr<UndoableAction?> Function() onQuickLog;
  final FutureOr<void> Function() onEdit;
  final FutureOr<UndoableAction?> Function() onDuplicate;
  final FutureOr<UndoableAction?> Function() onDelete;
  final FutureOr<UndoableAction?> Function() onTogglePause;
  final Widget? grip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final s = goal.stats;
    final paused = s.pace == GoalPace.paused;
    final canLog = !paused;
    final usual = texts.amount(goal.unit, goal.usualAmount);
    final paceColor = GrowthColors.pace(t, s.pace);
    // The ring shows the percentage – except once complete (a check).
    final progressLine = s.completed
        ? '${texts.progressOf(goal)}${l.growthSep}${texts.percent(s.fraction)}'
        : texts.progressOf(goal);

    return ActionableItem(
      onTap: onOpen,
      semanticLabel: texts.semantics(goal),
      onCompleteSwipe: canLog ? onQuickLog : null,
      completeIcon: Icons.add_rounded,
      completeLabel: l.growthLogQuick(usual),
      actions: ItemActions(
        onEdit: onEdit,
        onDuplicate: onDuplicate,
        onDelete: onDelete,
        extra: [
          if (canLog)
            ItemAction(
              icon: Icons.add_task_rounded,
              label: l.growthLogProgress,
              tone: ActionTone.accent,
              onSelected: () async {
                await onLog();
                return null;
              },
            ),
          if (!s.completed)
            ItemAction(
              icon: goal.row.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: goal.row.active ? l.growthPause : l.growthResume,
              tone: goal.row.active ? ActionTone.warning : ActionTone.success,
              onSelected: onTogglePause,
            ),
        ],
      ),
      quickActions: [
        if (!s.completed)
          QuickAction(
            icon: goal.row.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: goal.row.active ? l.growthPause : l.growthResume,
            onPressed: onTogglePause,
            tone: ActionTone.warning,
          ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.growthDelete,
          onPressed: onDelete,
          tone: ActionTone.danger,
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
        child: Opacity(
          opacity: paused ? 0.72 : 1,
          child: Row(
            children: [
              GoalRing(goal: goal, size: 54),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                    const SizedBox(height: Space.xxs),
                    Text(
                      progressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: Space.xxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(GrowthColors.paceIcon(s.pace), size: 14, color: paceColor),
                        ),
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: Text(
                            texts.paceLine(goal),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium!.copyWith(color: paceColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canLog) ...[
                const SizedBox(width: Space.xs),
                MadarButton.icon(
                  icon: Icons.add_rounded,
                  onPressed: () => onLog(),
                  semanticLabel: l.growthLogProgress,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.secondary,
                  sfx: Sfx.tap,
                ),
              ],
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}
