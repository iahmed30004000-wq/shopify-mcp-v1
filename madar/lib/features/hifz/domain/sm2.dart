import 'package:flutter/foundation.dart';

import '../../wird/domain/calendar_days.dart';

/// The SM-2 state of one item.
@immutable
class Sm2State {
  const Sm2State({this.easeFactor = Sm2.initialEase, this.intervalDays = 0, this.repetitions = 0, this.lapses = 0});

  static const Sm2State initial = Sm2State();

  /// E-Factor (≥ [Sm2.minEase]).
  final double easeFactor;

  /// Days until the next review (0 before the first one).
  final int intervalDays;

  /// Successful repetitions in a row (n).
  final int repetitions;

  /// Times the item was forgotten (a grade below 3).
  final int lapses;

  @override
  bool operator ==(Object other) =>
      other is Sm2State &&
      other.easeFactor == easeFactor &&
      other.intervalDays == intervalDays &&
      other.repetitions == repetitions &&
      other.lapses == lapses;

  @override
  int get hashCode => Object.hash(easeFactor, intervalDays, repetitions, lapses);

  @override
  String toString() => 'Sm2State(EF $easeFactor, I $intervalDays, n $repetitions, lapses $lapses)';
}

/// SuperMemo 2 (P. A. Woźniak, 1987), exactly as published:
///
/// * quality `q` ∈ 0…5;
/// * `q ≥ 3`: `I(1) = 1`, `I(2) = 6`, `I(n) = round(I(n−1) × EF)` (with the
///   E-Factor from *before* this repetition), and `n` grows by one;
/// * `q < 3`: repetitions start again (`n = 0`, `I = 1`) – a lapse;
/// * after every repetition `EF' = EF + (0.1 − (5 − q)(0.08 + (5 − q)·0.02))`,
///   never below 1.3.
///
/// Every step of the E-Factor is a multiple of 0.02, so it is kept on that
/// decimal grid (binary floating-point noise would otherwise push
/// `round(I × EF)` across a .5 boundary).
abstract final class Sm2 {
  static const double initialEase = 2.5;
  static const double minEase = 1.3;

  /// Lowest grade that counts as recalled.
  static const int passGrade = 3;

  /// Same-day re-drill threshold (SM-2 step 7: repeat items graded below 4
  /// until they reach 4; those repeats do not change the schedule).
  static const int redrillBelow = 4;

  static double nextEase(double ef, int quality) {
    final q = _check(quality);
    final d = 5 - q;
    final next = ef + (0.1 - d * (0.08 + d * 0.02));
    final snapped = (next * 100).roundToDouble() / 100;
    return snapped < minEase ? minEase : snapped;
  }

  /// The state after a review graded [quality].
  static Sm2State review(Sm2State s, int quality) {
    final q = _check(quality);
    final ef = nextEase(s.easeFactor, q);
    if (q < passGrade) {
      return Sm2State(easeFactor: ef, intervalDays: 1, repetitions: 0, lapses: s.lapses + 1);
    }
    final interval = switch (s.repetitions) {
      0 => 1,
      1 => 6,
      // round(I × EF) on the E-Factor's 0.01 grid, halves rounded up.
      _ => (s.intervalDays * (s.easeFactor * 100).round() + 50) ~/ 100,
    };
    return Sm2State(easeFactor: ef, intervalDays: interval, repetitions: s.repetitions + 1, lapses: s.lapses);
  }

  /// The calendar day [interval] days after [reviewDay] (month and year
  /// boundaries and DST changes handled).
  static DateTime dueDate(DateTime reviewDay, int interval) =>
      CalendarDays.add(CalendarDays.dateOnly(reviewDay), interval);

  static int _check(int q) {
    if (q < 0 || q > 5) throw RangeError.range(q, 0, 5, 'quality');
    return q;
  }
}
