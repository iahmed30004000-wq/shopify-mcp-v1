import 'package:flutter/foundation.dart';

import '../../prayer/domain/hijri.dart';
import 'prayer_times_of.dart';

/// Civil-day helpers (a "day" is a date with no time of day).
///
/// Day arithmetic goes through the calendar fields, never `+ Duration(days:)`,
/// so a daylight-saving change cannot move a date by one.
DateTime civilDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addCivilDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Whole civil days from [a] to [b] (negative when [b] is earlier).
int civilDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// One Ramadan on the civil calendar, as the Hijri offset places it.
@immutable
class RamadanSpan {
  RamadanSpan({required this.hijriYear, required DateTime first, required this.length}) : first = civilDay(first);

  final int hijriYear;

  /// 1 Ramadan (civil date).
  final DateTime first;

  /// 29 or 30.
  final int length;

  /// The last day of fasting (29 or 30 Ramadan).
  DateTime get last => addCivilDays(first, length - 1);

  /// 1 Shawwal: the Eid. It is not part of Ramadan.
  DateTime get eidDay => addCivilDays(first, length);

  bool contains(DateTime date) {
    final n = civilDaysBetween(first, date);
    return n >= 0 && n < length;
  }

  /// The day of Ramadan (1…[length]) of [date], or null outside the month.
  int? dayNumberOf(DateTime date) {
    final n = civilDaysBetween(first, date);
    return n >= 0 && n < length ? n + 1 : null;
  }

  /// The civil date of day [day] (1 = [first]).
  DateTime dateOfDay(int day) => addCivilDays(first, day - 1);

  /// The civil date whose Maghrib begins night [night].
  ///
  /// Convention: night N of Ramadan is the evening that BEGINS day N (the
  /// Islamic day starts at Maghrib). So night 1 starts at the Maghrib of the
  /// last day of Sha'ban, and night 27 starts at the Maghrib of 26 Ramadan.
  DateTime eveningOfNight(int night) => addCivilDays(first, night - 2);

  @override
  bool operator ==(Object other) =>
      other is RamadanSpan && other.hijriYear == hijriYear && other.first == first && other.length == length;

  @override
  int get hashCode => Object.hash(hijriYear, first, length);

  @override
  String toString() => 'RamadanSpan($hijriYear, $first, $length days)';
}

/// What the app needs to know about a civil day, in Ramadan terms.
@immutable
class RamadanStatus {
  const RamadanStatus({
    required this.date,
    required this.hijri,
    required this.dayOfRamadan,
    required this.length,
    required this.isEidDay,
    required this.daysUntilNextRamadan,
  });

  final DateTime date;
  final HijriDate hijri;

  /// 1…30 inside Ramadan, null outside.
  final int? dayOfRamadan;

  /// Length of the Ramadan the day belongs to (null outside Ramadan).
  final int? length;

  /// 1 Shawwal.
  final bool isEidDay;

  /// Days to the first day of the next Ramadan that starts strictly after
  /// [date] (inside Ramadan: next year's).
  final int daysUntilNextRamadan;

  bool get isRamadan => dayOfRamadan != null;
  bool get isFirstDay => dayOfRamadan == 1;
  bool get isLastDay => dayOfRamadan != null && dayOfRamadan == length;

  /// The Faith planet's Ramadan atmosphere: on from the first day, off at the
  /// Eid (1 Shawwal is NOT Ramadan).
  bool get atmosphereOn => isRamadan;
}

/// Which edges of Ramadan were crossed while the app was not looking.
@immutable
class RamadanBoundaries {
  const RamadanBoundaries({required this.started, required this.eidReached});

  static const none = RamadanBoundaries(started: false, eidReached: false);

  /// A 1 Ramadan fell in `(lastSeen, now]`.
  final bool started;

  /// A 1 Shawwal fell in `(lastSeen, now]`.
  final bool eidReached;

  bool get any => started || eidReached;
}

/// Ramadan from the Hijri date (Umm al-Qura plus the user's ±1 day offset,
/// the same setting as Part 9b), pure and clock-free: every method takes the
/// date it is asked about, so a test or a hand-changed phone clock behaves.
@immutable
class RamadanCalendar {
  const RamadanCalendar({int offsetDays = 0}) : offsetDays = offsetDays < -1 ? -1 : (offsetDays > 1 ? 1 : offsetDays);

  /// −1, 0 or +1 (+1: the local month started a day earlier).
  final int offsetDays;

  HijriDate hijriOf(DateTime date) => HijriCalendarMath.fromGregorian(civilDay(date), offsetDays: offsetDays);

  bool isRamadan(DateTime date) => hijriOf(date).isRamadan;

