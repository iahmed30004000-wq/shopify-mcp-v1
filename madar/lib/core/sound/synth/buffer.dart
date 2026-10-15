import 'dart:math' as math;
import 'dart:typed_data';

/// Decibels (full scale) → linear gain.
double dbToGain(double db) => math.pow(10.0, db / 20.0).toDouble();

/// Linear gain → decibels (full scale). Returns `-inf` for silence.
double gainToDb(double gain) => gain <= 0 ? double.negativeInfinity : 20.0 * math.log(gain) / math.ln10;

/// Frequency ratio for an interval in cents.
double centsToRatio(double cents) => math.pow(2.0, cents / 1200.0).toDouble();

/// Peak absolute sample value of [x].
double peakOf(Float64List x, [int start = 0, int? end]) {
  var p = 0.0;
  final e = end ?? x.length;
  for (var i = start; i < e; i++) {
    final a = x[i].abs();
    if (a > p) p = a;
  }
  return p;
}

/// A stereo float buffer – the working format of the synthesiser.
final class StereoBuffer {
  StereoBuffer(this.sampleRate, int frames)
      : left = Float64List(frames),
        right = Float64List(frames);

  StereoBuffer.fromChannels(this.sampleRate, this.left, this.right)
      : assert(left.length == right.length, 'channel lengths differ');

  final int sampleRate;
  final Float64List left;
  final Float64List right;

  int get frames => left.length;
  double get seconds => frames / sampleRate;

  /// Mixes a mono signal in with an equal-power pan law. [pan] is −1 (left)
  /// … 1 (right); when [panTo] is given the pan glides linearly across the
  /// length of [src].
  void addMono(Float64List src, {int offset = 0, double gain = 1.0, double pan = 0.0, double? panTo}) {
    final n = math.min(src.length, frames - offset);
    if (n <= 0 || gain == 0) return;
    if (panTo == null || panTo == pan) {
      final a = (pan.clamp(-1.0, 1.0) + 1.0) * math.pi / 4.0;
      final gl = math.cos(a) * gain * math.sqrt2;
      final gr = math.sin(a) * gain * math.sqrt2;
      for (var i = 0; i < n; i++) {
        final s = src[i];
        left[offset + i] += s * gl;
        right[offset + i] += s * gr;
      }
      return;
    }
    // Gliding pan: update the law every 64 samples (inaudible stepping).
    const block = 64;
    for (var b = 0; b < n; b += block) {
      final t = n <= 1 ? 0.0 : b / (n - 1);
      final p = (pan + (panTo - pan) * t).clamp(-1.0, 1.0);
      final a = (p + 1.0) * math.pi / 4.0;
      final gl = math.cos(a) * gain * math.sqrt2;
      final gr = math.sin(a) * gain * math.sqrt2;
      final e = math.min(b + block, n);
      for (var i = b; i < e; i++) {
        final s = src[i];
        left[offset + i] += s * gl;
        right[offset + i] += s * gr;
      }
    }
  }

  double peak() => math.max(peakOf(left), peakOf(right));

  void scale(double g) {
    for (var i = 0; i < frames; i++) {
      left[i] *= g;
      right[i] *= g;
    }
  }

  /// Raised-cosine fade-in over the first [n] frames.
  void fadeIn(int n) {
    final m = math.min(n, frames);
    for (var i = 0; i < m; i++) {
      final g = 0.5 - 0.5 * math.cos(math.pi * i / m);
      left[i] *= g;
      right[i] *= g;
    }
  }

  /// Raised-cosine fade-out over the last [n] frames; the final frame is 0.
  void fadeOut(int n) {
    final m = math.min(n, frames);
    final start = frames - m;
    for (var i = 0; i < m; i++) {
      final g = 0.5 + 0.5 * math.cos(math.pi * (i + 1) / m);
      left[start + i] *= g;
      right[start + i] *= g;
    }
  }

  /// Index one past the last frame whose level exceeds [threshold].
  int audibleEnd(double threshold) {
    for (var i = frames - 1; i >= 0; i--) {
      if (left[i].abs() > threshold || right[i].abs() > threshold) return i + 1;
    }
    return 0;
  }

  /// A copy truncated to [n] frames.
  StereoBuffer truncated(int n) {
    final m = math.min(n, frames);
    return StereoBuffer.fromChannels(
      sampleRate,
      Float64List.fromList(Float64List.sublistView(left, 0, m)),
      Float64List.fromList(Float64List.sublistView(right, 0, m)),
    );
  }
}
