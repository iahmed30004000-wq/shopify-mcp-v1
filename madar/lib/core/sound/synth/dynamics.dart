import 'dart:math' as math;
import 'dart:typed_data';

import 'buffer.dart';
import 'filters.dart';

/// Loudness helpers for level-matching sounds across profiles.
abstract final class Loudness {
  /// Loudest short-term RMS (dBFS) over [windowMs] windows of the stereo
  /// signal – a cheap stand-in for "momentary loudness" that treats a soft
  /// bell and a transient-heavy drum fairly.
  ///
  /// With [speakerWeighted] (default) the signal is first high-passed at
  /// 150 Hz (12 dB/oct), approximating what a phone speaker can reproduce,
  /// so deep sounds are levelled by their *audible* part rather than by
  /// sub-bass energy nobody hears on a phone.
  static double momentaryDb(StereoBuffer b, {double windowMs = 30, bool speakerWeighted = true}) {
    final w = math.max(1, (windowMs * b.sampleRate / 1000).round());
    final hop = math.max(1, w ~/ 3);
    var l = b.left, r = b.right;
    final n = b.frames;
    if (n == 0) return double.negativeInfinity;
    if (speakerWeighted) {
      l = Float64List.fromList(l);
      r = Float64List.fromList(r);
      Biquad(BiquadType.highPass, frequency: 150, sampleRate: b.sampleRate).processBuffer(l);
      Biquad(BiquadType.highPass, frequency: 150, sampleRate: b.sampleRate).processBuffer(r);
    }
    // Prefix sums of energy make every window O(1).
    final prefix = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + 0.5 * (l[i] * l[i] + r[i] * r[i]);
    }
    var best = 0.0;
    final win = math.min(w, n);
    for (var s = 0; s + win <= n; s += hop) {
      final e = (prefix[s + win] - prefix[s]) / win;
      if (e > best) best = e;
    }
    return best <= 0 ? double.negativeInfinity : 10.0 * math.log(best) / math.ln10;
  }
}

/// Offline, stereo-linked look-ahead peak limiter with a soft knee.
///
/// Guarantees `|sample| ≤ ceiling` (−1 dBFS by default) without the harsh
/// distortion of clipping:
///
/// 1. a soft-knee gain computer asks for just enough reduction per sample;
/// 2. a sliding-window minimum over the look-ahead window followed by a box
///    average of the same length yields a smooth gain curve that is provably
///    ≤ the required gain at every sample (each averaged value comes from a
///    window containing that sample);
/// 3. a one-pole release lets the gain recover gently;
/// 4. a final safety clamp catches floating-point residue.
final class SoftLimiter {
  const SoftLimiter({this.ceilingDb = -1.0, this.kneeDb = 3.0, this.lookaheadMs = 1.5, this.releaseMs = 60});

  final double ceilingDb;
  final double kneeDb;
  final double lookaheadMs;
  final double releaseMs;

  /// Ceiling as a linear gain, with a hair of margin for 16-bit rounding and
  /// dither.
  double get ceiling => dbToGain(ceilingDb) * 0.998;

  void process(StereoBuffer b) {
    final n = b.frames;
    if (n == 0) return;
    final l = b.left, r = b.right;
    final c = ceiling;
    final t = c * dbToGain(-kneeDb);
    final span = c - t;

    // 1. Required gain per sample.
    final req = Float64List(n);
    var any = false;
    for (var i = 0; i < n; i++) {
      final p = math.max(l[i].abs(), r[i].abs());
      if (p <= t) {
        req[i] = 1.0;
      } else {
        // Soft knee: output approaches the ceiling asymptotically.
        final over = (p - t) / span;
        final target = t + span * _tanh(over);
        req[i] = target / p;
        any = true;
      }
    }
    if (!any) return;

    // 2. Sliding minimum over the look-ahead window (monotonic deque, O(n)).
    final w = math.max(1, (lookaheadMs * b.sampleRate / 1000).round());
    final minHold = Float64List(n);
    final dq = Int32List(n);
    var head = 0, tail = 0;
    // minHold[i] = min(req[i .. i+w-1]); iterate backwards.
    for (var i = n - 1; i >= 0; i--) {
      while (tail > head && req[dq[tail - 1]] >= req[i]) {
        tail--;
      }
      dq[tail++] = i;
      while (dq[head] > i + w - 1) {
        head++;
      }
      minHold[i] = req[dq[head]];
    }

    // 3. Box average of length w over minHold[i-w+1 .. i]. Indices before 0
    // take minHold[0] = min(req[0 .. w-1]), which keeps the guarantee for
    // the first w samples too.
    final smooth = Float64List(n);
    final first = minHold[0];
    var acc = w * first;
    for (var i = 0; i < n; i++) {
      acc += minHold[i] - (i - w >= 0 ? minHold[i - w] : first);
      smooth[i] = acc / w;
    }

    // 4. Release smoothing + apply.
    final rel = 1.0 - math.exp(-1.0 / (releaseMs * b.sampleRate / 1000));
    var g = 1.0;
    for (var i = 0; i < n; i++) {
      final s = smooth[i];
      g = s < g ? s : g + (s - g) * rel;
      var lv = l[i] * g;
      var rv = r[i] * g;
      if (lv > c) {
        lv = c;
      } else if (lv < -c) {
        lv = -c;
      }
      if (rv > c) {
        rv = c;
      } else if (rv < -c) {
        rv = -c;
      }
      l[i] = lv;
      r[i] = rv;
    }
  }

  static double _tanh(double x) {
    if (x > 10) return 1.0;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}
