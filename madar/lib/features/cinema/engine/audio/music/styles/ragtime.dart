import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1920s silent-film piano: a honky-tonk upright with a stride left hand
/// and a syncopated right hand, a pit drummer and a violin for the hot
/// layer, theatre organ for the villain. Original material only: every
/// line comes from the grammar (no quotations).
final class RagtimeComposer implements StyleComposer {
  const RagtimeComposer();

  // One-bar 16th-grid right-hand cells: 16th–8th–16th syncopations, ties
  // across the beat, the cakewalk figure.
  static const _ragCells = [
    'xx-xxx-xx-x-x---',
    'x-xx-xx-x-x-x-x-',
    'xx-x-xx-xx-x----',
    'x--xx-x-x--xx-x-',
    'x-x-xx-xx-x-x-x-',
    '-xx-x-xx-x-xx---',
    'xx-x-x-xx-x-x-x-',
  ];

  static const _marchCells = ['x--xx--xx--xx---', 'x--xx--xx-------', 'x-x-x--xx--xx---', 'x-------x--xx---'];

  static const _waltzCells = ['x-----x-x-x-', 'x-----x-----', 'x--x-xx-----', 'x-x-x-x-----', 'x-----------', 'x---x---x---'];

  static const _counterCells = ['x-------x-------', 'x-----x-x-------', 'x---------------', 'x-------x---x---'];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _waltz(s, seed),
    MusicMood.tension => _hurry(s, seed),
    MusicMood.boss => _villain(s, seed),
    MusicMood.victory => _jingle(s, seed, won: true),
    MusicMood.defeat => _jingle(s, seed, won: false),
    _ => _rag(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {int bpb = 4, double room = 0.35}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    bpb: bpb,
    swing: s.swing,
    swing16: true,
    sound: cueSoundFor(s, roomSize: room, damping: 0.6, wet: 0.22),
    seed: seed * 13 + mood.index,
  );

