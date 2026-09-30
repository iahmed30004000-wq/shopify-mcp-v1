import 'dart:math' as math;

import '../../../../../core/sound/synth/rng.dart';
import 'score.dart';
import 'theory.dart';

/// A melody note before it is given an instrument.
final class MelNote {
  MelNote(this.beat, this.dur, this.pitch, {this.accent = false});

  final double beat;
  double dur;
  int pitch;
  bool accent;
}

/// How phrases end.
enum Cadence {
  /// Loops: the last bar leads back to the top (ends on a V-chord tone).
  loop,

  /// Jingles: ends on the tonic, held.
  resolve,
}

/// Parameters of the phrase-level melody grammar.
final class MelodySpec {
  const MelodySpec({
    required this.lo,
    required this.hi,
    required this.rhythms,
    this.steps = 16,
    this.form = 'ABAC',
    this.stepBias = 0.68,
    this.leap = 0.1,
    this.chromatic = 0.12,
    this.repeat = 0.08,
    this.blue = 0.0,
    this.extensions = 0.0,
    this.cadence = Cadence.loop,
    this.cadenceRhythm,
  });

  /// MIDI range.
  final int lo, hi;

  /// One-bar rhythm cells over [steps] grid steps: `x` onset, `-` hold,
  /// `.` rest. A cell may start with `-` (tied from the previous bar).
  final List<String> rhythms;
  final int steps;

  /// Phrase form: one letter per equal slice of the passage ("AABA",
  /// "ABAC"…). Repeated letters restate their material over the new chords.
  final String form;

  /// Probability of stepwise motion on weak notes.
  final double stepBias;

  /// Probability of a leap (a 4th–6th) on strong notes.
  final double leap;

  /// Probability of a chromatic approach into strong notes.
  final double chromatic;

  /// Probability of repeating the previous pitch.
  final double repeat;

  /// Probability of blue-note inflections (b3 / b5 / b7 of the key).
  final double blue;

  /// Probability that strong notes land on 9ths / 13ths.
  final double extensions;
  final Cadence cadence;

  /// Rhythm of the final bar (defaults: long note for [Cadence.resolve]).
  final String? cadenceRhythm;
}

/// Opening interval patterns of famous themes (semitones). The melody
/// grammar re-rolls any phrase containing one of these, so a generated
/// line can never accidentally quote a well-known tune.
const List<List<int>> famousIncipits = [
  [1, 1, 8, -8, 8, -8], // 1902 rag opening
  [2, 1, 2, 2, -4, 4], // "mountain king" march
  [0, 0, 3, -1, 0, -2], // funeral march
  [0, 0, 0, 0, 5, 2], // overture galop
  [-2, 2, -2, -2, -1, -2], // organ toccata
  [-1, 1, -1, 1, -5, 3], // bagatelle
  [0, 1, 2, 0, -2, -1], // joy hymn
  [0, 7, 0, 2, 0, -2], // nursery tune
  [0, 2, -2, 5, -1], // birthday song
  [3, -3, 0, 5, -5, -2], // 1980s synth hook
  [0, 2, -2, 3, -3, 5], // 1950s TV-detective bass riff
  [1, 2, 1, -4, 1, 2], // sneaky-cat saxophone theme
  [2, 0, 0, 0, -2, 0], // spy-film guitar vamp
  [0, 3, 2, -5, 0, -2], // 5/4 spy theme
  [1, -1, -4, 4, 1, -1], // twilight TV motif
  [1, -1, 1, -1, 1, -1], // shark ostinato
  [-1, -1, -1, 1, -1, -1], // bumblebee
];

