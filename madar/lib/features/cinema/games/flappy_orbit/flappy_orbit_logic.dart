import 'dart:math' as math;

// The rules of "Flappy Orbit" as pure Dart (no Flutter, no Flame): the
// rocket-kite's flight, the difficulty ramp, the gate spawner, the style
// scorer (near misses, flaps on the beat), the Maestro's brain (three
// phases of attacks) and the attract-mode autopilot. The game component
// drives these and draws the result; tests drive them directly.

/// Flight tunables (world units, seconds). The world is 360 × 800; the hero
/// hangs at a fixed x and only moves vertically.
abstract final class FlightTuning {
  static const double gravity = 1500;

  /// Upward speed of one boost (a tap).
  static const double flapSpeed = 470;
  static const double maxFall = 760;

  /// Highest point the rocket may reach (the top of the play area).
  static const double ceiling = 72;

  /// The rooftop ledge: touching it is a crash.
  static const double floor = 686;

  /// Rise of one boost from rest: v² / 2g.
  static double get boostRise => flapSpeed * flapSpeed / (2 * gravity);
}

/// What the rocket touched during a step.
enum FlightContact { none, ceiling, floor }

/// Vertical flight of the rocket-kite: gravity pulls, a boost throws it up.
class FlightPhysics {
  FlightPhysics({this.y = 360, this.vy = 0});

  double y;
  double vy;

  /// One tap: a fixed upward speed (so timing, not mashing, is the skill).
  void flap() => vy = -FlightTuning.flapSpeed;

  /// A gust or a hit: adds to the vertical speed.
  void shove(double dvy) => vy = (vy + dvy).clamp(-900.0, 900.0);

  FlightContact step(double dt) {
    vy = math.min(FlightTuning.maxFall, vy + FlightTuning.gravity * dt);
    y += vy * dt;
    if (y < FlightTuning.ceiling) {
      y = FlightTuning.ceiling;
      if (vy < 0) vy = 0;
      return FlightContact.ceiling;
    }
    if (y > FlightTuning.floor) {
      y = FlightTuning.floor;
      return FlightContact.floor;
    }
    return FlightContact.none;
  }
}

/// The ramp: faster scroll, narrower gaps, closer gates as gates are cleared
/// and bosses beaten ([tier]).
class Difficulty {
  Difficulty({this.tier = 0, this.gates = 0});

  /// Bosses defeated so far.
  int tier;

  /// Gates cleared so far (all tiers).
  int gates;

  double get ramp => math.min(1.0, gates / 32);
  double get speed => (152 + ramp * 85 + tier * 22).clamp(150.0, 290.0);
  double get gap => (238 - ramp * 68 - tier * 10).clamp(150.0, 240.0);
  double get spacing => (264 - ramp * 40 - tier * 6).clamp(200.0, 270.0);

  /// Vertical swing amplitude of a gate (it sways on the beat).
  double get swing => (ramp * 22 + tier * 6).clamp(0.0, 40.0);
}

/// What a gate is made of (a pair of props, one hanging, one standing).
enum GateKind { horns, chimney, flags, balloons }

/// A pooled gate: a gap of [gap] units centred on [gapY] (swinging by
/// [swing] on the beat), at [x] in world units.
class GateSlot {
  bool active = false;
  bool passed = false;
  GateKind kind = GateKind.horns;
  int variant = 0;
  double x = 0;
  double gapY = 360;
  double gap = 200;
  double swing = 0;
  double phase = 0;

  /// Half-width of the gate for collisions (the drawings are a bit wider).
  static const double halfWidth = 38;

  /// The gap's centre at [beat] (one sway every four beats).
  double centreAt(double beat) => gapY + swing * math.sin(beat * math.pi / 2 + phase);
  double topEdgeAt(double beat) => centreAt(beat) - gap / 2;
  double bottomEdgeAt(double beat) => centreAt(beat) + gap / 2;

  /// Whether a circle at ([hx], [hy]) of radius [r] overlaps either prop.
  bool hits(double hx, double hy, double r, double beat) {
    if ((hx - x).abs() > halfWidth + r) return false;
    final c = centreAt(beat);
    final dx = math.max(0.0, (hx - x).abs() - halfWidth);
    final topEdge = c - gap / 2, bottomEdge = c + gap / 2;
    // Distance from the circle's centre to the nearest prop (two
    // half-planes beyond the gap, [halfWidth] wide).
    final dy = hy < c ? math.max(0.0, hy - topEdge) : math.max(0.0, bottomEdge - hy);
    return dx * dx + dy * dy < r * r;
  }
}

