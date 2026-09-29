import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/record_providers.dart';
import '../data/record_service.dart';
import '../domain/appointment_plan.dart';
import '../domain/lab_series.dart';
import 'lab_visit_sheet.dart';
import 'record_sheets.dart';

/// Every user action of the record: opens the sheet, writes through
/// [RecordService], plays the feedback and offers undo. Row actions return
/// an [UndoableAction] (the interaction kit shows the toast); the others
/// show it themselves.
class RecordActions {
  RecordActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  RecordService get _s => ref.read(recordServiceProvider);
  L10n get _l => L10n.of(context);
  DateTime get _now => ref.read(recordClockProvider)();
  DateTime get _today => ref.read(recordTodayProvider);

  void _toast(String label, RecordUndo undo) {
    if (!context.mounted) return;
    unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
  }

  UndoableAction? _undoable(String label, RecordUndo? undo) =>
      undo == null ? null : UndoableAction(label: label, undo: undo);

  // ---------------------------------------------------------------- alerts

  Future<void> addAlert() async {
    final v = await RecordSheets.alert(context);
    if (v == null) return;
    final (_, undo) = await _s.addAlert(body: v.body, severity: v.severity, pinned: v.pinned);
    Fx.fire(Sfx.complete);
    _toast(_l.recordAlertAdded, undo);
  }

  Future<void> editAlert(HealthAlertRow a) async {
    final v = await RecordSheets.alert(context, initial: a);
    if (v == null) return;
    final undo = await _s.updateAlert(a.copyWith(body: v.body, severity: v.severity, pinned: v.pinned));
    _toast(_l.recordSavedToast, undo);
  }

  Future<UndoableAction?> togglePin(HealthAlertRow a) async {
    final undo = await _s.setAlertPinned(a.id, !a.pinned);
    Fx.fire(a.pinned ? Sfx.toggleOff : Sfx.toggleOn);
    return _undoable(a.pinned ? _l.recordAlertUnpinnedToast : _l.recordAlertPinnedToast, undo);
  }

  Future<UndoableAction?> deleteAlert(HealthAlertRow a) async =>
      _undoable(_l.recordAlertDeleted, await _s.deleteAlert(a.id));

  Future<void> reorderAlerts(List<HealthAlertRow> order) async {
    final undo = await _s.reorderAlerts([for (final a in order) a.id]);
    _toast(_l.recordReordered, undo);
  }

  // ------------------------------------------------------------ conditions

  Future<void> addCondition() async {
    final v = await RecordSheets.condition(context, today: _today);
    if (v == null) return;
    final (_, undo) = await _s.addCondition(name: v.name, notes: v.notes, since: v.since, active: v.active);
    Fx.fire(Sfx.complete);
    _toast(_l.recordConditionAdded, undo);
  }

  Future<void> editCondition(ConditionRow c) async {
    final v = await RecordSheets.condition(context, initial: c, today: _today);
    if (v == null) return;
    final undo = await _s.updateCondition(
      c.copyWith(name: v.name, notes: Value(v.notes), since: Value(v.since), active: v.active),
    );
    _toast(_l.recordSavedToast, undo);
  }

  Future<UndoableAction?> toggleConditionActive(ConditionRow c) async {
    final undo = await _s.setConditionActive(c.id, !c.active);
    Fx.fire(c.active ? Sfx.toggleOff : Sfx.toggleOn);
    return _undoable(c.active ? _l.recordConditionMarkedInactive : _l.recordConditionMarkedActive, undo);
  }

  Future<UndoableAction?> deleteCondition(ConditionRow c) async =>
      _undoable(_l.recordConditionDeleted, await _s.deleteCondition(c.id));

  Future<void> reorderConditions(List<ConditionRow> order) async {
    final undo = await _s.reorderConditions([for (final c in order) c.id]);
    _toast(_l.recordReordered, undo);
  }

  // ------------------------------------------------------------------ labs

