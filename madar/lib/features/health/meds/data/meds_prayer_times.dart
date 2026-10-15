import '../../../orbit/domain/prayer_schedule.dart';
import '../domain/dose_scheduler.dart';
import '../domain/med_models.dart';

/// Resolves prayer anchors ("20 min after Fajr") against the user's prayer
/// schedule (location, method and adjustments from the prayer settings).
PrayerTimeOf prayerTimeOf(PrayerSchedule schedule) => (day, base) {
  final t = schedule.timesFor(day);
  return switch (base) {
    AnchorBase.fajr => t.fajr,
    AnchorBase.sunrise => t.sunrise,
    AnchorBase.dhuhr => t.dhuhr,
    AnchorBase.asr => t.asr,
    AnchorBase.maghrib => t.maghrib,
    AnchorBase.isha => t.isha,
    _ => null,
  };
};
