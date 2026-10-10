import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/quran/quran_catalog.dart';
import '../../../home/widgets/window_chips.dart' show windowIcon;
import '../../domain/wird_engine.dart';
import '../wird_labels.dart';
import '../wird_plan_sheet.dart' show wirdTemplateIcon;

/// One plan in the list: today's ring, name, summary, window and badges, and
/// overall progress. Tap focuses it; long-press / swipe for actions.
class WirdPlanTile extends StatelessWidget {
  const WirdPlanTile({
    super.key,
    required this.state,
    required this.catalog,
    required this.primary,
    required this.focused,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
    required this.onMakePrimary,
    this.onMarkDone,
  });

  final WirdPlanState state;
  final QuranCatalog catalog;
  final bool primary;
  final bool focused;
  final VoidCallback onTap;
  final FutureOr<void> Function() onEdit;
  final FutureOr<UndoableAction?> Function() onDelete;
  final FutureOr<UndoableAction?> Function() onTogglePause;
  final FutureOr<UndoableAction?> Function() onMakePrimary;
  final FutureOr<UndoableAction?> Function()? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final texts = WirdTexts(l, fmt, catalog);
    final plan = state.plan;
    final met = state.started && !state.paused && state.target.met;
    final overall = state.fraction;
    final range = state.target.range;
    final (String todayLine, Color todayColor) = state.completed
        ? (l.wirdKhatmaDone, t.success)
        : state.paused
        ? (l.wirdPausedNote, t.textTertiary)
        : !state.started
        ? (l.wirdNotStarted(fmt.formatDate(plan.startDate, style: MadarDateStyle.dayMonth)), t.info)
        : range == null
        ? (l.wirdLegendRest, t.success)
        : (l.wirdTodayLine(texts.range(range)), met ? t.success : t.textSecondary);
    return ActionableItem(
      onTap: onTap,
      semanticLabel: '${plan.name}. ${texts.summary(plan)}',
      onCompleteSwipe: onMarkDone,
      completeLabel: l.wirdMarkDone,
      actions: ItemActions(
        onEdit: onEdit,
        onDelete: onDelete,
        extra: [
          if (!primary)
            ItemAction(
              icon: Icons.star_rounded,
              label: l.wirdMakePrimary,
              onSelected: onMakePrimary,
              tone: ActionTone.accent,
            ),
          ItemAction(
            icon: plan.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: plan.active ? l.wirdPause : l.wirdResume,
            onSelected: onTogglePause,
            tone: plan.active ? ActionTone.warning : ActionTone.success,
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: plan.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: plan.active ? l.wirdPause : l.wirdResume,
          onPressed: onTogglePause,
          tone: ActionTone.warning,
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.wirdDelete,
          onPressed: onDelete,
          tone: ActionTone.danger,
        ),
      ],
      child: GlassCard(
        borderColor: focused ? t.accent.withValues(alpha: 0.7) : null,
        glowColor: focused ? t.accentGlow : null,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            ProgressRing(
              value: state.paused ? 0 : state.target.progress,
              size: 48,
              strokeWidth: 4,
              color: met ? t.success : t.accent,
              glow: met,
              child: Icon(
                state.paused ? Icons.pause_rounded : (met ? Icons.check_rounded : wirdTemplateIcon(plan.template)),
                size: 20,
                color: state.paused ? t.textTertiary : (met ? t.success : t.accent),
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
                        child: Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium!.copyWith(color: plan.active ? t.textPrimary : t.textSecondary),
                        ),
                      ),
                      if (primary) ...[
                        const SizedBox(width: Space.xs),
                        _Badge(label: l.wirdPrimary, color: t.gold, icon: Icons.star_rounded),
                      ],
                      if (!plan.active) ...[
                        const SizedBox(width: Space.xs),
                        _Badge(label: l.wirdPaused, color: t.textTertiary),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    todayLine,
                    // Wraps rather than cut inside today's range.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: todayColor),
                  ),
                  const SizedBox(height: Space.xxs),
                  Row(
                    children: [
                      Icon(windowIcon(plan.window ?? PrayerWindow.anytime), size: 13, color: t.textTertiary),
                      const SizedBox(width: Space.xxs),
                      Flexible(
                        child: Text(
                          '${texts.window(plan.window)}${l.wirdSep}${l.wirdSummaryDaily(texts.amount(plan.unit, plan.amountPerDay))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall,
                        ),
                      ),
                      if (state.streak > 0) ...[
                        const SizedBox(width: Space.s),
                        Icon(Icons.local_fire_department_rounded, size: 13, color: t.warning),
                        const SizedBox(width: Space.xxs),
                        Text(texts.days(state.streak), style: text.labelSmall!.copyWith(color: t.warning)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.isKhatma
                      ? fmt.formatPercent(overall)
                      : l.wirdPagePosition(texts.number(catalog.pageOf(state.cursor ?? plan.start))),
                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: Space.xs),
                SizedBox(
                  width: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: overall,
                      minHeight: 3,
                      color: state.completed ? t.success : t.brass,
                      backgroundColor: t.glassBorder,
                    ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, 1, Space.s, 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 2)],
          Text(label, style: text.labelSmall!.copyWith(color: color, height: 1.3)),
        ],
      ),
    );
  }
}