  List<String> _categories() {
    final tests = ref.read(labTestsProvider).value ?? const <LabTestRow>[];
    final seen = <String>{};
    return [
      for (final t in tests)
        if (t.category?.trim() case final c? when c.isNotEmpty && seen.add(c)) c,
    ];
  }

  Future<LabTestRow?> addTest() async {
    final v = await RecordSheets.labTest(context, categories: _categories());
    if (v == null) return null;
    final (row, undo) = await _s.addTest(
      name: v.name,
      unit: v.unit,
      low: v.low,
      high: v.high,
      category: v.category,
      notes: v.notes,
    );
    Fx.fire(Sfx.complete);
    _toast(_l.recordLabTestAdded, undo);
    return row;
  }

  Future<void> editTest(LabTestRow t) async {
    final v = await RecordSheets.labTest(context, initial: t, categories: _categories());
    if (v == null) return;
    final undo = await _s.updateTest(
      t.copyWith(
        name: v.name,
        unit: Value(v.unit),
        low: Value(v.low),
        high: Value(v.high),
        category: Value(v.category),
        notes: Value(v.notes),
      ),
    );
    _toast(_l.recordSavedToast, undo);
  }

  Future<UndoableAction?> deleteTest(LabTestRow t) async =>
      _undoable(_l.recordLabTestDeleted, await _s.deleteTest(t.id));

  Future<void> reorderTests(List<String> ids) async {
    final undo = await _s.reorderTests(ids);
    _toast(_l.recordReordered, undo);
  }

  Future<void> addReading(LabTestView v) async {
    final r = await RecordSheets.reading(context, test: v.test, today: _today, decimals: v.decimals);
    if (r == null) return;
    final (_, undo) = await _s.addReading(testId: v.test.id, date: r.date, input: r.input, note: r.note);
    Fx.fire(Sfx.complete);
    _toast(_l.recordLabReadingAdded, undo);
  }

  Future<void> editReading(LabTestView v, LabPoint p) async {
    final row = await ref.read(repositoriesProvider).labReadings.byId(p.id);
    if (row == null || !context.mounted) return;
    final r = await RecordSheets.reading(context, test: v.test, initial: row, today: _today, decimals: v.decimals);
    if (r == null) return;
    final undo = await _s.updateReading(
      row.copyWith(date: r.date, value: Value(r.input.value), valueText: Value(r.input.text), note: Value(r.note)),
    );
    _toast(_l.recordSavedToast, undo);
  }

  Future<UndoableAction?> deleteReading(LabPoint p) async =>
      _undoable(_l.recordLabReadingDeleted, await _s.deleteReading(p.id));

