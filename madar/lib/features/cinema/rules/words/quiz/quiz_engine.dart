/// A small multiple-choice quiz engine shared by the Islamic Quiz and
/// Capitals & Flags: seeded option order, selection without repeats across
/// sessions, scoring and lifelines.
///
/// Scoring (documented for the UI): a correct answer earns
/// `pointsByLevel[level - 1]`, times a streak bonus of +10 % per previous
/// consecutive correct answer (capped at +50 %), times 0.5 when the 50/50
/// lifeline was used on that question, plus a speed bonus of up to +50 %
/// when [QuizConfig.timeLimitMs] is set (linear from instant to the limit).
/// A wrong answer or a timeout earns nothing and resets the streak. A
/// skipped question earns nothing, keeps the streak and is replaced by a
/// reserve question when one is available.
library;

import '../core/words_rng.dart';

/// Arabic + English text.
final class LocalizedText {
  /// Creates text.
  const LocalizedText(this.ar, this.en);

  /// Parses `{"ar": …, "en": …}`.
  factory LocalizedText.fromJson(Object? json) {
    final m = json! as Map<String, Object?>;
    return LocalizedText(m['ar']! as String, m['en']! as String);
  }

  /// Arabic.
  final String ar;

  /// English.
  final String en;

  /// The text for a language code (Arabic unless [languageCode] is `en`).
  String of(String languageCode) => languageCode == 'en' ? en : ar;

  /// Serialises.
  Map<String, Object?> toJson() => {'ar': ar, 'en': en};

  @override
  String toString() => ar;
}

/// Where a question's answer is documented.
final class QuizSource {
  /// Creates a source.
  const QuizSource({required this.type, required this.cite, this.sura, this.ayah, this.book, this.number, this.key});

  /// Parses a source object of islamic_quiz.json.
  factory QuizSource.fromJson(Map<String, Object?> j) => QuizSource(
    type: j['t']! as String,
    cite: LocalizedText.fromJson(j['cite']),
    sura: j['s'] as int?,
    ayah: j['a'] as int?,
    book: j['b'] as String?,
    number: j['n'] as int?,
    key: j['k'] as String?,
  );

  /// `quran`, `hadith`, `meta` (mushaf structure) or `data` (reference data).
  final String type;

  /// Human-readable citation.
  final LocalizedText cite;

  /// Quran sura number.
  final int? sura;

  /// Quran ayah number.
  final int? ayah;

  /// Hadith collection id (bukhari, muslim, tirmidhi, abudawud).
  final String? book;

  /// Hadith number.
  final int? number;

  /// Verification key: a letter skeleton that occurs in the cited text
  /// (Quran / hadith) or the name of a checked mushaf fact (meta).
  final String? key;
}

/// A multiple-choice question.
final class QuizQuestion {
  /// Creates a question.
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.level,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    this.sources = const [],
    this.payload = const {},
  });

  /// Stable id.
  final String id;

  /// Category id.
  final String category;

  /// 1 easy, 2 medium, 3 hard.
  final int level;

  /// The question.
  final LocalizedText prompt;

  /// Answer options.
  final List<LocalizedText> options;

  /// Index of the correct option in [options].
  final int answerIndex;

  /// Citations.
  final List<QuizSource> sources;

  /// Extra data for the UI (e.g. `{'flag': 'SA'}` for flag questions).
  final Map<String, Object?> payload;

  /// The correct option.
  LocalizedText get answer => options[answerIndex];
}

/// Remembers which questions a player has seen, so new sessions draw unseen
/// questions first; when every eligible question has been seen the cycle
/// restarts.
final class QuizDeck {
  /// Creates a deck.
  QuizDeck({Set<String>? seen, this.cycle = 0}) : _seen = {...?seen};

  /// Restores from JSON.
  factory QuizDeck.fromJson(Map<String, Object?> j) =>
      QuizDeck(seen: {for (final s in j['seen']! as List<Object?>) s! as String}, cycle: j['cycle']! as int);

  final Set<String> _seen;

  /// Completed cycles.
  int cycle;

  /// Ids seen in the current cycle.
  Set<String> get seen => Set.unmodifiable(_seen);

  /// Draws up to [count] questions from [pool]: unseen ones first (in seeded
  /// random order); when fewer than [count] are unseen the cycle restarts
  /// and the rest are drawn from the others, never repeating within the
  /// draw. The drawn ids are marked as seen.
  List<QuizQuestion> draw(List<QuizQuestion> pool, int count, WordsRng rng) {
    final unseen = rng.shuffle([for (final q in pool) if (!_seen.contains(q.id)) q]);
    final out = unseen.take(count).toList();
    if (out.length < count) {
      cycle++;
      _seen.removeWhere((id) => pool.any((q) => q.id == id));
      final taken = {for (final q in out) q.id};
      final rest = rng.shuffle([for (final q in pool) if (!taken.contains(q.id)) q]);
      out.addAll(rest.take(count - out.length));
    }
    _seen.addAll(out.map((q) => q.id));
    return out;
  }

