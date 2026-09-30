/// Backgammon – طاولة الزهر, the standard ("فرنجي") game.
///
/// Board indices 0..23 are the 24 points seen from player 0: index `i` is
/// player 0's point `i + 1`. Player 0 moves from index 23 towards 0 and bears
/// off from indices 0..5; player 1 moves from 0 towards 23 and bears off from
/// 18..23. `points[i] > 0` counts player 0's checkers, `< 0` player 1's.
///
/// Turn flow: `roll` (or `offerDouble` when the cube is enabled) → one
/// `play` of up to four steps (an empty play is the forced pass) → next
/// player. A double is answered by the opponent with `take` or `drop`.
/// The opening roll is automatic: each player rolls one die until they
/// differ; the higher die moves first using both dice (or, with
/// [BackgammonConfig.openingRollIsFirstMove] off, rolls afresh).
library;

import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

enum BackgammonPhase { awaitingRoll, moving, doubleOffered }

final class BackgammonConfig {
  const BackgammonConfig({
    this.doublingCube = false,
    this.gammons = true,
    this.backgammons = true,
    this.maxCube = 64,
    this.openingRollIsFirstMove = true,
  });

  factory BackgammonConfig.fromJson(Map<String, Object?> json) => BackgammonConfig(
    doublingCube: json['cube']! as bool,
    gammons: json['gammons']! as bool,
    backgammons: json['backgammons']! as bool,
    maxCube: (json['maxCube']! as num).toInt(),
    openingRollIsFirstMove: json['openingMove'] as bool? ?? true,
  );

  /// Enables the doubling cube (off by default – coffee-house play).
  final bool doublingCube;

  /// A win before the loser bears off any checker counts double (مارس).
  final bool gammons;

  /// …and triple when the loser still has a checker on the bar or in the
  /// winner's home board (requires [gammons]).
  final bool backgammons;
  final int maxCube;

  /// Standard: the higher opening die moves first using both opening dice.
  /// When false (a common house rule) the opening only decides who starts,
  /// and that player then rolls normally.
  final bool openingRollIsFirstMove;

  Map<String, Object?> toJson() => {
    'cube': doublingCube,
    'gammons': gammons,
    'backgammons': backgammons,
    'maxCube': maxCube,
    'openingMove': openingRollIsFirstMove,
  };
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

enum BackgammonMoveKind { roll, play, offerDouble, take, drop }

final class BackgammonMove extends GameMove {
  const BackgammonMove._(this.kind, [this.steps = const []]);

