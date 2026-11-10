/// Metropolis Machine – the pure rules: the hero's body (run, jump, dash,
/// wrench strike, i-frames, one-way lift platforms), the pooled hazards the
/// machines throw at him (telegraph → danger → gone), the five boss brains
/// (state machines with two phase changes each and an open "weak window"
/// after every attack), scoring and the attract-mode bot.
///
/// No Flutter or Flame here: everything is plain Dart on game time, so the
/// tests drive it headlessly and the scene only paints what it reads.
library;

import 'dart:math' as math;
import 'dart:ui' show Rect;

/// World-unit constants shared with the scene.
abstract final class MetroStage {
  static const double width = 360;
  static const double height = 800;
  static const double groundY = 640;

  /// The camera "contains" the world; the set paints beyond the sides.
  static const double paintLeft = -80;
  static const double paintRight = 440;

  /// Where the hero may run.
  static const double heroMinX = 26;
  static const double heroMaxX = 334;

  /// Where the hero starts a fight.
  static const double heroStartX = 92;

  static const int bossCount = 5;

  /// Floor vents of the boiler hall (and the dynamo's).
  static const List<double> vents = [44, 110, 176, 242];
}

/// The five machines, in order.
enum MetroBoss { clockPress, boilerHeart, switchboardSpider, liftTitan, motherDynamo }

extension MetroBossInfo on MetroBoss {
  /// Where the machine stands (its origin x in world units).
  double get standX => switch (this) {
    MetroBoss.clockPress => 268,
    MetroBoss.boilerHeart => 284,
    MetroBoss.switchboardSpider => 258,
    MetroBoss.liftTitan => 274,
    MetroBoss.motherDynamo => 302,
  };

  /// The hero cannot run past this x while the machine stands: its body
  /// is solid (every weak spot stays within the wrench's reach from here).
  double get heroLimit => switch (this) {
    MetroBoss.clockPress => standX - 82,
    MetroBoss.boilerHeart => standX - 126,
    MetroBoss.switchboardSpider => standX - 96,
    MetroBoss.liftTitan => standX - 96,
    MetroBoss.motherDynamo => standX - 128,
  };

  int get maxHp => switch (this) {
    MetroBoss.clockPress => 8,
    MetroBoss.boilerHeart => 9,
    MetroBoss.switchboardSpider => 9,
    MetroBoss.liftTitan => 10,
    MetroBoss.motherDynamo => 14,
  };

  /// Height of the drawing (world units).
  double get height => switch (this) {
    MetroBoss.clockPress => 330,
    MetroBoss.boilerHeart => 250,
    MetroBoss.switchboardSpider => 210,
    MetroBoss.liftTitan => 330,
    MetroBoss.motherDynamo => 320,
  };
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// Numbers that make the hero feel right (world units, seconds).
abstract final class HeroTuning {
  static const double height = 112;
  static const double halfWidth = 19;
  static const double runSpeed = 240;
  static const double accel = 2600;
  static const double brake = 3400;
  static const double gravity = 2400;
  static const double jumpSpeed = 880;

  /// Releasing the jump early cuts the rise to this fraction of jumpSpeed.
  static const double jumpCut = 0.42;
  static const double dashSpeed = 640;
  static const double dashTime = 0.18;
  static const double dashCooldown = 0.5;
  static const double dashIFrames = 0.26;
  static const double strikeActiveFrom = 0.05;
  static const double strikeActiveTo = 0.2;
  static const double strikeLength = 0.32;
  static const double strikeReach = 70;
  static const double hurtIFrames = 1.25;
  static const double hurtStun = 0.28;
  static const double hurtKnock = 240;
  static const double coyote = 0.09;
  static const double jumpBuffer = 0.12;
  static const double dropTime = 0.22;
}

/// What the player (or the bot) asks this tick. Edges are consumed by
/// [HeroBody.update].
class HeroInput {
  /// Held direction −1..1.
  double move = 0;

  /// Jump pressed this tick.
  bool jump = false;

  /// Jump still held (variable height).
  bool jumpHeld = false;

  /// Wrench strike pressed this tick.
  bool strike = false;

  /// Dash pressed this tick: −1 / 0 / 1.
  int dash = 0;

  /// Drop through a platform this tick.
  bool drop = false;

  void clearEdges() {
    jump = false;
    strike = false;
    dash = 0;
    drop = false;
  }

  void clear() {
    clearEdges();
    move = 0;
    jumpHeld = false;
  }
}

/// A one-way lift car the hero can stand on (top at [y], centred at [x]).
class MovingPlatform {
  bool active = false;
  double x = 0;
  double y = MetroStage.groundY;
  double w = 90;
  double yTop = MetroStage.groundY - 230;
  double yBottom = MetroStage.groundY - 90;
  double speed = 40;

  /// 0..1 position along the shaft (0 = bottom), with a direction.
  double t = 0;
  double dir = 1;
  double vy = 0;

  Rect get box => Rect.fromLTRB(x - w / 2, y - 14, x + w / 2, y);

