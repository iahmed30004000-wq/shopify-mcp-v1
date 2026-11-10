import 'package:flutter/foundation.dart';

import 'prayer_times_of.dart';
import 'ramadan_calendar.dart';

/// Where the day stands relative to the fast.
enum FastPhase {
  /// Between Fajr and Maghrib of a Ramadan day: counting down to iftar.
  fasting,

  /// From the Maghrib that begins a Ramadan night until Fajr: counting down
  /// to the end of suhoor (this includes the night before the first day).
  suhoorNight,

  /// No fast today and none about to begin (outside Ramadan, by day before
  /// the first night, and after the last iftar).
  idle,
}

/// The moment a countdown aims at.
enum FastTarget {
  /// Maghrib.
  iftar,

  /// Fajr: suhoor must end.
  suhoorEnd,
}

/// The next iftar / end-of-suhoor and the time left, from injected prayer
/// times. Pure: the same inputs always give the same answer, nothing is
/// remembered between calls, so a traveller's new times (or a clock changed
/// by hand) are simply a different input.
@immutable
class FastCountdown {
  const FastCountdown({required this.phase, this.target, this.at, this.remaining = Duration.zero, this.dayOfRamadan});

  static const idle = FastCountdown(phase: FastPhase.idle);

  final FastPhase phase;
  final FastTarget? target;

  /// The target instant.
  final DateTime? at;

  /// Real elapsed time until [at] (an instant difference, so a clock change
  /// between now and then is already counted); zero when idle.
  final Duration remaining;

  /// The day of Ramadan this fast belongs to (1…30).
  final int? dayOfRamadan;

  /// [fastDayOf] gives the day number of a civil day on which a fast is held,
  /// or null where there is none; [compute] fits it to a [RamadanCalendar].
  /// [now] may be a zone-aware wall-clock time; comparisons are by instant.
  static FastCountdown of({
    required DateTime now,
    required PrayerTimesOf timesOf,
    required int? Function(DateTime civilDay) fastDayOf,
  }) {
    final today = civilDay(now);
    // 1. Inside a fast? (Yesterday's is checked too: where Maghrib falls after
    //    midnight, the fast of the previous civil day is still running.)
    for (final offset in const [-1, 0, 1]) {
      final day = addCivilDays(today, offset);
      final n = fastDayOf(day);
      if (n == null) continue;
      final t = timesOf(day);
      if (!now.isBefore(t.fajr) && now.isBefore(t.maghrib)) {
        return FastCountdown(
          phase: FastPhase.fasting,
          target: FastTarget.iftar,
          at: t.maghrib,
          remaining: t.maghrib.difference(now),
          dayOfRamadan: n,
        );
      }
    }
    // 2. A night that leads into a fast: it begins at the previous day's
    //    Maghrib, so the daytime before the first night stays idle.
    FastCountdown? best;
    for (final offset in const [-1, 0, 1]) {
      final day = addCivilDays(today, offset);
      final n = fastDayOf(day);
      if (n == null) continue;
      final fajr = timesOf(day).fajr;
      final nightBegan = !now.isBefore(timesOf(addCivilDays(day, -1)).maghrib);
      if (!nightBegan || !fajr.isAfter(now)) continue;
      if (best == null || fajr.isBefore(best.at!)) {
        best = FastCountdown(
          phase: FastPhase.suhoorNight,
          target: FastTarget.suhoorEnd,
          at: fajr,
          remaining: fajr.difference(now),
          dayOfRamadan: n,
        );
      }
    }
    return best ?? idle;
  }

  static FastCountdown compute({
    required DateTime now,
    required PrayerTimesOf timesOf,
    required RamadanCalendar calendar,
  }) => of(now: now, timesOf: timesOf, fastDayOf: calendar.dayOfRamadan);

  @override
  bool operator ==(Object other) =>
      other is FastCountdown &&
      other.phase == phase &&
      other.target == target &&
      other.at == at &&
      other.remaining == remaining &&
      other.dayOfRamadan == dayOfRamadan;

  @override
  int get hashCode => Object.hash(phase, target, at, remaining, dayOfRamadan);
}

/// Suhoor-end and iftar of one day of Ramadan: what to arm notifications on.
@immutable
class RamadanDayTimes {
  const RamadanDayTimes({required this.dayOfRamadan, required this.date, required this.suhoorEnd, required this.iftar});

  final int dayOfRamadan;
  final DateTime date;

  /// Fajr.
  final DateTime suhoorEnd;

  /// Maghrib.
  final DateTime iftar;
}

/// Every day of [span] with its suhoor-end and iftar from [timesOf]. Call it
/// again with the new times when the location changes.
List<RamadanDayTimes> ramadanDayTimes(RamadanSpan span, PrayerTimesOf timesOf) => [
  for (var n = 1; n <= span.length; n++)
    () {
      final date = span.dateOfDay(n);
      final t = timesOf(date);
      return RamadanDayTimes(dayOfRamadan: n, date: date, suhoorEnd: t.fajr, iftar: t.maghrib);
    }(),
];
