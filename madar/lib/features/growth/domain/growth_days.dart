/// Calendar-day arithmetic for the Growth planet (zone- and DST-safe: days
/// are counted on the calendar, never as 24-hour spans).
abstract final class GrowthDays {
  /// Local midnight of [d]'s calendar day.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The calendar day [days] after [day] (negative = before).
  static DateTime add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  /// Whole calendar days from [a]'s day to [b]'s day (negative when [b] is
  /// earlier).
  static int between(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Days from the start of [origin]'s day to the instant [t], with the time
  /// of day as a fraction (for chart x positions).
  static double fractional(DateTime origin, DateTime t) =>
      between(origin, t) + (t.hour * 3600 + t.minute * 60 + t.second) / 86400;

  /// A sortable key for [d]'s calendar day: `20260928`.
  static int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
