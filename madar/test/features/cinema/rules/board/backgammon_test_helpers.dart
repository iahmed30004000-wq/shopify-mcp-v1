import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_rules.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

/// One isolated game (no match layer) of each variant.
const single = BackgammonConfig(matchTarget: 0);
const mahbusaSingle = BackgammonConfig(variant: TawlaVariant.mahbusa, matchTarget: 0);
const tawla31Single = BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0);

const step = BackgammonStep.new;
const bar = BackgammonStep.bar, off = BackgammonStep.off;

/// A position: [points] maps board index → signed count (player 0 > 0),
/// [pinned] maps board index → owner of a checker pinned there.
BackgammonState bg(
  Map<int, int> points, {
  Map<int, int> pinned = const {},
  List<int> bar = const [0, 0],
  List<int> off = const [0, 0],
  int player = 0,
  List<int> dice = const [3, 1],
  BackgammonPhase phase = BackgammonPhase.moving,
  BackgammonConfig config = single,
  List<int> rng = const [1, 2, 3, 4],
  List<int> matchScores = const [0, 0],
  int cubeValue = 1,
  int cubeOwner = -1,
}) {
  final p = List<int>.filled(24, 0);
  points.forEach((k, v) => p[k] = v);
  final pins = List<int>.filled(24, -1);
  pinned.forEach((k, v) => pins[k] = v);
  return BackgammonState(
    config: config,
    points: p,
    pinned: pins,
    bar: bar,
    off: off,
    currentPlayer: player,
    phase: phase,
    dice: phase == BackgammonPhase.moving ? dice : const [],
    rng: rng,
    matchScores: matchScores,
    cubeValue: cubeValue,
    cubeOwner: cubeOwner,
  );
}

/// Every checker accounted for, pins consistent with the variant.
void checkTawla(BackgammonState s) {
  var p0 = s.bar[0] + s.off[0], p1 = s.bar[1] + s.off[1];
  for (var i = 0; i < 24; i++) {
    final v = s.points[i];
    if (v > 0) p0 += v;
    if (v < 0) p1 -= v;
    final pin = s.pinned[i];
    if (pin == 0) {
      p0++;
      expect(v, lessThan(0), reason: 'a pinned checker of player 0 needs a pinner at $i');
    }
    if (pin == 1) {
      p1++;
      expect(v, greaterThan(0), reason: 'a pinned checker of player 1 needs a pinner at $i');
    }
  }
  expect(p0, 15);
  expect(p1, 15);
  expect(s.cubeValue, greaterThanOrEqualTo(1));
  if (s.config.variant != TawlaVariant.mahbusa) expect(s.pinned.every((o) => o == -1), isTrue);
  if (s.config.variant != TawlaVariant.sheshBesh) expect(s.bar, [0, 0]);
  expect(s.dice.length, s.phase == BackgammonPhase.moving ? 2 : 0);
  if (s.phase == BackgammonPhase.gameOver) expect(s.lastGame, isNotNull);
  if (s.result == null && s.config.target > 0) {
    expect(s.matchScores.every((x) => x < s.config.target), isTrue);
  }
}

/// Plays [initial] to the end (or [cap] plies) with [levels] per seat (null
/// = a uniformly random legal move), checking invariants, turn ownership
/// and a JSON round trip of every state.
BoardGameEngine<BackgammonState, BackgammonMove> playTawla(
  BackgammonState initial, {
  required int seed,
  List<AiLevel?> levels = const [null],
  AiBudget budget = const AiBudget.nodes(600),
  int cap = 6000,
  bool check = true,
}) {
  final engine = BoardGameEngine<BackgammonState, BackgammonMove>(backgammonRules, initial);
  final rng = BoardRng(seed * 7919 + 17);
  var plies = 0;
  while (!engine.isOver && plies < cap) {
    final state = engine.state;
    if (check) {
      checkTawla(state);
      expect(canonical(BackgammonState.fromJson(roundTrip(state.toJson()))), canonical(state));
      expect(engine.legalMoves(1 - state.currentPlayer), isEmpty);
    }
    final legal = engine.legalMoves();
    expect(legal, isNotEmpty);
    final level = levels[state.currentPlayer % levels.length];
    final move = level == null ? rng.pick(legal) : const BackgammonAi().chooseMove(state, level, rng, budget);
    expect(legal.contains(move) || backgammonRules.isLegal(state, move), isTrue, reason: '$move');
    engine.apply(move);
    plies++;
  }
  if (check) checkTawla(engine.state);
  return engine;
}
