import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  group('SeededRng', () {
    test('same seed, same sequence; state round trip continues it', () {
      final a = SeededRng(42), b = SeededRng(42);
      for (var i = 0; i < 100; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
      final c = SeededRng.fromState(a.state);
      for (var i = 0; i < 100; i++) {
        expect(c.nextInt(1000), a.nextInt(1000));
      }
      expect(SeededRng(1).nextUint32(), isNot(SeededRng(2).nextUint32()));
    });

    test('ranges and shuffles', () {
      final r = SeededRng(7);
      for (var i = 0; i < 2000; i++) {
        final v = r.nextInt(6);
        expect(v, inInclusiveRange(0, 5));
        final d = r.nextDouble();
        expect(d >= 0 && d < 1, isTrue);
        expect(r.nextRange(-3, 3), inInclusiveRange(-3, 3));
      }
      final l = List<int>.generate(50, (i) => i);
      r.shuffle(l);
      expect(l.toSet().length, 50);
      expect(() => r.nextInt(0), throwsRangeError);
    });
  });

  test('bit helpers', () {
    expect(bitCount(0), 0);
    expect(bitCount(0x1FF), 9);
    expect(bitCount(0xFFFFFFFF), 32);
    expect(lowestBit(8), 3);
  });

  group('every puzzle', () {
    test('new games serialise, restore and replay deterministically', () {
      for (final kind in PuzzleKind.values) {
        for (final d in [PuzzleDifficulty.easy, PuzzleDifficulty.medium]) {
          final game = newPuzzle(kind, d, 11);
          expect(game.kind, kind);
          expect(game.isSolved, isFalse, reason: '$kind starts unsolved');
          expectJsonRoundTrip(game);
          // Play a few hinted moves, then compare with a replay.
          final actions = <Map<String, Object?>>[];
          for (var i = 0; i < 6 && !game.isOver; i++) {
            final h = game.hint();
            if (h == null) break;
            expect(game.apply(h.action), isTrue, reason: '$kind hint ${h.action}');
            actions.add(roundTripJson(h.action.toJson()));
          }
          expectJsonRoundTrip(game);
          final again = newPuzzle(kind, d, 11);
          expect(replay(again, actions), replay(game, const []), reason: '$kind replay');
        }
      }
    });

    test('undo walks back to the initial snapshot', () {
      for (final kind in PuzzleKind.values) {
        final game = newPuzzle(kind, PuzzleDifficulty.easy, 5);
        final initial = game.state.toJson().toString();
        var applied = 0;
        for (var i = 0; i < 4 && !game.isOver; i++) {
          // Falling Blocks records undo points per locked piece.
          final action = kind == PuzzleKind.fallingBlocks ? FallingAction.hardDrop : game.hint()?.action;
          if (action == null || !game.apply(action)) break;
          applied++;
        }
        if (applied == 0) continue;
        while (game.undo()) {}
        expect(game.state.toJson().toString(), initial, reason: '$kind');
        expect(game.canUndo, isFalse);
      }
    });
  });
}
