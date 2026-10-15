import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  test('boards hold each star exactly twice', () {
    for (final d in PuzzleDifficulty.values) {
      final g = StarMemoryGame(StarMemoryConfig.forDifficulty(d, seed: 4));
      final counts = <int, int>{};
      for (final f in g.state.faces) {
        counts.update(f, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(counts.length, g.config.pairs);
      expect(counts.values.every((c) => c == 2), isTrue);
    }
    expect(StarMemoryConfig.forDifficulty(PuzzleDifficulty.expert).cards, 36);
  });

  test('flip rules: match stays up, mismatch waits, then turns down', () {
    final g = StarMemoryGame(const StarMemoryConfig(seed: 1));
    final faces = g.state.faces;
    final a = 0;
    final b = faces.indexOf(faces[a], 1);
    final other = faces.indexWhere((f) => f != faces[a]);
    expect(g.apply(StarMemoryAction.flip(a)), isTrue);
    expect(g.apply(StarMemoryAction.flip(a)), isFalse, reason: 'already up');
    expect(g.apply(StarMemoryAction.flip(other)), isTrue);
    expect(g.state.up, [a, other]);
    expect(g.state.moves, 1);
    expect(g.apply(const StarMemoryAction.conceal()), isTrue);
    expect(g.state.up, isEmpty);
    expect(g.apply(const StarMemoryAction.conceal()), isFalse);
    g.apply(StarMemoryAction.flip(a));
    g.apply(StarMemoryAction.flip(other));
    // A third flip turns the mismatch down automatically.
    expect(g.apply(StarMemoryAction.flip(a)), isTrue);
    expect(g.state.up, [a]);
    expect(g.apply(StarMemoryAction.flip(b)), isTrue);
    expect(g.state.matched[a] && g.state.matched[b], isTrue);
    expect(g.isFaceUp(a), isTrue);
    expect(g.apply(StarMemoryAction.flip(a)), isFalse, reason: 'matched');
    expect(g.state.pairsFound, 1);
  });

  test('perfect-memory hints finish close to par and score well', () {
    for (final d in PuzzleDifficulty.values) {
      final g = StarMemoryGame(StarMemoryConfig.forDifficulty(d, seed: 7));
      followHints(g);
      expect(g.isSolved, isTrue);
      expect(g.state.moves, lessThanOrEqualTo(2 * g.config.pairs));
      g.addTime(const Duration(seconds: 30));
      expect(g.score, greaterThan(0));
    }
  });

  test('scoring rewards fewer moves and less time', () {
    final best = starMemoryScore(pairs: 8, moves: 8, elapsedMs: 10000);
    expect(starMemoryScore(pairs: 8, moves: 20, elapsedMs: 10000), lessThan(best));
    expect(starMemoryScore(pairs: 8, moves: 8, elapsedMs: 90000), lessThan(best));
    expect(starMemoryScore(pairs: 8, moves: 400, elapsedMs: 9000000), 0);
  });

  test('random play, undo, replay and JSON', () {
    final g = StarMemoryGame(StarMemoryConfig.forDifficulty(PuzzleDifficulty.hard, seed: 3));
    final rng = SeededRng(3);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 1000 && !g.isOver; i++) {
      final a = rng.nextInt(10) == 0 ? const StarMemoryAction.conceal() : StarMemoryAction.flip(rng.nextInt(20));
      if (g.apply(a)) log.add(roundTripJson(a.toJson()));
    }
    expect(replay(StarMemoryGame(StarMemoryConfig.forDifficulty(PuzzleDifficulty.hard, seed: 3)), log),
        replay(g, const []));
    expectJsonRoundTrip(g);
    while (g.undo()) {}
    expect(g.state.moves, 0);
  });
}
