/// Star Hunter: a top-down shooter in waves.
///
/// Enemies fly in from above to slots of a swaying formation, then take
/// turns diving at the player; the formation and divers fire aimed shots.
/// The player moves inside the lower half and fires while the fire button
/// is held. Each wave adds enemies, tougher types and a faster dive and
/// fire rate. A hit costs a life and grants two seconds of invulnerability.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class StarHunterConfig {
  const StarHunterConfig({this.level = ArcadeLevel.medium, this.seed = 0, this.lives = 3});

  final ArcadeLevel level;
  final int seed;
  final int lives;

  static const double width = 240;
  static const double height = 320;

  double get aggression => switch (level) {
    ArcadeLevel.easy => 0.6,
    ArcadeLevel.medium => 1.0,
    ArcadeLevel.hard => 1.5,
  };
}

final class ShooterInput {
  const ShooterInput({this.dx = 0, this.dy = 0, this.fire = false});
  static const ShooterInput none = ShooterInput();
  final double dx;
  final double dy;

  /// Held: fires at the weapon's rate.
  final bool fire;
}

enum EnemyType { scout, fighter, bomber }

enum EnemyPhase { entering, holding, diving }

final class Enemy {
  Enemy(this.type, this.slot, this.pos, this.hp);
  final EnemyType type;
  final Vec2 slot;
  Vec2 pos;
  int hp;
  EnemyPhase phase = EnemyPhase.entering;
  Vec2 vel = Vec2.zero;

  double get radius => switch (type) {
    EnemyType.scout => 7,
    EnemyType.fighter => 8,
    EnemyType.bomber => 10,
  };

  int get points => switch (type) {
    EnemyType.scout => 50,
    EnemyType.fighter => 80,
    EnemyType.bomber => 150,
  };
}

final class Shot {
  Shot(this.pos, this.vel);
  Vec2 pos;
  final Vec2 vel;
}

final class StarHunterState {
  Vec2 player = const Vec2(StarHunterConfig.width / 2, 290);
  final List<Enemy> enemies = [];
  final List<Shot> playerShots = [];
  final List<Shot> enemyShots = [];
  int lives = 3;
  int score = 0;
  int wave = 0;
  double cooldown = 0;
  double invulnerable = 0;
  double waveDelay = 0;
  double time = 0;
  bool over = false;
}

final class StarHunterSim extends FixedStepSim<StarHunterState, ShooterInput> {
  StarHunterSim(this.config) : rng = SeededRng(config.seed), super(hz: 60) {
    _s.lives = config.lives;
    _nextWave();
  }

  final StarHunterConfig config;
  final SeededRng rng;
  final StarHunterState _s = StarHunterState();

  static const double playerSpeed = 150;
  static const double playerRadius = 6;
  static const double fireInterval = 0.15;

  @override
  ArcadeKind get kind => ArcadeKind.starHunter;

  @override
  StarHunterState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  void _nextWave() {
    _s.wave++;
    final count = math.min(30, 8 + 2 * _s.wave);
    final cols = math.min(10, 4 + _s.wave);
    for (var i = 0; i < count; i++) {
      final row = i ~/ cols, col = i % cols;
      final type = row == 0 && _s.wave >= 2
          ? EnemyType.bomber
          : (row == 1 && _s.wave >= 2 ? EnemyType.fighter : (rng.nextInt(6) == 0 ? EnemyType.fighter : EnemyType.scout));
      final slot = Vec2(
        StarHunterConfig.width / 2 + (col - (cols - 1) / 2) * 20,
        40 + row * 22,
      );
      final start = Vec2(rng.nextDoubleRange(0, StarHunterConfig.width), -20.0 - i * 12);
      final hp = switch (type) {
        EnemyType.scout => 1,
        EnemyType.fighter => 2,
        EnemyType.bomber => 4,
      };
      _s.enemies.add(Enemy(type, slot, start, hp));
    }
  }

  /// The formation sways sideways.
  Vec2 _home(Enemy e) => e.slot + Vec2(math.sin(_s.time * 0.8) * 18, 0);

