import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/audio/cinema_audio.dart' show CinemaSfx, CinemaSfxExtras;
import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'metropolis_bosses.dart';
import 'metropolis_fx.dart';
import 'metropolis_hazards.dart';
import 'metropolis_hero.dart';
import 'metropolis_hud.dart';
import 'metropolis_rules.dart';
import 'metropolis_set.dart';

/// Where the show is.
enum MetroAct {
  /// The shift-change: the crowd trudges past, the hero walks in, two
  /// dialogue cards.
  opening,

  /// A machine is on stage (entering, fighting, or beaten and falling).
  fight,

  /// The beaten machine falls apart; a reel comes back.
  bossFall,

  /// The conveyor carries the hero to the next hall.
  transit,

  /// The Mother-Dynamo is down: the Baron flies, the lights come back.
  finale,

  /// Out of reels.
  defeat,
}

/// **Metropolis Machine** (آلة المتروبوليس) – a 1920s silent-sepia boss
/// rush: five machines of a great machine city, back to back, each with a
/// personality and three phases, intertitle dialogue cards between them.
/// Miftah the night engineer runs, jumps, swings his wrench (tap) and
/// dashes (swipe); every attack is telegraphed, projectiles can be parried
/// back, lives are film reels and one comes back after every machine.
class MetropolisGame extends CinemaGame implements MetroSetState, MetroControlState {
  MetropolisGame({required super.context, this.autoplay = false}) : super(skin: EraSkins.of(Era.silent));

  /// Attract mode: the bot plays (screenshots, hall preview, tests).
  bool autoplay;

  // ------------------------------------------------------------ rules
  final HeroBody heroBody = HeroBody();
  final HeroInput input = HeroInput();
  final HazardPool hazards = HazardPool();
  final List<MovingPlatform> platforms = [MovingPlatform(), MovingPlatform()];
  final HeroBot _bot = HeroBot();
  BossBrain? brain;
  MachineRig? bossRig;
  int bossIndex = 0;

  // ------------------------------------------------------- components
  late final WorkerRig heroRig = WorkerRig(seed: context.seed);
  late final RigComponent hero;
  late final MetroPuffs puffs = MetroPuffs(priority: 13);
  late final MetroSparks sparks = MetroSparks(priority: 12);
  late final MetroGearBurst gears = MetroGearBurst(priority: 12);
  late final MetroFlashText flash = MetroFlashText(priority: 14);
  RigComponent? _bossComponent;
  ClockworkBoss? baron;
  RigComponent? _baronComponent;
  final List<bool> _wasArmed = [];

  // ------------------------------------------------------------ state
  MetroAct act = MetroAct.opening;
  double actTime = 0;
  int assist = 0;
  double fightTime = 0;
  bool flawless = true;
  int bossesBeaten = 0;
  int parries = 0;
  int strikesLanded = 0;
  int livesLost = 0;
  bool _entering = false;
  double _enterFrom = 0;
  bool _ended = false;
  /// Bumped whenever the show's flow is cut (dispose, a debug jump): a card
  /// that completes afterwards must not resume a stale continuation
  /// (`transitions.clear()` completes pending cards).
  int _flow = 0;
  Offset? _heroSpot;
  bool _baronFlying = false;
  bool _finaleCardShown = false;
  double _baronVx = 0, _baronVy = 0, _baronSpin = 0;
  double _cityLights = 0;
  double _scroll = 0;
  double _hallSlide = 0;
  double _crowdX = 380;
  bool _crowdVisible = false;
  late final double _shakeScale = env.reducedMotion ? 0.3 : 1;
  late final double _particleScale = env.reducedMotion ? 0.5 : 1;
  final math.Random _rng = math.Random(17);

  // ------------------------------------------------------------ input
  bool _padHeld = false;
  double _padDir = 0;
  Offset _padDownAt = Offset.zero;
  double _padDownTime = 0;
  bool _padSwiped = false;
  bool _actionDown = false;
  Offset _actionDownAt = Offset.zero;
  bool _swipeDone = false;
  bool _jumpHeldButton = false;
  bool _jumpHeldSwipe = false;
  double _dashLit = 0;

  @override
  String get gameId => 'metropolis_machine';

  @override
  Vector2 get worldSize => Vector2(MetroStage.width, MetroStage.height);

  @override
  MusicMood get openingMood => MusicMood.title;

  @override
  IntertitleCard? openingCard() => IntertitleCard(text: l10n.cinemaMetropolisTitle, subtitle: l10n.cinemaMetropolisOpeningSubtitle);

  @override
  IntertitleCard endingCard(GameResult result) => result.won
      ? IntertitleCard(text: l10n.cinemaMetropolisEndTitle, subtitle: l10n.cinemaMetropolisEndSubtitle, kind: IntertitleKind.theEnd)
      : IntertitleCard(text: l10n.cinemaGameOver, subtitle: l10n.cinemaMetropolisLostSubtitle, kind: IntertitleKind.gameOver);

  @override
  // One row up top: score at the start, the reels in the middle, pause at
  // the end. The machine's number rides on the boss bar's name plate
  // («القلب المِرجَل — ٢/٥»): a fourth item in the top row collided with the
  // score once it reached four digits (and at once in English).
  List<(HudSlot, HudItem)> buildHud() => [
    (HudSlot.topStart, hudKit.score()),
    (HudSlot.topCenter, hudKit.lives()),
    (HudSlot.topEnd, hudKit.pauseButton(pauseGame)),
    (HudSlot.bottomCenter, hudKit.bossBar()),
  ];

  // The control hints sit above the HUD's bottom row, inside the play
  // area: the run pad under the left thumb, the buttons under the right one
  // (hands, not reading direction), clear of the boss bar.
  late final RunPadHint _padHint = RunPadHint(this);
  late final JumpButtonHint _jumpHint = JumpButtonHint(this);
  late final WrenchButtonHint _wrenchHint = WrenchButtonHint(this);
  Rect _padHintRect = Rect.zero, _jumpHintRect = Rect.zero, _wrenchHintRect = Rect.zero;
  Rect _controlsFor = Rect.zero;

  Rect get padHintRect => _padHintRect;
  Rect get jumpHintRect => _jumpHintRect;
  Rect get wrenchHintRect => _wrenchHintRect;

  void _layoutControls() {
    final r = playRect;
    if (r.isEmpty) return;
    final ctx = hudContext;
    final s = ctx.scale;
    final bottom = math.min(r.bottom - 10 * s, stage.hudRect.bottom - 52 * s - 8 * s);
    final pad = _padHint.layoutSize(ctx), jump = _jumpHint.layoutSize(ctx), wrench = _wrenchHint.layoutSize(ctx);
    final left = math.max(r.left, stage.hudRect.left) + 6 * s;
    final right = math.min(r.right, stage.hudRect.right) - 6 * s;
    _padHintRect = Rect.fromLTWH(left, bottom - pad.height, pad.width, pad.height);
    _jumpHintRect = Rect.fromLTWH(right - jump.width, bottom - jump.height, jump.width, jump.height);
    _wrenchHintRect = Rect.fromLTWH(_jumpHintRect.left - 10 * s - wrench.width, bottom - wrench.height, wrench.width, wrench.height);
    _controlsFor = r;
  }

