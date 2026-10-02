import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/sound/soloud_sound_service.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/adhan_sound.dart';
import '../sound/tanbih_synth.dart';

/// Plays a muezzin / tone inside the app (previews in the settings, and the
/// adhan screen when no notification is sounding). Uses the prayer bus,
/// which prayer mute never silences and which plays even with interface
/// sounds switched off.
abstract interface class AdhanAudio {
  /// Starts [sound] (a recording needs its [muezzin] entry). Returns how long
  /// it plays, or null if nothing plays (silent engine, unsupported format).
  Future<Duration?> play(AdhanSoundRef sound, {CustomMuezzin? muezzin});

  Future<void> stop();

  /// Which sound is playing right now (null = none).
  ValueListenable<AdhanSoundRef?> get playing;

  void dispose();
}

/// [AdhanAudio] on the app's flutter_soloud engine.
class SoloudAdhanAudio implements AdhanAudio {
  SoloudAdhanAudio(this.sound, {required this.readFile});

  final SoundService sound;

  /// Reads a recording's bytes (the [MuezzinLibrary]).
  final Future<Uint8List?> Function(CustomMuezzin m) readFile;

  final _playing = ValueNotifier<AdhanSoundRef?>(null);
  final Map<TanbihTone, Future<Uint8List>> _toneCache = {};
  SoundClip? _clip;
  int? _voice;
  Timer? _end;
  int _generation = 0;

  @override
  ValueListenable<AdhanSoundRef?> get playing => _playing;

  @override
  Future<Duration?> play(AdhanSoundRef ref, {CustomMuezzin? muezzin}) async {
    await stop();
    final engine = sound;
    if (engine is! SoloudSoundService) return null;
    final generation = ++_generation;
    Uint8List? bytes;
    Duration? length;
    switch (ref.kind) {
      case AdhanSoundKind.silent:
        return null;
      case AdhanSoundKind.tone:
        final tone = ref.tone!;
        bytes = await _toneCache.putIfAbsent(tone, () => TanbihSynth.renderWavInBackground(tone));
        length = tone.length;
      case AdhanSoundKind.file:
        if (muezzin == null || !muezzin.playableInApp) return null;
        bytes = await readFile(muezzin);
        length = muezzin.length;
    }
    if (bytes == null || generation != _generation) return null;
    final clip = await engine.loadClip('adhan/${ref.key}', bytes);
    if (clip == null || generation != _generation) {
      if (clip != null) unawaited(engine.unloadClip(clip));
      return null;
    }
    final voice = engine.playClip(clip, category: SoundCategory.prayer, bypassGlobalSwitch: true);
    if (voice == null) {
      unawaited(engine.unloadClip(clip));
      return null;
    }
    _clip = clip;
    _voice = voice;
    _playing.value = ref;
    final plays = length ?? clip.duration ?? const Duration(minutes: 4);
    _end = Timer(plays + const Duration(milliseconds: 300), () {
      if (generation == _generation) unawaited(stop());
    });
    return plays;
  }

  @override
  Future<void> stop() async {
    _generation++;
    _end?.cancel();
    _end = null;
    final engine = sound;
    final voice = _voice, clip = _clip;
    _voice = null;
    _clip = null;
    _playing.value = null;
    if (engine is SoloudSoundService) {
      if (voice != null) engine.stopClip(voice, fade: const Duration(milliseconds: 350));
      if (clip != null) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
        await engine.unloadClip(clip);
      }
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    _playing.dispose();
  }
}

/// Records calls (tests, silent environments).
class FakeAdhanAudio implements AdhanAudio {
  final List<AdhanSoundRef> played = [];
  int stops = 0;
  final _playing = ValueNotifier<AdhanSoundRef?>(null);

  @override
  ValueListenable<AdhanSoundRef?> get playing => _playing;

  @override
  Future<Duration?> play(AdhanSoundRef sound, {CustomMuezzin? muezzin}) async {
    played.add(sound);
    if (sound.kind == AdhanSoundKind.silent) return null;
    _playing.value = sound;
    return sound.tone?.length ?? muezzin?.length ?? const Duration(minutes: 3);
  }

  @override
  Future<void> stop() async {
    stops++;
    _playing.value = null;
  }

  @override
  void dispose() => _playing.dispose();
}
