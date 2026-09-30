/// Ready-made [TogetherGameAdapter]s over the Madar Cinema rules engines:
/// every board game kit (chess, backgammon, dominoes, ludo, four in a row…)
/// and every card game (Tarneeb, Trix, Basra, Konkan…).
library;

import '../../cinema/rules/board/core/engine.dart' show BoardGameKit;
import '../../cinema/rules/board/core/game_types.dart' show BoardGameId, GameMove, GameState, jsonMap;
import '../../cinema/rules/cards/card_games.dart' show AnyCardEngine, CardGames;
import '../../cinema/rules/cards/core/card_game.dart' show CardGameId, CardMove;
import '../domain/play_modes.dart';
import '../protocol/game_data.dart';
import '../protocol/together_game.dart';

/// The Together history id of a board game.
String togetherIdOfBoardGame(BoardGameId id) => switch (id) {
  BoardGameId.connectFour => TogetherGames.fourInARow.id,
  _ => id.name,
};

/// Plays any [BoardGameKit] together. States are immutable; the kit's
/// `newGame(players, seed)` makes the shared initial state.
///
/// [players] defaults to the kit's minimum (4 for Ludo in partnerships).
/// The default [policy] ([boardPolicy]) reads the `keys` of chess and
/// draughts states – their Zobrist repetition history, as hex – as hashes,
/// not text.
class BoardKitTogetherAdapter extends TogetherGameAdapter<GameState, GameMove> {
  BoardKitTogetherAdapter(
    this.kit, {
    String? gameId,
    this.gameVersion = 1,
    int? players,
    this.policy = boardPolicy,
  }) : gameId = gameId ?? togetherIdOfBoardGame(kit.id),
       players = players ?? kit.minPlayers;

  /// The standard policy, with the board engines' hash fields.
  static const GameDataPolicy boardPolicy = GameDataPolicy(hashKeys: {'keys'});

  final BoardGameKit<GameState, GameMove> kit;

  @override
  final String gameId;

  @override
  final int gameVersion;

  final int players;

  @override
  final GameDataPolicy policy;

  @override
  TogetherGameKind get kind => TogetherGameKind.turnBased;

  @override
  int get seatCount => players;

  @override
  GameState initialState({required int seed, required GameData config}) => kit.newGame(players: players, seed: seed);

  @override
  int? seatToMove(GameState state) => state.isOver ? null : state.currentPlayer;

  @override
  String? validateMove(GameState state, int seat, GameMove move) {
    if (state.isOver) return 'matchOver';
    if (state.currentPlayer != seat) return 'notYourTurn';
    return kit.rules.isLegal(state, move) ? null : 'illegalMove';
  }

  @override
  GameState applyMove(GameState state, int seat, GameMove move) => kit.rules.apply(state, move);

  @override
  SeatOutcome? outcome(GameState state) {
    final r = state.result;
    if (r == null) return null;
    return r.isDraw ? SeatOutcome.draw(scores: r.scores) : SeatOutcome(winners: r.winners, scores: r.scores);
  }

  @override
  Object? encodeState(GameState state) => state.toJson();

  @override
  GameState decodeState(Object? json) => kit.rules.stateFromJson(jsonMap(json));

  @override
  Object? encodeMove(GameMove move) => move.toJson();

  @override
  GameMove decodeMove(Object? json) => kit.rules.moveFromJson(jsonMap(json));
}

/// Plays a card game together. Card engines mutate their state, so every
/// move is applied to a copy (via the engine's own save format).
///
/// Seats: 4 for the partnership games – seat the couple with
/// `TogetherSeats.partners` (vs two AIs) or `TogetherSeats.rivals` (each with
/// an AI partner); AI seats are played by the host through
/// `session.play(aiMove, seat: …)`.
class CardEngineTogetherAdapter extends TogetherGameAdapter<AnyCardEngine, CardMove> {
  CardEngineTogetherAdapter(
    this.game, {
    String? gameId,
    this.gameVersion = 1,
    this.optionsFromConfig,
    this.policy = GameDataPolicy.standard,
  }) : gameId = gameId ?? game.name;

  final CardGameId game;

  @override
  final String gameId;

  @override
  final int gameVersion;

  /// The game's options class from the shared config (null: defaults).
  final Object? Function(GameData config)? optionsFromConfig;

  @override
  final GameDataPolicy policy;

  late final AnyCardEngine _prototype = CardGames.newMatch(game, seed: 0);

  @override
  TogetherGameKind get kind => TogetherGameKind.turnBased;

  @override
  int get seatCount => _prototype.state.playerCount;

  @override
  AnyCardEngine initialState({required int seed, required GameData config}) =>
      CardGames.newMatch(game, seed: seed, options: optionsFromConfig?.call(config));

  @override
  int? seatToMove(AnyCardEngine state) => state.isOver ? null : state.currentPlayer;

  @override
  String? validateMove(AnyCardEngine state, int seat, CardMove move) {
    if (state.isOver) return 'matchOver';
    if (state.currentPlayer != seat) return 'notYourTurn';
    return state.validate(move);
  }

  @override
  AnyCardEngine applyMove(AnyCardEngine state, int seat, CardMove move) {
    final copy = CardGames.fromJson(state.toJson());
    copy.apply(move);
    return copy;
  }

  @override
  SeatOutcome? outcome(AnyCardEngine state) {
    if (!state.isOver) return null;
    final winners = state.state.winners;
    return winners.isEmpty
        ? SeatOutcome.draw(scores: state.scores)
        : SeatOutcome(winners: winners, scores: state.scores);
  }

  @override
  Object? encodeState(AnyCardEngine state) => state.toJson();

  @override
  AnyCardEngine decodeState(Object? json) => CardGames.fromJson(jsonMap(json));

  @override
  Object? encodeMove(CardMove move) => move.toJson();

  @override
  CardMove decodeMove(Object? json) => _prototype.moveFromJson(jsonMap(json));
}
