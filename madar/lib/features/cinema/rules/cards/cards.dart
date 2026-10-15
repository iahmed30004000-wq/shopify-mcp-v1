/// Madar Cinema – card games, pure game logic, with the rules as commonly
/// played in Jordan by default: Tarneeb (طرنيب), 41 (٤١ طلب فردي), Trix
/// (تركس, and Trix Complex), Hand (هاند, and partnership Hand), Konkan
/// (كونكان), Basra (باصرة), Baloot (بلوت), Blackjack 21 (بلاك جاك ٢١) and
/// Solitaire (سوليتير, Klondike).
///
/// Everything the table UI needs: [CardGames] to create / restore a match,
/// the uniform [CardGameEngine] (state, legalMoves, apply, isOver, scores,
/// currentPlayer) and [CardAi] (chooseMove at easy / medium / hard).
/// Solitaire is a one-player patience with its own [SolitaireGame] (undo,
/// hints, auto-player, solver) and has no [CardGameId]. No Flutter, no
/// user-facing strings: enums and ids only. The exact rules are in RULES.md
/// next to this file.
library;

export 'baloot/baloot_ai.dart';
export 'baloot/baloot_rules.dart';
export 'baloot/baloot_state.dart';
export 'basra/basra_ai.dart';
export 'basra/basra_rules.dart';
export 'basra/basra_state.dart';
export 'blackjack/blackjack_ai.dart';
export 'blackjack/blackjack_rules.dart';
export 'blackjack/blackjack_state.dart';
export 'blackjack/blackjack_strategy.dart';
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
export 'solitaire/solitaire_ai.dart';
export 'solitaire/solitaire_board.dart';
export 'solitaire/solitaire_game.dart';
export 'solitaire/solitaire_options.dart';
export 'solitaire/solitaire_seeds.dart';
export 'solitaire/solitaire_solver.dart';
export 'solitaire/solitaire_stats.dart';
export 'tarneeb/tarneeb_ai.dart';
export 'tarneeb/tarneeb_rules.dart';
export 'tarneeb/tarneeb_state.dart';
export 'tarneeb41/forty_one_ai.dart';
export 'tarneeb41/forty_one_rules.dart';
export 'tarneeb41/forty_one_state.dart';
export 'trix/trix_ai.dart';
export 'trix/trix_rules.dart';
export 'trix/trix_state.dart';
