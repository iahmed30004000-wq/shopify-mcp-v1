/// Caravan Dash – the pure rules: three depth lanes across the sand, the
/// hero's body (jump, slide, lane hops, i-frames), the pooled track items
/// (hazards, pickups, the boss's projectiles and the hero's thrown dates),
/// the pattern spawner with its difficulty ramp, the touch gesture machine
/// (tap / hold / swipe), the three-phase brain of Rammal the Sand-Djinn,
/// the three legs with their set pieces, scoring and the attract-mode bot.
///
/// No Flutter or Flame here: everything is plain Dart on game time, so the
/// tests drive it headlessly and the scene only paints what it reads.
library;

import 'dart:math' as math;

/// World-unit constants shared with the scene.
abstract final class CaravanStage {
  static const double width = 360;
  static const double height = 800;

  /// The camera "contains" the world; the set paints beyond the sides.
  static const double paintLeft = -100;
  static const double paintRight = 460;

  /// The three lanes, far to near: where the feet stand and how big things
  /// are drawn there (depth).
  static const int laneCount = 3;
  static const List<double> laneY = [548, 598, 648];
  static const List<double> laneScale = [0.84, 0.92, 1.0];

  /// Where the hero runs (in place; the set scrolls).
  static const double heroX = 104;

  /// Items are born here and recycled past [despawnX].
  static const double spawnX = 480;
  static const double despawnX = -140;

  /// The horizon line of the painted set.
  static const double horizonY = 420;

  static const int legCount = 3;

  /// Length of each leg in world units travelled.
  static const List<double> legLength = [7800, 8400, 7800];

  /// Hero hit box in design units (unscaled): half width and heights.
  static const double heroHalfWidth = 30;
  static const double heroHeight = 98;
  static const double heroSlideHeight = 50;

  /// Where the Djinn hovers (origin of his sand column) in phases 1–2.
  static const double djinnX = 282;
  static const double djinnY = 488;

  /// Where the scorpion rides alongside in phase 3.
  static const double scorpionX = 262;
}

/// Points.
abstract final class CaravanScore {
  static const int date = 1;
  static const int lantern = 5;
  static const int devilPopped = 2;
  static const int dodged = 2;
  static const int bossHit = 5;
  static const int legDone = 20;
  static const int bossBeaten = 30;
  static const int arrival = 50;
  static const int pouchMax = 9;
}

/// Lives.
abstract final class CaravanLives {
  static const int start = 3;
  static const int max = 4;
}

// ---------------------------------------------------------------------------
// The hero's body

/// Nawwara on Zajil: lane, jump arc, slide, lane hops, i-frames. Positions
/// are in world units; [lift] is the height above the lane's ground.
class HeroBody {
  int lane = 1;

  /// Height above the ground (≥ 0, up is positive).
  double lift = 0;

  /// Vertical speed (up is positive).
  double vy = 0;
  bool sliding = false;
  double slideTime = 0;

  /// 0..1: how far the body has visually folded into the slide.
  double slideAmount = 0;

  /// Visual y of the feet (springs toward the lane's ground on a hop).
  double shownY = CaravanStage.laneY[1];
  double _shownVy = 0;

  /// 0..1 the little sideways hop of a lane change (decays).
  double hop = 0;
  double invulnerable = 0;
  double hurtTime = 10;
  bool alive = true;

  static const double gravity = 2300;
  static const double jumpSpeed = 830;
  static const double minSlide = 0.3;
  static const double maxSlide = 1.6;

  bool get onGround => lift <= 0.0001;

  /// Height of the hit box right now.
  double get hitHeight => sliding || slideAmount > 0.5 ? CaravanStage.heroSlideHeight : CaravanStage.heroHeight;

  /// Apex of a jump in world units.
  static double get jumpApex => jumpSpeed * jumpSpeed / (2 * gravity);

  /// Seconds a jump keeps the hero in the air.
  static double get airTime => 2 * jumpSpeed / gravity;

  void reset({int lane = 1}) {
    this.lane = lane;
    lift = 0;
    vy = 0;
    sliding = false;
    slideTime = 0;
    slideAmount = 0;
    shownY = CaravanStage.laneY[lane];
    _shownVy = 0;
    hop = 0;
    invulnerable = 0;
    hurtTime = 10;
    alive = true;
  }

  /// Takes off; a slide is cancelled by a jump. Returns true if it jumped.
  bool jump() {
    if (!alive || !onGround) return false;
    sliding = false;
    vy = jumpSpeed;
    lift = 0.001;
    return true;
  }

  /// Starts a slide (only on the ground). Returns true if it started.
  bool slideStart() {
    if (!alive || !onGround || sliding) return false;
    sliding = true;
    slideTime = 0;
    return true;
  }

  /// Ends the slide once the minimum has played.
  void slideEnd() {
    if (!sliding) return;
    if (slideTime >= minSlide) {
      sliding = false;
    } else {
      _releaseQueued = true;
    }
  }

  bool _releaseQueued = false;

  /// Hops one lane toward the back (−1) or the front (+1). Returns true if
  /// the lane changed.
  bool changeLane(int dir) {
    if (!alive || dir == 0) return false;
    final next = (lane + dir.sign).clamp(0, CaravanStage.laneCount - 1);
    if (next == lane) return false;
    lane = next;
    hop = 1;
    return true;
  }

