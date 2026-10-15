import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';

import 'support.dart';

void main() {
  group('star hunter', () {
    test('waves enter, get shot down and the next wave is bigger', () {
      final s = StarHunterSim(const StarHunterConfig(seed: 1, level: ArcadeLevel.easy, lives: 99));
      final first = s.state.enemies.length;
      expect(s.state.wave, 1);
      for (var i = 0; i < 60 * 180 && s.state.wave < 3; i++) {
        // Stay under the nearest enemy and keep firing.
        final e = s.state.enemies.isEmpty
            ? null
            : s.state.enemies.reduce((a, b) => (a.pos.x - s.state.player.x).abs() < (b.pos.x - s.state.player.x).abs() ? a : b);
        final dx = e == null ? 0.0 : ((e.pos.x - s.state.player.x) / 10).clamp(-1.0, 1.0);
        s.step(1 / 60, ShooterInput(dx: dx, fire: true));
      }
      expect(s.state.wave, greaterThanOrEqualTo(3));
      expect(s.score, greaterThan(first * 50));
    });

    test('hits cost lives with invulnerability; no lives ends the run', () {
      final s = StarHunterSim(const StarHunterConfig(seed: 2, lives: 2));
      s.state.enemyShots.add(Shot(s.state.player, Vec2.zero));
      s.runTicks(1, ShooterInput.none);
      expect(s.state.lives, 1);
      expect(s.state.invulnerable, greaterThan(1.9));
      s.state.enemyShots.add(Shot(s.state.player, Vec2.zero));
      s.runTicks(1, ShooterInput.none);
      expect(s.state.lives, 1, reason: 'invulnerable');
      s.state.invulnerable = 0;
      s.state.enemyShots.add(Shot(s.state.player, Vec2.zero));
      s.runTicks(1, ShooterInput.none);
      expect(s.isOver, isTrue);
    });

    test('the player stays inside the lower half', () {
      final s = StarHunterSim(const StarHunterConfig(seed: 3, lives: 99));
      s.runTicks(300, const ShooterInput(dx: -1, dy: -1));
      expect(s.state.player.x, closeTo(StarHunterSim.playerRadius, 1e-9));
      expect(s.state.player.y, closeTo(StarHunterConfig.height / 2, 1e-9));
    });

    test('determinism and long random play', () {
      String run(int seed) {
        final rng = SeededRng(seed);
        return runScripted(
          StarHunterSim(StarHunterConfig(seed: seed)),
          6000,
          (f) => ShooterInput(dx: math.sin(f / 40), dy: math.cos(f / 55), fire: rng.nextInt(3) > 0),
        );
      }

      for (var seed = 0; seed < 6; seed++) {
        expect(run(seed), run(seed));
      }
    });
  });

  group('asteroid belt', () {
    test('rocks split large → medium → small → gone', () {
      final a = AsteroidBeltSim(const AsteroidConfig(seed: 1));
      final s = a.state;
      s.rocks
        ..clear()
        ..add(Rock(3, const Vec2(160, 60), Vec2.zero))
        ..add(Rock(3, const Vec2(20, 20), Vec2.zero));
      s.invulnerable = 100;
      s.bullets.add(Bullet(const Vec2(160, 60), Vec2.zero));
      a.runTicks(1, AsteroidInput.none);
      expect(s.rocks.where((r) => r.size == 2).length, 2);
      expect(a.score, 20);
      final medium = s.rocks.firstWhere((r) => r.size == 2);
      s.bullets.add(Bullet(medium.pos, Vec2.zero));
      a.runTicks(1, AsteroidInput.none);
      expect(s.rocks.where((r) => r.size == 1).length, 2);
      final small = s.rocks.firstWhere((r) => r.size == 1);
      for (final r in s.rocks) {
        if (r != small) r.pos = const Vec2(300, 220); // out of the way
      }
      s.bullets.add(Bullet(small.pos, Vec2.zero));
      a.runTicks(1, AsteroidInput.none);
      expect(a.score, 20 + 50 + 100);
    });

    test('a cleared belt starts a bigger wave away from the ship', () {
      final a = AsteroidBeltSim(const AsteroidConfig(seed: 2));
      a.state.rocks.clear();
      a.runTicks(1, AsteroidInput.none);
      expect(a.state.wave, 2);
      expect(a.state.rocks.length, 5);
      for (final r in a.state.rocks) {
        expect(wrapDelta(r.pos, a.state.ship, AsteroidConfig.width, AsteroidConfig.height).length, greaterThan(60));
      }
    });

    test('ship inertia, wrap-around and the speed cap', () {
      final a = AsteroidBeltSim(const AsteroidConfig(seed: 3));
      a.state.rocks
        ..clear()
        ..add(Rock(1, const Vec2(5, 5), Vec2.zero));
      a.state.angle = math.pi / 2; // facing right
      a.runTicks(240, const AsteroidInput(thrust: true));
      expect(a.state.shipVel.length, lessThanOrEqualTo(AsteroidBeltSim.maxSpeed + 1e-9));
      final x = a.state.ship.x;
      expect(x, inInclusiveRange(0, AsteroidConfig.width));
      a.runTicks(30, AsteroidInput.none);
      expect(a.state.shipVel.length, greaterThan(50), reason: 'drifts on');
    });

    test('collisions cost lives; respawn waits for a clear centre', () {
      final a = AsteroidBeltSim(const AsteroidConfig(seed: 4, lives: 2));
      final s = a.state;
      s.invulnerable = 0;
      s.rocks
        ..clear()
        ..add(Rock(3, s.ship, Vec2.zero));
      a.runTicks(1, AsteroidInput.none);
      expect(s.lives, 1);
      expect(s.alive, isFalse);
      // Park a rock in the centre: no respawn while it is there.
      s.rocks
        ..clear()
        ..add(Rock(2, s.ship, Vec2.zero))
        ..add(Rock(1, const Vec2(10, 10), Vec2.zero));
      a.runTicks(200, AsteroidInput.none);
      expect(s.alive, isFalse);
      s.rocks.removeAt(0);
      a.runTicks(2, AsteroidInput.none);
      expect(s.alive, isTrue);
    });

    test('determinism and long random play', () {
      String run(int seed) {
        final rng = SeededRng(seed);
        return runScripted(
          AsteroidBeltSim(AsteroidConfig(seed: seed, level: ArcadeLevel.values[seed % 3])),
          6000,
          (f) => AsteroidInput(
            turn: rng.nextDoubleRange(-1, 1),
            thrust: rng.nextBool(),
            fire: rng.nextInt(4) > 0,
            hyperspace: rng.nextInt(400) == 0,
          ),
          dt: jitterDt(seed),
        );
      }

      for (var seed = 0; seed < 6; seed++) {
        expect(run(seed), run(seed));
      }
    });
  });
}
