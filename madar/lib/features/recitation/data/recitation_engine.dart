import 'package:meta/meta.dart';

/// One entry of the engine's playlist.
@immutable
class EngineSource {
  const EngineSource.url(Uri this.uri) : filePath = null, silence = null;
  const EngineSource.file(String this.filePath) : uri = null, silence = null;
  const EngineSource.silence(Duration this.silence) : uri = null, filePath = null;

  final Uri? uri;
  final String? filePath;
  final Duration? silence;

  bool get isRemote => uri != null;

  @override
  bool operator ==(Object other) =>
      other is EngineSource && other.uri == uri && other.filePath == filePath && other.silence == silence;

  @override
  int get hashCode => Object.hash(uri, filePath, silence);

  @override
  String toString() => uri != null
      ? 'url($uri)'
      : filePath != null
      ? 'file($filePath)'
      : 'silence(${silence!.inMilliseconds}ms)';
}

/// What the engine is doing.
enum EngineProcessing { idle, loading, buffering, ready, completed }

@immutable
class EngineStatus {
  const EngineStatus({required this.playing, required this.processing});

  final bool playing;
  final EngineProcessing processing;

  static const idle = EngineStatus(playing: false, processing: EngineProcessing.idle);

  @override
  bool operator ==(Object other) => other is EngineStatus && other.playing == playing && other.processing == processing;

  @override
  int get hashCode => Object.hash(playing, processing);

  @override
  String toString() => 'EngineStatus(${playing ? 'playing' : 'paused'}, ${processing.name})';
}

/// A failure reported by the engine, with the playlist index it concerns.
@immutable
class EngineFailure {
  const EngineFailure({this.index, this.message, this.code});

  final int? index;
  final String? message;
  final int? code;

  /// The host answered 404 (no such file for this reciter).
  bool get notFound => (message ?? '').contains('404');

  @override
  String toString() => 'EngineFailure($index, $code, $message)';
}

/// The audio player behind the recitation controller (just_audio in the
/// app, a scripted fake in tests). A gapless playlist of per-ayah files,
/// silences and streams.
abstract class RecitationEngine {
  /// Playlist index of the entry playing (null before a playlist is set).
  Stream<int?> get index;
  Stream<EngineStatus> get status;
  Stream<EngineFailure> get failures;

  /// Position within the current entry (for progress rings).
  Stream<Duration> get position;
  Duration get currentPosition;

  /// Length of the current entry, once known.
  Duration? get duration;

  /// Playlist index of the current entry.
  int? get currentIndex;

  /// Replaces the playlist; loads [initialIndex] (at [initialPosition]) but
  /// does not start playing.
  Future<void> setSources(List<EngineSource> sources, {int initialIndex = 0, Duration initialPosition = Duration.zero});

  /// Appends to the playlist without interrupting playback.
  Future<void> addSources(List<EngineSource> sources);

  /// Starts or resumes (returns once the request is made, not when playback
  /// ends).
  Future<void> play();
  Future<void> pause();

  /// Stops and releases the decoder (the playlist is kept).
  Future<void> stop();
  Future<void> seek(Duration position, {int? index});
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

/// Audio focus and route events the controller reacts to (audio_session in
/// the app).
abstract class RecitationAudioFocus {
  /// Configures the session (speech, pause instead of ducking). Safe to call
  /// more than once.
  Future<void> configure();

  /// `true` when another app takes the audio, `false` when it gives it back
  /// after a transient loss (only then may playback resume).
  Stream<({bool begin, bool transient})> get interruptions;

  /// Headphones unplugged / Bluetooth disconnected.
  Stream<void> get becomingNoisy;
}

/// No audio focus events (tests, platforms without audio_session).
class NoAudioFocus implements RecitationAudioFocus {
  const NoAudioFocus();
  @override
  Future<void> configure() async {}
  @override
  Stream<({bool begin, bool transient})> get interruptions => const Stream.empty();
  @override
  Stream<void> get becomingNoisy => const Stream.empty();
}
