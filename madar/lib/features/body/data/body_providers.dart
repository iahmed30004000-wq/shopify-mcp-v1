import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/body_clock.dart';
import '../domain/body_reminder_plan.dart';
import '../domain/body_week.dart';
import '../domain/fasting.dart';
import '../domain/training.dart';
import '../domain/water.dart';
import 'body_reminders.dart';
import 'body_service.dart';

// ------------------------------------------------------------- basics ----

/// The Body wall clock (follows the orbit's and home's, so tests freeze all
/// three at once).
final bodyClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final bodyTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Wall times ↔ instants (tests inject a zone with a DST change).
final bodyWallClockProvider = Provider<BodyWallClock>((ref) => const LocalBodyWallClock());

/// First day of the displayed week: Saturday in Arabic, Sunday in English.
final bodyWeekStartProvider = Provider<int>(
  (ref) => BodyWeek.startFor(ref.watch(appSettingsProvider.select((s) => s.languageCode))),
);

/// Completions on the Body planet go through the orbit's pulse hub (the
/// planet flares). Tests may override it with null (plain activity rows).
final bodyActivityRecorderProvider = Provider<BodyActivityRecorder?>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (kind, table, id, {at, value, payload = const {}}) =>
      hub.recordCompletion(BodyService.planetKey, kind, table, id, at: at, value: value, payload: payload);
});

final bodyServiceProvider = Provider<BodyService>(
  (ref) => BodyService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(bodyClockProvider),
    recorder: ref.watch(bodyActivityRecorderProvider),
  ),
);

// -------------------------------------------------------------- streams ----

final bodyExerciseRowsProvider = StreamProvider<List<ExerciseRow>>(
  (ref) => ref.watch(bodyServiceProvider).watchExercises(),
);

/// Workout logs of the last 400 days (today's session, the week, history).
final bodyWorkoutRowsProvider = StreamProvider<List<WorkoutLogRow>>((ref) {
  final today = ref.watch(bodyTodayProvider);
  return ref.watch(bodyServiceProvider).watchWorkouts(since: DateTime(today.year, today.month, today.day - 400));
});

final bodyAvoidRowsProvider = StreamProvider<List<AvoidItemRow>>((ref) => ref.watch(bodyServiceProvider).watchAvoid());

final bodyFastRowsProvider = StreamProvider<List<FastingSessionRow>>(
  (ref) => ref.watch(bodyServiceProvider).watchFasts(),
);

final bodyFastingPlanProvider = StreamProvider<FastingPlan>((ref) => ref.watch(bodyServiceProvider).watchFastingPlan());

/// Water logs of the last 31 days.
final bodyWaterRowsProvider = StreamProvider<List<WaterLogRow>>((ref) {
  final today = ref.watch(bodyTodayProvider);
  return ref.watch(bodyServiceProvider).watchWater(since: DateTime(today.year, today.month, today.day - 31));
});

/// The stored water target (null until the user sets one).
final bodyStoredWaterTargetProvider = StreamProvider<int?>((ref) => ref.watch(bodyServiceProvider).watchWaterTarget());

// -------------------------------------------------------------- mapping ----

PlannedExercise plannedOf(ExerciseRow r) => PlannedExercise(
  id: r.id,
  name: r.name,
  weekdays: r.weekdays,
  sets: r.sets,
  reps: r.reps,
  durationMin: r.durationMin,
  weight: r.weight,
  notes: r.notes,
  active: r.active,
);

WorkoutEntry workoutOf(WorkoutLogRow r) => WorkoutEntry(
  id: r.id,
  exerciseId: r.exerciseId,
  name: r.name,
  at: r.at,
  sets: r.sets,
  reps: r.reps,
  weight: r.weight,
  durationMin: r.durationMin,
  notes: r.notes,
);

FastingSpan fastOf(FastingSessionRow r) =>
    FastingSpan(id: r.id, start: r.start, end: r.end, targetHours: r.targetHours, note: r.note);

WaterEntry waterOf(WaterLogRow r) => WaterEntry(id: r.id, at: r.at, ml: r.ml);

// -------------------------------------------------------------- derived ----

final bodyExercisesProvider = Provider<List<PlannedExercise>>(
  (ref) => [for (final r in ref.watch(bodyExerciseRowsProvider).value ?? const <ExerciseRow>[]) plannedOf(r)],
);

final bodyWorkoutsProvider = Provider<List<WorkoutEntry>>(
  (ref) => [for (final r in ref.watch(bodyWorkoutRowsProvider).value ?? const <WorkoutLogRow>[]) workoutOf(r)],
);

