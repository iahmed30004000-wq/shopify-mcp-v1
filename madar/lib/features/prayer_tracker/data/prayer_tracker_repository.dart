import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../orbit/data/orbit_pulses.dart';
import '../domain/tracker_days.dart';
import '../domain/tracker_prayers.dart';

/// Restores the state before a prayer log change.
typedef PrayerUndo = Future<void> Function();

/// The result of a tracker write: the log before and after it and the
/// exact undo.
class TrackerChange {
  const TrackerChange({required this.before, required this.after, required this.undo});

  /// Nothing changed (the undo does nothing).
  static TrackerChange none(PrayerLogRow? row) => TrackerChange(before: row, after: row, undo: _noop);

  static Future<void> _noop() async {}

  final PrayerLogRow? before;
  final PrayerLogRow? after;
  final PrayerUndo undo;

  PrayerStatus? get status => after?.status;

  bool get changed => !identical(undo, _noop);
}

/// The desired state of one log (null = no log).
typedef _Target = ({PrayerStatus status, bool inJamaah, bool atMosque});

/// Every prayer log write: one `prayer_logs` row per prayer day and prayer
/// (obligatory and voluntary), plus a Faith completion in the activity
/// stream for each prayer actually prayed (kind [obligatoryKind] or
/// [voluntaryKind], through the orbit's [OrbitPulseHub] when given so the
/// Faith world pulses at once). The score engine reads `prayer_logs`
/// directly; the activity entries keep the Neglect Radar's freshness.
///
/// Every write runs in one transaction and returns a [TrackerChange] whose
/// undo restores the earlier rows *and* their activity entries exactly.
class PrayerTrackerRepository {
  PrayerTrackerRepository(this.repos, {this.hub, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final OrbitPulseHub? hub;
  final DateTime Function() _clock;

  /// Planet and activity kinds of a prayer completion.
  static const planetKey = 'faith';
  static const obligatoryKind = 'prayer.logged';
  static const voluntaryKind = 'prayer.sunnah';
  static const table = 'prayer_logs';

  /// The activity kind recorded when [prayer] is prayed.
  static String kindFor(Prayer prayer) => TrackerPrayers.isObligatory(prayer) ? obligatoryKind : voluntaryKind;

  MadarDatabase get _db => repos.db;

  // ---------------------------------------------------------------- reads

  /// The log of [prayer] on the prayer day [day], if any.
  Future<PrayerLogRow?> logOf(DateTime day, Prayer prayer) async {
    final key = TrackerDays.key(day);
    final rows = await repos.prayerLogs.getAll(where: (t) => t.day.equals(key) & t.prayer.equalsValue(prayer));
    return rows.isEmpty ? null : rows.first;
  }

  /// Every log of the prayer day [day].
  Future<List<PrayerLogRow>> dayLogs(DateTime day) {
    final key = TrackerDays.key(day);
    return repos.prayerLogs.getAll(where: (t) => t.day.equals(key));
  }

  Stream<List<PrayerLogRow>> watchDay(DateTime day) {
    final key = TrackerDays.key(day);
    return repos.prayerLogs.watchAll(where: (t) => t.day.equals(key));
  }

  /// Logs of the prayer days from [from] to [to] (inclusive).
  Stream<List<PrayerLogRow>> watchRange(DateTime from, DateTime to) {
    final a = TrackerDays.key(from);
    final b = TrackerDays.key(to);
    return repos.prayerLogs.watchAll(where: (t) => t.day.isBetweenValues(a, b));
  }

  Future<List<PrayerLogRow>> range(DateTime from, DateTime to) {
    final a = TrackerDays.key(from);
    final b = TrackerDays.key(to);
    return repos.prayerLogs.getAll(where: (t) => t.day.isBetweenValues(a, b));
  }

  /// Every prayer log (the History tab).
  Stream<List<PrayerLogRow>> watchAll() => repos.prayerLogs.watchAll();

  // --------------------------------------------------------------- writes

  /// Logs [prayer] on [day] as [status]. An existing log keeps its id and
  /// its jamaah / mosque marks (cleared when the prayer was missed).
  Future<TrackerChange> setStatus(DateTime day, Prayer prayer, PrayerStatus status) => _write(
    day,
    prayer,
    (b) => (
      status: status,
      inJamaah: status.counts && (b?.inJamaah ?? false),
      atMosque: status.counts && (b?.atMosque ?? false),
    ),
  );

  /// Removes the log of [prayer] on [day].
  Future<TrackerChange> clear(DateTime day, Prayer prayer) => _write(day, prayer, (_) => null);

  /// The tap on an obligatory prayer: no log → prayed → late → missed → no
  /// log (see [StatusCycle]).
  Future<TrackerChange> cycle(DateTime day, Prayer prayer) => _write(day, prayer, (b) {
    final next = StatusCycle.next(b?.status);
    if (next == null) return null;
    return (
      status: next,
      inJamaah: next.counts && (b?.inJamaah ?? false),
      atMosque: next.counts && (b?.atMosque ?? false),
    );
  });

  /// Marks [prayer] as prayed in jamaah (or not). Marking an unlogged or
  /// missed prayer logs it as prayed on time; un-marking one leaves it as it
  /// is (it was not prayed in jamaah).
  Future<TrackerChange> setJamaah(DateTime day, Prayer prayer, bool value) => _write(day, prayer, (b) {
    if (!value && (b == null || !b.status.counts)) return _as(b);
    final status = b == null || !b.status.counts ? PrayerStatus.prayed : b.status;
    return (status: status, inJamaah: value, atMosque: b != null && b.status.counts && b.atMosque);
  }, keepIfUnchanged: true);

  /// Marks [prayer] as prayed at the mosque (or not). Marking an unlogged or
  /// missed prayer logs it as prayed on time; un-marking one leaves it as it
  /// is.
  Future<TrackerChange> setMosque(DateTime day, Prayer prayer, bool value) => _write(day, prayer, (b) {
    if (!value && (b == null || !b.status.counts)) return _as(b);
    final status = b == null || !b.status.counts ? PrayerStatus.prayed : b.status;
    return (status: status, inJamaah: b != null && b.status.counts && b.inJamaah, atMosque: value);
  }, keepIfUnchanged: true);

  /// A voluntary prayer (sunnah, Duha, Witr, Qiyam) on or off.
  Future<TrackerChange> toggleVoluntary(DateTime day, Prayer prayer) => _write(
    day,
    prayer,
    (b) => b != null && b.status.counts ? null : (status: PrayerStatus.prayed, inJamaah: false, atMosque: false),
  );

  /// Records that a missed prayer was made up: status qada, on the day it
  /// was missed.
  Future<TrackerChange> makeUp(DateTime day, Prayer prayer) =>
      _write(day, prayer, (_) => (status: PrayerStatus.qada, inJamaah: false, atMosque: false));

  /// [makeUp] for several prayers with a single undo.
  Future<PrayerUndo> makeUpAll(Iterable<(DateTime, Prayer)> entries) async {
    final undos = <PrayerUndo>[];
    await _db.transaction(() async {
      for (final (day, prayer) in entries) {
        final change = await _apply(
          day,
          prayer,
          (_) => (status: PrayerStatus.qada, inJamaah: false, atMosque: false),
          now: _clock(),
          keepIfUnchanged: false,
        );
        undos.add(change.undo);
      }
    });
    return () => _db.transaction(() async {
      for (final u in undos.reversed) {
        await u();
      }
    });
  }

  // ------------------------------------------------------------- internals

  /// The target that leaves [row] exactly as it is.
  static _Target? _as(PrayerLogRow? row) =>
      row == null ? null : (status: row.status, inJamaah: row.inJamaah, atMosque: row.atMosque);

  Future<TrackerChange> _write(
    DateTime day,
    Prayer prayer,
    _Target? Function(PrayerLogRow? before) decide, {
    bool keepIfUnchanged = false,
  }) async {
    final now = _clock();
    late TrackerChange change;
    await _db.transaction(() async {
      change = await _apply(day, prayer, decide, now: now, keepIfUnchanged: keepIfUnchanged);
    });
    return change;
  }

  /// One log change inside a transaction. The log's completion is replaced
  /// only when its status changes (toggling jamaah or mosque keeps it). With
  /// [keepIfUnchanged] a write that would leave the log exactly as it is
  /// does nothing; otherwise re-logging the same status re-stamps the log
  /// (the time it was prayed) and its completion.
  Future<TrackerChange> _apply(
    DateTime day,
    Prayer prayer,
    _Target? Function(PrayerLogRow? before) decide, {
    required DateTime now,
    required bool keepIfUnchanged,
  }) async {
    final before = await logOf(day, prayer);
    final target = decide(before);
    if (before == null && target == null) return TrackerChange.none(null);
    if (before != null &&
        target != null &&
        keepIfUnchanged &&
        before.status == target.status &&
        before.inJamaah == target.inJamaah &&
        before.atMosque == target.atMosque) {
      return TrackerChange.none(before);
    }
    // Re-logging the same status (not a mark toggle) re-stamps the log.
    final restamp = !keepIfUnchanged && before != null && target != null && before.status == target.status;
    final statusChanged = before == null || target == null || before.status != target.status || restamp;
    var removed = const <ActivityRow>[];
    if (before != null && statusChanged) {
      removed = await repos.activity.removeFor(refTable: table, refId: before.id);
    }
    PrayerLogRow? after;
    if (target == null) {
      await repos.prayerLogs.delete(before!.id);
    } else if (before == null) {
      after = await repos.prayerLogs.insert(
        PrayerLogsCompanion.insert(
          day: TrackerDays.key(day),
          prayer: prayer,
          status: Value(target.status),
          inJamaah: Value(target.inJamaah),
          atMosque: Value(target.atMosque),
          loggedAt: Value(now),
        ),
      );
    } else {
      await repos.prayerLogs.update(
        before.copyWith(
          status: target.status,
          inJamaah: target.inJamaah,
          atMosque: target.atMosque,
          loggedAt: statusChanged ? now : before.loggedAt,
        ),
      );
      after = await repos.prayerLogs.byId(before.id);
    }
    final row = after;
    if (row != null && statusChanged && row.status.counts) {
      await _complete(row, now);
    }
    Future<void> undo() => _db.transaction(() async {
      if (row != null) {
        if (statusChanged) await repos.activity.removeFor(refTable: table, refId: row.id);
        await repos.prayerLogs.delete(row.id);
      }
      if (before != null) {
        await repos.prayerLogs.restore(before);
        if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
      }
    });
    return TrackerChange(before: before, after: row, undo: undo);
  }

  Future<void> _complete(PrayerLogRow row, DateTime now) async {
    final kind = kindFor(row.prayer);
    final payload = <String, Object?>{'prayer': row.prayer.name, 'status': row.status.name, 'day': row.day};
    final h = hub;
    if (h != null) {
      await h.recordCompletion(planetKey, kind, table, row.id, at: now, payload: payload);
    } else {
      await repos.activity.log(
        planetKey: planetKey,
        kind: kind,
        refTable: table,
        refId: row.id,
        at: now,
        payload: payload,
      );
    }
  }
}
