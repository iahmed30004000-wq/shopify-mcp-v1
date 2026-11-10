import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../engine/core/score.dart';

/// One game's line in the player's ticket book.
@immutable
class GameRecord {
  const GameRecord({
    required this.gameId,
    this.best = 0,
    this.plays = 0,
    this.wins = 0,
    this.playTime = Duration.zero,
    this.lastScore,
    this.lastPlayed,
  });

  final String gameId;

  /// Best score (0 until a show scored).
  final int best;
  final int plays;
  final int wins;

  /// Total gameplay time (pauses and transitions excluded).
  final Duration playTime;
  final int? lastScore;
  final DateTime? lastPlayed;

  /// This record after [r] was played at [at].
  GameRecord add(GameResult r, DateTime at) => GameRecord(
    gameId: gameId,
    best: math.max(best, r.score),
    plays: plays + 1,
    wins: wins + (r.won ? 1 : 0),
    playTime: playTime + (r.playTime.isNegative ? Duration.zero : r.playTime),
    lastScore: r.score,
    lastPlayed: at,
  );

  Map<String, Object?> toJson() => {
    'best': best,
    'plays': plays,
    'wins': wins,
    'ms': playTime.inMilliseconds,
    if (lastScore != null) 'last': lastScore,
    if (lastPlayed != null) 'at': lastPlayed!.toUtc().millisecondsSinceEpoch,
  };

  /// Tolerant decoding: anything malformed reads as zero.
  factory GameRecord.fromJson(String gameId, Object? json) {
    int n(Object? v, {int max = 1 << 40}) => v is num && v.isFinite ? v.toInt().clamp(0, max) : 0;
    if (json is num) return GameRecord(gameId: gameId, best: n(json)); // legacy `cinema.best` value
    if (json is! Map) return GameRecord(gameId: gameId);
    final at = json['at'];
    return GameRecord(
      gameId: gameId,
      best: n(json['best']),
      plays: n(json['plays']),
      wins: n(json['wins']),
      playTime: Duration(milliseconds: n(json['ms'])),
      lastScore: json['last'] is num ? n(json['last']) : null,
      lastPlayed: at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt(), isUtc: true) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameRecord &&
      other.gameId == gameId &&
      other.best == best &&
      other.plays == plays &&
      other.wins == wins &&
      other.playTime == playTime &&
      other.lastScore == lastScore &&
      other.lastPlayed == lastPlayed;

  @override
  int get hashCode => Object.hash(gameId, best, plays, wins, playTime, lastScore, lastPlayed);
}

/// The whole ticket book: a record per game played, plus totals.
@immutable
class CinemaRecords {
  const CinemaRecords([this.games = const {}]);

  final Map<String, GameRecord> games;

  static const empty = CinemaRecords();

  GameRecord? of(String gameId) => games[gameId];

  /// Best score of [gameId], `null` before its first scored show.
  int? best(String gameId) {
    final b = games[gameId]?.best ?? 0;
    return b > 0 ? b : null;
  }

  int get totalPlays => games.values.fold(0, (a, r) => a + r.plays);
  int get totalWins => games.values.fold(0, (a, r) => a + r.wins);
  Duration get totalTime => games.values.fold(Duration.zero, (a, r) => a + r.playTime);

  /// The most played game (ties: the longer played, then the id).
  GameRecord? get favourite {
    GameRecord? top;
    for (final r in games.values) {
      if (r.plays == 0) continue;
      if (top == null ||
          r.plays > top.plays ||
          (r.plays == top.plays && r.playTime > top.playTime) ||
          (r.plays == top.plays && r.playTime == top.playTime && r.gameId.compareTo(top.gameId) < 0)) {
        top = r;
      }
    }
    return top;
  }

