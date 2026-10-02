import 'package:madar/features/adhan/domain/adhan_plan.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

tz.Location zone(String name) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  return tz.getLocation(name);
}

/// Synthetic prayer times at fixed wall-clock times of [location]
/// (Fajr 04:50, sunrise 06:10, Dhuhr 12:30, Asr 15:50, Maghrib 18:30,
/// Isha 19:50) – instants follow the zone's DST rules.
AdhanTimesFor wallClockTimes(tz.Location location, {Map<AdhanSlot, (int, int)>? at}) {
  final clock =
      at ??
      const {
        AdhanSlot.fajr: (4, 50),
        AdhanSlot.sunrise: (6, 10),
        AdhanSlot.dhuhr: (12, 30),
        AdhanSlot.asr: (15, 50),
        AdhanSlot.maghrib: (18, 30),
        AdhanSlot.isha: (19, 50),
      };
  return (day) => AdhanDayTimes(day, {
    for (final e in clock.entries)
      e.key: _plain(tz.TZDateTime(location, day.year, day.month, day.day, e.value.$1, e.value.$2)),
  });
}

LocalDayOf localDayIn(tz.Location location) => (instant) {
  final t = tz.TZDateTime.from(instant, location);
  return DateTime.utc(t.year, t.month, t.day);
};

/// A wall-clock moment in [location] as a UTC instant.
DateTime wall(tz.Location location, int y, int m, int d, int h, [int min = 0]) =>
    _plain(tz.TZDateTime(location, y, m, d, h, min));

/// A plain UTC `DateTime` (a `TZDateTime` never equals a `DateTime`).
DateTime _plain(tz.TZDateTime t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);
