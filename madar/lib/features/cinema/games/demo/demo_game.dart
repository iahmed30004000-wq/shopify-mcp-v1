import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';

/// "Rehearsal" – the engine's demo scene: a rubber-hose hero on a painted
/// stage jumps rolling barrels. Tap to jump; clear 12 barrels to win, three
/// hits and the show is over. It exists so every engine agent can see its
/// piece (grade, rig, stage, HUD, transitions, audio cues) in context – not
/// as a showcase game.
class DemoGame extends CinemaGame {
  DemoGame({required super.context, Era era = Era.rubberHose, this.autoplay = false})
    : super(skin: EraSkins.of(era));

  /// Attract mode: the hero jumps by itself (screenshots, hall preview).
  final bool autoplay;

  static const double groundY = 640;
  static const int goal = 12;
  static const double _gravity = 2300;
  static const double _jumpSpeed = 940;
  static const double _heroX = 112;

  late final RigComponent hero;
  final List<_Barrel> _barrels = [];
  double _vy = 0;
  double _heroY = groundY;
  double _spawnIn = 0.6;
  double _invulnerable = 0;
  final math.Random _rng = math.Random(7);

  @override
  String get gameId => 'demo';

  @override
  Vector2 get worldSize => Vector2(360, 800);

  @override
  IntertitleCard? openingCard() =>
      IntertitleCard(text: l10n.cinemaDemoOpening, subtitle: l10n.cinemaDemoOpeningSubtitle);

  bool get _onGround => _heroY >= groundY - 0.01;

  @override
  Future<void> onSceneLoad() async {
    world.add(_Backdrop(this));
    hero = RigComponent(
      rig: context.kit.rig(const RigSpec(id: 'demo_hero', height: 118, accent: PaletteRole.accent)),
      position: Vector2(_heroX, groundY),
      priority: 10,
    );
    world.add(hero);
    for (var i = 0; i < 4; i++) {
      final b = _Barrel(this)..priority = 5;
      _barrels.add(b);
      world.add(b);
    }
    hud
      ..lives = 3
      ..maxLives = 3;
    if (autoplay) {
      // Attract mode opens mid-show: barrels already rolling.
      _barrels[0].launch(250, 205);
      _barrels[1].launch(470, 205);
    }
  }

  @override
  void onSceneStart() {
    hero.rig
      ..act(RigAction.run)
      ..speed = 180
      ..expression = RigExpression.happy;
    music.cue(MusicMood.adventure, intensity: 0.4);
  }

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) {
    if (isPlaying) _jump();
  }

  void _jump() {
    if (!_onGround) return;
    _vy = -_jumpSpeed;
    hero.rig.act(RigAction.jump, restart: true);
    feedback(CinemaSound.jump);
  }

  @override
  void onGameplayUpdate(double dt) {
    // Hero physics.
    if (!_onGround || _vy < 0) {
      _vy += _gravity * dt;
      _heroY = math.min(groundY, _heroY + _vy * dt);
      if (_vy > 0 && hero.rig.action == RigAction.jump) hero.rig.act(RigAction.fall);
      if (_heroY >= groundY) {
        _vy = 0;
        hero.rig.act(RigAction.land);
        feedback(CinemaSound.land, volume: 0.6);
      }
    } else if (hero.rig.action == RigAction.idle) {
      hero.rig.act(RigAction.run);
    }
    hero.position.y = _heroY;
    if (_invulnerable > 0) {
      _invulnerable -= dt;
      hero.rig.expression = _invulnerable > 0 ? RigExpression.scared : RigExpression.happy;
    }

    // Barrels.
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      final free = _barrels.where((b) => !b.active).firstOrNull;
      if (free != null) {
        free.launch(worldSize.x + 60, 170 + hud.score * 9.0 + _rng.nextDouble() * 40);
        _spawnIn = 1.1 + _rng.nextDouble() * 0.9;
      }
    }
    for (final b in _barrels) {
      if (!b.active) continue;
      if (autoplay && _onGround && b.x > _heroX && b.x - _heroX < 82 + b.speed * 0.06) _jump();
      final dx = (b.x - _heroX).abs();
      final heroBottom = _heroY;
      if (_invulnerable <= 0 && dx < 38 && heroBottom > groundY - b.radius * 1.7) {
        _hit(b);
      } else if (!b.scored && b.x < _heroX - 30) {
        b.scored = true;
        addScore(1);
        feedback(CinemaSound.coin);
        if (hud.score >= goal) endScene(won: true);
      }
    }
    music.setIntensity((0.3 + hud.score / goal * 0.6).clamp(0.0, 1.0));
    hud.progress = hud.score / goal;
  }

  void _hit(_Barrel b) {
    b.scored = true;
    b.bounceAway();
    _invulnerable = 1.3;
    hud.lives = math.max(0, hud.lives - 1);
    hero.rig
      ..act(RigAction.hurt, restart: true)
      ..expression = RigExpression.scared;
    kick(flash: 0.45, shake: 0.7, damage: 0.6);
    feedback(CinemaSound.hurt);
    music.stinger(Stinger.hit);
    if (hud.lives == 0) endScene(won: false);
  }
}

