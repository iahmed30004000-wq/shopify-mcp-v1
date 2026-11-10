/// «شازام القرآن» · recite a phrase, be told where it is (Part 13, step 1).
///
/// Pure Dart, offline, and built **only** over the app's own verified
/// Uthmani text: an n-gram index of folded words (bigrams by default) picks
/// a shortlist, and every shortlisted ayah is then scored by how much of
/// the phrase it really contains, in order and close together. Every
/// position the result reports is a code-unit range of the **original**
/// ayah text.
///
/// **What it decides.** Which ayah a phrase of three words or more comes
/// from, and where inside it.
///
/// **What it refuses to decide.** It never picks one ayah when several fit
/// equally well – «فَبِأَىِّ آلَآءِ رَبِّكُمَا تُكَذِّبَانِ» is in ar-Rahman
/// thirty-one times, and the honest answer is a list, not a guess. It
/// refuses a phrase of fewer than three words (two words are everywhere).
/// It says plainly that it found nothing rather than offering the closest
/// thing it has. And it marks a weak best match as unsure instead of
/// presenting it as the answer.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import 'ayah_words.dart';
import 'recogniser.dart';

/// How much the engine trusts its own answer.
enum ReciteConfidence {
  /// One ayah, and the phrase really is in it.
  sure,

  /// Several ayat fit equally well. The screen must offer them all.
  several,

  /// The best match is partial – offer it, say it is a guess.
  unsure,

  /// Nothing was found. The screen says so; it invents nothing.
  none,

  /// The phrase was too short to place (fewer than
  /// [ReciteIndex.minWords] words).
  tooShort,
}

/// One place the phrase might be.
@immutable
final class RecitePlace {
  const RecitePlace({
    required this.ref,
    required this.index,
    required this.firstWord,
    required this.lastWord,
    required this.ranges,
    required this.matchedWords,
    required this.score,
  });

  final AyahRef ref;

  /// Absolute ayah index in the index's own order.
  final int index;

  /// First and last word of the ayah the phrase covers (0-based inside the
  /// ayah).
  final int firstWord;
  final int lastWord;

  /// Code-unit ranges to highlight **in the original ayah text**, one per
  /// matched word, in order.
  final List<(int, int)> ranges;

  /// How many words of the phrase were found here.
  final int matchedWords;

  /// `0.0 … 1.0`: how much of the phrase is here, and how tightly.
  final double score;

  @override
  String toString() => 'RecitePlace($ref words $firstWord-$lastWord, ${score.toStringAsFixed(2)})';
}

/// The answer to «وين هاي الآية؟».
@immutable
final class ReciteFindResult {
  const ReciteFindResult({
    required this.heardPhrase,
    required this.words,
    required this.places,
    required this.confidence,
    required this.total,
  });

  const ReciteFindResult.nothing(this.heardPhrase, this.words, {this.confidence = ReciteConfidence.none})
    : places = const [],
      total = 0;

  /// The phrase as the recogniser gave it. **Not Quran text** – a screen
  /// shows it as «اللي سمعه التطبيق» if it shows it at all.
  final String heardPhrase;

  /// Its folded words, the ones actually searched for.
  final List<String> words;

  /// The candidates, best first, capped at the query's limit.
  final List<RecitePlace> places;

  final ReciteConfidence confidence;

  /// How many ayat fit as well as the best one (may be more than [places]).
  final int total;

  /// The one answer – **only** when the engine is sure. Null otherwise, on
  /// purpose: the caller has to handle "several" and "none".
  RecitePlace? get only => confidence == ReciteConfidence.sure && places.length == 1 ? places.first : null;

  bool get isEmpty => places.isEmpty;

  @override
  String toString() => 'ReciteFindResult(${confidence.name}, ${places.length}/$total)';
}

/// An n-gram index of the verified text.
///
/// Built once (about 78,000 words of the Hafs text) and then asked as often
/// as he likes. Holds the folded words and their ranges only; the original
/// text stays where it is and is never copied or changed.
class ReciteIndex {
  ReciteIndex._(this._refs, this._words, this._grams, this.gram);

  /// Builds the index from `(ref, verbatim text)` pairs – the app's own
  /// Quran data, in mushaf order.
  ///
  /// [gram] is the n of the n-gram shortlist: 2 is the default because a
  /// single mis-heard word in the middle of a phrase still leaves whole
  /// bigrams on both sides of it, while trigrams would all be broken.
  factory ReciteIndex.build(List<(AyahRef, String)> ayat, {int gram = 2}) {
    if (gram < 1) throw ArgumentError.value(gram, 'gram');
    final refs = <AyahRef>[];
    final words = <List<TextWord>>[];
    final grams = <String, List<int>>{};
    for (var a = 0; a < ayat.length; a++) {
      final (ref, text) = ayat[a];
      final split = TasmeeFold.split(text);
      if (split.length >= _wordsPerAyahLimit) {
        throw StateError('Ayah $ref has ${split.length} words, over the index limit');
      }
      refs.add(ref);
      words.add(split);
      for (var i = 0; i + gram <= split.length; i++) {
        final key = [for (var k = 0; k < gram; k++) split[i + k].folded].join('\u0000');
        (grams[key] ??= <int>[]).add(a * _wordsPerAyahLimit + i);
      }
    }
    return ReciteIndex._(List.unmodifiable(refs), List.unmodifiable(words), grams, gram);
  }

  /// Ayat have at most 129 words in the Hafs text (al-Baqarah 282); this is
  /// the packing base for `(ayah, word)` pairs.
  static const int _wordsPerAyahLimit = 256;

