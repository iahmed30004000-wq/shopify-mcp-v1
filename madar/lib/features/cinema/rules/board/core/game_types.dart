/// Shared value types for the Madar Cinema Tier 2 board games.
///
/// Pure Dart: no Flutter imports and no user-facing strings. Every enum here
/// is an id the UI localises.
library;

/// The board games implemented under `rules/board`.
enum BoardGameId { chess, checkers, backgammon, dominoes, ludo, mancala, connectFour, ticTacToe }

/// AI difficulty.
enum AiLevel { easy, medium, hard }

/// How much an AI may think for one move.
///
/// [maxTime] is wall-clock (non-deterministic); [maxNodes] counts search
/// nodes / playout steps and is fully deterministic, which is what tests
/// use. When both are set the first limit reached stops the search. Every AI
/// always finishes a minimal (depth-1 / greedy) decision before it honours a
/// limit, so it never returns without a legal move.
final class AiBudget {
  const AiBudget({this.maxTime, this.maxNodes});

  /// Deterministic node-only budget.
  const AiBudget.nodes(int nodes) : maxTime = null, maxNodes = nodes;

  /// About 150 ms per move – the default for a phone.
  static const AiBudget phone = AiBudget(maxTime: Duration(milliseconds: 150));

  final Duration? maxTime;
  final int? maxNodes;

  Map<String, Object?> toJson() => {'ms': maxTime?.inMicroseconds, 'nodes': maxNodes};

  factory AiBudget.fromJson(Map<String, Object?> json) {
    final us = json['ms'] as num?;
    return AiBudget(
      maxTime: us == null ? null : Duration(microseconds: us.toInt()),
      maxNodes: (json['nodes'] as num?)?.toInt(),
    );
  }
}

/// Why a game ended. The UI maps each value to a localised sentence.
enum GameEndReason {
  // Chess
  checkmate,
  stalemate,
  threefoldRepetition,
  fiftyMoveRule,
  insufficientMaterial,
  // Checkers
  noLegalMoves,
  noProgress,
  // Connect four / tic-tac-toe
  lineCompleted,
  boardFull,
  // Backgammon
  bearOffSingle,
  bearOffGammon,
  bearOffBackgammon,
  doubleDeclined,
  // Dominoes (match)
  targetScoreReached,
  // Ludo
  allTokensHome,
  // Mancala
  sideEmpty,
  majorityCaptured,
  cannotFeed,
  moveLimit,
}

/// The outcome of a finished game.
final class GameResult {
  const GameResult({
    required this.winners,
    required this.reason,
    this.scores = const [],
    this.ranking = const [],
  });

  /// A draw for [reason].
  const GameResult.draw(this.reason, {this.scores = const []}) : winners = const [], ranking = const [];

  /// Winning players (several for team games); empty means a draw.
  final List<int> winners;
  final GameEndReason reason;

  /// Game-specific per-player numbers: mancala stores, domino match points,
  /// backgammon points won (0 for the loser), ludo tokens home…
  final List<int> scores;

  /// Finishing order (ludo); empty when not meaningful.
  final List<int> ranking;

  bool get isDraw => winners.isEmpty;
  bool isWinner(int player) => winners.contains(player);

  Map<String, Object?> toJson() => {'winners': winners, 'reason': reason.name, 'scores': scores, 'ranking': ranking};

  factory GameResult.fromJson(Map<String, Object?> json) => GameResult(
    winners: intList(json['winners']),
    reason: GameEndReason.values.byName(json['reason']! as String),
    scores: intList(json['scores']),
    ranking: intList(json['ranking']),
  );

  @override
  bool operator ==(Object other) =>
      other is GameResult &&
      other.reason == reason &&
      listEquals(other.winners, winners) &&
      listEquals(other.scores, scores) &&
      listEquals(other.ranking, ranking);

  @override
  int get hashCode => Object.hash(reason, Object.hashAll(winners), Object.hashAll(scores), Object.hashAll(ranking));

  @override
  String toString() => 'GameResult(${reason.name}, winners: $winners, scores: $scores)';
}

/// A complete, immutable snapshot of one game.
abstract class GameState {
  const GameState();

  int get playerCount;

  /// The player who must act next (also the responder to a pending offer).
  int get currentPlayer;

  /// Non-null once the game has ended.
  GameResult? get result;

  bool get isOver => result != null;

  Map<String, Object?> toJson();
}

/// One action a player can take (a chess move, a dice roll, a domino play…).
///
/// Moves are immutable values with structural equality.
abstract class GameMove {
  const GameMove();

  Map<String, Object?> toJson();
}

/// Thrown when a move is not legal in the current state.
final class IllegalMoveException implements Exception {
  const IllegalMoveException(this.move, [this.reason = '']);
  final Object? move;
  final String reason;

  @override
  String toString() => 'IllegalMoveException($move${reason.isEmpty ? '' : ': $reason'})';
}

// ---------------------------------------------------------------------------
// Small helpers shared by the games (not UI).

/// Parses a JSON list of numbers into `List<int>`.
List<int> intList(Object? json) => json == null ? const [] : [for (final v in json as List) (v as num).toInt()];

/// Element-wise list equality.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Reads a JSON object.
Map<String, Object?> jsonMap(Object? json) => (json! as Map).cast<String, Object?>();
