import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/daily_reading_goal.dart';
import 'package:madar/features/reading/domain/reading_session.dart';

String _k(int y, int m, int d) => '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

void main() {
  late DateTime now;
  late ReadingGoalCalculator calc;

  DailyReadingGoal goal(GoalUnit u, int t, DateTime from) => DailyReadingGoal(unit: u, target: t, effectiveFrom: from);

  setUp(() {
    now = DateTime(2026, 11, 10, 20);
    calc = ReadingGoalCalculator(clock: () => now);
  });

  group('streak', () {
    final history = [goal(GoalUnit.pages, 10, DateTime(2026, 11, 1))];

    test('counts consecutive met days up to today', () {
      final totals = {
        _k(2026, 11, 8): const DailyTotals(pages: 10),
        _k(2026, 11, 9): const DailyTotals(pages: 12),
        _k(2026, 11, 10): const DailyTotals(pages: 10),
      };
      final s = calc.streak(history: history, totals: totals);
      expect(s.current, 3);
      expect(s.todayMet, isTrue);
    });

    test('today still open does not break yesterday\'s streak', () {
      final totals = {
        _k(2026, 11, 8): const DailyTotals(pages: 10),
        _k(2026, 11, 9): const DailyTotals(pages: 10),
        _k(2026, 11, 10): const DailyTotals(pages: 3),
      };
      final s = calc.streak(history: history, totals: totals);
      expect(s.current, 2);
      expect(s.todayMet, isFalse);
    });

    test('a skipped day breaks it', () {
      final totals = {
        _k(2026, 11, 6): const DailyTotals(pages: 10),
        _k(2026, 11, 7): const DailyTotals(pages: 10),
        // 8th skipped
        _k(2026, 11, 9): const DailyTotals(pages: 10),
        _k(2026, 11, 10): const DailyTotals(pages: 10),
      };
      final s = calc.streak(history: history, totals: totals);
      expect(s.current, 2);
      expect(s.longest, 2);
    });

    test('longest remembers an older, longer run', () {
      final totals = {
        for (var d = 1; d <= 5; d++) _k(2026, 11, d): const DailyTotals(pages: 10),
        _k(2026, 11, 10): const DailyTotals(pages: 10),
      };
      final s = calc.streak(history: history, totals: totals);
      expect(s.longest, 5);
      expect(s.current, 1);
    });

    test('midnight: at 23:59 today is open, at 00:01 yesterday is what counts', () {
      final totals = {_k(2026, 11, 9): const DailyTotals(pages: 10), _k(2026, 11, 10): const DailyTotals(pages: 10)};
      now = DateTime(2026, 11, 10, 23, 59);
      expect(calc.streak(history: history, totals: totals).current, 2);
      now = DateTime(2026, 11, 11, 0, 1); // the 11th has nothing yet
      final s = calc.streak(history: history, totals: totals);
      expect(s.current, 2);
      expect(s.todayMet, isFalse);
      now = DateTime(2026, 11, 12, 0, 1); // the 11th was skipped
      expect(calc.streak(history: history, totals: totals).current, 0);
    });

    test('no goal yet means no streak, and days before the goal do not count', () {
      expect(calc.streak(history: const [], totals: {_k(2026, 11, 10): const DailyTotals(pages: 99)}).current, 0);
      final late = [goal(GoalUnit.pages, 10, DateTime(2026, 11, 10, 8))];
      final totals = {_k(2026, 11, 8): const DailyTotals(pages: 99), _k(2026, 11, 10): const DailyTotals(pages: 10)};
      expect(calc.streak(history: late, totals: totals).current, 1);
    });

    test('minutes goal reads active seconds', () {
      final h = [goal(GoalUnit.minutes, 15, DateTime(2026, 11, 1))];
      expect(calc.streak(history: h, totals: {_k(2026, 11, 10): const DailyTotals(seconds: 15 * 60)}).todayMet, isTrue);
      expect(calc.streak(history: h, totals: {_k(2026, 11, 10): const DailyTotals(seconds: 15 * 60 - 1)}).todayMet, isFalse);
    });
  });

  group('goal changed', () {
    test('raised mid-day: what he already read still counts for that day', () {
      final h = [goal(GoalUnit.pages, 10, DateTime(2026, 11, 1)), goal(GoalUnit.pages, 20, DateTime(2026, 11, 10, 14))];
      now = DateTime(2026, 11, 10, 18);
      final s = calc.streak(history: h, totals: {_k(2026, 11, 10): const DailyTotals(pages: 12)});
      expect(s.todayMet, isTrue);
      // The next day only the new target applies.
      now = DateTime(2026, 11, 11, 18);
      expect(calc.streak(history: h, totals: {_k(2026, 11, 11): const DailyTotals(pages: 12)}).todayMet, isFalse);
    });

    test('lowered mid-day: the new, easier goal counts', () {
      final h = [goal(GoalUnit.pages, 20, DateTime(2026, 11, 1)), goal(GoalUnit.pages, 5, DateTime(2026, 11, 10, 14))];
      expect(calc.streak(history: h, totals: {_k(2026, 11, 10): const DailyTotals(pages: 6)}).todayMet, isTrue);
    });

    test('switching unit from pages to minutes judges each past day by its own goal', () {
      final h = [goal(GoalUnit.pages, 10, DateTime(2026, 11, 1)), goal(GoalUnit.minutes, 15, DateTime(2026, 11, 10))];
      final totals = {
        _k(2026, 11, 9): const DailyTotals(pages: 10),
        _k(2026, 11, 10): const DailyTotals(seconds: 900),
      };
      expect(calc.streak(history: h, totals: totals).current, 2);
    });

    test('todayFraction follows the goal now in force', () {
      final h = [goal(GoalUnit.pages, 10, DateTime(2026, 11, 1))];
      expect(calc.todayFraction(history: h, totals: {_k(2026, 11, 10): const DailyTotals(pages: 4)}), 0.4);
      expect(calc.todayFraction(history: h, totals: {_k(2026, 11, 10): const DailyTotals(pages: 40)}), 1.0);
    });

    test('JSON round-trip', () {
      final g = goal(GoalUnit.minutes, 20, DateTime(2026, 11, 1, 7));
      expect(DailyReadingGoal.fromJson(g.toJson()), g);
    });
  });

  group('ReadingSession aggregation', () {
    ReadingSession s(String id, String book, DateTime a, DateTime b, int pages, int secs) =>
        ReadingSession(id: id, bookId: book, startedAt: a, endedAt: b, pagesRead: pages, activeSeconds: secs);

    test('sums sessions of the same day and book', () {
      final out = ReadingAggregator.byDay([
        s('1', 'a', DateTime(2026, 11, 10, 8), DateTime(2026, 11, 10, 8, 20), 5, 1200),
        s('2', 'b', DateTime(2026, 11, 10, 21), DateTime(2026, 11, 10, 21, 10), 3, 600),
      ]);
      expect(out[_k(2026, 11, 10)], const DailyTotals(pages: 8, seconds: 1800));
      expect(ReadingAggregator.forBook([s('1', 'a', DateTime(2026, 11, 10, 8), DateTime(2026, 11, 10, 8, 20), 5, 1200)], 'b'), DailyTotals.zero);
    });

    test('a session across midnight is split by time; pages go to the day it ended', () {
      final out = ReadingAggregator.byDay([
        s('1', 'a', DateTime(2026, 11, 9, 23, 40), DateTime(2026, 11, 10, 0, 20), 6, 2400),
      ]);
      expect(out[_k(2026, 11, 9)], const DailyTotals(pages: 0, seconds: 1200));
      expect(out[_k(2026, 11, 10)], const DailyTotals(pages: 6, seconds: 1200));
    });

    test('active seconds are conserved even when the split does not divide evenly', () {
      final out = ReadingAggregator.byDay([
        s('1', 'a', DateTime(2026, 11, 9, 23, 59, 59), DateTime(2026, 11, 10, 0, 0, 2), 1, 7),
      ]);
      expect(out.values.fold<int>(0, (a, b) => a + b.seconds), 7);
    });

    test('a session over two midnights touches three days', () {
      final out = ReadingAggregator.byDay([
        s('1', 'a', DateTime(2026, 11, 8, 23), DateTime(2026, 11, 10, 1), 2, 4800),
      ]);
      expect(out.keys.toSet(), {_k(2026, 11, 8), _k(2026, 11, 9), _k(2026, 11, 10)});
      expect(out.values.fold<int>(0, (a, b) => a + b.seconds), 4800);
    });

    test('JSON round-trip', () {
      final x = s('1', 'a', DateTime(2026, 11, 10, 8), DateTime(2026, 11, 10, 9), 4, 3000);
      final y = ReadingSession.fromJson(x.toJson());
      expect(y.pagesRead, 4);
      expect(y.endedAt, x.endedAt);
    });
  });
}
