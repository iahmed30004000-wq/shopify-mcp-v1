import 'package:drift/drift.dart' show DataClass, Insertable, Table, Value;

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../domain/lab_series.dart';
import '../domain/record_settings.dart';

/// Restores the exact state before a write.
typedef RecordUndo = Future<void> Function();

/// Logs a completion on the Health planet (the app wires it to the orbit's
/// pulse hub so the world flares).
typedef RecordActivityRecorder = Future<void> Function(String kind, String refTable, String refId, {double? value});

/// Activity kinds logged with planetKey `health`.
abstract final class RecordActivityKinds {
  static const appointmentDone = 'appointment.done';
  static const labReading = 'lab.reading';
  static const labVisit = 'lab.visit';
  static const questionAnswered = 'question.answered';
}

/// One result typed in the lab-visit sheet.
typedef LabVisitEntry = ({String testId, LabValueInput input, String? note});

/// Reads and writes the medical record: standing alerts, conditions, lab
/// tests and readings, appointments and doctor questions. Every write
/// returns a [RecordUndo] that puts the rows back exactly.
class RecordService {
  RecordService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Null = log straight into the activity table (no planet pulse).
  final RecordActivityRecorder? recorder;

  static const String planetKey = 'health';

  Future<void> _log(String kind, String table, String id, {double? value}) async {
    final r = recorder;
    if (r != null) {
      await r(kind, table, id, value: value);
    } else {
      await repos.activity.log(planetKey: planetKey, kind: kind, refTable: table, refId: id, at: clock(), value: value);
    }
  }

  Future<void> _unlog(String kind, String table, String id) async {
    await repos.activity.removeFor(refTable: table, refId: id, kind: kind);
  }

  // --------------------------------------------------------------- alerts

  Stream<List<HealthAlertRow>> watchAlerts() => repos.healthAlerts.watchAll();

  Future<(HealthAlertRow, RecordUndo)> addAlert({
    required String body,
    Severity severity = Severity.critical,
    bool pinned = true,
  }) async {
    final row = await repos.healthAlerts.insert(
      HealthAlertsCompanion.insert(body: body.trim(), severity: Value(severity), pinned: Value(pinned)),
    );
    return (row, () async => repos.healthAlerts.delete(row.id).then((_) {}));
  }

  Future<RecordUndo> updateAlert(HealthAlertRow updated) => _update(repos.healthAlerts, updated.id, updated);

  Future<RecordUndo> setAlertPinned(String id, bool pinned) => _setColumns(repos.healthAlerts, id, {'pinned': pinned});

  Future<RecordUndo?> deleteAlert(String id) => _delete(repos.healthAlerts, id);

  Future<RecordUndo> reorderAlerts(List<String> ids) => _reorder(repos.healthAlerts, ids, (r) => r.id);

  // ----------------------------------------------------------- conditions

  Stream<List<ConditionRow>> watchConditions() => repos.conditions.watchAll();

  Future<(ConditionRow, RecordUndo)> addCondition({
    required String name,
    String? notes,
    DateTime? since,
    bool active = true,
  }) async {
    final row = await repos.conditions.insert(
      ConditionsCompanion.insert(
        name: name.trim(),
        notes: Value(_blank(notes)),
        since: Value(since),
        active: Value(active),
      ),
    );
    return (row, () async => repos.conditions.delete(row.id).then((_) {}));
  }

  Future<RecordUndo> updateCondition(ConditionRow updated) => _update(repos.conditions, updated.id, updated);

  Future<RecordUndo> setConditionActive(String id, bool active) =>
      _setColumns(repos.conditions, id, {'active': active});

  Future<RecordUndo?> deleteCondition(String id) => _delete(repos.conditions, id);

  Future<RecordUndo> reorderConditions(List<String> ids) => _reorder(repos.conditions, ids, (r) => r.id);

  // ------------------------------------------------------------------ labs

  Stream<List<LabTestRow>> watchTests() => repos.labTests.watchAll();

  Stream<List<LabReadingRow>> watchReadings({String? testId}) =>
      repos.labReadings.watchAll(where: testId == null ? null : (t) => t.testId.equals(testId));

  Future<(LabTestRow, RecordUndo)> addTest({
    required String name,
    String? unit,
    double? low,
    double? high,
    String? category,
    String? notes,
  }) async {
    final row = await repos.labTests.insert(
      LabTestsCompanion.insert(
        name: name.trim(),
        unit: Value(_blank(unit)),
        low: Value(low),
        high: Value(high),
        category: Value(_blank(category)),
        notes: Value(_blank(notes)),
      ),
    );
    return (row, () async => repos.labTests.delete(row.id).then((_) {}));
  }

  Future<RecordUndo> updateTest(LabTestRow updated) => _update(repos.labTests, updated.id, updated);

