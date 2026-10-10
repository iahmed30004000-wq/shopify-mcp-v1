/// What a game provides to be played through a [TogetherSession]: its rules
/// as pure functions over a state, and the (de)serialisation of states and
/// moves into [GameData].
library;

import '../domain/play_modes.dart';
import 'game_data.dart';

/// How a finished game ended, by seat. The session maps seats to the two
/// players (and AI seats to nobody) before recording.
final class SeatOutcome {
  const SeatOutcome({required this.winners, this.scores = const []}) : isLoss = false;

  /// [seat] won alone.
  SeatOutcome.win(int seat, {this.scores = const []}) : winners = List.unmodifiable([seat]), isLoss = false;

  const SeatOutcome.draw({this.scores = const []}) : winners = const [], isLoss = false;

  /// Nobody won: the game beat every seat (a lost co-op game – "we lost
  /// together"). Not a draw: it never breaks a head-to-head streak.
  const SeatOutcome.loss({this.scores = const []}) : winners = const [], isLoss = true;

  /// Winning seats (partners together); empty for a draw or a [isLoss].
  final List<int> winners;

  /// Score per seat (empty when the game has no score).
  final List<int> scores;

  /// Every seat lost ([SeatOutcome.loss]).
  final bool isLoss;

  bool get isDraw => winners.isEmpty && !isLoss;

  @override
  bool operator ==(Object other) =>
      other is SeatOutcome &&
      other.isLoss == isLoss &&
      _listEq(other.winners, winners) &&
      _listEq(other.scores, scores);

  @override
  int get hashCode => Object.hash(isLoss, Object.hashAll(winners), Object.hashAll(scores));

  @override
  String toString() => 'SeatOutcome(${isLoss ? 'loss' : 'winners: $winners'}, scores: $scores)';

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A game playable together. [S] is the game's state (immutable, or copied
/// by [applyMove]), [M] its move.
///
/// Rules must be deterministic: the same seed and config give the same
/// initial state on both devices, and the same move gives the same next
/// state – states are compared by the hash of [encodeState].
abstract class TogetherGameAdapter<S, M> {
  const TogetherGameAdapter();

  /// Stable id (the head-to-head history key), e.g. `chess`.
  String get gameId;

  /// Bump when the rules or the encoding change (peers must match).
  int get gameVersion;

  TogetherGameKind get kind;

  /// What the game's states and moves may contain: set
  /// [GameDataPolicy.allowedKeys] to the game's own field names for a strict
  /// whitelist.
  GameDataPolicy get policy;

  /// Number of seats (2 for most games, 4 for Tarneeb / Trix).
  int get seatCount;

  /// The initial state for the shared [seed] and [config].
  S initialState({required int seed, required GameData config});

  /// The seat that must act, or null when the game is over (or every seat
  /// acts at once – real-time games).
  int? seatToMove(S state);

  /// Null when [move] is legal for [seat], else a stable error id.
  String? validateMove(S state, int seat, M move);

  /// The state after a legal [move] by [seat] (never mutates [state]).
  S applyMove(S state, int seat, M move);

  /// Non-null once the game has ended.
  SeatOutcome? outcome(S state);

  /// JSON of [state] (checked against [policy] before it travels).
  Object? encodeState(S state);

  S decodeState(Object? json);

  Object? encodeMove(M move);

  M decodeMove(Object? json);
}
