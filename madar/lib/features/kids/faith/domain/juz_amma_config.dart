// Which surahs of juz' 30 the kids reader offers.
//
// This is CONFIG, not content: the owner / sheikh edits the list (default
// empty => «قريبًا»). Only surah numbers 78..114 count; anything else is
// ignored, so a typo cannot open another part of the Quran to a child.
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int kidsJuzAmmaFirstSurah = 78;
const int kidsJuzAmmaLastSurah = 114;

/// The sheikh-approved surahs, in the order they should be shown.
final kidsJuzAmmaSurahsProvider = Provider<List<int>>((ref) => const []);

/// [configured] cleaned: in range, no repeats, order kept.
List<int> cleanJuzAmmaSurahs(Iterable<int> configured) {
  final seen = <int>{};
  return [
    for (final s in configured)
      if (s >= kidsJuzAmmaFirstSurah && s <= kidsJuzAmmaLastSurah && seen.add(s)) s,
  ];
}
