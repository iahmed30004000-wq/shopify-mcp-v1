import 'package:madar/features/orbit/domain/prayer_schedule.dart' show DayTimes;

/// Prayer times that never move: Fajr 05:30, Maghrib 17:20, Isha 18:45 (the
/// device's zone) - so the plan's arithmetic is checked against numbers
/// written in the test, not against another computation.
DayTimes fixedTimes(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  DateTime at(int h, int m) => DateTime(d.year, d.month, d.day, h, m);
  return DayTimes(day: d, fajr: at(5, 30), sunrise: at(6, 58), dhuhr: at(12, 5), asr: at(14, 55), maghrib: at(17, 20), isha: at(18, 45));
}

/// Ids written from the block 210000 + kind × 50 + number, independently of
/// `RamadanNotificationIds.forDay`.
int suhoorId(int day) => 210000 + day;
int iftarId(int day) => 210050 + day;
int taraweehId(int night) => 210100 + night;
int lastTenId(int night) => 210200 + night;
