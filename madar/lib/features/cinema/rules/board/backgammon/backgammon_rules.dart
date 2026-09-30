/// طاولة الزهر: شيش بيش / محبوسة / ٣١ – the three tawla games commonly played
/// in Jordan, on one engine.
///
/// * [TawlaVariant.sheshBesh] – شيش بيش (the default): the hitting game.
/// * [TawlaVariant.mahbusa] – محبوسة: all 15 checkers start on the own
///   24-point, landing on a lone opposing checker pins it.
/// * [TawlaVariant.tawla31] – ٣١ (واحد وثلاثين): the same start, any opposing
///   checker blocks a point, the first checker runs alone, rounds score the
///   loser's checkers left and the match goes to 31.
///
/// The `BackgammonConfig()` defaults are the Jordanian defaults
/// ([BackgammonConfig.jordan]): the opening winner rolls afresh, «مارس» = 2,
/// no triple, no cube, a match to 5 (31 for ٣١) whose later games are
/// started by the previous winner. See `RULES.md` §3 for every option.
///
/// Board indices 0..23 are the 24 points seen from player 0: index `i` is
/// player 0's point `i + 1`. Player 0 moves from index 23 towards 0 and bears
/// off from indices 0..5. Player 1 moves from 0 towards 23 and bears off
/// from 18..23 (in the parallel ٣١ layout he starts at index 11, runs
/// 11 → 0 → 23 and bears off from 12..17). `points[i] > 0` counts player 0's
/// free checkers, `< 0` player 1's; `pinned[i]` is the owner of a checker
/// pinned underneath (محبوسة), or -1.
///
/// Turn flow: `roll` (or `offerDouble` when the cube is on) → one `play` of
/// up to four steps (an empty play is the forced pass) → next player. A
/// double is answered with `take` or `drop`. When a game of a match ends the
/// phase is `gameOver` and the only move is `nextGame`.
library;

import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import 'backgammon_board.dart';

enum BackgammonPhase { awaitingRoll, moving, doubleOffered, gameOver }

/// The three games of the tawla board.
enum TawlaVariant { sheshBesh, mahbusa, tawla31 }

/// When a شيش بيش win counts triple.
enum TawlaTriple {
  /// Never: «مارس» (2) is the biggest win (Jordanian default).
  none,

  /// 3 when the loser has borne off nothing and has a checker on the bar.
  barOnly,

  /// 3 when the loser has borne off nothing and has a checker on the bar or
  /// in the winner's home board (international backgammon).
  standard,
}

/// Who starts game 2, 3, … of a match.
enum TawlaNextStarter {
  /// The previous game's winner rolls at once (after a void game: an
  /// opening roll).
  previousWinner,

  /// A new opening roll every game.
  openingRoll,
}

/// How a محبوسة game is scored.
enum MahbusaScoring {
  /// 1, or «مارس» 2 when the loser has borne off nothing.
  points,

  /// Historical: the loser's checkers left on the board; match to 31.
  checkersTo31,
}

/// The ٣١ starting layout.
enum Tawla31Layout {
  /// 15 each on the own 24-point, the stacks facing each other at one end,
  /// moving in opposite directions (like محبوسة).
  contrary,

  /// Fevga/Moultezim style: the stacks in diagonally opposite corners, both
  /// moving the same way round.
  parallel,
}

/// Where the ٣١ runner must arrive before the other checkers may move.
enum Tawla31RunnerTarget {
  /// The quadrant where the opponent's stack started: own pip ≤ 6
  /// (contrary) or ≤ 12 (parallel).
  opponentStartQuadrant,

  /// The opponent's half: own pip ≤ 12.
  opponentHalf,
}

/// Why one game (not the match) ended. The names match the shared
/// [GameEndReason] values where those exist; see [tawlaEndReason].
enum TawlaGameEnd {
  /// 1 point (× cube).
  bearOffSingle,

  /// «مارس»: the loser had borne off nothing.
  bearOffGammon,

  /// The triple win (option).
  bearOffBackgammon,

  /// A double was dropped: the cube value.
  doubleDeclined,

  /// محبوسة with `motherRule`: the opponent's last start-point checker is
  /// pinned and the winner's own start point is empty.
  motherPinned,

  /// ٣١ (or محبوسة `checkersTo31`): the loser's checkers left on the board.
  bearOffCount,

  /// Void: both players' last start-point checkers are pinned (E5).
  bothMothersPinned,

  /// Void: neither player can ever move again (E1).
  positionFrozen,

  /// Void: the turn cap was reached (E2, a bug guard).
  moveLimit;

  /// Void games score nothing and are replayed.
  bool get isVoid => this == bothMothersPinned || this == positionFrozen || this == moveLimit;
}

