import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_preferences.dart';
import '../../app/licenses.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/routing/routes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound.dart';
import '../adhan/presentation/adhan_permissions_card.dart';
import '../health/wellbeing/wellbeing.dart' show WellbeingSettings, wellbeingSettingsProvider;
import '../lock/application/lock_controller.dart';
import '../orbit/data/orbit_providers.dart' show prayerSettingsProvider;
import '../prayer/prayer.dart' show PrayerLabels, cityDatabaseProvider;
import '../quran/quran.dart' show QuranReaderMode, quranReaderPrefsProvider;
import '../recitation/recitation.dart' show recitationSettingsProvider;
import 'health_settings_screen.dart' show healthRemindersOnProvider;
import 'life_settings_section.dart';
import 'money_settings_section.dart';
import 'reminders_settings_screen.dart' show faithRemindersOnProvider;
import 'settings_controller.dart';
import 'system_settings_sections.dart';
import 'widgets/appearance_pickers.dart';
import 'widgets/settings_widgets.dart';

/// Settings hub: appearance and sound (own pages); faith – prayer times and
/// calculation, the adhan, Quran reading, recitation and the reminders
/// (adhkar and wird), each its own page, with the adhan's permissions card
/// below them; health (its own page: meal times, reminders, lab margin,
/// doctor report, worry window, emergency number); money (inline: base
/// currency and rates, weeks per month, week start, due reminders – see
/// [MoneySettingsSection]); life (inline: the family's reach-out
/// reminders, the water target, fasting, the packing lists and the
/// trackers – see [LifeSettingsSection]); motion and power (inline);
/// the system shell (inline: the notification centre and what each part
/// sends, the home-screen widgets, Together Mode and its two sheets, and
/// the AI's key, model and saved chats – see [SystemSettingsSections]);
/// motion and power (inline); privacy and security (the app lock's page);
/// «بياناتك» (the backup, the exports, the restore and the prototype
/// import – see [YourDataSection]); about (version, fonts and content
/// sources, licences) and the design gallery. Every change applies
/// instantly.
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
    final fmt = MadarFormatter.of(context);

    return MadarScaffold(
      title: l.settingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: settings.powerMode != PowerMode.batterySaver,
      backdropSeed: 0.23,
      body: SettingsListView(
        horizontal: Space.gutter,
        top: Space.xs,
        children: [
          // Glass panels only slide in: a fade is a save layer, and the
          // panels' backdrop blur would sample nothing until it ends.
          StaggerIn(
            id: 'settings',
            fade: false,
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
                title: l.settingsFaithSection,
                subtitle: l.settingsFaithSectionHint,
                seed: 0.2,
                children: [
                  SettingsTile(
                    icon: Icons.mosque_rounded,
                    iconColor: t.gold,
                    title: l.settingsPrayerTimes,
                    subtitle: _prayerSummary(l, ref),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.prayerSettings),
                  ),
                  SettingsTile(
                    icon: Icons.notifications_active_rounded,
                    title: l.settingsAdhan,
                    subtitle: l.adhanSettingsSubtitle,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.adhanSettings),
                  ),
                  SettingsTile(
                    icon: Icons.auto_stories_rounded,
                    iconColor: t.gold,
                    title: l.settingsQuran,
                    subtitle: _quranSummary(l, ref),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.quranSettings),
                  ),
                  SettingsTile(
                    icon: Icons.graphic_eq_rounded,
                    title: l.settingsRecitation,
                    subtitle: ref.watch(recitationSettingsProvider).value?.reciter.name(arabic: fmt.isArabic),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.recitationSettings),
                  ),
                  SettingsTile(
                    icon: Icons.alarm_rounded,
                    title: l.settingsReminders,
                    subtitle: fmt.localizeDigits(l.settingsRemindersCount(ref.watch(faithRemindersOnProvider))),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.reminders),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsetsDirectional.only(top: Space.m),
                child: AdhanPermissionsCard(),
              ),
              SettingsSection(
                title: l.healthHubSettingsSection,
                subtitle: l.healthHubSettingsSectionHint,
                seed: 0.25,
                children: [
                  SettingsTile(
                    icon: Icons.favorite_rounded,
                    iconColor: t.gold,
                    title: l.healthHubSettingsTitle,
                    subtitle: _healthSummary(l, fmt, ref),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.healthSettings),
                  ),
                ],
              ),
              const MoneySettingsSection(),
              const LifeSettingsSection(),
              const SystemSettingsSections(),
              SettingsSection(
                title: l.settingsSectionMotionPower,
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
                title: l.settingsSecuritySection,
                seed: 0.45,
                children: [
                  SettingsTile(
                    icon: Icons.fingerprint_rounded,
                    title: l.settingsAppLock,
                    subtitle: _lockSummary(l, ref.watch(lockControllerProvider)),
                    navigates: true,
                    onTap: () => context.go(AppRoutes.security),
                  ),
                ],
              ),
              const YourDataSection(),
              SettingsSection(
                title: l.settingsAbout,
                seed: 0.7,
                children: [
                  SettingsTile(
                    icon: Icons.brightness_7_rounded,
                    iconColor: t.gold,
                    title: l.appName,
                    subtitle: '${l.appTagline} · ${l.settingsVersion(fmt.formatVersion(madarVersion))}',
                  ),
                  SettingsTile(
                    icon: Icons.font_download_rounded,
                    title: l.settingsCredits,
                    subtitle: l.settingsCreditsBody,
                    navigates: true,
                    onTap: () => context.go(AppRoutes.licenses),
                  ),
                  SettingsTile(
                    icon: Icons.gavel_rounded,
                    title: l.settingsLicenses,
                    subtitle: l.settingsLicensesBody,
                    navigates: true,
                    onTap: () {
                      MadarLicenses.register();
                      showLicensePage(context: context, applicationName: l.appName, applicationVersion: madarVersion);
                    },
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
                    onTap: () => context.push(AppRoutes.gallery),
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

/// "Mushaf · with tajweed colours" – how the reader shows the text.
String? _quranSummary(L10n l, WidgetRef ref) {
  final prefs = ref.watch(quranReaderPrefsProvider).value;
  if (prefs == null) return null;
  return l.orbitUiListSeparator(
    prefs.mode == QuranReaderMode.mushaf ? l.quranModeMushaf : l.quranModeList,
    prefs.tajweed ? l.settingsQuranTajweedOn : l.settingsQuranTajweedOff,
  );
}

/// "2 reminders on · Emergency 911" – the health reminders switched on
/// (doses, appointments, the worry window) and the support note's number.
String _healthSummary(L10n l, MadarFormatter fmt, WidgetRef ref) {
  final on = ref.watch(healthRemindersOnProvider);
  final number = (ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings()).supportNumber;
  return l.healthHubSettingsEntrySummary(
    fmt.localizeDigits(l.healthHubSettingsRemindersOn(on, fmt.formatInt(on))),
    BidiIsolate.ltr(fmt.localizeDigits(number)),
  );
}

/// "Off", "On, with your PIN" or "On, with fingerprint and PIN".
String _lockSummary(L10n l, AppLockState lock) {
  if (!lock.armed) return l.settingsAppLockOff;
  return lock.biometrics ? l.settingsAppLockOnBio : l.settingsAppLockOn;
}

/// "Amman · Jordan (Ministry of Awqaf)" – where the prayer times are
/// calculated for, and how.
String _prayerSummary(L10n l, WidgetRef ref) {
  final settings = ref.watch(prayerSettingsProvider).value;
  if (settings == null) return l.ptLocationSubtitle;
  final lang = ref.watch(appSettingsProvider.select((s) => s.languageCode));
  final cities = ref.watch(cityDatabaseProvider).value;
  final place = l.placeLabel(settings, lang, cities: cities, withCountry: false);
  return l.orbitUiListSeparator(place, l.methodName(settings.method));
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
