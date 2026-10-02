import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/goals/domain/due_dates.dart';
import 'package:madar/features/money/goals/domain/obligation_plan.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

/// Pays [periods] times from [first], feeding the history back like the
/// service does, and returns every due date visited (first included).
List<DateTime> payChain(Recurrence f, int interval, DateTime first, int periods) {
  final history = <DateTime>[];
  var next = first;
  final out = [next];
  for (var i = 0; i < periods; i++) {
    final state = ObligationState.compute(
      frequency: f,
      interval: interval,
      nextDue: next,
      today: d(2000, 1, 1),
      history: history,
    );
    final step = state.advance();
    history.add(step.paidDue);
    next = step.nextDue;
    out.add(next);
  }
  return out;
}

void main() {
  group('CalendarDays', () {
    test('days in month and month ends, leap years included', () {
      expect(CalendarDays.inMonth(2026, 2), 28);
      expect(CalendarDays.inMonth(2028, 2), 29);
      expect(CalendarDays.inMonth(2100, 2), 28);
      expect(CalendarDays.inMonth(2000, 2), 29);
      expect(CalendarDays.inMonth(2026, 4), 30);
      expect(CalendarDays.inMonth(2026, 12), 31);
      expect(CalendarDays.isMonthEnd(d(2026, 2, 28)), isTrue);
      expect(CalendarDays.isMonthEnd(d(2028, 2, 28)), isFalse);
      expect(CalendarDays.isMonthEnd(d(2026, 9, 30)), isTrue);
    });

    test('addMonths clamps to the month and honours the anchor', () {
      expect(CalendarDays.addMonths(d(2026, 1, 31), 1), d(2026, 2, 28));
      expect(CalendarDays.addMonths(d(2028, 1, 31), 1), d(2028, 2, 29));
      expect(CalendarDays.addMonths(d(2026, 2, 28), 1), d(2026, 3, 28));
      expect(CalendarDays.addMonths(d(2026, 2, 28), 1, anchorDay: 31), d(2026, 3, 31));
      expect(CalendarDays.addMonths(d(2026, 2, 28), 2, anchorDay: 31), d(2026, 4, 30));
      expect(CalendarDays.addMonths(d(2026, 11, 15), 3), d(2027, 2, 15));
      expect(CalendarDays.addMonths(d(2026, 1, 15), -1), d(2025, 12, 15));
      expect(CalendarDays.addMonths(d(2026, 3, 31), -1), d(2026, 2, 28));
      expect(CalendarDays.addMonths(d(2028, 2, 29), 12), d(2029, 2, 28));
      expect(CalendarDays.addMonths(d(2028, 2, 29), 48), d(2032, 2, 29));
    });

    test('between counts calendar days, not hours', () {
      expect(CalendarDays.between(d(2026, 9, 29), d(2026, 10, 1)), 2);
      expect(CalendarDays.between(d(2026, 10, 1), d(2026, 9, 29)), -2);
      // A DST switch (Europe: 29 Mar 2026) between the dates changes nothing.
      expect(CalendarDays.between(DateTime(2026, 3, 28, 23, 30), DateTime(2026, 3, 30, 0, 10)), 2);
      expect(CalendarDays.between(d(2026, 1, 1), d(2027, 1, 1)), 365);
      expect(CalendarDays.between(d(2028, 1, 1), d(2029, 1, 1)), 366);
    });

    test('addDays stays on midnight across month and year ends', () {
      expect(CalendarDays.addDays(d(2026, 12, 29), 7), d(2027, 1, 5));
      expect(CalendarDays.addDays(d(2026, 3, 1), -1), d(2026, 2, 28));
    });

    test('monthsBetween counts a month only once its day is reached', () {
      expect(CalendarDays.monthsBetween(d(2026, 9, 29), d(2026, 12, 29)), 3);
      expect(CalendarDays.monthsBetween(d(2026, 9, 29), d(2026, 12, 28)), 2);
      expect(CalendarDays.monthsBetween(d(2026, 1, 31), d(2026, 2, 28)), 1);
      expect(CalendarDays.monthsBetween(d(2026, 1, 31), d(2026, 2, 27)), 0);
      expect(CalendarDays.monthsBetween(d(2026, 9, 29), d(2026, 10, 15)), 0);
      expect(CalendarDays.monthsBetween(d(2026, 9, 29), d(2027, 9, 29)), 12);
      expect(CalendarDays.monthsBetween(d(2026, 12, 29), d(2026, 9, 29)), -3);
    });
  });

  group('RecurrenceRule', () {
    test('weekly, monthly and yearly steps with intervals', () {
      expect(const RecurrenceRule(Recurrence.weekly).next(d(2026, 9, 29)), d(2026, 10, 6));
      expect(const RecurrenceRule(Recurrence.weekly, 2).next(d(2026, 12, 24)), d(2027, 1, 7));
      expect(const RecurrenceRule(Recurrence.monthly).next(d(2026, 9, 15)), d(2026, 10, 15));
      expect(const RecurrenceRule(Recurrence.monthly, 3).next(d(2026, 11, 30)), d(2027, 2, 28));
      expect(const RecurrenceRule(Recurrence.yearly).next(d(2026, 9, 1)), d(2027, 9, 1));
      expect(const RecurrenceRule(Recurrence.yearly, 2).next(d(2026, 9, 1)), d(2028, 9, 1));
    });

    test('a zero or negative interval means every period', () {
      expect(const RecurrenceRule(Recurrence.monthly, 0).interval, 1);
      expect(const RecurrenceRule(Recurrence.monthly, -3).next(d(2026, 1, 10)), d(2026, 2, 10));
    });

    test('previous inverts next', () {
      const rule = RecurrenceRule(Recurrence.monthly);
      expect(rule.previous(d(2026, 3, 31), anchorDay: 31), d(2026, 2, 28));
      expect(rule.previous(d(2026, 2, 28), anchorDay: 31), d(2026, 1, 31));
      expect(const RecurrenceRule(Recurrence.weekly, 2).previous(d(2026, 1, 7)), d(2025, 12, 24));
    });

    test('weekly steps are calendar days even across a DST switch', () {
      // Clocks go forward in many zones on the last Sunday of March.
      expect(const RecurrenceRule(Recurrence.weekly).next(d(2026, 3, 25)), d(2026, 4, 1));
      expect(const RecurrenceRule(Recurrence.weekly).next(d(2026, 10, 21)), d(2026, 10, 28));
    });

    test('occurrences keep the anchor', () {
      const rule = RecurrenceRule(Recurrence.monthly);
      expect(rule.occurrences(d(2026, 1, 31), d(2026, 5, 31)), [
        d(2026, 1, 31),
        d(2026, 2, 28),
        d(2026, 3, 31),
        d(2026, 4, 30),
        d(2026, 5, 31),
      ]);
      expect(rule.occurrences(d(2026, 1, 31), d(2026, 1, 30)), isEmpty);
      expect(rule.upcoming(d(2026, 2, 28), 3, anchorDay: 31), [d(2026, 2, 28), d(2026, 3, 31), d(2026, 4, 30)]);
    });

    group('anchorDayFor', () {
      const monthly = RecurrenceRule(Recurrence.monthly);
      test('a date that is not a month end is its own anchor', () {
        expect(monthly.anchorDayFor(d(2026, 3, 15), [d(2026, 2, 15)]), 15);
        expect(monthly.anchorDayFor(d(2028, 2, 28), [d(2028, 1, 28)]), 28);
      });
      test('a clamped month end recovers the anchor from the history', () {
        expect(monthly.anchorDayFor(d(2026, 2, 28), [d(2026, 1, 31)]), 31);
        expect(monthly.anchorDayFor(d(2026, 2, 28), [d(2026, 1, 30)]), 30);
        expect(monthly.anchorDayFor(d(2026, 2, 28), [d(2026, 1, 29)]), 29);
        expect(monthly.anchorDayFor(d(2026, 2, 28), [d(2026, 1, 28)]), 28);
        expect(monthly.anchorDayFor(d(2026, 4, 30), [d(2026, 3, 31), d(2026, 2, 28), d(2026, 1, 31)]), 31);
      });
      test('without history a month end is taken literally', () {
        expect(monthly.anchorDayFor(d(2026, 2, 28), const []), 28);
        expect(monthly.anchorDayFor(d(2026, 4, 30), const []), 30);
      });
      test('future history entries are ignored', () {
        expect(monthly.anchorDayFor(d(2026, 2, 28), [d(2026, 3, 31)]), 28);
      });
      test('weekly rules have no anchor', () {
        expect(const RecurrenceRule(Recurrence.weekly).anchorDayFor(d(2026, 2, 28), [d(2026, 2, 21)]), isNull);
      });
    });
  });

  group('Paid advances the next due date', () {
    test('monthly on the 31st returns to the 31st after short months', () {
      expect(payChain(Recurrence.monthly, 1, d(2026, 1, 31), 12), [
        d(2026, 1, 31),
        d(2026, 2, 28),
        d(2026, 3, 31),
        d(2026, 4, 30),
        d(2026, 5, 31),
        d(2026, 6, 30),
        d(2026, 7, 31),
        d(2026, 8, 31),
        d(2026, 9, 30),
        d(2026, 10, 31),
        d(2026, 11, 30),
        d(2026, 12, 31),
        d(2027, 1, 31),
      ]);
    });

    test('monthly on the 30th passes February (leap and common)', () {
      expect(payChain(Recurrence.monthly, 1, d(2028, 1, 30), 3), [
        d(2028, 1, 30),
        d(2028, 2, 29),
        d(2028, 3, 30),
        d(2028, 4, 30),
      ]);
      expect(payChain(Recurrence.monthly, 1, d(2027, 1, 29), 2), [d(2027, 1, 29), d(2027, 2, 28), d(2027, 3, 29)]);
    });

    test('monthly on the 28th stays on the 28th', () {
      expect(payChain(Recurrence.monthly, 1, d(2026, 1, 28), 3), [
        d(2026, 1, 28),
        d(2026, 2, 28),
        d(2026, 3, 28),
        d(2026, 4, 28),
      ]);
    });

    test('every 3 months from Nov 30 keeps the 30th', () {
      expect(payChain(Recurrence.monthly, 3, d(2026, 11, 30), 3), [
        d(2026, 11, 30),
        d(2027, 2, 28),
        d(2027, 5, 30),
        d(2027, 8, 30),
      ]);
    });

    test('yearly on Feb 29 comes back in the next leap year', () {
      expect(payChain(Recurrence.yearly, 1, d(2028, 2, 29), 4), [
        d(2028, 2, 29),
        d(2029, 2, 28),
        d(2030, 2, 28),
        d(2031, 2, 28),
        d(2032, 2, 29),
      ]);
    });

    test('yearly every 2 years and weekly every 2 weeks', () {
      expect(payChain(Recurrence.yearly, 2, d(2026, 9, 1), 2), [d(2026, 9, 1), d(2028, 9, 1), d(2030, 9, 1)]);
      expect(payChain(Recurrence.weekly, 2, d(2026, 12, 17), 3), [
        d(2026, 12, 17),
        d(2026, 12, 31),
        d(2027, 1, 14),
        d(2027, 1, 28),
      ]);
    });
  });

  group('ObligationState', () {
    test('due states and periods due', () {
      final today = d(2026, 9, 29);
      ObligationState s(DateTime due, {Recurrence f = Recurrence.monthly, bool active = true}) =>
          ObligationState.compute(frequency: f, interval: 1, nextDue: due, today: today, active: active);
      expect(s(d(2026, 9, 29)).dueState, DueState.today);
      expect(s(d(2026, 9, 29)).periodsDue, 1);
      expect(s(d(2026, 10, 3)).dueState, DueState.soon);
      expect(s(d(2026, 10, 3)).periodsDue, 0);
      expect(s(d(2026, 10, 3)).daysToDue, 4);
      expect(s(d(2026, 10, 30)).dueState, DueState.later);
      expect(s(d(2026, 9, 20)).dueState, DueState.overdue);
      expect(s(d(2026, 9, 20)).periodsDue, 1);
      expect(s(d(2026, 7, 20)).periodsDue, 3);
      expect(s(d(2026, 9, 1), f: Recurrence.weekly).periodsDue, 5);
      expect(s(d(2026, 9, 20), active: false).dueState, DueState.none);
    });

    test('dueStateOf', () {
      final today = d(2026, 9, 29);
      expect(dueStateOf(null, today), DueState.none);
      expect(dueStateOf(d(2026, 9, 28), today), DueState.overdue);
      expect(dueStateOf(d(2026, 10, 6), today), DueState.soon);
      expect(dueStateOf(d(2026, 10, 7), today), DueState.later);
      expect(dueStateOf(d(2026, 10, 7), today, soonDays: 14), DueState.soon);
    });
  });
}
