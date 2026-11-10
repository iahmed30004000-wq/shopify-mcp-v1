import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

void main() {
  group('FilmClock', () {
    int boilChanges(double hz, double seconds) {
      final c = FilmClock();
      var changes = 0;
      final ticks = (hz * seconds).round();
      for (var i = 0; i < ticks; i++) {
        c.advance(1 / hz);
        if (c.boilChanged) changes++;
      }
      return changes;
    }

    test('lines boil at 12 fps regardless of the display rate', () {
      expect(boilChanges(60, 2), inInclusiveRange(23, 25));
      expect(boilChanges(120, 2), inInclusiveRange(23, 25));
    });

    test('film frames follow the projection rate', () {
      final c = FilmClock(projectionFps: 18);
      for (var i = 0; i < 120; i++) {
        c.advance(1 / 120);
      }
      expect(c.filmFrame, 18);
      expect(c.tick, 120);
      expect(c.time, closeTo(1, 1e-9));
    });

    test('boilFps 0 never boils', () {
      final c = FilmClock(boilFps: 0);
      for (var i = 0; i < 60; i++) {
        c.advance(1 / 60);
        expect(c.boilFrame, 0);
      }
    });

    test('reset', () {
      final c = FilmClock()..advance(1);
      c.reset();
      expect(c.time, 0);
      expect(c.boilFrame, 0);
      expect(c.tick, 0);
    });
  });

  group('FilmFrame', () {
    test('kicks max-combine and decay to zero', () {
      final f = FilmFrame()
        ..kick(flash: 0.4, shake: 0.2)
        ..kick(flash: 0.2, shake: 0.8, damage: 2);
      expect(f.flash, 0.4);
      expect(f.shake, 0.8);
      expect(f.damage, 1);
      for (var i = 0; i < 300; i++) {
        f.decay(1 / 60);
      }
      expect(f.flash, 0);
      expect(f.shake, 0);
      expect(f.damage, 0);
    });

    test('reduce-flicker caps flashes', () {
      final f = FilmFrame()..kick(flash: 1);
      expect(f.safeFlash, 1);
      f.reduceFlicker = true;
      expect(f.safeFlash, 0.35);
    });
  });

  group('CinemaTween / CinemaDelay', () {
    test('animates and completes on game time', () async {
      final t = CinemaTween();
      var done = false;
      final f = t.animateTo(1, const Duration(milliseconds: 500)).then((_) => done = true);
      for (var i = 0; i < 29; i++) {
        t.update(1 / 60);
      }
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(t.value, inExclusiveRange(0.5, 1));
      t.update(1 / 60);
      await f;
      expect(done, isTrue);
      expect(t.value, 1);
      expect(t.isActive, isFalse);
    });

    test('retargeting completes the pending future', () async {
      final t = CinemaTween();
      var first = false;
      t.animateTo(1, const Duration(seconds: 1)).then((_) => first = true);
      t.animateTo(0, const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(first, isTrue);
    });

    test('zero duration jumps', () async {
      final t = CinemaTween(0.3);
      await t.animateTo(0.9, Duration.zero);
      expect(t.value, 0.9);
    });

    test('delay', () async {
      final d = CinemaDelay();
      var done = false;
      d.start(const Duration(milliseconds: 100)).then((_) => done = true);
      d.update(0.05);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      d.update(0.06);
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });
}
