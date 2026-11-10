/// «التسميع» · aligning what was heard against the verified text
/// (Part 13, step 1).
///
/// Pure Dart. The input is a [RecitationTarget] built from the app's own
/// Uthmani text and a list of [HeardWord]s from a [QuranRecogniser]; the
/// output is one verdict per **word of the verified text** – right · wrong ·
/// skipped – plus the words that were heard and are not in the text at all,
/// each with **its position in the original text**.
///
/// **What this engine decides.** Which word of the verified text each heard
/// word belongs to; that a word was replaced, skipped or added; that a run
/// of added words is the basmala, or words of the text said again (a
/// restart, a verse recited twice); that the reciter stopped for a while;
/// and that the words he has not reached yet are *not* mistakes.
///
/// **What it refuses to decide.** Whether a repetition was a restart or a
/// deliberate second recitation – it says only «these were words of the
/// text, said again». Whether a word the recogniser was unsure about was
/// right or wrong – it reports [WordVerdict.unsure] and counts no mistake.
/// Whether the diacritics were right, unless the caller switches the
/// experimental check on *and* the recogniser actually produced diacritics.
/// Whether he recited well: the result is a hint for him, never a ruling,
/// and nothing here is pronunciation (makharij), which Part 13 leaves out
/// on purpose.
///
/// **Folding.** Comparison runs on the Quran package's own folding
/// ([ArabicSearch]), so the Uthmani spelling and the everyday spelling of
/// the same word are the same word («ٱلرَّحْمَـٰنِ» = «الرحمن»), and the
/// joined Uthmani «يَـٰٓأَيُّهَا» still matches a reciter heard as two words
/// «يا أيها». Positions, text and lengths are always from the original.
library;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import 'ayah_words.dart';
import 'recogniser.dart';

/// The verdict on one word of the verified text.
enum WordVerdict {
  /// He recited it.
  right,

  /// He said a different word in its place.
  wrong,

  /// He went past it without saying it.
  skipped,

  /// Something was heard in its place but the recogniser was not sure
  /// enough to judge it. **Never counted as a mistake.**
  unsure,

  /// He has not reached it yet (or he stopped before it). Not a mistake.
  pending,
}

/// Why a word that is not in the text was heard.
enum ExtraReason {
  /// A word that is not in the text here at all – the only kind that
  /// counts as a mistake.
  inserted,

  /// Words of the verified text, said again: he restarted the verse, or
  /// recited it twice. The engine does not claim to know which.
  repetition,

  /// The basmala (or another prelude the caller allowed) before the first
  /// ayah of the target.
  prelude,

  /// The recogniser was too unsure for this to be called anything.
  unsure,
}

/// One word of the verified text, judged.
@immutable
final class WordCheck {
  const WordCheck({
    required this.word,
    required this.verdict,
    this.heard,
    this.confidence,
    this.at,
    this.tashkeel = TashkeelCheck.notChecked,
    this.hinted = false,
  });

  /// The verified word, with its own position in the original text.
  final AyahWord word;
  final WordVerdict verdict;

  /// What the recogniser thought it heard in this word's place – **not
  /// Quran text**, and never to be rendered as such. Null when nothing was
  /// heard here.
  final String? heard;

  final double? confidence;

  /// When it was heard, from the start of listening.
  final Duration? at;

  /// The experimental diacritics check; [TashkeelCheck.notChecked] unless
  /// the caller asked for it and the recogniser gave diacritics.
  final TashkeelCheck tashkeel;

  /// A peek revealed this word, so the result is not his memory alone.
  final bool hinted;

  AyahRef get ref => word.ref;

  /// Whether this counts against him.
  bool get isMistake => verdict == WordVerdict.wrong || verdict == WordVerdict.skipped;

  WordCheck copyWith({WordVerdict? verdict, TashkeelCheck? tashkeel, bool? hinted}) => WordCheck(
    word: word,
    verdict: verdict ?? this.verdict,
    heard: heard,
    confidence: confidence,
    at: at,
    tashkeel: tashkeel ?? this.tashkeel,
    hinted: hinted ?? this.hinted,
  );

  @override
  String toString() => 'WordCheck(${word.ref}#${word.indexInAyah} ${verdict.name}'
      '${heard == null ? '' : ' heard "$heard"'})';
}