  static const BackgammonMove roll = BackgammonMove._(BackgammonMoveKind.roll);
  static const BackgammonMove offerDouble = BackgammonMove._(BackgammonMoveKind.offerDouble);
  static const BackgammonMove take = BackgammonMove._(BackgammonMoveKind.take);
  static const BackgammonMove drop = BackgammonMove._(BackgammonMoveKind.drop);

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
    this.cubeValue = 1,
    this.cubeOwner = -1,
    List<int> openingRolls = const [],
    this.result,
  }) : points = List.unmodifiable(points),
       bar = List.unmodifiable(bar),
       off = List.unmodifiable(off),
       dice = List.unmodifiable(dice),
       rng = List.unmodifiable(rng),
       openingRolls = List.unmodifiable(openingRolls);

  /// A new game; the opening roll is made from [seed].
  factory BackgammonState.initial({int seed = 0, BackgammonConfig config = const BackgammonConfig()}) {
    final points = List<int>.filled(24, 0);
    // Player 0: 2 on 24, 5 on 13, 3 on 8, 5 on 6 (indices 23, 12, 7, 5).
    points[23] = 2;
    points[12] = 5;
    points[7] = 3;
    points[5] = 5;
    // Player 1 mirrored.
    points[0] = -2;
    points[11] = -5;
    points[16] = -3;
    points[18] = -5;
    final rng = BoardRng(seed);
    final opening = <int>[];
    int d0, d1;
    do {
      d0 = rng.rollDie();
      d1 = rng.rollDie();
      opening
        ..add(d0)
        ..add(d1);
    } while (d0 == d1);
    return BackgammonState(
      config: config,
      points: points,
      bar: const [0, 0],
      off: const [0, 0],
      currentPlayer: d0 > d1 ? 0 : 1,
      phase: config.openingRollIsFirstMove ? BackgammonPhase.moving : BackgammonPhase.awaitingRoll,
      dice: config.openingRollIsFirstMove ? [d0, d1] : const [],
      rng: rng.state,
      openingRolls: opening,
    );
  }

  factory BackgammonState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    return BackgammonState(
      config: BackgammonConfig.fromJson(jsonMap(json['config'])),
      points: intList(json['points']),
      bar: intList(json['bar']),
      off: intList(json['off']),
      currentPlayer: (json['player']! as num).toInt(),
      phase: BackgammonPhase.values.byName(json['phase']! as String),
      dice: intList(json['dice']),
      rng: intList(json['rng']),
      cubeValue: (json['cube']! as num).toInt(),
      cubeOwner: (json['cubeOwner']! as num).toInt(),
      openingRolls: intList(json['opening']),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final BackgammonConfig config;
  final List<int> points;
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

  /// Opening roll attempts as pairs `[p0 die, p1 die, …]` (for animation).
  final List<int> openingRolls;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  /// Pip count of [player] (bar = 25).
  int pipCount(int player) {
    var pips = bar[player] * 25;
    for (var i = 0; i < 24; i++) {
      final v = points[i];
      if (player == 0 && v > 0) pips += v * (i + 1);
      if (player == 1 && v < 0) pips += -v * (24 - i);
    }
    return pips;
  }

  BackgammonState copyWith({
    List<int>? points,
    List<int>? bar,
    List<int>? off,
    int? currentPlayer,
    BackgammonPhase? phase,
    List<int>? dice,
    List<int>? rng,
    int? cubeValue,
    int? cubeOwner,
    GameResult? result,
  }) => BackgammonState(
    config: config,
    points: points ?? this.points,
    bar: bar ?? this.bar,
    off: off ?? this.off,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    phase: phase ?? this.phase,
    dice: dice ?? this.dice,
    rng: rng ?? this.rng,
    cubeValue: cubeValue ?? this.cubeValue,
    cubeOwner: cubeOwner ?? this.cubeOwner,
    openingRolls: openingRolls,
    result: result ?? this.result,
  );

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'points': points,
    'bar': bar,
    'off': off,
    'player': currentPlayer,
    'phase': phase.name,
    'dice': dice,
    'rng': rng,
    'cube': cubeValue,
    'cubeOwner': cubeOwner,
    'opening': openingRolls,
    if (result != null) 'result': result!.toJson(),
  };
}

/// A position seen from the player to move: `a` = mover, `b` = opponent.
/// Each array: `[0]` = borne off, `[1..24]` = own pip numbers, `[25]` = bar.
/// Opponent's pip `m` is the mover's pip `25 - m`.
final class BgBoard {
  BgBoard(this.a, this.b);

  factory BgBoard.fromState(BackgammonState s, int player) {
    final a = Int8List(26), b = Int8List(26);
    for (var i = 0; i < 24; i++) {
      final v = s.points[i];
      if (v > 0) a[i + 1] = v;
      if (v < 0) b[24 - i] = -v;
    }
    a[25] = s.bar[0];
    b[25] = s.bar[1];
    a[0] = s.off[0];
    b[0] = s.off[1];
    return player == 0 ? BgBoard(a, b) : BgBoard(b, a);
  }

  final Int8List a;
  final Int8List b;

  BgBoard copy() => BgBoard(Int8List.fromList(a), Int8List.fromList(b));
  BgBoard swapped() => BgBoard(b, a);

  bool allHome() {
    for (var n = 7; n <= 25; n++) {
      if (a[n] > 0) return false;
    }
    return true;
  }

  bool canMove(int f, int d) {
    if (a[f] == 0) return false;
    if (a[25] > 0 && f != 25) return false;
    final t = f - d;
    if (t >= 1) return b[25 - t] <= 1;
    if (!allHome()) return false;
    if (t == 0) return true;
    for (var q = f + 1; q <= 6; q++) {
      if (a[q] > 0) return false;
    }
    return true;
  }

  /// Moves one checker; returns true when it hit a blot.
  bool move(int f, int d) {
    final t = f - d;
    a[f]--;
    if (t < 1) {
      a[0]++;
      return false;
    }
    a[t]++;
    if (b[25 - t] == 1) {
      b[25 - t] = 0;
      b[25]++;
      return true;
    }
    return false;
  }

  void undo(int f, int d, bool hit) {
    final t = f - d;
    a[f]++;
    if (t < 1) {
      a[0]--;
      return;
    }
    a[t]--;
    if (hit) {
      b[25]--;
      b[25 - t] = 1;
    }
  }

  String get key => '${a.join(',')}|${b.join(',')}';

  int pips(Int8List side) {
    var p = 0;
    for (var n = 1; n <= 25; n++) {
      p += side[n] * n;
    }
    return p;
  }
}

