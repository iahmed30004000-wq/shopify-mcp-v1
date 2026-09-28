import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';

/// A date of the Hijri calendar (Umm al-Qura, plus the user's day offset).
@immutable
class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day, required this.monthLength});

  final int year;

  /// 1 = Muharram … 12 = Dhu al-Hijjah.
  final int month;
  final int day;

  /// 29 or 30.
  final int monthLength;

  bool get isRamadan => month == 9;

  @override
  bool operator ==(Object other) =>
      other is HijriDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HijriDate($year-$month-$day)';
}

/// Gregorian → Hijri conversion (pure).
///
/// The Umm al-Qura calendar (the `hijri` package's table, 1356–1500 AH) is
/// the base; outside its range the tabular (arithmetic) Islamic calendar is
/// used. [offsetDays] (−2…+2) follows local moon sighting: +1 means the
/// month started a day earlier locally, so the local date is one day ahead.
abstract final class HijriCalendarMath {
  /// The Hijri date of the civil date of [date] (its year / month / day).
  static HijriDate fromGregorian(DateTime date, {int offsetDays = 0}) {
    final shifted = DateTime.utc(date.year, date.month, date.day + offsetDays.clamp(-2, 2));
    try {
      final h = HijriCalendar.fromDate(DateTime(shifted.year, shifted.month, shifted.day));
      if (h.hYear < 1 || h.hMonth < 1 || h.hMonth > 12 || h.hDay < 1) throw StateError('out of range');
      return HijriDate(year: h.hYear, month: h.hMonth, day: h.hDay, monthLength: h.lengthOfMonth);
    } catch (_) {
      return _tabular(shifted);
    }
  }

  /// The Hijri date at the instant [now] (read as the location's wall-clock
  /// time): with [rollAtMaghrib] the new Hijri day begins at [maghrib] (the
  /// same day's Maghrib) instead of midnight.
  static HijriDate at(DateTime now, {int offsetDays = 0, bool rollAtMaghrib = false, DateTime? maghrib}) {
    var civil = DateTime.utc(now.year, now.month, now.day);
    if (rollAtMaghrib && maghrib != null && !now.isBefore(maghrib)) {
      civil = civil.add(const Duration(days: 1));
    }
    return fromGregorian(civil, offsetDays: offsetDays);
  }

  /// The Gregorian date (UTC midnight) of Hijri [year]-[month]-[day] in the
  /// Umm al-Qura calendar, without an offset.
  static DateTime? toGregorian(int year, int month, int day) {
    try {
      final g = HijriCalendar().hijriToGregorian(year, month, day);
      return DateTime.utc(g.year, g.month, g.day);
    } catch (_) {
      return null;
    }
  }

  // Tabular Islamic calendar (civil epoch: 1 Muharram 1 AH = JDN 1948440),
  // used only outside the Umm al-Qura table.
  static HijriDate _tabular(DateTime utcDate) {
    final jdn = _julianDay(utcDate.year, utcDate.month, utcDate.day);
    final year = ((30 * (jdn - 1948439.5) + 10646) / 10631).floor();
    final month = (((jdn - (29 + _jdnOf(year, 1, 1))) / 29.5).ceil() + 1).clamp(1, 12);
    final day = jdn - _jdnOf(year, month, 1) + 1;
    final length = (month.isOdd || (month == 12 && _isLeap(year))) ? 30 : 29;
    return HijriDate(year: year, month: month, day: day, monthLength: length);
  }

  static int _jdnOf(int year, int month, int day) =>
      day + (29.5 * (month - 1)).ceil() + (year - 1) * 354 + ((3 + 11 * year) / 30).floor() + 1948439;

  static bool _isLeap(int year) => (14 + 11 * year) % 30 < 11;

  static int _julianDay(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
  }
}
