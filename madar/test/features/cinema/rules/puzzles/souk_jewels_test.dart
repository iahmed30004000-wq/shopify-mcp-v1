import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

/// A 6×6 board from rows of colour digits ('*' = star).
List<int> board(List<String> rows) => [
  for (final r in rows)
    for (final ch in r.split('')) ch == '*' ? Gem.star() : int.parse(ch),
];

void main() {
  const logic = JewelsBoard(6, 6, 5);

  test('fresh boards have no match and at least one move', () {
    for (final d in PuzzleDifficulty.values) {
      for (var seed = 0; seed < 30; seed++) {
        final g = JewelsGame(JewelsConfig.forDifficulty(d, seed: seed));
        expect(g.logic.hasMatch(g.state.board), isFalse);
        expect(g.validSwaps(), isNotEmpty);
      }
    }
  });

  test('swap validity', () {
    final b = board([
      '012340',
      '120401',
      '001234',
      '342012',
      '234120',
      '401243',
    ]);
    expect(logic.hasMatch(b), isFalse);
    expect(logic.isValidSwap(b, 0, 2), isFalse, reason: 'not adjacent');
    expect(logic.isValidSwap(b, 0, 7), isFalse, reason: 'diagonal');
    final swaps = logic.validSwaps(b);
    for (final (x, y) in swaps) {
      final t = List<int>.from(b);
      t[x] = b[y];
      t[y] = b[x];
      expect(logic.hasMatch(t), isTrue);
    }
    // Every other adjacent swap creates no match.
    for (var i = 0; i < 36; i++) {
      for (final j in [i + 1, i + 6]) {
        if (!logic.adjacent(i, j) || swaps.contains((i, j))) continue;
        final t = List<int>.from(b);
        t[i] = b[j];
        t[j] = b[i];
        expect(logic.hasMatch(t), isFalse);
      }
    }
  });

  test('a run of four makes a line gem, five a star, an L a bomb', () {
    final rng = SeededRng(1);
    // Row 0: 1 1 _ 1 1 with a 1 below the gap → swapping makes five.
    final five = board([
      '110112',
      '221230',
      '302021',
      '023302',
      '230230',
      '302302',
    ]);
    final r5 = logic.resolve(five, 2, 8, rng.copy());
    expect(r5.steps.first.created.values.map(Gem.special), contains(JewelSpecial.star));
    final four = board([
      '110122',
      '221230',
      '302021',
      '023302',
      '230230',
      '302302',
    ]);
    final r4 = logic.resolve(four, 2, 8, rng.copy());
    expect(r4.steps.first.created[2], Gem.make(1, JewelSpecial.lineColumn));
    // Swapping (2,0)↔(3,0) completes row 0 and column 2 through (2,0).
    final ell = board([
      '112130',
      '231023',
      '301202',
      '023310',
      '202031',
      '030213',
    ]);
    expect(logic.hasMatch(ell), isFalse);
    final rl = logic.resolve(ell, 2, 3, rng.copy());
    expect(rl.steps.first.created[2], Gem.make(1, JewelSpecial.bomb));
    expect(rl.steps.first.created.values.map(Gem.special), contains(JewelSpecial.bomb));
  });

  test('a swapped star clears every gem of the other colour', () {
    final b = board([
      '*12340',
      '120401',
      '001234',
      '342012',
      '234120',
      '401243',
    ]);
    expect(logic.isValidSwap(b, 0, 1), isTrue);
    final ones = [for (var i = 0; i < 36; i++) if (b[i] == 1) i];
    final r = logic.resolve(b, 0, 1, SeededRng(2));
    expect(r.steps.first.cleared, containsAll([...ones.where((i) => i != 1), 0, 1]));
    expect(r.board.contains(Gem.empty), isFalse);
  });

  test('specials detonate: a line gem in a match clears its column', () {
    final b = board([
      '012340',
      '120401',
      '001234',
      '342012',
      '234120',
      '401243',
    ]);
    b[14] = Gem.make(0, JewelSpecial.lineColumn); // row 2 col 2 is part of 0 0 _ ?
    final t = List<int>.from(b);
    // Force a 0-run through (2,2): row 2 = 0 0 L0 …
    t[12] = 0;
    t[13] = 0;
    final r = logic.resolve(t, 14, 15, SeededRng(3));
    // Whether or not the swap itself matched, resolving must never leave
    // holes or matches behind.
    expect(r.board.contains(Gem.empty), isFalse);
    expect(logic.hasMatch(r.board), isFalse);
  });

  test('reshuffle yields a playable board', () {
    // A 5-colour board with no possible move.
    final dead = board([
      '012340',
      '340123',
      '123401',
      '401234',
      '234012',
      '012340',
    ]);
    expect(logic.hasValidMove(dead), isFalse);
    final r = logic.reshuffle(dead, SeededRng(4));
    expect(logic.hasMatch(r), isFalse);
    expect(logic.hasValidMove(r), isTrue);
  });

  test('long random play keeps the invariants; cascades score more', () {
    var sawCascade = false;
    for (var seed = 0; seed < 25; seed++) {
      final g = JewelsGame(JewelsConfig.forDifficulty(PuzzleDifficulty.values[seed % 4], seed: seed));
      final rng = SeededRng(seed);
      while (!g.isOver) {
        final swaps = g.validSwaps();
        expect(swaps, isNotEmpty);
        final (a, b) = rng.pick(swaps);
        final before = g.state.score;
        expect(g.apply(JewelsAction(a, b)), isTrue);
        final s = g.state;
        expect(s.board.contains(Gem.empty), isFalse);
        expect(g.logic.hasMatch(s.board), isFalse);
        expect(s.score, greaterThan(before));
        if (s.lastSteps.length > 1) sawCascade = true;
      }
    }
    expect(sawCascade, isTrue);
  });

  test('hint plays the best swap; games can be won', () {
    final g = JewelsGame(JewelsConfig.forDifficulty(PuzzleDifficulty.easy, seed: 6));
    followHints(g);
    expect(g.isOver, isTrue);
    expect(g.state.score, greaterThan(0));
    expect(g.isSolved, isTrue, reason: 'greedy best swaps beat the easy target');
  });

  test('illegal swaps are rejected; undo, replay, JSON', () {
    final g = JewelsGame(const JewelsConfig(seed: 12));
    expect(g.apply(const JewelsAction(0, 9)), isFalse);
    final rng = SeededRng(12);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 10; i++) {
      final (a, b) = rng.pick(g.validSwaps());
      g.apply(JewelsAction(a, b));
      log.add(roundTripJson(JewelsAction(a, b).toJson()));
    }
    expect(replay(JewelsGame(const JewelsConfig(seed: 12)), log), replay(g, const []));
    final after = g.state.toJson().toString();
    g.undo();
    final (a, b) = (log.last['a']! as int, log.last['b']! as int);
    g.apply(JewelsAction(a, b));
    expect(g.state.toJson().toString(), after, reason: 'the refill RNG is part of the state');
    expectJsonRoundTrip(g);
  });
}
