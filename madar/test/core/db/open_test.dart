import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/db_errors.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/db/open.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory dir;
  late File file;
  final key = 'ab' * 32;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('madar_db_test');
    file = File('${dir.path}/nested/madar.db');
  });

  tearDown(() => dir.delete(recursive: true));

  test('opens a file database on a background isolate, seeds once and persists', () async {
    var db = await openMadarDatabase(key: key, file: file);
    expect(file.existsSync(), isTrue);
    expect(await db.select(db.planets).get(), hasLength(8));
    await db.into(db.tasks).insert(TasksCompanion.insert(title: 'persisted'));
    final journal = await db.customSelect('PRAGMA journal_mode').getSingle();
    expect(journal.data.values.single, 'wal');
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.single, 1);
    await db.close();

    db = await openMadarDatabase(key: key, file: file);
    expect((await db.select(db.tasks).get()).single.title, 'persisted');
    expect(await db.select(db.planets).get(), hasLength(8), reason: 'no duplicate seeding');
    await db.close();
  });

  test('requires SQLCipher when asked (always on Android)', () async {
    // The host test platform links the system SQLite, so cipher_version is
    // empty – exactly what a broken Android build would look like.
    await expectLater(
      openMadarDatabase(key: key, file: file, requireCipher: true),
      throwsA(isA<CipherUnavailableError>().having((e) => e.message, 'message', contains('SQLCipher'))),
    );
  });

  test('a key that does not decrypt the file surfaces as wrongKey', () async {
    // With SQLCipher a wrong key makes the first page read fail with
    // SQLITE_NOTADB; a file that is not a database fails the same way on the
    // host's plain SQLite.
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.generate(8192, (i) => (i * 31 + 7) % 256));
    await expectLater(
      openMadarDatabase(key: key, file: file),
      throwsA(isA<DatabaseKeyException>().having((e) => e.problem, 'problem', DatabaseKeyProblem.wrongKey)),
    );
  });

  test('rejects malformed keys before touching the file', () async {
    await expectLater(
      openMadarDatabase(key: "x'; DROP TABLE tasks; --", file: file),
      throwsA(isA<DatabaseKeyException>().having((e) => e.problem, 'problem', DatabaseKeyProblem.malformed)),
    );
    expect(file.existsSync(), isFalse);
  });

  test('unlock creates the key on first run and reuses it', () async {
    final secrets = MemorySecretStore();
    final keys = DatabaseKeyStore(store: secrets);
    var db = await unlockMadarDatabase(keyStore: keys, file: file);
    final created = secrets.values[DatabaseKeyStore.storageKey];
    expect(created, isNotNull);
    await db.close();

    db = await unlockMadarDatabase(keyStore: keys, file: file);
    expect(secrets.values[DatabaseKeyStore.storageKey], created);
    await db.close();
  });

  test('unlock refuses to invent a key for an existing database', () async {
    final keys = DatabaseKeyStore(store: MemorySecretStore());
    final db = await unlockMadarDatabase(keyStore: keys, file: file);
    await db.close();
    await keys.wipe();
    await expectLater(
      unlockMadarDatabase(keyStore: keys, file: file),
      throwsA(isA<DatabaseKeyException>().having((e) => e.problem, 'problem', DatabaseKeyProblem.missing)),
    );
    expect(await keys.readKey(), isNull);
  });

  test('delete all data removes the files and the key', () async {
    final keys = DatabaseKeyStore(store: MemorySecretStore());
    final db = await unlockMadarDatabase(keyStore: keys, file: file);
    await db.into(db.tasks).insert(TasksCompanion.insert(title: 'x'));
    await db.close();
    await deleteAllMadarData(keyStore: keys, file: file);
    for (final suffix in ['', '-wal', '-shm']) {
      expect(File('${file.path}$suffix').existsSync(), isFalse);
    }
    expect(await keys.readKey(), isNull);

    final fresh = await unlockMadarDatabase(keyStore: keys, file: file);
    expect(await fresh.select(fresh.tasks).get(), isEmpty);
    await fresh.close();
  });

  test('in-memory factory is seeded and ready', () async {
    final db = await openInMemoryMadarDatabase();
    expect(await db.select(db.currencies).get(), hasLength(5));
    await db.close();
  });
}