/// A generated play: steps in the mover's pip coordinates plus the result.
final class BgPlay {
  BgPlay(this.from, this.dice, this.result);
  final List<int> from; // mover pips (25 = bar)
  final List<int> dice;
  final BgBoard result;
}

/// Generates all distinct plays for [dice] (positions deduplicated; for
/// doubles, checkers are moved in non-increasing pip order – every final
/// position is still reached).
List<BgPlay> generatePlays(BgBoard board, List<int> dice) {
  final work = board.copy();
  final plays = <String, BgPlay>{};
  var maxLen = 0;
  final isDouble = dice[0] == dice[1];
  final remaining = isDouble ? [dice[0], dice[0], dice[0], dice[0]] : [dice[0], dice[1]];
  final from = <int>[], used = <int>[];

  void dfs(int minFromCap) {
    var any = false;
    final tried = <int>{};
    for (var i = 0; i < remaining.length; i++) {
      final d = remaining[i];
      if (d == 0 || !tried.add(d)) continue;
      final top = work.a[25] > 0 ? 25 : (isDouble ? minFromCap : 24);
      for (var f = top; f >= 1; f--) {
        if (f < 25 && work.a[25] > 0) break;
        if (!work.canMove(f, d)) continue;
        any = true;
        final hit = work.move(f, d);
        remaining[i] = 0;
        from.add(f);
        used.add(d);
        dfs(isDouble ? f : 25);
        from.removeLast();
        used.removeLast();
        remaining[i] = d;
        work.undo(f, d, hit);
      }
    }
    if (!any && from.length >= maxLen) {
      if (from.length > maxLen) {
        maxLen = from.length;
        plays.clear();
      }
      // Single-step plays keep the die in the key so that the higher-die
      // rule below can still choose between equal positions.
      final key = from.length == 1 ? '${work.key}#${used.first}' : work.key;
      plays.putIfAbsent(key, () => BgPlay(List.of(from), List.of(used), work.copy()));
    }
  }

  dfs(25);
  var out = plays.values.toList();
  if (maxLen == 1 && !isDouble) {
    final high = dice[0] > dice[1] ? dice[0] : dice[1];
    final withHigh = [
      for (final p in out)
        if (p.dice.first == high) p,
    ];
    if (withHigh.isNotEmpty) out = withHigh;
    final seen = <String>{};
    out = [
      for (final p in out)
        if (seen.add(p.result.key)) p,
    ];
  }
  return out;
}

int _toIndex(int player, int pip) => player == 0 ? pip - 1 : 24 - pip;

final class BackgammonRules extends GameRules<BackgammonState, BackgammonMove> {
  const BackgammonRules();

  @override
  BoardGameId get id => BoardGameId.backgammon;

  bool canOfferDouble(BackgammonState s) =>
      s.config.doublingCube &&
      s.phase == BackgammonPhase.awaitingRoll &&
      (s.cubeOwner == -1 || s.cubeOwner == s.currentPlayer) &&
      s.cubeValue < s.config.maxCube;

  @override
  List<BackgammonMove> legalMoves(BackgammonState state) {
    if (state.isOver) return const [];
    switch (state.phase) {
      case BackgammonPhase.awaitingRoll:
        return [BackgammonMove.roll, if (canOfferDouble(state)) BackgammonMove.offerDouble];
      case BackgammonPhase.doubleOffered:
        return const [BackgammonMove.take, BackgammonMove.drop];
      case BackgammonPhase.moving:
        final p = state.currentPlayer;
        final plays = generatePlays(BgBoard.fromState(state, p), state.dice);
        return [for (final play in plays) BackgammonMove.play(_publicSteps(p, play.from, play.dice))];
    }
  }

  static List<BackgammonStep> _publicSteps(int player, List<int> from, List<int> dice) => [
    for (var i = 0; i < from.length; i++)
      BackgammonStep(
        from[i] == 25 ? BackgammonStep.bar : _toIndex(player, from[i]),
        from[i] - dice[i] < 1 ? BackgammonStep.off : _toIndex(player, from[i] - dice[i]),
        dice[i],
      ),
  ];

  static int _toPip(int player, int index) => index == BackgammonStep.bar ? 25 : (player == 0 ? index + 1 : 24 - index);

