import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/together/together.dart';

import 'together_test_utils.dart';

/// A page with one button that opens [open] and keeps its result.
class _Launcher<T> extends StatefulWidget {
  const _Launcher(this.open, this.result);

  final Future<T?> Function(BuildContext context) open;
  final List<T?> result;

  @override
  State<_Launcher<T>> createState() => _LauncherState<T>();
}

class _LauncherState<T> extends State<_Launcher<T>> {
  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: '',
    body: Center(
      child: TextButton(
        key: const ValueKey('open'),
        onPressed: () async => widget.result.add(await widget.open(context)),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  group('Together home', () {
    testWidgets('empty (ar): generic players, invitation, trophies to earn', (tester) async {
      await pumpTogetherApp(tester, home: const TogetherHomeScreen());
      expect(find.text('معًا'), findsOneWidget);
      expect(find.text('اللاعب ١'), findsWidgets);
      expect(find.text('اللاعب ٢'), findsWidgets);
      expect(find.byKey(const ValueKey('together-empty')), findsOneWidget);
      expect(find.text('أول جائزة بانتظاركما'), findsOneWidget);
      expect(find.text('قاعة مجدنا'), findsOneWidget);
      expect(find.byType(TrophyMedal), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with history (en): score, leader, streaks, per game, recent matches', (tester) async {
      await pumpTogetherApp(tester, locale: const Locale('en'), home: const TogetherHomeScreen(), seed: seedTogetherHistory);
      expect(find.text('Together'), findsOneWidget);
      expect(find.textContaining('leads by'), findsOneWidget);
      expect(find.text('Head to head'), findsOneWidget);
      expect(find.byKey(const ValueKey('together-game-basra')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('together-match-seed-9')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent matches'), findsOneWidget);
      expect(find.byType(TogetherMatchTile), findsWidgets);
      expect(find.textContaining('Won together'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a game row opens that game\'s head-to-head history', (tester) async {
      await pumpTogetherApp(tester, locale: const Locale('en'), home: const TogetherHomeScreen(), seed: seedTogetherHistory);
      await tester.ensureVisible(find.byKey(const ValueKey('together-game-basra')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('together-game-basra')));
      await tester.pumpAndSettle();
      expect(find.byType(GameHistorySheet), findsOneWidget);
      // Three Basra matches, all won by player two; best score 104.
      expect(
        find.descendant(of: find.byType(GameHistorySheet), matching: find.byType(TogetherMatchTile)),
        findsNWidgets(3),
      );
      expect(find.text('Best: 104'), findsOneWidget);
      expect(find.text('Win streak ×3'), findsOneWidget);
    });

    testWidgets('editing a profile from the home avatar', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const TogetherHomeScreen());
      await tester.tap(find.byKey(const ValueKey('together-avatar-one')));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherProfileSheet), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('together-name-field')), 'Player Star');
      await tester.pump();
      await tester.tap(find.text('Emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🦉'));
      await tester.pump();
      await tester.ensureVisible(find.text('Quiz Whiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz Whiz'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('together-profile-save')));
      await settleTogether(tester);
      final saved = await tester.runAsync(() => env.repo.profiles());
      expect(saved!.one.name, 'Player Star');
      expect(saved.one.avatar.kind, AvatarKind.emoji);
      expect(saved.one.avatar.emoji, '🦉');
      expect(saved.one.title, PlayerTitle.quizWhiz);
      expect(find.text('Player Star'), findsWidgets);
    });

    testWidgets('the other player\'s colour cannot be taken', (tester) async {
      final env = await pumpTogetherApp(tester, locale: const Locale('en'), home: const TogetherHomeScreen());
      await tester.tap(find.byKey(const ValueKey('together-avatar-one')));
      await tester.pumpAndSettle();
      final taken = find.bySemanticsLabel(RegExp('Player 2.*colour'));
      await tester.ensureVisible(taken);
      await tester.tap(taken);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('together-profile-save')));
      await settleTogether(tester);
      final saved = await tester.runAsync(() => env.repo.profiles());
      expect(saved!.one.colorIndex, isNot(saved.two.colorIndex));
    });
  });

  group('launch sheet and mode picker', () {
    testWidgets('pass & play pre-selected; two phones are "coming soon"', (tester) async {
      final result = <GameLaunchChoice?>[];
      await pumpTogetherApp(
        tester,
        home: _Launcher<GameLaunchChoice>((c) => showGameLaunchSheet(c, game: TogetherGames.chess), result),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('شطرنج'), findsOneWidget);
      expect(find.byKey(const ValueKey('together-mode-passAndPlay')), findsOneWidget);
      expect(find.byKey(const ValueKey('together-mode-splitScreen')), findsNothing, reason: 'chess has no split screen');
      expect(find.text('قريبًا'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('together-mode-nearby')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('together-launch-start')));
      await tester.pumpAndSettle();
      expect(result.single, const GameLaunchChoice(mode: PlayMode.passAndPlay, firstPlayer: PlayerSlot.one));
      expect(result.single!.seating, [PlayerSlot.one, PlayerSlot.two]);
    });

    testWidgets('the settings default is used, the second player may start (en)', (tester) async {
      final result = <GameLaunchChoice?>[];
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        seed: (repo) => repo.saveSettings(const TogetherSettings(defaultMode: PlayMode.splitScreen, splitLayout: SplitLayout.sideBySide)),
        home: _Launcher<GameLaunchChoice>((c) => showGameLaunchSheet(c, game: TogetherGames.airHockey), result),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Air Hockey'), findsOneWidget);
      expect(find.text('Screen layout'), findsOneWidget);
      await tester.tap(find.text('Face to face'));
      await tester.pump();
      await tester.tap(find.text('Player 2').last);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('together-launch-start')));
      await tester.pumpAndSettle();
      final choice = result.single!;
      expect(choice.mode, PlayMode.splitScreen);
      expect(choice.splitLayout, SplitLayout.faceToFace);
      expect(choice.firstPlayer, PlayerSlot.two);
      expect(choice.seating, [PlayerSlot.two, PlayerSlot.one]);
    });

    testWidgets('a registered transport makes two phones available', (tester) async {
      final result = <GameLaunchChoice?>[];
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        overrides: [
          togetherTransportFactoriesProvider.overrideWithValue({
            PlayMode.nearby: (request) async => LoopbackLink().host,
          }),
        ],
        home: _Launcher<GameLaunchChoice>((c) => showGameLaunchSheet(c, game: TogetherGames.basra), result),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget, reason: 'online only');
      await tester.tap(find.byKey(const ValueKey('together-mode-nearby')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('together-launch-start')));
      await tester.pumpAndSettle();
      expect(result.single!.mode, PlayMode.nearby);
    });

