import '../../../core/quran/ayah.dart';

/// Ayat per surah in the Hafs (Kufan) count – 6236 in all. Identical in two
/// independent published copies of everyayah.com's recitation list
/// (risan/quran-json `data/audio/everyayah.json` and Alfanous
/// `configs/recitations.json`), so the audio files line up with it exactly.
const List<int> kSurahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, //
  135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, //
  75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, //
  22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, //
  50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, //
  19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6, //
];

/// Structural helpers over [kSurahAyahCounts] (pure; no catalog needed).
abstract final class SurahMath {
  static const int totalAyat = 6236;

  /// Ayat in [surah] (1–114).
  static int ayahCount(int surah) => kSurahAyahCounts[surah - 1];

  /// Whether [ayah] exists.
  static bool isValid(AyahRef ayah) => ayah.ayah <= ayahCount(ayah.surah);

  /// The last ayah of [surah].
  static AyahRef lastOf(int surah) => AyahRef(surah, ayahCount(surah));

  /// The whole of [surah] as a range.
  static AyahRange surahRange(int surah) => AyahRange(AyahRef(surah, 1), lastOf(surah));

  /// The ayah after [ayah] across surah boundaries; null after 114:6.
  static AyahRef? next(AyahRef ayah) {
    if (ayah.ayah < ayahCount(ayah.surah)) return AyahRef(ayah.surah, ayah.ayah + 1);
    if (ayah.surah < 114) return AyahRef(ayah.surah + 1, 1);
    return null;
  }

  /// The ayah before [ayah]; null before 1:1.
  static AyahRef? previous(AyahRef ayah) {
    if (ayah.ayah > 1) return AyahRef(ayah.surah, ayah.ayah - 1);
    if (ayah.surah > 1) return lastOf(ayah.surah - 1);
    return null;
  }

  /// Ayat in [range], in order (clamped to real ayat).
  static Iterable<AyahRef> ayatIn(AyahRange range) sync* {
    AyahRef? a = clamp(range.first);
    final last = clamp(range.last);
    while (a != null && a <= last) {
      yield a;
      a = next(a);
    }
  }

  /// Number of ayat in [range].
  static int countIn(AyahRange range) {
    final first = clamp(range.first), last = clamp(range.last);
    if (last < first) return 0;
    return _ordinal(last) - _ordinal(first) + 1;
  }

  /// 0-based position of [ayah] in the mushaf (1:1 → 0, 114:6 → 6235).
  static int ordinal(AyahRef ayah) => _ordinal(clamp(ayah));

  static int _ordinal(AyahRef ayah) {
    var n = 0;
    for (var s = 1; s < ayah.surah; s++) {
      n += ayahCount(s);
    }
    return n + ayah.ayah - 1;
  }

  /// [ayah] with its ayah number clamped to the surah's length.
  static AyahRef clamp(AyahRef ayah) {
    final count = ayahCount(ayah.surah);
    return ayah.ayah <= count ? ayah : AyahRef(ayah.surah, count);
  }
}
