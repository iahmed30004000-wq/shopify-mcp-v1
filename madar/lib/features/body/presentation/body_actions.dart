import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/body_providers.dart';
import '../data/body_service.dart';
import '../domain/body_clock.dart';
import '../domain/fasting.dart';
import '../domain/training.dart';
import '../domain/water.dart';
import 'body_texts.dart';
import 'sheets/exercise_sheet.dart';
import 'sheets/workout_log_sheet.dart';
import 'widgets/body_widgets.dart';

UndoableAction _undo(String label, BodyUndo undo) => UndoableAction(label: label, undo: undo);

/// Wraps a user-typed name for a sentence: bidi-isolated, so a Latin name
/// in an Arabic toast keeps its place and punctuation. Read it before any
/// await (the row may leave the tree).
String Function(String name) _namer(BuildContext context) => BodyTexts.of(context).fmt.isolate;

/// Every user action of the Body screens: sheets, writes, feedback and undo.
/// Actions that return an [UndoableAction] are shown as an undo toast by
/// the calling [ActionableItem]; the others show their own.
abstract final class BodyActions {
  // ------------------------------------------------------------ plan ----

  static Future<void> addExercise(BuildContext context, WidgetRef ref) async {
    final draft = await showExerciseSheet(context);
    if (draft == null) return;
    await ref.read(bodyServiceProvider).addExercise(draft);
  }

