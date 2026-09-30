import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../orbit/data/orbit_providers.dart';
import '../domain/body_map.dart';
import '../domain/habit_streaks.dart';
import '../domain/insights.dart';
import '../domain/support_rule.dart';
import '../domain/wellbeing_data.dart';
import '../domain/wellbeing_settings.dart';
import '../domain/wellbeing_stats.dart';
import '../domain/worry_window.dart';
import 'phone_dialer.dart';
import 'wellbeing_service.dart';
import 'worry_reminders.dart';

// ------------------------------------------------------------- basics ----

/// The wellbeing wall clock (follows the orbit's, so tests freeze both).
final wellbeingClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final wellbeingTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// "Now", refreshed every 30 s (the worry window's open / closed state).
final wellbeingNowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(wellbeingClockProvider);
  ref.watch(wellbeingTodayProvider);
  final controller = StreamController<DateTime>();
  controller.add(clock());
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => controller.add(clock()));
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Completions on the Health planet go through the orbit's pulse hub (the
/// world flares). Tests may override it with null (plain activity rows).
final wellbeingActivityRecorderProvider = Provider<WellbeingActivityRecorder?>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (kind, table, id, {value, payload = const {}}) =>
      hub.recordCompletion(WellbeingService.planetKey, kind, table, id, value: value, payload: payload);
});

final wellbeingServiceProvider = Provider<WellbeingService>(
  (ref) => WellbeingService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(wellbeingClockProvider),
    recorder: ref.watch(wellbeingActivityRecorderProvider),
  ),
);

/// Opens the dialer for the support number (url_launcher `tel:`).
final phoneDialerProvider = Provider<PhoneDialer>((ref) => const UrlLauncherPhoneDialer());

// -------------------------------------------------------------- streams ----

final painEntriesProvider = StreamProvider<List<PainEntryRow>>(
  (ref) => ref.watch(wellbeingServiceProvider).watchPain(),
);

final moodEntriesProvider = StreamProvider<List<MoodEntryRow>>(
  (ref) => ref.watch(wellbeingServiceProvider).watchMood(),
);

final wellbeingTagsProvider = StreamProvider.family<List<TagOptionRow>, TagKind>(
  (ref, kind) => ref.watch(wellbeingServiceProvider).watchTags(kind),
);

final wellbeingHabitsProvider = StreamProvider<List<HabitRow>>(
  (ref) => ref.watch(wellbeingServiceProvider).watchHabits(),
);

/// Habit logs of the last 400 days (streaks and the 7-day strip).
final wellbeingHabitLogsProvider = StreamProvider<List<HabitLogRow>>((ref) {
  final today = ref.watch(wellbeingTodayProvider);
  return ref.watch(wellbeingServiceProvider).watchHabitLogs(since: WbDays.add(today, -400));
});

final worriesProvider = StreamProvider<List<WorryRow>>((ref) => ref.watch(wellbeingServiceProvider).watchWorries());

final wellbeingSettingsProvider = StreamProvider<WellbeingSettings>(
  (ref) => ref.watch(wellbeingServiceProvider).watchSettings(),
);

// -------------------------------------------------------------- derived ----

PainSample painSampleOf(PainEntryRow r) => PainSample(
  at: r.at,
  score: r.score,
  locations: r.locations,
  triggers: r.triggers,
  points: BodyPoint.listFrom(r.bodyPoints),
);

MoodSample moodSampleOf(MoodEntryRow r) => MoodSample(
  at: r.at,
  mood: r.mood,
  stress: r.stress,
  anxiety: r.anxiety,
  energy: r.energy,
  sleepHours: r.sleepHours,
  caffeineCups: r.caffeineCups,
  factors: r.factors,
);

final painSamplesProvider = Provider<List<PainSample>>(
  (ref) => [for (final r in ref.watch(painEntriesProvider).value ?? const <PainEntryRow>[]) painSampleOf(r)],
);

final moodSamplesProvider = Provider<List<MoodSample>>(
  (ref) => [for (final r in ref.watch(moodEntriesProvider).value ?? const <MoodEntryRow>[]) moodSampleOf(r)],
);

/// Pain over the last N days (14, 30 or 90).
final painSummaryProvider = Provider.family<PainSummary, int>(
  (ref, days) =>
      WellbeingStats.pain(ref.watch(painSamplesProvider), today: ref.watch(wellbeingTodayProvider), days: days),
);

/// One metric's daily values over the last N days.
final wellbeingSeriesProvider = Provider.family<List<MetricPoint>, (WellMetric, int)>((ref, arg) {
  final (metric, days) = arg;
  return WellbeingStats.series(
    ref.watch(moodSamplesProvider),
    metric,
    today: ref.watch(wellbeingTodayProvider),
    days: days,
    pains: metric == WellMetric.pain ? ref.watch(painSamplesProvider) : const [],
  );
});

final moodFactorCountsProvider = Provider.family<List<(String, int)>, int>(
  (ref, days) =>
      WellbeingStats.factorCounts(ref.watch(moodSamplesProvider), today: ref.watch(wellbeingTodayProvider), days: days),
);

/// Local observations (see [InsightEngine] for the rules).
final wellbeingInsightsProvider = Provider<List<WellbeingInsight>>(
  (ref) => InsightEngine.compute(
    moods: ref.watch(moodSamplesProvider),
    pains: ref.watch(painSamplesProvider),
    today: ref.watch(wellbeingTodayProvider),
  ),
);

