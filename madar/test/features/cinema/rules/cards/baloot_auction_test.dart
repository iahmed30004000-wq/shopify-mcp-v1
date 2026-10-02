// Baloot auction, doubling and locking as commonly played in Jordan (the
// Saudi rules): final spec §7–§9, rules B2–B5 and the §13 edge cases.
//
// The dealer is seat 3 in every fixture, so the speakers are P1 = seat 0
// (dealer's right), P2 = seat 1, P3 = seat 2 (dealer's left), P4 = seat 3.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

const pass = BalootMove.pass();
const sun = BalootMove.sun();
const ashkal = BalootMove.ashkal();
const confirm = BalootMove.confirm();
const kawesh = BalootMove.kawesh();
const raise = BalootMove.raise();
const raiseLocked = BalootMove.raise(locked: true);

/// A deal with [hands] (five cards each) and the up card [up]; the rest of
/// the pack is the stock.
BalootEngine deal({
  List<String> hands = const ['JS 9S AS 7H 8H', 'TS KS QS 9H TH', '8S 7S JH QH KH', 'AH 7D 8D JD QD'],
  String up = '9D',
  BalootOptions options = const BalootOptions(),
  List<int> scores = const [0, 0],
}) {
  final hs = [for (final h in hands) c(h)];
  final upCard = p(up);
  final stock = cardsMinus(buildDeck(ranks: balootRanks), [for (final h in hs) ...h, upCard]);
  final s = BalootState.withDeal(hands: hs, upCard: upCard, stock: stock, options: options)
    ..teamScores = List.of(scores);
  return BalootEngine(s);
}

void run(BalootEngine e, List<BalootMove> moves) {
  for (final m in moves) {
    expect(e.validate(m), isNull, reason: '$m at seat ${e.currentPlayer}');
    e.apply(m);
  }
}

bool hasAshkal(BalootEngine e) => e.legalMoves(e.currentPlayer!).contains(ashkal);

