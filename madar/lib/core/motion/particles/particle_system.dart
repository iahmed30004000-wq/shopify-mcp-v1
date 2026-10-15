import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/foundation.dart';

import 'particle_pool.dart';

/// Sprite rectangles in an atlas image (implemented by `ParticleAtlas`).
abstract interface class SpriteRects {
  double left(int sprite);
  double top(int sprite);
  double right(int sprite);
  double bottom(int sprite);
  double spriteWidth(int sprite);
  double spriteHeight(int sprite);
}

/// The colours of one effect: a dominant hue, a supporting metal and a
/// white-hot core. Built from theme tokens (see `Celebrate`).
@immutable
class ParticlePalette {
  const ParticlePalette({required this.primary, required this.secondary, required this.hot});

  final Color primary;
  final Color secondary;
  final Color hot;

  /// Weighted pick: ~60 % primary, ~20 % hot, ~20 % secondary.
  int pick(double r) {
    if (r < 0.6) return primary.toARGB32();
    if (r < 0.8) return hot.toARGB32();
    return secondary.toARGB32();
  }
}

/// A continuous source of particles. [emit] is called every frame and returns
/// `false` once finished; [stop] asks it to finish (live particles fade out
/// naturally).
abstract class ParticleEmitter {
  bool _stopped = false;

  bool get isStopped => _stopped;

  /// Still emitting (not stopped, not run out).
  bool get isActive => !_stopped;

  void stop() => _stopped = true;

  bool emit(ParticleSystem system, double dt);
}

/// Rate-and-duration emitter base: spawns [rate] particles per second for
/// [duration] seconds (or until stopped; a `null` duration runs until
/// [stop]).
abstract class RateEmitter extends ParticleEmitter {
  RateEmitter({required this.rate, this.duration});

  final double rate;
  final double? duration;
  double _elapsed = 0;
  double _carry = 0;

  @override
  bool get isActive => !isStopped && (duration == null || _elapsed < duration!);

  /// 0..1 progress through [duration] (0 when open-ended).
  double get progress => duration == null ? 0 : (_elapsed / duration!).clamp(0.0, 1.0);

  @override
  bool emit(ParticleSystem system, double dt) {
    if (isStopped) return false;
    final d = duration;
    if (d != null && _elapsed >= d) return false;
    _elapsed += dt;
    _carry += rate * dt * envelope;
    while (_carry >= 1) {
      _carry -= 1;
      spawnOne(system);
    }
    return true;
  }

  /// Emission-rate multiplier over the effect's life (soft start and end).
  double get envelope {
    final d = duration;
    if (d == null) return math.min(1.0, _elapsed / 0.4);
    final t = _elapsed / d;
    return math.min(1.0, t / 0.12) * ((1 - t) / 0.25).clamp(0.0, 1.0);
  }

  void spawnOne(ParticleSystem system);

  /// Spawns [count] particles at once, each pre-aged by up to [spread] of
  /// its life so a burst starts already in motion.
  void prime(ParticleSystem system, int count, {double spread = 0}) {
    final pool = system.pool;
    for (var n = 0; n < count; n++) {
      final before = pool.count;
      spawnOne(system);
      if (pool.count == before) return;
      if (spread <= 0) continue;
      final i = before;
      final a = system.rng.nextDouble() * spread * pool.life[i];
      pool
        ..age[i] = a
        ..x[i] += pool.vx[i] * a
        ..y[i] += pool.vy[i] * a;
    }
  }
}

/// Allocation-free particle simulation: a [ParticlePool], active emitters, a
/// handful of soft flashes, and pre-allocated render buffers for
/// `Canvas.drawRawAtlas`. Notifies listeners after every [step].
class ParticleSystem extends ChangeNotifier {
  ParticleSystem({int capacity = 720, int? seed})
    : pool = ParticlePool(capacity),
      rng = math.Random(seed),
      _xf = Float32List((capacity + flashCapacity) * 4),
      _rects = Float32List((capacity + flashCapacity) * 4),
      _colors = Int32List(capacity + flashCapacity);

  static const int flashCapacity = 6;

  final ParticlePool pool;
  final math.Random rng;
  final List<ParticleEmitter> _emitters = [];

  final Float32List _fx = Float32List(flashCapacity);
  final Float32List _fy = Float32List(flashCapacity);
  final Float32List _fAge = Float32List(flashCapacity);
  final Float32List _fLife = Float32List(flashCapacity);
  final Float32List _fRadius = Float32List(flashCapacity);
  final Float32List _fGrow = Float32List(flashCapacity);
  final Uint32List _fColor = Uint32List(flashCapacity);
  int _flashCount = 0;

