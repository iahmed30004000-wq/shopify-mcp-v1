import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/lock/domain/pin_hash.dart';
import 'package:madar/features/lock/domain/sha256.dart';

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _a(String s) => utf8.encode(s);

void main() {
  group('SHA-256 (FIPS 180-2 examples)', () {
    test('empty, abc, two-block message', () {
      expect(_hex(Sha256.hash([])), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(_hex(Sha256.hash(_a('abc'))), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(
        _hex(Sha256.hash(_a('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('one million "a"', () {
      expect(
        _hex(Sha256.hash(Uint8List(1000000)..fillRange(0, 1000000, 0x61))),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
      );
    });

    test('padding boundaries (55, 56, 63, 64 bytes) match a reference', () {
      // Lengths around the one-block padding limit; each digest differs.
      final seen = <String>{};
      for (final n in [55, 56, 63, 64, 65]) {
        seen.add(_hex(Sha256.hash(List.filled(n, 0x61))));
      }
      expect(seen, hasLength(5));
      expect(
        _hex(Sha256.hash(List.filled(64, 0x61))),
        'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
      );
    });
  });

  group('HMAC-SHA256 (RFC 4231)', () {
    test('test case 1', () {
      expect(
        _hex(HmacSha256(List.filled(20, 0x0b)).convert(_a('Hi There'))),
        'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
      );
    });

    test('test case 2 (short key)', () {
      expect(
        _hex(HmacSha256(_a('Jefe')).convert(_a('what do ya want for nothing?'))),
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      );
    });

    test('test case 6 (key longer than a block)', () {
      expect(
        _hex(HmacSha256(List.filled(131, 0xaa)).convert(_a('Test Using Larger Than Block-Size Key - Hash Key First'))),
        '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54',
      );
    });

    test('the word-level fast path equals the general path', () {
      final mac = HmacSha256(_a('key'));
      final msg = Uint8List.fromList(List.generate(32, (i) => i * 7));
      final words = Uint32List(8);
      for (var i = 0; i < 8; i++) {
        words[i] = (msg[i * 4] << 24) | (msg[i * 4 + 1] << 16) | (msg[i * 4 + 2] << 8) | msg[i * 4 + 3];
      }
      mac.convertWords(words, words);
      final bytes = <int>[
        for (final w in words) ...[w >> 24, (w >> 16) & 255, (w >> 8) & 255, w & 255],
      ];
      expect(_hex(bytes), _hex(mac.convert(msg)));
    });
  });

  group('PBKDF2-HMAC-SHA256', () {
    // RFC 6070's inputs with SHA-256 (the widely published set).
    test('password / salt, c = 1, 2, 4096', () {
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('password'), salt: _a('salt'), iterations: 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('password'), salt: _a('salt'), iterations: 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('password'), salt: _a('salt'), iterations: 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('long password and salt, 40-byte output (two blocks)', () {
      expect(
        _hex(
          Pbkdf2Sha256.derive(
            password: _a('passwordPASSWORDpassword'),
            salt: _a('saltSALTsaltSALTsaltSALTsaltSALTsalt'),
            iterations: 4096,
            length: 40,
          ),
        ),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9',
      );
    });

    test('embedded NUL bytes, 16-byte output', () {
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('pass\u0000word'), salt: _a('sa\u0000lt'), iterations: 4096, length: 16)),
        '89b69d0516f829893c696226650a8687',
      );
    });

    // RFC 7914 §11 (the PBKDF2-HMAC-SHA256 vectors of the scrypt RFC).
    test('RFC 7914: passwd / salt, c = 1, 64 bytes', () {
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('passwd'), salt: _a('salt'), iterations: 1, length: 64)),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('RFC 7914: Password / NaCl, c = 80000, 64 bytes', () {
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('Password'), salt: _a('NaCl'), iterations: 80000, length: 64)),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });

    test('Madar\'s own parameters (120 000 iterations) match a reference', () {
      expect(
        _hex(Pbkdf2Sha256.derive(password: _a('1234'), salt: List.generate(16, (i) => i), iterations: 120000)),
        '5070321ca34dbdafe9b25371d1c0f83bcafe073fbae1f2274f00a6d6c68e9899',
      );
    });

    test('rejects nonsense parameters', () {
      expect(() => Pbkdf2Sha256.derive(password: [1], salt: [1], iterations: 0), throwsArgumentError);
      expect(() => Pbkdf2Sha256.derive(password: [1], salt: [1], iterations: 1, length: 0), throwsArgumentError);
    });
  });

  group('PinRules', () {
    test('4–8 Western digits', () {
      expect(PinRules.isValid('123'), isFalse);
      expect(PinRules.isValid('1234'), isTrue);
      expect(PinRules.isValid('12345678'), isTrue);
      expect(PinRules.isValid('123456789'), isFalse);
      expect(PinRules.isValid('12a4'), isFalse);
      expect(PinRules.isValid('١٢٣٤'), isFalse, reason: 'the keypad converts Arabic-Indic digits first');
    });

    test('weak PINs: repeats and straight runs', () {
      expect(PinRules.isWeak('0000'), isTrue);
      expect(PinRules.isWeak('1234'), isTrue);
      expect(PinRules.isWeak('8765'), isTrue);
      expect(PinRules.isWeak('7890'), isTrue);
      expect(PinRules.isWeak('2580'), isFalse);
      expect(PinRules.isWeak('1397'), isFalse);
    });
  });

  group('PinHasher', () {
    final hasher = PinHasher(iterations: 1000, runner: PinHasher.inlineRunner);

    test('hash → verify; wrong and different-length PINs fail', () async {
      final h = await hasher.hash('2580');
      expect(h.length, 4);
      expect(h.iterations, 1000);
      expect(h.salt, hasLength(PinHasher.saltLength));
      expect(await hasher.verify('2580', h), isTrue);
      expect(await hasher.verify('2581', h), isFalse);
      expect(await hasher.verify('25800', h), isFalse);
      expect(await hasher.verify('12', h), isFalse);
    });

    test('salted: the same PIN hashes differently every time; never stored in clear', () async {
      final a = await hasher.hash('2580');
      final b = await hasher.hash('2580');
      expect(a.hash, isNot(equals(b.hash)));
      final json = jsonEncode(a.toJson());
      expect(json, isNot(contains('2580')));
    });

    test('the hash is PBKDF2-HMAC-SHA256(pin, salt, iterations)', () async {
      final h = await hasher.hash('90210');
      expect(_hex(h.hash), _hex(Pbkdf2Sha256.derive(password: _a('90210'), salt: h.salt, iterations: h.iterations)));
    });

    test('JSON round trip and malformed input', () async {
      final h = await hasher.hash('13579');
      expect(PinHash.fromJson(jsonDecode(jsonEncode(h.toJson()))), h);
      expect(PinHash.fromJson(null), isNull);
      expect(PinHash.fromJson({'alg': 'md5'}), isNull);
      expect(PinHash.fromJson({...h.toJson(), 'len': 3}), isNull);
      expect(PinHash.fromJson({...h.toJson(), 'hash': 'AAAA'}), isNull);
    });

    test('default cost is at least 100 000 iterations', () {
      expect(PinHasher.defaultIterations, greaterThanOrEqualTo(100000));
      expect(
        PinHasher().needsRehash(PinHash(salt: Uint8List(16), hash: Uint8List(32), iterations: 1000, length: 4)),
        isTrue,
      );
    });

    test('rejects invalid PINs', () {
      expect(() => hasher.hash('12'), throwsArgumentError);
    });

    test('constant-time comparison', () {
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PinHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PinHasher.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });

    test('the isolate runner gives the same result', () async {
      final h = await PinHasher.isolateRunner(password: _a('2580'), salt: _a('saltsalt'), iterations: 500);
      expect(_hex(h), _hex(Pbkdf2Sha256.derive(password: _a('2580'), salt: _a('saltsalt'), iterations: 500)));
    });
  });
}