  /// A hit: i-frames and the hurt pose timer. Returns false while
  /// invulnerable.
  bool hurt({double invulnerableFor = 1.5}) {
    if (invulnerable > 0 || !alive) return false;
    invulnerable = invulnerableFor;
    hurtTime = 0;
    sliding = false;
    return true;
  }

  void update(double dt) {
    if (!onGround || vy > 0) {
      vy -= gravity * dt;
      lift = math.max(0, lift + vy * dt);
      if (lift <= 0) {
        lift = 0;
        vy = 0;
      }
    }
    if (sliding) {
      slideTime += dt;
      if (_releaseQueued && slideTime >= minSlide) {
        sliding = false;
        _releaseQueued = false;
      } else if (slideTime >= maxSlide) {
        sliding = false;
        _releaseQueued = false;
      }
    } else {
      _releaseQueued = false;
    }
    slideAmount += ((sliding ? 1.0 : 0.0) - slideAmount) * math.min(1, dt * 16);
    // The feet spring to the new lane's ground.
    final target = CaravanStage.laneY[lane];
    final a = 420 * (target - shownY) - 2 * 0.72 * math.sqrt(420) * _shownVy;
    _shownVy += a * dt;
    shownY += _shownVy * dt;
    if ((shownY - target).abs() < 0.05 && _shownVy.abs() < 1) {
      shownY = target;
      _shownVy = 0;
    }
    hop = math.max(0, hop - dt * 4.2);
    if (invulnerable > 0) invulnerable = math.max(0, invulnerable - dt);
    hurtTime += dt;
  }
}

// ---------------------------------------------------------------------------
// Track items

/// Everything that travels along a lane.
enum TrackKind {
  /// A saguaro: jump over it.
  cactus,

  /// A low market cart: jump over it.
  cart,

  /// A cart stacked with rugs: too tall to jump – change lane.
  tallCart,

  /// A rope of washing / an awning pole across the lane: slide under it.
  bar,

  /// A little whirlwind: jumpable, drifts toward another lane.
  sandDevil,

  /// A date: collect it (+score, +ammo).
  date,

  /// A lantern on a pole, hung high: jump to collect; lights the way.
  lantern,

  /// The Djinn's barrel: thrown in an arc, then rolls at you. Jump.
  barrel,

  /// The Djinn's sand-whirl: tall, shifts lane toward you. Change lane.
  whirl,

  /// The scorpion's stinger jab: fast and low. Jump.
  sting,

  /// A date the hero threw forward.
  dateShot,
}

extension TrackKindInfo on TrackKind {
  bool get isPickup => this == TrackKind.date || this == TrackKind.lantern;
  bool get isHazard => !isPickup && this != TrackKind.dateShot;

  /// Belongs to the boss fight (not the regular spawner).
  bool get isBossAttack => this == TrackKind.barrel || this == TrackKind.whirl || this == TrackKind.sting;

  /// A jump clears it when the hero's lift exceeds this.
  double get clearHeight => switch (this) {
    TrackKind.cactus => 62,
    TrackKind.cart => 56,
    TrackKind.tallCart => 400,
    TrackKind.bar => 0,
    TrackKind.sandDevil => 58,
    TrackKind.barrel => 50,
    TrackKind.whirl => 400,
    TrackKind.sting => 38,
    TrackKind.date || TrackKind.lantern || TrackKind.dateShot => 0,
  };

  /// Half width of the hit box (design units).
  double get halfWidth => switch (this) {
    TrackKind.cactus => 16,
    TrackKind.cart => 34,
    TrackKind.tallCart => 34,
    TrackKind.bar => 10,
    TrackKind.sandDevil => 18,
    TrackKind.date => 16,
    TrackKind.lantern => 16,
    TrackKind.barrel => 24,
    TrackKind.whirl => 26,
    TrackKind.sting => 22,
    TrackKind.dateShot => 10,
  };

  /// A bar hangs this high above the ground; only a sliding hero passes.
  double get hangHeight => this == TrackKind.bar ? 64 : 0;

  /// Points for passing it alive (boss attacks only).
  int get dodgePoints => isBossAttack ? CaravanScore.dodged : 0;
}

/// One pooled track item (never re-created).
class TrackItem {
  bool active = false;
  TrackKind kind = TrackKind.cactus;
  int lane = 1;

  /// World x (camera frame).
  double x = 0;

  /// Height above the ground (pickups hang; barrels fly).
  double lift = 0;

  /// Own camera-frame horizontal speed (projectiles) or extra speed on top
  /// of the ground scroll (ground-bound items).
  double vx = 0;
  double vy = 0;
  bool flying = false;
  double age = 0;

  /// Resolved: passed, hit or collected (no more collisions / scoring).
  bool resolved = false;

  /// Sand-devils and whirls drift to this lane once [x] < [shiftX].
  int laneTarget = 1;
  double shiftX = -1000;

  /// 0..1 the lean before the drift (a tell).
  double lean = 0;

  /// Visual phase (spin, hop, flicker).
  double spin = 0;
  int seed = 0;

  /// Visual y of the feet during a lane drift (springs).
  double shownY = 0;
  double _shownVy = 0;

