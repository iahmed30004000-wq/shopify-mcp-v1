import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_preferences.dart';
import '../../core/design/themes.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/settings/app_settings.dart';
import 'settings_controller.dart';
import 'widgets/appearance_pickers.dart';
import 'widgets/settings_widgets.dart';

/// A theme card tapped on the Appearance page. While following the device,
/// a dark theme becomes the dark-mode pairing; picking Pearl – which already
/// serves light mode – means "Pearl always", so following stops. Pure.
AppSettings pickTheme(AppSettings s, MadarThemeId id) {
  if (s.followSystem && id == MadarThemeId.pearl) {
    return SettingsChanges.followSystem(SettingsChanges.theme(s, id), false);
  }
  return SettingsChanges.theme(s, id);
}

/// Theme (five live miniatures), follow-the-device, accent colour, language
/// and digit style. Every tap re-themes / re-lays-out the app at once.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(appSettingsProvider);
    final brightness = ref.watch(platformBrightnessProvider);
    final active = settings.effectiveTheme(brightness);
    final fmt = MadarFormatter.of(context);
    final sample = [fmt.formatNumber(12345.67), fmt.formatPercent(0.42), fmt.formatClock(15, 45)].join('  ·  ');

    return MadarScaffold(
      title: l.settingsAppearance,
      extendBodyBehindAppBar: true,
      animateBackdrop: settings.powerMode != PowerMode.batterySaver,
      backdropSeed: 0.41,
      body: SettingsListView(
        horizontal: 0,
        top: Space.xs,
        children: [
          // Glass panels only slide in: a fade is a save layer, and the
          // panels' backdrop blur would sample nothing until it ends.
          StaggerIn(
            id: 'appearance',
            fade: false,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
                child: SectionHeader(
                  title: l.settingsTheme,
                  subtitle: settings.followSystem ? l.settingsFollowSystemHint : null,
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.m),
                ),
              ),
              ThemeCarousel(
                // Following the device, the ring marks the dark-mode pick
                // (Pearl always serves light mode).
                selected: settings.followSystem && settings.themeId == MadarThemeId.pearl
                    ? MadarThemeId.lapis
                    : settings.themeId,
                followSystem: settings.followSystem,
                customAccent: settings.customAccent,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
                onSelected: (id) => ref.updateSettings((s) => pickTheme(s, id)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, 0),
                child: GlassPanel(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
                  seed: 0.2,
                  child: SettingsSwitchTile(
                    icon: Icons.brightness_6_rounded,
                    title: l.settingsFollowSystem,
                    subtitle: l.settingsFollowSystemHint,
                    value: settings.followSystem,
                    onChanged: (v) => ref.updateSettings((s) => SettingsChanges.followSystem(s, v)),
                  ),
                ),
              ),
              _Group(
                title: l.settingsAccent,
                seed: 0.35,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Space.l),
                  child: AccentPicker(
                    theme: active,
                    value: settings.customAccent,
                    onChanged: (c) => ref.updateSettings((s) => SettingsChanges.accent(s, c)),
                  ),
                ),
              ),
              _Group(
                title: l.settingsLanguage,
                seed: 0.5,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Space.l),
                  child: LanguagePicker(
                    languageCode: settings.languageCode,
                    onChanged: (code) => ref.updateSettings((s) => SettingsChanges.language(s, code)),
                  ),
                ),
              ),
              _Group(
                title: l.settingsDigits,
                seed: 0.65,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Space.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DigitStylePicker(
                        value: settings.digits,
                        onChanged: (d) => ref.updateSettings((s) => SettingsChanges.digits(s, d)),
                      ),
                      const SizedBox(height: Space.m),
                      // Cross-fades when the digit style changes; a new
                      // language swaps it at once (keyed by language, so
                      // no Arabic sample lingers in an English layout).
                      KeyedSubtree(
                        key: ValueKey(settings.languageCode),
                        child: AnimatedSwitcher(
                          duration: context.motion(MadarMotion.short),
                          child: Text(
                            sample,
                            key: ValueKey(sample),
                            textAlign: TextAlign.center,
                            style: text.titleMedium!.copyWith(
                              color: t.accent,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        l.settingsDigitsHint,
                        textAlign: TextAlign.center,
                        style: text.bodySmall!.copyWith(color: t.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child, this.seed = 0});

  final String title;
  final Widget child;
  final double seed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: title,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
          ),
          GlassPanel(padding: EdgeInsetsDirectional.zero, seed: seed, child: child),
        ],
      ),
    );
  }
}
