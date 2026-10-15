import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';

/// Every ayah of the mushaf numbered 0…6235 in reading order (so ranges and
/// progress are plain integer arithmetic), built from a [QuranCatalog].
class QuranIndex {
  QuranIndex(QuranCatalog catalog)
    : _prefix = List<int>.filled(catalog.surahCount + 1, 0),
      surahCount = catalog.surahCount {
    for (var s = 1; s <= surahCount; s++) {
      _prefix[s] = _prefix[s - 1] + catalog.ayahCount(s);
    }
  }

  final int surahCount;

  /// `_prefix[s]` = ayat before surah `s + 1`.
  final List<int> _prefix;

  /// 6236 for the Hafs mushaf.
  int get total => _prefix[surahCount];

  int ayahCount(int surah) => _prefix[surah] - _prefix[surah - 1];

  /// 0-based index of [ayah] (clamped into its surah).
  int indexOf(AyahRef ayah) {
    final count = ayahCount(ayah.surah);
    return _prefix[ayah.surah - 1] + (ayah.ayah.clamp(1, count) - 1);
  }

  /// The ayah at [index] (clamped to the mushaf).
  AyahRef refAt(int index) {
    final i = index.clamp(0, total - 1);
    var lo = 1, hi = surahCount;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_prefix[mid] <= i) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return AyahRef(lo, i - _prefix[lo - 1] + 1);
  }

  /// Ayat in [range] (inclusive, across surahs).
  int count(AyahRange range) => indexOf(range.last) - indexOf(range.first) + 1;

  /// The range of indices `[from, to)` as ayat (null when empty).
  AyahRange? rangeOf(int from, int toExclusive) {
    if (toExclusive <= from) return null;
    return AyahRange(refAt(from), refAt(toExclusive - 1));
  }
}

/// A continuous measure of progress through the mushaf in one [WirdUnit]:
/// position `k + f` means `f` of the way (by ayat) through unit `k + 1`
/// (page, juz, hizb) – so "2 pages a day" and "a juz a day" are both plain
/// additions. For [WirdUnit.ayat] the position is the ayah index.
///
/// Positions past [units] continue into the next khatma
/// ([positionOfCumulative] / [indexAtCumulative]): an open-ended plan keeps
/// going round the mushaf.
class QuranAxis {
  QuranAxis._(this.index, this.unit, this._starts);

  /// The axis for [unit] from [catalog]'s page / juz / hizb starts.
  factory QuranAxis.of(QuranCatalog catalog, WirdUnit unit, {QuranIndex? index}) {
    final idx = index ?? QuranIndex(catalog);
    List<int>? starts;
    switch (unit) {
      case WirdUnit.pages:
        starts = [for (var p = 1; p <= 604; p++) idx.indexOf(catalog.pageStart(p))];
      case WirdUnit.juz:
        starts = [for (var j = 1; j <= 30; j++) idx.indexOf(catalog.juzStart(j))];
      case WirdUnit.hizb:
        starts = [for (var h = 1; h <= 60; h++) idx.indexOf(catalog.hizbStart(h))];
      case WirdUnit.ayat:
        starts = null;
    }
    return QuranAxis._(idx, unit, starts == null ? null : List.unmodifiable([...starts, idx.total]));
  }

  final QuranIndex index;
  final WirdUnit unit;

  /// Unit start indices plus the end sentinel (null for ayat).
  final List<int>? _starts;

  int get total => index.total;

  /// Units in one khatma (604 pages, 30 juz, 60 hizb, 6236 ayat).
  int get units => _starts == null ? index.total : _starts.length - 1;

  /// 0-based unit containing ayah [i] (0 ≤ i < total).
  int unitOf(int i) {
    final s = _starts;
    if (s == null) return i;
    var lo = 0, hi = s.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (s[mid] <= i) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// First ayah index of unit [k] (k == [units] gives [total]).
  int unitStart(int k) => _starts == null ? k : _starts[k];

  /// Position of ayah index [i] within one khatma, in `[0, units]`.
  double positionOf(int i) {
    if (i <= 0) return 0;
    if (i >= total) return units.toDouble();
    final s = _starts;
    if (s == null) return i.toDouble();
    final k = unitOf(i);
    final len = s[k + 1] - s[k];
    return k + (i - s[k]) / len;
  }

  /// The ayah index at [position] (`[0, units]` → `[0, total]`), rounded to
  /// the nearest ayah.
  int indexAt(double position) {
    if (position <= 0) return 0;
    if (position >= units) return total;
    final s = _starts;
    if (s == null) return position.round();
    final k = position.floor();
    final len = s[k + 1] - s[k];
    return s[k] + ((position - k) * len).round();
  }

  /// [positionOf] for a cumulative index (`lap * total + i`).
  double positionOfCumulative(int g) {
    final lap = g ~/ total;
    return lap * units + positionOf(g - lap * total);
  }

  /// [indexAt] for a cumulative position (`lap * units + p`).
  int indexAtCumulative(double position) {
    if (position <= 0) return 0;
    final lap = (position / units).floor();
    final rest = position - lap * units;
    return lap * total + indexAt(rest);
  }
}
