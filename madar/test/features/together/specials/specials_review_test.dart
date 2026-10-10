// Adversarial review of the couple specials: each test pins a defect found
// while trying to break scoring, week boundaries and reveal privacy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/together/together.dart';

import '../together_test_utils.dart';

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  // Lazily built lists: scroll the target into existence first.
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester) async {
  await tester.pump(HandOffScreen.armDelay);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('together-reveal')));
  await tester.pumpAndSettle();
}

void main() {
  group('reveal privacy', () {
    test('the live score counts only guesses already turned over', () {
      final r = KnowMeRound(
        id: 'r1',
        questions: const [RoundQuestion(id: 'a', text: 'A?'), RoundQuestion(id: 'b', text: 'B?')],
        first: PlayerSlot.one,
        startedAt: DateTime(2026),
      );
      // Every guess is the very same answer: all automatically spot on.
      r.submit(PlayerSlot.one, const [KnowMeAnswer(own: 'tea', guess: 'sea'), KnowMeAnswer(own: 'red', guess: 'blue')]);
      r.submit(PlayerSlot.two, const [KnowMeAnswer(own: 'sea', guess: 'tea'), KnowMeAnswer(own: 'blue', guess: 'red')]);
      expect(r.scoreOf(PlayerSlot.one), 4, reason: 'the full score already "knows" the unrevealed answers');
      expect(r.revealedScoreOf(PlayerSlot.one, const {}), 0);
      expect(r.revealedScoreOf(PlayerSlot.two, {KnowMeItem(0, PlayerSlot.one)}), 2);
      expect(r.revealedScoreOf(PlayerSlot.one, {KnowMeItem(0, PlayerSlot.one)}), 0);
      expect(r.revealedScoreOf(PlayerSlot.one, {KnowMeItem(9, PlayerSlot.two)}), 0, reason: 'out of range ignored');
    });

    testWidgets('the scoreboard does not give away answers that are still face down', (tester) async {
      final r = KnowMeRound(
        id: 'r2',
        questions: const [RoundQuestion(id: 'a', text: 'A?'), RoundQuestion(id: 'b', text: 'B?')],
        first: PlayerSlot.one,
        startedAt: togetherNow,
      );
      r.submit(PlayerSlot.one, const [KnowMeAnswer(own: 'tea', guess: 'sea'), KnowMeAnswer(own: 'red', guess: 'blue')]);
      r.submit(PlayerSlot.two, const [KnowMeAnswer(own: 'sea', guess: 'tea'), KnowMeAnswer(own: 'blue', guess: 'red')]);
      await pumpTogetherApp(tester, locale: const Locale('en'), home: KnowMeRoundScreen(round: r));
      final board = find.byKey(const ValueKey('knowme-scoreboard'));
      String label() => tester.getSemantics(board).label;
      expect(label(), contains('Player 1${'\u2069'} 0'));
      expect(label(), contains('Player 2${'\u2069'} 0'));
      await _tapKey(tester, 'knowme-reveal-0-one');
      expect(label(), contains('Player 2${'\u2069'} 2'), reason: 'player two guessed "tea" – now shown');
      expect(label(), contains('Player 1${'\u2069'} 0'), reason: 'player one\'s guesses are still face down');
    });
  });

  group('week boundaries', () {
    const sat = DateTime.saturday;
    final pool = ChallengeList.defaults().pool;
    final w0 = SpecialWeeks.weekOf(DateTime(2026, 9, 5), sat);

    ChallengeLog both(ChallengeLog log, int week) {
      final at = SpecialWeeks.dateOf(week + 1);
      final a = log.mark(week: week, weekStart: sat, slot: PlayerSlot.one, done: true, at: at, pool: pool).log;
      return a.mark(week: week, weekStart: sat, slot: PlayerSlot.two, done: true, at: at, pool: pool).log;
    }

    test('an earlier week completed after a later one (clock / zone moved back) extends the later streak', () {
      // Weeks w0 and w0+7 done; then the next week is done before the one
      // between them (the phone crossed the boundary westwards and back).
      var log = both(both(ChallengeLog.empty, w0), w0 + 7);
      log = both(log, w0 + 21);
      expect(log.weekAt(w0 + 21, sat)!.streak, 1);
      log = both(log, w0 + 14);
      expect(log.weekAt(w0 + 14, sat)!.streak, 3);
      expect(log.weekAt(w0 + 21, sat)!.streak, 4, reason: 'the later week continues the repaired run');
      expect(log.currentStreak(w0 + 21, sat), 4);
      expect((log.total, log.best), (4, 4));
      // Undoing the week in between breaks the run again – exactly.
      final undone = log.mark(week: w0 + 14, weekStart: sat, slot: PlayerSlot.one, done: false, at: DateTime(2026), pool: pool);
      expect(undone.log.weekAt(w0 + 21, sat)!.streak, 1);
      expect((undone.log.total, undone.log.best), (3, 2));
    });

    test('a pinned challenge deleted before anyone started moves on; a started one stays', () {
      final list = ChallengeList.defaults().add(id: 'wown', text: 'Ours');
      var log = ChallengeLog.empty.swap(week: w0, weekStart: sat, challengeId: 'wown', pool: list.pool);
      final after = list.delete('wown');
      final existing = {for (final c in after.items) c.id};
      final repinned = log.ensureWeek(w0, sat, after.pool, existing: existing);
      expect(repinned.weekAt(w0, sat)!.challengeId, isNot('wown'));
      expect(after.byId(repinned.weekAt(w0, sat)!.challengeId), isNotNull);
      // Hidden (not deleted) stays pinned.
      final hidden = list.setHidden('walk', true);
      final walkLog = ChallengeLog.empty.swap(week: w0, weekStart: sat, challengeId: 'walk', pool: list.pool);
      expect(walkLog.ensureWeek(w0, sat, hidden.pool, existing: {for (final c in hidden.items) c.id}), walkLog);
      // Started: stays (it is what they did).
      log = log.mark(week: w0, weekStart: sat, slot: PlayerSlot.one, done: true, at: DateTime(2026), pool: list.pool).log;
      expect(log.ensureWeek(w0, sat, after.pool, existing: existing).weekAt(w0, sat)!.challengeId, 'wown');
    });
  });

  group('editing', () {
    testWidgets('a question that cleans to nothing is refused quietly', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const QuestionBankScreen());
      await _tapKey(tester, 'bank-add-question');
      // Zero-width and bidi characters only: the sheet sees text, storage none.
      await tester.enterText(find.byType(TextField).first, '\u200B\u202E\u2066');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await settleTogether(tester);
      expect(tester.takeException(), isNull);
      final bank = await tester.runAsync(() => SpecialsRepository(env.db).bank());
      expect(bank!.questions.where((q) => !q.isDefault), isEmpty);
    });

    testWidgets('a challenge that cleans to nothing is refused quietly', (tester) async {
      final env2 = await pumpTogetherApp(tester, locale: const Locale('en'), home: const ChallengeListScreen());
      await _tapKey(tester, 'challenges-add');
      await tester.enterText(find.byType(TextField).first, '\u200B\u200B');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await settleTogether(tester);
      expect(tester.takeException(), isNull);
      expect((await tester.runAsync(() => SpecialsRepository(env2.db).challenges()))!.items, hasLength(26));
    });
  });

  group('scoring', () {
    testWidgets('"another round" never repeats the questions just asked', (tester) async {
      final env = await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: const KnowMeScreen(),
        seed: (repo) => SpecialsRepository(repo.db).updatePrefs(
          (p) => p.copyWith(roundSize: 5, categories: {'fav'}),
        ),
      );
      await _tapKey(tester, 'knowme-start');
      final first = tester.widget<KnowMeRoundScreen>(find.byType(KnowMeRoundScreen)).round;
      for (var turn = 0; turn < 2; turn++) {
        await _reveal(tester);
        await tester.enterText(_field('knowme-own-0'), 'x');
        for (var i = 0; i < 4; i++) {
          await _tapKey(tester, 'knowme-page-next');
        }
        await _tapKey(tester, 'knowme-submit');
      }
      for (var q = 0; q < 5; q++) {
        await _tapKey(tester, 'knowme-reveal-$q-one');
        await _tapKey(tester, 'knowme-reveal-$q-two');
        if (q == 0) {
          // Both guessed nothing: automatically "not quite".
          expect(find.textContaining('No guess'), findsWidgets);
        }
        await _tapKey(tester, 'knowme-next');
      }
      await settleTogether(tester);
      expect(find.text('Results'), findsOneWidget);
      // The results recap every answer: still out of the recents thumbnail.
      expect(env.secure.secure, isTrue);
      // The first match's trophy is celebrated first.
      final trophies = find.text('New in our Hall of Fame!');
      expect(trophies, findsOneWidget);
      Navigator.of(tester.element(trophies)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('knowme-again')));
      await settleTogether(tester);
      final second = tester.widget<KnowMeRoundScreen>(find.byType(KnowMeRoundScreen)).round;
      expect(second.id, isNot(first.id));
      expect(second.first, first.first.other);
      expect(
        second.questions.map((q) => q.id).toSet().intersection(first.questions.map((q) => q.id).toSet()),
        isEmpty,
      );
      final prefs = await tester.runAsync(() => SpecialsRepository(env.db).prefs());
      expect(prefs!.recent, hasLength(5));
    });

    testWidgets('an unlocked goal is not "dropped" – it goes to our rewards with the next goal', (tester) async {
      final env = await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: const CoopGoalScreen(),
        seed: (repo) async {
          final sp = SpecialsRepository(repo.db);
          await sp.startGoal(reward: 'Tea on the balcony', target: 1, metric: GoalMetric.counter, now: togetherNow);
          await sp.bumpCounter(1);
          await sp.unlockIfReached(togetherNow);
        },
      );
      expect(find.text('Reward unlocked!'), findsWidgets);
      expect(find.byKey(const ValueKey('goal-drop')), findsNothing);
      await _tapKey(tester, 'goal-next');
      await tester.enterText(find.byKey(const ValueKey('goal-reward-field')), 'A long walk');
      await tester.enterText(find.byKey(const ValueKey('goal-target-field')), '5');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-save')));
      await settleTogether(tester);
      final board = (await tester.runAsync(() => SpecialsRepository(env.db).goals()))!;
      expect(board.achieved.single.reward, 'Tea on the balcony');
      expect(board.active!.reward, 'A long walk');
      expect(board.active!.isUnlocked, isFalse);
      expect(find.text('Our rewards'), findsOneWidget);
    });
  });
}
