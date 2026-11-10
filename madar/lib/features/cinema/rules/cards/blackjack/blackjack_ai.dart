/// Blackjack AI seats (B-70): easy plays like the dealer, medium follows the
/// chart but plays like the dealer on a random 15 % of its decisions, hard
/// follows the chart exactly for the table's options.
///
/// No level searches: the dealer's play is fixed, so the chart is already
/// the best fixed play without counting cards. The AIs read only their own
/// hand, the up card and the options, never the hole card or the shoe
/// (B-76); [determinize] exists so the shared fairness test can check that.
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_game.dart';
import '../core/card_rng.dart';
import 'blackjack_rules.dart';
import 'blackjack_state.dart';
import 'blackjack_strategy.dart';

class BlackjackAi extends HeuristicAi<BlackjackState, BlackjackMove> {
  const BlackjackAi() : super(const BlackjackRules());

  /// Share of medium's decisions played like the dealer.
  static const double mediumSlipRate = 0.15;

  BlackjackMove _legalOr(List<BlackjackMove> legal, BlackjackAction action) {
    final m = BlackjackMove(action);
    return legal.contains(m) ? m : (legal.contains(BlackjackMove.stand) ? BlackjackMove.stand : legal.first);
  }

  /// Between rounds seat 0 always deals (an endless session is ended by a
  /// person, not by an AI).
  BlackjackMove? _betweenRounds(BlackjackState s, List<BlackjackMove> legal) =>
      s.phase == BlackjackPhase.betweenRounds ? _legalOr(legal, BlackjackAction.deal) : null;

  @override
  BlackjackMove easyMove(BlackjackState s, int seat, List<BlackjackMove> legal, math.Random rng) =>
      _betweenRounds(s, legal) ?? _legalOr(legal, BlackjackStrategy.dealerLike(s));

  @override
  BlackjackMove mediumMove(BlackjackState s, int seat, List<BlackjackMove> legal, math.Random rng) =>
      _betweenRounds(s, legal) ?? _legalOr(legal, BlackjackStrategy.advise(s)?.action ?? BlackjackAction.stand);

  @override
  BlackjackMove chooseMove(BlackjackState state, int player, AiLevel level, math.Random rng, AiBudget budget) {
    final legal = rules.legalMoves(state, player);
    if (legal.isEmpty) throw StateError('No legal move for seat $player');
    final deal = _betweenRounds(state, legal);
    if (deal != null) return deal;
    switch (level) {
      case AiLevel.easy:
        return easyMove(state, player, legal, rng);
      case AiLevel.medium:
        // The draw happens for every decision so the random stream does not
        // depend on the number of legal moves.
        final slip = rng.nextDouble() < mediumSlipRate;
        return slip ? easyMove(state, player, legal, rng) : mediumMove(state, player, legal, rng);
      case AiLevel.hard:
        return mediumMove(state, player, legal, rng);
    }
  }

  /// A copy in which the hole card and the undealt shoe are shuffled
  /// together (and future shuffles re-seeded): everything a seat cannot see.
  @override
  BlackjackState determinize(BlackjackState s, int observer, math.Random rng) {
    final w = s.copy()..rng = CardRng(rng.nextInt(0x7fffffff));
    final pool = [...w.shoe, if (w.holeHidden) w.dealer[1]];
    shuffleWith(pool, rng);
    if (w.holeHidden) w.dealer[1] = pool.removeLast();
    w.shoe = pool;
    return w;
  }
}
