// Test harness for the medical record: the real theme, localisations, digit
// scope, motion scope and celebration overlay over an in-memory database,
// silent sound, recording haptics, a frozen clock, a fake notification
// platform, a recording reminder scheduler and report exporter, and fonts
// read from the file system.
import 'dart:io';
import 'dart:typed_data';

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
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';
import 'record_seed.dart';

ReportFontLoader fileFontLoader() =>
    ReportFontLoader(read: (path) async => ByteData.sublistView(File(path).readAsBytesSync()));

/// What a test needs after pumping.
class RecordTestEnv {
  RecordTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final RecordingAppointmentReminderScheduler reminders = RecordingAppointmentReminderScheduler();
  final RecordingReportExporter exporter = RecordingReportExporter();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, RecordTestEnv)> buildRecordApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  bool seed = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  final arabic = locale.languageCode == 'ar';
  final clock = now ?? recordTestNow;
  if (seed) await tester.runAsync(() => seedRecord(db, arabic: arabic, now: clock));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = RecordTestEnv(db, haptics, sound);
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      recordReminderSchedulerProvider.overrideWithValue(env.reminders),
      reportExporterProvider.overrideWithValue(env.exporter),
      reportFontLoaderProvider.overrideWithValue(fileFontLoader()),
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

/// [buildRecordApp] + pump on a phone-sized surface.
Future<RecordTestEnv> pumpRecordApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool seed = false,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildRecordApp(
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
  await settleRecord(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleRecord(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}
