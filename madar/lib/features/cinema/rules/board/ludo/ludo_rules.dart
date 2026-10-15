/// Ludo (لودو) – 2–4 players, with configurable house rules.
///
/// The defaults (`LudoConfig()` = [LudoConfig.jordan]) are the app-style
/// game as commonly played in Jordan: a random first player, a 6 to leave
/// the yard, another roll for a 6, a capture or a token reaching home, the
/// third 6 in a row ends the turn (earlier moves stand), the exact roll to
/// finish, safe start and star squares, and landing on opponents captures
/// all of them. Options: safe pairs, blockades, a 1 also leaves the yard,
/// three tries while every token is in the yard, a bonus roll for an
/// unusable 6, a capture needed before entering the home column, 2 v 2
/// partnerships, and playing on for places.
///
/// Track: 52 shared squares; seat `s` enters on absolute square `13 * s`.
/// A token's progress is -1 (yard), 0..50 (main track, relative to its
/// seat's start square), 51..55 (home column) and 56 (home). With
/// [LudoConfig.captureToEnterHome] a token that may not enter its column
/// yet keeps lapping, and 57 ([kLudoBeforeStart]) marks the shared square
/// just before its own start. Two players sit opposite (seats 0 and 2);
/// three use seats 0, 1, 2.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

const int kLudoYard = -1;
const int kLudoLastTrack = 50;
const int kLudoHome = 56;

/// Progress of a lapping token on the shared square just before its own
/// start (absolute `13 * seat + 51`); only with
/// [LudoConfig.captureToEnterHome].
const int kLudoBeforeStart = 57;

enum LudoSafeSquares { startAndStars, startOnly, none }

/// Who rolls first.
enum LudoFirstPlayer {
  /// Seat 0 (player 0) always starts.
  seat0,

  /// A uniformly random player, drawn from the seed (the UI may animate a
  /// roll-off); the choice is stored in the initial state.
  random,
}

enum LudoPhase { awaitingRoll, awaitingMove }

