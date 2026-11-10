import 'dart:convert';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/key_value_repository.dart';
import '../../data/together_repository.dart';
import '../../domain/player_profile.dart';
import '../../domain/trophies.dart';
import '../domain/coop_goal.dart';
import '../domain/know_me_bank.dart';
import '../domain/know_me_round.dart';
import '../domain/specials_bounds.dart';
import '../domain/specials_settings.dart';
import '../domain/weekly_challenge.dart';

/// Reverts a change (offered by the undo toast).
typedef SpecialsUndo = Future<void> Function();

/// What recording a "How well do you know me?" round did.
final class KnowMeRecorded {
  const KnowMeRecorded({required this.recorded, required this.newTrophies});

  /// False for a round with nothing scored (it is not recorded).
  final bool recorded;

  /// Trophies earned (match trophies and "Mind reader").
  final List<EarnedTrophy> newTrophies;
}

/// What marking the weekly challenge did.
final class ChallengeMarked {
  const ChallengeMarked({required this.mark, this.newTrophies = const []});

  final ChallengeMark mark;
  final List<EarnedTrophy> newTrophies;
}

/// The couple specials' storage: bounded JSON values in the encrypted
/// KeyValues table – no schema of their own. Match results and trophies go
/// through [TogetherRepository] (the head-to-head history and the Hall of
/// Fame).
///
/// | key                          | value                                  |
/// |------------------------------|----------------------------------------|
/// | `together.knowMe.bank`       | questions and categories ([KnowMeBank]) |
/// | `together.knowMe.prefs`      | round size, categories, recently asked  |
/// | `together.weekly.list`       | the challenges ([ChallengeList])        |
/// | `together.weekly.log`        | weeks, streaks, totals ([ChallengeLog]) |
/// | `together.goal`              | the goal and our rewards ([GoalBoard])  |
/// | `together.specials.settings` | week start ([SpecialsSettings])         |
class SpecialsRepository {
  SpecialsRepository(this.db) : keyValues = KeyValueRepository(db), together = TogetherRepository(db);

  static const String bankKey = 'together.knowMe.bank';
  static const String prefsKey = 'together.knowMe.prefs';
  static const String challengesKey = 'together.weekly.list';
  static const String logKey = 'together.weekly.log';
  static const String goalKey = 'together.goal';
  static const String settingsKey = 'together.specials.settings';

  /// Every key the specials write.
  static const List<String> allKeys = [bankKey, prefsKey, challengesKey, logKey, goalKey, settingsKey];

  final MadarDatabase db;
  final KeyValueRepository keyValues;
  final TogetherRepository together;

  // ------------------------------------------------------------------ raw

  Stream<String?> _watchRaw(String key) =>
      (db.select(db.keyValues)..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value).distinct();