  /// Replays [steps] for the mover; null when a step is illegal.
  static BgBoard? _simulate(BackgammonState s, List<BackgammonStep> steps) {
    final p = s.currentPlayer;
    final board = BgBoard.fromState(s, p);
    final dice = s.dice[0] == s.dice[1] ? [s.dice[0], s.dice[0], s.dice[0], s.dice[0]] : [...s.dice];
    for (final step in steps) {
      final i = dice.indexOf(step.die);
      if (i < 0 || step.from < BackgammonStep.bar || step.from > 23) return null;
      final f = _toPip(p, step.from);
      final t = f - step.die;
      final expectedTo = t < 1 ? BackgammonStep.off : _toIndex(p, t);
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
    final plays = generatePlays(BgBoard.fromState(state, state.currentPlayer), state.dice);
    final key = result.key;
    return plays.any((p) => p.from.length == move.steps.length && p.result.key == key);
  }

  /// Steps that can come next after [partial] in some legal play – for a UI
  /// that moves one checker at a time.
  List<BackgammonStep> nextSteps(BackgammonState state, List<BackgammonStep> partial) {
    if (state.phase != BackgammonPhase.moving || state.isOver) return const [];
    final p = state.currentPlayer;
    final plays = generatePlays(BgBoard.fromState(state, p), state.dice);
    if (plays.isEmpty) return const [];
    final target = plays.first.from.length;
    final keys = {for (final play in plays) play.result.key};
    final board = _simulate(state, partial);
    if (board == null) return const [];
    final dice = state.dice[0] == state.dice[1] ? List.filled(4, state.dice[0]) : [...state.dice];
    for (final s in partial) {
      dice.remove(s.die);
    }
    final out = <BackgammonStep>{};
    // Depth-first over every order; a step is offered when some completion
    // reaches a legal final position with the full number of steps.
    bool completes(BgBoard b, List<int> left, int done) {
      if (done == target) return keys.contains(b.key);
      for (final d in left.toSet()) {
        for (var f = 25; f >= 1; f--) {
          if (!b.canMove(f, d)) continue;
          final hit = b.move(f, d);
          final rest = [...left]..remove(d);
          final ok = completes(b, rest, done + 1);
          b.undo(f, d, hit);
          if (ok) return true;
        }
      }
      return false;
    }

    for (final d in dice.toSet()) {
      for (var f = 25; f >= 1; f--) {
        if (!board.canMove(f, d)) continue;
        final hit = board.move(f, d);
        final rest = [...dice]..remove(d);
        if (completes(board, rest, partial.length + 1)) {
          out.add(
            BackgammonStep(
              f == 25 ? BackgammonStep.bar : _toIndex(p, f),
              f - d < 1 ? BackgammonStep.off : _toIndex(p, f - d),
              d,
            ),
          );
        }
        board.undo(f, d, hit);
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
        final scores = [0, 0]..[o] = state.cubeValue;
        return state.copyWith(
          result: GameResult(winners: [o], reason: GameEndReason.doubleDeclined, scores: scores),
        );
      case BackgammonMoveKind.play:
        final board = _simulate(state, move.steps) ?? (throw IllegalMoveException(move));
        final abs = p == 0 ? board : board.swapped(); // abs.a = player 0
        final points = List<int>.filled(24, 0);
        for (var n = 1; n <= 24; n++) {
          points[n - 1] += abs.a[n];
          points[24 - n] -= abs.b[n];
        }
        final bar = [abs.a[25], abs.b[25]];
        final off = [abs.a[0], abs.b[0]];
        GameResult? result;
        if (off[p] == 15) result = _winResult(state, board, p);
        return state.copyWith(
          points: points,
          bar: bar,
          off: off,
          currentPlayer: result == null ? o : p,
          phase: BackgammonPhase.awaitingRoll,
          dice: const [],
          result: result,
        );
    }
  }

  GameResult _winResult(BackgammonState s, BgBoard mover, int winner) {
    final loser = mover.b;
    var multiplier = 1;
    var reason = GameEndReason.bearOffSingle;
    if (loser[0] == 0 && s.config.gammons) {
      multiplier = 2;
      reason = GameEndReason.bearOffGammon;
      if (s.config.backgammons) {
        var inWinnerHome = loser[25] > 0;
        for (var m = 19; m <= 24; m++) {
          if (loser[m] > 0) inWinnerHome = true;
        }
        if (inWinnerHome) {
          multiplier = 3;
          reason = GameEndReason.bearOffBackgammon;
        }
      }
    }
    final scores = [0, 0]..[winner] = multiplier * s.cubeValue;
    return GameResult(winners: [winner], reason: reason, scores: scores);
  }

  @override
  BackgammonState stateFromJson(Map<String, Object?> json) => BackgammonState.fromJson(json);

  @override
  BackgammonMove moveFromJson(Map<String, Object?> json) => BackgammonMove.fromJson(json);
}

const backgammonRules = BackgammonRules();