/// A word that was heard and is not in the text at that place.
@immutable
final class ExtraWord {
  const ExtraWord({
    required this.heard,
    required this.ref,
    required this.beforeWord,
    required this.beforeWordInAyah,
    required this.atCodeUnit,
    required this.reason,
    this.confidence,
    this.at,
  });

  /// What was heard. **Not Quran text.**
  final String heard;

  /// The ayah it was heard inside.
  final AyahRef ref;

  /// The word of the whole target it came before (`wordCount` = after the
  /// last word).
  final int beforeWord;

  /// The same position inside [ref]'s own words.
  final int beforeWordInAyah;

  /// Code-unit position **in the original text of [ref]** where it was
  /// heard – the start of the word it came before, or the end of the last
  /// word when it came after everything.
  final int atCodeUnit;

  final ExtraReason reason;
  final double? confidence;
  final Duration? at;

  /// Only a genuinely inserted word is a mistake.
  bool get isMistake => reason == ExtraReason.inserted;

  @override
  String toString() => 'ExtraWord("$heard" before $ref#$beforeWordInAyah, ${reason.name})';
}

/// A silence long enough to notice. Never a mistake: he is allowed to
/// breathe, to stop and to come back.
@immutable
final class HeardPause {
  const HeardPause({required this.beforeWord, required this.at, required this.length});

  /// The word of the target the recitation came back on (`wordCount` when
  /// he never came back).
  final int beforeWord;

  /// When the silence started, from the start of listening.
  final Duration at;
  final Duration length;

  @override
  String toString() => 'HeardPause(${length.inMilliseconds}ms before word $beforeWord)';
}

/// How the aligner should behave.
@immutable
final class AlignmentOptions {
  const AlignmentOptions({
    this.confidenceFloor = 0.35,
    this.checkTashkeel = false,
    this.pauseAfter = const Duration(milliseconds: 2500),
    this.countUnreachedAsSkipped = false,
    this.hintedWords = const <int>{},
    this.maxJoin = 3,
  }) : assert(confidenceFloor >= 0.0 && confidenceFloor < 1.0),
       assert(maxJoin >= 1);

  /// Below this confidence the recogniser's word can never produce a
  /// mistake: a replacement becomes [WordVerdict.unsure] and an addition
  /// becomes [ExtraReason.unsure]. This is the answer to the owner's own
  /// risk note – a model that mishears must not invent mistakes.
  final double confidenceFloor;

  /// The **experimental** diacritics check. Off by default, word level
  /// first, and it never changes a verdict.
  final bool checkTashkeel;

  /// A silence at least this long is recorded as a [HeardPause].
  final Duration pauseAfter;

  /// Whether words he never reached count as skipped. Off: the engine does
  /// not call a word he never got to a mistake.
  final bool countUnreachedAsSkipped;

  /// Words a peek revealed (indices into [RecitationTarget.words]).
  final Set<int> hintedWords;

  /// How many heard words may make up one word of the verified text, and
  /// the other way round (the Uthmani script joins what the everyday
  /// spelling writes apart).
  final int maxJoin;

  AlignmentOptions copyWith({bool? checkTashkeel, Set<int>? hintedWords, bool? countUnreachedAsSkipped}) =>
      AlignmentOptions(
        confidenceFloor: confidenceFloor,
        checkTashkeel: checkTashkeel ?? this.checkTashkeel,
        pauseAfter: pauseAfter,
        countUnreachedAsSkipped: countUnreachedAsSkipped ?? this.countUnreachedAsSkipped,
        hintedWords: hintedWords ?? this.hintedWords,
        maxJoin: maxJoin,
      );
}

/// Counts of one check (a whole target or a single ayah).
@immutable
final class RecitationCounts {
  const RecitationCounts({
    required this.words,
    required this.right,
    required this.wrong,
    required this.skipped,
    required this.unsure,
    required this.pending,
    required this.extras,
    required this.hints,
    required this.tashkeelDifferent,
  });

  static const RecitationCounts zero = RecitationCounts(
    words: 0,
    right: 0,
    wrong: 0,
    skipped: 0,
    unsure: 0,
    pending: 0,
    extras: 0,
    hints: 0,
    tashkeelDifferent: 0,
  );

  final int words;
  final int right;
  final int wrong;
  final int skipped;
  final int unsure;
  final int pending;

  /// Genuinely inserted words only.
  final int extras;
  final int hints;

  /// Words whose letters matched and whose harakat did not (experimental).
  final int tashkeelDifferent;

