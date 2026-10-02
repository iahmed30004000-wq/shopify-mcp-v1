import 'dart:async';

import 'package:flutter/widgets.dart' show BuildContext, Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/prayer_mute.dart';
import '../data/audio_service_session.dart';
import '../data/download_manager.dart';
import '../data/download_transport.dart';
import '../data/just_audio_engine.dart';
import '../data/media_session.dart';
import '../data/network_probe.dart';
import '../data/recitation_engine.dart';
import '../data/recitation_repository.dart';
import '../data/recitation_storage.dart';
import '../domain/listening_tracker.dart';
import '../domain/recitation_queue.dart';
import '../domain/recitation_settings.dart';
import '../domain/recitation_state.dart';
import '../domain/reciters.dart';
import 'recitation_player.dart';

// --------------------------------------------------------------- platform
// Each platform piece sits behind a provider so tests swap in fakes.

/// Creates the audio engine (just_audio) – called on the first play only.
final recitationEngineFactoryProvider = Provider<RecitationEngine Function()>((ref) => JustAudioEngine.new);

/// Audio focus / becoming-noisy events (audio_session).
final recitationAudioFocusProvider = Provider<RecitationAudioFocus>((ref) => AudioSessionFocus());

/// The media notification / lock-screen session (audio_service), started on
/// the first play; falls back to foreground-only playback.
final recitationBackgroundProvider = Provider<RecitationBackground>((ref) {
  return AudioServiceBackground(channelName: _l10n(ref).recitationChannelName);
});

/// Where downloads live (app support dir).
final recitationStorageProvider = Provider<RecitationStorage>((ref) => RecitationStorage.appSupport());

/// HTTP for downloads.
final recitationTransportProvider = Provider<DownloadTransport>((ref) {
  final transport = HttpDownloadTransport();
  ref.onDispose(transport.close);
  return transport;
});

/// "On Wi-Fi?" for the Wi-Fi-only option.
final recitationNetworkProbeProvider = Provider<NetworkProbe>((ref) => const InterfaceNetworkProbe());

final recitationClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// --------------------------------------------------------------- settings

final recitationSettingsRepositoryProvider = Provider<RecitationSettingsRepository>(
  (ref) => RecitationSettingsRepository(ref.watch(repositoriesProvider).keyValues),
);

/// The user's recitation settings (live).
final recitationSettingsProvider = StreamNotifierProvider<RecitationSettingsController, RecitationSettings>(
  RecitationSettingsController.new,
);

class RecitationSettingsController extends StreamNotifier<RecitationSettings> {
  @override
  Stream<RecitationSettings> build() => ref.watch(recitationSettingsRepositoryProvider).watch();

  /// Saves [change] applied to the current settings.
  Future<void> change(RecitationSettings Function(RecitationSettings) change) async {
    final repo = ref.read(recitationSettingsRepositoryProvider);
    final current = state.value ?? await repo.load();
    final next = change(current);
    state = AsyncData(next);
    await repo.save(next);
  }
}

// -------------------------------------------------------------- downloads

/// The download manager (does nothing until the user starts a download).
final recitationDownloadsProvider = Provider<RecitationDownloads>((ref) {
  final downloads = RecitationDownloads(
    storage: ref.watch(recitationStorageProvider),
    transport: ref.watch(recitationTransportProvider),
    network: ref.watch(recitationNetworkProbeProvider),
    wifiOnly: () => ref.read(recitationSettingsProvider).value?.wifiOnly ?? true,
    clock: ref.watch(recitationClockProvider),
  );
  ref.onDispose(downloads.dispose);
  return downloads;
});

/// Rebuild signal for download UIs (bumps on every change) – watch it, then
/// read [recitationDownloadsProvider]. Reads the index on first watch.
final recitationDownloadsTickProvider = NotifierProvider<RecitationDownloadsTick, int>(RecitationDownloadsTick.new);

class RecitationDownloadsTick extends Notifier<int> {
  @override
  int build() {
    final downloads = ref.watch(recitationDownloadsProvider);
    void bump() => state = state + 1;
    downloads.addListener(bump);
    ref.onDispose(() => downloads.removeListener(bump));
    unawaited(downloads.load().catchError((Object _) {}));
    return 0;
  }
}

// ------------------------------------------------------------ navigation

/// Opens one reciter's per-surah downloads. The app's router registers this
/// (a routed page); null (the default) pushes the page directly.
final recitationOpenDownloadsProvider = Provider<void Function(BuildContext context, Reciter reciter)?>(
  (ref) => null,
);