  bool get isGroundBound => !flying && kind != TrackKind.dateShot && kind != TrackKind.sting;

  void reset() {
    active = false;
    resolved = false;
    flying = false;
    lift = 0;
    vx = 0;
    vy = 0;
    age = 0;
    lean = 0;
    spin = 0;
    shiftX = -1000;
    _shownVy = 0;
  }
}

/// The pool of track items.
class TrackPool {
  TrackPool({this.capacity = 48}) {
    for (var i = 0; i < capacity; i++) {
      items.add(TrackItem()..seed = i);
    }
  }

  final int capacity;
  final List<TrackItem> items = [];

  int get activeCount {
    var n = 0;
    for (final it in items) {
      if (it.active) n++;
    }
    return n;
  }

  TrackItem? spawn(TrackKind kind, int lane, double x, {double lift = 0, double vx = 0, double vy = 0, bool flying = false, int? laneTarget, double shiftX = -1000}) {
    for (final it in items) {
      if (it.active) continue;
      it
        ..reset()
        ..active = true
        ..kind = kind
        ..lane = lane.clamp(0, CaravanStage.laneCount - 1)
        ..x = x
        ..lift = lift
        ..vx = vx
        ..vy = vy
        ..flying = flying
        ..laneTarget = (laneTarget ?? lane).clamp(0, CaravanStage.laneCount - 1)
        ..shiftX = shiftX
        ..shownY = CaravanStage.laneY[lane.clamp(0, CaravanStage.laneCount - 1)];
      return it;
    }
    return null;
  }

  void clear({bool bossOnly = false}) {
    for (final it in items) {
      if (!it.active) continue;
      if (bossOnly && !it.kind.isBossAttack) continue;
      it.active = false;
    }
  }

