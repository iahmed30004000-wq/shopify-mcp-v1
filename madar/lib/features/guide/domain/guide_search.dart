/// Search over the guide entries. Arabic-aware through the app's own search
/// folding (`SearchText`): diacritics and tatweel dropped, every alef form,
/// ي/ى and ة/ه treated alike, digits in any script alike, the definite
/// article optional.
library;

import 'package:flutter/foundation.dart';

import '../../search/domain/search_text.dart';
import 'guide_entry.dart';

/// Which part of an entry matched best.
enum GuideMatchField { title, keywords, purpose, doItem, example }

@immutable
class GuideHit {
  const GuideHit(this.entry, this.score, this.field);

  final GuideEntry entry;

  /// Higher is better; only meaningful for comparing hits of one query.
  final double score;
  final GuideMatchField field;
}

class GuideSearch {
  GuideSearch(Iterable<GuideEntry> entries) : _docs = [for (final e in entries) _Doc(e)];

  final List<_Doc> _docs;

  /// Per-field weights: a word in the title beats the same word in an example.
  static const double _wTitle = 100, _wKeywords = 70, _wPurpose = 35, _wDo = 30, _wExample = 20;

  /// An exact word beats a prefix, a prefix beats a one-letter typo.
  static const double _exact = 1, _prefix = 0.8, _typo = 0.45;

  /// Hits for [query], best first (ties keep registry order). Every word of
  /// the query must match something in the entry; the last word may be
  /// unfinished (a prefix). An empty query has no hits.
  List<GuideHit> search(String query, {int limit = 20}) {
    final q = [for (final t in SearchText.terms(query)) _formsOf(t)];
    if (q.isEmpty || limit <= 0) return const [];
    final hits = <(GuideHit, int)>[];
    for (var i = 0; i < _docs.length; i++) {
      final hit = _score(_docs[i], q);
      if (hit != null) hits.add((hit, i));
    }
    // Ties keep the registry order.
    hits.sort((a, b) {
      final c = b.$1.score.compareTo(a.$1.score);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final h in hits.take(limit)) h.$1];
  }

  GuideHit? _score(_Doc d, List<List<String>> q) {
    var total = 0.0;
    var bestField = GuideMatchField.example;
    var bestWord = -1.0;
    for (var w = 0; w < q.length; w++) {
      final isLast = w == q.length - 1;
      var best = 0.0;
      var field = GuideMatchField.example;
      for (final f in d.fields) {
        final s = f.weight * _bestMatch(q[w], f.terms, allowPrefix: isLast || q[w].first.length >= 3);
        if (s > best) {
          best = s;
          field = f.field;
        }
      }
      if (best == 0) return null;
      total += best;
      if (best > bestWord) {
        bestWord = best;
        bestField = field;
      }
    }
    // A title that says the whole query in a row is the answer.
    if (q.length > 1 && d.titleFolded.contains([for (final f in q) f.first].join(' '))) total += 40;
    return GuideHit(d.entry, total, bestField);
  }

  /// 0..1: how well the query word (all its [forms]) matches the best of [terms].
  static double _bestMatch(List<String> forms, List<List<String>> terms, {required bool allowPrefix}) {
    var best = 0.0;
    for (final t in terms) {
      for (final form in t) {
        for (final word in forms) {
          if (form == word) return _exact;
          if (allowPrefix && word.length >= 2 && form.startsWith(word)) {
            if (best < _prefix) best = _prefix;
          } else if (best < _typo && word.length >= 4 && SearchText.prefixWithinOneEdit(word, form)) {
            best = _typo;
          }
        }
      }
    }
    return best;
  }
}

/// A word with the forms it is found by: itself first, then without its
/// article / conjunction, then each of those without a hamza.
List<String> _formsOf(String term) {
  final out = <String>{term};
  for (final v in SearchText.variants(term)) {
    out.add(v.$1);
  }
  for (final f in [...out]) {
    if (SearchText.hasHamza(f)) out.add(SearchText.dropHamza(f));
  }
  return out.toList(growable: false);
}

class _Field {
  _Field(this.field, this.weight, String text) : terms = [for (final t in SearchText.terms(text)) _formsOf(t)];

  final GuideMatchField field;
  final double weight;
  final List<List<String>> terms;
}

class _Doc {
  _Doc(this.entry)
    : titleFolded = SearchText.fold(entry.title),
      fields = [
        _Field(GuideMatchField.title, GuideSearch._wTitle, entry.title),
        _Field(GuideMatchField.keywords, GuideSearch._wKeywords, entry.keywords),
        _Field(GuideMatchField.purpose, GuideSearch._wPurpose, entry.purpose),
        for (final item in entry.doItems) _Field(GuideMatchField.doItem, GuideSearch._wDo, item),
        _Field(GuideMatchField.example, GuideSearch._wExample, entry.example),
      ];

  final GuideEntry entry;
  final String titleFolded;
  final List<_Field> fields;
}
