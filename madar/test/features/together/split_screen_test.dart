import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/together/together.dart';

import 'split_touch_harness.dart';
import 'together_test_utils.dart';

/// A half with a draggable paddle (GestureDetector – in the arena) and a
/// button, recording what it received.
class _Probe extends StatelessWidget {
  const _Probe({required this.half, required this.log});

  final SplitHalf half;
  final Map<int, List<String>> log;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    log.putIfAbsent(half.participant, () => []).add('pad:${pad.top},${pad.bottom},${pad.left},${pad.right}');
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => log[half.participant]!.add('panStart'),
          onPanUpdate: (d) => log[half.participant]!.add('pan:${d.delta.dx.round()},${d.delta.dy.round()}'),
          onPanEnd: (_) => log[half.participant]!.add('panEnd'),
          onPanCancel: () => log[half.participant]!.add('panCancel'),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 80,
            height: 60,
            child: GestureDetector(
              key: ValueKey('button-${half.participant}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => log[half.participant]!.add('tap'),
            ),
          ),
        ),
      ],
    );
  }
}

void main() {
  Future<(Map<int, List<String>>, List<SplitTouch>)> pumpArena(
    WidgetTester tester, {
    SplitLayout layout = SplitLayout.faceToFace,
    Size size = const Size(412, 915),
    EdgeInsets padding = EdgeInsets.zero,
    TextDirection direction = TextDirection.ltr,
  }) async {
    final log = <int, List<String>>{};
    final touches = <SplitTouch>[];
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = FakeViewPadding(
      left: padding.left * 2,
      top: padding.top * 2,
      right: padding.right * 2,
      bottom: padding.bottom * 2,
    );
    addTearDown(tester.view.reset);
    final (app, _) = await buildTogetherApp(
      tester,
      locale: direction == TextDirection.rtl ? const Locale('ar') : const Locale('en'),
      home: Scaffold(
        body: SplitScreenArena(
          layout: layout,
          onTouch: touches.add,
          halfBuilder: (context, half) => _Probe(half: half, log: log),
          hudBuilder: (context, half) => Align(
            alignment: Alignment.bottomCenter,
            child: Text('hud ${half.participant}', key: ValueKey('hud-${half.participant}')),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    return (log, touches);
  }

  testWidgets('simultaneous drags in both halves are independent – no stealing', (tester) async {
    final (log, touches) = await pumpArena(tester);
    final harness = SplitTouchHarness(tester);
    await harness.simultaneousDrags([
      const SplitPath(0, Offset(0.2, 0.7), Offset(0.8, 0.7)),
      // Same path in the far player's own frame: opposite on screen.
      const SplitPath(1, Offset(0.2, 0.7), Offset(0.8, 0.7)),
    ]);
    for (final p in [0, 1]) {
      final events = log[p]!.where((e) => !e.startsWith('pad:')).toList();
      expect(events.first, 'panStart', reason: 'half $p');
      expect(events.last, 'panEnd', reason: 'half $p');
      expect(events, isNot(contains('panCancel')));
      // Each half sees its own finger moving to its player's right.
      final dx = events.where((e) => e.startsWith('pan:')).map((e) => int.parse(e.substring(4).split(',').first));
      expect(dx.fold<int>(0, (s, v) => s + v), greaterThan(150), reason: 'half $p');
    }
    // Raw touches: both halves, their own pointers, in their own frame.
    final byHalf = {
      for (final p in [0, 1]) p: touches.where((t) => t.participant == p).toList(),
    };
    expect(byHalf[0]!.first.phase, SplitTouchPhase.down);
    expect(byHalf[1]!.first.phase, SplitTouchPhase.down);
    expect(byHalf[0]!.map((t) => t.pointer).toSet().intersection(byHalf[1]!.map((t) => t.pointer).toSet()), isEmpty);
    expect(byHalf[1]!.first.normalized.dx, closeTo(0.2, 0.02));
    expect(byHalf[1]!.last.normalized.dx, closeTo(0.8, 0.02));
    expect(byHalf[1]!.first.normalized.dy, closeTo(0.7, 0.02));
    expect(byHalf[0]!.last.phase, SplitTouchPhase.up);
    expect(byHalf[1]!.last.phase, SplitTouchPhase.up);
  });

  testWidgets('simultaneous taps land in both halves', (tester) async {
    final (log, _) = await pumpArena(tester);
    // The buttons sit at the top of each half, as its player sees it.
    await SplitTouchHarness(tester).simultaneousTaps([(0, const Offset(0.5, 0.05)), (1, const Offset(0.5, 0.05))]);
    expect(log[0], contains('tap'));
    expect(log[1], contains('tap'));
  });

  testWidgets('the far half is turned 180°: its own "bottom" is the device top', (tester) async {
    final (_, touches) = await pumpArena(tester);
    // Touch near the physical top edge, then near the physical bottom edge.
    await tester.tapAt(const Offset(100, 10));
    await tester.tapAt(const Offset(100, 905));
    final far = touches.firstWhere((t) => t.participant == 1 && t.phase == SplitTouchPhase.down);
    final near = touches.firstWhere((t) => t.participant == 0 && t.phase == SplitTouchPhase.down);
    expect(far.normalized.dy, greaterThan(0.95), reason: 'physical top = far player bottom');
    expect(far.normalized.dx, greaterThan(0.7), reason: 'physical left = far player right');
    expect(near.normalized.dy, greaterThan(0.95));
    expect(near.normalized.dx, lessThan(0.3));
    // Upside-down HUD: the far HUD is drawn above the near one on screen,
    // near the far player's own bottom (the device top).
    final farHud = tester.getCenter(find.byKey(const ValueKey('hud-1')));
    final nearHud = tester.getCenter(find.byKey(const ValueKey('hud-0')));
    expect(farHud.dy, lessThan(60));
    expect(nearHud.dy, greaterThan(855));
  });

  testWidgets('a finger sliding over the midline stays with its half, clamped', (tester) async {
    final (_, touches) = await pumpArena(tester);
    final g = await tester.startGesture(const Offset(200, 800), pointer: 7);
    await g.moveTo(const Offset(200, 300)); // deep into the far half
    await g.moveTo(const Offset(200, 100));
    await g.up();
    await tester.pump();
    final mine = touches.where((t) => t.pointer == 7).toList();
    expect(mine.every((t) => t.participant == 0), isTrue);
    expect(mine.last.normalized.dy, 0, reason: 'clamped to the top of its own half');
  });

  testWidgets('per-half safe areas: the notch is the far player bottom inset', (tester) async {
    final (log, _) = await pumpArena(tester, padding: const EdgeInsets.only(top: 40, bottom: 24, left: 5, right: 9));
    // near: top 0 (midline), bottom 24, left 5, right 9
    expect(log[0]!.firstWhere((e) => e.startsWith('pad:')), 'pad:0.0,24.0,5.0,9.0');
    // far (turned 180°): top 0, bottom = device top 40, left = device right 9
    expect(log[1]!.firstWhere((e) => e.startsWith('pad:')), 'pad:0.0,40.0,9.0,5.0');
  });

  testWidgets('side by side (RTL): player 0 at the reading start, both upright', (tester) async {
    final (_, touches) = await pumpArena(
      tester,
      layout: SplitLayout.sideBySide,
      size: const Size(915, 412),
      direction: TextDirection.rtl,
    );
    await tester.tapAt(const Offset(850, 200));
    await tester.tapAt(const Offset(60, 200));
    expect(touches.firstWhere((t) => t.phase == SplitTouchPhase.down).participant, 0);
    expect(touches.lastWhere((t) => t.phase == SplitTouchPhase.down).participant, 1);
    expect(touches.first.normalized.dy, closeTo(200 / 412, 0.02));
  });

  testWidgets('end to end: each half turned towards its short edge', (tester) async {
    final (log, touches) = await pumpArena(
      tester,
      layout: SplitLayout.endToEnd,
      size: const Size(915, 412),
      padding: const EdgeInsets.only(left: 30),
    );
    // Near the physical left edge = the left (participant 0 in LTR) player's bottom.
    await tester.tapAt(const Offset(5, 206));
    final t = touches.firstWhere((t) => t.phase == SplitTouchPhase.down);
    expect(t.participant, 0);
    expect(t.normalized.dy, greaterThan(0.95));
    expect(t.normalized.dx, closeTo(0.5, 0.02));
    // The left cut-out is that player's bottom inset.
    expect(log[0]!.firstWhere((e) => e.startsWith('pad:')), 'pad:0.0,30.0,0.0,0.0');
    expect(SplitScreenArena.quarterTurnsFor(SplitLayout.endToEnd, 0, physicalLeft: true), 1);
  });

  test('insets rotate with the half', () {
    const p = EdgeInsets.fromLTRB(1, 2, 3, 4);
    expect(SplitScreenArena.rotateInsets(p, 0), p);
    expect(SplitScreenArena.rotateInsets(p, 2), const EdgeInsets.fromLTRB(3, 4, 1, 2));
    expect(SplitScreenArena.rotateInsets(p, 1), const EdgeInsets.fromLTRB(2, 3, 4, 1));
    expect(SplitScreenArena.rotateInsets(p, 3), const EdgeInsets.fromLTRB(4, 1, 2, 3));
  });
}
