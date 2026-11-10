// «صيامي»'s records in `key_values`: no schema change, one record per day,
// every write undoable, a damaged value read as empty - and the whole thing
// riding a real encrypted-backup round trip.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/data/domain/backup_codec.dart';
import 'package:madar/features/data/domain/backup_format.dart';
import 'package:madar/features/fasting/fasting.dart';

/// Cheap key derivation: the backup's own tests pay the production cost.
const _fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const _codec = MadarBackupCodec(kdf: _fastKdf, useIsolate: false);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late FastingRepository repo;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    repo = FastingRepository(repos.keyValues);
  });

  tearDown(() => db.close());

  final day = DateTime(2026, 11, 16);

  group('the repository', () {
    test('a fresh install holds nothing and reads the defaults', () async {
      expect(await repo.config(), const FastingConfig());
      expect(await repo.intentions(), isEmpty);
      expect(await repo.log(), isEmpty);
    });

    test('the config round-trips, and the Hijri shift is NOT stored here (it is the prayer settings\')', () async {
      const config = FastingConfig(hijriOffset: 1, shawwalStartDay: 4, disabled: {FastKind.monday, FastKind.shabanMore});
      await repo.saveConfig(config);
      final back = await repo.config();
      expect(back.shawwalStartDay, 4);
      expect(back.disabled, {FastKind.monday, FastKind.shabanMore});
      expect(back.hijriOffset, 0, reason: 'one setting, never two');
      expect((await repos.keyValues.getJson(FastingRepository.configKey) as Map)['hijriOffset'], 0);
    });

    test('an intention is one record per day: a second answer replaces, the same one writes nothing', () async {
      expect(await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.yes)), isNull);
      // A double tap: same answer, no new row and no change.
      final before = await repos.keyValues.getJson(FastingRepository.intentionsKey);
      final again = await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.yes));
      expect(again, FastIntention(day: day, choice: FastIntentionChoice.yes));
      expect(await repos.keyValues.getJson(FastingRepository.intentionsKey), before);
      expect(await repo.intentions(), hasLength(1));
      // «لأ» afterwards replaces «ناوي»: still one record for the day.
      await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.no));
      final all = await repo.intentions();
      expect(all, hasLength(1));
      expect(all.single.choice, FastIntentionChoice.no);
      // Another day is another record.
      await repo.setIntention(FastIntention(day: DateTime(2026, 11, 19), choice: FastIntentionChoice.yes));
      expect(await repo.intentions(), hasLength(2));
      await repo.removeIntention(day);
      expect((await repo.intentions()).single.day, DateTime(2026, 11, 19));
    });

    test('old answers are dropped when a new one is written (a year is plenty)', () async {
      await repo.setIntention(FastIntention(day: DateTime(2025, 1, 6), choice: FastIntentionChoice.yes));
      await repo.setIntention(FastIntention(day: DateTime(2026, 11, 16), choice: FastIntentionChoice.yes));
      expect((await repo.intentions()).map((i) => i.day), [DateTime(2026, 11, 16)]);
    });

    test('the log is one entry per day; the last write wins; removing returns the entry', () async {
      await repo.setLogEntry(FastLogEntry(day: day, fasted: true, source: FastLogSource.manual, kind: FastKind.monday));
      await repo.setLogEntry(FastLogEntry(day: day, fasted: true, source: FastLogSource.reminded, kind: FastKind.monday));
      final log = await repo.log();
      expect(log, hasLength(1));
      expect(log.single.source, FastLogSource.reminded);
      final removed = await repo.removeLogEntry(day);
      expect(removed?.day, day);
      expect(await repo.log(), isEmpty);
      expect(await repo.removeLogEntry(day), isNull);
    });

    test('streams follow the writes and stay quiet when nothing changed', () async {
      final seen = <int>[];
      final sub = repo.watchIntentions().listen((l) => seen.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.yes));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.yes));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      expect(seen, [0, 1]);
    });

    test('a damaged or foreign value reads as empty, never as a crash', () async {
      await repos.keyValues.setJson(FastingRepository.intentionsKey, 'not a list');
      await repos.keyValues.setJson(FastingRepository.logKey, [
        {'day': 'nope'},
        {'day': '2026-11-16', 'fasted': true, 'kind': 'monday', 'source': 'manual'},
        42,
      ]);
      await repos.keyValues.setJson(FastingRepository.configKey, [1, 2]);
      expect(await repo.intentions(), isEmpty);
      expect((await repo.log()).single.day, day);
      expect(await repo.config(), const FastingConfig());
    });
  });

  group('the service: every write comes back with an undo', () {
    late ProviderContainer container;
    late FastingService service;

    setUp(() {
      container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      service = container.read(fastingServiceProvider);
    });

    test('«ناوي» then undo: the day is empty again; after an earlier answer, undo restores that one', () async {
      final undo = await service.answer(day, FastIntentionChoice.yes);
      expect((await repo.intentions()).single.intends, isTrue);
      await undo();
      expect(await repo.intentions(), isEmpty);

      await service.answer(day, FastIntentionChoice.no);
      final undo2 = await service.answer(day, FastIntentionChoice.yes);
      await undo2();
      expect((await repo.intentions()).single.choice, FastIntentionChoice.no);
    });

    test('logging today by hand carries the kind the rules gave it; undo and re-log; remove with undo', () async {
      final monday = DateTime(2026, 11, 16); // a Monday
      expect(monday.weekday, DateTime.monday);
      final undo = await service.logFasted(monday);
      final entry = (await repo.log()).single;
      expect(entry.fasted, isTrue);
      expect(entry.source, FastLogSource.manual);
      expect(entry.kind, isNotNull, reason: 'the rules know a Monday');
      await undo();
      expect(await repo.log(), isEmpty);

      await service.logFasted(monday);
      final undoRemove = await service.removeLog(monday);
      expect(await repo.log(), isEmpty);
      await undoRemove();
      expect(await repo.log(), hasLength(1));
    });

    test('a day with no rule is logged without a kind (he can fast any day)', () async {
      var free = DateTime(2026, 11, 17); // a Tuesday: step by weeks to one that is not a white day
      while (FastingRules.reminderOn(free, const FastingConfig()) != null) {
        free = DateTime(free.year, free.month, free.day + 7);
      }
      await service.logFasted(free);
      expect((await repo.log()).single.kind, isNull);
    });

    test('config changes undo to the old config', () async {
      final undo = await service.changeConfig((c) => FastKindGroup.weekly.set(c, false));
      expect((await repo.config()).isEnabled(FastKind.monday), isFalse);
      expect((await repo.config()).isEnabled(FastKind.thursday), isFalse);
      expect((await repo.config()).isEnabled(FastKind.whiteDay), isTrue);
      await undo();
      expect(await repo.config(), const FastingConfig());
    });

    test('the Hijri shift is the PRAYER settings\' own, and undo puts it back', () async {
      final undo = await service.setHijriShift(1);
      expect(container.read(fastingConfigProvider).hijriOffset, 0, reason: 'the stream has not emitted yet');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect((await repos.keyValues.getJson('prayer.settings') as Map)['hijriOffsetDays'], 1);
      container.listen(fastingConfigProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(container.read(fastingConfigProvider).hijriOffset, 1);
      await undo();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect((await repos.keyValues.getJson('prayer.settings') as Map)['hijriOffsetDays'], 0);
    });
  });

  group('backup and restore', () {
    test('key_values are in the snapshot, and his config, answers and log survive a real backup and restore', () async {
      await repo.saveConfig(const FastingConfig(shawwalStartDay: 5, disabled: {FastKind.arafah}));
      await repo.setIntention(FastIntention(day: day, choice: FastIntentionChoice.yes));
      await repo.setLogEntry(FastLogEntry(day: day, fasted: true, source: FastLogSource.manual, kind: FastKind.monday));

      final snapshot = await exportSnapshot(db, exportedAt: DateTime.utc(2026, 11, 10, 17));
      final rows = (snapshot['tables']! as Map)['key_values'] as List;
      final keys = [for (final r in rows) (r as Map)['key']];
      expect(keys, containsAll([FastingRepository.configKey, FastingRepository.intentionsKey, FastingRepository.logKey]));

      final bytes = utf8.encode(jsonEncode(snapshot));
      final (sealed, key) = await _codec.seal(
        bytes,
        'كلمة سر',
        createdAt: DateTime.utc(2026, 11, 10, 17),
        schemaVersion: db.schemaVersion,
      );
      key.destroy();
      final opened = await _codec.open(sealed, 'كلمة سر');
      final restoredJson = jsonDecode(utf8.decode(opened.json)) as Map<String, Object?>;

      final target = await openInMemoryMadarDatabase();
      addTearDown(target.close);
      await restoreSnapshot(target, restoredJson);
      final restored = FastingRepository(Repositories(target).keyValues);

      final config = await restored.config();
      expect(config.shawwalStartDay, 5);
      expect(config.disabled, {FastKind.arafah});
      expect((await restored.intentions()).single, FastIntention(day: day, choice: FastIntentionChoice.yes));
      final entry = (await restored.log()).single;
      expect(entry.day, day);
      expect(entry.kind, FastKind.monday);
    });
  });
}
