import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/meds_providers.dart';
import '../data/meds_service.dart';
import '../domain/dose_tracker.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'course_editor.dart';
import 'medication_editor.dart';
import 'meds_sheets.dart';
import 'rule_editor.dart';

/// The medication tracker's user actions: each writes through
/// [MedsService], fires its sound + haptic and offers Undo.
abstract final class MedsActions {
  static MedsTexts texts(BuildContext context) => MedsTexts(L10n.of(context), MadarFormatter.of(context));

  static UndoableAction _undoable(String label, MedsUndo undo) => UndoableAction(label: label, undo: undo);

  static Future<void> _afterAnswer(WidgetRef ref, TrackedDose t, DoseActionResult result) async {
    if (!result.changed) return;
    await ref.read(medsReminderSyncProvider.notifier).afterAnswer(t.key, t.dose.medId, result);
  }

  /// Taken (now).
  static Future<UndoableAction?> take(BuildContext context, WidgetRef ref, TrackedDose t, {bool toast = true}) async {
    final tx = texts(context);
    final result = await ref.read(medsServiceProvider).take(t.dose);
    if (!result.changed) return null;
    Fx.fire(Sfx.complete);
    if (context.mounted) Celebrate.burstFrom(context, kind: CelebrationKind.stardust, intensity: 0.5);
    unawaited(_afterAnswer(ref, t, result));
    final action = _undoable(tx.l.medsTookToast(tx.name(t.dose.med.name)), result.undo);
    if (toast && context.mounted) unawaited(showUndoToast(context, action));
    return action;
  }

  static Future<UndoableAction?> skip(BuildContext context, WidgetRef ref, TrackedDose t, {bool toast = true}) async {
    final tx = texts(context);
    final result = await ref.read(medsServiceProvider).skip(t.dose);
    if (!result.changed) return null;
    Fx.fire(Sfx.toggleOff);
    unawaited(_afterAnswer(ref, t, result));
    final action = _undoable(tx.l.medsSkippedToast(tx.name(t.dose.med.name)), result.undo);
    if (toast && context.mounted) unawaited(showUndoToast(context, action));
    return action;
  }

  static Future<UndoableAction?> snooze(
    BuildContext context,
    WidgetRef ref,
    TrackedDose t,
    int minutes, {
    bool toast = true,
  }) async {
    final tx = texts(context);
    final service = ref.read(medsServiceProvider);
    final result = await service.snooze(t.dose, Duration(minutes: minutes));
    if (!result.changed) return null;
    Fx.fire(Sfx.drop);
    unawaited(_afterAnswer(ref, t, result));
    final until = service.now.add(Duration(minutes: minutes));
    final action = _undoable(tx.l.medsSnoozedToast(tx.name(t.dose.med.name), tx.time(until)), result.undo);
    if (toast && context.mounted) unawaited(showUndoToast(context, action));
    return action;
  }

  /// Asks for 10 / 30 / 60 minutes, then snoozes.
  static Future<void> pickSnooze(BuildContext context, WidgetRef ref, TrackedDose t) async {
    final minutes = await showSnoozeSheet(context, name: t.dose.med.name);
    if (minutes == null || !context.mounted) return;
    await snooze(context, ref, t, minutes);
  }

  static Future<UndoableAction?> reset(BuildContext context, WidgetRef ref, TrackedDose t) async {
    final l = L10n.of(context);
    final result = await ref.read(medsServiceProvider).reset(t.dose);
    if (!result.changed) return null;
    Fx.fire(Sfx.undo);
    return _undoable(l.medsResetToast, result.undo);
  }

  /// Logs an as-needed dose now.
  static Future<void> logNow(BuildContext context, WidgetRef ref, MedSpec med) async {
    final tx = texts(context);
    final result = await ref.read(medsServiceProvider).logNow(med.id);
    if (!result.changed) return;
    Fx.fire(Sfx.complete);
    if (context.mounted) Celebrate.burstFrom(context, kind: CelebrationKind.stardust, intensity: 0.4);
    if (result.refillCrossed) {
      unawaited(ref.read(medsReminderSyncProvider.notifier).afterAnswer(null, med.id, result));
    }
    if (context.mounted) unawaited(showUndoToast(context, _undoable(tx.l.medsTookToast(tx.name(med.name)), result.undo)));
  }

