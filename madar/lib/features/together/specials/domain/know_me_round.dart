/// One round of "How well do you know me?" (قديش بتعرفني؟).
///
/// Every question is asked about both players. On a shared phone each
/// player, in private, answers the questions about themselves ("my own
/// answer") and guesses the other's answers. Nothing typed is shown until
/// both have answered; then, together, each answer is revealed next to the
/// other's guess and the player it is about judges the guess: spot on (2
/// points), close (1) or not quite (0). The better guesser wins the round.
///
/// Pure Dart: the UI drives it, the tests break it.
library;

import 'dart:math' as math;

import '../../domain/match_record.dart';
import '../../domain/play_modes.dart';
import '../../domain/player_profile.dart';
import 'know_me_bank.dart';
import 'specials_bounds.dart';

/// How close a guess was, as judged by the player it was about.
enum KnowMeVerdict {
  exact(2),
  close(1),
  miss(0);

  const KnowMeVerdict(this.points);

  final int points;
}

/// A player's private input for one question.
final class KnowMeAnswer {
  const KnowMeAnswer({this.own = '', this.guess = ''});

  /// The player's own answer (about themselves). Empty: the question is not
  /// scored for this player (skipped).
  final String own;

  /// The player's guess of the other's own answer. Empty: "no idea" (0).
  final String guess;

  KnowMeAnswer cleaned() => KnowMeAnswer(
    own: SpecialsBounds.clean(own, SpecialsBounds.maxAnswerLength),
    guess: SpecialsBounds.clean(guess, SpecialsBounds.maxAnswerLength),
  );
}

/// A question as asked in a round (its text fixed when the round starts).
final class RoundQuestion {
  const RoundQuestion({required this.id, required this.text});

  final String id;
  final String text;
}

/// One guess to judge: [guesser]'s guess of [subject]'s own answer to
/// question [index].
final class KnowMeItem {
  const KnowMeItem(this.index, this.subject);

  final int index;

  /// The player the question is about (who judges).
  final PlayerSlot subject;

  PlayerSlot get guesser => subject.other;

  String get _key => '$index:${subject.name}';

  @override
  bool operator ==(Object other) => other is KnowMeItem && other.index == index && other.subject == subject;

  @override
  int get hashCode => Object.hash(index, subject);

  @override
  String toString() => 'KnowMeItem($index, ${subject.name})';
}

enum KnowMePhase {
  /// A player is answering in private ([KnowMeRound.turn]).
  answering,

  /// Both answered: answers are revealed and judged together.
  reveal,

  /// Scored (and recorded).
  finished,
}

/// The result of a finished round.
final class KnowMeResult {
  const KnowMeResult({
    required this.outcome,
    required this.scoreOne,
    required this.scoreTwo,
    required this.maxOne,
    required this.maxTwo,
    required this.perfect,
  });

  final MatchOutcome outcome;

  /// Points each player earned as a guesser.
  final int scoreOne;
  final int scoreTwo;

  /// The most each could have earned.
  final int maxOne;
  final int maxTwo;

  /// Players who guessed every scored question spot on (at least
  /// [SpecialsBounds.perfectRoundMin] of them).
  final Set<PlayerSlot> perfect;

  int scoreOf(PlayerSlot s) => s == PlayerSlot.one ? scoreOne : scoreTwo;

  int maxOf(PlayerSlot s) => s == PlayerSlot.one ? maxOne : maxTwo;

  /// Whether anything was scored at all (an empty round is not recorded).
  bool get recordable => maxOne + maxTwo > 0;
}

/// Refused round operations (the UI never offers them).
final class KnowMeRoundError extends StateError {
  KnowMeRoundError(super.message);
}

/// A round's state machine. Private answers can only be read once both
/// players have answered ([answersOf] throws before).
class KnowMeRound {
  KnowMeRound({
    required this.id,
    required List<RoundQuestion> questions,
    required this.first,
    required this.startedAt,
  }) : questions = List.unmodifiable(questions) {
    if (questions.isEmpty) throw ArgumentError.value(questions, 'questions', 'a round needs a question');
    if (!SpecialsBounds.isValidId(id)) throw ArgumentError.value(id, 'id');
  }