  void _paintControls(Canvas canvas) {
    if (!isPlaying && state != SceneState.paused) return;
    if (_controlsFor != playRect) _layoutControls();
    final ctx = hudContext;
    _padHint.paint(canvas, _padHintRect, ctx);
    _jumpHint.paint(canvas, _jumpHintRect, ctx);
    _wrenchHint.paint(canvas, _wrenchHintRect, ctx);
  }

  // ----------------------------------------------------- set / hud state
  @override
  double get scroll => _scroll;
  @override
  int get hall => bossIndex.clamp(0, MetroStage.bossCount - 1);
  @override
  double get hallSlide => _hallSlide;
  @override
  double get cityLights => _cityLights;
  @override
  double get crowdX => _crowdX;
  @override
  bool get crowdVisible => _crowdVisible;
  @override
  double get moveHeld => input.move.abs() > 0.1 ? input.move.sign : 0;
  @override
  bool get jumpHeld => _jumpHeldButton || !heroBody.onGround && heroBody.vy < 0;
  @override
  bool get strikeLit => heroBody.swinging;
  @override
  bool get dashLit => _dashLit > 0;

  /// The run pad's touch zone (screen px): the bottom-left of the play
  /// area, generous around the painted pad.
  Rect get padZone {
    final r = playRect;
    if (_controlsFor != r) _layoutControls();
    return Rect.fromLTRB(r.left - 40, _padHintRect.top - r.height * 0.14, r.left + r.width * 0.42, r.bottom + 80);
  }

  /// The jump button's touch zone (screen px): the outer button plus a
  /// margin, so the wrench button next to it stays a plain tap.
  Rect get jumpZone {
    final r = playRect;
    if (_controlsFor != r) _layoutControls();
    return Rect.fromLTRB(_jumpHintRect.left - 6, _jumpHintRect.top - 16, r.right + 40, r.bottom + 80);
  }

  /// Tests: the machine stands idle (no attacks), so input can be probed.
  bool debugPeaceful = false;

  /// True while a cinematic or a card has the stage (input ignored).
  bool get cinematic => act != MetroAct.fight || _entering || transitions.isActive;

  /// The machine's name (localised) for [index].
  String bossName(int index) => switch (MetroBoss.values[index]) {
    MetroBoss.clockPress => l10n.cinemaMetropolisPressName,
    MetroBoss.boilerHeart => l10n.cinemaMetropolisBoilerName,
    MetroBoss.switchboardSpider => l10n.cinemaMetropolisSpiderName,
    MetroBoss.liftTitan => l10n.cinemaMetropolisTitanName,
    MetroBoss.motherDynamo => l10n.cinemaMetropolisDynamoName,
  };

  /// The boss bar's name plate: the machine's name and its number.
  String bossPlate(int index) => l10n.cinemaMetropolisBossPlate(bossName(index), digits(index + 1), digits(MetroStage.bossCount));

  String _bossLine(int index) => switch (MetroBoss.values[index]) {
    MetroBoss.clockPress => l10n.cinemaMetropolisPressLine,
    MetroBoss.boilerHeart => l10n.cinemaMetropolisBoilerLine,
    MetroBoss.switchboardSpider => l10n.cinemaMetropolisSpiderLine,
    MetroBoss.liftTitan => l10n.cinemaMetropolisTitanLine,
    MetroBoss.motherDynamo => l10n.cinemaMetropolisDynamoLine,
  };

  String _taunt(int afterIndex) => switch (afterIndex) {
    0 => l10n.cinemaMetropolisTauntOne,
    1 => l10n.cinemaMetropolisTauntTwo,
    2 => l10n.cinemaMetropolisTauntThree,
    _ => l10n.cinemaMetropolisTauntFour,
  };

  /// Digits in the reading language (Arabic-Indic for Arabic).
  String digits(int n) {
    final s = '$n';
    if (!l10n.localeName.startsWith('ar')) return s;
    final b = StringBuffer();
    for (final c in s.codeUnits) {
      b.writeCharCode(c >= 0x30 && c <= 0x39 ? 0x0660 + c - 0x30 : c);
    }
    return b.toString();
  }

  // ------------------------------------------------------------- load

  @override
  Future<void> onSceneLoad() async {
    world.addAll(buildMetroSet(this, this));
    hero = RigComponent(rig: heroRig, position: Vector2(MetroStage.heroStartX, MetroStage.groundY), priority: 10);
    world
      ..add(HazardTelegraphs(hazards, priority: 5))
      ..add(PlatformPainter(platforms, priority: 7))
      ..add(_HeroShadow(this)..priority = 9)
      ..add(hero)
      ..add(HazardSketches(hazards, priority: 11))
      ..add(sparks)
      ..add(gears)
      ..add(puffs)
      ..add(flash);
    for (var i = 0; i < hazards.items.length; i++) {
      _wasArmed.add(false);
    }
    add(_PaintLayer(_paintControls)..priority = 150);
    hud
      ..lives = MetroLives.start
      ..maxLives = MetroLives.max;
    final sink = context.scoreSink;
    if (sink != null) {
      unawaited(
        sink.best(gameId).then((b) {
          if (b != null && hud.best == null) hud.best = b;
        }).catchError((Object _) {}),
      );
    }
    heroBody.reset(x: context.skipOpening ? MetroStage.heroStartX : -50);
    hero.position.x = heroBody.x;
    heroRig
      ..act(RigAction.idle)
      ..expression = RigExpression.determined
      ..lookAt(const Offset(1, 0.1));
  }

  @override
  void onSceneStart() {
    if (context.skipOpening || autoplay) {
      _enterBoss();
    } else {
      _startOpening();
    }
  }

  // ------------------------------------------------------------- flow

  void _startOpening() {
    act = MetroAct.opening;
    actTime = 0;
    _crowdVisible = true;
    _crowdX = 40;
    heroRig
      ..act(RigAction.walk)
      ..speed = 120
      ..expression = RigExpression.determined;
    music.cue(MusicMood.adventure, intensity: 0.4);
    sfx.playExtra(CinemaSfx.whistle, volume: 0.8);
  }

  void _openingTick(double dt) {
    actTime += dt;
    _crowdX -= 30 * dt;
    if (actTime < 2.8) {
      // The hero walks in from the wings.
      final k = Bounce.smooth(actTime / 2.8);
      heroBody.x = Bounce.lerp(-50, MetroStage.heroStartX, k);
      if (actTime > 2.4 && heroRig.action == RigAction.walk) {
        heroRig
          ..act(RigAction.idle)
          ..speed = 0;
      }
      return;
    }
    if (actTime >= 2.8 && actTime < 100) {
      actTime = 200; // once
      final one = IntertitleCard(text: l10n.cinemaMetropolisIntroOne, kind: IntertitleKind.dialogue);
      final two = IntertitleCard(text: l10n.cinemaMetropolisIntroTwo, subtitle: l10n.cinemaMetropolisControlsHint, kind: IntertitleKind.dialogue);
      final flow = _flow;
      unawaited(
        transitions.intertitle(one, hold: const Duration(milliseconds: 2400)).then((_) async {
          if (!_live(flow)) return;
          await transitions.intertitle(two, hold: const Duration(milliseconds: 3600));
          if (!_live(flow)) return;
          _crowdVisible = false;
          _showBossCard();
        }),
      );
    }
  }

