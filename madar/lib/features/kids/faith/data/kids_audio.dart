// Recitation for children: ONLY what the parent has already downloaded.
//
// The app's recitation player streams an ayah when its file is not on the
// phone. The kids section makes no network call at all, so this wrapper checks
// that every file of the range is local BEFORE asking the player, and refuses
// otherwise (the screen then shows «الصوت مش محمّل»). It never starts a
// download and holds no HTTP client; a test pins both.
import '../../../../core/quran/ayah.dart';
import '../../../../core/quran/quran_audio.dart';
import '../../../recitation/data/local_files.dart';
import '../../../recitation/domain/reciters.dart';

abstract interface class KidsAyahAudio {
  /// The reciter the parent chose in the Quran section.
  Reciter get reciter;

  /// Whether every file of [surah] (ayat and the basmala) is on the phone.
  Future<bool> isSurahOnPhone(int surah, {required int ayahCount});

  Stream<QuranPlayback> get playback;
  QuranPlayback get value;

  /// Plays [range] (inside one surah) from local files only; false, and
  /// nothing played, when any file is missing.
  Future<bool> play(AyahRange range);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

/// [KidsAyahAudio] over the app's player and the downloaded files.
class LocalOnlyKidsAudio implements KidsAyahAudio {
  LocalOnlyKidsAudio({required this._files, required this._audio, required this._reciter});

  final LocalRecitationFiles _files;
  final QuranAudio _audio;
  final Reciter Function() _reciter;

  @override
  Reciter get reciter => _reciter();

  bool _hasAyah(AyahRef a) => _files.localFile(reciter, a) != null;

  bool _hasBasmalaIfNeeded(int surah) =>
      !EveryAyah.surahNeedsBasmala(surah) || _files.localFile(reciter, AyahRef(surah, 1), basmala: true) != null;

  @override
  Future<bool> isSurahOnPhone(int surah, {required int ayahCount}) async {
    await _files.prepare();
    if (!_hasBasmalaIfNeeded(surah)) return false;
    for (var a = 1; a <= ayahCount; a++) {
      if (!_hasAyah(AyahRef(surah, a))) return false;
    }
    return true;
  }

  @override
  Stream<QuranPlayback> get playback => _audio.playback;

  @override
  QuranPlayback get value => _audio.value;

  @override
  Future<bool> play(AyahRange range) async {
    await _files.prepare();
    final first = range.first;
    if (first.ayah == 1 && !_hasBasmalaIfNeeded(first.surah)) return false;
    for (var a = first.ayah; a <= range.last.ayah; a++) {
      if (!_hasAyah(AyahRef(first.surah, a))) return false;
    }
    await _audio.play(range, repeatAyah: 1, repeatRange: 1);
    return true;
  }

  @override
  Future<void> pause() => _audio.pause();
  @override
  Future<void> resume() => _audio.resume();
  @override
  Future<void> stop() => _audio.stop();
}
