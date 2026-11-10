// Test harness for the Quran screens: the real theme, localisations, digit
// scope, motion scope and celebration overlay (like AppFrame), over a seeded
// in-memory database, a silent recording sound engine, recording haptics, a
// frozen clock, the bundled Quran data read from disk, a scripted recitation
// player, recorded Quran.com answers and a recording share service.
import 'dart:async';
import 'dart:io';

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
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/quran/data/quran_com_client.dart';
import 'package:madar/features/quran/data/quran_providers.dart';
import 'package:madar/features/quran/data/quran_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'quran_test_data.dart';

/// Monday 28 Sep 2026, 20:10 in Amman (after Isha).
final DateTime quranTestNow = DateTime(2026, 9, 28, 20, 10);

/// A recitation player the test drives: records what was asked and emits
/// the ayah "being recited".
class FakeQuranAudio implements QuranAudio {
  final List<(AyahRange, int, int)> played = [];
  final StreamController<QuranPlayback> _c = StreamController.broadcast();
  QuranPlayback _value = QuranPlayback.idle;

  void recite(AyahRef ayah, {AyahRange? range, bool basmala = false}) {
    _value = QuranPlayback(
      current: ayah,
      range: range ?? AyahRange.single(ayah),
      playing: true,
      reciterId: 'test',
      basmala: basmala,
    );
    _c.add(_value);
  }

  @override
  Stream<QuranPlayback> get playback => _c.stream;

  @override
  QuranPlayback get value => _value;

  @override
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange}) async {
    played.add((range, repeatAyah ?? 1, repeatRange ?? 1));
    recite(range.first, range: range);
  }

  @override
  Future<void> pause() async {
    _value = QuranPlayback(current: _value.current, range: _value.range, reciterId: _value.reciterId);
    _c.add(_value);
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    _value = QuranPlayback.idle;
    _c.add(_value);
  }
}

/// Answers Quran.com requests from test/features/quran/fixtures.
class FixtureQuranHttp implements QuranHttp {
  final List<Uri> requests = [];
  bool offline = false;

  static String fixtureText(String name) => File('test/features/quran/fixtures/$name').readAsStringSync();

  static String _fixture(String name) => fixtureText(name);

  @override
  Future<(int, String)> get(Uri uri) async {
    requests.add(uri);
    if (offline) throw const QuranComException(QuranComProblem.offline);
    final u = uri.toString();
    if (u.contains('uthmani_tajweed?chapter_number=1')) return (200, _fixture('qurancom_tajweed_chapter_1.json'));
    if (u.contains('translations/20?chapter_number=1')) return (200, _fixture('qurancom_translation_20_chapter_1.json'));
    return (404, '{}');
  }
}

/// Everything a test needs after pumping.
class QuranTestEnv {
  QuranTestEnv(this.db, this.sound, this.haptics);

  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeQuranAudio audio = FakeQuranAudio();
  final FixtureQuranHttp http = FixtureQuranHttp();
  final MemoryQuranCacheStore cache = MemoryQuranCacheStore();
  final RecordingQuranShareService share = RecordingQuranShareService();
  late ProviderContainer container;
}

/// Builds the harness app around [home].
Future<(Widget, QuranTestEnv)> buildQuranApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  DateTime Function()? clock,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
  void Function(QuranTestEnv env)? setup,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = QuranTestEnv(db, sound, haptics);
  setup?.call(env);
  final fixed = now ?? quranTestNow;
  final wall = clock ?? () => fixed;
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(wall),
      quranStoreProvider.overrideWithValue(QuranTestData.store()),
      quranAudioProvider.overrideWithValue(env.audio),
      quranHttpProvider.overrideWithValue(env.http),
      quranCacheStoreProvider.overrideWithValue(env.cache),
      quranShareServiceProvider.overrideWithValue(env.share),
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

/// [buildQuranApp] + pump on a phone-sized surface.
Future<QuranTestEnv> pumpQuranApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  DateTime Function()? clock,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
  void Function(QuranTestEnv env)? setup,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildQuranApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    clock: clock,
    reducedMotion: reducedMotion,
    overrides: overrides,
    beforePump: beforePump,
    setup: setup,
  );
  await tester.pumpWidget(app);
  await settleQuran(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleQuran(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}
