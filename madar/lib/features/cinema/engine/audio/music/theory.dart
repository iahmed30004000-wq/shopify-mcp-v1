import 'dart:math' as math;

/// Chord qualities used by the style grammars (intervals above the root).
enum ChordQ {
  maj([0, 4, 7]),
  maj6([0, 4, 7, 9]),
  maj7([0, 4, 7, 11]),
  maj9([0, 4, 7, 11, 14]),
  dom7([0, 4, 7, 10]),
  dom9([0, 4, 7, 10, 14]),
  dom7b9([0, 4, 7, 10, 13]),
  dom7s5([0, 4, 8, 10]),
  min([0, 3, 7]),
  min6([0, 3, 7, 9]),
  min7([0, 3, 7, 10]),
  min9([0, 3, 7, 10, 14]),
  minMaj7([0, 3, 7, 11]),
  m7b5([0, 3, 6, 10]),
  dim7([0, 3, 6, 9]),
  aug([0, 4, 8]),
  sus4([0, 5, 7, 10]),
  power([0, 7]);

  const ChordQ(this.intervals);

  /// Semitones above the root, ascending (may exceed an octave for 9ths).
  final List<int> intervals;

  bool get isMinor => switch (this) {
    min || min6 || min7 || min9 || minMaj7 || m7b5 || dim7 => true,
    _ => false,
  };

  bool get isDominant => this == dom7 || this == dom9 || this == dom7b9 || this == dom7s5 || this == sus4;

  /// The scale a melody uses over this chord (semitones in one octave).
  List<int> get scale => switch (this) {
    maj || maj6 || maj9 || power => const [0, 2, 4, 5, 7, 9, 11],
    maj7 => const [0, 2, 4, 6, 7, 9, 11], // lydian colour
    dom7 || dom9 || sus4 => const [0, 2, 4, 5, 7, 9, 10],
    dom7b9 || dom7s5 => const [0, 1, 3, 4, 7, 8, 10], // altered-ish
    min || min7 || min9 || min6 => const [0, 2, 3, 5, 7, 9, 10], // dorian
    minMaj7 => const [0, 2, 3, 5, 7, 9, 11],
    m7b5 => const [0, 1, 3, 5, 6, 8, 10],
    dim7 => const [0, 2, 3, 5, 6, 8, 9, 11],
    aug => const [0, 2, 4, 6, 8, 10],
  };

  /// Chord tones without the extensions above the 7th, folded into one octave.
  List<int> get coreTones => [for (final i in intervals) i % 12];
}

/// A chord: [root] is a pitch class relative to the key's tonic (0..11).
final class Chord {
  const Chord(this.root, this.q);

  final int root;
  final ChordQ q;

  bool get isMinor => q.isMinor;

  /// True when pitch class [pc] (relative to the key) is a chord tone.
  bool contains(int pc) {
    final rel = ((pc - root) % 12 + 12) % 12;
    for (final i in q.intervals) {
      if (i % 12 == rel) return true;
    }
    return false;
  }

  /// True when [pc] belongs to this chord's melodic scale.
  bool inScale(int pc) {
    final rel = ((pc - root) % 12 + 12) % 12;
    return q.scale.contains(rel);
  }

  /// Absolute MIDI pitches of the chord tones inside [lo, hi].
  List<int> tonesIn(int keyMidi, int lo, int hi, {bool withExtensions = true}) {
    final out = <int>[];
    for (var m = lo; m <= hi; m++) {
      final pc = ((m - keyMidi) % 12 + 12) % 12;
      final rel = ((pc - root) % 12 + 12) % 12;
      for (final i in q.intervals) {
        if (!withExtensions && i > 11) continue;
        if (i % 12 == rel) {
          out.add(m);
          break;
        }
      }
    }
    return out;
  }

  /// Absolute MIDI pitches of the scale inside [lo, hi].
  List<int> scaleIn(int keyMidi, int lo, int hi) {
    final s = q.scale;
    final out = <int>[];
    for (var m = lo; m <= hi; m++) {
      final pc = ((m - keyMidi) % 12 + 12) % 12;
      final rel = ((pc - root) % 12 + 12) % 12;
      if (s.contains(rel)) out.add(m);
    }
    return out;
  }

  /// Root as the nearest MIDI note to [near] (key tonic [keyMidi]).
  int rootNear(int keyMidi, int near) {
    final pc = (keyMidi + root) % 12;
    var m = near - ((near - pc) % 12 + 12) % 12;
    if (near - m > 6) m += 12;
    return m;
  }

  /// A close-position voicing with its lowest note at or above [floor].
  List<int> closeVoicing(int keyMidi, int floor, {int size = 4, bool rootless = false, int inversion = 0}) {
    var ivs = [for (final i in q.intervals) i];
    if (rootless && ivs.length >= 4) ivs = ivs.sublist(1);
    if (ivs.length > size) ivs = ivs.sublist(ivs.length - size);
    final base = rootNear(keyMidi, floor + 6);
    var notes = [for (final i in ivs) base + (i > 11 ? i - 12 : i)]..sort();
    for (var k = 0; k < inversion % notes.length; k++) {
      notes = [...notes.sublist(1), notes.first + 12];
    }
    while (notes.first < floor) {
      notes = [for (final n in notes) n + 12];
    }
    while (notes.first >= floor + 12) {
      notes = [for (final n in notes) n - 12];
    }
    notes.sort();
    return notes;
  }

