import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart' show BudgetPeriod;
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../data/widget_providers.dart';
import '../domain/widget_kind.dart';
import 'widget_preview.dart';

/// Settings › Home-screen widgets: for each widget a live preview (exactly
/// what the home screen shows), whether it is on the home screen, and its
/// "Show details" switch – off by default while the app lock is on (counts
/// only: no names, times or amounts on the home screen); and the budget
/// widget's period.
///
/// Route it (e.g. `/settings/widgets`) or embed [WidgetsSettingsSection].
class WidgetsSettingsScreen extends ConsumerWidget {
  const WidgetsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    return MadarScaffold(
      title: l.widgetsSettingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.57,
      body: SettingsListView(
        children: [
          StaggerIn(
            id: 'settings-widgets',
            fade: false,
            children: [
              SettingsNote(l.widgetsSettingsIntro, icon: Icons.widgets_outlined),
              const WidgetsSettingsSection(showTitle: false),
            ],
          ),
        ],
      ),
    );
  }
}

class WidgetsSettingsSection extends ConsumerWidget {
  const WidgetsSettingsSection({super.key, this.showTitle = true, this.seed = 0.6});

  final bool showTitle;
  final double seed;

  static IconData iconOf(MadarWidgetKind kind) => switch (kind) {
    MadarWidgetKind.prayer => Icons.mosque_outlined,
    MadarWidgetKind.meds => Icons.medication_outlined,
    MadarWidgetKind.tasks => Icons.checklist_rounded,
    MadarWidgetKind.budget => Icons.account_balance_wallet_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final prefs = ref.watch(widgetPrefsProvider);
    final lockOn = ref.watch(widgetAppLockOnProvider);
    final installed = ref.watch(widgetInstalledProvider);
    final controller = ref.read(widgetPrefsProvider.notifier);
    String title(MadarWidgetKind k) => switch (k) {
      MadarWidgetKind.prayer => l.widgetsPrayerName,
      MadarWidgetKind.meds => l.widgetsMedsName,
      MadarWidgetKind.tasks => l.widgetsTasksName,
      MadarWidgetKind.budget => l.widgetsBudgetName,
    };
    String subtitle(MadarWidgetKind k, bool shown) {
      final what = k == MadarWidgetKind.prayer
          ? (shown ? l.widgetsPrayerDetailsShown : l.widgetsPrayerDetailsHidden)
          : (shown ? l.widgetsDetailsShown : l.widgetsDetailsHidden);
      final where = installed.contains(k) ? l.widgetsOnHomeScreen : l.widgetsNotAdded;
      return '$where · $what';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in MadarWidgetKind.values)
          SettingsSection(
            title: showTitle || kind != MadarWidgetKind.prayer ? title(kind) : null,
            seed: seed + kind.index * 0.07,
            children: [
              _LivePreview(kind: kind),
              SettingsSwitchTile(
                icon: iconOf(kind),
                title: l.widgetsShowDetails,
                subtitle: subtitle(kind, prefs.showsDetails(kind, appLockOn: lockOn)),
                value: prefs.showsDetails(kind, appLockOn: lockOn),
                onChanged: (v) => unawaited(controller.setDetails(kind, v)),
              ),
              if (kind == MadarWidgetKind.budget)
                SettingsChoiceTile<BudgetPeriod>(
                  icon: Icons.date_range_outlined,
                  title: l.widgetsBudgetPeriod,
                  options: [
                    ChoiceOption(value: BudgetPeriod.monthly, label: l.widgetsPeriodMonth),
                    ChoiceOption(value: BudgetPeriod.weekly, label: l.widgetsPeriodWeek),
                  ],
                  selected: prefs.budgetPeriod,
                  onChanged: (p) => unawaited(controller.setBudgetPeriod(p)),
                ),
            ],
          ),
        if (lockOn) SettingsNote(l.widgetsLockNote, icon: Icons.lock_outline_rounded),
        SettingsNote(l.widgetsPrivacyNote, icon: Icons.shield_moon_rounded),
      ],
    );
  }
}

/// What [kind]'s widget shows right now, drawn as on the home screen.
class _LivePreview extends ConsumerWidget {
  const _LivePreview({required this.kind});

  final MadarWidgetKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final build = ref.watch(widgetBuildProvider(kind)).value;
    final now = ref.watch(widgetNowProvider);
    final dark = context.tokens.isDark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.s),
      child: Center(
        child: SizedBox(
          height: 120,
          child: build == null
              ? const SizedBox(width: 250)
              : FittedBox(
                  child: MadarWidgetPreview(source: build, now: now, dark: dark),
                ),
        ),
      ),
    );
  }
}
