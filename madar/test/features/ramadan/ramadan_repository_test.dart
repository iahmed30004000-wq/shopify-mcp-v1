// «رمضان»'s records in `key_values`: no schema change, one entry per night,
// the khatmah and the supplication slot round-tripping, every write undoable,
// a damaged value read as empty - and the lot riding a real encrypted-backup
// round trip.
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
import 'package:madar/features/ramadan/ramadan.dart';

const _fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const _codec = MadarBackupCodec(kdf: _fastKdf, useIsolate: false);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late RamadanRepository repo;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    repo = RamadanRepository(repos.keyValues);
  });

  tearDown(() => db.close());

  final span = const RamadanCalendar().spanOfYear(1448);

  group('a fresh install', () {
    test('holds nothing and reads the defaults', () async {
      expect(await repo.config(), const RamadanConfig());
      expect((await repo.logBook()).years, isEmpty);
      expect(await repo.khatmahs(), isEmpty);
      expect(await repo.supplication(), isNull);
      expect(await repo.lastSeen(), isNull);
      for (final k in [
        RamadanRepository.configKey,
        RamadanRepository.logKey,
        RamadanRepository.khatmahKey,
        RamadanRepository.supplicationKey,
        RamadanRepository.lastSeenKey,
      ]) {
        expect(await repos.keyValues.contains(k), isFalse, reason: k);
      }
    });

    test('a damaged value reads as nothing stored, never a crash', () async {
      for (final k in [RamadanRepository.configKey, RamadanRepository.logKey, RamadanRepository.khatmahKey, RamadanRepository.supplicationKey]) {
        await repos.keyValues.setJson(k, 'garbage');
      }
      await repos.keyValues.setJson(RamadanRepository.khatmahKey, [1, 'x', {'hijriYear': 'no'}]);
      expect(await repo.config(), const RamadanConfig());
      expect((await repo.logBook()).years, isEmpty);
      expect(await repo.khatmahs(), isEmpty);
      expect(await repo.supplication(), isNull);
    });
  });

  group('the Taraweeh log', () {
    test('a night is one entry: the same write twice leaves one row and no change', () async {
      expect(await repo.setTaraweeh(1448, 5, const TaraweehEntry(night: 5)), isNull);
      final before = await repos.keyValues.getJson(RamadanRepository.logKey);
      final again = await repo.setTaraweeh(1448, 5, const TaraweehEntry(night: 5));
      expect(again, const TaraweehEntry(night: 5));
      expect(await repos.keyValues.getJson(RamadanRepository.logKey), before);
      expect((await repo.logBook()).of(1448)!.taraweeh.entries, hasLength(1));
    });

    test('undo puts back exactly what the night held (nothing, then the old entry)', () async {
      final previous = await repo.setTaraweeh(1448, 7, const TaraweehEntry(night: 7, rakaat: 8));
      expect(previous, isNull);
      final before = await repo.setTaraweeh(1448, 7, const TaraweehEntry(night: 7, rakaat: 20, note: 'x'));
      expect(before, const TaraweehEntry(night: 7, rakaat: 8));
      await repo.setTaraweeh(1448, 7, before);
      expect((await repo.logBook()).of(1448)!.taraweeh.entryOf(7), const TaraweehEntry(night: 7, rakaat: 8));
      await repo.setTaraweeh(1448, 7, null);
      expect((await repo.logBook()).of(1448)!.taraweeh.entryOf(7), isNull);
    });

    test('«صلّيت» from the notification: done once; a second press writes nothing; a night with a count keeps it', () async {
      expect(await repo.markTaraweehDone(1448, 12), isTrue);
      final stored = await repos.keyValues.getJson(RamadanRepository.logKey);
      expect(await repo.markTaraweehDone(1448, 12), isFalse);
      expect(await repos.keyValues.getJson(RamadanRepository.logKey), stored);
      await repo.setTaraweeh(1448, 13, const TaraweehEntry(night: 13, rakaat: 20));
      expect(await repo.markTaraweehDone(1448, 13), isFalse, reason: 'already done');
      expect((await repo.logBook()).of(1448)!.taraweeh.entryOf(13)!.rakaat, 20);
      // A night he had only written a note on becomes done and keeps the note.
      await repo.setTaraweeh(1448, 14, const TaraweehEntry(night: 14, done: false, note: 'late'));
      expect(await repo.markTaraweehDone(1448, 14), isTrue);
      final e = (await repo.logBook()).of(1448)!.taraweeh.entryOf(14)!;
      expect((e.done, e.note), (true, 'late'));
    });

    test('two years coexist side by side and compare', () async {
      await repo.setTaraweeh(1447, 1, const TaraweehEntry(night: 1));
      await repo.setTaraweeh(1447, 2, const TaraweehEntry(night: 2, rakaat: 8));
      await repo.setTaraweeh(1448, 1, const TaraweehEntry(night: 1));
      await repo.setTaraweeh(1448, 3, const TaraweehEntry(night: 3));
      final book = await repo.logBook();
      expect(book.years, [1448, 1447]);
      final cmp = RamadanComparison.compare(book.of(1448)!, book.previousOf(1448)!);
      expect(cmp.thisYear.nightsPrayed, 2);
      expect(cmp.lastYear.nightsPrayed, 2);
      expect(cmp.lastYear.rakaat, 8);
      expect(cmp.nights[0].difference, NightDifference.both);
      expect(cmp.nights[1].difference, NightDifference.onlyLastYear);
      expect(cmp.nights[2].difference, NightDifference.onlyThisYear);
    });
  });

  group('the khatmah', () {
    test('round trips, per year, and the pages read follow into the year\'s log in the same write', () async {
      final base = KhatmahRecord.defaultFor(span);
      expect(base.plan.days, 29, reason: 'a 29-day month: the plan never outlasts it');
      final read = base.copyWith(progress: base.progress.markReadThrough(0, 21, totalPages: 604));
      expect(await repo.setKhatmah(read), isNull);
      final back = (await repo.khatmahs())[1448]!;
      expect(back, read);
      expect(back.progress.frontier, 21);
      expect((await repo.logBook()).of(1448)!.pagesRead, 21);
      // Undo: the year holds nothing again, and the log's pages go back to zero.
      await repo.restoreKhatmah(1448, null);
      expect(await repo.khatmahs(), isEmpty);
      expect((await repo.logBook()).of(1448)?.pagesRead ?? 0, 0);
    });

    test('the ceiling edit is stored with the plan; the previous record comes back for undo', () async {
      final base = KhatmahRecord.defaultFor(span);
      await repo.setKhatmah(base.copyWith(plan: base.plan.copyWith(ceilingPages: 25)));
      final previous = await repo.setKhatmah(base.copyWith(plan: base.plan.copyWith(ceilingPages: 15)));
      expect(previous!.plan.ceilingPages, 25);
      await repo.restoreKhatmah(1448, previous);
      expect((await repo.khatmahs())[1448]!.plan.ceilingPages, 25);
    });
  });

  group('the supplication slot', () {
    test('his text, source and grading round trip exactly as typed; empty text is no supplication', () async {
      const mine = QadrSupplication(text: 'نصّه كما كتبه هو', source: 'مصدره عنده', grading: 'درجته عنده');
      expect(await repo.saveSupplication(mine), isNull);
      expect(await repo.supplication(), mine);
      const edited = QadrSupplication(text: 'نص جديد');
      expect(await repo.saveSupplication(edited), mine, reason: 'the old one comes back for undo');
      expect((await repo.supplication())!.hasSource, isFalse);
      expect(await repo.saveSupplication(null), edited);
      expect(await repo.supplication(), isNull);
      expect(await repos.keyValues.contains(RamadanRepository.supplicationKey), isFalse);
      expect(QadrSupplication.fromJson({'text': '   ', 'source': 'x'}), isNull);
    });
  });

  group('the last-seen day and the config', () {
    test('the config and the last-seen day round trip', () async {
      const c = RamadanConfig(atmosphere: false, iftarLeadMinutes: 20);
      await repo.saveConfig(c);
      expect(await repo.config(), c);
      await repo.setLastSeen(DateTime(2027, 2, 7));
      expect(await repo.lastSeen(), DateTime(2027, 2, 7));
    });
  });

  group('providers read the same rows', () {
    test('the config provider follows the stored row', () async {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      container.listen(ramadanConfigProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(container.read(ramadanConfigProvider), const RamadanConfig());
      await repo.saveConfig(const RamadanConfig(suhoorLeadMinutes: 60));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(container.read(ramadanConfigProvider).suhoorLeadMinutes, 60);
    });
  });

  group('backup and restore', () {
    test('key_values are in the snapshot, and everything of Ramadan survives a real backup and restore', () async {
      await repo.saveConfig(const RamadanConfig(atmosphere: false, iftarLeadMinutes: 25));
      await repo.setTaraweeh(1447, 4, const TaraweehEntry(night: 4, rakaat: 8));
      await repo.setTaraweeh(1448, 6, const TaraweehEntry(night: 6, note: 'ليلة'));
      final base = KhatmahRecord.defaultFor(span);
      await repo.setKhatmah(base.copyWith(progress: base.progress.markReadThrough(0, 21, totalPages: 604)));
      await repo.saveSupplication(const QadrSupplication(text: 'x', source: 'y', grading: 'z'));

      final snapshot = await exportSnapshot(db, exportedAt: DateTime.utc(2026, 11, 10, 17));
      final rows = (snapshot['tables']! as Map)['key_values'] as List;
      final keys = [for (final r in rows) (r as Map)['key']];
      expect(
        keys,
        containsAll([
          RamadanRepository.configKey,
          RamadanRepository.logKey,
          RamadanRepository.khatmahKey,
          RamadanRepository.supplicationKey,
        ]),
      );

      final bytes = utf8.encode(jsonEncode(snapshot));
      final (sealed, key) = await _codec.seal(bytes, 'كلمة سر', createdAt: DateTime.utc(2026, 11, 10, 17), schemaVersion: db.schemaVersion);
      key.destroy();
      final opened = await _codec.open(sealed, 'كلمة سر');
      final restoredJson = jsonDecode(utf8.decode(opened.json)) as Map<String, Object?>;

      final target = await openInMemoryMadarDatabase();
      addTearDown(target.close);
      await restoreSnapshot(target, restoredJson);
      final restored = RamadanRepository(Repositories(target).keyValues);

      expect(await restored.config(), const RamadanConfig(atmosphere: false, iftarLeadMinutes: 25));
      final book = await restored.logBook();
      expect(book.years, [1448, 1447]);
      expect(book.of(1447)!.taraweeh.entryOf(4)!.rakaat, 8);
      expect(book.of(1448)!.taraweeh.entryOf(6)!.note, 'ليلة');
      expect(book.of(1448)!.pagesRead, 21);
      expect((await restored.khatmahs())[1448]!.progress.frontier, 21);
      expect(await restored.supplication(), const QadrSupplication(text: 'x', source: 'y', grading: 'z'));
    });
  });
}
