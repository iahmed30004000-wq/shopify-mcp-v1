import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// One sura's metadata (Tanzil Quran Metadata + Madar's names).
@immutable
class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.ayahCount,
    required this.revelationOrder,
    required this.makki,
    required this.nameArabic,
    required this.nameEnglish,
    required this.meaningEnglish,
    required this.firstIndex,
  });

  /// 1–114.
  final int number;
  final int ayahCount;

  /// 1–114, the order of revelation.
  final int revelationOrder;
  final bool makki;

  /// `البقرة` (without «سورة»).
  final String nameArabic;

  /// `Al-Baqarah`.
  final String nameEnglish;

  /// `The Cow`.
  final String meaningEnglish;

  /// Absolute index (0–6235) of the sura's first ayah.
  final int firstIndex;

  AyahRef get first => AyahRef(number, 1);
  AyahRef get last => AyahRef(number, ayahCount);

  /// Whether the sura opens with a separate basmala (all but 1 and 9 – in
  /// al-Fatihah the basmala is its first ayah).
  bool get hasBasmalaHeader => number != 1 && number != 9;
}

/// A sajdah ayah (15 in the Madani mushaf).
@immutable
class SajdahInfo {
  const SajdahInfo(this.ref, {required this.obligatory});

  final AyahRef ref;

  /// Tanzil marks four sajdat as obligatory (wajib in the Hanafi school);
  /// the others are recommended.
  final bool obligatory;
}

/// Where a hizb quarter sits: juz 1–30, hizb 1–60, quarter 1–4 inside it.
@immutable
class QuarterPosition {
  const QuarterPosition({required this.index, required this.juz, required this.hizb, required this.quarter});

  /// 1–240.
  final int index;
  final int juz;
  final int hizb;

  /// 1 (hizb start), 2 (¼), 3 (½), 4 (¾).
  final int quarter;

  @override
  bool operator ==(Object other) => other is QuarterPosition && other.index == index;

  @override
  int get hashCode => index;
}

/// The whole structure of the Hafs Quran in the Madani 604-page mushaf:
/// suras, pages, juz, hizb quarters and sajdat, with fast lookups by
/// absolute ayah index (0–6235).
class QuranMeta {
  QuranMeta._({
    required this.surahs,
    required this.pageStarts,
    required this.juzStarts,
    required this.quarterStarts,
    required this.sajdat,
  }) : _pageStartIdx = [for (final r in pageStarts) _indexIn(surahs, r)],
       _juzStartIdx = [for (final r in juzStarts) _indexIn(surahs, r)],
       _quarterStartIdx = [for (final r in quarterStarts) _indexIn(surahs, r)],
       _sajdahByRef = {for (final s in sajdat) s.ref: s};

