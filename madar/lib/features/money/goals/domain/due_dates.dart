/// Calendar-day arithmetic for jars, debts and recurring obligations (pure
/// Dart, time-zone and DST safe: every value is a local calendar day at
/// midnight, and day differences are counted on the calendar, never from
/// elapsed hours).
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';

/// Calendar helpers.
abstract final class CalendarDays {
  /// [d]'s calendar day (local midnight).
  static DateTime of(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Number of days in [month] of [year] (leap years included).
  static int inMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Whether [d] is the last day of its month.
  static bool isMonthEnd(DateTime d) => d.day == inMonth(d.year, d.month);

  /// Whole calendar days from [from] to [to] (negative when [to] is
  /// earlier). Counted in UTC so a DST switch never shifts it.
  static int between(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// [d] + [days] calendar days.
  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// [d] + [months] calendar months on day [anchorDay] (default: [d]'s day),
  /// clamped to the target month's length: Jan 31 + 1 → Feb 28 (29 in a leap
  /// year); with anchor 31, Feb 28 + 1 → Mar 31.
  static DateTime addMonths(DateTime d, int months, {int? anchorDay}) {
    final index = d.year * 12 + (d.month - 1) + months;
    final year = index ~/ 12;
    final month = index % 12 + 1;
    final day = (anchorDay ?? d.day).clamp(1, 31);
    final last = inMonth(year, month);
    return DateTime(year, month, day > last ? last : day);
  }

  /// Whole calendar months from [from] to [to], counting a month only once
  /// its day is reached (Jan 31 → Feb 28 is 0 months; → Mar 1 is 1).
  static int monthsBetween(DateTime from, DateTime to) {
    if (to.isBefore(from)) return -monthsBetween(to, from);
    var months = (to.year - from.year) * 12 + to.month - from.month;
    if (months > 0 && addMonths(from, months).isAfter(of(to))) months--;
    return months;
  }
}

/// A recurrence: every [interval] weeks, months or years.
@immutable
class RecurrenceRule {
  const RecurrenceRule(this.frequency, [int interval = 1]) : _interval = interval;

  final Recurrence frequency;
  final int _interval;

  /// The stored interval, normalised to at least 1 (an imported 0 or a
  /// negative value means "every period").
  int get interval => _interval < 1 ? 1 : _interval;

  /// Months per step (weekly: 0).
  int get _monthStep => switch (frequency) {
    Recurrence.weekly => 0,
    Recurrence.monthly => interval,
    Recurrence.yearly => 12 * interval,
  };

  /// The due date after [due]. Monthly and yearly steps land on
  /// [anchorDay] (default: [due]'s day), clamped to the month's length.
  DateTime next(DateTime due, {int? anchorDay}) => switch (frequency) {
    Recurrence.weekly => CalendarDays.addDays(due, 7 * interval),
    _ => CalendarDays.addMonths(CalendarDays.of(due), _monthStep, anchorDay: anchorDay),
  };

  /// The due date before [due] (the inverse of [next]).
  DateTime previous(DateTime due, {int? anchorDay}) => switch (frequency) {
    Recurrence.weekly => CalendarDays.addDays(due, -7 * interval),
    _ => CalendarDays.addMonths(CalendarDays.of(due), -_monthStep, anchorDay: anchorDay),
  };

  /// Due dates from [first] (inclusive) up to [until] (inclusive), at most
  /// [max]. The anchor stays fixed, so a 31st keeps returning to the 31st.
  List<DateTime> occurrences(DateTime first, DateTime until, {int? anchorDay, int max = 400}) {
    final out = <DateTime>[];
    final anchor = anchorDay ?? first.day;
    final end = CalendarDays.of(until);
    for (var i = 0; out.length < max; i++) {
      final d = _nth(CalendarDays.of(first), i, anchor);
      if (d.isAfter(end)) break;
      out.add(d);
    }
    return out;
  }

  /// The next [count] due dates starting with [first].
  List<DateTime> upcoming(DateTime first, int count, {int? anchorDay}) {
    final anchor = anchorDay ?? first.day;
    return [for (var i = 0; i < count; i++) _nth(CalendarDays.of(first), i, anchor)];
  }

  DateTime _nth(DateTime first, int i, int anchor) => switch (frequency) {
    Recurrence.weekly => CalendarDays.addDays(first, 7 * interval * i),
    _ => i == 0 ? first : CalendarDays.addMonths(first, _monthStep * i, anchorDay: anchor),
  };

  /// Calendar months between two occurrences (null for weekly rules, whose
  /// monthly share depends on the weeks-per-month setting).
  int? get monthsPerOccurrence => frequency == Recurrence.weekly ? null : _monthStep;

  /// The day of the month a monthly / yearly obligation really falls on.
  ///
  /// The table stores only the next due date, and "Paid" may have clamped
  /// it (a 31st became Feb 28). The anchor is recovered from the payment
  /// [history] (due dates already paid or skipped, any order): walking back
  /// from [nextDue] through consecutive month-end dates, the first date that
  /// is not a month end gives the anchor; if all are month ends, the
  /// largest day wins (Jan 31 → Feb 28 → Mar 31; Feb 29 2028 → Feb 28 2029
  /// → … → Feb 29 2032). Weekly rules have no anchor (null).
  int? anchorDayFor(DateTime nextDue, Iterable<DateTime> history) {
    if (frequency == Recurrence.weekly) return null;
    final due = CalendarDays.of(nextDue);
    if (!CalendarDays.isMonthEnd(due)) return due.day;
    final past = [
      for (final h in history)
        if (CalendarDays.of(h).isBefore(due)) CalendarDays.of(h),
    ]..sort((a, b) => b.compareTo(a));
    var anchor = due.day;
    for (final h in past) {
      if (!CalendarDays.isMonthEnd(h)) return h.day > anchor ? h.day : anchor;
      if (h.day > anchor) anchor = h.day;
      if (anchor == 31) break;
    }
    return anchor;
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule && other.frequency == frequency && other.interval == interval;

  @override
  int get hashCode => Object.hash(frequency, interval);

  @override
  String toString() => 'RecurrenceRule(${frequency.name} × $interval)';
}

/// How close a due date is.
enum DueState {
  /// Before today.
  overdue,

  /// Today.
  today,

  /// Within the "soon" window (1..soonDays days ahead).
  soon,

  /// Further ahead.
  later,

  /// No due date.
  none,
}

/// Classifies [due] against [today]; [soonDays] is the look-ahead window.
DueState dueStateOf(DateTime? due, DateTime today, {int soonDays = 7}) {
  if (due == null) return DueState.none;
  final days = CalendarDays.between(today, due);
  if (days < 0) return DueState.overdue;
  if (days == 0) return DueState.today;
  if (days <= soonDays) return DueState.soon;
  return DueState.later;
}