final Map<String, GameEndReason> _sharedReasons = GameEndReason.values.asNameMap();

/// The shared [GameEndReason] for a game end: the value with the same name
/// when `core/game_types.dart` has it, otherwise the nearest existing one.
GameEndReason tawlaEndReason(TawlaGameEnd end) =>
    _sharedReasons[end.name] ??
    switch (end) {
      TawlaGameEnd.bearOffSingle || TawlaGameEnd.bearOffCount => GameEndReason.bearOffSingle,
      TawlaGameEnd.bearOffGammon || TawlaGameEnd.motherPinned => GameEndReason.bearOffGammon,
      TawlaGameEnd.bearOffBackgammon => GameEndReason.bearOffBackgammon,
      TawlaGameEnd.doubleDeclined => GameEndReason.doubleDeclined,
      TawlaGameEnd.bothMothersPinned || TawlaGameEnd.positionFrozen => GameEndReason.noLegalMoves,
      TawlaGameEnd.moveLimit => GameEndReason.moveLimit,
    };

final class BackgammonConfig {
  const BackgammonConfig({
    this.variant = TawlaVariant.sheshBesh,
    this.openingRollIsFirstMove = false,
    this.nextGameStarter = TawlaNextStarter.previousWinner,
    this.matchTarget,
    this.gammons = true,
    this.triple = TawlaTriple.none,
    this.doublingCube = false,
    this.maxCube = 64,
    this.motherRule = false,
    this.mahbusaScoring = MahbusaScoring.points,
    this.layout31 = Tawla31Layout.contrary,
    this.runnerTarget = Tawla31RunnerTarget.opponentStartQuadrant,
    this.noFullPrime = false,
    this.maxTurns = 2000,
  }) : assert(!doublingCube || variant == TawlaVariant.sheshBesh, 'the cube is a شيش بيش option'),
       assert(matchTarget == null || matchTarget >= 0),
       assert(maxCube >= 1),
       assert(maxTurns > 0);

  /// Rejects what the constructor only asserts, so that a bad save cannot
  /// make a release build loop (a turn cap of 0 voids every game of a match).
  factory BackgammonConfig.fromJson(Map<String, Object?> json) {
    final variant = TawlaVariant.values.byName(json['variant']! as String);
    if (json['cube']! as bool && variant != TawlaVariant.sheshBesh) {
      throw const FormatException('the doubling cube is only for sheshBesh');
    }
    final target = (json['target'] as num?)?.toInt();
    final maxCube = (json['maxCube']! as num).toInt();
    final maxTurns = (json['maxTurns']! as num).toInt();
    if (target != null && target < 0) throw FormatException('negative match target', target);
    if (maxCube < 1) throw FormatException('maxCube below 1', maxCube);
    if (maxTurns < 1) throw FormatException('maxTurns below 1', maxTurns);
    return BackgammonConfig(
      variant: variant,
      openingRollIsFirstMove: json['openingMove']! as bool,
      nextGameStarter: TawlaNextStarter.values.byName(json['nextStarter']! as String),
      matchTarget: target,
      gammons: json['gammons']! as bool,
      triple: TawlaTriple.values.byName(json['triple']! as String),
      doublingCube: json['cube']! as bool,
      maxCube: maxCube,
      motherRule: json['motherRule']! as bool,
      mahbusaScoring: MahbusaScoring.values.byName(json['mahbusaScoring']! as String),
      layout31: Tawla31Layout.values.byName(json['layout31']! as String),
      runnerTarget: Tawla31RunnerTarget.values.byName(json['runnerTarget']! as String),
      noFullPrime: json['noFullPrime']! as bool,
      maxTurns: maxTurns,
    );
  }

  /// شيش بيش as commonly played in Jordan (= `BackgammonConfig()`).
  static const BackgammonConfig jordan = BackgammonConfig();

  /// محبوسة with the Jordanian defaults.
  static const BackgammonConfig mahbusa = BackgammonConfig(variant: TawlaVariant.mahbusa);

  /// ٣١ with the Jordanian defaults.
  static const BackgammonConfig tawla31 = BackgammonConfig(variant: TawlaVariant.tawla31);

  /// The engine's earlier default: international backgammon as a single
  /// game (the opening dice are the first move, the triple counts).
  static const BackgammonConfig international = BackgammonConfig(
    openingRollIsFirstMove: true,
    nextGameStarter: TawlaNextStarter.openingRoll,
    matchTarget: 0,
    triple: TawlaTriple.standard,
  );

  final TawlaVariant variant;

  /// false (Jordan): the opening roll only decides who starts, and that
  /// player then rolls both dice. true: he plays the two opening dice.
  final bool openingRollIsFirstMove;
  final TawlaNextStarter nextGameStarter;

  /// Points that win the match; 0 = a single game; null = the variant's
  /// default ([target]).
  final int? matchTarget;