  @override
  bool operator ==(Object other) => other is Chord && other.root == root && other.q == q;

  @override
  int get hashCode => Object.hash(root, q);

  @override
  String toString() => '${_names[root % 12]}${q.name}';

  static const _names = ['I', 'bII', 'II', 'bIII', 'III', 'IV', '#IV', 'V', 'bVI', 'VI', 'bVII', 'VII'];
}

/// A chord held from [beat] for [beats].
final class ChordSlot {
  const ChordSlot(this.beat, this.beats, this.chord);

  final double beat;
  final double beats;
  final Chord chord;

  double get end => beat + beats;
}

/// Chord lookup over a cue's timeline (sorted slots).
final class ChordChart {
  ChordChart(List<ChordSlot> slots) : slots = List.unmodifiable(slots);

  final List<ChordSlot> slots;

  /// The chord sounding at [beat] (clamped to the ends).
  Chord at(double beat) {
    if (slots.isEmpty) return const Chord(0, ChordQ.maj);
    var lo = 0, hi = slots.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (slots[mid].beat <= beat + 1e-9) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return slots[lo].chord;
  }

  /// The slot sounding at [beat].
  ChordSlot slotAt(double beat) {
    var best = slots.first;
    for (final s in slots) {
      if (s.beat <= beat + 1e-9) best = s;
    }
    return best;
  }

  /// Next slot starting strictly after [beat], or null.
  ChordSlot? nextAfter(double beat) {
    for (final s in slots) {
      if (s.beat > beat + 1e-9) return s;
    }
    return null;
  }
}

/// Parses a compact progression: `'I | VI7 | ii7 V7 | I'` – bars separated
/// by `|`, chords inside a bar share it equally. Symbols: roman numeral
/// (upper = major family, lower = minor family), optional `b`/`#` prefix,
/// suffix one of `7 9 6 M7 M9 b9 +7 o7 ø7 m6 mM7 sus 5 +`.
List<ChordSlot> parseProgression(String text, {int beatsPerBar = 4, double startBeat = 0}) {
  final out = <ChordSlot>[];
  final bars = text.split('|');
  var beat = startBeat;
  for (final bar in bars) {
    final syms = bar.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (syms.isEmpty) {
      beat += beatsPerBar;
      continue;
    }
    // "%" repeats the previous chord for the whole bar.
    final each = beatsPerBar / syms.length;
    for (final s in syms) {
      final c = s == '%' ? (out.isEmpty ? const Chord(0, ChordQ.maj) : out.last.chord) : parseChord(s);
      out.add(ChordSlot(beat, each, c));
      beat += each;
    }
  }
  return out;
}

const _romans = {'i': 0, 'ii': 2, 'iii': 4, 'iv': 5, 'v': 7, 'vi': 9, 'vii': 11};

/// Parses one roman-numeral chord symbol (see [parseProgression]).
Chord parseChord(String s) {
  var i = 0;
  var shift = 0;
  while (i < s.length && (s[i] == 'b' || s[i] == '#')) {
    shift += s[i] == 'b' ? -1 : 1;
    i++;
  }
  final m = RegExp('^(VII|VI|V|IV|III|II|I|vii|vi|v|iv|iii|ii|i)').firstMatch(s.substring(i));
  if (m == null) throw FormatException('Bad chord symbol', s);
  final numeral = m.group(0)!;
  final upper = numeral == numeral.toUpperCase();
  final root = ((_romans[numeral.toLowerCase()]! + shift) % 12 + 12) % 12;
  final suffix = s.substring(i + numeral.length);
  final q = switch (suffix) {
    '' => upper ? ChordQ.maj : ChordQ.min,
    '7' => upper ? ChordQ.dom7 : ChordQ.min7,
    '9' => upper ? ChordQ.dom9 : ChordQ.min9,
    '6' => upper ? ChordQ.maj6 : ChordQ.min6,
    'M7' => upper ? ChordQ.maj7 : ChordQ.minMaj7,
    'M9' => ChordQ.maj9,
    'b9' => ChordQ.dom7b9,
    '+7' => ChordQ.dom7s5,
    '+' => ChordQ.aug,
    'o7' => ChordQ.dim7,
    'ø7' || 'h7' => ChordQ.m7b5,
    'm6' => ChordQ.min6,
    'mM7' => ChordQ.minMaj7,
    'sus' => ChordQ.sus4,
    '5' => ChordQ.power,
    _ => throw FormatException('Bad chord suffix', s),
  };
  return Chord(root, q);
}

/// MIDI note → Hz (A4 = 440).
double midiToHz(double midi) => 440.0 * math.pow(2.0, (midi - 69) / 12.0);

/// Semitones → playback-speed ratio.
double semitoneRatio(double semis) => math.pow(2.0, semis / 12.0).toDouble();