  /// Parses `assets/quran/quran-meta.json` (see
  /// assets/quran/source/build_quran.py).
  factory QuranMeta.fromJson(Map<String, Object?> json) {
    final rows = (json['suras']! as List).cast<List<Object?>>();
    var offset = 0;
    final surahs = <SurahInfo>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final count = r[0]! as int;
      surahs.add(
        SurahInfo(
          number: i + 1,
          ayahCount: count,
          revelationOrder: r[1]! as int,
          makki: r[2] == 'M',
          nameArabic: r[3]! as String,
          nameEnglish: r[4]! as String,
          meaningEnglish: r[5]! as String,
          firstIndex: offset,
        ),
      );
      offset += count;
    }
    List<AyahRef> refs(String key) => [
      for (final p in (json[key]! as List).cast<List<Object?>>()) AyahRef(p[0]! as int, p[1]! as int),
    ];
    final sajdat = [
      for (final p in (json['sajdat']! as List).cast<List<Object?>>())
        SajdahInfo(AyahRef(p[0]! as int, p[1]! as int), obligatory: p[2] == 'o'),
    ];
    return QuranMeta._(
      surahs: List.unmodifiable(surahs),
      pageStarts: List.unmodifiable(refs('pages')),
      juzStarts: List.unmodifiable(refs('juz')),
      quarterStarts: List.unmodifiable(refs('quarters')),
      sajdat: List.unmodifiable(sajdat),
    );
  }

  static const int surahCount = 114;
  static const int pageCount = 604;
  static const int juzCount = 30;
  static const int hizbCount = 60;
  static const int quarterCount = 240;
  static const int ayahTotal = 6236;

  final List<SurahInfo> surahs;
  final List<AyahRef> pageStarts;
  final List<AyahRef> juzStarts;

  /// The 240 hizb quarters (rub' al-hizb); hizb h starts at quarter 4h-3.
  final List<AyahRef> quarterStarts;
  final List<SajdahInfo> sajdat;

  final List<int> _pageStartIdx;
  final List<int> _juzStartIdx;
  final List<int> _quarterStartIdx;
  final Map<AyahRef, SajdahInfo> _sajdahByRef;

  static int _indexIn(List<SurahInfo> surahs, AyahRef ref) => surahs[ref.surah - 1].firstIndex + ref.ayah - 1;

  /// Total number of ayat (6236).
  int get ayahCount => surahs.last.firstIndex + surahs.last.ayahCount;

  SurahInfo surah(int number) {
    RangeError.checkValueInInterval(number, 1, surahs.length, 'surah');
    return surahs[number - 1];
  }

  /// Whether [ref] names a real ayah.
  bool isValid(AyahRef ref) => ref.surah <= surahs.length && ref.ayah <= surahs[ref.surah - 1].ayahCount;

  /// Absolute index 0–6235.
  int indexOf(AyahRef ref) {
    if (!isValid(ref)) throw RangeError('No ayah $ref');
    return _indexIn(surahs, ref);
  }

  /// The ayah at absolute [index].
  AyahRef refAt(int index) {
    RangeError.checkValueInInterval(index, 0, ayahCount - 1, 'index');
    var lo = 0;
    var hi = surahs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (surahs[mid].firstIndex <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return AyahRef(lo + 1, index - surahs[lo].firstIndex + 1);
  }

  /// Largest i with starts[i] <= index (starts ascending, starts[0] == 0).
  static int _bucket(List<int> starts, int index) {
    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= index) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Madani page 1–604.
  int pageOf(AyahRef ref) => _bucket(_pageStartIdx, indexOf(ref)) + 1;

  /// 1–30.
  int juzOf(AyahRef ref) => _bucket(_juzStartIdx, indexOf(ref)) + 1;

  /// Hizb quarter 1–240.
  int quarterOf(AyahRef ref) => _bucket(_quarterStartIdx, indexOf(ref)) + 1;

  /// 1–60.
  int hizbOf(AyahRef ref) => (quarterOf(ref) - 1) ~/ 4 + 1;

  QuarterPosition quarterPosition(int quarter) => QuarterPosition(
    index: quarter,
    juz: (quarter - 1) ~/ 8 + 1,
    hizb: (quarter - 1) ~/ 4 + 1,
    quarter: (quarter - 1) % 4 + 1,
  );

  AyahRef pageStart(int page) {
    RangeError.checkValueInInterval(page, 1, pageCount, 'page');
    return pageStarts[page - 1];
  }

  /// Last ayah on [page].
  AyahRef pageEnd(int page) =>
      page == pageCount ? surahs.last.last : refAt(_pageStartIdx[page] - 1);

  AyahRef juzStart(int juz) {
    RangeError.checkValueInInterval(juz, 1, juzCount, 'juz');
    return juzStarts[juz - 1];
  }

  AyahRef juzEnd(int juz) => juz == juzCount ? surahs.last.last : refAt(_juzStartIdx[juz] - 1);

  AyahRef hizbStart(int hizb) {
    RangeError.checkValueInInterval(hizb, 1, hizbCount, 'hizb');
    return quarterStarts[(hizb - 1) * 4];
  }

  AyahRef quarterStart(int quarter) {
    RangeError.checkValueInInterval(quarter, 1, quarterCount, 'quarter');
    return quarterStarts[quarter - 1];
  }

  /// Whether a hizb quarter begins at [ref] (1–240), or null.
  int? quarterStartingAt(AyahRef ref) {
    final q = quarterOf(ref);
    return quarterStarts[q - 1] == ref ? q : null;
  }

  /// Every ayah on [page], in order.
  List<AyahRef> ayatOnPage(int page) {
    final from = _pageStartIdx[page - 1];
    final to = page == pageCount ? ayahCount : _pageStartIdx[page];
    return [for (var i = from; i < to; i++) refAt(i)];
  }

  /// Suras that have at least one ayah on [page].
  List<int> surahsOnPage(int page) {
    final first = pageStart(page).surah;
    final last = pageEnd(page).surah;
    return [for (var s = first; s <= last; s++) s];
  }

  SajdahInfo? sajdahAt(AyahRef ref) => _sajdahByRef[ref];

  AyahRef? next(AyahRef ref) {
    final i = indexOf(ref);
    return i + 1 < ayahCount ? refAt(i + 1) : null;
  }

  AyahRef? previous(AyahRef ref) {
    final i = indexOf(ref);
    return i > 0 ? refAt(i - 1) : null;
  }

  /// Ayat in an inclusive range.
  int countInRange(AyahRange range) => indexOf(range.last) - indexOf(range.first) + 1;

  /// Fraction of [page] covered by [ayat] (ayat on other pages ignored).
  double pageShare(int page, int ayatSeenOnPage) {
    final total = ayatOnPage(page).length;
    return total == 0 ? 0 : (ayatSeenOnPage / total).clamp(0.0, 1.0);
  }
}
