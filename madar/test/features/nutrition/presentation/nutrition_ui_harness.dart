// Test harness for the food screens: the real theme, localisations, digit
// scope, motion scope and celebration overlay over an in-memory database,
// silent sound, recording haptics, a frozen clock, a fake notification
// platform, a recording meal-reminder scheduler and a recording navigator
// (the screens open one another through `nutritionNavigatorProvider`).
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
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:madar/features/nutrition/presentation/nutrition_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';
import 'nutrition_ui_seed.dart';

/// Tuesday 29 Sep 2026, 14:20 – after a planned lunch, before dinner.
final DateTime nutritionTestNow = DateTime(2026, 9, 29, 14, 20);

class NutritionTestEnv {
  NutritionTestEnv(this.db, this.haptics, this.sound, this.now);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final DateTime now;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final RecordingMealReminderScheduler reminders = RecordingMealReminderScheduler();

  /// Where the screens were asked to navigate, in order.
  final List<NutritionDestination> went = [];
  late ProviderContainer container;

  Repositories get repos => Repositories(db);

  NutritionService service({DateTime? clock}) => NutritionService(repos, clock: () => clock ?? now);
}

Future<(Widget, NutritionTestEnv)> buildNutritionApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  double textScale = 1,
  NutritionSeed? seed,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  final clock = now ?? nutritionTestNow;
  if (seed != null) {
    await tester.runAsync(() => seedNutrition(db, seed, now: clock, arabic: locale.languageCode == 'ar'));
  }
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = NutritionTestEnv(db, haptics, sound, clock);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      notificationServiceProvider.overrideWith((ref) {
        final service = NotificationService(env.notifications, clock: () => clock);
        ref.onDispose(service.dispose);
        return service;
      }),
      nutritionReminderSchedulerProvider.overrideWithValue(env.reminders),
      // Plain activity rows: no orbit pulse hub in a screen test.
      nutritionActivityRecorderProvider.overrideWithValue(null),
      nutritionNavigatorProvider.overrideWithValue((context, to) => env.went.add(to)),
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
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: MadarFormatScope(
              digits: DigitStyle.auto,
              child: MotionScope(
                reduced: reducedMotion,
                child: CelebrationOverlay(child: child!),
              ),
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

/// [buildNutritionApp] + pump on a phone-sized surface.
Future<NutritionTestEnv> pumpNutritionApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  NutritionSeed? seed,
  bool reducedMotion = false,
  double textScale = 1,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildNutritionApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    seed: seed,
    reducedMotion: reducedMotion,
    textScale: textScale,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleNutrition(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and the entrance, sheet and
/// spring animations finish.
///
/// Deliberately **not** `pumpAndSettle`: the empty states' illustrations and
/// the glass sheen loop for ever, and an undo toast counts down for five
/// seconds – settling would either hang or eat the toast.
Future<void> settleNutrition(WidgetTester tester, {int frames = 16}) =>
    nutritionFrames(tester, n: frames, step: const Duration(milliseconds: 60));

/// Pumps [n] frames of [step], letting database work in between – the way
/// to drive the screens when an undo toast must stay on screen (its
/// countdown would be consumed by `pumpAndSettle`).
Future<void> nutritionFrames(WidgetTester tester, {int n = 10, Duration step = const Duration(milliseconds: 60)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

/// Lets the undo toasts count down and leave (a test must not end with one
/// still on screen – its timer would be pending).
Future<void> expireNutritionToasts(WidgetTester tester) =>
    nutritionFrames(tester, n: 8, step: const Duration(seconds: 1));

/// Scrolls [finder] into view inside the nearest scroll view, then settles.
Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await nutritionFrames(tester, n: 8, step: const Duration(milliseconds: 40));
}

/// Runs real async work (database writes) from a test.
Future<T> nutritionWork<T>(WidgetTester tester, Future<T> Function() work) async {
  final result = await tester.runAsync(work);
  await settleNutrition(tester);
  return result as T;
}
