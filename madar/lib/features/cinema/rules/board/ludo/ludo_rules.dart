/// Ludo (لودو) – standard rules with configurable house rules, 2–4 players.
///
/// Track: 52 shared squares; seat `s` enters on absolute square `13 * s`.
/// A token's progress is -1 (yard), 0..50 (main track, relative to its
/// seat's start square), 51..55 (home column) and 56 (home).
/// Two players sit opposite (seats 0 and 2); three use seats 0, 1, 2.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

const int kLudoYard = -1;
const int kLudoLastTrack = 50;
const int kLudoHome = 56;

enum LudoSafeSquares { startAndStars, startOnly, none }

enum LudoPhase { awaitingRoll, awaitingMove }

final class LudoConfig {
  const LudoConfig({
    this.players = 4,
    this.tokensPerPlayer = 4,
    this.exitRolls = const [6],
    this.extraTurnOnSix = true,
    this.maxConsecutiveSixes = 3,
    this.extraTurnOnCapture = true,
    this.extraTurnOnHome = true,
    this.exactRollToFinish = true,
    this.safeSquares = LudoSafeSquares.startAndStars,
    this.blockades = false,
    this.playUntilLast = false,
  }) : assert(players >= 2 && players <= 4);

  factory LudoConfig.fromJson(Map<String, Object?> json) => LudoConfig(
    players: (json['players']! as num).toInt(),
    tokensPerPlayer: (json['tokens']! as num).toInt(),
    exitRolls: intList(json['exitRolls']),
    extraTurnOnSix: json['sixAgain']! as bool,
    maxConsecutiveSixes: (json['maxSixes']! as num).toInt(),
    extraTurnOnCapture: json['captureAgain']! as bool,
    extraTurnOnHome: json['homeAgain']! as bool,
    exactRollToFinish: json['exact']! as bool,
    safeSquares: LudoSafeSquares.values.byName(json['safe']! as String),
    blockades: json['blockades']! as bool,
    playUntilLast: json['untilLast']! as bool,
  );

  final int players;
  final int tokensPerPlayer;

  /// Rolls that release a token from the yard (house rule: `[1, 6]`).
  final List<int> exitRolls;
  final bool extraTurnOnSix;

  /// Rolling this many sixes in a row forfeits the turn (0 = no limit).
  final int maxConsecutiveSixes;
  final bool extraTurnOnCapture;
  final bool extraTurnOnHome;

  /// A token needs the exact count to reach home.
  final bool exactRollToFinish;
  final LudoSafeSquares safeSquares;

  /// Two or more tokens of one colour on a square cannot be passed or
  /// landed on by opponents.
  final bool blockades;

  /// Keep playing for 2nd/3rd place instead of stopping at the first winner.
  final bool playUntilLast;

  Map<String, Object?> toJson() => {
    'players': players,
    'tokens': tokensPerPlayer,
    'exitRolls': exitRolls,
    'sixAgain': extraTurnOnSix,
    'maxSixes': maxConsecutiveSixes,
    'captureAgain': extraTurnOnCapture,
    'homeAgain': extraTurnOnHome,
    'exact': exactRollToFinish,
    'safe': safeSquares.name,
    'blockades': blockades,
    'untilLast': playUntilLast,
  };

  /// Board seat (colour) of [player].
  int seatOf(int player) => players == 2 ? player * 2 : player;

  bool isSafe(int absolute) => switch (safeSquares) {
    LudoSafeSquares.none => false,
    LudoSafeSquares.startOnly => absolute % 13 == 0,
    LudoSafeSquares.startAndStars => absolute % 13 == 0 || absolute % 13 == 8,
  };
}

enum LudoMoveKind { roll, move, pass }

final class LudoMove extends GameMove {
  const LudoMove._(this.kind) : token = -1;
  const LudoMove.move(this.token) : kind = LudoMoveKind.move;

  static const LudoMove roll = LudoMove._(LudoMoveKind.roll);
  static const LudoMove pass = LudoMove._(LudoMoveKind.pass);

  factory LudoMove.fromJson(Map<String, Object?> json) {
    final kind = LudoMoveKind.values.byName(json['kind']! as String);
    return kind == LudoMoveKind.move ? LudoMove.move((json['token']! as num).toInt()) : LudoMove._(kind);
  }

  final LudoMoveKind kind;
  final int token;

  @override
  Map<String, Object?> toJson() => {'kind': kind.name, if (kind == LudoMoveKind.move) 'token': token};

  @override
  bool operator ==(Object other) => other is LudoMove && other.kind == kind && other.token == token;

