import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ayah.dart';

/// What the Quran player is doing, for highlighting and mini-players.
class QuranPlayback {
  const QuranPlayback({this.current, this.range, this.playing = false, this.loading = false, this.reciterId});

  /// The ayah being recited (null when idle).
  final AyahRef? current;

  /// The queued range (null when idle).
  final AyahRange? range;
  final bool playing;
  final bool loading;
  final String? reciterId;

  static const idle = QuranPlayback();
}

/// Recitation playback as seen by other features (reader highlighting,
/// Hifz listening drills, wird). Implemented by lib/features/recitation,
/// which owns [quranAudioProvider]'s body.
abstract class QuranAudio {
  /// Current playback state; emits on every ayah change.
  Stream<QuranPlayback> get playback;
  QuranPlayback get value;

  /// Plays [range] (defaults to one ayah) with the user's reciter, repeating
  /// each ayah [repeatAyah] times and the whole range [repeatRange] times.
  Future<void> play(AyahRange range, {int repeatAyah = 1, int repeatRange = 1});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

/// The app's [QuranAudio]. The recitation feature replaces the body with the
/// real player; the default is silent (safe for tests and for features built
/// before recitation is wired).
final quranAudioProvider = Provider<QuranAudio>((ref) => SilentQuranAudio());

/// A no-op [QuranAudio].
class SilentQuranAudio implements QuranAudio {
  @override
  Stream<QuranPlayback> get playback => const Stream.empty();
  @override
  QuranPlayback get value => QuranPlayback.idle;
  @override
  Future<void> play(AyahRange range, {int repeatAyah = 1, int repeatRange = 1}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
}
