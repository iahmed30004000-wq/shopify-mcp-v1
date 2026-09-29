// Builds recitation screens for widget and screenshot tests: the real
// providers over a seeded in-memory database, a scripted audio engine, fake
// audio focus / media session / HTTP / Wi-Fi, downloads in a temp folder
// and a fake Quran catalog.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/recitation/recitation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import 'recitation_fakes.dart';

class RecitationHarness {
  RecitationHarness({required this.db, required this.root}) {
    downloadManager = RecitationDownloads(
      storage: RecitationStorage.at(root),
      transport: transport,
      network: network,
      wifiOnly: () => true,
      retryDelay: Duration.zero,
    );
  }

  final MadarDatabase db;
  final Directory root;
  late final RecitationDownloads downloadManager;
  final FakeEngine engine = FakeEngine();
  final FakeFocus focus = FakeFocus();
  final FakeMediaSession media = FakeMediaSession();
  final FakeTransport transport = FakeTransport(fileSize: 2000, chunk: 500);
  final FixedNetworkProbe network = FixedNetworkProbe(wifi: true);
  final SilentSoundService sound = SilentSoundService();
  final RecordingHaptics haptics = RecordingHaptics();
  late Widget app;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  RecitationPlayer player(WidgetTester tester) => container(tester).read(recitationPlayerProvider);

  /// Creates downloaded files of [reciter] (sparse, [ayahBytes] each) for
  /// [surahs]; [partial] surah → number of its first ayat present.
  void seedDownloads(
    Reciter reciter, {
    List<int> surahs = const [],
    Map<int, int> partial = const {},
    int ayahBytes = 180000,
  }) {
    final dir = Directory('${root.path}/${reciter.folder}')..createSync(recursive: true);
    void file(String name) {
      final raf = File('${dir.path}/$name').openSync(mode: FileMode.write);
      raf.truncateSync(ayahBytes);
      raf.closeSync();
    }

    for (final s in surahs) {
      for (var a = 1; a <= SurahMath.ayahCount(s); a++) {
        file('${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3');
      }
    }
    for (final e in partial.entries) {
      for (var a = 1; a <= e.value; a++) {
        file('${e.key.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3');
      }
    }
    if ([...surahs, ...partial.keys].any(EveryAyah.surahNeedsBasmala)) file('basmala.mp3');
  }
}

Future<RecitationHarness> buildRecitationTestApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  String language = 'ar',
  RecitationSettings settings = const RecitationSettings(),
  bool background = true,
  QuranCatalog? catalog,
  List<Override> overrides = const [],
  void Function(RecitationHarness h)? seed,
  Future<void> Function(RecitationHarness h)? afterLoad,
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
  await tester.runAsync(() => RecitationSettingsRepository(Repositories(db).keyValues).save(settings));
  final root = Directory.systemTemp.createTempSync('madar_recitation_ui_');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  final h = RecitationHarness(db: db, root: root);
  seed?.call(h);
  // File IO has to run outside the fake-async zone of widget tests.
  await tester.runAsync(() async {
    await h.downloadManager.load();
    await afterLoad?.call(h);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  addTearDown(h.downloadManager.dispose);
  Fx.install(FeedbackService(h.sound, h.haptics));
  h.app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      soundServiceProvider.overrideWithValue(h.sound),
      hapticsServiceProvider.overrideWithValue(h.haptics),
      recitationEngineFactoryProvider.overrideWithValue(() => h.engine),
      recitationAudioFocusProvider.overrideWithValue(h.focus),
      recitationBackgroundProvider.overrideWithValue(
        background ? FakeBackground(h.media) : const NoRecitationBackground(),
      ),
      recitationStorageProvider.overrideWithValue(RecitationStorage.at(root)),
      recitationTransportProvider.overrideWithValue(h.transport),
      recitationNetworkProbeProvider.overrideWithValue(h.network),
      recitationDownloadsProvider.overrideWithValue(h.downloadManager),
      recitationClockProvider.overrideWithValue(() => DateTime(2026, 9, 28, 21, 40)),
      quranCatalogProvider.overrideWithValue(catalog ?? FakeQuranCatalog()),
      ...overrides,
    ],
    child: madarScreenshotApp(home: home, theme: theme, locale: Locale(language)),
  );
  return h;
}
