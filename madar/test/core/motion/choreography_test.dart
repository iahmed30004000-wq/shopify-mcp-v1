import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/choreography.dart';
import 'package:madar/core/motion/motion.dart';

import 'motion_test_utils.dart';

Widget _items({int count = 4}) => StaggerIn(
  children: [for (var i = 0; i < count; i++) SizedBox(height: 40, child: Center(child: Text('item $i')))],
);

double _opacityOf(WidgetTester tester, String text) {
  final opacity = tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first);
  return opacity.opacity;
}

void main() {
  group('EntranceTiming', () {
    test('stagger delays step and cap', () {
      expect(EntranceTiming.delayFor(0), Duration.zero);
      expect(EntranceTiming.delayFor(1), MadarMotion.staggerStep);
      expect(EntranceTiming.delayFor(3), MadarMotion.staggerStep * 3);
      expect(EntranceTiming.delayFor(500), MadarMotion.staggerCap);
      expect(EntranceTiming.delayFor(-2), Duration.zero);
    });

    test('spring progress starts at 0, rises and lands on 1', () {
      expect(EntranceTiming.progress(0), 0);
      expect(EntranceTiming.progress(-1), 0);
      expect(EntranceTiming.progress(0.05), inExclusiveRange(0, 1));
      expect(EntranceTiming.progress(0.1), greaterThan(EntranceTiming.progress(0.05)));
      expect(EntranceTiming.progress(EntranceTiming.settleSeconds), 1);
      expect(EntranceTiming.settleSeconds, lessThan(0.8));
    });

    test('reduced progress is a quick linear fade', () {
      expect(EntranceTiming.reducedProgress(0), 0);
      expect(EntranceTiming.reducedProgress(0.045), closeTo(0.5, 0.01));
      expect(EntranceTiming.reducedProgress(1), 1);
    });
  });

  group('EntranceFrame', () {
    test('slides in from the reading-direction start', () {
      final ltr = EntranceFrame.at(0, textDirection: TextDirection.ltr);
      final rtl = EntranceFrame.at(0, textDirection: TextDirection.rtl);
      expect(ltr.offset.dx, -18);
      expect(rtl.offset.dx, 18);
      expect(ltr.scale, 0.98);
      expect(ltr.blurSigma, 6);
      expect(ltr.opacity, 0);
    });

    test('end / top / bottom', () {
      expect(EntranceFrame.at(0, textDirection: TextDirection.ltr, from: EntranceFrom.end).offset.dx, 18);
      expect(EntranceFrame.at(0, textDirection: TextDirection.rtl, from: EntranceFrom.end).offset.dx, -18);
      expect(EntranceFrame.at(0, textDirection: TextDirection.ltr, from: EntranceFrom.top).offset.dy, -18);
      expect(EntranceFrame.at(0, textDirection: TextDirection.ltr, from: EntranceFrom.bottom).offset.dy, 18);
    });

    test('settles at 1 and fade frames never move', () {
      expect(EntranceFrame.at(1, textDirection: TextDirection.ltr).isSettled, isTrue);
      final f = EntranceFrame.fade(0.4);
      expect(f.offset, Offset.zero);
      expect(f.scale, 1);
      expect(f.blurSigma, 0);
      expect(f.opacity, 0.4);
    });

    test('blur clears before the motion ends', () {
      final mid = EntranceFrame.at(0.6, textDirection: TextDirection.ltr);
      expect(mid.blurSigma, lessThan(1.0));
      expect(mid.opacity, greaterThan(0.6));
    });
  });

  group('StaggerIn', () {
    for (final dir in TextDirection.values) {
      testWidgets('enters from the start side in $dir and settles in place', (tester) async {
        await tester.pumpWidget(motionApp(direction: dir, Scaffold(body: _items())));
        await tester.pump(const Duration(milliseconds: 40));
        final mid = tester.getCenter(find.text('item 0'));
        await tester.pumpAndSettle();
        final end = tester.getCenter(find.text('item 0'));
        if (dir == TextDirection.ltr) {
          expect(mid.dx, lessThan(end.dx), reason: 'LTR start is the left');
        } else {
          expect(mid.dx, greaterThan(end.dx), reason: 'RTL start is the right');
        }
        expect(_opacityOf(tester, 'item 0'), 1);
        expect(_opacityOf(tester, 'item 3'), 1);
        expect(find.byType(ImageFiltered), findsWidgets);
        final filters = tester.widgetList<ImageFiltered>(find.byType(ImageFiltered));
        expect(filters.every((f) => !f.enabled), isTrue, reason: 'no blur once settled');
      });
    }

    testWidgets('later items start later', (tester) async {
      await tester.pumpWidget(motionApp(Scaffold(body: _items(count: 6))));
      await tester.pump(const Duration(milliseconds: 60));
      final first = _opacityOf(tester, 'item 0');
      final later = _opacityOf(tester, 'item 5');
      expect(first, greaterThan(later));
      await tester.pumpAndSettle();
    });

    testWidgets('long lists are capped by staggerCap', (tester) async {
      await tester.pumpWidget(motionApp(Scaffold(body: SingleChildScrollView(child: _items(count: 30)))));
      final cap = MadarMotion.staggerCap.inMilliseconds;
      final settle = (EntranceTiming.settleSeconds * 1000).ceil();
      await tester.pump(Duration(milliseconds: cap + settle + 32));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacityOf(tester, 'item 29'), 1);
    });

    testWidgets('reduced motion: a quick fade, nothing moves', (tester) async {
      await tester.pumpWidget(motionApp(reduced: true, Scaffold(body: _items())));
      final end = tester.getCenter(find.text('item 2'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getCenter(find.text('item 2')), end);
      final o = _opacityOf(tester, 'item 2');
      expect(o, inExclusiveRange(0, 1));
      expect(_opacityOf(tester, 'item 0'), o, reason: 'no stagger under reduced motion');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacityOf(tester, 'item 2'), 1);
    });

    testWidgets('keeps Expanded children working', (tester) async {
      await tester.pumpWidget(
        motionApp(
          Scaffold(
            body: SizedBox(
              height: 300,
              child: StaggerIn(
                mainAxisSize: MainAxisSize.max,
                children: const [
                  SizedBox(height: 50, child: Text('head')),
                  Expanded(child: Text('body')),
                  Spacer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.ancestor(of: find.text('body'), matching: find.byType(Flexible))).height, 125);
    });

    testWidgets('child state survives the entrance', (tester) async {
      final key = GlobalKey<_CounterState>();
      await tester.pumpWidget(
        motionApp(
          Scaffold(
            body: StaggerIn(children: [_Counter(key: key)]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      key.currentState!.increment();
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);
    });
  });

  group('EntranceChoreo', () {
    testWidgets('items built after the entrance appear settled', (tester) async {
      await tester.pumpWidget(
        motionApp(
          Scaffold(
            body: EntranceChoreo(
              child: ListView.builder(
                itemCount: 200,
                itemExtent: 60,
                itemBuilder: (context, i) => StaggerItem(index: i, child: Text('row $i')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      final visible = find.textContaining('row 5');
      expect(visible, findsWidgets);
      final row = tester.widgetList<Text>(find.textContaining('row ')).first.data!;
      expect(_opacityOf(tester, row), 1);
    });

    testWidgets('plays once per route when given an id', (tester) async {
      Widget page(bool show) => Scaffold(
        body: show
            ? const EntranceChoreo(
                id: 'today',
                child: StaggerItem(index: 0, child: Text('hello')),
              )
            : const SizedBox(),
      );
      await tester.pumpWidget(motionApp(page(true)));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_opacityOf(tester, 'hello'), lessThan(1));
      await tester.pumpAndSettle();

      // Rebuilt from scratch in the same route: no replay.
      await tester.pumpWidget(motionApp(page(false)));
      await tester.pumpWidget(motionApp(page(true)));
      expect(_opacityOf(tester, 'hello'), 1);
    });

    testWidgets('does not start while tickers are disabled', (tester) async {
      Widget app(bool enabled) => motionApp(
        Scaffold(
          body: TickerMode(
            enabled: enabled,
            child: const EntranceChoreo(child: StaggerItem(index: 0, child: Text('later'))),
          ),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pump(const Duration(seconds: 2));
      expect(_opacityOf(tester, 'later'), 0);
      await tester.pumpWidget(app(true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_opacityOf(tester, 'later'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'later'), 1);
    });

    testWidgets('enabled: false shows everything settled', (tester) async {
      await tester.pumpWidget(
        motionApp(
          const Scaffold(
            body: EntranceChoreo(enabled: false, child: StaggerItem(index: 3, child: Text('now'))),
          ),
        ),
      );
      expect(_opacityOf(tester, 'now'), 1);
    });
  });

  group('AnimatedReveal', () {
    testWidgets('appears, hides and ignores pointers when hidden', (tester) async {
      var taps = 0;
      Widget build(bool visible) => motionApp(
        Scaffold(
          body: Center(
            child: AnimatedReveal(
              visible: visible,
              child: GestureDetector(onTap: () => taps++, child: const Text('reveal')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_opacityOf(tester, 'reveal'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'reveal'), 1);
      await tester.tap(find.text('reveal'));
      expect(taps, 1);

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'reveal'), 0);
      await tester.tap(find.text('reveal'), warnIfMissed: false);
      expect(taps, 1);
    });

    testWidgets('respects its delay', (tester) async {
      await tester.pumpWidget(
        motionApp(
          const Scaffold(
            body: AnimatedReveal(delay: Duration(milliseconds: 200), child: Text('late')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacityOf(tester, 'late'), 0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'late'), 1);
    });

    testWidgets('reduced motion: fade only', (tester) async {
      await tester.pumpWidget(
        motionApp(
          reduced: true,
          const Scaffold(
            body: Center(child: AnimatedReveal(child: Text('r'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final end = tester.getCenter(find.text('r'));
      await tester.pumpWidget(
        motionApp(
          reduced: true,
          const Scaffold(
            body: Center(child: AnimatedReveal(visible: false, child: Text('r'))),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getCenter(find.text('r')), end);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(_opacityOf(tester, 'r'), 0);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Text('count $count');
}
