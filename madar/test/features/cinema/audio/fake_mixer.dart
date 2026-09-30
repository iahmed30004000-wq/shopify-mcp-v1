import 'dart:typed_data';

import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/music/stingers.dart';
import 'package:madar/features/cinema/engine/audio/runtime/cue_source.dart';
import 'package:madar/features/cinema/engine/audio/runtime/mixer.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';
import 'package:madar/features/cinema/engine/core/era_skin.dart';

/// A voice as the fake mixer saw it.
class FakeVoice {
  FakeVoice(this.id, this.source, this.volume, this.pan, this.speed, this.loop, this.at, this.protect);

  final int id;
  final int source;
  final double volume;
  final double pan;
  final double speed;
  final bool loop;
  final Duration? at;
  final bool protect;
  final List<({double to, Duration over, Duration? at, bool thenStop})> fades = [];
  bool stopped = false;

  /// The volume it is heading to (last fade's target, else the start volume).
  double get target => fades.isEmpty ? volume : fades.last.to;
  bool get stopping => stopped || fades.any((f) => f.thenStop);
}

/// A scripted [CinemaMixer]: a manual engine clock, recorded calls.
class FakeCinemaMixer implements CinemaMixer {
  bool live = true;
  double gain = 1;
  Duration clock = const Duration(seconds: 10);
  final Map<int, (String, Uint8List, bool)> sources = {};
  final Map<int, FakeVoice> voices = {};
  final List<String> calls = [];
  int _src = 0, _voice = 0;

  void advance(Duration d) => clock += d;

  String nameOf(int source) => sources[source]?.$1 ?? '?';

  /// Live (not stopping) voices whose source name contains [part].
  List<FakeVoice> active([String part = '']) =>
      voices.values.where((v) => !v.stopping && nameOf(v.source).contains(part)).toList();

  @override
  bool get isLive => live;

  @override
  double get gamesGain => gain;

  @override
  Duration get now => clock;

  @override
  Future<int?> load(String name, Uint8List wav, {bool stream = false}) async {
    if (!live) return null;
    final id = _src++;
    sources[id] = (name, wav, stream);
    calls.add('load $name');
    return id;
  }

  @override
  void unload(int source) {
    sources.remove(source);
    calls.add('unload $source');
  }

  @override
  int play(int source, {double volume = 1, double pan = 0, double speed = 1, bool loop = false, Duration? at, bool protect = false}) {
    if (!live || !sources.containsKey(source)) return -1;
    final id = _voice++;
    voices[id] = FakeVoice(id, source, volume, pan, speed, loop, at, protect);
    calls.add('play ${nameOf(source)}');
    return id;
  }

  @override
  void fade(int voice, double to, Duration over, {Duration? at, bool thenStop = false}) {
    voices[voice]?.fades.add((to: to, over: over, at: at, thenStop: thenStop));
  }

  @override
  void stop(int voice) {
    voices[voice]?.stopped = true;
    calls.add('stop $voice');
  }
}

Uint8List tinyWav({int frames = 64, int sampleRate = 22050, int channels = 1}) =>
    Wav.encodePcm16([for (var c = 0; c < channels; c++) Float64List(frames)], sampleRate: sampleRate);

/// A [CueSource] that answers instantly with tiny clips and fixed timing:
/// 120 bpm (0.5 s beats), 4/4, a 1-bar intro and a 2-bar loop whose chords
/// are I (bar 1) and V (bar 2).
class FakeCueSource implements CueSource {
  final List<String> requests = [];

  /// Bytes per rendered cue (drives the LRU budget).
  int cueBytes = 1000;

  static CueInfo infoFor(MusicMood mood, {bool loops = true}) => CueInfo(
    style: MusicStyle.swing,
    mood: mood,
    sampleRate: 22050,
    beatsPerBar: 4,
    introSeconds: 2,
    introBeats: 4,
    loopSeconds: 4,
    loopBeats: 8,
    loops: loops,
    stems: const [StemSpec('bed'), StemSpec('lead', layer: 0.3), StemSpec('hot', layer: 0.65, gain: 0.8)],
    chords: const [ChordMark(-4, 7, false), ChordMark(0, 0, false), ChordMark(4, 7, false)],
    keyPc: 0,
  );

  @override
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed) async {
    requests.add('cue ${mood.name}');
    final jingle = mood == MusicMood.victory || mood == MusicMood.defeat;
    final info = infoFor(mood, loops: !jingle);
    final half = cueBytes ~/ 6;
    return RenderedCue(info, [
      for (final s in info.stems) RenderedStem(s, tinyWav(frames: half ~/ 2), tinyWav(frames: half ~/ 2)),
    ]);
  }

  @override
  Future<StingerKit> renderStingers(ScoreStyle style, int seed) async {
    requests.add('stingers');
    return StingerKit(0, {
      for (final s in Stinger.values)
        s: s == Stinger.drumroll || s == Stinger.rimshot
            ? StingerClips(drums: tinyWav(), tonal: false)
            : StingerClips(major: tinyWav(), minor: tinyWav(), drums: tinyWav()),
    });
  }

  @override
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed) async {
    requests.add('sfx ${era.name}');
    return {
      for (final s in CinemaSound.values) sfxKey(s): tinyWav(frames: 2205), // 100 ms
      for (final s in CinemaSfx.values) extraKey(s): tinyWav(frames: 2205),
    };
  }
}