  void place(double x, {double t = 0, double dir = 1, double speed = 40, double w = 90}) {
    active = true;
    this.x = x;
    this.t = t;
    this.dir = dir;
    this.speed = speed;
    this.w = w;
    y = yBottom + (yTop - yBottom) * t;
    vy = 0;
  }

  void update(double dt) {
    if (!active) return;
    final span = (yBottom - yTop).abs();
    final before = y;
    t += dir * dt * speed / span;
    if (t >= 1) {
      t = 1;
      dir = -1;
    } else if (t <= 0) {
      t = 0;
      dir = 1;
    }
    // Ease at the ends like a real lift.
    final e = t * t * (3 - 2 * t);
    y = yBottom + (yTop - yBottom) * e;
    vy = dt > 0 ? (y - before) / dt : 0;
  }
}

/// The hero's body: a point between the feet, y down, plus the timers of
/// his moves. Pure; the rig only poses from it.
class HeroBody {
  HeroBody({this.x = MetroStage.heroStartX});

  double x;
  double y = MetroStage.groundY;
  double vx = 0;
  double vy = 0;
  double facing = 1;
  bool onGround = true;

  /// The right-hand wall (a machine's body while it stands).
  double maxX = MetroStage.heroMaxX;

  /// Index of the platform ridden, −1 on the floor / in the air.
  int platform = -1;

  double dashLeft = 0;
  double dashCooldownLeft = 0;
  double iFrames = 0;

  /// Seconds since the strike started, −1 = none.
  double strikeTime = -1;
  double strikeCooldownLeft = 0;
  double coyoteLeft = 0;
  double jumpBufferLeft = 0;
  double stunLeft = 0;
  double dropLeft = 0;

  /// One hit per swing.
  bool strikeConsumed = false;

  // Events of the last update (the scene plays sounds / puffs from them).
  bool landed = false;
  bool jumped = false;
  bool dashed = false;
  bool struck = false;

  bool get dashing => dashLeft > 0;
  bool get striking => strikeTime >= HeroTuning.strikeActiveFrom && strikeTime <= HeroTuning.strikeActiveTo;
  bool get swinging => strikeTime >= 0;
  bool get invulnerable => iFrames > 0 || dashLeft > 0;
  bool get stunned => stunLeft > 0;

  /// Where he can be hit.
  Rect get hitBox =>
      Rect.fromLTRB(x - HeroTuning.halfWidth, y - HeroTuning.height * 0.92, x + HeroTuning.halfWidth, y - 2);

  /// Where the wrench hits while [striking].
  Rect get strikeBox {
    final from = x + facing * 4, to = x + facing * HeroTuning.strikeReach;
    return Rect.fromLTRB(math.min(from, to), y - HeroTuning.height * 0.95, math.max(from, to), y - HeroTuning.height * 0.12);
  }

  void reset({double? x}) {
    if (x != null) this.x = x;
    if (this.x > maxX) this.x = maxX;
    y = MetroStage.groundY;
    vx = 0;
    vy = 0;
    facing = 1;
    onGround = true;
    platform = -1;
    dashLeft = 0;
    dashCooldownLeft = 0;
    iFrames = 0;
    strikeTime = -1;
    strikeCooldownLeft = 0;
    coyoteLeft = 0;
    jumpBufferLeft = 0;
    stunLeft = 0;
    dropLeft = 0;
    strikeConsumed = false;
  }

  /// Knocked by something at [fromX]: stun, i-frames, a hop back.
  void hurt(double fromX) {
    iFrames = HeroTuning.hurtIFrames;
    stunLeft = HeroTuning.hurtStun;
    vx = (x <= fromX ? -1 : 1) * HeroTuning.hurtKnock;
    vy = -320;
    onGround = false;
    platform = -1;
    dashLeft = 0;
    strikeTime = -1;
  }