  /// The chapter card of [bossIndex], then the machine rolls in.
  void _showBossCard() {
    if (_ended) return;
    final last = bossIndex == MetroStage.bossCount - 1;
    if (last) music.stinger(Stinger.drumroll);
    final subtitle = '${l10n.cinemaMetropolisMachineOf(digits(bossIndex + 1), digits(MetroStage.bossCount))} — ${_bossLine(bossIndex)}';
    final card = IntertitleCard(text: bossName(bossIndex), subtitle: subtitle, kind: IntertitleKind.chapter);
    final flow = _flow;
    unawaited(
      transitions.intertitle(card, hold: const Duration(milliseconds: 2900)).then((_) {
        if (!_live(flow)) return;
        _enterBoss();
      }),
    );
  }

  /// Puts machine [bossIndex] on stage (sliding in from the wings).
  void _enterBoss() {
    if (_ended) return;
    final kind = MetroBoss.values[bossIndex];
    _removeBoss();
    final b = BossBrain(kind, seed: context.seed + bossIndex * 7, assist: assist, reducedMotion: env.reducedMotion);
    brain = b;
    final rig = switch (kind) {
      MetroBoss.clockPress => ClockPressRig(b, seed: context.seed),
      MetroBoss.boilerHeart => BoilerRig(b, seed: context.seed),
      MetroBoss.switchboardSpider => SpiderRig(b, seed: context.seed),
      MetroBoss.liftTitan => TitanRig(b, seed: context.seed),
      MetroBoss.motherDynamo => DynamoRig(b, seed: context.seed)..hazards = hazards,
    };
    bossRig = rig;
    rig.lookAt(const Offset(-1, 0.15));
    _enterFrom = kind.standX + 300;
    final comp = RigComponent(rig: rig, position: Vector2(_enterFrom, MetroStage.groundY), priority: 8);
    _bossComponent = comp;
    world.add(comp);
    if (kind == MetroBoss.motherDynamo) {
      final baron = RigCast.clockworkBoss(height: 96, seed: context.seed)
        ..facing = -1
        ..expression = RigExpression.sly
        ..act(RigAction.taunt);
      this.baron = baron;
      final bc = RigComponent(rig: baron, position: Vector2(_enterFrom, MetroStage.groundY - 300), priority: 9);
      _baronComponent = bc;
      world.add(bc);
      _baronFlying = false;
    }
    act = MetroAct.fight;
    actTime = 0;
    _entering = true;
    fightTime = 0;
    flawless = true;
    hud
      ..bossHealth = 1
      ..bossName = bossPlate(bossIndex)
      ..progress = null;
    heroBody
      ..maxX = kind.heroLimit
      ..reset(x: MetroStage.heroStartX);
    heroRig
      ..act(RigAction.idle)
      ..speed = 0
      ..expression = RigExpression.determined
      ..lookAt(const Offset(1, -0.2));
    music
      ..cue(bossIndex == MetroStage.bossCount - 1 ? MusicMood.action : MusicMood.boss, intensity: MetroTuning.intensity(kind, 0))
      ..stinger(Stinger.bossIntro);
    _placePlatforms(kind, 0);
  }

  /// Puts the hall's lift cars in place (the Titan's two, the Dynamo's one
  /// from its last phase); on a phase change the Titan's only speed up.
  void _placePlatforms(MetroBoss kind, int phase, {bool reset = true}) {
    if (kind == MetroBoss.liftTitan) {
      final speed = 40.0 + phase * 32;
      if (reset || !platforms[0].active) {
        platforms[0].place(96, t: 0.1, dir: 1, speed: speed);
        platforms[1].place(206, t: 0.9, dir: -1, speed: speed);
      } else {
        platforms[0].speed = speed;
        platforms[1].speed = speed;
      }
      return;
    }
    if (reset) {
      for (final p in platforms) {
        p.active = false;
      }
    }
    if (kind == MetroBoss.motherDynamo && phase >= 2 && !platforms[0].active) {
      platforms[0].place(150, t: 0.2, dir: 1, speed: 70, w: 100);
    }
  }

  void _entranceTick(double dt) {
    final comp = _bossComponent;
    final b = brain;
    if (comp == null || b == null) return;
    actTime += dt;
    final k = Bounce.smooth((actTime / 1.5).clamp(0.0, 1.0));
    comp.position.x = Bounce.lerp(_enterFrom, b.standX, k);
    _followBaron();
    if (actTime >= 1.5) {
      _entering = false;
      comp.position.x = b.standX;
      b.startFight();
      bossRig?.squash(0.3);
      kick(shake: 0.7 * _shakeScale, damage: 0.1);
      feedback(CinemaSound.explosion, volume: 0.8, pitch: 0.8);
      puffs.spawn(b.standX - 70, MetroStage.groundY - 2, size: 44, life: 0.8);
      puffs.spawn(b.standX + 50, MetroStage.groundY - 2, size: 40, life: 0.8);
    }
  }

  void _followBaron() {
    final bc = _baronComponent, comp = _bossComponent, rig = bossRig;
    if (bc == null || comp == null || rig is! DynamoRig || _baronFlying) return;
    final a = rig.cockpitAnchor;
    bc.position.setValues(comp.position.x + a.dx, comp.position.y + a.dy);
  }

  void _removeBoss() {
    heroBody.maxX = MetroStage.heroMaxX;
    _bossComponent?.removeFromParent();
    _bossComponent = null;
    bossRig = null;
    brain = null;
    _baronComponent?.removeFromParent();
    _baronComponent = null;
    baron = null;
    hazards.clear();
    for (var i = 0; i < _wasArmed.length; i++) {
      _wasArmed[i] = false;
    }
  }

  // ------------------------------------------------------------ update

  @override
  void onGameplayUpdate(double dt) {
    if (_ended) return;
    if (_dashLit > 0) _dashLit -= dt;
    final cards = transitions.isActive;
    switch (act) {
      case MetroAct.opening:
        if (!cards) _openingTick(dt);
        _heroPassive(dt);
      case MetroAct.fight:
        if (_entering) {
          if (!cards) _entranceTick(dt);
          _heroPassive(dt);
        } else {
          _fightTick(dt, cards);
        }
      case MetroAct.bossFall:
        _bossFallTick(dt);
        _heroPassive(dt);
      case MetroAct.transit:
        if (!cards) _transitTick(dt);
        _heroPassive(dt);
      case MetroAct.finale:
        _finaleTick(dt);
        _heroPassive(dt);
      case MetroAct.defeat:
        actTime += dt;
        _heroPassive(dt);
        if (actTime > 1.7) _finish(won: false);
    }
    hero.position.setValues(heroBody.x, heroBody.y);
    heroRig.velocity = heroBody.onGround ? Offset.zero : Offset(heroBody.vx, heroBody.vy);
    _followBaron();
    _syncHud();
  }

