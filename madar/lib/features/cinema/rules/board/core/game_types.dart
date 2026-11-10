/// Shared value types for the Madar Cinema Tier 2 board games.
///
/// Pure Dart: no Flutter imports and no user-facing strings. Every enum here
/// is an id the UI localises.
library;

/// The board games implemented under `rules/board`.
enum BoardGameId { chess, checkers, backgammon, dominoes, ludo, mancala, connectFour, ticTacToe }

/// Every named rule set (lobby mode) of every game. The UI localises [name].
///
/// Each game has exactly one default mode ([isDefault]): the game as
/// commonly played in Jordan (`RULES.md`). The other modes are regional or
/// international presets of the same engine, so every mode of a game shares
/// its rules object and AI, and any of them restores any save of that game.
/// `boardVariantKits` in `board_games.dart` has a kit for each value.
enum BoardVariantId {
  /// Standard FIDE chess.
  chess(BoardGameId.chess, isDefault: true),

  /// «الضامة» as commonly played in Jordan (`CheckersVariant.jordan`).
  damaJordan(BoardGameId.checkers, isDefault: true),

  /// «الضامة التركية» – Turkish federation rules (`CheckersVariant.turkish`).
  damaTurkish(BoardGameId.checkers),

  /// English / American draughts (`CheckersVariant.american`).
  draughtsAmerican(BoardGameId.checkers),

  /// American draughts with flying kings, a house rule
  /// (`CheckersVariant.americanFlyingKings`).
  draughtsAmericanFlyingKings(BoardGameId.checkers),

  /// طاولة الزهر: «شيش بيش», the hitting game, a match to 5
  /// (`BackgammonConfig.jordan`).
  tawlaSheshBesh(BoardGameId.backgammon, isDefault: true),

  /// طاولة الزهر: «محبوسة», the pinning game, a match to 5
  /// (`BackgammonConfig.mahbusa`).
  tawlaMahbusa(BoardGameId.backgammon),

  /// طاولة الزهر: «٣١», the blocking race, a match to 31
  /// (`BackgammonConfig.tawla31`).
  tawla31(BoardGameId.backgammon),

  /// International backgammon as one game: the opening dice are the first
  /// move and the triple counts (`BackgammonConfig.international`).
  backgammonInternational(BoardGameId.backgammon),

  /// «دومينو» as commonly played in Jordan: the draw game, count scoring to
  /// 101, partners with four (`DominoConfig.jordan`).
  dominoesJordan(BoardGameId.dominoes, isDefault: true),

  /// «الخمسات» – All Fives on a line, to 150 (`DominoConfig.allFives`).
  dominoesAllFives(BoardGameId.dominoes),

  /// The block game: nobody draws (`DominoConfig.block`).
  dominoesBlock(BoardGameId.dominoes),

  /// A locked line is played out: the player to move draws the whole stock
  /// (`DominoConfig.playOutLock`).
  dominoesPlayOutLock(BoardGameId.dominoes),

  /// «لودو» as commonly played in Jordan, 2–4 players (`LudoConfig.jordan`).
  ludoJordan(BoardGameId.ludo, isDefault: true),

  /// «لودو» in partnerships, exactly 4 players: 0 + 2 against 1 + 3
  /// (`LudoConfig(players: 4, teams: true)`).
  ludoTeams(BoardGameId.ludo),

  /// Kalah(6,4) (`MancalaConfig.kalah`).
  mancalaKalah(BoardGameId.mancala, isDefault: true),

  /// Oware (Abapa) (`MancalaConfig.oware`).
  mancalaOware(BoardGameId.mancala),

  /// Four in a row, 7 × 6.
  connectFour(BoardGameId.connectFour, isDefault: true),

  /// Tic-tac-toe, 3 × 3.
  ticTacToe(BoardGameId.ticTacToe, isDefault: true);

  const BoardVariantId(this.game, {this.isDefault = false});

  /// The game this mode belongs to.
  final BoardGameId game;

  /// Whether this is [game]'s default mode (as commonly played in Jordan).
  final bool isDefault;

  /// The default mode of [game].
  static BoardVariantId defaultOf(BoardGameId game) => values.firstWhere((v) => v.game == game && v.isDefault);

  /// Every mode of [game], the default first.
  static List<BoardVariantId> of(BoardGameId game) => [
    for (final v in values)
      if (v.game == game) v,
  ];
}

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

  Map<String, Object?> toJson() => {'us': maxTime?.inMicroseconds, 'nodes': maxNodes};

  factory AiBudget.fromJson(Map<String, Object?> json) {
    final us = json['us'] as num?;
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
  // Checkers / Dama
  noLegalMoves,
  noProgress,
  onePieceEach,
  kingsVsLoneKing,
  kingVsLoneMan,
  // Connect four / tic-tac-toe
  lineCompleted,
  boardFull,
  // Backgammon / tawla (void games: bothMothersPinned, positionFrozen,
  // moveLimit)
  bearOffSingle,
  bearOffGammon,
  bearOffBackgammon,
  doubleDeclined,
  motherPinned,
  bothMothersPinned,
  positionFrozen,
  bearOffCount,
  // Dominoes and tawla (match)
  targetScoreReached,
  // Ludo
  allTokensHome,
  // Mancala (moveLimit: also the tawla turn cap)
  sideEmpty,
  majorityCaptured,
  cannotFeed,
  moveLimit,
}

/// The outcome of a finished game.
final class GameResult {
  const GameResult({required this.winners, required this.reason, this.scores = const [], this.ranking = const []});

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
