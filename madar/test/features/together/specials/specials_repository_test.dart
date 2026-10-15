import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/features/together/together.dart';

KnowMeRound _played({String id = 'r1', int n = 5, bool perfectTwo = false}) {
  final r = KnowMeRound(
    id: id,
    questions: [for (var i = 0; i < n; i++) RoundQuestion(id: 'fav.q$i', text: 'Q$i')],
    first: PlayerSlot.one,
    startedAt: DateTime(2026, 9, 30, 20),
  );
  r.submit(PlayerSlot.one, [for (var i = 0; i < n; i++) KnowMeAnswer(own: 'a$i', guess: 'zz')]);
  r.submit(PlayerSlot.two, [for (var i = 0; i < n; i++) KnowMeAnswer(own: 'b$i', guess: perfectTwo ? 'a$i' : 'nope')]);
  for (final item in r.pending) {
    r.judge(item, KnowMeVerdict.miss);
  }
  return r;
}

void main() {
  late MadarDatabase db;
  late SpecialsRepository repo;

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repo = SpecialsRepository(db);
  });
  tearDown(() => db.close());

  test('defaults without anything stored; every key is a together.* key', () async {
    expect(await repo.bank(), KnowMeBank.defaults());
    expect(await repo.prefs(), const KnowMePrefs());
    expect(await repo.challenges(), ChallengeList.defaults());
    expect(await repo.log(), ChallengeLog.empty);
    expect((await repo.goals()).active, isNull);
    expect((await repo.settings()).weekStart, DateTime.saturday);
    for (final k in SpecialsRepository.allKeys) {
      expect(k, startsWith('together.'));
      expect(TogetherRepository.allKeys, isNot(contains(k)));
    }
  });

  test('bank edits persist and undo restores exactly', () async {
    final undo = await repo.updateBank((b) => b.addQuestion(id: 'qown', categoryId: 'fav', text: 'Our song?'));
    expect((await repo.bank()).question('qown'), isNotNull);
    final undo2 = await repo.updateBank((b) => b.deleteQuestion('fav.dish'));
    expect((await repo.bank()).question('fav.dish'), isNull);
    await undo2();
    expect((await repo.bank()).question('fav.dish'), isNotNull);
    await undo();
    expect(await KeyValueRepository(db).contains(SpecialsRepository.bankKey), isFalse);
    // A no-op change writes nothing.
    await repo.updateBank((b) => b);
    expect(await KeyValueRepository(db).contains(SpecialsRepository.bankKey), isFalse);
    // A refused change leaves the bank alone.
    await expectLater(repo.updateBank((b) => b.addQuestion(id: 'q2', categoryId: 'nope', text: 'x')), throwsA(isA<BankEditException>()));
  });

  test('a round goes into the head-to-head history once; a perfect one makes a mind reader', () async {
    final r = _played(perfectTwo: true);
    final first = await repo.recordKnowMe(r, DateTime(2026, 9, 30, 20, 10));
    expect(first.recorded, isTrue);
    final ids = first.newTrophies.map((t) => t.key).toList();
    expect(ids, contains(const TrophyKey(TrophyId.firstMatch)));
    expect(ids, contains(const TrophyKey(TrophyId.mindReader, holder: PlayerSlot.two)));
    final history = await repo.together.history();
    expect(history.single.id, 'knowMe-r1');
    expect(history.single.outcome, MatchOutcome.twoWon);
    expect((history.single.scoreOne, history.single.scoreTwo), (0, 10));
    // Recorded twice (double tap): nothing changes, nothing is celebrated again.
    final again = await repo.recordKnowMe(r, DateTime(2026, 9, 30, 20, 11));
    expect(again.newTrophies, isEmpty);
    expect(await repo.together.history(), hasLength(1));
    expect((await repo.together.ledger()).tallyOf('knowMe').winsTwo, 1);
    // The asked questions are remembered.
    expect((await repo.prefs()).recent, containsAll(['fav.q0', 'fav.q4']));
    // A second perfect round: the trophy is not awarded twice.
    final second = await repo.recordKnowMe(_played(id: 'r2', perfectTwo: true), DateTime(2026, 9, 30, 21));
    expect(second.newTrophies.where((t) => t.id == TrophyId.mindReader), isEmpty);
  });

  test('a round with nothing answered is not recorded', () async {
    final r = KnowMeRound(
      id: 'r9',
      questions: const [RoundQuestion(id: 'fav.dish', text: 'Q')],
      first: PlayerSlot.two,
      startedAt: DateTime(2026, 9, 30),
    );
    r.submit(PlayerSlot.two, const [KnowMeAnswer()]);
    r.submit(PlayerSlot.one, const [KnowMeAnswer()]);
    final out = await repo.recordKnowMe(r, DateTime(2026, 9, 30, 1));
    expect(out.recorded, isFalse);
    expect(await repo.together.history(), isEmpty);
  });

  test('weekly challenge: four weeks in a row earn "Challenge champions"', () async {
    final sat = DateTime(2026, 9, 5, 21);
    for (var k = 0; k < 4; k++) {
      final now = sat.add(Duration(days: 7 * k));
      await repo.ensureWeek(now);
      await repo.markChallenge(PlayerSlot.one, done: true, now: now);
      final res = await repo.markChallenge(PlayerSlot.two, done: true, now: now.add(const Duration(hours: 1)));
      expect(res.mark.completed, isTrue);
      expect(res.newTrophies.map((t) => t.id), k == 3 ? [TrophyId.challengeChampions] : isEmpty);
    }
    final log = await repo.log();
    expect((log.total, log.best), (4, 4));
    // Un-marking the fourth week takes the streak back (the trophy stays).
    final undo = await repo.markChallenge(PlayerSlot.one, done: false, now: sat.add(const Duration(days: 22)));
    expect(undo.mark.uncompleted, isTrue);
    expect(((await repo.log()).total, (await repo.log()).best), (3, 3));
    expect((await repo.together.trophies()).hasAny(TrophyId.challengeChampions), isTrue);
  });

  test('the week start setting moves the reset day', () async {
    // Friday 2 October 2026, 23:00 then Saturday 00:30.
    final friday = DateTime(2026, 10, 2, 23);
    final saturday = DateTime(2026, 10, 3, 0, 30);
    await repo.markChallenge(PlayerSlot.one, done: true, now: friday);
    await repo.markChallenge(PlayerSlot.two, done: true, now: saturday);
    // Saturday weeks: two different weeks, neither complete.
    expect((await repo.log()).total, 0);
    // With Sunday weeks both marks would have fallen in one week.
    await db.close();
    db = MadarDatabase(NativeDatabase.memory());
    repo = SpecialsRepository(db);
    await repo.saveSettings(const SpecialsSettings(weekStart: DateTime.sunday));
    await repo.markChallenge(PlayerSlot.one, done: true, now: friday);
    final res = await repo.markChallenge(PlayerSlot.two, done: true, now: saturday);
    expect(res.mark.completed, isTrue);
  });

  test('goal: counts from its start, unlocks once, "Dream came true" once, archives', () async {
    final now = DateTime(2026, 9, 30, 20);
    // Matches before the goal do not count.
    await repo.together.recordMatch(MatchRecord(id: 'old', gameId: 'chess', endedAt: now.subtract(const Duration(days: 3)), outcome: MatchOutcome.draw));
    final undo = await repo.startGoal(reward: 'Dinner at our place', target: 2, now: now);
    var board = await repo.goals();
    expect(board.active!.baseMatches, 1);
    expect(await repo.unlockIfReached(now), isNull);
    await repo.together.recordMatch(MatchRecord(id: 'm1', gameId: 'chess', endedAt: now.add(const Duration(hours: 1)), outcome: MatchOutcome.oneWon));
    expect(await repo.unlockIfReached(now), isNull);
    await repo.together.recordMatch(MatchRecord(id: 'm2', gameId: 'basra', endedAt: now.add(const Duration(hours: 2)), outcome: MatchOutcome.twoWon));
    // Two watchers race to unlock: exactly one wins and celebrates.
    final results = await Future.wait([repo.unlockIfReached(now), repo.unlockIfReached(now)]);
    expect(results.where((r) => r != null), hasLength(1));
    expect(results.firstWhere((r) => r != null)!.map((t) => t.id), [TrophyId.dreamCameTrue]);
    board = await repo.goals();
    expect(board.active!.unlockedAt, now);
    // Editing keeps the unlock and the start.
    await repo.editGoal((g) => g.copyWith(reward: 'Dinner by the sea', target: 50));
    board = await repo.goals();
    expect(board.active!.isUnlocked, isTrue);
    expect(board.active!.startedAt, now);
    expect(board.active!.reward, 'Dinner by the sea');
    // A new goal files the unlocked one under our rewards.
    await repo.startGoal(reward: 'A trip', target: 10, metric: GoalMetric.counter, unit: 'walks', now: now.add(const Duration(days: 1)));
    board = await repo.goals();
    expect(board.achieved.single.reward, 'Dinner by the sea');
    expect(board.active!.metric, GoalMetric.counter);
    await repo.bumpCounter(3);
    await repo.bumpCounter(-10);
    expect((await repo.goals()).active!.counter, 0);
    for (var i = 0; i < 12; i++) {
      await repo.bumpCounter(1);
    }
    final second = await repo.unlockIfReached(now.add(const Duration(days: 2)));
    expect(second, isEmpty, reason: 'unlocked, but "Dream came true" is already on the shelf');
    // The first undo still restores what was there before any goal.
    await undo();
    expect((await repo.goals()).active, isNull);
    await expectLater(repo.startGoal(reward: '   ', target: 3, now: now), throwsArgumentError);
  });

  test('awardTrophies refuses keys that do not fit the trophy', () async {
    final t = repo.together;
    expect(() => t.awardTrophies(const [TrophyKey(TrophyId.mindReader)], at: DateTime(2026)), throwsArgumentError);
    expect(
      () => t.awardTrophies(const [TrophyKey(TrophyId.dreamCameTrue, holder: PlayerSlot.one)], at: DateTime(2026)),
      throwsArgumentError,
    );
    final fresh = await t.awardTrophies(
      const [TrophyKey(TrophyId.dreamCameTrue), TrophyKey(TrophyId.dreamCameTrue)],
      at: DateTime(2026),
      matchId: 'not a valid id!',
    );
    expect(fresh, hasLength(1));
    expect(fresh.single.matchId, isNull);
    expect(await t.awardTrophies(const [TrophyKey(TrophyId.dreamCameTrue)], at: DateTime(2026)), isEmpty);
  });

  test('nothing personal is stored beyond what the couple typed; values stay small', () async {
    await repo.startGoal(reward: 'x' * 1000, target: 5, now: DateTime(2026));
    await repo.updateChallenges((c) => c.add(id: 'wx', text: '🌙' * 500));
    for (final key in SpecialsRepository.allKeys) {
      final raw = await KeyValueRepository(db).getJson(key);
      if (raw == null) continue;
      expect(utf8.encode(jsonEncode(raw)).length, lessThan(TogetherBounds.maxStoredBytes), reason: key);
    }
    final goal = (await repo.goals()).active!;
    expect(goal.reward.runes.length, SpecialsBounds.maxRewardLength);
  });
}