  @override
  int get hashCode => Object.hash(kind, token);

  @override
  String toString() => kind == LudoMoveKind.move ? 'move($token)' : kind.name;
}

final class LudoState extends GameState {
  LudoState({
    required this.config,
    required List<List<int>> tokens,
    required this.currentPlayer,
    required this.phase,
    required List<int> rng,
    this.dice = 0,
    this.consecutiveSixes = 0,
    List<int> ranking = const [],
    this.result,
  }) : tokens = List.unmodifiable([for (final t in tokens) List<int>.unmodifiable(t)]),
       rng = List.unmodifiable(rng),
       ranking = List.unmodifiable(ranking);

  factory LudoState.initial({int seed = 0, LudoConfig config = const LudoConfig()}) => LudoState(
    config: config,
    tokens: List.generate(config.players, (_) => List.filled(config.tokensPerPlayer, kLudoYard)),
    currentPlayer: 0,
    phase: LudoPhase.awaitingRoll,
    rng: BoardRng(seed).state,
  );

  factory LudoState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    return LudoState(
      config: LudoConfig.fromJson(jsonMap(json['config'])),
      tokens: [for (final t in json['tokens']! as List) intList(t)],
      currentPlayer: (json['player']! as num).toInt(),
      phase: LudoPhase.values.byName(json['phase']! as String),
      rng: intList(json['rng']),
      dice: (json['dice']! as num).toInt(),
      consecutiveSixes: (json['sixes']! as num).toInt(),
      ranking: intList(json['ranking']),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final LudoConfig config;

  /// `tokens[player][i]` = progress (see library docs).
  final List<List<int>> tokens;
  @override
  final int currentPlayer;
  final LudoPhase phase;
  final List<int> rng;

  /// The die showing (0 before the roll).
  final int dice;
  final int consecutiveSixes;

  /// Players who have brought every token home, in order.
  final List<int> ranking;
  @override
  final GameResult? result;

  @override
  int get playerCount => config.players;

  /// Absolute track square (0..51) of a token, or -1 when off the track.
  int absoluteSquare(int player, int progress) {
    if (progress < 0 || progress > kLudoLastTrack) return -1;
    return (13 * config.seatOf(player) + progress) % 52;
  }

  bool finished(int player) => tokens[player].every((t) => t == kLudoHome);

  int tokensHome(int player) => tokens[player].where((t) => t == kLudoHome).length;

  LudoState copyWith({
    List<List<int>>? tokens,
    int? currentPlayer,
    LudoPhase? phase,
    List<int>? rng,
    int? dice,
    int? consecutiveSixes,
    List<int>? ranking,
    GameResult? result,
  }) => LudoState(
    config: config,
    tokens: tokens ?? this.tokens,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    phase: phase ?? this.phase,
    rng: rng ?? this.rng,
    dice: dice ?? this.dice,
    consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
    ranking: ranking ?? this.ranking,
    result: result ?? this.result,
  );

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'tokens': tokens,
    'player': currentPlayer,
    'phase': phase.name,
    'rng': rng,
    'dice': dice,
    'sixes': consecutiveSixes,
    'ranking': ranking,
    if (result != null) 'result': result!.toJson(),
  };
}

/// Outcome of moving one token (shared with the AI).
final class LudoStep {
  const LudoStep(this.target, this.captures);
  final int target;

  /// `[player, token, …]` pairs sent back to the yard.
  final List<int> captures;
}

final class LudoRules extends GameRules<LudoState, LudoMove> {
  const LudoRules();

  @override
  BoardGameId get id => BoardGameId.ludo;

  /// Where token [t] of [player] lands with [roll], or null if it cannot move.
  static LudoStep? stepFor(LudoState s, int player, int t, int roll) {
    final cfg = s.config;
    final from = s.tokens[player][t];
    if (from == kLudoHome) return null;
    int target;
    if (from == kLudoYard) {
      if (!cfg.exitRolls.contains(roll)) return null;
      target = 0;
    } else {
      target = from + roll;
      if (target > kLudoHome) {
        if (cfg.exactRollToFinish) return null;
        target = kLudoHome;
      }
    }
    // Squares crossed on the shared track (for blockades) and the landing.
    if (cfg.blockades) {
      final start = from == kLudoYard ? 0 : from + 1;
      for (var q = start; q <= target && q <= kLudoLastTrack; q++) {
        if (_opponentBlock(s, player, s.absoluteSquare(player, q))) return null;
      }
    }
    final captures = <int>[];
    if (target <= kLudoLastTrack) {
      final sq = s.absoluteSquare(player, target);
      if (!cfg.isSafe(sq)) {
        for (var o = 0; o < cfg.players; o++) {
          if (o == player) continue;
          for (var i = 0; i < s.tokens[o].length; i++) {
            if (s.absoluteSquare(o, s.tokens[o][i]) == sq) {
              captures
                ..add(o)
                ..add(i);
            }
          }
        }
      }
    }
    return LudoStep(target, captures);
  }

