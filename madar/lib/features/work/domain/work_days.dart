/// Calendar-day arithmetic for the Work planet (due dates, deadlines, the
/// Top 3 day). Days are local midnights; differences run on UTC dates so
/// they never drift across DST changes or month boundaries.
abstract final class WorkDays {
  /// Local midnight of [t].
  static DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [day] moved by [days] calendar days.
  static DateTime add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int between(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static bool same(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  /// `2026-09-28`.
  static String key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// Parses [key]; null when malformed.
  static DateTime? parse(Object? key) {
    if (key is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}