  final Float32List _xf;
  final Float32List _rects;
  final Int32List _colors;
  int _viewCount = -1;
  Float32List _xfView = Float32List(0);
  Float32List _rectView = Float32List(0);
  Int32List _colorView = Int32List(0);

  int get capacity => pool.capacity;
  int get emitterCount => _emitters.length;
  int get flashCount => _flashCount;

  /// Nothing alive, nothing emitting: the ticker may sleep.
  bool get isIdle => pool.isEmpty && _emitters.isEmpty && _flashCount == 0;

  void addEmitter(ParticleEmitter emitter) => _emitters.add(emitter);

  /// A soft, motionless bloom of light (also the reduced-motion celebration).
  /// [grow] = 0 keeps the size constant.
  void flash(double x, double y, Color color, {double radius = 80, double duration = 0.45, double grow = 0.25}) {
    var i = _flashCount;
    if (i >= flashCapacity) {
      // Replace the oldest.
      var oldest = 0;
      for (var k = 1; k < _flashCount; k++) {
        if (_fAge[k] / _fLife[k] > _fAge[oldest] / _fLife[oldest]) oldest = k;
      }
      i = oldest;
    } else {
      _flashCount++;
    }
    _fx[i] = x;
    _fy[i] = y;
    _fAge[i] = 0;
    _fLife[i] = duration;
    _fRadius[i] = radius;
    _fGrow[i] = grow;
    _fColor[i] = color.toARGB32();
  }

  /// Stops every emitter and removes every particle and flash.
  void clear() {
    for (final e in _emitters) {
      e.stop();
    }
    _emitters.clear();
    pool.clear();
    _flashCount = 0;
    notifyListeners();
  }

