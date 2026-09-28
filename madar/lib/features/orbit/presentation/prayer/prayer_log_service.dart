import 'package:drift/drift.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../data/orbit_pulses.dart';

/// Restores the state before a prayer log change.
typedef PrayerUndo = Future<void> Function();

/// Logging an obligatory prayer from the astrolabe (the full prayer tracker
/// arrives with the Faith module): one `prayer_logs` row per prayer day and
/// prayer, plus a completion through the orbit's hook so the Faith world
/// pulses and its pointer ignites. Every change returns an exact undo.
class PrayerLogService {
  PrayerLogService(this.repos, {this.hub, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final OrbitPulseHub? hub;
  final DateTime Function() _clock;

  /// Planet and activity kind of a prayer completion.
  static const planetKey = 'faith';
  static const kind = 'prayer.logged';
  static const table = 'prayer_logs';

  /// `yyyy-MM-dd` of a prayer day.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// When a log was written ([loggedAt]), if that is a believable time to
  /// have prayed a prayer due at [prayerAt]: at or after it, within a day.
  /// Imported or back-filled logs carry the time they were written, which
  /// says nothing about the prayer – null then.
  static DateTime? plausibleLoggedAt(DateTime? loggedAt, DateTime prayerAt) {
    if (loggedAt == null || loggedAt.isBefore(prayerAt)) return null;
    return loggedAt.difference(prayerAt) < const Duration(days: 1) ? loggedAt : null;
  }

  /// The log of [prayer] on the prayer day [day], if any.
  Future<PrayerLogRow?> logOf(DateTime day, Prayer prayer) async {
    final key = dayKey(day);
    final rows = await repos.prayerLogs.getAll(where: (t) => t.day.equals(key) & t.prayer.equalsValue(prayer));
    return rows.isEmpty ? null : rows.first;
  }

  /// Logs [prayer] on [day] as [status] (replacing an earlier log and its
  /// completion, atomically). Prayed, late and made-up prayers count as a
  /// completion of the Faith world. The undo restores the earlier log and
  /// its completion exactly.
  Future<PrayerUndo> log(DateTime day, Prayer prayer, PrayerStatus status) async {
    final now = _clock();
    PrayerLogRow? previous;
    var removed = const <ActivityRow>[];
    late final PrayerLogRow row;
    await repos.db.transaction(() async {
      previous = await logOf(day, prayer);
      final prev = previous;
      if (prev != null) {
        removed = await repos.activity.removeFor(refTable: table, refId: prev.id, kind: kind);
        await repos.prayerLogs.delete(prev.id);
      }
      row = await repos.prayerLogs.insert(
        PrayerLogsCompanion.insert(day: dayKey(day), prayer: prayer, status: Value(status), loggedAt: Value(now)),
      );
      if (status != PrayerStatus.missed) {
        final h = hub;
        if (h != null) {
          await h.recordCompletion(planetKey, kind, table, row.id, at: now, payload: {'prayer': prayer.name});
        } else {
          await repos.activity.log(planetKey: planetKey, kind: kind, refTable: table, refId: row.id, at: now);
        }
      }
    });
    return () async {
      await repos.db.transaction(() async {
        await repos.activity.removeFor(refTable: table, refId: row.id, kind: kind);
        await repos.prayerLogs.delete(row.id);
        final prev = previous;
        if (prev != null) {
          await repos.prayerLogs.restore(prev);
          if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
        }
      });
    };
  }

  /// Removes the log of [prayer] on [day].
  Future<PrayerUndo> clear(DateTime day, Prayer prayer) async {
    final previous = await logOf(day, prayer);
    if (previous == null) return () async {};
    final activity = await repos.activity.removeFor(refTable: table, refId: previous.id, kind: kind);
    await repos.prayerLogs.delete(previous.id);
    return () async {
      await repos.prayerLogs.restore(previous);
      await repos.activityLog.restoreAll(activity);
    };
  }
}
