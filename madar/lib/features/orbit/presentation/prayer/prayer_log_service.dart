import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../../prayer_tracker/data/prayer_tracker_repository.dart';
import '../../../prayer_tracker/domain/tracker_days.dart';
import '../../data/orbit_pulses.dart';

export '../../../prayer_tracker/data/prayer_tracker_repository.dart' show PrayerUndo;

/// Logging an obligatory prayer from the astrolabe – a compatible facade
/// over the prayer tracker's [PrayerTrackerRepository] (which owns the
/// logic): one `prayer_logs` row per prayer day and prayer, plus a
/// completion through the orbit's hook so the Faith world pulses and its
/// pointer ignites. Every change returns an exact undo.
class PrayerLogService {
  PrayerLogService(this.repos, {this.hub, DateTime Function()? clock})
    : tracker = PrayerTrackerRepository(repos, hub: hub, clock: clock);

  final Repositories repos;
  final OrbitPulseHub? hub;

  /// The repository doing the work (jamaah / mosque, sunnah, qada …).
  final PrayerTrackerRepository tracker;

  /// Planet and activity kind of a prayer completion.
  static const planetKey = PrayerTrackerRepository.planetKey;
  static const kind = PrayerTrackerRepository.obligatoryKind;
  static const table = PrayerTrackerRepository.table;

  /// `yyyy-MM-dd` of a prayer day.
  static String dayKey(DateTime d) => TrackerDays.key(d);

  /// When a log was written ([loggedAt]), if that is a believable time to
  /// have prayed a prayer due at [prayerAt]: at or after it, within a day.
  /// Imported or back-filled logs carry the time they were written, which
  /// says nothing about the prayer – null then.
  static DateTime? plausibleLoggedAt(DateTime? loggedAt, DateTime prayerAt) {
    if (loggedAt == null || loggedAt.isBefore(prayerAt)) return null;
    return loggedAt.difference(prayerAt) < const Duration(days: 1) ? loggedAt : null;
  }

  /// The log of [prayer] on the prayer day [day], if any.
  Future<PrayerLogRow?> logOf(DateTime day, Prayer prayer) => tracker.logOf(day, prayer);

  /// Logs [prayer] on [day] as [status] (replacing an earlier log and its
  /// completion, atomically). Prayed, late and made-up prayers count as a
  /// completion of the Faith world. The undo restores the earlier log and
  /// its completion exactly.
  Future<PrayerUndo> log(DateTime day, Prayer prayer, PrayerStatus status) async =>
      (await tracker.setStatus(day, prayer, status)).undo;

  /// Removes the log of [prayer] on [day].
  Future<PrayerUndo> clear(DateTime day, Prayer prayer) async => (await tracker.clear(day, prayer)).undo;
}
