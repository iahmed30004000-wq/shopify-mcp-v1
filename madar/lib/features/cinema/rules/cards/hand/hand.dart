/// Hand (هاند) as commonly played in Jordan: the rummy engine with
/// `RummyOptions.hand()` – two packs and two jokers (106 cards), 14 cards and
/// 15 for the starter, whose first turn is only a discard; 51 to open (an ace
/// is 11, also in A-2-3); one wild per meld; the top discard only into a new
/// meld with two cards of the hand; −30 for going out, −60 and everyone else
/// doubled for a full hand (هاند); 5 rounds, lowest total wins. Partnership
/// Hand and the indicator card (ورقة الكشف) are presets
/// (`RummyOptions.handPartnership()`, `RummyOptions.handIndicator()`); every
/// other variant is an option. See RULES.md.
library;

import '../rummy/rummy_ai.dart';
import '../rummy/rummy_rules.dart';
import '../rummy/rummy_state.dart';

class HandEngine extends RummyEngine {
  HandEngine(super.state);

  factory HandEngine.newMatch({RummyOptions options = const RummyOptions.hand(), required int seed}) {
    assert(options.variant == RummyVariant.hand);
    return HandEngine(RummyState.newMatch(options: options, seed: seed));
  }

  factory HandEngine.fromJson(Map<String, Object?> json) => HandEngine(RummyState.fromJson(json));
}

/// The Hand AI is the shared rummy AI (easy / medium / hard).
class HandAi extends RummyAi {
  const HandAi();
}
