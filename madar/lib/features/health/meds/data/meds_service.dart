import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../domain/course_schedule.dart';
import '../domain/dose_scheduler.dart';
import '../domain/dose_tracker.dart';
import '../domain/med_models.dart';
import '../domain/meds_settings.dart';

/// Restores the exact state before a write.
typedef MedsUndo = Future<void> Function();

Future<void> _noUndo() async {}

/// What a dose action did.
@immutable
class DoseActionResult {
  const DoseActionResult({
    required this.undo,
    this.changed = true,
    this.stockAfter,
    this.refillCrossed = false,
    this.medName,
  });

  final MedsUndo undo;

  /// False when the dose already had that answer (a repeated notification
  /// action): nothing was written.
  final bool changed;
  final int? stockAfter;

  /// Taking it brought the stock down to the refill threshold.
  final bool refillCrossed;
  final String? medName;

  static const DoseActionResult none = DoseActionResult(undo: _noUndo, changed: false);
}

/// The medication editor's result.
@immutable
class MedDraft {
  const MedDraft({
    this.id,
    required this.name,
    this.kind = MedKind.medication,
    this.dose,
    this.doseAmount,
    this.doseUnit,
    this.slots = const [],
    this.takenWith = TakenWith.anytime,
    this.takenWithNote,
    this.notes,
    this.active = true,
    this.stock,
    this.refillAt,
    this.color,
    this.titration = const [],
    this.courseId,
  });

  factory MedDraft.of(MedSpec m) => MedDraft(
    id: m.id,
    name: m.name,
    kind: m.kind,
    dose: m.dose,
    doseAmount: m.doseAmount,
    doseUnit: m.doseUnit,
    slots: m.slots,
    takenWith: m.takenWith,
    takenWithNote: m.takenWithNote,
    notes: m.notes,
    active: m.active,
    stock: m.stock,
    refillAt: m.refillAt,
    color: m.color,
    titration: m.titration,
    courseId: m.courseId,
  );

  final String? id;
  final String name;
  final MedKind kind;
  final String? dose;
  final double? doseAmount;
  final String? doseUnit;
  final List<MedSlot> slots;
  final TakenWith takenWith;
  final String? takenWithNote;
  final String? notes;
  final bool active;
  final int? stock;
  final int? refillAt;
  final int? color;
  final List<TitrationStep> titration;
  final String? courseId;
}

@immutable
class CourseDraft {
  const CourseDraft({
    this.id,
    required this.name,
    required this.startDate,
    this.medicationId,
    this.phases = const [],
    this.notes,
    this.active = true,
  });

  factory CourseDraft.of(CourseSpec c) => CourseDraft(
    id: c.id,
    name: c.name,
    startDate: c.startDate,
    medicationId: c.medicationId,
    phases: c.phases,
    notes: c.notes,
    active: c.active,
  );

  final String? id;
  final String name;
  final DateTime startDate;
  final String? medicationId;
  final List<CoursePhase> phases;
  final String? notes;
  final bool active;
}

@immutable
class RuleDraft {
  const RuleDraft({this.id, required this.kind, required this.medAId, this.medBId, this.minutes = 0, this.note});

  factory RuleDraft.of(RuleSpec r) =>
      RuleDraft(id: r.id, kind: r.kind, medAId: r.medAId, medBId: r.medBId, minutes: r.minutes, note: r.note);

  final String? id;
  final MedRuleKind kind;
  final String medAId;
  final String? medBId;
  final int minutes;
  final String? note;
}

/// A dose answered from a notification (or anywhere that only knows the
/// medication and the slot).
enum MedDoseActionKind { taken, skipped, snoozed }

@immutable
class MedDoseAction {
  const MedDoseAction({required this.medId, required this.slot, required this.kind, required this.at, this.snooze});

  final String medId;
  final DateTime slot;
  final MedDoseActionKind kind;

  /// When the user answered.
  final DateTime at;
  final Duration? snooze;

  Map<String, Object?> toJson() => {
    'm': medId,
    's': slot.millisecondsSinceEpoch,
    'k': kind.name,
    'at': at.millisecondsSinceEpoch,
    if (snooze != null) 'z': snooze!.inMinutes,
  };

