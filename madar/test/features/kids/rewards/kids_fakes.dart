import 'package:madar/features/kids/rewards/data/rewards_store.dart';

/// Thrown by [MemoryKidsStore] when the "phone dies".
class PhoneDied implements Exception {
  @override
  String toString() => 'PhoneDied';
}

/// A key store in memory that can die after a number of writes, to test what a
/// dying battery leaves behind. [data] outlives a "restart" (a new store on
/// the same map).
class MemoryKidsStore implements KidsKeyStore {
  MemoryKidsStore([Map<String, Object?>? data]) : data = data ?? <String, Object?>{};

  final Map<String, Object?> data;

  /// Writes that still succeed; the next one throws [PhoneDied] without
  /// writing. Null: never dies.
  int? writesBeforeDeath;
  int writes = 0;

  @override
  Future<Object?> read(String key) async => data[key];

  @override
  Future<void> write(String key, Object? json) async {
    if (writesBeforeDeath != null && writes >= writesBeforeDeath!) throw PhoneDied();
    writes++;
    data[key] = json;
  }

  @override
  Future<void> remove(String key) async {
    if (writesBeforeDeath != null && writes >= writesBeforeDeath!) throw PhoneDied();
    writes++;
    data.remove(key);
  }
}
