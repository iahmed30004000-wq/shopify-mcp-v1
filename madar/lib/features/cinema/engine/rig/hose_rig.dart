import 'dart:math' as math;
import 'dart:ui';

import '../core/era_skin.dart';
import '../core/rig.dart';
import 'ink/boil.dart';
import 'ink/ink_build.dart';
import 'motion/spring.dart';
import 'parts/extremities.dart';

/// How often a rig makes a new drawing.
enum RigTiming {
  /// 1930s practice: loops that stay in place (idle, talk, cheer, taunt)
  /// are drawn on twos (12/s), anything that travels or hits on ones (24/s).
  auto,

  /// Every drawing held for two film frames (12 drawings/s).
  twos,

  /// A new drawing every film frame (24/s).
  ones,

  /// A new drawing every game tick (video-smooth, the 1980s look).
  smooth,
}

/// Base class of every procedural rubber-hose character.
///
/// Implements the [RigCharacter] contract once: action switching with
/// auto-return of one-shots, the volume-preserving squash spring, turning
/// through the front view, pupils that glance and blinks that come in
/// pairs, a hit flash, and the drawing cache.
///
/// **Drawing cache.** Like a cel animator, the rig makes a *drawing* only
/// when something changes – a new pose drawing (on ones or twos, see
/// [timing]), a new line-boil frame, a new skin or zoom – into a retained
/// [InkBuild] display list, and replays it every frame in between. Paths,
/// paints and shaders are pooled: nothing is allocated per frame.
///
/// Subclasses implement [animate] (targets and springs, called in fixed
/// sub-steps) and [build] (the drawing).
abstract class HoseRig implements RigCharacter {
  HoseRig(this.spec) : ink = InkBuild(seed: seedOf(spec.id) ^ spec.seed) {
    _nextBlink = 1.2 + boilHash01(0, ink.seed, 7) * 2.5;
    _nextGlance = 3 + boilHash01(0, ink.seed, 8) * 3;
  }

  @override
  final RigSpec spec;

  /// The retained drawing (exposed for tests and custom art).
  final InkBuild ink;

  /// Drawing rate policy.
  RigTiming timing = RigTiming.auto;

  /// Beats per minute of the idle bounce; `null` = the era's score tempo
  /// (so the whole cast bounces on the music's beat).
  double? tempo;

  /// Draw emanata (dizzy stars, sweat, speed lines, dust…).
  bool emanata = true;

  /// While > 0 the fills flash white (hit flash).
  double flashTime = 0;

  /// Mouth motion 0..1 a game can drive while the character speaks
  /// (the [RigAction.talk] loop animates it by itself).
  double talkLevel = 0;

  // --------------------------------------------------------------- state
  RigAction _action = RigAction.idle;
  RigAction _prevAction = RigAction.idle;
  double actionTime = 0;
  RigExpression _expression = RigExpression.neutral;
  double expressionTime = 10;
  double _facing = 1;
  final Spring1 facingSpring = Spring1(1);
  @override
  double speed = 0;
  Offset? _look;
  final Spring2 lookSpring = Spring2();
  final Spring1 squashSpring = Spring1();
  double time = 0;

  /// Beat phase (beats since start) at the current tempo.
  double beat = 0;

  /// Locomotion cycle phase (radians).
  double cycle = 0;

  double _nextBlink = 2, _blink = 0, _nextGlance = 4, _glance = 0, _glanceDir = 1;
  final List<HandShape?> _hands = [null, null];

  // Drawing cache keys.
  int _drawKey = -1, _boilKey = -1;
  EraSkin? _skinKey;
  double _scaleKey = -1;
  bool _dirty = true;
  double _tempoSkin = 120;

  /// Number of drawings made so far (tests: proves caching).
  int drawings = 0;

  Rect _bounds = Rect.zero;

  @override
  RigAction get action => _action;

  RigAction get previousAction => _prevAction;

  @override
  RigExpression get expression => _expression;

  @override
  set expression(RigExpression value) {
    if (value == _expression) return;
    _expression = value;
    expressionTime = 0;
    _dirty = true;
  }

  @override
  double get facing => _facing;

  @override
  set facing(double value) {
    final v = value.clamp(-1.0, 1.0);
    if (v == _facing) return;
    // A flip squashes through the turn.
    if (v.sign != _facing.sign && v != 0) squash(0.12);
    _facing = v;
    _dirty = true;
  }

  /// Displayed facing (springs through the front view when flipped).
  double get facingShown => facingSpring.value.clamp(-1.0, 1.0);

  /// 0 = front view … 1 = three-quarter toward the facing side.
  double get turn => Bounce.smooth(facingShown.abs() * 1.15);

  /// +1 / −1: which way the drawing is mirrored.
  double get dir => facingShown >= 0 ? 1.0 : -1.0;

  @override
  void act(RigAction action, {bool restart = false}) {
    if (action == _action && !restart) return;
    _prevAction = _action;
    _action = action;
    actionTime = 0;
    _dirty = true;
    onAction(action, _prevAction);
  }

  /// Hook: a new action started (kick springs, flash…).
  void onAction(RigAction action, RigAction previous) {
    switch (action) {
      case RigAction.jump:
        squash(-0.3);
      case RigAction.land:
        squash(0.34);
      case RigAction.hurt:
        squash(-0.2);
        flash(0.09);
      case RigAction.attack:
        squash(0.12);
      case RigAction.defeated:
        squash(0.3);
      default:
    }
  }