  @override
  void update(ShooterInput input) {
    final dt = tickSeconds;
    _s.time += dt;
    // Player.
    final mv = Vec2(input.dx.clamp(-1.0, 1.0), input.dy.clamp(-1.0, 1.0));
    final len = mv.length;
    final dir = len > 1 ? mv / len : mv;
    final p = _s.player + dir * (playerSpeed * dt);
    _s.player = Vec2(
      p.x.clamp(playerRadius, StarHunterConfig.width - playerRadius),
      p.y.clamp(StarHunterConfig.height / 2, StarHunterConfig.height - playerRadius),
    );
    _s.cooldown = math.max(0, _s.cooldown - dt);
    _s.invulnerable = math.max(0, _s.invulnerable - dt);
    if (input.fire && _s.cooldown == 0) {
      _s.playerShots.add(Shot(_s.player + const Vec2(0, -8), const Vec2(0, -360)));
      _s.cooldown = fireInterval;
    }
    // Enemies.
    final diveChance = 0.004 * config.aggression * (1 + 0.15 * _s.wave);
    final fireChance = 0.002 * config.aggression * (1 + 0.1 * _s.wave);
    for (final e in _s.enemies) {
      switch (e.phase) {
        case EnemyPhase.entering:
          final target = _home(e);
          final to = target - e.pos;
          final step = 120 * dt;
          if (to.length <= step) {
            e.pos = target;
            e.phase = EnemyPhase.holding;
          } else {
            e.pos = e.pos + to.normalized * step;
          }
        case EnemyPhase.holding:
          e.pos = _home(e);
          if (rng.nextDouble() < diveChance) {
            e.phase = EnemyPhase.diving;
            final aim = (_s.player - e.pos).normalized;
            e.vel = Vec2(aim.x * 70, 110 + 10.0 * _s.wave);
          }
        case EnemyPhase.diving:
          // Curve towards the player's column while falling.
          final steer = (_s.player.x - e.pos.x).clamp(-60.0, 60.0);
          e.vel = Vec2(e.vel.x + steer * dt * 2, e.vel.y);
          e.pos = e.pos + e.vel * dt;
          if (e.pos.y > StarHunterConfig.height + 20) {
            e.pos = Vec2(e.pos.x.clamp(0, StarHunterConfig.width), -20);
            e.phase = EnemyPhase.entering;
          }
      }
      if (e.phase != EnemyPhase.entering && rng.nextDouble() < fireChance) {
        final aim = (_s.player - e.pos).normalized;
        _s.enemyShots.add(Shot(e.pos, Vec2(aim.x * 60, 120 + 5.0 * _s.wave)));
      }
    }
    // Shots.
    for (final sh in _s.playerShots) {
      sh.pos = sh.pos + sh.vel * dt;
    }
    for (final sh in _s.enemyShots) {
      sh.pos = sh.pos + sh.vel * dt;
    }
    _s.playerShots.removeWhere((sh) => sh.pos.y < -10);
    _s.enemyShots.removeWhere((sh) => sh.pos.y > StarHunterConfig.height + 10 || sh.pos.x < -10 || sh.pos.x > StarHunterConfig.width + 10);
    // Player shots vs enemies (swept along the shot's path this tick).
    for (final sh in List<Shot>.from(_s.playerShots)) {
      final from = sh.pos - sh.vel * dt;
      for (final e in _s.enemies) {
        if (e.hp <= 0) continue;
        if (segmentHitsCircle(from, sh.pos, e.pos, e.radius + 2)) {
          e.hp--;
          _s.playerShots.remove(sh);
          if (e.hp <= 0) _s.score += e.points * (e.phase == EnemyPhase.diving ? 2 : 1);
          break;
        }
      }
    }
    _s.enemies.removeWhere((e) => e.hp <= 0);
    // Hits on the player.
    if (_s.invulnerable == 0) {
      final hitByShot = _s.enemyShots.any((sh) => circlesOverlap(sh.pos, 2, _s.player, playerRadius));
      final rammed = _s.enemies.where((e) => circlesOverlap(e.pos, e.radius, _s.player, playerRadius)).toList();
      if (hitByShot || rammed.isNotEmpty) {
        for (final e in rammed) {
          e.hp = 0;
        }
        _s.enemies.removeWhere((e) => e.hp <= 0);
        _s.enemyShots.clear();
        _s.lives--;
        _s.invulnerable = 2;
        if (_s.lives <= 0) {
          _s.over = true;
          return;
        }
      }
    }
    // Next wave.
    if (_s.enemies.isEmpty) {
      _s.waveDelay += dt;
      if (_s.waveDelay >= 1.5) {
        _s.waveDelay = 0;
        _s.score += 100 * _s.wave;
        _nextWave();
      }
    }
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'player': _s.player.toJson(),
    'enemies': [
      for (final e in _s.enemies) [e.type.index, e.phase.index, ...e.pos.toJson(), e.hp],
    ],
    'shots': [for (final s in _s.playerShots) s.pos.toJson()],
    'enemyShots': [for (final s in _s.enemyShots) s.pos.toJson()],
    'lives': _s.lives,
    'wave': _s.wave,
    'score': _s.score,
    'rng': rng.state,
  };
}
