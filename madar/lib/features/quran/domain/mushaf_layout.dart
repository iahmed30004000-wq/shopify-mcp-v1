import 'package:meta/meta.dart';

import 'quran_meta.dart';

/// A piece of a mushaf page, top to bottom.
@immutable
sealed class PageBlock {
  const PageBlock();
}

/// The ornamental sura title where a sura begins.
class SurahHeaderBlock extends PageBlock {
  const SurahHeaderBlock(this.surah);

  final SurahInfo surah;

  @override
  bool operator ==(Object other) => other is SurahHeaderBlock && other.surah.number == surah.number;

  @override
  int get hashCode => surah.number;
}

/// The basmala under a sura title (not for al-Fatihah – where it is the
/// first ayah – nor at-Tawbah).
class BasmalaBlock extends PageBlock {
  const BasmalaBlock(this.surah);

  final SurahInfo surah;

  @override
  bool operator ==(Object other) => other is BasmalaBlock && other.surah.number == surah.number;

  @override
  int get hashCode => -surah.number;
}

/// Consecutive ayat of one sura, flowing as one paragraph.
class AyatBlock extends PageBlock {
  const AyatBlock(this.surah, this.indices);

  final SurahInfo surah;

  /// Absolute ayah indices.
  final List<int> indices;

  @override
  bool operator ==(Object other) =>
      other is AyatBlock && other.surah.number == surah.number && _listEquals(other.indices, indices);

  @override
  int get hashCode => Object.hash(surah.number, Object.hashAll(indices));

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Splits a Madani page into titles, basmalas and ayat.
abstract final class MushafLayout {
  static List<PageBlock> page(QuranMeta meta, int page) {
    final out = <PageBlock>[];
    final ayat = meta.ayatOnPage(page);
    var i = 0;
    while (i < ayat.length) {
      final surah = meta.surah(ayat[i].surah);
      if (ayat[i].ayah == 1) {
        out.add(SurahHeaderBlock(surah));
        if (surah.hasBasmalaHeader) out.add(BasmalaBlock(surah));
      }
      final indices = <int>[];
      while (i < ayat.length && ayat[i].surah == surah.number) {
        indices.add(meta.indexOf(ayat[i]));
        i++;
      }
      out.add(AyatBlock(surah, indices));
    }
    return out;
  }
}
