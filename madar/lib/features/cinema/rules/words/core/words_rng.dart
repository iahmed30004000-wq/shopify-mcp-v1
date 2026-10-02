/// Deterministic, seedable, serialisable random numbers for the Madar Cinema
/// word games (daily words, grids, crosswords, quiz decks, ghosts).
///
/// xoshiro128** (Blackman & Vigna) seeded through SplitMix32. Only 32-bit
/// integer operations are used, so a seed yields the same sequence on the
/// Dart VM, AOT and the web.
library;

const int _mask32 = 0xFFFFFFFF;

int _mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >> 16) & 0xFFFF;
  return ((aLo * b) + (((aHi * b) & 0xFFFF) << 16)) & _mask32;
}

int _rotl(int x, int k) => ((x << k) | (x >> (32 - k))) & _mask32;

/// A small PRNG whose whole state is four 32-bit words ([state]).
final class WordsRng {
  /// Seeds the generator; any integer (including negative) is accepted.
  factory WordsRng(int seed) {
    var x = (seed ^ (seed >> 32)) & _mask32;
    int next() {
      x = (x + 0x9E3779B9) & _mask32;
      var z = x;
      z = _mul32(z ^ (z >> 16), 0x85EBCA6B);
      z = _mul32(z ^ (z >> 13), 0xC2B2AE35);
      return (z ^ (z >> 16)) & _mask32;
    }

    var s0 = next();
    final s1 = next(), s2 = next(), s3 = next();
    if ((s0 | s1 | s2 | s3) == 0) s0 = 1;
    return WordsRng._(s0, s1, s2, s3);
  }

  /// Seeds from text (FNV-1a over the UTF-16 code units).
  factory WordsRng.fromString(String seed) => WordsRng(hashString(seed));

  /// Restores a generator from [state] (four 32-bit words).
  factory WordsRng.fromState(List<int> state) {
    if (state.length != 4) {
      throw ArgumentError.value(state, 'state', 'expected four 32-bit words');
    }
    final s = [for (final w in state) w & _mask32];
    if ((s[0] | s[1] | s[2] | s[3]) == 0) s[0] = 1;
    return WordsRng._(s[0], s[1], s[2], s[3]);
  }

  WordsRng._(this._s0, this._s1, this._s2, this._s3);

  int _s0, _s1, _s2, _s3;

  /// The four state words (an unmodifiable copy).
  List<int> get state => List<int>.unmodifiable([_s0, _s1, _s2, _s3]);

  /// An independent copy continuing the same sequence.
  WordsRng copy() => WordsRng._(_s0, _s1, _s2, _s3);

  /// 32-bit FNV-1a hash of [s] – stable across platforms.
  static int hashString(String s) {
    var h = 0x811C9DC5;
    for (final cu in s.codeUnits) {
      h ^= cu & 0xFF;
      h = _mul32(h, 0x01000193);
      h ^= cu >> 8;
      h = _mul32(h, 0x01000193);
    }
    return h;
  }

  /// Combines integers into one 32-bit seed.
  static int mix(List<int> parts) {
    var h = 0x2545F491;
    for (final p in parts) {
      h ^= p & _mask32;
      h = _mul32(h ^ (h >> 15), 0x2C1B3C6D);
      h = _mul32(h ^ (h >> 12), 0x297A2D39);
      h ^= h >> 15;
    }
    return h & _mask32;
  }

  /// Next unsigned 32-bit value.
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

  /// Uniform integer in `[0, max)` (unbiased).
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) throw RangeError.range(max, 1, 0x100000000, 'max');
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final v = nextUint32();
      if (v < limit) return v % max;
    }
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Fair coin.
  bool nextBool() => (nextUint32() & 1) == 1;

  /// A random element of [items] (non-empty).
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Fisher–Yates shuffle of [items] in place; returns it.
  List<T> shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = items[i];
      items[i] = items[j];
      items[j] = t;
    }
    return items;
  }

  /// Index drawn with probability proportional to [weights] (all >= 0, sum > 0).
  int weightedIndex(List<double> weights) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var x = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      x -= weights[i];
      if (x < 0) return i;
    }
    return weights.length - 1;
  }
}