final insightReadinessProvider = Provider<InsightReadiness>(
  (ref) => InsightEngine.readiness(
    moods: ref.watch(moodSamplesProvider),
    pains: ref.watch(painSamplesProvider),
    today: ref.watch(wellbeingTodayProvider),
  ),
);

/// Whether the gentle support banner shows (see [SupportRule]).
final supportStateProvider = Provider<SupportState>((ref) {
  final entries = ref.watch(moodEntriesProvider).value;
  final settings = ref.watch(wellbeingSettingsProvider).value;
  if (entries == null || settings == null) return SupportState.none;
  return SupportRule.evaluate(
    [for (final e in entries) (e.at, e.mood)],
    now: ref.watch(wellbeingClockProvider)(),
    dismissedUntil: settings.supportDismissedUntil,
  );
});

/// Today's latest check-in (null before the first one).
final todayCheckInProvider = Provider<MoodEntryRow?>((ref) {
  final today = ref.watch(wellbeingTodayProvider);
  for (final e in ref.watch(moodEntriesProvider).value ?? const <MoodEntryRow>[]) {
    if (WbDays.dateOf(e.at) == today) return e;
  }
  return null;
});

/// Today's pain logs, newest first.
final todayPainProvider = Provider<List<PainEntryRow>>((ref) {
  final today = ref.watch(wellbeingTodayProvider);
  return [
    for (final e in ref.watch(painEntriesProvider).value ?? const <PainEntryRow>[])
      if (WbDays.dateOf(e.at) == today) e,
  ];
});

/// Every checklist habit's progress by id.
final habitProgressProvider = Provider<Map<String, HabitProgress>>((ref) {
  final today = ref.watch(wellbeingTodayProvider);
  final habits = ref.watch(wellbeingHabitsProvider).value ?? const <HabitRow>[];
  final logs = ref.watch(wellbeingHabitLogsProvider).value ?? const <HabitLogRow>[];
  final days = <String, Set<String>>{};
  for (final l in logs) {
    if (l.done) (days[l.habitId] ??= {}).add(l.day);
  }
  return {for (final h in habits) h.id: HabitStreaks.of(days[h.id] ?? const {}, today: today)};
});

/// Active checklist habits, and how many are done today.
final habitTodayCountProvider = Provider<({int done, int total})>((ref) {
  final habits = [
    for (final h in ref.watch(wellbeingHabitsProvider).value ?? const <HabitRow>[])
      if (h.active) h,
  ];
  final progress = ref.watch(habitProgressProvider);
  return (done: habits.where((h) => progress[h.id]?.doneToday ?? false).length, total: habits.length);
});

/// The worry window's state now.
final worryWindowStatusProvider = Provider<WorryWindowStatus>((ref) {
  final settings = ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings();
  final now = ref.watch(wellbeingNowProvider).value ?? ref.watch(wellbeingClockProvider)();
  return WorryWindow.statusAt(settings.worry, now);
});

/// Parked (unresolved) worries in the user's order.
final parkedWorriesProvider = Provider<List<WorryRow>>(
  (ref) => [
    for (final w in ref.watch(worriesProvider).value ?? const <WorryRow>[])
      if (!w.resolved) w,
  ],
);

// ----------------------------------------------------------- reminders ----

(L10n, MadarFormatter) wellbeingTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

final wellbeingNotificationSchedulerProvider = Provider<WorryReminderScheduler>(
  (ref) => NotificationWorryReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = wellbeingTextsOf(ref);
      return (group: l.wbNotifyGroup, name: l.wbNotifyChannel, description: l.wbNotifyChannelDescription);
    },
  ),
);

/// Delivers worry-window notifications; tests override it with
/// [RecordingWorryReminderScheduler].
final worryReminderSchedulerProvider = Provider<WorryReminderScheduler>(
  (ref) => ref.watch(wellbeingNotificationSchedulerProvider),
);

/// Keeps the worry-window notifications planned (next 7 days) whenever the
/// settings, the parked worries, the language or the day change. Watch it
/// once from the app root; its state is the last plan.
final worryReminderSyncProvider = NotifierProvider<WorryReminderSync, List<WorryNotice>?>(WorryReminderSync.new);

class WorryReminderSync extends Notifier<List<WorryNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<WorryNotice>? build() {
    ref.listen(wellbeingSettingsProvider, (_, _) => _schedule());
    ref.listen(parkedWorriesProvider.select((w) => w.length), (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(wellbeingTodayProvider, (_, _) => _schedule());
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
    final settings = ref.read(wellbeingSettingsProvider).value;
    if (settings == null || ref.read(worriesProvider).value == null) return;
    _running = true;
    try {
      await initializeDateFormatting();
      final (l, fmt) = wellbeingTextsOf(ref);
      final parked = ref.read(parkedWorriesProvider).length;
      final notices = WorryReminderPlanner.plan(
        settings: settings.worry,
        now: ref.read(wellbeingClockProvider)(),
        title: l.wbWorryNotifyTitle,
        body: (_) => parked == 0
            ? l.wbWorryNotifyBodyEmpty
            : fmt.localizeDigits(l.wbWorryNotifyBody(parked, fmt.formatInt(parked))),
      );
      await ref.read(worryReminderSchedulerProvider).replaceAll(notices);
      state = notices;
    } catch (e) {
      debugPrint('worry window reminders: $e');
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
