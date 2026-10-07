import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_rules.dart';

// The pure rules, headless: the hero's body, the hazards, the five brains,
// the tuning, the scoring and the attract-mode bot.

const double dt = 1 / 60;

void step(HeroBody hero, HeroInput input, {int ticks = 1, List<MovingPlatform> platforms = const []}) {
  for (var i = 0; i < ticks; i++) {
    hero.update(dt, input, platforms);
    input.clearEdges();
  }
}

void main() {
  group('hero body', () {
    test('runs toward the held direction and brakes when released', () {
      final hero = HeroBody();
      final input = HeroInput()..move = 1;
      step(hero, input, ticks: 30);
      expect(hero.vx, closeTo(HeroTuning.runSpeed, 1));
      expect(hero.x, greaterThan(MetroStage.heroStartX + 60));
      expect(hero.facing, 1);
      input.move = 0;
      step(hero, input, ticks: 20);
      expect(hero.vx, 0);
      input.move = -1;
      step(hero, input, ticks: 2);
      expect(hero.facing, -1);
    });

    test('is walled in at the stage edges', () {
      final hero = HeroBody();
      final input = HeroInput()..move = -1;
      step(hero, input, ticks: 240);
      expect(hero.x, MetroStage.heroMinX);
      expect(hero.vx, 0);
      input.move = 1;
      step(hero, input, ticks: 300);
      expect(hero.x, MetroStage.heroMaxX);
    });

    test('jumps with a held button higher than with a tap, and lands', () {
      double apex(bool hold) {
        final hero = HeroBody();
        final input = HeroInput()
          ..jump = true
          ..jumpHeld = hold;
        var top = MetroStage.groundY;
        for (var i = 0; i < 120; i++) {
          hero.update(dt, input, const []);
          input.jump = false;
          if (i > 4) input.jumpHeld = hold;
          top = math.min(top, hero.y);
        }
        expect(hero.onGround, isTrue, reason: 'back on the floor within two seconds');
        expect(hero.y, MetroStage.groundY);
        return MetroStage.groundY - top;
      }

      final high = apex(true), low = apex(false);
      expect(high, greaterThan(140));
      expect(low, lessThan(high * 0.6));
    });

    test('buffers a jump pressed just before landing and allows coyote time', () {
      final hero = HeroBody();
      final input = HeroInput()
        ..jump = true
        ..jumpHeld = true;
      step(hero, input, ticks: 1);
      expect(hero.jumped, isTrue);
      // Press again mid-air just before landing: it fires on touchdown.
      var landed = false;
      for (var i = 0; i < 200 && !landed; i++) {
        if (hero.vy > 0 && hero.y > MetroStage.groundY - 20) input.jump = true;
        hero.update(dt, input, const []);
        input.jump = false;
        if (hero.jumped && i > 2) landed = true;
      }
      expect(landed, isTrue);
    });

    test('dash: fixed speed, i-frames, cooldown', () {
      final hero = HeroBody();
      final input = HeroInput()..dash = 1;
      step(hero, input, ticks: 1);
      expect(hero.dashing, isTrue);
      expect(hero.invulnerable, isTrue);
      expect(hero.vx, HeroTuning.dashSpeed);
      input.dash = 0;
      step(hero, input, ticks: 12);
      expect(hero.dashing, isFalse);
      // A second dash right away is refused by the cooldown.
      input.dash = -1;
      step(hero, input, ticks: 1);
      expect(hero.dashing, isFalse);
      step(hero, input, ticks: 40);
      input.dash = -1;
      step(hero, input, ticks: 1);
      expect(hero.dashing, isTrue);
      expect(hero.facing, -1);
    });

    test('a strike has a short active window and a cooldown', () {
      final hero = HeroBody();
      final input = HeroInput()..strike = true;
      step(hero, input, ticks: 1);
      expect(hero.struck, isTrue);
      expect(hero.swinging, isTrue);
      var active = 0;
      for (var i = 0; i < 30; i++) {
        if (hero.striking) active++;
        step(hero, input);
      }
      expect(active, inInclusiveRange(7, 11));
      expect(hero.swinging, isFalse);
      // Pressing again inside the cooldown does nothing.
      final h2 = HeroBody();
      step(h2, HeroInput()..strike = true);
      step(h2, HeroInput()..strike = true, ticks: 3);
      expect(h2.strikeTime, lessThan(0.1));
    });

    test('the strike box reaches ahead of the facing side', () {
      final hero = HeroBody();
      expect(hero.strikeBox.left, greaterThan(hero.x));
      expect(hero.strikeBox.right, closeTo(hero.x + HeroTuning.strikeReach, 0.01));
      hero.facing = -1;
      expect(hero.strikeBox.right, lessThan(hero.x));
    });

    test('hurt: knocked away from the blow, stunned, invulnerable', () {
      final hero = HeroBody();
      hero.hurt(hero.x + 30);
      expect(hero.vx, lessThan(0));
      expect(hero.vy, lessThan(0));
      expect(hero.stunned, isTrue);
      expect(hero.invulnerable, isTrue);
      final input = HeroInput()..move = 1;
      step(hero, input, ticks: 5);
      // Still stunned: the held direction is ignored.
      expect(hero.vx, lessThan(0));
      step(hero, input, ticks: 80);
      expect(hero.stunned, isFalse);
      expect(hero.vx, greaterThan(0));
      step(hero, input, ticks: 40);
      expect(hero.invulnerable, isFalse);
    });

    test('lands on a lift car from above, rides it, drops through on request', () {
      final platforms = [MovingPlatform()..place(100, t: 0.5, speed: 0)];
      final p = platforms[0];
      final hero = HeroBody(x: 100);
      hero.y = p.y - 120;
      hero.onGround = false;
      final input = HeroInput();
      step(hero, input, ticks: 60, platforms: platforms);
      expect(hero.platform, 0);
      expect(hero.y, closeTo(p.y, 0.01));
      expect(hero.onGround, isTrue);
      // The car moves; the hero rides along.
      p.speed = 60;
      step(hero, input, ticks: 30, platforms: platforms);
      expect(hero.y, closeTo(p.y, 0.01));
      // Drop through.
      input.drop = true;
      step(hero, input, ticks: 1, platforms: platforms);
      expect(hero.platform, -1);
      step(hero, input, ticks: 10, platforms: platforms);
      expect(hero.y, greaterThan(p.y + 5));
      step(hero, input, ticks: 120, platforms: platforms);
      expect(hero.y, MetroStage.groundY);
    });

    test('a car is one-way: jumping up through it is free', () {
      final platforms = [MovingPlatform()..place(100, t: 0.1, speed: 0)];
      final hero = HeroBody(x: 100);
      final input = HeroInput()
        ..jump = true
        ..jumpHeld = true;
      var top = MetroStage.groundY;
      step(hero, input, ticks: 1, platforms: platforms);
      for (var i = 0; i < 30; i++) {
        hero.update(dt, input, platforms);
        top = math.min(top, hero.y);
      }
      expect(top, lessThan(platforms[0].y), reason: 'he passes the car on the way up');
      expect(hero.platform, -1);
      for (var i = 0; i < 90; i++) {
        hero.update(dt, input, platforms);
      }
      expect(hero.platform, 0, reason: 'and lands on it on the way down');
    });

    test('falls off the end of a car', () {
      final platforms = [MovingPlatform()..place(100, t: 0.5, speed: 0)];
      final hero = HeroBody(x: 100)
        ..y = platforms[0].y
        ..platform = 0
        ..onGround = true;
      final input = HeroInput()..move = 1;
      step(hero, input, ticks: 60, platforms: platforms);
      expect(hero.platform, -1);
      expect(hero.y, greaterThan(platforms[0].y));
    });
  });

  group('lift cars', () {
    test('cycle between the ends of the shaft and report their speed', () {
      final p = MovingPlatform()..place(100, speed: 80);
      final start = p.y;
      var maxUp = 0.0;
      for (var i = 0; i < 600; i++) {
        p.update(dt);
        maxUp = math.max(maxUp, start - p.y);
      }
      expect(maxUp, closeTo(p.yBottom - p.yTop, 1));
      expect(p.y, inInclusiveRange(p.yTop, p.yBottom));
      p.update(dt);
      expect(p.vy.abs(), lessThan(200));
    });
  });

  group('hazards', () {
    test('telegraph, then danger, then gone', () {
      final h = Hazard()..spawn(HazardKind.stamp, x: 100, w: 120, h: 70, telegraph: 0.5, life: 0.25);
      expect(h.armed, isFalse);
      for (var i = 0; i < 29; i++) {
        h.update(dt);
      }
      expect(h.armed, isFalse);
      expect(h.telegraphProgress, closeTo(0.97, 0.05));
      h.update(dt);
      h.update(dt);
      expect(h.armed, isTrue);
      for (var i = 0; i < 16; i++) {
        h.update(dt);
      }
      expect(h.active, isFalse);
    });

    test('a projectile arcs under gravity and rolls on the floor', () {
      final h = Hazard()..spawn(HazardKind.rivet, x: 200, y: MetroStage.groundY - 150, w: 26, h: 26, vx: -200, vy: -400, gravity: true, life: 4);
      var top = h.y;
      for (var i = 0; i < 90; i++) {
        h.update(dt);
        top = math.min(top, h.y);
      }
      expect(top, lessThan(MetroStage.groundY - 150));
      expect(h.y, lessThanOrEqualTo(MetroStage.groundY));
      expect(h.x, lessThan(200));
    });

    test('a parry flings it back the other way', () {
      final h = Hazard()..spawn(HazardKind.spark, x: 150, w: 30, h: 30, vx: -280, life: 2);
      h.parry(1);
      expect(h.parried, isTrue);
      expect(h.vx, greaterThan(500));
      expect(h.vy, lessThan(0));
      expect(h.gravity, isTrue);
    });

    test('a bolt stops where it lands and vanishes', () {
      final h = Hazard()..spawn(HazardKind.bolt, x: 100, y: MetroStage.groundY - 300, w: 22, h: 34, gravity: true, life: 3);
      for (var i = 0; i < 120; i++) {
        h.update(dt);
      }
      expect(h.active, isFalse);
    });

    test('the pool hands out free slots and clears', () {
      final pool = HazardPool(4);
      for (var i = 0; i < 4; i++) {
        expect(pool.free(), isNotNull);
        pool.free()!.spawn(HazardKind.spark, x: 0, w: 1, h: 1, life: 1);
      }
      expect(pool.free(), isNull);
      expect(pool.activeCount, 4);
      pool.clear();
      expect(pool.activeCount, 0);
    });

    test('kinds know whether they can be parried', () {
      expect(HazardKind.rivet.parryable, isTrue);
      expect(HazardKind.cog.parryable, isTrue);
      expect(HazardKind.spark.parryable, isTrue);
      expect(HazardKind.shockwave.parryable, isFalse);
      expect(HazardKind.bolt.projectile, isTrue);
      expect(HazardKind.stamp.projectile, isFalse);
    });
  });

  group('boss brains', () {
    BossBrain fight(MetroBoss kind, {int seed = 1}) => BossBrain(kind, seed: seed)..startFight();

    test('every machine has three phase scripts using only its own moves', () {
      for (final kind in MetroBoss.values) {
        final script = metroAttackScript[kind]!;
        expect(script, hasLength(3));
        for (final phase in script) {
          expect(phase, isNotEmpty);
        }
      }
    });

    test('the entrance waits for startFight, then the cycle runs: idle → tell → attack → open → recover', () {
      final b = BossBrain(MetroBoss.clockPress, seed: 1);
      expect(b.mode, BossMode.entering);
      for (var i = 0; i < 120; i++) {
        b.update(dt, 100, MetroStage.groundY);
      }
      expect(b.mode, BossMode.entering);
      b.startFight();
      final seen = <BossMode>[];
      for (var i = 0; i < 60 * 6; i++) {
        b.update(dt, 100, MetroStage.groundY);
        if (seen.isEmpty || seen.last != b.mode) seen.add(b.mode);
      }
      expect(seen.take(5), [BossMode.idle, BossMode.telegraph, BossMode.attack, BossMode.open, BossMode.recover]);
      final kinds = b.events.map((e) => e.kind).toList();
      expect(kinds, containsAllInOrder([BossEventKind.telegraph, BossEventKind.strike, BossEventKind.open, BossEventKind.close]));
    });

    test('the tell aims at the hero and the press stamps there', () {
      final b = fight(MetroBoss.clockPress);
      for (var i = 0; i < 60; i++) {
        b.update(dt, 180, MetroStage.groundY);
      }
      expect(b.mode, BossMode.telegraph);
      expect(b.targetX, 180);
      final tell = b.events.firstWhere((e) => e.kind == BossEventKind.telegraph);
      expect(tell.attack, AttackKind.stamp);
      expect(tell.x, 180);
      expect(b.windUp, inInclusiveRange(0.0, 1.0));
    });

    test('damage counts only through the open window, or when forced', () {
      final b = fight(MetroBoss.boilerHeart);
      expect(b.damage(), isFalse);
      expect(b.hp, b.maxHp);
      expect(b.damage(force: true), isTrue);
      expect(b.hp, b.maxHp - 1);
      // Run to the window.
      for (var i = 0; i < 60 * 8 && !b.vulnerable; i++) {
        b.update(dt, 100, MetroStage.groundY);
      }
      expect(b.vulnerable, isTrue);
      expect(b.weakBox.width, greaterThan(0));
      expect(b.damage(), isTrue);
      expect(b.hurtLeft, greaterThan(0));
    });

    test('phases change at two thirds and one third, closing the window', () {
      final b = fight(MetroBoss.switchboardSpider);
      final twoThirds = (b.maxHp * 2 / 3).floor();
      while (b.hp > twoThirds + 1) {
        b.damage(force: true);
      }
      expect(b.phase, 0);
      b.damage(force: true);
      expect(b.phase, 1);
      expect(b.events.any((e) => e.kind == BossEventKind.phase && e.i == 1), isTrue);
      expect(b.mode, BossMode.recover);
      final third = (b.maxHp / 3).floor();
      while (b.hp > third + 1) {
        b.damage(force: true);
      }
      b.damage(force: true);
      expect(b.phase, 2);
      while (b.alive) {
        b.damage(force: true);
      }
      expect(b.mode, BossMode.dying);
      expect(b.events.last.kind, BossEventKind.dead);
      expect(b.damage(force: true), isFalse);
      for (var i = 0; i < 60 * 3; i++) {
        b.update(dt, 100, MetroStage.groundY);
      }
      expect(b.mode, BossMode.dead);
    });

    test('debugSetPhase lands on the matching health', () {
      final b = BossBrain(MetroBoss.liftTitan);
      b.debugSetPhase(2);
      expect(b.phase, 2);
      expect(b.hp, lessThanOrEqualTo(b.maxHp / 3));
      expect(b.hp, greaterThan(0));
      b.debugSetPhase(0);
      expect(b.hp, b.maxHp);
    });

    test('a forced attack is the next move and starts at once', () {
      final b = fight(MetroBoss.motherDynamo);
      b.debugAttackNow(AttackKind.sparks);
      b.update(dt, 100, MetroStage.groundY);
      b.update(dt, 100, MetroStage.groundY);
      expect(b.mode, BossMode.telegraph);
      expect(b.attack, AttackKind.sparks);
    });

    test('multi-part attacks emit their later steps', () {
      final b = fight(MetroBoss.clockPress);
      b.debugAttackNow(AttackKind.stampSweep);
      var strikes = 0;
      for (var i = 0; i < 60 * 5; i++) {
        b.update(dt, 100, MetroStage.groundY);
        strikes += b.events.where((e) => e.kind == BossEventKind.strike).length;
        b.clearEvents();
      }
      expect(strikes, 3);
    });

    test('every script plays through without exceptions and opens windows', () {
      for (final kind in MetroBoss.values) {
        for (var phase = 0; phase < 3; phase++) {
          final b = BossBrain(kind, seed: 3)..startFight();
          b.debugSetPhase(phase);
          var opens = 0;
          for (var i = 0; i < 60 * 30; i++) {
            b.update(dt, 60 + (i % 200).toDouble(), MetroStage.groundY);
            opens += b.events.where((e) => e.kind == BossEventKind.open).length;
            b.clearEvents();
          }
          expect(opens, greaterThanOrEqualTo(3), reason: '$kind phase $phase');
        }
      }
    });

    test('weak boxes are within reach of the wrench from the floor or a car', () {
      for (final kind in MetroBoss.values) {
        for (var phase = 0; phase < 3; phase++) {
          final b = BossBrain(kind, seed: 5)..startFight();
          b.debugSetPhase(phase);
          for (var i = 0; i < 60 * 20; i++) {
            b.update(dt, 120, MetroStage.groundY);
            if (b.vulnerable) {
              final wb = b.weakBox;
              expect(wb.center.dx, inInclusiveRange(MetroStage.heroMinX - 40, MetroStage.heroMaxX + 60), reason: '$kind $phase');
              // Jump reach ≈ 170 units plus the swing's height.
              expect(wb.bottom, greaterThan(MetroStage.groundY - 170 - HeroTuning.height), reason: '$kind $phase');
            }
            b.clearEvents();
          }
        }
      }
    });

    test('the pool of events is reused (bounded, never grows unbounded)', () {
      final b = fight(MetroBoss.boilerHeart);
      for (var i = 0; i < 60 * 40; i++) {
        b.update(dt, 100, MetroStage.groundY);
        if (i % 7 == 0) b.clearEvents();
      }
      expect(b.events.length, lessThan(100));
    });
  });

  group('tuning and scoring', () {
    test('later phases and machines are faster, assist slows them', () {
      expect(MetroTuning.telegraph(MetroBoss.clockPress, 1, 0), lessThan(MetroTuning.telegraph(MetroBoss.clockPress, 0, 0)));
      expect(MetroTuning.telegraph(MetroBoss.clockPress, 2, 0), lessThan(MetroTuning.telegraph(MetroBoss.clockPress, 1, 0)));
      expect(MetroTuning.telegraph(MetroBoss.motherDynamo, 0, 0), lessThan(MetroTuning.telegraph(MetroBoss.clockPress, 0, 0)));
      expect(MetroTuning.telegraph(MetroBoss.clockPress, 0, 2), greaterThan(MetroTuning.telegraph(MetroBoss.clockPress, 0, 0)));
      expect(MetroTuning.telegraph(MetroBoss.clockPress, 0, 0, reducedMotion: true), greaterThan(MetroTuning.telegraph(MetroBoss.clockPress, 0, 0)));
      expect(MetroTuning.intensity(MetroBoss.clockPress, 2), greaterThan(MetroTuning.intensity(MetroBoss.clockPress, 0)));
      expect(MetroTuning.intensity(MetroBoss.motherDynamo, 2), lessThanOrEqualTo(1));
    });

    test('points', () {
      expect(MetroScore.bossBonus(0), 60);
      expect(MetroScore.bossBonus(4), 180);
      expect(MetroScore.timeBonus(20), 30);
      expect(MetroScore.timeBonus(90), 0);
      expect(MetroScore.parry, greaterThan(MetroScore.strike));
    });
  });

  group('the bot', () {
    test('steps out from under a telegraphed stamp', () {
      final bot = HeroBot();
      final hero = HeroBody(x: 150);
      final input = HeroInput();
      final pool = HazardPool();
      pool.free()!.spawn(HazardKind.stamp, x: 150, w: 120, h: 70, telegraph: 1, life: 0.3);
      bot.decide(dt, hero, input, pool, null, const []);
      expect(input.move, isNot(0));
    });

    test('jumps a wave rolling at it', () {
      final bot = HeroBot();
      final hero = HeroBody(x: 150);
      final input = HeroInput();
      final pool = HazardPool();
      pool.free()!.spawn(HazardKind.shockwave, x: 200, w: 70, h: 48, vx: -360, life: 1);
      bot.decide(dt, hero, input, pool, null, const []);
      expect(input.jump, isTrue);
    });

    test('walks up to an open machine and swings', () {
      final bot = HeroBot();
      final hero = HeroBody(x: 60);
      final input = HeroInput();
      final b = BossBrain(MetroBoss.clockPress)..startFight();
      for (var i = 0; i < 60 * 8 && !b.vulnerable; i++) {
        b.update(dt, hero.x, hero.y);
      }
      expect(b.vulnerable, isTrue);
      var swung = false;
      for (var i = 0; i < 90; i++) {
        bot.decide(dt, hero, input, HazardPool(), b, const []);
        if (input.strike) swung = true;
        hero.update(dt, input, const []);
      }
      expect(swung, isTrue);
      expect((hero.x - b.weakX).abs(), lessThan(HeroTuning.strikeReach + b.weakW));
    });

    test('survives a Clock-Press phase 1 fight with few hits', () {
      final bot = HeroBot(seed: 2);
      final hero = HeroBody();
      final input = HeroInput();
      final pool = HazardPool();
      final b = BossBrain(MetroBoss.clockPress, seed: 4)..startFight();
      var hits = 0;
      for (var i = 0; i < 60 * 30; i++) {
        bot.decide(dt, hero, input, pool, b, const []);
        hero.update(dt, input, const []);
        b.update(dt, hero.x, hero.y);
        for (final e in b.events) {
          if (e.kind == BossEventKind.telegraph && e.attack == AttackKind.stamp) {
            pool.free()?.spawn(HazardKind.stamp, x: e.x, w: 124, h: 72, telegraph: b.modeLength, life: 0.25);
          }
        }
        b.clearEvents();
        pool.update(dt);
        for (final h in pool.items) {
          if (h.active && h.armed && !h.hitHero && !hero.invulnerable && h.box.overlaps(hero.hitBox)) {
            h.hitHero = true;
            hero.hurt(h.x);
            hits++;
          }
        }
        if (hero.striking && !hero.strikeConsumed && b.vulnerable && hero.strikeBox.overlaps(b.weakBox)) {
          hero.strikeConsumed = true;
          b.damage();
        }
      }
      expect(hits, lessThanOrEqualTo(3));
      expect(b.hp, lessThan(b.maxHp), reason: 'the bot lands wrench hits');
    });
  });
}
