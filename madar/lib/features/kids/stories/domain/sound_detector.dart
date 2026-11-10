/// Decides whether the child made a sound, from the microphone's loudness
/// (0..1). There is no speech recognition in this part: any sound that stays
/// clearly above the room's own noise for a moment counts, and nothing is said
/// about what the sound was.
class SoundDetector {
  SoundDetector({
    this.threshold = 0.15,
    this.sustain = const Duration(milliseconds: 150),
    this.settle = const Duration(milliseconds: 500),
    this.noiseFactor = 2.5,
  });

  /// Quietest loudness that can count.
  final double threshold;

  /// How long the loudness must stay up (a click is not a voice).
  final Duration sustain;

  /// Listening starts deaf for this long (the tap that opened the beat, the
  /// phone being moved).
  final Duration settle;

  /// How much louder than the room's noise a sound must be.
  final double noiseFactor;

  Duration? _start;
  Duration? _loudSince;
  double _floor = 0;
  bool _fired = false;

  /// The room's own noise level, learnt while it is quiet.
  double get noiseFloor => _floor;

  /// Feed a loudness reading taken at [at] (any steady clock). True exactly
  /// once, when a sound is noticed; false until [reset] afterwards.
  bool update(double level, Duration at) {
    if (_fired) return false;
    _start ??= at;
    final bar = _bar;
    final loud = level >= bar;
    if (!loud) {
      // Learn the noise of the room from the quiet readings only.
      _floor = _floor == 0 ? level : _floor * 0.9 + level * 0.1;
      _loudSince = null;
      return false;
    }
    if (at - _start! < settle) return false;
    _loudSince ??= at;
    if (at - _loudSince! >= sustain) {
      _fired = true;
      return true;
    }
    return false;
  }

  double get _bar {
    final byNoise = _floor * noiseFactor;
    return byNoise > threshold ? byNoise : threshold;
  }

  /// Listen afresh (a new beat).
  void reset() {
    _start = null;
    _loudSince = null;
    _fired = false;
  }
}