final class LudoConfig {
  /// The Jordanian defaults unless options say otherwise.
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
    this.safePairs = false,
    this.firstPlayer = LudoFirstPlayer.random,
    this.yardRollAttempts = 1,
    this.bonusRollOnUnusableSix = false,
    this.captureToEnterHome = false,
    this.teams = false,
  }) : assert(players >= 2 && players <= 4),
       assert(!teams || players == 4),
       assert(yardRollAttempts >= 1);

  /// «لودو» as commonly played in Jordan (= `LudoConfig(players: …)`).
  const LudoConfig.jordan({required int players}) : this(players: players);

  /// Reads a saved config. Keys added after the first release fall back to
  /// the behaviour the save was played under (`first` missing → seat 0).
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
    safePairs: json['safePairs'] as bool? ?? false,
    firstPlayer: json['first'] == null
        ? LudoFirstPlayer.seat0
        : LudoFirstPlayer.values.byName(json['first']! as String),
    yardRollAttempts: (json['yardTries'] as num?)?.toInt() ?? 1,
    bonusRollOnUnusableSix: json['unusableSixAgain'] as bool? ?? false,
    captureToEnterHome: json['mustCapture'] as bool? ?? false,
    teams: json['teams'] as bool? ?? false,
  );

  final int players;
  final int tokensPerPlayer;

  /// Rolls that release a token from the yard (house rule: `[1, 6]`).
  final List<int> exitRolls;
  final bool extraTurnOnSix;

  /// Rolling this many sixes in a row ends the turn without a move; the
  /// moves made with the earlier sixes stand (0 = no limit).
  final int maxConsecutiveSixes;
  final bool extraTurnOnCapture;
  final bool extraTurnOnHome;

  /// A token needs the exact count to reach home.
  final bool exactRollToFinish;
  final LudoSafeSquares safeSquares;

  /// Two or more tokens of one colour on a square cannot be passed or
  /// landed on by opponents.
  final bool blockades;

  /// Keep playing for 2nd/3rd place instead of stopping at the first winner
  /// (ignored with [teams]: the first team home wins).
  final bool playUntilLast;

  /// Two or more tokens of one colour on a square cannot be captured, but
  /// may be passed and shared (implied by [blockades]).
  final bool safePairs;
  final LudoFirstPlayer firstPlayer;

  /// Rolls allowed per turn while none of the player's tokens is on the
  /// board (family rule: 3).
  final int yardRollAttempts;

  /// A 6 that no token can use still earns another roll.
  final bool bonusRollOnUnusableSix;

  /// A player's tokens may enter their home column only after that player
  /// has captured at least once; until then they keep lapping.
  final bool captureToEnterHome;

  /// Four players in partnerships 0+2 against 1+3: partners never capture
  /// or block each other, a player whose tokens are all home moves the
  /// partner's tokens, and the team wins when all eight are home.
  final bool teams;

  LudoConfig copyWith({
    int? players,
    int? tokensPerPlayer,
    List<int>? exitRolls,
    bool? extraTurnOnSix,
    int? maxConsecutiveSixes,
    bool? extraTurnOnCapture,
    bool? extraTurnOnHome,
    bool? exactRollToFinish,
    LudoSafeSquares? safeSquares,
    bool? blockades,
    bool? playUntilLast,
    bool? safePairs,
    LudoFirstPlayer? firstPlayer,
    int? yardRollAttempts,
    bool? bonusRollOnUnusableSix,
    bool? captureToEnterHome,
    bool? teams,
  }) => LudoConfig(
    players: players ?? this.players,
    tokensPerPlayer: tokensPerPlayer ?? this.tokensPerPlayer,
    exitRolls: exitRolls ?? this.exitRolls,
    extraTurnOnSix: extraTurnOnSix ?? this.extraTurnOnSix,
    maxConsecutiveSixes: maxConsecutiveSixes ?? this.maxConsecutiveSixes,
    extraTurnOnCapture: extraTurnOnCapture ?? this.extraTurnOnCapture,
    extraTurnOnHome: extraTurnOnHome ?? this.extraTurnOnHome,
    exactRollToFinish: exactRollToFinish ?? this.exactRollToFinish,
    safeSquares: safeSquares ?? this.safeSquares,
    blockades: blockades ?? this.blockades,
    playUntilLast: playUntilLast ?? this.playUntilLast,
    safePairs: safePairs ?? this.safePairs,
    firstPlayer: firstPlayer ?? this.firstPlayer,
    yardRollAttempts: yardRollAttempts ?? this.yardRollAttempts,
    bonusRollOnUnusableSix: bonusRollOnUnusableSix ?? this.bonusRollOnUnusableSix,
    captureToEnterHome: captureToEnterHome ?? this.captureToEnterHome,
    teams: teams ?? this.teams,
  );

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
    'safePairs': safePairs,
    'first': firstPlayer.name,
    'yardTries': yardRollAttempts,
    'unusableSixAgain': bonusRollOnUnusableSix,
    'mustCapture': captureToEnterHome,
    'teams': teams,
  };

  @override
  bool operator ==(Object other) => other is LudoConfig && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;

  @override
  String toString() => 'LudoConfig(${toJson()})';

  /// Board seat (colour) of [player].
  int seatOf(int player) => players == 2 ? player * 2 : player;

  /// Whether [a] and [b] play on the same side (themselves, or partners).
  bool allies(int a, int b) => a == b || (teams && a % 2 == b % 2);

  /// Whether pairs of one colour cannot be captured.
  bool get pairsAreSafe => safePairs || blockades;

  bool isSafe(int absolute) => switch (safeSquares) {
    LudoSafeSquares.none => false,
    LudoSafeSquares.startOnly => absolute % 13 == 0,
    LudoSafeSquares.startAndStars => absolute % 13 == 0 || absolute % 13 == 8,
  };
}

enum LudoMoveKind { roll, move, pass }

