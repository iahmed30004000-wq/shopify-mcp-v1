/// The `.madarbackup` container: a versioned, self-describing header followed
/// by the AES-256-GCM ciphertext of the gzip-compressed snapshot JSON.
///
/// ```text
/// offset  size        field
/// 0       8           magic  "MADARBAK" (ASCII)
/// 8       2           container version, uint16 big-endian (= 1)
/// 10      4           header length N, uint32 big-endian (≤ 64 KiB)
/// 14      N           header, UTF-8 JSON (see [BackupHeader])
/// 14+N    32          SHA-256 of bytes [0, 14+N) – detects a damaged header
/// 46+N    L           ciphertext (L = header.bodyLength)
/// 46+N+L  16          GCM authentication tag
/// ```
///
/// The first `14 + N` bytes (magic, version, length, header) are also the
/// GCM *additional authenticated data*, so nothing in the header can be
/// changed without the tag failing. The header holds no personal data: only
/// the format, the creation time, the schema version, the key-derivation
/// parameters and salt, the nonce, a 16-byte key check and the body length.
///
/// The key check (`SHA-256("madar.backup.check" ‖ K₂)[0..16)`, where the
/// passphrase-derived 64 bytes are `K₁ ‖ K₂` and `K₁` is the AES key) lets a
/// reader tell a wrong passphrase from a damaged file. It reveals nothing an
/// attacker could not learn by trying to decrypt: every guess still costs one
/// full Argon2id derivation.
///
/// Pure Dart (no Flutter): parsing and serialisation only; the cryptography
/// lives in `backup_codec.dart`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Magic bytes at the start of every backup file.
const List<int> madarBackupMagic = [0x4D, 0x41, 0x44, 0x41, 0x52, 0x42, 0x41, 0x4B]; // MADARBAK

/// Container version this build writes and the newest it can read.
const int madarBackupVersion = 1;

/// File extension (without the dot).
const String madarBackupExtension = 'madarbackup';

/// MIME type used when sharing / saving a backup.
const String madarBackupMimeType = 'application/octet-stream';

/// `format` value inside the header.
const String madarBackupFormat = 'madar.backup';

/// Fixed sizes of the container.
abstract final class BackupLayout {
  static const int magicLength = 8;
  static const int prefixLength = 14; // magic + version + header length
  static const int hashLength = 32;
  static const int tagLength = 16;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int checkLength = 16;

  /// Largest header accepted (a real one is ~400 bytes).
  static const int maxHeaderLength = 64 * 1024;
}

/// Why a backup could not be opened.
enum BackupProblem {
  /// Not a Madar backup at all (wrong magic / format).
  notABackup,

  /// Written by a newer Madar (container version, key derivation or schema).
  newerVersion,

  /// The passphrase does not open this backup.
  wrongPassphrase,

  /// The file ends early (an interrupted copy or download).
  truncated,

  /// The file was changed or damaged (header checksum, authentication tag,
  /// compression or contents).
  corrupted,
}

/// A backup failed to open. Nothing is ever changed when this is thrown.
class BackupException implements Exception {
  const BackupException(this.problem, this.message);

  final BackupProblem problem;
  final String message;

  @override
  String toString() => 'BackupException(${problem.name}): $message';
}

/// Argon2id cost parameters (RFC 9106).
@immutable
class BackupKdfParams {
  const BackupKdfParams({this.memoryKiB = 65536, this.iterations = 3, this.parallelism = 4});

  /// RFC 9106 §4, second recommended option ("memory-constrained"):
  /// Argon2id, 64 MiB, 3 passes, 4 lanes.
  ///
  /// Measured with the package's pure-Dart implementation (4-core x86-64,
  /// Dart VM): ≈ 0.8 s. A 2021 mid-range phone is roughly 2–4× slower per
  /// core (≈ 2–3 s), which is paid once per backup and once per restore.
  /// PBKDF2-HMAC-SHA256 at the OWASP 310 000 iterations took 1.5 s on the
  /// same machine (≈ 4–6 s on a phone) while being far cheaper to attack on
  /// GPUs, so Argon2id is both faster for the user and stronger. The
  /// parameters travel in every header, so they can be raised later without
  /// breaking old files.
  static const BackupKdfParams recommended = BackupKdfParams();

  /// Kibibytes of memory (m).
  final int memoryKiB;

  /// Passes over memory (t).
  final int iterations;

