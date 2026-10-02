/// The cooperative goal: a target the couple works towards together –
/// points from the games they play and the weekly challenges they complete,
/// or a counter of their own – that unlocks a reward they wrote together.
library;

import 'dart:math' as math;

import '../../domain/head_to_head.dart';
import '../../domain/together_bounds.dart';
import 'specials_bounds.dart';

/// What moves a goal forward.
enum GoalMetric {
  /// Together points: [SpecialsBounds.matchPoints] per match played together
  /// and [SpecialsBounds.challengePoints] per weekly challenge completed
  /// (each can be switched off).
  points,

  /// A counter the couple moves themselves (walks, pages, visits …).
  counter;

  static GoalMetric? tryParse(Object? v) => values.where((m) => m.name == v).firstOrNull;
}

/// The goal being worked on.
final class CoopGoal {
  const CoopGoal({
    this.title = '',
    required this.reward,
    this.metric = GoalMetric.points,
    required this.target,
    this.countGames = true,
    this.countChallenges = true,
    this.unit = '',
    this.counter = 0,
    required this.startedAt,
    this.baseMatches = 0,
    this.baseChallenges = 0,
    this.unlockedAt,
  });

  /// The goal's name ('' = the localised "Our goal").
  final String title;

  /// The reward the couple wrote (never empty).
  final String reward;
  final GoalMetric metric;

  /// 1..[SpecialsBounds.maxGoalTarget].
  final int target;
  final bool countGames;
  final bool countChallenges;

  /// A counter's unit ('' = the localised "times").
  final String unit;

  /// A counter goal's count.
  final int counter;
  final DateTime startedAt;

  /// Lifetime matches / completed challenges when the goal started: only
  /// what happens after counts.
  final int baseMatches;
  final int baseChallenges;

  /// When the goal was first reached (it stays unlocked).
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  /// A new goal starting [now], counting from [ledger] and [challengesDone].
  factory CoopGoal.start({
    String title = '',
    required String reward,
    GoalMetric metric = GoalMetric.points,
    required int target,
    bool countGames = true,
    bool countChallenges = true,
    String unit = '',
    required DateTime now,
    required TogetherLedger ledger,
    required int challengesDone,
  }) => CoopGoal(
    title: title,
    reward: reward,
    metric: metric,
    target: target,
    countGames: countGames,
    countChallenges: countChallenges,
    unit: unit,
    startedAt: now,
    baseMatches: ledger.overall.matches,
    baseChallenges: challengesDone,
  ).bounded();

  /// Matches played since the goal started. The lifetime ledger is exact
  /// however long ago the goal started; when the records were cleared since
  /// (the ledger then begins after the goal did) every match in it counts.
  int matchesSince(TogetherLedger ledger) {
    final first = ledger.firstPlayed;
    final all = ledger.overall.matches;
    if (first != null && !first.isBefore(startedAt)) return all;
    return math.max(0, all - baseMatches);
  }

  /// Progress towards [target] (not capped).
  int progress({required TogetherLedger ledger, required int challengesDone}) => switch (metric) {
    GoalMetric.counter => counter,
    GoalMetric.points =>
      (countGames ? matchesSince(ledger) * SpecialsBounds.matchPoints : 0) +
          (countChallenges ? math.max(0, challengesDone - baseChallenges) * SpecialsBounds.challengePoints : 0),
  };

  CoopGoal copyWith({
    String? title,
    String? reward,
    GoalMetric? metric,
    int? target,
    bool? countGames,
    bool? countChallenges,
    String? unit,
    int? counter,
    DateTime? Function()? unlockedAt,
  }) => CoopGoal(
    title: title ?? this.title,
    reward: reward ?? this.reward,
    metric: metric ?? this.metric,
    target: target ?? this.target,
    countGames: countGames ?? this.countGames,
    countChallenges: countChallenges ?? this.countChallenges,
    unit: unit ?? this.unit,
    counter: counter ?? this.counter,
    startedAt: startedAt,
    baseMatches: baseMatches,
    baseChallenges: baseChallenges,
    unlockedAt: unlockedAt == null ? this.unlockedAt : unlockedAt(),
  ).bounded();

