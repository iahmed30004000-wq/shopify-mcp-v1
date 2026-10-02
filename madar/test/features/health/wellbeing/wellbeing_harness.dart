// Test harness for wellbeing: the real theme, localisations, digit scope,
// motion scope and celebration overlay over an in-memory seeded database,
// silent sound, recording haptics, a frozen clock, a fake notification
// platform, a recording worry-reminder scheduler and a recording dialer.
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
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';
import 'wellbeing_seed.dart';

/// Tuesday 29 Sep 2026, 20:15.
final DateTime wellbeingTestNow = DateTime(2026, 9, 29, 20, 15);

class WellbeingTestEnv {
  WellbeingTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final RecordingWorryReminderScheduler reminders = RecordingWorryReminderScheduler();
  final RecordingPhoneDialer dialer = RecordingPhoneDialer();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, WellbeingTestEnv)> buildWellbeingApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  WellbeingSeed? seed,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  final clock = now ?? wellbeingTestNow;
  if (seed != null) await tester.runAsync(() => seedWellbeing(db, seed, now: clock));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = WellbeingTestEnv(db, haptics, sound);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      worryReminderSchedulerProvider.overrideWithValue(env.reminders),
      phoneDialerProvider.overrideWithValue(env.dialer),
      appSettingsProvider.overrideWith(() => _FixedSettings(AppSettings(languageCode: locale.languageCode))),
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

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

/// [buildWellbeingApp] + pump on a phone-sized surface.
Future<WellbeingTestEnv> pumpWellbeingApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  WellbeingSeed? seed,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildWellbeingApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    seed: seed,
    reducedMotion: reducedMotion,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleWellbeing(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleWellbeing(WidgetTester tester, {bool andSettle = true}) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (andSettle) await tester.pumpAndSettle();
}

/// Runs real async work (database writes) from a test.
Future<T> dbWork<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  await settleWellbeing(tester);
  return result as T;
}
