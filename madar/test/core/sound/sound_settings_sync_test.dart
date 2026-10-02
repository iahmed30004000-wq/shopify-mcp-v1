import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/sound/sound_settings_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_fakes.dart';

void main() {
  group('SoundSettingsSync', () {
    late SpySoundService sound;
    late SpyHaptics haptics;
    late SoundSettingsSync sync;

    setUp(() {
      sound = SpySoundService();
      haptics = SpyHaptics();
      sync = SoundSettingsSync(sound: sound, haptics: haptics);
    });

    test('first apply pushes every setting', () {
      sync.apply(const AppSettings());
      expect(sound.calls, contains('enabled true'));
      expect(sound.volumes, const AppSettings().volumes);
      expect(sound.calls, contains('profile lapis'));
      expect(sound.calls, isNot(contains('startAmbient')), reason: 'ambient is off by default');
      expect(haptics.enabled, isTrue);
    });

    test('only changed inputs produce calls', () {
      const s = AppSettings();
      sync.apply(s);
      sound.calls.clear();
      sync.apply(s.copyWith(volumes: {...s.volumes, SoundCategory.games: 0.2}));
      expect(sound.calls, ['volume games 0.2']);
    });

    test('theme → profile, including follow-system', () {
      const s = AppSettings(themeId: MadarThemeId.desert);
      sync.apply(s);
      expect(sync.profileId, 'desert');
      sync.apply(s.copyWith(themeId: MadarThemeId.aurora));
      expect(sound.calls.last, 'profile aurora');

      sync.apply(s.copyWith(themeId: MadarThemeId.emerald, followSystem: true));
      expect(sync.profileId, 'emerald', reason: 'dark system → chosen theme');
      sync.setPlatformBrightness(Brightness.light);
      expect(sync.profileId, 'pearl', reason: 'light system → Pearl');
    });

    test('ambient follows ambientEnabled, the sound switch and foreground', () {
      const s = AppSettings(ambientEnabled: true);
      sync.apply(s);
      expect(sound.calls, contains('startAmbient'));
      sync.apply(s.copyWith(soundEnabled: false));
      expect(sound.calls.last, 'stopAmbient');
      expect(sound.enabled, isFalse);
      sync.apply(s);
      expect(sound.calls.last, 'startAmbient');

      sync.setForeground(false);
      expect(sound.foreground, isFalse);
      expect(sound.calls.last, 'stopAmbient');
      sync.setForeground(true);
      expect(sound.foreground, isTrue);
      expect(sound.calls.last, 'startAmbient');
    });

    test('haptics switch', () {
      sync.apply(const AppSettings(hapticsEnabled: false));
      expect(haptics.enabled, isFalse);
    });
  });

  group('soundSettingsSyncProvider', () {
    testWidgets('wires settings, Fx and lifecycle through Riverpod', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sound = SpySoundService();
      final haptics = SpyHaptics();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        soundServiceProvider.overrideWithValue(sound),
        hapticsServiceProvider.overrideWithValue(haptics),
      ]);
      addTearDown(container.dispose);

      final sync = container.read(soundSettingsSyncProvider);
      expect(sync.profileId, 'lapis');
      expect(identical(Fx.instance?.sound, sound), isTrue);

      Fx.fire(Sfx.complete);
      expect(sound.calls.last, 'play complete');
      expect(haptics.fired.last, Haptic.success);

      await container.read(appSettingsProvider.notifier).update((s) => s.copyWith(themeId: MadarThemeId.emerald));
      expect(sound.calls.last, 'profile emerald');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(sound.foreground, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(sound.foreground, isTrue);
    });
  });
}
