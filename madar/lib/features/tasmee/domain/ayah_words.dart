/// «التسميع» · the verified text cut into words (Part 13, step 1).
///
/// Pure Dart. Nothing here invents, reflows or regenerates a single letter:
/// a word is a slice of the exact Uthmani text the app already ships, kept
/// verbatim together with **its own code-unit range in that original
/// string**. Comparison happens on a folded copy ([AyahWord.folded], the
/// Quran package's own [ArabicSearch] folding); every position reported
/// anywhere in this engine is a position in the original.
///
/// The Uthmani text writes the pause and hizb signs (`ۖ ۗ ۚ ۛ ۘ ۙ ۞`) as
/// space-separated tokens of their own. They are not recited words, so they
/// are not words here – but they stay inside the original text, and the
/// ranges of the words around them are unaffected.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import '../../quran/domain/arabic_search.dart';

/// One word of the verified text.
@immutable
final class AyahWord {
  const AyahWord({
    required this.ref,
    required this.index,
    required this.indexInAyah,
    required this.text,
    required this.start,
    required this.end,
    required this.folded,
    required this.marks,
  });

  /// Which ayah it belongs to.
  final AyahRef ref;

  /// Position in the whole target, 0-based (a range may span ayat).
  final int index;

  /// Position inside its own ayah, 0-based – what the mistake log stores.
  final int indexInAyah;

  /// The word exactly as the verified text writes it.
  final String text;

  /// Code-unit range `[start, end)` **in the original ayah text**.
  final int start;
  final int end;

  /// The folded form, for comparison only. Never shown.
  final String folded;

  /// The harakat of the word in order, for the experimental tashkeel check
  /// only («ٱلْحَمْدُ» → the sukun, fatha, sukun, damma).
  final String marks;

  @override
  String toString() => 'AyahWord($ref#$indexInAyah $text [$start,$end))';
}

/// One ayah of a target: its ref and the exact text the offsets refer to.
@immutable
final class TargetAyah {
  const TargetAyah({required this.ref, required this.text, required this.firstWord, required this.wordCount});

  final AyahRef ref;

  /// The verbatim text whose code units [AyahWord.start] / [AyahWord.end]
  /// index. The caller decides whether that is the ayah alone or the line
  /// with its basmala; the engine only ever reports into *this* string.
  final String text;

  /// Index of its first word in [RecitationTarget.words].
  final int firstWord;
  final int wordCount;

  int get lastWord => firstWord + wordCount - 1;

  @override
  String toString() => 'TargetAyah($ref, $wordCount words)';
}

/// What he is reciting: an ayah or a range of them, as words of the
/// verified text, plus whatever he is allowed to say before it.
@immutable
final class RecitationTarget {
  const RecitationTarget._({
    required this.range,
    required this.ayat,
    required this.words,
    required this.prelude,
    required this.textSource,
  });

  /// Builds a target from `(ref, verbatim text)` pairs in mushaf order.
  ///
  /// [prelude] holds word sequences he may recite **before** the first ayah
  /// without it counting as a mistake – in practice the basmala, taken from
  /// the same verified text (`QuranText.openingBasmala`), never written out
  /// here. Each entry is a list of words in their original spelling; the
  /// engine folds them itself.
  factory RecitationTarget.of(
    List<(AyahRef, String)> ayat, {
    List<List<String>> prelude = const [],
    String textSource = 'tanzil-uthmani',
  }) {
    if (ayat.isEmpty) throw ArgumentError.value(ayat, 'ayat', 'A target needs at least one ayah');
    final words = <AyahWord>[];
    final targets = <TargetAyah>[];
    for (final (ref, text) in ayat) {
      final first = words.length;
      var inAyah = 0;
      for (final token in TasmeeFold.split(text)) {
        words.add(
          AyahWord(
            ref: ref,
            index: words.length,
            indexInAyah: inAyah++,
            text: token.text,
            start: token.start,
            end: token.end,
            folded: token.folded,
            marks: TasmeeFold.marks(token.text),
          ),
        );
      }
      targets.add(TargetAyah(ref: ref, text: text, firstWord: first, wordCount: words.length - first));
    }
    return RecitationTarget._(
      range: AyahRange(ayat.first.$1, ayat.last.$1),
      ayat: List.unmodifiable(targets),
      words: List.unmodifiable(words),
      prelude: List.unmodifiable([
        for (final p in prelude)
          List<String>.unmodifiable([
            for (final w in p)
              if (ArabicSearch.normalize(w).text.isNotEmpty) w,
          ]),
      ]),
      textSource: textSource,
    );
  }

  /// A single ayah.
  factory RecitationTarget.ayah(
    AyahRef ref,
    String text, {
    List<List<String>> prelude = const [],
    String textSource = 'tanzil-uthmani',
  }) => RecitationTarget.of([(ref, text)], prelude: prelude, textSource: textSource);

