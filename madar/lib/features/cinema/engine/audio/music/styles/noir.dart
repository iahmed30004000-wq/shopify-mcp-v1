import '../../../core/audio.dart';
import '../../../core/era_skin.dart';
import '../cue_builder.dart';
import '../grammar.dart';
import '../score.dart';

/// 1940s noir: a slow walking upright bass, brushes stirring the snare,
/// sparse rootless piano, a breathy tenor or a Harmon-muted trumpet over
/// minor-ninth changes, vibraphone with the motor on.
final class NoirComposer implements StyleComposer {
  const NoirComposer();

  static const _slowCells = ['x---x.x.', 'x-----..', 'x.x.x---', '-x--x-x.', 'x--x--x.', '..x.x---', 'x-x-x-..'];
  static const _bopCells = ['x.xxx.x.', 'xxx.x.x-', '.xxxx.x.', 'x.x.xxx.', 'x-x.x.xx'];

  @override
  CueScore compose(MusicMood mood, ScoreStyle s, int seed) => switch (mood) {
    MusicMood.calm => _ballad(s, seed),
    MusicMood.tension => _stakeout(s, seed),
    MusicMood.action => _chase(s, seed, boss: false),
    MusicMood.boss => _chase(s, seed, boss: true),
    MusicMood.victory || MusicMood.defeat => _jingle(s, seed, won: mood == MusicMood.victory),
    _ => _prowl(mood, s, seed),
  };

  CueBuilder _builder(MusicMood mood, ScoreStyle s, int seed, double tempo, {double? swing, double wet = 0.3}) => CueBuilder(
    style: s.style,
    mood: mood,
    key: s.rootMidi,
    bpm: s.tempo * tempo,
    swing: swing ?? s.swing,
    sound: cueSoundFor(s, roomSize: 0.62, damping: 0.45, wet: wet),
    seed: seed * 19 + mood.index,
  );

  void _brushes(CueBuilder b, int stem, {double vel = 0.5, required double start, required int bars}) {
    b.pattern(Inst.brushSweep, const ['x.......x.......'], stem: stem, start: start, bars: bars, vel: vel, dur: 1.9);
    b.pattern(Inst.brushTap, const ['....x.......x...', '....x.......x..g'], stem: stem, start: start, bars: bars, vel: vel + 0.05);
    b.pattern(Inst.kick, const ['x.......x.......'], stem: stem, start: start, bars: bars, vel: 0.22);
  }

