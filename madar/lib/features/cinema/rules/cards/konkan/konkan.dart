/// Konkan (كونكان): the rummy engine with the Konkan preset (two packs and
/// two jokers, 14 cards / 15 for the opener, 51 to open, no bonus for going
/// out, a one-turn finish doubles everyone else, match to 500). See
/// RULES.md.
library;

import '../rummy/rummy_ai.dart';
import '../rummy/rummy_rules.dart';
import '../rummy/rummy_state.dart';

class KonkanEngine extends RummyEngine {
  KonkanEngine(super.state);

  factory KonkanEngine.newMatch({RummyOptions options = const RummyOptions.konkan(), required int seed}) {
    assert(options.variant == RummyVariant.konkan);
    return KonkanEngine(RummyState.newMatch(options: options, seed: seed));
  }

  factory KonkanEngine.fromJson(Map<String, Object?> json) => KonkanEngine(RummyState.fromJson(json));
}

/// The Konkan AI is the shared rummy AI.
class KonkanAi extends RummyAi {
  const KonkanAi();
}
