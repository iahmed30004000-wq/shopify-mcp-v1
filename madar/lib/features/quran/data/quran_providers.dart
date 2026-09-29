import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_audio.dart';
import '../../home/home_providers.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/arabic_search.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_prefs.dart';
import '../domain/quran_text.dart';
import '../domain/tajweed.dart';
import 'quran_com_client.dart';
import 'quran_services.dart';
import 'quran_store.dart';

// ------------------------------------------------------------------ data

/// Where the bundled files are read from (the app bundle by default).
final quranAssetSourceProvider = Provider<QuranAssetSource>((ref) => const BundleQuranAssetSource());

/// The loaded bundled data (kept for the app's lifetime).
final quranStoreProvider = Provider<QuranStore>((ref) => QuranStore(ref.watch(quranAssetSourceProvider)));

final quranMetaProvider = FutureProvider<QuranMeta>((ref) => ref.watch(quranStoreProvider).meta());

final quranTextProvider = FutureProvider<QuranText>((ref) => ref.watch(quranStoreProvider).text());

final quranTajweedProvider = FutureProvider<TajweedIndex>((ref) => ref.watch(quranStoreProvider).tajweed());

final quranSearchIndexProvider = FutureProvider<QuranSearchIndex>(
  (ref) => ref.watch(quranStoreProvider).searchIndex(),
);

/// The clock (sessions, last read).
final quranClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

// ----------------------------------------------------------- preferences

final quranPrefsStoreProvider = Provider<QuranPrefsStore>(
  (ref) => QuranPrefsStore(ref.watch(repositoriesProvider).keyValues),
);

final quranReaderPrefsProvider = StreamProvider<QuranReaderPrefs>(
  (ref) => ref.watch(quranPrefsStoreProvider).watchPrefs(),
);

final quranLastReadProvider = StreamProvider<QuranLastRead?>(
  (ref) => ref.watch(quranPrefsStoreProvider).watchLastRead(),
);

// ------------------------------------------------------------- bookmarks

final quranBookmarkServiceProvider = Provider<QuranBookmarkService>(
  (ref) => QuranBookmarkService(ref.watch(repositoriesProvider)),
);

final quranBookmarksProvider = StreamProvider<List<QuranBookmarkRow>>(
  (ref) => ref.watch(quranBookmarkServiceProvider).watchAll(),
);

/// Bookmarks by ayah (the reader's markers).
final quranBookmarksByAyahProvider = Provider<Map<AyahRef, QuranBookmarkRow>>((ref) {
  final rows = ref.watch(quranBookmarksProvider).value ?? const <QuranBookmarkRow>[];
  return {for (final r in rows) AyahRef(r.surah, r.ayah): r};
});

// -------------------------------------------------------------- sessions

final quranSessionRecorderProvider = Provider<QuranSessionRecorder>(
  (ref) => QuranSessionRecorder(ref.watch(repositoriesProvider), ref.watch(orbitPulseHubProvider)),
);

// ------------------------------------------------------------- Quran.com

final quranHttpProvider = Provider<QuranHttp>((ref) => IoQuranHttp());

final quranCacheStoreProvider = Provider<QuranCacheStore>((ref) => FileQuranCacheStore());

final quranComClientProvider = Provider<QuranComClient>(
  (ref) => QuranComClient(http: ref.watch(quranHttpProvider), cache: ref.watch(quranCacheStoreProvider)),
);

/// Bumped after every download so cache-reading providers re-read.
final quranDownloadsVersionProvider = NotifierProvider<QuranDownloadsVersion, int>(QuranDownloadsVersion.new);

class QuranDownloadsVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// A sura's cached translation (never downloads; null when not on disk).
final quranTranslationProvider = FutureProvider.autoDispose.family<QuranTranslation?, (int, int)>((ref, key) async {
  ref.watch(quranDownloadsVersionProvider);
  final (surah, id) = key;
  final meta = await ref.watch(quranMetaProvider.future);
  final s = meta.surah(surah);
  return ref
      .watch(quranComClientProvider)
      .cachedTranslation(surah, id: id, expectedAyat: [for (var a = 1; a <= s.ayahCount; a++) AyahRef(surah, a)]);
});

