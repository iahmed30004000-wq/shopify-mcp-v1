import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/settings/app_settings.dart';
import '../adhkar/adhkar.dart' show AdhkarReminderSettings, adhkarReminderSettingsProvider;
import '../wird/wird.dart' show wirdPlansProvider;
import 'widgets/adhkar_reminder_settings.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/wird_reminder_settings.dart';

/// Reminders switched on: the morning / evening adhkar and every wird plan
/// that can be reminded (Settings' Faith entry shows the count).
final faithRemindersOnProvider = Provider<int>((ref) {
  final adhkar = ref.watch(adhkarReminderSettingsProvider).value ?? const AdhkarReminderSettings();
  final plans = ref.watch(wirdPlansProvider).value ?? const [];
  return (adhkar.morning ? 1 : 0) + (adhkar.evening ? 1 : 0) + wirdRemindersOn(plans);
});

/// Settings › Reminders: the adhkar of the morning and evening after their
/// prayers, and each wird plan's reminder after its prayer – everything
/// that arrives as a notification around the prayers, on one page.
class RemindersSettingsScreen extends ConsumerWidget {
  const RemindersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    return MadarScaffold(
      title: l.settingsReminders,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.47,
      body: const SettingsListView(
        children: [
          StaggerIn(
            id: 'reminders-settings',
            fade: false,
            children: [
              AdhkarReminderSettingsSection(seed: 0.25),
              WirdReminderSettingsSection(seed: 0.35),
            ],
          ),
        ],
      ),
    );
  }
}