// ----------------------------------------------------------------- player

/// The recitation player – also the app's `quranAudioProvider`.
final recitationPlayerProvider = Provider<RecitationPlayer>((ref) {
  final player = RecitationPlayer(
    engineFactory: ref.watch(recitationEngineFactoryProvider),
    loadSettings: () async {
      final live = ref.read(recitationSettingsProvider).value;
      return live ?? await ref.read(recitationSettingsRepositoryProvider).load();
    },
    focus: ref.watch(recitationAudioFocusProvider),
    localFiles: ref.watch(recitationDownloadsProvider),
    logger: _LazyLogger(() => DbListeningLogger(ref.read(repositoriesProvider))),
    background: ref.watch(recitationBackgroundProvider),
    texts: () => recitationMediaTexts(ref),
    prayerMute: ref.watch(prayerMuteProvider),
    clock: ref.watch(recitationClockProvider),
  );
  ref.onDispose(player.dispose);
  return player;
});

/// The player's full state, for widgets.
final recitationStateProvider = NotifierProvider<RecitationStateNotifier, RecitationState>(RecitationStateNotifier.new);

class RecitationStateNotifier extends Notifier<RecitationState> {
  @override
  RecitationState build() {
    final player = ref.watch(recitationPlayerProvider);
    void sync() => state = player.state;
    player.addListener(sync);
    ref.onDispose(() => player.removeListener(sync));
    return player.state;
  }
}

/// The Quran catalog once loaded, or null while the reader feature is not
/// wired / its data is missing (names then fall back to numbers).
final recitationCatalogProvider = FutureProvider<QuranCatalog?>((ref) async {
  try {
    final catalog = ref.watch(quranCatalogProvider);
    await catalog.ensureLoaded();
    return catalog;
  } catch (_) {
    return null;
  }
});

// ------------------------------------------------------------------ texts

L10n _l10n(Ref ref) {
  var language = 'ar';
  try {
    language = ref.read(appSettingsProvider).languageCode;
  } catch (_) {}
  return lookupL10n(Locale(language == 'en' ? 'en' : 'ar'));
}

/// A surah's display name: the catalog's, or "Surah N" without it.
String recitationSurahName(QuranCatalog? catalog, int surah, L10n l, MadarFormatter fmt) {
  if (catalog != null) {
    try {
      return catalog.surahName(surah, arabic: fmt.isArabic);
    } catch (_) {}
  }
  return l.recitationSurahNumber(fmt.formatInt(surah));
}

/// `سورة البقرة · الآية ٢٥٥` / `Al-Baqarah · 255` / `… · البسملة`.
String recitationItemTitle(QueueItem item, QuranCatalog? catalog, L10n l, MadarFormatter fmt) {
  final surah = recitationSurahName(catalog, item.ayah.surah, l, fmt);
  return item.isBasmala ? l.recitationTitleBasmala(surah) : l.recitationTitleAyah(surah, fmt.formatInt(item.ayah.ayah));
}

/// Texts of the media notification in the app's language.
RecitationMediaTexts recitationMediaTexts(Ref ref) {
  var language = 'ar';
  var digits = DigitStyle.auto;
  try {
    final s = ref.read(appSettingsProvider);
    language = s.languageCode;
    digits = s.digits;
  } catch (_) {}
  final l = lookupL10n(Locale(language == 'en' ? 'en' : 'ar'));
  final fmt = MadarFormatter(languageCode: language, digits: digits);
  final catalog = ref.read(recitationCatalogProvider).value;
  return RecitationMediaTexts(
    title: (item) => recitationItemTitle(item, catalog, l, fmt),
    reciterName: (r) => r.name(arabic: fmt.isArabic),
    album: l.recitationAlbum,
    labels: RecitationMediaLabels(
      play: l.recitationPlay,
      pause: l.recitationPause,
      next: l.recitationNextAyah,
      previous: l.recitationPreviousAyah,
      stop: l.recitationStop,
    ),
  );
}

/// Opens the database only when a session is actually logged.
class _LazyLogger implements ListeningLogger {
  _LazyLogger(this._create);

  final ListeningLogger Function() _create;
  ListeningLogger? _logger;

  @override
  Future<void> log(ListeningSummary summary) => (_logger ??= _create()).log(summary);
}

/// The reciter the user chose (fallback while settings load).
final recitationReciterProvider = Provider<Reciter>(
  (ref) => ref.watch(recitationSettingsProvider.select((s) => s.value?.reciter ?? Reciters.fallback)),
);
