/// «الحفظ» · the shape of the mushaf, as the engine needs it (Part 14).
///
/// Pure Dart, and deliberately tiny: the engine of «الحفظ» has to walk the
/// mushaf (what is on a page, which ayah comes next, how far 2:280 is from
/// 3:5) without depending on Flutter, on a provider or on how the Quran
/// feature happens to load its data today. Everything it needs is behind
/// this one interface, implemented over the app's own [QuranCatalog] in
/// `data/` and over the test catalogue in the tests.
///
/// It holds **no verse text**. Text is only ever read from
/// `lib/features/quran/` (`QuranText`), never from here, and never from
/// anything this engine generates.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// The structure of the mushaf: how many ayat each surah has, and which
/// page and juz' an ayah falls on.
abstract class MushafShape {
  /// 114.
  int get surahCount;

  /// 604 for the Madani mushaf.
  int get pageCount;

  /// 6236 ayat in reading order.
  int get ayahTotal;

  int ayahCount(int surah);

  /// 0-based position of [ref] in reading order.
  int indexOf(AyahRef ref);

  /// The ayah at a 0-based reading position (clamped to the mushaf).
  AyahRef refAt(int index);

  int pageOf(AyahRef ref);
  AyahRef pageStart(int page);

  /// The last ayah of [page].
  AyahRef pageEnd(int page);

  int juzOf(AyahRef ref);
  int hizbOf(AyahRef ref);
}

/// Walking the mushaf: the arithmetic every part of «الحفظ» shares.
abstract final class Mushaf {
  /// How many ayat [range] holds (inclusive, across surahs).
  static int count(MushafShape shape, AyahRange range) => shape.indexOf(range.last) - shape.indexOf(range.first) + 1;

  /// Every ayah of [range] in reading order.
  static List<AyahRef> ayatIn(MushafShape shape, AyahRange range) {
    final from = shape.indexOf(range.first);
    final to = shape.indexOf(range.last);
    if (to < from) return const [];
    return [for (var i = from; i <= to; i++) shape.refAt(i)];
  }

  /// The ayah after [ref], or null at the end of the mushaf.
  static AyahRef? next(MushafShape shape, AyahRef ref) {
    final i = shape.indexOf(ref) + 1;
    return i >= shape.ayahTotal ? null : shape.refAt(i);
  }

  /// The ayah before [ref], or null at the very start.
  static AyahRef? previous(MushafShape shape, AyahRef ref) {
    final i = shape.indexOf(ref) - 1;
    return i < 0 ? null : shape.refAt(i);
  }

  /// [refs] folded into the fewest ranges, in reading order – so «آيات
  /// متفرقة» is shown as «البقرة ١–٥» and not as five lines.
  static List<AyahRange> rangesOf(MushafShape shape, Iterable<AyahRef> refs) {
    final indices = {for (final r in refs) shape.indexOf(r)}.toList()..sort();
    final out = <AyahRange>[];
    var i = 0;
    while (i < indices.length) {
      var j = i;
      while (j + 1 < indices.length && indices[j + 1] == indices[j] + 1) {
        j++;
      }
      out.add(AyahRange(shape.refAt(indices[i]), shape.refAt(indices[j])));
      i = j + 1;
    }
    return out;
  }

  /// [count] ayat starting at [from] (fewer at the end of the mushaf), as a
  /// range; null when [from] is past the end or [count] is not positive.
  static AyahRange? take(MushafShape shape, AyahRef from, int count) {
    if (count <= 0) return null;
    final start = shape.indexOf(from);
    if (start >= shape.ayahTotal) return null;
    var end = start + count - 1;
    if (end >= shape.ayahTotal) end = shape.ayahTotal - 1;
    return AyahRange(shape.refAt(start), shape.refAt(end));
  }

  /// The pages [range] touches, in order.
  static List<int> pagesOf(MushafShape shape, AyahRange range) {
    final first = shape.pageOf(range.first);
    final last = shape.pageOf(range.last);
    return [for (var p = first; p <= last; p++) p];
  }

  /// Whether [range] crosses from one surah into another.
  static bool crossesSurah(AyahRange range) => range.first.surah != range.last.surah;

  /// Whether [range] crosses from one juz' into another.
  static bool crossesJuz(MushafShape shape, AyahRange range) =>
      shape.juzOf(range.first) != shape.juzOf(range.last);

  /// [range] clamped to real ayat of the mushaf (an ayah number past the
  /// end of its surah becomes that surah's last ayah), with its ends
  /// swapped when they were given backwards.
  static AyahRange clamp(MushafShape shape, AyahRange range) {
    AyahRef fix(AyahRef r) {
      final n = shape.ayahCount(r.surah);
      return r.ayah > n ? AyahRef(r.surah, n) : r;
    }

    var first = fix(range.first);
    var last = fix(range.last);
    if (last < first) (first, last) = (last, first);
    return AyahRange(first, last);
  }
}

/// One stretch of the mushaf named by its numbers – the shape every goal,
/// mark and portion is written with. Carries no text.
@immutable
final class MushafStretch {
  const MushafStretch(this.range);

  final AyahRange range;

  AyahRef get first => range.first;
  AyahRef get last => range.last;

  bool contains(AyahRef ref) => range.contains(ref);

  int count(MushafShape shape) => Mushaf.count(shape, range);

  @override
  bool operator ==(Object other) => other is MushafStretch && other.range == range;

  @override
  int get hashCode => range.hashCode;

  @override
  String toString() => 'MushafStretch($range)';
}
