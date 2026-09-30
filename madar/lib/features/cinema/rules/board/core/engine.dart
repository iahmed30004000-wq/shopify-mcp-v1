/// The uniform engine / AI contracts every board game implements.
library;

import 'game_types.dart';
import 'rng.dart';

/// Pure rules of one game: immutable state in, immutable state out.
abstract class GameRules<S extends GameState, M extends GameMove> {
  const GameRules();

  BoardGameId get id;

  /// Legal moves for the state's [GameState.currentPlayer]; empty when the
  /// game is over.
  List<M> legalMoves(S state);

  /// Applies a legal [move]. Behaviour for an illegal move is unspecified –
  /// [BoardGameEngine.apply] validates first.
  S apply(S state, M move);

  /// Whether [move] is legal in [state]. Games whose moves have several
  /// equivalent spellings (backgammon step orders) override this.
  bool isLegal(S state, M move) => !state.isOver && legalMoves(state).contains(move);

  S stateFromJson(Map<String, Object?> json);
  M moveFromJson(Map<String, Object?> json);
}

/// A game in progress: the current state, the moves that led to it and undo.
///
/// This is the one object the UI drives:
/// `state`, `legalMoves(player)`, `apply(move)`, `isOver`, `result`,
/// `currentPlayer`, `toJson` / [BoardGameEngine.fromJson].
class BoardGameEngine<S extends GameState, M extends GameMove> {
  BoardGameEngine(this.rules, S initial) : _states = [initial];

  /// Restores an engine saved with [toJson] by replaying its moves from the
  /// saved initial state (every move is re-validated).
  factory BoardGameEngine.fromJson(GameRules<S, M> rules, Map<String, Object?> json) {
    final game = json['game'];
    if (game != rules.id.name) {
      throw FormatException('saved game is "$game", expected "${rules.id.name}"');
    }
    final engine = BoardGameEngine<S, M>(rules, rules.stateFromJson(jsonMap(json['initial'])));
    for (final m in json['moves']! as List) {
      engine.apply(rules.moveFromJson(jsonMap(m)));
    }
    return engine;
  }

  final GameRules<S, M> rules;
  final List<S> _states;
  final List<M> _moves = [];

  S get state => _states.last;
  S get initialState => _states.first;

  /// All states from the initial one to the current one.
  List<S> get states => List.unmodifiable(_states);

  /// Moves applied so far, oldest first.
  List<M> get history => List.unmodifiable(_moves);

  int get currentPlayer => state.currentPlayer;
  bool get isOver => state.isOver;
  GameResult? get result => state.result;

  /// Legal moves for [player] (default: the player to act). Empty when it is
  /// not that player's turn or the game is over.
  List<M> legalMoves([int? player]) {
    if (state.isOver) return const [];
    if (player != null && player != state.currentPlayer) return const [];
    return rules.legalMoves(state);
  }

  /// Validates and applies [move]; throws [IllegalMoveException] otherwise.
  void apply(M move) {
    if (state.isOver) throw IllegalMoveException(move, 'game over');
    if (!rules.isLegal(state, move)) throw IllegalMoveException(move);
    final next = rules.apply(state, move);
    _moves.add(move);
    _states.add(next);
  }

  bool get canUndo => _moves.isNotEmpty;

  /// Takes back the last move (dice and shuffles rewind too, since the RNG
  /// lives in the state).
  M undo() {
    if (_moves.isEmpty) throw StateError('nothing to undo');
    _states.removeLast();
    return _moves.removeLast();
  }

  Map<String, Object?> toJson() => {
    'game': rules.id.name,
    'v': 1,
    'initial': initialState.toJson(),
    'moves': [for (final m in _moves) m.toJson()],
  };
}

/// An AI opponent for one game.
abstract interface class BoardAi<S extends GameState, M extends GameMove> {
  /// Picks a legal move for `state.currentPlayer`.
  ///
  /// [rng] drives the AI's own randomness (mistakes at easy, tie-breaks,
  /// Monte-Carlo samples) and is independent of the game's dice. Hidden
  /// information (domino hands, future dice) is never read.
  M chooseMove(S state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]);
}

/// Everything the UI needs to host one game generically.
final class BoardGameKit<S extends GameState, M extends GameMove> {
  const BoardGameKit({
    required this.id,
    required this.rules,
    required this.ai,
    required this.minPlayers,
    required this.maxPlayers,
    required this.newGame,
  });

  final BoardGameId id;
  final GameRules<S, M> rules;
  final BoardAi<S, M> ai;
  final int minPlayers;
  final int maxPlayers;

  /// A fresh game with default options for [players] and a [seed] for dice
  /// and shuffles.
  final S Function({int players, int seed}) newGame;

  BoardGameEngine<S, M> engine({int players = 2, int seed = 0}) =>
      BoardGameEngine<S, M>(rules, newGame(players: players, seed: seed));

  BoardGameEngine<S, M> engineFromJson(Map<String, Object?> json) => BoardGameEngine<S, M>.fromJson(rules, json);
}
