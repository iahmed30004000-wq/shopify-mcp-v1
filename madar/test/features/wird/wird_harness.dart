// Test harness for the wird and Hifz screens: the real theme, localisations,
// digit scope, motion scope and celebration overlay (like AppFrame), over a
// seeded in-memory database, a silent sound engine, recording haptics, a
// frozen clock, the fake Quran catalog, a recording Quran player and a fake
// notification platform.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/wird/wird.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'fake_quran_catalog.dart';

/// Monday 28 Sep 2026, 17:10 in Amman (the Asr window).
final DateTime faithTestNow = DateTime(2026, 9, 28, 17, 10);

/// The bundled An-Nawawi's Forty, read straight from the asset file.
HadithCollection loadNawawi() => HadithCollection.fromJson(
  (jsonDecode(File(HadithCollection.nawawiAsset).readAsStringSync()) as Map).cast<String, Object?>(),
);

/// Records what was asked of the Quran player and echoes it as playback.
class FakeQuranAudio implements QuranAudio {
  final List<(AyahRange, int, int)> played = [];
  int stops = 0;
  final _controller = StreamController<QuranPlayback>.broadcast();
  QuranPlayback _value = QuranPlayback.idle;

  @override
  Stream<QuranPlayback> get playback => _controller.stream;

  @override
  QuranPlayback get value => _value;

  void _emit(QuranPlayback p) {
    _value = p;
    _controller.add(p);
  }

  @override
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange}) async {
    played.add((range, repeatAyah ?? 1, repeatRange ?? 1));
    _emit(QuranPlayback(current: range.first, range: range, playing: true, reciterId: 'husary'));
  }

  @override
  Future<void> pause() async => _emit(QuranPlayback(current: _value.current, range: _value.range));

  @override
  Future<void> resume() async => _emit(QuranPlayback(current: _value.current, range: _value.range, playing: true));

  @override
  Future<void> stop() async {
    stops++;
    _emit(QuranPlayback.idle);
  }
}

/// Everything a test needs after pumping.
class FaithTestEnv {
  FaithTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  final FakeQuranAudio audio = FakeQuranAudio();
  final List<WirdReadRequest> readRequests = [];
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

/// Builds the harness app around [home].
Future<(Widget, FaithTestEnv)> buildFaithApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  bool readNow = true,
  QuranCatalog? catalog,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? faithTestNow;
  final env = FaithTestEnv(db, haptics, sound);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      quranCatalogProvider.overrideWithValue(catalog ?? FakeQuranCatalog()),
      quranAudioProvider.overrideWithValue(env.audio),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      hadithCollectionProvider.overrideWith((ref) async => loadNawawi()),
      if (readNow) wirdReadNowProvider.overrideWithValue((context, request) => env.readRequests.add(request)),
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

/// [buildFaithApp] + pump on a phone-sized surface.
Future<FaithTestEnv> pumpFaithApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  bool readNow = true,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildFaithApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    readNow: readNow,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleFaith(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleFaith(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

// ------------------------------------------------------------ seed data ----

/// Adds a plan straight through the service (outside the widget tree).
Future<WirdPlan> seedPlan(MadarDatabase db, WirdDraft draft, {DateTime? now}) async {
  final service = WirdService(Repositories(db), clock: () => now ?? faithTestNow);
  final axis = QuranAxis.of(FakeQuranCatalog(), WirdUnit.pages);
  final (plan, _) = await service.create(draft, pagesAxis: axis);
  return plan;
}

/// Logs a reading session.
Future<void> seedSession(
  MadarDatabase db,
  DateTime day,
  AyahRange range, {
  String? planId,
  QuranSessionMode mode = QuranSessionMode.read,
  DateTime? at,
}) async {
  await Repositories(db).quranSessions.insert(
    QuranSessionsCompanion.insert(
      day: day,
      mode: Value(mode),
      fromSurah: range.first.surah,
      fromAyah: range.first.ayah,
      toSurah: range.last.surah,
      toAyah: range.last.ayah,
      planId: Value(planId),
      createdAt: Value(at ?? day.add(const Duration(hours: 6))),
    ),
  );
}

/// Reads [plan]'s portion on each of [days] (offsets from its start), by
/// replaying the engine day by day; [partialToday] reads that share of
/// today's portion.
Future<void> seedReading(
  MadarDatabase db,
  WirdPlan plan, {
  required Iterable<int> days,
  double? partialToday,
  DateTime? today,
}) async {
  final catalog = FakeQuranCatalog();
  final axis = QuranAxis.of(catalog, plan.unit);
  final sessions = <WirdSession>[];
  final end = today ?? CalendarDays.dateOnly(faithTestNow);
  for (final d in days) {
    final day = CalendarDays.add(plan.startDate, d);
    final s = WirdEngine.compute(plan: plan, sessions: sessions, axis: axis, today: day);
    final range = s.target.remaining;
    if (range == null) continue;
    await seedSession(db, day, range, planId: plan.id);
    sessions.add(
      WirdSession(id: 's$d', day: day, range: range, planId: plan.id, createdAt: day.add(const Duration(hours: 6))),
    );
  }
  if (partialToday != null) {
    final s = WirdEngine.compute(plan: plan, sessions: sessions, axis: axis, today: end);
    final range = s.target.remaining;
    if (range == null) return;
    final idx = axis.index;
    final a = idx.indexOf(range.first), b = idx.indexOf(range.last);
    final last = idx.refAt(a + ((b - a) * partialToday).round());
    await seedSession(db, end, AyahRange(range.first, last), planId: plan.id);
  }
}
