import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';

import 'support.dart';

/// Plays an AI-vs-AI match to the end; returns the winner (0 left, 1 right).
int match(ArcadeLevel left, ArcadeLevel right, int seed) {
  final p = PaddleDuelSim(PaddleDuelConfig(leftAi: left, ai: right, seed: seed));
  for (var t = 0; t < 60 * 60 * 20 && !p.isOver; t++) {
    p.step(1 / 60, PaddleInput.none);
  }
  expect(p.isOver, isTrue, reason: 'matches always finish');
  return p.state.winner;
}

void main() {
  group('paddle duel', () {
    test('AI levels are ordered: hard ≥ medium > easy', () {
      for (var seed = 0; seed < 4; seed++) {
        expect(match(ArcadeLevel.hard, ArcadeLevel.easy, seed), 0);
        expect(match(ArcadeLevel.easy, ArcadeLevel.medium, seed), 1);
      }
      var hardWins = 0;
      for (var seed = 0; seed < 6; seed++) {
        if (match(ArcadeLevel.hard, ArcadeLevel.medium, seed) == 0) hardWins++;
        if (match(ArcadeLevel.medium, ArcadeLevel.hard, seed) == 1) hardWins++;
      }
      expect(hardWins, greaterThanOrEqualTo(7), reason: 'hard beats medium most of the time ($hardWins/12)');
    });

    test('prediction folds wall bounces', () {
      final p = PaddleDuelSim(const PaddleDuelConfig(seed: 1));
      p.state.ball = const Vec2(160, 100);
      p.state.velocity = const Vec2(200, 170);
      final predicted = p.predictY(PaddleDuelConfig.rightX);
      // Integrate the ball alone (paddles far away) and compare.
      var ball = p.state.ball, v = p.state.velocity;
      const r = PaddleDuelConfig.ballRadius;
      while (ball.x < PaddleDuelConfig.rightX) {
        ball = ball + v * 0.0001;
        if (ball.y < r || ball.y > PaddleDuelConfig.height - r) v = Vec2(v.x, -v.y);
      }
      expect(predicted, closeTo(ball.y, 0.5));
    });

    test('player input moves the left paddle; points and the match end', () {
      final p = PaddleDuelSim(const PaddleDuelConfig(ai: ArcadeLevel.hard, seed: 2, pointsToWin: 3));
      p.runTicks(60, const PaddleInput(axis: -1));
      expect(p.state.leftY, closeTo(PaddleDuelConfig.paddleH / 2, 1e-9));
      // A motionless player loses to the hard AI.
      for (var t = 0; t < 60 * 120 && !p.isOver; t++) {
        p.step(1 / 60, const PaddleInput(targetY: 18));
      }
      expect(p.isOver, isTrue);
      expect(p.state.rightScore, 3);
      expect(p.state.winner, 1);
    });

    test('deterministic replays', () {
      String run() => runScripted(
        PaddleDuelSim(const PaddleDuelConfig(seed: 5)),
        8000,
        (f) => PaddleInput(targetY: 100 + 80 * ((f ~/ 30).isEven ? 1 : -1)),
        dt: 1 / 50,
      );
      expect(run(), run());
    });
  });

  group('stack tower', () {
    test('perfect drops keep the width and grow it back after three', () {
      final s = StackTowerSim(const StackConfig(seed: 1));
      s.state.tower[0] = const StackBlock(55, 90);
      // Force a narrower top, then stack perfectly.
      s.state.movingWidth = 90;
      var guard = 0;
      while (s.state.height < 30 && guard++ < 60 * 600) {
        final st = s.state;
        final perfect = (st.movingLeft - st.top.left).abs() <= s.config.perfectTolerance;
        s.step(1 / 60, StackInput(drop: perfect));
      }
      expect(s.isOver, isFalse);
      expect(s.state.height, 30);
      expect(s.state.perfects, 30);
      expect(s.state.top.width, StackConfig.baseWidth, reason: 'grown back to the base width');
      expect(s.score, 60);
    });

    test('an offset drop is trimmed; a miss ends the game', () {
      final s = StackTowerSim(const StackConfig(seed: 2));
      // Wait until the block is 20 units right of the tower.
      while ((s.state.movingLeft - (s.state.top.left + 20)).abs() > 1.6) {
        s.step(1 / 60, StackInput.none);
      }
      final offset = s.state.movingLeft - s.state.top.left;
      s.step(1 / 60, const StackInput(drop: true));
      expect(s.state.top.width, closeTo(StackConfig.baseWidth - offset.abs(), 1e-9));
      expect(s.state.debris, isNotEmpty);
      expect(s.state.combo, 0);
      // Now wait for a total miss.
      while (s.state.movingLeft < s.state.top.right + 1) {
        s.step(1 / 60, StackInput.none);
      }
      s.step(1 / 60, const StackInput(drop: true));
      expect(s.isOver, isTrue);
    });

    test('speed grows with height; deterministic replays', () {
      final s = StackTowerSim(const StackConfig(seed: 3));
      final v0 = s.speed;
      s.state.tower.addAll(List.filled(10, s.state.top));
      expect(s.speed, greaterThan(v0));
      String run() => runScripted(StackTowerSim(const StackConfig(seed: 4)), 3000, (f) => StackInput(drop: f % 67 == 30));
      expect(run(), run());
    });
  });

  group('fruit slice', () {
    FruitSliceSim bare() {
      final f = FruitSliceSim(const FruitConfig(seed: 1));
      f.state.spawnTimer = 1e9; // no spawns during the scripted tests
      return f;
    }

    test('a blade stroke through a fruit slices it', () {
      final f = bare();
      f.state.objects.add(FlyingObject(1, const Vec2(160, 200), Vec2.zero, false));
      f.step(1 / 60, const FruitInput([Vec2(100, 200), Vec2(220, 200)]));
      expect(f.state.sliced, 1);
      expect(f.score, 1);
      expect(f.state.objects, isEmpty);
    });

    test('three in one swipe earn a combo bonus', () {
      final f = bare();
      for (var i = 0; i < 3; i++) {
        f.state.objects.add(FlyingObject(i, Vec2(80 + 80.0 * i, 200), Vec2.zero, false));
      }
      f.step(1 / 60, const FruitInput([Vec2(40, 200), Vec2(120, 200)]));
      f.step(1 / 60, const FruitInput([Vec2(280, 200)]));
      f.step(1 / 60, FruitInput.none); // blade lifted: combo counted
      expect(f.state.sliced, 3);
      expect(f.score, 6);
      expect(f.state.bestCombo, 3);
    });

    test('slicing a bomb or three missed fruit end the game', () {
      final bomb = bare();
      bomb.state.objects.add(FlyingObject(1, const Vec2(160, 200), Vec2.zero, true));
      bomb.step(1 / 60, const FruitInput([Vec2(100, 200), Vec2(220, 200)]));
      expect(bomb.isOver, isTrue);
      final miss = bare();
      for (var i = 0; i < 3; i++) {
        miss.state.objects.add(FlyingObject(i, Vec2(50.0 + 60 * i, 400), const Vec2(0, 100), false));
      }
      for (var t = 0; t < 120 && !miss.isOver; t++) {
        miss.step(1 / 60, FruitInput.none);
      }
      expect(miss.state.strikes, 3);
      expect(miss.isOver, isTrue);
    });

    test('fast objects are caught by the sweep across the tick', () {
      final f = bare();
      // Moves 60 units per tick; only the middle of its path meets the
      // short stroke (both end positions are too far from it).
      f.state.objects.add(FlyingObject(1, const Vec2(160, 185), const Vec2(0, 3600), false));
      f.step(1 / 60, const FruitInput([Vec2(150, 215), Vec2(170, 215)]));
      expect(f.state.sliced, 1);
    });

    test('spawned arcs rise and fall back; determinism with a scripted blade', () {
      String run() {
        final f = FruitSliceSim(const FruitConfig(seed: 7));
        for (var t = 0; t < 60 * 40 && !f.isOver; t++) {
          final fruit = f.state.objects.where((o) => !o.bomb).toList();
          final blade = fruit.isEmpty || t % 3 != 0 ? const <Vec2>[] : [fruit.first.pos - const Vec2(25, 0), fruit.first.pos + const Vec2(25, 0)];
          f.step(1 / 60, FruitInput(blade));
        }
        return f.snapshot().toString();
      }

      expect(run(), run());
      final f = FruitSliceSim(const FruitConfig(seed: 8));
      var maxHeight = double.infinity;
      for (var t = 0; t < 600; t++) {
        f.step(1 / 60, FruitInput.none);
        for (final o in f.state.objects) {
          if (o.pos.y < maxHeight) maxHeight = o.pos.y;
        }
      }
      expect(maxHeight, lessThan(FruitConfig.height * 0.6), reason: 'arcs reach the upper half');
      expect(maxHeight, greaterThan(0), reason: 'and stay on screen');
    });
  });
}
