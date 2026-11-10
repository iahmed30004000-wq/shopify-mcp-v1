import 'package:drift/drift.dart';

import '../database.dart';

/// Append-only activity stream feeding planet balance scores and the Neglect
/// Radar ("task completed", "dose taken", "contacted person" …).
class ActivityRepository {
  ActivityRepository(this.db);

  final MadarDatabase db;

  /// Records one activity for [planetKey]. [kind] is a free-form verb such as
  /// `task.done`; [refTable]/[refId] point at the source row so the entry can
  /// be removed again when the action is undone.
  Future<ActivityRow> log({
    required String planetKey,
    required String kind,
    String? refTable,
    String? refId,
    DateTime? at,
    double? value,
    Map<String, Object?> payload = const {},
  }) {
    return db
        .into(db.activityLog)
        .insertReturning(
          ActivityLogCompanion.insert(
            planetKey: planetKey,
            kind: kind,
            refTable: Value(refTable),
            refId: Value(refId),
            at: at == null ? const Value.absent() : Value(at),
            value: Value(value),
            payload: Value(payload),
          ),
        );
  }

  /// Activities at or after [since], newest first.
  Future<List<ActivityRow>> since(DateTime since, {String? planetKey, String? kind}) =>
      _since(since, planetKey: planetKey, kind: kind).get();

  /// Live [since].
  Stream<List<ActivityRow>> watchSince(DateTime since, {String? planetKey, String? kind}) =>
      _since(since, planetKey: planetKey, kind: kind).watch();

  /// Most recent activity time per planet key (Neglect Radar), to the
  /// millisecond.
  Stream<Map<String, DateTime>> watchLastByPlanet() {
    final last = db.activityLog.at.julianday.max();
    final query = db.selectOnly(db.activityLog)
      ..addColumns([db.activityLog.planetKey, last])
      ..groupBy([db.activityLog.planetKey]);
    return query.watch().map(
      (rows) => {
        for (final r in rows)
          if (r.read(last) case final double julianDay) r.read(db.activityLog.planetKey)!: _fromJulianDay(julianDay),
      },
    );
  }

  static DateTime _fromJulianDay(double julianDay) {
    const unixEpochJulianDay = 2440587.5;
    final ms = ((julianDay - unixEpochJulianDay) * Duration.millisecondsPerDay).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// Removes the activities logged for a source row (undo of a completion)
  /// and returns them.
  Future<List<ActivityRow>> removeFor({required String refTable, required String refId, String? kind}) {
    Expression<bool> filter($ActivityLogTable t) {
      var e = t.refTable.equals(refTable) & t.refId.equals(refId);
      if (kind != null) e = e & t.kind.equals(kind);
      return e;
    }

    return db.transaction(() async {
      final rows = await (db.select(db.activityLog)..where(filter)).get();
      if (rows.isNotEmpty) await (db.delete(db.activityLog)..where(filter)).go();
      return rows;
    });
  }

  SimpleSelectStatement<$ActivityLogTable, ActivityRow> _since(DateTime since, {String? planetKey, String? kind}) {
    return db.select(db.activityLog)
      ..where((t) {
        var e = t.at.isBiggerOrEqualValue(since);
        if (planetKey != null) e = e & t.planetKey.equals(planetKey);
        if (kind != null) e = e & t.kind.equals(kind);
        return e;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.at.julianday), (t) => OrderingTerm.desc(t.rowId)]);
  }
}
