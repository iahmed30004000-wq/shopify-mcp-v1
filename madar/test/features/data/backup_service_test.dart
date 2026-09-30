import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/data/data/backup_service.dart';
import 'package:madar/features/data/data/data_repository.dart';
import 'package:madar/features/data/domain/backup_codec.dart';
import 'package:madar/features/data/domain/backup_format.dart';

import '../../core/db/fixtures.dart';

const fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const pass = 'amber lanterns over quiet water';

Matcher throwsProblem(BackupProblem p) =>
    throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));

Map<String, Object?> withoutTimestamp(Map<String, Object?> s) => Map.of(s)..remove('exportedAt');

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Directory safetyDir;
  var clock = DateTime(2026, 9, 30, 10);

  BackupService service(MadarDatabase d, {Future<Directory> Function()? dir, bool isolate = false}) => BackupService(
    d,
    codec: MadarBackupCodec(kdf: fastKdf, useIsolate: isolate),
    safetyDirectory: dir ?? () async => safetyDir,
    clock: () => clock,
  );

  setUp(() async {
    clock = DateTime(2026, 9, 30, 10);
    db = MadarDatabase(NativeDatabase.memory());
    await populateAllTables(db);
    safetyDir = Directory.systemTemp.createTempSync('madar_safety_');
  });

  tearDown(() async {
    await db.close();
    if (safetyDir.existsSync()) safetyDir.deleteSync(recursive: true);
  });

  test('create → open → restore round-trips every table losslessly', () async {
    final file = await service(db).create(pass);
    expect(file.name, 'madar-backup-2026-09-30-1000.madarbackup');
    expect(file.encrypted, isTrue);
    expect(file.mimeType, madarBackupMimeType);
    final source = await exportSnapshot(db);
    final expectedCounts = snapshotRowCounts(source);
    expect(file.records, expectedCounts.values.fold<int>(0, (a, b) => a + b));

    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await target.into(target.tasks).insert(TasksCompanion.insert(title: 'will be replaced'));
    final opened = await service(target).open(file.bytes, pass, fileName: file.name);
    expect(opened.counts, expectedCounts);
    expect(opened.header.schemaVersion, db.schemaVersion);
    expect(opened.fileName, file.name);

    final result = await service(target).restore(opened);
    expect(result.restoredRecords, file.records);
    expect(result.previousRecords, 1);
    expect(withoutTimestamp(await exportSnapshot(target)), withoutTimestamp(source));
  });

  test('restore first seals a safety copy of the current data with the same passphrase', () async {
    final backup = await service(db).create(pass);
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await target.into(target.tasks).insert(TasksCompanion.insert(id: const Value('mine'), title: 'current data'));
    final before = await exportSnapshot(target);

    final phases = <RestorePhase>[];
    final s = service(target);
    final result = await s.restore(await s.open(backup.bytes, pass), onPhase: phases.add);
    expect(phases, [RestorePhase.safetyCopy, RestorePhase.restoring]);

    final copy = result.safetyCopy;
    expect(copy.file.existsSync(), isTrue);
    expect(copy.file.path, startsWith(safetyDir.path));
    expect(copy.name, 'madar-safety-2026-09-30-100000.madarbackup');
    expect(safetyDir.listSync().whereType<File>().where((f) => f.path.endsWith('.part')), isEmpty);

    // The copy holds the data that was replaced and opens with the same passphrase.
    final reopened = await s.open(await copy.file.readAsBytes(), pass);
    expect(withoutTimestamp(reopened.snapshot), withoutTimestamp(jsonDecode(jsonEncode(before)) as Map<String, Object?>));
    // …and undoes the restore.
    await s.restore(reopened);
    final tasks = await target.select(target.tasks).get();
    expect(tasks.single.id, 'mine');
  });

  test('safety copies are listed newest first and pruned to three', () async {
    final backup = await service(db).create(pass);
    final s = service(db);
    for (var i = 0; i < 5; i++) {
      clock = DateTime(2026, 9, 30, 10, i);
      await s.restore(await s.open(backup.bytes, pass));
    }
    File('${safetyDir.path}/junk.madarbackup').writeAsStringSync('not a backup');
    final copies = await s.safetyCopies();
    expect(copies, hasLength(3));
    expect(copies.map((c) => c.createdAt.toLocal().minute), [4, 3, 2]);
    expect(copies.first.size, greaterThan(0));
  });

  test('no safety copy → no restore; the data is untouched', () async {
    final backup = await service(db).create(pass);
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await target.into(target.tasks).insert(TasksCompanion.insert(title: 'keep me'));
    final s = service(target, dir: () async => throw const FileSystemException('disk full'));
    final opened = await s.open(backup.bytes, pass);
    await expectLater(
      s.restore(opened),
      throwsA(isA<RestoreException>().having((e) => e.problem, 'problem', RestoreProblem.safetyCopyFailed)),
    );
    expect((await target.select(target.tasks).get()).single.title, 'keep me');
  });

  test('a snapshot the database rejects changes nothing', () async {
    final s = service(db);
    final json = Uint8List.fromList(utf8.encode(jsonEncode({
      'format': madarSnapshotFormat,
      'formatVersion': 1,
      'schemaVersion': db.schemaVersion,
      'tables': {
        'tasks': [
          {'id': 'x', 'title': 'x', 'no_such_column': 1},
        ],
      },
    })));
    final (bytes, key) = await s.codec.seal(json, pass, createdAt: clock, schemaVersion: db.schemaVersion);
    key.destroy();
    final before = await exportSnapshot(db);
    final opened = await s.open(bytes, pass);
    expect(opened.counts, {'tasks': 1});
    await expectLater(
      s.restore(opened),
      throwsA(isA<RestoreException>().having((e) => e.problem, 'problem', RestoreProblem.rejected)),
    );
    expect(withoutTimestamp(await exportSnapshot(db)), withoutTimestamp(before));
  });

  test('errors are reported before anything changes', () async {
    final s = service(db);
    final backup = await s.create(pass);
    await expectLater(s.open(backup.bytes, 'wrong passphrase here'), throwsProblem(BackupProblem.wrongPassphrase));
    await expectLater(s.open(Uint8List.sublistView(backup.bytes, 0, backup.bytes.length - 3), pass), throwsProblem(BackupProblem.truncated));
    final tampered = Uint8List.fromList(backup.bytes)..[backup.bytes.length - 40] ^= 1;
    await expectLater(s.open(tampered, pass), throwsProblem(BackupProblem.corrupted));
    await expectLater(s.open(Uint8List.fromList(utf8.encode('hello')), pass), throwsProblem(BackupProblem.notABackup));

    // A valid container whose content is not a snapshot.
    final (junk, key) = await s.codec.seal(Uint8List.fromList(utf8.encode('[1,2,3]')), pass, createdAt: clock, schemaVersion: 1);
    key.destroy();
    await expectLater(s.open(junk, pass), throwsProblem(BackupProblem.corrupted));
    final (notJson, key2) = await s.codec.seal(Uint8List.fromList(utf8.encode('{nope')), pass, createdAt: clock, schemaVersion: 1);
    key2.destroy();
    await expectLater(s.open(notJson, pass), throwsProblem(BackupProblem.corrupted));
  });

  test('a backup from a newer schema is refused before the passphrase is asked', () async {
    final s = service(db);
    final (bytes, key) = await s.codec.seal(
      Uint8List.fromList(utf8.encode(jsonEncode({'format': madarSnapshotFormat, 'schemaVersion': 99, 'tables': {}}))),
      pass,
      createdAt: clock,
      schemaVersion: 99,
    );
    key.destroy();
    expect(() => s.peek(bytes), throwsProblem(BackupProblem.newerVersion));
    await expectLater(s.open(bytes, pass), throwsProblem(BackupProblem.newerVersion));
    // An older-schema backup is accepted (restoreSnapshot migrates it).
    final (older, key3) = await s.codec.seal(
      Uint8List.fromList(utf8.encode(jsonEncode({'format': madarSnapshotFormat, 'schemaVersion': 1, 'tables': {'tasks': []}}))),
      pass,
      createdAt: clock,
      schemaVersion: 1,
    );
    key3.destroy();
    expect(s.peek(older).schemaVersion, 1);
    expect((await s.open(older, pass)).counts, {'tasks': 0});
  });

  test('the full JSON export restores to the same data', () async {
    final repo = DataExportRepository(db, useIsolate: false);
    final file = await repo.jsonExport(clock);
    expect(file.name, 'madar-export-2026-09-30.json');
    expect(file.mimeType, 'application/json');
    expect(file.encrypted, isFalse);
    final decoded = jsonDecode(utf8.decode(file.bytes)) as Map<String, Object?>;
    expect(decoded['format'], madarSnapshotFormat);
    expect(file.records, snapshotRowCounts(decoded).values.fold<int>(0, (a, b) => a + b));
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await restoreSnapshot(target, decoded);
    expect(withoutTimestamp(await exportSnapshot(target)), withoutTimestamp(await exportSnapshot(db)));
  });

  test('large data: 60 000 records back up and restore in reasonable time (background isolates)', () async {
    final big = MadarDatabase(NativeDatabase.memory());
    addTearDown(big.close);
    await big.batch((b) {
      b.insert(big.wallets, WalletsCompanion.insert(id: const Value('w'), name: 'Cash', currency: 'JOD'));
      for (var i = 0; i < 30000; i++) {
        b.insert(
          big.transactions,
          TransactionsCompanion.insert(
            walletId: 'w',
            kind: TxKind.expense,
            amountMilli: 1000 + i,
            date: DateTime(2020, 1, 1).add(Duration(days: i % 2400)),
            note: Value('ملاحظة رقم $i – note $i'),
            tags: const Value(['food', 'family']),
          ),
        );
      }
      for (var i = 0; i < 15000; i++) {
        b.insert(big.moodEntries, MoodEntriesCompanion.insert(at: DateTime(2020, 1, 1, 8).add(Duration(hours: i * 5)), mood: Value(1 + i % 5), stress: Value(i % 11)));
        b.insert(big.painEntries, PainEntriesCompanion.insert(at: DateTime(2020, 1, 1, 9).add(Duration(hours: i * 5)), score: i % 11, locations: const Value(['knee'])));
      }
    });
    final s = service(big, isolate: true);
    final sw = Stopwatch()..start();
    final file = await s.create(pass);
    final createMs = sw.elapsedMilliseconds;
    expect(file.records, 60001);

    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    final t = service(target, isolate: true);
    sw.reset();
    final opened = await t.open(file.bytes, pass);
    final openMs = sw.elapsedMilliseconds;
    sw.reset();
    await t.restore(opened);
    final restoreMs = sw.elapsedMilliseconds;
    expect(await target.select(target.transactions).get(), hasLength(30000));
    stdout.writeln(
      'large backup: ${file.records} records, ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB; '
      'create $createMs ms, open $openMs ms, restore $restoreMs ms',
    );
    // Generous bounds (a phone is slower than the host); catches regressions
    // such as an accidental quadratic step.
    expect(createMs, lessThan(60000));
    expect(openMs, lessThan(60000));
    expect(restoreMs, lessThan(90000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