  /// The hero outside a fight: scripted, no input.
  void _heroPassive(double dt) {
    input.clear();
    heroBody.update(dt, input, platforms, controllable: false);
  }

  void _fightTick(double dt, bool cards) {
    final b = brain;
    if (b == null) return;
    fightTime += dt;
    // Input.
    if (autoplay) {
      _bot.decide(dt, heroBody, input, hazards, b, platforms);
    } else {
      input.move = _padHeld ? _padDir : 0;
      input.jumpHeld = _jumpHeldButton || _jumpHeldSwipe;
    }
    if (cards) input.clear();
    heroBody.update(dt, input, platforms, controllable: !cards);
    input.clearEdges();
    _heroEvents();
    for (final p in platforms) {
      p.update(dt);
    }
    // The machine.
    if (!cards && !debugPeaceful) {
      b.update(dt, heroBody.x, heroBody.y);
      for (final e in b.events) {
        _onBossEvent(e);
      }
      b.clearEvents();
    }
    hazards.update(dt);
    _armingSounds();
    if (!cards) {
      _collide();
      _strikes();
    }
    // The ragtime follows the fight.
    music.setIntensity(MetroTuning.intensity(b.kind, b.phase) + (b.mode == BossMode.telegraph ? 0.05 : 0));
  }

  /// Sounds and puffs from what the body just did; the rig's action.
  void _heroEvents() {
    final hb = heroBody;
    final rig = heroRig;
    if (hb.jumped) {
      rig.act(RigAction.jump, restart: true);
      feedback(CinemaSound.jump);
      puffs.spawn(hb.x - 6, hb.y - 2, size: 20, life: 0.45);
    }
    if (hb.landed) {
      rig.act(RigAction.land);
      feedback(CinemaSound.land, volume: 0.5);
      puffs.spawn(hb.x + 8, hb.y - 2, size: 24, life: 0.5);
    }
    if (hb.dashed) {
      feedback(CinemaSound.whoosh);
      puffs.spawn(hb.x - hb.facing * 16, hb.y - 6, size: 28, life: 0.5, driftX: -hb.facing * 30);
      _dashLit = 0.3;
    }
    if (hb.struck) {
      rig.act(RigAction.attack, restart: true);
      feedback(CinemaSound.whoosh, volume: 0.7, pitch: 1.3);
    }
    rig.dashing = hb.dashing;
    rig.facing = hb.facing;
    if (hb.dashing) {
      if (rig.action != RigAction.run) rig.act(RigAction.run);
      rig.speed = 620;
      return;
    }
    if (hb.stunned) return;
    if (rig.action == RigAction.attack || rig.action == RigAction.land || rig.action == RigAction.hurt) return;
    if (!hb.onGround) {
      final want = hb.vy < 0 ? RigAction.jump : RigAction.fall;
      if (rig.action != want && !(rig.action == RigAction.jump && want == RigAction.fall && hb.vy < 60)) rig.act(want);
      return;
    }
    final moving = hb.vx.abs() > 25;
    if (moving) {
      if (rig.action != RigAction.run) rig.act(RigAction.run);
      rig.speed = hb.vx.abs();
    } else {
      if (rig.action != RigAction.idle) rig.act(RigAction.idle);
      rig.speed = 0;
    }
    if (hb.iFrames <= 0 && rig.expression == RigExpression.scared) rig.expression = RigExpression.determined;
  }

  /// Hazards that just armed hiss, clank or fall.
  void _armingSounds() {
    for (var i = 0; i < hazards.items.length; i++) {
      final h = hazards.items[i];
      final armed = h.active && h.armed;
      if (armed && !_wasArmed[i]) {
        switch (h.kind) {
          case HazardKind.steamJet:
            feedback(CinemaSound.slideUp, volume: 0.7, pitch: 0.6);
            puffs.spawn(h.x, h.y - 10, size: 34, life: 0.6, driftY: -90);
          case HazardKind.cableStab:
            kick(shake: 0.45 * _shakeScale);
            feedback(CinemaSound.hit, volume: 0.9, pitch: 0.7);
            puffs.spawn(h.x, h.y - 2, size: 30, life: 0.6);
          case HazardKind.stamp || HazardKind.piston:
            kick(shake: 0.85 * _shakeScale, damage: 0.12);
            feedback(CinemaSound.explosion, volume: 0.85);
            puffs.spawn(h.x - 40, h.y - 2, size: 40, life: 0.7);
            puffs.spawn(h.x + 40, h.y - 2, size: 40, life: 0.7);
            sparks.burst(h.x, h.y - 10, count: (10 * _particleScale).round(), speed: 260);
          case HazardKind.rivet:
            feedback(CinemaSound.pop, volume: 0.8);
          case HazardKind.spark:
            feedback(CinemaSound.zap, volume: 0.7);
          case HazardKind.bolt:
            feedback(CinemaSound.tick, volume: 0.5, pitch: 0.7);
          default:
        }
      }
      _wasArmed[i] = armed;
    }
  }