  static Future<void> editExercise(BuildContext context, WidgetRef ref, String exerciseId) async {
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null || !context.mounted) return;
    final draft = await showExerciseSheet(context, exercise: row);
    if (draft == null) return;
    await ref.read(bodyServiceProvider).updateExercise(row, draft);
  }

  static Future<UndoableAction?> duplicateExercise(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final isolate = _namer(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null) return null;
    final (_, undo) = await ref.read(bodyServiceProvider).duplicateExercise(row, name: l.bodyCopyName(row.name));
    return _undo(l.bodyDuplicatedName(isolate(row.name)), undo);
  }

  static Future<UndoableAction?> toggleExerciseActive(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final isolate = _namer(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).setExerciseActive(row, !row.active);
    Fx.fire(row.active ? Sfx.toggleOff : Sfx.toggleOn);
    final name = isolate(row.name);
    return _undo(row.active ? l.bodyPausedName(name) : l.bodyResumedName(name), undo);
  }

  static Future<UndoableAction?> deleteExercise(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final isolate = _namer(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).deleteExercise(row);
    return _undo(l.bodyDeletedName(isolate(row.name)), undo);
  }

  // -------------------------------------------------------- workouts ----

  /// Marks [exercise] done for today with its planned values (swipe /
  /// check). Celebrates when it completes the day's session.
  static Future<UndoableAction?> quickLog(BuildContext context, WidgetRef ref, PlannedExercise exercise) async {
    final l = L10n.of(context);
    final isolate = _namer(context);
    final before = ref.read(bodyTrainingTodayProvider);
    final (_, undo) = await ref
        .read(bodyServiceProvider)
        .logWorkout(
          WorkoutDraft(
            exerciseId: exercise.id,
            name: exercise.name,
            at: ref.read(bodyClockProvider)(),
            sets: exercise.sets,
            reps: exercise.reps,
            weight: exercise.weight,
            durationMin: exercise.durationMin,
          ),
        );
    if (context.mounted && before.completedBy(exercise.id)) {
      _celebrate(context, BodyPalette.of(context).training);
    }
    return _undo(l.bodyLoggedToast(isolate(exercise.name)), undo);
  }

  /// Opens the log sheet for [exercise] (prefilled) or a free workout.
  static Future<void> logWithDetails(BuildContext context, WidgetRef ref, {PlannedExercise? exercise}) async {
    final draft = await showWorkoutLogSheet(context, exercise: exercise);
    if (draft == null) return;
    final before = ref.read(bodyTrainingTodayProvider);
    await ref.read(bodyServiceProvider).logWorkout(draft);
    Fx.fire(Sfx.complete);
    final today = ref.read(bodyTodayProvider);
    final forToday = BodyDays.same(ref.read(bodyWallClockProvider).dayOf(draft.at), today);
    if (context.mounted && forToday && before.completedBy(draft.exerciseId)) {
      _celebrate(context, BodyPalette.of(context).training);
    }
  }

  static Future<void> editWorkout(BuildContext context, WidgetRef ref, String logId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).workoutLogs.byId(logId);
    if (row == null || !context.mounted) return;
    final draft = await showWorkoutLogSheet(context, log: row);
    if (draft == null) return;
    final undo = await ref.read(bodyServiceProvider).updateWorkout(row, draft);
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.bodyLogUpdated, undo));
  }

  /// Removes a log (un-marks a done exercise).
  static Future<UndoableAction?> deleteWorkout(BuildContext context, WidgetRef ref, String logId, {bool unmark = false}) async {
    final l = L10n.of(context);
    final isolate = _namer(context);
    final row = await ref.read(repositoriesProvider).workoutLogs.byId(logId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).deleteWorkout(row);
    return _undo(unmark ? l.bodyUnloggedToast(isolate(row.name)) : l.bodyLogDeleted, undo);
  }

  // ----------------------------------------------------------- avoid ----

  static List<FieldSpec> _avoidFields(L10n l) => [
    FieldSpec.text(
      'body',
      l.bodyAvoidWhat,
      required: true,
      hint: l.bodyAvoidWhatHint,
      icon: Icons.do_not_disturb_on_outlined,
      maxLength: 120,
      autofocus: true,
    ),
    FieldSpec.multiline('reason', l.bodyAvoidReason, hint: l.bodyAvoidReasonHint, maxLength: 400),
  ];

  static Future<void> addAvoid(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.bodyAvoidAdd,
      subtitle: l.bodyAvoidSubtitle,
      icon: Icons.do_not_disturb_on_outlined,
      fields: _avoidFields(l),
      saveLabel: l.bodySave,
    );
    final body = (v?['body'] as String?)?.trim();
    if (body == null || body.isEmpty) return;
    await ref.read(bodyServiceProvider).addAvoid(body, reason: v?['reason'] as String?);
  }

  static Future<void> editAvoid(BuildContext context, WidgetRef ref, AvoidItemRow row) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.bodyAvoidEdit,
      icon: Icons.do_not_disturb_on_outlined,
      fields: _avoidFields(l),
      initial: {'body': row.body, 'reason': row.reason ?? ''},
      saveLabel: l.bodySave,
    );
    final body = (v?['body'] as String?)?.trim();
    if (body == null || body.isEmpty) return;
    await ref.read(bodyServiceProvider).updateAvoid(row, body, reason: v?['reason'] as String?);
  }

  static Future<UndoableAction?> deleteAvoid(BuildContext context, WidgetRef ref, AvoidItemRow row) async {
    final l = L10n.of(context);
    final undo = await ref.read(bodyServiceProvider).deleteAvoid(row);
    return _undo(l.bodyAvoidRemoved, undo);
  }

  // --------------------------------------------------------- fasting ----

  static Future<void> startFast(BuildContext context, WidgetRef ref, {DateTime? at}) async {
    final l = L10n.of(context);
    final (_, undo) = await ref.read(bodyServiceProvider).startFast(at: at);
    Fx.fire(Sfx.toggleOn);
    if (context.mounted) await showUndoToast(context, _undo(l.bodyFastStarted, undo));
  }

  /// Starts a fast that began earlier (defaults to the last planned start
  /// when that was within the last day).
  static Future<void> startFastEarlier(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final now = ref.read(bodyClockProvider)();
    final plan = ref.read(bodyFastingPlanProvider).value ?? const FastingPlan();
    final planned = FastingMath.lastPlannedStart(plan, now, clock: ref.read(bodyWallClockProvider));
    final guess = now.difference(planned) < const Duration(hours: 24) ? planned : now;
    final at = await _pickMoment(context, title: l.bodyFastStartTitle, initial: guess, now: now, l: l);
    if (at == null || !context.mounted) return;
    await startFast(context, ref, at: at);
  }

  static Future<void> stopFast(BuildContext context, WidgetRef ref, FastingSpan span) async {
    final l = L10n.of(context);
    final tx = BodyTexts.of(context);
    final row = await ref.read(repositoriesProvider).fastingSessions.byId(span.id);
    if (row == null) return;
    final now = ref.read(bodyClockProvider)();
    final undo = await ref.read(bodyServiceProvider).stopFast(row, at: now);
    final reached = span.reached(now);
    Fx.fire(reached ? Sfx.levelUp : Sfx.toggleOff);
    if (!context.mounted) return;
    if (reached) _celebrate(context, BodyPalette.of(context).fasting, kind: CelebrationKind.lanternSparks);
    await showUndoToast(context, _undo(l.bodyFastEnded(tx.duration(span.duration(now))), undo));
  }

  static Future<void> editFast(BuildContext context, WidgetRef ref, String fastId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).fastingSessions.byId(fastId);
    if (row == null || !context.mounted) return;
    final now = ref.read(bodyClockProvider)();
    String hhmm(DateTime d) => BodyTimes.format(d.hour * 60 + d.minute);
    DateTime? combine(Object? day, Object? time) {
      final m = BodyTimes.parse(time as String?);
      if (day is! DateTime || m == null) return null;
      return DateTime(day.year, day.month, day.day, 0, m);
    }

    final end = row.end;
    final v = await showEditSheet(
      context,
      title: l.bodyFastEditTitle,
      icon: Icons.nights_stay_rounded,
      saveLabel: l.bodySave,
      initial: {
        'startDay': BodyDays.of(row.start),
        'startTime': hhmm(row.start),
        if (end != null) 'endDay': BodyDays.of(end),
        if (end != null) 'endTime': hhmm(end),
        'goal': row.targetHours,
        'note': row.note ?? '',
      },
      fields: [
        FieldSpec.date('startDay', l.bodyFastStartDate, required: true, lastDate: now),
        FieldSpec.time(
          'startTime',
          l.bodyFastStartTime,
          required: true,
          validator: (value, all) {
            final s = combine(all['startDay'], value);
            return s != null && s.isAfter(now) ? l.bodyFastInFuture : null;
          },
        ),
        if (end != null) FieldSpec.date('endDay', l.bodyFastEndDate, required: true, lastDate: now),
        if (end != null)
          FieldSpec.time(
            'endTime',
            l.bodyFastEndTime,
            required: true,
            validator: (value, all) {
              final s = combine(all['startDay'], all['startTime']);
              final e = combine(all['endDay'], value);
              if (s == null || e == null) return null;
              if (e.isBefore(s)) return l.bodyFastEndBeforeStart;
              return e.isAfter(now) ? l.bodyFastInFuture : null;
            },
          ),
        FieldSpec.number(
          'goal',
          l.bodyFastGoalHours,
          required: true,
          min: FastingPlan.minHours,
          max: FastingPlan.maxHours,
          decimals: 1,
          step: 0.5,
          unit: l.bodyUnitHours,
        ),
        FieldSpec.multiline('note', l.bodyFastNote, hint: l.bodyFastNoteHint, maxLength: 200),
      ],
    );
    if (v == null) return;
    final start = combine(v['startDay'], v['startTime']);
    if (start == null) return;
    final newEnd = end == null ? null : combine(v['endDay'], v['endTime']);
    final undo = await ref
        .read(bodyServiceProvider)
        .editFast(
          row,
          start: start,
          end: newEnd,
          targetHours: (v['goal'] as num?)?.toDouble() ?? row.targetHours,
          note: v['note'] as String?,
        );
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.bodyFastUpdated, undo));
  }

  static Future<UndoableAction?> deleteFast(BuildContext context, WidgetRef ref, String fastId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).fastingSessions.byId(fastId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).deleteFast(row);
    return _undo(l.bodyFastDeleted, undo);
  }

  static Future<void> updatePlan(BuildContext context, WidgetRef ref, FastingPlan Function(FastingPlan) change) async {
    final current = ref.read(bodyFastingPlanProvider).value ?? const FastingPlan();
    final next = change(current);
    if (next == current) return;
    await ref.read(bodyServiceProvider).setFastingPlan(next);
    // A notification just switched on: ask for the permission if missing.
    if ((next.notifyGoal && !current.notifyGoal) || (next.notifyEatingClose && !current.notifyEatingClose)) {
      unawaited(ref.read(bodyReminderSchedulerProvider).ensurePermission().catchError((_) => false));
    }
  }

  static Future<void> customFastHours(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final plan = ref.read(bodyFastingPlanProvider).value ?? const FastingPlan();
    final v = await showEditSheet(
      context,
      title: l.bodyFastCustomTitle,
      subtitle: l.bodyFastCustomHint,
      icon: Icons.hourglass_bottom_rounded,
      saveLabel: l.bodySave,
      initial: {'hours': plan.targetHours},
      fields: [
        FieldSpec.number(
          'hours',
          l.bodyFastHours,
          required: true,
          min: FastingPlan.minHours,
          max: FastingPlan.maxHours,
          decimals: 1,
          step: 0.5,
          unit: l.bodyUnitHours,
          icon: Icons.hourglass_bottom_rounded,
        ),
      ],
    );
    final hours = (v?['hours'] as num?)?.toDouble();
    if (hours == null || !context.mounted) return;
    await updatePlan(context, ref, (p) => p.copyWith(targetHours: hours));
  }

  static Future<void> pickLastMeal(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final plan = ref.read(bodyFastingPlanProvider).value ?? const FastingPlan();
    final v = await showEditSheet(
      context,
      title: l.bodyLastMeal,
      subtitle: l.bodyLastMealHint,
      icon: Icons.restaurant_rounded,
      saveLabel: l.bodySave,
      initial: {'time': BodyTimes.format(plan.lastMealMinutes)},
      fields: [FieldSpec.time('time', l.bodyLastMeal, required: true, icon: Icons.schedule_rounded)],
    );
    final m = BodyTimes.parse(v?['time'] as String?);
    if (m == null || !context.mounted) return;
    await updatePlan(context, ref, (p) => p.copyWith(lastMealMinutes: m));
  }

  // ----------------------------------------------------------- water ----

  /// Adds [ml] now, with an undo toast; a burst when it reaches the target.
  static Future<void> addWater(BuildContext context, WidgetRef ref, int ml) async {
    final tx = BodyTexts.of(context);
    final target = ref.read(bodyWaterTargetProvider);
    final before = ref.read(bodyWaterTodayProvider);
    final (_, undo) = await ref.read(bodyServiceProvider).addWater(ml);
    final crossed = before < target && before + ml >= target;
    Fx.fire(crossed ? Sfx.levelUp : Sfx.sparkle);
    if (!context.mounted) return;
    if (crossed) _celebrate(context, BodyPalette.of(context).water, kind: CelebrationKind.lightRain);
    await showUndoToast(context, _undo(tx.l.bodyWaterAdded(tx.ml(ml)), undo));
  }

  static Future<void> customWater(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.bodyWaterCustomTitle,
      icon: Icons.water_drop_rounded,
      saveLabel: l.bodySave,
      initial: const {'ml': 330},
      fields: [
        FieldSpec.number(
          'ml',
          l.bodyWaterAmount,
          required: true,
          min: WaterMath.minAmount,
          max: WaterMath.maxAmount,
          step: 50,
          unit: l.bodyUnitMl,
          icon: Icons.water_drop_outlined,
        ),
      ],
    );
    final ml = (v?['ml'] as num?)?.round();
    if (ml == null || !context.mounted) return;
    await addWater(context, ref, ml);
  }

  static Future<void> editWaterTarget(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final tx = BodyTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.bodyWaterTargetTitle,
      icon: Icons.flag_rounded,
      saveLabel: l.bodySave,
      initial: {'ml': ref.read(bodyWaterTargetProvider)},
      fields: [
        FieldSpec.number(
          'ml',
          l.bodyWaterTarget,
          required: true,
          min: WaterMath.minTarget,
          max: WaterMath.maxTarget,
          step: 250,
          unit: l.bodyUnitMl,
          icon: Icons.flag_outlined,
        ),
      ],
    );
    final ml = (v?['ml'] as num?)?.round();
    if (ml == null) return;
    final undo = await ref.read(bodyServiceProvider).setWaterTarget(ml);
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.bodyWaterTargetSaved(tx.ml(ml)), undo));
  }

  static Future<void> editWater(BuildContext context, WidgetRef ref, WaterLogRow row) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.bodyWaterEditTitle,
      icon: Icons.water_drop_rounded,
      saveLabel: l.bodySave,
      initial: {'ml': row.ml, 'time': BodyTimes.format(row.at.hour * 60 + row.at.minute)},
      fields: [
        FieldSpec.number(
          'ml',
          l.bodyWaterAmount,
          required: true,
          min: WaterMath.minAmount,
          max: WaterMath.maxAmount,
          step: 50,
          unit: l.bodyUnitMl,
        ),
        FieldSpec.time('time', l.bodyLogWhen, required: true),
      ],
    );
    if (v == null) return;
    final ml = (v['ml'] as num?)?.round() ?? row.ml;
    final m = BodyTimes.parse(v['time'] as String?);
    final at = m == null ? row.at : DateTime(row.at.year, row.at.month, row.at.day, 0, m);
    final undo = await ref.read(bodyServiceProvider).updateWater(row, ml: ml, at: at);
    if (context.mounted) await showUndoToast(context, _undo(l.bodyWaterUpdated, undo));
  }

  static Future<UndoableAction?> deleteWater(BuildContext context, WidgetRef ref, WaterLogRow row) async {
    final tx = BodyTexts.of(context);
    final undo = await ref.read(bodyServiceProvider).deleteWater(row);
    return _undo(tx.l.bodyWaterRemoved(tx.ml(row.ml)), undo);
  }

  // --------------------------------------------------------- helpers ----

  static Future<DateTime?> _pickMoment(
    BuildContext context, {
    required String title,
    required DateTime initial,
    required DateTime now,
    required L10n l,
  }) async {
    DateTime? combine(Object? day, Object? time) {
      final m = BodyTimes.parse(time as String?);
      if (day is! DateTime || m == null) return null;
      return DateTime(day.year, day.month, day.day, 0, m);
    }

    final v = await showEditSheet(
      context,
      title: title,
      icon: Icons.history_rounded,
      saveLabel: l.bodyStartFast,
      initial: {'day': BodyDays.of(initial), 'time': BodyTimes.format(initial.hour * 60 + initial.minute)},
      fields: [
        FieldSpec.date('day', l.bodyFastStartDate, required: true, firstDate: BodyDays.add(now, -3), lastDate: now),
        FieldSpec.time(
          'time',
          l.bodyFastStartTime,
          required: true,
          validator: (value, all) {
            final s = combine(all['day'], value);
            return s != null && s.isAfter(now) ? l.bodyFastInFuture : null;
          },
        ),
      ],
    );
    if (v == null) return null;
    return combine(v['day'], v['time']);
  }

  /// A burst in the upper third of the screen (a soft bloom under reduced
  /// motion – the overlay decides).
  static void _celebrate(BuildContext context, Color color, {CelebrationKind kind = CelebrationKind.stardust}) {
    final size = MediaQuery.sizeOf(context);
    Celebrate.burst(context, Offset(size.width / 2, size.height * 0.32), kind: kind, color: color);
  }
}

/// Bottom padding every Body tab leaves for the floating button.
const double bodyTabBottomPadding = 112;
