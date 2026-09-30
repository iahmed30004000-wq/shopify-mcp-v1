import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../../health/meds/data/meds_notifications.dart' show MedsNotificationTaps;
import '../data/center_controller.dart';
import '../data/center_hooks.dart';
import '../data/center_providers.dart';
import '../domain/center_models.dart';
import '../domain/center_policy.dart';
import '../domain/center_texts.dart';
import '../domain/describers.dart';

/// What the center's rows, sections and sheets do – each with its sound,
/// haptic and undo toast, the same everywhere.
abstract final class CenterActions {
  static NotificationCenterController _c(WidgetRef ref) => ref.read(notificationCenterProvider.notifier);

  static DateTime _now(WidgetRef ref) => ref.read(notificationCenterClockProvider)();

  static void _toast(BuildContext context, UndoableAction action) {
    if (!context.mounted) return;
    unawaited(showUndoToast(context, action));
  }

  static void _failed(BuildContext context) {
    Fx.fire(Sfx.error);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(CenterTexts.of(context).l.ncActionFailed)));
  }

  /// The sound (and paired haptic) of an inline action's button.
  static Sfx sfxOf(CenterActionSpec action) => switch (action.id) {
    MedsNotificationTaps.actionTaken => Sfx.complete,
    MedsNotificationTaps.actionSkip => Sfx.swipe,
    MedsNotificationTaps.actionSnooze => Sfx.drop,
    _ => action.tone == ActionTone.danger ? Sfx.toggleOff : Sfx.tap,
  };

  /// One of the notification's own buttons (Taken, Stop …); its button
  /// plays [sfxOf].
  static Future<void> perform(BuildContext context, WidgetRef ref, CenterItem item, CenterActionSpec action) async {
    final ok = await _c(ref).perform(item, action.id);
    if (!ok && context.mounted) _failed(context);
  }

  /// Opens what [item] is about (the lead's router), recording it opened.
  static Future<void> open(BuildContext context, WidgetRef ref, CenterItem item) async {
    final links = ref.read(notificationCenterLinksProvider);
    final open = links.open;
    if (open == null) return;
    Fx.fire(Sfx.navigate);
    await _c(ref).markOpened(item);
    if (!context.mounted) return;
    await open(context, item.notice.toTap());
  }

  static Future<void> openSettings(
    BuildContext context,
    WidgetRef ref,
    NotificationGroup group, [
    CenterItem? item,
  ]) async {
    final link = ref.read(notificationCenterLinksProvider).settings[group];
    if (link == null) return;
    Fx.fire(Sfx.navigate);
    await link(context, group, item?.notice);
  }

  /// Snoozes a delivered notification by [by] (toast: undo = cancel it and
  /// bring nothing back – the snoozed original is gone from the tray).
  static Future<void> snooze(BuildContext context, WidgetRef ref, CenterItem item, Duration by) async {
    Fx.fire(Sfx.drop);
    final tx = CenterTexts.of(context);
    final until = await _c(ref).snooze(item, by);
    if (!context.mounted) return;
    if (until == null) return _failed(context);
    _toast(
      context,
      UndoableAction(
        label: tx.l.ncSnoozedToast(tx.until(until, _now(ref))),
        undo: () =>
            _c(ref).cancelSnooze(CenterItem(notice: item.notice, group: item.group, state: CenterItemState.snoozed)),
      ),
    );
  }

  static Future<void> pickSnooze(BuildContext context, WidgetRef ref, CenterItem item) async {
    final by = await showSnoozeSheet(context, now: _now(ref));
    if (by == null || !context.mounted) return;
    await snooze(context, ref, item, by);
  }

  static Future<UndoableAction> skip(BuildContext context, WidgetRef ref, CenterItem item) async {
    final l = CenterTexts.of(context).l;
    Fx.fire(Sfx.toggleOff);
    final undo = await _c(ref).skip(item);
    return UndoableAction(label: l.ncSkippedToast, undo: undo);
  }

  static Future<void> restore(BuildContext context, WidgetRef ref, CenterItem item) async {
    Fx.fire(Sfx.toggleOn);
    await _c(ref).restore(item);
  }

  static Future<void> cancelSnooze(BuildContext context, WidgetRef ref, CenterItem item) async {
    Fx.fire(Sfx.toggleOff);
    await _c(ref).cancelSnooze(item);
  }

  static Future<UndoableAction> dismiss(BuildContext context, WidgetRef ref, CenterItem item) async {
    final l = CenterTexts.of(context).l;
    Fx.fire(Sfx.swipe);
    final undo = await _c(ref).dismiss(item);
    return UndoableAction(label: l.ncDismissed, undo: undo);
  }

  static Future<void> clearAll(BuildContext context, WidgetRef ref) async {
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final count = ref.read(notificationCenterProvider).recent.length;
    Fx.fire(Sfx.delete);
    final undo = await _c(ref).clearAll();
    if (undo == null || !context.mounted) return;
    _toast(context, UndoableAction(label: tx.digits(l.ncClearedAll(count)), undo: undo));
  }

  /// Asks how long, then mutes [group].
  static Future<void> pickMute(BuildContext context, WidgetRef ref, NotificationGroup group) async {
    final state = ref.read(notificationCenterProvider);
    final now = _now(ref);
    final choice = await showMuteSheet(context, group: group, now: now, mutedUntil: state.mutes[group]);
    if (choice == null || !context.mounted) return;
    if (choice.unmute) return unmute(context, ref, group);
    await mute(context, ref, group, choice.until!);
  }

  static Future<void> mute(BuildContext context, WidgetRef ref, NotificationGroup group, DateTime until) async {
    final tx = CenterTexts.of(context);
    Fx.fire(Sfx.toggleOff);
    final undo = await _c(ref).mute(group, until);
    if (!context.mounted) return;
    _toast(context, UndoableAction(label: tx.l.ncMutedToast(tx.group(group), tx.until(until, _now(ref))), undo: undo));
  }

  static Future<void> unmute(BuildContext context, WidgetRef ref, NotificationGroup group) async {
    Fx.fire(Sfx.toggleOn);
    await _c(ref).unmute(group);
  }
}

