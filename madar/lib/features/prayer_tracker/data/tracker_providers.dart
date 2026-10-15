import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show PrayerLogRow;
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../home/home_providers.dart' show homeNowProvider;
import '../../orbit/data/orbit_providers.dart' show orbitClockProvider, orbitPulseHubProvider, prayerScheduleProvider;
import '../domain/tracker_day.dart';
import '../domain/tracker_days.dart';
import '../domain/tracker_stats.dart';
import 'prayer_tracker_repository.dart';

/// Prayer log writes with undo (completions pulse the Faith world).
final prayerTrackerRepositoryProvider = Provider<PrayerTrackerRepository>(
  (ref) => PrayerTrackerRepository(
    ref.watch(repositoriesProvider),
    hub: ref.watch(orbitPulseHubProvider),
    clock: ref.watch(orbitClockProvider),
  ),
);

/// "Now" for the tracker: home's clock, which ticks every minute and at the
/// very start of each prayer window (so a prayer turns due on time).
/// Override with a fixed time in tests.
final trackerNowProvider = Provider.autoDispose<DateTime>((ref) => ref.watch(homeNowProvider));

/// The current prayer day (local midnight; the hours before Fajr still
/// belong to the day before).
final trackerTodayProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(prayerScheduleProvider).prayerDayOf(ref.watch(trackerNowProvider)),
);

/// The logs of one prayer day (local midnight).
final trackerDayLogsProvider = StreamProvider.autoDispose.family<List<PrayerLogRow>, DateTime>(
  (ref, day) => ref.watch(prayerTrackerRepositoryProvider).watchDay(day),
);

/// One prayer day with every tracked prayer, its window and its log.
final trackerDayProvider = Provider.autoDispose.family<AsyncValue<TrackerDayView>, DateTime>((ref, day) {
  final schedule = ref.watch(prayerScheduleProvider);
  final now = ref.watch(trackerNowProvider);
  return ref
      .watch(trackerDayLogsProvider(day))
      .whenData(
        (rows) => TrackerDayView.build(
          day: day,
          now: now,
          times: schedule.timesFor(day),
          nextDay: schedule.timesFor(TrackerDays.add(day, 1)),
          logs: rows,
        ),
      );
});

/// Today's prayer day as [TrackerDayView].
final trackerTodayViewProvider = Provider.autoDispose<AsyncValue<TrackerDayView>>(
  (ref) => ref.watch(trackerDayProvider(ref.watch(trackerTodayProvider))),
);

/// Every prayer log.
final trackerLogsProvider = StreamProvider.autoDispose<List<PrayerLogRow>>(
  (ref) => ref.watch(prayerTrackerRepositoryProvider).watchAll(),
);

/// Streaks, per-day summaries, totals and the qada ledger.
final trackerHistoryProvider = Provider.autoDispose<AsyncValue<TrackerHistory>>((ref) {
  final today = ref.watch(trackerTodayProvider);
  return ref.watch(trackerLogsProvider).whenData((rows) => TrackerHistory.of(rows, today: today));
});

/// The month the History heatmap shows (first day of the month).
final trackerMonthProvider = NotifierProvider.autoDispose<TrackerMonth, DateTime>(TrackerMonth.new);

class TrackerMonth extends Notifier<DateTime> {
  /// Follows the current month (a new day in a new month shows it).
  @override
  DateTime build() {
    final today = ref.watch(trackerTodayProvider);
    return DateTime(today.year, today.month);
  }

  /// Whether a later month can be shown (never beyond the current one).
  bool get canGoForward {
    final today = ref.read(trackerTodayProvider);
    return state.isBefore(DateTime(today.year, today.month));
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    if (canGoForward) state = DateTime(state.year, state.month + 1);
  }

  void show(DateTime month) => state = DateTime(month.year, month.month);
}

/// The prayer the qada ledger is filtered to (null = all).
final qadaFilterProvider = NotifierProvider.autoDispose<QadaFilter, Prayer?>(QadaFilter.new);

class QadaFilter extends Notifier<Prayer?> {
  @override
  Prayer? build() => null;

  void select(Prayer? prayer) => state = prayer;
}
