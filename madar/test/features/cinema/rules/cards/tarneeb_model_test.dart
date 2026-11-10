// Tarneeb and "41" checked against an independent model of the written rules
// (RULES.md §1 and §1b, the final Jordanian spec). The model below is written
// straight from the rule text – not from the engine – and follows the same
// moves: after every move the seat to act, the dealer, the legal moves, the
// error id of every illegal move, the scores and finally the winner must
// agree. Matches are fuzzed over the options and presets (mostly AI moves,
// some random legal ones), and saved/restored through JSON at random.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_state.dart';

/// ♥ ↔ ♦, ♠ ↔ ♣.
Suit sameColourOther(Suit s) => switch (s) {
  Suit.hearts => Suit.diamonds,
  Suit.diamonds => Suit.hearts,
  Suit.spades => Suit.clubs,
  Suit.clubs => Suit.spades,
};

/// A-opt-3: no ace, no king in 2+, no queen in 3+, no jack in 4+.
bool worthless(List<PlayingCard> hand) {
  for (final suit in Suit.values) {
    final cards = hand.where((c) => c.suit == suit).toList();
    for (final c in cards) {
      if (c.rank == Rank.ace) return false;
      if (c.rank == Rank.king && cards.length >= 2) return false;
      if (c.rank == Rank.queen && cards.length >= 3) return false;
      if (c.rank == Rank.jack && cards.length >= 4) return false;
    }
  }
  return true;
}

/// A5 scoring, per team: (bidders, defenders) placed by the bidder's team.
List<int> tarneebDealPoints(TarneebOptions o, int bidder, int b, int t) {
  final d = 13 - t;
  final whenMade = o.defendersScoreWhenMade ? d : 0;
  final (int, int) r;
  if (b == 13) {
    r = t == 13
        ? (o.kabootBidMadeScore, whenMade)
        : (-o.kabootBidFailPenalty, o.kabootFailDefenders == TarneebKabootFail.doubled ? 2 * d : d);
  } else if (t >= b) {
    r = (t == 13 ? o.kabootScore : (o.madeScore == TarneebMadeScore.tricksTaken ? t : b), whenMade);
  } else {
    r = (
      -b,
      switch (o.failScore) {
        TarneebFailScore.defendersTricks => d,
        TarneebFailScore.bid => b,
        TarneebFailScore.nothing => 0,
      },
    );
  }
  return bidder.isEven ? [r.$1, r.$2] : [r.$2, r.$1];
}

enum ModelPhase { auction, naming, play, over }

/// Partnership Tarneeb per the rules text. Hands come from the engine at
/// each new deal (the shuffle is the engine's); everything else is tracked
/// here.
class TarneebModel {
  TarneebModel(this.o) : dealer = o.firstDealer;

  final TarneebOptions o;
  int dealer;
  int deals = 0;
  int rounds = 0;
  late List<List<PlayingCard>> hands;
  late int toAct;
  ModelPhase phase = ModelPhase.auction;
  final List<(int seat, int amount)> calls = [];
  int contract = 0;
  int declarer = -1;
  Suit? trumps;
  final List<(int seat, PlayingCard card)> trick = [];
  int tricksPlayed = 0;
  List<int> taken = [0, 0];
  List<int> scores = [0, 0];
  int? winner;

  void deal(TarneebState s) {
    deals++;
    hands = [for (final h in s.hands) List.of(h)];
    phase = ModelPhase.auction;
    toAct = (dealer + 1) % 4;
    calls.clear();
    contract = 0;
    declarer = -1;
    trick.clear();
    tricksPlayed = 0;
    taken = [0, 0];
    if (o.trumpMode == TarneebTrumpMode.exposedCardSisterSuit) {
      // A-opt-1: the dealer's shown card stays in the dealer's hand.
      expect(hands[dealer], contains(s.exposedCard));
      trumps = sameColourOther(s.exposedCard!.suit);
    } else {
      expect(s.exposedCard, isNull);
      trumps = null;
    }
  }

  bool passedOut(int seat) => calls.any((c) => c.$1 == seat && c.$2 == 0);

  bool get openingLead => phase == ModelPhase.play && trick.isEmpty && tricksPlayed == 0;

  List<PlayingCard> playable(int seat) {
    final hand = hands[seat];
    if (openingLead && o.firstLeadMustBeTrump && hand.any((c) => c.suit == trumps)) {
      return hand.where((c) => c.suit == trumps).toList();
    }
    if (trick.isEmpty) return hand;
    final follow = hand.where((c) => c.suit == trick.first.$2.suit).toList();
    return follow.isEmpty ? hand : follow;
  }

