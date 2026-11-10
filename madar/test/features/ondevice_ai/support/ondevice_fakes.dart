// Fakes for Part 15 step A: a scripted on-device model, a fake native probe,
// a fake fingerprint gate and an in-memory model sink.
import 'dart:async';
import 'dart:typed_data';

import 'package:madar/features/ondevice_ai/data/model_download_manager.dart';
import 'package:madar/features/ondevice_ai/data/ondevice_probe_client.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';
import 'package:madar/features/ondevice_ai/domain/on_device_model.dart';

/// A model that says what the test scripted: [tokens] one by one, then ends,
/// or fails with [failure] after [failAfter] tokens, or hangs.
class FakeOnDeviceModel implements OnDeviceModel {
  FakeOnDeviceModel({
    this.path = ModelPath.aicore,
    this.tokens = const [],
    this.ready = true,
    this.failAfter,
    this.failure,
    this.hang = false,
    this.tokenDelay,
  });

  @override
  final ModelPath path;
  final List<String> tokens;
  bool ready;

  /// Number of tokens delivered before [failure] is thrown on the stream.
  final int? failAfter;
  final Object? failure;

  /// Never ends after the last token.
  final bool hang;
  final Duration? tokenDelay;

  final List<ModelRequest> requests = [];
  int cancelled = 0;
  int unloaded = 0;

  @override
  Future<bool> isReady() async => ready;

  @override
  ModelGeneration generate(ModelRequest request) {
    requests.add(request);
    return _FakeGeneration(this);
  }

  @override
  Future<void> unload() async => unloaded++;
}

class _FakeGeneration implements ModelGeneration {
  _FakeGeneration(this._model) {
    unawaited(_run());
  }

  final FakeOnDeviceModel _model;
  final StreamController<String> _controller = StreamController<String>();
  bool _stopped = false;

  @override
  Stream<String> get tokens => _controller.stream;

  Future<void> _run() async {
    var delivered = 0;
    for (final t in _model.tokens) {
      if (_stopped) return;
      if (_model.failAfter != null && delivered >= _model.failAfter!) {
        _controller.addError(_model.failure!);
        return;
      }
      if (_model.tokenDelay != null) await Future<void>.delayed(_model.tokenDelay!);
      if (_stopped) return;
      _controller.add(t);
      delivered++;
    }
    if (_stopped) return;
    if (_model.failAfter != null && delivered >= _model.failAfter!) {
      _controller.addError(_model.failure!);
      return;
    }
    if (!_model.hang) await _controller.close();
  }

  @override
  Future<void> cancel() async {
    _model.cancelled++;
    _stopped = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

/// The probe, answering with [caps] (or throwing).
class FakeProbe implements OnDeviceProbe {
  FakeProbe(this.caps);

  DeviceCapabilities caps;
  int calls = 0;

  @override
  Future<DeviceCapabilities> probe() async {
    calls++;
    return caps;
  }
}

class FakeAuthGate implements AuthGate {
  FakeAuthGate({this.allow = true});

  bool allow;
  int asked = 0;

  @override
  Future<bool> confirm() async {
    asked++;
    return allow;
  }
}

/// Parts and finished files in memory.
class MemoryModelSink implements ModelFileSink {
  final Map<String, Uint8List> parts = {};
  final Map<String, Uint8List> files = {};

  String _k(String id, int i) => '$id#$i';

  @override
  Future<int?> partLength(String id, int index) async => parts[_k(id, index)]?.length;

  @override
  Future<void> writePart(String id, int index, Uint8List bytes) async => parts[_k(id, index)] = bytes;

  @override
  Stream<List<int>> readPart(String id, int index) => Stream.value(parts[_k(id, index)]!);

  @override
  Future<void> deletePart(String id, int index) async => parts.remove(_k(id, index));

  @override
  Future<String> finalize(String id, int partCount) async {
    final b = BytesBuilder();
    for (var i = 0; i < partCount; i++) {
      b.add(parts.remove(_k(id, i))!);
    }
    files[id] = b.toBytes();
    return '/private/$id.bin';
  }

  @override
  Future<void> discard(String id) async {
    parts.removeWhere((k, _) => k.startsWith('$id#'));
    files.remove(id);
  }

  @override
  Future<bool> finalExists(String id) async => files.containsKey(id);
}

/// A phone that can run everything: AICore available, plenty of memory.
DeviceCapabilities capableCaps({
  FeatureProbe aicore = const FeatureProbe.available(),
  FeatureProbe engine = const FeatureProbe.available(),
  int sdkInt = 36,
  int totalGb = 16,
  int availableGb = 8,
  int freeGb = 100,
  ThermalState thermal = ThermalState.none,
  bool batterySaver = false,
  bool weightsInstalled = false,
}) => DeviceCapabilities(
  sdkInt: sdkInt,
  totalRamBytes: totalGb * gib,
  availableRamBytes: availableGb * gib,
  freeStorageBytes: freeGb * gib,
  aicore: aicore,
  engine: engine,
  thermal: thermal,
  batterySaver: batterySaver,
  weightsInstalled: weightsInstalled,
);

const int gib = 1024 * 1024 * 1024;