  /// شيش بيش: «مارس» (the loser bore off nothing) counts 2.
  final bool gammons;

  /// شيش بيش: when a «مارس» counts 3 (needs [gammons]).
  final TawlaTriple triple;

  /// شيش بيش only: the doubling cube (off – coffee-house play has none).
  final bool doublingCube;

  /// The cube never goes above this (a double is refused when it would).
  final int maxCube;

  /// محبوسة: pinning the opponent's last start-point checker while one's own
  /// start point is empty wins a «مارس» at once.
  final bool motherRule;
  final MahbusaScoring mahbusaScoring;
  final Tawla31Layout layout31;
  final Tawla31RunnerTarget runnerTarget;

  /// ٣١: forbid a six-point block that no opposing checker has passed.
  final bool noFullPrime;

  /// Plays (passes included) after which a game is void (E2 bug guard).
  final int maxTurns;

  /// The match target in effect: [matchTarget], or 5 (31 for ٣١ and the
  /// count-scored محبوسة).
  int get target =>
      matchTarget ??
      (variant == TawlaVariant.tawla31 ||
              (variant == TawlaVariant.mahbusa && mahbusaScoring == MahbusaScoring.checkersTo31)
          ? 31
          : 5);

  /// Whether rounds score the loser's checkers left.
  bool get countScoring =>
      variant == TawlaVariant.tawla31 ||
      (variant == TawlaVariant.mahbusa && mahbusaScoring == MahbusaScoring.checkersTo31);

  bool get _parallel => variant == TawlaVariant.tawla31 && layout31 == Tawla31Layout.parallel;

  /// The movement rules of [variant].
  BgMode get mode => switch (variant) {
    TawlaVariant.sheshBesh => BgMode.sheshBesh,
    TawlaVariant.mahbusa => BgMode.mahbusa,
    TawlaVariant.tawla31 => BgMode(
      landing: BgLanding.block,
      parallel: _parallel,
      runnerTarget: _parallel || runnerTarget == Tawla31RunnerTarget.opponentHalf ? 12 : 6,
      noFullPrime: noFullPrime,
    ),
  };

  /// Board index of [player]'s own pip `1..24`.
  int indexOf(int player, int pip) {
    if (player == 0) return pip - 1;
    return _parallel ? (pip + 11) % 24 : 24 - pip;
  }

  /// [player]'s own pip number of board index `0..23`.
  int pipOf(int player, int index) {
    if (player == 0) return index + 1;
    return _parallel ? (index + 12) % 24 + 1 : 24 - index;
  }

  Map<String, Object?> toJson() => {
    'variant': variant.name,
    'openingMove': openingRollIsFirstMove,
    'nextStarter': nextGameStarter.name,
    'target': matchTarget,
    'gammons': gammons,
    'triple': triple.name,
    'cube': doublingCube,
    'maxCube': maxCube,
    'motherRule': motherRule,
    'mahbusaScoring': mahbusaScoring.name,
    'layout31': layout31.name,
    'runnerTarget': runnerTarget.name,
    'noFullPrime': noFullPrime,
    'maxTurns': maxTurns,
  };

  @override
  bool operator ==(Object other) => other is BackgammonConfig && _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  String get _key => toJson().toString();
}

/// One checker moved by one die.
final class BackgammonStep {
  const BackgammonStep(this.from, this.to, this.die);

  factory BackgammonStep.fromJson(List<Object?> json) =>
      BackgammonStep((json[0]! as num).toInt(), (json[1]! as num).toInt(), (json[2]! as num).toInt());

  /// [from] value for a checker entering from the bar.
  static const int bar = -1;

  /// [to] value for a checker borne off.
  static const int off = -2;

  final int from;
  final int to;
  final int die;

  List<int> toJson() => [from, to, die];

  @override
  bool operator ==(Object other) => other is BackgammonStep && other.from == from && other.to == to && other.die == die;

  @override
  int get hashCode => Object.hash(from, to, die);

  @override
  String toString() => '${from == bar ? 'bar' : from}/${to == off ? 'off' : to}($die)';
}

enum BackgammonMoveKind { roll, play, offerDouble, take, drop, nextGame }

final class BackgammonMove extends GameMove {
  const BackgammonMove._(this.kind, [this.steps = const []]);

  static const BackgammonMove roll = BackgammonMove._(BackgammonMoveKind.roll);
  static const BackgammonMove offerDouble = BackgammonMove._(BackgammonMoveKind.offerDouble);
  static const BackgammonMove take = BackgammonMove._(BackgammonMoveKind.take);
  static const BackgammonMove drop = BackgammonMove._(BackgammonMoveKind.drop);

