import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../../adhkar/adhkar.dart';
import '../../lock/application/lock_controller.dart';
import 'settings_widgets.dart';

/// Settings › Adhkar reminders: the morning adhkar after Fajr and the evening
/// adhkar after Asr, each with how long after the adhan it arrives.
///
/// Saved through the adhkar package's reminder service, which plans the next
/// week of reminders with the notification service (and keeps re-planning
/// them as the prayer times move). Switching one on asks for notification
/// permission once; a refusal keeps the choice and says why nothing will
/// arrive. Both are off on a fresh install.
class AdhkarReminderSettingsSection extends ConsumerStatefulWidget {
  const AdhkarReminderSettingsSection({super.key, this.seed = 0.4});

  final double seed;

  @override
  ConsumerState<AdhkarReminderSettingsSection> createState() => _AdhkarReminderSettingsSectionState();
}

class _AdhkarReminderSettingsSectionState extends ConsumerState<AdhkarReminderSettingsSection> {
  /// Notifications were refused when a reminder was switched on.
  bool _denied = false;

  /// The choice being saved, shown at once (the stored value follows).
  AdhkarReminderSettings? _pending;

  Future<void> _save(AdhkarReminderSettings next, AdhkarReminderSettings before) async {
    final l = L10n.of(context);
    final service = ref.read(adhkarReminderServiceProvider);
    setState(() => _pending = next);
    try {
      final turningOn = (next.morning && !before.morning) || (next.evening && !before.evening);
      if (turningOn) {
        // Android's permission dialog must not trip the app lock's privacy
        // cover or time-out.
        final allowed = await ref.read(lockControllerProvider.notifier).whileSuspended(service.ensurePermission);
        if (!allowed) Fx.fire(Sfx.notify);
        if (mounted) setState(() => _denied = !allowed);
      } else if (!next.anyEnabled && mounted) {
        setState(() => _denied = false);
      }
      await service.update(next, l);
    } catch (e) {
      Fx.fire(Sfx.error);
      debugPrint('Adhkar reminders: saving failed: $e');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final stored = ref.watch(adhkarReminderSettingsProvider).value ?? const AdhkarReminderSettings();
    final s = _pending ?? stored;
    String offset(int m) => fmt.localizeDigits(l.adhkarReminderOffset(m));
    void save(AdhkarReminderSettings next) => unawaited(_save(next, s));
    List<ChoiceOption<int>> options() => [
      for (final m in AdhkarReminderSettings.offsets) ChoiceOption(value: m, label: offset(m)),
    ];

    return SettingsSection(
      title: l.settingsAdhkarReminders,
      seed: widget.seed,
      children: [
        SettingsSwitchTile(
          icon: Icons.wb_sunny_rounded,
          title: l.settingsAdhkarMorning,
          subtitle: s.morning ? l.settingsAdhkarAfter(offset(s.morningOffsetMin)) : l.settingsAdhkarOff,
          value: s.morning,
          onChanged: (v) => save(s.copyWith(morning: v)),
        ),
        if (s.morning)
          SettingsChoiceTile<int>(
            key: const ValueKey('adhkar-morning-offset'),
            icon: Icons.timelapse_rounded,
            title: l.adhkarReminderOffsetCaption,
            options: options(),
            selected: AdhkarReminderSettings.snapOffset(s.morningOffsetMin),
            onChanged: (m) => save(s.copyWith(morningOffsetMin: m)),
          ),
        SettingsSwitchTile(
          icon: Icons.nights_stay_rounded,
          title: l.settingsAdhkarEvening,
          subtitle: s.evening ? l.settingsAdhkarAfter(offset(s.eveningOffsetMin)) : l.settingsAdhkarOff,
          value: s.evening,
          onChanged: (v) => save(s.copyWith(evening: v)),
        ),
        if (s.evening)
          SettingsChoiceTile<int>(
            key: const ValueKey('adhkar-evening-offset'),
            icon: Icons.timelapse_rounded,
            title: l.adhkarReminderOffsetCaption,
            options: options(),
            selected: AdhkarReminderSettings.snapOffset(s.eveningOffsetMin),
            onChanged: (m) => save(s.copyWith(eveningOffsetMin: m)),
          ),
        if (_denied && s.anyEnabled)
          SettingsNote(l.adhkarReminderPermissionDenied, icon: Icons.notifications_off_rounded)
        else
          SettingsNote(l.adhkarReminderNote, icon: Icons.notifications_active_outlined),
      ],
    );
  }
}