  /// Advances the simulation by [dt] seconds.
  void step(double dt) {
    if (dt > 0) {
      for (var i = _emitters.length - 1; i >= 0; i--) {
        if (!_emitters[i].emit(this, dt)) _emitters.removeAt(i);
      }
      pool.update(dt);
      var i = 0;
      while (i < _flashCount) {
        final a = _fAge[i] + dt;
        if (a >= _fLife[i]) {
          final last = --_flashCount;
          _fx[i] = _fx[last];
          _fy[i] = _fy[last];
          _fAge[i] = _fAge[last];
          _fLife[i] = _fLife[last];
          _fRadius[i] = _fRadius[last];
          _fGrow[i] = _fGrow[last];
          _fColor[i] = _fColor[last];
          continue;
        }
        _fAge[i] = a;
        i++;
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Rendering.
  // ---------------------------------------------------------------------------

  Float32List get transforms => _xfView;
  Float32List get rects => _rectView;
  Int32List get colors => _colorView;

  /// Fills the render buffers for `drawRawAtlas` and returns the sprite
  /// count; afterwards [transforms], [rects] and [colors] hold exactly that
  /// many entries.
  int prepareRender(SpriteRects atlas) {
    final p = pool;
    final xf = _xf;
    final rects = _rects;
    final colors = _colors;
    var n = 0;
    for (var i = 0; i < p.count; i++) {
      final env = p.envelope(i);
      if (env <= 0.004) continue;
      final size = p.sizeOf(i);
      if (size <= 0.2) continue;
      final spr = p.sprite[i];
      final sw = atlas.spriteWidth(spr);
      final sh = atlas.spriteHeight(spr);
      final scale = spr == _streak ? size / sh : size / sw;

      double px;
      double py;
      var rot = p.rotation[i];
      if (p.motion[i] == ParticleMotion.orbital) {
        final r = p.radius[i];
        px = p.x[i] + math.cos(rot) * r;
        py = p.y[i] + math.sin(rot) * r;
      } else {
        px = p.x[i];
        py = p.y[i];
        final amp = p.swayAmp[i];
        if (amp != 0) px += amp * math.sin(p.phase[i] + p.swayFreq[i] * p.age[i]);
      }
      if (p.alignToVelocity[i] != 0) rot = math.atan2(-p.vx[i], p.vy[i]);

      final scos = scale * math.cos(rot);
      final ssin = scale * math.sin(rot);
      final ax = sw / 2;
      final ay = sh / 2;
      final o = n * 4;
      xf[o] = scos;
      xf[o + 1] = ssin;
      xf[o + 2] = px - scos * ax + ssin * ay;
      xf[o + 3] = py - ssin * ax - scos * ay;
      rects[o] = atlas.left(spr);
      rects[o + 1] = atlas.top(spr);
      rects[o + 2] = atlas.right(spr);
      rects[o + 3] = atlas.bottom(spr);
      final c = p.color[i];
      final a = ((c >>> 24) * env).round().clamp(0, 255);
      colors[n] = (a << 24) | (c & 0x00FFFFFF);
      n++;
    }
    // Flashes: big soft glows, drawn last (on top).
    final gw = atlas.spriteWidth(_glow);
    for (var f = 0; f < _flashCount; f++) {
      final t = _fAge[f] / _fLife[f];
      final rise = math.min(1.0, t / 0.14);
      final env = rise * (1 - t) * (1 - t);
      if (env <= 0.004) continue;
      final size = _fRadius[f] * 2 * (1 + _fGrow[f] * t);
      final scale = size / gw;
      final o = n * 4;
      final half = gw / 2;
      xf[o] = scale;
      xf[o + 1] = 0;
      xf[o + 2] = _fx[f] - scale * half;
      xf[o + 3] = _fy[f] - scale * half;
      rects[o] = atlas.left(_glow);
      rects[o + 1] = atlas.top(_glow);
      rects[o + 2] = atlas.right(_glow);
      rects[o + 3] = atlas.bottom(_glow);
      final c = _fColor[f];
      final a = ((c >>> 24) * env * 0.85).round().clamp(0, 255);
      colors[n] = (a << 24) | (c & 0x00FFFFFF);
      n++;
    }
    if (n != _viewCount) {
      _viewCount = n;
      _xfView = Float32List.sublistView(xf, 0, n * 4);
      _rectView = Float32List.sublistView(rects, 0, n * 4);
      _colorView = Int32List.sublistView(colors, 0, n);
    }
    return n;
  }

  static final int _streak = ParticleSprite.streak.index;
  static final int _glow = ParticleSprite.glow.index;
}

/// Effect recipes. Every preset only writes into the pool (no allocation per
/// particle); continuous ones return an emitter that was already added to the
/// system.
abstract final class ParticlePresets {
  static double _r(math.Random rng, double a, double b) => a + rng.nextDouble() * (b - a);

  /// Radial golden sparks with gravity and fade, a lingering glitter and an
  /// expanding astrolabe ring – for completions.
  static void stardustBurst(ParticleSystem sys, double x, double y, ParticlePalette palette, {double intensity = 1}) {
    final pool = sys.pool;
    final rng = sys.rng;
    final k = intensity.clamp(0.2, 3.0);
    final speedK = math.sqrt(k);
    sys.flash(x, y, palette.hot, radius: 72 * speedK, duration: 0.4);

    final sparks = (46 * k).round();
    for (var n = 0; n < sparks; n++) {
      final i = pool.obtain();
      if (i < 0) return;
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = (180 + math.pow(rng.nextDouble(), 0.7) * 520) * speedK;
      final sparkle = rng.nextDouble() < 0.35;
      pool
        ..x[i] = x
        ..y[i] = y
        ..vx[i] = math.cos(angle) * speed
        ..vy[i] = math.sin(angle) * speed - 70
        ..ay[i] = 430
        ..drag[i] = 2.5
        ..life[i] = _r(rng, 0.7, 1.4)
        ..size0[i] = sparkle ? _r(rng, 26, 44) : _r(rng, 14, 26)
        ..size1[i] = 1.5
        ..spin[i] = _r(rng, -5, 5)
        ..rotation[i] = rng.nextDouble() * math.pi
        ..alpha[i] = _r(rng, 0.85, 1)
        ..fadeIn[i] = 0.03
        ..fadeOut[i] = _r(rng, 0.3, 0.55)
        ..color[i] = palette.pick(rng.nextDouble())
        ..sprite[i] = (sparkle ? ParticleSprite.sparkle : ParticleSprite.glow).index;
    }

    final glitter = (26 * k).round();
    for (var n = 0; n < glitter; n++) {
      final i = pool.obtain();
      if (i < 0) return;
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = _r(rng, 30, 140) * speedK;
      pool
        ..x[i] = x
        ..y[i] = y
        ..vx[i] = math.cos(angle) * speed
        ..vy[i] = math.sin(angle) * speed - 30
        ..ay[i] = 70
        ..drag[i] = 1.3
        ..life[i] = _r(rng, 1.2, 2.1)
        ..size0[i] = _r(rng, 7, 12)
        ..size1[i] = 2
        ..alpha[i] = _r(rng, 0.45, 0.8)
        ..fadeIn[i] = 0.1
        ..fadeOut[i] = 0.45
        ..swayAmp[i] = _r(rng, 2, 7)
        ..swayFreq[i] = _r(rng, 3, 6)
        ..phase[i] = rng.nextDouble() * math.pi * 2
        ..flicker[i] = 0.45
        ..color[i] = palette.pick(rng.nextDouble() * 0.8)
        ..sprite[i] = ParticleSprite.glow.index;
    }

    // Shock ring: sparkles racing out on a circle and braking.
    final ring = (16 * math.min(k, 1.5)).round();
    final ringRadius = 64 * speedK;
    for (var n = 0; n < ring; n++) {
      final i = pool.obtain();
      if (i < 0) return;
      const drag = 5.0;
      pool
        ..motion[i] = ParticleMotion.orbital
        ..x[i] = x
        ..y[i] = y
        ..rotation[i] = n / ring * math.pi * 2
        ..spin[i] = 0.9
        ..radius[i] = 4
        ..radialVelocity[i] = ringRadius * drag
        ..drag[i] = drag
        ..life[i] = 0.55
        ..size0[i] = 20
        ..size1[i] = 5
        ..fadeIn[i] = 0.05
        ..fadeOut[i] = 0.35
        ..alpha[i] = 0.75
        ..color[i] = palette.hot.toARGB32()
        ..sprite[i] = ParticleSprite.sparkle.index;
    }
  }

  /// Warm embers rising and swaying from a small source around ([x], [y]).
  static ParticleEmitter lanternSparksBurst(
    ParticleSystem sys,
    double x,
    double y,
    ParticlePalette palette, {
    double intensity = 1,
  }) {
    final k = intensity.clamp(0.2, 3.0);
    sys.flash(x, y, palette.primary, radius: 52, duration: 0.6);
    final e = LanternSparksEmitter(
      area: Rect.fromCenter(center: Offset(x, y), width: 36, height: 10),
      palette: palette,
      rate: 60 * k,
      duration: 0.9,
      travel: 220 * math.sqrt(k),
      spread: 40,
    )..prime(sys, (10 * k).round(), spread: 0.08);
    sys.addEmitter(e);
    return e;
  }

  /// A short shower of light streaks falling through ([x], [y]).
  static ParticleEmitter lightRainBurst(
    ParticleSystem sys,
    double x,
    double y,
    ParticlePalette palette, {
    double intensity = 1,
  }) {
    final k = intensity.clamp(0.2, 3.0);
    final e = LightRainEmitter(
      area: Rect.fromLTRB(x - 130, y - 240, x + 130, y + 120),
      palette: palette,
      rate: 90 * k,
      duration: 0.8,
    )..prime(sys, (12 * k).round(), spread: 0.45);
    sys.addEmitter(e);
    sys.flash(x, y, palette.hot, radius: 40, duration: 0.9, grow: 0.6);
    return e;
  }

  /// Sparkles igniting along a ring of [radius] around ([x], [y]) and
  /// turning like an astrolabe rete.
  static void orbitalRingBurst(
    ParticleSystem sys,
    double x,
    double y,
    double radius,
    ParticlePalette palette, {
    double intensity = 1,
  }) {
    final pool = sys.pool;
    final rng = sys.rng;
    final k = intensity.clamp(0.2, 3.0);
    sys.flash(x, y, palette.primary, radius: radius * 0.95, duration: 0.7, grow: 0.15);
    final count = (48 * k).round();
    for (var n = 0; n < count; n++) {
      final i = pool.obtain();
      if (i < 0) return;
      final sparkle = n.isEven;
      final r0 = radius * _r(rng, 0.62, 0.78);
      const drag = 4.0;
      pool
        ..motion[i] = ParticleMotion.orbital
        ..x[i] = x
        ..y[i] = y
        ..rotation[i] = (n + rng.nextDouble() * 0.6) / count * math.pi * 2
        ..spin[i] = _r(rng, 0.9, 1.5)
        ..radius[i] = r0
        ..radialVelocity[i] = (radius * _r(rng, 0.98, 1.06) - r0) * drag
        ..drag[i] = drag
        ..life[i] = _r(rng, 1.0, 1.7)
        ..size0[i] = sparkle ? _r(rng, 22, 36) : _r(rng, 10, 18)
        ..size1[i] = sparkle ? 6 : 3
        ..fadeIn[i] = _r(rng, 0.04, 0.2)
        ..fadeOut[i] = 0.5
        ..alpha[i] = _r(rng, 0.75, 1)
        ..color[i] = palette.pick(rng.nextDouble())
        ..sprite[i] = (sparkle ? ParticleSprite.sparkle : ParticleSprite.glow).index;
    }
    // A continuous luminous band: many small, soft glows evenly on the ring.
    final band = (radius * 0.9).clamp(24, 96).round();
    for (var n = 0; n < band; n++) {
      final i = pool.obtain();
      if (i < 0) return;
      const drag = 4.0;
      final r0 = radius * 0.7;
      pool
        ..motion[i] = ParticleMotion.orbital
        ..x[i] = x
        ..y[i] = y
        ..rotation[i] = n / band * math.pi * 2
        ..spin[i] = 1.1
        ..radius[i] = r0
        ..radialVelocity[i] = (radius - r0) * drag
        ..drag[i] = drag
        ..life[i] = _r(rng, 0.9, 1.2)
        ..size0[i] = 14
        ..size1[i] = 8
        ..fadeIn[i] = 0.08
        ..fadeOut[i] = 0.35
        ..alpha[i] = 0.38
        ..color[i] = palette.primary.toARGB32()
        ..sprite[i] = ParticleSprite.glow.index;
    }
  }
}

/// Embers rising from the bottom band of [area], swaying and flickering,
/// slowly cooling (decelerating) as they climb about [travel] pixels.
class LanternSparksEmitter extends RateEmitter {
  LanternSparksEmitter({
    required this.area,
    required this.palette,
    super.rate = 26,
    super.duration,
    this.travel = 320,
    this.spread = 18,
  });

  final Rect area;
  final ParticlePalette palette;

  /// Typical rise height in pixels.
  final double travel;

  /// Sideways drift speed range (± px/s).
  final double spread;

  @override
  void spawnOne(ParticleSystem system) {
    final pool = system.pool;
    final rng = system.rng;
    final i = pool.obtain();
    if (i < 0) return;
    final bokeh = rng.nextDouble() < 0.18;
    final life = ParticlePresets._r(rng, 2.0, 3.8);
    // Start fast and cool down: v0 = 2·d/T with a matching deceleration
    // covers d in T.
    final distance = travel * ParticlePresets._r(rng, 0.55, 1.1);
    final v0 = 2 * distance / life;
    pool
      ..x[i] = area.left + rng.nextDouble() * area.width
      ..y[i] = area.bottom - rng.nextDouble() * area.height
      ..vx[i] = ParticlePresets._r(rng, -spread, spread)
      ..vy[i] = -v0
      ..ay[i] = v0 / life * 0.85
      ..drag[i] = 0.15
      ..life[i] = life
      ..size0[i] = bokeh ? ParticlePresets._r(rng, 34, 64) : ParticlePresets._r(rng, 13, 26)
      ..size1[i] = bokeh ? 24 : 4
      ..alpha[i] = bokeh ? ParticlePresets._r(rng, 0.16, 0.3) : ParticlePresets._r(rng, 0.75, 1)
      ..fadeIn[i] = 0.1
      ..fadeOut[i] = 0.5
      ..swayAmp[i] = ParticlePresets._r(rng, 6, 24)
      ..swayFreq[i] = ParticlePresets._r(rng, 1.1, 2.6)
      ..phase[i] = rng.nextDouble() * math.pi * 2
      ..flicker[i] = bokeh ? 0.1 : ParticlePresets._r(rng, 0.3, 0.6)
      ..color[i] = palette.pick(rng.nextDouble())
      ..sprite[i] = (bokeh ? ParticleSprite.glow : ParticleSprite.ember).index;
  }
}

/// Thin streaks of light falling across [area] with a slight slant.
class LightRainEmitter extends RateEmitter {
  LightRainEmitter({required this.area, required this.palette, super.rate = 40, super.duration, this.slant = 0.12});

  final Rect area;
  final ParticlePalette palette;

  /// Horizontal drift as a fraction of the fall speed.
  final double slant;

  @override
  void spawnOne(ParticleSystem system) {
    final pool = system.pool;
    final rng = system.rng;
    final i = pool.obtain();
    if (i < 0) return;
    final speed = ParticlePresets._r(rng, 720, 1150);
    final length = ParticlePresets._r(rng, 40, 92);
    final top = area.top - length;
    final fall = area.height + length * 2;
    final drift = speed * slant;
    final startX = area.left - drift * (fall / speed) * 0.5 + rng.nextDouble() * area.width;
    pool
      ..x[i] = startX
      ..y[i] = top
      ..vx[i] = drift
      ..vy[i] = speed
      ..life[i] = fall / speed
      ..size0[i] = length
      ..size1[i] = length * 0.8
      ..alpha[i] = ParticlePresets._r(rng, 0.3, 0.75)
      ..fadeIn[i] = 0.12
      ..fadeOut[i] = 0.72
      ..color[i] = palette.pick(rng.nextDouble())
      ..alignToVelocity[i] = 1
      ..sprite[i] = ParticleSprite.streak.index;
  }
}

/// A continuously shimmering ring of sparkles turning around a centre.
class OrbitalRingEmitter extends RateEmitter {
  OrbitalRingEmitter({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.palette,
    super.rate = 26,
    super.duration,
  });

  final double cx;
  final double cy;
  final double radius;
  final ParticlePalette palette;

  @override
  void spawnOne(ParticleSystem system) {
    final pool = system.pool;
    final rng = system.rng;
    final i = pool.obtain();
    if (i < 0) return;
    // A third are sparkles; the rest are soft glows that overlap into a
    // continuous luminous band.
    final sparkle = rng.nextDouble() < 0.34;
    pool
      ..motion[i] = ParticleMotion.orbital
      ..x[i] = cx
      ..y[i] = cy
      ..rotation[i] = rng.nextDouble() * math.pi * 2
      ..spin[i] = ParticlePresets._r(rng, 0.6, 1.0)
      ..radius[i] = radius + (sparkle ? ParticlePresets._r(rng, -5, 5) : ParticlePresets._r(rng, -1.5, 1.5))
      ..radialVelocity[i] = sparkle ? ParticlePresets._r(rng, -3, 6) : 0
      ..life[i] = ParticlePresets._r(rng, 1.2, 2.2)
      ..size0[i] = sparkle ? ParticlePresets._r(rng, 18, 30) : ParticlePresets._r(rng, 16, 26)
      ..size1[i] = sparkle ? 6 : 12
      ..fadeIn[i] = 0.25
      ..fadeOut[i] = 0.55
      ..alpha[i] = sparkle ? ParticlePresets._r(rng, 0.6, 1) : ParticlePresets._r(rng, 0.25, 0.4)
      ..flicker[i] = sparkle ? 0.2 : 0.15
      ..phase[i] = rng.nextDouble() * math.pi * 2
      ..color[i] = sparkle ? palette.pick(rng.nextDouble()) : palette.primary.toARGB32()
      ..sprite[i] = (sparkle ? ParticleSprite.sparkle : ParticleSprite.glow).index;
  }
}

/// Slow, twinkling motes of stardust drifting upward across [area].
class StardustDriftEmitter extends RateEmitter {
  StardustDriftEmitter({required this.area, required this.palette, super.rate = 14, super.duration});

  final Rect area;
  final ParticlePalette palette;

  @override
  void spawnOne(ParticleSystem system) {
    final pool = system.pool;
    final rng = system.rng;
    final i = pool.obtain();
    if (i < 0) return;
    final sparkle = rng.nextDouble() < 0.3;
    pool
      ..x[i] = area.left + rng.nextDouble() * area.width
      ..y[i] = area.top + rng.nextDouble() * area.height
      ..vx[i] = ParticlePresets._r(rng, -6, 6)
      ..vy[i] = ParticlePresets._r(rng, -22, -8)
      ..life[i] = ParticlePresets._r(rng, 2, 4)
      ..size0[i] = sparkle ? ParticlePresets._r(rng, 16, 26) : ParticlePresets._r(rng, 7, 13)
      ..size1[i] = sparkle ? 8 : 4
      ..fadeIn[i] = 0.3
      ..fadeOut[i] = 0.55
      ..alpha[i] = ParticlePresets._r(rng, 0.45, 0.9)
      ..swayAmp[i] = ParticlePresets._r(rng, 2, 8)
      ..swayFreq[i] = ParticlePresets._r(rng, 0.8, 1.8)
      ..phase[i] = rng.nextDouble() * math.pi * 2
      ..flicker[i] = 0.35
      ..spin[i] = ParticlePresets._r(rng, -0.6, 0.6)
      ..color[i] = palette.pick(rng.nextDouble())
      ..sprite[i] = (sparkle ? ParticleSprite.sparkle : ParticleSprite.glow).index;
  }
}
