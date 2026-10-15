import 'dart:typed_data';

/// SHA-256 (FIPS 180-4), HMAC-SHA256 (RFC 2104) and PBKDF2-HMAC-SHA256
/// (RFC 8018) in pure Dart.
///
/// Madar hashes the app-lock PIN on the device and has no crypto package
/// among its direct dependencies, so the three primitives live here, tested
/// against the published vectors (FIPS 180-2 examples, RFC 4231, RFC 7914 §11
/// and the widely used RFC 6070-style SHA-256 set).
///
/// PBKDF2 keeps the HMAC key's inner and outer states after the first block
/// (the standard optimisation), so each iteration costs exactly two
/// compression-function calls and allocates nothing.
abstract final class Sha256 {
  static const int blockSize = 64;
  static const int digestSize = 32;

  static const int _mask = 0xffffffff;

  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const List<int> _initial = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19, //
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

  /// The SHA-256 digest of [data].
  static Uint8List hash(List<int> data) {
    final state = Uint32List.fromList(_initial);
    final w = Uint32List(64);
    _absorb(state, w, data, prefixBytes: 0);
    return _wordsToBytes(state);
  }

  /// Absorbs [data] (with SHA-256 padding) into [state], which has already
  /// consumed [prefixBytes] bytes (a whole number of blocks).
  static void _absorb(Uint32List state, Uint32List w, List<int> data, {required int prefixBytes}) {
    final total = prefixBytes + data.length;
    // Message + 0x80 + zero padding + 64-bit big-endian bit length.
    final padded = ((data.length + 9 + blockSize - 1) ~/ blockSize) * blockSize;
    final buffer = Uint8List(padded)..setRange(0, data.length, data);
    buffer[data.length] = 0x80;
    final bits = total * 8;
    for (var i = 0; i < 8; i++) {
      buffer[padded - 1 - i] = (bits >> (8 * i)) & 0xff;
    }
    for (var off = 0; off < padded; off += blockSize) {
      for (var i = 0; i < 16; i++) {
        final j = off + i * 4;
        w[i] = (buffer[j] << 24) | (buffer[j + 1] << 16) | (buffer[j + 2] << 8) | buffer[j + 3];
      }
      compress(state, w);
    }
  }

  /// One application of the compression function: mixes the block held in
  /// `w[0..15]` into [state] (w is a 64-word scratch schedule).
  static void compress(Uint32List state, Uint32List w) {
    for (var t = 16; t < 64; t++) {
      final w15 = w[t - 15], w2 = w[t - 2];
      final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >> 3);
      final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >> 10);
      w[t] = w[t - 16] + s0 + w[t - 7] + s1;
    }
    var a = state[0], b = state[1], c = state[2], d = state[3];
    var e = state[4], f = state[5], g = state[6], h = state[7];
    for (var t = 0; t < 64; t++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final t1 = (h + s1 + ch + _k[t] + w[t]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
  }

  static Uint8List _wordsToBytes(Uint32List words) {
    final out = Uint8List(words.length * 4);
    for (var i = 0; i < words.length; i++) {
      final v = words[i];
      out[i * 4] = v >> 24;
      out[i * 4 + 1] = (v >> 16) & 0xff;
      out[i * 4 + 2] = (v >> 8) & 0xff;
      out[i * 4 + 3] = v & 0xff;
    }
    return out;
  }
}

/// HMAC-SHA256 with the key's inner / outer states precomputed.
class HmacSha256 {
  HmacSha256(List<int> key) {
    final block = Uint8List(Sha256.blockSize);
    final k = key.length > Sha256.blockSize ? Sha256.hash(key) : key;
    block.setRange(0, k.length, k);
    _inner = _keyedState(block, 0x36);
    _outer = _keyedState(block, 0x5c);
  }

  late final Uint32List _inner;
  late final Uint32List _outer;
  final Uint32List _w = Uint32List(64);

  Uint32List _keyedState(Uint8List block, int pad) {
    final state = Uint32List.fromList(Sha256._initial);
    for (var i = 0; i < 16; i++) {
      final j = i * 4;
      _w[i] =
          ((block[j] ^ pad) << 24) | ((block[j + 1] ^ pad) << 16) | ((block[j + 2] ^ pad) << 8) | (block[j + 3] ^ pad);
    }
    Sha256.compress(state, _w);
    return state;
  }

  /// HMAC(key, [message]).
  Uint8List convert(List<int> message) {
    final inner = Uint32List.fromList(_inner);
    Sha256._absorb(inner, _w, message, prefixBytes: Sha256.blockSize);
    final outer = Uint32List.fromList(_outer);
    Sha256._absorb(outer, _w, Sha256._wordsToBytes(inner), prefixBytes: Sha256.blockSize);
    return Sha256._wordsToBytes(outer);
  }

  /// HMAC of a 32-byte message given as 8 big-endian words ([input]),
  /// written to [output] (may alias [input]). Two compressions, no
  /// allocation – the PBKDF2 inner loop.
  void convertWords(Uint32List input, Uint32List output) {
    final w = _w;
    // Inner: key^ipad block (already absorbed) + 32-byte message block.
    for (var i = 0; i < 8; i++) {
      w[i] = input[i];
    }
    _padWords(w);
    final s = _scratch..setAll(0, _inner);
    Sha256.compress(s, w);
    for (var i = 0; i < 8; i++) {
      w[i] = s[i];
    }
    _padWords(w);
    s.setAll(0, _outer);
    Sha256.compress(s, w);
    output.setAll(0, s);
  }

  final Uint32List _scratch = Uint32List(8);

  /// SHA-256 padding for a 32-byte message that follows one 64-byte block
  /// (768 bits in total).
  static void _padWords(Uint32List w) {
    w[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = (Sha256.blockSize + Sha256.digestSize) * 8;
  }
}

/// PBKDF2 with HMAC-SHA256 as the PRF (RFC 8018 §5.2).
abstract final class Pbkdf2Sha256 {
  /// Derives [length] bytes from [password] and [salt] with [iterations].
  static Uint8List derive({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    int length = Sha256.digestSize,
  }) {
    if (iterations < 1) throw ArgumentError.value(iterations, 'iterations', 'must be ≥ 1');
    if (length < 1) throw ArgumentError.value(length, 'length', 'must be ≥ 1');
    final prf = HmacSha256(password);
    final blocks = (length + Sha256.digestSize - 1) ~/ Sha256.digestSize;
    final out = Uint8List(blocks * Sha256.digestSize);
    final u = Uint32List(8);
    final t = Uint32List(8);
    final first = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
    for (var block = 1; block <= blocks; block++) {
      first
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;
      final u1 = prf.convert(first);
      for (var i = 0; i < 8; i++) {
        final j = i * 4;
        u[i] = (u1[j] << 24) | (u1[j + 1] << 16) | (u1[j + 2] << 8) | u1[j + 3];
        t[i] = u[i];
      }
      for (var n = 1; n < iterations; n++) {
        prf.convertWords(u, u);
        for (var i = 0; i < 8; i++) {
          t[i] ^= u[i];
        }
      }
      out.setAll((block - 1) * Sha256.digestSize, Sha256._wordsToBytes(t));
    }
    return length == out.length ? out : Uint8List.sublistView(out, 0, length);
  }
}
