import 'dart:math';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/db_errors.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

/// Records writes; can be told to fail or to drop writes.
class FakeSecretStore extends MemorySecretStore {
  bool failReads = false;
  bool failWrites = false;
  bool dropWrites = false;
  int writes = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keystore locked');
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failWrites) throw StateError('keystore unavailable');
    if (dropWrites) return;
    await super.write(key, value);
  }
}

Matcher throwsKeyProblem(DatabaseKeyProblem problem) =>
    throwsA(isA<DatabaseKeyException>().having((e) => e.problem, 'problem', problem));

void main() {
  late FakeSecretStore store;
  late DatabaseKeyStore keys;

  setUp(() {
    store = FakeSecretStore();
    keys = DatabaseKeyStore(store: store);
  });

  test('generates a 256-bit hex key once and returns it afterwards', () async {
    expect(await keys.readKey(), isNull);
    expect(await keys.hasKey(), isFalse);
    final key = await keys.obtainKey();
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(DatabaseKeyStore.isValidKey(key), isTrue);
    expect(store.values[DatabaseKeyStore.storageKey], key);
    expect(await keys.obtainKey(), key);
    expect(await DatabaseKeyStore(store: store).obtainKey(), key, reason: 'a new instance reads the stored key');
    expect(store.writes, 1);
    expect(await keys.hasKey(), isTrue);
  });

  test('concurrent first-run calls share one key', () async {
    final results = await Future.wait([keys.obtainKey(), keys.obtainKey(), keys.obtainKey()]);
    expect(results.toSet(), hasLength(1));
    expect(store.writes, 1);
  });

  test('keys are random and generation is driven by the given Random', () {
    expect(DatabaseKeyStore.generateKey(Random(1)), DatabaseKeyStore.generateKey(Random(1)));
    expect(DatabaseKeyStore.generateKey(Random(1)), isNot(DatabaseKeyStore.generateKey(Random(2))));
    final secure = {for (var i = 0; i < 20; i++) DatabaseKeyStore.generateKey(Random.secure())};
    expect(secure, hasLength(20));
  });

  test('wipe forgets the key; the next run creates a new one', () async {
    final first = await keys.obtainKey();
    await keys.wipe();
    expect(await keys.readKey(), isNull);
    expect(await keys.obtainKey(), isNot(first));
  });

  test('a malformed stored key is reported, never replaced', () async {
    store.values[DatabaseKeyStore.storageKey] = 'not-a-key';
    await expectLater(keys.readKey(), throwsKeyProblem(DatabaseKeyProblem.malformed));
    await expectLater(keys.obtainKey(), throwsKeyProblem(DatabaseKeyProblem.malformed));
    expect(store.values[DatabaseKeyStore.storageKey], 'not-a-key');
  });

  test('storage failures surface as storageUnavailable', () async {
    store.failReads = true;
    await expectLater(keys.readKey(), throwsKeyProblem(DatabaseKeyProblem.storageUnavailable));
    store
      ..failReads = false
      ..failWrites = true;
    await expectLater(keys.obtainKey(), throwsKeyProblem(DatabaseKeyProblem.storageUnavailable));
    store
      ..failWrites = false
      ..dropWrites = true;
    await expectLater(keys.obtainKey(), throwsKeyProblem(DatabaseKeyProblem.storageUnavailable));
  });

  test('isValidKey', () {
    expect(DatabaseKeyStore.isValidKey('A' * 64), isTrue);
    expect(DatabaseKeyStore.isValidKey('a' * 63), isFalse);
    expect(DatabaseKeyStore.isValidKey("${'a' * 60}'; x"), isFalse);
  });

  group('describeDatabaseError', () {
    for (final lang in ['ar', 'en']) {
      test(lang, () {
        final l10n = lookupL10n(Locale(lang));
        expect(describeDatabaseError(l10n, CipherUnavailableError('x')), l10n.dbErrorCipherUnavailable);
        expect(
          describeDatabaseError(l10n, const DatabaseKeyException(DatabaseKeyProblem.wrongKey, 'x')),
          l10n.dbErrorWrongKey,
        );
        expect(
          describeDatabaseError(l10n, const DatabaseKeyException(DatabaseKeyProblem.missing, 'x')),
          l10n.dbErrorKeyMissing,
        );
        expect(
          describeDatabaseError(l10n, const SnapshotException(SnapshotProblem.newerSchema, 'x')),
          l10n.dbErrorSnapshotNewer,
        );
        expect(
          describeDatabaseError(l10n, const SnapshotException(SnapshotProblem.unknownColumn, 'x')),
          l10n.dbErrorSnapshotInvalid,
        );
        expect(
          describeDatabaseError(l10n, const SnapshotException(SnapshotProblem.rejected, 'x')),
          l10n.dbErrorSnapshotRejected,
        );
        expect(describeDatabaseError(l10n, Exception('?')), l10n.dbErrorUnknown);
      });
    }

    test('cipher errors are StateErrors; plain errors pass through unwrap', () {
      expect(CipherUnavailableError('x'), isA<StateError>());
      final plain = Exception('plain');
      expect(unwrapDatabaseError(plain), same(plain));
    });
  });
}