  bool get isEmpty => totalPlays == 0;
}

/// Where the hall keeps high scores and play statistics. It is also the
/// [ScoreSink] every game launched from the hall reports to.
abstract interface class CinemaRecordsStore implements ScoreSink {
  Future<CinemaRecords> load();
  Stream<CinemaRecords> watch();
}

/// Records in the encrypted key/value table – one bounded JSON map under
/// [key] (no schema change). The old best-score map (`cinema.best`,
/// gameId → score) is folded in on first load and then removed.
class KvCinemaRecordsStore implements CinemaRecordsStore {
  KvCinemaRecordsStore(this.kv, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final KeyValueRepository kv;
  final DateTime Function() _clock;

  static const key = 'cinema.records';
  static const legacyBestKey = 'cinema.best';

  /// Hard bound on stored games (ids beyond it are ignored).
  static const maxGames = 256;
  static final RegExp _id = RegExp(r'^[a-z0-9_]{1,48}$');

  Future<void> _chain = Future.value();
  bool _migrated = false;

  /// Serialises read-modify-write updates (two shows ending at once must
  /// not lose one).
  Future<T> _serial<T>(Future<T> Function() op) {
    final run = _chain.then((_) => op());
    _chain = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  static CinemaRecords decode(Object? raw) {
    if (raw is! Map) return CinemaRecords.empty;
    final games = <String, GameRecord>{};
    for (final e in raw.entries) {
      final id = e.key;
      if (id is! String || !_id.hasMatch(id) || games.length >= maxGames) continue;
      games[id] = GameRecord.fromJson(id, e.value);
    }
    return CinemaRecords(Map.unmodifiable(games));
  }

  static Map<String, Object?> encode(CinemaRecords r) => {for (final e in r.games.entries) e.key: e.value.toJson()};

  Future<CinemaRecords> _read() async {
    if (!_migrated) {
      _migrated = true;
      final legacy = await kv.getJson(legacyBestKey);
      if (legacy is Map && legacy.isNotEmpty) {
        final current = decode(await kv.getJson(key));
        final merged = Map<String, GameRecord>.of(current.games);
        for (final e in legacy.entries) {
          final id = e.key;
          if (id is! String || !_id.hasMatch(id)) continue;
          final old = GameRecord.fromJson(id, e.value);
          final now = merged[id];
          merged[id] = now == null
              ? old
              : GameRecord(
                  gameId: id,
                  best: math.max(now.best, old.best),
                  plays: now.plays,
                  wins: now.wins,
                  playTime: now.playTime,
                  lastScore: now.lastScore,
                  lastPlayed: now.lastPlayed,
                );
        }
        await kv.setJson(key, encode(CinemaRecords(merged)));
      }
      if (legacy != null || await kv.contains(legacyBestKey)) await kv.remove(legacyBestKey);
    }
    return decode(await kv.getJson(key));
  }

  @override
  Future<CinemaRecords> load() => _serial(_read);

  @override
  Stream<CinemaRecords> watch() async* {
    await load(); // folds the legacy map in first
    yield* kv.watchJson(key).map(decode).distinct(_same);
  }

  static bool _same(CinemaRecords a, CinemaRecords b) => mapEquals(a.games, b.games);

  @override
  Future<void> submit(GameResult result) => _serial(() async {
    if (!_id.hasMatch(result.gameId)) return;
    final current = await _read();
    final prev = current.games[result.gameId] ?? GameRecord(gameId: result.gameId);
    final next = Map<String, GameRecord>.of(current.games)..[result.gameId] = prev.add(result, _clock().toUtc());
    if (next.length > maxGames) return;
    await kv.setJson(key, encode(CinemaRecords(next)));
  });

  @override
  Future<int?> best(String gameId) async => (await load()).best(gameId);
}

/// In-memory records (tests, previews, no database).
class MemoryCinemaRecordsStore implements CinemaRecordsStore {
  MemoryCinemaRecordsStore([CinemaRecords initial = CinemaRecords.empty]) : _records = initial;

  CinemaRecords _records;
  final StreamController<CinemaRecords> _changes = StreamController.broadcast();
  final List<GameResult> submitted = [];

  CinemaRecords get records => _records;

  @override
  Future<CinemaRecords> load() async => _records;

  @override
  Stream<CinemaRecords> watch() {
    StreamSubscription<CinemaRecords>? sub;
    late final StreamController<CinemaRecords> out;
    out = StreamController<CinemaRecords>(
      onListen: () {
        out.add(_records);
        sub = _changes.stream.listen(out.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<void> submit(GameResult result) async {
    submitted.add(result);
    final prev = _records.games[result.gameId] ?? GameRecord(gameId: result.gameId);
    _records = CinemaRecords({..._records.games, result.gameId: prev.add(result, DateTime.now().toUtc())});
    _changes.add(_records);
  }

  @override
  Future<int?> best(String gameId) async => _records.best(gameId);
}

/// The hall's records store (encrypted key/value table). Override in tests.
final cinemaRecordsStoreProvider = Provider<CinemaRecordsStore>(
  (ref) => KvCinemaRecordsStore(ref.watch(repositoriesProvider).keyValues),
);

/// The ticket book, live.
final cinemaRecordsProvider = StreamProvider<CinemaRecords>((ref) => ref.watch(cinemaRecordsStoreProvider).watch());