  void update(double dt, HeroInput input, List<MovingPlatform> platforms, {bool controllable = true}) {
    landed = false;
    jumped = false;
    dashed = false;
    struck = false;
    if (dt <= 0) return;
    final wasGround = onGround;
    final prevY = y;
    final ctl = controllable && stunLeft <= 0;

    // Timers.
    if (iFrames > 0) iFrames -= dt;
    if (dashCooldownLeft > 0) dashCooldownLeft -= dt;
    if (strikeCooldownLeft > 0) strikeCooldownLeft -= dt;
    if (coyoteLeft > 0) coyoteLeft -= dt;
    if (jumpBufferLeft > 0) jumpBufferLeft -= dt;
    if (stunLeft > 0) stunLeft -= dt;
    if (dropLeft > 0) dropLeft -= dt;
    if (strikeTime >= 0) {
      strikeTime += dt;
      if (strikeTime > HeroTuning.strikeLength) strikeTime = -1;
    }

    // Dash.
    if (ctl && input.dash != 0 && dashCooldownLeft <= 0 && !dashing) {
      dashLeft = HeroTuning.dashTime;
      dashCooldownLeft = HeroTuning.dashCooldown;
      facing = input.dash < 0 ? -1 : 1;
      iFrames = math.max(iFrames, HeroTuning.dashIFrames);
      strikeTime = -1;
      dashed = true;
    }
    if (dashing) {
      dashLeft -= dt;
      vx = facing * HeroTuning.dashSpeed;
      vy = math.min(vy, 0);
    } else if (ctl) {
      final target = input.move.clamp(-1.0, 1.0) * HeroTuning.runSpeed;
      final rate = (target == 0 || target.sign != vx.sign) ? HeroTuning.brake : HeroTuning.accel;
      if (vx < target) {
        vx = math.min(target, vx + rate * dt);
      } else if (vx > target) {
        vx = math.max(target, vx - rate * dt);
      }
      if (input.move.abs() > 0.1 && !swinging) facing = input.move < 0 ? -1 : 1;
    } else {
      // Stunned / scripted: slow to a stop on the ground.
      if (onGround) {
        final rate = HeroTuning.brake * dt;
        vx = vx.abs() <= rate ? 0 : vx - vx.sign * rate;
      }
    }

    // Jump (buffered, with coyote time).
    if (ctl && input.jump) jumpBufferLeft = HeroTuning.jumpBuffer;
    if (ctl && jumpBufferLeft > 0 && (onGround || coyoteLeft > 0) && !dashing) {
      vy = -HeroTuning.jumpSpeed;
      onGround = false;
      platform = -1;
      coyoteLeft = 0;
      jumpBufferLeft = 0;
      jumped = true;
    }
    if (ctl && !input.jumpHeld && vy < -HeroTuning.jumpSpeed * HeroTuning.jumpCut && !dashing) {
      vy = -HeroTuning.jumpSpeed * HeroTuning.jumpCut;
    }

    // Drop through a platform.
    if (ctl && input.drop && platform >= 0) {
      dropLeft = HeroTuning.dropTime;
      platform = -1;
      onGround = false;
      y += 3;
    }

    // Strike.
    if (ctl && input.strike && strikeCooldownLeft <= 0 && !dashing) {
      strikeTime = 0;
      strikeCooldownLeft = HeroTuning.strikeLength;
      strikeConsumed = false;
      struck = true;
    }

    // Gravity and motion.
    if (!onGround && !dashing) vy += HeroTuning.gravity * dt;
    x += vx * dt;
    if (!onGround || platform < 0) y += vy * dt;
    if (x < MetroStage.heroMinX) {
      x = MetroStage.heroMinX;
      if (vx < 0) vx = 0;
    } else if (x > maxX) {
      x = maxX;
      if (vx > 0) vx = 0;
    }

    // Riding a platform: follow it (and fall off its ends).
    if (platform >= 0) {
      final p = platforms[platform];
      if (!p.active || (x - p.x).abs() > p.w / 2 + 6) {
        platform = -1;
        onGround = false;
        coyoteLeft = HeroTuning.coyote;
      } else {
        y = p.y;
        vy = 0;
        onGround = true;
      }
    }
    // Landing on a platform from above (one-way).
    if (platform < 0 && vy >= 0 && dropLeft <= 0 && !dashing) {
      for (var i = 0; i < platforms.length; i++) {
        final p = platforms[i];
        if (!p.active) continue;
        if ((x - p.x).abs() > p.w / 2 + 6) continue;
        final top = p.y;
        if (prevY <= top + 4 + math.max(0, p.vy * dt) && y >= top) {
          y = top;
          vy = 0;
          platform = i;
          onGround = true;
          break;
        }
      }
    }
    // The floor.
    if (y >= MetroStage.groundY) {
      y = MetroStage.groundY;
      vy = 0;
      onGround = true;
      platform = -1;
    } else if (platform < 0) {
      if (onGround) coyoteLeft = HeroTuning.coyote;
      onGround = false;
    }
    if (onGround && !wasGround) landed = true;
  }
}

// ---------------------------------------------------------------------------
// Hazards
// ---------------------------------------------------------------------------

/// What a hazard is (the painter draws each kind in its own way).
enum HazardKind {
  /// The press head coming down on a spot (telegraph: its shadow grows).
  stamp,

  /// A dust wave racing along the floor (jump it).
  shockwave,

  /// A column of steam from a floor vent (telegraph: the cap rattles).
  steamJet,

  /// A low blast of steam rolling along the floor (jump it).
  steamBlast,

  /// A glowing rivet lobbed at the hero (parry it back).
  rivet,

  /// A cable plug plunging from above onto a spot.
  cableStab,

  /// A cable sweeping the floor (jump it).
  cableSweep,

  /// A bolt falling from the shaft above.
  bolt,

  /// A ball of sparks rolling along the floor (parry it back).
  spark,

  /// A dynamo piston stamping a spot.
  piston,

  /// A cog flung in an arc (parry it back).
  cog,

  /// The titan's hook hand sweeping across at one height.
  grab,
}

extension HazardKindInfo on HazardKind {
  bool get parryable => this == HazardKind.rivet || this == HazardKind.spark || this == HazardKind.cog;

