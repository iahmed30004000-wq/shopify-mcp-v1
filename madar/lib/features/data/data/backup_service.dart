import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../core/db/database.dart';
import '../../../core/db/db_errors.dart';
import '../../../core/db/snapshot.dart';
import '../domain/backup_codec.dart';
import '../domain/backup_format.dart';
import 'data_repository.dart';

/// A backup opened with its passphrase, ready to preview and restore.
class OpenedBackup {
  OpenedBackup({required this.header, required this.snapshot, required this.counts, required this.key, this.fileName});

  final BackupHeader header;

  /// The snapshot (see `core/db/snapshot.dart`).
  final Map<String, Object?> snapshot;

  /// Rows per table ([snapshotRowCounts]).
  final Map<String, int> counts;

  /// The key that opened it (seals the safety copy); destroyed after use.
  final BackupKey key;
  final String? fileName;

  int get totalRecords => counts.values.fold(0, (a, b) => a + b);

  void dispose() => key.destroy();
}

/// A safety copy kept on this device (app-private storage).
class SafetyCopy {
  const SafetyCopy({required this.file, required this.createdAt, required this.size});

  final File file;
  final DateTime createdAt;
  final int size;

  String get name => file.uri.pathSegments.last;
}

/// Steps of [BackupService.restore], reported as they start.
enum RestorePhase { safetyCopy, restoring }

enum RestoreProblem {
  /// The safety copy of the current data could not be written; nothing was
  /// changed.
  safetyCopyFailed,

  /// The database refused the backup's data; nothing was changed.
  rejected,
}

class RestoreException implements Exception {
  const RestoreException(this.problem, [this.cause]);

  final RestoreProblem problem;
  final Object? cause;

  @override
  String toString() => 'RestoreException(${problem.name})${cause == null ? '' : ': $cause'}';
}

/// What a restore did.
class RestoreResult {
  const RestoreResult({required this.safetyCopy, required this.restoredRecords, required this.previousRecords});

  final SafetyCopy safetyCopy;
  final int restoredRecords;
  final int previousRecords;
}

/// Creates encrypted backups and restores them, keeping a safety copy of the
/// current data (sealed with the passphrase just entered) before replacing
/// anything.
class BackupService {
  BackupService(
    this.db, {
    this.codec = const MadarBackupCodec(),
    required this.safetyDirectory,
    DateTime Function()? clock,
    this.keepSafetyCopies = 3,
  }) : clock = clock ?? DateTime.now;

  final MadarDatabase db;
  final MadarBackupCodec codec;

  /// App-private folder for safety copies (created on demand).
  final Future<Directory> Function() safetyDirectory;
  final DateTime Function() clock;

