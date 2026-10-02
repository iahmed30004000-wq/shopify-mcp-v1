// Test harness for the data centre: the real theme, localisations, digit
// and motion scopes over an in-memory database, a silent sound engine,
// recording haptics, a recording file bridge (share / save / pick / copy),
// cheap key derivation and a temporary safety-copy folder. Self-contained
// (does not build the whole app or its router).
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_fixtures.dart';

class DataHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

const fastTestKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const fastTestCodec = MadarBackupCodec(kdf: fastTestKdf, useIsolate: false);

class DataTestEnv {
  DataTestEnv(this.db, this.bridge, this.haptics, this.sound, this.safetyDir);

  final MadarDatabase db;
  final RecordingDataFileBridge bridge;
  final DataHaptics haptics;
  final SilentSoundService sound;
  final Directory safetyDir;
}

/// An in-memory database whose streams close synchronously.
MadarDatabase dataTestDatabase() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Future<(Widget, DataTestEnv)> buildDataApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('en'),
  bool reducedMotion = false,
  Future<void> Function(MadarDatabase db)? beforePump,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = dataTestDatabase();
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final safetyDir = (await tester.runAsync(() => Directory.systemTemp.createTemp('madar_data_test_')))!;
  addTearDown(() => tester.runAsync(() => safetyDir.delete(recursive: true)));
  final sound = SilentSoundService();
  final haptics = DataHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final bridge = RecordingDataFileBridge();
  final env = DataTestEnv(db, bridge, haptics, sound, safetyDir);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      dataFileBridgeProvider.overrideWithValue(bridge),
      backupCodecProvider.overrideWithValue(fastTestCodec),
      safetyCopiesDirectoryProvider.overrideWithValue(() async => safetyDir),
      dataClockProvider.overrideWithValue(() => dataTestNow),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: DigitStyle.auto,
        child: MotionScope(reduced: reducedMotion, child: CelebrationOverlay(child: child!)),
      ),
      home: home,
    ),
  );
  return (app, env);
}

/// Lets real asynchronous work (file IO, database) progress between frames.
Future<void> settleAsync(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [n] 50 ms frames.
Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Phone-sized surface.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