void main() {
  group('round 1 (§8)', () {
    test('B2.4 the dealer\'s right speaks first; round 1 offers pass, Hokom in the up suit, Sun', () {
      final e = deal();
      expect(e.currentPlayer, 0);
      expect(e.state.speakerIndex(0), 0);
      expect(e.state.speakerIndex(3), 3);
      expect(e.legalMoves(0), const [pass, BalootMove.hokom(Suit.diamonds), sun]);
      expect(e.validate(const BalootMove.hokom(Suit.spades)), 'hokomSuitNotAllowed');
    });

    test('B4.1 Ashkal only for the 3rd and 4th speakers', () {
      final e = deal();
      expect(hasAshkal(e), isFalse);
      run(e, [pass]);
      expect(hasAshkal(e), isFalse);
      expect(e.validate(ashkal), 'ashkalNotAllowed');
      run(e, [pass]);
      expect(e.legalMoves(2), const [pass, BalootMove.hokom(Suit.diamonds), sun, ashkal]);
      run(e, [pass]);
      expect(hasAshkal(e), isTrue);
    });

    test('B4.1 Ashkal only when every earlier speaker passed (§13)', () {
      final e = deal();
      run(e, [const BalootMove.hokom(Suit.diamonds), pass]);
      // P3 after a Hokom: Sun or pass only.
      expect(e.legalMoves(2), const [pass, sun]);
    });

    test('B4.9 no Ashkal on an up-turned Ace (option ashkalOnAce allows it); Sun still allowed', () {
      final e = deal(up: 'AD', hands: const ['JS 9S AS 7H 8H', 'TS KS QS 9H TH', '8S 7S JH QH KH', 'AH 7D 8D JD QD']);
      run(e, [pass, pass]);
      expect(hasAshkal(e), isFalse);
      expect(e.legalMoves(2), contains(sun));
      final f = deal(up: 'AD', options: const BalootOptions(ashkalOnAce: true));
      run(f, [pass, pass]);
      expect(hasAshkal(f), isTrue);
    });

    test('B3.3 B4.8 Ashkal is Sun for the partner, who takes the up card and two more', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, ashkal]);
      // Priority: P1 (the partner) and P2 may still say Sun.
      expect(e.state.bidStage, BalootBidStage.priority);
      expect(e.currentPlayer, 0);
      run(e, [pass, pass]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.mode, BalootMode.sun);
      expect(e.state.ashkal, isTrue);
      expect(e.state.bidder, 2);
      expect(e.state.buyer, 0);
      expect(e.state.hands[0], contains(p('9D')));
      expect(e.state.hands.every((h) => h.length == 8), isTrue);
      expect(e.state.stock, isEmpty);
    });

    test('§13 after an Ashkal by P3, P1 may take it as his own Sun', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, ashkal, sun]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.ashkal, isFalse);
      expect(e.state.buyer, 0);
      expect(e.state.bidder, 0);
    });

    test('B4.4 Sun priority: an earlier speaker takes a later Sun; the earliest first', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, sun]);
      expect(e.state.bidStage, BalootBidStage.priority);
      expect(e.state.bidQueue, [0, 1]);
      expect(e.legalMoves(0), const [pass, sun]);
      run(e, [pass, sun]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.buyer, 1);
      expect(e.state.hands[1], contains(p('9D')));
    });

    test('B4.2 Sun beats a Hokom; the earlier speakers (even the Hokom bidder) may take the Sun', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, const BalootMove.hokom(Suit.diamonds), sun]);
      // Seat 2's Sun: seats 0 and 1 are asked, in that order.
      expect(e.state.bidQueue, [0, 1]);
      run(e, [pass, sun]);
      expect((e.state.mode, e.state.buyer), (BalootMode.sun, 1));
    });

    test('B4.2 a Sun over a Hokom stands when the earlier speakers pass', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [const BalootMove.hokom(Suit.diamonds), pass, sun, pass, pass]);
      expect((e.state.mode, e.state.buyer), (BalootMode.sun, 2));
      expect(e.state.phase, BalootPhase.playing);
    });

    test('B4.2 §14 priority chain: Hokom by P4 → P2\'s Sun beats P3\'s', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, pass, const BalootMove.hokom(Suit.diamonds)]);
      expect(e.state.bidStage, BalootBidStage.priority);
      expect(e.state.bidQueue, [0, 1, 2]);
      run(e, [pass, sun]);
      expect(e.state.phase, BalootPhase.playing);
      expect((e.state.mode, e.state.buyer), (BalootMode.sun, 1));
    });

    test('B4.3 only one Hokom per round: after a Hokom only Sun or pass', () {
      final e = deal();
      run(e, [const BalootMove.hokom(Suit.diamonds)]);
      expect(e.legalMoves(1), const [pass, sun]);
      expect(e.validate(const BalootMove.hokom(Suit.diamonds)), 'hokomSuitNotAllowed');
    });

    test('option sunPriority off: the first Sun wins at once', () {
      final e = deal(options: const BalootOptions(sunPriority: false, doubling: false));
      run(e, [pass, pass, sun]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.buyer, 2);
      // A Hokom may still be overcalled by the earlier speakers.
      final f = deal(options: const BalootOptions(sunPriority: false, doubling: false));
      run(f, [pass, const BalootMove.hokom(Suit.diamonds), pass, pass]);
      expect(f.state.bidStage, BalootBidStage.priority);
      expect(f.state.bidQueue, [0]);
    });

    test('option ashkal off: nobody may call Ashkal', () {
      final e = deal(options: const BalootOptions(ashkal: false));
      run(e, [pass, pass]);
      expect(hasAshkal(e), isFalse);
    });
  });

  group('confirmation (B4.5)', () {
    test('a Hokom that stands: its bidder confirms it', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, const BalootMove.hokom(Suit.diamonds), pass, pass, pass]);
      expect(e.state.bidStage, BalootBidStage.confirm);
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(1), const [confirm, sun]);
      run(e, [confirm]);
      expect(e.state.phase, BalootPhase.playing);
      expect((e.state.mode, e.state.trump, e.state.buyer), (BalootMode.hokom, Suit.diamonds, 1));
      expect(e.state.hands[1], contains(p('9D')));
      // The dealer's right leads the first trick, whoever bought.
      expect(e.currentPlayer, 0);
    });

    test('… or switches to Sun (same taker, no new priority round)', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, const BalootMove.hokom(Suit.diamonds), pass, pass, pass]);
      final events = e.apply(sun);
      expect(events.first.detail, 'switchToSun');
      expect(e.state.phase, BalootPhase.playing);
      expect((e.state.mode, e.state.trump, e.state.buyer), (BalootMode.sun, null, 1));
    });

    test('option takerMaySwitchToSun off: the Hokom stands at once', () {
      final e = deal(options: const BalootOptions(doubling: false, takerMaySwitchToSun: false));
      run(e, [const BalootMove.hokom(Suit.diamonds), pass, pass, pass]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.buyer, 0);
    });

    test('§13 a taker who switched to Sun gets the Sun double rule, not the Hokom ladder', () {
      final e = deal();
      run(e, [const BalootMove.hokom(Suit.diamonds), pass, pass, pass, sun]);
      expect(e.state.phase, BalootPhase.playing);
      final f = deal(scores: [120, 40]);
      run(f, [const BalootMove.hokom(Suit.diamonds), pass, pass, pass, sun]);
      expect(f.state.phase, BalootPhase.doubling);
      expect(f.legalMoves(f.currentPlayer!), const [pass, raise]);
    });
  });

  group('round 2 (B4.6–B4.7)', () {
    test('Hokom in one of the other three suits, or Sun; no Ashkal', () {
      final e = deal();
      run(e, [pass, pass, pass, pass]);
      expect(e.state.bidRound, 2);
      expect(e.legalMoves(0).where((m) => m.kind == BalootMoveKind.hokom).map((m) => m.suit), [
        Suit.clubs,
        Suit.hearts,
        Suit.spades,
      ]);
      expect(e.validate(const BalootMove.hokom(Suit.diamonds)), 'hokomSuitNotAllowed');
      run(e, [pass, pass]);
      expect(hasAshkal(e), isFalse);
    });

    test('option ashkalInRound2 (Riyadh): Ashkal for P3/P4 in round 2 as well', () {
      final e = deal(options: const BalootOptions(ashkalInRound2: true, doubling: false));
      run(e, [pass, pass, pass, pass, pass, pass]);
      expect(hasAshkal(e), isTrue);
      run(e, [ashkal]);
      expect(e.state.phase, BalootPhase.playing);
      expect((e.state.mode, e.state.buyer), (BalootMode.sun, 0));
    });

    test('a round-2 Sun ends the auction at once (no priority)', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, pass, pass, pass, sun]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.buyer, 1);
    });

    test('§13 after a round-2 Hokom by P3 only P4 may still say Sun; then the confirmation', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, pass, pass, pass, pass, const BalootMove.hokom(Suit.clubs)]);
      expect(e.currentPlayer, 3);
      expect(e.legalMoves(3), const [pass, sun]);
      run(e, [pass]);
      expect(e.state.bidStage, BalootBidStage.confirm);
      expect(e.currentPlayer, 2);
      run(e, [confirm]);
      expect((e.state.mode, e.state.trump, e.state.buyer), (BalootMode.hokom, Suit.clubs, 2));
      expect(e.state.hands[2], contains(p('9D')));
    });

    test('B4.7 all pass twice: thrown in, no score, the next dealer deals', () {
      final e = deal();
      final events = <CardEvent>[];
      for (var i = 0; i < 8; i++) {
        events.addAll(e.apply(pass));
      }
      expect(events.any((x) => x.type == CardEventType.redeal), isTrue);
      expect(e.state.dealNumber, 2);
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.teamScores, [0, 0]);
      expect(e.state.bidRound, 1);
    });
  });

  group('options: the Ace third round and Kawesh', () {
    test('option aceThirdRound: all pass twice on an up-turned Ace → P1 alone may still bid', () {
      final e = deal(up: 'AD', options: const BalootOptions(aceThirdRound: true, doubling: false));
      run(e, [for (var i = 0; i < 8; i++) pass]);
      expect(e.state.bidRound, 3);
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [pass, for (final s in Suit.values) BalootMove.hokom(s), sun]);
      run(e, [const BalootMove.hokom(Suit.diamonds)]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.hands[0], contains(p('AD')));
      // P1 passes too: redeal.
      final f = deal(up: 'AD', options: const BalootOptions(aceThirdRound: true));
      run(f, [for (var i = 0; i < 9; i++) pass]);
      expect(f.state.dealNumber, 2);
      // No third round without the option, or without an Ace.
      final g = deal(up: 'AD');
      run(g, [for (var i = 0; i < 8; i++) pass]);
      expect(g.state.dealNumber, 2);
      final h = deal(options: const BalootOptions(aceThirdRound: true));
      run(h, [for (var i = 0; i < 8; i++) pass]);
      expect(h.state.dealNumber, 2);
    });

    test('option kawesh: a first hand of 7s, 8s and 9s only may annul the deal in round 1', () {
      const hands = ['7S 8S 9S 7H 8H', 'TS KS QS 9H TH', 'AS JS JH QH KH', 'AH 7D 8D JD QD'];
      final e = deal(hands: hands, options: const BalootOptions(kawesh: true));
      expect(e.legalMoves(0), contains(kawesh));
      final events = e.apply(kawesh);
      expect(events.first.detail, 'kawesh');
      expect(e.state.dealNumber, 2);
      expect(e.state.dealer, 0);
      expect(e.state.teamScores, [0, 0]);
      // Not without the option, not with a higher card, not in round 2.
      expect(deal(hands: hands).legalMoves(0), isNot(contains(kawesh)));
      final other = deal(hands: hands, options: const BalootOptions(kawesh: true));
      run(other, [pass]);
      expect(other.legalMoves(1), isNot(contains(kawesh)));
      expect(other.validate(kawesh), 'kaweshNotAllowed');
      run(other, [pass, pass, pass]);
      expect(other.state.bidRound, 2);
      expect(other.legalMoves(0), isNot(contains(kawesh)));
    });
  });

  group('doubling and locking (§9)', () {
    BalootEngine hokomBy0({List<int> scores = const [0, 0], BalootOptions options = const BalootOptions()}) {
      final e = deal(scores: scores, options: options);
      run(e, [const BalootMove.hokom(Suit.diamonds), pass, pass, pass, confirm]);
      return e;
    }

    test('B5.5 doubling comes after the deal is complete, before the first card', () {
      final e = hokomBy0();
      expect(e.state.phase, BalootPhase.doubling);
      expect(e.state.hands.every((h) => h.length == 8), isTrue);
      expect(e.state.trick, isNull);
    });

    test('B5.1–B5.2 the defenders in order: the one after the taker, then the other', () {
      final e = hokomBy0();
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(1), const [pass, raise, raiseLocked]);
      run(e, [pass]);
      expect(e.currentPlayer, 3);
      run(e, [pass]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.level, 1);
    });

    test('B5.1 the ladder: double (locked or open), triple by the taker, four by the doubler, gahwa', () {
      final e = hokomBy0();
      run(e, [pass, raiseLocked]);
      expect((e.state.level, e.state.doubler, e.state.locked, e.currentPlayer), (2, 3, true, 0));
      // The triple is always open.
      expect(e.legalMoves(0), const [pass, raise]);
      expect(e.validate(raiseLocked), 'lockNotAllowed');
      run(e, [raise]);
      expect((e.state.level, e.state.locked, e.currentPlayer), (3, false, 3));
      // Only the doubler may say four; locked or open again.
      expect(e.legalMoves(3), const [pass, raise, raiseLocked]);
      run(e, [raiseLocked]);
      expect((e.state.level, e.state.locked, e.currentPlayer), (4, true, 0));
      run(e, [raise]);
      expect(e.state.gahwa, isTrue);
      expect(e.state.locked, isFalse);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.lastRaiserTeam, 0);
    });

    test('B5.4 a locked double stands if the taker does not triple; the lead is restricted', () {
      final e = hokomBy0();
      final events = e.apply(raiseLocked);
      expect(events.single.detail, 'locked');
      run(e, [pass]);
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.locked, isTrue);
      expect(e.state.lastRaiserTeam, 1);
      final leader = e.currentPlayer!;
      final hand = e.state.hands[leader];
      final allTrumps = hand.every((x) => x.suit == Suit.diamonds);
      final leads = e.legalMoves(leader).map((m) => m.card!).toList();
      expect(leads.any((x) => x.suit == Suit.diamonds), allTrumps);
    });

    test('B5.4 an open double: trumps may be led', () {
      final e = hokomBy0();
      run(e, [raise, pass]);
      expect(e.state.locked, isFalse);
      expect(e.legalMoves(e.currentPlayer!).length, e.state.hands[e.currentPlayer!].length);
    });

    test('B5.3 Sun: a double only when the takers are over 100 and the defenders under 100', () {
      BalootEngine sunBy0(List<int> scores, [BalootOptions o = const BalootOptions()]) {
        final e = deal(scores: scores, options: o);
        run(e, [sun]);
        return e;
      }

      expect(sunBy0([0, 0]).state.phase, BalootPhase.playing);
      expect(sunBy0([40, 120]).state.phase, BalootPhase.playing);
      expect(sunBy0([100, 40]).state.phase, BalootPhase.playing);
      final f = sunBy0([120, 40]);
      expect(f.state.phase, BalootPhase.doubling);
      // Never locked, nothing after the double.
      expect(f.legalMoves(f.currentPlayer!), const [pass, raise]);
      run(f, [raise]);
      expect(f.state.level, 2);
      expect(f.state.locked, isFalse);
      expect(f.state.phase, BalootPhase.playing);
    });

    test('options sunDoubleRule: either direction, always, never', () {
      BalootPhase phase(List<int> scores, BalootSunDoubleRule rule) {
        final e = deal(
          scores: scores,
          options: BalootOptions(sunDoubleRule: rule),
        );
        run(e, [sun]);
        return e.state.phase;
      }

      expect(phase([40, 120], BalootSunDoubleRule.oneOver100OneUnder), BalootPhase.doubling);
      expect(phase([120, 40], BalootSunDoubleRule.oneOver100OneUnder), BalootPhase.doubling);
      expect(phase([120, 110], BalootSunDoubleRule.oneOver100OneUnder), BalootPhase.playing);
      expect(phase([0, 0], BalootSunDoubleRule.always), BalootPhase.doubling);
      expect(phase([120, 40], BalootSunDoubleRule.never), BalootPhase.playing);
      // The legacy boolean maps onto the rule.
      expect(const BalootOptions(sunDoubleOnlyWhenBehind: false).sunDoubleRule, BalootSunDoubleRule.always);
      expect(
        const BalootOptions(sunDoubleOnlyWhenBehind: true).sunDoubleRule,
        BalootSunDoubleRule.takersOver100DoublersUnder100,
      );
    });

    test('option doubling off: straight to play', () {
      final e = hokomBy0(options: const BalootOptions(doubling: false));
      expect(e.state.phase, BalootPhase.playing);
    });
  });

  group('first lead (B2.4, option firstLead)', () {
    test('the dealer\'s right leads, whoever bought; option: the taker leads', () {
      final e = deal(options: const BalootOptions(doubling: false));
      run(e, [pass, pass, pass, const BalootMove.hokom(Suit.diamonds), pass, pass, pass, confirm]);
      expect(e.state.buyer, 3);
      expect(e.currentPlayer, 0);
      final f = deal(options: const BalootOptions(doubling: false, firstLead: BalootFirstLead.taker));
      run(f, [pass, pass, pass, const BalootMove.hokom(Suit.diamonds), pass, pass, pass, confirm]);
      expect(f.currentPlayer, 3);
      expect(f.state.trick!.leader, 3);
    });
  });
}