/// Today's session: the plan for today's weekday and what was logged.
final bodyTrainingTodayProvider = Provider<TrainingDay>(
  (ref) => TrainingDay.build(
    exercises: ref.watch(bodyExercisesProvider),
    logs: ref.watch(bodyWorkoutsProvider),
    day: ref.watch(bodyTodayProvider),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

/// This display week's planned vs done sessions.
final bodyWeekAdherenceProvider = Provider<WeekAdherence>(
  (ref) => WeekAdherence.of(
    exercises: ref.watch(bodyExercisesProvider),
    logs: ref.watch(bodyWorkoutsProvider),
    today: ref.watch(bodyTodayProvider),
    weekStart: ref.watch(bodyWeekStartProvider),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

/// One exercise's history and progress series.
final bodyExerciseProgressProvider = Provider.family<ExerciseProgress, String>((ref, exerciseId) {
  final exercise = ref.watch(bodyExercisesProvider.select((l) => l.where((e) => e.id == exerciseId).firstOrNull));
  if (exercise == null) return ExerciseProgress.empty;
  return ExerciseProgress.build(
    ref.watch(bodyWorkoutsProvider).where((l) => l.isOf(exercise)),
    clock: ref.watch(bodyWallClockProvider),
  );
});

final bodyFastsProvider = Provider<List<FastingSpan>>(
  (ref) => [for (final r in ref.watch(bodyFastRowsProvider).value ?? const <FastingSessionRow>[]) fastOf(r)],
);

/// The running fast, if any (the latest one without an end).
final bodyActiveFastProvider = Provider<FastingSpan?>(
  (ref) => ref.watch(bodyFastsProvider).where((f) => f.active).firstOrNull,
);

/// When the last finished fast ended.
final bodyLastFastEndProvider = Provider<DateTime?>((ref) {
  DateTime? last;
  for (final f in ref.watch(bodyFastsProvider)) {
    final e = f.end;
    if (e != null && (last == null || e.isAfter(last))) last = e;
  }
  return last;
});

final bodyFastingStatsProvider = Provider<FastingStats>((ref) {
  ref.watch(bodyTodayProvider);
  return FastingStats.of(
    ref.watch(bodyFastsProvider),
    now: ref.watch(bodyClockProvider)(),
    clock: ref.watch(bodyWallClockProvider),
  );
});

final bodyWaterEntriesProvider = Provider<List<WaterEntry>>(
  (ref) => [for (final r in ref.watch(bodyWaterRowsProvider).value ?? const <WaterLogRow>[]) waterOf(r)],
);

/// The effective daily target (the default until the user sets one).
final bodyWaterTargetProvider = Provider<int>(
  (ref) => WaterMath.targetOf(ref.watch(bodyStoredWaterTargetProvider).value),
);

/// Today's water rows, newest first.
final bodyWaterTodayRowsProvider = Provider<List<WaterLogRow>>((ref) {
  final today = ref.watch(bodyTodayProvider);
  final clock = ref.watch(bodyWallClockProvider);
  return [
    for (final r in ref.watch(bodyWaterRowsProvider).value ?? const <WaterLogRow>[])
      if (BodyDays.same(clock.dayOf(r.at), today)) r,
  ];
});

final bodyWaterTodayProvider = Provider<int>(
  (ref) => WaterMath.totalOn(
    ref.watch(bodyWaterEntriesProvider),
    ref.watch(bodyTodayProvider),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

final bodyWaterWeekProvider = Provider<List<({DateTime day, int ml})>>(
  (ref) => WaterMath.lastDays(
    ref.watch(bodyWaterEntriesProvider),
    ref.watch(bodyTodayProvider),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

final bodyWaterStreakProvider = Provider<int>(
  (ref) => WaterMath.streak(
    ref.watch(bodyWaterEntriesProvider),
    ref.watch(bodyTodayProvider),
    ref.watch(bodyWaterTargetProvider),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

// ----------------------------------------------------------- reminders ----

(L10n, MadarFormatter) bodyTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

final bodyNotificationSchedulerProvider = Provider<BodyReminderScheduler>(
  (ref) => NotificationBodyReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = bodyTextsOf(ref);
      return (group: l.bodyNotifyGroup, name: l.bodyNotifyChannel, description: l.bodyNotifyChannelDescription);
    },
  ),
);

/// Delivers the fasting notifications; tests override it with
/// [RecordingBodyReminderScheduler].
final bodyReminderSchedulerProvider = Provider<BodyReminderScheduler>(
  (ref) => ref.watch(bodyNotificationSchedulerProvider),
);

/// Keeps the fasting notifications planned whenever the plan, the running
/// fast, the language or the day change. Watch it once from the app root
/// (BodyScreen watches it too); its state is the last plan.
final bodyReminderSyncProvider = NotifierProvider<BodyReminderSync, List<BodyNotice>?>(BodyReminderSync.new);

class BodyReminderSync extends Notifier<List<BodyNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<BodyNotice>? build() {
    ref.listen(bodyFastingPlanProvider, (_, _) => _schedule());
    ref.listen(bodyActiveFastProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(bodyTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _run);
  }

  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    final plan = ref.read(bodyFastingPlanProvider).value;
    if (plan == null || ref.read(bodyFastRowsProvider).value == null) return;
    _running = true;
    try {
      await initializeDateFormatting();
      final (l, fmt) = bodyTextsOf(ref);
      final notices = BodyReminderPlanner.plan(
        plan: plan,
        now: ref.read(bodyClockProvider)(),
        active: ref.read(bodyActiveFastProvider),
        clock: ref.read(bodyWallClockProvider),
        goalTitle: l.bodyNotifyGoalTitle,
        goalBody: (f) => fmt.localizeDigits(l.bodyNotifyGoalBody(fmt.formatNumber(f.targetHours, maxDecimals: 1))),
        eatingTitle: l.bodyNotifyEatingTitle,
        eatingBody: (closes) => l.bodyNotifyEatingBody(fmt.formatTime(closes)),
      );
      await ref.read(bodyReminderSchedulerProvider).replaceAll(notices);
      state = notices;
    } catch (e) {
      debugPrint('body reminders: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Plans now (skips the debounce).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}