  // ------------------------------------------------------------ medications --

  static Future<void> addMed(BuildContext context, WidgetRef ref) async {
    final draft = await showMedicationEditor(context);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveMed(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<void> editMed(BuildContext context, WidgetRef ref, MedSpec med) async {
    final draft = await showMedicationEditor(context, med: med);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveMed(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> deleteMed(BuildContext context, WidgetRef ref, MedSpec med) async {
    final tx = texts(context);
    final undo = await ref.read(medsServiceProvider).deleteMed(med.id);
    return _undoable(tx.l.medsDeletedToast(tx.name(med.name)), undo);
  }

  static Future<UndoableAction?> togglePause(BuildContext context, WidgetRef ref, MedSpec med) async {
    final tx = texts(context);
    final undo = await ref.read(medsServiceProvider).setActive(med.id, !med.active);
    Fx.fire(med.active ? Sfx.toggleOff : Sfx.toggleOn);
    return _undoable(
      med.active ? tx.l.medsPausedToast(tx.name(med.name)) : tx.l.medsResumedToast(tx.name(med.name)),
      undo,
    );
  }

  static Future<UndoableAction?> duplicateMed(BuildContext context, WidgetRef ref, MedSpec med) async {
    final tx = texts(context);
    final (_, undo) = await ref.read(medsServiceProvider).duplicateMed(med.id, name: tx.l.medsCopyName(med.name));
    Fx.fire(Sfx.sparkle);
    return _undoable(tx.l.medsDuplicatedToast(tx.name(med.name)), undo);
  }

  static Future<void> refill(BuildContext context, WidgetRef ref, MedSpec med) async {
    final tx = texts(context);
    final added = await showRefillSheet(context, med: med);
    if (added == null || added <= 0) return;
    final undo = await ref.read(medsServiceProvider).setStock(med.id, (med.stock ?? 0) + added);
    Fx.fire(Sfx.complete);
    if (context.mounted) unawaited(showUndoToast(context, _undoable(tx.l.medsStockUpdated(tx.name(med.name)), undo)));
  }

  static Future<void> openHistory(BuildContext context, WidgetRef ref, MedSpec med) =>
      showMedHistorySheet(context, medId: med.id);

  // ------------------------------------------------------------------ rules --

  static Future<void> addRule(BuildContext context, WidgetRef ref) async {
    final draft = await showRuleEditor(context);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveRule(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<void> editRule(BuildContext context, WidgetRef ref, RuleSpec rule) async {
    final draft = await showRuleEditor(context, rule: rule);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveRule(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> deleteRule(BuildContext context, WidgetRef ref, RuleSpec rule) async {
    final l = L10n.of(context);
    final undo = await ref.read(medsServiceProvider).deleteRule(rule.id);
    return _undoable(l.medsRuleDeleted, undo);
  }

  // ---------------------------------------------------------------- courses --

  static Future<void> addCourse(BuildContext context, WidgetRef ref) async {
    final draft = await showCourseEditor(context);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveCourse(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<void> editCourse(BuildContext context, WidgetRef ref, CourseSpec course) async {
    final draft = await showCourseEditor(context, course: course);
    if (draft == null) return;
    await ref.read(medsServiceProvider).saveCourse(draft);
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> deleteCourse(BuildContext context, WidgetRef ref, CourseSpec course) async {
    final l = L10n.of(context);
    final undo = await ref.read(medsServiceProvider).deleteCourse(course.id);
    return _undoable(l.medsCourseDeleted, undo);
  }

  static Future<void> openSettings(BuildContext context, WidgetRef ref) async {
    final current = ref.read(medsSettingsProvider).value;
    if (current == null) return;
    final next = await showMedsSettingsSheet(context, settings: current);
    if (next == null || next == current) return;
    await ref.read(medsServiceProvider).saveSettings(next);
    Fx.fire(Sfx.complete);
  }
}
