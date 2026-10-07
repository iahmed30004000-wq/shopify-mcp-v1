import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'demo_cast.dart';
import 'demo_sets.dart';

/// Where the show is.
enum DemoAct {
  /// Act one: the hero runs through the set, jumping what rolls in.
  run,

  /// The chapter card: Baron Zunbruk rolls onto the stage.
  bossIntro,

  /// Act two: the Baron slams and hurls; every dodge wears him down.
  boss,

  /// The Baron is down, the hero takes a bow, the iris closes.
  finale,
}

/// "Rehearsal" (بروفة) – the engine's 30-second vignette, one per era: the
/// era's star runs through a painted set (opening card, iris in), jumps the
/// era's rolling hazards, then Baron Zunbruk takes the stage for a mini boss
/// fight (chapter card, boss bar, slams that shake the print, a blast of
/// gears) before the iris closes on a curtain call. Tap to jump.
///
/// It uses only the contracts and the standard kit, so every engine piece
/// (grade, stage, HUD, transitions, rig cast, props, audio cues) shows up in
/// context; the Tier 1 games copy its patterns (pooled hazards, a scripted
/// boss cycle, chapter cards, kicks and stingers).
class DemoGame extends CinemaGame {
  DemoGame({required super.context, Era era = Era.rubberHose, this.autoplay = false}) : super(skin: EraSkins.of(era));

  /// Attract mode: the hero jumps by itself (screenshots, hall preview).
  /// Mutable so a test can hand control back mid-show.
  bool autoplay;

  static const double groundY = DemoStage.groundY;
  static const double heroX = 100;
  static const double bossX = 284;
  static const double bossHeight = 250;

  /// Hazards to clear before the Baron enters.
  static const int runGoal = 6;

  /// Dodges that wear the Baron down.
  static const int bossGoal = 4;

  late final RigComponent hero;
  late final ClockworkBoss boss = RigCast.clockworkBoss(height: bossHeight, seed: context.seed)
    ..facing = -1
    ..expression = RigExpression.sly;
  late final RigComponent _bossComponent = RigComponent(rig: boss, position: Vector2(worldSize.x + 230, groundY), priority: 8);
  late final PuffPool puffs = PuffPool(priority: 12);
  final List<Hazard> _hazards = [];
  final math.Random _rng = math.Random(11);

  DemoAct act = DemoAct.run;

  /// World travel in units (the set scrolls by it).
  double scroll = 0;
  double runSpeed = 0;
  int cleared = 0;
  int bossHits = 0;

  double _vy = 0;
  double _heroY = groundY;
  double _spawnIn = 0.9;
  double _invulnerable = 0;
  double _heroDust = 0;
  late final double _gravity = DemoHero.gravity(era);
  late final double _jumpSpeed = DemoHero.jumpSpeed(era);
  late final double _heroHalf = DemoHero.halfWidth(era);

  // Boss cycle.
  int _bossStep = 0; // 0 wind-up, 1 attack, 2 recover
  double _bossTimer = 0;
  int _attackNo = 0;
  bool _launched = false;
  bool _bossEntering = false;
  double _finaleTimer = 0;
  Offset? _bossSpot;
  Offset? _heroSpot;

  @override
  String get gameId => 'demo';

  @override
  Vector2 get worldSize => Vector2(DemoStage.width, DemoStage.height);

  @override
  IntertitleCard? openingCard() => IntertitleCard(text: l10n.cinemaDemoOpening, subtitle: l10n.cinemaDemoTapToJump);

  @override
  List<(HudSlot, HudItem)> buildHud() => [
    ...super.buildHud(),
    (HudSlot.bottomCenter, hudKit.progress()),
    (HudSlot.bottomCenter, hudKit.bossBar()),
  ];

  bool get _onGround => _heroY >= groundY - 0.01;

  /// The hero's feet in world units (tests, overlays).
  double get heroY => _heroY;

  /// Number of pooled hazards (constant after load).
  int get hazardPoolSize => _hazards.length;

  /// Active hazards as text (debugging).
  String get debugHazards => [
    for (final h in _hazards)
      if (h.active) '${h.kind.name}@${h.position.x.toStringAsFixed(0)},${h.position.y.toStringAsFixed(0)} v${h.speed.toStringAsFixed(0)} fly=${h.flying} scored=${h.scored}',
  ].join(' | ');

