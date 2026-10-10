import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/motion/springs.dart';

import 'motion_test_utils.dart';

void main() {
  group('SpringMotion', () {
    for (final (name, spring) in [
      ('gentle', MadarMotion.gentle),
      ('snappy', MadarMotion.snappy),
      ('bouncy', MadarMotion.bouncy),
      ('cinematic', MadarMotion.cinematicSpring),
    ]) {
      test('$name converges to its target and comes to rest', () {
        final m = SpringMotion(spring: spring)..retarget(100, time: 0);
        expect(m.isAtRest, isFalse);
        var t = 0.0;
        while (!m.isAtRest && t < 10) {
          t += 1 / 120;
          m.advanceTo(t);
        }
        expect(m.isAtRest, isTrue, reason: 'settled after ${t.toStringAsFixed(2)} s');
        expect(t, lessThan(3));
        expect(m.value, 100);
        expect(m.velocity, 0);
      });
    }

    test('retargeting mid-flight keeps position and velocity continuous', () {
      final m = SpringMotion(spring: MadarMotion.snappy)..retarget(1, time: 0);
      m.advanceTo(0.05);
      final x = m.value;
      final v = m.velocity;
      expect(v, greaterThan(0));

      m.retarget(-1, time: 0.05);
      expect(m.value, x);
      expect(m.velocity, v);

      // A hair later the velocity has only changed by acceleration·dt (a
      // restart from rest would have lost all of v).
      m.advanceTo(0.05 + 1e-4);
      expect(v, greaterThan(2));
      expect((m.velocity - v).abs(), lessThan(0.5));
      expect((m.value - x).abs(), lessThan(v * 1e-4 * 1.5));
      // …and it keeps travelling in the old direction before turning back.
      m.advanceTo(0.05 + 1 / 120);
      expect(m.value, greaterThan(x));

      var t = 0.05;
      while (!m.isAtRest && t < 5) {
        t += 1 / 120;
        m.advanceTo(t);
      }
      expect(m.value, -1);
    });

    test('retarget with explicit velocity (fling)', () {
      final m = SpringMotion(spring: MadarMotion.gentle)..retarget(0, velocity: 10, time: 0);
      expect(m.isAtRest, isFalse);
      m.advanceTo(0.05);
      expect(m.value, greaterThan(0));
    });

    test('retarget to the current resting value is a no-op', () {
      final m = SpringMotion(spring: MadarMotion.gentle, value: 3)..retarget(3, time: 0);
      expect(m.isAtRest, isTrue);
      expect(m.value, 3);
    });

    test('changing the spring keeps the state', () {
      final m = SpringMotion(spring: MadarMotion.gentle)..retarget(1, time: 0);
      m.advanceTo(0.1);
      final x = m.value;
      final v = m.velocity;
      m.spring = MadarMotion.bouncy;
      expect(m.value, x);
      expect(m.velocity, v);
      expect(m.target, 1);
    });

    test('jumpTo stops immediately', () {
      final m = SpringMotion(spring: MadarMotion.gentle)..retarget(1, time: 0);
      m.jumpTo(0.4);
      expect(m.isAtRest, isTrue);
      expect(m.value, 0.4);
      expect(m.target, 0.4);
    });
  });

  group('SpringCurve', () {
    test('maps 0 → 0 and 1 → 1 and settles in a sensible time', () {
      final c = SpringCurve(MadarMotion.gentle);
      expect(c.transform(0), 0);
      expect(c.transform(1), 1);
      expect(c.transform(0.5), greaterThan(0.5));
      expect(c.settleDuration, greaterThan(const Duration(milliseconds: 200)));
      expect(c.settleDuration, lessThan(const Duration(milliseconds: 900)));
    });

    test('bouncy spring overshoots', () {
      final c = SpringCurve(MadarMotion.bouncy);
      var peak = 0.0;
      for (var t = 0.0; t <= 1; t += 0.01) {
        final v = c.transform(t);
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(1.05));
    });
  });

  group('SpringValue', () {
    testWidgets('animates to the target and notifies status', (tester) async {
      final v = SpringValue(vsync: tester, spring: MadarMotion.snappy);
      final statuses = <AnimationStatus>[];
      v.addStatusListener(statuses.add);
      v.animateTo(1);
      expect(v.isAnimating, isTrue);
      expect(v.status, AnimationStatus.forward);
      await pumpFrames(tester, 90);
      expect(v.value, 1);
      expect(v.isAnimating, isFalse);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
      v.dispose();
    });

    testWidgets('retargeting preserves velocity', (tester) async {
      final v = SpringValue(vsync: tester, spring: MadarMotion.gentle);
      v.animateTo(1);
      await pumpFrames(tester, 6);
      final before = v.velocity;
      final x = v.value;
      expect(before, greaterThan(0));
      v.animateTo(-1);
      expect(v.velocity, before);
      expect(v.value, x);
      await pumpFrames(tester, 200);
      expect(v.value, -1);
      v.dispose();
    });

    testWidgets('delay holds the value still', (tester) async {
      final v = SpringValue(vsync: tester);
      v.animateTo(1, delay: const Duration(milliseconds: 200));
      await pumpFrames(tester, 10);
      expect(v.value, 0);
      await pumpFrames(tester, 20);
      expect(v.value, greaterThan(0));
      await pumpFrames(tester, 120);
      expect(v.value, 1);
      v.dispose();
    });

    testWidgets('jumpTo stops the ticker', (tester) async {
      final v = SpringValue(vsync: tester);
      v.animateTo(1);
      await tester.pump(const Duration(milliseconds: 16));
      v.jumpTo(0.25);
      expect(v.isAnimating, isFalse);
      expect(v.value, 0.25);
      v.dispose();
    });

    testWidgets('SpringOffsetValue converges on both axes', (tester) async {
      final v = SpringOffsetValue(vsync: tester);
      v.animateTo(const Offset(120, -40));
      await pumpFrames(tester, 150);
      expect(v.value, const Offset(120, -40));
      expect(v.isAnimating, isFalse);
      v.dispose();
    });
  });

  group('SpringBuilder', () {
    testWidgets('springs from → value and retargets', (tester) async {
      final seen = <double>[];
      Widget build(double value) => motionApp(
        SpringBuilder(
          from: 0,
          value: value,
          builder: (context, v, _) {
            seen.add(v);
            return Text(v.toStringAsFixed(2));
          },
        ),
      );
      await tester.pumpWidget(build(1));
      await pumpFrames(tester, 5);
      expect(seen.last, inExclusiveRange(0, 1));
      await tester.pumpWidget(build(2));
      await tester.pumpAndSettle();
      expect(seen.last, 2);
    });

    testWidgets('reduced motion jumps', (tester) async {
      await tester.pumpWidget(
        motionApp(reduced: true, SpringBuilder(from: 0, value: 1, builder: (context, v, _) => Text('v=$v'))),
      );
      expect(find.text('v=1.0'), findsOneWidget);
    });

    testWidgets('SpringOffsetBuilder settles on the target', (tester) async {
      Offset? last;
      await tester.pumpWidget(
        motionApp(
          SpringOffsetBuilder(
            from: Offset.zero,
            value: const Offset(10, 20),
            spring: SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1),
            builder: (context, o, _) {
              last = o;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(last, const Offset(10, 20));
    });
  });
}
