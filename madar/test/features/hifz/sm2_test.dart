import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/hifz/domain/sm2.dart';

void main() {
  group('E-Factor', () {
    test('changes by the published formula for every grade', () {
      // EF' = EF + (0.1 − (5−q)(0.08 + (5−q)·0.02))
      expect(Sm2.nextEase(2.5, 5), 2.6);
      expect(Sm2.nextEase(2.5, 4), 2.5);
      expect(Sm2.nextEase(2.5, 3), 2.36);
      expect(Sm2.nextEase(2.5, 2), 2.18);
      expect(Sm2.nextEase(2.5, 1), 1.96);
      expect(Sm2.nextEase(2.5, 0), 1.7);
    });

    test('never falls below 1.3', () {
      expect(Sm2.nextEase(1.5, 0), 1.3);
      expect(Sm2.nextEase(1.3, 3), 1.3);
      var ef = 2.5;
      for (var i = 0; i < 20; i++) {
        ef = Sm2.nextEase(ef, 0);
      }
      expect(ef, Sm2.minEase);
    });

    test('rejects grades outside 0–5', () {
      expect(() => Sm2.nextEase(2.5, 6), throwsRangeError);
      expect(() => Sm2.review(Sm2State.initial, -1), throwsRangeError);
    });
  });

  test('worked reference sequence', () {
    // (grade, interval, repetitions, EF, lapses) after each review, from a
    // new item (EF 2.5). Intervals use the E-Factor from before the review.
    const expected = <(int, int, int, double, int)>[
      (5, 1, 1, 2.6, 0),
      (4, 6, 2, 2.6, 0),
      (3, 16, 3, 2.46, 0), // round(6 × 2.6 = 15.6)
      (5, 39, 4, 2.56, 0), // round(16 × 2.46 = 39.36)
      (2, 1, 0, 2.24, 1), // lapse: start again, EF still updated
      (4, 1, 1, 2.24, 1),
      (5, 6, 2, 2.34, 1),
      (4, 14, 3, 2.34, 1), // round(6 × 2.34 = 14.04)
      (3, 33, 4, 2.2, 1), // round(14 × 2.34 = 32.76)
      (0, 1, 0, 1.4, 2),
      (1, 1, 0, 1.3, 3), // floor
    ];
    var s = Sm2State.initial;
    for (final (q, interval, reps, ef, lapses) in expected) {
      s = Sm2.review(s, q);
      expect(s.intervalDays, interval, reason: 'interval after grade $q');
      expect(s.repetitions, reps, reason: 'repetitions after grade $q');
      expect(s.easeFactor, closeTo(ef, 1e-9), reason: 'EF after grade $q');
      expect(s.lapses, lapses, reason: 'lapses after grade $q');
    }
  });

  test('halves round up (round(I × EF))', () {
    // 25 × 2.5 = 62.5 → 63; 50 × 1.37 = 68.5 → 69.
    expect(Sm2.review(const Sm2State(easeFactor: 2.5, intervalDays: 25, repetitions: 3), 4).intervalDays, 63);
    expect(Sm2.review(const Sm2State(easeFactor: 1.37, intervalDays: 50, repetitions: 3), 4).intervalDays, 69);
  });

  test('perfect grades grow the interval geometrically', () {
    var s = Sm2State.initial;
    final intervals = <int>[];
    for (var i = 0; i < 6; i++) {
      s = Sm2.review(s, 5);
      intervals.add(s.intervalDays);
    }
    // EF before each review: 2.5, 2.6, 2.7, 2.8, 2.9, 3.0.
    expect(intervals, [1, 6, 16, 45, 131, 393]);
  });

  group('due dates on calendar days', () {
    test('across month boundaries', () {
      expect(Sm2.dueDate(DateTime(2026, 1, 30), 6), DateTime(2026, 2, 5));
      expect(Sm2.dueDate(DateTime(2026, 2, 27), 1), DateTime(2026, 2, 28));
      expect(Sm2.dueDate(DateTime(2026, 2, 27), 2), DateTime(2026, 3, 1)); // 2026 is not a leap year
      expect(Sm2.dueDate(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29)); // 2028 is
      expect(Sm2.dueDate(DateTime(2026, 4, 30), 1), DateTime(2026, 5, 1));
    });

    test('across the year end, from any time of day', () {
      expect(Sm2.dueDate(DateTime(2026, 12, 28, 23, 59), 6), DateTime(2027, 1, 3));
      expect(Sm2.dueDate(DateTime(2026, 9, 28, 0, 1), 39), DateTime(2026, 11, 6));
    });

    test('a long interval lands on the right day', () {
      expect(Sm2.dueDate(DateTime(2026, 9, 28), 393), DateTime(2027, 10, 26));
    });
  });
}
