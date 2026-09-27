import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_preferences.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/routing/routes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound.dart';
import 'settings_controller.dart';
import 'widgets/appearance_pickers.dart';
import 'widgets/settings_widgets.dart';

/// Settings hub: appearance and sound (own pages), motion and power (inline),
/// data (import), about (version, font credits and licences) and the design
/// gallery. Every change applies instantly.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final settings = ref.watch(appSettingsProvider);
    final brightness = ref.watch(platformBrightnessProvider);
    final theme = settings.effectiveTheme(brightness);
    final profile = SoundProfiles.idForTheme(theme);
    final languageName = settings.isArabic ? l.settingsLanguageArabic : l.settingsLanguageEnglish;

    return MadarScaffold(
      title: l.settingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: settings.powerMode != PowerMode.batterySaver,
      backdropSeed: 0.23,
      body: SettingsListView(
        horizontal: Space.gutter,
        top: Space.xs,
        children: [
          StaggerIn(
            id: 'settings',
            children: [
              SettingsSection(
                title: l.settingsPersonal,
                seed: 0.1,
                children: [
                  SettingsTile(
                    icon: Icons.palette_rounded,
                    title: l.settingsAppearance,
                    subtitle: '${themeName(l, theme)} · $languageName',
                    navigates: true,
                    trailing: const _ThemeDot(),
                    onTap: () => context.go(AppRoutes.appearance),
                  ),
                  SettingsTile(
                    icon: Icons.graphic_eq_rounded,
                    title: l.settingsSound,
                    subtitle: settings.soundEnabled ? l.soundProfileName(profile) : l.settingsSoundSubtitle,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.sound),
                  ),
                ],
              ),
              SettingsSection(
                title: l.settingsMotion,
                seed: 0.3,
                children: [
                  SettingsChoiceTile<MotionPreference>(
                    icon: Icons.animation_rounded,
                    title: l.settingsMotion,
                    subtitle: l.settingsMotionHint,
                    selected: settings.motion,
                    options: [
                      ChoiceOption(value: MotionPreference.system, label: l.settingsMotionSystem),
                      ChoiceOption(value: MotionPreference.reduced, label: l.settingsMotionReduced),
                      ChoiceOption(value: MotionPreference.full, label: l.settingsMotionFull),
                    ],
                    onChanged: (m) => ref.updateSettings((s) => SettingsChanges.motion(s, m)),
                  ),
                  SettingsChoiceTile<PowerMode>(
                    icon: Icons.bolt_rounded,
                    title: l.settingsPower,
                    subtitle: l.settingsPowerHint,
                    selected: settings.powerMode,
                    options: [
                      ChoiceOption(value: PowerMode.auto, label: l.settingsPowerAuto),
                      ChoiceOption(value: PowerMode.batterySaver, label: l.settingsPowerSaver, icon: Icons.eco_rounded),
                    ],
                    onChanged: (p) => ref.updateSettings((s) => SettingsChanges.power(s, p)),
                  ),
                ],
              ),
              SettingsSection(
                title: l.settingsData,
                seed: 0.5,
                children: [
                  SettingsTile(
                    icon: Icons.move_to_inbox_rounded,
                    title: l.settingsImport,
                    subtitle: l.settingsImportHint,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.import),
                  ),
                  SettingsNote(l.settingsPrivacyNote, icon: Icons.lock_rounded),
                ],
              ),
              SettingsSection(
                title: l.settingsAbout,
                seed: 0.7,
                children: [
                  SettingsTile(
                    icon: Icons.brightness_7_rounded,
                    iconColor: t.gold,
                    title: l.appName,
                    subtitle: '${l.appTagline} · ${l.settingsVersion(BidiIsolate.ltr(madarVersion))}',
                  ),
                  SettingsTile(
                    icon: Icons.font_download_rounded,
                    title: l.settingsFonts,
                    subtitle: l.settingsFontsBody,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.licenses),
                  ),
                ],
              ),
              SettingsSection(
                title: l.settingsDeveloper,
                seed: 0.9,
                children: [
                  SettingsTile(
                    icon: Icons.auto_awesome_mosaic_rounded,
                    title: l.designGalleryTitle,
                    subtitle: l.settingsGalleryHint,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.gallery),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tiny orb in the active accent over the theme's deep-space colour.
class _ThemeDot extends StatelessWidget {
  const _ThemeDot();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.medium),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [t.accent, t.space2]),
        border: Border.all(color: t.glassBorder),
        boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.5), blurRadius: 8)],
      ),
    );
  }
}
