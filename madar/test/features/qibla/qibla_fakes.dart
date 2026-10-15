// Test doubles for the qibla package: synthetic sensor vectors for a phone
// held at a known orientation, a scriptable HeadingSource and MotionSensors.
import 'dart:async';
import 'dart:math' as math;

import 'package:madar/features/qibla/data/sensor_heading_source.dart';
import 'package:madar/features/qibla/domain/compass_math.dart';
import 'package:madar/features/qibla/domain/heading.dart';

/// Device axes (in world East-North-Up) of a phone whose top edge points at
/// azimuth [heading], raised by [pitch] (top up) and then [roll] (right edge
/// up) – degrees.
class Pose {
  Pose({required double heading, double pitch = 0, double roll = 0}) {
    final h = heading * math.pi / 180, p = pitch * math.pi / 180, r = roll * math.pi / 180;
    final x0 = Vec3(math.cos(h), -math.sin(h), 0);
    final y0 = Vec3(math.sin(h), math.cos(h), 0);
    const z0 = Vec3(0, 0, 1);
    final y1 = y0 * math.cos(p) + z0 * math.sin(p);
    final z1 = y0 * -math.sin(p) + z0 * math.cos(p);
    x = x0 * math.cos(r) + z1 * math.sin(r);
    z = x0 * -math.sin(r) + z1 * math.cos(r);
    y = y1;
  }

  late final Vec3 x, y, z;

  /// A world (ENU) vector in device coordinates.
  Vec3 toDevice(Vec3 w) => Vec3(w.dot(x), w.dot(y), w.dot(z));

  /// The accelerometer at rest (reads "up", 9.81 m/s²).
  Vec3 accel({double g = 9.80665}) => toDevice(Vec3(0, 0, g));

  /// A magnetometer in a field of [total] µT dipping [dip]° below the
  /// horizontal toward magnetic north (the synthetic world's north).
  Vec3 magnetic({double total = 44, double dip = 50}) {
    final d = dip * math.pi / 180;
    return toDevice(Vec3(0, total * math.cos(d), -total * math.sin(d)));
  }
}

/// A [HeadingSource] driven by the test.
class FakeHeadingSource implements HeadingSource {
  FakeHeadingSource({this.initial, this.error});

  /// Emitted as soon as someone listens (and re-emitted on [emit]).
  HeadingReading? initial;

  /// When set, the stream fails with it on listen.
  Object? error;

  final List<StreamController<HeadingReading>> _controllers = [];
  int listens = 0;
  bool lastLandscape = false;
  bool lastBatterySaver = false;

  bool get hasListener => _controllers.any((c) => c.hasListener);

  @override
  Stream<HeadingReading> readings({bool landscape = false, bool batterySaver = false}) {
    lastLandscape = landscape;
    lastBatterySaver = batterySaver;
    late final StreamController<HeadingReading> c;
    c = StreamController<HeadingReading>(
      onListen: () {
        listens++;
        final e = error;
        if (e != null) {
          c.addError(e);
          return;
        }
        final r = initial;
        if (r != null) c.add(r);
      },
      onCancel: () => _controllers.remove(c),
    );
    _controllers.add(c);
    return c.stream;
  }

  /// Sends [r] to every listener.
  void emit(HeadingReading r) {
    initial = r;
    for (final c in List.of(_controllers)) {
      if (c.hasListener && !c.isClosed) c.add(r);
    }
  }

  void fail(Object e) {
    for (final c in List.of(_controllers)) {
      if (c.hasListener && !c.isClosed) c.addError(e);
    }
  }
}

/// Scriptable raw sensors.
class FakeMotionSensors implements MotionSensors {
  final accel = StreamController<MotionSample>.broadcast();
  final mag = StreamController<MotionSample>.broadcast();
  Duration? period;

  @override
  Stream<MotionSample> accelerometer(Duration samplingPeriod) {
    period = samplingPeriod;
    return accel.stream;
  }

  @override
  Stream<MotionSample> magnetometer(Duration samplingPeriod) => mag.stream;
}