/// Deals gates from a pool, deterministic for a seed.
class GateSpawner {
  GateSpawner({int seed = 0, this.poolSize = 6}) : _rng = math.Random(seed) {
    for (var i = 0; i < poolSize; i++) {
      pool.add(GateSlot());
    }
  }

  final int poolSize;
  final List<GateSlot> pool = [];
  final math.Random _rng;
  double lastGapY = 380;
  int dealt = 0;

  /// The rightmost active gate's x, or null.
  double? get lastX {
    double? best;
    for (final g in pool) {
      if (g.active && (best == null || g.x > best)) best = g.x;
    }
    return best;
  }

  int get activeCount {
    var n = 0;
    for (final g in pool) {
      if (g.active) n++;
    }
    return n;
  }

  /// Puts a free gate at [x] for [d]; returns it, or null if the pool is full.
  GateSlot? deal(double x, Difficulty d) {
    GateSlot? slot;
    for (final g in pool) {
      if (!g.active) {
        slot = g;
        break;
      }
    }
    if (slot == null) return null;
    final gap = d.gap, swing = d.swing;
    final lo = FlightTuning.ceiling + 34 + gap / 2 + swing;
    final hi = FlightTuning.floor - 46 - gap / 2 - swing;
    var y = lastGapY + (_rng.nextDouble() * 2 - 1) * 180;
    y = y.clamp(lo, math.max(lo, hi));
    lastGapY = y;
    slot
      ..active = true
      ..passed = false
      ..kind = GateKind.values[_rng.nextInt(GateKind.values.length)]
      ..variant = _rng.nextInt(2)
      ..x = x
      ..gapY = y
      ..gap = gap
      ..swing = swing
      ..phase = _rng.nextDouble() * math.pi * 2;
    dealt++;
    return slot;
  }

  void clear() {
    for (final g in pool) {
      g.active = false;
    }
  }
}

/// Style points: a near miss (grazing a prop while passing) and flaps that
/// land on the beat (a streak of four earns a bonus).
class StyleScorer {
  StyleScorer({this.beatWindow = 0.14, this.graze = 24});

  /// Fraction of a beat either side that counts as "on the beat".
  final double beatWindow;

  /// Distance (units) from a gap edge that counts as a near miss.
  final double graze;

  int rhythmStreak = 0;
  int nearMisses = 0;
  int rhythmBonuses = 0;
  int bestStreak = 0;

  /// Registers a flap at [beat] (beats since the music started). Returns
  /// the bonus points earned (0 normally, 2 on every fourth on-beat flap).
  int flap(double beat) {
    final off = (beat - beat.roundToDouble()).abs();
    if (off <= beatWindow) {
      rhythmStreak++;
      bestStreak = math.max(bestStreak, rhythmStreak);
      if (rhythmStreak % 4 == 0) {
        rhythmBonuses++;
        return 2;
      }
      return 0;
    }
    rhythmStreak = 0;
    return 0;
  }

  /// Registers a gate pass at [heroY] through a gap of [top]..[bottom].
  /// Returns the bonus (1 for a near miss).
  int pass(double heroY, double top, double bottom) {
    if (heroY - top < graze || bottom - heroY < graze) {
      nearMisses++;
      return 1;
    }
    return 0;
  }
}

/// The Maestro's three acts.
enum BossPhase { gusts, thunder, spin }

/// Where the Maestro is in his routine.
enum BossStep { entering, idle, windUp, attacking, recover, stunned, leaving }

/// What the current attack is.
enum BossAttackKind { gust, thunder }

/// What the brain tells the game this tick.
enum BossSignal {
  none,

  /// The tell starts (cheeks puff / baton rises).
  windUp,

  /// Launch the attack now.
  fire,

  /// The second thunder-note of a volley.
  fireSecond,

  /// The hero dodged the whole attack: the Maestro takes it badly.
  dodged,

  /// The attack landed: no damage to him.
  shrugged,

  /// A phase was cleared (also counts as dodged).
  phaseUp,

  /// Third phase cleared: he blows away.
  defeated,
}

