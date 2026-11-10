import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_audio.dart';
import 'recitation_queue.dart';
import 'reciters.dart';

/// Why playback is paused (other than by the user's own tap).
enum RecitationPause {
  /// The user paused.
  user,

  /// The adhan started / the prayer mute engaged. Never resumed on its own.
  prayer,

  /// Another app took the audio (a call, navigation prompt …).
  interruption,

  /// Headphones were unplugged.
  noisy,

  /// The sleep timer ran out.
  sleepTimer,

  /// Loading or playing failed (see [RecitationState.error]).
  error,
}

/// What went wrong.
enum RecitationError {
  /// No connection (and the ayah is not downloaded).
  network,

  /// The audio host has no such file.
  notFound,

  /// The player failed.
  playback,
}

/// The sleep timer.
@immutable
class SleepTimer {
  const SleepTimer.at(DateTime this.at, {this.length}) : afterAyah = false;
  const SleepTimer.afterAyah() : at = null, length = null, afterAyah = true;

  /// Wall-clock end.
  final DateTime? at;

  /// The length the user chose (for showing the choice).
  final Duration? length;

  /// Stop when the current ayah's recitation ends.
  final bool afterAyah;

  @override
  bool operator ==(Object other) =>
      other is SleepTimer && other.at == at && other.afterAyah == afterAyah && other.length == length;

  @override
  int get hashCode => Object.hash(at, afterAyah, length);
}

/// Everything the recitation UI shows. [QuranPlayback] (the shared contract)
/// is derived from it with [toPlayback].
@immutable
class RecitationState {
  const RecitationState({
    this.queue,
    this.index = 0,
    this.item,
    required this.reciter,
    this.playing = false,
    this.loading = false,
    this.speed = 1.0,
    this.pausedBy,
    this.error,
    this.sleep,
    this.localFile = false,
    this.background = false,
  });

  /// The queue being played (null when idle).
  final RecitationQueue? queue;

  /// Position in [queue].
  final int index;

  /// The entry at [index].
  final QueueItem? item;
  final Reciter reciter;
  final bool playing;

  /// Loading or buffering.
  final bool loading;
  final double speed;
  final RecitationPause? pausedBy;
  final RecitationError? error;
  final SleepTimer? sleep;

  /// The entry plays from a downloaded file.
  final bool localFile;

  /// A media notification / lock-screen session is attached.
  final bool background;

  bool get active => queue != null && item != null;
  AyahRef? get current => item?.ayah;
  AyahRange? get range => queue?.range;

  /// Pass over the range (1-based) and the number of passes (0 = endless).
  int get rangePass => item?.rangePass ?? 0;
  int get rangePasses => queue?.repeatRange ?? 0;

  /// Repetition of the current ayah (1-based) and the number per ayah.
  int get ayahPass => item?.ayahPass ?? 0;
  int get ayahPasses => queue?.repeatAyah ?? 0;

  bool get isBasmala => item?.isBasmala ?? false;

  RecitationState copyWith({
    RecitationQueue? queue,
    int? index,
    QueueItem? item,
    Reciter? reciter,
    bool? playing,
    bool? loading,
    double? speed,
    RecitationPause? Function()? pausedBy,
    RecitationError? Function()? error,
    SleepTimer? Function()? sleep,
    bool? localFile,
    bool? background,
  }) => RecitationState(
    queue: queue ?? this.queue,
    index: index ?? this.index,
    item: item ?? this.item,
    reciter: reciter ?? this.reciter,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    speed: speed ?? this.speed,
    pausedBy: pausedBy == null ? this.pausedBy : pausedBy(),
    error: error == null ? this.error : error(),
    sleep: sleep == null ? this.sleep : sleep(),
    localFile: localFile ?? this.localFile,
    background: background ?? this.background,
  );

  /// Idle, keeping the reciter, speed and background flag.
  RecitationState cleared() => RecitationState(reciter: reciter, speed: speed, background: background);

  QuranPlayback toPlayback() => active
      ? QuranPlayback(
          current: current,
          range: range,
          playing: playing,
          loading: loading,
          reciterId: reciter.id,
          basmala: isBasmala,
          ayahPass: ayahPass,
          ayahPasses: ayahPasses,
          rangePass: rangePass,
          rangePasses: rangePasses,
        )
      : QuranPlayback.idle;

  @override
  bool operator ==(Object other) =>
      other is RecitationState &&
      other.queue == queue &&
      other.index == index &&
      other.item == item &&
      other.reciter == reciter &&
      other.playing == playing &&
      other.loading == loading &&
      other.speed == speed &&
      other.pausedBy == pausedBy &&
      other.error == error &&
      other.sleep == sleep &&
      other.localFile == localFile &&
      other.background == background;

  @override
  int get hashCode =>
      Object.hash(queue, index, item, reciter, playing, loading, speed, pausedBy, error, sleep, localFile, background);
}
