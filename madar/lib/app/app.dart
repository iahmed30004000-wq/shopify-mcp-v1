import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design/themes.dart';
import '../core/design/widgets/ambient_motion.dart';
import '../core/design/tokens.dart';
import '../core/i18n/formatters.dart';
import '../core/i18n/gen/app_localizations.dart';
import '../core/interaction/quick_add/quick_add_handler.dart';
import '../core/motion/motion_kit.dart';
import '../core/providers.dart';
import '../core/routing/router.dart';
import '../core/settings/app_settings.dart';
import '../core/sound/sound_api.dart';
import '../core/sound/sound_settings_sync.dart';
import '../features/home/home_providers.dart';
import 'app_gate.dart';
import 'app_preferences.dart';

/// The root overrides of the Madar provider scope – shared by `bootstrap`
/// and the test harness so both run the same wiring.
///
/// * [prefs], [sound] and [haptics] are the platform services.
/// * `databaseProvider` resolves to the database opened by
///   [databaseUnlockProvider] (see [AppGate]).
/// * The quick-add bar gets the shell's handler (tasks, money, water …).
List<Override> madarAppOverrides({
  required SharedPreferences prefs,
  required SoundService sound,
  required HapticsService haptics,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  soundServiceProvider.overrideWithValue(sound),
  hapticsServiceProvider.overrideWithValue(haptics),
  databaseProvider.overrideWith((ref) => ref.watch(databaseUnlockProvider).requireValue),
  quickAddHandlerProvider.overrideWith((ref) => ref.watch(shellQuickAddHandlerProvider)),
];

/// The app's [ThemeData], rebuilt only when an input of the theme changes
/// (theme id for the platform brightness, custom accent, script). Watching
/// the whole settings would hand MaterialApp a new theme on every unrelated
/// change (a volume drag, the digit style …) and replay the theme animation.
final madarThemeDataProvider = Provider<ThemeData>((ref) {
  final brightness = ref.watch(platformBrightnessProvider);
  final k = ref.watch(appSettingsProvider.select((s) => (s.effectiveTheme(brightness), s.customAccent, s.isArabic)));
  return buildMadarTheme(k.$1, customAccent: k.$2, arabic: k.$3);
});

/// The Madar app: router, theme (smoothly cross-faded on every change through
/// [MadarTokens.lerp]), locale (switches instantly – no restart – and flips
/// the whole layout between RTL and LTR), and the shell layers every screen
/// shares ([AppFrame]).
class MadarApp extends ConsumerWidget {
  const MadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Applies settings to the audio engine / haptics and installs Fx.
    ref.watch(soundSettingsSyncProvider);
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(routerProvider);
    final reduced = resolveReducedMotion(
      settings.motion,
      systemReduced: WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations,
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => L10n.of(context).appName,
      theme: ref.watch(madarThemeDataProvider),
      themeMode: ThemeMode.light,
      themeAnimationDuration: reduced ? MadarMotion.reduced : MadarMotion.long,
      themeAnimationCurve: MadarMotion.standard,
      locale: settings.locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => AppFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Everything between MaterialApp and the navigator: system bar styling,
/// the digit style for [MadarFormatter], the effective reduced-motion flag,
/// the app-wide [CelebrationOverlay] and the database / lock [AppGate].
class AppFrame extends ConsumerWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final reduced = resolveReducedMotion(settings.motion, systemReduced: MediaQuery.disableAnimationsOf(context));
    final t = context.tokens;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(t.brightness),
      child: ColoredBox(
        color: t.space0,
        child: MadarFormatScope(
          digits: settings.digits,
          child: MotionScope(
            reduced: reduced,
            // Battery saver: every decorative loop (cosmos, glass sheens,
            // empty states) renders one static frame.
            child: AmbientMotionScope(
              enabled: settings.powerMode != PowerMode.batterySaver,
              child: CelebrationOverlay(child: AppGate(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}
