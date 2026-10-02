import 'package:flutter/foundation.dart';

import '../../../core/astro/astronomy.dart';
import 'compass_math.dart';

/// The sun as a compass: when it is up, its azimuth is a true bearing, so
/// pointing the phone at it fixes every other direction – no magnetometer
/// needed.
@immutable
class SunGuide {
  const SunGuide({required this.azimuth, required this.altitude, required this.at});

  /// The sun at [time] seen from [latitude] / [longitude] (NOAA algorithm,
  /// refraction included – [Astro.sun]).
  factory SunGuide.at(DateTime time, {required double latitude, required double longitude}) {
    final s = Astro.sun(time, latitude: latitude, longitude: longitude);
    return SunGuide(azimuth: s.azimuth, altitude: s.altitude, at: time);
  }

  /// Degrees clockwise from true north.
  final double azimuth;

  /// Degrees above the horizon.
  final double altitude;
  final DateTime at;

  /// Low enough to aim at yet clear of the horizon haze.
  static const double minAltitude = 2;

  /// Above this the sun is nearly overhead: its azimuth swings quickly and
  /// is hard to aim at.
  static const double highAltitude = 65;

  /// Whether the sun can serve as a compass.
  bool get usable => altitude >= minAltitude;

  /// Whether aiming is imprecise because the sun is high.
  bool get high => altitude > highAltitude;

  /// Signed angle from the sun to [bearing] (positive = to the right,
  /// clockwise), for someone facing the sun.
  double turnTo(double bearing) => CircularMath.delta(azimuth, bearing);

  /// Direction a vertical object's shadow points (true bearing).
  double get shadowAzimuth => CircularMath.wrap360(azimuth + 180);

  @override
  bool operator ==(Object other) =>
      other is SunGuide && other.azimuth == azimuth && other.altitude == altitude && other.at == at;

  @override
  int get hashCode => Object.hash(azimuth, altitude, at);
}
