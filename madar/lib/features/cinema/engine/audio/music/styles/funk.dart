import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1970s grindhouse funk: tight drums with ghost notes and sixteenth hats,
/// a syncopated finger/slap bass, wah guitar scratches, clavinet, a horn
/// section, congas and blaxploitation-style string stabs.
final class FunkComposer implements StyleComposer {
  const FunkComposer();

  static const _hornCells = [
    'x.xx...x..x.x...',
    'x..x..x.x.......',
    '....x.x..x.x.x..',
    'x-..x-..x.x.x...',
    '..x.x..x....x.x.',
    'x.......x-x-x...',
  ];
  static const _bassRiffs = [
    ['R..R.OR.g.R.7.F.', 'R..R.OR...R.F.O.'],
    ['R.gR..O.R.g.F.7.', 'R.gR..O.R...O.F.'],
    ['R...R.OR..R.g.O.', 'R...R.O.R.F.7.O.'],
  ];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _slowJam(s, seed),
    MusicMood.tension => _heat(s, seed),
    MusicMood.victory || MusicMood.defeat => _jingle(s, seed, won: mood == MusicMood.victory),
    _ => _groove(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {double wet = 0.18}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    swing: s.swing,
    swing16: true,
    sound: cueSoundFor(s, roomSize: 0.35, damping: 0.5, wet: wet),
    seed: seed * 29 + mood.index,
  );

  void _kit(CueBuilder b, int stem, {required double start, required int bars, bool busy = false, bool halfTime = false}) {
    b.pattern(
      Inst.kick,
      busy
          ? const ['x.x...x.x.x...x.', 'x.x...x.x...x.x.']
          : (halfTime ? const ['x.......x.......'] : const ['x..x..x...x.....', 'x..x..x...x..x..']),
      stem: stem,
      start: start,
      bars: bars,
      vel: 0.72,
    );
    b.pattern(
      Inst.snare,
      halfTime ? const ['........X.......'] : const ['g...X..g.g..X..g', 'g...X..g.g..X.gg'],
      stem: stem,
      start: start,
      bars: bars,
      vel: 0.62,
    );
    b.pattern(Inst.hatClosed, const ['XxXxXxXxXxXxXxX.', 'XxXxXxXxXxXxXx..'], stem: stem, start: start, bars: bars, vel: 0.5, gain: 1.4);
    b.pattern(Inst.hatOpen, const ['..............x.', '.............x..'], stem: stem, start: start, bars: bars, vel: 0.3);
  }

