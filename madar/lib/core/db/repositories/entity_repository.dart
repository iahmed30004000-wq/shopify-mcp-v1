import 'dart:convert';

import 'package:drift/drift.dart';

import '../tables/converters.dart' show newId;

/// Generic CRUD + undo + ordering over any table that uses the `Entity` mixin
/// (text `id` primary key, `created_at`, `updated_at`) and optionally
/// `Ordered` (`sort_order`).
///
/// Ordering: rows are listed by `sort_order` (when present), then
/// `created_at` (compared as instants, so rows written in different time
/// zones still sort correctly), then insertion order. `sort_order` values are
/// global to the table, so relative order is preserved inside every filtered
/// view (a board column, a prayer window, a project …).
///
/// Column names given to [setColumn], [setColumns] and `duplicate(overrides:)`
/// may be the Dart getter name (`columnId`, `isTop3`) or the SQL name
/// (`column_id`). Values are Dart values of the column's type: enums for
/// `textEnum` columns, maps/lists for JSON columns, [DateTime], [bool] …
/// Enum names and raw JSON strings are also accepted for converted columns,
/// and loosely typed maps/lists (straight from `jsonDecode`) for JSON columns.
class EntityRepository<T extends Table, R extends DataClass> {
  EntityRepository(this.db, this.table)
    : _id = _required<String>(table, 'id'),
      _createdAt = _required<DateTime>(table, 'created_at'),
      _updatedAt = _required<DateTime>(table, 'updated_at'),
      _sortOrder = table.columnsByName['sort_order'] as GeneratedColumn<int>?;

  final GeneratedDatabase db;
  final TableInfo<T, R> table;

  final GeneratedColumn<String> _id;
  final GeneratedColumn<DateTime> _createdAt;
  final GeneratedColumn<DateTime> _updatedAt;
  final GeneratedColumn<int>? _sortOrder;

  /// SQL name of the table (e.g. `board_cards`), as used by `ownerTable` /
  /// `refTable` columns.
  String get tableName => table.actualTableName;

  /// Whether the table has the `Ordered` mixin.
  bool get isOrdered => _sortOrder != null;

  static GeneratedColumn<C> _required<C extends Object>(TableInfo<Table, Object?> table, String name) {
    final column = table.columnsByName[name];
    if (column is! GeneratedColumn<C>) {
      throw ArgumentError('${table.actualTableName} has no "$name" column; EntityRepository needs the Entity mixin');
    }
    return column;
  }

  // ------------------------------------------------------------------ reads

  /// Live, ordered list of rows, optionally filtered.
  Stream<List<R>> watchAll({Expression<bool> Function(T tbl)? where}) => _query(where).watch();

  /// Ordered list of rows, optionally filtered.
  Future<List<R>> getAll({Expression<bool> Function(T tbl)? where}) => _query(where).get();

  /// The row with [id], or null.
  Future<R?> byId(String id) => _byIdQuery(id).getSingleOrNull();

  /// Live view of the row with [id] (null once deleted).
  Stream<R?> watchById(String id) => _byIdQuery(id).watchSingleOrNull();

  /// Number of rows, optionally filtered.
  Future<int> count({Expression<bool> Function(T tbl)? where}) => table.count(where: where).getSingle();

  SimpleSelectStatement<T, R> _byIdQuery(String id) => db.select(table)..where((_) => _id.equals(id));

  SimpleSelectStatement<T, R> _query(Expression<bool> Function(T tbl)? where) {
    final sort = _sortOrder;
    final query = db.select(table);
    if (where != null) query.where(where);
    query.orderBy([
      if (sort != null) (_) => OrderingTerm.asc(sort),
      (_) => OrderingTerm.asc(_createdAt.julianday),
      (_) => OrderingTerm.asc(table.rowId),
    ]);
    return query;
  }

  // ----------------------------------------------------------------- writes

  /// Inserts a new row (usually a companion) and returns it. `id`,
  /// `created_at` and `updated_at` get their defaults when absent. On ordered
  /// tables the row is appended at the end (`sort_order = max + 1`), whatever
  /// the insertable says.
  Future<R> insert(Insertable<R> row) {
    return db.transaction(() async {
      final values = Map<String, Expression>.of(row.toColumns(true));
      if (_sortOrder != null) values['sort_order'] = Variable<int>(await _maxSortOrder() + 1);
      return db.into(table).insertReturning(RawValuesInsertable<R>(values));
    });
  }

