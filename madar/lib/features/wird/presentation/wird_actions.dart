import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../data/wird_providers.dart';
import '../data/wird_service.dart';
import '../domain/wird_engine.dart';
import '../domain/wird_plan.dart';
import 'wird_labels.dart';
import 'wird_plan_sheet.dart';
import 'wird_progress_sheet.dart';

/// The wird's user actions, shared by the screen and the Faith-hub card:
/// each one writes through [WirdService], plays its sound and haptic, and
/// offers undo.
abstract final class WirdActions {
  static UndoableAction _undoable(String label, WirdUndo undo) => UndoableAction(label: label, undo: undo);

  /// Records the rest of today's portion as read.
  static Future<void> markDone(BuildContext context, WidgetRef ref, WirdPlanState state) async {
    final l = L10n.of(context);
    final axes = ref.read(wirdAxesProvider).value;
    final undo = await ref.read(wirdServiceProvider).markDone(state, pagesAxis: axes?.pages);
    if (undo == null || !context.mounted) return;
    Fx.fire(Sfx.complete);
    Celebrate.burstFrom(context, kind: CelebrationKind.lanternSparks);
    unawaited(showUndoToast(context, _undoable(l.wirdDoneToast, undo)));
  }

  /// "I stopped at…": picks the last ayah read and records it.
  static Future<void> stoppedAt(BuildContext context, WidgetRef ref, WirdPlanState state) async {
    final axes = ref.read(wirdAxesProvider).value;
    if (axes == null) return;
    final last = await showWirdProgressSheet(context, state: state, catalog: axes.catalog);
    if (last == null || !context.mounted) return;
    final undo = await ref.read(wirdServiceProvider).readUntil(state, last, pagesAxis: axes.pages);
    if (undo == null || !context.mounted) return;
    final l = L10n.of(context);
    Fx.fire(Sfx.complete);
    final texts = WirdTexts.of(context, axes.catalog);
    unawaited(showUndoToast(context, _undoable(l.wirdPartialToast(texts.ayah(last)), undo)));
  }

  /// Opens the reader (the app's route) at where the plan stands.
  static void readNow(BuildContext context, WirdReadNow handler, WirdPlanState state) {
    final start = state.target.resumeAt;
    if (start == null) return;
    Fx.fire(Sfx.navigate);
    handler(context, WirdReadRequest(planId: state.plan.id, start: start, range: state.target.remaining));
  }

  static Future<void> create(BuildContext context, WidgetRef ref) async {
    final draft = await showWirdPlanSheet(context);
    if (draft == null || !context.mounted) return;
    final l = L10n.of(context);
    final axes = ref.read(wirdAxesProvider).value;
    final (plan, undo) = await ref.read(wirdServiceProvider).create(draft, pagesAxis: axes?.pages);
    if (draft.remind && draft.window != null) unawaited(ref.read(wirdReminderServiceProvider).ensurePermission());
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undoable(l.wirdCreatedToast(plan.name), undo)));
  }

  static Future<void> edit(BuildContext context, WidgetRef ref, WirdPlan plan) async {
    final draft = await showWirdPlanSheet(context, plan: plan);
    if (draft == null || !context.mounted) return;
    final l = L10n.of(context);
    final axes = ref.read(wirdAxesProvider).value;
    final undo = await ref.read(wirdServiceProvider).update(plan, draft, pagesAxis: axes?.pages);
    if (draft.remind && draft.window != null) unawaited(ref.read(wirdReminderServiceProvider).ensurePermission());
    if (!context.mounted) return;
    unawaited(showUndoToast(context, _undoable(l.wirdSavedToast, undo)));
  }

  static Future<UndoableAction> delete(BuildContext context, WidgetRef ref, WirdPlan plan) async {
    final l = L10n.of(context);
    final undo = await ref.read(wirdServiceProvider).delete(plan);
    return _undoable(l.wirdDeletedToast, undo);
  }

  static Future<UndoableAction> togglePause(BuildContext context, WidgetRef ref, WirdPlan plan) async {
    final l = L10n.of(context);
    final service = ref.read(wirdServiceProvider);
    if (plan.active) {
      Fx.fire(Sfx.toggleOff);
      return _undoable(l.wirdPausedToast, await service.pause(plan));
    }
    Fx.fire(Sfx.toggleOn);
    return _undoable(l.wirdResumedToast, await service.resume(plan));
  }

  static Future<UndoableAction> makePrimary(BuildContext context, WidgetRef ref, WirdPlan plan) async {
    final l = L10n.of(context);
    Fx.fire(Sfx.sparkle);
    return _undoable(l.wirdPrimaryToast(plan.name), await ref.read(wirdServiceProvider).setPrimary(plan.id));
  }

  /// The ayah where [state]'s reading continues (for "read now").
  static AyahRef? resumeOf(WirdPlanState state) => state.target.resumeAt;
}
