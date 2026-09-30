import '../../core/audio.dart';
import '../../core/era_skin.dart';
import 'theory.dart';

/// Every voice the Film Reel Engine's band can play. Pitched instruments
/// read [NoteEvent.pitch] as a MIDI note; drums read it as a tuning offset
/// in semitones around their natural pitch (0 = standard).
enum Inst {
  // Keys and mallets.
  piano,
  honkyPiano,
  theatreOrgan,
  rhodes,
  vibes,
  xylophone,
  marimba,
  celesta,
  // Bass.
  uprightBass,
  tuba,
  electricBass,
  synthBass,
  // Strings and plucks.
  banjo,
  wahGuitar,
  clav,
  violin,
  strings,
  // Winds and brass.
  clarinet,
  mutedTrumpet,
  trumpet,
  trombone,
  altoSax,
  tenorSax,
  flute,
  // Synths.
  synthLead,
  synthArp,
  synthPad,
  synthBrass,
  // Drums and percussion.
  kick,
  snare,
  gatedSnare,
  brushTap,
  brushSweep,
  hatClosed,
  hatOpen,
  hatPedal,
  ride,
  crash,
  choke,
  rimClick,
  woodblock,
  templeBlock,
  tomLow,
  tomHigh,
  conga,
  bongo,
  clave,
  cowbell,
  shaker,
  timpani,
  clap,
  tambourine,
  gong;

  bool get isDrum => index >= Inst.kick.index;
}

/// Articulation bits for [NoteEvent.fx] (named `Art` so it never clashes
/// with the UI kit's `Fx` facade).
abstract final class Art {
  static const int accent = 1;
  static const int staccato = 2;

  /// Pitch scoops up into the note (jazz brass and reeds).
  static const int scoop = 4;

  /// Pitch falls off at the end (big-band fall).
  static const int fall = 8;

  /// Delayed vibrato on long notes.
  static const int vibrato = 16;

  /// Plunger / wah opening over the note.
  static const int wah = 32;

  /// Very soft ghost note.
  static const int ghost = 64;

  /// Glide from [NoteEvent.glideFrom] (trombone smear, synth portamento).
  static const int glide = 128;

  /// Tremolo / roll (mallets, drums, strings).
  static const int trem = 256;

  /// Growl / flutter tongue.
  static const int growl = 512;

  /// Slap / pop (bass) or rim (snare).
  static const int slap = 1024;
}

/// One note of a cue. Times are in beats from the cue's start (the intro's
/// first beat); swing and humanisation are applied by the renderer.
final class NoteEvent {
  const NoteEvent(
    this.beat,
    this.dur,
    this.pitch,
    this.vel,
    this.inst, {
    this.stem = 0,
    this.fx = 0,
    this.glideFrom = 0,
    this.straight = false,
  });

  final double beat;
  final double dur;
  final double pitch;
  final double vel;
  final Inst inst;
  final int stem;
  final int fx;
  final double glideFrom;

  /// Not swung (triplets, pre-placed grace notes).
  final bool straight;

  bool has(int flag) => fx & flag != 0;

  NoteEvent shifted(double beats) =>
      NoteEvent(beat + beats, dur, pitch, vel, inst, stem: stem, fx: fx, glideFrom: glideFrom, straight: straight);
}

/// A rendered stem's role in the adaptive mix.
final class StemSpec {
  const StemSpec(
    this.name, {
    this.layer = 0,
    this.gain = 1,
    this.pan = 0,
    this.reverb = 0.18,
    this.stereo = false,
    this.delayBeats = 0,
    this.delayFeedback = 0,
  });

  /// `bed`, `lead`, `hot` …
  final String name;

  /// Intensity at which the stem is half-way faded in (0 = always on).
  final double layer;
  final double gain;

  /// Mixer pan −1..1 (mono stems).
  final double pan;

  /// Reverb send.
  final double reverb;

  /// Rendered in stereo (synth pads and ping-pong delays).
  final bool stereo;

  /// Tempo-synced (ping-pong when [stereo]) echo, in beats; 0 = none.
  final double delayBeats;
  final double delayFeedback;

  /// Gain of this layer at [intensity] (smooth 0..1 ramp around [layer]).
  double layerGain(double intensity) {
    if (layer <= 0) return 1;
    final t = ((intensity - (layer - 0.12)) / 0.24).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// Room and period colour for a cue.
final class CueSound {
  const CueSound({
    this.roomSize = 0.5,
    this.damping = 0.5,
    this.wet = 0.25,
    this.lofi = 0.3,
    this.crackle = 0,
    this.wow = 0,
    this.sampleRate = 32000,
  });

  final double roomSize;
  final double damping;
  final double wet;
  final double lofi;
  final double crackle;
  final double wow;
  final int sampleRate;
}

/// A composed cue: metadata the director needs plus the notes to render.
final class CueScore {
  CueScore({
    required this.style,
    required this.mood,
    required this.keyMidi,
    required this.bpm,
    required this.beatsPerBar,
    required this.swing,
    required this.introBars,
    required this.loopBars,
    required this.loops,
    required this.chart,
    required this.stems,
    required this.events,
    required this.sound,
    this.jingleBars = 0,
    this.swing16 = false,
  });

  final MusicStyle style;
  final MusicMood mood;
  final int keyMidi;
  final double bpm;
  final int beatsPerBar;

  /// 0 = straight, 1 = full triplet swing (applied to off-beat 8ths, or to
  /// off-beat 16ths when [swing16]).
  final double swing;
  final bool swing16;

  /// Bars before the loop (a pickup / fanfare, or a jingle when ![loops]).
  final int introBars;

  /// Bars of the seamless loop (after the intro).
  final int loopBars;

  /// False for jingles: the intro plays once, then the (quiet) loop vamps.
  final bool loops;

  /// For jingles: the jingle's own length in bars (== [introBars]).
  final int jingleBars;

  final ChordChart chart;
  final List<StemSpec> stems;
  final List<NoteEvent> events;
  final CueSound sound;

  double get secondsPerBeat => 60.0 / bpm;
  double get introBeats => introBars * beatsPerBar.toDouble();
  double get loopBeats => loopBars * beatsPerBar.toDouble();
  double get introSeconds => introBeats * secondsPerBeat;
  double get loopSeconds => loopBeats * secondsPerBeat;

  /// Converts a (straight) beat position into seconds with swing applied.
  double beatToSeconds(double beat, {bool straight = false}) {
    if (straight || swing <= 0) return beat * secondsPerBeat;
    final unit = swing16 ? 0.5 : 1.0; // swing pair length in beats
    final pairs = (beat / unit).floorToDouble();
    final frac = beat / unit - pairs; // 0..1 inside the pair
    // Off-beat (0.5) moves towards the triplet position (2/3).
    final off = 0.5 + swing * (2.0 / 3.0 - 0.5);
    final warped = frac <= 0.5 ? frac / 0.5 * off : off + (frac - 0.5) / 0.5 * (1 - off);
    return (pairs + warped) * unit * secondsPerBeat;
  }
}
