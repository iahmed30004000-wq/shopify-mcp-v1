import '../../../../../core/sound/synth/rng.dart';
import '../../core/audio.dart';
import '../../core/era_skin.dart';
import 'grammar.dart';
import 'score.dart';
import 'theory.dart';

/// Scratch space for composing one cue: the chord chart (intro + loop),
/// stems and events, plus shortcuts to the grammar.
final class CueBuilder {
  CueBuilder({
    required this.style,
    required this.mood,
    required this.key,
    required this.bpm,
    required this.sound,
    required int seed,
    this.bpb = 4,
    this.swing = 0,
    this.swing16 = false,
  }) : seed = seed & 0x3fffffff,
       rng = SynthRandom(seed);

  final MusicStyle style;
  final MusicMood mood;
  final int key;
  final double bpm;
  final int bpb;
  final double swing;
  final bool swing16;
  final CueSound sound;
  final int seed;
  final SynthRandom rng;

  final List<ChordSlot> _slots = [];
  final List<NoteEvent> ev = [];
  final List<StemSpec> stems = [];
  int introBars = 0;
  int loopBars = 8;
  bool loops = true;
  ChordChart? _chart;

  double get introBeats => (introBars * bpb).toDouble();
  double get loopStart => introBeats;
  double get loopBeats => (loopBars * bpb).toDouble();

  /// Picks one of [options] with the builder's generator.
  T pick<T>(List<T> options) => options[rng.nextInt(options.length)];

  /// A fresh, independent seed for one part.
  int part(int salt) => (seed * 31 + salt * 7919) & 0x3fffffff;

  void setIntro(String progression, int bars) {
    introBars = bars;
    _slots.addAll(parseProgression(progression, beatsPerBar: bpb));
    _chart = null;
  }

  void setLoop(String progression, int bars) {
    loopBars = bars;
    _slots.addAll(parseProgression(progression, beatsPerBar: bpb, startBeat: introBeats));
    _chart = null;
  }

  ChordChart get chart => _chart ??= ChordChart([..._slots]..sort((a, b) => a.beat.compareTo(b.beat)));

  int stem(StemSpec s) {
    stems.add(s);
    return stems.length - 1;
  }

  /// Melody over the loop (or any passage).
  List<MelNote> melody(MelodySpec spec, {double? start, int? bars, int salt = 1}) => composeMelody(
    chart: chart,
    startBeat: start ?? loopStart,
    bars: bars ?? loopBars,
    beatsPerBar: bpb,
    keyMidi: key,
    spec: spec,
    seed: part(salt),
  );

  void notes(
    Inst inst,
    Iterable<MelNote> ns, {
    required int stem,
    double vel = 0.7,
    double accent = 0.15,
    int fx = 0,
    double transpose = 0,
    double legato = 1,
  }) => addNotes(ev, inst, ns, stem: stem, vel: vel, accentVel: accent, fx: fx, transpose: transpose, legato: legato);

  void pattern(
    Inst inst,
    List<String> pats, {
    required int stem,
    double? start,
    int? bars,
    double vel = 0.7,
    double pitch = 0,
    int fx = 0,
    double dur = 0.1,
  }) => addPattern(
    ev,
    inst,
    pats,
    start: start ?? loopStart,
    bars: bars ?? loopBars,
    beatsPerBar: bpb,
    stem: stem,
    vel: vel,
    pitch: pitch,
    fx: fx,
    dur: dur,
  );

  void hits(
    Inst inst,
    List<String> pats, {
    required int stem,
    double? start,
    int? bars,
    double vel = 0.6,
    int floor = 55,
    int size = 4,
    bool rootless = false,
    double strum = 0,
    double length = 0.9,
    int fx = 0,
    int topFx = 0,
  }) => addChordHits(
    ev,
    inst,
    chart,
    key,
    pats,
    start: start ?? loopStart,
    bars: bars ?? loopBars,
    beatsPerBar: bpb,
    stem: stem,
    vel: vel,
    floor: floor,
    size: size,
    rootless: rootless,
    strumBeats: strum,
    lengthScale: length,
    fx: fx,
    topFx: topFx,
  );

  void note(
    Inst inst,
    double beat,
    double dur,
    num pitch,
    double vel, {
    required int stem,
    int fx = 0,
    double glideFrom = 0,
    bool straight = false,
  }) => ev.add(NoteEvent(beat, dur, pitch.toDouble(), vel, inst, stem: stem, fx: fx, glideFrom: glideFrom, straight: straight));

  /// Crash / choke on the first beat of every [every]-bar phrase.
  void phraseCymbals(Inst inst, {required int stem, int every = 4, double vel = 0.5, double? start, int? bars}) {
    final s = start ?? loopStart;
    final n = bars ?? loopBars;
    for (var b = 0; b < n; b += every) {
      note(inst, s + b * bpb, 0.5, 0, vel, stem: stem);
    }
  }

  CueScore build() => CueScore(
    style: style,
    mood: mood,
    keyMidi: key,
    bpm: bpm,
    beatsPerBar: bpb,
    swing: swing,
    swing16: swing16,
    introBars: introBars,
    loopBars: loopBars,
    loops: loops,
    jingleBars: loops ? 0 : introBars,
    chart: chart,
    stems: stems,
    events: ev,
    sound: sound,
  );
}

/// Period colour derived from the era's [ScoreStyle].
CueSound cueSoundFor(ScoreStyle s, {double roomSize = 0.5, double damping = 0.5, double wet = 0.25, int? sampleRate}) {
  final sr =
      sampleRate ??
      switch (s.style) {
        MusicStyle.ragtime || MusicStyle.swing => 22050,
        MusicStyle.noirJazz => 24000,
        _ => 32000,
      };
  return CueSound(roomSize: roomSize, damping: damping, wet: wet, lofi: s.lofi, crackle: s.crackle, wow: s.lofi * 0.8, sampleRate: sr);
}

/// Every style composer: one cue per mood, deterministic in (style, seed).
abstract interface class StyleComposer {
  CueScore compose(MusicMood mood, ScoreStyle style, int seed);
}