  /// Deletes a test with all its readings.
  Future<RecordUndo?> deleteTest(String id) async {
    final readings = await repos.labReadings.deleteWhere((t) => t.testId.equals(id));
    final test = await repos.labTests.delete(id);
    if (test == null && readings.isEmpty) return null;
    return () async {
      if (test != null) await repos.labTests.restore(test);
      await repos.labReadings.restoreAll(readings);
    };
  }

  Future<RecordUndo> reorderTests(List<String> ids) => _reorder(repos.labTests, ids, (r) => r.id);

  Future<(LabReadingRow, RecordUndo)> addReading({
    required String testId,
    required DateTime date,
    required LabValueInput input,
    String? note,
  }) async {
    final row = await repos.labReadings.insert(
      LabReadingsCompanion.insert(
        testId: testId,
        date: date,
        value: Value(input.value),
        valueText: Value(input.text),
        note: Value(_blank(note)),
      ),
    );
    await _log(RecordActivityKinds.labReading, repos.labReadings.tableName, row.id, value: input.value);
    return (
      row,
      () async {
        await repos.labReadings.delete(row.id);
        await _unlog(RecordActivityKinds.labReading, repos.labReadings.tableName, row.id);
      },
    );
  }

  /// A lab visit: several results on one [date] at once (empty inputs are
  /// skipped). Logs one `lab.visit` activity.
  Future<(List<LabReadingRow>, RecordUndo)> addVisit({
    required DateTime date,
    required List<LabVisitEntry> entries,
  }) async {
    final rows = <LabReadingRow>[];
    await repos.db.transaction(() async {
      for (final e in entries) {
        if (e.input.isEmpty) continue;
        rows.add(
          await repos.labReadings.insert(
            LabReadingsCompanion.insert(
              testId: e.testId,
              date: date,
              value: Value(e.input.value),
              valueText: Value(e.input.text),
              note: Value(_blank(e.note)),
            ),
          ),
        );
      }
    });
    if (rows.isNotEmpty) {
      await _log(
        RecordActivityKinds.labVisit,
        repos.labReadings.tableName,
        rows.first.id,
        value: rows.length.toDouble(),
      );
    }
    return (
      rows,
      () async {
        await repos.db.transaction(() async {
          for (final r in rows) {
            await repos.labReadings.delete(r.id);
          }
        });
        if (rows.isNotEmpty) await _unlog(RecordActivityKinds.labVisit, repos.labReadings.tableName, rows.first.id);
      },
    );
  }

  Future<RecordUndo> updateReading(LabReadingRow updated) => _update(repos.labReadings, updated.id, updated);

  Future<RecordUndo?> deleteReading(String id) async {
    final row = await repos.labReadings.delete(id);
    if (row == null) return null;
    final logs = await repos.activity.removeFor(refTable: repos.labReadings.tableName, refId: id);
    return () async {
      await repos.labReadings.restore(row);
      await repos.activityLog.restoreAll(logs);
    };
  }

  // ---------------------------------------------------------- appointments

  Stream<List<AppointmentRow>> watchAppointments() => repos.appointments.watchAll();

  Future<(AppointmentRow, RecordUndo)> addAppointment({
    required String title,
    required DateTime at,
    String? doctor,
    String? place,
    String? notes,
  }) async {
    final row = await repos.appointments.insert(
      AppointmentsCompanion.insert(
        title: title.trim(),
        at: at,
        doctor: Value(_blank(doctor)),
        place: Value(_blank(place)),
        notes: Value(_blank(notes)),
      ),
    );
    return (row, () async => repos.appointments.delete(row.id).then((_) {}));
  }

  Future<RecordUndo> updateAppointment(AppointmentRow updated) => _update(repos.appointments, updated.id, updated);

  /// Marks an appointment done (logged on the Health planet) or not done.
  Future<RecordUndo> setAppointmentDone(String id, bool done) async {
    final before = await repos.appointments.byId(id);
    if (before == null || before.done == done) return () async {};
    await repos.appointments.setColumns(id, {'done': done});
    final table = repos.appointments.tableName;
    var removed = const <ActivityRow>[];
    if (done) {
      await _log(RecordActivityKinds.appointmentDone, table, id);
    } else {
      removed = await repos.activity.removeFor(refTable: table, refId: id, kind: RecordActivityKinds.appointmentDone);
    }
    return () async {
      await repos.appointments.setColumns(id, {'done': before.done});
      if (done) {
        await _unlog(RecordActivityKinds.appointmentDone, table, id);
      } else {
        await repos.activityLog.restoreAll(removed);
      }
    };
  }