  Stream<T> _watch<T>(String key, T Function(Object? json) decode) => _watchRaw(key).map((raw) => decode(_decode(raw)));

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<String?> _readRaw(String key) async =>
      (await (db.select(db.keyValues)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<Object?> _read(String key) async => _decode(await _readRaw(key));

  /// An undo restoring [key] to [raw] exactly.
  SpecialsUndo _restore(String key, String? raw) => () async {
    if (raw == null) {
      await keyValues.remove(key);
    } else {
      await keyValues.setJson(key, _decode(raw));
    }
  };

  /// Applies [change] to the stored value of [key] atomically; returns an
  /// undo (no-op changes write nothing).
  Future<SpecialsUndo> _update<T>(
    String key,
    T Function(Object? json) decode,
    Object? Function(T value) encode,
    T Function(T current) change,
    bool Function(T a, T b) same,
  ) => db.transaction(() async {
    final raw = await _readRaw(key);
    final current = decode(_decode(raw));
    final next = change(current);
    if (same(current, next)) return () async {};
    await keyValues.setJson(key, encode(next));
    return _restore(key, raw);
  });

  // -------------------------------------------------------------- know me

  Stream<KnowMeBank> watchBank() => _watch(bankKey, KnowMeBank.fromJson);

  Future<KnowMeBank> bank() async => KnowMeBank.fromJson(await _read(bankKey));

  /// Edits the question bank ([KnowMeBank]'s edits throw
  /// [BankEditException] for refused changes); returns an undo.
  Future<SpecialsUndo> updateBank(KnowMeBank Function(KnowMeBank bank) change) =>
      _update(bankKey, KnowMeBank.fromJson, (b) => b.toJson(), change, (a, b) => a == b);

  Stream<KnowMePrefs> watchPrefs() => _watch(prefsKey, KnowMePrefs.fromJson);

  Future<KnowMePrefs> prefs() async => KnowMePrefs.fromJson(await _read(prefsKey));

  Future<void> updatePrefs(KnowMePrefs Function(KnowMePrefs prefs) change) =>
      _update(prefsKey, KnowMePrefs.fromJson, (p) => p.toJson(), change, (a, b) => a == b);

  /// Records a finished round: the head-to-head match (idempotent – the
  /// record id comes from the round's), "Mind reader" for a perfect round,
  /// and the questions as recently asked. A round with nothing scored is
  /// not recorded.
  Future<KnowMeRecorded> recordKnowMe(KnowMeRound round, DateTime now) async {
    final result = round.finish();
    await updatePrefs((p) => p.asked(round.questions.map((q) => q.id)));
    if (!result.recordable) return const KnowMeRecorded(recorded: false, newTrophies: []);
    final record = round.toRecord(now);
    final recorded = await together.recordMatch(record);
    if (recorded.duplicate) return const KnowMeRecorded(recorded: true, newTrophies: []);
    final special = await together.awardTrophies(
      [for (final s in PlayerSlot.values) if (result.perfect.contains(s)) TrophyKey(TrophyId.mindReader, holder: s)],
      at: now,
      matchId: record.id,
    );
    return KnowMeRecorded(recorded: true, newTrophies: [...recorded.newTrophies, ...special]);
  }

  // --------------------------------------------------------------- weekly

  Stream<ChallengeList> watchChallenges() => _watch(challengesKey, ChallengeList.fromJson);

  Future<ChallengeList> challenges() async => ChallengeList.fromJson(await _read(challengesKey));

  /// Edits the challenge list (refused changes throw
  /// [ChallengeEditException]); returns an undo.
  Future<SpecialsUndo> updateChallenges(ChallengeList Function(ChallengeList list) change) =>
      _update(challengesKey, ChallengeList.fromJson, (l) => l.toJson(), change, (a, b) => a == b);

  Stream<ChallengeLog> watchLog() => _watch(logKey, ChallengeLog.fromJson);

  Future<ChallengeLog> log() async => ChallengeLog.fromJson(await _read(logKey));

  Stream<SpecialsSettings> watchSettings() => _watch(settingsKey, SpecialsSettings.fromJson);

  Future<SpecialsSettings> settings() async => SpecialsSettings.fromJson(await _read(settingsKey));

  Future<void> saveSettings(SpecialsSettings settings) => keyValues.setJson(settingsKey, settings.toJson());

  /// Pins this week's challenge (the week keeps it even if the list
  /// changes later – unless it was deleted before anyone started it).
  Future<void> ensureWeek(DateTime now) => db.transaction(() async {
    final ws = (await settings()).weekStart;
    final list = await challenges();
    final current = await log();
    final next = current.ensureWeek(
      SpecialWeeks.weekOf(now, ws),
      ws,
      list.pool,
      existing: {for (final c in list.items) c.id},
    );
    if (next != current) await keyValues.setJson(logKey, next.toJson());
  });

  /// [slot] marks this week's challenge done or not done. Completing a
  /// fourth week in a row earns "Challenge champions".
  Future<ChallengeMarked> markChallenge(PlayerSlot slot, {required bool done, required DateTime now}) async {
    final ws = (await settings()).weekStart;
    final week = SpecialWeeks.weekOf(now, ws);
    final mark = await db.transaction(() async {
      final pool = (await challenges()).pool;
      final m = (await log()).mark(week: week, weekStart: ws, slot: slot, done: done, at: now, pool: pool);
      await keyValues.setJson(logKey, m.log.toJson());
      return m;
    });
    var trophies = const <EarnedTrophy>[];
    if (mark.completed && mark.log.currentStreak(week, ws) >= SpecialsBounds.championStreak) {
      trophies = await together.awardTrophies(const [TrophyKey(TrophyId.challengeChampions)], at: now);
    }
    return ChallengeMarked(mark: mark, newTrophies: trophies);
  }

  /// Gives this week another challenge (only while nobody has marked it).
  Future<void> swapChallenge(String challengeId, DateTime now) => db.transaction(() async {
    final ws = (await settings()).weekStart;
    final pool = (await challenges()).pool;
    final next = (await log()).swap(week: SpecialWeeks.weekOf(now, ws), weekStart: ws, challengeId: challengeId, pool: pool);
    await keyValues.setJson(logKey, next.toJson());
  });

  // ----------------------------------------------------------------- goal

  Stream<GoalBoard> watchGoals() => _watch(goalKey, GoalBoard.fromJson);

  Future<GoalBoard> goals() async => GoalBoard.fromJson(await _read(goalKey));

  /// Starts a new goal counting from now (the unlocked goal before it, if
  /// any, is filed under "our rewards" first). Returns an undo.
  Future<SpecialsUndo> startGoal({
    String title = '',
    required String reward,
    GoalMetric metric = GoalMetric.points,
    required int target,
    bool countGames = true,
    bool countChallenges = true,
    String unit = '',
    required DateTime now,
  }) => db.transaction(() async {
    final raw = await _readRaw(goalKey);
    final ledger = await together.ledger();
    final done = (await log()).total;
    final goal = CoopGoal.start(
      title: title,
      reward: reward,
      metric: metric,
      target: target,
      countGames: countGames,
      countChallenges: countChallenges,
      unit: unit,
      now: now,
      ledger: ledger,
      challengesDone: done,
    );
    if (goal.reward.isEmpty) throw ArgumentError.value(reward, 'reward', 'a goal needs a reward');
    final board = GoalBoard.fromJson(_decode(raw)).archiveActive().withActive(goal);
    await keyValues.setJson(goalKey, board.toJson());
    return _restore(goalKey, raw);
  });

  /// Edits the active goal (its start and baselines stay). Returns an undo.
  Future<SpecialsUndo> editGoal(CoopGoal Function(CoopGoal goal) change) => db.transaction(() async {
    final raw = await _readRaw(goalKey);
    final board = GoalBoard.fromJson(_decode(raw));
    final g = board.active;
    if (g == null) return () async {};
    final next = change(g).bounded();
    if (next.reward.isEmpty) throw ArgumentError.value(next.reward, 'reward', 'a goal needs a reward');
    // The goal's identity and what it has already unlocked stay.
    final kept = CoopGoal(
      title: next.title,
      reward: next.reward,
      metric: next.metric,
      target: next.target,
      countGames: next.countGames,
      countChallenges: next.countChallenges,
      unit: next.unit,
      counter: next.counter,
      startedAt: g.startedAt,
      baseMatches: g.baseMatches,
      baseChallenges: g.baseChallenges,
      unlockedAt: g.unlockedAt,
    );
    if (kept == g) return () async {};
    await keyValues.setJson(goalKey, board.withActive(kept).toJson());
    return _restore(goalKey, raw);
  });

  /// Moves a counter goal by [delta] (bounded at 0 and the maximum).
  Future<void> bumpCounter(int delta) => editGoal((g) => g.copyWith(counter: g.counter + delta));

  /// Unlocks the active goal if it is reached and not unlocked yet. Returns
  /// the trophies earned when it was this call that unlocked it (the first
  /// goal ever earns "Dream came true"), else null.
  Future<List<EarnedTrophy>?> unlockIfReached(DateTime now) async {
    final unlocked = await db.transaction(() async {
      final board = await goals();
      final g = board.active;
      if (g == null || g.isUnlocked) return false;
      final standing = GoalStanding(
        goal: g,
        progress: g.progress(ledger: await together.ledger(), challengesDone: (await log()).total),
      );
      if (!standing.reached) return false;
      await keyValues.setJson(goalKey, board.withActive(g.copyWith(unlockedAt: () => now)).toJson());
      return true;
    });
    if (!unlocked) return null;
    return together.awardTrophies(const [TrophyKey(TrophyId.dreamCameTrue)], at: now);
  }

  /// Files the unlocked goal under "our rewards" (nothing otherwise).
  Future<SpecialsUndo> archiveGoal() =>
      _update(goalKey, GoalBoard.fromJson, (b) => b.toJson(), (b) => b.archiveActive(), (a, b) => a.active == b.active);

  /// Gives up the active goal. Returns an undo.
  Future<SpecialsUndo> deleteGoal() => _update(
    goalKey,
    GoalBoard.fromJson,
    (b) => b.toJson(),
    (b) => b.withActive(null),
    (a, b) => a.active == b.active,
  );
}
