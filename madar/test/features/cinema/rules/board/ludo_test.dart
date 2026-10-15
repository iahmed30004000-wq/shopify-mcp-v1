import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

LudoState ludo(
  List<List<int>> tokens, {
  int player = 0,
  int dice = 0,
  int sixes = 0,
  LudoConfig? config,
  List<int> ranking = const [],
}) => LudoState(
  config: config ?? LudoConfig(players: tokens.length),
  tokens: tokens,
  currentPlayer: player,
  phase: dice == 0 ? LudoPhase.awaitingRoll : LudoPhase.awaitingMove,
  rng: const [1, 2, 3, 4],
  dice: dice,
  consecutiveSixes: sixes,
  ranking: ranking,
);

const y = kLudoYard;

void main() {
  const rules = ludoRules;

  test('seats: two players sit opposite', () {
    final s = LudoState.initial(config: const LudoConfig(players: 2));
    expect(s.config.seatOf(0), 0);
    expect(s.config.seatOf(1), 2);
    expect(s.absoluteSquare(1, 0), 26);
    expect(s.absoluteSquare(0, 51), -1); // home column
    expect(rules.legalMoves(s), [LudoMove.roll]);
  });

  test('a six is needed to leave the yard', () {
    final s = ludo([
      [y, y, y, y],
      [y, y, y, y],
    ], dice: 5);
    expect(rules.legalMoves(s), [LudoMove.pass]);
    final six = ludo(
      [
        [y, y, y, y],
        [y, y, y, y],
      ],
      dice: 6,
      sixes: 1,
    );
    expect(rules.legalMoves(six), hasLength(4));
    final out = rules.apply(six, const LudoMove.move(0));
    expect(out.tokens[0][0], 0);
    expect(out.currentPlayer, 0); // six → roll again
    expect(out.phase, LudoPhase.awaitingRoll);
    // House rule: 1 also releases.
    final one = ludo(
      [
        [y, y, y, y],
        [y, y, y, y],
      ],
      dice: 1,
      config: const LudoConfig(players: 2, exitRolls: [1, 6]),
    );
    expect(rules.legalMoves(one), hasLength(4));
  });

  test('capture sends the victim home and grants another roll', () {
    // Player 1 (seat 2) token at relative 30 → absolute 4; player 0 at 1.
    final s = ludo([
      [1, y, y, y],
      [30, y, y, y],
    ], dice: 3);
    final after = rules.apply(s, const LudoMove.move(0));
    expect(after.tokens[1][0], y);
    expect(after.tokens[0][0], 4);
    expect(after.currentPlayer, 0);
  });

  test('safe squares protect', () {
    // Absolute 8 is a star: player 1 at relative 34 (seat 2 → 26+34=60→8).
    final s = ludo([
      [5, y, y, y],
      [34, y, y, y],
    ], dice: 3);
    final after = rules.apply(s, const LudoMove.move(0));
    expect(after.tokens[1][0], 34);
    expect(after.currentPlayer, 1);
    final unsafe = ludo(
      [
        [5, y, y, y],
        [34, y, y, y],
      ],
      dice: 3,
      config: const LudoConfig(players: 2, safeSquares: LudoSafeSquares.none),
    );
    expect(rules.apply(unsafe, const LudoMove.move(0)).tokens[1][0], y);
  });

  test('home column and the exact roll', () {
    final s = ludo([
      [48, 53, y, y],
      [y, y, y, y],
    ], dice: 4);
    expect(rules.legalMoves(s), [const LudoMove.move(0)]); // 53 + 4 > 56
    expect(rules.apply(s, const LudoMove.move(0)).tokens[0][0], 52);
    final exact = ludo([
      [53, y, y, y],
      [y, y, y, y],
    ], dice: 3);
    final home = rules.apply(exact, const LudoMove.move(0));
    expect(home.tokens[0][0], kLudoHome);
    expect(home.currentPlayer, 0); // reaching home: roll again
    final loose = ludo(
      [
        [53, y, y, y],
        [y, y, y, y],
      ],
      dice: 5,
      config: const LudoConfig(players: 2, exactRollToFinish: false),
    );
    expect(rules.apply(loose, const LudoMove.move(0)).tokens[0][0], kLudoHome);
  });

  test('three sixes in a row forfeit the turn', () {
    final s = ludo(
      [
        [10, y, y, y],
        [y, y, y, y],
      ],
      dice: 6,
      sixes: 3,
    );
    expect(rules.legalMoves(s), [LudoMove.pass]);
    final next = rules.apply(s, LudoMove.pass);
    expect(next.currentPlayer, 1);
    expect(next.consecutiveSixes, 0);
    // Rolling tracks the streak.
    var r = ludo([
      [10, y, y, y],
      [y, y, y, y],
    ]);
    r = rules.apply(r, LudoMove.roll);
    expect(r.consecutiveSixes, r.dice == 6 ? 1 : 0);
  });

  test('blockades (house rule) cannot be passed', () {
    const cfg = LudoConfig(players: 2, blockades: true);
    // Player 1 has two tokens on absolute 3 (relative 29 for seat 2).
    final s = ludo(
      [
        [1, y, y, y],
        [29, 29, y, y],
      ],
      dice: 4,
      config: cfg,
    );
    expect(rules.legalMoves(s), [LudoMove.pass]);
    final without = ludo([
      [1, y, y, y],
      [29, 29, y, y],
    ], dice: 4);
    expect(rules.legalMoves(without), [const LudoMove.move(0)]);
  });

  test('winning, and playing on for places', () {
    final s = ludo([
      [53, 56, 56, 56],
      [y, y, y, y],
    ], dice: 3);
    final end = rules.apply(s, const LudoMove.move(0));
    expect(end.result?.winners, [0]);
    expect(end.result?.reason, GameEndReason.allTokensHome);
    const cfg = LudoConfig(players: 3, playUntilLast: true);
    final three = ludo(
      [
        [53, 56, 56, 56],
        [y, y, y, y],
        [10, y, y, y],
      ],
      dice: 3,
      config: cfg,
    );
    final first = rules.apply(three, const LudoMove.move(0));
    expect(first.isOver, isFalse);
    expect(first.ranking, [0]);
    expect(first.currentPlayer, 1);
  });

  test('AI: hard captures when it can, easy stays legal', () {
    final s = ludo([
      [1, 20, y, y],
      [30, y, y, y],
    ], dice: 3);
    expect(const LudoAi().chooseMove(s, AiLevel.hard, BoardRng(1)), const LudoMove.move(0));
    expect(const LudoAi().chooseMove(s, AiLevel.medium, BoardRng(1)), const LudoMove.move(0));
    expect(rules.legalMoves(s), contains(const LudoAi().chooseMove(s, AiLevel.easy, BoardRng(1))));
  });
}