  /// Deletes an appointment; its questions stay as general questions.
  Future<RecordUndo?> deleteAppointment(String id) async {
    final questions = await repos.doctorQuestions.getAll(where: (t) => t.appointmentId.equals(id));
    for (final q in questions) {
      await repos.doctorQuestions.setColumns(q.id, {'appointmentId': null});
    }
    final row = await repos.appointments.delete(id);
    final logs = await repos.activity.removeFor(refTable: repos.appointments.tableName, refId: id);
    if (row == null) return null;
    return () async {
      await repos.appointments.restore(row);
      for (final q in questions) {
        await repos.doctorQuestions.setColumns(q.id, {'appointmentId': id});
      }
      await repos.activityLog.restoreAll(logs);
    };
  }

  // ------------------------------------------------------------- questions

  Stream<List<DoctorQuestionRow>> watchQuestions() => repos.doctorQuestions.watchAll();

  Future<(DoctorQuestionRow, RecordUndo)> addQuestion({required String question, String? appointmentId}) async {
    final row = await repos.doctorQuestions.insert(
      DoctorQuestionsCompanion.insert(question: question.trim(), appointmentId: Value(appointmentId)),
    );
    return (row, () async => repos.doctorQuestions.delete(row.id).then((_) {}));
  }

  Future<RecordUndo> updateQuestion(DoctorQuestionRow updated) async {
    final before = await repos.doctorQuestions.byId(updated.id);
    final undo = await _update(repos.doctorQuestions, updated.id, updated);
    if (before == null || before.answered == updated.answered) return undo;
    final table = repos.doctorQuestions.tableName;
    if (updated.answered) {
      await _log(RecordActivityKinds.questionAnswered, table, updated.id);
      return () async {
        await undo();
        await _unlog(RecordActivityKinds.questionAnswered, table, updated.id);
      };
    }
    final removed = await repos.activity.removeFor(
      refTable: table,
      refId: updated.id,
      kind: RecordActivityKinds.questionAnswered,
    );
    return () async {
      await undo();
      await repos.activityLog.restoreAll(removed);
    };
  }

  /// Marks a question answered (with an optional [answer]) or open again.
  Future<RecordUndo> setAnswered(String id, bool answered, {String? answer}) async {
    final q = await repos.doctorQuestions.byId(id);
    if (q == null) return () async {};
    return updateQuestion(
      q.copyWith(answered: answered, answer: answer == null ? Value(q.answer) : Value(_blank(answer))),
    );
  }

  Future<RecordUndo?> deleteQuestion(String id) async {
    final row = await repos.doctorQuestions.delete(id);
    if (row == null) return null;
    final logs = await repos.activity.removeFor(refTable: repos.doctorQuestions.tableName, refId: id);
    return () async {
      await repos.doctorQuestions.restore(row);
      await repos.activityLog.restoreAll(logs);
    };
  }

  Future<RecordUndo> reorderQuestions(List<String> ids) => _reorder(repos.doctorQuestions, ids, (r) => r.id);

  // -------------------------------------------------------------- settings

  static final _settingsKey = KvKey.json<RecordSettings>(
    RecordSettings.storageKey,
    fromJson: RecordSettings.fromJson,
    toJson: (s) => s.toJson(),
  );

  Stream<RecordSettings> watchSettings() => repos.keyValues.watch(_settingsKey).map((s) => s ?? const RecordSettings());

  Future<RecordSettings> settings() async => await repos.keyValues.get(_settingsKey) ?? const RecordSettings();

  Future<RecordUndo> saveSettings(RecordSettings next) async {
    final before = await settings();
    await repos.keyValues.set(_settingsKey, next);
    return () => repos.keyValues.set(_settingsKey, before);
  }

  // --------------------------------------------------------------- helpers

  static String? _blank(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<RecordUndo> _update<R extends DataClass>(EntityRepository<Table, R> repo, String id, R updated) async {
    final before = await repo.byId(id);
    await repo.update(updated as Insertable<R>);
    return () async {
      if (before != null) await repo.update(before as Insertable<R>);
    };
  }

  Future<RecordUndo> _setColumns<R extends DataClass>(
    EntityRepository<Table, R> repo,
    String id,
    Map<String, Object?> values,
  ) async {
    final before = await repo.byId(id);
    await repo.setColumns(id, values);
    return () async {
      if (before != null) await repo.update(before as Insertable<R>);
    };
  }

  Future<RecordUndo?> _delete<R extends DataClass>(EntityRepository<Table, R> repo, String id) async {
    final row = await repo.delete(id);
    if (row == null) return null;
    return () => repo.restore(row);
  }

  Future<RecordUndo> _reorder<R extends DataClass>(
    EntityRepository<Table, R> repo,
    List<String> ids,
    String Function(R row) idOf,
  ) async {
    final all = await repo.getAll();
    final wanted = ids.toSet();
    final previous = [
      for (final r in all)
        if (wanted.contains(idOf(r))) idOf(r),
    ];
    await repo.reorder(ids);
    return () => repo.reorder(previous);
  }
}
