// Test harness for the adhkar screens: the real theme, localisations,
// digit scope, motion scope and celebration overlay (like AppFrame), over a
// seeded in-memory database, a silent recording sound engine, recording
// haptics, a frozen clock and an in-memory recording store.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhkar/data/adhkar_providers.dart';
import 'package:madar/features/adhkar/data/dhikr_audio.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/adhkar/domain/audio_probe.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Monday 28 Sep 2026, 17:10 in Amman (Asr window: evening adhkar).
final DateTime adhkarTestNow = DateTime(2026, 9, 28, 17, 10);

/// The bundled library, read straight from the asset file (synchronous, so
/// it works inside fake-async widget tests).
AdhkarLibrary loadBundledLibrary() =>
    AdhkarLibrary.fromJson(jsonDecode(File('assets/adhkar/hisn_al_muslim.json').readAsStringSync()));

/// In-memory [DhikrAudioStore].
class MemoryDhikrAudioStore implements DhikrAudioStore {
  final Map<String, DhikrAudioInfo> _meta = {};
  final Map<String, Uint8List> _bytes = {};
  final _changes = StreamController<Map<String, DhikrAudioInfo>>.broadcast();

  void _emit() => _changes.add(Map.of(_meta));

  @override
  Stream<Map<String, DhikrAudioInfo>> watch() async* {
    yield Map.of(_meta);
    yield* _changes.stream;
  }

  @override
  Future<Map<String, DhikrAudioInfo>> all() async => Map.of(_meta);

  @override
  Future<DhikrAudioInfo> attach(String dhikrId, PickedAudio audio) async {
    if (audio.bytes.length > DhikrAudioStore.maxBytes) throw const DhikrAudioException(DhikrAudioProblem.tooLarge);
    final format = AudioProbe.sniff(audio.bytes);
    if (format == null) throw const DhikrAudioException(DhikrAudioProblem.unsupported);
    final info = DhikrAudioInfo(
      dhikrId: dhikrId,
      storedName: '$dhikrId.${format.extension}',
      originalName: audio.name,
      bytes: audio.bytes.length,
      duration: AudioProbe.duration(audio.bytes),
      addedAt: DateTime(2026, 9, 28),
    );
    _meta[dhikrId] = info;
    _bytes[dhikrId] = audio.bytes;
    _emit();
    return info;
  }

  @override
  Future<Uint8List?> read(String dhikrId) async => _bytes[dhikrId];

  @override
  Future<Future<void> Function()?> remove(String dhikrId) async {
    final info = _meta.remove(dhikrId);
    final bytes = _bytes.remove(dhikrId);
    if (info == null) return null;
    _emit();
    return () async {
      _meta[dhikrId] = info;
      if (bytes != null) _bytes[dhikrId] = bytes;
      _emit();
    };
  }
}

/// Records what the reader asked to play.
class FakeDhikrAudioPlayer implements DhikrAudioPlayer {
  final List<String> played = [];
  int stops = 0;
  bool available = true;

  @override
  Future<bool> play(String dhikrId, Uint8List bytes) async {
    if (!available) return false;
    played.add(dhikrId);
    return true;
  }

  @override
  void stop() => stops++;

  @override
  Future<void> dispose() async {}
}

/// A tiny valid WAV (0.5 s of silence at 8 kHz, 8-bit mono).
Uint8List silentWav({int samples = 4000}) {
  final b = BytesBuilder();
  void u32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
  b.add(ascii.encode('RIFF'));
  u32(36 + samples);
  b.add(ascii.encode('WAVEfmt '));
  u32(16);
  u16(1);
  u16(1);
  u32(8000);
  u32(8000);
  u16(1);
  u16(8);
  b.add(ascii.encode('data'));
  u32(samples);
  b.add(List.filled(samples, 128));
  return b.toBytes();
}

/// Everything a test needs after pumping.
class AdhkarTestEnv {
  AdhkarTestEnv(this.db, this.sound, this.haptics, this.audioStore, this.player);

  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final MemoryDhikrAudioStore audioStore;
  final FakeDhikrAudioPlayer player;

  /// The reminders land here (the real scheduler over a fake platform).
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  late ProviderContainer container;
}

/// Builds the harness app around [home].
Future<(Widget, AdhkarTestEnv)> buildAdhkarApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  PrayerWindow window = PrayerWindow.asr,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  final audioStore = MemoryDhikrAudioStore();
  final player = FakeDhikrAudioPlayer();
  Fx.install(FeedbackService(sound, haptics));
  final library = loadBundledLibrary();
  final clock = now ?? adhkarTestNow;
  final env = AdhkarTestEnv(db, sound, haptics, audioStore, player);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      adhkarLibraryProvider.overrideWith((ref) async => library),
      // Pinned so tests do not depend on the host's time zone.
      adhkarWindowProvider.overrideWithValue(window),
      dhikrAudioStoreProvider.overrideWithValue(audioStore),
      dhikrAudioPlayerProvider.overrideWithValue(player),
      notificationPlatformProvider.overrideWithValue(env.notifications),
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

/// [buildAdhkarApp] + pump on a phone-sized surface.
Future<AdhkarTestEnv> pumpAdhkarApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  PrayerWindow window = PrayerWindow.asr,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildAdhkarApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    window: window,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleAdhkar(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleAdhkar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}