  /// Writes [row] (a companion with `id` present, or a full data class) and
  /// bumps `updated_at`.
  ///
  /// Companions only write their present fields (`Value(null)` clears a
  /// column). For a data class every column is written except `created_at`
  /// and `sort_order`, so a stale copy can never undo a reorder – use
  /// [reorder] / [setColumn] for those. Missing rows are ignored.
  Future<void> update(Insertable<R> row) async {
    final values = Map<String, Expression>.of(row.toColumns(false));
    final id = _idOf(values);
    values.remove('id');
    values.remove('rowid');
    if (row is DataClass) {
      values
        ..remove(_createdAt.$name)
        ..remove('sort_order');
    }
    values[_updatedAt.$name] = Variable<DateTime>(DateTime.now());
    await (db.update(table)..where((_) => _id.equals(id))).write(RawValuesInsertable<R>(values));
  }

  /// Deletes the row with [id] and returns it for undo (null if absent).
  Future<R?> delete(String id) {
    return db.transaction(() async {
      final row = await byId(id);
      if (row == null) return null;
      await (db.delete(table)..where((_) => _id.equals(id))).go();
      return row;
    });
  }

  /// Deletes every row matching [where] and returns them (for undo of a
  /// cascade, e.g. a board and its cards).
  Future<List<R>> deleteWhere(Expression<bool> Function(T tbl) where) {
    return db.transaction(() async {
      final rows = await (db.select(table)..where(where)).get();
      if (rows.isNotEmpty) await (db.delete(table)..where(where)).go();
      return rows;
    });
  }

  /// Re-inserts a row returned by [delete] exactly as it was (same id,
  /// timestamps and position). Replaces a row with the same id.
  Future<void> restore(R row) {
    return db.into(table).insert(_exact(row), mode: InsertMode.insertOrReplace);
  }

  /// [restore] for many rows in one batch.
  Future<void> restoreAll(Iterable<R> rows) {
    return db.batch((b) => b.insertAll(table, [for (final r in rows) _exact(r)], mode: InsertMode.insertOrReplace));
  }

  /// Copies the row with [id]: new id and timestamps, placed right after the
  /// original (later rows shift down by one). [overrides] maps column names to
  /// new values, e.g. `{'title': 'Copy'}`; tables with unique columns (a
  /// planet's `key`) need an override for them. Throws [StateError] when the
  /// row does not exist.
  Future<R> duplicate(String id, {Map<String, Object?> overrides = const {}}) {
    return db.transaction(() async {
      final original = await byId(id);
      if (original == null) throw StateError('No $tableName row with id $id');
      final values = Map<String, Expression>.of((original as Insertable<R>).toColumns(false));
      final now = DateTime.now();
      values['id'] = Variable<String>(newId());
      values[_createdAt.$name] = Variable<DateTime>(now);
      values[_updatedAt.$name] = Variable<DateTime>(now);
      final sort = _sortOrder;
      if (sort != null) {
        final position = _variableValue(values['sort_order']) as int;
        await (db.update(table)..where((_) => sort.isBiggerThanValue(position))).write(
          RawValuesInsertable<R>({'sort_order': sort + const Constant(1)}),
        );
        values['sort_order'] = Variable<int>(position + 1);
      }
      overrides.forEach((name, value) {
        final column = columnNamed(name);
        values[column.$name] = encodeValue(column, value);
      });
      return db.into(table).insertReturning(RawValuesInsertable<R>(values));
    });
  }

  /// Persists a drag-and-drop order. [idsInOrder] are the rows of one view in
  /// their new order; they keep the set of `sort_order` slots they already
  /// occupied (made strictly increasing), so rows outside the view keep their
  /// relative position. Unknown ids are ignored. Does not bump `updated_at`.
  Future<void> reorder(List<String> idsInOrder) async {
    final sort = _sortOrder;
    if (sort == null) throw UnsupportedError('$tableName is not ordered');
    if (idsInOrder.isEmpty) return;
    await db.transaction(() async {
      final rows =
          await (db.selectOnly(table)
                ..addColumns([_id, sort])
                ..where(_id.isIn(idsInOrder)))
              .get();
      final current = {for (final r in rows) r.read(_id)!: r.read(sort)!};
      final ids = idsInOrder.toSet().where(current.containsKey).toList();
      final slots = current.values.toList()..sort();
      for (var i = 1; i < slots.length; i++) {
        if (slots[i] <= slots[i - 1]) slots[i] = slots[i - 1] + 1;
      }
      await db.batch((b) {
        for (var i = 0; i < ids.length; i++) {
          if (current[ids[i]] == slots[i]) continue;
          final id = ids[i];
          b.update(
            table,
            RawValuesInsertable<R>({'sort_order': Variable<int>(slots[i])}),
            where: (_) => _id.equals(id),
          );
        }
      });
    });
  }

