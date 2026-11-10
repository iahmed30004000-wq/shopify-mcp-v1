import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/design/widgets/ambient_motion.dart';
import '../../../core/design/widgets/shader_cache.dart';
import '../render/astrolabe/astrolabe_shaders.dart';
import '../render/orbit_shaders.dart';
import '../render/sky/sky_shaders.dart';
import 'scene/orbit_flight.dart';
import 'scene/scene_compositing.dart' show ZoomBlur;

/// The planet-page ↔ orbit-scene bridge (one per app).
final orbitFlightProvider = Provider<OrbitFlight>((ref) {
  final flight = OrbitFlight();
  ref.onDispose(flight.dispose);
  return flight;
});

/// One gyroscope sample: rotation rates (rad/s) about the portrait x (pitch)
/// and y (yaw) axes, and when it was taken.
typedef GyroSample = ({double pitchRate, double yawRate, Duration at});

/// Opens the gyroscope stream for the scene's parallax, or returns null
/// where there is none (tests, desktop, web). The scene subscribes only
/// while it is visible and motion is not reduced – at the game rate while
/// it runs live, at the UI rate while it idles.
final orbitGyroProvider = Provider<Stream<GyroSample>? Function({bool fast})>((ref) {
  return ({bool fast = true}) {
    if (kIsWeb || !AmbientMotion.enabled) return null;
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      return gyroscopeEventStream(samplingPeriod: fast ? SensorInterval.gameInterval : SensorInterval.uiInterval)
          .map((e) => (pitchRate: e.x, yawRate: e.y, at: Duration(microseconds: e.timestamp.microsecondsSinceEpoch)));
    } catch (_) {
      return null;
    }
  };
});

/// Loads and warms up every shader program of the Astrolabe Orbit (and the
/// design system's glass / cosmos) so the first orbit frame never compiles
/// a pipeline. Started as early as possible (bootstrap) and awaited by the
/// unlock splash; failures are swallowed – layers fall back to gradients.
abstract final class OrbitWarmUp {
  static Future<void>? _running;
  static bool _done = false;
  static bool? _gateOverride;
  static final bool _underTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether the unlock splash waits for the warm-up (off under
  /// `flutter test`, where GPU work only completes outside the fake clock).
  static bool get gatesSplash => _gateOverride ?? !_underTest;

  @visibleForTesting
  static set debugGatesSplash(bool? value) => _gateOverride = value;

  /// Whether every program is loaded and warmed.
  static bool get isDone => _done;

  /// Starts (once) and returns the warm-up.
  static Future<void> start() => _running ??= _run();

  static Future<void> _run() async {
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (kDebugMode) debugPrint('Orbit warm-up: $e');
      }
    }

    await Future.wait([
      guard(MadarShaders.preload),
      guard(() async => (await OrbitShaders.load()).warmUp()),
      guard(AstrolabePrograms.warmUp),
      guard(SkyPrograms.warmUp),
      guard(ZoomBlur.warmUp),
    ]);
    _done = true;
  }

  @visibleForTesting
  static void debugReset() {
    _running = null;
    _done = false;
  }
}

/// The warm-up as a provider (the splash waits on it, never longer than
/// [OrbitWarmUp] allows).
final orbitWarmUpProvider = FutureProvider<void>((ref) => OrbitWarmUp.start(), retry: (_, _) => null);

/// Keeps a stream subscription tidy (helper for the scene's gyro).
extension CancelQuietly on StreamSubscription<Object?>? {
  Future<void> cancelQuietly() async {
    try {
      await this?.cancel();
    } catch (_) {}
  }
}
