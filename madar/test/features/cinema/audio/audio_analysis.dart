// Offline audio analysis for the cinema audio tests: levels, spectra and
// loop-seam continuity. (We cannot listen in CI, so we measure.)
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:madar/core/sound/synth/filters.dart';
import 'package:madar/core/sound/synth/wav.dart';

/// Decoded WAV (mono or stereo).
class Pcm {
  Pcm(this.sampleRate, this.channels);

  factory Pcm.decode(Uint8List wav) {
    final info = Wav.parse(wav);
    return Pcm(info.sampleRate, [for (var c = 0; c < info.channels; c++) Wav.decodeChannel(wav, c)]);
  }

  final int sampleRate;
  final List<Float64List> channels;

  int get frames => channels.first.length;
  double get seconds => frames / sampleRate;

  /// Mono mixdown.
  Float64List get mono {
    if (channels.length == 1) return channels.first;
    final out = Float64List(frames);
    for (var i = 0; i < frames; i++) {
      out[i] = 0.5 * (channels[0][i] + channels[1][i]);
    }
    return out;
  }
}

double toDb(double x) => x <= 0 ? -200 : 20 * math.log(x) / math.ln10;

double peakDb(Float64List x) {
  var p = 0.0;
  for (final v in x) {
    if (v.abs() > p) p = v.abs();
  }
  return toDb(p);
}

/// RMS in dBFS, optionally speaker-weighted (high-passed at 150 Hz).
double rmsDb(Float64List x, int sr, {bool weighted = true}) {
  final y = Float64List.fromList(x);
  if (weighted) Biquad(BiquadType.highPass, frequency: 150, sampleRate: sr).processBuffer(y);
  var e = 0.0;
  for (final v in y) {
    e += v * v;
  }
  return y.isEmpty ? -200 : 10 * math.log(e / y.length + 1e-30) / math.ln10;
}

double mean(Float64List x) => x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;

/// Loop-seam click score: the 2nd difference across the wrap point divided
/// by the 99.9th percentile of 2nd differences inside the loop. ≤ 1 means
/// the seam is as smooth as the music itself.
double seamScore(Float64List x) {
  final n = x.length;
  if (n < 8) return 0;
  final d2 = Float64List(n - 2);
  for (var i = 1; i < n - 1; i++) {
    d2[i - 1] = (x[i + 1] - 2 * x[i] + x[i - 1]).abs();
  }
  final sorted = Float64List.fromList(d2)..sort();
  final p999 = sorted[(sorted.length * 0.999).floor().clamp(0, sorted.length - 1)];
  final seamA = (x[0] - 2 * x[n - 1] + x[n - 2]).abs();
  final seamB = (x[1] - 2 * x[0] + x[n - 1]).abs();
  return math.max(seamA, seamB) / (p999 + 1e-9);
}

/// Short-window (5 ms) high-frequency energy at the seam relative to the
/// median window: catches clicks a 2nd difference could miss.
double seamHfRatio(Float64List x, int sr) {
  final n = x.length;
  final rot = Float64List(n);
  for (var i = 0; i < n; i++) {
    rot[i] = x[(i + n ~/ 2) % n];
  }
  Biquad(BiquadType.highPass, frequency: math.min(4000, sr * 0.3), sampleRate: sr).processBuffer(rot);
  final w = (0.005 * sr).round();
  final energies = <double>[];
  for (var s = 0; s + w <= n; s += w) {
    var e = 0.0;
    for (var i = s; i < s + w; i++) {
      e += rot[i] * rot[i];
    }
    energies.add(e);
  }
  final seamWin = (n - n ~/ 2) ~/ w;
  final sorted = [...energies]..sort();
  final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
  return energies[seamWin.clamp(0, energies.length - 1)] / (p90 + 1e-12);
}

/// Welch-averaged magnitude spectrum → centroid and band shares.
class Spectrum {
  Spectrum(this.sr, this.power);

