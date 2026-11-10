/// «املأ الفراغ» · fill in the blank (Part 13, step 1).
///
/// Pure Dart. The blanks are chosen **deterministically from a seed**: the
/// same seed and the same range always give the same blanks, on his phone
/// and in a test, today and next month – so a drill can be repeated, shared
/// as a number, and reproduced when something looks wrong. Nothing is
/// chosen at random at run time.
///
/// Only the blanks are scored. Everything else he recites is context: the
/// engine aligns the whole thing (so it knows where he is) and then reports
/// on the blanked words alone.
library;

import 'package:meta/meta.dart';

import 'alignment.dart';
import 'ayah_words.dart';
import 'recogniser.dart';

/// How the blanks are spread.
enum BlankSpread {
  /// Anywhere, as the seed falls (never two next to each other).
  scattered,

  /// Only the last word of each ayah – the rhyme, which is what carries a
  /// verse's join to the next.
  ayahEnds,
}

/// Which words are blank, and why.
@immutable
final class BlankPlan {
  const BlankPlan({required this.target, required this.seed, required this.blanks, required this.spread});

  final RecitationTarget target;

  /// The seed the blanks came from.
  final int seed;

  /// Indices into [RecitationTarget.words], ascending.
  final List<int> blanks;
  final BlankSpread spread;

  int get count => blanks.length;

  bool isBlank(int index) => blanks.contains(index);

  /// The blanked words themselves.
  List<AyahWord> get words => [for (final i in blanks) target.words[i]];

  @override
  String toString() => 'BlankPlan(seed $seed, ${blanks.length} blanks)';
}

/// How one blank went.
@immutable
final class BlankAnswer {
  const BlankAnswer({required this.word, required this.verdict, this.heard, this.hinted = false});

  final AyahWord word;
  final WordVerdict verdict;

  /// What was heard in the blank. **Not Quran text.**
  final String? heard;
  final bool hinted;

  bool get isRight => verdict == WordVerdict.right;

  @override
  String toString() => 'BlankAnswer(${word.ref}#${word.indexInAyah} ${verdict.name})';
}

/// The score of a fill-in-the-blank drill: the blanks only.
@immutable
final class BlankScore {
  const BlankScore({required this.plan, required this.answers, required this.check});

  final BlankPlan plan;
  final List<BlankAnswer> answers;

  /// The full alignment behind it, for a screen that wants to show the
  /// context too. The score below ignores everything but the blanks.
  final RecitationCheck check;

  int get blanks => answers.length;

  int get right => [for (final a in answers) if (a.verdict == WordVerdict.right) a].length;

  int get wrong => [for (final a in answers) if (a.verdict == WordVerdict.wrong) a].length;

  int get skipped => [for (final a in answers) if (a.verdict == WordVerdict.skipped) a].length;

  int get unsure => [for (final a in answers) if (a.verdict == WordVerdict.unsure) a].length;

  int get pending => [for (final a in answers) if (a.verdict == WordVerdict.pending) a].length;

  int get hints => [for (final a in answers) if (a.hinted) a].length;

  /// Right out of the blanks he reached; null when he reached none.
  double? get accuracy {
    final reached = blanks - pending;
    return reached == 0 ? null : right / reached;
  }

  bool get isClean => blanks > 0 && pending == 0 && right == blanks;

  @override
  String toString() => 'BlankScore($right/$blanks)';
}

/// Choosing the blanks, and scoring them.
abstract final class Blanks {
  /// The share of words blanked when the caller does not say.
  static const double defaultShare = 0.25;

  /// Chooses the blanks for [target] from [seed].
  ///
  /// Deterministic by construction: the generator is seeded with [seed]
  /// mixed with the target's own range, so one seed gives each range its
  /// own stable pattern rather than the same word positions everywhere.
  ///
  /// The rules, in order: never the very first word of the target (he needs
  /// somewhere to start), never two blanks side by side, and never more
  /// than there is room for. [count] overrides [share].
  static BlankPlan plan(
    RecitationTarget target, {
    required int seed,
    int? count,
    double share = defaultShare,
    BlankSpread spread = BlankSpread.scattered,
  }) {
    final total = target.wordCount;
    if (spread == BlankSpread.ayahEnds) {
      final ends = [
        for (final a in target.ayat)
          if (a.wordCount > 0 && a.lastWord != 0) a.lastWord,
      ];
      return BlankPlan(target: target, seed: seed, blanks: List.unmodifiable(ends), spread: spread);
    }
    final wanted = count ?? (total * share).round();
    final room = total ~/ 2; // no two side by side, and never word 0
    var take = wanted;
    if (take > room) take = room;
    if (take < 0) take = 0;
    final candidates = [for (var i = 1; i < total; i++) i];
    final order = _shuffled(candidates, _mix(seed, target));
    final chosen = <int>[];
    for (final i in order) {
      if (chosen.length >= take) break;
      if (chosen.any((c) => (c - i).abs() <= 1)) continue;
      chosen.add(i);
    }
    chosen.sort();
    return BlankPlan(target: target, seed: seed, blanks: List.unmodifiable(chosen), spread: spread);
  }