/// `move(t)` moves token `t` of [LudoState.movingPlayer] (the player to act,
/// or their partner once their own tokens are home in team play).
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
    this.yardTries = 0,
    List<bool>? captured,
    List<int> ranking = const [],
    this.result,
  }) : tokens = List.unmodifiable([for (final t in tokens) List<int>.unmodifiable(t)]),
       rng = List.unmodifiable(rng),
       captured = List.unmodifiable(captured ?? List<bool>.filled(config.players, false)),
       ranking = List.unmodifiable(ranking);

  /// A new game from [seed]; [config] defaults to the Jordanian rules.
  ///
  /// With [LudoFirstPlayer.random] the first player comes from a separate
  /// generator salted from [seed], so the dice stream is neither consumed
  /// nor correlated with the choice.
  factory LudoState.initial({int seed = 0, LudoConfig config = const LudoConfig()}) => LudoState(
    config: config,
    tokens: List.generate(config.players, (_) => List.filled(config.tokensPerPlayer, kLudoYard)),
    currentPlayer: config.firstPlayer == LudoFirstPlayer.random
        ? BoardRng(seed ^ 0x9E3779B9).nextInt(config.players)
        : 0,
    phase: LudoPhase.awaitingRoll,
    rng: BoardRng(seed).state,
  );

  factory LudoState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    final cap = json['captured'];
    return LudoState(
      config: LudoConfig.fromJson(jsonMap(json['config'])),
      tokens: [for (final t in json['tokens']! as List) intList(t)],
      currentPlayer: (json['player']! as num).toInt(),
      phase: LudoPhase.values.byName(json['phase']! as String),
      rng: intList(json['rng']),
      dice: (json['dice']! as num).toInt(),
      consecutiveSixes: (json['sixes']! as num).toInt(),
      yardTries: (json['tries'] as num?)?.toInt() ?? 0,
      captured: cap == null ? null : [for (final c in cap as List) c! as bool],
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

  /// Failed rolls so far this turn while no token was on the board (for
  /// [LudoConfig.yardRollAttempts]).
  final int yardTries;

  /// Per player: has captured at least once (for
  /// [LudoConfig.captureToEnterHome]).
  final List<bool> captured;

  /// Players who have brought every token home, in order.
  final List<int> ranking;
  @override
  final GameResult? result;

  @override
  int get playerCount => config.players;

  /// Whose tokens the current player moves: their own, or – in team play,
  /// once all of their own are home – their partner's.
  int get movingPlayer {
    final p = currentPlayer;
    if (config.teams && finished(p)) return (p + 2) % 4;
    return p;
  }

  /// Whether [progress] is on the shared track (lapping square included).
  static bool onTrack(int progress) => (progress >= 0 && progress <= kLudoLastTrack) || progress == kLudoBeforeStart;

  /// Absolute track square (0..51) of a token, or -1 when off the track.
  int absoluteSquare(int player, int progress) {
    if (progress == kLudoBeforeStart) return (13 * config.seatOf(player) + 51) % 52;
    if (progress < 0 || progress > kLudoLastTrack) return -1;
    return (13 * config.seatOf(player) + progress) % 52;
  }

  bool finished(int player) => tokens[player].every((t) => t == kLudoHome);

  /// Whether [player]'s side is done (with teams: both partners).
  bool sideFinished(int player) => finished(player) && (!config.teams || finished((player + 2) % 4));

  int tokensHome(int player) => tokens[player].where((t) => t == kLudoHome).length;

  /// Whether [player]'s tokens must keep lapping instead of entering home.
  bool mustLap(int player) => config.captureToEnterHome && !captured[player];

  LudoState copyWith({
    List<List<int>>? tokens,
    int? currentPlayer,
    LudoPhase? phase,
    List<int>? rng,
    int? dice,
    int? consecutiveSixes,
    int? yardTries,
    List<bool>? captured,
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
    yardTries: yardTries ?? this.yardTries,
    captured: captured ?? this.captured,
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
    if (yardTries != 0) 'tries': yardTries,
    if (captured.any((c) => c)) 'captured': captured,
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
    final base = 13 * cfg.seatOf(player);
    // Absolute shared squares entered, in order (the landing square last
    // when the token stays on the shared track).
    final path = <int>[];
    int target;
    if (from == kLudoYard) {
      if (!cfg.exitRolls.contains(roll)) return null;
      target = 0;
      path.add(base % 52);
    } else if (from == kLudoBeforeStart) {
      // Lapping past its own start: the next square is progress 0.
      target = roll - 1;
      for (var q = 0; q <= target; q++) {
        path.add((base + q) % 52);
      }
    } else if (from <= kLudoLastTrack && from + roll > kLudoLastTrack && s.mustLap(player)) {
      // No capture yet: the token may not turn into its column.
      final rel = from + roll; // 51..56
      for (var x = from + 1; x <= rel; x++) {
        path.add((base + x) % 52);
      }
      target = rel == 51 ? kLudoBeforeStart : rel - 52;
    } else {
      target = from + roll;
      if (target > kLudoHome) {
        if (cfg.exactRollToFinish) return null;
        target = kLudoHome;
      }
      for (var x = from + 1; x <= target && x <= kLudoLastTrack; x++) {
        path.add((base + x) % 52);
      }
    }
    if (cfg.blockades) {
      for (final sq in path) {
        if (_opponentBlock(s, player, sq)) return null;
      }
    }
    final captures = <int>[];
    if (LudoState.onTrack(target)) {
      final sq = s.absoluteSquare(player, target);
      if (!cfg.isSafe(sq)) {
        for (var o = 0; o < cfg.players; o++) {
          if (cfg.allies(o, player)) continue;
          final here = <int>[
            for (var i = 0; i < s.tokens[o].length; i++)
              if (s.absoluteSquare(o, s.tokens[o][i]) == sq) i,
          ];
          if (here.length >= 2 && cfg.pairsAreSafe) continue;
          for (final i in here) {
            captures
              ..add(o)
              ..add(i);
          }
        }
      }
    }
    return LudoStep(target, captures);
  }

  static bool _opponentBlock(LudoState s, int player, int sq) {
    for (var o = 0; o < s.config.players; o++) {
      if (s.config.allies(o, player)) continue;
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
    final q = state.movingPlayer;
    final moves = <LudoMove>[
      for (var t = 0; t < state.tokens[q].length; t++)
        if (stepFor(state, q, t, state.dice) != null) LudoMove.move(t),
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
    final cfg = state.config;
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
        if (!_forfeit(state)) {
          final q = state.movingPlayer;
          final noneOut = state.tokens[q].every((t) => t == kLudoYard || t == kLudoHome);
          // Family rule: more tries while every token is in the yard.
          if (noneOut && state.yardTries + 1 < cfg.yardRollAttempts) {
            return state.copyWith(phase: LudoPhase.awaitingRoll, dice: 0, yardTries: state.yardTries + 1);
          }
          // Option: an unusable 6 still earns another roll (the run of
          // sixes is kept, so the third one still ends the turn).
          if (state.dice == 6 && cfg.bonusRollOnUnusableSix && cfg.extraTurnOnSix) {
            return state.copyWith(phase: LudoPhase.awaitingRoll, dice: 0);
          }
        }
        return state.copyWith(
          phase: LudoPhase.awaitingRoll,
          currentPlayer: _nextPlayer(state, p, state.ranking),
          dice: 0,
          consecutiveSixes: 0,
          yardTries: 0,
        );
      case LudoMoveKind.move:
        final q = state.movingPlayer;
        final step = stepFor(state, q, move.token, state.dice) ?? (throw IllegalMoveException(move));
        final tokens = [for (final t in state.tokens) List<int>.of(t)];
        tokens[q][move.token] = step.target;
        for (var i = 0; i < step.captures.length; i += 2) {
          tokens[step.captures[i]][step.captures[i + 1]] = kLudoYard;
        }
        var captured = state.captured;
        if (step.captures.isNotEmpty && !captured[q]) captured = [...captured]..[q] = true;
        bool allHome(int x) => tokens[x].every((t) => t == kLudoHome);
        var ranking = state.ranking;
        GameResult? result;
        final bool done;
        if (cfg.teams) {
          done = allHome(p) && allHome((p + 2) % 4);
          if (done) {
            final team = [p % 2, p % 2 + 2];
            ranking = team;
            result = GameResult(
              winners: team,
              reason: GameEndReason.allTokensHome,
              ranking: team,
              scores: [for (final t in tokens) t.where((x) => x == kLudoHome).length],
            );
          }
        } else {
          done = allHome(p);
          if (done) ranking = [...ranking, p];
          final active = cfg.players - ranking.length;
          if (done && (!cfg.playUntilLast || active <= 1)) {
            if (cfg.playUntilLast) {
              ranking = [
                ...ranking,
                for (var x = 0; x < cfg.players; x++)
                  if (!ranking.contains(x)) x,
              ];
            }
            result = GameResult(
              winners: [ranking.first],
              reason: GameEndReason.allTokensHome,
              ranking: cfg.playUntilLast ? ranking : [ranking.first],
              scores: [for (final t in tokens) t.where((x) => x == kLudoHome).length],
            );
          }
        }
        // At most one extra roll per move, for a 6, a capture or reaching home.
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
          // A bonus roll that is not for a 6 breaks the run of sixes.
          consecutiveSixes: again && state.dice == 6 ? state.consecutiveSixes : 0,
          yardTries: 0,
          captured: captured,
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
