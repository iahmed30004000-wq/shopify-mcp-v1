import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/repositories/repositories.dart';
import 'saved_game.dart';

/// Persistence of the user's saved web games. Owner: hall.
abstract interface class SavedGamesStore {
  Stream<List<SavedGame>> watch();
  Future<List<SavedGame>> all();
  Future<void> add(SavedGame game);
  Future<void> remove(String id);
}

/// Encrypted key/value store implementation (one JSON list under [key]).
class KvSavedGamesStore implements SavedGamesStore {
  KvSavedGamesStore(this.kv);

  final KeyValueRepository kv;
  static const key = 'cinema.savedGames';

  static List<SavedGame> _decode(Object? raw) {
    if (raw is! List) return const [];
    final out = <SavedGame>[];
    for (final e in raw) {
      try {
        out.add(SavedGame.fromJson(Map<String, Object?>.from(e as Map)));
      } catch (_) {
        // Skip malformed entries rather than losing the whole list.
      }
    }
    return out;
  }

  @override
  Stream<List<SavedGame>> watch() => kv.watchJson(key).map(_decode);

  @override
  Future<List<SavedGame>> all() async => _decode(await kv.getJson(key));

  @override
  Future<void> add(SavedGame game) async {
    final list = [...await all()]..removeWhere((g) => g.id == game.id);
    list.add(game);
    await kv.setJson(key, [for (final g in list) g.toJson()]);
  }

  @override
  Future<void> remove(String id) async {
    final list = [...await all()]..removeWhere((g) => g.id == id);
    await kv.setJson(key, [for (final g in list) g.toJson()]);
  }
}

/// In-memory implementation (tests, previews).
class MemorySavedGamesStore implements SavedGamesStore {
  MemorySavedGamesStore([List<SavedGame> initial = const []]) : _games = [...initial];

  final List<SavedGame> _games;
  final StreamController<List<SavedGame>> _changes = StreamController.broadcast();

  @override
  Stream<List<SavedGame>> watch() {
    // Snapshot and subscription are taken synchronously on listen, so no
    // change between them can be missed.
    StreamSubscription<List<SavedGame>>? sub;
    late final StreamController<List<SavedGame>> out;
    out = StreamController<List<SavedGame>>(
      onListen: () {
        out.add(List.unmodifiable(_games));
        sub = _changes.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<List<SavedGame>> all() async => List.unmodifiable(_games);

  @override
  Future<void> add(SavedGame game) async {
    _games
      ..removeWhere((g) => g.id == game.id)
      ..add(game);
    _changes.add(List.unmodifiable(_games));
  }

  @override
  Future<void> remove(String id) async {
    _games.removeWhere((g) => g.id == id);
    _changes.add(List.unmodifiable(_games));
  }
}

final savedGamesStoreProvider = Provider<SavedGamesStore>(
  (ref) => KvSavedGamesStore(ref.watch(repositoriesProvider).keyValues),
);

final savedGamesProvider = StreamProvider<List<SavedGame>>((ref) => ref.watch(savedGamesStoreProvider).watch());
