import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/data/domain/backup_codec.dart';
import 'package:madar/features/data/domain/backup_format.dart';

/// Cheap key derivation so the suite stays fast; the production cost is
/// exercised once in 'recommended parameters'.
const fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const codec = MadarBackupCodec(kdf: fastKdf, useIsolate: false);
final createdAt = DateTime.utc(2026, 9, 30, 8, 30);

Uint8List jsonBytes(Object value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

Future<Uint8List> seal(Uint8List json, String pass, {MadarBackupCodec c = codec}) async {
  final (bytes, key) = await c.seal(json, pass, createdAt: createdAt, schemaVersion: 2);
  key.destroy();
  return bytes;
}

Matcher throwsProblem(BackupProblem p) =>
    throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));

/// Header length (from the prefix).
int headerLength(Uint8List b) => ByteData.sublistView(b).getUint32(10);

/// Offset of the first ciphertext byte.
int bodyStart(Uint8List b) => BackupLayout.prefixLength + headerLength(b) + BackupLayout.hashLength;

/// Rewrites the header JSON and fixes the checksum (what a careful attacker
/// or a buggy tool would do) – only the GCM tag can catch it then.
Uint8List rewriteHeader(Uint8List file, Map<String, Object?> Function(Map<String, Object?>) change) {
  final len = headerLength(file);
  final json = jsonDecode(utf8.decode(file.sublist(BackupLayout.prefixLength, BackupLayout.prefixLength + len))) as Map<String, Object?>;
  final newHeader = utf8.encode(jsonEncode(change(json)));
  final prefix = Uint8List(BackupLayout.prefixLength + newHeader.length)
    ..setRange(0, BackupLayout.prefixLength, file)
    ..setRange(BackupLayout.prefixLength, BackupLayout.prefixLength + newHeader.length, newHeader);
  ByteData.sublistView(prefix).setUint32(10, newHeader.length);
  final hash = const DartSha256().hashSync(prefix).bytes;
  return Uint8List.fromList([...prefix, ...hash, ...file.sublist(bodyStart(file))]);
}

