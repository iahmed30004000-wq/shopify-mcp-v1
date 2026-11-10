/// Search over the budget tree for the picker (pure Dart).
library;

import '../../../../core/domain/money.dart';

abstract final class BudgetSearch {
  static final RegExp _diacritics = RegExp('[ً-ٰٟـ]');

  /// Lower-cased [text] with Arabic letter variants folded (أ إ آ → ا,
  /// ة → ه, ى → ي, ؤ → و, ئ → ي), diacritics and tatweel removed and digits
  /// in any script made ASCII.
  static String fold(String text) {
    var s = MoneyText.foldDigits(text).toLowerCase().replaceAll(_diacritics, '');
    s = s
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    return s.trim();
  }

  /// Ids to show for [query] in a tree given as depth-first `(id, parentId,
  /// name)` entries: every match plus its ancestors (so the path stays
  /// readable), in tree order. Everything for an empty query.
  static List<String> filter(List<({String id, String? parentId, String name})> tree, String query) {
    final q = fold(query);
    if (q.isEmpty) return [for (final e in tree) e.id];
    final parents = {for (final e in tree) e.id: e.parentId};
    final keep = <String>{};
    for (final e in tree) {
      if (!fold(e.name).contains(q)) continue;
      String? cur = e.id;
      while (cur != null && keep.add(cur)) {
        cur = parents[cur];
      }
    }
    return [
      for (final e in tree)
        if (keep.contains(e.id)) e.id,
    ];
  }
}