/// A rolling barrel (pooled – launched and recycled, never re-created).
class _Barrel extends PositionComponent {
  _Barrel(this.game);

  final DemoGame game;
  bool active = false;
  bool scored = false;
  double speed = 0;
  double radius = 26;
  double _angle = 0;
  double _vy = 0;
  bool _flying = false;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void launch(double x, double speed) {
    active = true;
    scored = false;
    _flying = false;
    this.speed = speed;
    position = Vector2(x, DemoGame.groundY - radius);
  }

  void bounceAway() {
    _flying = true;
    _vy = -620;
    speed = -120;
  }

  @override
  void update(double dt) {
    if (!active) return;
    position.x -= speed * dt;
    _angle -= speed * dt / radius;
    if (_flying) {
      _vy += 1800 * dt;
      position.y += _vy * dt;
      if (position.y > 900) active = false;
    }
    if (position.x < -80 || position.x > 600) active = false;
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final pal = game.skin.palette;
    final line = game.skin.ink.lineWidth * 0.9;
    final squash = _flying ? 1.0 : 1 + 0.04 * math.sin(_angle * 2);
    canvas
      ..save()
      ..scale(1 / squash, squash)
      ..rotate(_angle);
    _fill.color = pal.midtone;
    canvas.drawCircle(Offset.zero, radius, _fill);
    _fill.color = pal.shadow;
    canvas.drawCircle(const Offset(5, 6), radius * 0.72, _fill);
    _fill.color = pal.midtone;
    canvas.drawCircle(Offset.zero, radius * 0.62, _fill);
    _stroke
      ..color = pal.ink
      ..strokeWidth = line;
    canvas
      ..drawCircle(Offset.zero, radius, _stroke)
      ..drawCircle(Offset.zero, radius * 0.62, _stroke..strokeWidth = line * 0.7);
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(Offset(math.cos(a), math.sin(a)) * radius * 0.6, Offset(math.cos(a), math.sin(a)) * -radius * 0.6, _stroke);
    }
    _fill.color = pal.ink;
    canvas.drawCircle(Offset.zero, radius * 0.1, _fill);
    canvas.restore();
  }
}

/// The painted backdrop: sky, a grinning sun with turning rays, cardboard
/// hills with halftone shading, drifting clouds and stage boards.
class _Backdrop extends Component {
  _Backdrop(this.game);

  final DemoGame game;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _shade = Paint();
  final Path _path = Path();
  final ShaderPool _halftone = ShaderPool(CinemaShader.halftone, maxInstances: 4);
  Shader? _sky;

  double _j(int i) {
    final amp = game.skin.ink.boilAmplitude;
    if (amp == 0) return 0;
    final h = math.sin((game.clock.boilFrame * 12.9898 + i * 78.233)) * 43758.5453;
    return (h - h.floorToDouble() - 0.5) * 2 * amp;
  }

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    final t = game.clock.time;
    final line = game.skin.ink.lineWidth;

    _sky ??= Gradient.linear(const Offset(0, -200), const Offset(0, DemoGame.groundY), [
      Color.lerp(pal.backdrop, pal.shadow, 0.35)!,
      pal.backdrop,
      Color.lerp(pal.backdrop, pal.highlight, 0.55)!,
    ], [0, 0.6, 1]);
    _fill.shader = _sky;
    canvas.drawRect(const Rect.fromLTRB(-300, -400, 660, DemoGame.groundY + 2), _fill);
    _fill.shader = null;