  /// Starts the next game of a match.
  static const BackgammonMove nextGame = BackgammonMove._(BackgammonMoveKind.nextGame);

  /// A full play (empty = no legal move, the turn passes).
  factory BackgammonMove.play(List<BackgammonStep> steps) =>
      BackgammonMove._(BackgammonMoveKind.play, List.unmodifiable(steps));

  factory BackgammonMove.fromJson(Map<String, Object?> json) {
    final kind = BackgammonMoveKind.values.byName(json['kind']! as String);
    if (kind != BackgammonMoveKind.play) return BackgammonMove._(kind);
    return BackgammonMove.play([for (final s in json['steps']! as List) BackgammonStep.fromJson(s as List)]);
  }

  final BackgammonMoveKind kind;
  final List<BackgammonStep> steps;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (kind == BackgammonMoveKind.play) 'steps': [for (final s in steps) s.toJson()],
  };

  @override
  bool operator ==(Object other) => other is BackgammonMove && other.kind == kind && listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(steps));

  @override
  String toString() => kind == BackgammonMoveKind.play ? 'play$steps' : kind.name;
}

/// The last finished game of a match (for the UI's score sheet).
final class TawlaGameSummary {
  const TawlaGameSummary({required this.number, required this.winner, required this.points, required this.end});

  factory TawlaGameSummary.fromJson(Map<String, Object?> json) => TawlaGameSummary(
    number: (json['number']! as num).toInt(),
    winner: (json['winner'] as num?)?.toInt(),
    points: (json['points']! as num).toInt(),
    end: TawlaGameEnd.values.byName(json['end']! as String),
  );

  /// 1-based game number within the match.
  final int number;

  /// null for a void game (scores nothing, replayed).
  final int? winner;
  final int points;
  final TawlaGameEnd end;

  bool get isVoid => winner == null;

  Map<String, Object?> toJson() => {'number': number, 'winner': winner, 'points': points, 'end': end.name};

  @override
  bool operator ==(Object other) =>
      other is TawlaGameSummary &&
      other.number == number &&
      other.winner == winner &&
      other.points == points &&
      other.end == end;

  @override
  int get hashCode => Object.hash(number, winner, points, end);

  @override
  String toString() => 'Game $number: ${winner ?? 'void'} +$points (${end.name})';
}

final class BackgammonState extends GameState {
  BackgammonState({
    required this.config,
    required List<int> points,
    required List<int> bar,
    required List<int> off,
    required this.currentPlayer,
    required this.phase,
    required List<int> dice,
    required List<int> rng,
    List<int> pinned = const [],
    this.cubeValue = 1,
    this.cubeOwner = -1,
    List<int> openingRolls = const [],
    List<int> matchScores = const [0, 0],
    this.gameNumber = 1,
    this.turns = 0,
    this.lastGame,
    this.result,
  }) : points = List.unmodifiable(points),
       bar = List.unmodifiable(bar),
       off = List.unmodifiable(off),
       dice = List.unmodifiable(dice),
       rng = List.unmodifiable(rng),
       pinned = pinned.isEmpty ? _noPins : List.unmodifiable(pinned),
       openingRolls = List.unmodifiable(openingRolls),
       matchScores = List.unmodifiable(matchScores);

  static final List<int> _noPins = List.unmodifiable(List.filled(24, -1));

  /// A new match (its first game); the opening roll is made from [seed].
  factory BackgammonState.initial({int seed = 0, BackgammonConfig config = const BackgammonConfig()}) =>
      _newGame(config, BoardRng(seed), matchScores: const [0, 0], gameNumber: 1);

  /// The start of a game: the variant's layout, then either an opening roll
  /// (when [starter] is null) or [starter] to roll.
  static BackgammonState _newGame(
    BackgammonConfig config,
    BoardRng rng, {
    required List<int> matchScores,
    required int gameNumber,
    int? starter,
    TawlaGameSummary? lastGame,
  }) {
    final points = startingPoints(config);
    var phase = BackgammonPhase.awaitingRoll;
    var dice = const <int>[];
    final opening = <int>[];
    var first = starter ?? -1;
    if (starter == null) {
      int d0, d1;
      do {
        d0 = rng.rollDie();
        d1 = rng.rollDie();
        opening
          ..add(d0)
          ..add(d1);
      } while (d0 == d1);
      first = d0 > d1 ? 0 : 1;
      if (config.openingRollIsFirstMove) {
        phase = BackgammonPhase.moving;
        dice = [d0, d1];
      }
    }
    return BackgammonState(
      config: config,
      points: points,
      bar: const [0, 0],
      off: const [0, 0],
      currentPlayer: first,
      phase: phase,
      dice: dice,
      rng: rng.state,
      openingRolls: opening,
      matchScores: matchScores,
      gameNumber: gameNumber,
      lastGame: lastGame,
    );
  }

