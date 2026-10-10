import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/together/together.dart';

import '../together_test_utils.dart';

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

TextField _textField(WidgetTester tester, String key) => tester.widget<TextField>(_field(key));

Future<void> _reveal(WidgetTester tester) async {
  await tester.pump(HandOffScreen.armDelay);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('together-reveal')));
  await tester.pumpAndSettle();
}

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

KnowMeRound _twoQuestions() => KnowMeRound(
  id: 'rw1',
  questions: const [
    RoundQuestion(id: 'fav.dish', text: "What's my favourite dish?"),
    RoundQuestion(id: 'fav.drink', text: "What's my favourite drink?"),
  ],
  first: PlayerSlot.one,
  startedAt: togetherNow,
);

void main() {
  group('How well do you know me?', () {
    testWidgets('private answers never meet; the reveal scores; the round is recorded', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: KnowMeRoundScreen(round: _twoQuestions()));
      expect(find.byType(HandOffScreen), findsOneWidget);
      expect(find.text('Player 1'), findsWidgets);
      expect(find.byType(EditableText), findsNothing, reason: 'nothing private before the reveal tap');
      expect(env.secure.secure, isTrue, reason: 'hidden from recents while answering');

      // Player 1, in private.
      await _reveal(tester);
      final own = _textField(tester, 'knowme-own-0');
      expect(own.enableSuggestions, isFalse);
      expect(own.autocorrect, isFalse);
      expect(own.enableIMEPersonalizedLearning, isFalse, reason: 'no keyboard learning / suggestion bar leaks');
      expect(_textField(tester, 'knowme-guess-0').enableIMEPersonalizedLearning, isFalse);
      await tester.enterText(_field('knowme-own-0'), 'Mansaf');
      await tester.enterText(_field('knowme-guess-0'), 'Green tea');
      await _tapKey(tester, 'knowme-page-next');
      await tester.enterText(_field('knowme-own-1'), 'Coffee');
      await tester.enterText(_field('knowme-guess-1'), 'Pizza');
      await _tapKey(tester, 'knowme-submit');

      // Handed over: nothing of player 1's is on screen or in the tree.
      expect(find.byType(HandOffScreen), findsOneWidget);
      expect(find.text('Player 2'), findsWidgets);
      expect(find.byType(EditableText), findsNothing);
      for (final secret in ['Mansaf', 'Green tea', 'Coffee', 'Pizza']) {
        expect(find.textContaining(secret), findsNothing, reason: secret);
      }

      // Player 2, in private: empty fields, none of player 1's answers.
      await _reveal(tester);
      expect(_textField(tester, 'knowme-own-0').controller!.text, isEmpty);
      expect(_textField(tester, 'knowme-guess-0').controller!.text, isEmpty);
      expect(find.textContaining('Mansaf'), findsNothing);
      await tester.enterText(_field('knowme-own-0'), 'Tea');
      await tester.enterText(_field('knowme-guess-0'), 'mansaf');

      // The app leaves the foreground mid-turn: everything private goes …
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);
      expect(find.textContaining('mansaf'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      // … and comes back, as typed, once the player confirms it is still them.
      await _reveal(tester);
      expect(_textField(tester, 'knowme-own-0').controller!.text, 'Tea');
      expect(_textField(tester, 'knowme-guess-0').controller!.text, 'mansaf');
      await _tapKey(tester, 'knowme-page-next');
      await tester.enterText(_field('knowme-guess-1'), 'coffee');
      await _tapKey(tester, 'knowme-submit');

      // The reveal, together.
      expect(find.text('The reveal'), findsOneWidget);
      expect(env.secure.secure, isTrue);
      expect(find.text('Mansaf'), findsNothing, reason: 'face down until revealed');
      final next = find.byKey(const ValueKey('knowme-next'));
      expect(tester.widget<MadarButton>(next).onPressed, isNull);
      await _tapKey(tester, 'knowme-reveal-0-one');
      expect(find.text('Mansaf'), findsOneWidget);
      expect(find.text('mansaf'), findsOneWidget);
      await _tapKey(tester, 'knowme-reveal-0-two');
      // "Green tea" for "Tea": suggested close, still to judge.
      expect(tester.widget<MadarButton>(next).onPressed, isNull);
      await _tapKey(tester, 'knowme-judge-0-two-close');
      expect(tester.widget<MadarButton>(next).onPressed, isNotNull);
      await _tapKey(tester, 'knowme-next');
      await _tapKey(tester, 'knowme-reveal-1-one');
      await _tapKey(tester, 'knowme-reveal-1-two');
      expect(find.text('Skipped – not scored'), findsOneWidget);
      await _tapKey(tester, 'knowme-next');
      await settleTogether(tester);

      // Results: player two guessed 4 of 4, player one 1 of 2.
      expect(find.text('Results'), findsOneWidget);
      expect(find.textContaining('won'), findsWidgets);
      expect(find.text('4 of 4'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      final history = await tester.runAsync(() => env.repo.history());
      expect(history!.single.id, 'knowMe-rw1');
      expect(history.single.outcome, MatchOutcome.twoWon);
      expect((history.single.scoreOne, history.single.scoreTwo), (1, 4));
      // The first match ever: its trophy is celebrated.
      expect(find.text('New in our Hall of Fame!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('set-up: round size and first player; leaving asks only once something was typed', (tester) async {
      final env = await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: KnowMeScreen(random: math.Random(3)),
      );
      expect(find.text('How Well Do You Know Me?'), findsOneWidget);
      expect(find.text('60 questions'), findsOneWidget);
      await tester.tap(find.text('3').first);
      await settleTogether(tester);
      expect((await tester.runAsync(() => SpecialsRepository(env.db).prefs()))!.roundSize, 3);
      await tester.tap(find.text('Player 2').last);
      await tester.pumpAndSettle();
      await _tapKey(tester, 'knowme-start');
      expect(find.byType(KnowMeRoundScreen), findsOneWidget);
      final round = tester.widget<KnowMeRoundScreen>(find.byType(KnowMeRoundScreen)).round;
      expect(round.questions, hasLength(3));
      expect(round.first, PlayerSlot.two);

      // Nothing typed: closing leaves at once.
      await _tapKey(tester, 'knowme-close');
      expect(find.byType(KnowMeRoundScreen), findsNothing);

      // Something typed: closing asks first.
      await _tapKey(tester, 'knowme-start');
      await _reveal(tester);
      await tester.enterText(_field('knowme-own-0'), 'x');
      await _tapKey(tester, 'knowme-close');
      expect(find.text('Leave the round?'), findsOneWidget);
      await _tapKey(tester, 'knowme-stay');
      expect(find.byType(KnowMeRoundScreen), findsOneWidget);
      await _tapKey(tester, 'knowme-close');
      await _tapKey(tester, 'knowme-leave');
      expect(find.byType(KnowMeRoundScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the question bank: categories, add a question, restore', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const QuestionBankScreen());
      expect(find.text('Question bank'), findsOneWidget);
      expect(find.text("What's my favourite dish?"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bank-cat-habits')));
      await tester.pumpAndSettle();
      expect(find.text("What's the first thing I do after waking up?"), findsOneWidget);
      await _tapKey(tester, 'bank-add-question');
      await tester.enterText(find.byType(TextField).first, 'Which song do I hum the most?');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await settleTogether(tester);
      final bank = await tester.runAsync(() => SpecialsRepository(env.db).bank());
      final added = bank!.questions.where((q) => !q.isDefault).single;
      expect(added.category, 'habits');
      expect(added.text, 'Which song do I hum the most?');
      expect(bank.questionsIn('habits').last.id, added.id);
      await tester.scrollUntilVisible(find.text('Which song do I hum the most?'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Our own'), findsOneWidget);
      expect(find.byKey(const ValueKey('bank-restore')), findsNothing, reason: 'only additions: nothing to restore');
      await tester.runAsync(() => SpecialsRepository(env.db).updateBank((b) => b.deleteQuestion('habits.tea')));
      await settleTogether(tester);
      expect(find.byKey(const ValueKey('bank-restore')), findsOneWidget);
      await _tapKey(tester, 'bank-restore');
      await settleTogether(tester);
      expect((await tester.runAsync(() => SpecialsRepository(env.db).bank()))!.question('habits.tea'), isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('weekly challenge', () {
    testWidgets('both mark it done: done together, a streak; the challenge is then locked', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const WeeklyChallengeScreen());
      await settleTogether(tester);
      final repo = SpecialsRepository(env.db);
      final log = (await tester.runAsync(repo.log))!;
      expect(log.weeks, hasLength(1), reason: 'the week is pinned when shown');
      expect(find.text('Challenge of the week'), findsOneWidget);
      // Wednesday of a Saturday week: three days left, renews on Saturday.
      expect(find.textContaining('3 days left'), findsOneWidget);
      expect(find.textContaining('Renews on Saturday'), findsOneWidget);
      expect(find.text('Not started yet'), findsOneWidget);

      await _tapKey(tester, 'weekly-done-one');
      await settleTogether(tester);
      expect(find.textContaining(RegExp('Waiting for .*Player 2')), findsOneWidget);
      expect(tester.widget<MadarButton>(find.byKey(const ValueKey('weekly-another'))).onPressed, isNull);
      await _tapKey(tester, 'weekly-done-two');
      await settleTogether(tester);
      expect(find.text('Done together!'), findsOneWidget);
      final done = (await tester.runAsync(repo.log))!;
      expect((done.total, done.best), (1, 1));
      expect(find.text('×1'), findsWidgets);

      // Un-marking takes it back.
      await _tapKey(tester, 'weekly-done-two');
      await settleTogether(tester);
      expect((await tester.runAsync(repo.log))!.total, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('another challenge before anyone starts; the list screen', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const WeeklyChallengeScreen());
      await settleTogether(tester);
      final repo = SpecialsRepository(env.db);
      final before = (await tester.runAsync(repo.log))!.weeks.single.challengeId;
      await _tapKey(tester, 'weekly-another');
      await settleTogether(tester);
      final after = (await tester.runAsync(repo.log))!.weeks.single.challengeId;
      expect(after, isNot(before));
      await _tapKey(tester, 'weekly-list');
      expect(find.text('Our challenges'), findsOneWidget);
      expect(find.text('Walk together for half an hour'), findsOneWidget);
      await _tapKey(tester, 'challenge-toggle-walk');
      await settleTogether(tester);
      expect((await tester.runAsync(repo.challenges))!.byId('walk')!.hidden, isTrue);
      expect(find.text('Not in rotation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('cooperative goal', () {
    testWidgets('set a counter goal, reach it: the reward unlocks with a celebration', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const CoopGoalScreen());
      expect(find.text('No goal yet'), findsOneWidget);
      await _tapKey(tester, 'goal-set');
      // Saving without a reward is refused.
      await tester.tap(find.byKey(const ValueKey('goal-save')));
      await tester.pumpAndSettle();
      expect(find.text('Write the reward that waits for you'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('goal-reward-field')), 'Dinner by the sea');
      await tester.tap(find.text('Our own counter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('goal-unit-field')), 'walks');
      await tester.enterText(find.byKey(const ValueKey('goal-target-field')), '٣');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-save')));
      await settleTogether(tester);
      expect(find.text('Our goal'), findsWidgets);
      expect(find.text('/ 3 walks'), findsOneWidget);
      expect(find.text('Your reward is waiting'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await _tapKey(tester, 'goal-plus');
        await settleTogether(tester);
      }
      expect(find.byKey(const ValueKey('goal-unlocked-reward')), findsOneWidget);
      expect(find.text('Dinner by the sea'), findsWidgets);
      final board = (await tester.runAsync(() => SpecialsRepository(env.db).goals()))!;
      expect(board.active!.isUnlocked, isTrue);
      expect((await tester.runAsync(env.repo.trophies))!.hasAny(TrophyId.dreamCameTrue), isTrue);
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      // Then the trophy.
      expect(find.text('New in our Hall of Fame!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Together home', () {
    testWidgets('"Just the two of us" shows the three specials and opens them', (tester) async {
      await pumpTogetherApp(tester, locale: const Locale('en'), home: const TogetherHomeScreen());
      await settleTogether(tester);
      expect(find.text('Just the two of us'), findsOneWidget);
      expect(find.byKey(const ValueKey('specials-knowme')), findsOneWidget);
      expect(find.byKey(const ValueKey('specials-weekly')), findsOneWidget);
      expect(find.byKey(const ValueKey('specials-goal')), findsOneWidget);
      expect(find.text('Set a goal and a reward'), findsOneWidget);
      await _tapKey(tester, 'specials-weekly');
      expect(find.byType(WeeklyChallengeScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapKey(tester, 'specials-goal');
      expect(find.byType(CoopGoalScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
