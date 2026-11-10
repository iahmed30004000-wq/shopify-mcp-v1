import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/together/together.dart';

import 'together_test_utils.dart';

const _secretKey = ValueKey('secret-hand');

/// A pass-and-play table: the public board and the viewer's private hand.
class _Table extends StatelessWidget {
  const _Table({required this.controller});

  final HandOffController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HandOffGate(
      controller: controller,
      profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two),
      publicSummary: 'e4',
      privateBuilder: (context, participant) => Center(
        child: Text('hand of $participant: A♠ K♥', key: _secretKey),
      ),
    ),
  );
}

void main() {
  Finder secret() => find.byKey(_secretKey, skipOffstage: false);
  Finder secretText() => find.textContaining('A♠', skipOffstage: false);

  testWidgets('nothing private is in the tree before the reveal', (tester) async {
    final controller = HandOffController()..passTo(0);
    addTearDown(controller.dispose);
    final env = await pumpTogetherApp(tester, home: _Table(controller: controller));

    expect(find.byType(HandOffScreen), findsOneWidget);
    expect(secret(), findsNothing);
    expect(secretText(), findsNothing);
    expect(find.text('مرّر الهاتف إلى'), findsOneWidget);
    expect(find.textContaining('اللاعب ١'), findsWidgets);
    expect(find.text('آخر حركة: e4'), findsOneWidget);
    // Hidden from recents while the gate is up.
    expect(env.secure.secure, isTrue);

    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(secret(), findsOneWidget);
    expect(find.text('hand of 0: A♠ K♥'), findsOneWidget);
    expect(find.byType(HandOffScreen), findsNothing);

    // The turn passes: the hand is gone at once (not faded out underneath).
    controller.passTo(1);
    await tester.pump();
    expect(secret(), findsNothing);
    expect(secretText(), findsNothing);
    expect(find.byType(HandOffScreen), findsOneWidget);
    expect(find.textContaining('اللاعب ٢'), findsWidgets);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(find.text('hand of 1: A♠ K♥'), findsOneWidget);
  });

  testWidgets('leaving the app mid-turn hides the hand until the player confirms', (tester) async {
    final controller = HandOffController()..passTo(1);
    addTearDown(controller.dispose);
    await pumpTogetherApp(tester, home: _Table(controller: controller));
    controller.reveal();
    await tester.pumpAndSettle();
    expect(secret(), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(secret(), findsNothing, reason: 'the recents snapshot must not show the hand');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(secret(), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.phase, HandOffPhase.shielded);
    expect(secret(), findsNothing);
    expect(find.textContaining('هل ما زلت'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(secret(), findsOneWidget);
  });

  testWidgets('the gate follows a pass-and-play session turn by turn', (tester) async {
    final session = TogetherSession<RaceState, int>.local(adapter: const RaceGame());
    addTearDown(session.dispose);
    final env = await pumpTogetherApp(
      tester,
      locale: const Locale('en'),
      home: Scaffold(
        body: FollowingHandOffGate(
          activeParticipant: session.activeParticipant,
          profileOf: (p) => TogetherProfile.defaults(session.slotOf(p)),
          privateBuilder: (context, p) => Text('answer sheet of $p', key: _secretKey),
        ),
      ),
    );
    expect(secret(), findsNothing);
    await tester.runAsync(() => session.start(seed: 0));
    await tester.pumpAndSettle();
    expect(find.text('Pass the phone to'), findsOneWidget);
    expect(find.text('Player 1'), findsWidgets);
    expect(secret(), findsNothing);
    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(find.text('answer sheet of 0'), findsOneWidget);

    await tester.runAsync(() => session.play(1));
    await tester.pump();
    expect(secret(), findsNothing);
    expect(find.text('Player 2'), findsWidgets);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(find.text('answer sheet of 1'), findsOneWidget);
    expect(env.haptics.fired, isNotEmpty);
  });

  testWidgets('FLAG_SECURE is released when the gate goes and respects the setting', (tester) async {
    final controller = HandOffController()..passTo(0);
    addTearDown(controller.dispose);
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    final env = await pumpTogetherApp(
      tester,
      home: ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (context, v, _) => v ? _Table(controller: controller) : const SizedBox(),
      ),
    );
    expect(env.secure.calls, [true]);
    show.value = false;
    await tester.pumpAndSettle();
    expect(env.secure.calls, [true, false]);

    await tester.runAsync(() => env.repo.saveSettings(const TogetherSettings(hideInRecents: false)));
    await settleTogether(tester);
    show.value = true;
    await settleTogether(tester);
    expect(env.secure.secure, isFalse, reason: 'the user turned it off');
    expect(env.secure.calls.last, isFalse);
  });

  testWidgets('reduced motion: the hand-off screen and reveal still work', (tester) async {
    final controller = HandOffController()..passTo(0);
    addTearDown(controller.dispose);
    await pumpTogetherApp(tester, reducedMotion: true, home: _Table(controller: controller));
    expect(find.byType(HandOffScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await tester.pumpAndSettle();
    expect(secret(), findsOneWidget);
  });
}