  /// Projectiles move; the rest stay where they are telegraphed.
  bool get projectile => switch (this) {
    HazardKind.rivet || HazardKind.bolt || HazardKind.spark || HazardKind.cog => true,
    _ => false,
  };
}

/// One pooled hazard. [x] is the centre, [y] the BOTTOM of its box (floor
/// things stand on y = groundY).
class Hazard {
  bool active = false;
  HazardKind kind = HazardKind.stamp;
  double x = 0;
  double y = MetroStage.groundY;
  double w = 40;
  double h = 40;
  double vx = 0;
  double vy = 0;

  /// Seconds until it becomes dangerous (shown as a telegraph meanwhile).
  double telegraph = 0;

  /// Total telegraph (for the painter's progress).
  double telegraphTotal = 0;

  /// Seconds of danger left once armed.
  double life = 0;
  double lifeTotal = 0;
  double age = 0;
  bool gravity = false;
  bool parried = false;
  bool hitHero = false;
  bool hitBoss = false;

  /// Free number for the painter / rig (e.g. a vent index, a sweep side).
  double param = 0;
  int salt = 0;

  bool get armed => active && telegraph <= 0;
  double get telegraphProgress => telegraphTotal <= 0 ? 1 : (1 - telegraph / telegraphTotal).clamp(0.0, 1.0);
  double get lifeProgress => lifeTotal <= 0 ? 1 : (1 - life / lifeTotal).clamp(0.0, 1.0);

  Rect get box => Rect.fromLTRB(x - w / 2, y - h, x + w / 2, y);

  void spawn(
    HazardKind kind, {
    required double x,
    double y = MetroStage.groundY,
    required double w,
    required double h,
    double vx = 0,
    double vy = 0,
    double telegraph = 0,
    double life = 1,
    bool gravity = false,
    double param = 0,
    int salt = 0,
  }) {
    active = true;
    this.kind = kind;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.vx = vx;
    this.vy = vy;
    this.telegraph = telegraph;
    telegraphTotal = telegraph;
    this.life = life;
    lifeTotal = life;
    this.gravity = gravity;
    this.param = param;
    this.salt = salt;
    age = 0;
    parried = false;
    hitHero = false;
    hitBoss = false;
  }

  /// Knocked back by the wrench: flies the other way, a little up.
  void parry(double facing) {
    parried = true;
    vx = facing * math.max(520, vx.abs() * 1.3);
    vy = -260;
    gravity = true;
    life = 2.2;
    lifeTotal = 2.2;
    hitHero = false;
  }

  void update(double dt) {
    if (!active) return;
    age += dt;
    if (telegraph > 0) {
      telegraph -= dt;
      if (telegraph > 0) return;
    }
    life -= dt;
    if (gravity) vy += 1900 * dt;
    x += vx * dt;
    y += vy * dt;
    if (kind.projectile && !parried && y >= MetroStage.groundY && vy > 0) {
      // Rolls on along the floor.
      y = MetroStage.groundY;
      vy = kind == HazardKind.bolt ? 0 : -vy * 0.35;
      if (kind == HazardKind.bolt) {
        vx = 0;
        gravity = false;
        life = math.min(life, 0.35);
      }
    }
    if (life <= 0 || x < MetroStage.paintLeft - 60 || x > MetroStage.paintRight + 60 || y > MetroStage.height + 80) {
      active = false;
    }
  }
}

/// A fixed pool of hazards.
class HazardPool {
  HazardPool([int count = 28]) : items = List.generate(count, (_) => Hazard());

  final List<Hazard> items;

  Hazard? free() {
    for (final h in items) {
      if (!h.active) return h;
    }
    return null;
  }

  int get activeCount {
    var n = 0;
    for (final h in items) {
      if (h.active) n++;
    }
    return n;
  }

  void update(double dt) {
    for (final h in items) {
      h.update(dt);
    }
  }

  void clear() {
    for (final h in items) {
      h.active = false;
    }
  }
}

// ---------------------------------------------------------------------------
// Boss brains
// ---------------------------------------------------------------------------

/// What a brain is doing.
enum BossMode {
  /// Rolling onto the stage (the scene animates it).
  entering,

  /// Catching its breath before the next attack.
  idle,

  /// The tell: the attack is announced, hazards are telegraphed.
  telegraph,

  /// The attack itself (hazards armed).
  attack,

  /// The weak spot is exposed – strike now.
  open,

  /// Winding back up after a window (or after a phase change roar).
  recover,

  /// Falling apart.
  dying,
  dead,
}

/// The moves of the five machines.
enum AttackKind {
  stamp,
  stampSweep,
  cogToss,
  jets,
  blast,
  rivets,
  whistle,
  stab,
  sweep,
  drop,
  sparks,
  grab,
  boltRain,
  punch,
  pistons,
  overload,
}

enum BossEventKind {
  /// The tell of [BossEvent.attack] started.
  telegraph,

  /// The attack of [BossEvent.attack] lands now.
  strike,

  /// The weak window opened.
  open,

  /// The weak window closed.
  close,