  /// Words he actually reached.
  int get reached => right + wrong + skipped + unsure;

  int get mistakes => wrong + skipped + extras;

  /// Right out of what he reached, `0.0 … 1.0`; null when he reached
  /// nothing (the engine says "no result", not "zero").
  double? get accuracy => reached == 0 ? null : right / reached;

  /// Nothing wrong, nothing skipped, nothing inserted – and he reached at
  /// least one word.
  bool get isClean => reached > 0 && mistakes == 0;

  Map<String, Object?> toJson() => {
    'words': words,
    'right': right,
    'wrong': wrong,
    'skipped': skipped,
    'unsure': unsure,
    'pending': pending,
    'extras': extras,
    'hints': hints,
    'tashkeelDifferent': tashkeelDifferent,
  };

  @override
  String toString() => 'RecitationCounts(right $right, wrong $wrong, skipped $skipped, extra $extras)';
}

/// One ayah of a check.
@immutable
final class AyahCheck {
  const AyahCheck({required this.ref, required this.words, required this.extras, required this.counts});

  final AyahRef ref;
  final List<WordCheck> words;
  final List<ExtraWord> extras;
  final RecitationCounts counts;

  @override
  String toString() => 'AyahCheck($ref, $counts)';
}

/// The whole result of checking a recitation against the verified text.
///
/// Holds no audio, no recording, no file – there is nothing here to delete
/// after scoring because there was never anything to keep.
@immutable
final class RecitationCheck {
  const RecitationCheck({
    required this.target,
    required this.words,
    required this.extras,
    required this.pauses,
    required this.counts,
    required this.heardWords,
    required this.listenedFor,
    this.tashkeelChecked = false,
  });

  final RecitationTarget target;

  /// One entry per word of the verified text, in order.
  final List<WordCheck> words;
  final List<ExtraWord> extras;
  final List<HeardPause> pauses;
  final RecitationCounts counts;

  /// How many final words the recogniser produced.
  final int heardWords;

  /// How long the recitation ran.
  final Duration listenedFor;

  /// Whether the experimental diacritics check was on.
  final bool tashkeelChecked;

  AyahRange get range => target.range;

  /// Only the mistakes, in order: wrong and skipped words first, then the
  /// inserted words.
  List<WordCheck> get wrongOrSkipped => [for (final w in words) if (w.isMistake) w];

  List<ExtraWord> get inserted => [for (final e in extras) if (e.isMistake) e];

  /// The result sliced per ayah, in mushaf order.
  List<AyahCheck> get ayat => [
    for (final a in target.ayat)
      () {
        final mine = words.sublist(a.firstWord, a.firstWord + a.wordCount);
        final theirs = [for (final e in extras) if (e.ref == a.ref) e];
        return AyahCheck(ref: a.ref, words: mine, extras: theirs, counts: _count(mine, theirs));
      }(),
  ];

  AyahCheck ayah(AyahRef ref) => ayat.firstWhere((a) => a.ref == ref);

  /// The word he is expected to say next, or null when he finished.
  int? get cursor {
    for (var i = 0; i < words.length; i++) {
      if (words[i].verdict == WordVerdict.pending) return i;
    }
    return null;
  }

  bool get isClean => counts.isClean;

  @override
  String toString() => 'RecitationCheck($range, $counts)';

  static RecitationCounts _count(List<WordCheck> words, List<ExtraWord> extras) {
    var right = 0, wrong = 0, skipped = 0, unsure = 0, pending = 0, hints = 0, tashkeel = 0;
    for (final w in words) {
      switch (w.verdict) {
        case WordVerdict.right:
          right++;
        case WordVerdict.wrong:
          wrong++;
        case WordVerdict.skipped:
          skipped++;
        case WordVerdict.unsure:
          unsure++;
        case WordVerdict.pending:
          pending++;
      }
      if (w.hinted) hints++;
      if (w.tashkeel == TashkeelCheck.different) tashkeel++;
    }
    return RecitationCounts(
      words: words.length,
      right: right,
      wrong: wrong,
      skipped: skipped,
      unsure: unsure,
      pending: pending,
      extras: [for (final e in extras) if (e.isMistake) e].length,
      hints: hints,
      tashkeelDifferent: tashkeel,
    );
  }
}

// --------------------------------------------------------------------------

