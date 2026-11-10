import 'package:madar/features/fasting/domain/fasting_models.dart';
import 'package:madar/features/prayer/domain/hijri.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

/// An independent view of the Hijri calendar for the tests: built from
/// `toGregorian` (month starts), never from the engine's own `fromGregorian`
/// loop, so the rules are checked against the table and not against themselves.
class HijriYearView {
  HijriYearView(this.year) {
    for (var m = 1; m <= 12; m++) {
      final s = _local(HijriCalendarMath.toGregorian(year, m, 1)!);
      final next = _local(m == 12 ? HijriCalendarMath.toGregorian(year + 1, 1, 1)! : HijriCalendarMath.toGregorian(year, m + 1, 1)!);
      starts[m] = s;
      lengths[m] = CalendarDays.between(s, next);
    }
  }

  final int year;
  final Map<int, DateTime> starts = {};
  final Map<int, int> lengths = {};

  static DateTime _local(DateTime utc) => DateTime(utc.year, utc.month, utc.day);

  DateTime get firstDay => starts[1]!;
  DateTime get lastDay => CalendarDays.add(starts[12]!, lengths[12]! - 1);

  /// The civil day on which Hijri [month]/[day] falls when the owner shifts
  /// the date by [offset] (+1: the local date is one ahead, so the day comes
  /// one civil day earlier).
  DateTime civil(int month, int day, int offset) => CalendarDays.add(starts[month]!, day - 1 - offset);

  /// The expected reminded civil days (keys), written from the owner's list
  /// and not from the engine: every Hijri day of the year that is not
  /// Ramadan, not an Eid or Tashriq, and is Monday / Thursday, a white day,
  /// one of the first nine of Dhu al-Hijjah, 2-7 Shawwal, 9-10 Muharram, or
  /// the first of Muharram / Sha'ban.
  Set<String> expectedReminded(int offset) {
    final out = <String>{};
    for (var m = 1; m <= 12; m++) {
      if (m == 9) continue;
      for (var d = 1; d <= lengths[m]!; d++) {
        if (m == 10 && d == 1) continue;
        if (m == 12 && d >= 10 && d <= 13) continue;
        final g = civil(m, d, offset);
        final yes =
            g.weekday == DateTime.monday ||
            g.weekday == DateTime.thursday ||
            (d >= 13 && d <= 15) ||
            (m == 12 && d <= 9) ||
            (m == 10 && d >= 2 && d <= 7) ||
            (m == 1 && (d == 9 || d == 10 || d == 1)) ||
            (m == 8 && d == 1);
        if (yes) out.add(CalendarDays.key(g));
      }
    }
    return out;
  }
}

FastingConfig cfg(int offset, {int shawwalStartDay = 2, int nudgeDay = 1, Set<FastKind> disabled = const {}}) =>
    FastingConfig(hijriOffset: offset, shawwalStartDay: shawwalStartDay, nudgeDay: nudgeDay, disabled: disabled);
