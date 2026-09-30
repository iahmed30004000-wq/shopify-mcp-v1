import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1950s Technicolor: a swinging big band (sax soli, brass shouts with
/// falls), a mambo orchestra (clave, congas, tumbao, piano montuno,
/// trumpet riffs) and an exotica lounge (vibes, marimba, bongos, flute).
final class BigBandComposer implements StyleComposer {
  const BigBandComposer();

  static const _swingCells = ['x.xxx.x.', 'xxx.x-x.', 'x-x-x.x.', '-xx.x.x.', 'x.x.x-x-', 'x-xx-x..'];
  static const _mamboCells = ['x..x..x...x.x...', 'x.x..x..x.x.....', '..x..x.x..x.x...', 'x..x..x.x.......', 'x-.x-.x.x..x....'];
  static const _loungeCells = ['x---x-x-', 'x-----x-', 'x-x-x---', '..x-x---', 'x-------'];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _lounge(s, seed),
    MusicMood.adventure => _mambo(s, seed, minor: false),
    MusicMood.tension => _mambo(s, seed, minor: true),
    MusicMood.victory || MusicMood.defeat => _jingle(s, seed, won: mood == MusicMood.victory),
    _ => _band(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {double? swing, double wet = 0.26}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    swing: swing ?? s.swing,
    sound: cueSoundFor(s, roomSize: 0.7, damping: 0.4, wet: wet),
    seed: seed * 23 + mood.index,
  );

  CueScore _band(MusicMood mood, ScoreStyle s, int seed) {
    final boss = mood == MusicMood.boss;
    final action = mood == MusicMood.action;
    final b = _builder(mood, s, seed, boss ? 1.1 : (action ? 1.2 : 1.0), swing: 0.45);
    b.setIntro(boss ? 'i | Vb9' : 'ii7 | V7', 2);
    b.setLoop(
      boss
          ? b.pick(const ['i | i | iv7 | iv7 | bVI7 | Vb9 | i | Vb9', 'i | bVI7 | Vb9 | i | iv7 | bII7 | Vb9 | Vb9'])
          : b.pick(const [
              'I6 | vi7 | ii7 | V7 | iii7 VI7 | ii7 V7 | I6 VI7 | ii7 V7',
              'I6 | I7 | IV6 | #IVo7 | I6 VI7 | ii7 V7 | iii7 VI7 | ii7 V7',
              'IM7 | vi7 | ii7 | V7 | IM7 | IV7 | iii7 VI7 | ii7 V7',
            ]),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.22, pan: -0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.22, pan: 0.2, gain: 0.85));
    final all = b.introBars + b.loopBars;
    b.notes(Inst.uprightBass, walkingBass(b.chart, b.loopStart, b.loopBeats, b.key, b.rng, lo: 31, hi: 52), stem: bed, vel: 0.62);
    b.pattern(Inst.ride, const ['x...x.x.x...x.x.'], stem: bed, start: 0, bars: all, vel: 0.42);
    b.pattern(Inst.hatPedal, const ['....x.......x...'], stem: bed, start: 0, bars: all, vel: 0.45);
    b.pattern(Inst.kick, const ['x...x...x...x...'], stem: bed, start: 0, bars: all, vel: 0.22);
    b.hits(Inst.piano, const ['x..x....', '..x...x.', 'x.....x.'], stem: bed, vel: 0.32, floor: 55, rootless: true, length: 0.6);
    if (boss) b.pattern(Inst.tomLow, const ['X...x...X...x...'], stem: bed, vel: 0.5);

    // Saxes (or trumpets for the shout) in four-part close harmony.
    final mel = b.melody(
      MelodySpec(lo: boss ? 62 : 67, hi: boss ? 80 : 86, rhythms: _swingCells, steps: 8, form: 'AABA', chromatic: 0.18, blue: 0.08),
    );
    addSoli(
      b.ev,
      action ? Inst.trumpet : Inst.altoSax,
      b.chart,
      b.key,
      mel,
      stem: lead,
      vel: 0.52,
      leadInst: action ? Inst.trumpet : Inst.altoSax,
    );
    // Brass backgrounds: stabs with falls, kicks lined up underneath.
    const stabs = ['......x.....X...', '..x.....x.....X.', '......x.......x.', 'X.......x...X...'];
    b.hits(Inst.trumpet, stabs, stem: hot, vel: 0.55, floor: 67, size: 3, length: 0.5, topFx: Art.fall);
    b.hits(Inst.trombone, stabs, stem: hot, vel: 0.55, floor: 50, size: 3, length: 0.5);
    b.pattern(Inst.kick, stabs, stem: hot, vel: 0.4);
    b.phraseCymbals(Inst.crash, stem: hot, vel: 0.45);

    // Intro: trumpets climb, the band hits.
    final ii = b.chart.at(0).closeVoicing(b.key, 64, size: 3);
    for (var i = 0; i < 6; i++) {
      for (final p in ii) {
        b.note(Inst.trumpet, i * 0.5, 0.4, p + i, 0.5 + i * 0.05, stem: hot);
      }
    }
    for (final p in b.chart.at(4).closeVoicing(b.key, 64, size: 4)) {
      b.note(Inst.trumpet, 4, 0.5, p, 0.8, stem: hot, fx: Art.accent);
      b.note(Inst.trumpet, 5.5, 2.3, p, 0.85, stem: hot, fx: Art.fall);
    }
    for (final p in b.chart.at(4).closeVoicing(b.key, 48, size: 3)) {
      b.note(Inst.trombone, 4, 0.5, p, 0.75, stem: hot);
      b.note(Inst.trombone, 5.5, 2.3, p, 0.8, stem: hot);
    }
    b.pattern(Inst.snare, const ['x.x.x.x.x.xxX.x.', 'X.....X.........'], stem: bed, start: 0, bars: 2, vel: 0.5);
    b.note(Inst.crash, 5.5, 1, 0, 0.55, stem: hot);
    b.note(Inst.uprightBass, 4, 0.5, b.chart.at(4).rootNear(b.key, 40), 0.7, stem: bed);
    b.note(Inst.uprightBass, 5.5, 2.3, b.chart.at(4).rootNear(b.key, 40), 0.7, stem: bed);
    return b.build();
  }

  CueScore _mambo(ScoreStyle s, int seed, {required bool minor}) {
    final mood = minor ? MusicMood.tension : MusicMood.adventure;
    final b = _builder(mood, s, seed, minor ? 1.0 : 1.1, swing: 0);
    b.setIntro(minor ? 'Vb9' : 'V7', 1);
    b.setLoop(
      minor
          ? b.pick(const ['i | iv | Vb9 | i | bVI7 | Vb9 | i | Vb9', 'i | i | iv | Vb9 | i | bII7 | Vb9 | Vb9'])
          : b.pick(const ['I | ii7 V7 | I | ii7 V7 | IV | I | ii7 | V7', 'I | V7 | V7 | I | IV | I | ii7 V7 | I V7']),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.2, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.22, pan: -0.25, gain: 0.85));
    final all = b.introBars + b.loopBars;
    b.notes(Inst.uprightBass, tumbaoBass(b.chart, 0, all, b.key, lo: 33, hi: 52), stem: bed, vel: 0.66);
    // 3-2 son clave, conga tumbao, cowbell, shaker.
    b.pattern(Inst.clave, const ['x.....x.....x...', '....x...x.......'], stem: bed, start: 0, bars: all, vel: 0.5);
    b.pattern(Inst.conga, const ['g.g.X.g.g.g.x.x.'], stem: bed, start: 0, bars: all, vel: 0.5, fx: 0);
    b.pattern(Inst.conga, const ['....X...........'], stem: bed, start: 0, bars: all, vel: 0.45, fx: Art.slap);
    b.pattern(Inst.shaker, const ['x.x.x.x.x.x.x.x.'], stem: bed, start: 0, bars: all, vel: 0.4);
    // Piano montuno: syncopated octave arpeggios.
    for (var bar = 0; bar < all; bar++) {
      final start = bar * 4.0;
      const shape = [0, 2, 1, 2, 3, 2, 1, 2];
      const pos = [0.0, 0.5, 1.5, 2.0, 2.5, 3.0, 3.5];
      for (var i = 0; i < pos.length; i++) {
        final v = b.chart.at(start + pos[i]).closeVoicing(b.key, 60, size: 3);
        final p = v[shape[i] % v.length] + (shape[i] == 3 ? 12 : 0);
        b.note(Inst.piano, start + pos[i], 0.4, p, 0.42 + (i == 0 ? 0.1 : 0), stem: bed);
        b.note(Inst.piano, start + pos[i], 0.4, p + 12, 0.3, stem: bed);
      }
    }
    // Trumpet riff (unison + octave trombone).
    final riff = b.melody(MelodySpec(lo: 67, hi: 84, rhythms: _mamboCells, form: 'AABA', repeat: 0.2, stepBias: 0.6, leap: 0.2));
    b.notes(Inst.trumpet, riff, stem: lead, vel: 0.6, legato: 0.8, fx: Art.staccato);
    b.notes(Inst.trombone, riff, stem: lead, vel: 0.45, transpose: -12, legato: 0.8);
    final counter = b.melody(
      const MelodySpec(lo: 60, hi: 76, rhythms: ['..x.x...x-x.....', '....x..x..x.x...', 'x.x.............'], form: 'AB', repeat: 0.25),
      salt: 6,
    );
    b.notes(Inst.altoSax, counter, stem: hot, vel: 0.45);
    b.pattern(Inst.cowbell, const ['X.x.x.x.X.x.x.x.'], stem: hot, vel: 0.35);
    b.pattern(Inst.bongo, const ['x.xxx.xxx.xxx.xx'], stem: hot, vel: 0.35, pitch: 0);
    b.pattern(Inst.tomHigh, const ['..............xx', '........x.x.x.xx'], stem: hot, vel: 0.35, pitch: 7);
    // Intro: timbale-style fill into the band.
    b.pattern(Inst.tomHigh, const ['x.x.xx.x..x.x.xx'], stem: hot, start: 0, bars: 1, vel: 0.5, pitch: 7);
    b.note(Inst.crash, b.loopStart, 1, 0, 0.45, stem: hot);
    return b.build();
  }

  CueScore _lounge(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 0.72, swing: 0, wet: 0.34);
    b.setIntro('bII7', 1);
    b.setLoop(
      b.pick(const ['IM7 | bIIIM7 | IVM7 | ivm6 | IM7 | VI7 | ii7 | bII7', 'IM7 | IVM7 | iii7 | bIIIM7 | ii7 | V7 | IM7 | bII7']),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.32, pan: -0.1));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.32, pan: 0.25, gain: 0.8));
    final all = b.introBars + b.loopBars;
    b.notes(Inst.uprightBass, twoFeelBass(b.chart, 0, all, 4, b.key, b.rng, lo: 33, hi: 52, dur: 1.7, pickups: false), stem: bed, vel: 0.5);
    b.pattern(Inst.bongo, const ['x..xx.x.x..xx.x.'], stem: bed, start: 0, bars: all, vel: 0.3, pitch: 0);
    b.pattern(Inst.bongo, const ['..x.......x.....'], stem: bed, start: 0, bars: all, vel: 0.28, pitch: -5);
    b.pattern(Inst.shaker, const ['x.x.x.x.x.x.x.x.'], stem: bed, start: 0, bars: all, vel: 0.28);
    addPad(b.ev, Inst.strings, b.chart, b.key, start: 0, beats: all * 4.0, floor: 55, size: 4, stem: bed, vel: 0.28);
    final mel = b.melody(MelodySpec(lo: 67, hi: 84, rhythms: _loungeCells, steps: 8, form: 'AABA', extensions: 0.45, stepBias: 0.78));
    b.notes(Inst.vibes, mel, stem: lead, vel: 0.52);
    addArp(
      b.ev,
      Inst.marimba,
      b.chart,
      b.key,
      start: b.loopStart,
      bars: b.loopBars,
      steps: 8,
      floor: 60,
      span: 2,
      shape: 'updown',
      stem: hot,
      vel: 0.32,
    );
    final flute = b.melody(
      const MelodySpec(lo: 74, hi: 91, rhythms: ['x-------', '....x---', 'x---x---'], steps: 8, form: 'AB', stepBias: 0.85),
      salt: 8,
    );
    b.notes(Inst.flute, flute, stem: hot, vel: 0.4, fx: Art.vibrato);
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 1.0 : 0.8, swing: 0.3);
    b.loops = false;
    b.setIntro(won ? 'ii7 V7 | I6' : 'iv6 | i6', 2);
    b.setLoop(won ? 'I6 | vi7 | ii7 | V7' : 'i6 | iv6 | i6 | Vb9', 4);
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.24));
    final hot = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.24, gain: 0.85));
    final k = b.key;
    if (won) {
      for (var i = 0; i < 4; i++) {
        for (final p in b.chart.at(i * 1.0).closeVoicing(k, 64 + i * 2, size: 3)) {
          b.note(Inst.trumpet, i * 1.0, 0.5, p, 0.6 + i * 0.05, stem: hot);
        }
      }
      for (final p in b.chart.at(4).closeVoicing(k, 67, size: 4)) {
        b.note(Inst.trumpet, 4, 3.8, p, 0.85, stem: hot, fx: Art.vibrato);
      }
      for (final p in b.chart.at(4).closeVoicing(k, 48, size: 4)) {
        b.note(Inst.trombone, 4, 3.8, p, 0.8, stem: lead);
      }
      b.note(Inst.altoSax, 4, 3.8, k + 28, 0.6, stem: lead, fx: Art.glide | Art.vibrato, glideFrom: k + 21.0);
      b.note(Inst.uprightBass, 4, 3, k - 24, 0.7, stem: bed);
      b.pattern(Inst.snare, const ['x.x.x.x.x.xxxxxx'], stem: bed, start: 0, bars: 1, vel: 0.5);
      b.note(Inst.crash, 4, 1, 0, 0.6, stem: bed);
      b.note(Inst.kick, 4, 0.2, 0, 0.7, stem: bed);
    } else {
      const line = [0, -1, -3, -5];
      for (var i = 0; i < 4; i++) {
        for (final p in [k - 12 + 7 + line[i], k - 12 + 3 + line[i]]) {
          b.note(Inst.trombone, i * 1.0, 0.95, p, 0.55, stem: lead);
        }
      }
      for (final p in b.chart.at(4).closeVoicing(k, 48, size: 4)) {
        b.note(Inst.trombone, 4, 3.5, p, 0.5, stem: lead, fx: Art.vibrato);
      }
      b.note(Inst.uprightBass, 4, 3.5, k - 24, 0.6, stem: bed);
      b.note(Inst.timpani, 4, 1, k - 12, 0.5, stem: hot);
    }
    b.notes(Inst.uprightBass, twoFeelBass(b.chart, b.loopStart, b.loopBars, 4, k, b.rng, lo: 33, hi: 52), stem: bed, vel: 0.35);
    b.pattern(Inst.brushSweep, const ['x.......x.......'], stem: bed, vel: 0.3, dur: 1.9);
    b.hits(Inst.piano, const ['..x...x.'], stem: bed, vel: 0.22, floor: 57, rootless: true);
    return b.build();
  }
}
