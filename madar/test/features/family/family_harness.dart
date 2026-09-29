// Builds Family screens for widget and screenshot tests: an in-memory
// database, fixed clock, silent recording sound + haptics, fake
// notifications and a recording dialer.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/family/family.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'family_seed.dart';

class FamilyTestEnv {
  FamilyTestEnv(this.db, this.sound, this.haptics);

  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final RecordingContactLauncher launcher = RecordingContactLauncher();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, FamilyTestEnv)> buildFamilyApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  // The app's language follows the test locale (notification texts too).
  SharedPreferences.setMockInitialValues({
    'madar.settings.v1': jsonEncode(AppSettings(languageCode: locale.languageCode, onboarded: true).toJson()),
  });
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode, seed: false);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? familyTestNow;
  final env = FamilyTestEnv(db, sound, haptics);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      // The notification service drops requests in its past: give it the
      // test clock, not the wall clock (else the plan depends on when the
      // test runs).
      notificationServiceProvider.overrideWith((ref) {
        final service = NotificationService(env.notifications, clock: () => clock);
        ref.onDispose(service.dispose);
        return service;
      }),
      familyContactLauncherProvider.overrideWithValue(env.launcher),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        env.container = ProviderScope.containerOf(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(theme, arabic: arabic),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(
              reduced: reducedMotion,
              child: CelebrationOverlay(child: child!),
            ),
          ),
          home: home,
        );
      },
    ),
  );
  return (app, env);
}

/// [buildFamilyApp] + pump on a phone-sized surface.
Future<FamilyTestEnv> pumpFamilyApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildFamilyApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleFamily(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleFamily(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}
