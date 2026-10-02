import 'package:drift/drift.dart';

import 'database.dart';
import 'db_errors.dart';

/// Marker stored in every snapshot.
const madarSnapshotFormat = 'madar.snapshot';

/// Version of the snapshot envelope (not of the schema).
const madarSnapshotFormatVersion = 1;

/// Exports every table as JSON-friendly data:
///
/// ```json
/// {
///   "format": "madar.snapshot", "formatVersion": 1,
///   "schemaVersion": 1, "exportedAt": "2026-09-27T08:00:00.000Z",
///   "tables": {"tasks": [{"id": "…", "created_at": "…", "window": "fajr", …}], …}
/// }
/// ```
///
/// Rows hold the raw SQL values keyed by SQL column name, which makes the
/// round trip lossless by construction: enums are their names, JSON columns
/// their JSON text, dates the ISO-8601 text drift stored (offset included),
/// booleans 0/1, and nulls stay null. Rows are in insertion (rowid) order.
///
/// The result is plain data – pass it to `jsonEncode`. It is NOT encrypted;
/// whoever writes it to disk or shares it must protect it.
Future<Map<String, Object?>> exportSnapshot(MadarDatabase db, {DateTime? exportedAt}) async {
  return db.transaction(() async {
    final tables = <String, Object?>{};
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final rows = await db.customSelect('SELECT * FROM ${_q(name)} ORDER BY rowid', readsFrom: {table}).get();
      tables[name] = [for (final row in rows) _jsonRow(row.data, name)];
    }
    return <String, Object?>{
      'format': madarSnapshotFormat,
      'formatVersion': madarSnapshotFormatVersion,
      'schemaVersion': db.schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'tables': tables,
    };
  });
}

/// Row counts per table of a snapshot (for a "restore 120 tasks, …" preview).
/// Throws [SnapshotException] when [snapshot] is not a Madar snapshot.
Map<String, int> snapshotRowCounts(Map<String, Object?> snapshot) {
  final tables = _tablesOf(snapshot);
  return {
    for (final MapEntry(:key, :value) in tables.entries)
      if (value is List) key: value.length,
  };
}

/// Replaces ALL data with [snapshot] in one transaction.
///
/// Validates the envelope, schema version, table and column names and value
/// types first, and reads every restored table back through its typed row
/// class (enum names, JSON text, dates) before committing. Snapshots from an older schema are accepted (missing columns
/// take their defaults, missing tables end up empty); newer ones are refused.
/// Any failure – including SQLite constraint violations – rolls everything
/// back and throws [SnapshotException]; the current data is then untouched.
Future<void> restoreSnapshot(MadarDatabase db, Map<String, Object?> snapshot) async {
  final plan = _plan(db, snapshot);
  try {
    await db.transaction(() async {
      await db.customStatement('PRAGMA defer_foreign_keys = ON');
      await db.batch((b) {
        for (final table in db.allTables) {
          b.deleteAll(table);
        }
        for (final (table, statements) in plan) {
          for (final (sql, args) in statements) {
            b.customStatement(sql, args, [TableUpdate.onTable(table, kind: UpdateKind.insert)]);
          }
        }
      });
      // SQLite accepts any text in enum / JSON / date columns; make sure the
      // app can read every restored row back before the old data is gone.
      for (final (table, _) in plan) {
        try {
          await db.select(table).get();
        } catch (e) {
          throw SnapshotException(
            SnapshotProblem.invalidValue,
            'Table "${table.actualTableName}" holds values the app cannot read',
            unwrapDatabaseError(e),
          );
        }
      }
    });
  } on SnapshotException {
    rethrow;
  } catch (e) {
    throw SnapshotException(SnapshotProblem.rejected, 'The database rejected the snapshot', unwrapDatabaseError(e));
  }
}

typedef _Statement = (String sql, List<Object?> args);

List<(TableInfo, List<_Statement>)> _plan(MadarDatabase db, Map<String, Object?> snapshot) {
  if (snapshot['format'] != madarSnapshotFormat) {
    throw const SnapshotException(SnapshotProblem.notASnapshot, 'Missing "format": "$madarSnapshotFormat"');
  }
  final version = snapshot['schemaVersion'];
  if (version is! int || version < 1) {
    throw const SnapshotException(SnapshotProblem.notASnapshot, 'Missing or invalid "schemaVersion"');
  }
  if (version > db.schemaVersion) {
    throw SnapshotException(
      SnapshotProblem.newerSchema,
      'Snapshot schema $version is newer than this app (${db.schemaVersion})',
    );
  }
  final tables = _tablesOf(snapshot);
  final byName = {for (final t in db.allTables) t.actualTableName: t};
  final unknown = tables.keys.where((k) => !byName.containsKey(k)).toList();
  if (unknown.isNotEmpty) {
    throw SnapshotException(SnapshotProblem.unknownTable, 'Unknown tables: ${unknown.join(', ')}');
  }

  final plan = <(TableInfo, List<_Statement>)>[];
  for (final MapEntry(key: name, value: rawRows) in tables.entries) {
    final table = byName[name]!;
    if (rawRows is! List) {
      throw SnapshotException(SnapshotProblem.notASnapshot, 'Table "$name" is not a list of rows');
    }
    final columns = table.columnsByName;
    final statements = <_Statement>[];
    for (final rawRow in rawRows) {
      if (rawRow is! Map) {
        throw SnapshotException(SnapshotProblem.notASnapshot, 'A row of "$name" is not an object');
      }
      final names = <String>[];
      final args = <Object?>[];
      for (final MapEntry(:key, :value) in rawRow.entries) {
        if (key is! String || !columns.containsKey(key)) {
          throw SnapshotException(SnapshotProblem.unknownColumn, 'Unknown column "$name.$key"');
        }
        names.add(key);
        args.add(_sqlValue(value, '$name.$key'));
      }
      if (names.isEmpty) continue;
      final placeholders = List.filled(names.length, '?').join(', ');
      statements.add(('INSERT INTO ${_q(name)} (${names.map(_q).join(', ')}) VALUES ($placeholders)', args));
    }
    plan.add((table, statements));
  }
  return plan;
}

Map<String, Object?> _tablesOf(Map<String, Object?> snapshot) {
  final tables = snapshot['tables'];
  if (snapshot['format'] != madarSnapshotFormat || tables is! Map) {
    throw const SnapshotException(SnapshotProblem.notASnapshot, 'Not a Madar snapshot');
  }
  return tables.cast<String, Object?>();
}

/// Non-finite doubles cannot be JSON-encoded, so they are tagged.
const _realTag = r'$real';

Object? _jsonRow(Map<String, Object?> data, String table) {
  return {
    for (final MapEntry(:key, :value) in data.entries)
      key: switch (value) {
        null || String() || int() => value,
        double() when value.isFinite => value,
        double() => {_realTag: value.toString()},
        _ => throw StateError('Unsupported SQL value in $table.$key: ${value.runtimeType}'),
      },
  };
}

Object? _sqlValue(Object? value, String where) {
  return switch (value) {
    null || String() || int() || double() => value,
    bool() => value ? 1 : 0,
    {_realTag: final String text} when double.tryParse(text) != null => double.parse(text),
    _ => throw SnapshotException(SnapshotProblem.invalidValue, 'Invalid value for $where: $value'),
  };
}

String _q(String identifier) => '"${identifier.replaceAll('"', '""')}"';