/// The conductor-cloud's state machine: idle → wind-up → attack → recover,
/// one phase per [hitsPerPhase] dodged attacks, faster with each [level].
class BossBrain {
  BossBrain({this.level = 0, this.hitsPerPhase = 3});

  /// Which boss this is (0 = first): each one is quicker.
  final int level;
  final int hitsPerPhase;

  BossPhase phase = BossPhase.gusts;
  BossStep step = BossStep.entering;
  BossAttackKind attack = BossAttackKind.gust;
  double timer = 0;
  int survived = 0;
  int survivedInPhase = 0;
  int attackNo = 0;
  bool hitThisAttack = false;
  bool _secondFired = false;

  int get totalHits => hitsPerPhase * BossPhase.values.length;
  double get health => (1 - survived / totalHits).clamp(0.0, 1.0);
  bool get isDefeated => step == BossStep.leaving;
  bool get spinning => phase == BossPhase.spin && step != BossStep.leaving;

  double get pace => 1 - level * 0.12;
  double get windUpTime => (phase == BossPhase.spin ? 0.5 : 0.72) * pace;
  double get attackTime => (attack == BossAttackKind.gust ? 1.15 : 1.05) * pace;
  double get recoverTime =>
      switch (phase) {
        BossPhase.gusts => 1.2,
        BossPhase.thunder => 0.95,
        BossPhase.spin => 0.7,
      } *
      pace;
  double get stunTime => 1.5;

  /// He has floated to his mark.
  void arrive() {
    step = BossStep.idle;
    timer = 0;
  }

  /// The hero was hit (or shoved) by the current attack.
  void heroHit() => hitThisAttack = true;

  BossSignal update(double dt) {
    timer += dt;
    switch (step) {
      case BossStep.entering || BossStep.leaving:
        return BossSignal.none;
      case BossStep.idle:
        if (timer < 0.45) return BossSignal.none;
        attack = switch (phase) {
          BossPhase.gusts => BossAttackKind.gust,
          BossPhase.thunder => BossAttackKind.thunder,
          BossPhase.spin => attackNo.isEven ? BossAttackKind.gust : BossAttackKind.thunder,
        };
        step = BossStep.windUp;
        timer = 0;
        return BossSignal.windUp;
      case BossStep.windUp:
        if (timer < windUpTime) return BossSignal.none;
        step = BossStep.attacking;
        timer = 0;
        hitThisAttack = false;
        _secondFired = false;
        attackNo++;
        return BossSignal.fire;
      case BossStep.attacking:
        if (attack == BossAttackKind.thunder && !_secondFired && timer >= 0.34) {
          _secondFired = true;
          return BossSignal.fireSecond;
        }
        if (timer < attackTime) return BossSignal.none;
        timer = 0;
        if (hitThisAttack) {
          step = BossStep.recover;
          return BossSignal.shrugged;
        }
        survived++;
        survivedInPhase++;
        if (survivedInPhase >= hitsPerPhase) {
          survivedInPhase = 0;
          if (phase == BossPhase.spin) {
            step = BossStep.leaving;
            return BossSignal.defeated;
          }
          phase = BossPhase.values[phase.index + 1];
          step = BossStep.stunned;
          return BossSignal.phaseUp;
        }
        step = BossStep.recover;
        return BossSignal.dodged;
      case BossStep.recover:
        if (timer >= recoverTime) {
          step = BossStep.idle;
          timer = 0;
        }
        return BossSignal.none;
      case BossStep.stunned:
        if (timer >= stunTime) {
          step = BossStep.idle;
          timer = 0;
        }
        return BossSignal.none;
    }
  }
}

/// The attract-mode / test pilot: boosts when the rocket is about to drop
/// under where it wants to be, so it hovers in a band one boost tall
/// (about 73 units) just around the target.
abstract final class AutoPilot {
  /// Reaction time (s) the pilot looks ahead.
  static const double lookAhead = 0.1;

  /// The band sits from [targetY] − rise + [bandOffset] to [targetY] + [bandOffset].
  static const double bandOffset = 30;

  /// Whether to boost now to hold [targetY] (world y, down positive).
  static bool shouldFlap({required double y, required double vy, required double targetY}) {
    const t = lookAhead;
    final predicted = y + vy * t + 0.5 * FlightTuning.gravity * t * t;
    return predicted > targetY + bandOffset && vy > -100;
  }
}