  /// The starting points of [config]'s variant.
  static List<int> startingPoints(BackgammonConfig config) {
    final points = List<int>.filled(24, 0);
    if (config.variant == TawlaVariant.sheshBesh) {
      // Each side: 2 on its 24-point, 5 on 13, 3 on 8, 5 on 6.
      for (final (pip, n) in const [(24, 2), (13, 5), (8, 3), (6, 5)]) {
        points[config.indexOf(0, pip)] = n;
        points[config.indexOf(1, pip)] = -n;
      }
    } else {
      points[config.indexOf(0, 24)] = 15;
      points[config.indexOf(1, 24)] = -15;
    }
    return points;
  }

  factory BackgammonState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    final last = json['last'];
    return BackgammonState(
      config: BackgammonConfig.fromJson(jsonMap(json['config'])),
      points: intList(json['points']),
      pinned: intList(json['pinned']),
      bar: intList(json['bar']),
      off: intList(json['off']),
      currentPlayer: (json['player']! as num).toInt(),
      phase: BackgammonPhase.values.byName(json['phase']! as String),
      dice: intList(json['dice']),
      rng: intList(json['rng']),
      cubeValue: (json['cube']! as num).toInt(),
      cubeOwner: (json['cubeOwner']! as num).toInt(),
      openingRolls: intList(json['opening']),
      matchScores: intList(json['match']),
      gameNumber: (json['game']! as num).toInt(),
      turns: (json['turns']! as num).toInt(),
      lastGame: last == null ? null : TawlaGameSummary.fromJson(jsonMap(last)),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final BackgammonConfig config;

  /// Free checkers per index: `> 0` player 0, `< 0` player 1.
  final List<int> points;

  /// Per index: the owner of a checker pinned under the other side's
  /// checkers (محبوسة), or -1.
  final List<int> pinned;
  final List<int> bar;
  final List<int> off;
  @override
  final int currentPlayer;
  final BackgammonPhase phase;

  /// The two dice of the current roll (a double is `[d, d]` = four moves).
  final List<int> dice;

  /// Game RNG state (dice).
  final List<int> rng;
  final int cubeValue;

  /// -1 = centred.
  final int cubeOwner;

  /// This game's opening roll attempts as pairs `[p0 die, p1 die, …]` (for
  /// animation); empty when the previous winner started without one.
  final List<int> openingRolls;

  /// Match points so far.
  final List<int> matchScores;

  /// 1-based number of the game in progress (or just finished).
  final int gameNumber;

  /// Plays made in this game (passes included; E2).
  final int turns;

  /// The last finished game, if any.
  final TawlaGameSummary? lastGame;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  bool get hasPins => !identical(pinned, _noPins) && pinned.any((o) => o >= 0);

  /// Pip count of [player] (bar = 25, pinned checkers included).
  int pipCount(int player) {
    var pips = bar[player] * 25;
    for (var i = 0; i < 24; i++) {
      final v = points[i];
      final mine = player == 0 ? (v > 0 ? v : 0) : (v < 0 ? -v : 0);
      final pin = pinned[i] == player ? 1 : 0;
      if (mine + pin > 0) pips += (mine + pin) * config.pipOf(player, i);
    }
    return pips;
  }

  /// Checkers of [player] currently pinned.
  int pinnedCount(int player) => pinned.where((o) => o == player).length;

  BackgammonState copyWith({
    List<int>? points,
    List<int>? pinned,
    List<int>? bar,
    List<int>? off,
    int? currentPlayer,
    BackgammonPhase? phase,
    List<int>? dice,
    List<int>? rng,
    int? cubeValue,
    int? cubeOwner,
    List<int>? matchScores,
    int? turns,
    TawlaGameSummary? lastGame,
    GameResult? result,
  }) => BackgammonState(
    config: config,
    points: points ?? this.points,
    pinned: pinned ?? this.pinned,
    bar: bar ?? this.bar,
    off: off ?? this.off,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    phase: phase ?? this.phase,
    dice: dice ?? this.dice,
    rng: rng ?? this.rng,
    cubeValue: cubeValue ?? this.cubeValue,
    cubeOwner: cubeOwner ?? this.cubeOwner,
    openingRolls: openingRolls,
    matchScores: matchScores ?? this.matchScores,
    gameNumber: gameNumber,
    turns: turns ?? this.turns,
    lastGame: lastGame ?? this.lastGame,
    result: result ?? this.result,
  );

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'points': points,
    if (hasPins) 'pinned': pinned,
    'bar': bar,
    'off': off,
    'player': currentPlayer,
    'phase': phase.name,
    'dice': dice,
    'rng': rng,
    'cube': cubeValue,
    'cubeOwner': cubeOwner,
    'opening': openingRolls,
    'match': matchScores,
    'game': gameNumber,
    'turns': turns,
    if (lastGame != null) 'last': lastGame!.toJson(),
    if (result != null) 'result': result!.toJson(),
  };
}

