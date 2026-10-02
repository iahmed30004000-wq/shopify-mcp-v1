import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';
import 'package:madar/features/cinema/rules/puzzles/core/grid.dart';

import 'support.dart';

/// Steers towards the highest solid platform the current jump can reach.
double skyBot(SkyJumperSim sim) {
  final s = sim.state;
  final apex = s.vy > 0 ? s.y + s.vy * s.vy / (2 * SkyConfig.gravity) : s.y;
  final deathLine = s.camera - 40;
  SkyPlatform? target;
  for (final p in s.platforms) {
    if (!p.solid || p.broken) continue;
    if (p.y > apex - 4 || p.y < deathLine + 10) continue;
    if (s.vy <= 0 && p.y > s.y) continue;
    if (target == null || p.y > target.y) target = p;
  }
  if (target == null) return 0;
  var dx = target.x + SkyConfig.platformWidth / 2 - s.x;
  if (dx > SkyConfig.width / 2) dx -= SkyConfig.width;
  if (dx < -SkyConfig.width / 2) dx += SkyConfig.width;
  return (dx / 8).clamp(-1.0, 1.0);
}

void main() {
  group('sky jumper', () {
    test('generated platforms always leave a solid step within reach', () {
      for (final level in ArcadeLevel.values) {
        for (var seed = 0; seed < 5; seed++) {
          final sim = SkyJumperSim(SkyConfig(level: level, seed: seed));
          final seen = <SkyPlatform>{};
          var lastSolid = 10.0;
          for (var i = 0; i < 60 * 60 && !sim.isOver; i++) {
            sim.step(1 / 60, SkyInput(skyBot(sim)));
            final fresh = sim.state.platforms.where(seen.add).toList()..sort((a, b) => a.y.compareTo(b.y));
            for (final p in fresh) {
              if (!p.solid) continue;
              expect(p.y - lastSolid, lessThanOrEqualTo(sim.config.maxGap + 1e-9));
              expect(sim.config.maxGap, lessThan(SkyConfig.maxJump));
              lastSolid = p.y;
            }
          }
          expect(sim.isOver, isFalse, reason: 'the steering bot never falls ($level seed $seed)');
          expect(sim.score, greaterThan(4000));
        }
      }
    });

    test('bounces, crumbling platforms and springs', () {
      final sim = SkyJumperSim(const SkyConfig(seed: 1));
      final s = sim.state;
      s.platforms
        ..clear()
        ..add(SkyPlatform(PlatformKind.crumbling, 100, 200))
        ..add(SkyPlatform(PlatformKind.normal, 100, 100))
        ..add(SkyPlatform(PlatformKind.spring, 100, 20));
      s
        ..x = 120
        ..y = 210
        ..vy = -10
        ..camera = 0;
      sim.runTicks(20, SkyInput.none);
      expect(s.platforms.first.broken, isTrue, reason: 'crumbles without a bounce');
      expect(s.vy, lessThan(0));
      sim.runTicks(30, SkyInput.none);
      expect(s.bounces, 1);
      expect(s.vy, greaterThan(0));
      // Straight down onto the spring.
      s
        ..y = 21
        ..vy = -10
        ..camera = -100;
      sim.runTicks(5, SkyInput.none);
      expect(s.vy, closeTo(SkyConfig.jumpSpeed * SkyConfig.springFactor - SkyConfig.gravity * sim.tickSeconds * 4, 60));
    });

    test('the world wraps sideways; falling off-screen ends the run', () {
      final sim = SkyJumperSim(const SkyConfig(seed: 2));
      sim.runTicks(60, const SkyInput(-1));
      expect(sim.state.x, inInclusiveRange(0, SkyConfig.width));
      final fall = SkyJumperSim(const SkyConfig(seed: 3));
      fall.state.platforms.clear();
      fall.state.vy = 0;
      fall.state.camera = 100;
      fall.runTicks(120, SkyInput.none);
      expect(fall.isOver, isTrue);
    });

    test('deterministic replays', () {
      String run() => runScripted(SkyJumperSim(const SkyConfig(seed: 4)), 3000, (f) => SkyInput(((f ~/ 40) % 3) - 1.0), dt: jitterDt(3));
      expect(run(), run());
    });
  });

  group('maze chase', () {
    test('mazes are symmetric, connected and free of dead ends', () {
      for (var seed = 0; seed < 25; seed++) {
        final m = MazeMap.generate(SeededRng(seed));
        final open = m.corridors;
        for (final (x, y) in open) {
          expect(m.open(MazeConfig.width - 1 - x, y), isTrue, reason: 'mirror');
          expect(m.exits(x, y).length, greaterThanOrEqualTo(2), reason: 'dead end at ($x,$y) seed $seed');
        }
        final seen = <(int, int)>{m.start};
        final queue = [m.start];
        while (queue.isNotEmpty) {
          final (x, y) = queue.removeLast();
          for (final d in m.exits(x, y)) {
            if (seen.add((x + d.dx, y + d.dy))) queue.add((x + d.dx, y + d.dy));
          }
        }
        expect(seen.length, open.length, reason: 'connected');
        expect(m.open(m.den.$1, m.den.$2) && m.open(m.start.$1, m.start.$2), isTrue);
      }
    });

    test('pellets, power pellets and chaser targets', () {
      final sim = MazeChaseSim(const MazeConfig(seed: 1));
      final s = sim.state;
      expect(s.powerPellets.length, 4);
      expect(s.pellets.length, sim.map.corridors.length - 6);
      s.runner
        ..x = 5
        ..y = 7
        ..dir = Dir4.right;
      final ember = s.chasers[0]..mode = ChaserMode.chase;
      final tide = s.chasers[1]..mode = ChaserMode.chase;
      final moss = s.chasers[2]..mode = ChaserMode.chase;
      final dusk = s.chasers[3]..mode = ChaserMode.chase;
      ember
        ..x = 1
        ..y = 1;
      expect(sim.targetOf(ember), (5, 7));
      expect(sim.targetOf(tide), (9, 7));
      expect(sim.targetOf(moss), (2 * 7 - 1, 2 * 7 - 1));
      dusk
        ..x = 5
        ..y = 9;
      expect(sim.targetOf(dusk), MazeChaseSim.corner(ChaserId.dusk), reason: 'too close: retreats');
      dusk
        ..x = 19
        ..y = 21;
      expect(sim.targetOf(dusk), (5, 7));
      ember.mode = ChaserMode.scatter;
      expect(sim.targetOf(ember), MazeChaseSim.corner(ChaserId.ember));
    });

    test('power pellets frighten; eating chasers chains 200, 400…; normal contact costs a life', () {
      final sim = MazeChaseSim(const MazeConfig(seed: 2));
      final s = sim.state;
      final power = s.powerPellets.first;
      s.runner
        ..x = power.$1.toDouble()
        ..y = power.$2.toDouble();
      for (final c in s.chasers) {
        c.mode = ChaserMode.chase;
      }
      sim.runTicks(1, MazeInput.none);
      expect(s.frightened, greaterThan(0));
      expect(s.chasers.every((c) => c.mode == ChaserMode.frightened), isTrue);
      final score = s.score;
      for (final c in s.chasers.take(2)) {
        c
          ..x = s.runner.x
          ..y = s.runner.y;
      }
      sim.runTicks(1, MazeInput.none);
      expect(s.score - score, 200 + 400);
      expect(s.chasers.take(2).every((c) => c.mode == ChaserMode.eaten), isTrue);
      // Frightened time runs out, then a chasing contact costs a life.
      sim.runTicks((sim.frightTime * 60).ceil() + 2, MazeInput.none);
      expect(s.frightened, lessThanOrEqualTo(0));
      s.deathPause = 0;
      s.chasers.last
        ..mode = ChaserMode.chase
        ..x = s.runner.x
        ..y = s.runner.y;
      final lives = s.lives;
      sim.runTicks(1, MazeInput.none);
      expect(s.lives, lives - 1);
    });

    test('scatter and chase alternate on the schedule; chasers leave the den in turn', () {
      final sim = MazeChaseSim(const MazeConfig(seed: 3, lives: 99));
      sim.state.powerPellets.clear();
      sim.runTicks(60, MazeInput.none);
      expect(sim.state.chasers[0].mode, ChaserMode.scatter);
      expect(sim.state.chasers[3].mode, ChaserMode.waiting);
      sim.runTicks(60 * 8, MazeInput.none);
      expect(sim.state.chasers.where((c) => c.mode == ChaserMode.chase).length, greaterThanOrEqualTo(1));
    });

    test('movers stay on corridor tiles; long random play; determinism', () {
      String run(int seed) {
        final sim = MazeChaseSim(MazeConfig(seed: seed, level: ArcadeLevel.values[seed % 3]));
        final rng = SeededRng(seed);
        for (var f = 0; f < 60 * 90 && !sim.isOver; f++) {
          sim.step(jitterDt(f), MazeInput(rng.nextInt(15) == 0 ? rng.pick(Dir4.values) : sim.state.runner.dir));
          for (final c in [sim.state.runner, ...sim.state.chasers]) {
            expect(sim.map.open(c.x.round(), c.y.round()), isTrue);
            expect((c.x - c.x.round()).abs() < 1e-6 || (c.y - c.y.round()).abs() < 1e-6, isTrue, reason: 'on a corridor axis');
          }
        }
        return sim.snapshot().toString();
      }

      for (var seed = 0; seed < 4; seed++) {
        expect(run(seed), run(seed));
      }
    });
  });

  group('road crossing', () {
    test('lanes are deterministic, grass never closes, roads leave gaps', () {
      final a = RoadCrossingSim(const RoadConfig(seed: 5));
      final b = RoadCrossingSim(const RoadConfig(seed: 5));
      b.lane(300);
      for (var row = 0; row < 300; row++) {
        final la = a.lane(row), lb = b.lane(row);
        expect(la.kind, lb.kind);
        expect(la.items, lb.items);
        expect(la.trees, lb.trees);
        if (la.kind == LaneKind.grass) {
          expect(RoadConfig.columns - la.trees.length, greaterThanOrEqualTo(3));
          if (row > 0 && a.lane(row - 1).kind == LaneKind.grass) {
            final shared = {
              for (var c = 0; c < RoadConfig.columns; c++)
                if (!la.trees.contains(c) && !a.lane(row - 1).trees.contains(c)) c,
            };
            expect(shared.length, greaterThanOrEqualTo(2));
          }
        }
        if (la.kind == LaneKind.road) {
          for (var i = 0; i + 1 < la.items.length; i++) {
            expect(la.items[i + 1] - (la.items[i] + la.lengths[i]), greaterThanOrEqualTo(2));
          }
        }
        if (la.kind == LaneKind.river) expect(la.items, isNotEmpty);
      }
      expect({for (var r = 0; r < 300; r++) a.lane(r).kind}, LaneKind.values.toSet());
    });

    test('vehicles, water, riding logs and the storm', () {
      // Find a road lane and wait on the grass before it until a vehicle
      // is about to cover the landing cell, then hop into it.
      final sim = RoadCrossingSim(const RoadConfig(seed: 6));
      var row = 3;
      while (sim.lane(row).kind != LaneKind.road || sim.lane(row - 1).kind != LaneKind.grass) {
        row++;
      }
      final s = sim.state
        ..row = row - 1
        ..x = 4
        ..storm = -100;
      var guard = 0;
      while (!sim.lane(row).covered(4, s.time + 1 / 60) && guard++ < 6000) {
        sim.step(1 / 60, RoadInput.none);
      }
      sim.step(1 / 60, const RoadInput(Dir4.up));
      expect(s.dead, isTrue);
      expect(s.cause, 'vehicle');

      final water = RoadCrossingSim(const RoadConfig(seed: 6));
      var r2 = 3;
      while (water.lane(r2).kind != LaneKind.river) {
        r2++;
      }
      final w = water.state
        ..row = r2
        ..storm = -100;
      // Stand where no log will be after this tick's drift.
      final wl = water.lane(r2);
      var x = 0.0;
      while (wl.covered(x + wl.speed / 60, w.time + 1 / 60, half: 0) && x < 9) {
        x += 0.25;
      }
      w.x = x;
      water.step(1 / 60, RoadInput.none);
      expect(w.dead, isTrue);

      final ride = RoadCrossingSim(const RoadConfig(seed: 6));
      final lane = ride.lane(r2);
      final st = ride.state..storm = -100;
      // Wait (on the start grass) for a log well inside the screen, then
      // put the player on its centre and let it carry them.
      bool inside((double, int) e) => e.$1 > 1 && e.$1 + e.$2 < 8;
      while (!lane.spans(st.time).any(inside)) {
        ride.step(1 / 60, RoadInput.none);
      }
      final (left, len) = lane.spans(st.time).firstWhere(inside);
      st
        ..row = r2
        ..x = left + len / 2;
      final x0 = st.x;
      ride.runTicks(10, RoadInput.none);
      expect(st.dead, isFalse);
      expect(st.x - x0, closeTo(lane.speed * 10 / 60, 1e-9));

      final idle = RoadCrossingSim(const RoadConfig(seed: 7));
      idle.step(1 / 60, const RoadInput(Dir4.up));
      idle.step(1 / 60, const RoadInput(Dir4.down));
      for (var t = 0; t < 60 * 30 && !idle.isOver; t++) {
        idle.step(1 / 60, RoadInput.none);
      }
      expect(idle.state.cause, 'storm');
    });

    test('hops respect trees and edges; score is the best row; determinism', () {
      final sim = RoadCrossingSim(const RoadConfig(seed: 8));
      sim.state.x = 0;
      sim.step(1 / 60, const RoadInput(Dir4.left));
      expect(sim.state.x, 0);
      sim.step(1 / 60, const RoadInput(Dir4.up));
      expect(sim.state.row, 1);
      sim.runTicks(10, RoadInput.none);
      sim.step(1 / 60, const RoadInput(Dir4.down));
      expect(sim.state.row, 0);
      expect(sim.score, 1);
      String run() => runScripted(
        RoadCrossingSim(const RoadConfig(seed: 9, level: ArcadeLevel.hard)),
        5000,
        (f) => RoadInput(f % 13 == 0 ? Dir4.values[(f ~/ 13) % 4] : null),
      );
      expect(run(), run());
    });
  });
}
