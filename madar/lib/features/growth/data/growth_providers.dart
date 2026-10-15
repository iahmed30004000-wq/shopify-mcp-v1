import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/growth_goal.dart';
import 'growth_service.dart';

/// The Growth planet's wall clock (follows the orbit's, so tests freeze both).
final growthClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final growthTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Logs growth activity through the orbit's pulse hub, so the Growth planet
/// pulses the moment progress is logged.
final growthActivityRecorderProvider = Provider<GrowthActivityRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required kind, required refTable, required refId, required at, value, payload = const {}}) =>
      hub.recordCompletion(GrowthActivity.planetKey, kind, refTable, refId, at: at, value: value, payload: payload);
});

final growthServiceProvider = Provider<GrowthService>(
  (ref) => GrowthService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(growthClockProvider),
    recorder: ref.watch(growthActivityRecorderProvider),
  ),
);

final growthGoalRowsProvider = StreamProvider<List<LearningGoalRow>>(
  (ref) => ref.watch(growthServiceProvider).watchGoals(),
);

final growthLogRowsProvider = StreamProvider<List<GoalLogRow>>((ref) => ref.watch(growthServiceProvider).watchLogs());

/// Every goal with its stats today, in the user's order.
final growthOverviewProvider = Provider<AsyncValue<GrowthOverview>>((ref) {
  final rows = ref.watch(growthGoalRowsProvider);
  final logs = ref.watch(growthLogRowsProvider);
  final today = ref.watch(growthTodayProvider);
  for (final a in <AsyncValue<Object?>>[rows, logs]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  }
  final r = rows.value, l = logs.value;
  if (r == null || l == null) return const AsyncLoading();
  return AsyncData(GrowthOverview.of(r, l, today: today));
});

/// One goal (null once deleted).
final growthGoalProvider = Provider.family<AsyncValue<GrowthGoal?>, String>(
  (ref, id) => ref.watch(growthOverviewProvider).whenData((o) => o.byId(id)),
);

/// Opens a goal's page. Null (the default) pushes [GoalScreen] on the
/// nearest navigator; the app may route instead.
typedef GrowthOpenGoal = void Function(BuildContext context, String goalId);

final growthOpenGoalProvider = Provider<GrowthOpenGoal?>((ref) => null);
