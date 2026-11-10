import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../wird/domain/calendar_days.dart';
import '../../domain/hifz_models.dart';
import '../hifz_labels.dart';

bool _arabic(L10n l) => l.localeName.startsWith('ar');

/// Reviews due on each of the next seven days as slim bars (today includes
/// overdue).
class HifzForecast extends StatelessWidget {
  const HifzForecast({super.key, required this.forecast, required this.today});

  final List<int> forecast;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final max = math.max(1, forecast.fold<int>(0, math.max));
    final reduced = context.reducedMotion;
    String day(int i) {
      if (i == 0) return l.hifzForecastToday;
      final d = CalendarDays.add(today, i);
      try {
        // Arabic abbreviations are the full names anyway.
        return (_arabic(l) ? DateFormat.EEEE(l.localeName) : DateFormat.E(l.localeName)).format(d);
      } catch (_) {
        return DateFormat.E('en').format(d);
      }
    }

    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.hifzForecastTitle, style: text.titleSmall),
          const SizedBox(height: Space.m),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Semantics(
                      label: '${day(i)}: ${fmt.localizeDigits(l.hifzDueCount(forecast[i]))}',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            forecast[i] == 0 ? '' : fmt.formatInt(forecast[i]),
                            style: text.labelSmall!.copyWith(
                              color: i == 0 ? t.accent : t.textSecondary,
                              fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: reduced ? forecast[i] / max : 0, end: forecast[i] / max),
                            duration: context.motion(MadarMotion.long),
                            curve: MadarMotion.decelerate,
                            builder: (context, v, _) => Container(
                              width: 14,
                              height: 4 + 64 * v,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: i == 0
                                      ? [t.accent.withValues(alpha: 0.55), t.accent]
                                      : [t.brass.withValues(alpha: 0.25), t.brass.withValues(alpha: 0.7)],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            day(i),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: text.labelSmall!.copyWith(color: i == 0 ? t.accent : t.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One Hifz item in a list: kind medallion, title, subtitle, when it is due
/// and its SM-2 standing. Tap previews; long-press / swipe for actions.
class HifzItemTile extends StatelessWidget {
  const HifzItemTile({
    super.key,
    required this.card,
    required this.texts,
    required this.today,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSuspend,
    required this.onReset,
    this.onReviewNow,
  });

  final HifzCard card;
  final HifzTexts texts;
  final DateTime today;
  final VoidCallback onTap;
  final FutureOr<void> Function()? onEdit;
  final FutureOr<UndoableAction?> Function() onDelete;
  final FutureOr<UndoableAction?> Function() onToggleSuspend;
  final FutureOr<UndoableAction?> Function()? onReset;
  final FutureOr<UndoableAction?> Function()? onReviewNow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = texts.l;
    final fmt = texts.fmt;
    final text = Theme.of(context).textTheme;
    final overdue = card.overdueDays(today) > 0;
    final dueColor = card.suspended
        ? t.textTertiary
        : card.isNew
        ? t.info
        : overdue
        ? t.warning
        : (card.isDue(today) ? t.accent : t.textSecondary);
    final strength = card.isNew ? 0.0 : (card.sm2.intervalDays / HifzStats.matureDays).clamp(0.08, 1.0);
    return ActionableItem(
      onTap: onTap,
      semanticLabel: '${texts.title(card)}. ${texts.subtitle(card)}. ${texts.due(card, today)}',
      actions: ItemActions(
        onEdit: onEdit,
        onDelete: onDelete,
        extra: [
          ItemAction(
            icon: card.suspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: card.suspended ? l.hifzUnsuspend : l.hifzSuspend,
            onSelected: onToggleSuspend,
            tone: card.suspended ? ActionTone.success : ActionTone.warning,
          ),
          if (onReset != null && !card.isNew)
            ItemAction(icon: Icons.restart_alt_rounded, label: l.hifzResetProgress, onSelected: onReset!),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: card.suspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: card.suspended ? l.hifzUnsuspend : l.hifzSuspend,
          onPressed: onToggleSuspend,
          tone: ActionTone.warning,
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.hifzDelete,
          onPressed: onDelete,
          tone: ActionTone.danger,
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            ProgressRing(
              value: strength,
              size: 44,
              strokeWidth: 3.5,
              color: card.suspended ? t.textTertiary : (strength >= 1 ? t.success : t.brass),
              glow: false,
              child: Icon(hifzKindIcon(card.kind), size: 19, color: card.suspended ? t.textTertiary : t.accent),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.title(card),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium!.copyWith(color: card.suspended ? t.textSecondary : t.textPrimary),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(texts.subtitle(card), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  card.suspended ? l.hifzSuspendedBadge : texts.due(card, today),
                  style: text.labelMedium!.copyWith(color: dueColor, fontWeight: FontWeight.w600),
                ),
                if (!card.isNew) ...[
                  const SizedBox(height: 2),
                  Text(hifzIntervalText(l, fmt, card.sm2.intervalDays), style: text.labelSmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
