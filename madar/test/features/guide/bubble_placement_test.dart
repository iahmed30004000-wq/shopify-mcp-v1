import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/guide/guide.dart';

const _screen = Size(360, 760);
const _bubble = Size(300, 160);
const _safe = EdgeInsets.fromLTRB(0, 24, 0, 16);

BubblePlacement _place(Rect? target, {TextDirection dir = TextDirection.ltr, double keyboard = 0, Size bubble = _bubble}) =>
    BubbleGeometry.place(target: target, screen: _screen, bubble: bubble, direction: dir, safe: _safe, keyboard: keyboard);

/// The area a bubble must stay inside (margin 16 from the safe area).
Rect _area({double keyboard = 0}) => Rect.fromLTRB(16, 24 + 16, 360 - 16, 760 - (keyboard > 16 ? keyboard : 16) - 16);

void main() {
  group('targets in the four corners, both directions', () {
    final corners = <String, Rect>{
      'top-left': const Rect.fromLTWH(8, 40, 48, 48),
      'top-right': const Rect.fromLTWH(304, 40, 48, 48),
      'bottom-left': const Rect.fromLTWH(8, 690, 48, 48),
      'bottom-right': const Rect.fromLTWH(304, 690, 48, 48),
    };
    for (final dir in TextDirection.values) {
      for (final c in corners.entries) {
        test('${c.key} ${dir.name}: on screen, off the target, on the roomy side', () {
          final p = _place(c.value, dir: dir);
          final area = _area();
          expect(p.rect.left, greaterThanOrEqualTo(area.left));
          expect(p.rect.right, lessThanOrEqualTo(area.right));
          expect(p.rect.top, greaterThanOrEqualTo(area.top));
          expect(p.rect.bottom, lessThanOrEqualTo(area.bottom));
          expect(p.rect.overlaps(c.value), isFalse);
          expect(p.overlapsTarget, isFalse);
          expect(p.spotlight, c.value);
          expect(p.side, c.key.startsWith('top') ? BubbleSide.below : BubbleSide.above);
          // A gap of at least 12 between bubble and target.
          final gap = p.side == BubbleSide.below ? p.rect.top - c.value.bottom : c.value.top - p.rect.bottom;
          expect(gap, greaterThanOrEqualTo(12));
        });
      }
    }

    test('a narrow target is centred on when it fits, clamped at the edges', () {
      final mid = _place(const Rect.fromLTWH(156, 300, 48, 48));
      expect(mid.rect.center.dx, closeTo(180, 0.01));
      final left = _place(corners['top-left']);
      expect(left.rect.left, 16);
      final right = _place(corners['top-right']);
      expect(right.rect.right, 360 - 16);
    });
  });

  group('direction', () {
    const wide = Rect.fromLTWH(30, 300, 310, 60);

    test('a target wider than the bubble lines up with its start edge: left in LTR, right in RTL', () {
      final ltr = _place(wide, dir: TextDirection.ltr);
      final rtl = _place(wide, dir: TextDirection.rtl);
      expect(ltr.rect.left, 30);
      expect(rtl.rect.right, 340);
      expect(ltr.rect.left, isNot(rtl.rect.left));
    });

    test('same vertical decision in both directions', () {
      expect(_place(wide, dir: TextDirection.ltr).side, _place(wide, dir: TextDirection.rtl).side);
    });
  });

  group('the keyboard', () {
    test('lowers the floor: a target near the bottom gets the bubble above it', () {
      const target = Rect.fromLTWH(100, 330, 160, 48);
      expect(_place(target).side, BubbleSide.below);
      final p = _place(target, keyboard: 420);
      expect(p.side, BubbleSide.above);
      expect(p.rect.bottom, lessThanOrEqualTo(_area(keyboard: 420).bottom));
      expect(p.rect.overlaps(target), isFalse);
    });

    test('the bubble never reaches into the keyboard', () {
      const target = Rect.fromLTWH(100, 100, 160, 48);
      final p = _place(target, keyboard: 420, bubble: const Size(300, 260));
      expect(p.rect.bottom, lessThanOrEqualTo(760 - 420 - 16));
    });

    test('a target hidden behind the keyboard: no spotlight, bubble centred in what is visible', () {
      const target = Rect.fromLTWH(100, 600, 160, 48);
      final p = _place(target, keyboard: 420);
      expect(p.spotlight, isNull);
      expect(p.side, BubbleSide.center);
      final area = _area(keyboard: 420);
      expect(p.rect.bottom, lessThanOrEqualTo(area.bottom));
      expect(p.rect.top, greaterThanOrEqualTo(area.top));
    });

    test('a target half behind the keyboard is clipped to the visible part', () {
      const target = Rect.fromLTWH(100, 320, 160, 80);
      final p = _place(target, keyboard: 400);
      expect(p.spotlight!.bottom, 360);
      expect(p.rect.overlaps(p.spotlight!), isFalse);
    });
  });

  group('no room', () {
    test('a tall bubble beside a middle target takes the roomier side and shrinks', () {
      const target = Rect.fromLTWH(100, 330, 160, 100);
      final p = _place(target, bubble: const Size(300, 600));
      expect(p.overlapsTarget, isFalse);
      expect(p.rect.height, lessThan(600));
      expect(p.rect.overlaps(target), isFalse);
      expect(BubbleGeometry.maxBubbleHeight(target: target, screen: _screen, safe: _safe), p.rect.height);
    });

    test('a target filling the screen: the bubble stays on screen and says it overlaps', () {
      const target = Rect.fromLTWH(0, 0, 360, 760);
      final p = _place(target);
      expect(p.overlapsTarget, isTrue);
      final area = _area();
      expect(p.rect.top, greaterThanOrEqualTo(area.top));
      expect(p.rect.bottom, lessThanOrEqualTo(area.bottom));
    });

    test('no target: centred, at most the visible area tall', () {
      final p = _place(null, bubble: const Size(300, 2000));
      expect(p.side, BubbleSide.center);
      expect(p.spotlight, isNull);
      expect(p.rect.height, _area().height);
      expect(BubbleGeometry.maxBubbleHeight(target: null, screen: _screen, safe: _safe), _area().height);
    });

    test('a bubble wider than the screen is narrowed to the margins', () {
      final p = _place(const Rect.fromLTWH(100, 100, 40, 40), bubble: const Size(900, 100));
      expect(p.rect.width, 328);
      expect(p.rect.left, 16);
    });
  });
}
