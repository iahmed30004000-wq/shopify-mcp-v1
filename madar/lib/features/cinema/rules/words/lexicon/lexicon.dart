/// The Arabic game lexicon (assets/games/arabic_lexicon.txt).
///
/// One entry per line, most frequent first: `word[<TAB>vowelled]`; lines
/// starting with `#` are comments. The rank of a word is its position among
/// the entries (1 = most frequent). Words are plain letters (see
/// [ArabicText.plain]), 3–8 letters long. Frequencies come from Arabic
/// Wikipedia word counts; Madar's curated words carry a vowelled display
/// form. Blocked words were removed at build time.
library;

import '../core/arabic_text.dart';

/// One lexicon entry.
final class LexiconEntry {
  /// Creates an entry.
  const LexiconEntry(this.word, this.rank, [this.vowelled]);

  /// Plain letters.
  final String word;

  /// Frequency rank, 1 = most frequent.
  final int rank;

  /// Vowelled display form (curated words only).
  final String? vowelled;

  /// The form to display: vowelled when available.
  String get display => vowelled ?? word;

  /// Letter count.
  int get length => word.length;
}

/// The parsed lexicon with fast lookups.
final class ArabicLexicon {
  ArabicLexicon._(this.entries)
    : _byWord = {for (final e in entries) e.word: e},
      _byKey = _index(entries);

  /// Parses the lexicon text file.
  factory ArabicLexicon.parse(String text) {
    final entries = <LexiconEntry>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty || line.startsWith('#')) continue;
      final tab = line.indexOf('\t');
      final word = tab < 0 ? line : line.substring(0, tab);
      final vowelled = tab < 0 ? null : line.substring(tab + 1);
      entries.add(LexiconEntry(word, entries.length + 1, vowelled));
    }
    return ArabicLexicon._(List.unmodifiable(entries));
  }

  /// Builds a lexicon from words in frequency order (tests).
  factory ArabicLexicon.fromWords(Iterable<String> words) {
    var rank = 0;
    return ArabicLexicon._(List.unmodifiable([for (final w in words) LexiconEntry(ArabicText.plain(w), ++rank)]));
  }

  static Map<String, LexiconEntry> _index(List<LexiconEntry> entries) {
    final m = <String, LexiconEntry>{};
    for (final e in entries) {
      m.putIfAbsent(ArabicText.lookupKey(e.word), () => e);
    }
    return m;
  }

  /// All entries in rank order.
  final List<LexiconEntry> entries;
  final Map<String, LexiconEntry> _byWord;
  final Map<String, LexiconEntry> _byKey;
  final Map<int, List<LexiconEntry>> _byLength = {};

  /// Number of entries.
  int get length => entries.length;

  /// The entry spelled exactly [word] (plain letters), if any.
  LexiconEntry? exact(String word) => _byWord[ArabicText.plain(word)];

  /// The most frequent entry sharing [word]'s lookup key (hamza / alef /
  /// taa-marbuta spelling variants match).
  LexiconEntry? lookup(String word) => _byKey[ArabicText.lookupKey(word)];

  /// Whether [word] (in any common spelling) is in the lexicon.
  bool contains(String word) => lookup(word) != null;

  /// Frequency rank of [word] or null.
  int? rankOf(String word) => lookup(word)?.rank;

  /// Entries of exactly [letters] letters, in rank order.
  List<LexiconEntry> ofLength(int letters) =>
      _byLength.putIfAbsent(letters, () => List.unmodifiable(entries.where((e) => e.length == letters)));

  /// Relative frequency of each game letter over the [top] most frequent
  /// entries (used to fill word-search grids with natural-looking letters).
  Map<String, double> letterWeights({int top = 20000}) {
    final counts = <String, double>{};
    for (final e in entries.take(top)) {
      for (var i = 0; i < e.word.length; i++) {
        counts.update(e.word[i], (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final total = counts.values.fold<double>(0, (a, b) => a + b);
    return {for (final e in counts.entries) e.key: e.value / total};
  }
}
