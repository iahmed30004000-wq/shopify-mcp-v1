import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// The microphone, behind a small interface so the rest is tested with a
/// fake. Nothing here touches the network.
abstract interface class VoiceRecorder {
  /// Asks for the microphone permission when it is not yet granted; true when
  /// the app may record.
  Future<bool> ensurePermission();

  /// Starts writing a recording to [path].
  Future<void> start(String path);

  /// Loudness 0..1, about ten times a second while recording.
  Stream<double> get levels;

  /// Fires when something else took the audio (a phone call, an alarm) and the
  /// recording has stopped by itself; call [stop] to finish the file.
  Stream<void> get interruptions;

  /// Ends the recording and finishes the file. Returns its path, or null when
  /// nothing was recorded.
  Future<String?> stop();

  /// Ends the recording and throws the file away.
  Future<void> cancel();

  Future<void> dispose();
}

/// `record` (BSD-3) over the platform recorder: AAC in an .m4a file, mono,
/// speech quality (small files), paused by the system on audio-focus loss.
class RecordPackageRecorder implements VoiceRecorder {
  RecordPackageRecorder() : _rec = AudioRecorder();

  final AudioRecorder _rec;

  @override
  Future<bool> ensurePermission() => _rec.hasPermission();

  @override
  Future<void> start(String path) => _rec.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 32000,
      numChannels: 1,
      audioInterruption: AudioInterruptionMode.pause,
    ),
    path: path,
  );

  @override
  Stream<double> get levels => _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).map((a) => dbToLevel(a.current));

  // Nobody pauses the recorder from the app, so a pause is the system taking
  // the audio away.
  @override
  Stream<void> get interruptions => _rec.onStateChanged().where((s) => s == RecordState.pause);

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> dispose() => _rec.dispose();

  /// dBFS (about -60 quiet to 0 loud) to 0..1.
  @visibleForTesting
  static double dbToLevel(double db) => db.isNaN ? 0 : ((db + 55) / 55).clamp(0.0, 1.0);
}

/// A microphone that only listens: no file is written, nothing is kept. The
/// interactive story uses it to notice that the child made a sound.
abstract interface class SoundMeter {
  /// True when the app may listen (never asks by itself unless [request]).
  Future<bool> hasPermission({bool request = false});

  /// Starts listening; [levels] then emits 0..1 loudness.
  Future<void> start();

  Stream<double> get levels;

  Future<void> stop();

  Future<void> dispose();
}

/// [SoundMeter] over a `record` PCM stream: the samples are turned into one
/// loudness number and dropped at once.
class RecordSoundMeter implements SoundMeter {
  final AudioRecorder _rec = AudioRecorder();
  final StreamController<double> _levels = StreamController<double>.broadcast();
  StreamSubscription<Uint8List>? _sub;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<bool> hasPermission({bool request = false}) => _rec.hasPermission(request: request);

  @override
  Future<void> start() async {
    if (_sub != null) return;
    final stream = await _rec.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
    );
    _sub = stream.listen((chunk) {
      if (!_levels.isClosed) _levels.add(pcm16Level(chunk));
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _rec.isRecording()) await _rec.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _levels.close();
    await _rec.dispose();
  }

  /// RMS of little-endian 16-bit samples, 0..1 (speech sits around 0.05-0.4).
  @visibleForTesting
  static double pcm16Level(Uint8List bytes) => pcm16Rms(bytes);
}

/// RMS loudness of 16-bit little-endian PCM, scaled so ordinary speech is
/// clearly above 0.1.
double pcm16Rms(Uint8List bytes) {
  final n = bytes.length ~/ 2;
  if (n == 0) return 0;
  final data = ByteData.sublistView(bytes);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final v = data.getInt16(i * 2, Endian.little) / 32768.0;
    sum += v * v;
  }
  return (math.sqrt(sum / n) * 3).clamp(0.0, 1.0);
}
