// Builds the prayer screens over the real providers: an in-memory database
// (prayer settings in KeyValues), mock prefs, the real city list, fake
// location / time-zone sources, a frozen clock and a recording Fx.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart' show sharedPreferencesProvider;
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart' show homeClockProvider;
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import 'fakes.dart';

/// Monday 28 Sep 2026, 14:10 in Amman (the Dhuhr window; Asr ≈ 15:53).
final prayerTestNow = DateTime.utc(2026, 9, 28, 11, 10).toLocal();

/// Amman with its own zone, so the times read the same on any machine.
const prayerTestSettings = PrayerSettings(
  timeZone: 'Asia/Amman',
  cityId: 'jo-amman',
  cityNameAr: 'عمّان',
  cityNameEn: 'Amman',
  countryCode: 'JO',
  locationSource: PrayerLocationSource.city,
);

class PrayerTestSetup {
  PrayerTestSetup(this.app, this.db, this.sound, this.haptics, this.location);

  final Widget app;
  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeLocationSource location;
}

/// [home] inside the app's theme / localisations with the prayer providers
/// wired to test doubles.
Future<PrayerTestSetup> buildPrayerTestApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  PrayerSettings settings = prayerTestSettings,
  FakeLocationSource? location,
  List<Override> overrides = const [],
}) async {
  MadarTimeZones.ensure();
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  await tester.runAsync(() => Repositories(db).keyValues.set(OrbitRepository.prayerSettingsKv, settings));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  addTearDown(() => Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics())));
  final cities = loadTestCities();
  final loc = location ?? FakeLocationSource();
  final clock = now ?? prayerTestNow;
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      homeClockProvider.overrideWithValue(() => clock),
      cityDatabaseProvider.overrideWith((ref) async => cities),
      locationSourceProvider.overrideWithValue(loc),
      deviceTimeZoneProvider.overrideWithValue(FakeDeviceTimeZone('Asia/Amman')),
      ...overrides,
    ],
    child: madarScreenshotApp(home: home, theme: theme, locale: locale),
  );
  return PrayerTestSetup(app, db, sound, haptics, loc);
}

/// Pumps until the database streams and entrance animations have settled.
Future<void> settlePrayer(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