  static MedDoseAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw['m'], s = raw['s'], k = raw['k'], at = raw['at'], z = raw['z'];
    final kind = MedDoseActionKind.values.where((v) => v.name == k).firstOrNull;
    if (m is! String || s is! int || kind == null || at is! int) return null;
    return MedDoseAction(
      medId: m,
      slot: DateTime.fromMillisecondsSinceEpoch(s),
      kind: kind,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      snooze: z is int ? Duration(minutes: z) : null,
    );
  }

  @override
  String toString() => 'MedDoseAction(${kind.name} $medId@$slot)';
}

/// Reads and writes everything of the medication tracker. Every write
/// returns a [MedsUndo] that restores the exact prior state.
///
/// Storage notes:
/// * `Medications.times` holds each daily time's `HH:mm` (the dose's
///   identity); a time that follows a prayer or a meal also has its anchor
///   under `key_values` [anchorsKey] (`{medId: {"HH:mm": "prayer:fajr:+20"}}`).
/// * `MedDoses`: one row per answered slot (`scheduledAt` = the slot);
///   Snooze keeps the row with status `snoozed` and `takenAt` = the moment
///   it is snoozed until; Taken turns the same row into `taken`.
/// * Taken logs `ActivityLog` (planet `health`, kind [doseActivityKind]).
class MedsService {
  MedsService(this.repos, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  static const anchorsKey = 'meds.anchors';
  static const settingsKey = 'meds.settings';
  static const doseActivityKind = 'health.dose';
  static const doseTable = 'med_doses';

  MadarDatabase get _db => repos.db;

  DateTime get now => _clock();

  // ------------------------------------------------------------------ reads --

  static MedSpec specOf(MedicationRow r, Map<String, String> anchors) {
    final slots = <MedSlot>[];
    final seen = <String>{};
    for (final t in r.times) {
      final key = ClockHm.tryParse(t);
      if (key == null || !seen.add(key.hhmm)) continue;
      slots.add(MedSlot(key, TimeAnchor.decode(anchors[key.hhmm])));
    }
    slots.sort((a, b) => a.key.compareTo(b.key));
    return MedSpec(
      id: r.id,
      name: r.name,
      kind: r.kind,
      dose: r.dose,
      doseAmount: r.doseAmount,
      doseUnit: r.doseUnit,
      slots: slots,
      takenWith: r.takenWith,
      takenWithNote: r.takenWithNote,
      notes: r.notes,
      active: r.active,
      stock: r.stock,
      refillAt: r.refillAt,
      courseId: r.courseId,
      titration: TitrationStep.parseList(r.titration),
      color: r.color,
      createdAt: r.createdAt,
      sortOrder: r.sortOrder,
    );
  }

  static CourseSpec courseOf(MedCourseRow r) => CourseSpec(
    id: r.id,
    name: r.name,
    medicationId: r.medicationId,
    startDate: r.startDate,
    phases: CoursePhase.parseList(r.phases),
    notes: r.notes,
    active: r.active,
  );

  static RuleSpec ruleOf(MedRuleRow r) =>
      RuleSpec(id: r.id, kind: r.kind, medAId: r.medAId, medBId: r.medBId, minutes: r.minutes, note: r.note);

  static DoseLog logOf(MedDoseRow r) => DoseLog(
    id: r.id,
    medId: r.medicationId,
    slot: r.scheduledAt,
    at: r.takenAt,
    status: r.status,
    dose: r.dose,
    note: r.note,
  );

  Map<String, Map<String, String>> _decodeAnchors(Object? raw) {
    final out = <String, Map<String, String>>{};
    if (raw is! Map) return out;
    raw.forEach((medId, v) {
      if (medId is! String || v is! Map) return;
      out[medId] = {
        for (final e in v.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    });
    return out;
  }

  Future<Map<String, Map<String, String>>> _anchors() async => _decodeAnchors(await repos.keyValues.getJson(anchorsKey));

  /// Every medication (active and paused) in the user's order.
  Future<List<MedSpec>> meds() async {
    final anchors = await _anchors();
    return [for (final r in await repos.medications.getAll()) specOf(r, anchors[r.id] ?? const {})];
  }

  /// [meds] as a stream (anchors are written before their medication row, so
  /// every change comes through the row).
  Stream<List<MedSpec>> watchMeds() => repos.medications.watchAll().asyncMap((rows) async {
    final anchors = await _anchors();
    return [for (final r in rows) specOf(r, anchors[r.id] ?? const {})];
  });

  Future<MedSpec?> med(String id) async {
    final r = await repos.medications.byId(id);
    if (r == null) return null;
    return specOf(r, (await _anchors())[id] ?? const {});
  }

  Future<List<CourseSpec>> courses() async => [for (final r in await repos.medCourses.getAll()) courseOf(r)];

  Stream<List<CourseSpec>> watchCourses() => repos.medCourses.watchAll().map((rows) => [for (final r in rows) courseOf(r)]);

  Future<List<RuleSpec>> rules() async => [for (final r in await repos.medRules.getAll()) ruleOf(r)];

  Stream<List<RuleSpec>> watchRules() => repos.medRules.watchAll().map((rows) => [for (final r in rows) ruleOf(r)]);

  Expression<bool> _logsSince($MedDosesTable d, DateTime from) {
    final since = Variable<DateTime>(from).julianday;
    return d.scheduledAt.julianday.isBiggerOrEqual(since) |
        (d.scheduledAt.isNull() & d.takenAt.julianday.isBiggerOrEqual(since));
  }

  /// Dose-log entries whose slot (or, without one, whose time) is at or
  /// after [from].
  Future<List<DoseLog>> logs(DateTime from) async => [
    for (final r in await repos.medDoses.getAll(where: (d) => _logsSince(d, from))) logOf(r),
  ];

  Stream<List<DoseLog>> watchLogs(DateTime from) =>
      repos.medDoses.watchAll(where: (d) => _logsSince(d, from)).map((rows) => [for (final r in rows) logOf(r)]);

  Future<MedsSettings> settings() async => MedsSettings.fromJson(await repos.keyValues.getJson(settingsKey));

  Stream<MedsSettings> watchSettings() => repos.keyValues.watchJson(settingsKey).map(MedsSettings.fromJson);

  Future<void> saveSettings(MedsSettings settings) => repos.keyValues.setJson(settingsKey, settings.toJson());

  /// Standing alerts pinned by the health record (read-only here).
  Stream<List<HealthAlertRow>> watchAlerts() => repos.healthAlerts.watchAll(where: (a) => a.pinned.equals(true));

  // ------------------------------------------------------------ medications --

  Future<void> _setAnchors(String medId, List<MedSlot> slots) async {
    final all = await _anchors();
    final mine = {
      for (final s in slots)
        if (s.anchor != null) s.key.hhmm: s.anchor!.encode(),
    };
    if (mine.isEmpty) {
      if (all.remove(medId) == null) return;
    } else {
      all[medId] = mine;
    }
    await repos.keyValues.setJson(anchorsKey, all);
  }

  static List<String> _times(List<MedSlot> slots) {
    final keys = {for (final s in slots) s.key.hhmm}.toList()..sort();
    return keys;
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Creates or updates a medication (with its anchors and course link).
  Future<MedSpec> saveMed(MedDraft d) async {
    return _db.transaction(() async {
      final name = d.name.trim();
      final titration = [for (final s in d.titration) s.toJson()];
      final String id;
      if (d.id == null) {
        final row = await repos.medications.insert(
          MedicationsCompanion.insert(
            name: name,
            kind: Value(d.kind),
            dose: Value(_clean(d.dose)),
            doseAmount: Value(d.doseAmount),
            doseUnit: Value(_clean(d.doseUnit)),
            times: Value(_times(d.slots)),
            takenWith: Value(d.takenWith),
            takenWithNote: Value(_clean(d.takenWithNote)),
            notes: Value(_clean(d.notes)),
            active: Value(d.active),
            stock: Value(d.stock),
            refillAt: Value(d.refillAt),
            courseId: Value(d.courseId),
            titration: Value(titration),
            color: Value(d.color),
          ),
        );
        id = row.id;
        await _setAnchors(id, d.slots);
        // Touch the row so the stream sees the anchors.
        await repos.medications.update(MedicationsCompanion(id: Value(id)));
      } else {
        id = d.id!;
        await _setAnchors(id, d.slots);
        await repos.medications.update(
          MedicationsCompanion(
            id: Value(id),
            name: Value(name),
            kind: Value(d.kind),
            dose: Value(_clean(d.dose)),
            doseAmount: Value(d.doseAmount),
            doseUnit: Value(_clean(d.doseUnit)),
            times: Value(_times(d.slots)),
            takenWith: Value(d.takenWith),
            takenWithNote: Value(_clean(d.takenWithNote)),
            notes: Value(_clean(d.notes)),
            active: Value(d.active),
            stock: Value(d.stock),
            refillAt: Value(d.refillAt),
            courseId: Value(d.courseId),
            titration: Value(titration),
            color: Value(d.color),
          ),
        );
      }
      await _linkCourse(medId: id, courseId: d.courseId);
      return (await med(id))!;
    });
  }

  /// Keeps both sides of the medication ↔ course link in step.
  Future<void> _linkCourse({required String medId, required String? courseId}) async {
    for (final c in await repos.medCourses.getAll(where: (c) => c.medicationId.equals(medId))) {
      if (c.id != courseId) await repos.medCourses.update(MedCoursesCompanion(id: Value(c.id), medicationId: const Value(null)));
    }
    if (courseId != null) {
      await repos.medCourses.update(MedCoursesCompanion(id: Value(courseId), medicationId: Value(medId)));
    }
  }

  /// Deletes a medication with its rules and dose history; its courses are
  /// unlinked.
  Future<MedsUndo> deleteMed(String id) async {
    return _db.transaction(() async {
      final row = await repos.medications.delete(id);
      if (row == null) return _noUndo;
      final rules = await repos.medRules.deleteWhere((r) => r.medAId.equals(id) | r.medBId.equals(id));
      final doses = await repos.medDoses.deleteWhere((d) => d.medicationId.equals(id));
      final linked = await repos.medCourses.getAll(where: (c) => c.medicationId.equals(id));
      for (final c in linked) {
        await repos.medCourses.update(MedCoursesCompanion(id: Value(c.id), medicationId: const Value(null)));
      }
      final allAnchors = await _anchors();
      final myAnchors = allAnchors.remove(id);
      if (myAnchors != null) await repos.keyValues.setJson(anchorsKey, allAnchors);
      return () => _db.transaction(() async {
        if (myAnchors != null) {
          final a = await _anchors();
          a[id] = myAnchors;
          await repos.keyValues.setJson(anchorsKey, a);
        }
        await repos.medications.restore(row);
        await repos.medRules.restoreAll(rules);
        await repos.medDoses.restoreAll(doses);
        for (final c in linked) {
          await repos.medCourses.update(MedCoursesCompanion(id: Value(c.id), medicationId: Value(id)));
        }
      });
    });
  }

  /// Pauses / resumes a medication.
  Future<MedsUndo> setActive(String id, bool active) async {
    final row = await repos.medications.byId(id);
    if (row == null || row.active == active) return _noUndo;
    await repos.medications.update(MedicationsCompanion(id: Value(id), active: Value(active)));
    return () => repos.medications.update(MedicationsCompanion(id: Value(id), active: Value(row.active)));
  }

  /// Copies a medication (with its anchors) right after it; returns the copy.
  Future<(MedSpec, MedsUndo)> duplicateMed(String id, {String? name}) async {
    return _db.transaction(() async {
      final original = await med(id);
      if (original == null) throw StateError('No medication $id');
      final copy = await repos.medications.duplicate(id, overrides: {'name': ?name, 'courseId': null});
      await _setAnchors(copy.id, original.slots);
      final spec = (await med(copy.id))!;
      return (
        spec,
        () async {
          await _setAnchors(copy.id, const []);
          await repos.medications.delete(copy.id);
        },
      );
    });
  }

  Future<void> reorderMeds(List<String> ids) => repos.medications.reorder(ids);

  /// Sets the stock (e.g. after a refill).
  Future<MedsUndo> setStock(String id, int? stock) async {
    final row = await repos.medications.byId(id);
    if (row == null) return _noUndo;
    await repos.medications.update(MedicationsCompanion(id: Value(id), stock: Value(stock)));
    return () => repos.medications.update(MedicationsCompanion(id: Value(id), stock: Value(row.stock)));
  }

  // ---------------------------------------------------------------- courses --

  Future<CourseSpec> saveCourse(CourseDraft d) async {
    return _db.transaction(() async {
      final phases = [for (final p in d.phases) p.toJson()];
      final String id;
      if (d.id == null) {
        final row = await repos.medCourses.insert(
          MedCoursesCompanion.insert(
            name: d.name.trim(),
            startDate: MedDays.dateOnly(d.startDate),
            medicationId: Value(d.medicationId),
            phases: Value(phases),
            notes: Value(_clean(d.notes)),
            active: Value(d.active),
          ),
        );
        id = row.id;
      } else {
        id = d.id!;
        await repos.medCourses.update(
          MedCoursesCompanion(
            id: Value(id),
            name: Value(d.name.trim()),
            startDate: Value(MedDays.dateOnly(d.startDate)),
            medicationId: Value(d.medicationId),
            phases: Value(phases),
            notes: Value(_clean(d.notes)),
            active: Value(d.active),
          ),
        );
      }
      // The medication points back at its course; any other medication that
      // pointed here lets go.
      for (final m in await repos.medications.getAll(where: (m) => m.courseId.equals(id))) {
        if (m.id != d.medicationId) {
          await repos.medications.update(MedicationsCompanion(id: Value(m.id), courseId: const Value(null)));
        }
      }
      if (d.medicationId != null) {
        await repos.medications.update(MedicationsCompanion(id: Value(d.medicationId!), courseId: Value(id)));
      }
      return courseOf((await repos.medCourses.byId(id))!);
    });
  }

  Future<MedsUndo> deleteCourse(String id) async {
    return _db.transaction(() async {
      final row = await repos.medCourses.delete(id);
      if (row == null) return _noUndo;
      final linked = await repos.medications.getAll(where: (m) => m.courseId.equals(id));
      for (final m in linked) {
        await repos.medications.update(MedicationsCompanion(id: Value(m.id), courseId: const Value(null)));
      }
      return () => _db.transaction(() async {
        await repos.medCourses.restore(row);
        for (final m in linked) {
          await repos.medications.update(MedicationsCompanion(id: Value(m.id), courseId: Value(id)));
        }
      });
    });
  }

  // ------------------------------------------------------------------ rules --

  Future<RuleSpec> saveRule(RuleDraft d) async {
    final medB = d.kind == MedRuleKind.separate ? d.medBId : null;
    if (d.id == null) {
      final row = await repos.medRules.insert(
        MedRulesCompanion.insert(
          kind: d.kind,
          medAId: d.medAId,
          medBId: Value(medB),
          minutes: Value(d.minutes),
          note: Value(_clean(d.note)),
        ),
      );
      return ruleOf(row);
    }
    await repos.medRules.update(
      MedRulesCompanion(
        id: Value(d.id!),
        kind: Value(d.kind),
        medAId: Value(d.medAId),
        medBId: Value(medB),
        minutes: Value(d.minutes),
        note: Value(_clean(d.note)),
      ),
    );
    return ruleOf((await repos.medRules.byId(d.id!))!);
  }

  Future<MedsUndo> deleteRule(String id) async {
    final row = await repos.medRules.delete(id);
    if (row == null) return _noUndo;
    return () => repos.medRules.restore(row);
  }

  // ------------------------------------------------------------------ doses --

  Future<MedDoseRow?> _rowForSlot(String medId, DateTime slot) async {
    final lo = Variable<DateTime>(slot.subtract(const Duration(seconds: 59))).julianday;
    final hi = Variable<DateTime>(slot.add(const Duration(seconds: 59))).julianday;
    final rows = await repos.medDoses.getAll(
      where: (d) =>
          d.medicationId.equals(medId) &
          d.scheduledAt.julianday.isBiggerOrEqual(lo) &
          d.scheduledAt.julianday.isSmallerOrEqual(hi),
    );
    if (rows.isEmpty) return null;
    // Two rows for one slot should not exist; the answered one counts.
    rows.sort((a, b) => _rank(b.status).compareTo(_rank(a.status)));
    return rows.first;
  }

  static int _rank(DoseStatus s) => switch (s) {
    DoseStatus.taken => 3,
    DoseStatus.skipped => 2,
    DoseStatus.snoozed => 1,
    DoseStatus.missed => 0,
  };

  /// Writes [status] for the slot, returning the undo of the row change.
  Future<(MedDoseRow, MedsUndo)> _answer(
    String medId,
    DateTime slot, {
    required DoseStatus status,
    DateTime? at,
    String? dose,
  }) async {
    final prev = await _rowForSlot(medId, slot);
    if (prev == null) {
      final row = await repos.medDoses.insert(
        MedDosesCompanion.insert(
          medicationId: medId,
          scheduledAt: Value(slot),
          takenAt: Value(at),
          status: status,
          dose: Value(dose),
        ),
      );
      return (row, () async => repos.medDoses.delete(row.id).then((_) {}));
    }
    await repos.medDoses.update(
      MedDosesCompanion(id: Value(prev.id), status: Value(status), takenAt: Value(at), dose: Value(dose ?? prev.dose)),
    );
    final row = (await repos.medDoses.byId(prev.id))!;
    return (row, () => repos.medDoses.restore(prev));
  }

  /// Marks [dose] taken (at [at], default now): one row per slot, the stock
  /// goes down by the dose's units, `health.dose` is logged. Taking a dose
  /// that is already taken changes nothing.
  Future<DoseActionResult> take(PlannedDose dose, {DateTime? at}) =>
      takeSlot(dose.medId, dose.slot, at: at, dose: dose.dose, doseAmount: dose.doseAmount);

  Future<DoseActionResult> takeSlot(
    String medId,
    DateTime slot, {
    DateTime? at,
    String? dose,
    double? doseAmount,
  }) async {
    return _db.transaction(() async {
      final med = await repos.medications.byId(medId);
      if (med == null) return DoseActionResult.none;
      final existing = await _rowForSlot(medId, slot);
      if (existing?.status == DoseStatus.taken) return DoseActionResult.none;
      final when = at ?? now;
      final (row, undoRow) = await _answer(medId, slot, status: DoseStatus.taken, at: when, dose: dose ?? med.dose);
      final stock = await _useStock(med, doseAmount ?? med.doseAmount);
      final activity = await repos.activity.log(
        planetKey: 'health',
        kind: doseActivityKind,
        refTable: doseTable,
        refId: row.id,
        at: when,
        value: 1,
        payload: {'med': medId, if (stock.units != null) unitsKey: stock.units},
      );
      return DoseActionResult(
        medName: med.name,
        stockAfter: stock.after,
        refillCrossed: MedStock.crossedRefill(before: med.stock, after: stock.after, refillAt: med.refillAt),
        undo: () => _db.transaction(() async {
          await repos.activityLog.delete(activity.id);
          await stock.undo();
          await undoRow();
        }),
      );
    });
  }

  /// Activity payload key: the stock units a Taken used (so taking it back
  /// returns exactly those, whatever the day's titration step or course
  /// phase was).
  static const unitsKey = 'units';

  Future<({int? after, int? units, MedsUndo undo})> _useStock(MedicationRow med, double? amount) async {
    final before = med.stock;
    if (before == null) return (after: null, units: null, undo: _noUndo);
    final units = MedStock.unitsPerDose(med.doseUnit, amount);
    final after = (before - units).clamp(0, 1 << 30);
    await repos.medications.update(MedicationsCompanion(id: Value(med.id), stock: Value(after)));
    return (
      after: after,
      // What actually left the stock (a stock of 1 gives 1 for a dose of 2).
      units: before - after,
      undo: () => repos.medications.update(MedicationsCompanion(id: Value(med.id), stock: Value(before))),
    );
  }

  /// Takes back a Taken (restoring the stock and the activity).
  Future<MedsUndo> _untake(MedDoseRow row) async {
    final med = await repos.medications.byId(row.medicationId);
    final removed = await repos.activity.removeFor(refTable: doseTable, refId: row.id, kind: doseActivityKind);
    MedsUndo stockUndo = _noUndo;
    if (med?.stock != null) {
      // The units the Taken recorded; older entries fall back to the
      // medication's own dose.
      final recorded = removed.map((a) => a.payload[unitsKey]).whereType<num>().firstOrNull;
      final units = recorded?.toInt() ?? MedStock.unitsPerDose(med!.doseUnit, med.doseAmount);
      final before = med!.stock!;
      await repos.medications.update(MedicationsCompanion(id: Value(med.id), stock: Value(before + units)));
      stockUndo = () => repos.medications.update(MedicationsCompanion(id: Value(med.id), stock: Value(before)));
    }
    return () async {
      await repos.activityLog.restoreAll(removed);
      await stockUndo();
    };
  }

  /// Skips [dose] (a taken one is un-taken first).
  Future<DoseActionResult> skip(PlannedDose dose) => skipSlot(dose.medId, dose.slot, dose: dose.dose);

  Future<DoseActionResult> skipSlot(String medId, DateTime slot, {String? dose}) async {
    return _db.transaction(() async {
      final existing = await _rowForSlot(medId, slot);
      if (existing?.status == DoseStatus.skipped) return DoseActionResult.none;
      final untake = existing?.status == DoseStatus.taken ? await _untake(existing!) : _noUndo;
      final (_, undoRow) = await _answer(medId, slot, status: DoseStatus.skipped, at: null, dose: dose);
      return DoseActionResult(
        undo: () => _db.transaction(() async {
          await undoRow();
          await untake();
        }),
      );
    });
  }

  /// Snoozes [dose] for [by] from now (Snooze on a taken or skipped dose
  /// does nothing).
  Future<DoseActionResult> snooze(PlannedDose dose, Duration by) => snoozeSlot(dose.medId, dose.slot, by);

  Future<DoseActionResult> snoozeSlot(String medId, DateTime slot, Duration by, {DateTime? from}) async {
    return _db.transaction(() async {
      final existing = await _rowForSlot(medId, slot);
      if (existing != null && (existing.status == DoseStatus.taken || existing.status == DoseStatus.skipped)) {
        return DoseActionResult.none;
      }
      final until = (from ?? now).add(by);
      final (_, undoRow) = await _answer(medId, slot, status: DoseStatus.snoozed, at: until);
      return DoseActionResult(undo: undoRow);
    });
  }

  /// Clears any answer of [dose] (back to waiting).
  Future<DoseActionResult> reset(PlannedDose dose) async {
    return _db.transaction(() async {
      final existing = await _rowForSlot(dose.medId, dose.slot);
      if (existing == null) return DoseActionResult.none;
      final untake = existing.status == DoseStatus.taken ? await _untake(existing) : _noUndo;
      await repos.medDoses.delete(existing.id);
      return DoseActionResult(
        undo: () => _db.transaction(() async {
          await repos.medDoses.restore(existing);
          await untake();
        }),
      );
    });
  }

  /// Logs a dose taken outside the plan (as needed), at [at] (default now).
  Future<DoseActionResult> logNow(String medId, {DateTime? at, String? dose}) async {
    return _db.transaction(() async {
      final med = await repos.medications.byId(medId);
      if (med == null) return DoseActionResult.none;
      final when = at ?? now;
      final row = await repos.medDoses.insert(
        MedDosesCompanion.insert(
          medicationId: medId,
          takenAt: Value(when),
          status: DoseStatus.taken,
          dose: Value(dose ?? med.dose),
        ),
      );
      final stock = await _useStock(med, med.doseAmount);
      final activity = await repos.activity.log(
        planetKey: 'health',
        kind: doseActivityKind,
        refTable: doseTable,
        refId: row.id,
        at: when,
        value: 1,
        payload: {'med': medId, if (stock.units != null) unitsKey: stock.units},
      );
      return DoseActionResult(
        medName: med.name,
        stockAfter: stock.after,
        refillCrossed: MedStock.crossedRefill(before: med.stock, after: stock.after, refillAt: med.refillAt),
        undo: () => _db.transaction(() async {
          await repos.activityLog.delete(activity.id);
          await stock.undo();
          await repos.medDoses.delete(row.id);
        }),
      );
    });
  }

  /// The dose text / amount of a slot, as the plan would give it (course
  /// phase, else titration step, else the medication's own).
  Future<({String? dose, double? amount})> doseForSlot(String medId, DateTime slot) async {
    final m = await med(medId);
    if (m == null) return (dose: null, amount: null);
    final day = MedDays.dateOnly(slot);
    for (final c in await courses()) {
      if (!c.active || !(c.medicationId == m.id || c.id == m.courseId)) continue;
      final cd = CourseSchedule.doseOn(c, day);
      if (cd != null && cd.dose != null) return (dose: cd.dose, amount: cd.doseAmount);
    }
    final d = DoseScheduler.doseOn(m, day);
    return (dose: d?.dose ?? m.dose, amount: d?.amount ?? m.doseAmount);
  }

  /// Applies an answer that only knows the medication and the slot (a
  /// notification button).
  Future<DoseActionResult> apply(MedDoseAction action) async {
    switch (action.kind) {
      case MedDoseActionKind.taken:
        final d = await doseForSlot(action.medId, action.slot);
        return takeSlot(action.medId, action.slot, at: action.at, dose: d.dose, doseAmount: d.amount);
      case MedDoseActionKind.skipped:
        final d = await doseForSlot(action.medId, action.slot);
        return skipSlot(action.medId, action.slot, dose: d.dose);
      case MedDoseActionKind.snoozed:
        return snoozeSlot(action.medId, action.slot, action.snooze ?? const Duration(minutes: 10), from: action.at);
    }
  }
}
