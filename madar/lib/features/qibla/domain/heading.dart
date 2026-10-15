import 'package:flutter/foundation.dart';

/// One processed compass reading: tilt compensated, smoothed on the unit
/// circle, relative to MAGNETIC north (declination is applied later, from
/// the World Magnetic Model at the prayer location).
@immutable
class HeadingReading {
  const HeadingReading({
    required this.heading,
    double? rawHeading,
    this.fieldMicroTesla,
    this.fieldSpread = 0,
    this.dip,
    this.jitter = 0,
    this.pitch = 0,
    this.roll = 0,
    this.pointing = 1,
    this.steady = true,
    this.timestamp = Duration.zero,
  }) : rawHeading = rawHeading ?? heading;

  /// Smoothed magnetic heading of the screen's forward direction, [0, 360).
  final double heading;

  /// The unsmoothed heading of the same sample.
  final double rawHeading;

  /// Smoothed |B| (µT); null when the source cannot measure it.
  final double? fieldMicroTesla;

  /// Standard deviation of |B| over the last second or so (µT). A calibrated
  /// magnetometer keeps |B| constant while the phone turns; hard-iron
  /// offsets or nearby metal make it wander.
  final double fieldSpread;

  /// Measured inclination below the horizontal (degrees); null = unknown.
  final double? dip;

  /// RMS deviation of the raw heading from the smoothed one (degrees).
  final double jitter;

  /// Screen top / right edge elevation (degrees) – for parallax.
  final double pitch, roll;

  /// How well the pointing direction is defined (0 … 1).
  final double pointing;

  /// Whether the phone is still enough for the gravity vector to be
  /// trusted (|a| ≈ g).
  final bool steady;

  /// Sensor time of the sample (monotonic).
  final Duration timestamp;

  HeadingReading copyWith({double? heading, Duration? timestamp}) => HeadingReading(
    heading: heading ?? this.heading,
    rawHeading: heading ?? rawHeading,
    fieldMicroTesla: fieldMicroTesla,
    fieldSpread: fieldSpread,
    dip: dip,
    jitter: jitter,
    pitch: pitch,
    roll: roll,
    pointing: pointing,
    steady: steady,
    timestamp: timestamp ?? this.timestamp,
  );

  @override
  String toString() =>
      'HeadingReading(${heading.toStringAsFixed(1)}°, |B| ${fieldMicroTesla?.toStringAsFixed(1)} µT, '
      'dip ${dip?.toStringAsFixed(1)}°, jitter ${jitter.toStringAsFixed(1)}°)';
}

/// Why the compass cannot be used.
enum HeadingUnavailableReason {
  /// The device has no magnetometer (or no accelerometer).
  noSensor,

  /// The sensor stream failed.
  sensorError,

  /// The sensors were never able to produce a heading in time.
  noReadings,
}

/// Error a [HeadingSource] stream emits when the compass is unavailable.
class HeadingUnavailable implements Exception {
  const HeadingUnavailable(this.reason, [this.cause]);

  final HeadingUnavailableReason reason;
  final Object? cause;

  @override
  String toString() => 'HeadingUnavailable($reason${cause == null ? '' : ': $cause'})';
}

/// A live compass. The sensors run only while the stream is listened to.
abstract interface class HeadingSource {
  /// Readings for a screen in portrait or [landscape] (the forward axis
  /// follows the display rotation); errors are [HeadingUnavailable].
  /// [batterySaver] lowers the sampling rate.
  Stream<HeadingReading> readings({bool landscape = false, bool batterySaver = false});
}