  bool get dealerForcedToBid =>
      o.allPass == TarneebAllPass.dealerTakesMinimum &&
      toAct == dealer &&
      calls.length == 3 &&
      calls.every((c) => c.$2 == 0);

  int get lowestBid {
    if (contract == 0) return o.minBid;
    return o.oneRoundAuction && toAct == dealer ? math.max(contract, o.minBid) : contract + 1;
  }

  bool get mayThrowIn =>
      o.worthlessHandRedeal && declarer < 0 && !calls.any((c) => c.$1 == toAct) && worthless(hands[toAct]);

  /// The error id the rules give for [m] (null = legal).
  String? errorFor(TarneebMove m) {
    if (phase == ModelPhase.over) return 'matchOver';
    switch (m.kind) {
      case TarneebMoveKind.pass:
        if (phase != ModelPhase.auction) return 'wrongPhase';
        return dealerForcedToBid ? 'dealerMustBid' : null;
      case TarneebMoveKind.bid:
        if (phase != ModelPhase.auction) return 'wrongPhase';
        if (m.amount! > 13) return 'bidTooHigh';
        return m.amount! < lowestBid ? 'bidTooLow' : null;
      case TarneebMoveKind.throwIn:
        if (phase != ModelPhase.auction) return 'wrongPhase';
        return mayThrowIn ? null : 'cannotThrowIn';
      case TarneebMoveKind.trump:
        return phase == ModelPhase.naming ? null : 'wrongPhase';
      case TarneebMoveKind.play:
        if (phase != ModelPhase.play) return 'wrongPhase';
        if (!hands[toAct].contains(m.card)) return 'cardNotInHand';
        if (playable(toAct).contains(m.card)) return null;
        return openingLead ? 'mustLeadTrump' : 'mustFollowSuit';
    }
  }

  /// Plays [m]; returns true when a new deal is dealt (hands to re-read).
  bool play(TarneebMove m) {
    final seat = toAct;
    switch (m.kind) {
      case TarneebMoveKind.throwIn:
        dealer = (dealer + 1) % 4; // A-opt-3: the next dealer deals.
        return true;
      case TarneebMoveKind.pass:
      case TarneebMoveKind.bid:
        final amount = m.kind == TarneebMoveKind.bid ? m.amount! : 0;
        calls.add((seat, amount));
        if (amount > 0) {
          contract = amount;
          declarer = seat;
        }
        if (contract == 13) return _auctionWon(); // A2.3
        if (o.oneRoundAuction) {
          // A-opt-2: one call each, the dealer last.
          if (seat != dealer) {
            toAct = (seat + 1) % 4;
            return false;
          }
          return declarer < 0 ? _allPassed() : _auctionWon();
        }
        if (o.passIsFinal) {
          final inAuction = [
            for (var i = 0; i < 4; i++)
              if (!passedOut(i)) i,
          ];
          if (inAuction.isEmpty) return _allPassed();
          if (declarer >= 0 && inAuction.length == 1) return _auctionWon();
          var next = (seat + 1) % 4;
          while (passedOut(next)) {
            next = (next + 1) % 4;
          }
          toAct = next;
          return false;
        }
        // A-opt-5: three passes in a row after a bid end it; four with no bid
        // throw the cards in.
        var trailing = 0;
        for (final c in calls.reversed) {
          if (c.$2 != 0) break;
          trailing++;
        }
        if (declarer >= 0 && trailing == 3) return _auctionWon();
        if (declarer < 0 && trailing == 4) return _allPassed();
        toAct = (seat + 1) % 4;
        return false;
      case TarneebMoveKind.trump:
        trumps = m.suit;
        _lead();
        return false;
      case TarneebMoveKind.play:
        hands[seat].remove(m.card);
        trick.add((seat, m.card!));
        if (trick.length < 4) {
          toAct = (seat + 1) % 4;
          return false;
        }
        // A4: the highest trump, else the highest card of the suit led.
        final led = trick.first.$2.suit;
        int strength(PlayingCard c) => c.suit == trumps ? 100 + c.rank.value : (c.suit == led ? c.rank.value : 0);
        var best = trick.first;
        for (final x in trick) {
          if (strength(x.$2) > strength(best.$2)) best = x;
        }
        taken[best.$1 % 2]++;
        tricksPlayed++;
        trick.clear();
        toAct = best.$1;
        if (tricksPlayed < 13) return false;
        // A5, A6.
        rounds++;
        final pts = tarneebDealPoints(o, declarer, contract, taken[declarer % 2]);
        scores = [scores[0] + pts[0], scores[1] + pts[1]];
        final target = o.targetScore;
        if (scores[0] >= target || scores[1] >= target) {
          winner = scores[0] == scores[1] ? declarer % 2 : (scores[0] > scores[1] ? 0 : 1);
        } else if (o.loseAtNegativeTarget && (scores[0] <= -target || scores[1] <= -target)) {
          winner = scores[0] <= -target ? 1 : 0;
        }
        if (winner != null) {
          phase = ModelPhase.over;
          return false;
        }
        dealer = (dealer + 1) % 4; // A1: after a scored deal.
        return true;
    }
  }

