import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/growth/domain/goal_chart_data.dart';
import 'package:madar/features/growth/domain/goal_math.dart';
import 'package:madar/features/growth/domain/growth_days.dart';
import 'package:madar/features/growth/domain/growth_streaks.dart';

/// Monday 28 Sep 2026.
final DateTime today = DateTime(2026, 9, 28);

GoalEntry e(double amount, DateTime at) => GoalEntry(amount: amount, at: at);

DateTime day(int offset, {int hour = 9}) => DateTime(2026, 9, 28 + offset, hour);

GoalStats stats({
  double initial = 0,
  double target = 300,
  List<GoalEntry> entries = const [],
  DateTime? created,
  DateTime? deadline,
  bool active = true,
  DateTime? now,
}) => GoalMath.compute(
  initial: initial,
  target: target,
  entries: entries,
  created: created ?? day(-9, hour: 20),
  deadline: deadline,
  active: active,
  today: now ?? today,
);

void main() {
  group('GrowthDays', () {
    test('counts calendar days across a DST change', () {
      expect(GrowthDays.between(DateTime(2026, 3, 27), DateTime(2026, 3, 30, 23)), 3);
      expect(GrowthDays.between(DateTime(2026, 10, 30), DateTime(2026, 10, 25)), -5);
      expect(GrowthDays.add(DateTime(2026, 12, 30), 3), DateTime(2027, 1, 2));
    });

    test('fractional days include the time of day', () {
      expect(GrowthDays.fractional(DateTime(2026, 9, 1), DateTime(2026, 9, 3, 12)), 2.5);
    });
  });

  group('progress', () {
    test('current is the starting value plus every log', () {
      final s = stats(initial: 40, entries: [e(10, day(-2)), e(20, day(-1))]);
      expect(s.logged, 30);
      expect(s.current, 70);
      expect(s.fraction, closeTo(70 / 300, 1e-9));
      expect(s.remaining, 230);
      expect(s.overshoot, 0);
      expect(s.status, GoalStatus.active);
    });

    test('overshoot: past the target stays completed, fraction above one', () {
      final s = stats(
        target: 100,
        deadline: day(20),
        entries: [e(60, day(-5)), e(50, day(-3, hour: 21)), e(15, day(-1))],
      );
      expect(s.current, 125);
      expect(s.fraction, 1.25);
      expect(s.progress, 1.0);
      expect(s.overshoot, 25);
      expect(s.remaining, 0);
      expect(s.pace, GoalPace.completed);
      expect(s.status, GoalStatus.completed);
      expect(s.completedOn, DateTime(2026, 9, 25), reason: 'the day the running total crossed 100');
      expect(s.neededPerDay, isNull);
      expect(s.projectedFinish, isNull);
    });

    test('a completed goal stays completed when paused', () {
      final s = stats(target: 10, entries: [e(10, day(-1))], active: false);
      expect(s.status, GoalStatus.completed);
      expect(s.pace, GoalPace.completed);
    });

    test('a starting value at the target completes on the first day', () {
      final s = stats(initial: 50, target: 50);
      expect(s.completed, isTrue);
      expect(s.completedOn, DateTime(2026, 9, 19));
    });

    test('a target of zero counts as reached', () {
      final s = stats(target: 0);
      expect(s.completed, isTrue);
      expect(s.fraction, 1);
    });
  });

  group('pace with a deadline', () {
    test('zero progress: not started, needed pace spread over the days left', () {
      // Created today, deadline in 29 days → 30 days left including today.
      final s = stats(target: 300, created: day(0, hour: 8), deadline: day(29));
      expect(s.pace, GoalPace.notStarted);
      expect(s.daysLeft, 30);
      expect(s.neededPerDay, 10);
      expect(s.neededPerWeek, 70);
      expect(s.actualPerDay, 0);
      expect(s.projectedFinish, isNull);
      expect(s.expectedNow, 0, reason: 'nothing is expected before the first day ends');
      expect(s.elapsedDays, 1);
      expect(s.paceWindow, 1);
    });

    test('zero progress on an old goal is still "not started" but behind plan', () {
      final s = stats(target: 300, created: day(-10), deadline: day(19));
      expect(s.pace, GoalPace.notStarted);
      expect(s.vsPlan, lessThan(0));
      // 30-day plan, 10 full days elapsed.
      expect(s.expectedNow, closeTo(100, 1e-9));
    });

    test('on track: the recent pace exactly meets the needed pace', () {
      // 10 days old (started 19 Sep), 10 pages every day for the last 10 days.
      final entries = [for (var i = -9; i <= 0; i++) e(10, day(i))];
      // 100 done, 200 left, 20 days left → 10/day needed.
      final s = stats(target: 300, created: day(-9), deadline: day(19), entries: entries);
      expect(s.daysLeft, 20);
      expect(s.neededPerDay, 10);
      expect(s.actualPerDay, 10);
      expect(s.paceRatio, 1);
      expect(s.pace, GoalPace.onTrack);
      expect(s.projectedFinish, DateTime(2026, 10, 17), reason: '20 days counting today');
      expect(s.projectedSlip, 0);
    });

    test('behind: the recent pace falls short, the projection lands late', () {
      final entries = [for (var i = -9; i <= 0; i++) e(5, day(i))];
      final s = stats(target: 300, created: day(-9), deadline: day(19), entries: entries);
      expect(s.current, 50);
      expect(s.neededPerDay, 12.5);
      expect(s.actualPerDay, 5);
      expect(s.pace, GoalPace.behind);
      expect(s.projectedFinish, DateTime(2026, 11, 16), reason: '250 ÷ 5 = 50 days from today');
      expect(s.projectedSlip, 30);
    });

    test('ahead: at least 25 % faster than needed', () {
      final entries = [for (var i = -9; i <= 0; i++) e(20, day(i))];
      final s = stats(target: 300, created: day(-9), deadline: day(19), entries: entries);
      expect(s.neededPerDay, 5);
      expect(s.actualPerDay, 20);
      expect(s.pace, GoalPace.ahead);
      expect(s.projectedSlip, lessThan(0));
      expect(s.vsPlan, greaterThan(0));
    });

    test('the actual pace looks back fourteen days at most', () {
      final entries = [
        e(200, day(-40)), // long ago: outside the window
        for (var i = -13; i <= 0; i++) e(2, day(i)),
      ];
      final s = stats(target: 1000, created: day(-40), entries: entries, deadline: day(60));
      expect(s.paceWindow, 14);
      expect(s.actualPerDay, 2);
    });

    test('a young goal measures its pace over its own days', () {
      final s = stats(created: day(-2), entries: [e(30, day(-2)), e(15, day(0))], deadline: day(30));
      expect(s.paceWindow, 3);
      expect(s.actualPerDay, 15);
    });

    test('a back-dated log moves the start earlier', () {
      final s = stats(created: day(0), entries: [e(10, day(-3))]);
      expect(s.start, DateTime(2026, 9, 25));
      expect(s.elapsedDays, 4);
    });

    test('due today: the whole remainder is needed today', () {
      final s = stats(target: 100, entries: [e(90, day(-2))], deadline: day(0));
      expect(s.daysLeft, 1);
      expect(s.neededPerDay, 10);
      expect(s.pace, isNot(GoalPace.overdue));
    });

    test('overdue: the deadline passed short of the target', () {
      final s = stats(target: 100, entries: [e(40, day(-5))], deadline: day(-3));
      expect(s.daysLeft, 0);
      expect(s.daysOverdue, 3);
      expect(s.pace, GoalPace.overdue);
      expect(s.neededPerDay, isNull);
      expect(s.remaining, 60);
    });

    test('paused goals are not judged', () {
      final s = stats(entries: [e(5, day(-1))], deadline: day(10), active: false);
      expect(s.pace, GoalPace.paused);
      expect(s.status, GoalStatus.paused);
    });
  });

  group('pace without a deadline', () {
    test('no deadline: no needed pace, projection from the recent pace', () {
      final s = stats(target: 120, created: day(-3), entries: [e(10, day(-3)), e(10, day(-1)), e(20, day(0))]);
      expect(s.pace, GoalPace.noDeadline);
      expect(s.daysLeft, isNull);
      expect(s.neededPerDay, isNull);
      expect(s.expectedNow, isNull);
      expect(s.actualPerDay, 10);
      // 80 left at 10/day → 8 days counting today.
      expect(s.projectedFinish, DateTime(2026, 10, 5));
      expect(s.projectedSlip, isNull);
    });

    test('no recent logs: no projection', () {
      final s = stats(created: day(-60), entries: [e(10, day(-40))]);
      expect(s.actualPerDay, 0);
      expect(s.projectedFinish, isNull);
      expect(s.pace, GoalPace.noDeadline);
    });

    test('a projection beyond ten years is dropped', () {
      final s = stats(target: 1e7, entries: [e(1, day(0))], created: day(0));
      expect(s.projectedFinish, isNull);
    });
  });

  group('celebration', () {
    test('only the log that reaches the target crosses it', () {
      expect(GoalMath.crossesTarget(before: 90, added: 10, target: 100), isTrue);
      expect(GoalMath.crossesTarget(before: 90, added: 20, target: 100), isTrue);
      expect(GoalMath.crossesTarget(before: 90, added: 5, target: 100), isFalse);
      expect(GoalMath.crossesTarget(before: 100, added: 5, target: 100), isFalse, reason: 'already reached');
      expect(GoalMath.crossesTarget(before: 0, added: 5, target: 0), isFalse);
    });
  });

  group('streaks', () {
    test('counts back from today', () {
      final s = GrowthStreaks.of([day(0), day(-1, hour: 23), day(-2), day(-2, hour: 7), day(-5)], today: today);
      expect(s.current, 3);
      expect(s.best, 3);
      expect(s.loggedToday, isTrue);
      expect(s.atRisk, isFalse);
    });

    test('alive through yesterday until today ends', () {
      final s = GrowthStreaks.of([day(-1), day(-2)], today: today);
      expect(s.current, 2);
      expect(s.loggedToday, isFalse);
      expect(s.atRisk, isTrue);
    });

    test('broken after a missed day; the best run is kept', () {
      final s = GrowthStreaks.of([day(-2), day(-10), day(-11), day(-12), day(-13)], today: today);
      expect(s.current, 0);
      expect(s.best, 4);
    });

    test('future logs are ignored, empty is zero', () {
      expect(GrowthStreaks.of([day(2)], today: today).current, 0);
      final empty = GrowthStreaks.of(const [], today: today);
      expect(empty.current, 0);
      expect(empty.best, 0);
      expect(empty.lastDays(7), everyElement(isFalse));
    });

    test('last seven days, oldest first', () {
      final s = GrowthStreaks.of([day(0), day(-6), day(-3)], today: today);
      expect(s.lastDays(7), [true, false, false, true, false, false, true]);
      expect(s.activeDaysInLast(7), 3);
    });

    test('runs across a month boundary', () {
      final s = GrowthStreaks.of([
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
      ], today: DateTime(2026, 10, 2));
      expect(s.current, 3);
    });
  });

  group('chart data', () {
    test('running total, straight-line plan, target and projection', () {
      final s = stats(
        target: 300,
        created: day(-9, hour: 0),
        deadline: day(19),
        entries: [e(50, day(-5, hour: 12)), e(50, day(-1, hour: 12))],
      );
      final c = GoalChartData.build(s, [e(50, day(-5, hour: 12)), e(50, day(-1, hour: 12))], now: day(0, hour: 18));
      expect(c.origin, DateTime(2026, 9, 19));
      expect(c.actual, const [ChartXY(0, 0), ChartXY(4.5, 50), ChartXY(8.5, 100), ChartXY(9.75, 100)]);
      expect(c.plan, const [ChartXY(0, 0), ChartXY(29, 300)], reason: '19 Sep … 17 Oct, both included');
      expect(c.target, 300);
      expect(c.nowX, 9.75);
      expect(c.projection.first, const ChartXY(9.75, 100));
      expect(c.projection.last.y, closeTo(300, 1e-9));
      expect(c.maxX, greaterThanOrEqualTo(29));
      expect(c.maxY, greaterThan(300));
      expect(c.dateAt(4.5), DateTime(2026, 9, 23));
    });

    test('far projections are cut and interpolated', () {
      final s = stats(target: 1000, created: day(-1, hour: 0), entries: [e(1, day(0, hour: 1))]);
      final c = GoalChartData.build(s, [e(1, day(0, hour: 1))], now: day(0, hour: 12), reach: 30);
      expect(c.plan, isEmpty);
      final end = c.projection.last;
      expect(end.x, closeTo(1.5 + 30, 1e-9), reason: 'now (1.5) + reach');
      expect(end.y, lessThan(1000));
      expect(end.y, greaterThan(1));
    });

    test('a completed goal has no projection', () {
      final s = stats(target: 10, entries: [e(12, day(-1))]);
      final c = GoalChartData.build(s, [e(12, day(-1))], now: day(0));
      expect(c.projection, isEmpty);
      expect(c.maxY, greaterThanOrEqualTo(12));
    });

    test('mirrors x in right-to-left layouts', () {
      expect(GoalChartData.mirror(2, 10, rtl: true), 8);
      expect(GoalChartData.mirror(2, 10, rtl: false), 2);
    });

    test('nice steps', () {
      expect(GoalChartData.niceStep(0), 1);
      expect(GoalChartData.niceStep(0.7), 1);
      expect(GoalChartData.niceStep(1.3), 2);
      expect(GoalChartData.niceStep(2.2), 2.5);
      expect(GoalChartData.niceStep(84), 100);
      expect(GoalChartData.niceStep(420), 500);
      expect(GoalChartData.niceStep(0.03), closeTo(0.05, 1e-12));
    });
  });
}
