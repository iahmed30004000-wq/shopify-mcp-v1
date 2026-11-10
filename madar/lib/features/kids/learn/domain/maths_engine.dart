// The question generator for «الحساب» (a nine-year-old): multiplication tables
// 2-12, division as the inverse, simple fractions. Pure Dart, seeded, no clock.
//
// Promises (tests check them on 1000 questions each):
//  * the answer is correct and appears exactly once among the choices;
//  * the distractors are distinct from each other and from the answer;
//  * nothing is negative or zero where it would make no sense, and there is
//    no division by zero (divisors are always >= 2);
//  * the same question never comes twice in a row;
//  * difficulty follows the child gently: three first-try answers in a row go
//    one level up, two misses in a row go one level down. No score is shown.
import 'dart:math';

import 'package:flutter/foundation.dart';

enum MathsKind { multiplication, division, fractions }

/// What a fractions question asks.
enum FractionTask {
  /// A pie with [MathsQuestion.b] equal slices, [MathsQuestion.a] coloured:
  /// pick the fraction. Choices are fractions.
  readPie,

  /// "a/b of total": pick the number. Choices are whole numbers.
  ofAmount,
}

/// A whole number or a fraction; [den] is 1 for whole numbers.
@immutable
class MathsValue {
  const MathsValue(this.num, [this.den = 1]) : assert(den > 0);

  final int num;
  final int den;

  bool get isWhole => den == 1;

  /// Equal in value: 2/4 equals 1/2.
  bool sameValue(MathsValue o) => num * o.den == o.num * den;

  double get value => num / den;

  @override
  bool operator ==(Object other) => other is MathsValue && other.num == num && other.den == den;

  @override
  int get hashCode => Object.hash(num, den);

  @override
  String toString() => isWhole ? '$num' : '$num/$den';
}

@immutable
class MathsQuestion {
  const MathsQuestion({
    required this.kind,
    required this.a,
    required this.b,
    required this.answer,
    required this.choices,
    this.task,
    this.total,
  });

  final MathsKind kind;

  /// multiplication: `a x b` (a rows of b). division: `a / b` (a is the
  /// dividend, b the divisor, never 0). fractions: numerator a, denominator b.
  final int a, b;

  /// Only for [FractionTask.ofAmount]: the whole amount (a multiple of b).
  final int? total;

  final FractionTask? task;
  final MathsValue answer;

  /// Always exactly 3, in display order, the answer among them once.
  final List<MathsValue> choices;

  /// What identifies the question for the "never twice in a row" rule.
  String get key => '${kind.name}:${task?.name}:$a:$b:${total ?? 0}';

  bool isCorrect(MathsValue picked) => picked.sameValue(answer);
}

class MathsEngine {
  MathsEngine({int seed = 0, int level = 1}) : _rng = Random(seed), _level = level.clamp(1, maxLevel);

  static const int maxLevel = 5;
  static const int choiceCount = 3;

  final Random _rng;
  int _level;
  int _streak = 0;
  int _misses = 0;
  String? _lastKey;

  int get level => _level;

  /// Tell the engine how the child did on a question ([firstTry]: the very
  /// first tap was right). Gentle: up after three in a row, down after two
  /// misses in a row, never below 1 or above [maxLevel].
  void record({required bool firstTry}) {
    if (firstTry) {
      _misses = 0;
      if (++_streak >= 3) {
        _streak = 0;
        _level = min(maxLevel, _level + 1);
      }
    } else {
      _streak = 0;
      if (++_misses >= 2) {
        _misses = 0;
        _level = max(1, _level - 1);
      }
    }
  }

  MathsQuestion next(MathsKind kind) {
    MathsQuestion q;
    var tries = 0;
    do {
      q = switch (kind) {
        MathsKind.multiplication => _multiplication(),
        MathsKind.division => _division(),
        MathsKind.fractions => _fractions(),
      };
    } while (q.key == _lastKey && ++tries < 100);
    _lastKey = q.key;
    return q;
  }

  // ---- multiplication & division ------------------------------------------