  static bool _opponentBlock(LudoState s, int player, int sq) {
    for (var o = 0; o < s.config.players; o++) {
      if (o == player) continue;
      var count = 0;
      for (final p in s.tokens[o]) {
        if (s.absoluteSquare(o, p) == sq) count++;
      }
      if (count >= 2) return true;
    }
    return false;
  }

  bool _forfeit(LudoState s) => s.config.maxConsecutiveSixes > 0 && s.consecutiveSixes >= s.config.maxConsecutiveSixes;

  @override
  List<LudoMove> legalMoves(LudoState state) {
    if (state.isOver) return const [];
    if (state.phase == LudoPhase.awaitingRoll) return const [LudoMove.roll];
    if (_forfeit(state)) return const [LudoMove.pass];
    final p = state.currentPlayer;
    final moves = <LudoMove>[
      for (var t = 0; t < state.tokens[p].length; t++)
        if (stepFor(state, p, t, state.dice) != null) LudoMove.move(t),
    ];
    return moves.isEmpty ? const [LudoMove.pass] : moves;
  }

  int _nextPlayer(LudoState s, int from, List<int> ranking) {
    final n = s.config.players;
    for (var i = 1; i <= n; i++) {
      final q = (from + i) % n;
      if (!ranking.contains(q)) return q;
    }
    return from;
  }

  @override
  LudoState apply(LudoState state, LudoMove move) {
    final p = state.currentPlayer;
    switch (move.kind) {
      case LudoMoveKind.roll:
        final rng = BoardRng.fromState(state.rng);
        final roll = rng.rollDie();
        return state.copyWith(
          phase: LudoPhase.awaitingMove,
          dice: roll,
          rng: rng.state,
          consecutiveSixes: roll == 6 ? state.consecutiveSixes + 1 : 0,
        );
      case LudoMoveKind.pass:
        return state.copyWith(
          phase: LudoPhase.awaitingRoll,
          currentPlayer: _nextPlayer(state, p, state.ranking),
          dice: 0,
          consecutiveSixes: 0,
        );
      case LudoMoveKind.move:
        final step = stepFor(state, p, move.token, state.dice) ?? (throw IllegalMoveException(move));
        final tokens = [for (final t in state.tokens) List<int>.of(t)];
        tokens[p][move.token] = step.target;
        for (var i = 0; i < step.captures.length; i += 2) {
          tokens[step.captures[i]][step.captures[i + 1]] = kLudoYard;
        }
        final cfg = state.config;
        var ranking = state.ranking;
        final done = tokens[p].every((t) => t == kLudoHome);
        if (done) ranking = [...ranking, p];
        final active = cfg.players - ranking.length;
        GameResult? result;
        if (done && (!cfg.playUntilLast || active <= 1)) {
          if (cfg.playUntilLast) {
            ranking = [
              ...ranking,
              for (var q = 0; q < cfg.players; q++)
                if (!ranking.contains(q)) q,
            ];
          }
          result = GameResult(
            winners: [ranking.first],
            reason: GameEndReason.allTokensHome,
            ranking: cfg.playUntilLast ? ranking : [ranking.first],
            scores: [for (final t in tokens) t.where((x) => x == kLudoHome).length],
          );
        }
        final again =
            !done &&
            ((state.dice == 6 && cfg.extraTurnOnSix) ||
                (step.captures.isNotEmpty && cfg.extraTurnOnCapture) ||
                (step.target == kLudoHome && cfg.extraTurnOnHome));
        final next = result != null ? p : (again ? p : _nextPlayer(state, p, ranking));
        return state.copyWith(
          tokens: tokens,
          currentPlayer: next,
          phase: LudoPhase.awaitingRoll,
          dice: 0,
          consecutiveSixes: again && state.dice == 6 ? state.consecutiveSixes : 0,
          ranking: ranking,
          result: result,
        );
    }
  }

  @override
  LudoState stateFromJson(Map<String, Object?> json) => LudoState.fromJson(json);

  @override
  LudoMove moveFromJson(Map<String, Object?> json) => LudoMove.fromJson(json);
}

const ludoRules = LudoRules();