  /// Sets one column (used by "Move": window, column, category, parent …)
  /// and bumps `updated_at`. With [moveToEnd] the row is also appended at the
  /// end of the order, so it lands last in its new list.
  Future<void> setColumn(String id, String columnName, Object? value, {bool moveToEnd = false}) {
    return setColumns(id, {columnName: value}, moveToEnd: moveToEnd);
  }

  /// Sets several columns at once (see [setColumn]).
  Future<void> setColumns(String id, Map<String, Object?> values, {bool moveToEnd = false}) {
    return db.transaction(() async {
      final data = <String, Expression>{};
      values.forEach((name, value) {
        final column = columnNamed(name);
        if (column.$name == 'id') throw ArgumentError.value(name, 'columnName', 'The id cannot be changed');
        data[column.$name] = encodeValue(column, value);
      });
      if (moveToEnd && _sortOrder != null) data['sort_order'] = Variable<int>(await _maxSortOrder() + 1);
      data[_updatedAt.$name] = Variable<DateTime>(DateTime.now());
      await (db.update(table)..where((_) => _id.equals(id))).write(RawValuesInsertable<R>(data));
    });
  }

  // ---------------------------------------------------------------- helpers

  /// Resolves a Dart getter name (`columnId`) or SQL name (`column_id`).
  GeneratedColumn columnNamed(String name) {
    final byName = table.columnsByName;
    final column = byName[name] ?? byName[snakeCase(name)];
    if (column == null) throw ArgumentError.value(name, 'columnName', 'Unknown column of $tableName');
    return column;
  }

  /// Converts a Dart value for [column] into a bound SQL variable, applying
  /// the column's type converter (enum → name, map/list → JSON).
  static Variable<Object> encodeValue(GeneratedColumn column, Object? value) {
    if (value == null) {
      if (!column.$nullable) {
        throw ArgumentError.value(value, column.$name, 'Column is not nullable');
      }
      return const Variable<Object>(null);
    }
    var sqlValue = value;
    if (column is GeneratedColumnWithTypeConverter) {
      final converter = column.converter as TypeConverter<Object?, Object?>;
      try {
        final converted = converter.toSql(value);
        if (converted != null) sqlValue = converted;
      } on TypeError {
        // Already in SQL form (an enum name or a JSON string), or a loosely
        // typed map/list for one of the JSON columns (all store JSON text).
        sqlValue = value is Map || value is List ? jsonEncode(value) : value;
      }
    }
    final type = column.type;
    if (type == DriftSqlType.double && sqlValue is int) sqlValue = sqlValue.toDouble();
    if (!_matches(type, sqlValue)) {
      throw ArgumentError.value(value, column.$name, 'Wrong type for a $type column');
    }
    return Variable<Object>(sqlValue);
  }

  static bool _matches(Object type, Object value) => switch (type) {
    DriftSqlType.bool => value is bool,
    DriftSqlType.string => value is String,
    DriftSqlType.int => value is int,
    DriftSqlType.bigInt => value is BigInt,
    DriftSqlType.double => value is double,
    DriftSqlType.dateTime => value is DateTime,
    DriftSqlType.blob => value is Uint8List,
    _ => true,
  };

  /// `isTop3` → `is_top3`, `medAId` → `med_a_id` (drift's naming).
  static String snakeCase(String name) {
    final out = StringBuffer();
    for (final char in name.split('')) {
      final lower = char.toLowerCase();
      if (char != lower) {
        if (out.isNotEmpty) out.write('_');
        out.write(lower);
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }

  RawValuesInsertable<R> _exact(R row) => RawValuesInsertable<R>((row as Insertable<R>).toColumns(false));

  Future<int> _maxSortOrder() async {
    final max = _sortOrder!.max();
    final row = await (db.selectOnly(table)..addColumns([max])).getSingle();
    return row.read(max) ?? -1;
  }

  String _idOf(Map<String, Expression> values) {
    final id = _variableValue(values['id']);
    if (id is! String) throw ArgumentError('update() needs the row id (companion `id: Value(...)`)');
    return id;
  }

  static Object? _variableValue(Expression? e) => switch (e) {
    Variable(:final value) => value,
    Constant(:final value) => value,
    _ => null,
  };
}