  /// The tables on offer at this level.
  List<int> get _tables => switch (_level) {
    1 => const [2, 5, 10],
    2 => const [2, 3, 4, 5, 10],
    3 => const [2, 3, 4, 5, 6, 7, 8, 9, 10],
    _ => const [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  };

  /// The largest other factor at this level (the smallest is 2).
  int get _factorMax => switch (_level) {
    1 || 2 => 10,
    3 => 10,
    4 => 11,
    _ => 12,
  };

  T _pick<T>(List<T> l) => l[_rng.nextInt(l.length)];

  MathsQuestion _multiplication() {
    final table = _pick(_tables);
    final other = 2 + _rng.nextInt(_factorMax - 1);
    // The table can come first or second ("3 x 4" or "4 x 3").
    final swap = _rng.nextBool();
    final a = swap ? other : table;
    final b = swap ? table : other;
    final answer = a * b;
    final near = <int>[answer + a, answer - a, answer + b, answer - b, answer + 1, answer - 1, answer + 2, answer - 2];
    return MathsQuestion(
      kind: MathsKind.multiplication,
      a: a,
      b: b,
      answer: MathsValue(answer),
      choices: _wholeChoices(answer, near),
    );
  }

  MathsQuestion _division() {
    final divisor = _pick(_tables); // always >= 2
    final quotient = 2 + _rng.nextInt(_factorMax - 1);
    final dividend = divisor * quotient;
    final near = <int>[
      quotient + 1,
      quotient - 1,
      quotient + 2,
      quotient - 2,
      divisor,
      dividend - divisor,
      quotient * 2,
    ];
    return MathsQuestion(
      kind: MathsKind.division,
      a: dividend,
      b: divisor,
      answer: MathsValue(quotient),
      choices: _wholeChoices(quotient, near),
    );
  }

  /// The answer plus two near-miss distractors (>= 1, distinct, not the
  /// answer), shuffled.
  List<MathsValue> _wholeChoices(int answer, List<int> near) {
    final pool = <int>{
      for (final n in near)
        if (n >= 1 && n != answer) n,
    }.toList()..shuffle(_rng);
    final picked = <int>[answer];
    for (final n in pool) {
      if (picked.length == choiceCount) break;
      picked.add(n);
    }
    // A tiny answer (1) can leave too few near misses: step upwards.
    var step = 1;
    while (picked.length < choiceCount) {
      final c = answer + step++;
      if (c >= 1 && !picked.contains(c)) picked.add(c);
    }
    picked.shuffle(_rng);
    return [for (final v in picked) MathsValue(v)];
  }

  // ---- fractions ----------------------------------------------------------

  /// Denominators the pie can have at this level (halves, thirds, quarters
  /// first; fifths, sixths and eighths later).
  List<int> get _dens => switch (_level) {
    1 => const [2, 4],
    2 => const [2, 3, 4],
    3 => const [2, 3, 4],
    4 => const [2, 3, 4, 5, 6],
    _ => const [2, 3, 4, 5, 6, 8],
  };

  MathsQuestion _fractions() {
    final amount = _level >= 3 && _rng.nextInt(2) == 0;
    final den = _pick(amount ? const [2, 3, 4] : _dens);
    // Early on, unit fractions (1/2, 1/3, 1/4) of an amount; later any.
    final num = amount && _level == 3 ? 1 : 1 + _rng.nextInt(den - 1);
    if (!amount) {
      final answer = MathsValue(num, den);
      return MathsQuestion(
        kind: MathsKind.fractions,
        task: FractionTask.readPie,
        a: num,
        b: den,
        answer: answer,
        choices: _fractionChoices(answer),
      );
    }
    final unit = 1 + _rng.nextInt(_level >= 5 ? 6 : 4);
    final total = den * unit;
    final result = num * unit;
    final near = <int>[result + 1, result - 1, result + unit, result - unit, total, total - result, result + 2];
    return MathsQuestion(
      kind: MathsKind.fractions,
      task: FractionTask.ofAmount,
      a: num,
      b: den,
      total: total,
      answer: MathsValue(result),
      choices: _wholeChoices(result, near),
    );
  }

  List<MathsValue> _fractionChoices(MathsValue answer) {
    final sameDen = <MathsValue>[], otherDen = <MathsValue>[];
    final seen = <MathsValue>[];
    for (final d in {2, 3, 4, ..._dens}) {
      for (var n = 1; n < d; n++) {
        final f = MathsValue(n, d);
        // Equal in value to the answer (2/4 for 1/2) would be a second right
        // answer; one representative per value only.
        if (f.sameValue(answer) || seen.any((s) => s.sameValue(f))) continue;
        seen.add(f);
        (d == answer.den ? sameDen : otherDen).add(f);
      }
    }
    sameDen.shuffle(_rng);
    otherDen.shuffle(_rng);
    final picked = <MathsValue>[
      answer,
      ...[...sameDen, ...otherDen].take(choiceCount - 1),
    ]..shuffle(_rng);
    return picked;
  }
}
