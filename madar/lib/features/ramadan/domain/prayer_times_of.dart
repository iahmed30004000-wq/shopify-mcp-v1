import '../../orbit/domain/prayer_schedule.dart';

/// The prayer times of one civil day, supplied by the caller.
///
/// The app passes `PrayerSchedule.timesFor` (a tear-off fits); tests pass a
/// closure. Everything in the Ramadan domain takes this instead of a
/// schedule, so a traveller whose location changed simply passes the times of
/// the new place and nothing here remembers the old ones.
///
/// Maghrib is the iftar; Fajr is the end of suhoor.
typedef PrayerTimesOf = DayTimes Function(DateTime day);
