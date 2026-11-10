// The lock screen's fingerprint face after the hotfix (the prompt opens by
// itself; a large "Use fingerprint" button after a cancel), for review:
//   flutter test --tags screenshot test/features/lock/lock_hotfix_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_shaders.dart';

import '../../helpers/screenshot_harness.dart';
import 'lock_test_utils.dart';

const _dir = 'hotfix';

Future<Widget> _app(
  WidgetTester tester,
  LockFixture fx, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
}) async {
  await tester.runAsync(AstrolabePrograms.load);
  // On a phone the lock screen shows in the foreground.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final prefs = await settingsPrefs(
    tester,
    AppSettings(onboarded: true, themeId: theme, languageCode: locale.languageCode),
  );
  return lockTestApp(
    prefs: prefs,
    overrides: fx.overrides,
    theme: theme,
    locale: locale,
    home: const Scaffold(body: SizedBox.expand()),
    builder: (context, child) => LockGateHost(child: child!),
  );
}

void main() {
  for (final (theme, locale) in [(MadarThemeId.lapis, const Locale('ar')), (MadarThemeId.pearl, const Locale('en'))]) {
    final tag = '${locale.languageCode}_${theme.name}';

    testWidgets('the prompt opened by itself: the astrolabe assembles – $tag', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.holdPrompt = true;
      await captureScreen(
        tester,
        await _app(tester, fx, theme: theme, locale: locale),
        '$_dir/lock_auto_reading_$tag',
        settle: const Duration(milliseconds: 1400),
      );
      expect(fx.bio.prompts, hasLength(1));
    });

    testWidgets('after a cancel: the large "Use fingerprint" button – $tag', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.fallback = BiometricOutcome.cancelled;
      await captureScreen(tester, await _app(tester, fx, theme: theme, locale: locale), '$_dir/lock_after_cancel_$tag');
      expect(fx.bio.prompts, hasLength(1));
    });

    testWidgets('after an error – $tag', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.fallback = BiometricOutcome.error;
      await captureScreen(tester, await _app(tester, fx, theme: theme, locale: locale), '$_dir/lock_after_error_$tag');
    });

    testWidgets('locked out: straight to the PIN – $tag', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.fallback = BiometricOutcome.lockedOut;
      await captureScreen(
        tester,
        await _app(tester, fx, theme: theme, locale: locale),
        '$_dir/lock_lockedout_pin_$tag',
      );
    });
  }
}
