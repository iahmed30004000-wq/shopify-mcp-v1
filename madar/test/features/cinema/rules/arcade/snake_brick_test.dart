import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';
import 'package:madar/features/cinema/rules/puzzles/core/grid.dart';

import 'support.dart';

void main() {
  group('snake', () {
    test('advances one cell per interval and ignores reversal', () {
      final s = SnakeSim(const SnakeConfig(seed: 1, level: ArcadeLevel.medium));
      final head = s.state.head;
      s.runTicks(7, SnakeInput.none);
      expect(s.state.head, head);
      s.runTicks(1, SnakeInput.none);
      expect(s.state.head, (head.$1 + 1, head.$2));
      s.step(1 / 60, const SnakeInput(Dir4.left)); // reverse: ignored
      s.runTicks(8, SnakeInput.none);
      expect(s.state.direction, Dir4.right);
      s.step(1 / 60, const SnakeInput(Dir4.up));
      s.runTicks(8, SnakeInput.none);
      expect(s.state.direction, Dir4.up);
    });

    test('eating grows, scores and speeds up every five', () {
      final s = SnakeSim(const SnakeConfig(seed: 2));
      final len = s.state.body.length;
      s.state.food = (s.state.head.$1 + 1, s.state.head.$2);
      s.runTicks(8, SnakeInput.none);
      expect(s.state.body.length, len + 1);
      expect(s.score, 20);
      expect(s.state.food, isNot(s.state.head));
      s.state.eaten = 5;
      expect(s.interval, 7);
    });

    test('walls and the body kill; wrap mode crosses edges', () {
      final wall = SnakeSim(const SnakeConfig(seed: 3, width: 10, height: 10));
      wall.state.food = (0, 0);
      wall.runTicks(8 * 6, SnakeInput.none);
      expect(wall.isOver, isTrue);
      final wrap = SnakeSim(const SnakeConfig(seed: 3, width: 10, height: 10, wrap: true));
      wrap.state.food = (0, 0);
      wrap.runTicks(8 * 6, SnakeInput.none);
      expect(wrap.isOver, isFalse);
      expect(wrap.state.head.$1, lessThan(5));
      // A tight turn into itself.
      final self = SnakeSim(const SnakeConfig(seed: 4));
      for (var i = 0; i < 6; i++) {
        self.state.food = (0, 0);
        self.state.body.add(self.state.body.last);
      }
      for (final d in [Dir4.up, Dir4.left, Dir4.down]) {
        self.step(1 / 60, SnakeInput(d));
        self.runTicks(8, SnakeInput.none);
      }
      expect(self.state.dead, isTrue);
    });

    test('filling the board wins', () {
      final s = SnakeSim(const SnakeConfig(width: 4, height: 1, seed: 0));
      expect(s.state.food, (3, 0));
      s.runTicks(8, SnakeInput.none);
      expect(s.state.won, isTrue);
      expect(s.isOver, isTrue);
    });

    test('deterministic replays under jittery frames; long random play', () {
      String run() => runScripted(
        SnakeSim(const SnakeConfig(seed: 9, wrap: true)),
        5000,
        (f) => SnakeInput(f % 17 == 0 ? Dir4.values[(f ~/ 17) % 4] : null),
      );
      final a = SnakeSim(const SnakeConfig(seed: 9));
      final b = SnakeSim(const SnakeConfig(seed: 9));
      for (var f = 0; f < 3000; f++) {
        final input = SnakeInput(f % 23 == 0 ? Dir4.values[(f ~/ 23) % 4] : null);
        a.step(jitterDt(f), input);
        b.step(jitterDt(f), input);
      }
      expect(a.snapshot(), b.snapshot());
      expect(run(), run());
      for (var seed = 0; seed < 20; seed++) {
        final s = SnakeSim(SnakeConfig(seed: seed, wrap: seed.isEven, level: ArcadeLevel.values[seed % 3]));
        final rng = SeededRng(seed);
        for (var f = 0; f < 4000 && !s.isOver; f++) {
          s.step(1 / 60, SnakeInput(rng.nextInt(12) == 0 ? rng.pick(Dir4.values) : null));
        }
        expect(s.state.body.toSet().length, s.state.body.length, reason: 'no overlapping body');
      }
    });
  });

  group('brick breaker', () {
    test('the ball waits on the paddle until launched', () {
      final b = BrickBreakerSim(const BrickConfig(seed: 1));
      b.runTicks(30, const BrickInput(axis: 1));
      expect(b.state.attached, isTrue);
      expect(b.state.ball.x, closeTo(b.state.paddleX, 1e-9));
      b.step(1 / 60, const BrickInput(launch: true));
      expect(b.state.attached, isFalse);
      expect(b.state.velocity.y, lessThan(0));
    });

    test('swept collisions: a very fast ball cannot tunnel through a brick', () {
      final b = BrickBreakerSim(const BrickConfig(seed: 2));
      final s = b.state;
      final target = s.bricks.firstWhere((x) => x.breakable)..hp = 3;
      s.bricks
        ..clear()
        ..add(target)
        ..add(Brick(const Aabb(0, 0, 1, 1), -1));
      const hp = 3;
      s.attached = false;
      s.ball = Vec2(target.box.center.x, 250);
      s.velocity = const Vec2(0, -30000); // 500 units in one tick
      b.runTicks(1, BrickInput.none);
      expect(target.hp, hp - 1, reason: 'the brick was hit');
      expect(s.ball.y, greaterThan(target.box.bottom), reason: 'bounced back below it');
      expect(s.velocity.y, greaterThan(0));
      // Walls too.
      s.ball = const Vec2(120, 200);
      s.velocity = const Vec2(-40000, 3000);
      b.runTicks(1, BrickInput.none);
      expect(s.ball.x, inInclusiveRange(BrickConfig.ballRadius - 1e-6, BrickConfig.width - BrickConfig.ballRadius + 1e-6));
    });

    test('the paddle angles the bounce by the hit position', () {
      final b = BrickBreakerSim(const BrickConfig(seed: 3));
      final s = b.state
        ..attached = false
        ..bricks.clear()
        ..bricks.add(Brick(const Aabb(0, 0, 10, 5), 1));
      s.ball = Vec2(s.paddleX + 15, 280);
      s.velocity = const Vec2(0, 200);
      b.runTicks(10, BrickInput.none);
      expect(s.velocity.x, greaterThan(0), reason: 'right side sends the ball right');
      expect(s.velocity.y, lessThan(0));
    });

    test('losing the ball costs a life; no lives ends the game', () {
      final b = BrickBreakerSim(const BrickConfig(seed: 4, lives: 2));
      b.step(1 / 60, const BrickInput(launch: true));
      for (var i = 0; i < 60 * 60 && !b.isOver; i++) {
        b.step(1 / 60, const BrickInput(targetX: 0, launch: true));
      }
      expect(b.isOver, isTrue);
      expect(b.state.lives, 0);
    });

    test('a tracking paddle keeps the ball and clears bricks; the ball never leaves the field', () {
      for (var seed = 0; seed < 4; seed++) {
        final b = BrickBreakerSim(BrickConfig(seed: seed));
        final start = b.state.bricks.where((x) => x.breakable).length;
        for (var i = 0; i < 60 * 90 && !b.isOver; i++) {
          final s = b.state;
          // Aim slightly off-centre so the ball keeps an angle.
          b.step(1 / 60, BrickInput(targetX: s.ball.x + (seed.isEven ? 6 : -6), launch: true));
          expect(s.ball.x, inInclusiveRange(BrickConfig.ballRadius - 0.01, BrickConfig.width - BrickConfig.ballRadius + 0.01));
          expect(s.ball.y, greaterThanOrEqualTo(BrickConfig.ballRadius - 0.01));
        }
        expect(b.state.lives, 3, reason: 'seed $seed');
        final left = b.state.bricks.where((x) => x.breakable).length;
        expect(b.state.level > 1 || left < start, isTrue);
        expect(b.score, greaterThan(0));
      }
    });

    test('deterministic replay with jittery frames', () {
      String run() {
        final b = BrickBreakerSim(const BrickConfig(seed: 5, level: ArcadeLevel.hard));
        for (var f = 0; f < 4000 && !b.isOver; f++) {
          b.step(jitterDt(f), BrickInput(axis: (f ~/ 50).isEven ? 1 : -1, launch: f % 90 == 0));
        }
        return b.snapshot().toString();
      }

      expect(run(), run());
    });
  });
}