  bool _allPassed() {
    if (o.allPass == TarneebAllPass.redealNextDealer) dealer = (dealer + 1) % 4;
    return true; // A2.4: nobody scores; (the same) dealer deals again.
  }

  bool _auctionWon() {
    if (trumps != null) {
      _lead(); // Syrian: trumps are already known.
    } else {
      phase = ModelPhase.naming;
      toAct = declarer;
    }
    return false;
  }

  void _lead() {
    phase = ModelPhase.play;
    toAct = o.bidderLeads ? declarer : (dealer + 1) % 4;
  }
}

final allCards = buildDeck();

List<TarneebMove> everyTarneebMove() => [
  const TarneebMove.pass(),
  const TarneebMove.throwIn(),
  for (var b = 0; b <= 14; b++) TarneebMove.bid(b),
  for (final s in Suit.values) TarneebMove.trump(s),
  for (final c in allCards) TarneebMove.play(c),
];

TarneebOptions fuzzedTarneebOptions(math.Random r) => TarneebOptions(
  targetScore: [31, 41, 61, 21][r.nextInt(4)],
  minBid: r.nextInt(4) == 0 ? 8 : 7,
  passIsFinal: r.nextInt(3) != 0,
  oneRoundAuction: r.nextInt(4) == 0,
  allPass: TarneebAllPass.values[r.nextInt(3)],
  madeScore: TarneebMadeScore.values[r.nextInt(2)],
  failScore: TarneebFailScore.values[r.nextInt(3)],
  defendersScoreWhenMade: r.nextInt(3) == 0,
  kabootFailDefenders: TarneebKabootFail.values[r.nextInt(2)],
  trumpMode: TarneebTrumpMode.values[r.nextInt(2)],
  bidderLeads: r.nextInt(3) != 0,
  firstLeadMustBeTrump: r.nextBool(),
  worthlessHandRedeal: r.nextBool(),
  loseAtNegativeTarget: r.nextBool(),
  firstDealer: r.nextInt(4),
);

/// The 41 value tables (B3), read with the bidder's score at the deal start.
int fortyOneValue(FortyOneOptions o, int bid, int ownScore) => switch (o.valueTable) {
  FortyOneValueTable.faceValue => bid,
  FortyOneValueTable.doubleFrom7 => bid >= 7 ? 2 * bid : bid,
  FortyOneValueTable.levant400 =>
    bid >= 10
        ? (o.levantTenPlus == FortyOneTenPlus.flat40 ? 40 : 4 * bid)
        : (ownScore < 30 ? const [1, 2, 3, 4, 10, 12, 14, 16, 27] : const [1, 2, 3, 4, 5, 6, 14, 16, 27])[bid - 1],
};

/// 400 rising minimums: +1 at 30, +2 at 40, +3 from 50.
int risingStep(int score) => score < 30 ? 0 : (score < 40 ? 1 : (score < 50 ? 2 : 3));

