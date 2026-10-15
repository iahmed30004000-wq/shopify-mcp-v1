import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../data/growth_service.dart';
import '../domain/goal_math.dart';
import '../domain/growth_days.dart';
import '../domain/growth_goal.dart';
import 'goal_celebration.dart';
import 'goal_sheet.dart';
import 'growth_texts.dart';
import 'log_progress_sheet.dart';

/// The Growth planet's user actions, shared by the screens and the card:
/// each writes through [GrowthService], plays its sound and haptic and
/// offers undo; logging that reaches a target celebrates.
abstract final class GrowthActions {
  static UndoableAction _undoable(String label, GrowthUndo undo) => UndoableAction(label: label, undo: undo);

  static GrowthService _service(WidgetRef ref) => ref.read(growthServiceProvider);

  // ------------------------------------------------------------- goals ----

  static Future<void> create(BuildContext context, WidgetRef ref) async {
    final draft = await showGoalSheet(context);
    if (draft == null || !context.mounted) return;
    final l = L10n.of(context);
    final (row, undo) = await _service(ref).createGoal(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undoable(l.growthGoalCreated(row.name), undo)));
  }

  static Future<void> edit(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final draft = await showGoalSheet(context, goal: goal);
    if (draft == null || !context.mounted) return;
    if (draft == GoalDraft.of(goal.row)) return;
    final l = L10n.of(context);
    final undo = await _service(ref).updateGoal(goal.row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undoable(l.growthGoalSaved, undo)));
  }

  /// Deletes [goal] with its logs; the returned action undoes it (the
  /// interaction kit shows the toast).
  static Future<UndoableAction> delete(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final l = L10n.of(context);
    final undo = await _service(ref).deleteGoal(goal.row);
    return _undoable(l.growthGoalDeleted(goal.name), undo);
  }

  static Future<UndoableAction> duplicate(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final l = L10n.of(context);
    final (_, undo) = await _service(ref).duplicateGoal(goal.row, name: l.growthCopyName(goal.name));
    Fx.fire(Sfx.drop);
    return _undoable(l.growthGoalDuplicated, undo);
  }

  static Future<UndoableAction> togglePause(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final l = L10n.of(context);
    final pause = goal.row.active;
    Fx.fire(pause ? Sfx.toggleOff : Sfx.toggleOn);
    final undo = await _service(ref).setActive(goal.row, !pause);
    return _undoable(pause ? l.growthGoalPaused : l.growthGoalResumed, undo);
  }

  static Future<void> reorder(WidgetRef ref, List<GrowthGoal> ordered, {List<GrowthGoal> rest = const []}) =>
      _service(ref).reorder([
        for (final g in [...ordered, ...rest]) g.id,
      ]);

  // -------------------------------------------------------------- logs ----

  /// Opens the log sheet and records what it returns.
  static Future<void> log(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final draft = await showLogProgressSheet(context, goal: goal);
    if (draft == null || !context.mounted) return;
    final action = await _record(context, ref, goal, draft.amount, at: draft.at, note: draft.note);
    if (action != null && context.mounted) unawaited(showUndoToast(context, action));
  }

  /// Logs [amount] now, in one tap. With [toast] false the caller shows the
  /// returned undo (e.g. a swipe of the interaction kit).
  static Future<UndoableAction?> quickLog(
    BuildContext context,
    WidgetRef ref,
    GrowthGoal goal,
    double amount, {
    bool toast = true,
  }) async {
    final action = await _record(context, ref, goal, amount);
    if (toast && action != null && context.mounted) unawaited(showUndoToast(context, action));
    return action;
  }

  /// Writes the log and answers it: particles and a chime, or – when it
  /// reaches the target – the celebration, awaited so the undo toast comes
  /// after it (never over its buttons). Returns null when nothing was
  /// logged, or when the user went on to set a new goal from the
  /// celebration (the log stays; it can be removed from the history).
  static Future<UndoableAction?> _record(
    BuildContext context,
    WidgetRef ref,
    GrowthGoal goal,
    double amount, {
    DateTime? at,
    String? note,
  }) async {
    if (amount <= 0) return null;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final tokens = context.tokens;
    final before = goal.stats.current;
    final (row, undo) = await _service(ref).addLog(goal.id, amount, at: at, note: note);
    final action = _undoable(l.growthLogged(texts.amount(goal.unit, amount), goal.name), undo);
    if (!context.mounted) return action;
    if (!GoalMath.crossesTarget(before: before, added: amount, target: goal.row.target)) {
      Fx.fire(Sfx.complete);
      Celebrate.burstFrom(
        context,
        kind: CelebrationKind.stardust,
        color: GrowthColors.goal(tokens, goal.color),
        intensity: 0.55,
      );
      return action;
    }
    final days = GrowthDays.between(goal.stats.start, row.at) + 1;
    final again = await showGoalCelebration(
      context,
      GoalCelebrationInfo(
        name: goal.name,
        amount: texts.amount(goal.unit, before + amount),
        days: days < 1 ? 1 : days,
        color: goal.color,
      ),
    );
    if (!again || !context.mounted) return action;
    unawaited(create(context, ref));
    return null;
  }

  static Future<void> editLog(BuildContext context, WidgetRef ref, GrowthGoal goal, GoalLogRow log) async {
    final draft = await showLogProgressSheet(context, goal: goal, log: log);
    if (draft == null || !context.mounted) return;
    final l = L10n.of(context);
    final undo = await _service(ref).updateLog(log, amount: draft.amount, at: draft.at, note: draft.note);
    if (!context.mounted) return;
    Fx.fire(Sfx.drop);
    unawaited(showUndoToast(context, _undoable(l.growthLogUpdated, undo)));
  }

  static Future<UndoableAction> deleteLog(BuildContext context, WidgetRef ref, GoalLogRow log) async {
    final l = L10n.of(context);
    final undo = await _service(ref).deleteLog(log);
    return _undoable(l.growthLogDeleted, undo);
  }
}
