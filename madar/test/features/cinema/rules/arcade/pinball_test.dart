import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/arcade/arcade.dart';

import 'support.dart';

/// Minimum clearance between the ball and every static wall.
double wallClearance(Vec2 ball) {
  var best = double.infinity;
  for (final w in [...PinballTable.walls, ...PinballTable.kickers]) {
    final d = (closestOnSegment(ball, w.a, w.b) - ball).length;
    if (d < best) best = d;
  }
  return best;
}

void main() {
  test('the plunger launches the ball up the lane into the playfield', () {
    final p = PinballSim();
    p.runTicks(60, PinballInput.none);
    expect(p.state.onPlunger, isTrue);
    p.step(1 / 120, const PinballInput(launch: true));
    expect(p.state.onPlunger, isFalse);
    var enteredPlayfield = false;
    for (var t = 0; t < 240; t++) {
      p.step(1 / 120, PinballInput.none);
      if (p.state.ball.x < PinballTable.laneX - 1) enteredPlayfield = true;
    }
    expect(enteredPlayfield, isTrue);
  });

  test('a raised flipper fires a resting ball up the table', () {
    final p = PinballSim();
    final f = p.state.left;
    // Rest the ball on the middle of the left flipper.
    final mid = f.pivot + (f.tip - f.pivot) * 0.6;
    final normal = (f.tip - f.pivot).perp.normalized;
    final up = normal.y < 0 ? normal : -normal;
    p.placeBall(mid + up * (PinballConfig.ballRadius + Flipper.radius + 0.01));
    p.runTicks(20, PinballInput.none);
    expect(p.state.ball.y, lessThan(34), reason: 'still on the flipper');
    p.runTicks(8, const PinballInput(left: true));
    expect(p.state.velocity.y, lessThan(-12), reason: 'launched upwards: ${p.state.velocity}');
    expect(p.state.flipperHits, greaterThan(0));
  });

  test('pop bumpers and slingshots kick and score', () {
    final p = PinballSim();
    final b = PinballTable.bumpers.first;
    p.placeBall(b.center + const Vec2(0, -3), const Vec2(0, 12));
    p.runTicks(30, PinballInput.none);
    expect(p.state.bumperHits, greaterThanOrEqualTo(1));
    expect(p.score, greaterThanOrEqualTo(100));
    final k = PinballTable.kickers.first;
    final mid = (k.a + k.b) * 0.5;
    final out = (k.b - k.a).perp.normalized;
    final towards = out.x > 0 ? out : -out; // the face looks into the table
    final q = PinballSim();
    q.placeBall(mid + towards * 2, -towards * 8);
    q.runTicks(30, PinballInput.none);
    expect(q.state.kickerHits, greaterThanOrEqualTo(1));
    expect(q.score, greaterThanOrEqualTo(10));
  });

  test('stable at 120 Hz: no tunnelling, bounded speed, over minutes of play', () {
    for (var seed = 0; seed < 4; seed++) {
      final p = PinballSim(PinballConfig(seed: seed, balls: 50));
      final rng = SeededRng(seed);
      var left = false, right = false;
      for (var t = 0; t < 120 * 120 && !p.isOver; t++) {
        if (rng.nextInt(20) == 0) left = !left;
        if (rng.nextInt(20) == 0) right = !right;
        p.step(1 / 120, PinballInput(left: left, right: right, launch: true, power: rng.nextDouble()));
        final s = p.state;
        if (s.onPlunger) continue;
        expect(s.velocity.length, lessThanOrEqualTo(PinballConfig.maxSpeed + 1e-9));
        expect(s.ball.x, inInclusiveRange(-0.01, PinballConfig.width + 0.01));
        expect(s.ball.y, greaterThanOrEqualTo(-0.01));
        if (s.ball.y < PinballConfig.height) {
          expect(wallClearance(s.ball), greaterThan(PinballConfig.ballRadius - 0.05), reason: 'seed $seed tick $t ${s.ball}');
          for (final bump in PinballTable.bumpers) {
            expect((s.ball - bump.center).length, greaterThan(bump.radius + PinballConfig.ballRadius - 0.05));
          }
        }
      }
      expect(p.score, greaterThan(0));
    }
  });

  test('balls drain without flippers; the game ends after the last ball', () {
    final p = PinballSim(const PinballConfig(balls: 3, seed: 1));
    for (var t = 0; t < 120 * 600 && !p.isOver; t++) {
      p.step(1 / 120, const PinballInput(launch: true));
    }
    expect(p.isOver, isTrue);
    expect(p.state.ballsLeft, 0);
  });

  test('deterministic replays; 120 Hz frames equal fixed ticks', () {
    String run(double dt) => runScripted(
      PinballSim(const PinballConfig(seed: 3)),
      (6000 * (1 / 120) / dt).round(),
      (f) => PinballInput(left: (f ~/ 25).isEven, right: (f ~/ 35).isOdd, launch: f % 400 == 0),
      dt: dt,
    );
    expect(run(1 / 120), run(1 / 120));
    final a = PinballSim(const PinballConfig(seed: 4));
    final b = PinballSim(const PinballConfig(seed: 4));
    for (var t = 0; t < 3000; t++) {
      final input = PinballInput(left: (t ~/ 30).isEven, launch: t == 5);
      a.step(1 / 120, input);
      b.runTicks(1, input);
    }
    expect(a.snapshot(), b.snapshot());
  });
}
