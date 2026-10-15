import 'dart:math' as math;
import 'dart:typed_data';

/// Room description for [Reverb].
final class ReverbSpec {
  const ReverbSpec({
    this.roomSize = 0.45,
    this.damping = 0.4,
    this.preDelayMs = 8,
    this.width = 1.0,
  });

  /// 0..1 → comb feedback 0.70..0.98 (Freeverb mapping).
  final double roomSize;

  /// 0..1 high-frequency absorption inside the combs.
  final double damping;
  final double preDelayMs;

  /// 0 = mono tail, 1 = fully decorrelated stereo tail.
  final double width;
}

/// A lightweight Freeverb-style reverb.
///
/// Classic Freeverb runs 8 parallel damped combs + 4 series all-passes *per
/// channel*. This version runs one mono bank of 6 combs and diffuses it into
/// two decorrelated all-pass chains (left / right with Freeverb's stereo
/// spread) – about 60 % cheaper with an indistinguishable tail for short UI
/// sounds, and still lush enough for the ambient bed.
final class Reverb {
  Reverb(this.sampleRate, [this.spec = const ReverbSpec()]) {
    final s = sampleRate / 44100.0;
    _combs = [for (final l in _combTunings) _Comb((l * s).round())];
    _apL = [for (final l in _allpassTunings) _Allpass((l * s).round())];
    _apR = [for (final l in _allpassTunings) _Allpass(((l + _stereoSpread) * s).round())];
    final feedback = 0.70 + 0.28 * spec.roomSize.clamp(0.0, 1.0);
    final damp = spec.damping.clamp(0.0, 1.0) * 0.4;
    for (final c in _combs) {
      c.feedback = feedback;
      c.damp1 = damp;
      c.damp2 = 1 - damp;
    }
  }

  static const _combTunings = [1116, 1188, 1277, 1356, 1491, 1617];
  static const _allpassTunings = [556, 441, 341];
  static const _stereoSpread = 23;

  /// Input gain so the 6-comb sum sits near unity (Freeverb uses 0.015 for 8
  /// combs with a ×3 wet scale).
  static const double _inputGain = 0.06;

  final int sampleRate;
  final ReverbSpec spec;
  late final List<_Comb> _combs;
  late final List<_Allpass> _apL;
  late final List<_Allpass> _apR;

  /// Reverberates the mono [send] and *adds* the wet signal (scaled by
  /// [wet]) into [outL]/[outR]. Processes `frames` samples (default: all).
  ///
  /// Block-processed: each comb / all-pass runs as its own tight loop over
  /// the whole buffer, which keeps state in registers and is ~2× faster than
  /// the per-sample object graph of textbook Freeverb.
  void process(Float64List send, Float64List outL, Float64List outR, {double wet = 1.0, int? frames}) {
    final n = math.min(frames ?? send.length, send.length);
    if (n <= 0) return;
    final acc = Float64List(n);
    for (final c in _combs) {
      c.processBlock(send, acc, n, _inputGain);
    }
    final l = Float64List.fromList(acc);
    final r = acc;
    for (final a in _apL) {
      a.processBlock(l, n);
    }
    for (final a in _apR) {
      a.processBlock(r, n);
    }
    final pre = (spec.preDelayMs * sampleRate / 1000).round();
    final width = spec.width.clamp(0.0, 1.0);
    final wet1 = wet * (width / 2 + 0.5);
    final wet2 = wet * ((1 - width) / 2);
    final m = math.min(n, outL.length - pre);
    for (var i = 0; i < m; i++) {
      final lv = l[i], rv = r[i];
      outL[i + pre] += lv * wet1 + rv * wet2;
      outR[i + pre] += rv * wet1 + lv * wet2;
    }
  }

  /// Rough −60 dB decay time of the tail in seconds (for sizing buffers).
  double get tailSeconds {
    final fb = 0.70 + 0.28 * spec.roomSize.clamp(0.0, 1.0);
    final meanDelay = _combTunings.reduce((a, b) => a + b) / _combTunings.length / 44100.0;
    return -3.0 * meanDelay / (math.log(fb) / math.ln10);
  }
}

final class _Comb {
  _Comb(int length) : _buf = Float64List(math.max(1, length));

  final Float64List _buf;
  int _i = 0;
  double feedback = 0.84;
  double damp1 = 0.2;
  double damp2 = 0.8;
  double _store = 0;

  /// `acc[i] += comb(x[i] * gain)` for i < n.
  void processBlock(Float64List x, Float64List acc, int n, double gain) {
    final buf = _buf;
    final len = buf.length;
    final fb = feedback, d1 = damp1, d2 = damp2;
    var idx = _i;
    var store = _store;
    for (var i = 0; i < n; i++) {
      final out = buf[idx];
      store = out * d2 + store * d1;
      buf[idx] = x[i] * gain + store * fb;
      if (++idx >= len) idx = 0;
      acc[i] += out;
    }
    _i = idx;
    _store = store;
  }
}

final class _Allpass {
  _Allpass(int length) : _buf = Float64List(math.max(1, length));

  final Float64List _buf;
  int _i = 0;

  /// In-place Schroeder all-pass (feedback 0.5).
  void processBlock(Float64List x, int n) {
    final buf = _buf;
    final len = buf.length;
    var idx = _i;
    for (var i = 0; i < n; i++) {
      final b = buf[idx];
      final v = x[i];
      buf[idx] = v + b * 0.5;
      if (++idx >= len) idx = 0;
      x[i] = b - v;
    }
    _i = idx;
  }
}
