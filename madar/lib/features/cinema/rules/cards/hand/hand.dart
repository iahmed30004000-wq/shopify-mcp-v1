/// Hand (هاند): the rummy engine with the Hand preset (two packs and four
/// jokers, 14 cards / 15 for the opener, 51 to open, −30 for going out,
/// "hand" finish doubles everyone else). See RULES.md.
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

/// The Hand AI is the shared rummy AI.
class HandAi extends RummyAi {
  const HandAi();
}
