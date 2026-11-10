import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Plays a recording from a file, behind a small interface (a fake in tests).
abstract interface class VoicePlayer {
  /// Opens [path]. Throws when the file is missing or cannot be decoded.
  Future<void> load(String path);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();

  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<bool> get playing;

  /// Emits once each time the recording plays to its end.
  Stream<void> get completed;

  Future<void> dispose();
}

/// `just_audio` over a local file. just_audio asks Android for audio focus
/// itself and pauses when a call comes in.
class JustAudioVoicePlayer implements VoicePlayer {
  JustAudioVoicePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Duration?> get duration => _player.durationStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Stream<void> get completed => _player.processingStateStream.where((s) => s == ProcessingState.completed);

  @override
  Future<void> dispose() => _player.dispose();
}
