import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

/// JSON through a real encode/decode cycle (catches non-JSON values).
Map<String, Object?> roundTripJson(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

/// Saves [game], restores it and checks the snapshot and history survive.
PuzzleGame<PuzzleState, PuzzleAction> expectJsonRoundTrip(PuzzleGame<PuzzleState, PuzzleAction> game) {
  final json = roundTripJson(game.toJson());
  final restored = puzzleFromJson(json);
  expect(restored.kind, game.kind);
  expect(jsonEncode(restored.toJson()), jsonEncode(game.toJson()));
  expect(restored.isSolved, game.isSolved);
  expect(restored.isOver, game.isOver);
  return restored;
}

/// Plays [actions] (as JSON) on [fresh] and returns the final state JSON.
String replay(PuzzleGame<PuzzleState, PuzzleAction> fresh, List<Map<String, Object?>> actions) {
  for (final a in actions) {
    fresh.apply(puzzleActionFromJson(fresh.kind, a));
  }
  return jsonEncode(fresh.state.toJson());
}

/// Follows hints until the puzzle ends or [maxSteps] is reached.
int followHints(PuzzleGame<PuzzleState, PuzzleAction> game, {int maxSteps = 100000}) {
  var steps = 0;
  while (!game.isOver && steps < maxSteps) {
    final h = game.hint();
    if (h == null) break;
    expect(game.apply(h.action), isTrue, reason: 'hint ${h.action} must be legal');
    steps++;
  }
  return steps;
}

/// Median of [samples].
int median(List<int> samples) {
  final s = [...samples]..sort();
  return s[s.length ~/ 2];
}

/// Measures [body] in milliseconds.
int timeMs(void Function() body) {
  final sw = Stopwatch()..start();
  body();
  return sw.elapsedMilliseconds;
}
