import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

FallingBlocksGame withWell(List<int> well, BlockShape shape, {int level = 1}) {
  final base = FallingBlocksGame(FallingConfig(seed: 1, startLevel: level));
  final s = base.state.copyWith(well: List.unmodifiable(well), piece: ActivePiece.spawn(shape));
  final json = base.toJson()..['state'] = s.toJson();
  return FallingBlocksGame.fromJson(roundTripJson(json));
}

void main() {
  test('shapes: four cells, four rotations, a full turn is the identity', () {
    for (final s in BlockShape.values) {
      final rots = kShapeCells[s]!;
      expect(rots.length, 4);
      for (final r in rots) {
        expect(r.toSet().length, 4);
      }
    }
    // The tee's first clockwise state points right.
    expect(kShapeCells[BlockShape.tee]![1].toSet(), {(1, 0), (1, 1), (2, 1), (1, 2)});
  });

  test('pieces come from a seeded 7-bag with a 5-piece preview', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 5));
    final seen = <BlockShape>[g.state.piece.shape];
    expect(g.state.preview.length, 5);
    for (var i = 0; i < 27; i++) {
      g.apply(FallingAction.hardDrop);
      seen.add(g.state.piece.shape);
    }
    for (var bag = 0; bag < 4; bag++) {
      expect(seen.sublist(bag * 7, bag * 7 + 7).toSet().length, 7, reason: 'bag $bag');
    }
    final again = FallingBlocksGame(const FallingConfig(seed: 5));
    expect(again.state.preview, FallingBlocksGame(const FallingConfig(seed: 5)).state.preview);
  });

  test('walls stop movement; rotation kicks off the wall', () {
    final g = withWell(List<int>.filled(kWellWidth * kWellHeight, 0), BlockShape.tee);
    g.apply(FallingAction.rotateCw); // vertical, bump right
    while (g.apply(FallingAction.moveLeft)) {}
    expect(g.state.piece.cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b), 0);
    // Rotating back to flat needs a kick to the right.
    final x = g.state.piece.x;
    expect(g.apply(FallingAction.rotateCcw), isTrue);
    expect(g.state.piece.cells.every((c) => c.$1 >= 0), isTrue);
    expect(g.state.piece.x, greaterThanOrEqualTo(x));
    final bar = withWell(List<int>.filled(kWellWidth * kWellHeight, 0), BlockShape.bar);
    for (var i = 0; i < 10; i++) {
      bar.apply(FallingAction.moveRight);
    }
    expect(bar.state.piece.cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b), kWellWidth - 1);
  });

  test('hard drop lands, locks and scores two per row', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 2));
    final ghost = FallingBlocksGame.ghost(g.state.well, g.state.piece);
    final rows = ghost.y - g.state.piece.y;
    expect(g.apply(FallingAction.hardDrop), isTrue);
    expect(g.state.score, 2 * rows);
    expect(g.state.pieces, 2);
    expect(g.state.well.where((c) => c != 0).length, 4);
  });

  test('line clears score by count and level', () {
    // Bottom four rows full except column 9: a vertical bar clears four.
    final well = List<int>.filled(kWellWidth * kWellHeight, 0);
    for (var y = kWellHeight - 4; y < kWellHeight; y++) {
      for (var x = 0; x < 9; x++) {
        well[y * kWellWidth + x] = 1;
      }
    }
    final g = withWell(well, BlockShape.bar, level: 3);
    g.apply(FallingAction.rotateCw);
    while (g.apply(FallingAction.moveRight)) {}
    final before = g.state.score;
    g.apply(FallingAction.hardDrop);
    expect(g.state.lastClear, 4);
    expect(g.state.lines, 4);
    expect(g.state.well.every((c) => c == 0), isTrue);
    expect(g.state.score - before, greaterThanOrEqualTo(800 * 3));
  });

  test('gravity follows the level speed; lock delay is 30 frames', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 3));
    final y0 = g.state.piece.y;
    for (var i = 0; i < 59; i++) {
      g.apply(FallingAction.tick);
    }
    expect(g.state.piece.y, y0, reason: 'level 1: one row per second');
    g.apply(FallingAction.tick);
    expect(g.state.piece.y, y0 + 1);
    expect(secondsPerRow(1), 1.0);
    expect(secondsPerRow(10), lessThan(secondsPerRow(5)));
    // Rest the piece on the floor and count frames to lock.
    while (g.apply(FallingAction.softDrop)) {}
    final pieces = g.state.pieces;
    var frames = 0;
    while (g.state.pieces == pieces) {
      g.apply(FallingAction.tick);
      frames++;
    }
    expect(frames, kLockDelayFrames);
  });

  test('hold swaps once per piece', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 4));
    final first = g.state.piece.shape;
    final next = g.state.preview.first;
    expect(g.apply(FallingAction.hold), isTrue);
    expect(g.state.hold, first);
    expect(g.state.piece.shape, next);
    expect(g.apply(FallingAction.hold), isFalse);
    g.apply(FallingAction.hardDrop);
    expect(g.apply(FallingAction.hold), isTrue);
    expect(g.state.piece.shape, first);
  });

  test('topping out ends the game; undo returns to the previous piece', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 6));
    var guard = 0;
    while (!g.isOver && guard++ < 200) {
      g.apply(FallingAction.hardDrop);
    }
    expect(g.isOver, isTrue);
    expect(g.apply(FallingAction.moveLeft), isFalse);
    expect(g.canUndo, isTrue);
    expect(g.undo(), isTrue);
    expect(g.isOver, isFalse);
  });

  test('the placement AI survives 150 pieces', () {
    final g = FallingBlocksGame(const FallingConfig(seed: 8));
    var steps = 0;
    while (!g.isOver && g.state.pieces < 150 && steps < 5000) {
      final h = g.hint()!;
      g.apply(h.action);
      steps++;
    }
    expect(g.isOver, isFalse);
    expect(g.state.lines, greaterThan(40));
  });

  test('long random play never throws; deterministic replay and JSON', () {
    for (var seed = 0; seed < 10; seed++) {
      final g = FallingBlocksGame(FallingConfig(seed: seed, startLevel: 1 + seed));
      final rng = SeededRng(seed);
      final log = <Map<String, Object?>>[];
      for (var i = 0; i < 4000 && !g.isOver; i++) {
        final a = rng.nextInt(3) == 0 ? FallingAction.tick : rng.pick(FallingAction.values);
        if (g.apply(a)) log.add(roundTripJson(a.toJson()));
      }
      final again = FallingBlocksGame(FallingConfig(seed: seed, startLevel: 1 + seed));
      expect(replay(again, log), replay(g, const []));
      expectJsonRoundTrip(g);
    }
    final g = FallingBlocksGame(const FallingConfig(seed: 1));
    expect(g.advance(1.0), 60);
  });
}