void main() {
  final snapshot = {
    'format': 'madar.snapshot',
    'schemaVersion': 2,
    'tables': {
      'tasks': [
        {'id': 't1', 'title': 'مهمة – ☪ “quoted”', 'notes': 'line1\nline2'},
      ],
    },
  };

  group('round trip', () {
    test('seal → open returns the exact JSON and header', () async {
      final json = jsonBytes(snapshot);
      final file = await seal(json, 'correct horse battery staple');
      expect(BackupEnvelope.looksLikeBackup(file), isTrue);
      expect(file.sublist(0, 8), madarBackupMagic);
      expect(utf8.decode(file.sublist(0, 8)), 'MADARBAK');

      final opened = await codec.open(file, 'correct horse battery staple');
      expect(opened.json, json);
      expect(opened.header.createdAt, createdAt);
      expect(opened.header.schemaVersion, 2);
      expect(opened.header.kdf, fastKdf);
      expect(opened.header.compression, 'gzip');
      expect(opened.header.salt, hasLength(16));
      expect(opened.header.nonce, hasLength(12));
    });

    test('the header holds no personal data and the body is not readable', () async {
      final file = await seal(jsonBytes(snapshot), 'correct horse battery staple');
      final header = utf8.decode(file.sublist(BackupLayout.prefixLength, BackupLayout.prefixLength + headerLength(file)));
      final decoded = jsonDecode(header) as Map<String, Object?>;
      expect(decoded.keys, unorderedEquals(['format', 'createdAt', 'schemaVersion', 'content', 'compression', 'kdf', 'cipher', 'check', 'bodyLength']));
      expect(header, isNot(contains('مهمة')));
      final text = latin1.decode(file);
      expect(text, isNot(contains('madar.snapshot"')));
      expect(text, isNot(contains('t1')));
      expect(text, isNot(contains('quoted')));
    });

    test('Arabic and emoji passphrases work; each seal uses a fresh salt and nonce', () async {
      final json = jsonBytes(snapshot);
      const pass = 'مدار حياتي الجميلة 🌙';
      final a = await seal(json, pass);
      final b = await seal(json, pass);
      expect(a, isNot(b));
      expect(MadarBackupCodec.peek(a).salt, isNot(MadarBackupCodec.peek(b).salt));
      expect((await codec.open(a, pass)).json, json);
      expect((await codec.open(b, pass)).json, json);
    });

    test('sealWithKey (safety copy) opens with the same passphrase, fresh nonce', () async {
      final (first, key) = await codec.seal(jsonBytes(snapshot), 'the same passphrase', createdAt: createdAt, schemaVersion: 2);
      final second = await codec.sealWithKey(jsonBytes({'other': true}), key, createdAt: createdAt, schemaVersion: 2);
      key.destroy();
      expect(MadarBackupCodec.peek(second).salt, MadarBackupCodec.peek(first).salt);
      expect(MadarBackupCodec.peek(second).nonce, isNot(MadarBackupCodec.peek(first).nonce));
      expect(utf8.decode((await codec.open(second, 'the same passphrase')).json), '{"other":true}');
    });

    test('runs on a background isolate', () async {
      const isolated = MadarBackupCodec(kdf: fastKdf);
      final json = jsonBytes(snapshot);
      final (file, key) = await isolated.seal(json, 'isolate passphrase', createdAt: createdAt, schemaVersion: 2);
      key.destroy();
      expect((await isolated.open(file, 'isolate passphrase')).json, json);
      await expectLater(isolated.open(file, 'nope'), throwsProblem(BackupProblem.wrongPassphrase));
    });

    test('compresses the snapshot', () async {
      final big = jsonBytes({
        'rows': [for (var i = 0; i < 2000; i++) {'id': 'row-$i', 'title': 'repeated title text', 'n': i}],
      });
      final file = await seal(big, 'compression test phrase');
      expect(file.length, lessThan(big.length ~/ 4));
    });
  });

  group('wrong passphrase', () {
    test('is reported as such (not as damage)', () async {
      final file = await seal(jsonBytes(snapshot), 'correct horse battery staple');
      await expectLater(codec.open(file, 'correct horse battery stapler'), throwsProblem(BackupProblem.wrongPassphrase));
      await expectLater(codec.open(file, ''), throwsProblem(BackupProblem.wrongPassphrase));
      await expectLater(codec.open(file, 'Correct horse battery staple'), throwsProblem(BackupProblem.wrongPassphrase));
    });
  });

  group('tampering', () {
    late Uint8List file;
    setUp(() async => file = await seal(jsonBytes(snapshot), 'correct horse battery staple'));

    Future<void> expectDamaged(Uint8List bytes) =>
        expectLater(codec.open(bytes, 'correct horse battery staple'), throwsProblem(BackupProblem.corrupted));

    test('a flipped bit anywhere in the ciphertext fails the tag', () async {
      final start = bodyStart(file);
      for (final offset in [start, start + 1, (start + file.length - 16) ~/ 2, file.length - 17]) {
        final bad = Uint8List.fromList(file)..[offset] ^= 0x01;
        await expectDamaged(bad);
      }
    });

    test('a changed tag byte fails', () async {
      final bad = Uint8List.fromList(file)..[file.length - 1] ^= 0x80;
      await expectDamaged(bad);
    });

    test('a changed header byte fails the header checksum', () async {
      final bad = Uint8List.fromList(file)..[BackupLayout.prefixLength + 5] ^= 0x01;
      expect(() => MadarBackupCodec.peek(bad), throwsProblem(BackupProblem.corrupted));
      await expectDamaged(bad);
    });

    test('a changed checksum byte fails', () async {
      final at = BackupLayout.prefixLength + headerLength(file) + 3;
      final bad = Uint8List.fromList(file)..[at] ^= 0x10;
      await expectDamaged(bad);
    });

    test('a rewritten header with a fixed checksum still fails (header is authenticated)', () async {
      final bad = rewriteHeader(file, (h) => {...h, 'createdAt': '2020-01-01T00:00:00.000Z'});
      expect(MadarBackupCodec.peek(bad).createdAt, DateTime.utc(2020));
      await expectDamaged(bad);
    });

    test('trailing bytes are refused', () async {
      await expectDamaged(Uint8List.fromList([...file, 0]));
    });

    test('garbage is not a backup', () async {
      await expectLater(codec.open(Uint8List.fromList(utf8.encode('{"format":"madar.snapshot"}')), 'x'), throwsProblem(BackupProblem.notABackup));
      await expectLater(codec.open(Uint8List(0), 'x'), throwsProblem(BackupProblem.notABackup));
      await expectLater(codec.open(Uint8List.fromList(List.filled(100, 7)), 'x'), throwsProblem(BackupProblem.notABackup));
    });
  });

  group('truncation', () {
    test('any cut after the magic is reported as truncated', () async {
      final file = await seal(jsonBytes(snapshot), 'correct horse battery staple');
      final cuts = {8, 10, 13, 14, 20, BackupLayout.prefixLength + headerLength(file), bodyStart(file) - 1, bodyStart(file), file.length - 16, file.length - 1};
      for (final n in cuts) {
        await expectLater(
          codec.open(Uint8List.sublistView(file, 0, n), 'correct horse battery staple'),
          throwsProblem(BackupProblem.truncated),
          reason: 'cut at $n of ${file.length}',
        );
      }
    });

    test('a cut inside the magic is not a backup', () async {
      final file = await seal(jsonBytes(snapshot), 'correct horse battery staple');
      await expectLater(codec.open(Uint8List.sublistView(file, 0, 5), 'x'), throwsProblem(BackupProblem.notABackup));
    });
  });

  group('versions', () {
    late Uint8List file;
    setUp(() async => file = await seal(jsonBytes(snapshot), 'correct horse battery staple'));

    test('a newer container version is refused with a clear problem', () async {
      final newer = Uint8List.fromList(file);
      ByteData.sublistView(newer).setUint16(8, madarBackupVersion + 1);
      expect(() => MadarBackupCodec.peek(newer), throwsProblem(BackupProblem.newerVersion));
      await expectLater(codec.open(newer, 'correct horse battery staple'), throwsProblem(BackupProblem.newerVersion));
    });

    test('version 0 is damage', () async {
      final zero = Uint8List.fromList(file);
      ByteData.sublistView(zero).setUint16(8, 0);
      expect(() => MadarBackupCodec.peek(zero), throwsProblem(BackupProblem.corrupted));
    });

    test('an unknown key derivation, cipher or compression means a newer app', () {
      Map<String, Object?> kdf(Map<String, Object?> h) => (h['kdf']! as Map).cast<String, Object?>();
      expect(
        () => MadarBackupCodec.peek(rewriteHeader(file, (h) => {...h, 'kdf': {...kdf(h), 'alg': 'scrypt'}})),
        throwsProblem(BackupProblem.newerVersion),
      );
      expect(
        () => MadarBackupCodec.peek(rewriteHeader(file, (h) => {...h, 'cipher': {'alg': 'xchacha20', 'nonce': ''}})),
        throwsProblem(BackupProblem.newerVersion),
      );
      expect(
        () => MadarBackupCodec.peek(rewriteHeader(file, (h) => {...h, 'compression': 'zstd'})),
        throwsProblem(BackupProblem.newerVersion),
      );
    });

    test('absurd key-derivation costs are refused before any work', () {
      Map<String, Object?> kdf(Map<String, Object?> h) => (h['kdf']! as Map).cast<String, Object?>();
      for (final bad in [
        {'m': 64 * 1024 * 1024},
        {'t': 0},
        {'p': 0},
        {'p': 64},
        {'m': 4, 'p': 1},
        {'m': '64'},
      ]) {
        expect(
          () => MadarBackupCodec.peek(rewriteHeader(file, (h) => {...h, 'kdf': {...kdf(h), ...bad}})),
          throwsProblem(BackupProblem.corrupted),
          reason: '$bad',
        );
      }
    });

    test('a header that is not a Madar backup header', () {
      expect(
        () => MadarBackupCodec.peek(rewriteHeader(file, (h) => {...h, 'format': 'something.else'})),
        throwsProblem(BackupProblem.notABackup),
      );
    });

    test('the file layout is stable (version 1)', () {
      final view = ByteData.sublistView(file);
      expect(view.getUint16(8), 1);
      final header = MadarBackupCodec.peek(file);
      expect(file.length, bodyStart(file) + header.bodyLength + BackupLayout.tagLength);
    });
  });

  group('key derivation cost', () {
    test('recommended parameters are RFC 9106 Argon2id m=64 MiB, t=3, p=4', () {
      expect(BackupKdfParams.recommended, const BackupKdfParams(memoryKiB: 65536, iterations: 3, parallelism: 4));
      expect(const MadarBackupCodec().kdf, BackupKdfParams.recommended);
      expect(BackupKdfParams.recommended.isSane, isTrue);
    });

    test('recommended parameters: a real round trip, timed', () async {
      const real = MadarBackupCodec();
      final sw = Stopwatch()..start();
      final (file, key) = await real.seal(jsonBytes(snapshot), 'timing passphrase', createdAt: createdAt, schemaVersion: 2);
      final sealMs = sw.elapsedMilliseconds;
      key.destroy();
      sw.reset();
      final opened = await real.open(file, 'timing passphrase');
      final openMs = sw.elapsedMilliseconds;
      expect(opened.header.kdf, BackupKdfParams.recommended);
      // Host (4-core x86-64, Dart VM): ≈ 0.8 s each. A generous bound keeps
      // CI stable while still catching an accidental 10× cost.
      expect(sealMs, lessThan(15000));
      expect(openMs, lessThan(15000));
      stdout.writeln('Argon2id(64 MiB, t=3, p=4): seal $sealMs ms, open $openMs ms');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });
}