  /// Draws a round from [bank] following [prefs]: fresh questions first
  /// (never asked recently), then the longest-ago asked; in random order.
  factory KnowMeRound.draw({
    required KnowMeBank bank,
    required KnowMePrefs prefs,
    required String languageCode,
    required PlayerSlot first,
    required DateTime now,
    math.Random? random,
    String? id,
    int? size,
  }) {
    final r = random ?? math.Random();
    final picked = pickQuestions(bank, prefs, count: size ?? prefs.roundSize, random: r);
    return KnowMeRound(
      id: id ?? SpecialsBounds.newId('r', r),
      questions: [for (final q in picked) RoundQuestion(id: q.id, text: q.textIn(languageCode))],
      first: first,
      startedAt: now,
    );
  }

  /// Up to [count] questions of the chosen categories, fresh ones first.
  static List<KnowMeQuestion> pickQuestions(
    KnowMeBank bank,
    KnowMePrefs prefs, {
    required int count,
    required math.Random random,
  }) {
    final n = count.clamp(1, SpecialsBounds.maxRoundSize);
    final pool = bank.questionsInAny(prefs.categories);
    final age = {for (var i = 0; i < prefs.recent.length; i++) prefs.recent[i]: i};
    final fresh = [
      for (final q in pool)
        if (!age.containsKey(q.id)) q,
    ]..shuffle(random);
    final stale = [
      for (final q in pool)
        if (age.containsKey(q.id)) q,
    ]..sort((a, b) => age[a.id]!.compareTo(age[b.id]!));
    return [...fresh, ...stale].take(n).toList()..shuffle(random);
  }

  final String id;
  final List<RoundQuestion> questions;

  /// Who answers first.
  final PlayerSlot first;
  final DateTime startedAt;

  final Map<PlayerSlot, List<KnowMeAnswer>> _answers = {};
  final Map<String, KnowMeVerdict> _verdicts = {};
  KnowMeResult? _result;

  /// Who answers now (null once both have).
  PlayerSlot? get turn {
    if (_result != null) return null;
    if (!_answers.containsKey(first)) return first;
    if (!_answers.containsKey(first.other)) return first.other;
    return null;
  }

  KnowMePhase get phase => _result != null
      ? KnowMePhase.finished
      : turn != null
      ? KnowMePhase.answering
      : KnowMePhase.reveal;

  bool hasAnswered(PlayerSlot slot) => _answers.containsKey(slot);

  /// [slot]'s private answers, in question order. Only [turn] may submit,
  /// once; the texts are cleaned and bounded.
  void submit(PlayerSlot slot, List<KnowMeAnswer> answers) {
    if (turn != slot) throw KnowMeRoundError('not ${slot.name}\'s turn to answer');
    if (answers.length != questions.length) throw ArgumentError.value(answers.length, 'answers', 'one per question');
    _answers[slot] = List.unmodifiable([for (final a in answers) a.cleaned()]);
  }

  void _requireRevealed() {
    if (phase == KnowMePhase.answering) throw KnowMeRoundError('answers are private until both have answered');
  }

  /// [slot]'s answers – only once both players have answered.
  List<KnowMeAnswer> answersOf(PlayerSlot slot) {
    _requireRevealed();
    return _answers[slot]!;
  }

  /// Every guess to judge, question by question (the first player's
  /// answers first).
  List<KnowMeItem> get items => [
    for (var i = 0; i < questions.length; i++) ...[KnowMeItem(i, first), KnowMeItem(i, first.other)],
  ];

  /// The subject's own answer of [item].
  String ownAnswer(KnowMeItem item) => answersOf(item.subject)[item.index].own;

