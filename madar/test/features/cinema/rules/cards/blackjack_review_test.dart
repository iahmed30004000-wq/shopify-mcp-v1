// Blackjack 21: adversarial review. The first group holds the cases that
// failed against the first implementation (each names the defect it proved);
// the second checks every settled round of seeded self-play against an
// independent re-computation of the rules (settlement, points, dealer play,
// advisor legality) for every rule set.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_ai.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_rules.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_state.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_strategy.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';

BlackjackEngine table(String draw, BlackjackOptions options) => BlackjackEngine(
  BlackjackState.custom(options: options.copyWith(burnCard: false), drawOrder: PlayingCard.list(draw)),
);

List<BlackjackEvent> play(BlackjackEngine e, BlackjackMove m) => e.apply(m).cast<BlackjackEvent>();

/// What the events of one round say each seat scored: every `handSettled`
/// plus any `lossCapped` (B-25, B-61g).
List<int> eventPoints(Iterable<BlackjackEvent> ev, int seats) {
  final out = List.filled(seats, 0);
  for (final e in ev) {
    if (e.kind == BlackjackEventKind.handSettled || e.kind == BlackjackEventKind.lossCapped) {
      out[e.seat!] += e.value!;
    }
  }
  return out;
}

/// The outcome the rules give [h] against the dealer's final cards
/// (B-13, B-22, B-24, B-55…B-59), computed without the engine.
BlackjackOutcome expectedOutcome(BlackjackHand h, List<PlayingCard> dealer) {
  final dealerNatural = dealer.length == 2 && blackjackTotal(dealer).total == 21;
  final dealerTotal = blackjackTotal(dealer).total;
  final natural = !h.fromSplit && h.cards.length == 2 && h.total == 21;
  if (h.surrendered) return BlackjackOutcome.surrendered;
  if (natural) return dealerNatural ? BlackjackOutcome.push : BlackjackOutcome.blackjack;
  if (h.total > 21 || dealerNatural) return BlackjackOutcome.loss;
  if (dealerTotal > 21 || h.total > dealerTotal) return BlackjackOutcome.win;
  return h.total == dealerTotal ? BlackjackOutcome.push : BlackjackOutcome.loss;
}

int expectedNet(BlackjackOutcome o, bool doubled, BlackjackOptions options) => switch (o) {
  BlackjackOutcome.blackjack => options.blackjackBonus,
  BlackjackOutcome.win => doubled ? 4 : 2,
  BlackjackOutcome.push => 0,
  BlackjackOutcome.loss => doubled ? -4 : -2,
  BlackjackOutcome.surrendered => -1,
};

