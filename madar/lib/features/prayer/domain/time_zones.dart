import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The IANA time-zone database for prayer times (pure Dart, no plugin).
///
/// Prayer times are computed for the stored location's own zone (a city in
/// the offline list or a GPS fix carries its IANA name), so the times read
/// correctly even when the device clock is set to another zone.
///
/// [ensure] is idempotent and safe to call from any feature: it loads the
/// full database (`latest_all`, every zone of the city list) only when it is
/// missing or when a reduced database (`latest.dart`) was loaded before, and
/// then restores the `tz.local` location someone else may have set (the adhan
/// scheduler sets it to the device zone), because loading resets it to UTC.
abstract final class MadarTimeZones {
  /// A zone only the full database has – proves `latest_all` is loaded.
  static const _fullDatabaseProbe = 'Asia/Kuala_Lumpur';

  /// Loads the database if needed (≈40 ms the first time).
  static void ensure() {
    final db = tz.timeZoneDatabase;
    if (db.isInitialized && db.locations.containsKey(_fullDatabaseProbe)) return;
    String? previousLocal;
    if (db.isInitialized) {
      try {
        previousLocal = tz.local.name;
      } catch (_) {
        previousLocal = null;
      }
    }
    tzdata.initializeTimeZones();
    if (previousLocal != null && previousLocal != 'UTC' && previousLocal != 'Etc/UTC') {
      final loc = tz.timeZoneDatabase.locations[previousLocal];
      if (loc != null) tz.setLocalLocation(loc);
    }
  }

  /// The zone called [name], or null for an empty/unknown name.
  static tz.Location? find(String? name) {
    if (name == null || name.isEmpty) return null;
    ensure();
    return tz.timeZoneDatabase.locations[name];
  }

  /// Whether [name] is a zone of the database.
  static bool isValid(String? name) => find(name) != null;

  /// [instant] as a wall-clock time in [zone] (the device's own local time
  /// when [zone] is null).
  static DateTime wallClock(DateTime instant, tz.Location? zone) =>
      zone == null ? instant.toLocal() : tz.TZDateTime.from(instant, zone);

  /// The calendar date (midnight, device-local `DateTime`) that [instant]
  /// falls on in [zone].
  static DateTime dateIn(DateTime instant, tz.Location? zone) {
    final w = wallClock(instant, zone);
    return DateTime(w.year, w.month, w.day);
  }

  /// The UTC offset of [zone] at [instant] (the device's offset when null).
  static Duration offsetAt(DateTime instant, tz.Location? zone) =>
      zone == null ? instant.toLocal().timeZoneOffset : tz.TZDateTime.from(instant, zone).timeZoneOffset;
}
