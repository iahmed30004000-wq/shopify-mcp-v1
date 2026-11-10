/// How wall-clock times and calendar days map to instants.
///
/// Production uses the device's zone ([LocalBodyWallClock]); tests inject a
/// zone with a daylight-saving change so "20:00 every day" and "which day
/// did this glass of water belong to" are checked across a 23- or 25-hour
/// day.
abstract interface class BodyWallClock {
  /// The instant [minutes] after local midnight of calendar [day] (a wall
  /// time; one skipped by a spring-forward resolves forward).
  DateTime at(DateTime day, int minutes);

  /// The local calendar day (a plain local-midnight `DateTime`) containing
  /// [instant].
  DateTime dayOf(DateTime instant);
}

/// [BodyWallClock] in the device's zone.
class LocalBodyWallClock implements BodyWallClock {
  const LocalBodyWallClock();

  @override
  DateTime at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, 0, minutes);

  @override
  DateTime dayOf(DateTime instant) {
    final l = instant.toLocal();
    return DateTime(l.year, l.month, l.day);
  }
}

/// Calendar-day helpers (days are local midnights; arithmetic is by
/// calendar, never by 24-hour steps).
abstract final class BodyDays {
  static DateTime of(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  /// Whole calendar days from [a] to [b] (positive when [b] is later).
  static int between(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// `2026-09-29`.
  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A time of day stored as `"HH:mm"`.
abstract final class BodyTimes {
  /// `"20:30"` → 1230; null when malformed.
  static int? parse(String? hhmm) {
    if (hhmm == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  /// 1230 → `"20:30"`.
  static String format(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}