const int _opMatch = 0;
const int _opSub = 1;
const int _opSkip = 2;
const int _opExtra = 3;
const int _opJoinHeard = 4; // one verified word = several heard words
const int _opJoinWords = 5; // several verified words = one heard word

/// The aligner itself: one pure function and the small machinery behind it.
abstract final class TasmeeAligner {
  /// Judges [heard] against [target].
  ///
  /// Partial hypotheses (`isFinal == false`) are dropped: a guess the model
  /// may still revise never scores. Everything else is aligned with a
  /// word-level edit distance that also knows how to join words, because
  /// the Uthmani script writes some words joined.
  static RecitationCheck align(
    RecitationTarget target,
    List<HeardWord> heard, {
    AlignmentOptions options = const AlignmentOptions(),
  }) {
    final said = [for (final w in heard) if (w.isFinal) w];
    final expected = target.words;
    final saidFolded = [for (final w in said) TasmeeFold.word(w.heard)];
    final e = expected.length;
    final h = said.length;

    // ---- the table -------------------------------------------------------
    final cost = List.generate(e + 1, (_) => List<double>.filled(h + 1, 0), growable: false);
    final op = List.generate(e + 1, (_) => List<int>.filled(h + 1, -1), growable: false);
    final backI = List.generate(e + 1, (_) => List<int>.filled(h + 1, 0), growable: false);
    final backJ = List.generate(e + 1, (_) => List<int>.filled(h + 1, 0), growable: false);
    for (var i = 1; i <= e; i++) {
      cost[i][0] = i.toDouble();
      op[i][0] = _opSkip;
      backI[i][0] = i - 1;
      backJ[i][0] = 0;
    }
    for (var j = 1; j <= h; j++) {
      cost[0][j] = j.toDouble();
      op[0][j] = _opExtra;
      backI[0][j] = 0;
      backJ[0][j] = j - 1;
    }
    const joinPenalty = 0.001; // a plain one-to-one match is still preferred
    for (var i = 1; i <= e; i++) {
      final want = expected[i - 1].folded;
      for (var j = 1; j <= h; j++) {
        var best = double.infinity;
        var bestOp = -1;
        var bi = 0;
        var bj = 0;
        void offer(double c, int kind, int fi, int fj) {
          if (c < best) {
            best = c;
            bestOp = kind;
            bi = fi;
            bj = fj;
          }
        }

        final got = saidFolded[j - 1];
        // 1. the same word.
        if (want == got) offer(cost[i - 1][j - 1], _opMatch, i - 1, j - 1);
        // 2. one verified word heard as several («يَـٰٓأَيُّهَا» → «يا أيها»).
        for (var k = 2; k <= options.maxJoin && k <= j; k++) {
          final joined = saidFolded.sublist(j - k, j).join();
          if (joined == want) offer(cost[i - 1][j - k] + joinPenalty, _opJoinHeard, i - 1, j - k);
        }
        // 3. several verified words heard as one.
        for (var m = 2; m <= options.maxJoin && m <= i; m++) {
          final joined = [for (var x = i - m; x < i; x++) expected[x].folded].join();
          if (joined == got) offer(cost[i - m][j - 1] + joinPenalty, _opJoinWords, i - m, j - 1);
        }
        // 4. a different word in its place.
        offer(cost[i - 1][j - 1] + _subCost(want, got), _opSub, i - 1, j - 1);
        // 5. he went past it.
        offer(cost[i - 1][j] + 1.0, _opSkip, i - 1, j);
        // 6. he said something that is not here.
        offer(cost[i][j - 1] + 1.0, _opExtra, i, j - 1);
        cost[i][j] = best;
        op[i][j] = bestOp;
        backI[i][j] = bi;
        backJ[i][j] = bj;
      }
    }

    // ---- walk it back ----------------------------------------------------
    final verdicts = List<WordVerdict>.filled(e, WordVerdict.pending);
    final heardFor = List<HeardWord?>.filled(e, null);
    final extraAt = <(int, HeardWord)>[]; // (gap in the verified text, heard)
    var i = e;
    var j = h;
    while (i > 0 || j > 0) {
      final kind = op[i][j];
      final pi = backI[i][j];
      final pj = backJ[i][j];
      switch (kind) {
        case _opMatch:
          verdicts[i - 1] = WordVerdict.right;
          heardFor[i - 1] = said[j - 1];
        case _opJoinHeard:
          verdicts[i - 1] = WordVerdict.right;
          heardFor[i - 1] = said[pj]; // the first of the joined run
        case _opJoinWords:
          for (var x = pi; x < i; x++) {
            verdicts[x] = WordVerdict.right;
            heardFor[x] = said[j - 1];
          }
        case _opSub:
          verdicts[i - 1] = WordVerdict.wrong;
          heardFor[i - 1] = said[j - 1];
        case _opSkip:
          verdicts[i - 1] = WordVerdict.skipped;
        case _opExtra:
          extraAt.add((i, said[j - 1]));
        default:
          throw StateError('Alignment walked into an impossible cell ($i, $j)');
      }
      i = pi;
      j = pj;
    }
    // The walk ran backwards, so the extras came out in reverse order of
    // what was heard; put them back and group them by where they sit (the
    // sort is stable, so a run keeps the order he said it in).
    final heardOrder = extraAt.reversed.toList();
    heardOrder.sort((a, b) => a.$1.compareTo(b.$1));
    extraAt
      ..clear()
      ..addAll(heardOrder);

    // ---- what he never reached is not a mistake -------------------------
    if (!options.countUnreachedAsSkipped) {
      for (var k = e - 1; k >= 0; k--) {
        if (verdicts[k] != WordVerdict.skipped) break;
        verdicts[k] = WordVerdict.pending;
      }
    }

    // ---- the verdicts, honestly -----------------------------------------
    final checks = <WordCheck>[];
    for (var k = 0; k < e; k++) {
      final word = expected[k];
      final got = heardFor[k];
      var verdict = verdicts[k];
      final unsureHeard = got != null && got.confidence < options.confidenceFloor;
      if (verdict == WordVerdict.wrong && unsureHeard) verdict = WordVerdict.unsure;
      var tashkeel = TashkeelCheck.notChecked;
      if (options.checkTashkeel && verdict == WordVerdict.right && got != null) {
        final heardMarks = TasmeeFold.marks(got.heard);
        if (heardMarks.isNotEmpty && word.marks.isNotEmpty) {
          tashkeel = heardMarks == word.marks ? TashkeelCheck.same : TashkeelCheck.different;
        }
      }
      checks.add(
        WordCheck(
          word: word,
          verdict: verdict,
          heard: got?.heard,
          confidence: got?.confidence,
          at: got?.at,
          tashkeel: tashkeel,
          hinted: options.hintedWords.contains(k),
        ),
      );
    }

    // ---- the extras, grouped into runs so a restart is recognisable -----
    final extras = _classifyExtras(target, extraAt, saidFolded, said, options);

    // ---- the silences ----------------------------------------------------
    final pauses = <HeardPause>[];
    final gapOfHeard = _gapPerHeardWord(e, h, verdicts, heardFor, said);
    for (var k = 1; k < said.length; k++) {
      final silence = said[k].at - said[k - 1].end;
      if (silence >= options.pauseAfter) {
        pauses.add(HeardPause(beforeWord: gapOfHeard[k], at: said[k - 1].end, length: silence));
      }
    }

    return RecitationCheck(
      target: target,
      words: List.unmodifiable(checks),
      extras: List.unmodifiable(extras),
      pauses: List.unmodifiable(pauses),
      counts: RecitationCheck._count(checks, extras),
      heardWords: h,
      listenedFor: said.isEmpty ? Duration.zero : said.last.end,
      tashkeelChecked: options.checkTashkeel,
    );
  }

