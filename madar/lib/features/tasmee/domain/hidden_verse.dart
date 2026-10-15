/// «الآية المخفية» · the hidden-verse machine (Part 13, step 1).
///
/// Pure Dart. The page starts hidden and a word appears **only** because
/// the alignment says he recited it – never because a timer went off and
/// never because the engine got bored. Tapping to peek reveals one word and
/// **is recorded as a hint**, so the strength Part 14 computes from these
/// results is honest about what he actually remembered.
///
/// It holds no audio: it is fed [HeardWord]s and keeps nothing but words,
/// times and confidences.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import 'alignment.dart';
import 'ayah_words.dart';
import 'recogniser.dart';

/// How one word of the page is shown.
enum WordState {
  /// Still hidden: he has not got there.
  hidden,

  /// Revealed because he recited it.
  revealed,

  /// Revealed because he asked to see it – a hint.
  peeked,

  /// He said something else here, so the real word is shown with the
  /// mistake.
  wrong,

  /// He went past it.
  skipped,

  /// Something was heard here and the recogniser was not sure. Shown as
  /// "not sure", never as a mistake.
  unsure,
}

/// One word of the page as the screen should draw it.
@immutable
final class WordReveal {
  const WordReveal({required this.word, required this.state, this.heard});

  final AyahWord word;
  final WordState state;

  /// What was heard in its place, when something was. **Not Quran text.**
  final String? heard;

  /// Whether the verified word may be drawn at all.
  bool get isVisible => state != WordState.hidden;

  /// The letters the screen may draw – the verified word when it is
  /// visible, and otherwise null (so a screen cannot leak it by accident).
  String? get text => isVisible ? word.text : null;

  @override
  String toString() => 'WordReveal(${word.ref}#${word.indexInAyah} ${state.name})';
}

/// The hidden-verse mode over one ayah or a range of them.
class HiddenVerseMachine {
  HiddenVerseMachine({required this.target, AlignmentOptions options = const AlignmentOptions()})
    : _options = options.copyWith(hintedWords: <int>{});

  final RecitationTarget target;
  AlignmentOptions _options;
  final List<HeardWord> _heard = [];
  final Set<int> _peeked = <int>{};
  RecitationCheck? _cached;

  /// Every word he was shown without reciting it, in order.
  List<int> get hints => _peeked.toList()..sort();

  int get hintCount => _peeked.length;

  /// What the recogniser has reported so far (final words only).
  int get heardCount => _heard.length;

  /// Whether the experimental tashkeel check is on.
  bool get tashkeelChecked => _options.checkTashkeel;

  /// Turns the **experimental** tashkeel check on or off mid-session.
  void setTashkeelCheck(bool on) {
    if (_options.checkTashkeel == on) return;
    _options = _options.copyWith(checkTashkeel: on);
    _cached = null;
  }

  /// One more word from the recogniser.
  void hear(HeardWord word) {
    if (!word.isFinal) return; // a guess it may still revise never scores
    _heard.add(word);
    _cached = null;
  }

  /// Several at once.
  void hearAll(Iterable<HeardWord> words) {
    for (final w in words) {
      hear(w);
    }
  }

  /// He tapped a hidden word to see it. **Counted as a hint.** Returns the
  /// word so the screen can show it, or null when [index] is not a word of
  /// the target.
  AyahWord? peek(int index) {
    if (index < 0 || index >= target.wordCount) return null;
    _peeked.add(index);
    _cached = null;
    return target.words[index];
  }

  /// He tapped «ورّيني كلمة» without choosing one: the next word he has not
  /// reached yet. Returns null when there is nothing left to reveal.
  AyahWord? peekNext() {
    final at = cursor;
    return at == null ? null : peek(at);
  }

  /// The check as it stands, recomputed only when something changed.
  RecitationCheck get check =>
      _cached ??= TasmeeAligner.align(target, _heard, options: _options.copyWith(hintedWords: _peeked));

  /// The word he is expected to say next, or null when the page is done.
  int? get cursor => check.cursor;

  /// Whether every word has been recited (a peek does not finish a word –
  /// he still has to say it).
  bool get isComplete => check.counts.pending == 0;

  /// The whole page as the screen should draw it.
  List<WordReveal> get page => [
    for (final w in check.words)
      WordReveal(
        word: w.word,
        state: switch (w.verdict) {
          WordVerdict.right => WordState.revealed,
          WordVerdict.wrong => WordState.wrong,
          WordVerdict.skipped => WordState.skipped,
          WordVerdict.unsure => WordState.unsure,
          WordVerdict.pending => _peeked.contains(w.word.index) ? WordState.peeked : WordState.hidden,
        },
        heard: w.heard,
      ),
  ];

  /// The page of one ayah of the range.
  List<WordReveal> ayahPage(AyahRef ref) {
    final a = target.ayat.firstWhere((x) => x.ref == ref);
    return page.sublist(a.firstWord, a.firstWord + a.wordCount);
  }

  /// Words revealed by reciting them (peeks excluded).
  int get revealedCount => check.counts.right;

  /// Starts over on the same target: nothing heard, nothing peeked.
  void reset() {
    _heard.clear();
    _peeked.clear();
    _cached = null;
  }
}
