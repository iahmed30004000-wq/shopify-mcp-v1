import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New random primary key (UUID v4).
String newId() => _uuid.v4();

/// Common columns for every user-owned record: a UUID primary key and
/// creation / modification timestamps.
mixin Entity on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Records the user can reorder with drag handles.
mixin Ordered on Table {
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// JSON object column.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(fromDb);
    return decoded is Map ? decoded.cast<String, Object?>() : <String, Object?>{};
  }

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}

/// JSON array column (arbitrary JSON values).
class JsonListConverter extends TypeConverter<List<Object?>, String> {
  const JsonListConverter();

  @override
  List<Object?> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <Object?>[];
    final decoded = jsonDecode(fromDb);
    return decoded is List ? decoded.cast<Object?>() : <Object?>[];
  }

  @override
  String toSql(List<Object?> value) => jsonEncode(value);
}

/// List of strings stored as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <String>[];
    final decoded = jsonDecode(fromDb);
    return decoded is List ? decoded.map((e) => '$e').toList() : <String>[];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// List of ints stored as a JSON array (e.g. weekdays 1..7).
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <int>[];
    final decoded = jsonDecode(fromDb);
    return decoded is List
        ? decoded.map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0).toList()
        : <int>[];
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);
}
