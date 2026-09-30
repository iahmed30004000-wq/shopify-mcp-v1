import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';

/// A counter sim recording which ticks saw a one-shot event.
final class _Probe extends FixedStepSim<List<int>, bool> {
  _Probe() : super(hz: 60, maxTicksPerStep: 5);
  final List<int> events = [];

  @override
  ArcadeKind get kind => ArcadeKind.snake;
  @override
  List<int> get state => events;
  @override
  int get score => events.length;
  @override
  bool get isOver => false;
  @override
  bool heldOnly(bool input) => false;
  @override
  bool mergeInput(bool earlier, bool later) => earlier || later;
  @override
  void update(bool input) {
    if (input) events.add(tick);
  }

  @override
  Map<String, Object?> snapshot() => {'events': events};
}

void main() {
  group('fixed timestep', () {
    test('whole ticks from variable frames; alpha is the remainder', () {
      final p = _Probe();
      p.step(1 / 60, false);
      expect(p.tick, 1);
      p.step(0.5 / 60, false);
      expect(p.tick, 1);
      expect(p.alpha, closeTo(0.5, 1e-6));
      p.step(0.5 / 60, false);
      expect(p.tick, 2);
      p.step(3 / 60, false);
      expect(p.tick, 5);
    });

    test('one-shot inputs fire exactly once, even across short frames', () {
      final p = _Probe();
      p.step(0.3 / 60, true); // too short to tick: carried over
      expect(p.events, isEmpty);
      p.step(0.3 / 60, false);
      p.step(0.5 / 60, false); // tick runs with the carried event
      expect(p.events, [0]);
      p.step(4 / 60, true); // several ticks, the event only on the first
      expect(p.events, [0, 1]);
    });

    test('huge or invalid frames are clamped', () {
      final p = _Probe();
      p.step(10, false);
      expect(p.tick, 5, reason: 'maxTicksPerStep');
      p.step(double.nan, true);
      p.step(-1, false);
      expect(p.tick, 5);
    });
  });

  group('geometry', () {
    test('swept circle vs box matches fine sub-stepping', () {
      final rng = SeededRng(3);
      const box = Aabb(40, 40, 60, 50);
      for (var i = 0; i < 3000; i++) {
        final p = Vec2(rng.nextDoubleRange(0, 100), rng.nextDoubleRange(0, 100));
        final d = Vec2(rng.nextDoubleRange(-80, 80), rng.nextDoubleRange(-80, 80));
        const r = 3.0;
        final hit = sweepCircleAabb(p, d, r, box);
        // Brute force: first sample where the circle touches the box, and
        // the closest approach (grazing contacts are ambiguous: skipped).
        double? first;
        var closest = double.infinity;
        for (var k = 0; k <= 4000; k++) {
          final t = k / 4000;
          final c = p + d * t;
          final dist = (box.clamp(c) - c).length;
          if (dist < closest) closest = dist;
          if (first == null && dist <= r) first = t;
        }
        if ((closest - r).abs() < 0.02) continue;
        if (first == null) {
          expect(hit, isNull, reason: '$p $d');
        } else {
          expect(hit, isNotNull, reason: '$p $d');
          expect(hit!.t, closeTo(first, 0.002), reason: '$p $d');
          expect(hit.normal.length, closeTo(1, 1e-9));
        }
      }
    });

    test('ray vs circle, segments, wrap', () {
      expect(rayCircle(Vec2.zero, const Vec2(10, 0), const Vec2(5, 0), 1), closeTo(0.4, 1e-9));
      expect(rayCircle(Vec2.zero, const Vec2(10, 0), const Vec2(5, 3), 1), isNull);
      expect(segmentHitsCircle(Vec2.zero, const Vec2(10, 0), const Vec2(5, 0.9), 1), isTrue);
      expect(segmentHitsCircle(Vec2.zero, const Vec2(10, 0), const Vec2(12, 0), 1), isFalse);
      expect(wrapDelta(const Vec2(1, 1), const Vec2(99, 1), 100, 100).x, closeTo(-2, 1e-9));
      expect(wrapPoint(const Vec2(-1, 105), 100, 100), const Vec2(99, 5));
      expect(const Vec2(1, 0).rotate(math.pi / 2).y, closeTo(1, 1e-9));
      expect(const Vec2(3, -4).reflect(const Vec2(0, 1)), const Vec2(3, 4));
    });
  });
}
