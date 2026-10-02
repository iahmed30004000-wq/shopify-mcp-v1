import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/quran/data/quran_providers.dart' show quranStoreProvider;
import '../../features/quran/data/quran_store.dart' show BundledQuranCatalog;
import 'ayah.dart';

/// Read-only access to the Quran text and its structure (Hafs, Madani
/// 604-page mushaf). Implemented by the Quran reader feature
/// (lib/features/quran), which owns [quranCatalogProvider]'s body; other
/// features (wird, Hifz, recitation) depend only on this interface and use
/// fakes in tests.
abstract class QuranCatalog {
  /// 114.
  int get surahCount;

  /// Number of ayat in [surah] (1–114).
  int ayahCount(int surah);

  /// Surah name – Arabic (`الفاتحة`) or transliterated English (`Al-Fatihah`).
  String surahName(int surah, {required bool arabic});

  /// Whether [surah] was revealed in Makkah.
  bool isMakki(int surah);

  /// Madani mushaf page (1–604), juz (1–30) and hizb (1–60) of an ayah.
  int pageOf(AyahRef ayah);
  int juzOf(AyahRef ayah);
  int hizbOf(AyahRef ayah);

  /// First ayah of a page / juz / hizb.
  AyahRef pageStart(int page);
  AyahRef juzStart(int juz);
  AyahRef hizbStart(int hizb);

  /// The ayah after / before [ayah] across surah boundaries; null at the ends.
  AyahRef? next(AyahRef ayah);
  AyahRef? previous(AyahRef ayah);

  /// Ayat in an inclusive range (across surahs).
  int countInRange(AyahRange range);

  /// Uthmani text of an ayah (no ayah-number marker), loaded from bundled
  /// data. Completes with an error only if the bundled data is missing.
  Future<String> ayahText(AyahRef ayah);

  /// Waits until the catalog's structural data is loaded (call once before
  /// using the synchronous getters; cheap afterwards).
  Future<void> ensureLoaded();
}

/// The app's [QuranCatalog]: the bundled Tanzil Uthmani text and Madani
/// mushaf structure (assets/quran/), loaded by the Quran reader feature's
/// store (lib/features/quran). Call [QuranCatalog.ensureLoaded] once before
/// the synchronous getters.
final quranCatalogProvider = Provider<QuranCatalog>((ref) => BundledQuranCatalog(ref.watch(quranStoreProvider)));
