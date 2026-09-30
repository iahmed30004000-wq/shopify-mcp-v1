import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/db/repositories/repositories.dart';
import '../domain/saved_web_game.dart';

/// Everything Saved Games keeps: the games in the user's order and the
/// screen's layout.
@immutable
class SavedGamesState {
  const SavedGamesState({this.games = const [], this.layout = SavedGamesLayout.grid});

  static const empty = SavedGamesState();

  final List<SavedWebGame> games;
  final SavedGamesLayout layout;

  bool get isFull => games.length >= SavedGamesLimits.maxGames;

  SavedWebGame? byId(String id) {
    for (final g in games) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// The saved game with the same (normalised) link, if any.
  SavedWebGame? byUrl(Uri url) {
    final s = url.toString();
    for (final g in games) {
      if (g.url.toString() == s) return g;
    }
    return null;
  }

  SavedGamesState copyWith({List<SavedWebGame>? games, SavedGamesLayout? layout}) =>
      SavedGamesState(games: games ?? this.games, layout: layout ?? this.layout);

  @override
  bool operator ==(Object other) =>
      other is SavedGamesState && other.layout == layout && listEquals(other.games, games);

  @override
  int get hashCode => Object.hash(layout, Object.hashAll(games));
}

/// The stored JSON document (one key/value row):
/// `{"v": 1, "layout": "grid", "games": [{…}, …]}`.
abstract final class SavedGamesCodec {
  static const int version = 1;

  /// Never throws: malformed or untrusted entries are skipped, duplicate
  /// ids dropped, fields clamped and the list cut to
  /// [SavedGamesLimits.maxGames].
  static SavedGamesState decode(Object? json) {
    if (json is! Map) return SavedGamesState.empty;
    final layout = SavedGamesLayout.values.asNameMap()[json['layout']] ?? SavedGamesLayout.grid;
    final raw = json['games'];
    final games = <SavedWebGame>[];
    final ids = <String>{};
    if (raw is List) {
      for (final e in raw) {
        if (games.length >= SavedGamesLimits.maxGames) break;
        if (e is! Map) continue;
        try {
          final g = SavedWebGame.fromJson(e);
          if (ids.add(g.id)) games.add(g);
        } on Object {
          // Skip this entry rather than losing the whole list.
        }
      }
    }
    return SavedGamesState(games: List.unmodifiable(games), layout: layout);
  }

  static Map<String, Object?> encode(SavedGamesState state) => {
    'v': version,
    'layout': state.layout.name,
    'games': [for (final g in state.games.take(SavedGamesLimits.maxGames)) g.bounded().toJson()],
  };
}

/// Outcome of [SavedWebGamesStore.add].
enum AddGameStatus { added, duplicate, full }

@immutable
class AddGameResult {
  const AddGameResult(this.status, this.game);

  final AddGameStatus status;

  /// The added game, or the existing one with the same link.
  final SavedWebGame? game;
}

/// A deleted game and where it was, for undo.
@immutable
class RemovedGame {
  const RemovedGame(this.game, this.index);

  final SavedWebGame game;
  final int index;
}

/// Persistence of Saved Games on top of a raw JSON slot. Every change is a
/// serialized read-modify-write of the whole (bounded) document, so
/// overlapping calls never lose each other's updates.
abstract class SavedWebGamesStore {
  Future<Object?> readRaw();
  Future<void> writeRaw(Object? json);
  Stream<Object?> watchRaw();

  Future<void> _tail = Future<void>.value();

  Stream<SavedGamesState> watch() => watchRaw().map(SavedGamesCodec.decode).distinct();

  Future<SavedGamesState> read() async => SavedGamesCodec.decode(await readRaw());

