import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/center_controller.dart';
import '../../data/center_hooks.dart';
import '../../data/center_providers.dart';
import '../../data/group_settings.dart';
import '../../domain/center_models.dart';
import '../../domain/center_texts.dart';
import '../center_actions.dart';
import '../center_visuals.dart';

/// Settings › Notifications at a glance: every group with its switches as
/// its feature keeps them ("On", "4 of 6 on", "Off", "Set per item"), what
/// is coming this week and its mute – a tap opens the group's own reminder
/// settings (when the lead wired them), the bell mutes or unmutes it.
///
/// Embeddable in the Settings page as is; [showNotificationSettingsSheet]
/// shows it in a sheet.
class NotificationSettingsSummary extends ConsumerWidget {
  const NotificationSettingsSummary({super.key, this.onOpenSettings});

  /// Replaces the lead's settings link (the sheet closes itself first).
  final void Function(NotificationGroup group)? onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationGroupSettingsProvider);
    final state = ref.watch(notificationCenterProvider);
    final links = ref.watch(notificationCenterLinksProvider);
    final groups = [
      for (final g in NotificationGroup.values)
        if (g != NotificationGroup.other || state.upcomingIn(g) > 0) g,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups) ...[
          _GroupRow(
            group: g,
            settings: settings[g] ?? GroupReminderSettings.perItem(g),
            coming: state.upcomingIn(g),
            mutedUntil: state.mutes[g],
            onOpen: links.hasSettings(g)
                ? () => onOpenSettings != null ? onOpenSettings!(g) : CenterActions.openSettings(context, ref, g)
                : null,
          ),
          const SizedBox(height: Space.s),
        ],
      ],
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({
    required this.group,
    required this.settings,
    required this.coming,
    required this.mutedUntil,
    required this.onOpen,
  });

  final NotificationGroup group;
  final GroupReminderSettings settings;
  final int coming;
  final DateTime? mutedUntil;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final now = ref.watch(notificationCenterClockProvider)();
    final name = tx.group(group);
    final status = !settings.hasToggle
        ? l.ncSettingsPerItem
        : settings.total <= 1 || settings.allOn || !settings.enabled
        ? (settings.enabled ? l.ncSettingsOn : l.ncSettingsOff)
        : l.ncSettingsSome(tx.count(settings.on), tx.count(settings.total));
    final statusColor = !settings.hasToggle
        ? t.textSecondary
        : settings.enabled
        ? t.success
        : t.textTertiary;
    final muted = mutedUntil != null;
    return GlassCard(
      onTap: onOpen,
      glow: false,
      semanticLabel: tx.join([
        name,
        status,
        tx.digits(l.ncSettingsComing(coming)),
        if (muted) l.ncMutedUntil(tx.until(mutedUntil!, now)),
        if (onOpen != null) l.ncSettingsOpen(name),
      ]),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.xs, Space.s + 2),
      child: Row(
        children: [
          CenterGroupDisc(group: group, size: 38, dim: !settings.enabled && settings.hasToggle),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' · ${tx.digits(l.ncSettingsComing(coming))}'),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: t.textSecondary),
                ),
                if (muted) ...[
                  const SizedBox(height: Space.xs),
                  CenterBadge(
                    label: l.ncMutedUntil(tx.until(mutedUntil!, now)),
                    color: t.warning,
                    icon: Icons.notifications_paused_rounded,
                  ),
                ],
              ],
            ),
          ),
          MadarButton.icon(
            icon: muted ? Icons.notifications_active_rounded : Icons.notifications_paused_outlined,
            semanticLabel: muted ? l.ncActionUnmute : l.ncActionMuteGroup(name),
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: muted ? Sfx.toggleOn : Sfx.sheetOpen,
            onPressed: () =>
                muted ? CenterActions.unmute(context, ref, group) : CenterActions.pickMute(context, ref, group),
          ),
          if (onOpen != null)
            Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
        ],
      ),
    );
  }
}

/// The summary in a sheet (the center's tune button).
Future<void> showNotificationSettingsSheet(BuildContext context, WidgetRef ref) {
  final outer = context;
  return showInteractionSheet<void>(
    context,
    builder: (context) {
      final l = CenterTexts.of(context).l;
      return InteractionSheetFrame(
        title: l.ncSettingsTitle,
        subtitle: l.ncSettingsSubtitle,
        icon: Icons.notifications_rounded,
        body: NotificationSettingsSummary(
          onOpenSettings: (group) {
            Navigator.of(context).pop();
            if (outer.mounted) CenterActions.openSettings(outer, ref, group);
          },
        ),
      );
    },
  );
}
