import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1930s hot jazz for rubber-hose cartoons: tuba and banjo four-to-the-bar,
/// a clarinet and a plunger-muted trumpet trading phrases, tailgate
/// trombone smears, temple blocks, cymbal chokes and a xylophone.
final class SwingComposer implements StyleComposer {
  const SwingComposer();

  // Eighth-note grid (swung by the renderer).
  static const _hotCells = ['x.xxx.x.', 'xxx.x-x.', 'x-x-xxx.', '-xxxx.x.', 'x.x.x-x-', 'xxxxx.x.', 'x-xx-xx.', 'x.x-x.xx'];
  static const _lazyCells = ['x---x.x.', 'x-----x.', 'x.x.x---', '-x--x-x.', 'x-------'];
  static const _sneakCells = ['x.x...x.', 'x...x.x.', 'x.x.x...', '..x.x.x.', 'x.....x.'];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _lazy(s, seed),
    MusicMood.tension => _sneak(s, seed),
    MusicMood.boss => _jungle(s, seed),
    MusicMood.victory || MusicMood.defeat => _jingle(s, seed, won: mood == MusicMood.victory),
    _ => _hot(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {double? swing}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    swing: swing ?? s.swing,
    sound: cueSoundFor(s, roomSize: 0.4, damping: 0.55, wet: 0.24),
    seed: seed * 17 + mood.index,
  );

  /// Tuba "oom" on 1 and 3, banjo on every beat, feathered bass drum,
  /// brushed afterbeats and a pedal hi-hat.
  void _rhythm(CueBuilder b, int stem, {double? start, int? bars, bool walking = false, double vel = 0.6}) {
    final st = start ?? b.loopStart;
    final n = bars ?? b.loopBars;
    if (walking) {
      b.notes(Inst.uprightBass, walkingBass(b.chart, st, n * 4.0, b.key, b.rng, lo: 34, hi: 55), stem: stem, vel: vel);
    } else {
      b.notes(Inst.tuba, twoFeelBass(b.chart, st, n, 4, b.key, b.rng, lo: 34, hi: 50, dur: 0.85), stem: stem, vel: vel, fx: Art.staccato);
    }
    b.hits(Inst.banjo, const ['x.X.x.X.'], stem: stem, start: st, bars: n, vel: 0.42, floor: 58, size: 4, strum: 0.03, length: 0.45);
    b.pattern(Inst.kick, const ['x...x...x...x...'], stem: stem, start: st, bars: n, vel: 0.35);
    b.pattern(Inst.brushTap, const ['....x.......x...'], stem: stem, start: st, bars: n, vel: 0.55);
    b.pattern(Inst.hatPedal, const ['....x.......x...'], stem: stem, start: st, bars: n, vel: 0.4);
  }