  /// Phase [BossEvent.i] begins.
  phase,

  /// The machine is beaten.
  dead,
}

/// A thing the brain tells the scene (reused objects, never allocated per tick).
class BossEvent {
  BossEventKind kind = BossEventKind.telegraph;
  AttackKind attack = AttackKind.stamp;
  double x = 0;
  double y = 0;
  int i = 0;
}

/// Difficulty knobs by boss, phase and the assist level (which rises when
/// the player loses a reel, so the show stays beatable).
abstract final class MetroTuning {
  static double speed(MetroBoss boss, int phase, int assist) {
    final s = 1 - 0.11 * phase - 0.04 * boss.index;
    return (s * (1 + 0.14 * assist)).clamp(0.55, 1.4);
  }

  static double idleGap(MetroBoss boss, int phase, int assist, {bool reducedMotion = false}) =>
      switch (boss) {
        MetroBoss.clockPress => 1.0,
        MetroBoss.boilerHeart => 1.0,
        MetroBoss.switchboardSpider => 0.9,
        MetroBoss.liftTitan => 1.0,
        MetroBoss.motherDynamo => 0.85,
      } *
      speed(boss, phase, assist);

  static double telegraph(MetroBoss boss, int phase, int assist, {bool reducedMotion = false}) =>
      switch (boss) {
        MetroBoss.clockPress => 1.0,
        MetroBoss.boilerHeart => 0.95,
        MetroBoss.switchboardSpider => 0.85,
        MetroBoss.liftTitan => 0.9,
        MetroBoss.motherDynamo => 0.85,
      } *
      speed(boss, phase, assist) *
      (reducedMotion ? 1.3 : 1);

  static double openWindow(MetroBoss boss, int phase, int assist) =>
      (switch (boss) {
            MetroBoss.clockPress => 1.1,
            MetroBoss.boilerHeart => 1.2,
            MetroBoss.switchboardSpider => 1.0,
            MetroBoss.liftTitan => 1.1,
            MetroBoss.motherDynamo => 1.0,
          } -
          0.12 * phase) *
      (1 + 0.1 * assist);

  /// Music intensity for a phase (the ragtime piano speeds up).
  static double intensity(MetroBoss boss, int phase) => (0.42 + 0.24 * phase + 0.04 * boss.index).clamp(0.0, 1.0);
}

/// The attack lists each machine cycles through, by phase.
const Map<MetroBoss, List<List<AttackKind>>> metroAttackScript = {
  MetroBoss.clockPress: [
    [AttackKind.stamp, AttackKind.stamp, AttackKind.cogToss],
    [AttackKind.stamp, AttackKind.cogToss, AttackKind.stamp, AttackKind.stampSweep],
    [AttackKind.stampSweep, AttackKind.cogToss, AttackKind.stamp, AttackKind.stampSweep],
  ],
  MetroBoss.boilerHeart: [
    [AttackKind.jets, AttackKind.blast, AttackKind.jets],
    [AttackKind.jets, AttackKind.rivets, AttackKind.blast, AttackKind.jets],
    [AttackKind.whistle, AttackKind.rivets, AttackKind.blast, AttackKind.jets, AttackKind.whistle],
  ],
  MetroBoss.switchboardSpider: [
    [AttackKind.stab, AttackKind.stab, AttackKind.sweep],
    [AttackKind.stab, AttackKind.sweep, AttackKind.drop, AttackKind.stab],
    [AttackKind.stab, AttackKind.sparks, AttackKind.sweep, AttackKind.drop, AttackKind.sparks],
  ],
  MetroBoss.liftTitan: [
    [AttackKind.punch, AttackKind.grab, AttackKind.boltRain],
    [AttackKind.grab, AttackKind.boltRain, AttackKind.punch, AttackKind.grab],
    [AttackKind.grab, AttackKind.grab, AttackKind.boltRain, AttackKind.punch],
  ],
  MetroBoss.motherDynamo: [
    [AttackKind.pistons, AttackKind.jets, AttackKind.stab],
    [AttackKind.pistons, AttackKind.sparks, AttackKind.jets, AttackKind.sweep, AttackKind.pistons],
    [AttackKind.overload, AttackKind.sparks, AttackKind.stab, AttackKind.overload, AttackKind.pistons],
  ],
};

/// The state machine of one machine. The scene calls [update] every tick
/// with the hero's position, then reads [events] (and clears them), spawns
/// hazards for `telegraph`/`strike` events and checks strikes against
/// [weakBox] while [vulnerable].
class BossBrain {
  BossBrain(this.kind, {int seed = 0, this.assist = 0, this.reducedMotion = false})
    : hp = kind.maxHp,
      maxHp = kind.maxHp,
      rng = math.Random(seed);

  final MetroBoss kind;
  final math.Random rng;
  int hp;
  final int maxHp;
  int phase = 0;
  int assist;
  final bool reducedMotion;
  BossMode mode = BossMode.entering;
  double timer = 0;
  double modeLength = 1.6;
  AttackKind attack = AttackKind.stamp;
  int attackNo = 0;

