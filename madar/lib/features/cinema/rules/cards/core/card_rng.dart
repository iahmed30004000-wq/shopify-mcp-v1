/// A small, fast, deterministic and serialisable random generator.
///
/// xoshiro128** seeded through splitmix32. Every operation is 32-bit and
/// avoids products above 2^53, so a seed gives the same sequence on the VM
/// and on the web. The whole state is four integers, stored in JSON so a
/// saved match resumes with exactly the same future deals.
library;

import 'dart:math' as math;

const int _mask32 = 0xFFFFFFFF;

int _imul(int a, int b) {
  final aHi = (a >>> 16) & 0xFFFF;
  final aLo = a & 0xFFFF;
  return ((aLo * b) + (((aHi * b) & 0xFFFF) << 16)) & _mask32;
}

int _rotl(int x, int k) => ((x << k) | (x >>> (32 - k))) & _mask32;

/// Deterministic generator used for dealing and by the AIs.
class CardRng implements math.Random {
  /// Seeds the generator from any integer (negative and 64-bit seeds too).
  factory CardRng(int seed) {
    var x = (seed & _mask32) ^ _imul((seed ~/ 0x100000000) & _mask32, 0x9E3779B1);
    int next() {
      x = (x + 0x9E3779B9) & _mask32;
      var z = x;
      z = _imul(z ^ (z >>> 16), 0x85EBCA6B);
      z = _imul(z ^ (z >>> 13), 0xC2B2AE35);
      return (z ^ (z >>> 16)) & _mask32;
    }

    final s = [next(), next(), next(), next()];
    if (s.every((v) => v == 0)) s[0] = 1;
    return CardRng._(s[0], s[1], s[2], s[3]);
  }

  CardRng._(this._s0, this._s1, this._s2, this._s3);

  factory CardRng.fromJson(Object? json) {
    final l = (json! as List).cast<int>();
    return CardRng._(l[0], l[1], l[2], l[3]);
  }

  int _s0, _s1, _s2, _s3;

  /// Next unsigned 32-bit value.
  int nextUint32() {
    final result = _imul(_rotl(_imul(_s1, 5), 7), 9);
    final t = (_s1 << 9) & _mask32;
    _s2 ^= _s0;
    _s3 ^= _s1;
    _s1 ^= _s2;
    _s0 ^= _s3;
    _s2 ^= t;
    _s3 = _rotl(_s3, 11);
    return result;
  }

  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) throw RangeError.range(max, 1, 0x100000000, 'max');
    final limit = (0x100000000 ~/ max) * max;
    while (true) {
      final r = nextUint32();
      if (r < limit) return r % max;
    }
  }

  @override
  double nextDouble() => nextUint32() / 4294967296.0;

  @override
  bool nextBool() => (nextUint32() & 0x80000000) != 0;

  /// Fisher–Yates shuffle in place.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  /// An independent generator derived from this one (advances this one).
  CardRng fork() => CardRng._(nextUint32(), nextUint32(), nextUint32(), nextUint32() | 1);

  CardRng copy() => CardRng._(_s0, _s1, _s2, _s3);

  List<int> toJson() => [_s0, _s1, _s2, _s3];
}

/// Shuffles with any [math.Random] (the AIs receive a plain `Random`).
void shuffleWith<T>(List<T> list, math.Random rng) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
}
