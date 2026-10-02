import 'dart:math' as math;
import 'dart:typed_data';

/// Sprites of the procedural atlas (see `ParticleAtlas`).
enum ParticleSprite {
  /// Soft gaussian glow.
  glow,

  /// Four-pointed star with a hot core.
  sparkle,

  /// A thin streak of light (head at the bottom, tail at the top).
  streak,

  /// A small, hot, tightly falling-off ember.
  ember,
}

/// How a particle moves.
abstract final class ParticleMotion {
  /// Position/velocity integration with gravity and drag.
  static const int ballistic = 0;

  /// Polar motion around a centre (`x`, `y`): `angle` advances by `spin`,
  /// `radius` by `radialVelocity`.
  static const int orbital = 1;
}

/// A fixed-capacity, allocation-free particle store (structure of arrays).
///
/// Live particles are always packed into `[0, count)`: a dying particle is
/// replaced by the last live one, so iteration never touches dead slots and
/// spawning never allocates. When full, [obtain] returns -1 (the effect is
/// simply a little sparser) – the pool never grows past [capacity].
class ParticlePool {
  ParticlePool(this.capacity)
    : assert(capacity > 0),
      x = Float32List(capacity),
      y = Float32List(capacity),
      vx = Float32List(capacity),
      vy = Float32List(capacity),
      ax = Float32List(capacity),
      ay = Float32List(capacity),
      drag = Float32List(capacity),
      age = Float32List(capacity),
      life = Float32List(capacity),
      size0 = Float32List(capacity),
      size1 = Float32List(capacity),
      rotation = Float32List(capacity),
      spin = Float32List(capacity),
      alpha = Float32List(capacity),
      fadeIn = Float32List(capacity),
      fadeOut = Float32List(capacity),
      swayAmp = Float32List(capacity),
      swayFreq = Float32List(capacity),
      phase = Float32List(capacity),
      flicker = Float32List(capacity),
      radius = Float32List(capacity),
      radialVelocity = Float32List(capacity),
      color = Uint32List(capacity),
      sprite = Uint8List(capacity),
      motion = Uint8List(capacity),
      alignToVelocity = Uint8List(capacity);

  final int capacity;

  final Float32List x, y, vx, vy, ax, ay, drag;
  final Float32List age, life;

  /// Rendered diameter (px) at birth and at death.
  final Float32List size0, size1;
  final Float32List rotation, spin;

  /// Peak opacity; fade-in fraction of life; fraction of life at which the
  /// fade-out starts.
  final Float32List alpha, fadeIn, fadeOut;

  /// Horizontal sway (render-time offset `swayAmp·sin(phase + swayFreq·age)`).
  final Float32List swayAmp, swayFreq, phase;

  /// Opacity flicker depth (0..1), for embers.
  final Float32List flicker;

  /// Orbital motion.
  final Float32List radius, radialVelocity;

  /// Non-premultiplied ARGB.
  final Uint32List color;
  final Uint8List sprite, motion, alignToVelocity;

  int _count = 0;

  int get count => _count;
  bool get isEmpty => _count == 0;
  bool get isFull => _count >= capacity;

  /// Claims a slot with neutral defaults and returns its index, or -1 when
  /// the pool is full.
  int obtain() {
    if (_count >= capacity) return -1;
    final i = _count++;
    x[i] = 0;
    y[i] = 0;
    vx[i] = 0;
    vy[i] = 0;
    ax[i] = 0;
    ay[i] = 0;
    drag[i] = 0;
    age[i] = 0;
    life[i] = 1;
    size0[i] = 8;
    size1[i] = 0;
    rotation[i] = 0;
    spin[i] = 0;
    alpha[i] = 1;
    fadeIn[i] = 0.08;
    fadeOut[i] = 0.4;
    swayAmp[i] = 0;
    swayFreq[i] = 0;
    phase[i] = 0;
    flicker[i] = 0;
    radius[i] = 0;
    radialVelocity[i] = 0;
    color[i] = 0xFFFFFFFF;
    sprite[i] = ParticleSprite.glow.index;
    motion[i] = ParticleMotion.ballistic;
    alignToVelocity[i] = 0;
    return i;
  }