void main() {
  group('defects found in review (each failed before its fix)', () {
    test('B-25/B-61g originalOnly: the handSettled events of a seat add up to its round points', () {
      // Split into three hands, two doubled; the dealer's second card makes a
      // natural. The seat loses −2 in all, and the events must say so.
      final e = table('8S TD 8H 8C 3S 9H 2D 5S 7D AS', const BlackjackOptions.european(originalOnly: true));
      final ev = <BlackjackEvent>[
        ...play(e, BlackjackMove.deal),
        ...play(e, BlackjackMove.split),
        ...play(e, BlackjackMove.split),
        ...play(e, BlackjackMove.doubleHand),
        ...play(e, BlackjackMove.doubleHand),
        ...play(e, BlackjackMove.stand),
      ];
      expect(e.state.lastRound!.dealerBlackjack, isTrue);
      expect(e.state.lastRound!.seatPoints, [-2]);
      expect(eventPoints(ev, 1), [-2]);
      final capped = [
        for (final x in ev)
          if (x.kind == BlackjackEventKind.lossCapped) x,
      ];
      expect(capped.single.value, 8); // −4 −4 −2 → −2
      expect(
        ev.indexOf(capped.single),
        lessThan(ev.indexWhere((x) => x.kind == BlackjackEventKind.roundScored)),
      );
    });

    test('B-25/B-61g originalOnly: a hand busted before the dealer natural is inside the seat\'s −2', () {
      // Split 8-8: the first hand doubles and busts (−4 at once), the second
      // stands; the dealer's second card makes a natural.
      final e = table('8S TD 8H 5C TH 9D AS', const BlackjackOptions.european(originalOnly: true));
      final ev = <BlackjackEvent>[
        ...play(e, BlackjackMove.deal),
        ...play(e, BlackjackMove.split),
        ...play(e, BlackjackMove.doubleHand), // 8 5 T = 23
        ...play(e, BlackjackMove.stand), // 8 9 = 17
      ];
      expect(e.state.seats.first.hands.first.bust, isTrue);
      expect(e.state.lastRound!.dealerBlackjack, isTrue);
      expect(e.scores, [-2]);
      expect(eventPoints(ev, 1), [-2]);
      // Without originalOnly nothing is capped: −4 and −2.
      final full = table('8S TD 8H 5C TH 9D AS', const BlackjackOptions.european());
      final ev2 = <BlackjackEvent>[
        ...play(full, BlackjackMove.deal),
        ...play(full, BlackjackMove.split),
        ...play(full, BlackjackMove.doubleHand),
        ...play(full, BlackjackMove.stand),
      ];
      expect(full.scores, [-6]);
      expect(eventPoints(ev2, 1), [-6]);
      expect(ev2.where((x) => x.kind == BlackjackEventKind.lossCapped), isEmpty);
    });

    test('§5.8 European table with H17: 8-8 against an ace is hit (the European change wins over the H17 one)', () {
      final euH17 = const BlackjackOptions.european().copyWith(dealerHitsSoft17: true);
      expect(BlackjackStrategy.pairCode(8, 11, euH17), isNull);
      expect(BlackjackStrategy.pairCode(8, 10, euH17), isNull);
      final e = table('8S AD 8H', euH17);
      e.apply(BlackjackMove.deal);
      expect(e.state.canSplit, isTrue);
      expect(e.advice()!.action, BlackjackAction.hit);
      expect(
        const BlackjackAi().chooseMove(e.state, 0, AiLevel.hard, CardRng(1), AiBudget.phone),
        BlackjackMove.hit,
      );
      // With originalOnly the peek chart applies, and H17 makes it Rp → split
      // (no surrender on the European table).
      final eo = table('8S AD 8H', euH17.copyWith(originalOnly: true));
      eo.apply(BlackjackMove.deal);
      expect(eo.advice()!.action, BlackjackAction.split);
      // On a peek table with H17 and late surrender it is still Rp → surrender.
      final peek = table('8S AD 8H 9C', const BlackjackOptions(dealerHitsSoft17: true, surrender: BlackjackSurrender.late));
      peek.apply(BlackjackMove.deal);
      expect(peek.advice()!.code, BlackjackChartCode.surrenderOrSplit);
      expect(peek.advice()!.action, BlackjackAction.surrender);
    });
  });

  group('every settled round agrees with an independent re-computation', () {
    final sets = <String, BlackjackOptions>{
      'jordan 3 seats': const BlackjackOptions(seats: 3, sessionRounds: 50),
      'continuous shuffle, 2 packs, no burn': const BlackjackOptions(
        decks: 2,
        continuousShuffle: true,
        burnCard: false,
        seats: 2,
        sessionRounds: 50,
      ),
      'h17 late surrender 2 seats': const BlackjackOptions(
        seats: 2,
        dealerHitsSoft17: true,
        surrender: BlackjackSurrender.late,
        sessionRounds: 50,
      ),
      'european 3 seats': const BlackjackOptions.european(seats: 3, sessionRounds: 50),
      'european originalOnly 3 seats': const BlackjackOptions.european(seats: 3, sessionRounds: 50, originalOnly: true),
      'one pack, every split option, winsOnly': const BlackjackOptions(
        decks: 1,
        penetration: 0.85,
        seats: 3,
        resplitAces: true,
        hitSplitAces: true,
        doubleAfterSplit: false,
        doubleOn: BlackjackDoubleOn.nineToEleven,
        tally: BlackjackTally.winsOnly,
        blackjackBonus: 2,
        autoStandOn21: false,
        sessionRounds: 50,
      ),
      'european originalOnly, one pack, winsOnly': const BlackjackOptions(
        decks: 1,
        penetration: 0.85,
        seats: 3,
        holeCard: BlackjackHoleCard.europeanNoHoleCard,
        originalOnly: true,
        tally: BlackjackTally.winsOnly,
        maxHands: 3,
        sessionRounds: 50,
      ),
    };
    const ai = BlackjackAi();
    for (final entry in sets.entries) {
      test(entry.key, () {
        final o = entry.value;
        var rounds = 0;
        var capped = 0;
        for (var seed = 1; seed <= 6; seed++) {
          final e = BlackjackEngine.newMatch(seed: seed, options: o);
          final rng = CardRng(seed * 101);
          final roundEvents = <BlackjackEvent>[];
          final before = [for (final s in e.state.seats) s.handsPlayed];
          // Levels differ per seed so splits, doubles and dealer-like play
          // all happen.
          final level = AiLevel.values[seed % 3];
          while (!e.isOver) {
            final seat = e.currentPlayer!;
            if (e.state.phase == BlackjackPhase.playerTurn) {
              final advice = BlackjackStrategy.advise(e.state)!;
              expect(e.legalMoves(seat), contains(BlackjackMove(advice.action)), reason: 'advice must be legal');
            }
            final m = ai.chooseMove(e.state, seat, level, rng, AiBudget.phone);
            final shoeBefore = e.state.shoe.length;
            final ev = play(e, m);
            roundEvents.addAll(ev);
            if (m == BlackjackMove.deal) {
              // B-2…B-4: a shuffle before the round only below the line (or
              // always, continuous), and a burn only after a cut-card one.
              final reasons = [
                for (final x in ev)
                  if (x.kind == BlackjackEventKind.shoeShuffled) x.reason,
              ];
              final burned = ev.where((x) => x.kind == BlackjackEventKind.cardBurned).length;
              if (o.continuousShuffle) {
                expect(reasons.first, 'continuous');
                expect(burned, 0);
              } else if (shoeBefore < o.reshuffleBelow) {
                expect(reasons.first, 'cutCard');
                expect(burned, o.burnCard ? 1 : 0);
              } else {
                expect(reasons.where((r) => r != 'emergency'), isEmpty);
                expect(burned, 0);
              }
            }
            if (!ev.any((x) => x.kind == BlackjackEventKind.roundScored)) continue;

            // One round has just been settled.
            rounds++;
            final s = e.state;
            final last = s.lastRound!;
            final dealer = s.dealer;
            expect(s.holeHidden, isFalse);
            expect(last.dealerBlackjack, dealer.length == 2 && blackjackTotal(dealer).total == 21);
            expect(last.dealerTotal, blackjackTotal(dealer).total);
            // The dealer's play (B-50…B-52): every card after the first two
            // was taken on a hitting total, and a dealer who played stopped
            // on a standing total (or ran out of cards).
            for (var k = 2; k < dealer.length; k++) {
              expect(BlackjackRules.dealerHits(dealer.sublist(0, k), o), isTrue, reason: 'dealer drew on $dealer');
            }
            final anyLive = [
              for (final seatState in s.seats)
                for (final h in seatState.hands)
                  if (!h.surrendered && !h.bust && !h.natural) h,
            ].isNotEmpty;
            if (anyLive && !last.dealerBlackjack && dealer.length >= 2) {
              final cardsLeft = s.shoe.isNotEmpty || s.discards.isNotEmpty;
              expect(BlackjackRules.dealerHits(dealer, o) && cardsLeft, isFalse, reason: 'dealer stopped early');
            }
            if (!anyLive && !o.european) expect(dealer.length, 2, reason: 'B-50 no live hand: no dealer card');
            final settled = roundEvents.where((x) => x.kind == BlackjackEventKind.handSettled).toList();
            expect(settled.length, s.seats.fold<int>(0, (n, seatState) => n + seatState.hands.length));
            for (var i = 0; i < s.seats.length; i++) {
              final hands = s.seats[i].hands;
              var net = 0;
              for (final h in hands) {
                final outcome = expectedOutcome(h, dealer);
                expect(h.outcome, outcome, reason: 'seat $i hand ${h.cards} vs $dealer');
                net += expectedNet(outcome, h.doubled, o);
              }
              if (last.dealerBlackjack && o.originalOnlyApplies) {
                net = hands.any((h) => h.natural) ? 0 : -2;
              }
              final tallied = o.tally == BlackjackTally.winsOnly
                  ? [for (final h in hands) expectedNet(h.outcome!, h.doubled, o)].fold<int>(0, (a, b) => a + (b > 0 ? b : 0))
                  : net;
              expect(last.seatPoints[i], tallied, reason: 'seat $i points');
              expect(hands.fold<int>(0, (a, h) => a + h.points), last.seatPoints[i]);
              expect(s.seats[i].handsPlayed - before[i], hands.length);
              before[i] = s.seats[i].handsPlayed;
            }
            expect(eventPoints(roundEvents, s.seats.length), last.seatPoints, reason: 'events vs points');
            capped += roundEvents.where((x) => x.kind == BlackjackEventKind.lossCapped).length;
            roundEvents.clear();
          }
        }
        expect(rounds, 300);
        if (!o.originalOnlyApplies) expect(capped, 0);
      });
    }
  });
}
