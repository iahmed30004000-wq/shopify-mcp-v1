/// Madar Cinema – Tier 2 card games, pure game logic: Tarneeb (طرنيب), Trix
/// (تركس), Hand (هاند), Basra (باصرة), Baloot (بلوت) and Konkan (كونكان).
///
/// Everything the table UI needs: [CardGames] to create / restore a match,
/// the uniform [CardGameEngine] (state, legalMoves, apply, isOver, scores,
/// currentPlayer) and [CardAi] (chooseMove at easy / medium / hard). No
/// Flutter, no user-facing strings: enums and ids only. The exact rules are
/// in RULES.md next to this file.
library;

export 'baloot/baloot_ai.dart';
export 'baloot/baloot_rules.dart';
export 'baloot/baloot_state.dart';
export 'basra/basra_ai.dart';
export 'basra/basra_rules.dart';
export 'basra/basra_state.dart';
export 'card_games.dart';
export 'core/ai_base.dart' show HeuristicAi;
export 'core/card_game.dart';
export 'core/card_rng.dart';
export 'core/deck.dart';
export 'core/playing_card.dart';
export 'core/trick.dart' show Trick;
export 'hand/hand.dart';
export 'konkan/konkan.dart';
export 'rummy/rummy_ai.dart';
export 'rummy/rummy_meld.dart';
export 'rummy/rummy_rules.dart';
export 'rummy/rummy_state.dart';
export 'tarneeb/tarneeb_ai.dart';
export 'tarneeb/tarneeb_rules.dart';
export 'tarneeb/tarneeb_state.dart';
export 'trix/trix_ai.dart';
export 'trix/trix_rules.dart';
export 'trix/trix_state.dart';