  /// The guesser's guess of [item].
  String guessOf(KnowMeItem item) => answersOf(item.guesser)[item.index].guess;

  /// Not scored: the subject skipped the question about themselves.
  bool isVoid(KnowMeItem item) => ownAnswer(item).isEmpty;

  /// What the app would suggest: no guess → not quite; the same answer
  /// (ignoring case, Arabic letter forms, diacritics, "the"/"ال") → spot
  /// on; a shared word → close.
  KnowMeVerdict? suggestion(KnowMeItem item) {
    if (isVoid(item)) return null;
    final guess = guessOf(item);
    if (guess.isEmpty) return KnowMeVerdict.miss;
    final own = ownAnswer(item);
    if (KnowMeAnswerMatch.same(own, guess)) return KnowMeVerdict.exact;
    if (KnowMeAnswerMatch.similar(own, guess)) return KnowMeVerdict.close;
    return null;
  }

  /// The verdict of [item]: the subject's judgement, or – when there is
  /// nothing to judge – "not quite" for an empty guess and "spot on" for
  /// the very same answer. Null: still to be judged (or void).
  KnowMeVerdict? verdictOf(KnowMeItem item) {
    if (isVoid(item)) return null;
    final judged = _verdicts[item._key];
    if (judged != null) return judged;
    final guess = guessOf(item);
    if (guess.isEmpty) return KnowMeVerdict.miss;
    if (KnowMeAnswerMatch.same(ownAnswer(item), guess)) return KnowMeVerdict.exact;
    return null;
  }

  /// Whether the subject judged [item] (rather than the automatic verdict).
  bool isJudged(KnowMeItem item) => _verdicts.containsKey(item._key);

  /// The subject judges the guess of [item] (changeable until [finish]).
  void judge(KnowMeItem item, KnowMeVerdict verdict) {
    if (phase != KnowMePhase.reveal) throw KnowMeRoundError('judging happens after both answered, before finishing');
    if (item.index < 0 || item.index >= questions.length) throw RangeError.index(item.index, questions, 'index');
    if (isVoid(item)) throw KnowMeRoundError('a skipped question is not scored');
    _verdicts[item._key] = verdict;
  }

  /// Items still waiting for a verdict.
  List<KnowMeItem> get pending => [
    for (final item in items)
      if (!isVoid(item) && verdictOf(item) == null) item,
  ];

  bool get allJudged => phase != KnowMePhase.answering && pending.isEmpty;

  /// Points [guesser] has so far.
  int scoreOf(PlayerSlot guesser) {
    _requireRevealed();
    var s = 0;
    for (final item in items) {
      if (item.guesser == guesser && !isVoid(item)) s += verdictOf(item)?.points ?? 0;
    }
    return s;
  }

  /// Points [guesser] has from the guesses in [revealed] only – what a
  /// live scoreboard may show during the reveal. (Automatic verdicts of
  /// guesses still face down would give them away.)
  int revealedScoreOf(PlayerSlot guesser, Iterable<KnowMeItem> revealed) {
    _requireRevealed();
    var s = 0;
    for (final item in revealed.toSet()) {
      if (item.index < 0 || item.index >= questions.length) continue;
      if (item.guesser == guesser && !isVoid(item)) s += verdictOf(item)?.points ?? 0;
    }
    return s;
  }

  /// The most [guesser] can earn this round.
  int maxScoreOf(PlayerSlot guesser) {
    _requireRevealed();
    return KnowMeVerdict.exact.points * items.where((i) => i.guesser == guesser && !isVoid(i)).length;
  }

  KnowMeResult? get result => _result;

