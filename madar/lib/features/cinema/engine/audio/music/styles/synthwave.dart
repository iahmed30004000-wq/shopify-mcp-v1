import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1980s VHS synthwave: four-on-the-floor kick, gated snare, galloping
/// saw bass, supersaw pads, a portamento lead, ping-pong sixteenth arps.
final class SynthwaveComposer implements StyleComposer {
  const SynthwaveComposer();

  static const _leadCells = [
    'x-------x---x---',
    'x---x---x-x-x---',
    'x-----x-x-------',
    '..x-x-x-x---x---',
    'x-x-x---x-------',
    'x-----------x-x-',
  ];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _drift(s, seed),
    MusicMood.tension => _pulse(s, seed),
    MusicMood.victory || MusicMood.defeat => _jingle(s, seed, won: mood == MusicMood.victory),
    _ => _drive(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {double wet = 0.3}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    swing: 0,
    sound: cueSoundFor(s, roomSize: 0.72, damping: 0.35, wet: wet),
    seed: seed * 31 + mood.index,
  );

  void _lead(CueBuilder b, int stem, List<MelNote> mel, {Inst inst = Inst.synthLead, double vel = 0.55}) {
    MelNote? prev;
    for (final n in mel) {
      final legato = prev != null && (n.beat - (prev.beat + prev.dur)).abs() < 0.3 && (n.pitch - prev.pitch).abs() <= 7;
      b.note(
        inst,
        n.beat,
        n.dur,
        n.pitch,
        vel + (n.accent ? 0.1 : 0),
        stem: stem,
        fx: (legato ? Art.glide : 0) | (n.dur >= 1 ? Art.vibrato : 0),
        glideFrom: legato ? prev.pitch.toDouble() : 0,
      );
      prev = n;
    }
  }