  /// What one replacement costs.
  ///
  /// Just over one, so a word said wrong reads as **one** wrong word rather
  /// than a skip plus an addition (which would cost two), while two
  /// replacements in a row cost a shade more than a skip plus an addition –
  /// so a dropped word followed by an inserted one is read as exactly
  /// that, and not as a chain of wrong words shifted along. The surcharge
  /// shrinks to nothing as the two words get closer, so a near miss really
  /// is paired with the word it is a near miss of.
  static double _subCost(String want, String got) => 1.0 + 0.1 * (1.0 - TasmeeFold.similarity(want, got));

  /// Which word of the target each heard word sits at, for the pauses.
  static List<int> _gapPerHeardWord(
    int e,
    int h,
    List<WordVerdict> verdicts,
    List<HeardWord?> heardFor,
    List<HeardWord> said,
  ) {
    final out = List<int>.filled(h, e);
    final byIdentity = <HeardWord, int>{};
    for (var k = 0; k < e; k++) {
      final got = heardFor[k];
      if (got != null) byIdentity.putIfAbsent(got, () => k);
    }
    var last = 0;
    for (var k = 0; k < h; k++) {
      final at = byIdentity[said[k]];
      if (at != null) last = at;
      out[k] = at ?? last;
    }
    return out;
  }

