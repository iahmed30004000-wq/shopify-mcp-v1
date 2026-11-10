// The Dart client of the one native call: it feature-detects, it never throws
// and it never turns an unexpected answer into "available". The native side
// is replaced by a fake channel.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/data/ondevice_probe_client.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';

import 'support/ondevice_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelOnDeviceProbe.channelName);

  void answer(Future<Object?> Function(MethodCall call) handler) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );

  test('the channel is named app.madar.orbit/ondevice and has one method: probe', () async {
    expect(MethodChannelOnDeviceProbe.channelName, 'app.madar.orbit/ondevice');
    final calls = <String>[];
    answer((c) async {
      calls.add(c.method);
      return <String, Object?>{};
    });
    await MethodChannelOnDeviceProbe().probe();
    expect(calls, ['probe']);
  });

  test('what the Kotlin side sends today: both engines unsupported, the real numbers', () async {
    answer(
      (c) async => <String, Object?>{
        'aicore': 'unsupported',
        'engine': 'unsupported',
        'sdkInt': 36,
        'totalRamBytes': 12 * gib,
        'availableRamBytes': 5 * gib,
        'freeStorageBytes': 90 * gib,
        'thermalStatus': 0,
        'batterySaver': false,
      },
    );
    final caps = await MethodChannelOnDeviceProbe().probe();
    expect(caps.aicore.status, ProbeStatus.unsupported);
    expect(caps.engine.status, ProbeStatus.unsupported);
    expect(caps.sdkInt, 36);
    expect(caps.totalRamBytes, 12 * gib);
    expect(caps.availableRamBytes, 5 * gib);
    expect(caps.freeStorageBytes, 90 * gib);
    expect(caps.thermal, ThermalState.none);
    expect(caps.batterySaver, isFalse);
  });

  test('a missing plugin (iOS, desktop, no engine built) is "unsupported", not an exception', () async {
    // No handler registered: the channel throws MissingPluginException.
    final caps = await MethodChannelOnDeviceProbe().probe();
    expect(caps.aicore.status, ProbeStatus.unsupported);
    expect(caps.engine.status, ProbeStatus.unsupported);
    expect(caps.totalRamBytes, isNull, reason: 'a number nobody gave is unknown, not zero');
  });

  test('a failed call is "unknown", never a crash', () async {
    answer((c) async => throw PlatformException(code: 'ondevice_probe', message: 'boom'));
    final caps = await MethodChannelOnDeviceProbe().probe();
    expect(caps.aicore.status, ProbeStatus.unknown);
    expect(caps.engine.status, ProbeStatus.unknown);
  });

  test('a reply of the wrong shape is "unknown"', () async {
    for (final bad in <Object?>[null, 'unsupported', 42, <Object?>[1, 2]]) {
      answer((c) async => bad);
      final caps = await MethodChannelOnDeviceProbe().probe();
      expect(caps.aicore.status, ProbeStatus.unknown, reason: '$bad');
    }
  });

  test('a preview that answers with a word we do not know is "unknown", not "available"', () {
    final caps = MethodChannelOnDeviceProbe.parse({'aicore': 'AVAILABLE_PREVIEW_2', 'engine': 7});
    expect(caps.aicore.status, ProbeStatus.unknown);
    expect(caps.engine.status, ProbeStatus.unknown);
  });

  test('a probe may also answer with a map carrying the version it measured', () {
    final caps = MethodChannelOnDeviceProbe.parse({
      'aicore': {'status': 'available', 'version': 'preview-1'},
      'engine': {'status': 'available'},
    });
    expect(caps.aicore, const FeatureProbe.available(version: 'preview-1'));
    expect(caps.engine, const FeatureProbe.available());
  });

  test('nonsense numbers are dropped to unknown (negative, text, NaN)', () {
    final caps = MethodChannelOnDeviceProbe.parse({
      'sdkInt': '36',
      'totalRamBytes': -5,
      'availableRamBytes': double.nan,
      'freeStorageBytes': null,
      'thermalStatus': 'hot',
      'batterySaver': 'yes',
    });
    expect(caps.sdkInt, isNull);
    expect(caps.totalRamBytes, isNull);
    expect(caps.availableRamBytes, isNull);
    expect(caps.freeStorageBytes, isNull);
    expect(caps.thermal, ThermalState.unknown);
    expect(caps.batterySaver, isFalse);
  });

  test('thermal -1 (Android below 10) is unknown; 3 is severe; battery saver true is read', () {
    final caps = MethodChannelOnDeviceProbe.parse({'thermalStatus': -1, 'batterySaver': true});
    expect(caps.thermal, ThermalState.unknown);
    expect(caps.batterySaver, isTrue);
    expect(MethodChannelOnDeviceProbe.parse({'thermalStatus': 3}).thermal, ThermalState.severe);
  });
}