  /// Below three words the engine refuses: two words are everywhere.
  static const int minWords = 3;

  final List<AyahRef> _refs;
  final List<List<TextWord>> _words;
  final Map<String, List<int>> _grams;

  /// The n of the n-gram shortlist.
  final int gram;

  int get ayahCount => _refs.length;

  /// Distinct n-grams held.
  int get gramCount => _grams.length;

  /// Words indexed.
  int get wordCount {
    var n = 0;
    for (final w in _words) {
      n += w.length;
    }
    return n;
  }

  /// Where [phrase] is, if the engine can say.
  ReciteFindResult find(String phrase, {int limit = 20}) => _find(phrase, TasmeeFold.phrase(phrase), limit: limit);

  /// Where the recitation in [heard] is.
  ///
  /// Words the recogniser was not sure about (below [confidenceFloor]) are
  /// dropped rather than searched for: a mis-heard word must not send him
  /// to the wrong surah. Partial hypotheses are dropped too.
  ReciteFindResult findHeard(List<HeardWord> heard, {double confidenceFloor = 0.35, int limit = 20}) {
    final kept = [
      for (final w in heard)
        if (w.isFinal && w.confidence >= confidenceFloor) w,
    ];
    final phrase = kept.map((w) => w.heard).join(' ');
    final words = <String>[];
    for (final w in kept) {
      words.addAll(TasmeeFold.phrase(w.heard));
    }
    return _find(phrase, words, limit: limit);
  }

  ReciteFindResult _find(String phrase, List<String> words, {required int limit}) {
    if (words.length < minWords) {
      return ReciteFindResult.nothing(phrase, List.unmodifiable(words), confidence: ReciteConfidence.tooShort);
    }
    // 1. the n-gram shortlist: every ayah that shares at least one n-gram.
    final votes = <int, int>{};
    for (var i = 0; i + gram <= words.length; i++) {
      final key = [for (var k = 0; k < gram; k++) words[i + k]].join('\u0000');
      final postings = _grams[key];
      if (postings == null) continue;
      for (final packed in postings) {
        final ayah = packed ~/ _wordsPerAyahLimit;
        votes[ayah] = (votes[ayah] ?? 0) + 1;
      }
    }
    if (votes.isEmpty) return ReciteFindResult.nothing(phrase, List.unmodifiable(words));

    // 2. score the shortlist properly: how much of the phrase is really
    //    there, in order, and how tightly packed.
    final shortlist = votes.keys.toList()
      ..sort((a, b) {
        final byVotes = votes[b]!.compareTo(votes[a]!);
        return byVotes != 0 ? byVotes : a.compareTo(b);
      });
    final places = <RecitePlace>[];
    for (final ayah in shortlist.take(_shortlistLimit)) {
      final place = _score(ayah, words);
      if (place != null) places.add(place);
    }
    if (places.isEmpty) return ReciteFindResult.nothing(phrase, List.unmodifiable(words));
    places.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });

    // 3. say how sure we are – and never pick one of several.
    final best = places.first.score;
    final tied = [for (final p in places) if (best - p.score <= _tie) p];
    final ReciteConfidence confidence;
    if (best < _weak) {
      confidence = ReciteConfidence.unsure;
    } else if (tied.length > 1) {
      confidence = ReciteConfidence.several;
    } else if (best >= _certain) {
      confidence = ReciteConfidence.sure;
    } else {
      confidence = ReciteConfidence.unsure;
    }
    final shown = confidence == ReciteConfidence.sure ? tied : places;
    return ReciteFindResult(
      heardPhrase: phrase,
      words: List.unmodifiable(words),
      places: List.unmodifiable(shown.take(limit)),
      confidence: confidence,
      total: confidence == ReciteConfidence.sure ? 1 : tied.length,
    );
  }

  /// At most this many shortlisted ayat are scored properly (the n-gram
  /// votes order them, so the ones left out share fewer n-grams than every
  /// one kept).
  static const int _shortlistLimit = 300;

  /// Scores within this of the best count as equally good.
  static const double _tie = 0.02;

  /// Below this the engine calls its own answer a guess.
  static const double _weak = 0.5;

  /// At or above this, and alone, the engine is sure.
  static const double _certain = 0.8;

  /// How much of [words] ayah [ayah] holds, in order.
  RecitePlace? _score(int ayah, List<String> words) {
    final mine = _words[ayah];
    // Longest common subsequence of the two word sequences, remembering
    // which of the ayah's words took part.
    final n = mine.length;
    final m = words.length;
    final table = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0), growable: false);
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        table[i][j] = mine[i - 1].folded == words[j - 1]
            ? table[i - 1][j - 1] + 1
            : (table[i - 1][j] >= table[i][j - 1] ? table[i - 1][j] : table[i][j - 1]);
      }
    }
    final matched = table[n][m];
    if (matched < minWords) return null;
    final taken = <int>[];
    var i = n;
    var j = m;
    while (i > 0 && j > 0) {
      if (mine[i - 1].folded == words[j - 1] && table[i][j] == table[i - 1][j - 1] + 1) {
        taken.add(i - 1);
        i--;
        j--;
      } else if (table[i - 1][j] >= table[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    final ordered = taken.reversed.toList();
    final first = ordered.first;
    final last = ordered.last;
    final span = last - first + 1;
    final score = (matched / m) * (matched / span);
    return RecitePlace(
      ref: _refs[ayah],
      index: ayah,
      firstWord: first,
      lastWord: last,
      ranges: List.unmodifiable([for (final k in ordered) (mine[k].start, mine[k].end)]),
      matchedWords: matched,
      score: score,
    );
  }
}
