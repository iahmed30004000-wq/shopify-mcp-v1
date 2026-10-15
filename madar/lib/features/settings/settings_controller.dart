import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/themes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound_api.dart';

/// Every settings change the shell's screens make, as pure transforms of
/// [AppSettings] (unit-tested) applied through the contract's
/// `AppSettingsController.update`. Changes apply instantly: theme, locale,
/// motion and sound all react to the provider.
abstract final class SettingsChanges {
  static AppSettings theme(AppSettings s, MadarThemeId id) => s.copyWith(themeId: id);

  static AppSettings followSystem(AppSettings s, bool on) => s.copyWith(followSystem: on);

  static AppSettings accent(AppSettings s, Color? color) =>
      color == null ? s.copyWith(clearCustomAccent: true) : s.copyWith(customAccent: color);

  static AppSettings language(AppSettings s, String code) => s.copyWith(languageCode: code == 'en' ? 'en' : 'ar');

  static AppSettings digits(AppSettings s, DigitStyle style) => s.copyWith(digits: style);

  static AppSettings sound(AppSettings s, bool on) => s.copyWith(soundEnabled: on);

  static AppSettings haptics(AppSettings s, bool on) => s.copyWith(hapticsEnabled: on);

  static AppSettings ambient(AppSettings s, bool on) => s.copyWith(ambientEnabled: on);

  static AppSettings volume(AppSettings s, SoundCategory c, double v) =>
      s.copyWith(volumes: {...s.volumes, c: v.clamp(0.0, 1.0)});

  static AppSettings motion(AppSettings s, MotionPreference m) => s.copyWith(motion: m);

  static AppSettings power(AppSettings s, PowerMode p) => s.copyWith(powerMode: p);

  static AppSettings onboarded(AppSettings s) => s.copyWith(onboarded: true);
}

extension SettingsRef on WidgetRef {
  /// Applies [change] to the persisted settings (fire-and-forget; the
  /// in-memory state updates synchronously).
  void updateSettings(AppSettings Function(AppSettings s) change) =>
      unawaited(read(appSettingsProvider.notifier).update(change));
}