  final AyahRange range;

  /// The ayat in order, each with the text its offsets index.
  final List<TargetAyah> ayat;

  /// Every word of the target in order.
  final List<AyahWord> words;

  /// Word sequences allowed before the first ayah (the basmala).
  final List<List<String>> prelude;

  /// Which text the words came from, written into the log and the export so
  /// a result is never read against a different edition.
  final String textSource;

  int get wordCount => words.length;

  /// The ayah [word] belongs to.
  TargetAyah ayahOf(AyahWord word) => ayat.firstWhere((a) => a.ref == word.ref);

  /// The verbatim text of [ref] inside this target (the offsets' string).
  String textOf(AyahRef ref) => ayat.firstWhere((a) => a.ref == ref).text;

  /// Whether a word at [index] starts an ayah.
  bool startsAyah(int index) => ayat.any((a) => a.firstWord == index);

  /// First word index of the ayah containing word [index].
  int ayahStartOf(int index) {
    for (final a in ayat) {
      if (index >= a.firstWord && index <= a.lastWord) return a.firstWord;
    }
    return 0;
  }

  /// The folded prelude sequences, longest first (so the basmala wins over
  /// a prefix of it).
  List<List<String>> get foldedPrelude {
    final out = [
      for (final p in prelude) [for (final w in p) ArabicSearch.normalize(w).text],
    ]..sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  @override
  String toString() => 'RecitationTarget($range, $wordCount words)';
}

/// One word of a text: verbatim, where it is, and its folded form.
@immutable
final class TextWord {
  const TextWord({required this.text, required this.start, required this.end, required this.folded});

  /// The word exactly as the text writes it.
  final String text;

  /// Code-unit range `[start, end)` in that text.
  final int start;
  final int end;

  /// The folded form, for comparison only.
  final String folded;

  @override
  String toString() => 'TextWord($text [$start,$end))';
}

/// The two folds «التسميع» needs, on top of the Quran package's own.
abstract final class TasmeeFold {
  /// The project's folding of one word, for comparison only.
  static String word(String text) => ArabicSearch.normalize(text).text;

  /// [text] cut into words at its spaces, keeping each word's own range in
  /// the original. Tokens that fold to nothing – the Uthmani pause and hizb
  /// signs (`ۖ ۗ ۚ ۛ ۘ ۙ ۞`), punctuation, a stray number – are **not**
  /// words and are left out, while the ranges of the real words around them
  /// stay exactly as they are in the original.
  static List<TextWord> split(String text) {
    final out = <TextWord>[];
    var start = -1;
    void close(int end) {
      if (start < 0) return;
      final raw = text.substring(start, end);
      final folded = word(raw);
      if (folded.isNotEmpty) out.add(TextWord(text: raw, start: start, end: end, folded: folded));
      start = -1;
    }

    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      final space = c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || c == 0x200F;
      if (space) {
        close(i);
      } else if (start < 0) {
        start = i;
      }
    }
    close(text.length);
    return out;
  }

  /// Every word of a phrase folded, dropping tokens that fold to nothing
  /// (a pause sign, punctuation, a stray number).
  static List<String> phrase(String text) => [
    for (final part in text.split(RegExp(r'\s+')))
      if (word(part).isNotEmpty) word(part),
  ];

  /// The harakat of [text] in order – fatha, kasra, damma, their tanween
  /// forms, shadda, sukun and the superscript alef – and nothing else.
  ///
  /// Used **only** by the experimental tashkeel check, which is off by
  /// default: when the recogniser's output carries no marks at all this is
  /// empty and the check reports [TashkeelCheck.notChecked] rather than
  /// inventing a mistake.
  static String marks(String text) {
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if ((c >= 0x064B && c <= 0x0652) || c == 0x0670) out.writeCharCode(c);
    }
    return out.toString();
  }

  /// How alike two folded words are, `0.0 … 1.0` (a normalised edit
  /// distance over their letters).
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final longest = a.length > b.length ? a.length : b.length;
    return 1.0 - distance(a, b) / longest;
  }

  /// Levenshtein distance between two folded words.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i, growable: false);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= b.length; j++) {
        final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        var best = deletion < insertion ? deletion : insertion;
        if (substitution < best) best = substitution;
        current[j] = best;
      }
      previous = List<int>.of(current, growable: false);
    }
    return previous[b.length];
  }
}

/// Whether the diacritics matched – **experimental and off by default**.
enum TashkeelCheck {
  /// Not asked for, or the recogniser gave no diacritics at all. The engine
  /// says nothing rather than guessing.
  notChecked,

  /// The harakat matched.
  same,

  /// The letters matched and the harakat did not. Labelled as experimental
  /// wherever it is shown, and never on its own a mistake.
  different,
}
