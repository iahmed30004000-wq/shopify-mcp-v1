// Builds the full Madar app for widget tests: the real MadarApp (router,
// themes, locale, AppFrame, AppGate, quick-add handler, adhan host, app
// lock) over a seeded in-memory database, mock SharedPreferences, a silent,
// recording sound engine and fakes of the platform services (notifications,
// the adhan's Android bridge, battery optimisation, adhan audio).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar/app/app.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records haptics fired through [Fx].
class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Handle on a running test app.
class TestApp {
  TestApp(this.tester, this._db, this.sound, this.haptics, this.notifications, this.adhanSystem);

  final WidgetTester tester;
  final MadarDatabase? _db;

  /// The in-memory database (only when pumped with `database: true`).
  MadarDatabase get db => _db!;
  final SilentSoundService sound;
  final RecordingHaptics haptics;

  /// The notifications plugin (fake): scheduled alarms, taps, the launch.
  final FakeNotificationPlatform notifications;

  /// The adhan's Android bridge (fake): lock-screen mode, keyguard.
  final FakeAdhanSystem adhanSystem;

  ProviderContainer get container => ProviderScope.containerOf(tester.element(find.byType(MadarApp)));

  AppSettings get settings => container.read(appSettingsProvider);

  Repositories get repos => container.read(repositoriesProvider);

  GoRouter get router => container.read(routerProvider);

  String get location => router.state.matchedLocation;

  /// Changes settings exactly like the settings screens do.
  void updateSettings(AppSettings Function(AppSettings s) change) =>
      unawaited(container.read(appSettingsProvider.notifier).update(change));
}

/// A fixed "now" for home tests: Sunday 27 Sep 2026, 13:10 (Dhuhr window
/// with the placeholder times).
final DateTime testNow = DateTime(2026, 9, 27, 13, 10);

/// Phone-sized test surface (logical 412×915).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A seeded in-memory database whose query streams close synchronously
/// (drift otherwise keeps a zero-length timer alive after the last listener,
/// which widget tests report as a pending timer).
MadarDatabase testDatabase({String languageCode = 'ar', bool seed = true}) => MadarDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  seed: seed ? SeedOptions(languageCode: languageCode) : null,
);

/// Opens (migrates and seeds) [testDatabase] outside the fake-async zone.
Future<MadarDatabase> openTestDatabase(WidgetTester tester, {String languageCode = 'ar', bool seed = true}) async {
  final db = testDatabase(languageCode: languageCode, seed: seed);
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  return db;
}

/// The pieces of a test app before it is pumped.
class TestAppSetup {
  TestAppSetup(this.app, this.db, this.sound, this.haptics, this.notifications, this.adhanSystem);

  /// `ProviderScope(overrides: …, child: MadarApp())`.
  final Widget app;
  final MadarDatabase? db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeNotificationPlatform notifications;
  final FakeAdhanSystem adhanSystem;
}

/// Fakes of the platform services every full-app test needs (the real
/// plugins have no platform side under flutter_tester): notifications
/// ([notifications], clocked at [clock]), the adhan's Android bridge,
/// battery optimisation (exempt) and adhan audio.
List<Override> platformFakeOverrides({
  required FakeNotificationPlatform notifications,
  required FakeAdhanSystem adhanSystem,
  required DateTime Function() clock,
}) => [
  notificationPlatformProvider.overrideWithValue(notifications),
  notificationServiceProvider.overrideWith((ref) {
    final service = NotificationService(notifications, clock: clock);
    ref.onDispose(service.dispose);
    return service;
  }),
  adhanSystemProvider.overrideWithValue(adhanSystem),
  batteryGateProvider.overrideWithValue(FakeBatteryGate(exempt: true)),
  adhanAudioProvider.overrideWithValue(FakeAdhanAudio()),
];

/// Builds (without pumping) the whole app: mock prefs holding [settings], a
/// seeded in-memory database (unless [database] is false – then
/// `databaseUnlockProvider` is left to [overrides], for gate tests), a
/// silent recording sound engine, the router at [initialLocation] and the
/// home clock frozen at [now] (defaults to [testNow]). [beforePump] may fill
/// the database first. [notifications] / [adhanSystem] replace the default
/// platform fakes (e.g. a launch notification); [clock] replaces the frozen
/// [now] with a moving one.
Future<TestAppSetup> buildMadarTestApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboarded: true),
  String initialLocation = '/',
  DateTime? now,
  bool database = true,
  bool seed = true,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
  FakeNotificationPlatform? notifications,
  FakeAdhanSystem? adhanSystem,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = database ? await openTestDatabase(tester, languageCode: settings.languageCode, seed: seed) : null;
  if (db != null && beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  final fixed = now ?? testNow;
  final DateTime Function() wall = clock ?? () => fixed;
  final platform = notifications ?? FakeNotificationPlatform();
  final system = adhanSystem ?? FakeAdhanSystem(directory: '${Directory.systemTemp.path}/madar_app_test_sounds');

  // Persist the requested settings before the app reads them.
  final probe = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  await tester.runAsync(() => probe.read(appSettingsProvider.notifier).update((_) => settings));
  probe.dispose();

  final app = ProviderScope(
    overrides: [
      ...madarAppOverrides(prefs: prefs, sound: sound, haptics: haptics),
      if (db != null) databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)),
      routerInitialLocationProvider.overrideWithValue(initialLocation),
      homeClockProvider.overrideWithValue(wall),
      ...platformFakeOverrides(notifications: platform, adhanSystem: system, clock: wall),
      ...overrides,
    ],
    child: const MadarApp(),
  );
  return TestAppSetup(app, db, sound, haptics, platform, system);
}

/// [buildMadarTestApp] + pump (+ settle) on a phone-sized surface.
Future<TestApp> pumpMadarApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboarded: true),
  String initialLocation = '/',
  DateTime? now,
  bool database = true,
  bool seed = true,
  bool phone = true,
  bool settle = true,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
  FakeNotificationPlatform? notifications,
  FakeAdhanSystem? adhanSystem,
  DateTime Function()? clock,
}) async {
  if (phone) usePhoneSurface(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: settings,
    initialLocation: initialLocation,
    now: now,
    database: database,
    seed: seed,
    overrides: overrides,
    beforePump: beforePump,
    notifications: notifications,
    adhanSystem: adhanSystem,
    clock: clock,
  );
  await tester.pumpWidget(setup.app);
  if (settle) await settleApp(tester);
  return TestApp(tester, setup.db, setup.sound, setup.haptics, setup.notifications, setup.adhanSystem);
}

/// Lets database work (microtasks) and finite animations finish.
Future<void> settleApp(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
