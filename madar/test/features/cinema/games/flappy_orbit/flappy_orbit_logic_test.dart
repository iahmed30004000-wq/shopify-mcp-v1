import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_logic.dart';

// The rules of Flappy Orbit as pure Dart: the flight, the ramp, the gate
// spawner and hit test, style points, the Maestro's brain and the autopilot.
void main() {
  group('FlightPhysics', () {
    test('gravity pulls the rocket down and caps the fall', () {
      final f = FlightPhysics(y: 300);
      for (var i = 0; i < 120; i++) {
        f.step(1 / 60);
      }
      expect(f.y, greaterThan(300));
      expect(f.vy, FlightTuning.maxFall);
    });

    test('a boost throws it up by about v²/2g', () {
      final f = FlightPhysics(y: 400)..flap();
      var top = 400.0;
      for (var i = 0; i < 60; i++) {
        f.step(1 / 60);
        if (f.y < top) top = f.y;
      }
      expect(400 - top, closeTo(FlightTuning.boostRise, 12));
    });

    test('the ceiling and the rooftop are reported', () {
      final up = FlightPhysics(y: FlightTuning.ceiling + 5, vy: -600);
      expect(up.step(1 / 60), FlightContact.ceiling);
      expect(up.y, FlightTuning.ceiling);
      expect(up.vy, 0);
      final down = FlightPhysics(y: FlightTuning.floor - 2, vy: 400);
      expect(down.step(1 / 60), FlightContact.floor);
      expect(down.y, FlightTuning.floor);
    });

    test('a shove is clamped', () {
      final f = FlightPhysics()..shove(-5000);
      expect(f.vy, -900);
    });
  });

  group('Difficulty', () {
    test('ramps with gates and tiers inside its clamps', () {
      final d = Difficulty();
      final s0 = d.speed, g0 = d.gap, sp0 = d.spacing;
      d.gates = 40;
      expect(d.speed, greaterThan(s0));
      expect(d.gap, lessThan(g0));
      expect(d.spacing, lessThan(sp0));
      d.tier = 5;
      expect(d.speed, lessThanOrEqualTo(290));
      expect(d.gap, greaterThanOrEqualTo(150));
      expect(d.spacing, greaterThanOrEqualTo(200));
      expect(d.swing, lessThanOrEqualTo(40));
    });
  });

  group('GateSpawner and GateSlot', () {
    test('deals from a pool, gaps inside the sky, then runs dry', () {
      final s = GateSpawner(seed: 3, poolSize: 4);
      final d = Difficulty();
      for (var i = 0; i < 4; i++) {
        final g = s.deal(400 + i * 250.0, d);
        expect(g, isNotNull);
        expect(g!.active, isTrue);
        expect(g.topEdgeAt(0) - g.swing, greaterThanOrEqualTo(FlightTuning.ceiling + 30));
        expect(g.bottomEdgeAt(0) + g.swing, lessThanOrEqualTo(FlightTuning.floor - 40));
      }
      expect(s.deal(2000, d), isNull, reason: 'the pool is exhausted');
      expect(s.activeCount, 4);
      expect(s.lastX, 1150);
      s.pool[1].active = false;
      expect(s.deal(2000, d), isNotNull);
      s.clear();
      expect(s.activeCount, 0);
    });

    test('a gate is deterministic for a seed', () {
      final a = GateSpawner(seed: 9).deal(500, Difficulty())!;
      final b = GateSpawner(seed: 9).deal(500, Difficulty())!;
      expect(a.gapY, b.gapY);
      expect(a.kind, b.kind);
      expect(a.phase, b.phase);
    });

    test('consecutive gaps never jump more than a boost or two apart', () {
      final s = GateSpawner(seed: 5, poolSize: 40);
      var last = s.lastGapY;
      for (var i = 0; i < 40; i++) {
        final g = s.deal(i * 250.0, Difficulty(gates: i))!;
        expect((g.gapY - last).abs(), lessThanOrEqualTo(180 + 1e-9));
        last = g.gapY;
      }
    });

    test('hit test: clear through the gap, blocked by the props', () {
      final g = GateSlot()
        ..active = true
        ..x = 200
        ..gapY = 400
        ..gap = 200;
      expect(g.hits(200, 400, 20, 0), isFalse, reason: 'the middle of the gap');
      expect(g.hits(200, 290, 20, 0), isTrue, reason: 'inside the hanging prop');
      expect(g.hits(200, 520, 20, 0), isTrue, reason: 'inside the standing prop');
      expect(g.hits(200, 310, 20, 0), isTrue, reason: 'grazing the top edge');
      expect(g.hits(200, 322, 20, 0), isFalse, reason: 'just clear of the top edge');
      expect(g.hits(100, 290, 20, 0), isFalse, reason: 'far to the left');
      expect(g.hits(150, 290, 20, 0), isTrue, reason: 'the corner of the prop');
    });

    test('a gate sways with the beat by its swing', () {
      final g = GateSlot()
        ..gapY = 400
        ..swing = 20
        ..phase = 0;
      expect(g.centreAt(0), 400);
      expect(g.centreAt(1), closeTo(420, 1e-9));
      expect(g.centreAt(3), closeTo(380, 1e-9));
    });
  });

  group('StyleScorer', () {
    test('four boosts on the beat earn a bonus; an off-beat one resets', () {
      final s = StyleScorer();
      expect(s.flap(1.05), 0);
      expect(s.flap(2.0), 0);
      expect(s.flap(2.9), 0);
      expect(s.flap(4.1), 2);
      expect(s.rhythmStreak, 4);
      expect(s.rhythmBonuses, 1);
      expect(s.flap(5.5), 0);
      expect(s.rhythmStreak, 0);
      expect(s.bestStreak, 4);
    });

    test('a near miss is a pass within the graze of an edge', () {
      final s = StyleScorer();
      expect(s.pass(400, 300, 500), 0);
      expect(s.pass(315, 300, 500), 1);
      expect(s.pass(490, 300, 500), 1);
      expect(s.nearMisses, 2);
    });
  });

  group('BossBrain', () {
    List<BossSignal> drive(BossBrain b, double seconds, {bool hit = false}) {
      final out = <BossSignal>[];
      var t = 0.0;
      while (t < seconds) {
        final s = b.update(1 / 60);
        if (s != BossSignal.none) out.add(s);
        if (hit && s == BossSignal.fire) b.heroHit();
        t += 1 / 60;
      }
      return out;
    }

    test('one gust attack: wind-up, fire, dodged', () {
      final b = BossBrain()..arrive();
      final s = drive(b, 4);
      expect(s.take(3), [BossSignal.windUp, BossSignal.fire, BossSignal.dodged]);
      expect(b.survived, 1);
      expect(b.health, closeTo(8 / 9, 1e-9));
      expect(b.attack, BossAttackKind.gust);
    });

    test('an attack that lands is shrugged off', () {
      final b = BossBrain()..arrive();
      final s = drive(b, 4, hit: true);
      expect(s, contains(BossSignal.shrugged));
      expect(s, isNot(contains(BossSignal.dodged)));
      expect(b.survived, 0);
    });

    test('three dodges clear a phase, spin-phase volleys fire twice, nine blow him away', () {
      final b = BossBrain()..arrive();
      final all = drive(b, 90);
      final phaseUps = all.where((s) => s == BossSignal.phaseUp).length;
      expect(phaseUps, 2);
      expect(all.last, BossSignal.defeated);
      expect(b.isDefeated, isTrue);
      expect(b.health, 0);
      expect(all, contains(BossSignal.fireSecond));
      // Single notes in the thunder phase; pairs only once the stage spins.
      final secondPhaseUp = all.lastIndexOf(BossSignal.phaseUp);
      expect(all.sublist(0, secondPhaseUp), isNot(contains(BossSignal.fireSecond)));
      expect(drive(b, 2), isEmpty, reason: 'nothing more once he has left');
    });

    test('the spin phase alternates gusts and thunder and is marked spinning', () {
      final b = BossBrain()..arrive();
      var t = 0.0;
      while (b.phase != BossPhase.spin && t < 120) {
        b.update(1 / 60);
        t += 1 / 60;
      }
      expect(b.phase, BossPhase.spin);
      expect(b.spinning, isTrue);
      final kinds = <BossAttackKind>[];
      while (!b.isDefeated && t < 200) {
        if (b.update(1 / 60) == BossSignal.fire) kinds.add(b.attack);
        t += 1 / 60;
      }
      expect(kinds, [BossAttackKind.gust, BossAttackKind.thunder, BossAttackKind.gust], reason: 'the seventh attack is even-numbered');
      expect(b.spinning, isFalse, reason: 'the stage stops once he has left');
    });

    test('later bosses are quicker', () {
      expect(BossBrain(level: 2).windUpTime, lessThan(BossBrain().windUpTime));
      expect(BossBrain(level: 2).recoverTime, lessThan(BossBrain().recoverTime));
    });
  });

  group('AutoPilot', () {
    test('boosts when about to drop under the target, not while shooting up', () {
      expect(AutoPilot.shouldFlap(y: 440, vy: 200, targetY: 400), isTrue);
      expect(AutoPilot.shouldFlap(y: 300, vy: 0, targetY: 400), isFalse);
      expect(AutoPilot.shouldFlap(y: 440, vy: -400, targetY: 400), isFalse);
    });

    test('holds a height for ten seconds without touching the sky or the roofs', () {
      final f = FlightPhysics(y: 400);
      var cooldown = 0.0;
      for (var i = 0; i < 600; i++) {
        cooldown -= 1 / 60;
        if (cooldown <= 0 && AutoPilot.shouldFlap(y: f.y, vy: f.vy, targetY: 400)) {
          f.flap();
          cooldown = 0.08;
        }
        expect(f.step(1 / 60), FlightContact.none);
        expect(f.y, inInclusiveRange(340, 460));
      }
    });
  });
}
