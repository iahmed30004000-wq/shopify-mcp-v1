/// One entry point for the UI: create, restore and get the AI of any card
/// game behind [CardGameEngine], by [CardGameId]. Solitaire is not here: it is
/// a one-player patience with its own `SolitaireGame` (see RULES.md §7).
library;

import 'baloot/baloot_ai.dart';
import 'baloot/baloot_rules.dart';
import 'baloot/baloot_state.dart';
import 'basra/basra_ai.dart';
import 'basra/basra_rules.dart';
import 'basra/basra_state.dart';
import 'blackjack/blackjack_ai.dart';
import 'blackjack/blackjack_rules.dart';
import 'blackjack/blackjack_state.dart';
import 'core/card_game.dart';
import 'hand/hand.dart';
import 'konkan/konkan.dart';
import 'rummy/rummy_state.dart';
import 'tarneeb/tarneeb_ai.dart';
import 'tarneeb/tarneeb_rules.dart';
import 'tarneeb/tarneeb_state.dart';
import 'tarneeb41/forty_one_ai.dart';
import 'tarneeb41/forty_one_rules.dart';
import 'tarneeb41/forty_one_state.dart';
import 'trix/trix_ai.dart';
import 'trix/trix_rules.dart';
import 'trix/trix_state.dart';

typedef AnyCardEngine = CardGameEngine<CardGameState, CardMove>;
typedef AnyCardAi = CardAi<CardGameState, CardMove>;

abstract final class CardGames {
  /// A new match. [options] is the game's options class: `TarneebOptions`,
  /// `FortyOneOptions`, `TrixOptions` (menu entries: `TrixPreset.values`, each
  /// with its `.options`), `BasraOptions`, `BalootOptions`, `RummyOptions`
  /// for Hand and Konkan, or `BlackjackOptions`. Null means the game as
  /// commonly played in Jordan (every options class's `const` default is its
  /// Jordanian preset; Hand and Konkan use `RummyOptions.hand()` and
  /// `RummyOptions.konkan()`).
  ///
  /// Basra throws an `ArgumentError` for a table that cannot be dealt (for
  /// example `BasraOptions.palestinian44(players: 3)`); check
  /// `BasraOptions.configError` first. Rummy options that
  /// `RummyOptions.invalidReason` refuses are refused the same way, and so are
  /// Konkan options for Hand or Hand options for Konkan.
  static AnyCardEngine newMatch(CardGameId id, {required int seed, Object? options}) => switch (id) {
    CardGameId.tarneeb => TarneebEngine.newMatch(
      seed: seed,
      options: options as TarneebOptions? ?? const TarneebOptions(),
    ),
    CardGameId.trix => TrixEngine.newMatch(seed: seed, options: options as TrixOptions? ?? const TrixOptions()),
    CardGameId.basra => BasraEngine.newMatch(seed: seed, options: options as BasraOptions? ?? const BasraOptions()),
    CardGameId.baloot => BalootEngine.newMatch(seed: seed, options: options as BalootOptions? ?? const BalootOptions()),
    CardGameId.hand => HandEngine.newMatch(
      seed: seed,
      options: _rummy(options, RummyVariant.hand, const RummyOptions.hand()),
    ),
    CardGameId.konkan => KonkanEngine.newMatch(
      seed: seed,
      options: _rummy(options, RummyVariant.konkan, const RummyOptions.konkan()),
    ),
    CardGameId.fortyOne => FortyOneEngine.newMatch(
      seed: seed,
      options: options as FortyOneOptions? ?? const FortyOneOptions(),
    ),
    CardGameId.blackjack => BlackjackEngine.newMatch(
      seed: seed,
      options: options as BlackjackOptions? ?? const BlackjackOptions(),
    ),
  };

  static RummyOptions _rummy(Object? options, RummyVariant variant, RummyOptions defaults) {
    final o = options as RummyOptions? ?? defaults;
    if (o.variant != variant) throw ArgumentError.value(o.variant, 'options', 'not ${variant.name} options');
    return o;
  }

  /// Restores a match saved with [CardGameEngine.toJson] (its `game` key is
  /// the [CardGameId] name).
  static AnyCardEngine fromJson(Map<String, Object?> json) =>
      switch (CardGameId.values.byName(json['game']! as String)) {
        CardGameId.tarneeb => TarneebEngine.fromJson(json),
        CardGameId.trix => TrixEngine.fromJson(json),
        CardGameId.basra => BasraEngine.fromJson(json),
        CardGameId.baloot => BalootEngine.fromJson(json),
        CardGameId.hand => HandEngine.fromJson(json),
        CardGameId.konkan => KonkanEngine.fromJson(json),
        CardGameId.fortyOne => FortyOneEngine.fromJson(json),
        CardGameId.blackjack => BlackjackEngine.fromJson(json),
      };

  static AnyCardAi ai(CardGameId id) => switch (id) {
    CardGameId.tarneeb => const TarneebAi(),
    CardGameId.trix => const TrixAi(),
    CardGameId.basra => const BasraAi(),
    CardGameId.baloot => const BalootAi(),
    CardGameId.hand => const HandAi(),
    CardGameId.konkan => const KonkanAi(),
    CardGameId.fortyOne => const FortyOneAi(),
    CardGameId.blackjack => const BlackjackAi(),
  };
}