  /// Advances every particle by [dt] seconds and recycles the dead.
  void update(double dt) {
    if (dt <= 0) return;
    var i = 0;
    while (i < _count) {
      final a = age[i] + dt;
      if (a >= life[i]) {
        _kill(i);
        continue;
      }
      age[i] = a;
      final d = drag[i];
      final damp = d > 0 ? 1 / (1 + d * dt) : 1.0;
      if (motion[i] == ParticleMotion.orbital) {
        rotation[i] += spin[i] * dt;
        final rv = radialVelocity[i] * damp;
        radialVelocity[i] = rv;
        radius[i] = math.max(0, radius[i] + rv * dt);
      } else {
        final nvx = (vx[i] + ax[i] * dt) * damp;
        final nvy = (vy[i] + ay[i] * dt) * damp;
        vx[i] = nvx;
        vy[i] = nvy;
        x[i] += nvx * dt;
        y[i] += nvy * dt;
        rotation[i] += spin[i] * dt;
      }
      i++;
    }
  }

  /// Removes every particle.
  void clear() => _count = 0;

  void _kill(int i) {
    final last = --_count;
    if (i == last) return;
    x[i] = x[last];
    y[i] = y[last];
    vx[i] = vx[last];
    vy[i] = vy[last];
    ax[i] = ax[last];
    ay[i] = ay[last];
    drag[i] = drag[last];
    age[i] = age[last];
    life[i] = life[last];
    size0[i] = size0[last];
    size1[i] = size1[last];
    rotation[i] = rotation[last];
    spin[i] = spin[last];
    alpha[i] = alpha[last];
    fadeIn[i] = fadeIn[last];
    fadeOut[i] = fadeOut[last];
    swayAmp[i] = swayAmp[last];
    swayFreq[i] = swayFreq[last];
    phase[i] = phase[last];
    flicker[i] = flicker[last];
    radius[i] = radius[last];
    radialVelocity[i] = radialVelocity[last];
    color[i] = color[last];
    sprite[i] = sprite[last];
    motion[i] = motion[last];
    alignToVelocity[i] = alignToVelocity[last];
  }

  /// Opacity envelope of particle [i] (0..1) – fade in, hold, fade out, with
  /// optional flicker.
  double envelope(int i) {
    final t = age[i] / life[i];
    final fi = fadeIn[i];
    var e = fi > 0 ? math.min(1.0, t / fi) : 1.0;
    final fo = fadeOut[i];
    if (t > fo) {
      final k = ((t - fo) / (1 - fo)).clamp(0.0, 1.0);
      e *= 1 - k * k * (3 - 2 * k);
    }
    final f = flicker[i];
    if (f > 0) e *= 1 - f * (0.5 + 0.5 * math.sin(phase[i] * 3.1 + age[i] * 17.0));
    return e * alpha[i];
  }

  /// Current rendered diameter of particle [i].
  double sizeOf(int i) {
    final t = age[i] / life[i];
    // Ease-out so sparks keep their bloom, then shrink.
    final k = 1 - (1 - t) * (1 - t);
    return size0[i] + (size1[i] - size0[i]) * k;
  }

  /// Render position of particle [i].
  (double, double) positionOf(int i) {
    if (motion[i] == ParticleMotion.orbital) {
      final a = rotation[i];
      final r = radius[i];
      return (x[i] + math.cos(a) * r, y[i] + math.sin(a) * r);
    }
    final amp = swayAmp[i];
    if (amp == 0) return (x[i], y[i]);
    return (x[i] + amp * math.sin(phase[i] + swayFreq[i] * age[i]), y[i]);
  }
}