/// The mute sheet's answer.
@immutable
class MuteChoice {
  const MuteChoice.until(DateTime this.until) : unmute = false;
  const MuteChoice.unmute() : until = null, unmute = true;

  final DateTime? until;
  final bool unmute;
}

/// "Mute Money dues": for an hour, four hours, until tomorrow morning, a
/// week (each with the moment it ends) – or unmute when it is muted.
Future<MuteChoice?> showMuteSheet(
  BuildContext context, {
  required NotificationGroup group,
  required DateTime now,
  DateTime? mutedUntil,
}) {
  return showInteractionSheet<MuteChoice>(
    context,
    builder: (context) {
      final tx = CenterTexts.of(context);
      final l = tx.l;
      String label(MuteLength m) => switch (m) {
        MuteLength.hour => tx.digits(l.ncMuteForHours(1)),
        MuteLength.fourHours => tx.digits(l.ncMuteForHours(4)),
        MuteLength.untilMorning => l.ncMuteUntilMorning,
        MuteLength.week => l.ncMuteWeek,
      };
      return InteractionSheetFrame(
        title: l.ncMuteTitle(tx.group(group)),
        subtitle: l.ncMuteSubtitle,
        icon: Icons.notifications_paused_rounded,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mutedUntil != null) ...[
              _SheetOption(
                icon: Icons.notifications_active_rounded,
                label: l.ncActionUnmute,
                detail: l.ncMutedUntil(tx.until(mutedUntil, now)),
                accent: true,
                onTap: () => Navigator.of(context).pop(const MuteChoice.unmute()),
              ),
              const SizedBox(height: Space.s),
            ],
            for (final m in MuteLength.values) ...[
              _SheetOption(
                icon: switch (m) {
                  MuteLength.hour => Icons.hourglass_bottom_rounded,
                  MuteLength.fourHours => Icons.hourglass_top_rounded,
                  MuteLength.untilMorning => Icons.bedtime_rounded,
                  MuteLength.week => Icons.date_range_rounded,
                },
                label: label(m),
                detail: l.ncOptionUntil(tx.until(m.endFrom(now), now)),
                onTap: () => Navigator.of(context).pop(MuteChoice.until(m.endFrom(now))),
              ),
              const SizedBox(height: Space.s),
            ],
          ],
        ),
      );
    },
  );
}

/// "Bring it back later": 10 minutes, 30 minutes, an hour.
Future<Duration?> showSnoozeSheet(BuildContext context, {required DateTime now}) {
  return showInteractionSheet<Duration>(
    context,
    builder: (context) {
      final tx = CenterTexts.of(context);
      final l = tx.l;
      return InteractionSheetFrame(
        title: l.ncSnoozeTitle,
        subtitle: l.ncSnoozeSubtitle,
        icon: Icons.snooze_rounded,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in centerSnoozeLengths) ...[
              _SheetOption(
                icon: Icons.snooze_rounded,
                label: l.ncActionSnoozeFor(tx.duration(d)),
                detail: l.ncOptionAt(tx.until(now.add(d), now)),
                onTap: () => Navigator.of(context).pop(d),
              ),
              const SizedBox(height: Space.s),
            ],
          ],
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final hue = accent ? t.accent : t.textSecondary;
    return GlassCard(
      onTap: onTap,
      glow: accent,
      glowColor: accent ? t.accentGlow : null,
      semanticLabel: CenterTexts.of(context).join([label, detail]),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Icon(icon, size: 22, color: hue),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(label, style: text.titleSmall!.copyWith(color: accent ? t.accent : t.textPrimary)),
            ),
            const SizedBox(width: Space.s),
            Text(detail, style: text.bodySmall!.copyWith(color: t.textTertiary)),
          ],
        ),
      ),
    );
  }
}
