// Builds adhan screens for widget and screenshot tests: the real providers
// over a seeded in-memory database (Amman, Jordanian preset, Asia/Amman
// zone), a fake notifications plugin, fake Android bridge, silent audio and
// a frozen clock.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';

/// Amman with its own zone, so times read the same on any host.
const ammanPrayerSettings = PrayerSettings(timeZone: 'Asia/Amman', cityNameAr: 'عمّان', cityNameEn: 'Amman');

class AdhanHarness {
  AdhanHarness({
    required this.db,
    required this.platform,
    required this.system,
    required this.audio,
    required this.sound,
    required this.battery,
  });

  final MadarDatabase db;
  final FakeNotificationPlatform platform;
  final FakeAdhanSystem system;
  final FakeAdhanAudio audio;
  final SilentSoundService sound;
  final FakeBatteryGate battery;
  final RecordingHaptics haptics = RecordingHaptics();
  final List<(DateTime, Prayer)> prayed = [];
  late Widget app;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<AdhanHarness> buildAdhanTestApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  String language = 'ar',
  required DateTime now,
  DateTime Function()? clock,
  AdhanSettings settings = const AdhanSettings(),
  FakeNotificationPlatform? platform,
  FakeAdhanSystem? system,
  FakeBatteryGate? battery,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final probe = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  await tester.runAsync(
    () => probe
        .read(appSettingsProvider.notifier)
        .update((_) => AppSettings(onboarded: true, languageCode: language, themeId: theme)),
  );
  probe.dispose();

  final db = await openTestDatabase(tester, languageCode: language);
  await tester.runAsync(() async {
    final repos = Repositories(db);
    await OrbitRepository(repos).setPrayerSettings(ammanPrayerSettings);
    await AdhanSettingsRepository(repos.keyValues).save(settings);
  });
  final h = AdhanHarness(
    db: db,
    platform: platform ?? FakeNotificationPlatform(),
    system: system ?? FakeAdhanSystem(directory: '${Directory.systemTemp.path}/madar_adhan_test_sounds'),
    audio: FakeAdhanAudio(),
    sound: SilentSoundService(),
    battery: battery ?? FakeBatteryGate(exempt: true),
  );
  Fx.install(FeedbackService(h.sound, h.haptics));
  h.app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      soundServiceProvider.overrideWithValue(h.sound),
      hapticsServiceProvider.overrideWithValue(h.haptics),
      homeClockProvider.overrideWithValue(clock ?? () => now),
      notificationPlatformProvider.overrideWithValue(h.platform),
      notificationServiceProvider.overrideWithValue(NotificationService(h.platform, clock: clock ?? () => now)),
      adhanSystemProvider.overrideWithValue(h.system),
      batteryGateProvider.overrideWithValue(h.battery),
      adhanAudioProvider.overrideWithValue(h.audio),
      adhanMarkPrayedProvider.overrideWithValue((day, prayer) async => h.prayed.add((day, prayer))),
      ...overrides,
    ],
    child: madarScreenshotApp(home: home, theme: theme, locale: Locale(language)),
  );
  return h;
}

/// An adhan event of [slot] on 28 Sep 2026 in Amman.
AdhanEvent adhanEventFor(
  AdhanSlot slot, {
  AdhanKind kind = AdhanKind.adhan,
  required DateTime prayerAt,
  DateTime? firedAt,
  AdhanSoundRef? sound = const AdhanSoundRef.tone(TanbihTone.brass),
  int minutesBefore = 0,
  String? actionId,
}) => AdhanEvent(
  kind: kind,
  slot: slot,
  prayerAt: prayerAt,
  firedAt: firedAt ?? prayerAt,
  day: DateTime.utc(prayerAt.year, prayerAt.month, prayerAt.day),
  notificationId: 100003,
  sound: sound,
  minutesBefore: minutesBefore,
  actionId: actionId,
);
