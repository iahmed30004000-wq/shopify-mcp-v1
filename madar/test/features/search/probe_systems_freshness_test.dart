// Probes (systems lens): freshness of the global search index – every
// insert / edit / delete shows up, a backup restore leaves nothing stale,
// the 60k cap, and "nothing is re-read while no search screen is open".
// The cap and background-read probes FAIL while the problem exists; the
// restore and custom-module tests pass and are kept as regression tests
// (neither case was covered before).
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';

final DateTime _now = DateTime(2026, 9, 30, 12);

MadarDatabase _db([QueryInterceptor? interceptor]) {
  QueryExecutor executor = NativeDatabase.memory();
  if (interceptor != null) executor = executor.interceptWith(interceptor);
  return MadarDatabase(DatabaseConnection(executor, closeStreamsSynchronously: true));
}

SearchEngine _engine(MadarDatabase db, {SearchWorkerFactory? worker}) => SearchEngine(
  db: db,
  registry: SearchRegistry(BuiltInSearchSources.all()),
  workerFactory: worker ?? () async => InlineSearchWorker(),
  clock: () => _now,
  debounce: const Duration(milliseconds: 20),
  context: () async => SearchLoadContext(
    repos: Repositories(db),
    l10n: lookupL10n(const Locale('en')),
    formatter: MadarFormatter(languageCode: 'en'),
  ),
);

List<String> _titles(SearchResults r) => [for (final h in r.hits) h.doc.title];

Future<void> _eventually(FutureOr<bool> Function() condition, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

/// Counts the SELECTs the database runs.
class _SelectCounter extends QueryInterceptor {
  final List<String> selects = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    selects.add(statement);
    return executor.runSelect(statement, args);
  }
}

void main() {
  group('backup restore replaces every table', () {
    late MadarDatabase db;
    late SearchEngine engine;
    late Map<String, Object?> backup;

    setUp(() async {
      // The backup: other records than the ones on the phone now.
      final other = _db();
      await Repositories(other).tasks.insert(TasksCompanion.insert(title: 'Restored errand'));
      backup = await exportSnapshot(other);
      await other.close();

      db = _db();
      await Repositories(db).tasks.insert(TasksCompanion.insert(title: 'Current errand'));
      engine = _engine(db);
      expect(_titles(await engine.search(const SearchRequest('errand'))), ['Current errand']);
    });

    tearDown(() async {
      await engine.dispose();
      await db.close();
    });

    test('with no search screen open: the next query sees only the restored data', () async {
      await restoreSnapshot(db, backup);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(_titles(await engine.search(const SearchRequest('errand'))), ['Restored errand']);
    });

    test('with the search screen open: results follow the restore', () async {
      final listening = engine.changes.listen((_) {});
      addTearDown(listening.cancel);
      await restoreSnapshot(db, backup);
      await _eventually(
        () async => _titles(await engine.search(const SearchRequest('errand'))).join() == 'Restored errand',
      );
    });
  });

  group('custom modules', () {
    late MadarDatabase db;
    late Repositories repos;
    late SearchEngine engine;
    late CustomModuleRow module;

    setUp(() async {
      db = _db();
      repos = Repositories(db);
      module = await repos.customModules.insert(
        CustomModulesCompanion.insert(
          name: 'Reading log',
          color: 0xFF4CC96B,
          fields: const Value([
            {'id': 'f1', 'label': 'Book', 'type': 'text'},
            {'id': 'f2', 'label': 'Pages', 'type': 'number'},
          ]),
        ),
      );
      await repos.customEntries.insert(
        CustomEntriesCompanion.insert(moduleId: module.id, entryValues: const Value({'f1': 'Dune', 'f2': 40})),
      );
      engine = _engine(db);
      await engine.warmUp();
    });

    tearDown(() async {
      await engine.dispose();
      await db.close();
    });

    Future<void> renameAndDelete() async {
      await repos.customModules.update(
        CustomModulesCompanion(
          id: Value(module.id),
          fields: const Value([
            {'id': 'f1', 'label': 'Book', 'type': 'text'},
            {'id': 'f2', 'label': 'Chapters', 'type': 'number'},
          ]),
        ),
      );
      await _eventually(() async {
        final r = await engine.search(const SearchRequest('chapters dune'));
        return !r.partial && r.hits.any((h) => h.doc.sourceId == 'custom_entries');
      });
      expect((await engine.search(const SearchRequest('pages dune'))).partial, isTrue);

      // Deleted the way the module screen does it (entries first).
      await repos.customEntries.deleteWhere((t) => t.moduleId.equals(module.id));
      await repos.customModules.delete(module.id);
      await _eventually(() async => (await engine.search(const SearchRequest('dune'))).hits.isEmpty);
      await _eventually(() async => (await engine.search(const SearchRequest('reading'))).hits.isEmpty);
    }

    test('field renamed, module deleted – search screen closed', renameAndDelete);

    test('field renamed, module deleted – search screen open', () async {
      final listening = engine.changes.listen((_) {});
      addTearDown(listening.cancel);
      await renameAndDelete();
    });
  });

  test('records dropped at the cap come back once the index has room again', () async {
    final db = _db();
    addTearDown(db.close);
    final repos = Repositories(db);
    // 105 dated tasks; a cap of 100 (the 60k cap, scaled down).
    await db.batch((b) {
      b.insertAll(db.tasks, [
        for (var i = 0; i < 105; i++)
          TasksCompanion.insert(
            id: Value('t$i'),
            title: 'errand number$i',
            date: Value(_now.subtract(Duration(days: 200 - i))), // t0 is the oldest
          ),
      ]);
    });
    final engine = _engine(
      db,
      worker: () async => InlineSearchWorker(SearchIndex(limits: const SearchIndexLimits(maxDocs: 100))),
    );
    addTearDown(engine.dispose);
    await engine.warmUp();
    expect((await engine.search(const SearchRequest('number0'))).hits, isEmpty); // dropped: expected at the cap

    // The user deletes the 60 newest tasks: the index now has plenty of room.
    await (db.delete(db.tasks)..where((t) => t.id.isIn([for (var i = 45; i < 105; i++) 't$i']))).go();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final stats = await engine.stats();
    expect(await repos.tasks.count(), 45);
    // Every task still in the database should be findable again.
    expect(stats.docs, 45, reason: 'index holds ${stats.docs} records for 45 tasks');
    expect(_titles(await engine.search(const SearchRequest('number0'))), ['errand number0']);
  });

  test('nothing is re-read while no search screen is open (planets edited)', () async {
    final counter = _SelectCounter();
    final db = _db(counter);
    addTearDown(db.close);
    final repos = Repositories(db);
    final planet = await repos.planets.insert(
      PlanetsCompanion.insert(
        key: 'garden',
        nameAr: 'الحديقة',
        nameEn: 'Garden',
        color: 0xFF00AA00,
        archetype: PlanetArchetype.values.first,
      ),
    );
    final engine = _engine(db);
    addTearDown(engine.dispose);
    await engine.warmUp(); // the search was used once, then closed
    counter.selects.clear();
    await repos.planets.update(planet.copyWith(weight: 2));
    await repos.tasks.insert(TasksCompanion.insert(title: 'background write'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final reads = counter.selects.where((s) => !s.contains('RETURNING') && !s.contains('MAX(')).toList();
    expect(reads, isEmpty, reason: 'read in the background: $reads');
  });
}
