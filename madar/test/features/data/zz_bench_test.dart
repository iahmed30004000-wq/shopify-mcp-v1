import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bench', () async {
    final out = StringBuffer();
    Future<void> time(String name, Future<void> Function() f) async {
      final sw = Stopwatch()..start();
      await f();
      out.writeln('$name: ${sw.elapsedMilliseconds} ms');
    }

    final pass = SecretKey('correct horse battery staple'.codeUnits);
    final salt = List<int>.generate(16, (i) => i);
    // warmup
    await DartArgon2id(parallelism: 1, memory: 1024, iterations: 1, hashLength: 32).deriveKey(secretKey: pass, nonce: salt);
    await time('argon2id m=19MiB t=2 p=1', () => DartArgon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32).deriveKey(secretKey: pass, nonce: salt));
    await time('argon2id m=19MiB t=2 p=1 maxIsolates=1', () => DartArgon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32, maxIsolates: 1).deriveKey(secretKey: pass, nonce: salt));
    await time('argon2id m=46MiB t=1 p=1', () => DartArgon2id(parallelism: 1, memory: 47104, iterations: 1, hashLength: 32).deriveKey(secretKey: pass, nonce: salt));
    await time('argon2id m=64MiB t=3 p=4', () => DartArgon2id(parallelism: 4, memory: 65536, iterations: 3, hashLength: 32).deriveKey(secretKey: pass, nonce: salt));
    await time('pbkdf2 sha256 310k', () => DartPbkdf2(macAlgorithm: Hmac.sha256(), iterations: 310000, bits: 256).deriveKey(secretKey: pass, nonce: salt));
    final key = SecretKey(List<int>.generate(32, (i) => i));
    final data = Uint8List(10 * 1024 * 1024);
    for (var i = 0; i < data.length; i++) {
      data[i] = (i * 31) & 0xff;
    }
    late SecretBox box;
    await time('aes-gcm encrypt 10MB', () async => box = await AesGcm.with256bits().encrypt(data, secretKey: key));
    await time('aes-gcm decrypt 10MB', () async => await AesGcm.with256bits().decrypt(box, secretKey: key));
    await time('gzip 10MB', () async => gzip.encode(data));
    File('/tmp/claude-0/-home-user-shopify-mcp-v1/9de7c4e9-a8bd-58b2-8976-585818a6d9d3/scratchpad/d1_bench.txt').writeAsStringSync(out.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
