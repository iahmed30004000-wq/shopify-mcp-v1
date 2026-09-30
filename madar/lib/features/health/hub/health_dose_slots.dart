import '../../../core/db/repositories/repositories.dart';
import '../../orbit/data/orbit_repository.dart' show DoseSlotSource, OrbitRepository;
import '../../orbit/domain/planet_scores.dart' show DoseIn;
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/domain/time_zones.dart';
import '../meds/meds.dart';

/// The Health world's dose slots as the medication tracker plans them – the
/// source the app gives the orbit ([OrbitRepository.doseSlots]) so the
/// Health balance and the Neglect Radar see exactly the doses the
/// medications screen shows:
///
/// * a course doses on its own days only (daily ×10 → weekly ×4 →
///   monthly), a titration "stop" ends the doses, a paused medication has
///   none, an as-needed one is never "past due";
/// * a time that follows a prayer or a meal is where the tracker puts it
///   today, and timing rules have moved it;
/// * a snoozed dose is due again when its snooze ends;
/// * taken or skipped – in the app, from the notification's buttons, or
///   logged by hand within three hours – is handled.
///
/// Doses before the medication existed are left out (as before).
DoseSlotSource trackerDoseSlots(Repositories repos) =>
    ({required DateTime from, required DateTime now}) => planDoseSlots(repos, from: from, now: now);

/// See [trackerDoseSlots]: the doses from [from] (a day start) up to [now].
Future<List<DoseIn>> planDoseSlots(Repositories repos, {required DateTime from, required DateTime now}) async {
  final service = MedsService(repos, clock: () => now);
  final meds = [
    for (final m in await service.meds())
      if (m.active) m,
  ];
  if (meds.isEmpty) return const [];
  final scheduler = DoseScheduler(
    meds: meds,
    courses: await service.courses(),
    rules: await service.rules(),
    settings: await service.settings(),
    prayerTime: await _prayerTime(repos),
  );
  final days = MedDays.dateOnly(now).difference(MedDays.dateOnly(from)).inDays + 1;
  if (days <= 0) return const [];
  // A day earlier: a log of a dose planned past midnight still matches.
  final logs = await service.logs(MedDays.add(MedDays.dateOnly(from), -1));
  final period = MedsPlanner.period(scheduler, from: from, count: days, logs: logs, now: now);
  final start = MedDays.dateOnly(from);
  return [
    for (final t in period.tracked)
      if (!t.dose.day.isBefore(start) &&
          !t.dose.at.isAfter(now) &&
          (t.dose.med.createdAt == null || !t.dose.slot.isBefore(t.dose.med.createdAt!)))
        DoseIn(medId: t.dose.medId, medName: t.dose.med.name, scheduledAt: t.dueAt, taken: t.state.done),
  ];
}

/// Prayer anchors against the stored prayer settings (null when they cannot
/// be read – anchored times then keep their stored clock time).
Future<PrayerTimeOf?> _prayerTime(Repositories repos) async {
  try {
    MadarTimeZones.ensure();
  } catch (_) {}
  try {
    final settings = await repos.keyValues.get(OrbitRepository.prayerSettingsKv) ?? const PrayerSettings();
    return prayerTimeOf(PrayerSchedule(settings));
  } catch (_) {
    return null;
  }
}
