import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database.dart';

/// A typed key in the encrypted key/value store: its name plus how its value
/// maps to and from JSON.
@immutable
class KvKey<T> {
  const KvKey(this.name, {required this.decode, required this.encode});

  /// Stored as a JSON string.
  static KvKey<String> string(String name) => KvKey<String>(name, decode: (j) => j as String, encode: (v) => v);

  /// Stored as a JSON integer.
  static KvKey<int> integer(String name) => KvKey<int>(name, decode: (j) => (j as num).toInt(), encode: (v) => v);

  /// Stored as a JSON number.
  static KvKey<double> number(String name) =>
      KvKey<double>(name, decode: (j) => (j as num).toDouble(), encode: (v) => v);

  /// Stored as a JSON boolean.
  static KvKey<bool> boolean(String name) => KvKey<bool>(name, decode: (j) => j as bool, encode: (v) => v);

  /// Stored as a JSON object.
  static KvKey<Map<String, Object?>> map(String name) =>
      KvKey<Map<String, Object?>>(name, decode: (j) => (j as Map).cast<String, Object?>(), encode: (v) => v);

  /// Stored as whatever JSON [toJson] produces.
  static KvKey<V> json<V>(
    String name, {
    required V Function(Object? json) fromJson,
    required Object? Function(V) toJson,
  }) => KvKey<V>(name, decode: fromJson, encode: toJson);

  /// Namespaced key, e.g. `prayer.config`, `location`.
  final String name;
  final T Function(Object? json) decode;
  final Object? Function(T value) encode;

  /// Encodes [value] for storage. Tolerates an `int` for a `double` key (Dart
  /// infers `set(numberKey, 4)` as `num`); any other mismatch is a TypeError.
  Object? encodeValue(Object? value) {
    final v = value is int && 0.0 is T && value is! T ? value.toDouble() : value;
    return encode(v as T);
  }

  @override
  bool operator ==(Object other) => other is KvKey<T> && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'KvKey<$T>($name)';
}

/// Encrypted key/value settings (location, prayer config, fasting config …).
class KeyValueRepository {
  KeyValueRepository(this.db);

  final MadarDatabase db;

  /// Decoded value for [key]; null when absent or when the stored JSON no
  /// longer fits the key's type.
  Future<T?> get<T>(KvKey<T> key) async => _decode(key, await _row(key.name).getSingleOrNull());

  /// Live value for [key] (see [get]); emits only on change.
  Stream<T?> watch<T>(KvKey<T> key) => _row(key.name).watchSingleOrNull().map((row) => _decode(key, row)).distinct();

  /// Stores [value] under [key].
  Future<void> set<T>(KvKey<T> key, T value) => setJson(key.name, key.encodeValue(value));

  /// Raw JSON value (null when absent).
  Future<Object?> getJson(String key) async {
    final row = await _row(key).getSingleOrNull();
    return row == null ? null : jsonDecode(row.value);
  }

  /// Live raw JSON value.
  Stream<Object?> watchJson(String key) =>
      _row(key).watchSingleOrNull().map((row) => row == null ? null : jsonDecode(row.value));

  /// Stores any JSON-encodable [value].
  Future<void> setJson(String key, Object? value) {
    return db
        .into(db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion.insert(key: key, value: jsonEncode(value), updatedAt: Value(DateTime.now())),
        );
  }

  /// Whether [key] is present.
  Future<bool> contains(String key) async => await _row(key).getSingleOrNull() != null;

  /// Removes [key].
  Future<void> remove(String key) => (db.delete(db.keyValues)..where((t) => t.key.equals(key))).go();

  SimpleSelectStatement<$KeyValuesTable, KeyValueRow> _row(String key) =>
      db.select(db.keyValues)..where((t) => t.key.equals(key));

  T? _decode<T>(KvKey<T> key, KeyValueRow? row) {
    if (row == null) return null;
    try {
      return key.decode(jsonDecode(row.value));
    } on Object catch (e) {
      debugPrint('KeyValueRepository: cannot decode ${key.name}: $e');
      return null;
    }
  }
}
