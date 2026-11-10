import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/sound/sound_api.dart';

/// Records haptics fired through [Fx].
class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Installs a silent, recording feedback service and returns it.
({SilentSoundService sound, RecordingHaptics haptics}) installRecordingFx() {
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  return (sound: sound, haptics: haptics);
}

/// Pumps [child] inside a Madar-themed, localised app.
Future<void> pumpMadar(
  WidgetTester tester,
  Widget child, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  TextDirection? direction,
  bool reducedMotion = false,
  bool scaffold = true,
}) async {
  final arabic = locale.languageCode == 'ar';
  Widget home = scaffold ? Scaffold(body: Center(child: child)) : child;
  if (direction != null) home = Directionality(textDirection: direction, child: home);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, app) => MotionScope(reduced: reducedMotion, child: app!),
      home: home,
    ),
  );
}