  Hazard? _spawn(
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
  }) {
    final hz = hazards.free();
    if (hz == null) return null;
    final i = hazards.items.indexOf(hz);
    _wasArmed[i] = false;
    hz.spawn(kind, x: x, y: y, w: w, h: h, vx: vx, vy: vy, telegraph: telegraph, life: life, gravity: gravity, param: param, salt: _rng.nextInt(1000));
    return hz;
  }

  void _onBossEvent(BossEvent e) {
    final b = brain!;
    switch (e.kind) {
      case BossEventKind.telegraph:
        _onTelegraph(e, b);
      case BossEventKind.strike:
        _onStrike(e, b);
      case BossEventKind.open:
        feedback(CinemaSound.bell, volume: 0.6, pitch: 1.3);
        sparks.burst(e.x, e.y - 30, count: (6 * _particleScale).round(), speed: 160, dirY: -0.8);
      case BossEventKind.close:
        break;
      case BossEventKind.phase:
        _phaseUp(e.i, b);
      case BossEventKind.dead:
        _bossFell();
    }
  }

  void _onTelegraph(BossEvent e, BossBrain b) {
    final tell = b.modeLength;
    final ph = b.phase;
    final sx = b.standX;
    switch (e.attack) {
      case AttackKind.stamp:
        _spawn(HazardKind.stamp, x: e.x, w: 124, h: 72, telegraph: tell, life: 0.25);
        feedback(CinemaSound.tick, volume: 0.8);
      case AttackKind.stampSweep:
        for (var k = 0; k < 3; k++) {
          _spawn(HazardKind.stamp, x: (e.x + 60.0 * k).clamp(MetroStage.heroMinX + 20, MetroStage.heroMaxX - 20), w: 124, h: 72, telegraph: tell + 0.45 * k, life: 0.25);
        }
        feedback(CinemaSound.tick, volume: 0.8, pitch: 1.2);
      case AttackKind.cogToss:
        feedback(CinemaSound.tick, volume: 0.6, pitch: 1.5);
      case AttackKind.punch:
        _spawn(HazardKind.stamp, x: e.x, w: 104, h: 72, telegraph: tell, life: 0.25);
        feedback(CinemaSound.tick, volume: 0.7, pitch: 0.8);
      case AttackKind.pistons:
        // Two heads: one on the hero, one on the other side of his room.
        final mid = (MetroStage.heroMinX + b.kind.heroLimit) / 2;
        final other = e.x < mid ? e.x + 110 : e.x - 110;
        _spawn(HazardKind.piston, x: e.x, w: 104, h: 72, telegraph: tell, life: 0.3);
        _spawn(HazardKind.piston, x: other.clamp(MetroStage.heroMinX + 30, b.kind.heroLimit), w: 104, h: 72, telegraph: tell + 0.25, life: 0.3);
        feedback(CinemaSound.tick, volume: 0.8, pitch: 0.7);
      case AttackKind.overload:
        _spawn(HazardKind.piston, x: e.x, w: 112, h: 72, telegraph: tell, life: 0.3);
        feedback(CinemaSound.tick, volume: 0.8, pitch: 0.7);
      case AttackKind.jets:
        final count = b.kind == MetroBoss.motherDynamo ? 2 : (ph == 0 ? 2 : 3);
        final start = _rng.nextInt(MetroStage.vents.length);
        for (var k = 0; k < count; k++) {
          final vx = MetroStage.vents[(start + k * (ph == 2 ? 1 : 2)) % MetroStage.vents.length];
          _spawn(HazardKind.steamJet, x: vx, w: 54, h: ph == 2 ? 230 : 200, telegraph: tell + 0.22 * k, life: 0.75);
        }
        feedback(CinemaSound.pop, volume: 0.6, pitch: 0.7);
      case AttackKind.whistle:
        for (var k = 0; k < MetroStage.vents.length; k++) {
          _spawn(HazardKind.steamJet, x: MetroStage.vents[k], w: 54, h: 230, telegraph: tell + 0.3 * k, life: 0.6);
        }
        sfx.playExtra(CinemaSfx.whistle, volume: 0.9);
      case AttackKind.blast:
        feedback(CinemaSound.honk, volume: 0.7, pitch: 0.75);
      case AttackKind.rivets:
        feedback(CinemaSound.tick, volume: 0.6, pitch: 1.4);
      case AttackKind.stab:
        _spawn(HazardKind.cableStab, x: e.x, w: 44, h: 150, telegraph: tell, life: 0.3, param: b.kind == MetroBoss.motherDynamo ? 1 : 0);
        feedback(CinemaSound.tick, volume: 0.7, pitch: 1.25);
      case AttackKind.sweep:
        feedback(CinemaSound.slideDown, volume: 0.6);
      case AttackKind.drop:
        feedback(CinemaSound.slideUp, volume: 0.6, pitch: 1.2);
      case AttackKind.sparks:
        feedback(CinemaSound.zap, volume: 0.5, pitch: 0.8);
      case AttackKind.grab:
        feedback(CinemaSound.bell, volume: 0.8);
      case AttackKind.boltRain:
        for (var k = 0; k < 5; k++) {
          final x = (e.x + (_rng.nextDouble() - 0.5) * 280).clamp(MetroStage.heroMinX + 10, MetroStage.heroMaxX - 10);
          _spawn(HazardKind.bolt, x: x, y: MetroStage.groundY - 440, w: 22, h: 34, telegraph: tell + 0.12 * k, life: 3, gravity: true);
        }
        feedback(CinemaSound.tick, volume: 0.6, pitch: 0.6);
        kick(shake: 0.25 * _shakeScale);
    }
    // Machines that stand still but aim their body at the hero.
    if (sx > 0) bossRig?.lookAt(Offset(heroBody.x < sx ? -1 : 1, 0.2));
  }

  void _onStrike(BossEvent e, BossBrain b) {
    final ph = b.phase;
    final sx = b.standX;
    void shock(double x, {bool both = true}) {
      _spawn(HazardKind.shockwave, x: x - 30, w: 70, h: 48, vx: -360, life: 1.1);
      if (both) _spawn(HazardKind.shockwave, x: x + 30, w: 70, h: 48, vx: 360, life: 1.1);
    }

    switch (e.attack) {
      case AttackKind.stamp:
        if (ph >= 1) shock(e.x);
      case AttackKind.stampSweep:
        if (ph >= 1) shock((e.x + 60.0 * e.i).clamp(MetroStage.heroMinX + 20, MetroStage.heroMaxX - 20), both: e.i == 2);
      case AttackKind.cogToss:
        final x0 = sx - 20, y0 = MetroStage.groundY - 330;
        _spawn(HazardKind.cog, x: x0, y: y0, w: 38, h: 38, vx: (b.targetX - x0) / 1.05, vy: -380, gravity: true, life: 4);
        feedback(CinemaSound.whoosh, volume: 0.7);
      case AttackKind.punch:
        shock(e.x, both: ph >= 2);
      case AttackKind.pistons:
        if (ph >= 1) shock(e.x, both: false);
      case AttackKind.overload:
        if (e.i > 0) {
          final vx = MetroStage.vents[_rng.nextInt(MetroStage.vents.length)];
          _spawn(HazardKind.steamJet, x: vx, w: 54, h: 220, telegraph: 0.45, life: 0.6);
          _spawn(HazardKind.piston, x: e.x, w: 112, h: 72, telegraph: 0.55, life: 0.3);
        }
        if (e.i == 1) _spawn(HazardKind.spark, x: sx - 100, w: 32, h: 32, vx: -300, life: 2.6, telegraph: 0.2);
      case AttackKind.jets:
        break;
      case AttackKind.whistle:
        music.stinger(Stinger.rimshot);
      case AttackKind.blast:
        _spawn(HazardKind.steamBlast, x: sx - 125, w: 140, h: 64, vx: -330, life: 1.4);
        feedback(CinemaSound.whoosh, volume: 0.9, pitch: 0.6);
        kick(shake: 0.3 * _shakeScale);
        puffs.spawn(sx - 110, MetroStage.groundY - 20, size: 40, life: 0.6, driftX: -120);
      case AttackKind.rivets:
        final n = ph >= 2 ? 3 : 2;
        final x0 = sx - 70, y0 = MetroStage.groundY - 150;
        for (var k = 0; k < n; k++) {
          _spawn(HazardKind.rivet, x: x0, y: y0, w: 26, h: 26, vx: (b.targetX - x0) / 0.85 + (k - 1) * 45, vy: -520 - k * 40, gravity: true, telegraph: 0.22 * k, life: 4);
        }
      case AttackKind.stab:
        break;
      case AttackKind.sweep:
        _spawn(HazardKind.cableSweep, x: sx - 70, w: 72, h: 48, vx: -420, life: 1.0, param: b.kind == MetroBoss.motherDynamo ? 1 : 0);
        feedback(CinemaSound.whoosh, volume: 0.8, pitch: 0.8);
      case AttackKind.drop:
        kick(shake: 0.9 * _shakeScale, damage: 0.1);
        feedback(CinemaSound.explosion, volume: 0.9);
        shock(sx - 40);
        puffs.spawn(sx - 90, MetroStage.groundY - 2, size: 44, life: 0.8);
        puffs.spawn(sx + 10, MetroStage.groundY - 2, size: 44, life: 0.8);
      case AttackKind.sparks:
        for (var k = 0; k < 3; k++) {
          _spawn(HazardKind.spark, x: sx - 90, w: 32, h: 32, vx: -(260 + 50.0 * k), telegraph: 0.3 * k, life: 2.6);
        }
      case AttackKind.grab:
        _spawn(HazardKind.grab, x: sx - 70, y: e.y + 10, w: 84, h: 72, vx: -470, life: 0.95);
        feedback(CinemaSound.whoosh, volume: 0.8, pitch: 0.7);
      case AttackKind.boltRain:
        kick(shake: 0.4 * _shakeScale);
        feedback(CinemaSound.hit, volume: 0.6, pitch: 0.5);
    }
  }

  void _phaseUp(int phase, BossBrain b) {
    flash.show(l10n.cinemaMetropolisPhaseUp, heroBody.x, heroBody.y - 150);
    kick(flash: 0.3, shake: 0.6 * _shakeScale, damage: 0.15);
    feedback(CinemaSound.honk, volume: 0.9, pitch: 0.6);
    music.setIntensity(MetroTuning.intensity(b.kind, phase));
    bossRig
      ?..squash(0.3)
      ..flash(0.2);
    final sx = b.standX;
    sparks.burst(sx - 40, MetroStage.groundY - 160, count: (18 * _particleScale).round(), speed: 360);
    puffs.spawn(sx - 60, MetroStage.groundY - 140, size: 44, life: 0.9, driftY: -60);
    puffs.spawn(sx + 20, MetroStage.groundY - 200, size: 40, life: 0.9, driftY: -60);
    _placePlatforms(b.kind, phase, reset: false);
  }

  // ------------------------------------------------------ collisions

  void _collide() {
    final hb = heroBody;
    final b = brain!;
    final heroBox = hb.hitBox;
    for (final h in hazards.items) {
      if (!h.active || !h.armed) continue;
      if (h.parried) {
        // Flying back: does it hit the machine?
        if (!h.hitBoss && h.box.overlaps(_bossBox(b))) {
          h.hitBoss = true;
          h.active = false;
          _bossHit(b, h.x, h.y - h.h / 2, force: true);
        }
        continue;
      }
      if (h.hitHero || hb.invulnerable) continue;
      if (h.box.overlaps(heroBox)) {
        h.hitHero = true;
        if (h.kind.projectile) h.active = false;
        _hurt(h.x);
      }
    }
  }

  Rect _bossBox(BossBrain b) => Rect.fromLTRB(b.standX - 120, MetroStage.groundY - b.kind.height, b.standX + 130, MetroStage.groundY);

  void _strikes() {
    final hb = heroBody;
    if (!hb.striking || hb.strikeConsumed) return;
    final b = brain!;
    final box = hb.strikeBox;
    // Parry first: a projectile in the swing flies back.
    for (final h in hazards.items) {
      if (!h.active || !h.armed || !h.kind.parryable || h.parried) continue;
      if (box.overlaps(h.box)) {
        h.parry(hb.facing);
        hb.strikeConsumed = true;
        parries++;
        addScore(MetroScore.parry);
        flash.show(l10n.cinemaMetropolisParry, hb.x, hb.y - 140);
        feedback(CinemaSound.hit, volume: 1, pitch: 1.4);
        music.stinger(Stinger.pickup);
        kick(flash: 0.2, shake: 0.25 * _shakeScale);
        sparks.burst(h.x, h.y - h.h / 2, count: (10 * _particleScale).round(), speed: 240, dirX: hb.facing * 0.5);
        heroRig.squash(0.15);
        return;
      }
    }
    if (b.vulnerable && box.overlaps(b.weakBox)) {
      hb.strikeConsumed = true;
      _bossHit(b, b.weakX, b.weakY - b.weakH / 2);
    } else if (box.overlaps(_bossBox(b)) && b.alive) {
      // Clang: armour, no damage.
      hb.strikeConsumed = true;
      feedback(CinemaSound.tick, volume: 0.6, pitch: 0.5);
      sparks.burst(box.center.dx + hb.facing * 20, box.center.dy, count: (4 * _particleScale).round(), speed: 140);
    }
  }

  void _bossHit(BossBrain b, double x, double y, {bool force = false}) {
    if (!b.damage(force: force)) return;
    strikesLanded++;
    addScore(MetroScore.strike);
    feedback(CinemaSound.hit, volume: 1);
    kick(flash: 0.28, shake: 0.4 * _shakeScale);
    bossRig
      ?..flash(0.1)
      ..squash(0.22);
    sparks.burst(x, y, count: (14 * _particleScale).round(), speed: 320, dirX: 0.3);
    puffs.spawn(x, y, size: 26, life: 0.5, driftY: -40);
    heroRig.squash(0.1);
    if (b.hp > 0 && b.phase > 0 && b.events.isEmpty) stage.pulse(0.4);
    hud.bossHealth = b.health;
  }

  void _hurt(double fromX) {
    final hb = heroBody;
    hb.hurt(fromX);
    // The attract bot never loses the last reel: the preview keeps playing.
    if (!autoplay || hud.lives > 1) hud.lives = math.max(0, hud.lives - 1);
    livesLost++;
    flawless = false;
    assist = math.min(2, assist + 1);
    brain?.assist = assist;
    heroRig
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.scared;
    kick(flash: 0.45, shake: 0.7 * _shakeScale, damage: 0.55);
    feedback(CinemaSound.hurt);
    music.stinger(Stinger.hit);
    puffs.spawn(hb.x, hb.y - 40, size: 34, life: 0.6);
    if (hud.lives == 0) _gameOver();
  }

  void _gameOver() {
    act = MetroAct.defeat;
    actTime = 0;
    hazards.clear();
    heroRig
      ..act(RigAction.defeated)
      ..expression = RigExpression.dizzy;
    bossRig?.act(RigAction.taunt);
    music.cue(MusicMood.tension, intensity: 0.3);
  }

  // ------------------------------------------------------- boss fall

  void _bossFell() {
    final b = brain!;
    act = MetroAct.bossFall;
    actTime = 0;
    hazards.clear();
    for (final p in platforms) {
      p.active = false;
    }
    hud.bossHealth = 0;
    bossesBeaten++;
    bossRig
      ?..act(RigAction.defeated)
      ..squash(0.4)
      ..flash(0.25);
    baron?.act(RigAction.hurt, restart: true);
    music.stinger(Stinger.bossDefeat);
    sfx.playExtra(CinemaSfx.cymbalCrash, volume: 0.9);
    feedback(CinemaSound.explosion, volume: 1, pitch: 0.7);
    kick(flash: 0.5, shake: 1 * _shakeScale, damage: 0.3);
    final sx = b.standX, top = MetroStage.groundY - b.kind.height * 0.6;
    gears.burst(sx - 40, top, count: (10 * _particleScale).round());
    sparks.burst(sx - 30, top, count: (30 * _particleScale).round(), speed: 420);
    for (var i = 0; i < 3; i++) {
      puffs.spawn(sx - 90 + i * 60.0, MetroStage.groundY - 20 - i * 60.0, size: 50, life: 1, driftY: -40);
    }
    var bonus = MetroScore.bossBonus(bossIndex) + MetroScore.timeBonus(fightTime);
    if (flawless) bonus += MetroScore.flawlessBonus;
    addScore(bonus);
    if (hud.lives < MetroLives.max) {
      hud.lives++;
      flash.show(l10n.cinemaMetropolisReelBack, heroBody.x, heroBody.y - 150);
      feedback(CinemaSound.powerUp, volume: 0.9);
    }
    input.clear();
    heroBody.reset(x: heroBody.x);
    heroRig
      ..act(RigAction.cheer)
      ..expression = RigExpression.happy
      ..lookAt(null)
      ..dashing = false;
    _heroSpot = null;
  }

  void _bossFallTick(double dt) {
    final b = brain;
    actTime += dt;
    if (b != null && actTime < 2.2) {
      b.update(dt, heroBody.x, heroBody.y);
      final sx = b.standX;
      if (((actTime * 5).floor() % 2 == 0) && (actTime * 5) % 1 < dt * 5) {
        sparks.burst(sx - 60 + _rng.nextDouble() * 100, MetroStage.groundY - _rng.nextDouble() * b.kind.height * 0.8, count: (8 * _particleScale).round(), speed: 260);
        puffs.spawn(sx - 50 + _rng.nextDouble() * 80, MetroStage.groundY - 30 - _rng.nextDouble() * 150, size: 34, life: 0.8, driftY: -50);
        kick(shake: 0.3 * _shakeScale);
        feedback(CinemaSound.pop, volume: 0.5, pitch: 0.6 + _rng.nextDouble() * 0.3);
      }
    }
    // Once: the sentinel jumps past the window (a bare `>= 2.4` re-fired
    // the taunt every tick until the first card's continuation started the
    // conveyor – under the card, with the stinger doubled).
    if (actTime >= 2.4 && actTime < 100) {
      actTime = 1000;
      if (bossIndex >= MetroStage.bossCount - 1) {
        _startFinale();
      } else {
        _showTaunt();
      }
    }
  }

  void _showTaunt() {
    final card = IntertitleCard(text: _taunt(bossIndex), subtitle: l10n.cinemaMetropolisTauntSigned, kind: IntertitleKind.dialogue);
    music.stinger(Stinger.rimshot);
    final flow = _flow;
    unawaited(
      transitions.intertitle(card, hold: const Duration(milliseconds: 2600)).then((_) {
        if (!_live(flow)) return;
        _startTransit();
      }),
    );
  }

  // --------------------------------------------------------- transit

  void _startTransit() {
    act = MetroAct.transit;
    actTime = 0;
    _hallSlide = 0;
    _removeBoss();
    heroBody.reset(x: heroBody.x);
    heroRig
      ..act(RigAction.run)
      ..speed = 240
      ..expression = RigExpression.determined
      ..lookAt(const Offset(1, 0.1));
    music.cue(MusicMood.adventure, intensity: 0.6);
    feedback(CinemaSound.projector, volume: 0.5);
  }

  void _transitTick(double dt) {
    actTime += dt;
    const length = 2.0;
    _scroll += 320 * dt;
    _hallSlide = Bounce.smooth((actTime / length).clamp(0.0, 1.0));
    // The conveyor keeps the hero at his mark.
    heroBody.x += (MetroStage.heroStartX - heroBody.x) * math.min(1, dt * 3);
    if (actTime >= length) {
      bossIndex++;
      _hallSlide = 0;
      heroRig
        ..act(RigAction.idle)
        ..speed = 0;
      act = MetroAct.fight;
      _entering = true;
      actTime = 0;
      _showBossCard();
    }
  }

  // ---------------------------------------------------------- finale

  void _startFinale() {
    act = MetroAct.finale;
    actTime = 0;
    _baronFlying = true;
    _baronVx = -230;
    _baronVy = -950;
    _baronSpin = 0;
    baron
      ?..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.dizzy;
    sfx.playExtra(CinemaSfx.crowdCheer, volume: 0.9);
    feedback(CinemaSound.boing, volume: 0.8, pitch: 0.7);
    _crowdVisible = true;
    _crowdX = 300;
    heroRig
      ..act(RigAction.cheer)
      ..expression = RigExpression.happy;
    _finaleCardShown = false;
  }

  void _finaleTick(double dt) {
    actTime += dt;
    _cityLights = (actTime / 3).clamp(0.0, 1.0);
    if (!_finaleCardShown && actTime > 1.1) {
      _finaleCardShown = true;
      final card = IntertitleCard(text: l10n.cinemaMetropolisBaronBeaten, subtitle: l10n.cinemaMetropolisTauntSigned, kind: IntertitleKind.dialogue);
      unawaited(transitions.intertitle(card, hold: const Duration(milliseconds: 2200)));
    }
    _crowdX -= 40 * dt;
    final bc = _baronComponent;
    if (bc != null && _baronFlying) {
      _baronVy += 1500 * dt;
      _baronSpin += 7 * dt;
      bc.position.x += _baronVx * dt;
      bc.position.y += _baronVy * dt;
      bc.angle = _baronSpin;
    }
    _heroSpot ??= worldToScreen(Vector2(heroBody.x, MetroStage.groundY - 60));
    stage.spotlight(_heroSpot);
    if (actTime > 0.4 && (actTime * 4) % 1 < dt * 4) {
      final sx = MetroBoss.motherDynamo.standX;
      sparks.burst(sx - 80 + _rng.nextDouble() * 160, MetroStage.groundY - _rng.nextDouble() * 280, count: (10 * _particleScale).round(), speed: 300);
      gears.burst(sx - 60 + _rng.nextDouble() * 120, MetroStage.groundY - 120, count: 2);
      puffs.spawn(sx - 60 + _rng.nextDouble() * 120, MetroStage.groundY - 60 - _rng.nextDouble() * 150, size: 40, life: 0.9, driftY: -50);
    }
    if (actTime > 6.2 && !transitions.isActive) {
      stage.spotlight(null);
      _finish(won: true);
    }
  }

  void _finish({required bool won}) {
    if (_ended) return;
    _ended = true;
    unawaited(
      endScene(
        won: won,
        stats: {'bosses': bossesBeaten, 'parries': parries, 'hits': strikesLanded, 'livesLost': livesLost},
      ),
    );
  }

  void _syncHud() {
    final b = brain;
    if (b != null && act == MetroAct.fight) hud.bossHealth = b.health;
  }

  /// Whether a continuation captured at [flow] may still run.
  bool _live(int flow) => !_ended && flow == _flow;

  /// The intermission (pause button, back, backgrounding) lets go of every
  /// held control: the engine forwards no tap-cancel, so a finger that was
  /// on the pad when the app went to the background would otherwise keep
  /// the hero running after the resume.
  @override
  void pauseGame() {
    releaseControls();
    super.pauseGame();
  }

  /// Lets go of the pad, the buttons and any half-made swipe.
  void releaseControls() {
    _padHeld = false;
    _padDir = 0;
    _padSwiped = false;
    _actionDown = false;
    _swipeDone = false;
    _jumpHeldButton = false;
    _jumpHeldSwipe = false;
    input.clear();
  }

  @override
  void onDispose() {
    // Disposing clears the transitions, which completes any pending card:
    // its continuation must find the show over.
    _flow++;
    _ended = true;
    super.onDispose();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _heroSpot = null;
    _controlsFor = Rect.zero;
  }

  // ----------------------------------------------------------- input

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) {
    if (!isPlaying || autoplay) return;
    if (padZone.contains(screenPoint)) {
      _padHeld = true;
      _padDir = screenPoint.dx < padZone.center.dx + 20 ? -1 : 1;
      _padDownAt = screenPoint;
      _padDownTime = clock.time;
      _padSwiped = false;
    } else if (jumpZone.contains(screenPoint)) {
      input.jump = true;
      _jumpHeldButton = true;
    } else {
      _actionDown = true;
      _actionDownAt = screenPoint;
      _swipeDone = false;
    }
  }

  @override
  void onScreenTapUp(Vector2 worldPoint, Offset screenPoint) {
    if (autoplay) return;
    if (_padHeld && padZone.inflate(30).contains(screenPoint)) {
      _padHeld = false;
    } else if (_jumpHeldButton && jumpZone.inflate(30).contains(screenPoint)) {
      _jumpHeldButton = false;
    } else if (_actionDown) {
      _actionDown = false;
      if (!_swipeDone && isPlaying) input.strike = true;
    } else {
      _padHeld = false;
      _jumpHeldButton = false;
    }
  }

  @override
  void onScreenDrag(Vector2 worldDelta, Offset screenPoint) {
    if (autoplay) return;
    if (_actionDown) {
      if (_swipeDone) return;
      final d = screenPoint - _actionDownAt;
      if (d.dy < -42 && d.dy.abs() > d.dx.abs()) {
        input.jump = true;
        _jumpHeldSwipe = true;
        _swipeDone = true;
      } else if (d.dy > 48 && d.dy.abs() > d.dx.abs()) {
        input.drop = true;
        _swipeDone = true;
      } else if (d.dx.abs() > 44) {
        input.dash = d.dx.sign.toInt();
        _swipeDone = true;
      }
    } else if (_padHeld) {
      final d = screenPoint - _padDownAt;
      if (!_padSwiped) {
        final quick = clock.time - _padDownTime < 0.28;
        if (quick && d.dx.abs() > 52 && d.dx.abs() > d.dy.abs()) {
          input.dash = d.dx.sign.toInt();
          _padSwiped = true;
        } else if (d.dy < -52 && d.dy.abs() > d.dx.abs()) {
          input.jump = true;
          _jumpHeldSwipe = true;
          _padSwiped = true;
        }
      }
      if (padZone.inflate(40).contains(screenPoint)) {
        _padDir = screenPoint.dx < padZone.center.dx + 20 ? -1 : 1;
      }
    }
  }

  @override
  void onScreenDragEnd() {
    if (autoplay) return;
    if (_actionDown) {
      _actionDown = false;
      _jumpHeldSwipe = false;
    } else if (_padHeld) {
      _padHeld = false;
      _jumpHeldSwipe = false;
    } else {
      _jumpHeldButton = false;
      _jumpHeldSwipe = false;
    }
  }

  // ----------------------------------------------------------- debug

  /// Tests and screenshots: puts machine [index] on stage at [phase], the
  /// entrance done, the fight on.
  void debugJumpToBoss(int index, {int phase = 0}) {
    bossIndex = index.clamp(0, MetroStage.bossCount - 1);
    _hallSlide = 0;
    _crowdVisible = false;
    _flow++;
    transitions.clear();
    _enterBoss();
    final comp = _bossComponent!, b = brain!;
    comp.position.x = b.standX;
    _entering = false;
    b
      ..debugSetPhase(phase)
      ..startFight();
    _placePlatforms(b.kind, phase);
    music.setIntensity(MetroTuning.intensity(b.kind, phase));
    hud.bossHealth = b.health;
  }

  /// Tests: the machine falls now.
  void debugDefeatBoss() {
    final b = brain;
    if (b == null || !b.alive) return;
    b.damage(amount: b.hp, force: true);
    for (final e in b.events) {
      _onBossEvent(e);
    }
    b.clearEvents();
  }

  /// Tests: the machine makes [kind] its next move at once.
  void debugForceAttack(AttackKind kind) => brain?.debugAttackNow(kind);

  /// Tests: the hero takes a hit.
  void debugHurtHero() => _hurt(heroBody.x + 10);

  /// Whether the entrance is still playing.
  bool get entering => _entering;
}