  @override
  Future<void> onSceneLoad() async {
    world.addAll(buildDemoSet(this, () => scroll));
    hero = RigComponent(rig: DemoHero.build(era), position: Vector2(heroX, groundY), priority: 10);
    world
      ..add(_HeroShadow(this)..priority = 9)
      ..add(hero)
      ..add(puffs);
    for (var i = 0; i < 5; i++) {
      // In front of the Baron (a lobbed gear must not vanish behind him),
      // behind the hero.
      final h = Hazard(era, seed: i)..priority = 9;
      _hazards.add(h);
      world.add(h);
    }
    hud
      ..lives = 3
      ..maxLives = 3
      ..progress = 0;
    if (autoplay) {
      // Attract mode opens mid-show: things already rolling in.
      _hazards[0].launch(300, 210);
      _hazards[1].launch(560, 210);
      _spawnIn = 1.6;
    }
  }

  @override
  void onSceneStart() {
    runSpeed = DemoHero.runSpeed(era);
    hero.rig
      ..act(RigAction.run)
      ..speed = runSpeed
      ..expression = RigExpression.happy
      ..lookAt(const Offset(1, 0.25));
    music.cue(MusicMood.adventure, intensity: 0.45);
  }

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) {
    if (isPlaying) _jump();
  }

  void _jump() {
    if (!_onGround || act == DemoAct.finale) return;
    _vy = -_jumpSpeed;
    hero.rig.act(RigAction.jump, restart: true);
    feedback(CinemaSound.jump);
    puffs.spawn(heroX - 6, groundY - 2, size: 22, life: 0.5);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _bossSpot = null;
    _heroSpot = null;
  }

  @override
  void onGameplayUpdate(double dt) {
    final cardUp = transitions.isActive;
    scroll += runSpeed * dt;
    _heroPhysics(dt);
    switch (act) {
      case DemoAct.run:
        _spawnRollers(dt);
      case DemoAct.bossIntro:
        _bossEntrance(dt);
      case DemoAct.boss:
        _bossCycle(dt);
      case DemoAct.finale:
        _finale(dt);
    }
    if (!cardUp) _collide();
    if (act == DemoAct.run) {
      music.setIntensity((0.35 + cleared / runGoal * 0.5).clamp(0.0, 1.0));
    }
  }

  // ---------------------------------------------------------------- hero

  void _heroPhysics(double dt) {
    final rig = hero.rig;
    if (!_onGround || _vy < 0) {
      _vy += _gravity * dt;
      _heroY = math.min(groundY, _heroY + _vy * dt);
      if (_vy > 0 && rig.action == RigAction.jump) rig.act(RigAction.fall);
      if (_heroY >= groundY) {
        _vy = 0;
        rig.act(RigAction.land);
        feedback(CinemaSound.land, volume: 0.55);
        puffs.spawn(heroX + 8, groundY - 2, size: 26, life: 0.55);
        _heroDust = 0;
      }
    } else if (rig.action == RigAction.idle) {
      rig.act(act == DemoAct.run ? RigAction.run : RigAction.idle);
      if (act == DemoAct.run) rig.act(RigAction.run);
    }
    hero.position.y = _heroY;
    if (rig is HoseRig) {
      rig.velocity = _onGround ? Offset.zero : Offset(0, _vy);
      if (rig is StarBird) rig.pitch = (_vy / 900).clamp(-0.5, 0.8);
    }
    // Running kicks up dust on the boards.
    if (act == DemoAct.run && _onGround) {
      _heroDust += dt;
      if (_heroDust > 0.42) {
        _heroDust = 0;
        puffs.spawn(heroX - 18, groundY - 1, size: 16, life: 0.45, driftY: -14);
      }
    }
    if (_invulnerable > 0) {
      _invulnerable -= dt;
      if (_invulnerable <= 0) rig.expression = act == DemoAct.boss ? RigExpression.determined : RigExpression.happy;
    }
  }

  void _hit(Hazard h) {
    h.scored = true;
    if (h.kind == HazardKind.roller) h.bounceAway();
    _invulnerable = 1.3;
    hud.lives = math.max(0, hud.lives - 1);
    hero.rig
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.scared;
    kick(flash: 0.45, shake: 0.7, damage: 0.6);
    feedback(CinemaSound.hurt);
    music.stinger(Stinger.hit);
    if (hud.lives == 0) {
      hero.rig.act(RigAction.defeated);
      unawaited(endScene(won: false, stats: {'cleared': cleared, 'bossHits': bossHits}));
    }
  }

  // ------------------------------------------------------------- hazards

  Hazard? _free() {
    for (final h in _hazards) {
      if (!h.active) return h;
    }
    return null;
  }

  void _spawnRollers(double dt) {
    _spawnIn -= dt;
    if (_spawnIn > 0) return;
    // Always a jump's worth of road between rollers (a jump lasts ~0.8 s).
    for (final h in _hazards) {
      if (h.active && !h.scored && h.position.x > worldSize.x - 150) return;
    }
    final h = _free();
    if (h == null) return;
    h.launch(worldSize.x + 90, 190 + cleared * 8.0 + _rng.nextDouble() * 30);
    _spawnIn = 1.25 + _rng.nextDouble() * 0.7;
  }

  void _collide() {
    for (final h in _hazards) {
      if (!h.active) continue;
      final dx = h.position.x - heroX;
      if (autoplay && _onGround && !h.flying && !h.scored && dx > 0 && dx < 62 + h.speed * 0.085) _jump();
      if (h.scored) continue;
      if (dx.abs() < h.hitHalf + _heroHalf && _heroY > groundY - h.clearHeight) {
        if (_invulnerable <= 0) _hit(h);
      } else if (dx < -_heroHalf - 26) {
        h.scored = true;
        _cleared(h);
      }
    }
  }

  void _cleared(Hazard h) {
    cleared++;
    addScore(1);
    feedback(CinemaSound.coin);
    switch (act) {
      case DemoAct.run:
        hud.progress = (cleared / runGoal).clamp(0.0, 1.0);
        if (cleared >= runGoal) _startBossIntro();
      case DemoAct.boss:
        _bossHurt();
      default:
    }
  }

  // ---------------------------------------------------------------- boss

  void _startBossIntro() {
    act = DemoAct.bossIntro;
    runSpeed = 0;
    hud.progress = null;
    for (final h in _hazards) {
      if (h.active && h.position.x > heroX) h.active = false;
    }
    hero.rig
      ..act(RigAction.idle)
      ..speed = 0
      ..expression = RigExpression.determined
      ..lookAt(const Offset(1, -0.35));
    music
      ..cue(MusicMood.boss, intensity: 0.7)
      ..stinger(Stinger.bossIntro);
    world.add(_bossComponent);
    boss
      ..act(RigAction.walk)
      ..speed = 170
      ..expression = RigExpression.sly;
    _bossEntering = true;
    final card = IntertitleCard(text: l10n.cinemaDemoActTwo, subtitle: l10n.cinemaDemoBossEnters, kind: IntertitleKind.chapter);
    unawaited(
      transitions.intertitle(card, hold: const Duration(milliseconds: 1500)).then((_) {
        if (state == SceneState.ending || state == SceneState.ended) return;
        act = DemoAct.boss;
        hud
          ..bossHealth = 1
          ..bossName = l10n.cinemaRigZunbruk;
        _bossStep = 2;
        _bossTimer = 0.2;
      }),
    );
  }

  void _bossEntrance(double dt) {
    if (!_bossEntering) return;
    final p = _bossComponent.position;
    p.x = math.max(bossX, p.x - 170 * dt);
    if (p.x <= bossX) {
      _bossEntering = false;
      boss
        ..speed = 0
        ..act(RigAction.taunt);
      kick(shake: 0.5, damage: 0.1);
      feedback(CinemaSound.hit, volume: 0.7, pitch: 0.7);
      puffs.spawn(bossX - 40, groundY - 2, size: 40, life: 0.8);
      puffs.spawn(bossX + 40, groundY - 2, size: 40, life: 0.8);
    }
  }

  void _bossCycle(double dt) {
    _bossSpot ??= worldToScreen(Vector2(bossX, groundY - bossHeight * 0.55));
    stage.spotlight(_bossSpot);
    _bossTimer += dt;
    switch (_bossStep) {
      case 0:
        const windUp = 0.75;
        boss.windUp = (_bossTimer / windUp).clamp(0.0, 1.0);
        if (_bossTimer > 0.25 && _bossTimer < 0.3) {
          puffs.spawn(bossX + 10, groundY - bossHeight * 1.02, size: 34, life: 0.9, driftY: -50);
        }
        if (_bossTimer >= windUp) {
          boss
            ..windUp = 0
            ..attack = _attackNo.isEven ? BossAttack.slam : BossAttack.blast
            ..expression = RigExpression.angry
            ..act(RigAction.attack, restart: true);
          _bossStep = 1;
          _bossTimer = 0;
          _launched = false;
        }
      case 1:
        final slam = boss.attack == BossAttack.slam;
        final hitAt = slam ? 0.44 : 0.26;
        if (!_launched && _bossTimer >= hitAt) {
          _launched = true;
          final h = _free();
          if (slam) {
            kick(shake: 0.9, damage: 0.15);
            feedback(CinemaSound.explosion, volume: 0.8);
            puffs.spawn(bossX - 70, groundY - 2, size: 44, life: 0.8);
            h?.launch(bossX - 80, 330, kind: HazardKind.wave);
          } else {
            feedback(CinemaSound.whoosh);
            // The rig updates its anchors when it draws; headless (tests,
            // first frame) they are still zero – fall back to the design.
            final m = boss.mouthAnchor == Offset.zero ? Offset(-bossHeight * 0.28, -bossHeight * 0.6) : boss.mouthAnchor;
            puffs.spawn(bossX + m.dx - 20, groundY + m.dy, size: 30, life: 0.6, driftY: -20);
            // Lobbed high out of the furnace, drifting back a little; it
            // lands well short of the hero and rolls at him, so the lob
            // itself is the tell and there is time to jump.
            h?.launch(bossX + m.dx - 10, -25, y: groundY + m.dy, vy: -560, landSpeed: 215);
          }
        }
        if (_bossTimer >= boss.oneShotLength(RigAction.attack) + 0.05) {
          _bossStep = 2;
          _bossTimer = 0;
        }
      default:
        if (_bossTimer >= 0.8) {
          _bossStep = 0;
          _bossTimer = 0;
          _attackNo++;
        }
    }
  }

  void _bossHurt() {
    bossHits++;
    addScore(2);
    hud.bossHealth = (1 - bossHits / bossGoal).clamp(0.0, 1.0);
    boss
      ..act(RigAction.hurt, restart: true)
      ..phase = bossHits >= 3 ? 2 : (bossHits >= 1 ? 1 : 0)
      ..expression = RigExpression.dizzy;
    feedback(CinemaSound.hit);
    kick(flash: 0.25, shake: 0.35);
    puffs.spawn(bossX + 30, groundY - bossHeight * 0.5, size: 36, life: 0.7, driftY: -40);
    if (bossHits >= bossGoal) {
      _bossDefeated();
    } else {
      _bossStep = 2;
      _bossTimer = -0.35;
    }
  }

  void _bossDefeated() {
    act = DemoAct.finale;
    _finaleTimer = 0;
    boss
      ..windUp = 0
      ..act(RigAction.defeated)
      ..expression = RigExpression.dizzy;
    music.stinger(Stinger.bossDefeat);
    kick(flash: 0.5, shake: 1, damage: 0.3);
    feedback(CinemaSound.explosion);
    addScore(10);
    hud.bossHealth = 0;
    hero.rig
      ..act(RigAction.cheer)
      ..expression = RigExpression.happy
      ..lookAt(null);
    for (var i = 0; i < 3; i++) {
      puffs.spawn(bossX - 60 + i * 60.0, groundY - 10 - i * 30.0, size: 48, life: 1, driftY: -30);
    }
  }

  void _finale(double dt) {
    _finaleTimer += dt;
    _heroSpot ??= worldToScreen(Vector2(heroX, groundY - 60));
    stage.spotlight(_heroSpot);
    if (_finaleTimer > 2.6) {
      stage.spotlight(null);
      unawaited(endScene(won: true, stats: {'cleared': cleared, 'bossHits': bossHits}));
    }
  }
}

/// The hero's contact shadow: shrinks and fades as the hero rises.
class _HeroShadow extends Component {
  _HeroShadow(this.game);

  final DemoGame game;
  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final lift = (DemoGame.groundY - game.heroY).clamp(0.0, 260.0) / 260;
    final w = game.hero.rig.bounds.width * 0.4 * (1 - lift * 0.45);
    _paint.color = game.skin.palette.ink.withValues(alpha: 0.22 * (1 - lift * 0.6));
    canvas.drawOval(Rect.fromCenter(center: const Offset(DemoGame.heroX, DemoGame.groundY + 2), width: w * 2, height: w * 0.42), _paint);
  }
}
