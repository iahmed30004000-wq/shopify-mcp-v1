/// Calendar-day helpers for `prayer_logs.day` (`yyyy-MM-dd`, the prayer
/// day: the hours before Fajr still belong to the day before). Day
/// arithmetic goes through the calendar fields (never `Duration(days: 1)`),
/// so daylight-saving changes cannot shift a day. Pure Dart.
library;

abstract final class TrackerDays {
  /// Local midnight of [d].
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `yyyy-MM-dd` of [d].
  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Parses a stored day key (null when malformed).
  static DateTime? parse(String key) {
    final m = _key.firstMatch(key.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, mo, d);
    // Reject overflowing dates such as 2026-02-31.
    if (date.month != mo || date.day != d) return null;
    return date;
  }

  static final RegExp _key = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// [d] moved by [days] calendar days (local midnight).
  static DateTime add(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// A day number that increases by exactly one per calendar day.
  static int ordinal(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Local midnight of the day with [ordinal].
  static DateTime fromOrdinal(int ordinal) {
    final u = DateTime.fromMillisecondsSinceEpoch(ordinal * 86400000, isUtc: true);
    return DateTime(u.year, u.month, u.day);
  }

  /// Calendar days from [a] to [b] (positive when [b] is later).
  static int between(DateTime a, DateTime b) => ordinal(b) - ordinal(a);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Number of days in [month] of [year].
  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
}
