import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'circular_filter.dart';
import 'compass_math.dart';
import 'heading.dart';
import 'wmm.dart';

/// Coarse accuracy of the compass right now.
enum CompassAccuracy { high, medium, low, unreliable }

/// The compass's estimated error and whether the user should calibrate.
@immutable
class CompassQuality {
  const CompassQuality({
    required this.accuracy,
    required this.errorDeg,
    this.needsCalibration = false,
    this.interference = false,
  });

  /// Before any reading.
  static const unknown = CompassQuality(accuracy: CompassAccuracy.medium, errorDeg: 10);

  final CompassAccuracy accuracy;

  /// Estimated heading error (degrees, ~95 %).
  final double errorDeg;

  /// Show the figure-eight prompt.
  final bool needsCalibration;

  /// |B| is far from what the World Magnetic Model expects here – metal or a
  /// magnet nearby rather than (only) an uncalibrated sensor.
  final bool interference;

  static CompassAccuracy levelFor(double errorDeg) => errorDeg <= 6
      ? CompassAccuracy.high
      : errorDeg <= 12
      ? CompassAccuracy.medium
      : errorDeg <= 22
      ? CompassAccuracy.low
      : CompassAccuracy.unreliable;

  @override
  bool operator ==(Object other) =>
      other is CompassQuality &&
      other.accuracy == accuracy &&
      other.errorDeg == errorDeg &&
      other.needsCalibration == needsCalibration &&
      other.interference == interference;

  @override
  int get hashCode => Object.hash(accuracy, errorDeg, needsCalibration, interference);

  @override
  String toString() =>
      'CompassQuality($accuracy ±${errorDeg.toStringAsFixed(1)}°${needsCalibration ? ', calibrate' : ''}'
      '${interference ? ', interference' : ''})';
}

/// Estimates the compass error from how the measured field compares with the
/// World Magnetic Model at the user's location, and decides (with
/// hysteresis) when to ask for a figure-eight calibration.
///
/// A disturbance of δ µT perpendicular to the horizontal field H turns the
/// needle by up to atan(δ / H). The disturbance is seen three ways: |B|
/// differing from the model's F, the measured dip differing from the
/// model's inclination, and |B| wandering while the phone turns (hard-iron
/// offsets). These combine by root-sum-square with the heading jitter, a
/// poorly defined pointing direction and a 1.5° floor (sensor and model).
class CompassQualityMonitor {
  CompassQualityMonitor({
    required this.expected,
    this.enterAfter = const Duration(milliseconds: 1000),
    this.exitAfter = const Duration(milliseconds: 1500),
  });

  /// The model field at the user's location.
  final GeomagneticField expected;
  final Duration enterAfter;
  final Duration exitAfter;

  /// Error above which calibration is suggested, and below which the
  /// suggestion clears.
  static const double calibrateAbove = 15;
  static const double clearBelow = 8;

  final EwmStats _error = EwmStats(0.6);
  Duration? _last;
  Duration? _badSince;
  Duration? _goodSince;
  bool _needs = false;

  /// The instantaneous error estimate of one reading (degrees).
  double errorOf(HeadingReading r) {
    final hExp = math.max(expected.hMicroTesla, 0.5);
    final fExp = expected.fMicroTesla;
    double atanDeg(double v) => math.atan(v) * CircularMath.degPerRad;

    var fieldErr = 0.0;
    final fMeas = r.fieldMicroTesla;
    if (fMeas != null) {
      // A uniform scale error does not turn the needle: allow 8 % freely.
      final excess = math.max(0.0, (fMeas - fExp).abs() - 0.08 * fExp);
      fieldErr = atanDeg(excess / hExp);
    }
    final dip = r.dip;
    if (dip != null && r.steady) {
      final excess = math.max(0.0, (dip - expected.inclination).abs() - 4);
      fieldErr = math.max(fieldErr, atanDeg(fExp * math.sin(excess * CircularMath.radPerDeg) / hExp));
    }
    final spreadErr = atanDeg(2 * r.fieldSpread / hExp);
    final pointingErr = (1 - r.pointing.clamp(0.0, 1.0)) * 20;
    var e = math.sqrt(
      1.5 * 1.5 + fieldErr * fieldErr + spreadErr * spreadErr + r.jitter * r.jitter + pointingErr * pointingErr,
    );
    if (expected.inBlackoutZone) {
      e = math.max(e, 45);
    } else if (expected.inCautionZone) {
      e = math.max(e, 15);
    }
    return math.min(e, 90);
  }

  /// Folds [r] in and returns the current quality.
  CompassQuality update(HeadingReading r) {
    final t = r.timestamp;
    final dt = _last == null ? 0.0 : math.max(0.0, (t - _last!).inMicroseconds / 1e6);
    _last = t;
    final instant = errorOf(r);
    _error.add(instant, dt);
    final e = _error.mean ?? instant;

    if (e > calibrateAbove) {
      _goodSince = null;
      _badSince ??= t;
      if (!_needs && t - _badSince! >= enterAfter) _needs = true;
    } else if (e < clearBelow) {
      _badSince = null;
      _goodSince ??= t;
      if (_needs && t - _goodSince! >= exitAfter) _needs = false;
    } else {
      _badSince = null;
      _goodSince = null;
    }

    final fMeas = r.fieldMicroTesla;
    final ratio = fMeas == null ? 1.0 : fMeas / math.max(expected.fMicroTesla, 1e-6);
    return CompassQuality(
      accuracy: CompassQuality.levelFor(e),
      errorDeg: e,
      needsCalibration: _needs,
      interference: ratio < 0.65 || ratio > 1.45,
    );
  }

  void reset() {
    _error.reset();
    _last = null;
    _badSince = null;
    _goodSince = null;
    _needs = false;
  }
}