  static List<ExtraWord> _classifyExtras(
    RecitationTarget target,
    List<(int, HeardWord)> extraAt,
    List<String> saidFolded,
    List<HeardWord> said,
    AlignmentOptions options,
  ) {
    if (extraAt.isEmpty) return const [];
    final expected = target.words;
    final prelude = target.foldedPrelude;
    final out = <ExtraWord>[];
    var at = 0;
    while (at < extraAt.length) {
      final gap = extraAt[at].$1;
      var to = at;
      while (to + 1 < extraAt.length && extraAt[to + 1].$1 == gap) {
        to++;
      }
      final run = [for (var k = at; k <= to; k++) extraAt[k].$2];
      final runFolded = [for (final w in run) TasmeeFold.word(w.heard)];
      final reasons = _reasonsOf(target, expected, prelude, gap, runFolded);
      for (var k = 0; k < run.length; k++) {
        final w = run[k];
        var reason = reasons[k];
        if (reason == ExtraReason.inserted && w.confidence < options.confidenceFloor) {
          reason = ExtraReason.unsure;
        }
        out.add(_extraOf(target, gap, w, reason));
      }
      at = to + 1;
    }
    return out;
  }

  /// Why each word of one run of extras was heard.
  ///
  /// A run is read **piece by piece** from its start, because a reciter
  /// does several forgivable things in a row: the basmala, then the verse,
  /// then the verse again. Each piece is either a prelude the caller
  /// allowed, or a stretch of the verified text said again, and whatever is
  /// left over is a genuinely inserted word.
  static List<ExtraReason> _reasonsOf(
    RecitationTarget target,
    List<AyahWord> expected,
    List<List<String>> prelude,
    int gap,
    List<String> run,
  ) {
    final out = List<ExtraReason>.filled(run.length, ExtraReason.inserted);
    final atAyahStart = gap == 0 || target.startsAyah(gap);
    var i = 0;
    while (i < run.length) {
      // 1. the basmala (or another allowed prelude) before an ayah's first word.
      if (atAyahStart) {
        var matched = false;
        for (final p in prelude) {
          if (p.isEmpty || i + p.length > run.length) continue;
          if (!_same(run.sublist(i, i + p.length), p)) continue;
          for (var k = i; k < i + p.length; k++) {
            out[k] = ExtraReason.prelude;
          }
          i += p.length;
          matched = true;
          break;
        }
        if (matched) continue;
      }
      // 2. words of the verified text said again: the longest stretch of
      //    the text that starts here. Anywhere in the text when it is two
      //    words or more; a single word only when it is the one just said
      //    or the one about to be said (a stutter, a restart of one word).
      var best = 0;
      for (var s = 0; s < expected.length; s++) {
        var len = 0;
        while (i + len < run.length && s + len < expected.length && run[i + len] == expected[s + len].folded) {
          len++;
        }
        if (len > best && (len >= 2 || s == gap - 1 || s == gap)) best = len;
      }
      if (best > 0) {
        for (var k = i; k < i + best; k++) {
          out[k] = ExtraReason.repetition;
        }
        i += best;
        continue;
      }
      // 3. a word that is not in the text here at all.
      out[i] = ExtraReason.inserted;
      i++;
    }
    return out;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var k = 0; k < a.length; k++) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  static ExtraWord _extraOf(RecitationTarget target, int gap, HeardWord heard, ExtraReason reason) {
    final words = target.words;
    final AyahRef ref;
    final int indexInAyah;
    final int codeUnit;
    if (gap < words.length) {
      final word = words[gap];
      ref = word.ref;
      indexInAyah = word.indexInAyah;
      codeUnit = word.start;
    } else {
      final word = words.last;
      ref = word.ref;
      indexInAyah = word.indexInAyah + 1;
      codeUnit = word.end;
    }
    return ExtraWord(
      heard: heard.heard,
      ref: ref,
      beforeWord: gap,
      beforeWordInAyah: indexInAyah,
      atCodeUnit: codeUnit,
      reason: reason,
      confidence: heard.confidence,
      at: heard.at,
    );
  }
}