/// [player]'s view of [s] as a [BgBoard] (`a` = [player]).
BgBoard boardFor(BackgammonState s, int player) {
  final cfg = s.config;
  final mode = cfg.mode;
  final pins = mode.landing == BgLanding.pin;
  final a0 = Int8List(26), a1 = Int8List(26);
  final p0 = pins ? Int8List(26) : null, p1 = pins ? Int8List(26) : null;
  for (var i = 0; i < 24; i++) {
    final v = s.points[i];
    if (v > 0) a0[i + 1] = v;
    if (v < 0) a1[cfg.pipOf(1, i)] = -v;
    if (pins) {
      if (s.pinned[i] == 0) p0![i + 1] = 1;
      if (s.pinned[i] == 1) p1![cfg.pipOf(1, i)] = 1;
    }
  }
  a0[25] = s.bar[0];
  a1[25] = s.bar[1];
  a0[0] = s.off[0];
  a1[0] = s.off[1];
  return player == 0 ? BgBoard(a0, a1, mode: mode, pa: p0, pb: p1) : BgBoard(a1, a0, mode: mode, pa: p1, pb: p0);
}

final class BackgammonRules extends GameRules<BackgammonState, BackgammonMove> {
  const BackgammonRules();

  @override
  BoardGameId get id => BoardGameId.backgammon;

  bool canOfferDouble(BackgammonState s) =>
      s.config.doublingCube &&
      s.config.variant == TawlaVariant.sheshBesh &&
      s.phase == BackgammonPhase.awaitingRoll &&
      (s.cubeOwner == -1 || s.cubeOwner == s.currentPlayer) &&
      s.cubeValue * 2 <= s.config.maxCube;

  @override
  List<BackgammonMove> legalMoves(BackgammonState state) {
    if (state.isOver) return const [];
    switch (state.phase) {
      case BackgammonPhase.awaitingRoll:
        return [BackgammonMove.roll, if (canOfferDouble(state)) BackgammonMove.offerDouble];
      case BackgammonPhase.doubleOffered:
        return const [BackgammonMove.take, BackgammonMove.drop];
      case BackgammonPhase.gameOver:
        return const [BackgammonMove.nextGame];
      case BackgammonPhase.moving:
        final p = state.currentPlayer;
        final plays = generatePlays(boardFor(state, p), state.dice);
        return [for (final play in plays) BackgammonMove.play(publicSteps(state.config, p, play.from, play.dice))];
    }
  }

  /// A generated play's steps as board indices.
  static List<BackgammonStep> publicSteps(BackgammonConfig cfg, int player, List<int> from, List<int> dice) => [
    for (var i = 0; i < from.length; i++) _publicStep(cfg, player, from[i], dice[i]),
  ];

  static BackgammonStep _publicStep(BackgammonConfig cfg, int player, int f, int d) => BackgammonStep(
    f == 25 ? BackgammonStep.bar : cfg.indexOf(player, f),
    f - d < 1 ? BackgammonStep.off : cfg.indexOf(player, f - d),
    d,
  );

  static List<int> _allDice(List<int> dice) => dice[0] == dice[1] ? [dice[0], dice[0], dice[0], dice[0]] : [...dice];

  /// Replays [steps] for the mover; null when a step is illegal.
  static BgBoard? _simulate(BackgammonState s, List<BackgammonStep> steps) {
    final p = s.currentPlayer;
    final cfg = s.config;
    final board = boardFor(s, p);
    final dice = _allDice(s.dice);
    for (final step in steps) {
      final i = dice.indexOf(step.die);
      if (i < 0 || step.from < BackgammonStep.bar || step.from > 23) return null;
      final f = step.from == BackgammonStep.bar ? 25 : cfg.pipOf(p, step.from);
      final t = f - step.die;
      final expectedTo = t < 1 ? BackgammonStep.off : cfg.indexOf(p, t);
      if (step.to != expectedTo || !board.canMove(f, step.die)) return null;
      board.move(f, step.die);
      dice.removeAt(i);
    }
    return board;
  }

  /// Accepts any step order that reaches a legal play's final position.
  @override
  bool isLegal(BackgammonState state, BackgammonMove move) {
    if (state.isOver) return false;
    if (move.kind != BackgammonMoveKind.play || state.phase != BackgammonPhase.moving) {
      return legalMoves(state).contains(move);
    }
    final result = _simulate(state, move.steps);
    if (result == null) return false;
    final plays = generatePlays(boardFor(state, state.currentPlayer), state.dice);
    final full = diceCount(state.dice);
    final maxLen = effectiveLength(plays.first, full);
    final len = result.a[0] == 15 ? full : move.steps.length;
    if (len != maxLen) return false;
    final key = result.key;
    return plays.any((p) => p.result.key == key);
  }