  /// Every field cleaned and within bounds (a points goal counts at least
  /// one source).
  CoopGoal bounded() {
    final games = countGames || !countChallenges;
    return CoopGoal(
      title: SpecialsBounds.clean(title, SpecialsBounds.maxGoalTitleLength),
      reward: SpecialsBounds.clean(reward, SpecialsBounds.maxRewardLength),
      metric: metric,
      target: target.clamp(1, SpecialsBounds.maxGoalTarget),
      countGames: games,
      countChallenges: countChallenges,
      unit: SpecialsBounds.clean(unit, SpecialsBounds.maxUnitLength),
      counter: counter.clamp(0, SpecialsBounds.maxCounter),
      startedAt: startedAt,
      baseMatches: math.max(0, baseMatches),
      baseChallenges: math.max(0, baseChallenges),
      unlockedAt: unlockedAt,
    );
  }

  Map<String, Object?> toJson() {
    final b = bounded();
    return {
      if (b.title.isNotEmpty) 'ti': b.title,
      'r': b.reward,
      'm': b.metric.name,
      'n': b.target,
      if (!b.countGames) 'ng': 1,
      if (!b.countChallenges) 'nc': 1,
      if (b.unit.isNotEmpty) 'u': b.unit,
      if (b.counter > 0) 'k': b.counter,
      's': b.startedAt.millisecondsSinceEpoch,
      if (b.baseMatches > 0) 'bm': b.baseMatches,
      if (b.baseChallenges > 0) 'bc': b.baseChallenges,
      'x': ?b.unlockedAt?.millisecondsSinceEpoch,
    };
  }

  static CoopGoal? fromJson(Object? json) {
    if (json is! Map) return null;
    final reward = SpecialsBounds.clean(json['r'], SpecialsBounds.maxRewardLength);
    final started = TogetherBounds.time(json['s']);
    final n = json['n'];
    if (reward.isEmpty || started == null || n is! int) return null;
    return CoopGoal(
      title: SpecialsBounds.clean(json['ti'], SpecialsBounds.maxGoalTitleLength),
      reward: reward,
      metric: GoalMetric.tryParse(json['m']) ?? GoalMetric.points,
      target: n,
      countGames: json['ng'] != 1,
      countChallenges: json['nc'] != 1,
      unit: SpecialsBounds.clean(json['u'], SpecialsBounds.maxUnitLength),
      counter: TogetherBounds.count(json['k'], max: SpecialsBounds.maxCounter),
      startedAt: started,
      baseMatches: TogetherBounds.count(json['bm']),
      baseChallenges: TogetherBounds.count(json['bc']),
      unlockedAt: TogetherBounds.time(json['x']),
    ).bounded();
  }

  @override
  bool operator ==(Object other) =>
      other is CoopGoal &&
      other.title == title &&
      other.reward == reward &&
      other.metric == metric &&
      other.target == target &&
      other.countGames == countGames &&
      other.countChallenges == countChallenges &&
      other.unit == unit &&
      other.counter == counter &&
      other.startedAt == startedAt &&
      other.baseMatches == baseMatches &&
      other.baseChallenges == baseChallenges &&
      other.unlockedAt == unlockedAt;

  @override
  int get hashCode => Object.hash(
    title,
    reward,
    metric,
    target,
    countGames,
    countChallenges,
    unit,
    counter,
    startedAt,
    baseMatches,
    baseChallenges,
    unlockedAt,
  );
}

/// A reward the couple unlocked ("our rewards").
final class AchievedGoal {
  const AchievedGoal({
    this.title = '',
    required this.reward,
    required this.metric,
    required this.target,
    this.unit = '',
    required this.startedAt,
    required this.unlockedAt,
  });