  CueScore _hot(MusicMood mood, ScoreStyle s, int seed) {
    final title = mood == MusicMood.title;
    final action = mood == MusicMood.action;
    final b = _builder(mood, s, seed, title ? 0.95 : (action ? 1.12 : 1.0));
    b.setIntro(title ? 'V7 | V7' : 'V7', title ? 2 : 1);
    b.setLoop(
      b.pick(const [
        'I | VI7 | II7 | V7 | I | VI7 | II7 V7 | I V7',
        'I I7 | IV #IVo7 | I VI7 | II7 V7 | I I7 | IV iv6 | I VI7 | II7 V7',
        'I | I | II7 | II7 | V7 | V7 | I | II7 V7',
        'I | III7 | VI7 | II7 V7 | I | III7 | VI7 II7 | V7',
      ]),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.12));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.18, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.64, reverb: 0.2, pan: -0.2, gain: 0.85));
    _rhythm(b, bed, walking: action);
    b.pattern(Inst.templeBlock, const ['........', '........', '........', 'x.x.xx.x'], stem: bed, vel: 0.4, pitch: 0);
    b.phraseCymbals(Inst.choke, stem: bed, vel: 0.42);

    // Clarinet and plunger trumpet trade four-bar phrases.
    final mel = b.melody(MelodySpec(lo: 62, hi: 86, rhythms: _hotCells, steps: 8, form: 'ABAC', chromatic: 0.22, blue: 0.1, repeat: 0.06));
    final half = b.loopStart + 16;
    b.notes(Inst.clarinet, mel.where((n) => n.beat < half), stem: lead, vel: 0.6, fx: 0);
    for (final n in mel.where((n) => n.beat >= half)) {
      b.note(
        Inst.mutedTrumpet,
        n.beat,
        n.dur,
        n.pitch - (n.pitch > 80 ? 12 : 0),
        0.62 + (n.accent ? 0.12 : 0),
        stem: lead,
        fx: n.dur >= 1 ? Art.wah | Art.scoop : Art.wah,
      );
    }

    // Tailgate trombone smears into each 2-bar phrase + brass stabs.
    for (var bar = 0; bar < b.loopBars; bar += 2) {
      final beat = b.loopStart + bar * 4;
      final chord = b.chart.at(beat);
      final tones = chord.tonesIn(b.key, 48, 60, withExtensions: false);
      final target = tones.isEmpty ? b.key - 12 : tones.last;
      b.note(Inst.trombone, beat, 1.8, target, 0.62, stem: hot, fx: Art.glide, glideFrom: target - 7.0);
    }
    b.hits(
      Inst.trumpet,
      const ['......x.....x...', '......x.......x.'],
      stem: hot,
      vel: 0.5,
      floor: 62,
      size: 3,
      length: 0.5,
      fx: Art.staccato,
    );
    if (action) {
      b.pattern(Inst.snare, const ['....x.......x...', '....x.......x.xx'], stem: hot, vel: 0.45);
    }
    // Xylophone run into the turnaround.
    final xylo = b.melody(
      const MelodySpec(lo: 72, hi: 91, rhythms: ['xxxxxxxx', 'xxxx.x.x'], steps: 8, form: 'A', stepBias: 0.9),
      start: b.loopStart + 28,
      bars: 1,
      salt: 5,
    );
    b.notes(Inst.xylophone, xylo, stem: hot, vel: 0.5);

    // Intro.
    final v = b.key + 7;
    if (title) {
      for (final (beat, dur) in const [(0.0, 0.5), (1.5, 0.5), (3.0, 1.0)]) {
        for (final p in [v - 12 + 4, v - 12 + 10, v + 4 - 12 + 12]) {
          b.note(Inst.trumpet, beat, dur, p, 0.72, stem: hot, fx: Art.accent);
        }
        b.note(Inst.trombone, beat, dur, v - 12, 0.7, stem: hot);
        b.note(Inst.tuba, beat, dur, v - 24, 0.7, stem: bed);
      }
      b.pattern(Inst.snare, const ['x.x.x.x.x.x.xxxx'], stem: bed, start: 4, bars: 1, vel: 0.5);
      b.note(Inst.crash, 0, 1, 0, 0.5, stem: bed);
      b.note(Inst.clarinet, 6, 2, b.key + 24 - 5, 0.6, stem: lead, fx: Art.glide, glideFrom: b.key + 12.0);
    } else {
      b.pattern(Inst.templeBlock, const ['x.x.x.x.x.xxx.x.'], stem: bed, start: 0, bars: 1, vel: 0.45);
      b.note(Inst.clarinet, 2, 2, b.key + 19, 0.6, stem: lead, fx: Art.glide, glideFrom: b.key + 7.0);
      b.note(Inst.tuba, 0, 0.8, v - 24, 0.6, stem: bed);
      b.note(Inst.tuba, 2, 0.8, v - 24 + 7, 0.6, stem: bed);
    }
    return b.build();
  }

  CueScore _lazy(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 0.68, swing: 0.66);
    b.setIntro('ii7 V7', 1);
    b.setLoop(b.pick(const ['I | vi7 | ii7 | V7 | I | IV | I VI7 | II7 V7', 'I | I7 | IV | iv6 | I | VI7 | II7 | V7']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.16));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.22, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.25, pan: -0.25, gain: 0.8));
    b.notes(Inst.tuba, twoFeelBass(b.chart, 0, b.introBars + b.loopBars, 4, b.key, b.rng, lo: 34, hi: 50, dur: 1.6), stem: bed, vel: 0.45);
    b.hits(
      Inst.piano,
      const ['..x...x.', '..x...x.'],
      stem: bed,
      start: 0,
      bars: b.introBars + b.loopBars,
      vel: 0.28,
      floor: 57,
      size: 4,
      length: 0.6,
    );
    b.pattern(Inst.brushTap, const ['....x.......x...'], stem: bed, start: 0, bars: b.introBars + b.loopBars, vel: 0.35);
    b.pattern(Inst.brushSweep, const ['x.......x.......'], stem: bed, start: 0, bars: b.introBars + b.loopBars, vel: 0.4, dur: 1.8);
    final mel = b.melody(MelodySpec(lo: 60, hi: 79, rhythms: _lazyCells, steps: 8, form: 'AABA', stepBias: 0.8, blue: 0.12));
    for (final n in mel) {
      b.note(Inst.mutedTrumpet, n.beat, n.dur, n.pitch, 0.55, stem: lead, fx: Art.wah | (n.dur >= 1 ? Art.vibrato : 0));
    }
    final counter = b.melody(
      const MelodySpec(lo: 72, hi: 88, rhythms: ['x.x.x...', '....x.x.', 'x-..x...'], steps: 8, form: 'AB'),
      salt: 3,
    );
    b.notes(Inst.celesta, counter, stem: hot, vel: 0.4);
    b.notes(Inst.clarinet, mel, stem: hot, vel: 0.35, transpose: -5, legato: 0.95);
    return b.build();
  }

  CueScore _sneak(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.tension, s, seed, 0.72, swing: 0.5);
    final m = b.pick(const ['i | i | iv | iv | i | bVI7 | V7 | V7', 'i | io7 | i | io7 | iv | bVI7 | V7 | V7']);
    b.setIntro('V7', 1);
    b.setLoop(m, 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.12));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.16));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.2, pan: 0.3));
    // Tiptoe: staccato pizzicato bass in 8ths + tick-tock temple blocks.
    final walk = walkingBass(b.chart, 0, (b.introBars + b.loopBars) * 4.0, b.key, b.rng, lo: 36, hi: 55);
    for (final n in walk) {
      b.note(Inst.uprightBass, n.beat, 0.35, n.pitch, 0.6, stem: bed, fx: Art.staccato);
      b.note(Inst.uprightBass, n.beat + 0.5, 0.25, n.pitch + 12, 0.35, stem: bed, fx: Art.staccato);
    }
    b.pattern(Inst.templeBlock, const ['x...x...x...x...'], stem: bed, start: 0, bars: b.introBars + b.loopBars, vel: 0.35, pitch: 0);
    b.pattern(Inst.templeBlock, const ['..x...x...x...x.'], stem: bed, start: 0, bars: b.introBars + b.loopBars, vel: 0.3, pitch: -5);
    final mel = b.melody(MelodySpec(lo: 50, hi: 70, rhythms: _sneakCells, steps: 8, form: 'AABA', chromatic: 0.3, repeat: 0.15));
    b.notes(Inst.clarinet, mel, stem: lead, vel: 0.55, legato: 0.45, fx: Art.staccato);
    for (final n in mel) {
      if (n.accent) b.note(Inst.xylophone, n.beat, 0.2, n.pitch + 24, 0.4, stem: hot);
    }
    b.hits(
      Inst.trombone,
      const ['x.......x.......', '........x...x...'],
      stem: hot,
      vel: 0.4,
      floor: 48,
      size: 3,
      length: 0.3,
      fx: Art.staccato,
    );
    return b.build();
  }

  CueScore _jungle(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.boss, s, seed, 1.1, swing: 0.45);
    b.setIntro('i', 1);
    b.setLoop(b.pick(const ['i | i | iv | iv | bVI7 | V7 | i | V7', 'i | bVI7 | V7 | i | iv | iv | V7 | V7']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.2, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.2, pan: -0.2, gain: 0.9));
    final all = b.introBars + b.loopBars;
    b.pattern(Inst.tomLow, const ['X...x...X...x...', 'X...x...X...x.x.'], stem: bed, start: 0, bars: all, vel: 0.62);
    b.pattern(Inst.tomHigh, const ['..x...x...x...x.', '..x...x...xx.xx.'], stem: bed, start: 0, bars: all, vel: 0.4);
    final riff = riffBass(b.chart, 0, all, b.key, const ['R.R.F.b.R.R.F.O.', 'R.R.F.b.R...F.R.'], base: 40);
    b.notes(Inst.tuba, riff, stem: bed, vel: 0.62, fx: Art.staccato, legato: 0.8);
    final mel = b.melody(MelodySpec(lo: 65, hi: 89, rhythms: _hotCells, steps: 8, form: 'AABA', blue: 0.2, chromatic: 0.2));
    for (final n in mel) {
      final wail = n.dur >= 1;
      b.note(
        Inst.clarinet,
        n.beat,
        n.dur,
        n.pitch,
        0.62 + (n.accent ? 0.1 : 0),
        stem: lead,
        fx: wail ? Art.glide | Art.vibrato : 0,
        glideFrom: wail ? n.pitch - 3.0 : 0,
      );
    }
    b.hits(
      Inst.trombone,
      const ['X.....x.........', 'X.....x.....x...'],
      stem: hot,
      vel: 0.6,
      floor: 46,
      size: 3,
      length: 0.5,
      topFx: Art.fall,
    );
    for (var bar = 0; bar < b.loopBars; bar += 2) {
      final beat = b.loopStart + bar * 4 + 2;
      final p = b.chart.at(beat).rootNear(b.key, 70) + 7;
      b.note(Inst.mutedTrumpet, beat, 1.5, p, 0.6, stem: hot, fx: Art.growl | Art.wah);
    }
    b.phraseCymbals(Inst.choke, stem: hot, vel: 0.5, every: 2);
    b.note(Inst.gong, 0, 2, 0, 0.45, stem: bed);
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 1.0 : 0.7);
    b.loops = false;
    b.setIntro(won ? 'V7 | I6' : 'iv | i', 2);
    b.setLoop(won ? 'I | VI7 | II7 | V7' : 'i | iv | i | V7', 4);
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.2));
    final hot = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.2, gain: 0.85));
    final k = b.key;
    if (won) {
      const run = [7, 11, 14, 17, 19, 23, 26, 29];
      for (var i = 0; i < 8; i++) {
        b.note(Inst.trumpet, i * 0.5, 0.45, k + run[i] - 12, 0.55 + i * 0.04, stem: lead);
      }
      b.pattern(Inst.snare, const ['x.x.x.x.x.xxxxxx'], stem: bed, start: 0, bars: 1, vel: 0.45);
      for (final p in [k + 4, k + 9, k + 12, k + 16]) {
        b.note(Inst.trumpet, 4, 0.4, p, 0.8, stem: hot);
        b.note(Inst.trumpet, 5.5, 2.3, p, 0.85, stem: hot, fx: Art.vibrato);
      }
      b.note(Inst.clarinet, 5.5, 2.3, k + 24, 0.7, stem: lead, fx: Art.glide | Art.vibrato, glideFrom: k + 19.0);
      b.note(Inst.trombone, 5.5, 2.3, k, 0.75, stem: hot, fx: Art.glide, glideFrom: k - 5.0);
      b.note(Inst.tuba, 4, 0.4, k - 24, 0.8, stem: bed);
      b.note(Inst.tuba, 5.5, 2.3, k - 24, 0.8, stem: bed);
      b.note(Inst.crash, 5.5, 1, 0, 0.6, stem: bed);
    } else {
      b.note(Inst.mutedTrumpet, 0, 1.4, k + 7, 0.6, stem: lead, fx: Art.wah);
      b.note(Inst.mutedTrumpet, 1.5, 2.3, k + 3, 0.6, stem: lead, fx: Art.wah | Art.vibrato);
      b.note(Inst.tuba, 4, 3, k - 24, 0.7, stem: bed, fx: Art.fall);
      b.note(Inst.templeBlock, 4, 0.2, -5, 0.5, stem: hot);
      b.note(Inst.templeBlock, 4.5, 0.2, -9, 0.45, stem: hot);
    }
    // Soft vamp for the results screen.
    b.notes(
      Inst.tuba,
      twoFeelBass(b.chart, b.loopStart, b.loopBars, 4, b.key, b.rng, lo: 34, hi: 50, dur: 0.8),
      stem: bed,
      vel: 0.3,
      fx: Art.staccato,
    );
    b.hits(Inst.banjo, const ['x.x.x.x.'], stem: bed, vel: 0.22, floor: 58, strum: 0.03, length: 0.4);
    b.pattern(Inst.brushTap, const ['....x.......x...'], stem: bed, vel: 0.25);
    return b.build();
  }
}
