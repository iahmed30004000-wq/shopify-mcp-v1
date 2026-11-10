import 'dart:math' as math;
import 'dart:typed_data';

/// Attack / decay / sustain / release envelope with smooth (raised-cosine
/// attack, exponential decay/release) segments. Times are in seconds.
///
/// The envelope is rendered into a buffer once and multiplied into a voice,
/// which is cheaper than evaluating segment logic per sample per voice.
final class Adsr {
  const Adsr({
    this.attack = 0.005,
    this.decay = 0.1,
    this.sustain = 0.7,
    this.release = 0.2,
  })  : assert(attack >= 0 && decay >= 0 && release >= 0, 'negative time'),
        assert(sustain >= 0 && sustain <= 1, 'sustain must be 0..1');

  final double attack;
  final double decay;
  final double sustain;
  final double release;

  /// Renders the envelope for a note held for [holdSeconds] (note-on to
  /// note-off) followed by its release. The last sample is exactly 0.
  Float64List render(int sampleRate, double holdSeconds) {
    final hold = (holdSeconds * sampleRate).round();
    final rel = math.max(1, (release * sampleRate).round());
    final out = Float64List(hold + rel);
    final a = (attack * sampleRate).round();
    final d = math.max(1, (decay * sampleRate).round());
    // exp decay reaching ~1 % of the distance to sustain after `decay`.
    final kd = math.exp(math.log(0.01) / d);
    var level = 0.0;
    for (var i = 0; i < hold; i++) {
      if (i < a) {
        level = 0.5 - 0.5 * math.cos(math.pi * (i + 1) / a);
      } else {
        level = sustain + (level - sustain) * kd;
      }
      out[i] = level;
    }
    // Release: exponential shape blended into a raised-cosine so it lands on
    // exactly zero (no click at note end).
    final start = hold == 0 ? 0.0 : level;
    for (var i = 0; i < rel; i++) {
      final t = (i + 1) / rel;
      final expPart = math.exp(-5.0 * t);
      final cosPart = 0.5 + 0.5 * math.cos(math.pi * t);
      out[hold + i] = start * expPart * cosPart;
    }
    return out;
  }
}

/// Per-sample multiplier giving a −60 dB decay after [t60] seconds.
double decayFactor(double t60, int sampleRate) =>
    t60 <= 0 ? 0.0 : math.pow(10.0, -3.0 / (t60 * sampleRate)).toDouble();

/// In-place raised-cosine fades on a mono buffer.
abstract final class Fades {
  static void fadeIn(Float64List x, int n, [int start = 0]) {
    final m = math.min(n, x.length - start);
    for (var i = 0; i < m; i++) {
      x[start + i] *= 0.5 - 0.5 * math.cos(math.pi * i / m);
    }
  }

  static void fadeOut(Float64List x, int n) {
    final m = math.min(n, x.length);
    final s = x.length - m;
    for (var i = 0; i < m; i++) {
      x[s + i] *= 0.5 + 0.5 * math.cos(math.pi * (i + 1) / m);
    }
  }
}
