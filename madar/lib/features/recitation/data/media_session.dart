import 'package:meta/meta.dart';

/// What the media notification / lock screen shows.
@immutable
class RecitationMediaInfo {
  const RecitationMediaInfo({
    required this.id,
    required this.title,
    required this.reciter,
    required this.album,
    required this.playing,
    this.loading = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.hasNext = true,
    this.hasPrevious = true,
  });

  /// Stable per entry (`quran/<reciter>/<surah>:<ayah>`).
  final String id;

  /// `سورة البقرة · الآية ٢٥٥`.
  final String title;
  final String reciter;

  /// `القرآن الكريم`.
  final String album;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration? duration;
  final double speed;
  final bool hasNext;
  final bool hasPrevious;

  @override
  bool operator ==(Object other) =>
      other is RecitationMediaInfo &&
      other.id == id &&
      other.title == title &&
      other.reciter == reciter &&
      other.album == album &&
      other.playing == playing &&
      other.loading == loading &&
      other.position == position &&
      other.duration == duration &&
      other.speed == speed &&
      other.hasNext == hasNext &&
      other.hasPrevious == hasPrevious;

  @override
  int get hashCode =>
      Object.hash(id, title, reciter, album, playing, loading, position, duration, speed, hasNext, hasPrevious);
}

/// Localised labels of the notification's buttons.
@immutable
class RecitationMediaLabels {
  const RecitationMediaLabels({
    required this.play,
    required this.pause,
    required this.next,
    required this.previous,
    required this.stop,
  });

  final String play, pause, next, previous, stop;

  static const english = RecitationMediaLabels(
    play: 'Play',
    pause: 'Pause',
    next: 'Next ayah',
    previous: 'Previous ayah',
    stop: 'Stop',
  );
}

/// The commands a media session sends back (notification buttons, lock
/// screen, headset keys, Bluetooth).
abstract class RecitationMediaControls {
  Future<void> resume();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> stop();
  Future<void> seekWithin(Duration position);
}

/// The system media session (audio_service in the app). Without one,
/// playback still works while Madar is open (foreground-only).
abstract class RecitationMediaSession {
  /// Wires the session's buttons to the player.
  void attach(RecitationMediaControls controls);

  /// Shows [info]; null removes the notification (stopped).
  void update(RecitationMediaInfo? info, RecitationMediaLabels labels);
}

/// Starts the media session on first use (never before the user plays).
abstract class RecitationBackground {
  /// The session, or null when background playback is unavailable (the
  /// activity is not wired for audio_service, tests, …).
  Future<RecitationMediaSession?> start();
}

/// No background playback (tests, the foreground-only fallback).
class NoRecitationBackground implements RecitationBackground {
  const NoRecitationBackground();

  @override
  Future<RecitationMediaSession?> start() async => null;
}
