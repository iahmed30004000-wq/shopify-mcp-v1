import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_preferences.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound.dart';
import 'settings_controller.dart';
import 'widgets/settings_widgets.dart';

/// Sound & haptics: the global switch, haptics, the cosmic ambience, a
/// volume slider per category (heard at the new level on release) and the
/// theme's sound character with a preview.
class SoundSettingsScreen extends ConsumerWidget {
  const SoundSettingsScreen({super.key});

  static IconData _categoryIcon(SoundCategory c) => switch (c) {
    SoundCategory.ui => Icons.touch_app_rounded,
    SoundCategory.ambient => Icons.blur_on_rounded,
    SoundCategory.games => Icons.sports_esports_rounded,
    SoundCategory.prayer => Icons.mosque_rounded,
  };

  static Sfx _previewFor(SoundCategory c) => switch (c) {
    SoundCategory.ui => Sfx.tap,
    SoundCategory.ambient => Sfx.sparkle,
    SoundCategory.games => Sfx.levelUp,
    SoundCategory.prayer => Sfx.prayerLit,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(appSettingsProvider);
    final brightness = ref.watch(platformBrightnessProvider);
    final profile = SoundProfiles.idForTheme(settings.effectiveTheme(brightness));
    final on = settings.soundEnabled;

    return MadarScaffold(
      title: l.settingsSound,
      extendBodyBehindAppBar: true,
      animateBackdrop: settings.powerMode != PowerMode.batterySaver,
      backdropSeed: 0.57,
      body: SettingsListView(
        horizontal: Space.gutter,
        top: Space.xs,
        children: [
          // Glass panels only slide in: a fade is a save layer, and the
          // panels' backdrop blur would sample nothing until it ends.
          StaggerIn(
            id: 'sound',
            fade: false,
            children: [
              SettingsSection(
                title: l.settingsGeneral,
                seed: 0.15,
                children: [
                  SettingsSwitchTile(
                    icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    title: l.settingsSoundEnabled,
                    subtitle: l.settingsSoundEnabledHint,
                    value: on,
                    onChanged: (v) => ref.updateSettings((s) => SettingsChanges.sound(s, v)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.vibration_rounded,
                    title: l.settingsHaptics,
                    subtitle: l.settingsHapticsHint,
                    value: settings.hapticsEnabled,
                    onChanged: (v) => ref.updateSettings((s) => SettingsChanges.haptics(s, v)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.nights_stay_rounded,
                    title: l.settingsAmbient,
                    subtitle: l.settingsAmbientHint,
                    value: settings.ambientEnabled,
                    onChanged: on ? (v) => ref.updateSettings((s) => SettingsChanges.ambient(s, v)) : null,
                  ),
                ],
              ),
              SettingsSection(
                title: l.settingsVolumes,
                seed: 0.35,
                children: [
                  for (final c in SoundCategory.values)
                    SettingsSliderTile(
                      icon: _categoryIcon(c),
                      title: l.soundCategoryName(c),
                      value: settings.volumes[c] ?? 1,
                      enabled: on,
                      onChanged: (v) => ref.updateSettings((s) => SettingsChanges.volume(s, c, v)),
                      onChangeEnd: (v) => Fx.fire(_previewFor(c), volume: v.clamp(0.05, 1.0)),
                    ),
                  SettingsNote(l.soundPrayerMuteNote, icon: Icons.mosque_outlined),
                ],
              ),
              SettingsSection(
                title: l.settingsSoundProfile,
                subtitle: l.settingsSoundProfileHint,
                seed: 0.55,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
                    child: Row(
                      children: [
                        SettingsIcon(Icons.music_note_rounded, color: t.gold),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: context.motion(MadarMotion.medium),
                            child: Column(
                              key: ValueKey(profile),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l.soundProfileName(profile), style: text.titleMedium),
                                Text(
                                  l.soundProfileDescription(profile),
                                  style: text.bodySmall!.copyWith(color: t.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        MadarButton(
                          label: l.soundPreview,
                          icon: Icons.play_arrow_rounded,
                          variant: MadarButtonVariant.secondary,
                          size: MadarButtonSize.small,
                          sfx: Sfx.complete,
                          onPressed: on ? () {} : null,
                        ),
                      ],
                    ),
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
