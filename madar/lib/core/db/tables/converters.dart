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

/// Calendar-day columns: a task's day, a birthday, a due date, the day of a
/// transaction or lab reading …
///
/// Drift stores a *local* `DateTime` together with its UTC offset and turns
/// it back into the reader's *current* zone, so a local midnight written in
/// Amman (UTC+3) reads back as 22:00 of the previous day in London. A day
/// must not move when the device changes zone, so these columns are stored
/// zone-free: as **12:00 UTC of the calendar day** (`2026-09-01T12:00:00.000Z`)
/// and read back as local midnight of that same day (`DateTime(2026, 9, 1)`),
/// whatever zone the device is in now. Any time of day given is dropped.
///
/// Noon rather than midnight keeps the stored instant inside the local
/// calendar day for every offset from UTC−11:59 to UTC+11:59, so range
/// queries with local-midnight bounds (`julianday(date) >= julianday(start)`)
/// and raw reads that bypass this converter still land on the right day.
/// New day-range queries should prefer [CalendarDayConverter.startOf] bounds.
class CalendarDayConverter extends TypeConverter<DateTime, DateTime> {
  const CalendarDayConverter();

  @override
  DateTime fromSql(DateTime fromDb) => DateTime(fromDb.year, fromDb.month, fromDb.day);

  @override
  DateTime toSql(DateTime value) => DateTime.utc(value.year, value.month, value.day, 12);

  /// The stored instant of [day]'s calendar day (12:00 UTC).
  static DateTime stored(DateTime day) => DateTime.utc(day.year, day.month, day.day, 12);

  /// A zone-free lower bound for a range starting on [day]'s calendar day
  /// (00:00 UTC): `stored >= startOf(first) & stored < startOf(afterLast)`.
  static DateTime startOf(DateTime day) => DateTime.utc(day.year, day.month, day.day);
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
