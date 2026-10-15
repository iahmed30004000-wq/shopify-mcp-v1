import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'recitation_engine.dart';

/// [RecitationEngine] on just_audio (ExoPlayer on Android: gapless
/// concatenation, pitch-preserving speed, native silence sources).
///
/// Interruptions are handled by the controller (never auto-resumed after
/// the adhan), so the player's own handling is off.
///
/// The user agent goes out natively (ExoPlayer's `setUserAgent`), not through
/// just_audio's default local proxy: that proxy is a plain-HTTP server on
/// 127.0.0.1, which Android's default network security policy (cleartext
/// off) blocks – every streamed ayah would fail. No cleartext exception is
/// needed in the manifest this way.
class JustAudioEngine implements RecitationEngine {
  JustAudioEngine()
    : _player = AudioPlayer(
        handleInterruptions: false,
        userAgent: 'Madar/1 (Quran recitation)',
        useProxyForRequestHeaders: false,
      );

  final AudioPlayer _player;

  @override
  Stream<int?> get index => _player.currentIndexStream;

  @override
  Stream<EngineStatus> get status => _player.playerStateStream.map(
    (s) => EngineStatus(
      playing: s.playing,
      processing: switch (s.processingState) {
        ProcessingState.idle => EngineProcessing.idle,
        ProcessingState.loading => EngineProcessing.loading,
        ProcessingState.buffering => EngineProcessing.buffering,
        ProcessingState.ready => EngineProcessing.ready,
        ProcessingState.completed => EngineProcessing.completed,
      },
    ),
  );

  @override
  Stream<EngineFailure> get failures =>
      _player.errorStream.map((e) => EngineFailure(index: e.index, message: e.message, code: e.code));

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Duration get currentPosition => _player.position;

  @override
  Duration? get duration => _player.duration;

  static AudioSource _source(EngineSource s) {
    if (s.silence != null) return SilenceAudioSource(duration: s.silence!);
    if (s.filePath != null) return AudioSource.file(s.filePath!);
    return AudioSource.uri(s.uri!);
  }

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  Future<void> setSources(
    List<EngineSource> sources, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    await _player.setAudioSources(
      [for (final s in sources) _source(s)],
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> addSources(List<EngineSource> sources) => _player.addAudioSources([for (final s in sources) _source(s)]);

  @override
  Future<void> play() async {
    // just_audio's play() completes only when playback pauses again.
    unawaited(_player.play().catchError((Object _) {}));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position, {int? index}) => _player.seek(position, index: index);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() => _player.dispose();
}

/// [RecitationAudioFocus] on audio_session: spoken-audio attributes, full
/// focus, and a pause (never a duck) when another app speaks over it.
class AudioSessionFocus implements RecitationAudioFocus {
  Future<AudioSession>? _session;

  Future<AudioSession> get _instance => _session ??= AudioSession.instance;

  @override
  Future<void> configure() async {
    final session = await _instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  @override
  Stream<({bool begin, bool transient})> get interruptions => Stream.fromFuture(_instance).asyncExpand(
    (s) => s.interruptionEventStream.map((e) => (begin: e.begin, transient: e.type != AudioInterruptionType.unknown)),
  );

  @override
  Stream<void> get becomingNoisy => Stream.fromFuture(_instance).asyncExpand((s) => s.becomingNoisyEventStream);
}