/// A sura's cached Quran.com tajweed text (never downloads).
final quranComTajweedProvider = FutureProvider.autoDispose.family<Map<AyahRef, TajweedText>?, int>((ref, surah) async {
  ref.watch(quranDownloadsVersionProvider);
  final meta = await ref.watch(quranMetaProvider.future);
  final s = meta.surah(surah);
  return ref
      .watch(quranComClientProvider)
      .cachedTajweed(surah, expectedAyat: [for (var a = 1; a <= s.ayahCount; a++) AyahRef(surah, a)]);
});

/// Downloads (explicit user action only) and refreshes the readers.
class QuranDownloads {
  QuranDownloads(this._ref);

  final Ref _ref;

  List<AyahRef> _ayat(QuranMeta meta, int surah) => [
    for (var a = 1; a <= meta.surah(surah).ayahCount; a++) AyahRef(surah, a),
  ];

  Future<QuranTranslation> translation(int surah, int id) async {
    final meta = await _ref.read(quranMetaProvider.future);
    final t = await _ref.read(quranComClientProvider).downloadTranslation(surah, id: id, expectedAyat: _ayat(meta, surah));
    _ref.read(quranDownloadsVersionProvider.notifier).bump();
    return t;
  }

  Future<void> tajweed(int surah) async {
    final meta = await _ref.read(quranMetaProvider.future);
    await _ref.read(quranComClientProvider).downloadTajweed(surah, expectedAyat: _ayat(meta, surah));
    _ref.read(quranDownloadsVersionProvider.notifier).bump();
  }
}

final quranDownloadsProvider = Provider<QuranDownloads>(QuranDownloads.new);

// -------------------------------------------------------------- playback

/// The recitation state (current ayah for highlighting / following).
final quranPlaybackProvider = StreamProvider<QuranPlayback>((ref) async* {
  final audio = ref.watch(quranAudioProvider);
  yield audio.value;
  yield* audio.playback;
});

// ----------------------------------------------------------------- hooks

/// Adds an ayah range to Hifz (set by the Hifz package / the app shell);
/// returns whether it was added. Null hides the reader's "Add to Hifz".
typedef QuranAddToHifz = Future<bool> Function(BuildContext context, AyahRange range);

final quranAddToHifzProvider = Provider<QuranAddToHifz?>((ref) => null);

/// Opens a tafsir for an ayah (set by the host once a tafsir exists); null
/// shows the "coming soon" note.
typedef QuranOpenTafsir = void Function(BuildContext context, AyahRef ayah);

final quranOpenTafsirProvider = Provider<QuranOpenTafsir?>((ref) => null);

/// Copy / share.
final quranShareServiceProvider = Provider<QuranShareService>((ref) => const PlatformQuranShareService());

// --------------------------------------------------------------- content

/// An ayah ready to lay out: its text (basmala split off) and tajweed marks.
@immutable
class AyahContent {
  const AyahContent({required this.ref, required this.index, required this.text, required this.marks});

  final AyahRef ref;
  final int index;
  final String text;
  final List<TajweedMark> marks;
}

/// Assembles ayat from the bundled text + tajweed, or from a downloaded
/// Quran.com tajweed text for the suras in [quranCom].
class QuranContent {
  QuranContent({required this.meta, required this.text, this.tajweed, this.quranCom = const {}});

  final QuranMeta meta;
  final QuranText text;
  final TajweedIndex? tajweed;
  final Map<AyahRef, TajweedText> quranCom;

  AyahContent ayah(int index) {
    final ref = meta.refAt(index);
    final remote = quranCom[ref];
    if (remote != null) return AyahContent(ref: ref, index: index, text: remote.text, marks: remote.marks);
    final line = text.line(index);
    final cut = text.basmalaLength(index);
    final marks = tajweed?.lineMarks(index) ?? const <TajweedMark>[];
    return AyahContent(
      ref: ref,
      index: index,
      text: cut == 0 ? line : line.substring(cut),
      marks: cut == 0 ? marks : Tajweed.slice(marks, cut, line.length),
    );
  }

  /// The basmala above [surah] with its marks (null for suras 1 and 9).
  (String, List<TajweedMark>)? basmala(SurahInfo surah) {
    final b = text.basmalaOf(surah);
    if (b == null) return null;
    final marks = tajweed?.lineMarks(surah.firstIndex) ?? const <TajweedMark>[];
    return (b, Tajweed.slice(marks, 0, b.length));
  }
}
