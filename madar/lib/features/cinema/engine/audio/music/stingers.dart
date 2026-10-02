import 'dart:typed_data';

import '../../core/audio.dart';
import '../../core/era_skin.dart';
import '../synth/renderer.dart';
import 'cue_builder.dart';
import 'score.dart';

/// The clips of one stinger: a tonal part (major / minor, rendered on the
/// key's root; the director transposes it onto the chord that is sounding)
/// and an untransposed drum part. Any may be null.
final class StingerClips {
  const StingerClips({this.major, this.minor, this.drums, this.tonal = true});

  final Uint8List? major;
  final Uint8List? minor;
  final Uint8List? drums;

  /// False when the tonal part must not be transposed (drum-only or
  /// fixed-key stingers).
  final bool tonal;

  int get bytes => (major?.length ?? 0) + (identical(minor, major) ? 0 : (minor?.length ?? 0)) + (drums?.length ?? 0);
}

/// Every stinger of one era, keyed by [Stinger].
final class StingerKit {
  const StingerKit(this.keyPc, this.clips);

  /// Pitch class the tonal parts were rendered in.
  final int keyPc;
  final Map<Stinger, StingerClips> clips;

  int get bytes => clips.values.fold(0, (a, c) => a + c.bytes);
}

/// The band each style uses for its stingers.
final class _Band {
  const _Band(this.stab, this.stab2, this.mallet, this.low, this.lead, {this.snare = Inst.snare, this.cymbal = Inst.crash, this.tom = Inst.tomHigh});

  final Inst stab, stab2, mallet, low, lead, snare, cymbal, tom;
}

_Band _bandFor(MusicStyle s) => switch (s) {
  MusicStyle.ragtime => const _Band(Inst.honkyPiano, Inst.honkyPiano, Inst.xylophone, Inst.honkyPiano, Inst.violin, tom: Inst.woodblock),
  MusicStyle.swing => const _Band(Inst.trumpet, Inst.trombone, Inst.xylophone, Inst.tuba, Inst.clarinet, cymbal: Inst.choke, tom: Inst.templeBlock),
  MusicStyle.noirJazz => const _Band(Inst.trombone, Inst.piano, Inst.vibes, Inst.uprightBass, Inst.tenorSax, cymbal: Inst.ride),
  MusicStyle.bigBand => const _Band(Inst.trumpet, Inst.trombone, Inst.marimba, Inst.uprightBass, Inst.altoSax),
  MusicStyle.funk => const _Band(Inst.trumpet, Inst.tenorSax, Inst.clav, Inst.electricBass, Inst.wahGuitar),
  MusicStyle.synthwave => const _Band(Inst.synthBrass, Inst.synthPad, Inst.synthArp, Inst.synthBass, Inst.synthLead, snare: Inst.gatedSnare, tom: Inst.tomLow),
};

/// Composes and renders every [Stinger] for an era (pure; isolate-safe).
StingerKit renderStingerKit(ScoreStyle style, {int seed = 1}) {
  final band = _bandFor(style.style);
  final key = style.rootMidi;
  final bpm = style.tempo.clamp(90.0, 140.0);
  final sound = cueSoundFor(style, roomSize: 0.5, damping: 0.5, wet: 0.22);
  final clips = <Stinger, StingerClips>{};
  for (final st in Stinger.values) {
    final drums = _drums(st, band, key);
    final major = _tonal(st, band, key, false);
    final seconds = switch (st) {
      Stinger.bossIntro => 4.5,
      Stinger.pickup || Stinger.hit || Stinger.rimshot => 1.6,
      _ => 3.0,
    };
    if (major.isEmpty) {
      final parts = renderParts([drums], style: style.style, bpm: bpm, sound: sound, loudnessDb: -17, seed: seed + st.index, maxSeconds: seconds);
      clips[st] = StingerClips(drums: parts.first, tonal: false);
      continue;
    }
    final loud = switch (st) {
      Stinger.pickup => -19.0,
      Stinger.hit => -16.0,
      _ => -15.0,
    };
    // Only chords with a third need a minor twin.
    final twin = st == Stinger.pickup || st == Stinger.sceneStart || st == Stinger.bossDefeat || st == Stinger.victory;
    final parts = renderParts(
      [major, if (twin) _tonal(st, band, key, true), if (drums.isNotEmpty) drums],
      style: style.style,
      bpm: bpm,
      sound: sound,
      loudnessDb: loud,
      seed: seed + st.index,
      maxSeconds: seconds,
      measure: [0, if (drums.isNotEmpty) (twin ? 2 : 1)],
    );
    clips[st] = StingerClips(major: parts[0], minor: twin ? parts[1] : parts[0], drums: drums.isEmpty ? null : parts.last);
  }
  return StingerKit(key % 12, clips);
}

List<NoteEvent> _chord(Inst i, double beat, double dur, int root, List<int> ivs, double vel, {int fx = 0}) => [
  for (final iv in ivs) NoteEvent(beat, dur, (root + iv).toDouble(), vel, i, fx: fx),
];