  /// Lanes (p).
  final int parallelism;

  /// Bounds accepted when *reading* a header: anything outside is treated as
  /// damage (and protects the phone from a crafted file demanding 64 GiB).
  bool get isSane =>
      parallelism >= 1 &&
      parallelism <= 16 &&
      iterations >= 1 &&
      iterations <= 64 &&
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= 1024 * 1024;

  Map<String, Object?> toJson() => {'m': memoryKiB, 't': iterations, 'p': parallelism};

  @override
  bool operator ==(Object other) =>
      other is BackupKdfParams &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);

  @override
  String toString() => 'Argon2id(m=$memoryKiB KiB, t=$iterations, p=$parallelism)';
}

/// The JSON header of a backup file (never secret).
@immutable
class BackupHeader {
  const BackupHeader({
    required this.createdAt,
    required this.schemaVersion,
    required this.kdf,
    required this.salt,
    required this.nonce,
    required this.keyCheck,
    required this.bodyLength,
    this.compression = 'gzip',
  });

  /// When the backup was made (UTC).
  final DateTime createdAt;

  /// Database schema version of the snapshot inside.
  final int schemaVersion;
  final BackupKdfParams kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List keyCheck;

  /// Ciphertext length (without the tag).
  final int bodyLength;
  final String compression;

  Map<String, Object?> toJson() => {
    'format': madarBackupFormat,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'content': 'madar.snapshot+json',
    'compression': compression,
    'kdf': {'alg': 'argon2id', 'v': 19, ...kdf.toJson(), 'salt': base64.encode(salt)},
    'cipher': {'alg': 'aes-256-gcm', 'nonce': base64.encode(nonce)},
    'check': base64.encode(keyCheck),
    'bodyLength': bodyLength,
  };

  /// Parses a decoded header; throws [BackupException].
  static BackupHeader fromJson(Object? json) {
    Never damaged(String what) => throw BackupException(BackupProblem.corrupted, 'Invalid header: $what');
    if (json is! Map) damaged('not an object');
    if (json['format'] != madarBackupFormat) {
      throw const BackupException(BackupProblem.notABackup, 'Header format is not madar.backup');
    }
    final kdf = json['kdf'];
    final cipher = json['cipher'];
    if (kdf is! Map || cipher is! Map) damaged('kdf / cipher');
    if (kdf['alg'] != 'argon2id' || kdf['v'] != 19) {
      throw BackupException(BackupProblem.newerVersion, 'Unsupported key derivation ${kdf['alg']}/${kdf['v']}');
    }
    if (cipher['alg'] != 'aes-256-gcm') {
      throw BackupException(BackupProblem.newerVersion, 'Unsupported cipher ${cipher['alg']}');
    }
    final compression = json['compression'];
    if (compression != 'gzip') {
      throw BackupException(BackupProblem.newerVersion, 'Unsupported compression $compression');
    }
    Uint8List bytes(Object? v, int length, String what) {
      if (v is! String) damaged(what);
      final Uint8List out;
      try {
        out = base64.decode(v);
      } on FormatException {
        damaged(what);
      }
      if (out.length != length) damaged(what);
      return out;
    }

    int integer(Object? v, String what) => v is int ? v : damaged(what);
    final params = BackupKdfParams(
      memoryKiB: integer(kdf['m'], 'm'),
      iterations: integer(kdf['t'], 't'),
      parallelism: integer(kdf['p'], 'p'),
    );
    if (!params.isSane) damaged('kdf parameters $params');
    final created = json['createdAt'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    if (createdAt == null) damaged('createdAt');
    final schema = integer(json['schemaVersion'], 'schemaVersion');
    final length = integer(json['bodyLength'], 'bodyLength');
    if (schema < 1 || length < 0) damaged('schemaVersion / bodyLength');
    return BackupHeader(
      createdAt: createdAt.toUtc(),
      schemaVersion: schema,
      kdf: params,
      salt: bytes(kdf['salt'], BackupLayout.saltLength, 'salt'),
      nonce: bytes(cipher['nonce'], BackupLayout.nonceLength, 'nonce'),
      keyCheck: bytes(json['check'], BackupLayout.checkLength, 'check'),
      bodyLength: length,
      compression: compression as String,
    );
  }
}

/// A backup file split into its parts (nothing decrypted yet).
@immutable
class BackupEnvelope {
  const BackupEnvelope({required this.header, required this.aad, required this.cipherText, required this.tag});

