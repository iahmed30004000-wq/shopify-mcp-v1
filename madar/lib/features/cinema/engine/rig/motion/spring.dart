import 'dart:math' as math;

/// A damped spring on one value (semi-implicit Euler; call with small
/// steps – the rig sub-steps at ≤ 1/120 s).
final class Spring1 {
  Spring1([this.value = 0]);

  double value;
  double velocity = 0;

  void snap(double v) {
    value = v;
    velocity = 0;
  }

  /// [omega] = stiffness as angular frequency (rad/s), [zeta] = damping
  /// ratio (< 1 overshoots: the rubber wobble).
  void step(double dt, double target, double omega, double zeta) {
    final a = omega * omega * (target - value) - 2 * zeta * omega * velocity;
    velocity += a * dt;
    value += velocity * dt;
  }

  void kick(double dv) => velocity += dv;
}

/// A damped spring on a 2D point.
final class Spring2 {
  Spring2([this.x = 0, this.y = 0]);

  double x, y;
  double vx = 0, vy = 0;

  void snap(double nx, double ny) {
    x = nx;
    y = ny;
    vx = 0;
    vy = 0;
  }

  void step(double dt, double tx, double ty, double omega, double zeta) {
    final w2 = omega * omega, c = 2 * zeta * omega;
    vx += (w2 * (tx - x) - c * vx) * dt;
    vy += (w2 * (ty - y) - c * vy) * dt;
    x += vx * dt;
    y += vy * dt;
  }

  void kick(double dvx, double dvy) {
    vx += dvx;
    vy += dvy;
  }
}

/// Timing curves of the 1930s "bounce".
abstract final class Bounce {
  /// A bouncing ball: 0 at every contact (integer [t]), 1 at the apex; fast
  /// through the bottom, hangs at the top.
  static double hop(double t) => math.sin((t - t.floorToDouble()) * math.pi).abs();

  /// Contact squash pulse: 1 right at each integer [t], quickly back to 0.
  static double contact(double t) {
    final f = t - t.floorToDouble();
    final d = math.min(f, 1 - f) * 2; // 0 at contact, 1 mid-beat
    final k = 1 - d;
    return k * k * k * k;
  }

  /// Smoothstep.
  static double smooth(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Ease out with a little overshoot (anticipation's release).
  static double backOut(double t, [double s = 1.8]) {
    final c = t.clamp(0.0, 1.0) - 1;
    return c * c * ((s + 1) * c + s) + 1;
  }

  /// Ease out.
  static double out(double t) {
    final c = 1 - t.clamp(0.0, 1.0);
    return 1 - c * c * c;
  }

  /// Ease in.
  static double inn(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c;
  }

  /// Linear map of [t] from [a, b] to [0, 1], clamped.
  static double span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  static double lerp(double a, double b, double t) => a + (b - a) * t;
}