  /// Scores the round. Every scored guess must have a verdict; finishing
  /// twice returns the same result.
  KnowMeResult finish() {
    final done = _result;
    if (done != null) return done;
    if (phase != KnowMePhase.reveal) throw KnowMeRoundError('the round is still being answered');
    if (!allJudged) throw KnowMeRoundError('${pending.length} guesses still to judge');
    final one = scoreOf(PlayerSlot.one), two = scoreOf(PlayerSlot.two);
    bool perfect(PlayerSlot s) {
      final scored = items.where((i) => i.guesser == s && !isVoid(i)).toList();
      return scored.length >= SpecialsBounds.perfectRoundMin && scored.every((i) => verdictOf(i) == KnowMeVerdict.exact);
    }

    return _result = KnowMeResult(
      outcome: one == two ? MatchOutcome.draw : (one > two ? MatchOutcome.oneWon : MatchOutcome.twoWon),
      scoreOne: one,
      scoreTwo: two,
      maxOne: maxScoreOf(PlayerSlot.one),
      maxTwo: maxScoreOf(PlayerSlot.two),
      perfect: {
        for (final s in PlayerSlot.values)
          if (perfect(s)) s,
      },
    );
  }

  /// The head-to-head record of the finished round (its id is derived from
  /// the round's, so recording twice changes nothing).
  MatchRecord toRecord(DateTime endedAt) {
    final r = _result;
    if (r == null) throw KnowMeRoundError('finish the round first');
    final seconds = endedAt.difference(startedAt).inSeconds;
    return MatchRecord(
      id: 'knowMe-$id',
      gameId: 'knowMe',
      endedAt: endedAt,
      outcome: r.outcome,
      scoreOne: r.scoreOne,
      scoreTwo: r.scoreTwo,
      mode: PlayMode.passAndPlay,
      durationSeconds: seconds < 0 ? null : seconds,
    );
  }
}

/// Comparing a guess with an answer, forgivingly: case, Arabic letter
/// variants (أ/إ/آ → ا, ى → ي, ة → ه), diacritics and tatweel, digits of any
/// script, punctuation, and the articles "ال" / "the" / "a" do not matter.
abstract final class KnowMeAnswerMatch {
  static final RegExp _marks = RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
  static final RegExp _punct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final RegExp _space = RegExp(r'\s+');
  static const Set<String> _stop = {'the', 'a', 'an', 'my', 'of'};

  static String _letters(String s) {
    final b = StringBuffer();
    for (final c in s.toLowerCase().replaceAll(_marks, '').runes) {
      final mapped = switch (c) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
        0x0649 => 0x064A, // ى → ي
        0x0629 => 0x0647, // ة → ه
        0x0624 => 0x0648, // ؤ → و
        0x0626 => 0x064A, // ئ → ي
        >= 0x0660 && <= 0x0669 => c - 0x0660 + 0x30, // Arabic-Indic digits
        >= 0x06F0 && <= 0x06F9 => c - 0x06F0 + 0x30, // Persian digits
        _ => c,
      };
      b.writeCharCode(mapped);
    }
    return b.toString();
  }

  /// The words of [s], normalised.
  static List<String> tokens(String s) {
    final words = _letters(s).replaceAll(_punct, ' ').split(_space);
    return [
      for (final w in words)
        if (w.isNotEmpty && !_stop.contains(w)) w.startsWith('ال') && w.length > 3 ? w.substring(2) : w,
    ];
  }

  static String normalize(String s) => tokens(s).join(' ');

  /// The same answer (spaces between words do not matter either).
  static bool same(String a, String b) {
    final na = normalize(a).replaceAll(' ', ''), nb = normalize(b).replaceAll(' ', '');
    return na.isNotEmpty && na == nb;
  }

  /// Close enough to suggest "close": one contains the other, or they share
  /// a word of three letters or more.
  static bool similar(String a, String b) {
    if (same(a, b)) return true;
    final na = normalize(a), nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    final ca = na.replaceAll(' ', ''), cb = nb.replaceAll(' ', '');
    if ((ca.length >= 3 && cb.contains(ca)) || (cb.length >= 3 && ca.contains(cb))) return true;
    final ta = {for (final t in na.split(' ')) if (t.runes.length >= 3) t};
    return nb.split(' ').any(ta.contains);
  }
}