  final BackupHeader header;

  /// Magic + version + header length + header (the GCM additional data).
  final Uint8List aad;
  final Uint8List cipherText;
  final Uint8List tag;

  /// Assembles a file: `aad ‖ sha256(aad) ‖ cipherText ‖ tag`.
  static Uint8List assemble({
    required Uint8List aad,
    required List<int> aadHash,
    required List<int> cipherText,
    required List<int> tag,
  }) {
    final out = Uint8List(aad.length + aadHash.length + cipherText.length + tag.length);
    var o = 0;
    for (final part in [aad, aadHash, cipherText, tag]) {
      out.setRange(o, o + part.length, part);
      o += part.length;
    }
    return out;
  }

  /// `magic ‖ version ‖ length ‖ header` for [header].
  static Uint8List prefixFor(BackupHeader header, {int version = madarBackupVersion}) {
    final json = utf8.encode(jsonEncode(header.toJson()));
    final out = Uint8List(BackupLayout.prefixLength + json.length);
    out.setRange(0, BackupLayout.magicLength, madarBackupMagic);
    final view = ByteData.sublistView(out);
    view.setUint16(8, version);
    view.setUint32(10, json.length);
    out.setRange(BackupLayout.prefixLength, out.length, json);
    return out;
  }

  /// Whether [bytes] start like a Madar backup (magic only).
  static bool looksLikeBackup(List<int> bytes) {
    if (bytes.length < BackupLayout.magicLength) return false;
    for (var i = 0; i < BackupLayout.magicLength; i++) {
      if (bytes[i] != madarBackupMagic[i]) return false;
    }
    return true;
  }

  /// Splits [bytes] and validates everything that can be checked without
  /// the passphrase. [sha256] hashes the prefix (injected to keep this file
  /// free of the crypto package).
  static BackupEnvelope parse(Uint8List bytes, {required List<int> Function(List<int>) sha256}) {
    if (!looksLikeBackup(bytes)) {
      throw const BackupException(BackupProblem.notABackup, 'Missing MADARBAK magic');
    }
    if (bytes.length < BackupLayout.prefixLength) {
      throw const BackupException(BackupProblem.truncated, 'File ends inside the header');
    }
    final view = ByteData.sublistView(bytes);
    final version = view.getUint16(8);
    if (version == 0) throw const BackupException(BackupProblem.corrupted, 'Container version 0');
    if (version > madarBackupVersion) {
      throw BackupException(BackupProblem.newerVersion, 'Container version $version > $madarBackupVersion');
    }
    final headerLength = view.getUint32(10);
    if (headerLength == 0 || headerLength > BackupLayout.maxHeaderLength) {
      throw BackupException(BackupProblem.corrupted, 'Header length $headerLength');
    }
    final aadEnd = BackupLayout.prefixLength + headerLength;
    if (bytes.length < aadEnd + BackupLayout.hashLength) {
      throw const BackupException(BackupProblem.truncated, 'File ends inside the header');
    }
    final aad = Uint8List.sublistView(bytes, 0, aadEnd);
    final storedHash = Uint8List.sublistView(bytes, aadEnd, aadEnd + BackupLayout.hashLength);
    if (!constantTimeEquals(sha256(aad), storedHash)) {
      throw const BackupException(BackupProblem.corrupted, 'Header checksum mismatch');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(Uint8List.sublistView(aad, BackupLayout.prefixLength)));
    } on FormatException {
      throw const BackupException(BackupProblem.corrupted, 'Header is not JSON');
    }
    final header = BackupHeader.fromJson(json);
    final bodyStart = aadEnd + BackupLayout.hashLength;
    final expectedEnd = bodyStart + header.bodyLength + BackupLayout.tagLength;
    if (bytes.length < expectedEnd) {
      throw BackupException(BackupProblem.truncated, 'Expected $expectedEnd bytes, found ${bytes.length}');
    }
    if (bytes.length > expectedEnd) {
      throw BackupException(BackupProblem.corrupted, '${bytes.length - expectedEnd} unexpected trailing bytes');
    }
    return BackupEnvelope(
      header: header,
      aad: aad,
      cipherText: Uint8List.sublistView(bytes, bodyStart, bodyStart + header.bodyLength),
      tag: Uint8List.sublistView(bytes, bodyStart + header.bodyLength, expectedEnd),
    );
  }
}

/// Compares two byte lists in time independent of where they differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
