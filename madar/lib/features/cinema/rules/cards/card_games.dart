/// One entry point for the UI: create, restore and get the AI of any of the
/// six card games by [CardGameId].
library;

import 'baloot/baloot_ai.dart';
import 'baloot/baloot_rules.dart';
import 'baloot/baloot_state.dart';
import 'basra/basra_ai.dart';
import 'basra/basra_rules.dart';
import 'basra/basra_state.dart';
import 'core/card_game.dart';
import 'hand/hand.dart';
import 'konkan/konkan.dart';
import 'rummy/rummy_state.dart';
import 'tarneeb/tarneeb_ai.dart';
import 'tarneeb/tarneeb_rules.dart';
import 'tarneeb/tarneeb_state.dart';
import 'trix/trix_ai.dart';
import 'trix/trix_rules.dart';
import 'trix/trix_state.dart';

typedef AnyCardEngine = CardGameEngine<CardGameState, CardMove>;
typedef AnyCardAi = CardAi<CardGameState, CardMove>;

abstract final class CardGames {
  /// A new match. [options] is the game's options class (`TarneebOptions`,
  /// `TrixOptions`, `BasraOptions`, `BalootOptions`, or `RummyOptions` for
  /// Hand and Konkan); null means the documented defaults.
  static AnyCardEngine newMatch(CardGameId id, {required int seed, Object? options}) => switch (id) {
    CardGameId.tarneeb => TarneebEngine.newMatch(seed: seed, options: options as TarneebOptions? ?? const TarneebOptions()),
    CardGameId.trix => TrixEngine.newMatch(seed: seed, options: options as TrixOptions? ?? const TrixOptions()),
    CardGameId.basra => BasraEngine.newMatch(seed: seed, options: options as BasraOptions? ?? const BasraOptions()),
    CardGameId.baloot => BalootEngine.newMatch(seed: seed, options: options as BalootOptions? ?? const BalootOptions()),
    CardGameId.hand => HandEngine.newMatch(seed: seed, options: options as RummyOptions? ?? const RummyOptions.hand()),
    CardGameId.konkan => KonkanEngine.newMatch(
      seed: seed,
      options: options as RummyOptions? ?? const RummyOptions.konkan(),
    ),
  };

  /// Restores a match saved with [CardGameEngine.toJson].
  static AnyCardEngine fromJson(Map<String, Object?> json) => switch (CardGameId.values.byName(json['game']! as String)) {
    CardGameId.tarneeb => TarneebEngine.fromJson(json),
    CardGameId.trix => TrixEngine.fromJson(json),
    CardGameId.basra => BasraEngine.fromJson(json),
    CardGameId.baloot => BalootEngine.fromJson(json),
    CardGameId.hand => HandEngine.fromJson(json),
    CardGameId.konkan => KonkanEngine.fromJson(json),
  };

  static AnyCardAi ai(CardGameId id) => switch (id) {
    CardGameId.tarneeb => const TarneebAi(),
    CardGameId.trix => const TrixAi(),
    CardGameId.basra => const BasraAi(),
    CardGameId.baloot => const BalootAi(),
    CardGameId.hand => const HandAi(),
    CardGameId.konkan => const KonkanAi(),
  };
}
