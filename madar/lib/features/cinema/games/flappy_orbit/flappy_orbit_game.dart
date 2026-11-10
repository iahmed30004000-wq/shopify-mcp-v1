import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'flappy_orbit_conductor.dart';
import 'flappy_orbit_gates.dart';
import 'flappy_orbit_logic.dart';
import 'flappy_orbit_pilot.dart';
import 'flappy_orbit_sets.dart';

/// Where the show is.
enum FlappyAct {
  /// On the rooftop launch pad, winding the key: tap to launch.
  launch,

  /// The rocket sputters off the pad up to cruising height.
  liftoff,

  /// Flying the gates: tap to boost, gravity pulls.
  flight,

  /// The chapter card: the Maestro floats in.
  bossIntro,

  /// The fight: gusts, thunder-notes, then the whole stage spins.
  boss,

  /// The Maestro deflates and blows away.
  bossOutro,

  /// The loop-the-loop landing (all bosses beaten).
  finale,

  /// Out of lives: the tumble into the pie.
  crash,
}

/// "Flappy Orbit" (رفرفة المدار) – a 1930s rubber-hose flyer. Falak, a
/// little astrolabe-headed pilot, rides a rickety wind-up rocket-kite over a
/// cartoon skyline that bounces to a hot swing score. Tap to boost; gravity
/// pulls. The gates are swinging brass horns, chimney smoke, bunting and
/// balloons that sway and pulse on the beat. Every [gatesPerBoss] gates
/// Maestro Ghaym, a grumpy conductor-cloud, takes the stage for three
/// phases (gusts, thunder-notes, and finally spinning the whole stage);
/// every attack dodged knocks a notch off his burning film-strip health
/// bar. Score = gates + style (near misses, boosts on the beat). Three
/// Maestros beaten end the show with a loop-the-loop; three lives lost end
/// it in a pie.
class FlappyOrbitGame extends CinemaGame {
  FlappyOrbitGame({required super.context, this.autoplay = false, this.gatesPerBoss = 8, this.bossCount = 3})
    : super(skin: EraSkins.of(Era.rubberHose));

  /// Attract mode: the autopilot flies (screenshots, tests).
  bool autoplay;

  /// Gates between Maestro visits.
  final int gatesPerBoss;

  /// Maestros to beat for the loop-the-loop ending.
  final int bossCount;

  static const double heroX = OrbitStage.heroX;
  static const double heroRadius = 21;
  static const double bossX = 268;
  static const double bossRestY = 400;
  static const double padHeroY = OrbitStage.groundY - 62;
  static const double cruiseY = 370;

  late final OrbitPilot pilot;
  late final RigComponent hero;
  late final ConductorCloud maestro;
  late final _OffstageRig _maestroC;
  late final StarBird bird;
  late final _OffstageRig _birdC;
  late final GateField gates;
  late final BossAttacks attacks;
  late final PuffPool puffs;
  late final StarBurst stars;
  late final LaunchPad pad;
  late final PropComponent _padC;
  late final PiePlate pie;
  late final PropComponent _pieC;

  final FlightPhysics flight = FlightPhysics(y: padHeroY);
  final Difficulty difficulty = Difficulty();
  late final GateSpawner spawner = GateSpawner(seed: context.seed);
  final StyleScorer style = StyleScorer();
  BossBrain? brain;

  FlappyAct act = FlappyAct.launch;
  int bossesDefeated = 0;
  int gatesSinceBoss = 0;
  int gatesPassed = 0;

  /// World travel in units (the set scrolls by it).
  double scroll = 0;
  double speed = 0;
  double _actTime = 0;
  double _invulnerable = 0;
  double _exhaustIn = 0;
  double _bonkCooldown = 0;
  double _flapCooldown = 0;
  double _spotIn = 0;
  double _stageAngle = 0;
  double _gustDir = -1;
  double _noteLaunchIn = -1;
  double _loopBaseY = cruiseY;
  double _crashT = -1;
  bool _cardDone = false;
  bool _birdLeaving = false;
  bool _birdReturning = false;
  String _callout = '';
  double _calloutTime = 0;

  @override
  String get gameId => 'flappy_orbit';

  @override
  Vector2 get worldSize => Vector2(OrbitStage.width, OrbitStage.height);

  @override
  MusicMood get openingMood => MusicMood.title;

  @override
  IntertitleCard? openingCard() => IntertitleCard(text: l10n.cinemaFlappyOrbitTitle, subtitle: l10n.cinemaFlappyOrbitTapToBoost);

  @override
  IntertitleCard endingCard(GameResult result) => result.won
      ? IntertitleCard(text: l10n.cinemaTheEnd, subtitle: l10n.cinemaFlappyOrbitEndLoop, kind: IntertitleKind.theEnd)
      : IntertitleCard(text: l10n.cinemaGameOver, subtitle: l10n.cinemaFlappyOrbitEndPie, kind: IntertitleKind.gameOver);

