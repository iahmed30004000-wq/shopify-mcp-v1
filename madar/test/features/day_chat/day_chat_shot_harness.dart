// Harness for the daily chat's screenshots: the real screen with the real
// fonts and shaders, over an in-memory database holding a made-up day.
//
// Nothing here is real data of his – the app ships none.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/day_chat/day_chat.dart';
import 'package:madar/features/home/domain/prayer_day.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'day_chat_app.dart' show dayChatNow, dayChatToday, seedDayChat;

/// What a shot's day holds.
enum DayChatShot {
  /// A fresh install: nothing typed yet.
  empty,

  /// His five-fact line, nothing decided.
  day,

  /// The five facts with the money one filed and the prayer one refused.
  decided,

  /// A line with a gap, a sentence it could not read, and a bare number.
  awkward,
}

/// Reads [lines] into the chat and remembers them, the way sending them
/// does – and decides nothing.
Future<DayChatService> _chat(MadarDatabase db, {List<String> lines = const []}) async {
  final repos = Repositories(db);
  final service = DayChatService(
    repos,
    clock: () => dayChatNow,
    prayerDay: () => PrayerDayTimes.placeholder,
    focusedWindow: () => PrayerWindow.isha,
    defaultWalletName: () => 'المحفظة',
  );
  for (final line in lines) {
    await service.remember(await service.read(line, day: dayChatToday));
  }
  return service;
}

Future<void> seedDayChatShot(MadarDatabase db, DayChatShot shot) async {
  if (shot == DayChatShot.empty) return;
  await seedDayChat(db);
  switch (shot) {
    case DayChatShot.empty:
      return;
    case DayChatShot.day:
      await _chat(db, lines: const [
        'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، شربت كاسة مي',
      ]);
    case DayChatShot.decided:
      final service = await _chat(db, lines: const [
        'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، شربت كاسة مي',
      ]);
      final reading = await service.read(
        'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، شربت كاسة مي',
        day: dayChatToday,
      );
      await service.apply(reading.pieces.first, day: dayChatToday);
      await service.reject(reading.pieces[1], day: dayChatToday);
      await service.apply(reading.pieces.last, day: dayChatToday);
    case DayChatShot.awkward:
      await _chat(db, lines: const ['صرفت على القهوة', 'غسلت السيارة', 'وزني ٨٢']);
  }
}

/// The chat screen in [theme] and [locale], over the day [shot] describes.
Future<(Widget, MadarDatabase)> buildDayChatShot(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DayChatShot shot = DayChatShot.day,
  double textScale = 1,
  bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  await tester.runAsync(() => seedDayChatShot(db, shot));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => dayChatNow),
      appSettingsProvider.overrideWith(() => FixedDayChatSettings(AppSettings(languageCode: locale.languageCode))),
      ...overrides,
    ],
    child: MaterialApp(
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
    ),
  );
  return (app, db);
}

class FixedDayChatSettings extends AppSettingsController {
  FixedDayChatSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}