/// True when [pitches] contain a famous incipit anywhere.
bool quotesFamousTune(List<int> pitches) {
  if (pitches.length < 6) return false;
  final iv = [for (var i = 1; i < pitches.length; i++) pitches[i] - pitches[i - 1]];
  for (final inc in famousIncipits) {
    for (var s = 0; s + inc.length <= iv.length; s++) {
      var match = true;
      for (var k = 0; k < inc.length; k++) {
        if (iv[s + k] != inc[k]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
  }
  return false;
}

/// Parses a one-bar rhythm cell into (onsetStep, lengthSteps) pairs.
/// A leading `-` run is returned as onset −1 (tie from the previous note).
List<(int, int)> parseRhythm(String cell) {
  final out = <(int, int)>[];
  var i = 0;
  final n = cell.length;
  while (i < n) {
    final c = cell[i];
    if (c == 'x' || c == 'X' || (c == '-' && i == 0)) {
      final start = c == '-' ? -1 : i;
      var j = i + 1;
      while (j < n && cell[j] == '-') {
        j++;
      }
      out.add((start, j - i));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

/// Phrase-grammar melody over [chart] from [startBeat] for [bars] bars.
List<MelNote> composeMelody({
  required ChordChart chart,
  required double startBeat,
  required int bars,
  required int beatsPerBar,
  required int keyMidi,
  required MelodySpec spec,
  required int seed,
}) {
  for (var attempt = 0; attempt < 8; attempt++) {
    final notes = _melodyAttempt(chart, startBeat, bars, beatsPerBar, keyMidi, spec, seed + attempt * 7777);
    if (!quotesFamousTune([for (final n in notes) n.pitch])) return notes;
  }
  // Extremely unlikely: fall back to a plain chord-tone line.
  return _melodyAttempt(chart, startBeat, bars, beatsPerBar, keyMidi, spec.withForm('A'), seed ^ 0xABCDEF);
}

extension on MelodySpec {
  MelodySpec withForm(String f) => MelodySpec(
    lo: lo,
    hi: hi,
    rhythms: rhythms,
    steps: steps,
    form: f,
    stepBias: stepBias,
    leap: leap,
    chromatic: chromatic,
    repeat: repeat,
    blue: blue,
    extensions: extensions,
    cadence: cadence,
    cadenceRhythm: cadenceRhythm,
  );
}

List<MelNote> _melodyAttempt(ChordChart chart, double startBeat, int bars, int beatsPerBar, int keyMidi, MelodySpec spec, int seed) {
  final form = spec.form.isEmpty ? 'A' : spec.form;
  final sliceBars = math.max(1, bars ~/ form.length);
  final stepBeats = beatsPerBar / spec.steps;
  final out = <MelNote>[];
  final letterCells = <String, List<int>>{};
  final letterSeeds = <String, int>{};
  final top = SynthRandom(seed);
  var prev = (spec.lo + spec.hi) ~/ 2;
  // Start near the tonic's chord tone in the middle of the range.
  final firstChord = chart.at(startBeat);
  final tones = firstChord.tonesIn(keyMidi, spec.lo, spec.hi, withExtensions: false);
  if (tones.isNotEmpty) prev = tones.reduce((a, b) => (a - prev).abs() <= (b - prev).abs() ? a : b);

  for (var li = 0; li < form.length; li++) {
    final letter = form[li];
    final isRepeat = letterSeeds.containsKey(letter);
    final letterSeed = letterSeeds.putIfAbsent(letter, () => top.nextUint32());
    final cells = letterCells.putIfAbsent(letter, () => [for (var b = 0; b < sliceBars; b++) top.nextInt(spec.rhythms.length)]);
    final lastLetter = li == form.length - 1;
    for (var b = 0; b < sliceBars; b++) {
      final bar = li * sliceBars + b;
      if (bar >= bars) break;
      final barBeat = startBeat + bar * beatsPerBar;
      final lastBar = lastLetter && b == sliceBars - 1;
      String cell = spec.rhythms[cells[b] % spec.rhythms.length];
      if (lastBar && spec.cadenceRhythm != null) cell = spec.cadenceRhythm!;
      if (lastBar && spec.cadenceRhythm == null && spec.cadence == Cadence.resolve) {
        cell = 'x${'-' * (spec.steps - 1)}';
      }
      // Repeats reuse the letter's decisions, except the variant's last bar.
      final variantBar = isRepeat && b == sliceBars - 1;
      final rng = SynthRandom(letterSeed + b * 31 + (variantBar ? li * 977 : 0));
      final rhythm = parseRhythm(cell);
      // Contour: rise through the first half of the slice, fall after.
      final rising = (b + 0.5) / sliceBars < 0.55;
      for (final (step, len) in rhythm) {
        if (step < 0) {
          // Tie into this bar.
          if (out.isNotEmpty) out.last.dur += len * stepBeats;
          continue;
        }
        final beat = barBeat + step * stepBeats;
        final dur = len * stepBeats;
        final chord = chart.at(beat);
        final posInBar = step / spec.steps;
        final strong = posInBar == 0 || posInBar == 0.5 || dur >= 1.0 - 1e-9 || out.isEmpty;
        int p;
        if (rng.nextDouble() < spec.repeat && out.isNotEmpty && !strong) {
          p = prev;
        } else if (strong) {
          final ext = rng.nextDouble() < spec.extensions;
          final cands = chord.tonesIn(keyMidi, spec.lo, spec.hi, withExtensions: ext);
          var desired = prev + (rising ? 1 : -1) * (rng.nextDouble() < spec.leap ? 5 + rng.nextInt(4) : 1 + rng.nextInt(3));
          if (rng.nextDouble() < 0.25) desired = prev + (rising ? -2 : 2);
          p = _nearest(cands, desired, prev, rng);
        } else {
          final cands = chord.scaleIn(keyMidi, spec.lo, spec.hi);
          final stepwise = rng.nextDouble() < spec.stepBias;
          final dir = (rising ? 1 : -1) * (rng.nextDouble() < 0.72 ? 1 : -1);
          final idx = _indexNear(cands, prev);
          final move = stepwise ? 1 : 2 + rng.nextInt(2);
          p = cands.isEmpty ? prev : cands[(idx + dir * move).clamp(0, cands.length - 1)];
          if (rng.nextDouble() < spec.blue) p = _blueNote(keyMidi, p, spec.lo, spec.hi, rng);
        }
        // After a leap, turn back by step (gap fill).
        if (out.length >= 2) {
          final lastIv = out.last.pitch - out[out.length - 2].pitch;
          if (lastIv.abs() >= 5 && (p - out.last.pitch).sign == lastIv.sign) {
            final cands = chord.scaleIn(keyMidi, spec.lo, spec.hi);
            final idx = _indexNear(cands, out.last.pitch);
            if (cands.isNotEmpty) p = cands[(idx - lastIv.sign).clamp(0, cands.length - 1)];
          }
        }
        p = p.clamp(spec.lo, spec.hi);
        out.add(MelNote(beat, dur, p, accent: strong && posInBar != 0 || (step % 4 != 0 && len >= 3)));
        prev = p;
      }
    }
  }
  // Chromatic approaches into strong notes.
  final ar = SynthRandom(seed ^ 0x55AA);
  for (var i = 0; i + 1 < out.length; i++) {
    final a = out[i], b = out[i + 1];
    final posB = ((b.beat - startBeat) % beatsPerBar) / beatsPerBar;
    final strongB = posB == 0 || posB == 0.5;
    if (strongB && a.dur <= 0.5 + 1e-9 && (b.beat - a.beat) <= 0.75 && ar.nextDouble() < spec.chromatic) {
      a.pitch = (b.pitch + (ar.nextDouble() < 0.7 ? -1 : 1)).clamp(spec.lo, spec.hi);
    }
  }
  // Cadence.
  if (out.isNotEmpty) {
    final last = out.last;
    final chord = chart.at(last.beat);
    if (spec.cadence == Cadence.resolve) {
      final tonic = <int>[
        for (var m = spec.lo; m <= spec.hi; m++)
          if ((m - keyMidi) % 12 == 0 || (m - keyMidi - chordThird(chord)) % 12 == 0) m,
      ];
      if (tonic.isNotEmpty) last.pitch = _nearest(tonic, last.pitch, last.pitch, null);
    } else {
      final cands = chord.tonesIn(keyMidi, spec.lo, spec.hi, withExtensions: false);
      if (cands.isNotEmpty && !chord.contains((last.pitch - keyMidi) % 12)) last.pitch = _nearest(cands, last.pitch, last.pitch, null);
    }
  }
  return out;
}

int chordThird(Chord c) => c.isMinor ? 3 : 4;

int _indexNear(List<int> xs, int p) {
  var best = 0;
  var d = 1 << 30;
  for (var i = 0; i < xs.length; i++) {
    final dd = (xs[i] - p).abs();
    if (dd < d) {
      d = dd;
      best = i;
    }
  }
  return best;
}

int _nearest(List<int> cands, int desired, int prev, SynthRandom? rng) {
  if (cands.isEmpty) return desired;
  var best = cands.first;
  var bestScore = double.infinity;
  for (final c in cands) {
    var score = (c - desired).abs().toDouble();
    if (c == prev) score += 1.5; // mild aversion to static lines
    if ((c - prev).abs() > 9) score += 4; // avoid wild leaps
    if (rng != null) score += rng.nextDouble() * 0.8;
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

int _blueNote(int keyMidi, int near, int lo, int hi, SynthRandom rng) {
  const blues = [3, 6, 10];
  final pc = blues[rng.nextInt(blues.length)];
  var m = near - ((near - keyMidi - pc) % 12 + 12) % 12;
  if (near - m > 6) m += 12;
  return m.clamp(lo, hi);
}

// -----------------------------------------------------------------------------
// Bass lines

/// Quarter-note walking bass: roots on chord changes, chromatic or
/// scalar approaches into the next root.
List<MelNote> walkingBass(ChordChart chart, double start, double beats, int keyMidi, SynthRandom rng, {int lo = 31, int hi = 55}) {
  final out = <MelNote>[];
  var prev = chart.at(start).rootNear(keyMidi, 40).clamp(lo, hi);
  for (var b = 0.0; b < beats - 1e-9; b += 1) {
    final beat = start + b;
    final chord = chart.at(beat);
    final slot = chart.slotAt(beat);
    final isChange = (beat - slot.beat).abs() < 1e-6;
    final next = chart.at(beat + 1);
    final nextIsChange = (chart.slotAt(beat + 1).beat - (beat + 1)).abs() < 1e-6 || b + 1 >= beats;
    int p;
    if (isChange || out.isEmpty) {
      p = chord.rootNear(keyMidi, prev);
      if (rng.nextDouble() < 0.15) p = _nearest(chord.tonesIn(keyMidi, lo, hi, withExtensions: false), prev, prev, rng);
    } else if (nextIsChange) {
      final target = next.rootNear(keyMidi, prev);
      final r = rng.nextDouble();
      if (r < 0.55) {
        p = target + (prev < target ? -1 : 1);
      } else if (r < 0.8) {
        p = target + 7 > hi ? target - 5 : target + 7;
      } else {
        p = target + (prev < target ? -2 : 2);
      }
    } else {
      final cands = chord.scaleIn(keyMidi, lo, hi);
      final idx = _indexNear(cands, prev);
      final dir = rng.nextDouble() < 0.5 ? 1 : -1;
      p = cands.isEmpty ? prev : cands[(idx + dir * (1 + rng.nextInt(2))).clamp(0, cands.length - 1)];
      if (rng.nextDouble() < 0.3) p = _nearest(chord.tonesIn(keyMidi, lo, hi, withExtensions: false), prev + dir * 4, prev, rng);
    }
    while (p < lo) {
      p += 12;
    }
    while (p > hi) {
      p -= 12;
    }
    out.add(MelNote(beat, 0.92, p, accent: b % 2 == 1));
    prev = p;
  }
  return out;
}

/// Root–fifth bass (two-beat feel, oom-pah): roots on beat 1, fifths on the
/// half bar; approach notes before changes when [pickups].
List<MelNote> twoFeelBass(
  ChordChart chart,
  double start,
  int bars,
  int beatsPerBar,
  int keyMidi,
  SynthRandom rng, {
  int lo = 33,
  int hi = 52,
  double dur = 1.8,
  bool pickups = true,
}) {
  final out = <MelNote>[];
  var prev = chart.at(start).rootNear(keyMidi, 40);
  final half = beatsPerBar == 3 ? 3.0 : beatsPerBar / 2;
  for (var bar = 0; bar < bars; bar++) {
    for (var h = 0.0; h < beatsPerBar - 1e-9; h += half) {
      final beat = start + bar * beatsPerBar + h;
      final chord = chart.at(beat);
      final slot = chart.slotAt(beat);
      final changed = (beat - slot.beat).abs() < 1e-6;
      int p;
      if (changed || h == 0) {
        p = chord.rootNear(keyMidi, prev);
      } else {
        final fifth = chord.rootNear(keyMidi, prev) + 7;
        p = fifth > hi ? fifth - 12 : fifth;
      }
      while (p < lo) {
        p += 12;
      }
      while (p > hi) {
        p -= 12;
      }
      final isLastHalf = h + half >= beatsPerBar - 1e-9;
      if (pickups && isLastHalf && beatsPerBar == 4 && rng.nextDouble() < 0.35) {
        out.add(MelNote(beat, 1.0, p));
        final next = chart.at(beat + half).rootNear(keyMidi, p);
        out.add(MelNote(beat + 1, math.min(dur, 1.0) * 0.9, next + (p < next ? -1 : 1)));
      } else {
        out.add(MelNote(beat, dur, p));
      }
      prev = p;
    }
  }
  return out;
}

/// Mambo tumbao: the "and of 2" and an anticipated beat 4 (next chord).
List<MelNote> tumbaoBass(ChordChart chart, double start, int bars, int keyMidi, {int lo = 33, int hi = 52}) {
  final out = <MelNote>[];
  var prev = chart.at(start).rootNear(keyMidi, 40);
  for (var bar = 0; bar < bars; bar++) {
    final b0 = start + bar * 4;
    final c = chart.at(b0 + 1.5);
    var fifth = c.rootNear(keyMidi, prev) + 7;
    if (fifth > hi) fifth -= 12;
    final next = chart.at(b0 + 4.0 - 1e-6 + (bar == bars - 1 ? -3.9 : 0.5));
    var root = next.rootNear(keyMidi, fifth);
    while (root < lo) {
      root += 12;
    }
    while (root > hi) {
      root -= 12;
    }
    out.add(MelNote(b0 + 1.5, 1.4, fifth.clamp(lo, hi)));
    out.add(MelNote(b0 + 3.0, 1.5, root, accent: true));
    prev = root;
  }
  return out;
}

/// Sixteenth-grid bass riff from [pattern] (per bar: `R` root, `O` octave,
/// `F` fifth, `7` seventh, `3` third, `g` ghost root, `-` hold, `.` rest),
/// transposed onto the chord of each onset.
List<MelNote> riffBass(ChordChart chart, double start, int bars, int keyMidi, List<String> patterns, {int base = 40, int beatsPerBar = 4}) {
  final out = <MelNote>[];
  for (var bar = 0; bar < bars; bar++) {
    final pat = patterns[bar % patterns.length];
    final steps = pat.length;
    final stepBeats = beatsPerBar / steps;
    for (var i = 0; i < steps; i++) {
      final c = pat[i];
      if (c == '.' || c == '-') continue;
      var len = 1;
      while (i + len < steps && pat[i + len] == '-') {
        len++;
      }
      final beat = start + bar * beatsPerBar + i * stepBeats;
      final chord = chart.at(beat);
      final root = chord.rootNear(keyMidi, base);
      final third = root + (chord.isMinor ? 3 : 4);
      final p = switch (c) {
        'O' => root + 12,
        'F' => root + 7,
        '7' => root + (chord.q == ChordQ.maj7 || chord.q == ChordQ.maj ? 11 : 10),
        '3' => third,
        'b' => root - 2,
        'L' => root - 12 < 24 ? root : root - 12,
        _ => root,
      };
      out.add(MelNote(beat, len * stepBeats * 0.9, p, accent: c == 'O' || c == 'R' && i == 0));
      if (c == 'g') out.last.accent = false;
    }
  }
  return out;
}

// -----------------------------------------------------------------------------
// Drums and patterns

/// Adds a drum pattern: per bar string over a grid (`x` hit, `X` accent,
/// `g` ghost, `.` rest). Several bars cycle through [bars] strings.
void addPattern(
  List<NoteEvent> out,
  Inst inst,
  List<String> patterns, {
  required double start,
  required int bars,
  int beatsPerBar = 4,
  int stem = 0,
  double vel = 0.7,
  double pitch = 0,
  int fx = 0,
  double dur = 0.1,
}) {
  for (var bar = 0; bar < bars; bar++) {
    final pat = patterns[bar % patterns.length];
    final stepBeats = beatsPerBar / pat.length;
    for (var i = 0; i < pat.length; i++) {
      final c = pat[i];
      if (c == '.' || c == '-') continue;
      final v = switch (c) {
        'X' => math.min(1.0, vel * 1.3),
        'g' => vel * 0.38,
        _ => vel,
      };
      out.add(NoteEvent(start + bar * beatsPerBar + i * stepBeats, dur, pitch, v, inst, stem: stem, fx: c == 'g' ? fx | Art.ghost : fx));
    }
  }
}

/// Places [notes] as events.
void addNotes(
  List<NoteEvent> out,
  Inst inst,
  Iterable<MelNote> notes, {
  int stem = 0,
  double vel = 0.7,
  double accentVel = 0.15,
  int fx = 0,
  double transpose = 0,
  double legato = 1.0,
}) {
  for (final n in notes) {
    out.add(
      NoteEvent(n.beat, n.dur * legato, n.pitch + transpose, math.min(1.0, vel + (n.accent ? accentVel : 0)), inst, stem: stem, fx: fx),
    );
  }
}

/// Chord voicings on the rhythm of [pattern] (per bar; `x`/`X` hits).
void addChordHits(
  List<NoteEvent> out,
  Inst inst,
  ChordChart chart,
  int keyMidi,
  List<String> patterns, {
  required double start,
  required int bars,
  int beatsPerBar = 4,
  int stem = 0,
  double vel = 0.6,
  int floor = 55,
  int size = 4,
  bool rootless = false,
  double strumBeats = 0,
  double lengthScale = 0.9,
  int fx = 0,
  int topFx = 0,
}) {
  for (var bar = 0; bar < bars; bar++) {
    final pat = patterns[bar % patterns.length];
    final steps = pat.length;
    final stepBeats = beatsPerBar / steps;
    for (var i = 0; i < steps; i++) {
      final c = pat[i];
      if (c != 'x' && c != 'X' && c != 'g') continue;
      var len = 1;
      while (i + len < steps && pat[i + len] == '-') {
        len++;
      }
      final beat = start + bar * beatsPerBar + i * stepBeats;
      // A hit held across the next change (an anticipation) takes the
      // next chord.
      final nextSlot = chart.nextAfter(beat);
      final gap = nextSlot == null ? 99.0 : nextSlot.beat - beat;
      final chord = gap <= 0.5 + 1e-6 && gap < len * stepBeats - 1e-6 ? nextSlot!.chord : chart.at(beat);
      final voicing = chord.closeVoicing(keyMidi, floor, size: size, rootless: rootless);
      final v = c == 'X' ? math.min(1.0, vel * 1.25) : (c == 'g' ? vel * 0.45 : vel);
      for (var k = 0; k < voicing.length; k++) {
        out.add(
          NoteEvent(
            beat + k * strumBeats,
            len * stepBeats * lengthScale,
            voicing[k].toDouble(),
            v * (k == voicing.length - 1 ? 1.0 : 0.85),
            inst,
            stem: stem,
            fx: fx | (k == voicing.length - 1 ? topFx : 0),
          ),
        );
      }
    }
  }
}

/// Four-voice close harmony under a lead line (sax soli / brass section).
void addSoli(
  List<NoteEvent> out,
  Inst inst,
  ChordChart chart,
  int keyMidi,
  List<MelNote> lead, {
  int stem = 0,
  double vel = 0.6,
  int voices = 4,
  int fx = 0,
  Inst? leadInst,
}) {
  for (final n in lead) {
    final chord = chart.at(n.beat);
    out.add(NoteEvent(n.beat, n.dur, n.pitch.toDouble(), math.min(1.0, vel + (n.accent ? 0.12 : 0)), leadInst ?? inst, stem: stem, fx: fx));
    // Chord tones below the lead, within an octave.
    final below = chord.tonesIn(keyMidi, n.pitch - 12, n.pitch - 1, withExtensions: false).reversed.toList();
    for (var v = 0; v < voices - 1 && v < below.length; v++) {
      out.add(NoteEvent(n.beat, n.dur, below[v].toDouble(), vel * 0.8, inst, stem: stem, fx: fx));
    }
  }
}

/// Arpeggio over chord tones on a grid ([steps] per bar).
void addArp(
  List<NoteEvent> out,
  Inst inst,
  ChordChart chart,
  int keyMidi, {
  required double start,
  required int bars,
  int beatsPerBar = 4,
  int steps = 16,
  int floor = 57,
  int span = 2,
  String shape = 'up',
  int stem = 0,
  double vel = 0.55,
  double gate = 0.8,
  String? mask,
}) {
  final stepBeats = beatsPerBar / steps;
  for (var bar = 0; bar < bars; bar++) {
    for (var i = 0; i < steps; i++) {
      if (mask != null && mask[i % mask.length] == '.') continue;
      final beat = start + bar * beatsPerBar + i * stepBeats;
      final chord = chart.at(beat);
      final tones = <int>[];
      final base = chord.closeVoicing(keyMidi, floor, size: 3);
      for (var o = 0; o < span; o++) {
        tones.addAll(base.map((t) => t + 12 * o));
      }
      final n = tones.length;
      final k = switch (shape) {
        'down' => n - 1 - (i % n),
        'updown' => () {
          final period = 2 * n - 2;
          final m = i % period;
          return m < n ? m : period - m;
        }(),
        'pulse' => (i % 4 == 0) ? 0 : (i % 2 == 0 ? n - 1 : 1 + (i ~/ 2) % (n - 1)),
        _ => i % n,
      };
      final accent = i % 4 == 0;
      out.add(NoteEvent(beat, stepBeats * gate, tones[k].toDouble(), accent ? vel * 1.15 : vel, inst, stem: stem));
    }
  }
}

/// Sustained chord pad per chord slot in [start, start + beats).
void addPad(
  List<NoteEvent> out,
  Inst inst,
  ChordChart chart,
  int keyMidi, {
  required double start,
  required double beats,
  int floor = 52,
  int size = 4,
  int stem = 0,
  double vel = 0.45,
  int fx = 0,
}) {
  for (final s in chart.slots) {
    if (s.beat < start - 1e-6 || s.beat >= start + beats - 1e-6) continue;
    final v = s.chord.closeVoicing(keyMidi, floor, size: size);
    for (final p in v) {
      out.add(NoteEvent(s.beat, s.beats * 0.98, p.toDouble(), vel, inst, stem: stem, fx: fx));
    }
  }
}
