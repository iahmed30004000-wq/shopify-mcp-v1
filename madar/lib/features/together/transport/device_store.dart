import '../../../core/db/database.dart';
import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/player_profile.dart';

/// Which of the two players this phone belongs to – asked once by the
/// pairing sheet ("Who is playing on this phone?") and remembered in the
/// encrypted KeyValues table (key [TogetherDeviceStore.key]).
class TogetherDeviceStore {
  TogetherDeviceStore(this.db) : keyValues = KeyValueRepository(db);

  static const String key = 'together.net.device';

  /// Every key this store writes (for "delete all data").
  static const List<String> allKeys = [key];

  final MadarDatabase db;
  final KeyValueRepository keyValues;

  static PlayerSlot? _decode(Object? json) => json is Map ? PlayerSlot.tryParse(json['slot']) : null;

  Stream<PlayerSlot?> watch() => keyValues.watchJson(key).map(_decode).distinct();

  Future<PlayerSlot?> read() async {
    try {
      return _decode(await keyValues.getJson(key));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(PlayerSlot slot) => keyValues.setJson(key, {'v': 1, 'slot': slot.name});
}