  factory AchievedGoal.of(CoopGoal g, DateTime unlockedAt) => AchievedGoal(
    title: g.title,
    reward: g.reward,
    metric: g.metric,
    target: g.target,
    unit: g.unit,
    startedAt: g.startedAt,
    unlockedAt: unlockedAt,
  );

  final String title;
  final String reward;
  final GoalMetric metric;
  final int target;
  final String unit;
  final DateTime startedAt;
  final DateTime unlockedAt;

  Map<String, Object?> toJson() => {
    if (title.isNotEmpty) 'ti': SpecialsBounds.clean(title, SpecialsBounds.maxGoalTitleLength),
    'r': SpecialsBounds.clean(reward, SpecialsBounds.maxRewardLength),
    'm': metric.name,
    'n': target.clamp(1, SpecialsBounds.maxGoalTarget),
    if (unit.isNotEmpty) 'u': SpecialsBounds.clean(unit, SpecialsBounds.maxUnitLength),
    's': startedAt.millisecondsSinceEpoch,
    'x': unlockedAt.millisecondsSinceEpoch,
  };

  static AchievedGoal? fromJson(Object? json) {
    if (json is! Map) return null;
    final reward = SpecialsBounds.clean(json['r'], SpecialsBounds.maxRewardLength);
    final s = TogetherBounds.time(json['s']);
    final x = TogetherBounds.time(json['x']);
    final n = json['n'];
    if (reward.isEmpty || s == null || x == null || n is! int) return null;
    return AchievedGoal(
      title: SpecialsBounds.clean(json['ti'], SpecialsBounds.maxGoalTitleLength),
      reward: reward,
      metric: GoalMetric.tryParse(json['m']) ?? GoalMetric.points,
      target: n.clamp(1, SpecialsBounds.maxGoalTarget),
      unit: SpecialsBounds.clean(json['u'], SpecialsBounds.maxUnitLength),
      startedAt: s,
      unlockedAt: x,
    );
  }
}

/// The active goal and the rewards unlocked so far.
final class GoalBoard {
  const GoalBoard({this.active, this.achieved = const []});

  static const GoalBoard empty = GoalBoard();

  final CoopGoal? active;

  /// Oldest first, at most [SpecialsBounds.maxAchieved].
  final List<AchievedGoal> achieved;

  GoalBoard withActive(CoopGoal? goal) => GoalBoard(active: goal, achieved: achieved);

  /// Files the unlocked active goal under "our rewards" and clears it.
  GoalBoard archiveActive() {
    final g = active;
    final at = g?.unlockedAt;
    if (g == null || at == null) return this;
    final list = [...achieved, AchievedGoal.of(g, at)];
    return GoalBoard(
      achieved: list.length > SpecialsBounds.maxAchieved ? list.sublist(list.length - SpecialsBounds.maxAchieved) : list,
    );
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    if (active != null) 'g': active!.toJson(),
    if (achieved.isNotEmpty) 'a': [for (final a in achieved) a.toJson()],
  };

  static GoalBoard fromJson(Object? json) {
    if (json is! Map) return empty;
    final list = <AchievedGoal>[];
    final raw = json['a'];
    if (raw is List) {
      for (final item in raw) {
        final a = AchievedGoal.fromJson(item);
        if (a != null) list.add(a);
      }
    }
    return GoalBoard(
      active: CoopGoal.fromJson(json['g']),
      achieved: list.length > SpecialsBounds.maxAchieved ? list.sublist(list.length - SpecialsBounds.maxAchieved) : list,
    );
  }
}

/// A goal's standing at one moment.
final class GoalStanding {
  const GoalStanding({required this.goal, required this.progress});

  final CoopGoal goal;

  /// Not capped (a counter can overshoot).
  final int progress;

  int get target => goal.target;

  double get fraction => (progress / target).clamp(0.0, 1.0);

  bool get reached => progress >= target;

  int get remaining => math.max(0, target - progress);
}