  /// Seconds a one-shot plays before returning to idle (0 = loops / holds).
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.land => 0.3,
    RigAction.hurt => 0.62,
    RigAction.attack => 0.46,
    _ => 0,
  };

  @override
  void lookAt(Offset? direction) => _look = direction;

  Offset? get lookTarget => _look;

  @override
  void squash(double amount) => squashSpring.kick(amount * 9 * (0.4 + 0.6 * spec.bounciness));

  /// Current squash (+) / stretch (−).
  double get squashAmount => squashSpring.value;

  /// Flash the fills white for [seconds] (a hit).
  void flash([double seconds = 0.08]) => flashTime = math.max(flashTime, seconds);

  /// Overrides a hand's shape (index 0 = far/back hand, 1 = near/front);
  /// `null` returns it to the pose's own shape.
  void setHand(int index, HandShape? shape) {
    _hands[index.clamp(0, 1)] = shape;
    _dirty = true;
  }

  HandShape? handOverride(int index) => _hands[index.clamp(0, 1)];

  /// 0..1 how closed the eyes are from blinking.
  double get blinkAmount => _blink > 0 ? 1 : 0;

  /// Idle glance direction (−1..1) or 0.
  double get glance => _glance > 0 ? _glanceDir : 0;

  double get tempoBpm => tempo ?? _tempoSkin;

  // -------------------------------------------------------------- update

  @override
  void update(double dt) {
    if (dt <= 0) return;
    final steps = math.max(1, (dt * 120).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      _step(h);
    }
  }

  void _step(double h) {
    time += h;
    actionTime += h;
    expressionTime += h;
    beat += h * tempoBpm / 60;
    if (flashTime > 0) flashTime = math.max(0, flashTime - h);
    final len = oneShotLength(_action);
    if (len > 0 && actionTime >= len) act(RigAction.idle);

    // Facing turns through the front (quick, a touch of overshoot).
    facingSpring.step(h, _facing, 24, 0.75);
    // Squash wobbles back with overshoot (rubber).
    final k = 0.8 + 0.4 * spec.bounciness;
    squashSpring.step(h, 0, 17 * k, 0.32 / k);
    squashSpring.value = squashSpring.value.clamp(-0.45, 0.45);

    // Blinks (sometimes a double blink) and idle glances.
    _nextBlink -= h;
    if (_nextBlink <= 0) {
      _blink = 0.1;
      final r = boilHash01((time * 10).floor(), ink.seed, 11);
      _nextBlink = r < 0.18 ? 0.22 : 2.2 + r * 3.2;
    }
    if (_blink > 0) _blink = math.max(0, _blink - h);
    _nextGlance -= h;
    if (_nextGlance <= 0) {
      _glance = 0.9;
      _glanceDir = boilNoise((time * 10).floor(), ink.seed, 12) > 0 ? 1 : -1;
      _nextGlance = 3.5 + boilHash01((time * 10).floor(), ink.seed, 13) * 4;
    }
    if (_glance > 0) _glance = math.max(0, _glance - h);
    final lx = _look?.dx ?? glance * 0.9, ly = _look?.dy ?? 0.0;
    final ll = math.sqrt(lx * lx + ly * ly);
    final nx = ll > 1 ? lx / ll : lx, ny = ll > 1 ? ly / ll : ly;
    lookSpring.step(h, nx, ny, 34, 0.8);

    animate(h);
  }

  /// Advances the character's own targets and springs by [h] (≤ 1/120 s).
  void animate(double h);

  // --------------------------------------------------------------- paint

  /// Whether the pose is "fast" (drawn on ones in [RigTiming.auto]).
  bool get fastAction {
    switch (_action) {
      case RigAction.idle || RigAction.talk || RigAction.cheer || RigAction.taunt || RigAction.defeated:
        return actionTime < 0.2 || squashSpring.velocity.abs() > 1.2;
      default:
        return true;
    }
  }

  double _drawRate(EraSkin skin) {
    if (skin.ink.boilFps <= 0) return 0;
    return switch (timing) {
      RigTiming.smooth => 0,
      RigTiming.ones => 24,
      RigTiming.twos => 12,
      RigTiming.auto => fastAction ? 24 : 12,
    };
  }

  @override
  void paint(Canvas canvas, RigPaintContext context) {
    final clock = context.clock;
    final skin = context.skin;
    final rate = _drawRate(skin);
    final key = rate <= 0 ? clock.tick : (clock.time * rate + 1e-6).floor() * 100 + rate.toInt();
    if (_dirty ||
        key != _drawKey ||
        clock.boilFrame != _boilKey ||
        !identical(skin, _skinKey) ||
        context.pixelScale != _scaleKey) {
      _drawKey = key;
      _boilKey = clock.boilFrame;
      _skinKey = skin;
      _scaleKey = context.pixelScale;
      _dirty = false;
      _tempoSkin = skin.score.tempo;
      ink.time = time;
      build(context);
      drawings++;
    }
    ink.list.replay(canvas, flash: flashTime > 0 ? ink.colors.flash : null);
  }

  /// Builds the drawing into [ink] (call [InkBuild.begin] first).
  void build(RigPaintContext context);

  /// Records the drawing's bounds (character space) during [build].
  void setBounds(Rect r) => _bounds = r;

  @override
  Rect get bounds {
    if (_bounds != Rect.zero) return _bounds;
    final h = spec.height;
    return Rect.fromLTRB(-h * 0.5, -h * 1.06, h * 0.5, 0);
  }

  /// Forces a new drawing on the next paint.
  void markDirty() => _dirty = true;

  @override
  void dispose() => ink.list.dispose();
}