  /// Several results at once. Offers to create a test first when there is
  /// none.
  Future<void> labVisit() async {
    var tests = ref.read(labTestViewsProvider).value ?? const <LabTestView>[];
    if (tests.isEmpty) {
      final added = await addTest();
      if (added == null || !context.mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      tests = ref.read(labTestViewsProvider).value ?? const <LabTestView>[];
      if (tests.isEmpty || !context.mounted) return;
    }
    final result = await showLabVisitSheet(context, tests: tests, today: _today);
    if (result == null || result.entries.isEmpty) return;
    final (rows, undo) = await _s.addVisit(date: result.date, entries: result.entries);
    if (!context.mounted) return;
    _toast(_l.recordLabVisitSaved(rows.length, MadarFormatter.of(context).formatInt(rows.length)), undo);
  }

  // ---------------------------------------------------------- appointments

  Future<void> _nudgePermission() async {
    if (!ref.read(recordSettingsValueProvider).remindersEnabled) return;
    try {
      await ref.read(recordReminderSchedulerProvider).ensurePermission();
    } catch (_) {
      // No permission prompt available (tests, previews).
    }
  }

  Future<void> addAppointment() async {
    final v = await RecordSheets.appointment(context, now: _now);
    if (v == null) return;
    final (_, undo) = await _s.addAppointment(
      title: v.title,
      at: v.at,
      doctor: v.doctor,
      place: v.place,
      notes: v.notes,
    );
    Fx.fire(Sfx.complete);
    _toast(_l.recordAppointmentAdded, undo);
    unawaited(_nudgePermission());
  }

  Future<void> editAppointment(AppointmentRow a) async {
    final v = await RecordSheets.appointment(context, initial: a, now: _now);
    if (v == null) return;
    final undo = await _s.updateAppointment(
      a.copyWith(title: v.title, at: v.at, doctor: Value(v.doctor), place: Value(v.place), notes: Value(v.notes)),
    );
    _toast(_l.recordSavedToast, undo);
  }

  Future<UndoableAction?> toggleAppointmentDone(AppointmentRow a) async {
    final undo = await _s.setAppointmentDone(a.id, !a.done);
    if (a.done) Fx.fire(Sfx.toggleOff);
    return _undoable(a.done ? _l.recordAppointmentUndoneToast : _l.recordAppointmentDoneToast, undo);
  }

  Future<UndoableAction?> deleteAppointment(AppointmentRow a) async =>
      _undoable(_l.recordAppointmentDeleted, await _s.deleteAppointment(a.id));

  // ------------------------------------------------------------- questions

  List<AppointmentRow> _upcoming() =>
      AppointmentTimeline.split(ref.read(appointmentsProvider).value ?? const [], _now).upcoming;

  Future<void> addQuestion({String? appointmentId}) async {
    final v = await RecordSheets.question(context, appointments: _upcoming(), appointmentId: appointmentId);
    if (v == null) return;
    final (_, undo) = await _s.addQuestion(question: v.question, appointmentId: v.appointmentId);
    Fx.fire(Sfx.complete);
    _toast(_l.recordQuestionAdded, undo);
  }

  Future<void> editQuestion(DoctorQuestionRow q) async {
    final all = ref.read(appointmentsProvider).value ?? const <AppointmentRow>[];
    final upcoming = _upcoming();
    // Keep the question's own (maybe past) appointment selectable.
    final own = all.where((a) => a.id == q.appointmentId && !upcoming.contains(a));
    final v = await RecordSheets.question(context, initial: q, appointments: [...own, ...upcoming]);
    if (v == null) return;
    final undo = await _s.updateQuestion(
      q.copyWith(
        question: v.question,
        appointmentId: Value(v.appointmentId),
        answered: v.answered,
        answer: Value(v.answer),
      ),
    );
    _toast(_l.recordSavedToast, undo);
  }

  /// Swipe: asks for the answer (optional), then marks it answered.
  Future<UndoableAction?> markAnswered(DoctorQuestionRow q) async {
    if (q.answered) {
      final undo = await _s.setAnswered(q.id, false);
      Fx.fire(Sfx.toggleOff);
      return _undoable(_l.recordQuestionReopened, undo);
    }
    final answer = await RecordSheets.answer(context, q);
    if (answer == null) return null;
    final undo = await _s.setAnswered(q.id, true, answer: answer);
    Fx.fire(Sfx.complete);
    return _undoable(_l.recordQuestionAnsweredToast, undo);
  }

  Future<UndoableAction?> deleteQuestion(DoctorQuestionRow q) async =>
      _undoable(_l.recordQuestionDeleted, await _s.deleteQuestion(q.id));

  Future<void> reorderQuestions(List<DoctorQuestionRow> order) async {
    final undo = await _s.reorderQuestions([for (final q in order) q.id]);
    _toast(_l.recordReordered, undo);
  }

  // -------------------------------------------------------------- settings

  Future<void> openSettings() async {
    final current = ref.read(recordSettingsValueProvider);
    final next = await RecordSheets.settings(context, current);
    if (next == null || next == current) return;
    final undo = await _s.saveSettings(next);
    _toast(_l.recordSavedToast, undo);
  }
}
