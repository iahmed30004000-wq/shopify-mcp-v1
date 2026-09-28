import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/db_errors.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/snapshot.dart';

import 'fixtures.dart';

/// Every row of every table, typed (read through drift's data classes) and
/// normalised to comparable values (JSON columns become their JSON text,
/// enums their names, dates stay [DateTime]).
Future<Map<String, List<Map<String, Object?>>>> typedDump(MadarDatabase db) async {
  final out = <String, List<Map<String, Object?>>>{};
  for (final table in db.allTables) {
    final rows = await (db.select(table)..orderBy([(_) => OrderingTerm.asc(table.rowId)])).get();
    out[table.actualTableName] = [
      for (final row in rows)
        {
          for (final MapEntry(:key, :value) in (row as Insertable).toColumns(false).entries)
            key: (value as Variable).value,
        },
    ];
  }
  return out;
}

Map<String, Object?> withoutTimestamp(Map<String, Object?> snapshot) => Map.of(snapshot)..remove('exportedAt');

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase source;

  setUp(() async {
    source = await openInMemoryMadarDatabase();
    await populateAllTables(source);
  });

  tearDown(() => source.close());

  test('fixtures cover every table', () async {
    for (final table in source.allTables) {
      final count = await source.customSelect('SELECT count(*) AS c FROM "${table.actualTableName}"').getSingle();
      expect(count.read<int>('c'), greaterThan(0), reason: '${table.actualTableName} has no fixture rows');
    }
  });

  test('export → JSON → restore round-trips every table losslessly', () async {
    final exported = await exportSnapshot(source, exportedAt: DateTime.utc(2026, 9, 27));
    expect(exported['format'], madarSnapshotFormat);
    expect(exported['schemaVersion'], source.schemaVersion);
    expect(exported['exportedAt'], '2026-09-27T00:00:00.000Z');

    // Through real JSON text, as a backup file would be.
    final decoded = jsonDecode(jsonEncode(exported)) as Map<String, Object?>;

    // Restore into a database that already holds different (seeded) data.
    final target = await openInMemoryMadarDatabase();
    addTearDown(target.close);
    await target.into(target.tasks).insert(TasksCompanion.insert(title: 'to be replaced'));
    await restoreSnapshot(target, decoded);

    expect(await typedDump(target), await typedDump(source));
    final reExported = await exportSnapshot(target, exportedAt: DateTime.utc(2026, 9, 27));
    expect(reExported, exported);
    expect(await target.select(target.tasks).get(), hasLength(2));
  });

  test('typed values survive: enums, JSON, dates, nulls, unicode', () async {
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await restoreSnapshot(target, jsonDecode(jsonEncode(await exportSnapshot(source))) as Map<String, Object?>);

    final task = await (target.select(target.tasks)..where((t) => t.id.equals('task-full'))).getSingle();
    final original = await (source.select(source.tasks)..where((t) => t.id.equals('task-full'))).getSingle();
    expect(task.window, original.window);
    expect(task.recurrence, {
      'every': 'week',
      'weekdays': [5],
    });
    expect(task.date, original.date);
    // A calendar-day column: the day survives, the time of day is dropped.
    expect(task.date, DateTime(tLocal.year, tLocal.month, tLocal.day));
    expect(task.doneAt!.microsecond, tMicros.microsecond);
    expect(task.notes, original.notes);
    expect(task.title, 'مهمة كاملة');

    final sparse = await (target.select(target.tasks)..where((t) => t.title.equals('sparse'))).getSingle();
    expect(sparse.notes, isNull);
    expect(sparse.date, isNull);
    expect(sparse.recurrence, isNull);

    final planet = await (target.select(target.planets)..where((t) => t.key.equals('custom_1'))).getSingle();
    expect(planet.sources, {
      'tasks': 0.5,
      'nested': {
        'list': [1, 'two', null, true, 3.25],
      },
    });
    expect(planet.createdAt, tUtc);
    expect(planet.createdAt.isUtc, isTrue);

    final entry = await (target.select(target.customEntries)..where((t) => t.moduleId.equals('module-1'))).get();
    expect(entry.first.entryValues, {'f1': 12, 'f2': 'text', 'f3': null, 'f4': 1.5});
  });

  test('non-finite doubles are tagged and restored', () async {
    await (source.update(
      source.learningGoals,
    )..where((t) => t.id.equals('goal-1'))).write(const LearningGoalsCompanion(target: Value(double.infinity)));
    final json = jsonEncode(await exportSnapshot(source));
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await restoreSnapshot(target, jsonDecode(json) as Map<String, Object?>);
    final goal = await (target.select(target.learningGoals)..where((t) => t.id.equals('goal-1'))).getSingle();
    expect(goal.target, double.infinity);
  });

  test('snapshotRowCounts previews the content', () async {
    final counts = snapshotRowCounts(await exportSnapshot(source));
    expect(counts['planets'], 9); // 8 seeded + 1 fixture
    expect(counts['tasks'], 2);
    expect(counts.keys, containsAll(['currencies', 'key_values', 'custom_entries']));
  });

  group('invalid snapshots are refused and leave data untouched', () {
    late Map<String, Object?> good;
    late Map<String, List<Map<String, Object?>>> before;

    setUp(() async {
      good = jsonDecode(jsonEncode(await exportSnapshot(source))) as Map<String, Object?>;
      before = await typedDump(source);
    });

    Future<void> expectRefused(Map<String, Object?> snapshot, SnapshotProblem problem) async {
      await expectLater(
        restoreSnapshot(source, snapshot),
        throwsA(isA<SnapshotException>().having((e) => e.problem, 'problem', problem)),
      );
      expect(await typedDump(source), before);
    }

    Map<String, Object?> mutate(void Function(Map<String, dynamic> tables) change) {
      final copy = jsonDecode(jsonEncode(good)) as Map<String, dynamic>;
      change(copy['tables'] as Map<String, dynamic>);
      return copy;
    }

    test('not a snapshot', () async {
      await expectRefused({'hello': 'world'}, SnapshotProblem.notASnapshot);
      await expectRefused({...good, 'tables': 'nope'}, SnapshotProblem.notASnapshot);
      await expectRefused({...good, 'schemaVersion': 'x'}, SnapshotProblem.notASnapshot);
      expect(() => snapshotRowCounts({'format': 'other'}), throwsA(isA<SnapshotException>()));
    });

    test('newer schema', () async {
      await expectRefused({...good, 'schemaVersion': source.schemaVersion + 1}, SnapshotProblem.newerSchema);
    });

    test('unknown table / column', () async {
      await expectRefused(mutate((t) => t['secrets'] = []), SnapshotProblem.unknownTable);
      await expectRefused(
        mutate((t) => ((t['tasks'] as List).first as Map)['colour'] = 1),
        SnapshotProblem.unknownColumn,
      );
    });

    test('invalid value', () async {
      await expectRefused(
        mutate((t) => ((t['tasks'] as List).first as Map)['title'] = {'nested': true}),
        SnapshotProblem.invalidValue,
      );
    });

    test('bogus enum name', () async {
      await expectRefused(
        mutate((t) => ((t['tasks'] as List).first as Map)['window'] = 'bogus'),
        SnapshotProblem.invalidValue,
      );
    });

    test('invalid JSON text', () async {
      await expectRefused(
        mutate((t) => ((t['tasks'] as List).first as Map)['recurrence'] = '{'),
        SnapshotProblem.invalidValue,
      );
    });

    test('constraint violation rolls back the whole restore', () async {
      await expectRefused(mutate((t) => ((t['tasks'] as List).last as Map)['title'] = null), SnapshotProblem.rejected);
      await expectRefused(
        mutate((t) => (t['planets'] as List).add(Map.of((t['planets'] as List).first as Map))),
        SnapshotProblem.rejected,
      );
    });
  });

  test('older snapshots missing a table or column restore with defaults', () async {
    final snapshot = jsonDecode(jsonEncode(await exportSnapshot(source))) as Map<String, dynamic>;
    final tables = snapshot['tables'] as Map<String, dynamic>;
    tables.remove('water_logs');
    for (final row in (tables['tasks'] as List).cast<Map<String, dynamic>>()) {
      row.remove('priority');
    }
    final target = MadarDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await restoreSnapshot(target, snapshot);
    expect(await target.select(target.waterLogs).get(), isEmpty);
    final tasks = await target.select(target.tasks).get();
    expect(tasks.map((t) => t.priority), everyElement(0));
  });

  test('restore notifies watchers', () async {
    final target = await openInMemoryMadarDatabase();
    addTearDown(target.close);
    final emissions = <int>[];
    final sub = target.select(target.tasks).watch().listen((rows) => emissions.add(rows.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await restoreSnapshot(target, await exportSnapshot(source));
    await pumpEventQueue();
    expect(emissions.first, 0);
    expect(emissions.last, 2);
  });
}