  /// Moves everything by the ground scroll ([speed] units/s) and its own
  /// motion; recycles what left the stage.
  void update(double dt, double speed) {
    for (final it in items) {
      if (!it.active) continue;
      it.age += dt;
      switch (it.kind) {
        case TrackKind.dateShot:
          it.x += it.vx * dt;
          it.lift += it.vy * dt;
          it.vy -= 300 * dt;
          it.spin += dt * 14;
          if (it.x > CaravanStage.spawnX + 60 || it.lift < -10) it.active = false;
        case TrackKind.sting:
          it.x += it.vx * dt;
          it.spin += dt * 30;
          if (it.x < CaravanStage.despawnX) it.active = false;
        case TrackKind.barrel:
          if (it.flying) {
            it.x += it.vx * dt;
            it.lift += it.vy * dt;
            it.vy -= 1500 * dt;
            it.spin += dt * 6;
            if (it.lift <= 0) {
              it.lift = 0;
              it.flying = false;
              it.vy = 0;
              it.vx = 70;
            }
          } else {
            it.x -= (speed + it.vx) * dt;
            it.spin -= (speed + it.vx) * dt / 22;
            if (it.x < CaravanStage.despawnX) it.active = false;
          }
        default:
          it.x -= (speed + it.vx) * dt;
          it.spin += dt * (it.kind == TrackKind.sandDevil || it.kind == TrackKind.whirl ? 9 : 2);
          if (it.x < CaravanStage.despawnX) it.active = false;
      }
      // Drifters: lean, then hop to the target lane.
      if (it.kind == TrackKind.sandDevil || it.kind == TrackKind.whirl) {
        if (it.lane != it.laneTarget) {
          final toGo = it.x - it.shiftX;
          it.lean = (1 - toGo / 90).clamp(0.0, 1.0) * (it.laneTarget > it.lane ? 1 : -1);
          if (toGo <= 0) {
            it.lane = it.laneTarget;
            it.lean = 0;
          }
        }
        final target = CaravanStage.laneY[it.lane];
        final a = 300 * (target - it.shownY) - 2 * 0.8 * math.sqrt(300) * it._shownVy;
        it._shownVy += a * dt;
        it.shownY += it._shownVy * dt;
      } else {
        it.shownY = CaravanStage.laneY[it.lane];
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Collisions

/// What happened between the hero and an item this tick.
enum Contact { none, hit, dodged, collected }

abstract final class Collisions {
  /// Resolves one item against the hero. Pickups are collected on overlap,
  /// hazards hit unless jumped / slid / in another lane, and a hazard that
  /// went past is "dodged" once.
  static Contact resolve(TrackItem it, HeroBody hero) {
    if (!it.active || it.resolved) return Contact.none;
    if (it.kind == TrackKind.dateShot) return Contact.none;
    final dx = it.x - CaravanStage.heroX;
    final sameLane = it.lane == hero.lane;
    final reach = it.kind.halfWidth + CaravanStage.heroHalfWidth;
    if (dx.abs() < reach && sameLane) {
      if (it.kind.isPickup) {
        // A hanging lantern needs a jump; dates are at the hero's height.
        final bottom = it.lift, top = it.lift + 44;
        final hb = hero.lift, ht = hero.lift + hero.hitHeight;
        if (ht >= bottom && hb <= top) {
          it.resolved = true;
          return Contact.collected;
        }
        return Contact.none;
      }
      if (it.kind == TrackKind.bar) {
        if (hero.sliding || hero.slideAmount > 0.6) return Contact.none;
        if (hero.lift + hero.hitHeight < it.kind.hangHeight) return Contact.none;
        it.resolved = true;
        return Contact.hit;
      }
      final top = it.lift + it.kind.clearHeight;
      if (hero.lift >= top) return Contact.none;
      if (it.flying && it.lift > hero.lift + hero.hitHeight) return Contact.none;
      it.resolved = true;
      return Contact.hit;
    }
    if (dx < -reach - 6 && it.kind.isHazard) {
      it.resolved = true;
      return Contact.dodged;
    }
    return Contact.none;
  }

  /// A thrown date against a sand-devil in the same lane (pops it).
  static bool shotHitsDevil(TrackItem shot, TrackItem devil) {
    if (!shot.active || !devil.active || devil.resolved) return false;
    if (shot.kind != TrackKind.dateShot || devil.kind != TrackKind.sandDevil) return false;
    if (shot.lane != devil.lane) return false;
    return (shot.x - devil.x).abs() < devil.kind.halfWidth + 10 && shot.lift < devil.kind.clearHeight;
  }
}

// ---------------------------------------------------------------------------
// Spawner

/// One placement inside a pattern: a kind at a lane offset and a distance
/// from the pattern's start (in units at the reference speed).
class PatternStep {
  const PatternStep(this.kind, this.laneOffset, this.dx, {this.lift = 0, this.laneTarget});

  final TrackKind kind;
  final int laneOffset;
  final double dx;
  final double lift;

  /// Sand-devils drift to base + this.
  final int? laneTarget;
}

/// A reusable arrangement; [length] is the distance to the next pattern.
class Pattern {
  const Pattern(this.name, this.steps, {required this.length, this.minDifficulty = 0, this.night = false, this.weight = 1});

  final String name;
  final List<PatternStep> steps;
  final double length;
  final int minDifficulty;

  /// Only in the night market (lanterns).
  final bool night;
  final double weight;
}

/// The patterns, designed at a reference speed of 300 units/s; distances
/// scale with the real speed so reaction time stays the same. Every pattern
/// leaves a dodge in every lane (jump, slide or a free lane).
abstract final class Patterns {
  static const double referenceSpeed = 300;

  static const List<Pattern> all = [
    Pattern('cactus', [
      PatternStep(TrackKind.cactus, 0, 0),
      PatternStep(TrackKind.date, 1, 0),
      PatternStep(TrackKind.date, 1, 40),
      PatternStep(TrackKind.date, 1, 80),
    ], length: 260),
    Pattern('cart arc', [
      PatternStep(TrackKind.cart, 0, 0),
      PatternStep(TrackKind.date, 0, -70, lift: 70),
      PatternStep(TrackKind.date, 0, -20, lift: 108),
      PatternStep(TrackKind.date, 0, 30, lift: 108),
      PatternStep(TrackKind.date, 0, 80, lift: 70),
    ], length: 300),
    Pattern('washing line', [
      PatternStep(TrackKind.bar, 0, 0),
      PatternStep(TrackKind.date, 0, -40, lift: 10),
      PatternStep(TrackKind.date, 0, 0, lift: 10),
      PatternStep(TrackKind.date, 0, 40, lift: 10),
    ], length: 280),
    Pattern('date trail', [
      PatternStep(TrackKind.date, 0, 0),
      PatternStep(TrackKind.date, 0, 44),
      PatternStep(TrackKind.date, 0, 88),
      PatternStep(TrackKind.date, 0, 132),
      PatternStep(TrackKind.date, 0, 176),
    ], length: 300, weight: 0.8),
    Pattern('zigzag', [
      PatternStep(TrackKind.date, 0, 0),
      PatternStep(TrackKind.date, 1, 70),
      PatternStep(TrackKind.date, 2, 140),
      PatternStep(TrackKind.date, 1, 210),
      PatternStep(TrackKind.date, 0, 280),
    ], length: 380, weight: 0.7),
    Pattern('two cacti', [
      PatternStep(TrackKind.cactus, 0, 0),
      PatternStep(TrackKind.cactus, 1, 30),
      PatternStep(TrackKind.date, 2, 0),
      PatternStep(TrackKind.date, 2, 40),
    ], length: 300, minDifficulty: 1),
    Pattern('sand-devil', [
      PatternStep(TrackKind.sandDevil, 0, 0, laneTarget: 1),
      PatternStep(TrackKind.date, 2, 20),
      PatternStep(TrackKind.date, 2, 60),
    ], length: 320, minDifficulty: 1),
    Pattern('rug cart', [
      PatternStep(TrackKind.tallCart, 0, 0),
      PatternStep(TrackKind.date, 1, -30),
      PatternStep(TrackKind.date, 1, 10),
      PatternStep(TrackKind.date, 1, 50),
    ], length: 320, minDifficulty: 2),
    Pattern('gauntlet', [
      PatternStep(TrackKind.cactus, 0, 0),
      PatternStep(TrackKind.bar, 1, 90),
      PatternStep(TrackKind.cart, 2, 180),
      PatternStep(TrackKind.date, 1, 0),
      PatternStep(TrackKind.date, 2, 90, lift: 100),
    ], length: 420, minDifficulty: 2),
    Pattern('cart then line', [
      PatternStep(TrackKind.cart, 0, 0),
      PatternStep(TrackKind.bar, 0, 230),
      PatternStep(TrackKind.date, 0, 100),
      PatternStep(TrackKind.date, 0, 140),
    ], length: 420, minDifficulty: 3),
    Pattern('devil pair', [
      PatternStep(TrackKind.sandDevil, 0, 0, laneTarget: 1),
      PatternStep(TrackKind.sandDevil, 2, 120, laneTarget: 1),
      PatternStep(TrackKind.date, 1, 60, lift: 100),
    ], length: 400, minDifficulty: 3),
    Pattern('rug and cactus', [
      PatternStep(TrackKind.tallCart, 0, 0),
      PatternStep(TrackKind.cactus, 1, 40),
      PatternStep(TrackKind.date, 2, 0),
      PatternStep(TrackKind.date, 2, 40),
      PatternStep(TrackKind.date, 2, 80),
    ], length: 360, minDifficulty: 4),
    Pattern('lantern', [
      PatternStep(TrackKind.lantern, 0, 0, lift: 96),
      PatternStep(TrackKind.date, 0, -50),
      PatternStep(TrackKind.date, 0, 50),
    ], length: 240, night: true, weight: 1.6),
    Pattern('lantern over cart', [
      PatternStep(TrackKind.cart, 0, 0),
      PatternStep(TrackKind.lantern, 0, 0, lift: 110),
      PatternStep(TrackKind.date, 1, 0),
    ], length: 300, night: true, minDifficulty: 1),
  ];
}

/// Hands out patterns along the road.
class Spawner {
  Spawner({int seed = 0}) : _rng = math.Random(seed);

  final math.Random _rng;

  /// Distance travelled so far (units).
  double travelled = 0;

  /// Where the next pattern starts (units travelled).
  double nextAt = 420;

  /// 0..4: unlocks patterns and shortens gaps.
  int difficulty = 0;
  bool enabled = true;
  bool night = false;
  int spawnedPatterns = 0;
  String lastPattern = '';
  Pattern? _last;

  double get gap => 170.0 - difficulty * 18;

  /// Advances by [distance] (units) at [speed] and spawns what is due.
  void update(double distance, double speed, TrackPool pool) {
    travelled += distance;
    if (!enabled) {
      nextAt = math.max(nextAt, travelled + 200);
      return;
    }
    while (travelled >= nextAt) {
      final p = _pick();
      final k = (speed / Patterns.referenceSpeed).clamp(0.8, 1.6);
      final overshoot = travelled - nextAt;
      final base = _rng.nextInt(CaravanStage.laneCount);
      for (final s in p.steps) {
        final lane = (base + s.laneOffset) % CaravanStage.laneCount;
        final target = s.laneTarget == null ? null : (base + s.laneTarget!) % CaravanStage.laneCount;
        final x = CaravanStage.spawnX + s.dx * k - overshoot;
        final it = pool.spawn(s.kind, lane, x, lift: s.lift, laneTarget: target);
        if (it != null && s.kind == TrackKind.sandDevil) {
          it
            ..vx = 50
            ..shiftX = 260 + _rng.nextDouble() * 60;
        }
      }
      spawnedPatterns++;
      lastPattern = p.name;
      _last = p;
      nextAt += p.length * k + gap * k;
    }
  }

  Pattern _pick() {
    var total = 0.0;
    for (final p in Patterns.all) {
      if (_eligible(p)) total += p.weight;
    }
    var r = _rng.nextDouble() * total;
    for (final p in Patterns.all) {
      if (!_eligible(p)) continue;
      r -= p.weight;
      if (r <= 0) return p;
    }
    return Patterns.all.first;
  }

  bool _eligible(Pattern p) {
    if (p.minDifficulty > difficulty) return false;
    if (p.night && !night) return false;
    if (identical(p, _last) && Patterns.all.length > 1) return false;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Input

/// What a gesture asked for.
enum CaravanCommand { none, jump, slideStart, slideEnd, laneBack, laneFront, throwDate }

/// Tap / hold / swipe, resolved from the engine's raw events: a quick tap
/// jumps on release, a press held for [holdDelay] slides until released,
/// a vertical swipe hops a lane (up = the far lane), a horizontal swipe
/// throws a date.
class CaravanInput {
  bool pressed = false;
  bool resolved = false;
  bool sliding = false;
  double downX = 0, downY = 0, downTime = 0;

  static const double swipe = 34;
  static const double holdDelay = 0.17;

  void down(double x, double y, double t) {
    pressed = true;
    resolved = false;
    downX = x;
    downY = y;
    downTime = t;
  }

  /// A finger movement (screen px). Returns a lane hop or a throw once.
  CaravanCommand move(double x, double y) {
    if (!pressed || resolved || sliding) return CaravanCommand.none;
    final dx = x - downX, dy = y - downY;
    if (dy.abs() >= swipe && dy.abs() > dx.abs()) {
      resolved = true;
      return dy < 0 ? CaravanCommand.laneBack : CaravanCommand.laneFront;
    }
    if (dx.abs() >= swipe * 1.2 && dx.abs() > dy.abs()) {
      resolved = true;
      return CaravanCommand.throwDate;
    }
    return CaravanCommand.none;
  }

  /// The finger lifted without a swipe.
  CaravanCommand up(double t) {
    if (!pressed) return CaravanCommand.none;
    pressed = false;
    if (sliding) {
      sliding = false;
      return CaravanCommand.slideEnd;
    }
    if (resolved) return CaravanCommand.none;
    resolved = true;
    return t - downTime < holdDelay * 1.6 ? CaravanCommand.jump : CaravanCommand.none;
  }

  /// The finger lifted after a drag.
  CaravanCommand dragEnd() {
    if (!pressed) return CaravanCommand.none;
    pressed = false;
    if (sliding) {
      sliding = false;
      return CaravanCommand.slideEnd;
    }
    return CaravanCommand.none;
  }

  /// Per tick: a held press turns into a slide.
  CaravanCommand tick(double t) {
    if (pressed && !resolved && !sliding && t - downTime >= holdDelay) {
      sliding = true;
      resolved = true;
      return CaravanCommand.slideStart;
    }
    return CaravanCommand.none;
  }

  void cancel() {
    pressed = false;
    resolved = false;
    sliding = false;
  }
}

// ---------------------------------------------------------------------------
// The Sand-Djinn

/// Which fight Rammal brings to the leg.
enum DjinnPhase { barrels, whirls, scorpion }

/// What the brain is doing.
enum DjinnMode {
  /// Floating / riding in.
  entering,

  /// The taunt card is up; waits for [DjinnBrain.startFight].
  taunt,

  /// Stalking (phase 3): the scorpion picks its next lane.
  stalk,

  /// The tell before an attack.
  windUp,

  /// The attack just launched (the game spawns it when [launchPending]).
  attack,

  /// Breathing between attacks.
  recover,

  /// Took a date.
  hurt,

  /// Beaten: flees / breaks down.
  beaten,
}

/// What the Djinn launches.
enum DjinnAttack { barrel, whirl, sting }

/// The boss's state machine for one phase. The game feeds it the hero's
/// lane, consumes [launchPending] (spawning the projectile) and reports
/// resolved attacks and date hits.
class DjinnBrain {
  DjinnBrain(this.phase, {int seed = 0, this.reducedMotion = false}) : _rng = math.Random(seed + phase.index * 31);

  final DjinnPhase phase;
  final bool reducedMotion;
  final math.Random _rng;

  DjinnMode mode = DjinnMode.entering;
  double timer = 0;
  int attacksLaunched = 0;
  int attacksResolved = 0;
  int dodged = 0;
  int hits = 0;
  bool launchPending = false;
  DjinnAttack nextAttack = DjinnAttack.barrel;
  int targetLane = 1;

  /// The scorpion's lane and sidestep state (phase 3).
  int scorpionLane = 1;
  int scorpionNextLane = 1;
  bool shifting = false;
  double shiftTimer = 0;
  double _stalkFor = 1.1;

  /// Attacks in phases 1–2 (every one counts, dodged or not).
  static const int attacksPerPhase = 7;

  /// Date hits that break the scorpion.
  static const int hitsToBeat = 6;

  /// Phase 2 mixes a barrel into the whirls.
  static const List<DjinnAttack> whirlPattern = [
    DjinnAttack.whirl,
    DjinnAttack.whirl,
    DjinnAttack.barrel,
    DjinnAttack.whirl,
    DjinnAttack.whirl,
    DjinnAttack.barrel,
    DjinnAttack.whirl,
  ];

  double get _tellScale => reducedMotion ? 1.35 : 1;

  double get windUpLength => switch (phase) {
    DjinnPhase.barrels => 0.85 * _tellScale,
    DjinnPhase.whirls => 0.75 * _tellScale,
    DjinnPhase.scorpion => 0.62 * _tellScale,
  };

  /// 0..1 progress of the tell.
  double get windUp => mode == DjinnMode.windUp ? (timer / windUpLength).clamp(0.0, 1.0) : 0;

  /// 1 → 0 as the phase is worn down.
  double get health => switch (phase) {
    DjinnPhase.scorpion => (1 - hits / hitsToBeat).clamp(0.0, 1.0),
    _ => (1 - attacksResolved / attacksPerPhase).clamp(0.0, 1.0),
  };

  bool get beaten => mode == DjinnMode.beaten;
  bool get fighting => mode != DjinnMode.entering && mode != DjinnMode.taunt && mode != DjinnMode.beaten;

  /// The scorpion sits in the hero's lane (a sting may come).
  bool get scorpionInHeroLane => phase == DjinnPhase.scorpion && scorpionLane == targetLane;

  /// The game finished the entrance: the taunt card is up.
  void entered() {
    if (mode != DjinnMode.entering) return;
    mode = DjinnMode.taunt;
    timer = 0;
  }

  /// The card is gone: fight.
  void startFight() {
    if (mode != DjinnMode.taunt) return;
    mode = phase == DjinnPhase.scorpion ? DjinnMode.stalk : DjinnMode.recover;
    timer = phase == DjinnPhase.scorpion ? -0.4 : -0.3;
    _stalkFor = 1.0;
  }

  /// One attack left the stage (dodged or it hit).
  void attackResolved({required bool dodgedIt}) {
    if (phase == DjinnPhase.scorpion) {
      if (dodgedIt) dodged++;
      return;
    }
    attacksResolved++;
    if (dodgedIt) dodged++;
    if (attacksResolved >= attacksPerPhase && attacksLaunched >= attacksPerPhase && mode != DjinnMode.beaten) {
      mode = DjinnMode.beaten;
      timer = 0;
    }
  }

  /// A thrown date landed (phase 3).
  void dateHit() {
    if (phase != DjinnPhase.scorpion || mode == DjinnMode.beaten || mode == DjinnMode.entering || mode == DjinnMode.taunt) {
      return;
    }
    hits++;
    launchPending = false;
    shifting = false;
    if (hits >= hitsToBeat) {
      mode = DjinnMode.beaten;
    } else {
      mode = DjinnMode.hurt;
    }
    timer = 0;
  }

  void update(double dt, {required int heroLane}) {
    targetLane = heroLane;
    timer += dt;
    switch (mode) {
      case DjinnMode.entering || DjinnMode.taunt || DjinnMode.beaten:
        break;
      case DjinnMode.recover:
        final rest = phase == DjinnPhase.scorpion ? 0.9 : 0.55;
        if (timer >= rest) {
          if (phase == DjinnPhase.scorpion) {
            mode = DjinnMode.stalk;
            _stalkFor = 0.8 + _rng.nextDouble() * 0.6;
          } else if (attacksLaunched < attacksPerPhase) {
            mode = DjinnMode.windUp;
            nextAttack = phase == DjinnPhase.barrels ? DjinnAttack.barrel : whirlPattern[attacksLaunched % whirlPattern.length];
            // Aim: mostly the hero's lane, sometimes a neighbour.
            final r = _rng.nextDouble();
            targetLane = r < 0.6 ? heroLane : (heroLane + (r < 0.8 ? 1 : -1)).clamp(0, CaravanStage.laneCount - 1);
          }
          timer = 0;
        }
      case DjinnMode.windUp:
        if (timer >= windUpLength) {
          // Count at the launch, never in recover (ENGINE.md §4).
          mode = DjinnMode.attack;
          launchPending = true;
          attacksLaunched++;
          timer = 0;
        }
      case DjinnMode.attack:
        if (timer >= 0.45) {
          mode = DjinnMode.recover;
          timer = 0;
        }
      case DjinnMode.hurt:
        if (timer >= 0.75) {
          mode = DjinnMode.stalk;
          _stalkFor = 0.7;
          timer = 0;
        }
      case DjinnMode.stalk:
        if (shifting) {
          shiftTimer += dt;
          if (shiftTimer >= 0.42 * _tellScale) {
            scorpionLane = scorpionNextLane;
            shifting = false;
            timer = 0;
            _stalkFor = scorpionLane == heroLane ? 0.25 : 0.8 + _rng.nextDouble() * 0.5;
          }
        } else if (timer >= _stalkFor) {
          if (scorpionLane == heroLane) {
            mode = DjinnMode.windUp;
            nextAttack = DjinnAttack.sting;
            timer = 0;
          } else {
            // Sidestep toward the hero (mostly) or feint elsewhere.
            final toward = heroLane > scorpionLane ? 1 : -1;
            final r = _rng.nextDouble();
            var next = scorpionLane + (r < 0.72 ? toward : -toward);
            next = next.clamp(0, CaravanStage.laneCount - 1);
            if (next == scorpionLane) next = scorpionLane + toward;
            scorpionNextLane = next.clamp(0, CaravanStage.laneCount - 1);
            shifting = true;
            shiftTimer = 0;
          }
        }
    }
  }
}

// ---------------------------------------------------------------------------
// Legs and set pieces

/// What the set shows.
enum SetPiece { dunes, sandstorm, oasis, nightMarket, souk, dawn }

/// The journey: three legs with their set pieces and speed ramps.
abstract final class LegPlan {
  static SetPiece pieceAt(int leg, double progress) => switch (leg) {
    0 => progress < 0.3 || progress > 0.72 ? SetPiece.dunes : SetPiece.sandstorm,
    1 => progress < 0.36 ? SetPiece.oasis : SetPiece.nightMarket,
    _ => progress < 0.44 ? SetPiece.souk : SetPiece.dawn,
  };

  /// 0..1 how thick the sandstorm is at [progress] of leg 0.
  static double storm(int leg, double progress) {
    if (leg != 0) return 0;
    const inAt = 0.3, full = 0.4, outAt = 0.64, gone = 0.74;
    if (progress < inAt || progress > gone) return 0;
    if (progress < full) return (progress - inAt) / (full - inAt);
    if (progress > outAt) return 1 - (progress - outAt) / (gone - outAt);
    return 1;
  }

  /// 0..1 how dark the night is (leg 1 becomes the night market; the boss
  /// fight and leg 2's souk are still night, dawn breaks after it).
  static double night(int leg, double progress) => switch (leg) {
    1 => ((progress - 0.3) / 0.12).clamp(0.0, 1.0),
    2 => progress < 0.44 ? 1 : (1 - (progress - 0.44) / 0.2).clamp(0.0, 1.0),
    _ => 0,
  };

  /// Ground speed (units/s) at [progress] of [leg].
  static double speed(int leg, double progress) {
    final base = 236 + leg * 18.0;
    return base + 92 * progress.clamp(0.0, 1.0);
  }

  /// Spawner difficulty at [progress] of [leg].
  static int difficulty(int leg, double progress) => (leg * 1.5 + progress * 2.2).floor().clamp(0, 4);

  /// Speed while the boss is on (steady, a little brisk).
  static double bossSpeed(int leg) => 300 + leg * 20.0;

  /// The sprint after the scorpion breaks.
  static const double sprintSpeed = 440;
}

// ---------------------------------------------------------------------------
// The attract bot

/// Plays the run by itself: reads the nearest things in the hero's lane and
/// jumps, slides, hops lanes, picks up dates and pelts the scorpion.
class CaravanBot {
  CaravanBot({int seed = 3}) : _rng = math.Random(seed);

  final math.Random _rng;
  double _cooldown = 0;
  double _throwCooldown = 0;

  /// Decides at most one command per tick.
  CaravanCommand decide(double dt, HeroBody hero, TrackPool pool, double speed, {DjinnBrain? boss, int ammo = 0}) {
    _cooldown = math.max(0, _cooldown - dt);
    _throwCooldown = math.max(0, _throwCooldown - dt);
    if (!hero.alive) return CaravanCommand.none;
    // The scorpion in my lane and ammo in the pouch: throw.
    if (boss != null && boss.phase == DjinnPhase.scorpion && boss.fighting && ammo > 0 && _throwCooldown <= 0 && boss.scorpionLane == hero.lane && !boss.shifting) {
      _throwCooldown = 0.5;
      return CaravanCommand.throwDate;
    }
    if (_cooldown > 0) return CaravanCommand.none;
    final react = speed * 0.5 + 40;
    TrackItem? threat;
    var threatDx = double.infinity;
    for (final it in pool.items) {
      if (!it.active || it.resolved || !it.kind.isHazard) continue;
      if (it.lane != hero.lane && !(it.kind == TrackKind.sandDevil || it.kind == TrackKind.whirl) ) continue;
      if ((it.kind == TrackKind.sandDevil || it.kind == TrackKind.whirl) && it.laneTarget != hero.lane && it.lane != hero.lane) continue;
      final dx = it.x - CaravanStage.heroX;
      if (dx < -10 || dx > react) continue;
      if (dx < threatDx) {
        threat = it;
        threatDx = dx;
      }
    }
    if (threat != null) {
      final kind = threat.kind;
      if (kind == TrackKind.bar) {
        if (!hero.sliding && hero.onGround && threatDx < react * 0.7) {
          _cooldown = 0.4;
          return CaravanCommand.slideStart;
        }
        return CaravanCommand.none;
      }
      if (kind == TrackKind.tallCart || kind == TrackKind.whirl) {
        if (threatDx < react * 0.85) {
          _cooldown = 0.45;
          return _freeLane(hero, pool);
        }
        return CaravanCommand.none;
      }
      // Jumpable: jump when it is a jump's travel away.
      final jumpAt = speed * HeroBody.airTime * 0.42 + kind.halfWidth;
      if (hero.onGround && threatDx <= jumpAt + 8) {
        _cooldown = 0.3;
        return CaravanCommand.jump;
      }
      return CaravanCommand.none;
    }
    if (hero.sliding && hero.slideTime > HeroBody.minSlide) return CaravanCommand.slideEnd;
    // Pickups: a lantern or a date arc overhead → jump; dates in the next
    // lane → hop when the lane is safe.
    for (final it in pool.items) {
      if (!it.active || it.resolved || !it.kind.isPickup) continue;
      final dx = it.x - CaravanStage.heroX;
      if (dx < 0 || dx > react * 0.6) continue;
      if (it.lane == hero.lane && it.lift > 50 && hero.onGround && dx < speed * HeroBody.airTime * 0.45) {
        _cooldown = 0.3;
        return CaravanCommand.jump;
      }
      if (it.lane != hero.lane && (it.lane - hero.lane).abs() == 1 && it.lift < 30 && hero.onGround && _rng.nextDouble() < 0.5) {
        if (_laneSafe(it.lane, pool, react)) {
          _cooldown = 0.5;
          return it.lane < hero.lane ? CaravanCommand.laneBack : CaravanCommand.laneFront;
        }
      }
    }
    return CaravanCommand.none;
  }

  bool _laneSafe(int lane, TrackPool pool, double react) {
    for (final it in pool.items) {
      if (!it.active || it.resolved || !it.kind.isHazard) continue;
      if (it.lane != lane && it.laneTarget != lane) continue;
      final dx = it.x - CaravanStage.heroX;
      if (dx > -40 && dx < react * 1.1) return false;
    }
    return true;
  }

  CaravanCommand _freeLane(HeroBody hero, TrackPool pool) {
    final react = 220.0;
    final options = <int>[];
    for (var l = 0; l < CaravanStage.laneCount; l++) {
      if ((l - hero.lane).abs() != 1) continue;
      if (_laneSafe(l, pool, react)) options.add(l);
    }
    if (options.isEmpty) return CaravanCommand.jump;
    final l = options[_rng.nextInt(options.length)];
    return l < hero.lane ? CaravanCommand.laneBack : CaravanCommand.laneFront;
  }
}
