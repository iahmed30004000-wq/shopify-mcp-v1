/// «خريطة الصفحات» · the mushaf coloured by strength, as data (Part 14).
///
/// Pure Dart: the drawing is step 2, this is the numbers it draws. Every
/// number here is the same number [HifzStrengths] computed – a page's
/// strength is the mean of the strengths of the ayat on it that have a
/// result, and nothing else. A page he has never been tested on is
/// [StrengthBand.unknown] and carries no number at all, so a colour can
/// never suggest progress that did not happen.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import 'hifz_strength.dart';
import 'mushaf_shape.dart';

/// One page of the mushaf.
@immutable
final class PageStrength {
  const PageStrength({
    required this.page,
    required this.range,
    required this.ayatOnPage,
    required this.memorised,
    required this.tested,
    required this.skipped,
    required this.band,
    required this.weakest,
    this.strength,
    this.lastDay,
  });

  final int page;

  /// The ayat the page holds.
  final AyahRange range;
  final int ayatOnPage;

  /// How many of them are in his Hifz list.
  final int memorised;

  /// How many of them have a real result behind them.
  final int tested;

  /// How many he marked «مش عليّ».
  final int skipped;

  /// The mean strength of the tested ayat; null when none was tested.
  final double? strength;

  /// The band the page is coloured by (the mean's band, or
  /// [StrengthBand.unknown] when nothing was tested).
  final StrengthBand band;

  /// The weakest band found on the page – what a screen warns with.
  final StrengthBand weakest;

  /// The newest attempt on this page.
  final DateTime? lastDay;

  /// How much of the page is in his list, 0 … 1.
  double get coverage => ayatOnPage == 0 ? 0 : memorised / ayatOnPage;

  bool get isUntouched => tested == 0;

  @override
  String toString() =>
      'PageStrength($page ${band.name}${strength == null ? '' : ' ${strength!.toStringAsFixed(2)}'}, $memorised/$ayatOnPage)';
}

/// One surah, for the heatmap of «التقدّم».
@immutable
final class SurahStrength {
  const SurahStrength({
    required this.surah,
    required this.ayahCount,
    required this.memorised,
    required this.tested,
    required this.band,
    this.strength,
    this.lastDay,
  });

  final int surah;
  final int ayahCount;
  final int memorised;
  final int tested;
  final double? strength;
  final StrengthBand band;
  final DateTime? lastDay;

  double get coverage => ayahCount == 0 ? 0 : memorised / ayahCount;

  @override
  String toString() => 'SurahStrength($surah ${band.name}, $memorised/$ayahCount)';
}

/// The mushaf by page and by surah, coloured by the strengths.
@immutable
final class HifzPageMap {
  const HifzPageMap._({required this.pages, required this.surahs, required this.memorisedAyat});

  /// Builds the map over [pages] (the whole mushaf by default).
  ///
  /// [memorised] is his inventory; an ayah outside it still shows its
  /// strength if he was tested on it, because a result is a result.
  factory HifzPageMap.build({
    required MushafShape shape,
    required HifzStrengths strengths,
    required List<AyahRange> memorised,
    int? firstPage,
    int? lastPage,
  }) {
    final inList = <String, bool>{};
    for (final range in memorised) {
      for (final ref in Mushaf.ayatIn(shape, Mushaf.clamp(shape, range))) {
        inList[ref.toString()] = true;
      }
    }
    final from = (firstPage ?? 1).clamp(1, shape.pageCount);
    final to = (lastPage ?? shape.pageCount).clamp(from, shape.pageCount);
    final pages = <PageStrength>[];
    final bySurah = <int, List<AyahRef>>{};
    for (var p = from; p <= to; p++) {
      final range = AyahRange(shape.pageStart(p), shape.pageEnd(p));
      final refs = Mushaf.ayatIn(shape, range);
      var memorisedCount = 0, testedCount = 0, skippedCount = 0;
      var sum = 0.0;
      DateTime? last;
      var weakest = StrengthBand.solid;
      for (final ref in refs) {
        (bySurah[ref.surah] ??= []).add(ref);
        if (inList.containsKey(ref.toString())) memorisedCount++;
        final s = strengths.of(ref);
        if (s.isSkipped) {
          skippedCount++;
          continue;
        }
        if (!s.isKnown) {
          if (inList.containsKey(ref.toString()) && _rank(StrengthBand.unknown) < _rank(weakest)) {
            weakest = StrengthBand.unknown;
          }
          continue;
        }
        testedCount++;
        sum += s.strength;
        if (_rank(s.band) < _rank(weakest)) weakest = s.band;
        if (s.lastDay != null && (last == null || s.lastDay!.isAfter(last))) last = s.lastDay;
      }
      final mean = testedCount == 0 ? null : sum / testedCount;
      pages.add(
        PageStrength(
          page: p,
          range: range,
          ayatOnPage: refs.length,
          memorised: memorisedCount,
          tested: testedCount,
          skipped: skippedCount,
          strength: mean,
          band: mean == null
              ? (skippedCount == refs.length && refs.isNotEmpty ? StrengthBand.skipped : StrengthBand.unknown)
              : strengths.model.bandOf(mean),
          weakest: testedCount == 0 && memorisedCount == 0 ? StrengthBand.unknown : weakest,
          lastDay: last,
        ),
      );
    }

    final surahs = <SurahStrength>[];
    final surahNumbers = bySurah.keys.toList()..sort();
    for (final s in surahNumbers) {
      final refs = bySurah[s]!;
      var memorisedCount = 0, testedCount = 0;
      var sum = 0.0;
      DateTime? last;
      for (final ref in refs) {
        if (inList.containsKey(ref.toString())) memorisedCount++;
        final st = strengths.of(ref);
        if (!st.isKnown) continue;
        testedCount++;
        sum += st.strength;
        if (st.lastDay != null && (last == null || st.lastDay!.isAfter(last))) last = st.lastDay;
      }
      final mean = testedCount == 0 ? null : sum / testedCount;
      surahs.add(
        SurahStrength(
          surah: s,
          ayahCount: refs.length,
          memorised: memorisedCount,
          tested: testedCount,
          strength: mean,
          band: mean == null ? StrengthBand.unknown : strengths.model.bandOf(mean),
          lastDay: last,
        ),
      );
    }

    return HifzPageMap._(
      pages: List.unmodifiable(pages),
      surahs: List.unmodifiable(surahs),
      memorisedAyat: inList.length,
    );
  }

  final List<PageStrength> pages;
  final List<SurahStrength> surahs;

  /// How many ayat are in his list in all.
  final int memorisedAyat;

  PageStrength? page(int number) {
    for (final p in pages) {
      if (p.page == number) return p;
    }
    return null;
  }

  /// The pages he has results for, weakest first.
  List<PageStrength> weakestPages({int limit = 10}) {
    final known = [for (final p in pages) if (p.strength != null) p]
      ..sort((a, b) {
        final s = a.strength!.compareTo(b.strength!);
        return s != 0 ? s : a.page.compareTo(b.page);
      });
    return known.take(limit).toList();
  }

  /// Pages with something of his on them.
  List<PageStrength> get touchedPages => [for (final p in pages) if (p.memorised > 0 || p.tested > 0) p];

  static int _rank(StrengthBand band) => switch (band) {
    StrengthBand.unknown => 0,
    StrengthBand.weak => 1,
    StrengthBand.shaky => 2,
    StrengthBand.firm => 3,
    StrengthBand.solid => 4,
    StrengthBand.skipped => 5,
  };

  @override
  String toString() => 'HifzPageMap(${pages.length} pages, $memorisedAyat ayat)';
}