  /// 1…30 when [date] is in Ramadan, otherwise null.
  int? dayOfRamadan(DateTime date) {
    final h = hijriOf(date);
    return h.isRamadan ? h.day : null;
  }

  /// 1 Shawwal.
  bool isEidDay(DateTime date) {
    final h = hijriOf(date);
    return h.month == 10 && h.day == 1;
  }

  /// The Ramadan that contains [date], or null.
  RamadanSpan? spanContaining(DateTime date) {
    final h = hijriOf(date);
    if (!h.isRamadan) return null;
    return RamadanSpan(hijriYear: h.year, first: addCivilDays(date, -(h.day - 1)), length: h.monthLength);
  }

  /// The first Ramadan whose first day is strictly after [date].
  RamadanSpan nextSpanAfter(DateTime date) => _next(date, inclusive: false);

  /// The first Ramadan whose first day is on or after [date].
  RamadanSpan nextSpanOnOrAfter(DateTime date) => _next(date, inclusive: true);

  /// The Ramadan of Hijri [year] under this offset.
  RamadanSpan spanOfYear(int year) {
    // 1 Muharram of `year` is near Gregorian 622.54 + 0.970229 × year; start
    // the walk a year and a half before that so rounding can never overshoot.
    final approx = DateTime.utc((622.54 + year * 0.970229).floor(), 1, 1);
    var span = _next(addCivilDays(approx, -550), inclusive: true);
    for (var i = 0; i < 6 && span.hijriYear < year; i++) {
      span = _next(span.first, inclusive: false);
    }
    return span;
  }

  RamadanSpan _next(DateTime date, {required bool inclusive}) {
    final day = civilDay(date);
    final h = hijriOf(day);
    var cursor = addCivilDays(day, -(h.day - 1)); // 1st of the current month
    var month = h.month;
    // At most a full Hijri year of month-hops; 14 leaves room for the
    // skipped current month and for data oddities.
    for (var i = 0; i < 14; i++) {
      if (month == 9 && (inclusive ? !cursor.isBefore(day) : cursor.isAfter(day))) {
        final c = hijriOf(cursor);
        return RamadanSpan(hijriYear: c.year, first: cursor, length: c.monthLength);
      }
      cursor = addCivilDays(cursor, hijriOf(cursor).monthLength);
      month = month == 12 ? 1 : month + 1;
    }
    // Unreachable for a sane calendar; fail loudly rather than loop.
    throw StateError('No Ramadan found after $date');
  }

  RamadanStatus statusOn(DateTime date) {
    final day = civilDay(date);
    final h = hijriOf(day);
    final next = nextSpanAfter(day);
    return RamadanStatus(
      date: day,
      hijri: h,
      dayOfRamadan: h.isRamadan ? h.day : null,
      length: h.isRamadan ? h.monthLength : null,
      isEidDay: h.month == 10 && h.day == 1,
      daysUntilNextRamadan: civilDaysBetween(day, next.first),
    );
  }

  /// Days until the next Ramadan begins (strictly after [date]).
  int daysUntilNextRamadan(DateTime date) => civilDaysBetween(civilDay(date), nextSpanAfter(date).first);

  /// Which edges lie in `(lastSeen, now]`: what to catch up on when the app
  /// opens after being closed. A clock set backwards ([now] not after
  /// [lastSeen]) crosses nothing.
  RamadanBoundaries boundariesBetween(DateTime lastSeen, DateTime now) {
    final from = civilDay(lastSeen), to = civilDay(now);
    if (!to.isAfter(from)) return RamadanBoundaries.none;
    final next = nextSpanAfter(from);
    final started = !next.first.isAfter(to);
    final current = spanContaining(from);
    final eidSpan = current ?? next;
    final eidReached = !eidSpan.eidDay.isAfter(to);
    return RamadanBoundaries(started: started, eidReached: eidReached);
  }

  /// The night of Ramadan (1…30) that [now] falls in, or null by day, outside
  /// Ramadan, and on the Eid night when the month had no night of that number.
  ///
  /// Night N is the evening that begins day N (see
  /// [RamadanSpan.eveningOfNight]); it lasts from that Maghrib to the next
  /// Fajr. [now] may be a zone-aware wall-clock time (`PrayerSchedule.wallClock`):
  /// its y/m/d pick the civil day and comparisons are by instant.
  int? nightAt(DateTime now, PrayerTimesOf timesOf) {
    final d = civilDay(now);
    if (!now.isBefore(timesOf(d).maghrib)) return dayOfRamadan(addCivilDays(d, 1));
    final yesterday = addCivilDays(d, -1);
    if (!now.isBefore(timesOf(yesterday).maghrib) && now.isBefore(timesOf(d).fajr)) return dayOfRamadan(d);
    return null;
  }
}
