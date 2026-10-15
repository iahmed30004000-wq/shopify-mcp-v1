import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/sound/sound_api.dart';

/// Records haptics fired through [Fx].
class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Installs a silent feedback service that records every [Sfx] played.
({SilentSoundService sound, RecordingHaptics haptics}) installInteractionFx() {
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  return (sound: sound, haptics: haptics);
}

/// A Madar-themed, localised app for interaction tests.
Widget interactionApp(
  Widget home, {
  Locale locale = const Locale('ar'),
  bool reduced = false,
  MadarThemeId theme = MadarThemeId.lapis,
  bool scaffold = true,
  List<Override> overrides = const [],
  DigitStyle digits = DigitStyle.auto,
}) {
  final arabic = locale.languageCode == 'ar';
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: digits,
        child: MotionScope(reduced: reduced, child: child!),
      ),
      home: scaffold ? Scaffold(body: home) : home,
    ),
  );
}

/// Pumps [count] frames of [step].
Future<void> pumpFrames(WidgetTester tester, int count, [Duration step = const Duration(milliseconds: 16)]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// Phone-sized test surface (logical 412×915).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
