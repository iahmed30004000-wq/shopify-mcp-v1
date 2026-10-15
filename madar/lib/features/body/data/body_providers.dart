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
import '../domain/gym.dart';
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

/// The sets of those logs, in the order he did them.
final bodyWorkoutSetRowsProvider = StreamProvider<List<WorkoutSetRow>>((ref) {
  final today = ref.watch(bodyTodayProvider);
  return ref.watch(bodyServiceProvider).watchSets(since: DateTime(today.year, today.month, today.day - 400));
});

/// His named training days, in his order.
final bodyTemplateRowsProvider = StreamProvider<List<WorkoutTemplateRow>>(
  (ref) => ref.watch(bodyServiceProvider).watchTemplates(),
);

final bodyTemplateItemRowsProvider = StreamProvider<List<WorkoutTemplateItemRow>>(
  (ref) => ref.watch(bodyServiceProvider).watchTemplateItems(),
);

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
  photo: r.photo,
  video: r.video,
  muscles: r.muscles,
  restSec: r.restSec,
  warmupSets: r.warmupSets,
);

LoggedSet loggedSetOf(WorkoutSetRow r) => LoggedSet(id: r.id, reps: r.reps, weight: r.weight, warmup: r.warmup);

TemplateExercise templateItemOf(WorkoutTemplateItemRow r) => TemplateExercise(
  id: r.id,
  exerciseId: r.exerciseId,
  sets: r.sets,
  reps: r.reps,
  weight: r.weight,
  restSec: r.restSec,
  warmupSets: r.warmupSets,
);

WorkoutEntry workoutOf(WorkoutLogRow r, {List<LoggedSet> setLog = const []}) => WorkoutEntry(
  id: r.id,
  exerciseId: r.exerciseId,
  name: r.name,
  at: r.at,
  sets: r.sets,
  reps: r.reps,
  weight: r.weight,
  durationMin: r.durationMin,
  notes: r.notes,
  setLog: setLog,
);

FastingSpan fastOf(FastingSessionRow r) =>
    FastingSpan(id: r.id, start: r.start, end: r.end, targetHours: r.targetHours, note: r.note);

WaterEntry waterOf(WaterLogRow r) => WaterEntry(id: r.id, at: r.at, ml: r.ml);

// -------------------------------------------------------------- derived ----

final bodyExercisesProvider = Provider<List<PlannedExercise>>(
  (ref) => [for (final r in ref.watch(bodyExerciseRowsProvider).value ?? const <ExerciseRow>[]) plannedOf(r)],
);

/// Every logged workout with its own sets attached.
final bodyWorkoutsProvider = Provider<List<WorkoutEntry>>((ref) {
  final sets = <String, List<LoggedSet>>{};
  for (final r in ref.watch(bodyWorkoutSetRowsProvider).value ?? const <WorkoutSetRow>[]) {
    (sets[r.logId] ??= []).add(loggedSetOf(r));
  }
  return [
    for (final r in ref.watch(bodyWorkoutRowsProvider).value ?? const <WorkoutLogRow>[])
      workoutOf(r, setLog: sets[r.id] ?? const []),
  ];
});

/// His named training days with their exercises, in his order.
final bodyTemplatesProvider = Provider<List<WorkoutTemplate>>((ref) {
  final items = <String, List<TemplateExercise>>{};
  for (final r in ref.watch(bodyTemplateItemRowsProvider).value ?? const <WorkoutTemplateItemRow>[]) {
    (items[r.templateId] ??= []).add(templateItemOf(r));
  }
  return [
    for (final r in ref.watch(bodyTemplateRowsProvider).value ?? const <WorkoutTemplateRow>[])
      WorkoutTemplate(
        id: r.id,
        name: r.name,
        weekdays: r.weekdays,
        notes: r.notes,
        active: r.active,
        items: items[r.id] ?? const [],
      ),
  ];
});

/// What a day asks for: its templates' exercises in his order, then
/// anything scheduled on that weekday which no template of the day named.
/// Without a single template this is exactly the old plan.
final bodyDayPlanProvider = Provider<List<PlannedExercise> Function(DateTime day)>((ref) {
  final exercises = ref.watch(bodyExercisesProvider);
  final templates = ref.watch(bodyTemplatesProvider);
  if (templates.every((t) => !t.active || t.items.isEmpty)) {
    return (day) => [
      for (final e in exercises)
        if (e.trainsOn(day)) e,
    ];
  }
  return (day) => SessionPlan.forDay(exercises: exercises, templates: templates, day: day);
});

/// Today's session: the plan for today's weekday and what was logged.
final bodyTrainingTodayProvider = Provider<TrainingDay>(
  (ref) => TrainingDay.build(
    exercises: ref.watch(bodyExercisesProvider),
    logs: ref.watch(bodyWorkoutsProvider),
    day: ref.watch(bodyTodayProvider),
    clock: ref.watch(bodyWallClockProvider),
    planFor: ref.watch(bodyDayPlanProvider),
  ),
);

/// The templates that train today, in his order.
final bodyTemplatesTodayProvider = Provider<List<WorkoutTemplate>>(
  (ref) => SessionPlan.templatesOn(ref.watch(bodyTemplatesProvider), ref.watch(bodyTodayProvider)),
);

/// This display week's planned vs done sessions.
final bodyWeekAdherenceProvider = Provider<WeekAdherence>(
  (ref) => WeekAdherence.of(
    exercises: ref.watch(bodyExercisesProvider),
    logs: ref.watch(bodyWorkoutsProvider),
    today: ref.watch(bodyTodayProvider),
    weekStart: ref.watch(bodyWeekStartProvider),
    clock: ref.watch(bodyWallClockProvider),
    planFor: ref.watch(bodyDayPlanProvider),
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

/// The numbers of his next session of one exercise, read off his own log
/// (`NextLoad` – arithmetic, never advice).
final bodyNextLoadProvider = Provider.family<NextLoad, String>(
  (ref, exerciseId) => NextLoad.of(
    ref.watch(bodyExerciseProgressProvider(exerciseId)),
    clock: ref.watch(bodyWallClockProvider),
  ),
);

/// One exercise of the library, watched by id (the exercise screen).
final bodyExerciseProvider = Provider.family<PlannedExercise?, String>(
  (ref, id) => ref.watch(bodyExercisesProvider.select((l) => l.where((e) => e.id == id).firstOrNull)),
);

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
      // The app may have locked or reset meanwhile (the notifier is gone).
      if (ref.mounted) state = notices;
    } catch (e) {
      debugPrint('body reminders: $e');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
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
