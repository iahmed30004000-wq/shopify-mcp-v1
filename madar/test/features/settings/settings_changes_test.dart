import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_preferences.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/settings/settings_controller.dart';

void main() {
  const s = AppSettings();

  test('appearance changes', () {
    expect(SettingsChanges.theme(s, MadarThemeId.aurora).themeId, MadarThemeId.aurora);
    expect(SettingsChanges.followSystem(s, true).followSystem, isTrue);
    const c = Color(0xFF4CC96B);
    final accented = SettingsChanges.accent(s, c);
    expect(accented.customAccent, c);
    expect(SettingsChanges.accent(accented, null).customAccent, isNull);
    expect(SettingsChanges.language(s, 'en').languageCode, 'en');
    expect(SettingsChanges.language(s, 'fr').languageCode, 'ar');
    expect(SettingsChanges.digits(s, DigitStyle.western).digits, DigitStyle.western);
  });

  test('sound changes keep the other volumes', () {
    final v = SettingsChanges.volume(s, SoundCategory.ambient, 1.4);
    expect(v.volumes[SoundCategory.ambient], 1.0);
    expect(v.volumes[SoundCategory.ui], s.volumes[SoundCategory.ui]);
    expect(SettingsChanges.sound(s, false).soundEnabled, isFalse);
    expect(SettingsChanges.haptics(s, false).hapticsEnabled, isFalse);
    expect(SettingsChanges.ambient(s, true).ambientEnabled, isTrue);
  });

  test('motion, power, onboarding', () {
    expect(SettingsChanges.motion(s, MotionPreference.reduced).motion, MotionPreference.reduced);
    expect(SettingsChanges.power(s, PowerMode.batterySaver).powerMode, PowerMode.batterySaver);
    expect(SettingsChanges.onboarded(s).onboarded, isTrue);
  });

  test('resolveReducedMotion: in-app preference wins, system follows the platform', () {
    expect(resolveReducedMotion(MotionPreference.system, systemReduced: true), isTrue);
    expect(resolveReducedMotion(MotionPreference.system, systemReduced: false), isFalse);
    expect(resolveReducedMotion(MotionPreference.reduced, systemReduced: false), isTrue);
    expect(resolveReducedMotion(MotionPreference.full, systemReduced: true), isFalse);
  });

  test('system bars contrast with the theme', () {
    expect(systemBarsFor(Brightness.dark).statusBarIconBrightness, Brightness.light);
    expect(systemBarsFor(Brightness.light).statusBarIconBrightness, Brightness.dark);
    expect(systemBarsFor(Brightness.dark).statusBarColor!.a, 0);
  });
}