  /// Steps that can come next after [partial] in some legal play – for a UI
  /// that moves one checker at a time.
  List<BackgammonStep> nextSteps(BackgammonState state, List<BackgammonStep> partial) {
    if (state.phase != BackgammonPhase.moving || state.isOver) return const [];
    final p = state.currentPlayer;
    final plays = generatePlays(boardFor(state, p), state.dice);
    final full = diceCount(state.dice);
    final target = effectiveLength(plays.first, full);
    final keys = {for (final play in plays) play.result.key};
    final board = _simulate(state, partial);
    if (board == null || board.a[0] == 15) return const [];
    final dice = _allDice(state.dice);
    for (final s in partial) {
      dice.remove(s.die);
    }
    final out = <BackgammonStep>{};
    // Depth-first over every order; a step is offered when some completion
    // reaches a legal final position with the full number of steps (or ends
    // the game, E4).
    bool completes(BgBoard b, List<int> left, int done) {
      if (b.a[0] == 15 || done == target) return keys.contains(b.key);
      for (final d in left.toSet()) {
        for (var f = 25; f >= 1; f--) {
          if (!b.canMove(f, d)) continue;
          final token = b.move(f, d);
          final rest = [...left]..remove(d);
          final ok = completes(b, rest, done + 1);
          b.undo(f, d, token);
          if (ok) return true;
        }
      }
      return false;
    }

    for (final d in dice.toSet()) {
      for (var f = 25; f >= 1; f--) {
        if (!board.canMove(f, d)) continue;
        final token = board.move(f, d);
        final rest = [...dice]..remove(d);
        if (completes(board, rest, partial.length + 1)) out.add(_publicStep(state.config, p, f, d));
        board.undo(f, d, token);
      }
    }
    return out.toList();
  }

  @override
  BackgammonState apply(BackgammonState state, BackgammonMove move) {
    final p = state.currentPlayer;
    final o = 1 - p;
    switch (move.kind) {
      case BackgammonMoveKind.roll:
        final rng = BoardRng.fromState(state.rng);
        final d1 = rng.rollDie(), d2 = rng.rollDie();
        return state.copyWith(phase: BackgammonPhase.moving, dice: [d1, d2], rng: rng.state);
      case BackgammonMoveKind.offerDouble:
        return state.copyWith(phase: BackgammonPhase.doubleOffered, currentPlayer: o);
      case BackgammonMoveKind.take:
        return state.copyWith(
          phase: BackgammonPhase.awaitingRoll,
          currentPlayer: o,
          cubeValue: state.cubeValue * 2,
          cubeOwner: p,
        );
      case BackgammonMoveKind.drop:
        return _finishGame(state, o, state.cubeValue, TawlaGameEnd.doubleDeclined);
      case BackgammonMoveKind.nextGame:
        final last = state.lastGame!;
        final starter = last.winner == null || state.config.nextGameStarter == TawlaNextStarter.openingRoll
            ? null
            : last.winner;
        return BackgammonState._newGame(
          state.config,
          BoardRng.fromState(state.rng),
          matchScores: state.matchScores,
          gameNumber: state.gameNumber + 1,
          starter: starter,
          lastGame: last,
        );
      case BackgammonMoveKind.play:
        final board = _simulate(state, move.steps) ?? (throw IllegalMoveException(move));
        final next = _fromBoard(state, board, p).copyWith(
          currentPlayer: o,
          phase: BackgammonPhase.awaitingRoll,
          dice: const [],
          turns: state.turns + 1,
        );
        final end = playEnd(
          state.config,
          board,
          cubeValue: state.cubeValue,
          turns: next.turns,
          passed: move.steps.isEmpty,
        );
        if (end == null) return next;
        final winner = switch (end.moverWon) {
          null => null,
          true => p,
          false => o,
        };
        return _finishGame(next, winner, end.points, end.end);
    }
  }

  /// Writes the mover's [board] back into absolute coordinates.
  static BackgammonState _fromBoard(BackgammonState s, BgBoard board, int mover) {
    final cfg = s.config;
    final abs = mover == 0 ? board : board.swapped(); // abs.a = player 0
    final pins = board.mode.landing == BgLanding.pin;
    final points = List<int>.filled(24, 0);
    final pinned = pins ? List<int>.filled(24, -1) : null;
    for (var n = 1; n <= 24; n++) {
      final i0 = cfg.indexOf(0, n), i1 = cfg.indexOf(1, n);
      points[i0] += abs.a[n];
      points[i1] -= abs.b[n];
      if (pins) {
        if (abs.pa[n] == 1) pinned![i0] = 0;
        if (abs.pb[n] == 1) pinned![i1] = 1;
      }
    }
    return s.copyWith(
      points: points,
      pinned: pinned,
      bar: [abs.a[25], abs.b[25]],
      off: [abs.a[0], abs.b[0]],
    );
  }