  @override
  List<(HudSlot, HudItem)> buildHud() => [
    ...super.buildHud(),
    (HudSlot.bottomCenter, hudKit.progress()),
    (HudSlot.bottomCenter, hudKit.bossBar()),
    // At the end side: the boss bar's name plate sits at the start side.
    (HudSlot.bottomEnd, hudKit.label(() => _calloutTime > 0 ? _callout : '')),
  ];

  /// Beats since the scene started, at the era's tempo (the cast bounces on
  /// the same count).
  double get beat => clock.time * skin.score.tempo / 60;

  /// The rocket's axis in world y.
  double get heroY => flight.y;

  /// Seconds into the current act.
  double get actTime => _actTime;

  /// Whether the chapter card of the boss intro has finished.
  bool get bossCardDone => _cardDone;

  /// The Maestro's centre in world units.
  Vector2 get maestroCentre => _maestroCentre;
  final Vector2 _maestroCentre = Vector2.zero();

  /// Where the follow-spot aims (world units). The stage spot is a floor
  /// light: its bright pool would wash the ink out of a face, so it aims at
  /// the floor of the air just under the star and the beam lights them.
  final Vector2 _spotAt = Vector2.zero();

  bool get _bossOnStage => act == FlappyAct.bossIntro || act == FlappyAct.boss || act == FlappyAct.bossOutro;

  @override
  Future<void> onSceneLoad() async {
    world.addAll(buildOrbitSet(this, () => scroll, () => beat));
    pad = LaunchPad(seed: context.seed);
    _padC = PropComponent(prop: pad, position: Vector2(heroX + 4, OrbitStage.groundY), priority: 3);
    pie = PiePlate(seed: context.seed);
    _pieC = PropComponent(prop: pie, position: Vector2(heroX + 6, OrbitStage.groundY), priority: 4);
    gates = GateField(spawner: spawner, beat: () => beat, priority: 5);
    attacks = BossAttacks(priority: 12)
      ..onNoteHit = _noteHit
      ..onGust = _gusted;
    puffs = PuffPool(priority: 9, count: 10);
    stars = StarBurst(priority: 14);
    pilot = OrbitPilot(height: 84, seed: context.seed);
    hero = RigComponent(rig: pilot, position: Vector2(heroX, padHeroY - pilot.axisY), priority: 10);
    maestro = ConductorCloud(height: 150, seed: context.seed)
      ..facing = -1
      ..expression = RigExpression.angry;
    _maestroC = _OffstageRig(rig: maestro, position: Vector2(OrbitStage.width + 260, bossRestY + 75), priority: 8);
    bird = RigCast.starBird(height: 56, seed: context.seed)
      ..facing = -1
      ..expression = RigExpression.happy
      ..lookAt(const Offset(-1, 0.2));
    _birdC = _OffstageRig(rig: bird, position: Vector2(heroX + 98, OrbitStage.groundY), priority: 9);
    world
      ..add(_padC)
      ..add(gates)
      ..add(_birdC)
      ..add(hero)
      ..add(puffs)
      ..add(_maestroC)
      ..add(attacks)
      ..add(stars);
    hud
      ..lives = 3
      ..maxLives = 3
      ..progress = 0;
    if (autoplay) {
      // Attract mode opens in the air with gates rolling in.
      _startFlightFromAir();
    }
  }

  void _startFlightFromAir() {
    act = FlappyAct.flight;
    flight
      ..y = cruiseY
      ..vy = -100;
    pilot
      ..winding = false
      ..act(RigAction.fall);
    speed = difficulty.speed;
    _padC.position.x = -400;
    _birdC.position.x = OrbitStage.width + 400;
    spawner.deal(OrbitStage.width + 60, difficulty);
  }

  @override
  void onSceneStart() {
    if (act == FlappyAct.launch) {
      pilot
        ..winding = true
        ..act(RigAction.idle)
        ..expression = RigExpression.happy
        ..lookAt(const Offset(1, -0.4));
      bird.act(RigAction.idle);
      _say(l10n.cinemaFlappyOrbitLaunchHint, 3.5);
    }
    music.cue(MusicMood.adventure, intensity: 0.35);
  }