    testWidgets('settings: default mode, layout, privacy; online stays off without a transport', (tester) async {
      final env = await pumpTogetherApp(
        tester,
        home: const MadarScaffold(
          title: '',
          body: Padding(padding: EdgeInsets.all(16), child: TogetherSettingsTile()),
        ),
      );
      expect(find.text('تمرير الهاتف'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-settings-tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('together-mode-splitScreen')));
      await settleTogether(tester);
      expect((await tester.runAsync(() => env.repo.settings()))!.defaultMode, PlayMode.splitScreen);
      final switches = find.byType(MadarSwitch);
      expect(switches, findsNWidgets(2));
      expect(tester.widget<MadarSwitch>(switches.last).onChanged, isNull, reason: 'online: coming soon');
      await tester.tap(switches.first);
      await settleTogether(tester);
      expect((await tester.runAsync(() => env.repo.settings()))!.hideInRecents, isFalse);
      expect(find.text(TogetherTexts.of(tester.element(switches.first)).l.togetherOnlyGameState), findsOneWidget);
    });
  });

  testWidgets('clearing history and trophies can be undone', (tester) async {
    final env = await pumpTogetherApp(
      tester,
      locale: const Locale('en'),
      home: const MadarScaffold(title: '', body: Padding(padding: EdgeInsets.all(16), child: TogetherSettingsTile())),
      seed: seedTogetherHistory,
    );
    await tester.tap(find.byKey(const ValueKey('together-settings-tile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('together-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('together-reset')));
    // The undo toast counts down: pump frames, do not settle it away.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await tester.runAsync(() => env.repo.history()), isEmpty);
    expect(find.text('History and trophies cleared'), findsOneWidget);
    await tester.tap(find.text('Undo').last);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    expect((await tester.runAsync(() => env.repo.history()))!, hasLength(10));
  });

  group('Hall of Fame', () {
    testWidgets('every trophy on the shelf, earned ones first, details on tap (ar)', (tester) async {
      await pumpTogetherApp(tester, home: const HallOfFameScreen(), seed: seedTogetherHistory);
      expect(find.text('قاعة مجدنا'), findsOneWidget);
      expect(find.byKey(const ValueKey('together-trophy-firstMatch')), findsOneWidget);
      final first = tester.getTopLeft(find.byKey(const ValueKey('together-trophy-firstMatch')));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('together-trophy-dayStreak30')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('together-trophy-dayStreak30')));
      await tester.pumpAndSettle();
      final locked = tester.getTopLeft(find.byKey(const ValueKey('together-trophy-dayStreak30')));
      final scrolled = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
      expect(locked.dy + scrolled, greaterThan(first.dy), reason: 'earned trophies come first');
      await tester.tap(find.byKey(const ValueKey('together-trophy-dayStreak30')));
      await tester.pumpAndSettle();
      expect(find.text('لم تُحصد بعد'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('new trophies are celebrated after a recorded match', (tester) async {
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: _Launcher<void>((c) async {
          final repo = ProviderScope.containerOf(c).read(togetherRepositoryProvider);
          final recorded = await repo.recordMatch(
            MatchRecord(id: 'x1', gameId: 'chess', endedAt: togetherNow, outcome: MatchOutcome.draw),
          );
          if (c.mounted) await celebrateNewTrophies(c, recorded);
        }, []),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await settleTogether(tester);
      expect(find.text('New in our Hall of Fame!'), findsOneWidget);
      expect(find.text('First Match'), findsOneWidget);
      expect(find.text('Neck and Neck'), findsOneWidget);
    });
  });
}
