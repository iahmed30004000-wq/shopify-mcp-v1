/// Fruit Slice: swipe through flying fruit, avoid bombs.
///
/// Fruit and bombs are tossed from below the screen on seeded ballistic
/// arcs. The blade is the polyline of pointer positions reported each frame;
/// every blade segment of a tick is tested against every object's circle
/// (segment-vs-circle, with the object's motion during the tick included so
/// fast objects are not missed). Three or more fruit in one continuous
/// swipe score a combo bonus. A fruit that falls back unsliced is a strike;
/// three strikes, or slicing a bomb, end the game.
library;

import 'dart:math' as math;

import '../core/arcade_sim.dart';
import '../core/geometry.dart';

final class FruitConfig {
  const FruitConfig({this.level = ArcadeLevel.medium, this.seed = 0});

  final ArcadeLevel level;
  final int seed;

  static const double width = 320;
  static const double height = 480;
  static const double gravity = 400;

  double get bombChance => switch (level) {
    ArcadeLevel.easy => 0.06,
    ArcadeLevel.medium => 0.12,
    ArcadeLevel.hard => 0.18,
  };

  double get waveInterval => switch (level) {
    ArcadeLevel.easy => 1.6,
    ArcadeLevel.medium => 1.3,
    ArcadeLevel.hard => 1.0,
  };
}

/// Blade points (screen coordinates) sampled since the previous frame. An
/// empty list means the pointer is up.
final class FruitInput {
  const FruitInput([this.blade = const []]);
  static const FruitInput none = FruitInput();
  final List<Vec2> blade;
}

final class FlyingObject {
  FlyingObject(this.id, this.pos, this.vel, this.bomb);
  final int id;
  Vec2 pos;
  Vec2 vel;
  final bool bomb;
  bool sliced = false;
  bool gone = false;

  double get radius => bomb ? 16 : 18;
}

final class FruitState {
  final List<FlyingObject> objects = [];
  int score = 0;
  int strikes = 0;
  int sliced = 0;
  int bestCombo = 0;
  double spawnTimer = 0.5;
  double time = 0;
  Vec2? lastBlade;
  int swipeCount = 0;
  bool bombHit = false;
  int nextId = 0;

  bool get over => bombHit || strikes >= 3;
}

final class FruitSliceSim extends FixedStepSim<FruitState, FruitInput> {
  FruitSliceSim(this.config) : rng = SeededRng(config.seed), super(hz: 60);

  final FruitConfig config;
  final SeededRng rng;
  final FruitState _s = FruitState();

  @override
  ArcadeKind get kind => ArcadeKind.fruitSlice;

  @override
  FruitState get state => _s;

  @override
  int get score => _s.score;

  @override
  bool get isOver => _s.over;

  /// Blade points are events: a later tick of the same frame gets none, but
  /// the blade stays down (its last point is kept) while points keep coming.
  @override
  FruitInput heldOnly(FruitInput input) =>
      input.blade.isEmpty ? input : FruitInput([input.blade.last]);

  @override
  FruitInput mergeInput(FruitInput earlier, FruitInput later) {
    if (later.blade.isEmpty && earlier.blade.isNotEmpty) return later;
    return FruitInput([...earlier.blade, ...later.blade]);
  }

  void _spawnWave() {
    final count = 1 + rng.nextInt(math.min(5, 2 + (_s.time ~/ 20)));
    for (var i = 0; i < count; i++) {
      final x = rng.nextDoubleRange(40, FruitConfig.width - 40);
      final apex = rng.nextDoubleRange(FruitConfig.height * 0.25, FruitConfig.height * 0.55);
      final rise = FruitConfig.height + 20 - apex;
      final vy = -math.sqrt(2 * FruitConfig.gravity * rise);
      final vx = (FruitConfig.width / 2 - x) * rng.nextDoubleRange(0.2, 0.6);
      _s.objects.add(
        FlyingObject(_s.nextId++, Vec2(x, FruitConfig.height + 20), Vec2(vx, vy), rng.nextDouble() < config.bombChance),
      );
    }
  }

  @override
  void update(FruitInput input) {
    final dt = tickSeconds;
    _s.time += dt;
    _s.spawnTimer -= dt;
    if (_s.spawnTimer <= 0) {
      _spawnWave();
      _s.spawnTimer = math.max(0.5, config.waveInterval - _s.time / 120);
    }
    final previous = {for (final o in _s.objects) o.id: o.pos};
    for (final o in _s.objects) {
      o.vel = Vec2(o.vel.x, o.vel.y + FruitConfig.gravity * dt);
      o.pos = o.pos + o.vel * dt;
    }
    // Blade segments this tick.
    final pts = <Vec2>[?_s.lastBlade, ...input.blade];
    if (input.blade.isEmpty) {
      _s.lastBlade = null;
      _endSwipe();
    } else {
      _s.lastBlade = input.blade.last;
    }
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i], b = pts[i + 1];
      for (final o in _s.objects) {
        if (o.sliced || o.gone) continue;
        // Test in the object's frame over the tick: the object moved from
        // `from` to `pos`; check both ends and the midpoint.
        final from = previous[o.id] ?? o.pos;
        final hit =
            segmentHitsCircle(a, b, o.pos, o.radius) ||
            segmentHitsCircle(a, b, from, o.radius) ||
            segmentHitsCircle(a, b, (from + o.pos) * 0.5, o.radius);
        if (!hit) continue;
        o.sliced = true;
        if (o.bomb) {
          _s.bombHit = true;
          return;
        }
        _s.sliced++;
        _s.score += 1;
        _s.swipeCount++;
      }
    }
    // Strikes for fruit falling back unsliced.
    for (final o in _s.objects) {
      if (o.gone) continue;
      if (o.pos.y > FruitConfig.height + 40 && o.vel.y > 0) {
        o.gone = true;
        if (!o.bomb && !o.sliced) _s.strikes++;
      }
      if (o.sliced) o.gone = true;
    }
    _s.objects.removeWhere((o) => o.gone);
  }

  void _endSwipe() {
    if (_s.swipeCount >= 3) _s.score += _s.swipeCount;
    if (_s.swipeCount > _s.bestCombo) _s.bestCombo = _s.swipeCount;
    _s.swipeCount = 0;
  }

  @override
  Map<String, Object?> snapshot() => {
    'tick': tick,
    'objects': [
      for (final o in _s.objects) [o.id, o.bomb, ...o.pos.toJson()],
    ],
    'score': _s.score,
    'strikes': _s.strikes,
    'rng': rng.state,
  };
}
