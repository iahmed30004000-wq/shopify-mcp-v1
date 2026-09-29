import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recitation/application/recitation_providers.dart' show recitationPlayerProvider;
import 'ayah.dart';

/// What the Quran player is doing, for highlighting and mini-players.
class QuranPlayback {
  const QuranPlayback({
    this.current,
    this.range,
    this.playing = false,
    this.loading = false,
    this.reciterId,
    this.basmala = false,
    this.ayahPass = 0,
    this.ayahPasses = 0,
    this.rangePass = 0,
    this.rangePasses = 0,
  });

  /// The ayah being recited (null when idle). While [basmala] is true it is
  /// the ayah the basmala opens (ayah 1 of the surah).
  final AyahRef? current;

  /// The queued range (null when idle).
  final AyahRange? range;
  final bool playing;
  final bool loading;
  final String? reciterId;

  /// The basmala before [current] is being recited.
  final bool basmala;

  /// Repetition of [current] (1-based) out of [ayahPasses]; 0 when idle.
  final int ayahPass;
  final int ayahPasses;

  /// Pass over [range] (1-based) out of [rangePasses] (0 = until stopped).
  final int rangePass;
  final int rangePasses;

  bool get isIdle => current == null;

  static const idle = QuranPlayback();

  @override
  bool operator ==(Object other) =>
      other is QuranPlayback &&
      other.current == current &&
      other.range == range &&
      other.playing == playing &&
      other.loading == loading &&
      other.reciterId == reciterId &&
      other.basmala == basmala &&
      other.ayahPass == ayahPass &&
      other.ayahPasses == ayahPasses &&
      other.rangePass == rangePass &&
      other.rangePasses == rangePasses;

  @override
  int get hashCode =>
      Object.hash(current, range, playing, loading, reciterId, basmala, ayahPass, ayahPasses, rangePass, rangePasses);

  @override
  String toString() => isIdle
      ? 'QuranPlayback.idle'
      : 'QuranPlayback($current${basmala ? ' basmala' : ''}, '
            '${playing ? 'playing' : 'paused'}${loading ? ', loading' : ''}, $ayahPass/$ayahPasses, $rangePass/$rangePasses)';
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
  /// With neither count the user's repeat defaults apply; with either, the
  /// counts are taken as asked (a missing one is 1) – so an explicit
  /// `repeatAyah: 1` really is once.
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

/// The app's [QuranAudio]: the recitation player (lib/features/recitation).
/// Nothing touches the audio plugins, the network or the database until
/// something calls [QuranAudio.play]; tests that never play can use it as
/// is, tests that do override it (e.g. with [SilentQuranAudio] or a fake).
///
/// Semantics of [QuranAudio.play] in the recitation player: no counts apply
/// the user's repeat defaults from the recitation settings; given counts are
/// taken as asked (a missing one is 1); `repeatRange: 0` repeats the range
/// until stopped. The basmala precedes ayah 1 of every surah but
/// al-Fatihah and at-Tawbah. The full player is `recitationPlayerProvider`.
final quranAudioProvider = Provider<QuranAudio>((ref) => ref.watch(recitationPlayerProvider));

/// A no-op [QuranAudio].
class SilentQuranAudio implements QuranAudio {
  @override
  Stream<QuranPlayback> get playback => const Stream.empty();
  @override
  QuranPlayback get value => QuranPlayback.idle;
  @override
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
}