  factory Spectrum.of(Float64List x, int sr, {int size = 2048}) {
    final power = Float64List(size ~/ 2);
    final win = Float64List(size);
    for (var i = 0; i < size; i++) {
      win[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
    }
    final re = Float64List(size), im = Float64List(size);
    var frames = 0;
    for (var s = 0; s + size <= x.length; s += size ~/ 2) {
      for (var i = 0; i < size; i++) {
        re[i] = x[s + i] * win[i];
        im[i] = 0;
      }
      fftInPlace(re, im);
      for (var k = 0; k < size ~/ 2; k++) {
        power[k] += re[k] * re[k] + im[k] * im[k];
      }
      frames++;
    }
    if (frames > 0) {
      for (var k = 0; k < power.length; k++) {
        power[k] /= frames;
      }
    }
    return Spectrum(sr, power);
  }

  final int sr;
  final Float64List power;

  double hz(int k) => k * sr / (2.0 * power.length);

  double get centroid {
    var num = 0.0, den = 0.0;
    for (var k = 1; k < power.length; k++) {
      num += hz(k) * power[k];
      den += power[k];
    }
    return den == 0 ? 0 : num / den;
  }

  /// Share of power in [lo, hi) Hz.
  double band(double lo, double hi) {
    var inBand = 0.0, all = 0.0;
    for (var k = 1; k < power.length; k++) {
      final f = hz(k);
      all += power[k];
      if (f >= lo && f < hi) inBand += power[k];
    }
    return all == 0 ? 0 : inBand / all;
  }

  /// Frequency below which [share] of the power lies (roll-off).
  double rolloff([double share = 0.85]) {
    var all = 0.0;
    for (var k = 1; k < power.length; k++) {
      all += power[k];
    }
    var acc = 0.0;
    for (var k = 1; k < power.length; k++) {
      acc += power[k];
      if (acc >= share * all) return hz(k);
    }
    return hz(power.length - 1);
  }
}

/// In-place radix-2 FFT.
void fftInPlace(Float64List re, Float64List im) {
  {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang), wi = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var cr = 1.0, ci = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final ar = re[i + k], ai = im[i + k];
          final br = re[i + k + len ~/ 2] * cr - im[i + k + len ~/ 2] * ci;
          final bi = re[i + k + len ~/ 2] * ci + im[i + k + len ~/ 2] * cr;
          re[i + k] = ar + br;
          im[i + k] = ai + bi;
          re[i + k + len ~/ 2] = ar - br;
          im[i + k + len ~/ 2] = ai - bi;
          final nr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = nr;
        }
      }
    }
  }
}

/// Where previews go: `MADAR_AUDIO_PREVIEW_DIR`, else the system temp dir.
Directory previewDir() {
  final env = Platform.environment['MADAR_AUDIO_PREVIEW_DIR'];
  final d = Directory(env ?? '${Directory.systemTemp.path}/madar_cinema_audio');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// Click detector for a loop's wrap point: the second difference across
/// the seam relative to the largest one in the ±[windowMs] neighbourhood
/// (excluding the seam). Musical onsets at the downbeat raise the
/// neighbourhood too; a discontinuity stands out (score ≫ 1).
double seamClickScore(Float64List x, int sr, {double windowMs = 8}) {
  final n = x.length;
  double at(int i) => x[(i % n + n) % n];
  double d2(int i) => (at(i + 1) - 2 * at(i) + at(i - 1)).abs();
  final seam = [d2(n - 1), d2(0)].reduce((a, b) => a > b ? a : b);
  final w = (windowMs * sr / 1000).round();
  var neighbour = 1e-9;
  for (var k = 2; k <= w; k++) {
    final a = d2(n - 1 - k), b = d2(k);
    if (a > neighbour) neighbour = a;
    if (b > neighbour) neighbour = b;
  }
  return seam / neighbour;
}

/// [x] high-passed at 150 Hz (what a phone speaker can reproduce).
Float64List speakerWeighted(Float64List x, int sr) {
  final y = Float64List.fromList(x);
  Biquad(BiquadType.highPass, frequency: 150, sampleRate: sr).processBuffer(y);
  Biquad(BiquadType.highPass, frequency: 150, sampleRate: sr).processBuffer(y);
  return y;
}
