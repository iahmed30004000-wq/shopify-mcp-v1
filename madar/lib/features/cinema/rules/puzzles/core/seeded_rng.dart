/// Deterministic, seedable, serialisable random numbers shared by the Madar
/// Cinema puzzles and arcade simulations.
///
/// xoshiro128** (Blackman & Vigna) seeded through SplitMix32. Only 32-bit
/// integer operations are used, so a seed yields the same sequence on the
/// Dart VM, AOT and the web.
library;

const int _mask32 = 0xFFFFFFFF;

/// 32-bit multiplication that stays exact where integers are doubles.
int _mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >> 16) & 0xFFFF;
  return ((aLo * b) + (((aHi * b) & 0xFFFF) << 16)) & _mask32;
}

int _rotl(int x, int k) => ((x << k) | (x >> (32 - k))) & _mask32;

/// A small PRNG whose entire state is four 32-bit words ([state]).
///
/// Puzzle states store [state] so undo and `toJson`/`fromJson` round trips
/// replay future random events (tile spawns, refills…) identically.
final class SeededRng {
  /// Seeds the generator; any integer (including negative) is accepted.
  factory SeededRng(int seed) {
    var x = (seed ^ (seed >> 32)) & _mask32;
    int next() {
      x = (x + 0x9E3779B9) & _mask32;
      var z = x;
      z = _mul32(z ^ (z >> 16), 0x85EBCA6B);
      z = _mul32(z ^ (z >> 13), 0xC2B2AE35);
      return (z ^ (z >> 16)) & _mask32;
    }

    var s0 = next(), s1 = next(), s2 = next(), s3 = next();
    if ((s0 | s1 | s2 | s3) == 0) s0 = 1;
    return SeededRng._(s0, s1, s2, s3);
  }

  SeededRng._(this._s0, this._s1, this._s2, this._s3);

  /// Restores a generator from [state] (four 32-bit words).
  factory SeededRng.fromState(List<int> state) {
    if (state.length != 4) {
      throw ArgumentError.value(state, 'state', 'expected four 32-bit words');
    }
    final s = [for (final w in state) w & _mask32];
    if ((s[0] | s[1] | s[2] | s[3]) == 0) s[0] = 1;
    return SeededRng._(s[0], s[1], s[2], s[3]);
  }

  int _s0, _s1, _s2, _s3;

  /// The four state words (an unmodifiable copy).
  List<int> get state => List<int>.unmodifiable([_s0, _s1, _s2, _s3]);

  /// An independent copy continuing the same sequence.
  SeededRng copy() => SeededRng._(_s0, _s1, _s2, _s3);

  /// Derives an independent generator (advances this one).
  SeededRng fork() => SeededRng(nextUint32() ^ (nextUint32() << 16));

  /// Next uniformly distributed unsigned 32-bit integer.
  int nextUint32() {
    final result = _mul32(_rotl(_mul32(_s1, 5), 7), 9);
    final t = (_s1 << 9) & _mask32;
    _s2 ^= _s0;
    _s3 ^= _s1;
    _s1 ^= _s2;
    _s0 ^= _s3;
    _s2 ^= t;
    _s3 = _rotl(_s3, 11);
    return result;
  }

  /// Uniform integer in `[0, max)` without modulo bias (`1 <= max <= 2^32`).
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000, 'max');
    }
    if (max == 1) return 0;
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final r = nextUint32();
      if (r < limit) return r % max;
    }
  }

  /// Uniform integer in `[min, max]` (inclusive).
  int nextRange(int min, int max) => min + nextInt(max - min + 1);

  /// Uniform double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform double in `[min, max)`.
  double nextDoubleRange(double min, double max) => min + (max - min) * nextDouble();

  /// A fair coin.
  bool nextBool() => (nextUint32() & 1) == 1;

  /// True with probability [p].
  bool chance(double p) => nextDouble() < p;

  /// Fisher–Yates shuffle in place.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// A uniformly random element of the non-empty [list].
  T pick<T>(List<T> list) => list[nextInt(list.length)];

  Map<String, Object?> toJson() => {'s': state};

  factory SeededRng.fromJson(Map<String, Object?> json) =>
      SeededRng.fromState([for (final w in json['s']! as List) (w as num).toInt()]);
}