  /// Tests and screenshots: the next attack to pick instead of the script.
  AttackKind? forcedAttack;

  /// Where the current attack aims (the hero's x when the tell began).
  double targetX = MetroStage.heroStartX;
  double targetY = MetroStage.groundY;

  /// Weak box while [vulnerable] (bottom-anchored like hazards).
  double weakX = 0;
  double weakY = MetroStage.groundY;
  double weakW = 60;
  double weakH = 60;

  /// Seconds left of the hurt pose after a hit.
  double hurtLeft = 0;

  /// Wrench hits taken in the current window; the machine recoils after
  /// [hitsPerWindow] so a fight is a rhythm of openings, not a beating.
  int windowHits = 0;
  static const int hitsPerWindow = 2;

  /// Sub-step of multi-part attacks (a sweep's stamps).
  int step = 0;

  final List<BossEvent> events = [];
  final List<BossEvent> _pool = List.generate(24, (_) => BossEvent());
  int _poolAt = 0;

  double get standX => kind.standX;
  bool get vulnerable => mode == BossMode.open;
  bool get alive => mode != BossMode.dying && mode != BossMode.dead;
  bool get fighting => mode != BossMode.entering && alive;
  double get health => (hp / maxHp).clamp(0.0, 1.0);

  /// The tell's progress 0..1 (rigs lean into it).
  double get windUp => mode == BossMode.telegraph ? (timer / modeLength).clamp(0.0, 1.0) : 0;

  /// Progress of the current mode 0..1.
  double get progress => modeLength <= 0 ? 1 : (timer / modeLength).clamp(0.0, 1.0);

  Rect get weakBox => Rect.fromLTRB(weakX - weakW / 2, weakY - weakH, weakX + weakW / 2, weakY);

  BossEvent _emit(BossEventKind k, {AttackKind? attack, double x = 0, double y = 0, int i = 0}) {
    final e = _pool[_poolAt];
    _poolAt = (_poolAt + 1) % _pool.length;
    e
      ..kind = k
      ..attack = attack ?? this.attack
      ..x = x
      ..y = y
      ..i = i;
    events.add(e);
    return e;
  }

  void _enter(BossMode m, double length) {
    mode = m;
    timer = 0;
    modeLength = length;
  }

  /// The entrance is over: fight.
  void startFight() {
    if (mode != BossMode.entering) return;
    _enter(BossMode.idle, 0.8);
  }

  /// Jumps straight to [phase] with the matching health (tests, screenshots).
  void debugSetPhase(int p) {
    phase = p.clamp(0, 2);
    hp = switch (phase) { 0 => maxHp, 1 => (maxHp * 2 / 3).floor(), _ => (maxHp / 3).floor() };
    if (hp < 1) hp = 1;
  }

  /// Tests and screenshots: makes [k] the next attack and starts it at once
  /// when the machine is between moves.
  void debugAttackNow(AttackKind k) {
    forcedAttack = k;
    if (mode == BossMode.idle || mode == BossMode.recover || mode == BossMode.open) _enter(BossMode.idle, 0.001);
  }

  List<AttackKind> get _script => metroAttackScript[kind]![phase];

  double _telegraphLen() => MetroTuning.telegraph(kind, phase, assist, reducedMotion: reducedMotion);

  void update(double dt, double heroX, double heroY) {
    if (hurtLeft > 0) hurtLeft -= dt;
    timer += dt;
    switch (mode) {
      case BossMode.entering:
      case BossMode.dead:
        return;
      case BossMode.dying:
        if (timer >= modeLength) _enter(BossMode.dead, 0);
      case BossMode.idle:
        if (timer >= modeLength) _beginAttack(heroX, heroY);
      case BossMode.telegraph:
        if (timer >= modeLength) _beginStrike(heroX, heroY);
      case BossMode.attack:
        _attackTick(heroX, heroY);
        if (timer >= modeLength) _afterAttack();
      case BossMode.open:
        if (timer >= modeLength) {
          _emit(BossEventKind.close);
          _enter(BossMode.recover, 0.55 * MetroTuning.speed(kind, phase, assist));
        }
      case BossMode.recover:
        if (timer >= modeLength) _enter(BossMode.idle, MetroTuning.idleGap(kind, phase, assist));
    }
  }

  void _beginAttack(double heroX, double heroY) {
    final script = _script;
    attack = forcedAttack ?? script[attackNo % script.length];
    forcedAttack = null;
    attackNo++;
    step = 0;
    targetX = heroX.clamp(MetroStage.heroMinX + 30, math.min(kind.heroLimit, MetroStage.heroMaxX - 24));
    targetY = heroY;
    _enter(BossMode.telegraph, _telegraphLen());
    _emit(BossEventKind.telegraph, x: targetX, y: targetY);
  }

