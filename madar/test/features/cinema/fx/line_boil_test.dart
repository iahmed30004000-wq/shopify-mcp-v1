import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';

void main() {
  test('jitter is deterministic, bounded and re-rolls per boil frame', () {
    final seen = <double>{};
    for (var frame = 0; frame < 50; frame++) {
      for (var i = 0; i < 20; i++) {
        final j = LineBoil.jitter(7, i, frame);
        expect(j, inInclusiveRange(-1.0, 1.0));
        expect(LineBoil.jitter(7, i, frame), j);
        seen.add(j);
      }
    }
    expect(seen.length, greaterThan(900), reason: 'values spread, not a handful');
    expect(LineBoil.jitter(7, 3, 1), isNot(LineBoil.jitter(7, 3, 2)));
    final mean = seen.reduce((a, b) => a + b) / seen.length;
    expect(mean.abs(), lessThan(0.08), reason: 'centred');
    final o = LineBoil.offset(1, 2, 3, 2);
    expect(o.dx.abs(), lessThanOrEqualTo(2));
    expect(o.dy.abs(), lessThanOrEqualTo(2));
  });

  test('a boiled path re-inks 12 times a second, whatever the display rate', () {
    for (final hz in [60.0, 120.0]) {
      final clock = FilmClock(boilFps: 12);
      final path = BoiledPath((pen) => pen.circle(const Offset(50, 50), 30));
      for (var i = 0; i < hz; i++) {
        clock.advance(1 / hz);
        path.at(clock.boilFrame);
      }
      expect(path.builds, inInclusiveRange(12, 13), reason: '$hz Hz');
    }
  });

  test('reduced motion freezes the boil but keeps the hand-drawn wobble', () {
    final clock = FilmClock(boilFps: 12)..advance(2);
    expect(LineBoil.frameOf(clock, enabled: false), 0);
    expect(LineBoil.frameOf(clock), clock.boilFrame);
  });

  test('pen primitives stay close to their geometry', () {
    final pen = BoilPen(amplitude: 1);
    final path = Path();
    pen
      ..begin(path, 3)
      ..circle(const Offset(100, 100), 40);
    final b = path.getBounds();
    expect(b.center.dx, closeTo(100, 2));
    expect(b.width, closeTo(80, 4));

    final brush = Path();
    pen
      ..begin(brush, 3)
      ..brush(const Offset(0, 0), const Offset(50, -40), const Offset(100, 0), 10);
    final bb = brush.getBounds();
    expect(bb.left, closeTo(0, 6));
    expect(bb.right, closeTo(100, 6));
    expect(bb.height, greaterThan(15));
  });

  test('changing the amplitude or invalidating rebuilds once', () {
    final path = BoiledPath((pen) => pen.rect(const Rect.fromLTWH(0, 0, 10, 10)));
    path.at(1);
    path.at(1);
    expect(path.builds, 1);
    path.amplitude = 2;
    path.at(1);
    expect(path.builds, 2);
    path.invalidate();
    path.at(1);
    expect(path.builds, 3);
  });
}