  /// Safety copies kept (oldest are deleted).
  final int keepSafetyCopies;

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final l = t.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)}-${two(l.hour)}${two(l.minute)}${two(l.second)}';
  }

  static String backupFileName(DateTime now) {
    final s = _stamp(now);
    return 'madar-backup-${s.substring(0, s.length - 2)}.$madarBackupExtension';
  }

  Future<Uint8List> _currentJson(DateTime now) async {
    final snapshot = await exportSnapshot(db, exportedAt: now);
    return DataExportRepository.encodeJson(snapshot, useIsolate: codec.useIsolate);
  }

  /// Seals every table with [passphrase]. The passphrase is not kept.
  Future<DataFile> create(String passphrase) async {
    final now = clock();
    final snapshot = await exportSnapshot(db, exportedAt: now);
    final records = snapshotRowCounts(snapshot).values.fold<int>(0, (a, b) => a + b);
    final json = await DataExportRepository.encodeJson(snapshot, useIsolate: codec.useIsolate);
    final (bytes, key) = await codec.seal(json, passphrase, createdAt: now, schemaVersion: db.schemaVersion);
    key.destroy();
    return DataFile(
      name: backupFileName(now),
      bytes: bytes,
      mimeType: madarBackupMimeType,
      encrypted: true,
      records: records,
    );
  }

  /// Reads the header without a passphrase (throws [BackupException]).
  BackupHeader peek(Uint8List file) {
    final header = MadarBackupCodec.peek(file);
    _checkSchema(header.schemaVersion);
    return header;
  }

  void _checkSchema(int version) {
    if (version > db.schemaVersion) {
      throw BackupException(BackupProblem.newerVersion, 'Schema $version is newer than ${db.schemaVersion}');
    }
  }

  /// Opens [file] with [passphrase] and validates the snapshot inside.
  /// Throws [BackupException]; nothing is changed.
  Future<OpenedBackup> open(Uint8List file, String passphrase, {String? fileName}) async {
    final opened = await codec.open(file, passphrase);
    try {
      _checkSchema(opened.header.schemaVersion);
      final Object? decoded;
      try {
        decoded = await _decodeJson(opened.json, useIsolate: codec.useIsolate);
      } on FormatException {
        throw const BackupException(BackupProblem.corrupted, 'Snapshot is not JSON');
      }
      if (decoded is! Map<String, Object?>) {
        throw const BackupException(BackupProblem.corrupted, 'Snapshot is not an object');
      }
      final Map<String, int> counts;
      try {
        counts = snapshotRowCounts(decoded);
      } on SnapshotException {
        throw const BackupException(BackupProblem.corrupted, 'Not a Madar snapshot');
      }
      final schema = decoded['schemaVersion'];
      if (schema is int) _checkSchema(schema);
      return OpenedBackup(header: opened.header, snapshot: decoded, counts: counts, key: opened.key, fileName: fileName);
    } catch (_) {
      opened.key.destroy();
      rethrow;
    }
  }

  /// Rows per table in the current database.
  Future<Map<String, int>> currentCounts() async => {
    for (final table in db.allTables)
      table.actualTableName: (await db
              .customSelect('SELECT count(*) AS c FROM "${table.actualTableName}"', readsFrom: {table})
              .getSingle())
          .read<int>('c'),
  };

  /// Replaces all data with [backup]: first seals a safety copy of the
  /// current data (same passphrase) into app storage, then restores in one
  /// transaction. On any failure the current data is untouched.
  Future<RestoreResult> restore(OpenedBackup backup, {void Function(RestorePhase phase)? onPhase}) async {
    final now = clock();
    onPhase?.call(RestorePhase.safetyCopy);
    final previous = (await currentCounts()).values.fold<int>(0, (a, b) => a + b);
    final SafetyCopy safety;
    try {
      final json = await _currentJson(now);
      final bytes = await codec.sealWithKey(json, backup.key, createdAt: now, schemaVersion: db.schemaVersion);
      safety = await _writeSafetyCopy(bytes, now);
    } catch (e) {
      throw RestoreException(RestoreProblem.safetyCopyFailed, e);
    }
    onPhase?.call(RestorePhase.restoring);
    try {
      await restoreSnapshot(db, backup.snapshot);
    } catch (e) {
      throw RestoreException(RestoreProblem.rejected, unwrapDatabaseError(e));
    }
    return RestoreResult(safetyCopy: safety, restoredRecords: backup.totalRecords, previousRecords: previous);
  }

  Future<SafetyCopy> _writeSafetyCopy(Uint8List bytes, DateTime now) async {
    final dir = await safetyDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/madar-safety-${_stamp(now)}.$madarBackupExtension');
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    // Read back and check it opens as a container before trusting it.
    final check = await tmp.readAsBytes();
    if (check.length != bytes.length) throw const FileSystemException('Safety copy was not fully written');
    MadarBackupCodec.peek(check);
    await tmp.rename(file.path);
    await _prune(dir);
    return SafetyCopy(file: file, createdAt: now, size: bytes.length);
  }

  Future<void> _prune(Directory dir) async {
    final copies = await safetyCopies();
    for (final c in copies.skip(keepSafetyCopies)) {
      try {
        await c.file.delete();
      } catch (_) {}
    }
  }

  /// Safety copies on this device, newest first.
  Future<List<SafetyCopy>> safetyCopies() async {
    final dir = await safetyDirectory();
    if (!await dir.exists()) return const [];
    final out = <SafetyCopy>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.$madarBackupExtension')) continue;
      try {
        final bytes = await e.readAsBytes();
        final header = MadarBackupCodec.peek(bytes);
        out.add(SafetyCopy(file: e, createdAt: header.createdAt, size: bytes.length));
      } catch (_) {
        // A damaged leftover: ignore (never auto-delete user data).
      }
    }
    out.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.name.compareTo(a.name);
    });
    return out;
  }
}

Future<Object?> _decodeJson(Uint8List bytes, {required bool useIsolate}) {
  Object? work() => jsonDecode(utf8.decode(bytes));
  return useIsolate ? Isolate.run(work) : Future.value(work());
}
