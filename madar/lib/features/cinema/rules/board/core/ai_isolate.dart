/// Runs an AI decision on a background isolate so the UI thread never
/// stalls (pure Dart: `dart:isolate`, not available on the web).
library;

import 'dart:isolate';

import 'engine.dart';
import 'game_types.dart';
import 'rng.dart';

/// [BoardAi.chooseMove] on a short-lived isolate.
///
/// The isolate works on a copy of [rng], so the caller's generator does not
/// advance; pass `rng.fork()` per call to keep games reproducible.
Future<M> chooseMoveInBackground<S extends GameState, M extends GameMove>(
  BoardAi<S, M> ai,
  S state,
  AiLevel level,
  BoardRng rng, [
  AiBudget budget = AiBudget.phone,
]) {
  final seed = rng.state;
  return Isolate.run(() => ai.chooseMove(state, level, BoardRng.fromState(seed), budget));
}
