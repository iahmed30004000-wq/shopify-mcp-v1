import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/interaction.dart';
import '../../data/center_controller.dart';
import '../../data/center_hooks.dart';
import '../../data/center_providers.dart';
import '../../domain/center_models.dart';
import '../../domain/center_texts.dart';
import '../../domain/describers.dart';
import '../center_actions.dart';
import '../center_visuals.dart';

/// One notification in the center: its group's disc, a human title and its
/// body, when it fires / fired, its state (muted, snoozed, answered …) and
/// – while it can still be answered – the notification's own buttons.
///
/// * Tap → opens what it is about (when the lead wired the link).
/// * Swipe right → Upcoming: this one won't arrive (skip); Recent: dismiss.
///   Both with undo.
/// * Swipe left → snooze / mute / settings.
/// * Long-press → everything: snooze…, skip / restore, mute the group,
///   reminder settings, open, dismiss.
class NotificationRow extends ConsumerWidget {
  const NotificationRow({super.key, required this.item});

  final CenterItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final d = ref.watch(notificationDescribersProvider).describe(item.notice, tx);
    final links = ref.watch(notificationCenterLinksProvider);
    final now = ref.watch(notificationCenterProvider.select((s) => s.now));
    final muted = ref.watch(notificationCenterProvider.select((s) => s.mutes[item.group]));
    final upcoming = item.state.isUpcoming;
    final dim = item.state == CenterItemState.muted || item.state == CenterItemState.skipped;
    final canOpen = links.opens(item.notice.toTap());
    final canSettings = links.hasSettings(item.group);
    final actions = [
      for (final a in d.actions)
        if (a.availableFor(item)) a,
    ];
    final snoozable = !upcoming && d.snoozable && item.state != CenterItemState.acted;
    final groupName = tx.group(item.group);

    final when = tx.when(item.at, now);
    final badge = _badge(context, tx, now, d);
    final showKind = d.kind != d.title && d.kind != groupName;
    final meta = [when, if (showKind) d.kind].join(' · ');