  /// Serialises.
  Map<String, Object?> toJson() => {'seen': _seen.toList(), 'cycle': cycle};
}

/// Session options.
final class QuizConfig {
  /// Creates options.
  const QuizConfig({
    this.questionCount = 10,
    this.fiftyFifty = 1,
    this.skips = 1,
    this.pointsByLevel = const [100, 200, 300],
    this.timeLimitMs,
    this.reserve = 3,
  });

  /// Questions asked.
  final int questionCount;

  /// 50/50 lifelines available.
  final int fiftyFifty;

  /// Skip lifelines available.
  final int skips;

  /// Base points for levels 1–3.
  final List<int> pointsByLevel;

  /// Optional time limit per question (enables the speed bonus).
  final int? timeLimitMs;

  /// Reserve questions drawn for skips.
  final int reserve;
}

/// Outcome of an answer.
final class AnswerOutcome {
  const AnswerOutcome._({required this.correct, required this.points, required this.correctOption});

  /// Whether the choice was right.
  final bool correct;

  /// Points earned.
  final int points;

  /// Displayed index of the right option.
  final int correctOption;
}

/// A running quiz.
final class QuizSession {
  /// Starts a session over [questions] (the first [QuizConfig.questionCount]
  /// are asked, the next [QuizConfig.reserve] replace skipped ones).
  QuizSession(List<QuizQuestion> questions, {this.config = const QuizConfig(), required int seed})
    : _rng = WordsRng(seed),
      _queue = questions.take(config.questionCount).toList(),
      _reserve = questions.skip(config.questionCount).take(config.reserve).toList(),
      fiftyFiftyLeft = config.fiftyFifty,
      skipsLeft = config.skips {
    _prepare();
  }

  /// Options.
  final QuizConfig config;
  final WordsRng _rng;
  final List<QuizQuestion> _queue;
  final List<QuizQuestion> _reserve;

  int _index = 0;
  List<int> _order = const [];
  Set<int> _hidden = {};
  bool _usedFiftyHere = false;

  /// Remaining 50/50 lifelines.
  int fiftyFiftyLeft;

  /// Remaining skips.
  int skipsLeft;

  /// Total score.
  int score = 0;

  /// Correct answers.
  int correctCount = 0;

  /// Questions answered (not skipped).
  int answeredCount = 0;

  /// Current streak of correct answers.
  int streak = 0;

  /// Best streak.
  int bestStreak = 0;

  void _prepare() {
    _hidden = {};
    _usedFiftyHere = false;
    if (finished) return;
    _order = _rng.shuffle(List<int>.generate(current.options.length, (i) => i));
  }

  /// Whether all questions were handled.
  bool get finished => _index >= _queue.length;

  /// Question number (0-based).
  int get index => _index;

  /// Questions in the session.
  int get length => _queue.length;

  /// The current question.
  QuizQuestion get current => _queue[_index];

  /// Options in display order.
  List<LocalizedText> get options => [for (final i in _order) current.options[i]];

  /// Display indices hidden by 50/50.
  Set<int> get hiddenOptions => Set.unmodifiable(_hidden);

  /// Display index of the correct option.
  int get correctOption => _order.indexOf(current.answerIndex);

  /// Uses a 50/50: hides two wrong options. False when unavailable.
  bool useFiftyFifty() {
    if (finished || fiftyFiftyLeft <= 0 || _usedFiftyHere) return false;
    final wrong = [for (var i = 0; i < _order.length; i++) if (i != correctOption) i];
    _rng.shuffle(wrong);
    _hidden = wrong.take(wrong.length - 1 < 2 ? wrong.length - 1 : 2).toSet();
    fiftyFiftyLeft--;
    _usedFiftyHere = true;
    return true;
  }

  /// Skips the current question (replaced from the reserve when possible).
  bool skip() {
    if (finished || skipsLeft <= 0) return false;
    skipsLeft--;
    if (_reserve.isNotEmpty) {
      _queue[_index] = _reserve.removeAt(0);
    } else {
      _index++;
    }
    _prepare();
    return true;
  }

  /// Answers with the option at display index [choice] (null = timed out).
  AnswerOutcome answer(int? choice, {int? elapsedMs}) {
    if (finished) throw StateError('quiz finished');
    final right = correctOption;
    final correct = choice == right;
    var points = 0;
    if (correct) {
      final base = config.pointsByLevel[(current.level - 1).clamp(0, config.pointsByLevel.length - 1)];
      var p = base * (1 + 0.1 * (streak < 5 ? streak : 5));
      if (_usedFiftyHere) p *= 0.5;
      final limit = config.timeLimitMs;
      if (limit != null && elapsedMs != null && elapsedMs < limit) {
        p *= 1 + 0.5 * (1 - elapsedMs / limit);
      }
      points = p.round();
      score += points;
      correctCount++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }
    answeredCount++;
    _index++;
    _prepare();
    return AnswerOutcome._(correct: correct, points: points, correctOption: right);
  }
}