  CueScore _prowl(MusicMood mood, ScoreStyle s, int seed) {
    final title = mood == MusicMood.title;
    final b = _builder(mood, s, seed, title ? 0.95 : 1.0);
    b.setIntro('i9', 1);
    b.setLoop(
      b.pick(const [
        'i9 | iv9 | iiø7 Vb9 | i9 | bVI7 | Vb9 | i9 bVI7 | iiø7 Vb9',
        'i9 | i9 | iv9 | iv9 | bVIM7 | iiø7 | Vb9 | Vb9',
        'i9 | bIIM7 | iiø7 | Vb9 | i9 | iv9 | bVI7 | Vb9',
        // Minor blues, folded into eight bars.
        'i9 | iv9 | i9 | i9 | iv9 | iv9 | bVI7 Vb9 | i9 Vb9',
      ]),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.14));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.3, pan: 0.1));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.3, pan: -0.25, gain: 0.8));
    final all = b.introBars + b.loopBars;
    b.notes(Inst.uprightBass, walkingBass(b.chart, b.loopStart, b.loopBeats, b.key, b.rng, lo: 31, hi: 50), stem: bed, vel: 0.62);
    _brushes(b, bed, start: 0, bars: all);
    b.hits(
      Inst.piano,
      const ['x..x....', '......x.', '..x...x.', 'x-......'],
      stem: bed,
      vel: 0.34,
      floor: 52,
      size: 4,
      rootless: true,
      length: 0.8,
    );
    final mel = b.melody(
      MelodySpec(lo: 55, hi: 77, rhythms: _slowCells, steps: 8, form: 'ABAC', blue: 0.18, extensions: 0.35, chromatic: 0.2, stepBias: 0.75),
    );
    for (final n in mel) {
      final fx = (n.dur >= 1 ? Art.vibrato : 0) | (n.accent ? Art.scoop : 0);
      if (title) {
        b.note(Inst.mutedTrumpet, n.beat, n.dur, n.pitch + 5, 0.55, stem: lead, fx: fx);
      } else {
        b.note(Inst.tenorSax, n.beat, n.dur, n.pitch, 0.58 + (n.accent ? 0.1 : 0), stem: lead, fx: fx);
      }
    }
    final vib = b.melody(
      const MelodySpec(lo: 67, hi: 84, rhythms: ['x---....', '....x---', 'x.x.x---'], steps: 8, form: 'AB', extensions: 0.5),
      salt: 4,
    );
    b.notes(Inst.vibes, vib, stem: hot, vel: 0.45);
    b.pattern(Inst.ride, const ['x...x.x.x...x.x.'], stem: hot, vel: 0.3);
    // Intro: low piano, bass pedal and a vibes shimmer.
    b.note(Inst.uprightBass, 0, 3.5, b.key - 24, 0.6, stem: bed);
    for (final p in b.chart.at(0).closeVoicing(b.key, 48, size: 4, rootless: true)) {
      b.note(Inst.piano, 0, 3.5, p, 0.35, stem: bed);
    }
    for (var i = 0; i < 6; i++) {
      final v = b.chart.at(0).closeVoicing(b.key, 67, size: 3);
      b.note(Inst.vibes, 1 + i * 0.5, 0.45, v[i % 3], 0.3 + i * 0.03, stem: hot);
    }
    return b.build();
  }

  CueScore _ballad(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.calm, s, seed, 0.85, swing: 0.6, wet: 0.36);
    b.setIntro('Vb9', 1);
    b.setLoop(b.pick(const ['i9 | bVIM7 | iv9 | Vb9 | i9 | iv9 | bVIM7 | Vb9', 'bIIIM7 | bVIM7 | iiø7 | Vb9 | i9 | iv9 | bVIM7 | Vb9']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.35, pan: -0.1));
    final hot = b.stem(const StemSpec('hot', layer: 0.6, reverb: 0.35, pan: 0.25, gain: 0.8));
    final all = b.introBars + b.loopBars;
    b.notes(Inst.uprightBass, twoFeelBass(b.chart, 0, all, 4, b.key, b.rng, lo: 31, hi: 50, dur: 1.9), stem: bed, vel: 0.5);
    b.pattern(Inst.brushSweep, const ['x.......x.......'], stem: bed, start: 0, bars: all, vel: 0.4, dur: 1.9);
    b.hits(
      Inst.piano,
      const ['x-......', '....x-..'],
      stem: bed,
      start: 0,
      bars: all,
      vel: 0.28,
      floor: 52,
      size: 4,
      rootless: true,
      length: 1.2,
    );
    final mel = b.melody(MelodySpec(lo: 62, hi: 81, rhythms: _slowCells, steps: 8, form: 'AABA', extensions: 0.4, stepBias: 0.8));
    b.notes(Inst.vibes, mel, stem: lead, vel: 0.5);
    final counter = b.melody(
      const MelodySpec(lo: 50, hi: 69, rhythms: ['x-------', 'x---x---', '....x---'], steps: 8, form: 'AB', stepBias: 0.85),
      salt: 9,
    );
    b.notes(Inst.tenorSax, counter, stem: hot, vel: 0.42, fx: Art.vibrato);
    return b.build();
  }

  CueScore _stakeout(ScoreStyle s, int seed) {
    final b = _builder(MusicMood.tension, s, seed, 0.92, swing: 0.4);
    b.setIntro('i', 1);
    b.setLoop(b.pick(const ['i | i | io7 | io7 | iv | bII | Vb9 | Vb9', 'i | bII | i | bII | iv | iv | Vb9 | bII']), 8);
    final bed = b.stem(const StemSpec('bed', reverb: 0.16));
    final lead = b.stem(const StemSpec('lead', layer: 0.32, reverb: 0.3, pan: 0.2));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.3, pan: -0.2, gain: 0.85));
    final all = b.introBars + b.loopBars;
    final riff = riffBass(b.chart, 0, all, b.key, const ['R..R..F.....R...', 'R..R..b.....F...'], base: 38);
    b.notes(Inst.uprightBass, riff, stem: bed, vel: 0.62);
    b.pattern(Inst.brushSweep, const ['x...............'], stem: bed, start: 0, bars: all, vel: 0.35, dur: 3.5);
    b.pattern(Inst.rimClick, const ['............x...'], stem: bed, start: 0, bars: all, vel: 0.4);
    // Low piano clusters on the "and" of 4.
    for (var bar = 0; bar < all; bar++) {
      final beat = bar * 4 + 3.5;
      final r = b.chart.at(beat + 0.5).rootNear(b.key, 40);
      for (final p in [r, r + 1, r + 6]) {
        b.note(Inst.piano, beat, 0.4, p, 0.42, stem: bed);
      }
    }
    final stabs = b.melody(
      const MelodySpec(lo: 60, hi: 76, rhythms: ['....x-..', 'x-......', '......x.', '........'], steps: 8, form: 'ABAC', chromatic: 0.3),
    );
    b.notes(Inst.mutedTrumpet, stabs, stem: lead, vel: 0.55, fx: Art.scoop);
    for (var bar = 0; bar < b.loopBars; bar++) {
      final start = b.loopStart + bar * 4;
      final v = b.chart.at(start).closeVoicing(b.key, 64, size: 4);
      for (final p in v) {
        b.note(Inst.vibes, start, 3.8, p, 0.28, stem: hot, fx: Art.trem);
      }
    }
    b.pattern(Inst.ride, const ['x.......x.......'], stem: hot, vel: 0.22);
    return b.build();
  }

  CueScore _chase(ScoreStyle s, int seed, {required bool boss}) {
    final mood = boss ? MusicMood.boss : MusicMood.action;
    final b = _builder(mood, s, seed, boss ? 1.3 : 1.5, swing: 0.5, wet: 0.24);
    b.setIntro(boss ? 'i' : 'Vb9', 1);
    b.setLoop(
      boss
          ? b.pick(const ['i | i | bVI7 | Vb9 | i | iv | bII | Vb9', 'i | iv | i | bVI7 | iiø7 | Vb9 | i | Vb9'])
          : b.pick(const ['i7 | i7 | iv7 | iv7 | bVI7 | Vb9 | i7 | Vb9', 'i7 | iv7 | i7 | bVI7 | iiø7 | Vb9 | i7 | iiø7 Vb9']),
      8,
    );
    final bed = b.stem(const StemSpec('bed', reverb: 0.12));
    final lead = b.stem(const StemSpec('lead', layer: 0.3, reverb: 0.22, pan: 0.12));
    final hot = b.stem(const StemSpec('hot', layer: 0.62, reverb: 0.22, pan: -0.2, gain: 0.85));
    final all = b.introBars + b.loopBars;
    if (boss) {
      final riff = riffBass(b.chart, 0, all, b.key, const ['R..R..b.R...F.O.', 'R..R..b.R.R.F...'], base: 38);
      b.notes(Inst.uprightBass, riff, stem: bed, vel: 0.7);
      b.notes(Inst.piano, riff, stem: bed, vel: 0.5, transpose: 12, gain: 0.7);
      b.pattern(Inst.tomLow, const ['x.......x.....x.', 'x.......x...x.x.'], stem: bed, start: 0, bars: all, vel: 0.5);
    } else {
      b.notes(Inst.uprightBass, walkingBass(b.chart, 0, all * 4.0, b.key, b.rng, lo: 31, hi: 52), stem: bed, vel: 0.66);
    }
    b.pattern(Inst.ride, const ['x...x.x.x...x.x.'], stem: bed, start: 0, bars: all, vel: 0.42);
    b.pattern(Inst.hatPedal, const ['....x.......x...'], stem: bed, start: 0, bars: all, vel: 0.45);
    b.pattern(Inst.snare, const ['..g...g.....g.g.', '......g...g...x.'], stem: bed, start: 0, bars: all, vel: 0.4);
    b.hits(Inst.piano, const ['x..x....', '...x..x.'], stem: bed, vel: 0.3, floor: 52, rootless: true, length: 0.6);
    final mel = b.melody(
      MelodySpec(lo: boss ? 55 : 64, hi: boss ? 77 : 86, rhythms: _bopCells, steps: 8, form: 'AABA', chromatic: 0.25, blue: 0.15),
    );
    for (final n in mel) {
      if (boss) {
        b.note(Inst.tenorSax, n.beat, n.dur, n.pitch, 0.64 + (n.accent ? 0.1 : 0), stem: lead, fx: n.dur >= 1 ? Art.growl : 0);
      } else {
        b.note(Inst.trumpet, n.beat, n.dur, n.pitch, 0.6 + (n.accent ? 0.1 : 0), stem: lead, fx: n.dur >= 1 ? Art.fall : 0);
      }
    }
    b.hits(
      Inst.trombone,
      const ['......X.........', '..............X.'],
      stem: hot,
      vel: 0.55,
      floor: 46,
      size: 3,
      length: 0.6,
      topFx: Art.fall,
    );
    b.phraseCymbals(Inst.crash, stem: hot, vel: 0.4);
    if (boss) {
      for (var bar = 0; bar < b.loopBars; bar += 2) {
        final start = b.loopStart + bar * 4;
        for (final p in b.chart.at(start).closeVoicing(b.key, 66, size: 3)) {
          b.note(Inst.vibes, start, 3.8, p, 0.3, stem: hot, fx: Art.trem);
        }
      }
      b.note(Inst.gong, 0, 2, 0, 0.5, stem: bed);
    }
    b.pattern(Inst.snare, const ['x.x.x.x.x.xxX...'], stem: bed, start: 0, bars: 1, vel: 0.45);
    return b.build();
  }

  CueScore _jingle(ScoreStyle s, int seed, {required bool won}) {
    final mood = won ? MusicMood.victory : MusicMood.defeat;
    final b = _builder(mood, s, seed, won ? 0.9 : 0.75, swing: 0.4, wet: 0.36);
    b.loops = false;
    b.setIntro(won ? 'iv9 Vb9 | IM9' : 'iiø7 Vb9 | iM7', 2);
    b.setLoop(won ? 'IM9 | IVM7 | IM9 | IVM7' : 'iM7 | iM7 | iv9 | iv9', 4);
    final bed = b.stem(const StemSpec('bed', reverb: 0.2));
    final lead = b.stem(const StemSpec('lead', layer: 0.2, reverb: 0.35));
    final hot = b.stem(const StemSpec('hot', layer: 0.5, reverb: 0.35, gain: 0.85));
    final k = b.key;
    if (won) {
      final v = [k + 2, k + 7, k + 11, k + 14, k + 19, k + 23, k + 26];
      for (var i = 0; i < v.length; i++) {
        b.note(Inst.vibes, i * 0.5, 0.6, v[i], 0.4 + i * 0.04, stem: hot);
      }
      for (final p in b.chart.at(4).closeVoicing(k, 52, size: 5)) {
        b.note(Inst.piano, 4, 3.8, p, 0.45, stem: bed);
      }
      b.note(Inst.uprightBass, 4, 3.8, k - 24, 0.6, stem: bed);
      b.note(Inst.tenorSax, 2, 1.8, k + 11, 0.55, stem: lead, fx: Art.scoop);
      b.note(Inst.tenorSax, 4, 3.8, k + 14, 0.6, stem: lead, fx: Art.vibrato);
      b.note(Inst.ride, 4, 1, 0, 0.4, stem: hot);
    } else {
      const line = [15, 14, 12, 11, 7];
      for (var i = 0; i < line.length; i++) {
        b.note(
          Inst.tenorSax,
          i * 0.75,
          i == line.length - 1 ? 4.5 : 0.7,
          k + line[i] - 12,
          0.55,
          stem: lead,
          fx: i == line.length - 1 ? Art.vibrato : 0,
        );
      }
      for (final p in b.chart.at(4).closeVoicing(k, 50, size: 4)) {
        b.note(Inst.piano, 4, 3.8, p, 0.4, stem: bed);
      }
      b.note(Inst.uprightBass, 4, 3.8, k - 24, 0.55, stem: bed);
      b.note(Inst.brushSweep, 4, 2, 0, 0.4, stem: hot);
    }
    b.notes(Inst.uprightBass, twoFeelBass(b.chart, b.loopStart, b.loopBars, 4, k, b.rng, lo: 31, hi: 50, dur: 1.9), stem: bed, vel: 0.35);
    b.pattern(Inst.brushSweep, const ['x.......x.......'], stem: bed, vel: 0.28, dur: 1.9);
    final vib = b.melody(
      const MelodySpec(lo: 67, hi: 84, rhythms: ['x---....', '....x---'], steps: 8, form: 'AB', extensions: 0.5),
      salt: 12,
    );
    b.notes(Inst.vibes, vib, stem: lead, vel: 0.3);
    return b.build();
  }
}