  void _beginStrike(double heroX, double heroY) {
    final len = switch (attack) {
      AttackKind.stamp || AttackKind.pistons || AttackKind.punch => 0.3,
      AttackKind.stampSweep => 1.35,
      AttackKind.cogToss => 0.4,
      AttackKind.jets => 1.0,
      AttackKind.blast => 1.1,
      AttackKind.rivets => 0.8,
      AttackKind.whistle => 1.9,
      AttackKind.stab => 0.45,
      AttackKind.sweep => 1.0,
      AttackKind.drop => 0.55,
      AttackKind.sparks => 0.9,
      AttackKind.grab => 0.9,
      AttackKind.boltRain => 1.4,
      AttackKind.overload => 2.1,
    };
    _enter(BossMode.attack, len);
    step = 0;
    _emit(BossEventKind.strike, x: targetX, y: targetY, i: 0);
  }

  /// Multi-part strikes emit their later parts here.
  void _attackTick(double heroX, double heroY) {
    switch (attack) {
      case AttackKind.stampSweep:
        // Three stamps marching across the hall (step 0 fired at start).
        final at = 0.45 * (step + 1);
        if (step < 2 && timer >= at) {
          step++;
          _emit(BossEventKind.strike, x: targetX, i: step);
        }
      case AttackKind.overload:
        final at = 0.7 * (step + 1);
        if (step < 2 && timer >= at) {
          step++;
          _emit(BossEventKind.strike, x: heroX.clamp(MetroStage.heroMinX + 30, MetroStage.heroMaxX - 24), i: step);
        }
      case AttackKind.grab when phase == 2:
        if (step < 1 && timer >= 0.5) {
          step++;
          _emit(BossEventKind.strike, x: targetX, y: heroY, i: step);
        }
      default:
    }
  }

  void _afterAttack() {
    _placeWeakBox();
    windowHits = 0;
    _enter(BossMode.open, MetroTuning.openWindow(kind, phase, assist));
    _emit(BossEventKind.open, x: weakX, y: weakY);
  }

  /// Where the wrench must land for this machine after this attack.
  void _placeWeakBox() {
    switch (kind) {
      case MetroBoss.clockPress:
        // The hammer head resting on the floor where it last stamped.
        weakX = attack == AttackKind.stampSweep ? targetX + 60 : (attack == AttackKind.cogToss ? standX - 70 : targetX);
        weakY = MetroStage.groundY;
        weakW = 130;
        weakH = 64;
      case MetroBoss.boilerHeart:
        // The valve in the open furnace door.
        weakX = standX - 100;
        weakY = MetroStage.groundY - 10;
        weakW = 60;
        weakH = 78;
      case MetroBoss.switchboardSpider:
        if (attack == AttackKind.stab) {
          weakX = targetX;
          weakY = MetroStage.groundY;
          weakW = 46;
          weakH = 96;
        } else {
          weakX = standX - 40;
          weakY = MetroStage.groundY - 8;
          weakW = 120;
          weakH = 76;
        }
      case MetroBoss.liftTitan:
        weakX = standX - 62;
        weakY = MetroStage.groundY - (phase == 2 ? 150 : 46);
        weakW = 76;
        weakH = 70;
      case MetroBoss.motherDynamo:
        weakX = standX - 76;
        weakY = MetroStage.groundY - 104;
        weakW = 80;
        weakH = 72;
    }
  }

  /// A wrench (or a parried projectile) lands. Returns true when it counted.
  bool damage({int amount = 1, bool force = false}) {
    if (!alive) return false;
    if (!vulnerable && !force) return false;
    hp = math.max(0, hp - amount);
    hurtLeft = 0.32;
    if (hp == 0) {
      _emit(BossEventKind.dead);
      _enter(BossMode.dying, 2.3);
      return true;
    }
    final newPhase = hp <= maxHp / 3 ? 2 : (hp <= maxHp * 2 / 3 ? 1 : 0);
    if (newPhase > phase) {
      phase = newPhase;
      attackNo = 0;
      _emit(BossEventKind.phase, i: phase);
      _emit(BossEventKind.close);
      _enter(BossMode.recover, 1.3);
    } else if (mode == BossMode.open) {
      windowHits++;
      if (windowHits >= hitsPerWindow) {
        _emit(BossEventKind.close);
        _enter(BossMode.recover, 0.7 * MetroTuning.speed(kind, phase, assist));
      }
    }
    return true;
  }

  /// Everything the scene must forget after reading.
  void clearEvents() => events.clear();
}

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

/// Points of the show.
abstract final class MetroScore {
  static const int strike = 5;
  static const int parry = 8;
  static const int phaseBonus = 20;
  static int bossBonus(int index) => 60 + 30 * index;
  static const int flawlessBonus = 40;
  static int timeBonus(double fightSeconds) => math.max(0, (50 - fightSeconds).round());
}

// ---------------------------------------------------------------------------
// The attract-mode bot
// ---------------------------------------------------------------------------

/// A simple stand-in player: dodges what is telegraphed, jumps what rolls
/// in, strikes what is open. Good enough to carry a fight by itself (it
/// still gets hit now and then, which is what an attract loop should show).
class HeroBot {
  HeroBot({int seed = 3}) : _rng = math.Random(seed);