    return ActionableItem(
      semanticLabel: tx.join([d.title, ?d.body, meta, if (badge != null) badge.$1, if (item.unread) l.ncStateNew]),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: canOpen ? () => CenterActions.open(context, ref, item) : null,
      swipeEnabled: upcoming ? item.state == CenterItemState.scheduled : true,
      completeIcon: upcoming ? Icons.notifications_off_rounded : Icons.done_all_rounded,
      completeLabel: upcoming ? l.ncActionSkipOne : l.ncActionDismiss,
      onCompleteSwipe: () =>
          upcoming ? CenterActions.skip(context, ref, item) : CenterActions.dismiss(context, ref, item),
      actions: ItemActions(
        extra: [
          if (snoozable)
            ItemAction(
              icon: Icons.snooze_rounded,
              label: l.ncActionSnoozeMenu,
              onSelected: () => CenterActions.pickSnooze(context, ref, item).then((_) => null),
            ),
          if (item.state == CenterItemState.scheduled)
            ItemAction(
              icon: Icons.notifications_off_rounded,
              label: l.ncActionSkipOne,
              onSelected: () => CenterActions.skip(context, ref, item),
            ),
          if (item.state == CenterItemState.skipped)
            ItemAction(
              icon: Icons.restore_rounded,
              label: l.ncActionRestore,
              tone: ActionTone.success,
              onSelected: () => CenterActions.restore(context, ref, item).then((_) => null),
            ),
          if (item.state == CenterItemState.snoozed)
            ItemAction(
              icon: Icons.alarm_off_rounded,
              label: l.ncActionCancelSnooze,
              onSelected: () => CenterActions.cancelSnooze(context, ref, item).then((_) => null),
            ),
          ItemAction(
            icon: muted == null ? Icons.notifications_paused_rounded : Icons.notifications_active_rounded,
            label: muted == null ? l.ncActionMuteGroup(groupName) : l.ncActionUnmute,
            onSelected: () =>
                (muted == null
                        ? CenterActions.pickMute(context, ref, item.group)
                        : CenterActions.unmute(context, ref, item.group))
                    .then((_) => null),
          ),
          if (canSettings)
            ItemAction(
              icon: Icons.tune_rounded,
              label: l.ncActionSettings,
              onSelected: () => CenterActions.openSettings(context, ref, item.group, item).then((_) => null),
            ),
          if (canOpen)
            ItemAction(
              icon: Icons.open_in_new_rounded,
              label: l.ncActionOpen,
              onSelected: () => CenterActions.open(context, ref, item).then((_) => null),
            ),
          if (!upcoming)
            ItemAction(
              icon: Icons.close_rounded,
              label: l.ncActionDismiss,
              tone: ActionTone.danger,
              onSelected: () => CenterActions.dismiss(context, ref, item),
            ),
        ],
      ),
      quickActions: [
        if (snoozable)
          QuickAction(
            icon: Icons.snooze_rounded,
            label: l.ncActionSnooze,
            tone: ActionTone.info,
            onPressed: () => CenterActions.pickSnooze(context, ref, item).then((_) => null),
          ),
        QuickAction(
          icon: muted == null ? Icons.notifications_paused_rounded : Icons.notifications_active_rounded,
          label: muted == null ? l.ncSettingsMute : l.ncActionUnmute,
          tone: ActionTone.warning,
          onPressed: () =>
              (muted == null
                      ? CenterActions.pickMute(context, ref, item.group)
                      : CenterActions.unmute(context, ref, item.group))
                  .then((_) => null),
        ),
        if (canSettings)
          QuickAction(
            icon: Icons.tune_rounded,
            label: l.ncActionSettings,
            tone: ActionTone.neutral,
            onPressed: () => CenterActions.openSettings(context, ref, item.group, item).then((_) => null),
          ),
      ],
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: item.live || item.unread,
        glowColor: item.live ? groupColor(item.group, t).withValues(alpha: 0.35) : null,
        borderColor: item.unread ? t.accent.withValues(alpha: 0.45) : null,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CenterGroupDisc(group: item.group, icon: d.icon, live: item.live, dim: dim),
            const SizedBox(width: Space.m),
            Expanded(
              child: AnimatedOpacity(
                opacity: dim ? 0.62 : 1,
                duration: const Duration(milliseconds: 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            d.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall!.copyWith(
                              color: t.textPrimary,
                              fontWeight: item.unread ? FontWeight.w700 : FontWeight.w600,
                              decoration: item.state == CenterItemState.skipped ? TextDecoration.lineThrough : null,
                              decorationColor: t.textTertiary,
                            ),
                          ),
                        ),
                        if (item.unread) ...[
                          const SizedBox(width: Space.s),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _Dot(color: t.accent),
                          ),
                        ],
                      ],
                    ),
                    if (d.body != null && d.body!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.35),
                      ),
                    ],
                    const SizedBox(height: Space.xs + 2),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(meta, style: text.labelSmall!.copyWith(color: t.textTertiary, height: 1.3)),
                        if (badge != null) CenterBadge(label: badge.$1, color: badge.$2, icon: badge.$3),
                      ],
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: Space.s + 2),
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (final a in actions)
                            MadarButton(
                              label: a.label,
                              icon: a.icon,
                              size: MadarButtonSize.small,
                              sfx: CenterActions.sfxOf(a),
                              variant: a.primary
                                  ? (a.tone == ActionTone.danger
                                        ? MadarButtonVariant.danger
                                        : MadarButtonVariant.primary)
                                  : MadarButtonVariant.secondary,
                              onPressed: () => CenterActions.perform(context, ref, item, a),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The state label beside the time (text, hue, icon), or none.
  (String, Color, IconData?)? _badge(BuildContext context, CenterTexts tx, DateTime now, NotificationDescription d) {
    final t = context.tokens;
    final l = tx.l;
    return switch (item.state) {
      CenterItemState.scheduled => null,
      CenterItemState.muted => (l.ncStateMuted, t.warning, Icons.notifications_paused_rounded),
      CenterItemState.skipped => (l.ncStateSkipped, t.textSecondary, Icons.notifications_off_rounded),
      CenterItemState.snoozed => (l.ncStateSnoozed, t.info, Icons.snooze_rounded),
      CenterItemState.live => (l.ncStateLive, groupColor(item.group, t), Icons.circle),
      CenterItemState.delivered => null,
      CenterItemState.silenced => (l.ncStateSilenced, t.warning, Icons.volume_off_rounded),
      CenterItemState.deferred => (
        item.until == null ? l.ncStateSnoozed : l.ncStateSnoozedUntil(tx.until(item.until!, now)),
        t.info,
        Icons.snooze_rounded,
      ),
      CenterItemState.opened => (l.ncStateOpened, t.textTertiary, Icons.visibility_rounded),
      CenterItemState.acted => (
        l.ncStateAnswered(d.actions.where((a) => a.id == item.actionId).firstOrNull?.label ?? l.ncActionOpen),
        t.success,
        Icons.check_circle_rounded,
      ),
    };
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
    ),
  );
}