/// Screen-space layer that delegates painting (the control hints).
class _PaintLayer extends Component {
  _PaintLayer(this._paint);

  final void Function(Canvas canvas) _paint;

  @override
  void render(Canvas canvas) => _paint(canvas);
}

/// The hero's contact shadow: shrinks and fades as he rises.
class _HeroShadow extends Component {
  _HeroShadow(this.game);

  final MetropolisGame game;
  final Paint _paint = Paint();
  static const Rect _unit = Rect.fromLTRB(-1, -1, 1, 1);

  @override
  void render(Canvas canvas) {
    final hb = game.heroBody;
    var floor = MetroStage.groundY;
    for (final p in game.platforms) {
      if (p.active && (hb.x - p.x).abs() < p.w / 2 && p.y >= hb.y - 1 && p.y < floor) floor = p.y;
    }
    final lift = (floor - hb.y).clamp(0.0, 260.0) / 260;
    final w = 30 * (1 - lift * 0.45);
    _paint.color = game.skin.palette.ink.withValues(alpha: 0.22 * (1 - lift * 0.6));
    // A const unit oval, scaled: no geometry built per frame.
    canvas
      ..save()
      ..translate(hb.x, floor + 2)
      ..scale(w, w * 0.21)
      ..drawOval(_unit, _paint)
      ..restore();
  }
}
