import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/sound/sound_api.dart';

/// Records haptics fired through [Fx].
class RecordingHapticsService implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Installs a silent, recording feedback service.
({SilentSoundService sound, RecordingHapticsService haptics}) installMotionFx() {
  final sound = SilentSoundService();
  final haptics = RecordingHapticsService();
  Fx.install(FeedbackService(sound, haptics));
  return (sound: sound, haptics: haptics);
}

/// A Madar-themed app with an explicit text direction and motion setting.
Widget motionApp(
  Widget home, {
  TextDirection direction = TextDirection.rtl,
  bool reduced = false,
  MadarThemeId theme = MadarThemeId.lapis,
  TransitionBuilder? builder,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMadarTheme(theme, arabic: direction == TextDirection.rtl),
    builder: (context, child) {
      Widget app = MotionScope(
        reduced: reduced,
        child: Directionality(textDirection: direction, child: child!),
      );
      if (builder != null) app = builder(context, app);
      return app;
    },
    home: home,
  );
}

/// Pumps [count] frames of [step].
Future<void> pumpFrames(WidgetTester tester, int count, [Duration step = const Duration(milliseconds: 16)]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}
