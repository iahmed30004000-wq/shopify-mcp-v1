import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/compass_math.dart';
import '../domain/heading.dart';
import '../domain/heading_engine.dart';

/// One raw sample in device coordinates with its sensor time.
@immutable
class MotionSample {
  const MotionSample(this.value, this.time);

  final Vec3 value;

  /// Monotonic sensor time (both sensors share one clock).
  final Duration time;
}

/// The raw accelerometer (m/s², gravity included) and magnetometer (µT)
/// streams – the platform seam behind [SensorHeadingSource].
abstract interface class MotionSensors {
  Stream<MotionSample> accelerometer(Duration samplingPeriod);
  Stream<MotionSample> magnetometer(Duration samplingPeriod);
}

/// [MotionSensors] from sensors_plus (Android `TYPE_ACCELEROMETER` and the
/// OS-calibrated `TYPE_MAGNETIC_FIELD`; neither needs a permission).
class SensorsPlusMotionSensors implements MotionSensors {
  const SensorsPlusMotionSensors();

  @override
  Stream<MotionSample> accelerometer(Duration samplingPeriod) =>
      accelerometerEventStream(samplingPeriod: samplingPeriod)
          .map((e) => MotionSample(Vec3(e.x, e.y, e.z), Duration(microseconds: e.timestamp.microsecondsSinceEpoch)));

  @override
  Stream<MotionSample> magnetometer(Duration samplingPeriod) =>
      magnetometerEventStream(samplingPeriod: samplingPeriod)
          .map((e) => MotionSample(Vec3(e.x, e.y, e.z), Duration(microseconds: e.timestamp.microsecondsSinceEpoch)));
}

/// The production [HeadingSource]: accelerometer + magnetometer through a
/// [HeadingEngine] (tilt compensation, circular smoothing, statistics).
/// Sensors are registered only while the stream has a listener.
class SensorHeadingSource implements HeadingSource {
  SensorHeadingSource({this.sensors = const SensorsPlusMotionSensors()});

  final MotionSensors sensors;

  /// 50 Hz: low latency; well under Android 12's 200 Hz cap that would
  /// need HIGH_SAMPLING_RATE_SENSORS.
  static const Duration livePeriod = SensorInterval.gameInterval;

  /// 15 Hz under battery saver.
  static const Duration saverPeriod = SensorInterval.uiInterval;

  @override
  Stream<HeadingReading> readings({bool landscape = false, bool batterySaver = false}) {
    StreamSubscription<MotionSample>? accel;
    StreamSubscription<MotionSample>? mag;
    late final StreamController<HeadingReading> out;
    final engine = HeadingEngine(landscape: landscape);
    var failed = false;

    Future<void> stop() async {
      final a = accel, m = mag;
      accel = null;
      mag = null;
      await Future.wait([if (a != null) a.cancel(), if (m != null) m.cancel()]);
    }

    void fail(Object error) {
      if (failed || out.isClosed) return;
      failed = true;
      out.addError(HeadingUnavailable(reasonFor(error), error));
      unawaited(stop().whenComplete(out.close));
    }

    out = StreamController<HeadingReading>(
      onListen: () {
        final period = batterySaver ? saverPeriod : livePeriod;
        try {
          accel = sensors.accelerometer(period).listen((s) => engine.addAccelerometer(s.value, s.time), onError: fail);
          mag = sensors.magnetometer(period).listen((s) {
            final r = engine.addMagnetometer(s.value, s.time);
            if (r != null && !out.isClosed) out.add(r);
          }, onError: fail);
        } catch (e) {
          fail(e);
        }
      },
      onCancel: stop,
    );
    return out.stream;
  }

  /// Maps a plugin error to a reason ("NO_SENSOR" from sensors_plus when the
  /// device lacks the sensor; a missing plugin on hosts without sensors).
  static HeadingUnavailableReason reasonFor(Object error) {
    if (error is HeadingUnavailable) return error.reason;
    if (error is PlatformException && error.code == 'NO_SENSOR') return HeadingUnavailableReason.noSensor;
    if (error is MissingPluginException) return HeadingUnavailableReason.noSensor;
    return HeadingUnavailableReason.sensorError;
  }
}