  CueScore _rag(MusicMood mood, ScoreStyle s, int seed) {
    final title = mood == MusicMood.title;
    final action = mood == MusicMood.action;
    final b = _builder(mood, s, seed, title ? 0.92 : (action ? 1.24 : 1.0));
    b.setIntro(title ? 'V7 | V7' : 'V7', title ? 2 : 1);
    b.setLoop(
      b.pick(const [
        'I | I | VI7 | VI7 | II7 | V7 | I VI7 | II7 V7',
        'I | I7 | IV | #IVo7 | I | VI7 | II7 V7 | I V7',
        'I | III7 | VI7 | II7 | V7 | I | II7 V7 | I V7',
        'I | Io7 | ii7 V7 | I | IV | iv6 | I VI7 | II7 V7',
      ]),
      8,
    );
    final lh = b.stem(const StemSpec('bed', reverb: 0.1, pan: -0.1));
    final rh = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.1, pan: 0.1));
    final pit = b.stem(const StemSpec('hot', layer: 0.66, reverb: 0.16, pan: 0.3, gain: 0.62));

    _strideLeftHand(b, lh, b.loopStart, b.loopBars, vel: action ? 0.62 : 0.55);
    final mel = b.melody(
      MelodySpec(
        lo: 67,
        hi: 88,
        rhythms: title ? _marchCells : _ragCells,
        form: b.pick(const ['ABAC', 'AABA', 'ABAB']),
        repeat: 0.12,
        chromatic: 0.18,
      ),
    );
    _rightHand(b, rh, mel, vel: 0.62);

    // Pit drummer and violin for the hot layer.
    b.pattern(Inst.kick, const ['x.......x.......'], stem: pit, vel: 0.38);
    b.pattern(Inst.snare, action ? const ['x.x.x.x.x.x.x.x.', 'x.x.x.x.x.x.xxxx'] : const ['g.x.g.x.g.x.g.x.'], stem: pit, vel: 0.26);
    b.pattern(Inst.woodblock, const ['x..x..x.x..x..x.', 'x..x..x.x.x.x...'], stem: pit, vel: 0.22);
    b.phraseCymbals(Inst.choke, stem: pit, vel: 0.45);
    final counter = b.melody(MelodySpec(lo: 64, hi: 81, rhythms: _counterCells, form: 'AB', stepBias: 0.85), salt: 7);
    b.notes(Inst.violin, counter, stem: pit, vel: 0.3, fx: Art.vibrato, gain: 0.5);

    // Intro: a rising chromatic run over the dominant, then the band hits.
    final v7root = b.key + 7;
    if (title) {
      for (var i = 0; i < 16; i++) {
        b.note(Inst.honkyPiano, i * 0.25, 0.23, v7root - 12 + i, 0.4 + i * 0.02, stem: rh);
      }
      _tremoloBass(b, lh, 0, 1, v7root - 24, 0.5);
      b.note(Inst.honkyPiano, 4, 0.5, v7root - 24, 0.8, stem: lh);
      b.note(Inst.honkyPiano, 4, 0.5, v7root - 12, 0.8, stem: lh);
      for (final p in [v7root + 4, v7root + 7, v7root + 10, v7root + 12]) {
        b.note(Inst.honkyPiano, 4, 0.5, p, 0.8, stem: rh);
        b.note(Inst.honkyPiano, 6, 1.5, p, 0.85, stem: rh);
      }
      b.note(Inst.honkyPiano, 6, 1.5, v7root - 24, 0.8, stem: lh);
      b.note(Inst.crash, 6, 0.5, 0, 0.5, stem: pit);
      b.note(Inst.snare, 7.5, 0.1, 0, 0.5, stem: pit);
    } else {
      for (var i = 0; i < 12; i++) {
        b.note(Inst.honkyPiano, i * 0.25, 0.23, v7root - 5 + i, 0.4 + i * 0.03, stem: rh);
      }
      b.note(Inst.honkyPiano, 3.25, 0.2, v7root + 4, 0.7, stem: rh);
      b.note(Inst.honkyPiano, 3.5, 0.4, v7root + 7, 0.75, stem: rh);
      _strideLeftHand(b, lh, 0, 1, vel: 0.5);
      b.note(Inst.snare, 3.5, 0.1, 0, 0.45, stem: pit);
    }
    return b.build();
  }

  CueScore _waltz(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 1.08, bpb: 3, room: 0.45);
    b.setIntro('V7', 1);
    b.setLoop(
      b.pick(const [
        'I | vi | ii7 | V7 | I | IV | ii7 V7 | I',
        'I | I | IV | iv6 | I | VI7 | II7 V7 | I',
        'I | Io7 | ii7 | V7 | iii7 | VI7 | II7 | V7',
      ]),
      8,
    );
    final lh = b.stem(const StemSpec('bed', reverb: 0.16));
    final rh = b.stem(const StemSpec('lead', layer: 0.25, reverb: 0.16));
    final vln = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.22, pan: 0.3, gain: 0.8));
    for (var bar = -1; bar < b.loopBars; bar++) {
      final beat = b.loopStart + bar * 3;
      final chord = b.chart.at(beat);
      final bass = chord.rootNear(b.key, 43) + (bar.isOdd ? 7 : 0);
      b.note(Inst.piano, beat, 0.9, bass > 52 ? bass - 12 : bass, 0.5, stem: lh);
      for (final beatOff in const [1, 2]) {
        for (final p in chord.closeVoicing(b.key, 55, size: 3)) {
          b.note(Inst.piano, beat + beatOff, 0.5, p, 0.3, stem: lh);
        }
      }
    }
    final mel = b.melody(MelodySpec(lo: 67, hi: 84, rhythms: _waltzCells, steps: 12, form: 'ABAC', stepBias: 0.8, leap: 0.15));
    b.notes(Inst.piano, mel, stem: rh, vel: 0.5);
    b.notes(Inst.violin, mel, stem: vln, vel: 0.42, transpose: 12, fx: Art.vibrato);
    b.note(Inst.piano, 2, 1, b.key + 7 + 4, 0.4, stem: rh);
    return b.build();
  }

  CueScore _hurry(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.tension, s, seed, 1.18);
    b.setIntro('V7', 1);
    b.setLoop(b.pick(const ['i | io7 | i | io7 | iv | #ivo7 | V7 | V7', 'i | iv | io7 | i | bVI7 | #ivo7 | V7 | V7']), 8);
    final lh = b.stem(const StemSpec('bed', reverb: 0.1));
    final rh = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.1));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.2, gain: 0.85));
    for (var bar = -1; bar < b.loopBars; bar++) {
      final start = b.loopStart + bar * 4;
      final root = b.chart.at(start).rootNear(b.key, 38);
      _tremoloBass(b, lh, start, 1, root, 0.42);
    }
    // Rising chromatic sequences in octaves, a falling run to loop back.
    var p = b.key + b.pick(const [3, 0, 7, -2]);
    // Sequence figures: chromatic climb, neighbour turn, broken third.
    final figure = b.pick(const [
      [0, 1, 2, 3],
      [0, 1, 0, 3],
      [0, 3, 1, 4],
    ]);
    for (var bar = 0; bar < b.loopBars; bar++) {
      final start = b.loopStart + bar * 4;
      if (bar == b.loopBars - 1) {
        for (var i = 0; i < 16; i++) {
          final q = b.key + 19 - i;
          b.note(Inst.honkyPiano, start + i * 0.25, 0.22, q, 0.5 + (i.isEven ? 0.08 : 0), stem: rh);
        }
        continue;
      }
      for (var half = 0; half < 2; half++) {
        final chord = b.chart.at(start + half * 2);
        final tones = chord.tonesIn(b.key, 62, 84, withExtensions: false);
        final t = tones.isEmpty ? p : tones.reduce((a, c) => (a - p).abs() <= (c - p).abs() ? a : c);
        for (var i = 0; i < 4; i++) {
          final beat = start + half * 2 + i * 0.5;
          b.note(Inst.honkyPiano, beat, 0.45, t + figure[i], 0.55 + i * 0.05, stem: rh);
          b.note(Inst.honkyPiano, beat, 0.45, t + figure[i] - 12, 0.45, stem: rh);
        }
        p = t + 3;
      }
      if (p > 80) p -= 12;
    }
    b.note(Inst.timpani, b.loopStart, 4, b.key - 12, 0.55, stem: hot, fx: Art.trem);
    b.note(Inst.timpani, b.loopStart + 16, 4, b.key - 7, 0.6, stem: hot, fx: Art.trem);
    b.note(Inst.timpani, b.loopStart + 24, 8, b.key - 17, 0.65, stem: hot, fx: Art.trem);
    b.pattern(Inst.snare, const ['x.x.x.x.x.x.x.x.', 'xxxxxxxxxxxxxxxx'], stem: hot, vel: 0.3);
    b.phraseCymbals(Inst.crash, stem: hot, vel: 0.35);
    for (var i = 0; i < 8; i++) {
      b.note(Inst.honkyPiano, i * 0.5, 0.45, b.key + 7 - 12 + i, 0.4 + i * 0.05, stem: rh);
    }
    return b.build();
  }

  CueScore _villain(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.boss, s, seed, 0.84, room: 0.6);
    b.setIntro('i', 1);
    b.setLoop(b.pick(const ['i | i | bVI7 | V7 | i | iv | #ivo7 | V7', 'i | bII | V7 | i | iv | bVI7 | io7 | V7']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.25));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.18, gain: 0.85));
    final bass = riffBass(b.chart, b.loopStart, b.loopBars, b.key, const ['R.....R.R.....F.', 'R.....R.R...R.b.'], base: 46);
    b.notes(Inst.honkyPiano, bass, stem: bed, vel: 0.7);
    b.notes(Inst.honkyPiano, bass, stem: bed, vel: 0.6, transpose: -12);
    addPad(b.ev, Inst.theatreOrgan, b.chart, b.key, start: b.loopStart, beats: b.loopBeats, floor: 53, size: 3, stem: bed, vel: 0.3);
    final mel = b.melody(
      const MelodySpec(
        lo: 62,
        hi: 81,
        rhythms: ['x-------x---x---', 'x-----------x-x-', 'x-------x-------', 'x---x---x-------'],
        form: 'ABAC',
        stepBias: 0.75,
      ),
    );
    b.notes(Inst.theatreOrgan, mel, stem: lead, vel: 0.6);
    // Right-hand diminished tremolo (hot) + timpani strokes.
    for (var bar = 0; bar < b.loopBars; bar++) {
      final start = b.loopStart + bar * 4;
      final v = b.chart.at(start).closeVoicing(b.key, 67, size: 3);
      for (var i = 0; i < 16; i++) {
        b.note(Inst.honkyPiano, start + i * 0.25, 0.2, i.isEven ? v.first : v.last, 0.32 + (i % 4 == 0 ? 0.1 : 0), stem: hot);
      }
      b.note(Inst.timpani, start, 1, b.chart.at(start).rootNear(b.key, 45), 0.6, stem: hot);
    }
    b.phraseCymbals(Inst.crash, stem: hot, vel: 0.4);
    // Intro: gong, low octave and an organ swell.
    b.note(Inst.gong, 0, 2, 0, 0.55, stem: bed);
    b.note(Inst.honkyPiano, 0, 3, b.key - 24, 0.8, stem: bed);
    b.note(Inst.honkyPiano, 0, 3, b.key - 12, 0.7, stem: bed);
    for (final p in [b.key - 12, b.key - 9, b.key - 6]) {
      b.note(Inst.theatreOrgan, 0, 3.8, p, 0.45, stem: lead);
    }
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 1.1 : 0.8);
    b.loops = false;
    b.setIntro(won ? 'I | I' : 'iv V7 | i', 2);
    b.setLoop(won ? 'I | IV | I | V7' : 'i | iv | i | V7', 4);
    final lh = b.stem(const StemSpec('bed', reverb: 0.14));
    final rh = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.14));
    final pit = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.2, gain: 0.8));
    final k = b.key;
    if (won) {
      const arp = [0, 4, 7, 12, 16, 19, 24, 28];
      for (var i = 0; i < 16; i++) {
        b.note(Inst.honkyPiano, i * 0.25, 0.24, k + arp[i % 8] + (i >= 8 ? 12 : 0) - 12, 0.45 + i * 0.025, stem: rh);
      }
      b.note(Inst.honkyPiano, 0, 1, k - 24, 0.7, stem: lh);
      b.note(Inst.honkyPiano, 0, 1, k - 12, 0.7, stem: lh);
      b.note(Inst.honkyPiano, 2, 1, k - 17, 0.6, stem: lh);
      for (final p in [k + 12, k + 16, k + 19, k + 24]) {
        b.note(Inst.honkyPiano, 4, 0.4, p, 0.8, stem: rh);
        b.note(Inst.honkyPiano, 5.5, 2.4, p, 0.9, stem: rh);
      }
      for (final p in [k - 24, k - 12]) {
        b.note(Inst.honkyPiano, 4, 0.4, p, 0.8, stem: lh);
        b.note(Inst.honkyPiano, 5.5, 2.4, p, 0.9, stem: lh);
      }
      b.note(Inst.crash, 5.5, 1, 0, 0.6, stem: pit);
      b.note(Inst.kick, 5.5, 0.2, 0, 0.7, stem: pit);
      b.note(Inst.snare, 4, 0.1, 0, 0.6, stem: pit);
    } else {
      const line = [7, 5, 3, 2];
      for (var i = 0; i < 4; i++) {
        b.note(Inst.honkyPiano, i * 1.0, 0.95, k + line[i], 0.55, stem: rh);
        b.note(Inst.honkyPiano, i * 1.0, 0.95, k + line[i] - 12, 0.45, stem: rh);
      }
      b.note(Inst.honkyPiano, 0, 2, k - 19, 0.5, stem: lh);
      b.note(Inst.honkyPiano, 2, 2, k - 17, 0.5, stem: lh);
      b.note(Inst.honkyPiano, 4, 3.5, k, 0.55, stem: rh);
      b.note(Inst.honkyPiano, 4, 3.5, k - 12, 0.5, stem: rh);
      for (final p in [k - 24, k - 12 + 3, k - 12 + 7]) {
        b.note(Inst.honkyPiano, 4, 3.5, p, 0.5, stem: lh);
      }
      b.note(Inst.timpani, 4, 1, k - 24 + 12, 0.45, stem: pit);
    }
    // The quiet vamp afterwards (results screen).
    for (var bar = 0; bar < b.loopBars; bar++) {
      final beat = b.loopStart + bar * 4;
      final chord = b.chart.at(beat);
      b.note(Inst.honkyPiano, beat, 1.8, chord.rootNear(k, 43), 0.3, stem: lh);
      b.note(Inst.honkyPiano, beat + 2, 1.8, chord.rootNear(k, 43) + 7, 0.25, stem: lh);
      for (final p in chord.closeVoicing(k, 60, size: 3)) {
        b.note(Inst.honkyPiano, beat + 1, 0.5, p, 0.2, stem: rh);
        b.note(Inst.honkyPiano, beat + 3, 0.5, p, 0.18, stem: rh);
      }
    }
    return b.build();
  }

  /// Stride: octave bass on 1 and 3 (root, then fifth), chords on 2 and 4.
  static void _strideLeftHand(CueBuilder b, int stem, double start, int bars, {double vel = 0.55}) {
    for (var bar = 0; bar < bars; bar++) {
      for (var beat = 0; beat < 4; beat++) {
        final t = start + bar * 4 + beat;
        final chord = b.chart.at(t);
        if (beat.isEven) {
          final slot = b.chart.slotAt(t);
          final fresh = (slot.beat - t).abs() < 1e-6 || beat == 0;
          var p = chord.rootNear(b.key, 43) + (fresh ? 0 : 7);
          if (p > 50) p -= 12;
          b.note(Inst.honkyPiano, t, 0.6, p, vel + (beat == 0 ? 0.08 : 0), stem: stem);
          b.note(Inst.honkyPiano, t, 0.6, p - 12, vel * 0.85, stem: stem);
        } else {
          for (final p in chord.closeVoicing(b.key, 53, size: 3)) {
            b.note(Inst.honkyPiano, t, 0.4, p, vel * 0.72, stem: stem, fx: Art.staccato);
          }
        }
      }
    }
  }

  /// Right hand: the line, thickened with a chord tone below on accents.
  static void _rightHand(CueBuilder b, int stem, List<MelNote> mel, {double vel = 0.62}) {
    for (final n in mel) {
      b.note(Inst.honkyPiano, n.beat, n.dur * 0.92, n.pitch, vel + (n.accent ? 0.14 : 0), stem: stem);
      if (n.accent || n.dur >= 1) {
        final chord = b.chart.at(n.beat);
        final below = chord.tonesIn(b.key, n.pitch - 9, n.pitch - 3, withExtensions: false);
        if (below.isNotEmpty) b.note(Inst.honkyPiano, n.beat, n.dur * 0.9, below.last, vel * 0.8, stem: stem);
      }
    }
  }

  /// Octave tremolo in 16ths (agitato).
  static void _tremoloBass(CueBuilder b, int stem, double start, int bars, int root, double vel) {
    for (var i = 0; i < bars * 16; i++) {
      b.note(Inst.honkyPiano, start + i * 0.25, 0.23, i.isEven ? root : root + 12, vel + (i % 4 == 0 ? 0.08 : 0), stem: stem);
    }
  }
}
