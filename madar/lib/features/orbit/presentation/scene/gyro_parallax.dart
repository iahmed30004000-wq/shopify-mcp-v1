import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Gyroscope parallax (pure): integrates the phone's rotation rates into a
/// few degrees of yaw / pitch that ease back to rest, low-pass filtered so
/// hand tremor never shakes the scene.
///
/// Feed [addRates] from the gyroscope (rad/s, portrait axes: x = pitch,
/// y = yaw) and call [advance] once per scene frame.
class GyroParallax {
  GyroParallax({this.maxAngle = 0.07, this.returnTime = 1.8, this.smoothing = 0.14, this.deadZone = 0.05});

  /// Largest parallax angle (radians, ≈ 4°).
  final double maxAngle;

  /// Time constant (s) of the drift back to rest when the phone is still.
  final double returnTime;

  /// Time constant (s) of the output low-pass filter.
  final double smoothing;

  /// Rotation rates below this (rad/s) are sensor noise – and hand tremor
  /// (≈ 0.01–0.04 rad/s on a held phone), so holding the phone still never
  /// keeps the scene out of its idle cadence.
  final double deadZone;

  /// The parallax output still differs visibly from where it is heading
  /// (more than ≈ 0.1°): only then is it worth a full-rate frame.
  bool get isMovingVisibly => (_yaw - _rawYaw).abs() > 2e-3 || (_pitch - _rawPitch).abs() > 2e-3;

  double _rawYaw = 0, _rawPitch = 0;
  double _yaw = 0, _pitch = 0;

  /// Filtered output (radians).
  double get yaw => _yaw;
  double get pitch => _pitch;

  /// Output in degrees (yaw, pitch) – the sky's `gyro` input.
  Offset get degrees => Offset(_yaw * 180 / math.pi, _pitch * 180 / math.pi);

  /// Nothing left to ease (the scene may idle).
  bool get isSettled =>
      _rawYaw.abs() < 1e-4 &&
      _rawPitch.abs() < 1e-4 &&
      (_yaw - _rawYaw).abs() < 1e-4 &&
      (_pitch - _rawPitch).abs() < 1e-4;

  /// One gyroscope sample: [pitchRate] / [yawRate] in rad/s over [dt] s.
  void addRates(double pitchRate, double yawRate, double dt) {
    if (!dt.isFinite || dt <= 0 || dt > 0.25) return;
    double gate(double r) => r.isFinite && r.abs() > deadZone ? r : 0;
    _rawPitch = (_rawPitch + gate(pitchRate) * dt).clamp(-maxAngle, maxAngle);
    _rawYaw = (_rawYaw + gate(yawRate) * dt).clamp(-maxAngle, maxAngle);
  }

  /// Eases toward rest and filters the output by [dt] seconds.
  void advance(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    final decay = math.exp(-dt / returnTime);
    _rawYaw *= decay;
    _rawPitch *= decay;
    final k = 1 - math.exp(-dt / smoothing);
    _yaw += (_rawYaw - _yaw) * k;
    _pitch += (_rawPitch - _pitch) * k;
    if (isSettled) reset();
  }

  void reset() {
    _rawYaw = _rawPitch = _yaw = _pitch = 0;
  }
}
