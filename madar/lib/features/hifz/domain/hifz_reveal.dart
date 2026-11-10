import 'package:flutter/foundation.dart';

/// How much of the text a review shows.
enum HifzRevealStage {
  /// Only the shape of each word (pure recall).
  hidden,

  /// The first letter of each word.
  firstLetters,

  /// Words revealed one at a time (the rest keep their first letter).
  words,

  /// The whole text.
  full,
}

/// One token of a text under review: a word to recall, or a marker that is
/// always shown (an ayah number).
@immutable
class HifzToken {
  const HifzToken(this.text, {this.marker = false});

  final String text;
  final bool marker;

  @override
  bool operator ==(Object other) => other is HifzToken && other.text == text && other.marker == marker;

  @override
  int get hashCode => Object.hash(text, marker);

  @override
  String toString() => marker ? '[$text]' : text;
}

/// Progressive reveal of a text (pure).
@immutable
class HifzReveal {
  const HifzReveal({required this.words, this.stage = HifzRevealStage.hidden, this.shown = 0});

  /// Words to recall (markers not counted).
  final int words;
  final HifzRevealStage stage;

  /// Words revealed in [HifzRevealStage.words].
  final int shown;

  bool get isFull => stage == HifzRevealStage.full;

  /// Whether word [i] (0-based among words) is shown in full.
  bool isShown(int i) => stage == HifzRevealStage.full || (stage == HifzRevealStage.words && i < shown);

  /// Whether a hidden word shows its first letter.
  bool get showsFirstLetters => stage != HifzRevealStage.hidden;

  HifzReveal firstLetters() => HifzReveal(words: words, stage: HifzRevealStage.firstLetters);

  /// Reveals the next word (the whole text once the last one is shown).
  HifzReveal nextWord() {
    if (isFull) return this;
    final n = (stage == HifzRevealStage.words ? shown : 0) + 1;
    if (n >= words) return HifzReveal(words: words, stage: HifzRevealStage.full, shown: words);
    return HifzReveal(words: words, stage: HifzRevealStage.words, shown: n);
  }

  /// Reveals up to and including word [i].
  HifzReveal revealTo(int i) {
    if (i + 1 >= words) return HifzReveal(words: words, stage: HifzRevealStage.full, shown: words);
    final n = (stage == HifzRevealStage.words ? shown : 0);
    return HifzReveal(words: words, stage: HifzRevealStage.words, shown: i + 1 > n ? i + 1 : n);
  }

  HifzReveal all() => HifzReveal(words: words, stage: HifzRevealStage.full, shown: words);

  HifzReveal hide() => HifzReveal(words: words);
}

/// Splitting texts into words and finding a word's first letter.
abstract final class HifzText {
  /// Arabic combining marks (harakat, Quranic annotation signs, small high
  /// letters) and the tatweel – they belong to the letter before them.
  static final RegExp _mark = RegExp('[ؐ-ؚـً-ٰٟۖ-ۜ۟-۪ۤۧۨ-ۭ࣓-ࣿ]');

  /// Pause and section signs of the mushaf that stand alone between words
  /// (ۖ ۗ ۚ ۛ ۜ ۞ ۩): joined to the word before them, so they sit above its
  /// last letter as in the printed mushaf.
  static final RegExp _standalone = RegExp('^[ۖ-۞۩]+\$');

  static bool isMark(String ch) => _mark.hasMatch(ch);

  /// Words of [text] (whitespace-separated; pause signs join the previous
  /// word).
  static List<String> words(String text) {
    final out = <String>[];
    for (final w in text.trim().split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      if (out.isNotEmpty && _standalone.hasMatch(w)) {
        out[out.length - 1] = '${out.last}$w';
      } else {
        out.add(w);
      }
    }
    return out;
  }

  /// The first letter of [word] with its marks (`بِسْمِ` → `بِ`), after any
  /// leading punctuation.
  static String firstLetter(String word) {
    final chars = word.runes.map(String.fromCharCode).toList();
    var i = 0;
    while (i < chars.length && !_isLetter(chars[i])) {
      i++;
    }
    if (i >= chars.length) return word;
    final b = StringBuffer(chars.sublist(0, i + 1).join());
    var j = i + 1;
    while (j < chars.length && isMark(chars[j])) {
      b.write(chars[j]);
      j++;
    }
    return b.toString();
  }

  /// Splits [word] after its first letter: (`بِ`, `سْمِ`).
  static (String, String) splitFirst(String word) {
    final head = firstLetter(word);
    return (head, word.substring(head.length));
  }

  static bool _isLetter(String ch) {
    final c = ch.codeUnitAt(0);
    if (isMark(ch)) return false;
    // Arabic letters (incl. alef wasla ٱ and Quranic letters), Latin, digits.
    return (c >= 0x0621 && c <= 0x064A) ||
        (c >= 0x0671 && c <= 0x06D3) ||
        c == 0x06D5 ||
        (c >= 0x06EE && c <= 0x06FF) ||
        (c >= 0x0041 && c <= 0x005A) ||
        (c >= 0x0061 && c <= 0x007A) ||
        (c >= 0x00C0 && c <= 0x024F) ||
        (c >= 0x0030 && c <= 0x0039);
  }

  /// Tokens of an ayah range: each ayah's words followed by its number
  /// marker.
  static List<HifzToken> ayatTokens(List<(int ayah, String text)> ayat, String Function(int ayah) marker) => [
    for (final (n, t) in ayat) ...[for (final w in words(t)) HifzToken(w), HifzToken(marker(n), marker: true)],
  ];

  static List<HifzToken> textTokens(String text) => [for (final w in words(text)) HifzToken(w)];
}