  CueScore _groove(MusicMood mood, ScoreStyle s, int seed) {
    final boss = mood == MusicMood.boss;
    final action = mood == MusicMood.action;
    final title = mood == MusicMood.title;
    final b = _builder(mood, s, seed, boss ? 1.08 : (action ? 1.18 : (title ? 0.95 : 1.0)));
    b.setIntro(boss ? 'i7' : 'i7', 1);
    b.setLoop(
      boss
          ? b.pick(const ['i7 | i7 | bVI7 | V7 | i7 | i7 | bII7 | V7', 'i7 | bVII7 | bVI7 | V7 | i7 | iv7 | bII7 | V7'])
          : b.pick(const [
              'i7 | i7 | IV9 | IV9 | i7 | i7 | bVI7 | V7',
              'i9 | IV9 | i9 | IV9 | bVI7 | bVII7 | i9 | V7',
              'i7 | i7 | i7 | IV9 | i7 | i7 | bVII7 | IV9',
            ]),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.08));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.16, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.14, pan: -0.25, gain: 0.8));
    _kit(b, bed, start: b.loopStart, bars: b.loopBars, busy: action);
    final riff = riffBass(b.chart, b.loopStart, b.loopBars, b.key, b.pick(_bassRiffs), base: 40);
    for (final n in riff) {
      b.note(
        Inst.electricBass,
        n.beat,
        n.dur,
        n.pitch,
        n.accent ? 0.72 : 0.6,
        stem: bed,
        fx: n.pitch - b.chart.at(n.beat).rootNear(b.key, 40) >= 12 ? Art.slap : 0,
      );
    }
    // Horn section: trumpet + tenor in octaves, falls at phrase ends.
    final horns = b.melody(MelodySpec(lo: 64, hi: 81, rhythms: _hornCells, form: 'AABA', repeat: 0.2, chromatic: 0.12, blue: 0.12));
    for (final n in horns) {
      final fx = n.dur >= 1 ? Art.fall : Art.staccato;
      b.note(Inst.trumpet, n.beat, n.dur, n.pitch, 0.72 + (n.accent ? 0.12 : 0), stem: lead, fx: fx);
      b.note(Inst.tenorSax, n.beat, n.dur, n.pitch - 12, 0.62, stem: lead, fx: n.dur >= 1 ? 0 : Art.staccato);
    }
    // Wah scratches, clav, congas.
    b.hits(Inst.wahGuitar, const ['g.x.gxg.g.x.gxg.', 'g.x.gxg.gxx.g.g.'], stem: hot, vel: 0.34, floor: 64, size: 2, length: 0.8);
    b.hits(Inst.clav, const ['..x..x.x..x..x..', '..x..x.x..x.x...'], stem: hot, vel: 0.28, floor: 60, size: 2, length: 0.6);
    b.pattern(Inst.conga, const ['x..x..x.x..x..x.'], stem: hot, vel: 0.26, pitch: 0);
    b.pattern(Inst.conga, const ['..x.......x...x.'], stem: hot, vel: 0.26, pitch: -5);
    if (action) b.pattern(Inst.cowbell, const ['x.x.x.x.x.x.x.x.'], stem: hot, vel: 0.25);
    if (boss) {
      b.hits(
        Inst.strings,
        const ['X.......x.......', '......x.X.......'],
        stem: hot,
        vel: 0.55,
        floor: 60,
        size: 4,
        length: 0.6,
        fx: Art.staccato,
      );
      b.pattern(Inst.tomLow, const ['..............xx', '............xxxx'], stem: bed, vel: 0.55);
    }
    b.phraseCymbals(Inst.crash, stem: bed, vel: 0.45);
    // Intro: solo drum break with a bass pickup.
    b.pattern(Inst.kick, const ['x..x..x...x..x..'], stem: bed, start: 0, bars: 1, vel: 0.75);
    b.pattern(Inst.snare, const ['....X..g.g..X.XX'], stem: bed, start: 0, bars: 1, vel: 0.65);
    b.pattern(Inst.hatClosed, const ['XxXxXxXxXxXx....'], stem: bed, start: 0, bars: 1, vel: 0.3);
    b.pattern(Inst.tomHigh, const ['............x.x.'], stem: bed, start: 0, bars: 1, vel: 0.55);
    b.note(Inst.electricBass, 3.5, 0.45, b.key - 12 - 2, 0.6, stem: bed, fx: Art.glide, glideFrom: b.key - 12 - 7.0);
    return b.build();
  }

  CueScore _slowJam(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 0.8, wet: 0.26);
    b.setIntro('iv9', 1);
    b.setLoop(b.pick(const ['i9 | iv9 | bIIIM7 | bVIM7 | i9 | iv9 | bVI7 | V7', 'i9 | i9 | iv9 | iv9 | bVIM7 | bVII7 | i9 | V7']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.3, pan: 0.15));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.3, pan: -0.2, gain: 0.8));
    final all = b.introBars + b.loopBars;
    b.pattern(Inst.kick, const ['x.......x..x....'], stem: bed, start: 0, bars: all, vel: 0.5);
    b.pattern(Inst.rimClick, const ['....x.......x...'], stem: bed, start: 0, bars: all, vel: 0.45);
    b.pattern(Inst.hatClosed, const ['x.x.x.x.x.x.x.x.'], stem: bed, start: 0, bars: all, vel: 0.22);
    b.notes(
      Inst.electricBass,
      riffBass(b.chart, 0, all, b.key, const ['R-----..R.F-..7.', 'R-----..R...O...'], base: 40),
      stem: bed,
      vel: 0.5,
    );
    b.hits(
      Inst.rhodes,
      const ['x-----..x-......', 'x-----......x-..'],
      stem: bed,
      start: 0,
      bars: all,
      vel: 0.36,
      floor: 55,
      size: 4,
      rootless: true,
      length: 1.0,
    );
    final mel = b.melody(
      const MelodySpec(
        lo: 67,
        hi: 88,
        rhythms: ['x---x.x.x-------', 'x-----x.x.x.x---', '..x.x.x-x-------', 'x-------x---x---'],
        form: 'ABAC',
        blue: 0.1,
        stepBias: 0.8,
      ),
    );
    b.notes(Inst.flute, mel, stem: lead, vel: 0.5, fx: Art.vibrato);
    addPad(b.ev, Inst.strings, b.chart, b.key, start: b.loopStart, beats: b.loopBeats, floor: 60, stem: hot, vel: 0.3);
    return b.build();
  }

  CueScore _heat(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.tension, s, seed, 0.9);
    b.setIntro('i', 1);
    b.setLoop(b.pick(const ['i | bII | i | bII | i | bII | iv | bII', 'i | i | bII | bII | i | i | Vb9 | bII']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.1));
    final lead = b.stem(const StemSpec('lead', layer: 0.32, reverb: 0.2, pan: 0.2));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.22, pan: -0.2, gain: 0.85));
    final all = b.introBars + b.loopBars;
    _kit(b, bed, start: 0, bars: all, halfTime: true);
    b.notes(
      Inst.electricBass,
      riffBass(b.chart, 0, all, b.key, const ['R.RRR.O.R.RRR.O.', 'R.RRR.O.R.R.O.F.'], base: 40),
      stem: bed,
      vel: 0.55,
    );
    b.hits(
      Inst.wahGuitar,
      const ['gggggggggggggggg', 'ggggggggggggx.x.'],
      stem: bed,
      start: 0,
      bars: all,
      vel: 0.35,
      floor: 64,
      size: 2,
      length: 0.9,
    );
    b.hits(
      Inst.trumpet,
      const ['..............X.', '......X.........', '..............X.', '..........X.X...'],
      stem: lead,
      vel: 0.62,
      floor: 64,
      size: 3,
      length: 0.4,
      topFx: Art.fall,
    );
    b.hits(Inst.strings, const ['X-------........', '........X-------'], stem: hot, vel: 0.5, floor: 55, size: 4, fx: Art.trem);
    b.pattern(Inst.shaker, const ['xxxxxxxxxxxxxxxx'], stem: hot, vel: 0.2);
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 1.0 : 0.8);
    b.loops = false;
    b.setIntro(won ? 'IV9 | I9' : 'iv7 | i7', 2);
    b.setLoop(won ? 'I9 | IV9 | I9 | IV9' : 'i7 | iv7 | i7 | iv7', 4);
    final bed = b.stem(const StemSpec('bed', reverb: 0.1));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.2));
    final hot = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.2, gain: 0.85));
    final k = b.key;
    if (won) {
      b.pattern(Inst.snare, const ['X..X..X.X.X.XXXX'], stem: bed, start: 0, bars: 1, vel: 0.55);
      b.pattern(Inst.kick, const ['X..X..X.X.......'], stem: bed, start: 0, bars: 1, vel: 0.7);
      for (final (beat, dur) in const [(0.0, 0.4), (0.75, 0.4), (1.5, 0.4), (2.5, 1.2)]) {
        for (final p in b.chart.at(0).closeVoicing(k, 64, size: 3)) {
          b.note(Inst.trumpet, beat, dur, p, 0.65, stem: lead, fx: Art.staccato);
        }
      }
      for (final p in b.chart.at(4).closeVoicing(k, 64, size: 4)) {
        b.note(Inst.trumpet, 4, 3.5, p, 0.85, stem: lead, fx: Art.fall);
        b.note(Inst.tenorSax, 4, 3.5, p - 12, 0.6, stem: lead);
      }
      b.note(Inst.electricBass, 4, 3.5, k - 12, 0.75, stem: bed, fx: Art.slap);
      b.note(Inst.crash, 4, 1, 0, 0.6, stem: bed);
      b.note(Inst.kick, 4, 0.2, 0, 0.8, stem: bed);
    } else {
      for (final (i, p) in const [10, 7, 3].indexed) {
        b.note(Inst.wahGuitar, i * 1.0, 0.9, k + p, 0.6, stem: hot);
      }
      b.note(Inst.electricBass, 0, 3.8, k - 12 + 7, 0.6, stem: bed, fx: Art.fall);
      for (final p in b.chart.at(4).closeVoicing(k, 60, size: 3)) {
        b.note(Inst.trumpet, 4, 2.5, p, 0.5, stem: lead, fx: Art.fall);
      }
      b.note(Inst.electricBass, 4, 3, k - 12, 0.6, stem: bed);
      b.note(Inst.snare, 4, 0.2, 0, 0.5, stem: bed);
    }
    b.pattern(Inst.kick, const ['x.......x..x....'], stem: bed, vel: 0.35);
    b.pattern(Inst.rimClick, const ['....x.......x...'], stem: bed, vel: 0.3);
    b.hits(Inst.rhodes, const ['x-----..x-......'], stem: bed, vel: 0.25, floor: 55, rootless: true);
    b.pattern(Inst.conga, const ['x..x..x.x..x..x.'], stem: hot, vel: 0.22);
    b.hits(Inst.wahGuitar, const ['g.x.g.g.g.x.g.g.'], stem: hot, vel: 0.26, floor: 64, size: 2, length: 0.8);
    return b.build();
  }
}
