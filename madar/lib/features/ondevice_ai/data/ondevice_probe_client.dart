/// The Dart side of the one native call, `app.madar.orbit/ondevice` ›
/// `probe` (Android: `OnDeviceChannel.kt`).
///
/// It **feature-detects**: a missing plugin (iOS, desktop, a test run, an
/// engine that was not built), a failed call or an unexpected reply all
/// become «unsupported / unknown», never an exception and never «available».
/// Until step B the native side answers `aicore: unsupported` and
/// `engine: unsupported` and only gives the real numbers (memory, storage,
/// Android level, temperature, battery saver) from standard Android APIs.
library;

import 'package:flutter/services.dart';

import '../domain/model_path.dart';

/// The probe's transport, so tests use a fake instead of a platform channel.
abstract interface class OnDeviceProbe {
  Future<DeviceCapabilities> probe();
}

class MethodChannelOnDeviceProbe implements OnDeviceProbe {
  MethodChannelOnDeviceProbe([MethodChannel? channel]) : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'app.madar.orbit/ondevice';

  final MethodChannel _channel;

  @override
  Future<DeviceCapabilities> probe() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('probe');
      return parse(raw);
    } on MissingPluginException {
      return const DeviceCapabilities(aicore: FeatureProbe.unsupported(), engine: FeatureProbe.unsupported());
    } on PlatformException {
      return const DeviceCapabilities.unknown();
    } catch (_) {
      return const DeviceCapabilities.unknown();
    }
  }

  /// Reads the native map defensively. Anything that is not exactly the
  /// shape we expect is dropped to «unknown».
  static DeviceCapabilities parse(Object? raw) {
    if (raw is! Map) return const DeviceCapabilities.unknown();
    int? intOf(String key) {
      final v = raw[key];
      if (v is int && v >= 0) return v;
      if (v is double && v.isFinite && v >= 0) return v.toInt();
      return null;
    }

    FeatureProbe probeOf(String key) {
      final v = raw[key];
      // «aicore: "available"», or a map {status, version}.
      if (v is Map) {
        final status = ProbeStatus.parse(v['status']);
        final version = v['version'];
        return FeatureProbe(status, version: version is String ? version : null);
      }
      return FeatureProbe(ProbeStatus.parse(v));
    }

    return DeviceCapabilities(
      sdkInt: intOf('sdkInt'),
      totalRamBytes: intOf('totalRamBytes'),
      availableRamBytes: intOf('availableRamBytes'),
      freeStorageBytes: intOf('freeStorageBytes'),
      aicore: probeOf('aicore'),
      engine: probeOf('engine'),
      thermal: ThermalState.fromAndroid(raw['thermalStatus']),
      batterySaver: raw['batterySaver'] == true,
    );
  }
}
