import 'package:flutter/foundation.dart';

/// The outcome of one play of a game, reported by `CinemaGame.endScene`.
@immutable
class GameResult {
  const GameResult({
    required this.gameId,
    required this.score,
    required this.won,
    required this.playTime,
    this.stats = const {},
  });

  final String gameId;
  final int score;
  final bool won;

  /// Gameplay time (pauses and transitions excluded).
  final Duration playTime;

  /// Game-specific numbers (e.g. {'coins': 12, 'bossPhase': 3}).
  final Map<String, num> stats;

  @override
  String toString() => 'GameResult($gameId, score: $score, won: $won, ${playTime.inSeconds}s)';
}

/// Where results go (best scores, statistics). The hall provides the
/// persistent implementation; games never persist anything themselves.
abstract interface class ScoreSink {
  Future<void> submit(GameResult result);

  /// Best score recorded for [gameId], or `null`.
  Future<int?> best(String gameId);
}

/// In-memory [ScoreSink] (tests, demo, previews).
class MemoryScoreSink implements ScoreSink {
  final List<GameResult> results = [];

  @override
  Future<void> submit(GameResult result) async => results.add(result);

  @override
  Future<int?> best(String gameId) async {
    int? best;
    for (final r in results) {
      if (r.gameId == gameId && (best == null || r.score > best)) best = r.score;
    }
    return best;
  }
}