  CueScore _drive(MusicMood mood, ScoreStyle s, int seed) {
    final boss = mood == MusicMood.boss;
    final action = mood == MusicMood.action;
    final title = mood == MusicMood.title;
    final b = _builder(mood, s, seed, boss ? 1.1 : (action ? 1.15 : 1.0));
    b.setIntro(title ? 'bVI | bVII' : 'bVII', title ? 2 : 1);
    b.setLoop(
      boss
          ? b.pick(const ['i | bVI | iv | V | i | bVI | bII | V', 'i | i | bVI | V | iv | bVI | V | V'])
          : b.pick(const [
              'i | bVI | bIII | bVII | i | bVI | bIII | bVII',
              'i | bVII | bVI | bVII | i | bVII | iv | bVII',
              'bVI | bVII | i | i | bVI | bVII | bIII | bVII',
            ]),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.1));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.3, delayBeats: 0.75, delayFeedback: 0.3));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.25, stereo: true, delayBeats: 0.75, delayFeedback: 0.35, gain: 0.7));
    final all = b.introBars + b.loopBars;
    b.pattern(Inst.kick, const ['x...x...x...x...'], stem: bed, vel: 0.62);
    b.pattern(Inst.gatedSnare, const ['....x.......x...'], stem: bed, vel: 0.6);
    b.pattern(Inst.clap, const ['....x.......x...'], stem: bed, vel: 0.4);
    b.pattern(Inst.hatClosed, action ? const ['xxXxxxXxxxXxxxXx'] : const ['x.X.x.X.x.X.x.X.'], stem: bed, vel: 0.5, gain: 1.5);
    b.pattern(
      Inst.tomHigh,
      const ['................', '................', '................', '........x.x.xxxx'],
      stem: bed,
      vel: 0.45,
      pitch: 3,
    );
    b.pattern(Inst.tomLow, const ['................', '................', '................', '............x.xx'], stem: bed, vel: 0.5);
    b.phraseCymbals(Inst.crash, stem: bed, vel: 0.4);
    final gallop = boss ? const ['R.RRR.RRR.RRR.RR', 'R.RRR.RRR.RRO.OO'] : const ['R.R.O.R.R.R.O.R.', 'R.R.O.R.R.R.O.RO'];
    b.notes(Inst.synthBass, riffBass(b.chart, b.loopStart, b.loopBars, b.key, gallop, base: 36), stem: bed, vel: 0.52, gain: 0.8);
    addPad(b.ev, Inst.synthPad, b.chart, b.key, start: 0, beats: all * 4.0, floor: 55, size: 4, stem: bed, vel: 0.36, gain: 0.8);
    final mel = b.melody(
      MelodySpec(lo: boss ? 62 : 64, hi: boss ? 81 : 84, rhythms: _leadCells, form: 'AABA', stepBias: 0.72, leap: 0.14, chromatic: 0.05),
    );
    _lead(b, lead, mel);
    if (boss) {
      b.hits(Inst.synthBrass, const ['X.....x.........', '......X...x.....'], stem: lead, vel: 0.5, floor: 57, size: 4, length: 0.5);
    }
    addArp(
      b.ev,
      Inst.synthArp,
      b.chart,
      b.key,
      start: 0,
      bars: all,
      steps: 16,
      floor: 64,
      span: 2,
      shape: action ? 'updown' : 'up',
      stem: hot,
      vel: 0.33,
      gain: 0.6,
      gate: 0.6,
    );
    // Intro: filtered arp alone (title: plus pad swell), then the kit enters.
    if (!title) b.pattern(Inst.tomLow, const ['........x.x.xxxx'], stem: bed, start: 0, bars: 1, vel: 0.5);
    b.note(Inst.crash, b.loopStart, 1, 0, 0.5, stem: bed);
    return b.build();
  }

  CueScore _drift(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 0.85, wet: 0.38);
    b.setIntro('bVI', 1);
    b.setLoop(b.pick(const ['i | bVI | iv | bVII | i | bVI | bIII | bVII', 'bVI | bIII | bVII | i | bVI | bIII | iv | bVII']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.4, delayBeats: 0.75, delayFeedback: 0.3));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.35, stereo: true, delayBeats: 0.5, delayFeedback: 0.3, gain: 0.7));
    final all = b.introBars + b.loopBars;
    addPad(b.ev, Inst.synthPad, b.chart, b.key, start: 0, beats: all * 4.0, floor: 55, size: 4, stem: bed, vel: 0.45);
    b.notes(Inst.synthBass, riffBass(b.chart, 0, all, b.key, const ['R-------R---O---'], base: 36), stem: bed, vel: 0.45);
    b.pattern(Inst.hatClosed, const ['..x...x...x...x.'], stem: bed, start: 0, bars: all, vel: 0.18);
    final mel = b.melody(
      const MelodySpec(
        lo: 64,
        hi: 84,
        rhythms: ['x-------x-------', 'x---x---x-------', 'x-----x---------', '....x---x---x---'],
        form: 'ABAC',
        stepBias: 0.8,
      ),
    );
    b.notes(Inst.rhodes, mel, stem: lead, vel: 0.5);
    addArp(
      b.ev,
      Inst.synthArp,
      b.chart,
      b.key,
      start: b.loopStart,
      bars: b.loopBars,
      steps: 8,
      floor: 64,
      span: 2,
      shape: 'updown',
      stem: hot,
      vel: 0.32,
      gate: 0.5,
    );
    return b.build();
  }

  CueScore _pulse(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.tension, s, seed, 0.9);
    b.setIntro('i', 1);
    b.setLoop(b.pick(const ['i | i | bII | bII | i | i | bVI | V', 'i | bVI | i | bII | i | bVI | iv | V']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.12));
    final lead = b.stem(const StemSpec('lead', layer: 0.32, reverb: 0.3, delayBeats: 1.5, delayFeedback: 0.35));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.3, stereo: true, delayBeats: 0.75, delayFeedback: 0.35, gain: 0.7));
    final all = b.introBars + b.loopBars;
    b.pattern(Inst.kick, const ['x..x............', 'x..x........x...'], stem: bed, start: 0, bars: all, vel: 0.7);
    b.pattern(Inst.hatClosed, const ['xxxxxxxxxxxxxxxx'], stem: bed, start: 0, bars: all, vel: 0.2);
    b.notes(Inst.synthBass, riffBass(b.chart, 0, all, b.key, const ['RRRRRRRRRRRRRRRR'], base: 36), stem: bed, vel: 0.5, legato: 0.6);
    addPad(b.ev, Inst.synthPad, b.chart, b.key, start: 0, beats: all * 4.0, floor: 50, size: 3, stem: bed, vel: 0.35);
    b.hits(
      Inst.synthBrass,
      const ['........X-......', '..............X.', '................', '........X-..X...'],
      stem: lead,
      vel: 0.55,
      floor: 57,
      size: 3,
      length: 0.8,
    );
    addArp(
      b.ev,
      Inst.synthArp,
      b.chart,
      b.key,
      start: b.loopStart,
      bars: b.loopBars,
      steps: 16,
      floor: 62,
      span: 2,
      shape: 'pulse',
      stem: hot,
      vel: 0.35,
      gate: 0.5,
      mask: 'x.xx.xx.x.xx.x.x',
    );
    b.pattern(Inst.gatedSnare, const ['................', '............x...'], stem: hot, vel: 0.45);
    // A distant, sparse lead: long notes that hang in the echo.
    final mel = b.melody(const MelodySpec(lo: 69, hi: 88, rhythms: ['x-------........', '........x-------', '................', 'x-----x---------'], form: 'ABAC'), salt: 3);
    _lead(b, lead, mel, vel: 0.4);
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 1.0 : 0.8, wet: 0.38);
    b.loops = false;
    b.setIntro(won ? 'bVI bVII | I' : 'iv | i', 2);
    b.setLoop(won ? 'I | bVII | IV | I' : 'i | bVI | iv | i', 4);
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.35, delayBeats: 0.75, delayFeedback: 0.3));
    final hot = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.3, stereo: true, delayBeats: 0.5, delayFeedback: 0.3, gain: 0.7));
    final k = b.key;
    if (won) {
      addArp(
        b.ev,
        Inst.synthArp,
        b.chart,
        b.key,
        start: 0,
        bars: 1,
        steps: 16,
        floor: 60,
        span: 3,
        shape: 'up',
        stem: hot,
        vel: 0.45,
        gate: 0.7,
      );
      for (final p in b.chart.at(4).closeVoicing(k, 60, size: 4)) {
        b.note(Inst.synthBrass, 4, 3.5, p, 0.7, stem: lead);
        b.note(Inst.synthPad, 4, 3.8, p - 12, 0.5, stem: bed);
      }
      b.note(Inst.synthLead, 4, 3.5, k + 16, 0.6, stem: lead, fx: Art.glide | Art.vibrato, glideFrom: k + 12.0);
      b.note(Inst.synthBass, 4, 3.5, k - 12, 0.7, stem: bed);
      b.note(Inst.kick, 4, 0.2, 0, 0.8, stem: bed);
      b.note(Inst.gatedSnare, 4, 0.2, 0, 0.6, stem: bed);
      b.note(Inst.crash, 4, 1, 0, 0.6, stem: bed);
      b.pattern(Inst.tomHigh, const ['........x.x.xxxx'], stem: bed, start: 0, bars: 1, vel: 0.45, pitch: 3);
    } else {
      b.note(Inst.synthLead, 0, 3.6, k + 12, 0.55, stem: lead, fx: Art.fall | Art.vibrato);
      for (final p in b.chart.at(0).closeVoicing(k, 55, size: 3)) {
        b.note(Inst.synthPad, 0, 3.8, p, 0.45, stem: bed);
      }
      for (final p in b.chart.at(4).closeVoicing(k, 52, size: 3)) {
        b.note(Inst.synthPad, 4, 3.8, p, 0.45, stem: bed);
      }
      b.note(Inst.synthBass, 4, 3.5, k - 12, 0.6, stem: bed, fx: Art.fall);
    }
    addPad(b.ev, Inst.synthPad, b.chart, b.key, start: b.loopStart, beats: b.loopBeats, floor: 55, stem: bed, vel: 0.3);
    addArp(b.ev, Inst.synthArp, b.chart, b.key, start: b.loopStart, bars: b.loopBars, steps: 8, floor: 64, stem: hot, vel: 0.25, gate: 0.5);
    return b.build();
  }
}
