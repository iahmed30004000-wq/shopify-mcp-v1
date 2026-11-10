import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../../lock/application/lock_controller.dart';
import '../../wird/wird.dart';
import 'settings_widgets.dart';

/// Whether [plan] can be reminded at all: it runs (not paused) and has a
/// prayer to follow.
bool wirdPlanRemindable(WirdPlan plan) =>
    plan.active && plan.window != null && plan.window != PrayerWindow.anytime;

/// Wird reminders switched on (and able to arrive).
int wirdRemindersOn(Iterable<WirdPlan> plans) => plans.where((p) => wirdPlanRemindable(p) && p.meta.remind).length;

/// Settings › Reminders › Wird: each plan's reminder after its prayer –
/// on or off, and how long after the adhan. Saved in the plan's settings
/// (the plan itself is untouched) and re-planned at once through the wird
/// reminder sync; switching one on asks for notification permission (a
/// refusal keeps the choice and says why nothing will arrive). A plan
/// without a prayer, or paused, says so and offers its editor. No plan yet:
/// an invitation to start one.
class WirdReminderSettingsSection extends ConsumerStatefulWidget {
  const WirdReminderSettingsSection({super.key, this.seed = 0.35});

  final double seed;

  @override
  ConsumerState<WirdReminderSettingsSection> createState() => _WirdReminderSettingsSectionState();
}

class _WirdReminderSettingsSectionState extends ConsumerState<WirdReminderSettingsSection> {
  /// Notifications were refused when a reminder was switched on.
  bool _denied = false;

  /// Choices being saved, shown at once (the stored values follow).
  final Map<String, WirdPlanMeta> _pending = {};

  Future<void> _save(WirdPlan plan, {bool? remind, int? offset}) async {
    final next = plan.meta.copyWith(remind: remind, remindOffsetMin: offset);
    setState(() => _pending[plan.id] = next);
    try {
      if (remind ?? false) {
        final reminders = ref.read(wirdReminderServiceProvider);
        // Android's permission dialog must not trip the app lock.
        final allowed = await ref.read(lockControllerProvider.notifier).whileSuspended(reminders.ensurePermission);
        if (!allowed) Fx.fire(Sfx.notify);
        if (mounted) setState(() => _denied = !allowed);
      }
      await ref.read(wirdServiceProvider).setReminder(plan, remind: remind, offsetMin: offset);
      await ref.read(wirdReminderSyncProvider.notifier).syncNow();
    } catch (e) {
      Fx.fire(Sfx.error);
      debugPrint('Wird reminders: saving failed: $e');
    } finally {
      if (mounted) setState(() => _pending.remove(plan.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final plans = ref.watch(wirdPlansProvider).value;
    String offset(int m) => fmt.localizeDigits(l.adhkarReminderOffset(m));

    final rows = <Widget>[];
    if (plans == null) {
      rows.add(const SizedBox(height: 72, child: Center(child: OrbitLoader(size: 28))));
    } else if (plans.isEmpty) {
      rows
        ..add(SettingsNote(l.settingsWirdNoPlans, icon: Icons.auto_stories_outlined))
        ..add(
          SettingsTile(
            icon: Icons.add_rounded,
            title: l.wirdStartPlanCta,
            navigates: true,
            onTap: () => unawaited(WirdActions.create(context, ref)),
          ),
        );
    } else {
      for (final stored in plans) {
        final plan = stored.copyWith(meta: _pending[stored.id]);
        final meta = plan.meta;
        final remindable = wirdPlanRemindable(plan);
        final on = remindable && meta.remind;
        final String subtitle;
        if (!plan.active) {
          subtitle = l.settingsWirdPaused;
        } else if (!remindable) {
          subtitle = l.settingsWirdNoWindow;
        } else if (on) {
          subtitle = l.orbitUiListSeparator(
            wirdWindowLabel(l, plan.window),
            l.settingsAdhkarAfter(offset(meta.remindOffsetMin)),
          );
        } else {
          subtitle = l.settingsAdhkarOff;
        }
        rows.add(
          SettingsSwitchTile(
            key: ValueKey('wird-remind-${plan.id}'),
            icon: wirdTemplateIcon(plan.template),
            title: plan.name,
            subtitle: subtitle,
            value: on,
            onChanged: remindable ? (v) => unawaited(_save(stored, remind: v)) : null,
          ),
        );
        if (on) {
          rows.add(
            SettingsChoiceTile<int>(
              key: ValueKey('wird-offset-${plan.id}'),
              icon: Icons.timelapse_rounded,
              title: l.adhkarReminderOffsetCaption,
              options: [for (final m in WirdPlanMeta.offsets) ChoiceOption(value: m, label: offset(m))],
              selected: meta.remindOffsetMin,
              onChanged: (m) => unawaited(_save(stored, offset: m)),
            ),
          );
        } else if (plan.active && !remindable) {
          rows.add(
            SettingsTile(
              key: ValueKey('wird-edit-${plan.id}'),
              icon: Icons.edit_calendar_rounded,
              title: l.settingsWirdEditPlan,
              navigates: true,
              onTap: () => unawaited(WirdActions.edit(context, ref, stored)),
            ),
          );
        }
      }
      rows.add(
        _denied && wirdRemindersOn(plans) > 0
            ? SettingsNote(l.adhkarReminderPermissionDenied, icon: Icons.notifications_off_rounded)
            : SettingsNote(l.settingsWirdReminderNote, icon: Icons.notifications_active_outlined),
      );
    }

    return SettingsSection(title: l.settingsWirdReminders, seed: widget.seed, children: rows);
  }
}
