import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../home/home_providers.dart' show appForegroundProvider;
import '../../data/together_providers.dart';
import '../domain/coop_goal.dart';
import '../domain/know_me_bank.dart';
import '../domain/specials_bounds.dart';
import '../domain/specials_settings.dart';
import '../domain/weekly_challenge.dart';
import 'specials_repository.dart';

/// The couple specials' storage over the unlocked database.
final specialsRepositoryProvider = Provider<SpecialsRepository>(
  (ref) => SpecialsRepository(ref.watch(databaseProvider)),
);

final knowMeBankProvider = StreamProvider<KnowMeBank>((ref) => ref.watch(specialsRepositoryProvider).watchBank());

final knowMePrefsProvider = StreamProvider<KnowMePrefs>((ref) => ref.watch(specialsRepositoryProvider).watchPrefs());

final challengeListProvider = StreamProvider<ChallengeList>(
  (ref) => ref.watch(specialsRepositoryProvider).watchChallenges(),
);

final challengeLogProvider = StreamProvider<ChallengeLog>((ref) => ref.watch(specialsRepositoryProvider).watchLog());

final specialsSettingsProvider = StreamProvider<SpecialsSettings>(
  (ref) => ref.watch(specialsRepositoryProvider).watchSettings(),
);

final goalBoardProvider = StreamProvider<GoalBoard>((ref) => ref.watch(specialsRepositoryProvider).watchGoals());

/// Rebuilds [ref]'s provider when the app returns to the foreground (so a
/// "now" taken at build time is never stale: a new week, a lapsed streak).
void _refreshOnForeground(Ref ref) {
  final foreground = ref.watch(appForegroundProvider);
  var was = foreground.value;
  void listener() {
    final now = foreground.value;
    if (now && !was) ref.invalidateSelf();
    was = now;
  }

  foreground.addListener(listener);
  ref.onDispose(() => foreground.removeListener(listener));
}

/// This week's challenge at one moment.
final class WeeklyView {
  const WeeklyView({
    required this.now,
    required this.weekStart,
    required this.week,
    required this.list,
    required this.log,
    required this.challenge,
  });

  final DateTime now;

  /// ISO weekday the week starts on.
  final int weekStart;

  /// This week's first local day.
  final int week;
  final ChallengeList list;
  final ChallengeLog log;

  /// This week's challenge (null when nothing is in rotation – cannot
  /// happen through the UI).
  final Challenge? challenge;

  ChallengeWeek? get record => log.weekAt(week, weekStart);

  bool get pinned => record != null;

  int get streak => log.currentStreak(week, weekStart);

  int get daysLeft => SpecialWeeks.daysLeft(week, now);

  /// The day the next week starts (for "resets on …").
  DateTime get resetsOn => SpecialWeeks.dateOf(week + 7);

  bool get canSwap => !(record?.anyDone ?? false) && list.pool.length > 1;
}

/// [WeeklyView] of now (rebuilt on return to the foreground).
final weeklyViewProvider = Provider.autoDispose<AsyncValue<WeeklyView>>((ref) {
  _refreshOnForeground(ref);
  final list = ref.watch(challengeListProvider);
  final log = ref.watch(challengeLogProvider);
  final settings = ref.watch(specialsSettingsProvider);
  final parts = <AsyncValue<Object?>>[list, log, settings];
  for (final p in parts) {
    if (p case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (parts.any((p) => !p.hasValue)) return const AsyncLoading();
  final now = ref.watch(togetherClockProvider)();
  final ws = settings.requireValue.weekStart;
  final week = SpecialWeeks.weekOf(now, ws);
  final l = list.requireValue;
  final id = log.requireValue.challengeFor(week, ws, l.pool);
  return AsyncData(
    WeeklyView(
      now: now,
      weekStart: ws,
      week: week,
      list: l,
      log: log.requireValue,
      challenge: l.byId(id) ?? l.pool.firstOrNull,
    ),
  );
});

/// The active goal's standing (null data: no goal).
final goalStandingProvider = Provider.autoDispose<AsyncValue<GoalStanding?>>((ref) {
  final board = ref.watch(goalBoardProvider);
  final ledger = ref.watch(togetherLedgerProvider);
  final log = ref.watch(challengeLogProvider);
  final parts = <AsyncValue<Object?>>[board, ledger, log];
  for (final p in parts) {
    if (p case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (parts.any((p) => !p.hasValue)) return const AsyncLoading();
  final g = board.requireValue.active;
  if (g == null) return const AsyncData(null);
  return AsyncData(
    GoalStanding(goal: g, progress: g.progress(ledger: ledger.requireValue, challengesDone: log.requireValue.total)),
  );
});
