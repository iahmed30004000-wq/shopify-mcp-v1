import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_settings.dart';

/// Whether motion is reduced: the in-app preference wins, `system` follows
/// the platform's "remove animations" accessibility setting. Pure.
bool resolveReducedMotion(MotionPreference preference, {required bool systemReduced}) => switch (preference) {
  MotionPreference.system => systemReduced,
  MotionPreference.reduced => true,
  MotionPreference.full => false,
};

/// Transparent, edge-to-edge system bars with icons that contrast with the
/// theme ([brightness] is the theme's brightness).
SystemUiOverlayStyle systemBarsFor(Brightness brightness) {
  const clear = Color(0x00000000);
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: clear,
    systemNavigationBarColor: clear,
    systemNavigationBarDividerColor: clear,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}

/// The platform's light/dark mode, kept current (drives
/// `AppSettings.followSystem`).
final platformBrightnessProvider = NotifierProvider<PlatformBrightnessNotifier, Brightness>(
  PlatformBrightnessNotifier.new,
);

class PlatformBrightnessNotifier extends Notifier<Brightness> with WidgetsBindingObserver {
  @override
  Brightness build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.platformBrightness;
  }

  @override
  void didChangePlatformBrightness() => state = WidgetsBinding.instance.platformDispatcher.platformBrightness;
}

/// Version shown in Settings › About: `--dart-define=MADAR_VERSION=…` when
/// the build provides it, else the pubspec version of this source tree.
const String madarVersion = String.fromEnvironment('MADAR_VERSION', defaultValue: '0.1.0');