  final math.Random _rng;
  double _wander = 130;
  double _wanderIn = 0;
  double _jumpHold = 0;
  double _dashCool = 0;

  void decide(double dt, HeroBody hero, HeroInput input, HazardPool hazards, BossBrain? brain, List<MovingPlatform> platforms) {
    input.clearEdges();
    input.move = 0;
    _jumpHold = math.max(0, _jumpHold - dt);
    _dashCool = math.max(0, _dashCool - dt);
    input.jumpHeld = _jumpHold > 0;
    var dangerDir = 0.0;
    var mustJump = false;
    var mustDrop = false;
    var danger = 0.0;
    var lowThreat = false;
    final left = hero.x - MetroStage.heroMinX, right = hero.maxX - hero.x;
    for (final h in hazards.items) {
      if (!h.active) continue;
      final box = h.box;
      final dx = h.x - hero.x;
      switch (h.kind) {
        case HazardKind.stamp || HazardKind.piston || HazardKind.cableStab || HazardKind.steamJet:
          // Standing under a tell: step out of it – or hop it at the last
          // moment when cornered against a wall.
          final reach = h.w / 2 + HeroTuning.halfWidth + 24;
          if (dx.abs() < reach) {
            var dir = dx > 0 ? -1.0 : 1.0;
            if (dx.abs() < 6) dir = left > right ? -1 : 1;
            final room = dir < 0 ? left : right;
            if (room < reach - dx.abs() + 10 && h.kind != HazardKind.steamJet) {
              if (h.telegraph < 0.22) mustJump = true;
              dir = -dir;
            }
            dangerDir += dir;
            danger = math.max(danger, 1);
          }
        case HazardKind.shockwave || HazardKind.steamBlast || HazardKind.cableSweep || HazardKind.spark || HazardKind.rivet || HazardKind.cog:
          if (!h.armed || h.parried) continue;
          final towards = (h.vx > 0 && dx < 0) || (h.vx < 0 && dx > 0) || h.vx == 0;
          final falling = h.kind.projectile && h.vy > 0 && box.bottom < hero.y - 60;
          if (falling && dx.abs() < 70) {
            // Something coming down on him: sidestep, never jump into it.
            dangerDir += dx >= 0 ? -1 : 1;
            danger = math.max(danger, 0.6);
          } else if (towards && dx.abs() < 100 && box.top > hero.y - 150) {
            if (h.kind.parryable && dx.abs() < 60 && dx.abs() > 18 && hero.onGround && !hero.swinging) {
              input.strike = true;
              hero.facing = dx > 0 ? 1 : -1;
            } else if (dx.abs() < 95) {
              mustJump = true;
              if (dx.abs() < 45) lowThreat = true;
            }
          }
        case HazardKind.bolt:
          if (dx.abs() < 40 && h.y < hero.y) {
            dangerDir += dx >= 0 ? -1 : 1;
            danger = math.max(danger, 0.8);
          }
        case HazardKind.grab:
          if (!h.armed) continue;
          final sameLevel = (box.bottom - hero.y).abs() < 70;
          if (sameLevel && dx.abs() < 120) {
            if (hero.platform >= 0) {
              mustDrop = true;
            } else {
              mustJump = true;
            }
          }
      }
    }
    if (dangerDir != 0) {
      input.move = dangerDir.sign;
      if (danger >= 1 && _dashCool <= 0 && hero.onGround) {
        input.dash = dangerDir.sign.toInt();
        _dashCool = 1.4;
      }
    } else if (lowThreat && !hero.onGround && _dashCool <= 0) {
      // Caught in the air over a wave: dash through it on i-frames.
      input.dash = hero.facing >= 0 ? 1 : -1;
      _dashCool = 1.4;
    } else if (brain != null && brain.vulnerable) {
      final wb = brain.weakBox;
      final tx = wb.center.dx;
      final dx = tx - hero.x;
      final reach = wb.width / 2 + HeroTuning.strikeReach * 0.6;
      if (dx.abs() > reach) {
        input.move = dx.sign;
      } else {
        hero.facing = dx >= 0 ? 1 : -1;
        final high = wb.bottom < hero.y - HeroTuning.height * 0.75;
        if (high && hero.onGround) {
          input.jump = true;
          _jumpHold = 0.3;
        }
        if (!high || hero.y < wb.bottom + 40) input.strike = true;
      }
    } else {
      // Keep a working distance from the machine, drifting a little.
      _wanderIn -= dt;
      if (_wanderIn <= 0) {
        _wanderIn = 1.2 + _rng.nextDouble() * 1.6;
        _wander = 70 + _rng.nextDouble() * 110;
      }
      final dx = _wander - hero.x;
      if (dx.abs() > 14) input.move = dx.sign * 0.8;
    }
    if (mustJump && hero.onGround) {
      input.jump = true;
      _jumpHold = 0.28;
    }
    if (mustDrop) input.drop = true;
  }
}

/// Lives as film reels.
abstract final class MetroLives {
  static const int max = 3;
  static const int start = 3;
}