List<NoteEvent> _tonal(Stinger st, _Band b, int key, bool minor) {
  final third = minor ? 3 : 4;
  final triad = [0, third, 7, 12];
  final hi = key + 12;
  switch (st) {
    case Stinger.sceneStart:
      return [
        ..._chord(b.stab, 0, 0.25, hi, triad, 0.75),
        ..._chord(b.stab, 0.5, 1.6, hi, triad, 0.85, fx: Art.vibrato),
        ..._chord(b.stab2, 0.5, 1.6, key, [0, 7, 12], 0.7),
        NoteEvent(0.5, 1.6, key - 12.0, 0.8, b.low),
      ];
    case Stinger.hit:
      return [
        ..._chord(b.stab, 0, 0.35, hi, [0, 1, 6, 12], 0.85, fx: Art.fall),
        ..._chord(b.stab2, 0, 0.35, key, [0, 6], 0.7),
        NoteEvent(0, 0.3, key - 12.0, 0.8, b.low, fx: Art.staccato),
      ];
    case Stinger.pickup:
      return [
        for (final (i, iv) in [0, third, 7, 12, 12 + third].indexed) NoteEvent(i * 0.25, 0.3, hi + 12.0 + iv, 0.5 + i * 0.08, b.mallet),
      ];
    case Stinger.bossIntro:
      return [
        NoteEvent(0, 3, key - 12.0, 0.6, Inst.timpani, fx: Art.trem),
        ..._chord(b.stab2, 0, 3, key, [0, 3, 6, 11], 0.5, fx: Art.trem),
        ..._chord(b.stab, 3, 1.5, key, [0, 3, 6, 12], 0.9, fx: Art.fall),
        NoteEvent(3, 1.5, key - 12.0, 0.85, b.low),
      ];
    case Stinger.bossDefeat:
      return [
        for (var i = 0; i < 8; i++) NoteEvent(i * 0.125, 0.15, hi + const [0, 2, 4, 5, 7, 9, 11, 12][i] + 0.0, 0.5 + i * 0.05, b.mallet),
        ..._chord(b.stab, 1, 2.5, hi, [0, 4, 7, 12], 0.9, fx: Art.vibrato),
        ..._chord(b.stab2, 1, 2.5, key, [0, 4, 7], 0.75),
        NoteEvent(1, 2.5, key - 12.0, 0.85, b.low),
      ];
    case Stinger.victory:
      return [
        ..._chord(b.stab, 0, 0.3, hi, [4, 7, 12], 0.8),
        ..._chord(b.stab, 0.75, 2.2, hi, [0, 4, 7, 12], 0.9, fx: Art.vibrato),
        NoteEvent(0.75, 2.2, hi + 16.0, 0.7, b.lead, fx: Art.vibrato),
        ..._chord(b.stab2, 0.75, 2.2, key, [0, 7], 0.7),
        NoteEvent(0.75, 2.2, key - 12.0, 0.8, b.low),
      ];
    case Stinger.defeat:
      return [
        NoteEvent(0, 0.9, hi + 7.0 - 12, 0.7, b.stab2, fx: Art.vibrato),
        NoteEvent(1, 2.0, hi + 3.0 - 12, 0.7, b.stab2, fx: Art.vibrato | Art.fall),
        NoteEvent(1, 2.0, key - 12.0, 0.7, b.low),
      ];
    case Stinger.drumroll || Stinger.rimshot:
      return const [];
  }
}

List<NoteEvent> _drums(Stinger st, _Band b, int key) {
  NoteEvent d(Inst i, double beat, double vel, {int fx = 0, double pitch = 0}) => NoteEvent(beat, 0.2, pitch, vel, i, fx: fx);
  switch (st) {
    case Stinger.sceneStart:
      return [d(b.snare, 0, 0.5), d(b.snare, 0.08, 0.7), d(Inst.kick, 0.5, 0.8), d(b.cymbal, 0.5, 0.7)];
    case Stinger.hit:
      return [d(Inst.kick, 0, 0.9), d(Inst.choke, 0, 0.7)];
    case Stinger.pickup:
      return const [];
    case Stinger.bossIntro:
      return [d(Inst.gong, 0, 0.7), d(Inst.kick, 3, 0.9), d(Inst.crash, 3, 0.8)];
    case Stinger.bossDefeat:
      return [for (var i = 0; i < 8; i++) d(b.snare, i * 0.125, 0.3 + i * 0.06), d(Inst.kick, 1, 0.9), d(Inst.crash, 1, 0.9)];
    case Stinger.victory:
      return [d(b.snare, 0, 0.6), d(b.snare, 0.5, 0.5), d(Inst.kick, 0.75, 0.9), d(Inst.crash, 0.75, 0.8)];
    case Stinger.defeat:
      return [d(Inst.kick, 1, 0.5), d(b.cymbal == Inst.choke ? Inst.choke : Inst.ride, 1, 0.3)];
    case Stinger.drumroll:
      return [
        for (var i = 0; i < 24; i++) d(b.snare, i / 12.0, 0.25 + 0.6 * i / 24, fx: i.isOdd ? Art.ghost : 0),
        d(Inst.kick, 2, 0.9),
        d(Inst.crash, 2, 0.9),
      ];
    case Stinger.rimshot:
      return [d(b.tom, 0, 0.7), d(b.snare, 0.5, 0.75), d(Inst.kick, 0.5, 0.7), d(b.cymbal == Inst.ride ? Inst.ride : Inst.crash, 1, 0.7)];
  }
}
