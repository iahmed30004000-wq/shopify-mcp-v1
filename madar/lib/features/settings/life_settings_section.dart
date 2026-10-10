import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../body/body.dart' show BodyActions, BodyTab, bodyWaterTargetProvider;
import '../custom_modules/custom_modules.dart' show customModulesProvider;
import '../family/family.dart' show FamilyActions, FamilySettings, familySettingsProvider;
import '../travel/travel.dart' show TravelTab;
import 'widgets/settings_widgets.dart';

/// Settings › Life: the family's reach-out reminders (the daily digest and
/// birthdays – their sheet), the daily water target (its sheet), the
/// intermittent fasting plan and notifications (Body › Fasting), the
/// packing lists (Travel › Packing lists) and the user's own trackers and
/// lists. Every change is saved through its package's own store, so the
/// worlds, the reminders and the hubs follow at once; the pages open over
/// Settings (`push`: back returns here).
class LifeSettingsSection extends ConsumerWidget {
  const LifeSettingsSection({super.key, this.seed = 0.28});

  final double seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final family = ref.watch(familySettingsProvider).value;
    final water = ref.watch(bodyWaterTargetProvider);
    // The trackers the user keeps: an archived one is put away (the trackers
    // page lists it apart; the worlds and the reminders ignore it).
    final modules = ref.watch(customModulesProvider).value?.where((m) => !m.archived).length;
    return SettingsSection(
      title: l.lifeHubSettingsSection,
      subtitle: l.lifeHubSettingsSectionHint,
      seed: seed,
      children: [
        SettingsTile(
          icon: Icons.favorite_rounded,
          iconColor: t.accent,
          title: l.familyRemindersTitle,
          subtitle: family == null ? null : LifeSettingsSummary.family(l, fmt, family),
          navigates: true,
          onTap: () => unawaited(FamilyActions.openSettings(context, ref)),
        ),
        SettingsTile(
          icon: Icons.water_drop_rounded,
          title: l.bodyWaterTargetTitle,
          subtitle: l.lifeHubSettingsWaterValue(fmt.formatInt(water)),
          navigates: true,
          onTap: () => unawaited(BodyActions.editWaterTarget(context, ref)),
        ),
        SettingsTile(
          icon: Icons.nights_stay_rounded,
          title: l.bodyFastingTitle,
          subtitle: l.lifeHubSettingsFastingHint,
          navigates: true,
          onTap: () => context.push(AppRoutes.bodyOf(tab: BodyTab.fasting.name)),
        ),
        SettingsTile(
          icon: Icons.luggage_rounded,
          title: l.travelTabTemplates,
          subtitle: l.lifeHubSettingsTemplatesHint,
          navigates: true,
          onTap: () => context.push(AppRoutes.travelOf(tab: TravelTab.templates.name)),
        ),
        SettingsTile(
          icon: Icons.insights_rounded,
          title: l.cmodTitle,
          subtitle: modules == null
              ? null
              : l.lifeHubSettingsModulesCount(modules, fmt.formatInt(modules)),
          navigates: true,
          onTap: () => context.push(AppRoutes.modules),
        ),
      ],
    );
  }
}

/// The Life entries' one-line summaries (pure).
abstract final class LifeSettingsSummary {
  /// "Daily digest at 8:00 PM", "Birthdays only" or "Off".
  static String family(L10n l, MadarFormatter fmt, FamilySettings s) {
    if (s.digestEnabled) {
      return l.lifeHubSettingsFamilyOn(fmt.formatClock(s.digestMinutes ~/ 60, s.digestMinutes % 60));
    }
    return s.birthdaysEnabled ? l.lifeHubSettingsFamilyBirthdays : l.lifeHubSettingsFamilyOff;
  }
}
