/// Seals and opens `.madarbackup` files: Argon2id key derivation from the
/// user's passphrase, gzip, AES-256-GCM (see `backup_format.dart` for the
/// layout). The passphrase is only ever held in memory for the duration of
/// a call – it is never stored, logged or written anywhere.
///
/// Heavy work (Argon2id, compression, AES in pure Dart) runs on a background
/// isolate by default so the UI keeps animating.
library;

import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';

import 'backup_format.dart';

/// Key material derived from a passphrase for one salt. Held in memory only
/// (to seal the safety copy with the passphrase the user just typed, without
/// a second Argon2id run); call [destroy] when done.
@immutable
class BackupKey {
  const BackupKey({required this.kdf, required this.salt, required this.aesKey, required this.keyCheck});

  final BackupKdfParams kdf;
  final Uint8List salt;
  final Uint8List aesKey;
  final Uint8List keyCheck;

  /// Overwrites the key bytes.
  void destroy() {
    aesKey.fillRange(0, aesKey.length, 0);
  }
}

/// A decrypted backup: its header, the snapshot JSON bytes and the key that
/// opened it.
@immutable
class OpenedBackupBytes {
  const OpenedBackupBytes({required this.header, required this.json, required this.key});

  final BackupHeader header;

  /// UTF-8 snapshot JSON.
  final Uint8List json;
  final BackupKey key;
}

class MadarBackupCodec {
  const MadarBackupCodec({this.kdf = BackupKdfParams.recommended, this.useIsolate = true});

  /// Cost of the key derivation for *new* backups (reading uses the file's).
  final BackupKdfParams kdf;

  /// Run on a background isolate (off in widget tests that fake time).
  final bool useIsolate;

  static const _checkLabel = 'madar.backup.check';
  static final GZipCodec _gzip = GZipCodec(level: 6);

  Future<T> _run<T>(Future<T> Function() work) => useIsolate ? Isolate.run(work) : work();

  /// Derives the AES key and key check for [passphrase] and [salt].
  static Future<BackupKey> deriveKey(String passphrase, {required BackupKdfParams kdf, required Uint8List salt}) async {
    final argon = DartArgon2id(
      parallelism: kdf.parallelism,
      memory: kdf.memoryKiB,
      iterations: kdf.iterations,
      hashLength: 64,
    );
    final derived = await argon.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    final bytes = Uint8List.fromList(await derived.extractBytes());
    final aesKey = Uint8List.fromList(bytes.sublist(0, 32));
    final check = const DartSha256().hashSync([...utf8.encode(_checkLabel), ...bytes.sublist(32, 64)]).bytes;
    bytes.fillRange(0, bytes.length, 0);
    return BackupKey(
      kdf: kdf,
      salt: Uint8List.fromList(salt),
      aesKey: aesKey,
      keyCheck: Uint8List.fromList(check.sublist(0, BackupLayout.checkLength)),
    );
  }

  static Uint8List _randomBytes(Random random, int n) => Uint8List.fromList([for (var i = 0; i < n; i++) random.nextInt(256)]);

  static List<int> _sha256(List<int> data) => const DartSha256().hashSync(data).bytes;

  /// Encrypts [json] (the UTF-8 snapshot) with a key derived from
  /// [passphrase] and a fresh random salt. Returns the file bytes and the key
  /// (for [sealWithKey]); destroy the key when done.
  Future<(Uint8List, BackupKey)> seal(
    Uint8List json,
    String passphrase, {
    required DateTime createdAt,
    required int schemaVersion,
  }) {
    final kdf = this.kdf;
    return _run(() async {
      final random = Random.secure();
      final key = await deriveKey(passphrase, kdf: kdf, salt: _randomBytes(random, BackupLayout.saltLength));
      final file = await _sealSync(json, key, createdAt: createdAt, schemaVersion: schemaVersion, random: random);
      return (file, key);
    });
  }

  /// Encrypts [json] with an already derived [key] (same passphrase and
  /// salt, fresh nonce) – used for the safety copy taken before a restore.
  Future<Uint8List> sealWithKey(Uint8List json, BackupKey key, {required DateTime createdAt, required int schemaVersion}) =>
      _run(() => _sealSync(json, key, createdAt: createdAt, schemaVersion: schemaVersion, random: Random.secure()));

  static Future<Uint8List> _sealSync(
    Uint8List json,
    BackupKey key, {
    required DateTime createdAt,
    required int schemaVersion,
    required Random random,
  }) async {
    final compressed = Uint8List.fromList(_gzip.encode(json));
    final nonce = _randomBytes(random, BackupLayout.nonceLength);
    final header = BackupHeader(
      createdAt: createdAt.toUtc(),
      schemaVersion: schemaVersion,
      kdf: key.kdf,
      salt: key.salt,
      nonce: nonce,
      keyCheck: key.keyCheck,
      bodyLength: compressed.length,
    );
    final aad = BackupEnvelope.prefixFor(header);
    final box = await DartAesGcm.with256bits().encrypt(
      compressed,
      secretKey: SecretKeyData(key.aesKey),
      nonce: nonce,
      aad: aad,
    );
    return BackupEnvelope.assemble(aad: aad, aadHash: _sha256(aad), cipherText: box.cipherText, tag: box.mac.bytes);
  }

  /// Reads the header without the passphrase (throws [BackupException]).
  static BackupHeader peek(Uint8List file) => BackupEnvelope.parse(file, sha256: _sha256).header;

  /// Opens [file] with [passphrase]. Throws [BackupException]:
  /// [BackupProblem.notABackup], [BackupProblem.newerVersion],
  /// [BackupProblem.truncated], [BackupProblem.wrongPassphrase] or
  /// [BackupProblem.corrupted].
  Future<OpenedBackupBytes> open(Uint8List file, String passphrase) => _run(() async {
    final envelope = BackupEnvelope.parse(file, sha256: _sha256);
    final header = envelope.header;
    final key = await deriveKey(passphrase, kdf: header.kdf, salt: header.salt);
    if (!constantTimeEquals(key.keyCheck, header.keyCheck)) {
      key.destroy();
      throw const BackupException(BackupProblem.wrongPassphrase, 'The passphrase does not match');
    }
    final List<int> compressed;
    try {
      compressed = await DartAesGcm.with256bits().decrypt(
        SecretBox(envelope.cipherText, nonce: header.nonce, mac: Mac(envelope.tag)),
        secretKey: SecretKeyData(key.aesKey),
        aad: envelope.aad,
      );
    } on SecretBoxAuthenticationError {
      key.destroy();
      throw const BackupException(BackupProblem.corrupted, 'Authentication tag mismatch');
    }
    final Uint8List json;
    try {
      json = Uint8List.fromList(_gzip.decode(compressed));
    } catch (_) {
      key.destroy();
      throw const BackupException(BackupProblem.corrupted, 'Body does not decompress');
    }
    return OpenedBackupBytes(header: header, json: json, key: key);
  });
}