    // Sun with turning rays and a face.
    const sun = Offset(252, 250);
    _fill.color = Color.lerp(pal.paper, pal.accent, game.era.isMonochrome ? 0 : 0.25)!;
    _stroke
      ..color = pal.ink
      ..strokeWidth = line;
    _path.reset();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + t * 0.35;
      final a1 = a - 0.11, a2 = a + 0.11;
      _path
        ..moveTo(sun.dx + math.cos(a1) * 56, sun.dy + math.sin(a1) * 56)
        ..lineTo(sun.dx + math.cos(a) * (86 + _j(i)), sun.dy + math.sin(a) * (86 + _j(i + 20)))
        ..lineTo(sun.dx + math.cos(a2) * 56, sun.dy + math.sin(a2) * 56)
        ..close();
    }
    canvas
      ..drawPath(_path, _fill)
      ..drawPath(_path, _stroke);
    canvas
      ..drawCircle(sun, 52, _fill)
      ..drawCircle(sun, 52 + _j(3) * 0.5, _stroke);
    _fill.color = pal.ink;
    for (final dx in [-16.0, 16.0]) {
      canvas.drawOval(Rect.fromCenter(center: sun + Offset(dx, -10), width: 11, height: 18), _fill);
    }
    _path
      ..reset()
      ..moveTo(sun.dx - 22, sun.dy + 12)
      ..quadraticBezierTo(sun.dx + _j(5), sun.dy + 34, sun.dx + 22, sun.dy + 12);
    canvas.drawPath(_path, _stroke);

    // Clouds.
    for (var i = 0; i < 3; i++) {
      final x = ((i * 170 + t * (10 + i * 4)) % 620) - 140;
      final y = 150.0 + i * 70;
      _cloud(canvas, Offset(x, y), 1 - i * 0.18, pal, line, i);
    }

    // Hills (far: halftone shaded, near: flat) with ink outlines.
    _hill(canvas, -40, 470, 460, 540, pal.midtone, pal, line, 0, shaded: true);
    _hill(canvas, 150, 525, 560, 580, Color.lerp(pal.midtone, pal.paper, 0.4)!, pal, line, 1, shaded: false);

    // Stage boards.
    _fill.color = Color.lerp(pal.midtone, pal.shadow, 0.35)!;
    canvas.drawRect(const Rect.fromLTRB(-300, DemoGame.groundY, 660, 1000), _fill);
    _stroke
      ..color = pal.ink
      ..strokeWidth = line;
    canvas.drawLine(const Offset(-300, DemoGame.groundY), const Offset(660, DemoGame.groundY), _stroke);
    _stroke.strokeWidth = line * 0.5;
    for (var i = 0; i < 6; i++) {
      final y = DemoGame.groundY + 16 + i * (14.0 + i * 5);
      canvas.drawLine(Offset(-300, y), Offset(660, y + _j(40 + i)), _stroke);
    }
    for (var i = -6; i < 16; i++) {
      final x = i * 48.0 + (i.isEven ? 0 : 20);
      canvas.drawLine(Offset(x, DemoGame.groundY + 2), Offset(x - 8, DemoGame.groundY + 26), _stroke);
    }
  }

  void _cloud(Canvas canvas, Offset c, double s, EraPalette pal, double line, int seed) {
    _path.reset();
    for (final (dx, dy, r) in const [(-34.0, 6.0, 20.0), (-10.0, -8.0, 26.0), (18.0, -2.0, 22.0), (38.0, 8.0, 16.0)]) {
      _path.addOval(Rect.fromCircle(center: c + Offset(dx * s, dy * s), radius: r * s + _j(seed * 7 + dx.toInt()) * 0.4));
    }
    _fill.color = pal.paper;
    _stroke
      ..color = pal.ink
      ..strokeWidth = line * 0.8;
    canvas
      ..drawPath(_path, _stroke)
      ..drawPath(_path, _fill);
  }

  void _hill(Canvas canvas, double x0, double top, double x1, double base, Color color, EraPalette pal, double line, int seed, {required bool shaded}) {
    final mid = (x0 + x1) / 2;
    _path
      ..reset()
      ..moveTo(x0 - 200, DemoGame.groundY + 2)
      ..lineTo(x0 - 200, base)
      ..cubicTo(x0, base, mid - 120, top + _j(seed * 3), mid, top)
      ..cubicTo(mid + 120, top + _j(seed * 3 + 1), x1, base, x1 + 200, base)
      ..lineTo(x1 + 200, DemoGame.groundY + 2)
      ..close();
    _fill.color = color;
    canvas.drawPath(_path, _fill);
    if (shaded) {
      final s = _halftone.next(game.clock);
      if (s != null) {
        HalftoneUniforms.write(
          s,
          from: Offset(mid - 60, top),
          to: Offset(x1, DemoGame.groundY),
          ink: pal.shadow,
          style: game.skin.halftone,
          toneFrom: -0.2,
          toneTo: 0.9,
          boilFrame: game.clock.boilFrame,
          pixelScale: game.rigPaint.pixelScale,
        );
        _shade.shader = s;
        canvas
          ..save()
          ..clipPath(_path)
          ..drawRect(Rect.fromLTRB(x0 - 200, top - 10, x1 + 200, DemoGame.groundY), _shade)
          ..restore();
      }
    }
    _stroke
      ..color = pal.ink
      ..strokeWidth = line;
    canvas.drawPath(_path, _stroke);
  }

  @override
  void onRemove() {
    _halftone.dispose();
    super.onRemove();
  }
}