  /// Scores a drill: aligns everything, reports the blanks only.
  static BlankScore score(
    BlankPlan plan,
    List<HeardWord> heard, {
    AlignmentOptions options = const AlignmentOptions(),
    Set<int> hinted = const <int>{},
  }) {
    final check = TasmeeAligner.align(plan.target, heard, options: options.copyWith(hintedWords: hinted));
    return BlankScore(
      plan: plan,
      answers: List.unmodifiable([
        for (final i in plan.blanks)
          BlankAnswer(
            word: check.words[i].word,
            verdict: check.words[i].verdict,
            heard: check.words[i].heard,
            hinted: check.words[i].hinted,
          ),
      ]),
      check: check,
    );
  }

  /// The seed mixed with the range, so one number gives each range its own
  /// pattern. Plain integer arithmetic, so it is identical everywhere.
  static int _mix(int seed, RecitationTarget target) {
    final r = target.range;
    var x = seed & 0x3FFFFFFF;
    for (final part in [r.first.surah, r.first.ayah, r.last.surah, r.last.ayah, target.wordCount]) {
      x = (x * 1103515245 + part * 12345 + 7) & 0x3FFFFFFF;
    }
    return x;
  }

  /// A deterministic shuffle (Fisher-Yates over a small linear generator).
  static List<int> _shuffled(List<int> items, int seed) {
    final out = List<int>.of(items);
    var state = seed == 0 ? 1 : seed;
    for (var i = out.length - 1; i > 0; i--) {
      state = (state * 1103515245 + 12345) & 0x3FFFFFFF;
      final j = (state >> 8) % (i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }
}

/// A running fill-in-the-blank drill: the plan plus what has been heard.
class BlankDrill {
  BlankDrill(this.plan, {this.options = const AlignmentOptions()});

  /// Builds the plan and the drill in one go.
  factory BlankDrill.of(
    RecitationTarget target, {
    required int seed,
    int? count,
    double share = Blanks.defaultShare,
    BlankSpread spread = BlankSpread.scattered,
    AlignmentOptions options = const AlignmentOptions(),
  }) => BlankDrill(
    Blanks.plan(target, seed: seed, count: count, share: share, spread: spread),
    options: options,
  );

  final BlankPlan plan;
  final AlignmentOptions options;
  final List<HeardWord> _heard = [];
  final Set<int> _hinted = <int>{};
  BlankScore? _cached;

  RecitationTarget get target => plan.target;

  void hear(HeardWord word) {
    if (!word.isFinal) return;
    _heard.add(word);
    _cached = null;
  }

  void hearAll(Iterable<HeardWord> words) {
    for (final w in words) {
      hear(w);
    }
  }

  /// He asked to see a blank. Recorded as a hint, exactly like a peek in
  /// the hidden-verse mode.
  AyahWord? peek(int index) {
    if (!plan.isBlank(index)) return null;
    _hinted.add(index);
    _cached = null;
    return target.words[index];
  }

  BlankScore get score => _cached ??= Blanks.score(plan, _heard, options: options, hinted: _hinted);

  /// The text with the blanks taken out, for a screen: every word of the
  /// target, with null where a blank is still unanswered.
  List<String?> get shown {
    final s = score;
    return [
      for (var i = 0; i < target.wordCount; i++)
        if (!plan.isBlank(i) || s.check.words[i].verdict != WordVerdict.pending || _hinted.contains(i))
          target.words[i].text
        else
          null,
    ];
  }

  void reset() {
    _heard.clear();
    _hinted.clear();
    _cached = null;
  }
}
