/// The small uniform interface between the card-game rules and the UI.
///
/// Every game exposes a [CardGameEngine] (state, legal moves, apply, scores,
/// whose turn) and a [CardAi]. Nothing here is user-facing text: games,
/// phases, moves, events and errors are enums / stable ids the UI localises.
library;

import 'dart:math' as math;

import 'playing_card.dart';

/// The six Tier 2 card games.
enum CardGameId { tarneeb, trix, hand, basra, baloot, konkan }

/// AI strength.
enum AiLevel { easy, medium, hard }

/// How long the hard AI may think. The search stops at whichever limit comes
/// first; tests pass a large [time] and a tiny [maxSimulations] so that the
/// result is deterministic for a seed.
class AiBudget {
  const AiBudget({this.time = const Duration(milliseconds: 150), this.maxSimulations = 1 << 30});

  /// ≤ 150 ms per move, the phone default.
  static const AiBudget phone = AiBudget();

  /// Deterministic budget for tests: [simulations] rollouts, no time limit.
  const AiBudget.simulations(int simulations) : this(time: const Duration(seconds: 30), maxSimulations: simulations);

  final Duration time;
  final int maxSimulations;
}

/// A move of one game. Every game's move is a value object (== / hashCode)
/// with JSON round-tripping.
abstract class CardMove {
  const CardMove();

  Map<String, Object?> toJson();
}

/// What just happened, for the table animations (cards flying, tricks
/// collected, scores). [detail] is a stable id (an enum name) when needed.
class CardEvent {
  const CardEvent(this.type, {this.seat, this.cards = const [], this.value, this.suit, this.detail});

  final CardEventType type;
  final int? seat;
  final List<PlayingCard> cards;
  final int? value;
  final Suit? suit;
  final String? detail;

  @override
  String toString() => 'CardEvent(${type.name}, seat: $seat, cards: $cards, value: $value, detail: $detail)';
}

enum CardEventType {
  dealt,
  redeal,
  bid,
  pass,
  trumpChosen,
  contractChosen,
  doubled,
  cardPlayed,
  trickWon,
  captured,
  basra,
  cardToTable,
  drewStock,
  tookDiscard,
  discarded,
  opened,
  melded,
  laidOff,
  jokerSwapped,
  projectsDeclared,
  belote,
  playerFinished,
  roundScored,
  matchOver,
}

/// The whole (mutable) state of a match. The UI must treat it as read-only
/// and change it only through [CardGameEngine.apply].
abstract class CardGameState {
  CardGameId get gameId;

  int get playerCount;

  /// Seat to act, or null once [isOver].
  int? get currentPlayer;

  bool get isOver;

  /// Match score per seat (partners share their team total).
  List<int> get scores;

  /// True for the rummy games, where points are penalties.
  bool get lowerScoreWins => false;

  /// Winning seats (both partners in a partnership); empty until [isOver].
  List<int> get winners;

  /// Counts every deal, redeals included (the AI stops its rollouts there).
  int get dealNumber;

  /// Team of [seat]; individual games return the seat itself.
  int teamOf(int seat) => seat;

  /// Every card currently in the game (hands, table, piles, stock) – a
  /// multiset that must always equal the full deck (card conservation).
  List<PlayingCard> cardsInPlay();

  /// The full deck of the current configuration.
  List<PlayingCard> fullDeck();

  CardGameState copy();

  Map<String, Object?> toJson();
}

/// Thrown by [CardGameEngine.apply] for a move that is not legal. [code] is a
/// stable id such as `notYourTurn`, `mustFollowSuit`, `openingBelowThreshold`.
class IllegalMoveException implements Exception {
  const IllegalMoveException(this.code);

  final String code;

  @override
  String toString() => 'IllegalMoveException($code)';
}

/// Rules of one game as pure functions of a state.
abstract class CardRules<S extends CardGameState, M extends CardMove> {
  const CardRules();

  List<M> legalMoves(S s, int seat);

  /// Null when [m] is legal for [seat], else an error id. The default
  /// accepts exactly [legalMoves]; games with compound moves (rummy melds)
  /// accept more than they enumerate.
  String? validate(S s, int seat, M m) {
    if (s.isOver) return 'matchOver';
    if (s.currentPlayer != seat) return 'notYourTurn';
    return legalMoves(s, seat).contains(m) ? null : 'illegalMove';
  }

  /// Applies a legal [m] for the current player (no validation).
  void apply(S s, M m, [List<CardEvent>? ev]);

  M moveFromJson(Map<String, Object?> json);
}

/// The interface the UI uses.
abstract interface class CardGameEngine<S extends CardGameState, M extends CardMove> {
  S get state;

  List<M> legalMoves(int player);

  /// Null when legal, else an error id (see [IllegalMoveException.code]).
  String? validate(M move);

  /// Plays [move] for [currentPlayer]; returns what happened.
  List<CardEvent> apply(M move);

  bool get isOver;

  List<int> get scores;

  int? get currentPlayer;

  M moveFromJson(Map<String, Object?> json);

  Map<String, Object?> toJson();
}

/// Generic engine over a [CardRules] implementation.
class RulesEngine<S extends CardGameState, M extends CardMove> implements CardGameEngine<S, M> {
  RulesEngine(this.rules, this._state);

  final CardRules<S, M> rules;
  S _state;

  @override
  S get state => _state;

  /// Replaces the state (loading a save).
  set state(S value) => _state = value;

  @override
  List<M> legalMoves(int player) =>
      _state.isOver || _state.currentPlayer != player ? <M>[] : rules.legalMoves(_state, player);

  @override
  String? validate(M move) {
    final p = _state.currentPlayer;
    if (p == null) return 'matchOver';
    return rules.validate(_state, p, move);
  }

  @override
  List<CardEvent> apply(M move) {
    final error = validate(move);
    if (error != null) throw IllegalMoveException(error);
    final events = <CardEvent>[];
    rules.apply(_state, move, events);
    return events;
  }

  @override
  bool get isOver => _state.isOver;

  @override
  List<int> get scores => _state.scores;

  @override
  int? get currentPlayer => _state.currentPlayer;

  @override
  M moveFromJson(Map<String, Object?> json) => rules.moveFromJson(json);

  @override
  Map<String, Object?> toJson() => _state.toJson();
}

/// The AI interface the UI uses. [chooseMove] never changes [state].
abstract interface class CardAi<S extends CardGameState, M extends CardMove> {
  M chooseMove(S state, int player, AiLevel level, math.Random rng, AiBudget budget);
}