  // ------------------------------------------------------------------ input

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) {
    if (!isPlaying) return;
    switch (act) {
      case FlappyAct.launch:
        _liftoff();
      case FlappyAct.bossIntro when transitions.isActive:
        break; // The chapter card hides the rocket (it hovers, see _hover).
      case FlappyAct.flight || FlappyAct.bossIntro || FlappyAct.boss || FlappyAct.bossOutro:
        _flap();
      case FlappyAct.liftoff || FlappyAct.finale || FlappyAct.crash:
        break;
    }
  }

  void _liftoff() {
    if (act != FlappyAct.launch) return;
    act = FlappyAct.liftoff;
    _actTime = 0;
    pilot
      ..winding = false
      ..act(RigAction.run, restart: true)
      ..expression = RigExpression.determined
      ..lookAt(const Offset(1, -0.3));
    feedback(CinemaSound.slideUp);
    feedback(CinemaSound.pop, volume: 0.6);
    kick(shake: 0.25);
    stage.pulse(0.4);
    for (var i = 0; i < 3; i++) {
      puffs.spawn(heroX - 40 - i * 14.0, padHeroY + 10 + i * 6.0, size: 30 + i * 6.0, life: 0.8, driftY: -20, vx: -40);
    }
    bird
      ..facing = 1
      ..act(RigAction.jump, restart: true)
      ..expression = RigExpression.happy
      ..lookAt(null);
    _birdLeaving = true;
    music.setIntensity(0.5);
    _calloutTime = 0;
  }

  void _flap() {
    if (_flapCooldown > 0) return;
    _flapCooldown = 0.08;
    flight.flap();
    pilot.act(RigAction.jump, restart: true);
    feedback(CinemaSound.whoosh, volume: 0.75);
    puffs.spawn(heroX - 56, flight.y + 4, size: 22, life: 0.45, driftY: 6, vx: -90);
    final bonus = style.flap(beat);
    hud.combo = style.rhythmStreak;
    if (bonus > 0) {
      addScore(bonus);
      feedback(CinemaSound.bell, volume: 0.7);
      stage.pulse(0.35);
      _say(l10n.cinemaFlappyOrbitOnBeat, 1.1);
    }
  }

  void _say(String text, double seconds) {
    _callout = text;
    _calloutTime = seconds;
  }

  // ----------------------------------------------------------------- update

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _spotIn = 0;
  }

  @override
  void onGameplayUpdate(double dt) {
    _actTime += dt;
    if (_calloutTime > 0) _calloutTime -= dt;
    if (_invulnerable > 0) _invulnerable -= dt;
    if (_bonkCooldown > 0) _bonkCooldown -= dt;
    if (_flapCooldown > 0) _flapCooldown -= dt;
    if (autoplay) _autopilot(dt);
    switch (act) {
      case FlappyAct.launch:
        speed = 0;
        _idleOnPad();
      case FlappyAct.liftoff:
        _liftoffUpdate(dt);
      case FlappyAct.flight:
        speed = difficulty.speed;
        _fly(dt);
        _spawnGates();
        _moveGates(dt);
        music.setIntensity((0.4 + difficulty.ramp * 0.4 + difficulty.tier * 0.08).clamp(0.0, 1.0));
      case FlappyAct.bossIntro:
        speed = difficulty.speed;
        if (transitions.isActive) {
          _hover(dt);
        } else {
          _fly(dt);
        }
        _moveGates(dt);
        _bossEntrance(dt);
      case FlappyAct.boss:
        speed = difficulty.speed;
        _fly(dt);
        _bossFight(dt);
      case FlappyAct.bossOutro:
        speed = difficulty.speed;
        _fly(dt);
        _bossExit(dt);
      case FlappyAct.finale:
        _finaleUpdate(dt);
      case FlappyAct.crash:
        _crashUpdate(dt);
    }
    scroll += speed * dt;
    _padC.position.x -= speed * dt;
    _birdUpdate(dt);
    _exhaust(dt);
    _stageSpin(dt);
    hero.position.y = flight.y - pilot.axisY;
    attacks
      ..heroX = hero.position.x
      ..heroY = flight.y
      ..heroRadius = heroRadius * 0.9;
  }

  void _idleOnPad() {
    flight
      ..y = padHeroY
      ..vy = 0;
    pilot.velocity = Offset.zero;
  }

  void _liftoffUpdate(double dt) {
    const rise = 1.0;
    final k = Bounce.inn(math.min(1, _actTime / rise));
    speed = difficulty.speed * Bounce.smooth(_actTime / 1.2);
    flight
      ..y = Bounce.lerp(padHeroY, cruiseY, Bounce.smooth(k))
      ..vy = -220 * k;
    pilot.velocity = Offset(speed * 0.4, -200 * k);
    if (_actTime >= rise) {
      act = FlappyAct.flight;
      _actTime = 0;
      flight.vy = -160;
      pilot.act(RigAction.jump, restart: true);
      spawner.deal(OrbitStage.width + 100, difficulty);
      music.stinger(Stinger.pickup);
    }
  }

  /// While the chapter card hides the sky the rocket hovers back to cruise
  /// height: no gravity, no rooftop, no taps. A player who stops to read the
  /// card loses nothing, and the fight starts from a fair height.
  void _hover(double dt) {
    flight
      ..y += (cruiseY - flight.y) * (1 - math.exp(-dt * 3))
      ..vy = 0;
    pilot.velocity = Offset(speed * 0.3, 0);
  }

  /// Gravity, boosts, the ceiling bonk and the rooftop crash.
  void _fly(double dt) {
    final contact = flight.step(dt);
    pilot.velocity = Offset(speed * 0.3, flight.vy);
    final a = pilot.action;
    if (flight.vy > 140 && a != RigAction.fall && a != RigAction.hurt && a != RigAction.defeated && a != RigAction.cheer) {
      pilot.act(RigAction.fall);
    } else if (a == RigAction.idle) {
      pilot.act(flight.vy > 0 ? RigAction.fall : RigAction.jump);
    }
    if (_invulnerable <= 0 && pilot.expression == RigExpression.scared) pilot.expression = RigExpression.determined;
    switch (contact) {
      case FlightContact.ceiling:
        if (_bonkCooldown <= 0) {
          _bonkCooldown = 0.5;
          pilot.squash(0.25);
          feedback(CinemaSound.boing, volume: 0.5);
          flight.vy = 60;
        }
      case FlightContact.floor:
        _rooftopHit();
      case FlightContact.none:
        break;
    }
  }

  void _rooftopHit() {
    puffs.spawn(heroX - 20, OrbitStage.groundY - 4, size: 34, life: 0.6, driftY: -24);
    puffs.spawn(heroX + 24, OrbitStage.groundY - 4, size: 28, life: 0.5, driftY: -20);
    _hit();
    flight.vy = -430;
  }

  void _spawnGates() {
    final last = spawner.lastX;
    if (last == null) {
      if (_actTime > 0.3) spawner.deal(OrbitStage.width + 100, difficulty);
      return;
    }
    if (last < OrbitStage.width + 110 - difficulty.spacing) spawner.deal(last + difficulty.spacing, difficulty);
  }

  void _moveGates(double dt) {
    final bt = beat;
    final cardUp = transitions.isActive;
    for (final g in spawner.pool) {
      if (!g.active) continue;
      g.x -= speed * dt;
      if (g.x < -140) {
        g.active = false;
        continue;
      }
      if (!g.passed && g.x + GateSlot.halfWidth < heroX - heroRadius) {
        g.passed = true;
        _passGate(g, bt);
      } else if (!g.passed && !cardUp && _invulnerable <= 0 && g.hits(heroX, flight.y, heroRadius, bt)) {
        _hit();
        flight.vy = math.min(flight.vy, -260);
      }
    }
  }

  void _passGate(GateSlot g, double bt) {
    gatesPassed++;
    difficulty.gates++;
    gatesSinceBoss++;
    addScore(1);
    feedback(CinemaSound.coin, volume: 0.7);
    final bonus = style.pass(flight.y, g.topEdgeAt(bt), g.bottomEdgeAt(bt));
    if (bonus > 0) {
      addScore(bonus);
      feedback(CinemaSound.whoosh, volume: 0.5, pitch: 1.3);
      stage.pulse(0.3);
      _say(l10n.cinemaFlappyOrbitNearMiss, 1.1);
    }
    if (act == FlappyAct.flight) {
      hud.progress = (gatesSinceBoss / gatesPerBoss).clamp(0.0, 1.0);
      if (gatesSinceBoss >= gatesPerBoss) _startBossIntro();
    }
  }

  void _hit() {
    if (_invulnerable > 0 || act == FlappyAct.crash || act == FlappyAct.finale) return;
    _invulnerable = 1.6;
    hud.lives = math.max(0, hud.lives - 1);
    pilot
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.scared
      ..flash(0.1);
    kick(flash: 0.4, shake: 0.65, damage: 0.5);
    feedback(CinemaSound.hurt);
    music.stinger(Stinger.hit);
    stars.burst(heroX, flight.y, count: 5, speed: 160, size: 6);
    brain?.heroHit();
    style.rhythmStreak = 0;
    hud.combo = 0;
    if (hud.lives == 0) _crash();
  }

  void _noteHit() {
    _hit();
    flight.shove(140);
  }

  void _gusted(double dir) {
    if (act != FlappyAct.boss) return;
    brain?.heroHit();
    flight.shove(dir * 520);
    pilot
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.surprised;
    kick(shake: 0.3);
    feedback(CinemaSound.whoosh, volume: 1, pitch: 0.8);
    _say(l10n.cinemaFlappyOrbitGusted, 1);
  }

  // ------------------------------------------------------------------- boss

  String _chapterTitle(int n) => switch (n) {
    0 => l10n.cinemaFlappyOrbitActTwo,
    1 => l10n.cinemaFlappyOrbitActThree,
    _ => l10n.cinemaFlappyOrbitActFinal,
  };

  void _startBossIntro() {
    act = FlappyAct.bossIntro;
    _actTime = 0;
    _cardDone = false;
    brain = BossBrain(level: bossesDefeated);
    hud
      ..progress = null
      ..bossName = l10n.cinemaFlappyOrbitBossName;
    // Gates still ahead vanish behind the chapter card.
    for (final g in spawner.pool) {
      if (g.active && !g.passed) g.active = false;
    }
    maestro
      ..phase = 0
      ..deflate = 0
      ..whirl = 0
      ..whirlSpeed = 0
      ..windUp = 0
      ..expression = RigExpression.angry
      ..act(RigAction.taunt, restart: true)
      ..lookAt(const Offset(-1, 0.2));
    _maestroC.position.setValues(OrbitStage.width + 260, bossRestY + 75);
    music
      ..cue(MusicMood.boss, intensity: 0.65)
      ..stinger(Stinger.bossIntro);
    final card = IntertitleCard(text: _chapterTitle(bossesDefeated), subtitle: l10n.cinemaFlappyOrbitBossEnters, kind: IntertitleKind.chapter);
    unawaited(
      transitions.intertitle(card, hold: const Duration(milliseconds: 1500)).then((_) {
        _cardDone = true;
      }),
    );
  }

  void _bossEntrance(double dt) {
    final p = _maestroC.position;
    p.x = math.max(bossX, p.x - 230 * dt);
    p.y = bossRestY + 75 + math.sin(clock.time * 1.3) * 12;
    if (p.x <= bossX && _cardDone && state == SceneState.playing) {
      act = FlappyAct.boss;
      _actTime = 0;
      brain!.arrive();
      hud.bossHealth = 1;
      maestro.act(RigAction.idle);
      kick(shake: 0.3);
      feedback(CinemaSound.honk, volume: 0.8, pitch: 0.7);
      music.setIntensity(0.7);
    }
  }

  void _bossFight(double dt) {
    final b = brain!;
    final p = _maestroC.position;
    final spin = b.phase == BossPhase.spin;
    final bobAmp = spin ? 80.0 : 36.0;
    p.x = bossX + math.sin(clock.time * 0.7) * 14;
    p.y = bossRestY + 75 + math.sin(clock.time * (spin ? 2.2 : 1.1)) * bobAmp;
    _maestroCentre.setValues(p.x, p.y - 75);
    _spotIn -= dt;
    if (_spotIn <= 0) {
      _spotIn = 0.4;
      _spotAt.setValues(p.x, p.y + 14);
      stage.spotlight(worldToScreen(_spotAt));
    }
    // A thunder-note leaves the baton a beat into the slash, when it points
    // at the hero.
    if (_noteLaunchIn > 0) {
      _noteLaunchIn -= dt;
      if (_noteLaunchIn <= 0) _fireNote(p, flight.y);
    }
    if (b.step == BossStep.windUp) {
      final k = (b.timer / b.windUpTime).clamp(0.0, 1.0);
      maestro
        ..windUp = k
        ..attack = b.attack == BossAttackKind.gust ? CloudAttack.gust : CloudAttack.thunder;
      attacks.lanePreview = b.attack == BossAttackKind.gust ? k : 0;
    } else if (attacks.activeGusts > 0) {
      attacks.lanePreview = 1;
    } else {
      attacks.lanePreview = math.max(0, attacks.lanePreview - dt * 4);
      if (attacks.lanePreview <= 0) attacks.laneY = null;
    }
    switch (b.update(dt)) {
      case BossSignal.none:
        break;
      case BossSignal.windUp:
        maestro.attack = b.attack == BossAttackKind.gust ? CloudAttack.gust : CloudAttack.thunder;
        maestro.lookAt(const Offset(-1, 0));
        // He inhales looking at where you are: the gust's lane is fixed now.
        if (b.attack == BossAttackKind.gust) attacks.laneY = flight.y;
        feedback(b.attack == BossAttackKind.gust ? CinemaSound.slideUp : CinemaSound.tick, volume: 0.6);
      case BossSignal.fire:
        maestro
          ..windUp = 0
          ..act(RigAction.attack, restart: true);
        if (b.attack == BossAttackKind.gust) {
          _gustDir = -_gustDir;
          attacks.blowGust(p.x + maestro.mouthX - 20, attacks.laneY ?? flight.y, _gustDir);
          feedback(CinemaSound.whoosh, volume: 1, pitch: 0.7);
          kick(shake: 0.2);
          puffs.spawn(p.x + maestro.mouthX - 50, p.y + maestro.mouthY, size: 34, life: 0.6, driftY: 0, vx: -200);
        } else {
          _noteLaunchIn = 0.16;
        }
      case BossSignal.fireSecond:
        _noteLaunchIn = 0.16;
      case BossSignal.dodged:
        _maestroHurt(b);
      case BossSignal.shrugged:
        maestro.expression = RigExpression.sly;
        feedback(CinemaSound.honk, volume: 0.6);
      case BossSignal.phaseUp:
        _maestroHurt(b);
        _phaseUp(b);
      case BossSignal.defeated:
        _maestroHurt(b);
        _bossDefeated();
    }
    if (b.step == BossStep.recover && b.timer > 0.3 && maestro.expression == RigExpression.sly) {
      maestro.expression = RigExpression.angry;
    }
  }

  void _fireNote(Vector2 p, double targetY) {
    // From the baton tip, but never closer than a readable flight away (his
    // reach is long enough to tap the rocket).
    final x = math.max(p.x + maestro.batonX, heroX + 120), y = p.y + maestro.batonY;
    attacks.fireNote(x, y, heroX, targetY, flightTime: 0.62 * brain!.pace);
    feedback(CinemaSound.zap, volume: 0.8);
    kick(flash: 0.12);
    stars.burst(x, y, count: 4, speed: 120, size: 5);
  }

  void _maestroHurt(BossBrain b) {
    hud.bossHealth = b.health;
    addScore(2);
    maestro
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.surprised;
    feedback(CinemaSound.hit, volume: 0.8);
    kick(flash: 0.2, shake: 0.3);
    final p = _maestroC.position;
    puffs.spawn(p.x - 40, p.y - 110, size: 30, life: 0.6, driftY: -40);
    puffs.spawn(p.x + 50, p.y - 70, size: 26, life: 0.6, driftY: -30);
    pilot.expression = RigExpression.happy;
  }

  void _phaseUp(BossBrain b) {
    maestro.phase = b.phase.index;
    // A clean breather: whatever is still in the air is gone.
    attacks
      ..clear()
      ..laneY = null;
    _noteLaunchIn = -1;
    addScore(5);
    kick(flash: 0.3, shake: 0.5, damage: 0.2);
    switch (b.phase) {
      case BossPhase.thunder:
        music.stinger(Stinger.drumroll);
        _say(l10n.cinemaFlappyOrbitPhaseThunder, 1.6);
        feedback(CinemaSound.zap, volume: 0.9, pitch: 0.7);
      case BossPhase.spin:
        music.stinger(Stinger.rimshot);
        _say(l10n.cinemaFlappyOrbitPhaseSpin, 1.8);
        feedback(CinemaSound.slideDown, volume: 0.9);
        maestro.whirlSpeed = env.reducedMotion ? 0.9 : 2.6;
      case BossPhase.gusts:
        break;
    }
    music.setIntensity((0.7 + b.phase.index * 0.14).clamp(0.0, 1.0));
    stars.burst(_maestroC.position.x, _maestroC.position.y - 80, count: 10, speed: 220, size: 7);
  }

  void _bossDefeated() {
    act = FlappyAct.bossOutro;
    _actTime = 0;
    bossesDefeated++;
    maestro
      ..whirlSpeed = 0
      ..windUp = 0
      ..act(RigAction.defeated)
      ..expression = RigExpression.dizzy;
    attacks
      ..clear()
      ..laneY = null;
    _noteLaunchIn = -1;
    music.stinger(Stinger.bossDefeat);
    addScore(10);
    hud.bossHealth = 0;
    kick(flash: 0.5, shake: 0.8, damage: 0.3);
    feedback(CinemaSound.pop);
    feedback(CinemaSound.slideDown, volume: 0.8);
    stars.burst(_maestroC.position.x, _maestroC.position.y - 80, count: 22, speed: 300, size: 9);
    pilot
      ..expression = RigExpression.happy
      ..squash(-0.2);
    _say(l10n.cinemaFlappyOrbitBossDown, 2);
    stage.spotlight(null);
  }

  void _bossExit(double dt) {
    final p = _maestroC.position;
    final k = (_actTime / 1.6).clamp(0.0, 1.0);
    maestro.deflate = k;
    p.x += 170 * dt;
    p.y -= 140 * dt;
    if (((_actTime * 10).floor() % 3) == 0 && _actTime < 1.2) {
      puffs.spawn(p.x - 60 - k * 30, p.y - 60, size: 24, life: 0.5, driftY: 10, vx: -120);
    }
    if (_actTime >= 1.7) {
      _maestroC.position.setValues(OrbitStage.width + 600, bossRestY);
      hud.bossHealth = null;
      if (bossesDefeated >= bossCount) {
        _finale();
      } else {
        act = FlappyAct.flight;
        _actTime = 0;
        difficulty.tier = bossesDefeated;
        gatesSinceBoss = 0;
        hud.progress = 0;
        music.cue(MusicMood.adventure, intensity: (0.5 + difficulty.tier * 0.15).clamp(0.0, 1.0));
      }
    }
  }

  // -------------------------------------------------------------- endings

  void _finale() {
    act = FlappyAct.finale;
    _actTime = 0;
    _loopBaseY = flight.y.clamp(260.0, 480.0);
    pilot
      ..act(RigAction.cheer, restart: true)
      ..expression = RigExpression.happy
      ..lookAt(null);
    music.cue(MusicMood.action, intensity: 1);
    stars.burst(heroX, flight.y, count: 16, speed: 240, size: 8);
    bird
      ..facing = 1
      ..act(RigAction.run)
      ..expression = RigExpression.happy;
    _birdC.position.setValues(-90, flight.y + 40);
    _birdReturning = true;
    _spotIn = 0;
    feedback(CinemaSound.powerUp);
  }

  void _finaleUpdate(double dt) {
    speed = math.max(60, speed - 90 * dt);
    const loop = 1.9;
    final t = _actTime;
    const r = 78.0;
    if (t < loop) {
      final a = Bounce.smooth(t / loop) * math.pi * 2;
      flight.y = _loopBaseY - (1 - math.cos(a)) * r;
      hero.position.x = heroX + math.sin(a) * r * 1.15;
      pilot
        ..pitch = -a
        ..velocity = Offset.zero;
      if (((t * 12).floor() % 2) == 0) {
        puffs.spawn(hero.position.x - math.cos(a) * 40, flight.y + math.sin(a) * 40, size: 18, life: 0.5, driftY: 0);
      }
    } else {
      final k = Bounce.smooth((t - loop) / 0.6);
      flight.y = Bounce.lerp(flight.y, _loopBaseY, k * 0.2);
      hero.position.x = Bounce.lerp(hero.position.x, heroX, k * 0.2);
      pilot.pitch = Bounce.lerp(pilot.pitch ?? 0, 0, k);
    }
    _spotIn -= dt;
    if (_spotIn <= 0) {
      _spotIn = 0.3;
      _spotAt.setValues(hero.position.x, flight.y + 46);
      stage.spotlight(worldToScreen(_spotAt));
    }
    if (t > 3.1) {
      stage.spotlight(null);
      pilot.pitch = null;
      unawaited(endScene(won: true, stats: _stats()));
    }
  }

  void _crash() {
    act = FlappyAct.crash;
    _actTime = 0;
    _crashT = -1;
    pilot
      ..act(RigAction.defeated)
      ..expression = RigExpression.dizzy
      ..lookAt(null);
    attacks
      ..clear()
      ..laneY = null;
    for (final g in spawner.pool) {
      if (g.active && !g.passed && g.x < heroX + 160) g.active = false;
    }
    pie.splat = 0;
    _pieC.position.setValues(heroX + 6, OrbitStage.groundY);
    world.add(_pieC);
    music.cue(MusicMood.tension, intensity: 0.6);
    if (_bossOnStage) {
      maestro
        ..windUp = 0
        ..whirlSpeed = 0
        ..act(RigAction.taunt, restart: true)
        ..expression = RigExpression.sly;
      stage.spotlight(null);
    }
  }

  void _crashUpdate(double dt) {
    speed = math.max(0, speed - 320 * dt);
    if (_bossOnStage) _maestroC.position.x += 60 * dt;
    if (_crashT < 0) {
      flight.vy = math.min(FlightTuning.maxFall, flight.vy + FlightTuning.gravity * dt);
      flight.y += flight.vy * dt;
      pilot.velocity = Offset(0, flight.vy);
      const pieTop = OrbitStage.groundY - 44;
      if (flight.y >= pieTop) {
        flight
          ..y = pieTop
          ..vy = 0;
        _crashT = 0;
        pie.splat = 1;
        pilot
          ..velocity = Offset.zero
          ..squash(0.4);
        feedback(CinemaSound.splat);
        kick(flash: 0.3, shake: 0.7, damage: 0.4);
        for (var i = 0; i < 5; i++) {
          puffs.spawn(heroX - 50 + i * 26.0, OrbitStage.groundY - 36, size: 26 + (i % 2) * 8, life: 0.9, driftY: -50 - i * 8.0, vx: (i - 2) * 40.0);
        }
        stars.burst(heroX, OrbitStage.groundY - 50, count: 8, speed: 180, size: 6);
      }
    } else {
      _crashT += dt;
      if (_crashT > 1.7) unawaited(endScene(won: false, stats: _stats()));
    }
  }

  Map<String, num> _stats() => {
    'gates': gatesPassed,
    'bosses': bossesDefeated,
    'nearMisses': style.nearMisses,
    'rhythm': style.rhythmBonuses,
    'bestStreak': style.bestStreak,
  };

  // ----------------------------------------------------------- side shows

  void _birdUpdate(double dt) {
    final p = _birdC.position;
    if (_birdLeaving) {
      p.x += 170 * dt;
      p.y -= 290 * dt;
      bird
        ..speed = 300
        ..velocity = const Offset(170, -290);
      if (bird.action != RigAction.run && bird.actionTime > 0.3) bird.act(RigAction.run);
      if (p.y < -160) {
        _birdLeaving = false;
        p.setValues(OrbitStage.width + 400, 0);
        bird.velocity = Offset.zero;
      }
    } else if (_birdReturning) {
      final tx = hero.position.x - 112, ty = flight.y + 92;
      p.x += (tx - p.x) * math.min(1, dt * 2.5);
      p.y += (ty - p.y) * math.min(1, dt * 2.5);
      bird.velocity = Offset((tx - p.x) * 2, (ty - p.y) * 2);
      if ((tx - p.x).abs() < 12 && bird.action != RigAction.cheer) bird.act(RigAction.cheer);
    } else if (act == FlappyAct.launch) {
      p.x = _padC.position.x + 94;
    }
  }

  void _exhaust(double dt) {
    if (pilot.thrust < 0.3 || act == FlappyAct.launch) return;
    _exhaustIn -= dt;
    if (_exhaustIn > 0) return;
    _exhaustIn = 0.16 / math.max(0.3, pilot.thrust);
    puffs.spawn(hero.position.x - 62, flight.y + 2, size: 14 + pilot.thrust * 10, life: 0.5, driftY: 4, vx: -60 - speed * 0.3);
  }

  void _stageSpin(double dt) {
    final b = brain;
    final spinning = act == FlappyAct.boss && b != null && b.spinning;
    final amp = env.reducedMotion ? 0.05 : 0.2;
    final target = spinning ? math.sin(clock.time * 2.2) * amp : 0.0;
    _stageAngle += (target - _stageAngle) * math.min(1, dt * (spinning ? 6 : 3));
    if (_stageAngle.abs() < 0.0005 && !spinning) _stageAngle = 0;
    camera.viewfinder.angle = _stageAngle;
  }

  /// The world's rotation (radians) while the stage spins.
  double get stageAngle => _stageAngle;

  // -------------------------------------------------------------- autopilot

  void _autopilot(double dt) {
    switch (act) {
      case FlappyAct.launch:
        if (_actTime > 1.6) _liftoff();
        return;
      case FlappyAct.liftoff || FlappyAct.finale || FlappyAct.crash:
        return;
      case FlappyAct.bossIntro when transitions.isActive:
        return; // Hovering behind the chapter card.
      case FlappyAct.flight || FlappyAct.bossIntro || FlappyAct.boss || FlappyAct.bossOutro:
        break;
    }
    var target = act == FlappyAct.boss ? bossRestY - 20 : cruiseY;
    if (act == FlappyAct.flight || act == FlappyAct.bossIntro) {
      GateSlot? next;
      for (final g in spawner.pool) {
        if (!g.active || g.passed || g.x + GateSlot.halfWidth < heroX - 30) continue;
        if (next == null || g.x < next.x) next = g;
      }
      if (next != null) target = next.centreAt(beat + 0.5) - 10;
    } else if (act == FlappyAct.boss) {
      // Keep clear of the lane the Maestro is blowing (or about to), and of
      // the thunder-note whose mark is nearest: stay on the side you are on
      // while there is room, dropping being quicker than climbing.
      var threat = double.nan, nearest = double.infinity;
      for (var i = 0; i < BossAttacks.noteCount; i++) {
        if (!attacks.noteActive(i) || attacks.noteX(i) < heroX - 10) continue;
        final ny = attacks.noteYAt(i, heroX);
        final d = (ny - flight.y).abs();
        if (d < nearest) {
          nearest = d;
          threat = ny;
        }
      }
      final lane = attacks.laneY;
      if (lane != null) threat = lane;
      if (!threat.isNaN) {
        final roomBelow = FlightTuning.floor - 70 - threat, roomAbove = threat - (FlightTuning.ceiling + 50);
        final below = flight.y >= threat;
        target = (below && roomBelow >= 120) || roomAbove < 120 ? threat + 150 : threat - 150;
      }
    }
    target = target.clamp(FlightTuning.ceiling + 50, FlightTuning.floor - 70);
    if (AutoPilot.shouldFlap(y: flight.y, vy: flight.vy, targetY: target)) _flap();
  }
}

/// A rig that is only drawn while it is near the stage (the Maestro and
/// the bird wait far off to the right between appearances).
class _OffstageRig extends RigComponent {
  _OffstageRig({required super.rig, super.position, super.priority});

  @override
  void render(Canvas canvas) {
    if (position.x > OrbitStage.paintRight + 160 || position.x < OrbitStage.paintLeft - 160) return;
    super.render(canvas);
  }
}