  /// How the game ends right after a play (null: it goes on). The end tests
  /// run in the spec's order (§5.4): 15 off, both mothers pinned, the mother
  /// rule, a frozen position after a pass ([passed]), the turn cap.
  ///
  /// [board] is the mover's view after the play and [turns] counts the plays
  /// of this game including it. `moverWon` is null for a void game. The AI
  /// uses this too, so it sees every way a game can end.
  static ({bool? moverWon, int points, TawlaGameEnd end})? playEnd(
    BackgammonConfig cfg,
    BgBoard board, {
    required int cubeValue,
    required int turns,
    bool passed = false,
  }) {
    if (board.a[0] == 15) {
      final (points, end) = winPoints(cfg, board, cubeValue);
      return (moverWon: true, points: points, end: end);
    }
    if (cfg.variant == TawlaVariant.mahbusa) {
      final myMother = board.pa[24] == 1, theirMother = board.pb[24] == 1;
      if (myMother && theirMother) return (moverWon: null, points: 0, end: TawlaGameEnd.bothMothersPinned);
      if (cfg.motherRule) {
        if (theirMother && board.a[24] == 0) {
          return (moverWon: true, points: _marsValue(cfg), end: TawlaGameEnd.motherPinned);
        }
        if (myMother && board.b[24] == 0) {
          return (moverWon: false, points: _marsValue(cfg), end: TawlaGameEnd.motherPinned);
        }
      }
    }
    if (passed && cfg.variant != TawlaVariant.sheshBesh && !hasAnyPlay(board) && !hasAnyPlay(board.swapped())) {
      return (moverWon: null, points: 0, end: TawlaGameEnd.positionFrozen);
    }
    if (turns >= cfg.maxTurns) return (moverWon: null, points: 0, end: TawlaGameEnd.moveLimit);
    return null;
  }

  static int _marsValue(BackgammonConfig cfg) => cfg.countScoring ? 15 : 2;

  /// Points and reason for the mover of [board] who has just borne off his
  /// 15th checker.
  static (int, TawlaGameEnd) winPoints(BackgammonConfig cfg, BgBoard board, int cubeValue) {
    final loser = board.b;
    if (cfg.countScoring) return (15 - loser[0], TawlaGameEnd.bearOffCount);
    if (loser[0] > 0) return (cubeValue, TawlaGameEnd.bearOffSingle);
    if (cfg.variant == TawlaVariant.mahbusa) return (2, TawlaGameEnd.bearOffGammon);
    if (!cfg.gammons) return (cubeValue, TawlaGameEnd.bearOffSingle);
    var triple = false;
    switch (cfg.triple) {
      case TawlaTriple.none:
        break;
      case TawlaTriple.barOnly:
        triple = loser[25] > 0;
      case TawlaTriple.standard:
        triple = loser[25] > 0;
        for (var m = 19; m <= 24; m++) {
          if (loser[m] > 0) triple = true;
        }
    }
    return triple ? (3 * cubeValue, TawlaGameEnd.bearOffBackgammon) : (2 * cubeValue, TawlaGameEnd.bearOffGammon);
  }

  /// Ends the current game: match bookkeeping (X1–X5).
  static BackgammonState _finishGame(BackgammonState s, int? winner, int points, TawlaGameEnd end) {
    final cfg = s.config;
    final summary = TawlaGameSummary(number: s.gameNumber, winner: winner, points: points, end: end);
    final scores = [...s.matchScores];
    if (winner != null) scores[winner] += points;
    GameResult? result;
    if (cfg.target <= 0) {
      result = winner == null
          ? GameResult.draw(tawlaEndReason(end), scores: const [0, 0])
          : GameResult(winners: [winner], reason: tawlaEndReason(end), scores: [0, 0]..[winner] = points);
    } else if (winner != null && scores[winner] >= cfg.target) {
      result = GameResult(winners: [winner], reason: GameEndReason.targetScoreReached, scores: scores);
    }
    return s.copyWith(
      phase: BackgammonPhase.gameOver,
      dice: const [],
      currentPlayer: winner ?? s.currentPlayer,
      matchScores: scores,
      lastGame: summary,
      result: result,
    );
  }

  @override
  BackgammonState stateFromJson(Map<String, Object?> json) => BackgammonState.fromJson(json);

  @override
  BackgammonMove moveFromJson(Map<String, Object?> json) => BackgammonMove.fromJson(json);
}

const backgammonRules = BackgammonRules();