void main() {
  test('Tarneeb: the engine follows the rules model move by move (fuzzed options and presets)', () {
    const ai = TarneebAi();
    final everything = everyTarneebMove();
    var dealsSeen = 0;
    for (var g = 0; g < 36; g++) {
      final r = CardRng(1000 + g);
      final o = switch (g) {
        0 => const TarneebOptions(),
        1 => const TarneebOptions.syrianTrump(),
        2 => const TarneebOptions.lebaneseAuction(),
        3 => const TarneebOptions.openAuction(),
        _ => fuzzedTarneebOptions(r),
      };
      var e = TarneebEngine.newMatch(seed: g, options: o);
      final model = TarneebModel(o)..deal(e.state);
      for (var n = 0; n < 2500 && !e.isOver; n++) {
        final why = 'match $g move $n (${o.toJson()})';
        final seat = e.currentPlayer!;
        expect(seat, model.toAct, reason: why);
        expect(e.state.dealer, model.dealer, reason: why);
        expect(e.state.dealNumber, model.deals, reason: why);
        expect(e.state.roundNumber, model.rounds, reason: why);
        final legal = e.legalMoves(seat).toSet();
        for (final m in everything) {
          final expected = model.errorFor(m);
          expect(e.validate(m), expected, reason: '$why: $m');
          expect(legal.contains(m), expected == null, reason: '$why: $m');
        }
        // Mostly the AI (easy or medium); now and then any legal move, with
        // a throw-in whenever one is allowed.
        final options = legal.toList();
        final TarneebMove m;
        if (legal.contains(const TarneebMove.throwIn()) && r.nextBool()) {
          m = const TarneebMove.throwIn();
        } else if (r.nextInt(8) == 0) {
          m = e.state.phase == TarneebPhase.bidding
              ? options[r.nextInt(math.min(options.length, 3))]
              : options[r.nextInt(options.length)];
        } else {
          m = ai.chooseMove(e.state, seat, AiLevel.values[r.nextInt(2)], r, AiBudget.phone);
        }
        final dealt = model.play(m);
        e.apply(m);
        if (dealt) {
          model.deal(e.state);
          dealsSeen++;
        }
        expect(e.state.teamScores, model.scores, reason: why);
        if (r.nextInt(30) == 0) {
          final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
          e = TarneebEngine.fromJson(json);
          expect(jsonEncode(e.toJson()), jsonEncode(json), reason: why);
        }
      }
      expect(e.state.winnerTeam, model.winner, reason: 'match $g');
      if (e.isOver) expect(e.validate(const TarneebMove.pass()), 'matchOver');
    }
    expect(dealsSeen, greaterThan(200));
  });

  test('41: the engine follows the rules model deal by deal (fuzzed options and presets)', () {
    const ai = FortyOneAi();
    var scoredDeals = 0;
    var throwIns = 0;
    for (var g = 0; g < 30; g++) {
      final r = CardRng(5000 + g);
      final o = switch (g) {
        0 => const FortyOneOptions(),
        1 => const FortyOneOptions.lebanese400(),
        2 => const FortyOneOptions.syrian(),
        _ => FortyOneOptions(
          trumpMode: FortyOneTrumpMode.values[r.nextInt(2)],
          minBid: 1 + r.nextInt(2),
          risingMinimums: r.nextBool(),
          valueTable: FortyOneValueTable.values[r.nextInt(3)],
          levantTenPlus: FortyOneTenPlus.values[r.nextInt(2)],
          partnerRule: FortyOnePartnerRule.values[r.nextInt(2)],
          bothQualify: FortyOneBothQualify.values[r.nextInt(2)],
          throwInRedeal: FortyOneThrowIn.values[r.nextInt(2)],
          firstLead: FortyOneFirstLead.values[r.nextInt(2)],
          bid13WinsMatch: r.nextBool(),
          firstDealer: r.nextInt(4),
        ),
      };
      var e = FortyOneEngine.newMatch(seed: g, options: o);
      var dealer = o.firstDealer;
      var scores = [0, 0, 0, 0];
      int? winner;
      for (var n = 0; n < 3000 && !e.isOver; n++) {
        final why = 'match $g move $n (${o.toJson()})';
        final s = e.state;
        expect(s.dealer, dealer, reason: why);
        if (o.trumpMode == FortyOneTrumpMode.heartsFixed) {
          expect(s.trump, Suit.hearts, reason: why);
        } else {
          expect(s.trump, sameColourOther(s.exposedCard!.suit), reason: why);
          expect([...s.hands[dealer], ...s.playedCards], contains(s.exposedCard), reason: why);
        }
        final seat = e.currentPlayer!;
        final legal = e.legalMoves(seat);
        if (s.phase == FortyOnePhase.bidding) {
          // B2: one bid each from the dealer's right, minBid (rising in 400)
          // to 13, no pass.
          final bidsSoFar = s.bids.where((b) => b != null).length;
          expect(seat, (dealer + 1 + bidsSoFar) % 4, reason: why);
          final lowest = o.minBid + (o.risingMinimums ? risingStep(scores[seat]) : 0);
          expect(legal, [for (var b = lowest; b <= 13; b++) FortyOneMove.bid(b)], reason: why);
          for (var b = 0; b <= 15; b++) {
            expect(
              e.validate(FortyOneMove.bid(b)),
              b > 13 ? 'bidTooHigh' : (b < lowest ? 'bidTooLow' : null),
              reason: '$why bid $b',
            );
          }
          expect(e.validate(FortyOneMove.play(s.hands[seat].first)), 'wrongPhase', reason: why);
        } else {
          // B3: follow suit if able, else anything.
          final led = s.trick!.ledSuit;
          final follow = led == null ? <PlayingCard>[] : s.hands[seat].where((c) => c.suit == led).toList();
          final playable = follow.isEmpty ? s.hands[seat] : follow;
          expect(legal.map((m) => m.card).toSet(), playable.toSet(), reason: why);
          for (final c in allCards) {
            final v = e.validate(FortyOneMove.play(c));
            expect(
              v,
              playable.contains(c) ? null : (s.hands[seat].contains(c) ? 'mustFollowSuit' : 'cardNotInHand'),
              reason: '$why $c',
            );
          }
        }
        final m = r.nextInt(6) == 0 && s.phase == FortyOnePhase.playing
            ? legal[r.nextInt(legal.length)]
            : ai.chooseMove(s, seat, AiLevel.values[r.nextInt(2)], r, AiBudget.phone);
        final bidsBefore = List.of(s.bids);
        final roundsBefore = s.roundNumber;
        e.apply(m);
        final t = e.state;
        if (m.kind == FortyOneMoveKind.bid && seat == dealer) {
          final bids = [...bidsBefore]..[seat] = m.amount;
          final total = bids.fold<int>(0, (a, b) => a + b!);
          final minTotal = o.minTotal + (o.risingMinimums ? risingStep(scores.reduce(math.max)) : 0);
          if (total < minTotal) {
            // Thrown in: no score; next (or the same) dealer.
            throwIns++;
            if (o.throwInRedeal == FortyOneThrowIn.nextDealer) dealer = (dealer + 1) % 4;
            expect(t.phase, FortyOnePhase.bidding, reason: why);
            expect(t.currentPlayer, (dealer + 1) % 4, reason: why);
            expect(t.playerScores, scores, reason: why);
          } else {
            var leader = (dealer + 1) % 4;
            if (o.firstLead == FortyOneFirstLead.highestBidder) {
              for (var i = 1; i < 4; i++) {
                final x = (dealer + 1 + i) % 4;
                if (bids[x]! > bids[leader]!) leader = x;
              }
            }
            expect(t.phase, FortyOnePhase.playing, reason: why);
            expect(t.currentPlayer, leader, reason: why);
          }
        }
        if (t.roundNumber != roundsBefore) {
          // B4 scoring and B5 winning.
          scoredDeals++;
          final res = t.lastResult!;
          expect(res.tricks.fold<int>(0, (a, b) => a + b), 13, reason: why);
          for (var i = 0; i < 4; i++) {
            final v = fortyOneValue(o, res.bids[i], scores[i]);
            expect(res.points[i], res.tricks[i] >= res.bids[i] ? v : -v, reason: '$why seat $i');
          }
          scores = [for (var i = 0; i < 4; i++) scores[i] + res.points[i]];
          expect(t.playerScores, scores, reason: why);
          bool partnerOk(int v) => o.partnerRule == FortyOnePartnerRule.positive ? v > 0 : v >= 0;
          bool qualifies(int team) =>
              (scores[team] >= o.target && partnerOk(scores[team + 2])) ||
              (scores[team + 2] >= o.target && partnerOk(scores[team]));
          int? w;
          if (o.bid13WinsMatch) {
            for (var i = 0; i < 4; i++) {
              if (res.bids[i] == 13 && res.tricks[i] == 13) w = i % 2;
            }
          }
          if (w == null && qualifies(0) != qualifies(1)) w = qualifies(0) ? 0 : 1;
          if (w == null && qualifies(0) && qualifies(1)) {
            final totals = [scores[0] + scores[2], scores[1] + scores[3]];
            final best = [math.max(scores[0], scores[2]), math.max(scores[1], scores[3])];
            final order = o.bothQualify == FortyOneBothQualify.higherTeamTotal ? [totals, best] : [best, totals];
            for (final k in order) {
              if (k[0] != k[1]) {
                w = k[0] > k[1] ? 0 : 1;
                break;
              }
            }
          }
          winner = w;
          if (w == null) {
            dealer = (dealer + 1) % 4;
            expect(t.currentPlayer, (dealer + 1) % 4, reason: why);
          } else {
            expect(t.isOver, isTrue, reason: why);
            expect(t.winnerTeam, w, reason: why);
          }
        }
        if (r.nextInt(30) == 0) {
          final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
          e = FortyOneEngine.fromJson(json);
          expect(jsonEncode(e.toJson()), jsonEncode(json), reason: why);
        }
      }
      if (e.isOver) expect(e.state.winnerTeam, winner, reason: 'match $g');
    }
    expect(scoredDeals, greaterThan(150));
    expect(throwIns, greaterThan(10));
  });
}
