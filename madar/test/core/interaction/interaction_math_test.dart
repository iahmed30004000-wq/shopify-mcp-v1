import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/interaction_math.dart';
import 'package:madar/core/motion/motion.dart';

void main() {
  group('SwipeMath', () {
    const width = 400.0;
    final threshold = SwipeMath.completeThreshold(width);
    double display(double raw, {bool complete = true, bool tray = true}) => SwipeMath.displayOffset(
      raw: raw,
      threshold: threshold,
      trayWidth: 150,
      canComplete: complete,
      hasTray: tray,
      width: width,
    );

    test('threshold is a third of the row, clamped to a thumb distance', () {
      expect(threshold, closeTo(136, 0.01));
      expect(SwipeMath.completeThreshold(100), 72);
      expect(SwipeMath.completeThreshold(1000), 140);
    });

    test('free movement up to the threshold / tray width', () {
      expect(display(50), 50);
      expect(display(threshold), threshold);
      expect(display(-120), -120);
    });

    test('rubber-bands beyond the threshold and never exceeds the dimension', () {
      final beyond = display(threshold + 200);
      expect(beyond, greaterThan(threshold));
      expect(beyond, lessThan(threshold + 200));
      expect(display(threshold + 100000), lessThan(threshold + width * 0.35));
      final left = display(-400);
      expect(left, lessThan(-150));
      expect(left, greaterThan(-400));
    });

    test('a side without an action barely moves', () {
      expect(display(200, complete: false), lessThan(28));
      expect(display(-200, tray: false), greaterThan(-28));
    });

    test('rubberBand is monotonic and bounded', () {
      var last = 0.0;
      for (var x = 1.0; x < 5000; x *= 2) {
        final v = SwipeMath.rubberBand(x, 60);
        expect(v, greaterThan(last));
        expect(v, lessThan(60));
        last = v;
      }
      expect(SwipeMath.rubberBand(0, 60), 0);
      expect(SwipeMath.rubberBand(-5, 60), 0);
    });

    test('completeProgress', () {
      expect(SwipeMath.completeProgress(threshold / 2, threshold), closeTo(0.5, 1e-9));
      expect(SwipeMath.completeProgress(-30, threshold), 0);
      expect(SwipeMath.completeProgress(10, 0), 0);
    });

    SwipeSettle settle(double d, double v, {bool complete = true, bool tray = true}) => SwipeMath.settle(
      display: d,
      velocity: v,
      threshold: threshold,
      trayWidth: 150,
      canComplete: complete,
      hasTray: tray,
    );

    test('settle: completes only past the threshold', () {
      expect(settle(threshold, 0), SwipeSettle.complete);
      expect(settle(threshold - 1, 2000), SwipeSettle.closed);
      expect(settle(threshold + 20, 0, complete: false), SwipeSettle.closed);
    });

    test('settle: tray opens past half-way or on a fling, closes on a reverse fling', () {
      expect(settle(-80, 0), SwipeSettle.openTray);
      expect(settle(-60, 0), SwipeSettle.closed);
      expect(settle(-30, -800), SwipeSettle.openTray);
      expect(settle(-140, 800), SwipeSettle.closed);
      expect(settle(-140, 0, tray: false), SwipeSettle.closed);
      expect(settle(0, 0), SwipeSettle.closed);
    });
  });

  group('ContextMenuLayout', () {
    const screen = Size(400, 800);
    const safe = EdgeInsets.only(top: 24, bottom: 16);
    const menu = Size(240, 260);

    test('below the item when there is room, aligned to the start edge (LTR)', () {
      final p = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(20, 100, 360, 64),
        menu: menu,
        screen: screen,
        safe: safe,
        direction: TextDirection.ltr,
      );
      expect(p.below, isTrue);
      expect(p.menuOffset, const Offset(20, 174));
      expect(p.itemOffset, const Offset(20, 100));
    });

    test('aligned to the right edge in RTL', () {
      final p = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(20, 100, 360, 64),
        menu: menu,
        screen: screen,
        safe: safe,
        direction: TextDirection.rtl,
      );
      expect(p.menuOffset.dx, 380 - 240);
    });

    test('above the item near the bottom of the screen', () {
      final p = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(20, 650, 360, 64),
        menu: menu,
        screen: screen,
        safe: safe,
        direction: TextDirection.ltr,
      );
      expect(p.below, isFalse);
      expect(p.menuOffset.dy, 650 - 10 - 260);
    });

    test('never leaves the safe area horizontally', () {
      final p = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(-50, 300, 100, 50),
        menu: menu,
        screen: screen,
        safe: safe,
        direction: TextDirection.ltr,
      );
      expect(p.menuOffset.dx, 12);
      final q = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(380, 300, 100, 50),
        menu: menu,
        screen: screen,
        safe: safe,
        direction: TextDirection.rtl,
      );
      expect(q.menuOffset.dx + menu.width, lessThanOrEqualTo(400 - 12));
    });

    test('a tall item and menu: menu pinned to the bottom, item lifted above it', () {
      final p = ContextMenuLayout.compute(
        item: const Rect.fromLTWH(20, 300, 360, 300),
        menu: const Size(240, 400),
        screen: screen,
        safe: safe,
        direction: TextDirection.ltr,
      );
      expect(p.menuOffset.dy + 400, lessThanOrEqualTo(800 - 16 - 12));
      expect(p.itemOffset.dy, lessThan(300));
      expect(p.itemOffset.dy, greaterThanOrEqualTo(24 + 12));
    });
  });

  group('reorderItems', () {
    test('moves an element (indexes already adjusted for removal)', () {
      expect(reorderItems(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
      expect(reorderItems(['a', 'b', 'c', 'd'], 3, 0), ['d', 'a', 'b', 'c']);
    });
    test('clamps and ignores out-of-range indexes; never mutates the input', () {
      final input = List.unmodifiable(['a', 'b']);
      expect(reorderItems(input, 0, 99), ['b', 'a']);
      expect(reorderItems(input, 5, 0), ['a', 'b']);
    });
  });

  group('InteractionSpringCurve', () {
    test('starts at 0, ends at 1 and overshoots for bouncy springs', () {
      final curve = InteractionSpringCurve(MadarMotion.bouncy);
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      final samples = [for (var i = 1; i < 100; i++) curve.transform(i / 100)];
      expect(samples.any((v) => v > 1.0), isTrue);
    });
    test('settle duration is bounded and longer for softer springs', () {
      final snappy = InteractionSpringCurve.settleSeconds(MadarMotion.snappy);
      final gentle = InteractionSpringCurve.settleSeconds(MadarMotion.gentle);
      expect(snappy, lessThan(gentle));
      expect(gentle, lessThanOrEqualTo(2.0));
      expect(snappy, greaterThanOrEqualTo(0.12));
    });
  });
}
