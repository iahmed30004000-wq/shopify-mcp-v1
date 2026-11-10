import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/search_text.dart';

/// The last searches (newest first), kept in the encrypted key/value store
/// under [key]. Two searches that fold to the same words («الصلاة» /
/// «الصلاه») count as one.
class RecentSearchesStore {
  RecentSearchesStore(this._kv, {this.max = 8});

  final KeyValueRepository _kv;

  /// Most searches kept.
  final int max;

  static const String key = 'search.recent';

  /// Longest search kept.
  static const int maxLength = 80;

  static List<String> _decode(Object? json) => json is List
      ? [
          for (final v in json)
            if (v is String && v.trim().isNotEmpty) v,
        ]
      : const [];

  Future<List<String>> read() async => _decode(await _kv.getJson(key));

  Stream<List<String>> watch() => _kv.watchJson(key).map(_decode);

  /// Puts [query] first (dropping an equivalent older one).
  Future<void> add(String query) async {
    var q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty || SearchText.fold(q).isEmpty) return;
    if (q.length > maxLength) q = q.substring(0, maxLength);
    final folded = SearchText.fold(q);
    final list = await read();
    final next = [q, ...list.where((s) => SearchText.fold(s) != folded)].take(max).toList();
    await _kv.setJson(key, next);
  }

  Future<void> remove(String query) async {
    final list = await read();
    final next = list.where((s) => s != query).toList();
    if (next.length != list.length) await _kv.setJson(key, next);
  }

  Future<void> clear() => _kv.remove(key);
}
