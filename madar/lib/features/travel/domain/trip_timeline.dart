import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/domain/enums.dart';
import '../../prayer/domain/time_zones.dart';

/// Calendar-day arithmetic that never trips over a daylight-saving change
/// (a 23- or 25-hour day): days are compared by their year / month / day.
abstract final class TravelDates {
  /// Midnight of [d]'s own calendar day.
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Where a trip stands, as the lists group it.
enum TripPhase {
  /// No departure date yet (listed with the upcoming trips, last).
  undated,
  upcoming,
  current,
  past,
}

/// "Today" at home (the device's calendar) and at the destination (its own
/// zone's calendar) – they differ around midnight when the zones differ.
@immutable
class TravelToday {
  const TravelToday({required this.home, required this.destination});

  /// [now] on the device calendar and in [zone] (the device's when null).
  factory TravelToday.at(DateTime now, {tz.Location? zone}) =>
      TravelToday(home: TravelDates.day(now.toLocal()), destination: MadarTimeZones.dateIn(now, zone));

  /// Both calendars on the same day (tests, undated destinations).
  factory TravelToday.same(DateTime day) => TravelToday(home: TravelDates.day(day), destination: TravelDates.day(day));

  final DateTime home;
  final DateTime destination;
}

/// What a countdown pill says.
enum CountdownKind {
  /// No dates.
  undated,

  /// Departure ahead: [TripCountdown.days] (0 = today, 1 = tomorrow).
  startsIn,

  /// Under way: day [TripCountdown.dayIndex] of [TripCountdown.length]
  /// (length null for an open-ended trip).
  underway,

  /// Over: ended [TripCountdown.days] days ago.
  ended,

  /// Marked finished by hand before its dates said so.
  finished,
}

@immutable
class TripCountdown {
  const TripCountdown(this.kind, {this.days = 0, this.dayIndex = 0, this.length});

  final CountdownKind kind;
  final int days;
  final int dayIndex;
  final int? length;

  @override
  bool operator ==(Object other) =>
      other is TripCountdown &&
      other.kind == kind &&
      other.days == days &&
      other.dayIndex == dayIndex &&
      other.length == length;

  @override
  int get hashCode => Object.hash(kind, days, dayIndex, length);

  @override
  String toString() => 'TripCountdown($kind, days: $days, day: $dayIndex/$length)';
}

/// A trip's dates and the rules that derive its status from them.
///
/// * Before the departure day (on the home calendar) a trip is *planned*.
/// * From the departure day it is *active* – until the day after its last
///   day has begun both at home and at the destination (a trip to New York
///   that ends on the 10th is still under way at 01:00 on the 11th in
///   Amman, when it is the evening of the 10th there).
/// * An open-ended trip (no return date) stays active until it is marked
///   finished.
/// * No dates: planned.
@immutable
class TripTimeline {
  const TripTimeline({this.start, this.end});

  /// Calendar days (only their y/m/d count). An end before the start is
  /// read as a one-day trip.
  final DateTime? start;
  final DateTime? end;

  DateTime? get _start => start ?? end;

  DateTime? get _end {
    final s = _start;
    final e = end;
    if (s == null || e == null) return null;
    return TravelDates.daysBetween(s, e) < 0 ? s : e;
  }

  bool get hasDates => _start != null;

  /// Days of the trip, inclusive (null when open-ended or undated).
  int? get lengthDays {
    final s = _start, e = _end;
    if (s == null || e == null) return null;
    return TravelDates.daysBetween(s, e) + 1;
  }

  /// The status the dates give on [today].
  TripStatus derive(TravelToday today) {
    final s = _start;
    if (s == null) return TripStatus.planned;
    if (TravelDates.daysBetween(today.home, s) > 0) return TripStatus.planned;
    final e = _end;
    if (e != null && TravelDates.daysBetween(e, today.home) > 0 && TravelDates.daysBetween(e, today.destination) > 0) {
      return TripStatus.done;
    }
    return TripStatus.active;
  }

  /// The status to show: a manual choice wins over the dates.
  TripStatus effective({required TripStatus stored, required bool manual, required TravelToday today}) =>
      manual ? stored : derive(today);

  /// The list a trip with [status] belongs in.
  TripPhase phaseOf(TripStatus status) => switch (status) {
    TripStatus.planned => hasDates ? TripPhase.upcoming : TripPhase.undated,
    TripStatus.active => TripPhase.current,
    TripStatus.done => TripPhase.past,
  };

  /// Calendar days from home's today to departure (negative once gone).
  int? daysUntilStart(DateTime homeToday) {
    final s = _start;
    return s == null ? null : TravelDates.daysBetween(homeToday, s);
  }

  /// 1-based day of the trip on the destination's calendar (clamped to the
  /// trip), or null before departure / without dates.
  int? dayIndexOn(TravelToday today) {
    final s = _start;
    if (s == null) return null;
    final i = TravelDates.daysBetween(s, today.destination) + 1;
    if (i < 1) return TravelDates.daysBetween(s, today.home) >= 0 ? 1 : null;
    final len = lengthDays;
    return len == null ? i : i.clamp(1, len);
  }

  /// The countdown for a trip whose effective status is [status].
  TripCountdown countdown(TripStatus status, TravelToday today) {
    final s = _start;
    if (s == null) return const TripCountdown(CountdownKind.undated);
    switch (status) {
      case TripStatus.planned:
        final d = daysUntilStart(today.home)!;
        // A trip held back by hand past its date still counts from today.
        return TripCountdown(CountdownKind.startsIn, days: d < 0 ? 0 : d);
      case TripStatus.active:
        return TripCountdown(CountdownKind.underway, dayIndex: dayIndexOn(today) ?? 1, length: lengthDays);
      case TripStatus.done:
        final e = _end ?? s;
        final ago = TravelDates.daysBetween(e, today.home);
        if (ago <= 0) return const TripCountdown(CountdownKind.finished);
        return TripCountdown(CountdownKind.ended, days: ago);
    }
  }

  /// Every day of the trip (at most [max]); just [fallback] without dates.
  List<DateTime> days({required DateTime fallback, int max = 45}) {
    final s = _start;
    if (s == null) return [TravelDates.day(fallback)];
    final len = (lengthDays ?? 1).clamp(1, max);
    return [for (var i = 0; i < len; i++) TravelDates.addDays(s, i)];
  }
}