  Future<T> _change<T>(({SavedGamesState? next, T result}) Function(SavedGamesState current) edit) {
    final run = _tail.then((_) async {
      final current = await read();
      final out = edit(current);
      final next = out.next;
      if (next != null && next != current) await writeRaw(SavedGamesCodec.encode(next));
      return out.result;
    });
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Appends [game] (bounded). Refuses a second copy of the same link and a
  /// full shelf.
  Future<AddGameResult> add(SavedWebGame game) => _change((s) {
    final existing = s.byUrl(game.url);
    if (existing != null) return (next: null, result: AddGameResult(AddGameStatus.duplicate, existing));
    if (s.isFull) return (next: null, result: const AddGameResult(AddGameStatus.full, null));
    final g = game.bounded();
    final games = [...s.games.where((e) => e.id != g.id), g];
    return (next: s.copyWith(games: games), result: AddGameResult(AddGameStatus.added, g));
  });

  /// Replaces the game with [game]'s id (no-op when it is gone).
  Future<void> update(SavedWebGame game) => _change((s) {
    final i = s.games.indexWhere((g) => g.id == game.id);
    if (i < 0) return (next: null, result: null);
    final games = [...s.games]..[i] = game.bounded();
    return (next: s.copyWith(games: games), result: null);
  });

  Future<RemovedGame?> remove(String id) => _change((s) {
    final i = s.games.indexWhere((g) => g.id == id);
    if (i < 0) return (next: null, result: null);
    final games = [...s.games]..removeAt(i);
    return (next: s.copyWith(games: games), result: RemovedGame(s.games[i], i));
  });

  /// Undo of [remove]: back at its old place (unless the shelf filled up or
  /// the link was saved again meanwhile).
  Future<bool> restore(RemovedGame removed) => _change((s) {
    if (s.byId(removed.game.id) != null || s.byUrl(removed.game.url) != null || s.isFull) {
      return (next: null, result: false);
    }
    final games = [...s.games]..insert(removed.index.clamp(0, s.games.length), removed.game.bounded());
    return (next: s.copyWith(games: games), result: true);
  });

  /// Puts the games in [ids] order; unknown ids are ignored and games
  /// missing from [ids] keep their relative order at the end.
  Future<void> reorder(List<String> ids) => _change((s) {
    final byId = {for (final g in s.games) g.id: g};
    final ordered = <SavedWebGame>[];
    for (final id in ids) {
      final g = byId.remove(id);
      if (g != null) ordered.add(g);
    }
    ordered.addAll(s.games.where((g) => byId.containsKey(g.id)));
    return (next: s.copyWith(games: ordered), result: null);
  });

  /// Records a play: last played [at], play count + 1.
  Future<void> markPlayed(String id, DateTime at) => _change((s) {
    final g = s.byId(id);
    if (g == null) return (next: null, result: null);
    final i = s.games.indexOf(g);
    final played = g.copyWith(lastPlayedAt: at, playCount: (g.playCount + 1).clamp(0, SavedGamesLimits.maxPlayCount));
    return (next: s.copyWith(games: [...s.games]..[i] = played), result: null);
  });

  Future<void> setClearDataPending(String id, bool pending) => _change((s) {
    final g = s.byId(id);
    if (g == null || g.clearDataPending == pending) return (next: null, result: null);
    final i = s.games.indexOf(g);
    return (next: s.copyWith(games: [...s.games]..[i] = g.copyWith(clearDataPending: pending)), result: null);
  });

  Future<void> setLayout(SavedGamesLayout layout) => _change((s) => (next: s.copyWith(layout: layout), result: null));
}

/// The encrypted key/value table (one JSON row under [key]; no schema
/// change). Included in Madar's snapshot export like every other key.
class KvSavedWebGamesStore extends SavedWebGamesStore {
  KvSavedWebGamesStore(this.kv);

  final KeyValueRepository kv;
  static const String key = 'savedGames.v1';

  @override
  Future<Object?> readRaw() async {
    try {
      return await kv.getJson(key);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeRaw(Object? json) => kv.setJson(key, json);

  @override
  Stream<Object?> watchRaw() => kv
      .watchJson(key)
      .transform(
        StreamTransformer<Object?, Object?>.fromHandlers(
          handleError: (error, stack, sink) {
            if (error is FormatException) {
              sink.add(null);
            } else {
              sink.addError(error, stack);
            }
          },
        ),
      );
}

/// In-memory store (tests, previews). Values round-trip through JSON text
/// like the real table.
class MemorySavedWebGamesStore extends SavedWebGamesStore {
  MemorySavedWebGamesStore([SavedGamesState initial = SavedGamesState.empty])
    : _json = jsonEncode(SavedGamesCodec.encode(initial));

  String? _json;
  final StreamController<Object?> _changes = StreamController<Object?>.broadcast(sync: true);

  /// Number of writes so far (tests).
  int writes = 0;

  @override
  Future<Object?> readRaw() async => _json == null ? null : _tryDecode(_json!);

  @override
  Future<void> writeRaw(Object? json) async {
    _json = jsonEncode(json);
    writes++;
    _changes.add(jsonDecode(_json!));
  }

  @override
  Stream<Object?> watchRaw() {
    StreamSubscription<Object?>? sub;
    late final StreamController<Object?> out;
    out = StreamController<Object?>(
      onListen: () {
        out.add(_json == null ? null : _tryDecode(_json!));
        sub = _changes.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  /// The stored JSON text (tests).
  String? get rawText => _json;

  /// Replaces the stored text as-is (tests: corrupt / oversized data).
  set rawText(String? text) {
    _json = text;
    _changes.add(text == null ? null : _tryDecode(text));
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
