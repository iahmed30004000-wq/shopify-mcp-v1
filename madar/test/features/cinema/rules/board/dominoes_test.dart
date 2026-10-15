import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

Domino d(int a, int b) => Domino.of(a, b);

/// A state with explicit hands; the rest of the double-six set goes to the
/// boneyard unless [boneyard] is given.
DominoState dom(
  List<List<Domino>> hands, {
  List<PlacedDomino> line = const [],
  List<Domino>? boneyard,
  int player = 0,
  DominoConfig config = const DominoConfig(targetScore: 0),
  List<int>? scores,
  List<int>? voids,
}) {
  final used = {for (final h in hands) ...h, for (final p in line) p.tile};
  return DominoState(
    config: config,
    hands: hands,
    boneyard:
        boneyard ??
        [
          for (final t in Domino.doubleSix)
            if (!used.contains(t)) t,
        ],
    line: line,
    currentPlayer: player,
    phase: DominoPhase.playing,
    scores: scores ?? List.filled(config.sides, 0),
    voids: voids ?? List.filled(config.players, 0),
    rng: const [5, 6, 7, 8],
  );
}

void main() {
  const rules = dominoRules;

  test('tiles, ids and pips', () {
    expect(Domino.doubleSix, hasLength(28));
    for (var i = 0; i < 28; i++) {
      expect(Domino.fromId(i).id, i);
    }
    expect(d(6, 2), const Domino(2, 6));
    expect(d(6, 6).isDouble, isTrue);
    expect(d(3, 5).pips, 8);
  });

  test('dealing and the opening double', () {
    for (final players in [2, 3, 4]) {
      final s = DominoState.initial(
        seed: players,
        config: DominoConfig(players: players),
      );
      checkInvariants(s);
      expect(s.hands.every((h) => h.length == 7), isTrue);
      expect(s.boneyard, hasLength(28 - 7 * players));
      final legal = rules.legalMoves(s);
      expect(legal, hasLength(1));
      expect(legal.single.tile, s.mustLead);
      expect(s.hands[s.currentPlayer], contains(s.mustLead));
      if (players == 4) expect(s.mustLead, d(6, 6));
    }
  });

  test('matching ends and orientation', () {
    var s = dom([
      [d(6, 6), d(6, 3), d(1, 1)],
      [d(6, 2), d(0, 0), d(4, 4)],
    ]);
    s = rules.apply(s, DominoMove.play(d(6, 6), DominoEnd.left));
    expect(s.currentPlayer, 1);
    expect(rules.legalMoves(s).toSet(), {
      DominoMove.play(d(6, 2), DominoEnd.left),
      DominoMove.play(d(6, 2), DominoEnd.right),
    });
    s = rules.apply(s, DominoMove.play(d(6, 2), DominoEnd.right));
    expect((s.leftEnd, s.rightEnd), (6, 2));
    s = rules.apply(s, DominoMove.play(d(6, 3), DominoEnd.left));
    expect((s.leftEnd, s.rightEnd), (3, 2));
    expect([for (final p in s.line) '${p.left}${p.right}'], ['36', '66', '62']);
  });

  test('draw until able, then pass when the boneyard is empty; voids are public', () {
    final line = [PlacedDomino(d(5, 5), 5, 5)];
    var s = dom(
      [
        [d(0, 1)],
        [d(2, 2)],
      ],
      line: line,
      boneyard: [d(0, 5), d(3, 4)],
    );
    expect(rules.legalMoves(s), [DominoMove.draw]);
    s = rules.apply(s, DominoMove.draw); // draws 3-4 (last)
    expect(s.hands[0], contains(d(3, 4)));
    expect(s.voids[0], 1 << 5);
    expect(rules.legalMoves(s), [DominoMove.draw]);
    s = rules.apply(s, DominoMove.draw); // draws 0-5: now playable
    expect(rules.legalMoves(s), contains(DominoMove.play(d(0, 5), DominoEnd.left)));
    s = rules.apply(s, DominoMove.play(d(0, 5), DominoEnd.right));
    expect(rules.legalMoves(s), [DominoMove.pass]); // player 1: nothing, empty boneyard
    s = rules.apply(s, DominoMove.pass);
    expect(s.voids[1], (1 << 5) | (1 << 0));
  });

  test('block game: no drawing', () {
    final s = dom(
      [
        [d(0, 1)],
        [d(2, 2)],
      ],
      line: [PlacedDomino(d(5, 5), 5, 5)],
      config: const DominoConfig(drawFromBoneyard: false, targetScore: 0),
    );
    expect(rules.legalMoves(s), [DominoMove.pass]);
  });

  test('going out scores every opponent pip', () {
    final s = dom(
      [
        [d(6, 1)],
        [d(4, 4), d(0, 2)],
        [d(3, 3)],
      ],
      line: [PlacedDomino(d(6, 6), 6, 6)],
      config: const DominoConfig(players: 3, targetScore: 0),
    );
    final end = rules.apply(s, DominoMove.play(d(6, 1), DominoEnd.left));
    expect(end.lastRound?.end, DominoRoundEnd.domino);
    expect(end.lastRound?.winner, 0);
    expect(end.lastRound?.points, 8 + 2 + 6);
    expect(end.result, const GameResult(winners: [0], reason: GameEndReason.targetScoreReached, scores: [16, 0, 0]));
  });

  test('blocked round: lowest count wins, a tie scores nothing', () {
    DominoState blocked(List<List<Domino>> hands) {
      var s = dom(
        hands,
        line: [PlacedDomino(d(5, 5), 5, 5)],
        boneyard: const [],
        config: const DominoConfig(targetScore: 0),
      );
      s = rules.apply(s, DominoMove.pass);
      return rules.apply(s, DominoMove.pass);
    }

    final win = blocked([
      [d(0, 1)],
      [d(6, 6)],
    ]);
    expect(win.lastRound?.end, DominoRoundEnd.blocked);
    expect(win.lastRound?.winner, 0);
    expect(win.lastRound?.points, 12);
    expect(win.result?.winners, [0]);
    final tie = blocked([
      [d(0, 3)],
      [d(1, 2)],
    ]);
    expect(tie.lastRound?.winner, isNull);
    expect(tie.result?.isDraw, isTrue);
  });

  test('partnerships: partners share a score and their pips are not counted', () {
    final s = dom(
      [
        [d(6, 1)],
        [d(4, 4)],
        [d(3, 3)],
        [d(2, 2)],
      ],
      line: [PlacedDomino(d(6, 6), 6, 6)],
      config: const DominoConfig(players: 4, teams: true, targetScore: 0),
    );
    final end = rules.apply(s, DominoMove.play(d(6, 1), DominoEnd.left));
    expect(end.lastRound?.points, 8 + 4);
    expect(end.scores, [12, 0]);
    expect(end.result?.winners, [0, 2]);
    expect(end.result?.scores, [12, 0, 12, 0]);
  });

  test('match play: rounds continue until the target, the winner leads next', () {
    final cfg = const DominoConfig(targetScore: 20);
    final s = dom(
      [
        [d(6, 1)],
        [d(4, 4)],
      ],
      line: [PlacedDomino(d(6, 6), 6, 6)],
      config: cfg,
    );
    final end = rules.apply(s, DominoMove.play(d(6, 1), DominoEnd.left));
    expect(end.isOver, isFalse);
    expect(end.phase, DominoPhase.roundOver);
    expect(end.scores, [8, 0]);
    expect(rules.legalMoves(end), [DominoMove.nextRound]);
    final next = rules.apply(end, DominoMove.nextRound);
    expect(next.round, 2);
    expect(next.currentPlayer, 0);
    expect(next.mustLead, isNull);
    expect(next.scores, [8, 0]);
    expect(rules.legalMoves(next), hasLength(7)); // any tile may lead
    checkInvariants(next);
    final won = rules.apply(
      dom(
        [
          [d(6, 1)],
          [d(4, 4), d(6, 6)],
        ],
        line: [PlacedDomino(d(6, 5), 6, 5)],
        config: cfg,
        scores: [10, 5],
      ),
      DominoMove.play(d(6, 1), DominoEnd.left),
    );
    expect(won.result, const GameResult(winners: [0], reason: GameEndReason.targetScoreReached, scores: [30, 5]));
  });

  test('the AI only uses public information', () {
    // Same public view, hidden tiles distributed differently.
    final mine = [d(6, 6), d(6, 1), d(2, 3), d(0, 4)];
    final line = [PlacedDomino(d(1, 1), 1, 1)];
    final others = [
      for (final t in Domino.doubleSix)
        if (!mine.contains(t) && t != d(1, 1)) t,
    ];
    final a = dom([mine, others.sublist(0, 5)], line: line, boneyard: others.sublist(5));
    final b = dom([mine, others.sublist(18)], line: line, boneyard: others.sublist(0, 18));
    expect(a.hands[1].length, b.hands[1].length);
    for (final level in AiLevel.values) {
      expect(
        const DominoAi().chooseMove(a, level, BoardRng(4), const AiBudget.nodes(3000)),
        const DominoAi().chooseMove(b, level, BoardRng(4), const AiBudget.nodes(3000)),
        reason: level.name,
      );
    }
  });

  test('medium sheds the heavy double', () {
    final s = dom(
      [
        [d(6, 6), d(1, 6), d(0, 2)],
        [d(3, 3), d(4, 4)],
      ],
      line: [PlacedDomino(d(5, 6), 5, 6)],
    );
    expect(const DominoAi().chooseMove(s, AiLevel.medium, BoardRng(1)).tile, d(6, 6));
  });
}
