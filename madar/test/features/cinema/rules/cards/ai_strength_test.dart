// Sanity check: the hard AI beats the easy AI over seeded matches, for every
// game and main variant of the registry.
//
// Deterministic: the hard AI's budget is a fixed number of simulations, so
// every seed replays exactly. The thresholds are deliberately loose.
//
// Not here, by design: Blackjack 21 (the dealer is not an opponent; its
// strength test, B-77, compares points per hand over 20 000 hands in
// `blackjack_ai_test.dart`) and Solitaire (no opponent; hard wins more of the
// same 200 deals than easy in `solitaire_ai_test.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/baloot/baloot_ai.dart';
import 'package:madar/features/cinema/rules/cards/baloot/baloot_rules.dart';
import 'package:madar/features/cinema/rules/cards/basra/basra_ai.dart';
import 'package:madar/features/cinema/rules/cards/basra/basra_rules.dart';
import 'package:madar/features/cinema/rules/cards/basra/basra_state.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/hand/hand.dart';
import 'package:madar/features/cinema/rules/cards/konkan/konkan.dart';
import 'package:madar/features/cinema/rules/cards/rummy/rummy_state.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_rules.dart';
import 'package:madar/features/cinema/rules/cards/trix/trix_ai.dart';
import 'package:madar/features/cinema/rules/cards/trix/trix_rules.dart';
import 'package:madar/features/cinema/rules/cards/trix/trix_state.dart';

import 'support.dart';

class Duel {
  Duel(this.kit, this.matches, {this.budget = const AiBudget.simulations(24)});

  final Kit kit;
  final int matches;
  final AiBudget budget;
}

/// True for a four-seat game played in partnerships (seats 0 & 2 against
/// 1 & 3), where both partners of the hard side must be hard.
bool isPartnership(CardGameState s) => s.playerCount == 4 && s.teamOf(0) == s.teamOf(2);

/// Plays [d.matches] matches; the hard side alternates between the two
/// teams (partnerships: both partners hard) or rotates one hard seat round
/// the table (individual games), so seat order does not matter. A match
/// counts as a hard win when a hard seat is among the match winners.
/// Returns (hard wins, average points edge of the hard side).
(int, double) duel(Duel d) {
  var wins = 0;
  var edge = 0.0;
  for (var m = 0; m < d.matches; m++) {
    final probe = d.kit.create(1000 + m).state;
    final n = probe.playerCount;
    final hardSeats = isPartnership(probe)
        ? [
            for (var s = 0; s < n; s++)
              if (s % 2 == m % 2) s,
          ]
        : [m % n];
    final levels = [for (var s = 0; s < n; s++) hardSeats.contains(s) ? AiLevel.hard : AiLevel.easy];
    final r = playMatch(d.kit, 1000 + m, levels, budget: d.budget);
    final sign = probe.lowerScoreWins ? -1 : 1;
    final hard = hardSeats.map((s) => r.scores[s]).reduce((a, b) => a + b) / hardSeats.length;
    final others = [
      for (var s = 0; s < n; s++)
        if (!hardSeats.contains(s)) r.scores[s],
    ];
    final easy = others.reduce((a, b) => a + b) / others.length;
    edge += sign * (hard - easy);
    if (r.winners.any(hardSeats.contains)) wins++;
  }
  return (wins, edge / d.matches);
}

void main() {
  final duels = <String, Duel>{
    'tarneeb': Duel(
      Kit('tarneeb', (seed) => TarneebEngine.newMatch(seed: seed), TarneebEngine.fromJson, const TarneebAi()),
      8,
    ),
    'forty-one': Duel(
      Kit('forty-one', (seed) => FortyOneEngine.newMatch(seed: seed), FortyOneEngine.fromJson, const FortyOneAi()),
      8,
    ),
    'trix': Duel(Kit('trix', (seed) => TrixEngine.newMatch(seed: seed), TrixEngine.fromJson, const TrixAi()), 4),
    'trix complex': Duel(
      Kit(
        'trix complex',
        (seed) => TrixEngine.newMatch(seed: seed, options: TrixPreset.complex.options),
        TrixEngine.fromJson,
        const TrixAi(),
      ),
      4,
    ),
    'basra': Duel(
      Kit(
        'basra',
        (seed) => BasraEngine.newMatch(seed: seed, options: const BasraOptions(targetScore: 61)),
        BasraEngine.fromJson,
        const BasraAi(),
      ),
      8,
    ),
    'baloot': Duel(
      Kit('baloot', (seed) => BalootEngine.newMatch(seed: seed), BalootEngine.fromJson, const BalootAi()),
      8,
    ),
    'hand': Duel(
      Kit(
        'hand',
        (seed) => HandEngine.newMatch(seed: seed, options: const RummyOptions.hand(rounds: 3)),
        HandEngine.fromJson,
        const HandAi(),
      ),
      8,
    ),
    'hand partnership': Duel(
      Kit(
        'hand partnership',
        (seed) => HandEngine.newMatch(seed: seed, options: const RummyOptions.handPartnership(rounds: 3)),
        HandEngine.fromJson,
        const HandAi(),
      ),
      6,
    ),
    // The Jordanian match end (elimination), with the shorter 101 limit.
    'konkan': Duel(
      Kit(
        'konkan',
        (seed) => KonkanEngine.newMatch(seed: seed, options: const RummyOptions.konkan(eliminationScore: 101)),
        KonkanEngine.fromJson,
        const KonkanAi(),
      ),
      6,
    ),
  };
  for (final e in duels.entries) {
    test('${e.key}: hard beats easy', () {
      final (wins, edge) = duel(e.value);
      // ignore: avoid_print
      print('${e.key}: hard won $wins/${e.value.matches}, average edge ${edge.toStringAsFixed(1)}');
      // More points than the easy side on average, and at least as many wins
      // as chance (1 in 2 for partnerships, 1 in n for a lone hard seat).
      final probe = e.value.kit.create(0).state;
      final sides = isPartnership(probe) ? 2 : probe.playerCount;
      expect(edge, greaterThan(0));
      expect(wins, greaterThanOrEqualTo(e.value.matches / sides));
    });
  }
}
