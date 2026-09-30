/// Konkan (كونكان): the rummy engine with `RummyOptions.konkan()` – the
/// Hand core (106 cards, 14 / 15, the starter only discards first, 51 to
/// open, one wild per meld, the top discard only into a new meld), nothing
/// for going out, a one-turn finish (كونكان) doubles everyone else, a joker
/// left in hand costs 25, and a player whose total goes over 301 is out
/// until one player is left. Low confidence: see RULES.md.
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

/// The Konkan AI is the shared rummy AI; near the elimination score it
/// sheds high cards first.
class KonkanAi extends RummyAi {
  const KonkanAi();
}
