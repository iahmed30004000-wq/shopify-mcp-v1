// Shared self-play driver for the card-game tests.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';

typedef AnyEngine = CardGameEngine<CardGameState, CardMove>;

/// How to build and restore one game for the generic tests.
class Kit {
  const Kit(this.name, this.create, this.restore, this.ai);

  final String name;
  final AnyEngine Function(int seed) create;
  final AnyEngine Function(Map<String, Object?> json) restore;
  final CardAi<CardGameState, CardMove> ai;
}

class MatchRecord {
  MatchRecord(this.scores, this.winners, this.moves, this.finalJson, this.moveLog);

  final List<int> scores;
  final List<int> winners;
  final int moves;
  final String finalJson;

  /// Every move played, as JSON.
  final List<String> moveLog;
}

String _codes(Iterable<PlayingCard> cards) => (sortedCards(cards).map((c) => c.code)).join(',');

/// Plays one match with [levels] per seat and checks the invariants after
/// every move: a legal move always exists for the seat to act, the AI's
/// choice validates, and every card of the deck is somewhere exactly once.
/// With [jsonEvery] > 0 the state is also round-tripped through JSON every
/// that many moves (and play continues on the restored engine).
MatchRecord playMatch(
  Kit kit,
  int seed,
  List<AiLevel> levels, {
  AiBudget budget = const AiBudget.simulations(24),
  int jsonEvery = 0,
  int maxMoves = 100000,
  void Function(AnyEngine engine, CardMove move)? onMove,
}) {
  var engine = kit.create(seed);
  final rng = CardRng(seed * 7919 + 17);
  final deck = _codes(engine.state.fullDeck());
  var moves = 0;
  final log = <String>[];
  while (!engine.isOver) {
    final p = engine.currentPlayer;
    expect(p, isNotNull);
    final legal = engine.legalMoves(p!);
    expect(legal, isNotEmpty, reason: '${kit.name}: no legal move at move $moves');
    final before = jsonEncode(engine.toJson());
    final m = kit.ai.chooseMove(engine.state, p, levels[p], rng, budget);
    expect(jsonEncode(engine.toJson()), before, reason: '${kit.name}: the AI changed the state');
    expect(engine.validate(m), isNull, reason: '${kit.name}: AI chose an illegal move $m');
    onMove?.call(engine, m);
    log.add(jsonEncode(m.toJson()));
    final events = engine.apply(m);
    expect(events, isNotEmpty, reason: '${kit.name}: no event for $m');
    moves++;
    expect(_codes(engine.state.cardsInPlay()), deck, reason: '${kit.name}: cards not conserved after $m');
    if (jsonEvery > 0 && moves % jsonEvery == 0) {
      final json = jsonDecode(jsonEncode(engine.toJson())) as Map<String, Object?>;
      final restored = kit.restore(json);
      expect(jsonEncode(restored.toJson()), jsonEncode(json), reason: '${kit.name}: JSON round trip');
      final mj = jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>;
      expect(engine.moveFromJson(mj), m, reason: '${kit.name}: move JSON round trip');
      engine = restored;
    }
    if (moves > maxMoves) fail('${kit.name}: match did not end after $maxMoves moves');
  }
  expect(engine.currentPlayer, isNull);
  expect(engine.state.winners, isNotEmpty);
  return MatchRecord(List.of(engine.scores), List.of(engine.state.winners), moves, jsonEncode(engine.toJson()), log);
}
