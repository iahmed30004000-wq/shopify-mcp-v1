/// Deterministic, platform-independent pseudo-random numbers for synthesis.
///
/// `dart:math`'s `Random(seed)` is deterministic too, but its algorithm is an
/// implementation detail of the VM. Sound kits must render bit-identically on
/// every device and in every test run, so the synthesiser uses its own
/// xorshift32 generator (Marsaglia 2003) – tiny, fast and fully specified.
final class SynthRandom {
  SynthRandom(int seed) : _state = _scramble(seed);

  int _state;

  static int _scramble(int seed) {
    // SplitMix-style avalanche so nearby seeds give unrelated streams.
    var z = (seed * 0x9E3779B1 + 0x7F4A7C15) & 0xFFFFFFFF;
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF;
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
    z = (z ^ (z >> 16)) & 0xFFFFFFFF;
    return z == 0 ? 0x6D2B79F5 : z;
  }

  /// Next raw 32-bit value.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x;
    return x;
  }

  /// Uniform in `[0, 1)`.
  double nextDouble() => nextUint32() * (1.0 / 4294967296.0);

  /// Uniform in `[-1, 1)` – white noise.
  double bipolar() => nextDouble() * 2.0 - 1.0;

  /// Uniform in `[min, max)`.
  double range(double min, double max) => min + (max - min) * nextDouble();

  /// Uniform integer in `[0, max)`.
  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);

  /// A new generator whose stream is independent of this one.
  SynthRandom fork() => SynthRandom(nextUint32());
}
