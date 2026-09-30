// TEMPORARY adversarial probe (reviewer): an independent shadow model of the
// final spec, driven by fuzzed moves, compared with the engine at every step.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_state.dart';

Suit sister(Suit s) => switch (s) {
  Suit.hearts => Suit.diamonds,
  Suit.diamonds => Suit.hearts,
  Suit.spades => Suit.clubs,
  Suit.clubs => Suit.spades,
};

bool worthless(List<PlayingCard> hand) {
  for (final s in Suit.values) {
    final cs = hand.where((c) => c.suit == s).toList();
    for (final c in cs) {
      if (c.rank == Rank.ace) return false;
      if (c.rank == Rank.king && cs.length >= 2) return false;
      if (c.rank == Rank.queen && cs.length >= 3) return false;
      if (c.rank == Rank.jack && cs.length >= 4) return false;
    }
  }
  return true;
}

/// Spec §A5.
List<int> specPoints(TarneebOptions o, int bidder, int b, int t) {
  final d = 13 - t;
  int whenMade() => o.defendersScoreWhenMade ? d : 0;
  (int, int) r;
  if (b == 13) {
    r = t == 13
        ? (o.kabootBidMadeScore, whenMade())
        : (-o.kabootBidFailPenalty, o.kabootFailDefenders == TarneebKabootFail.doubled ? 2 * d : d);
  } else if (t >= b) {
    final made = t == 13 ? o.kabootScore : (o.madeScore == TarneebMadeScore.tricksTaken ? t : b);
    r = (made, whenMade());
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
  final pts = [0, 0];
  pts[bidder % 2] = r.$1;
  pts[1 - bidder % 2] = r.$2;
  return pts;
}

class Shadow {
  Shadow(this.o, this.dealer);
  final TarneebOptions o;
  int dealer;
  late List<List<PlayingCard>> hands;
  late int turn;
  String phase = 'bidding';
  List<(int, int)> calls = [];
  List<bool> passed = List.filled(4, false);
  int high = 0;
  int highSeat = -1;
  Suit? trump;
  List<(int, PlayingCard)> trick = [];
  int tricksDone = 0;
  List<int> won = [0, 0];
  List<int> scores = [0, 0];
  int? winner;

  void newDeal(TarneebState s) {
    hands = [for (final h in s.hands) List.of(h)];
    phase = 'bidding';
    turn = (dealer + 1) % 4;
    calls = [];
    passed = List.filled(4, false);
    high = 0;
    highSeat = -1;
    trick = [];
    tricksDone = 0;
    won = [0, 0];
    if (o.trumpMode == TarneebTrumpMode.exposedCardSisterSuit) {
      expect(s.exposedCard, isNotNull);
      expect(hands[dealer], contains(s.exposedCard));
      trump = sister(s.exposedCard!.suit);
    } else {
      expect(s.exposedCard, isNull);
      trump = null;
    }
  }

  bool dealerMustBid(int seat) =>
      o.allPass == TarneebAllPass.dealerTakesMinimum &&
      seat == dealer &&
      calls.length == 3 &&
      calls.every((c) => c.$2 == 0);

  Set<TarneebMove> legal({required bool strictThrowIn}) {
    final seat = turn;
    switch (phase) {
      case 'bidding':
        var lo = high == 0 ? o.minBid : high + 1;
        if (o.oneRoundAuction && seat == dealer && high > 0) lo = math.max(high, o.minBid);
        return {
          if (!dealerMustBid(seat)) const TarneebMove.pass(),
          for (var b = lo; b <= 13; b++) TarneebMove.bid(b),
          if (o.worthlessHandRedeal &&
              !calls.any((c) => c.$1 == seat) &&
              (!strictThrowIn || highSeat < 0) &&
              worthless(hands[seat]))
            const TarneebMove.throwIn(),
        };
      case 'trump':
        return {for (final s in Suit.values) TarneebMove.trump(s)};
      case 'playing':
        final h = hands[seat];
        if (trick.isEmpty && tricksDone == 0 && o.firstLeadMustBeTrump && h.any((c) => c.suit == trump)) {
          return {for (final c in h.where((c) => c.suit == trump)) TarneebMove.play(c)};
        }
        if (trick.isEmpty) return {for (final c in h) TarneebMove.play(c)};
        final led = trick.first.$2.suit;
        final f = h.where((c) => c.suit == led).toList();
        return {for (final c in (f.isEmpty ? h : f)) TarneebMove.play(c)};
    }
    return {};
  }

  /// Returns true when a new deal starts (hands must be re-synced).
  bool apply(TarneebMove m) {
    final seat = turn;
    switch (m.kind) {
      case TarneebMoveKind.throwIn:
        dealer = (dealer + 1) % 4;
        return true;
      case TarneebMoveKind.bid:
      case TarneebMoveKind.pass:
        final amount = m.kind == TarneebMoveKind.bid ? m.amount! : 0;
        calls.add((seat, amount));
        if (amount > 0) {
          high = amount;
          highSeat = seat;
        } else {
          passed[seat] = true;
        }
        if (high == 13) return _end();
        if (o.oneRoundAuction) {
          if (seat != dealer) {
            turn = (seat + 1) % 4;
            return false;
          }
          return highSeat < 0 ? _allPass() : _end();
        }
        if (o.passIsFinal) {
          final active = [for (var i = 0; i < 4; i++) if (!passed[i]) i];
          if (active.isEmpty) return _allPass();
          if (highSeat >= 0 && active.length == 1) {
            expect(active.single, highSeat);
            return _end();
          }
          var n = (seat + 1) % 4;
          while (passed[n]) {
            n = (n + 1) % 4;
          }
          turn = n;
          return false;
        }
        // Open auction: count trailing passes.
        var trailing = 0;
        for (final c in calls.reversed) {
          if (c.$2 != 0) break;
          trailing++;
        }
        if (highSeat >= 0 && trailing >= 3) return _end();
        if (highSeat < 0 && trailing >= 4) return _allPass();
        turn = (seat + 1) % 4;
        return false;
      case TarneebMoveKind.trump:
        trump = m.suit;
        _startPlay();
        return false;
      case TarneebMoveKind.play:
        hands[seat].remove(m.card);
        trick.add((seat, m.card!));
        if (trick.length < 4) {
          turn = (seat + 1) % 4;
          return false;
        }
        final led = trick.first.$2.suit;
        int pw(PlayingCard c) => c.suit == trump ? 100 + c.rank.value : (c.suit == led ? c.rank.value : -1);
        var best = trick.first;
        for (final x in trick) {
          if (pw(x.$2) > pw(best.$2)) best = x;
        }
        won[best.$1 % 2]++;
        tricksDone++;
        trick = [];
        turn = best.$1;
        if (tricksDone < 13) return false;
        final pts = specPoints(o, highSeat, high, won[highSeat % 2]);
        scores = [scores[0] + pts[0], scores[1] + pts[1]];
        final t = o.targetScore;
        if (scores[0] >= t || scores[1] >= t) {
          winner = scores[0] > scores[1] ? 0 : (scores[1] > scores[0] ? 1 : highSeat % 2);
        } else if (o.loseAtNegativeTarget && (scores[0] <= -t || scores[1] <= -t)) {
          winner = scores[0] <= -t ? 1 : 0;
        }
        if (winner != null) {
          phase = 'over';
          return false;
        }
        dealer = (dealer + 1) % 4;
        return true;
    }
  }

  bool _allPass() {
    if (o.allPass == TarneebAllPass.redealNextDealer) dealer = (dealer + 1) % 4;
    return true;
  }

  bool _end() {
    if (trump != null) {
      _startPlay();
    } else {
      phase = 'trump';
      turn = highSeat;
    }
    return false;
  }

  void _startPlay() {
    phase = 'playing';
    turn = o.bidderLeads ? highSeat : (dealer + 1) % 4;
  }
}

List<TarneebMove> candidates(TarneebState s) => [
  const TarneebMove.pass(),
  const TarneebMove.throwIn(),
  for (var b = 0; b <= 14; b++) TarneebMove.bid(b),
  for (final x in Suit.values) TarneebMove.trump(x),
  for (final c in PlayingCard.list(
    '2S 3S 4S 5S 6S 7S 8S 9S TS JS QS KS AS 2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH '
    '2D 3D 4D 5D 6D 7D 8D 9D TD JD QD KD AD 2C 3C 4C 5C 6C 7C 8C 9C TC JC QC KC AC',
  ))
    TarneebMove.play(c),
];

const knownErrors = {
  'notYourTurn',
  'matchOver',
  'wrongPhase',
  'bidTooLow',
  'bidTooHigh',
  'dealerMustBid',
  'cannotThrowIn',
  'mustFollowSuit',
  'mustLeadTrump',
  'cardNotInHand',
};

TarneebOptions randomOptions(math.Random r) => TarneebOptions(
  targetScore: [31, 41, 61, 21][r.nextInt(4)],
  minBid: [7, 7, 7, 8, 13][r.nextInt(5)],
  passIsFinal: r.nextBool(),
  oneRoundAuction: r.nextInt(3) == 0,
  allPass: TarneebAllPass.values[r.nextInt(3)],
  madeScore: TarneebMadeScore.values[r.nextInt(2)],
  failScore: TarneebFailScore.values[r.nextInt(3)],
  defendersScoreWhenMade: r.nextBool(),
  kabootFailDefenders: TarneebKabootFail.values[r.nextInt(2)],
  trumpMode: TarneebTrumpMode.values[r.nextInt(2)],
  bidderLeads: r.nextBool(),
  firstLeadMustBeTrump: r.nextBool(),
  worthlessHandRedeal: r.nextBool(),
  loseAtNegativeTarget: r.nextBool(),
  firstDealer: r.nextInt(4),
);

void main() {
  test('tarneeb: engine == shadow model of the spec over fuzzed matches', () {
    final issues = <String>{};
    for (var g = 0; g < 120; g++) {
      final r = CardRng(1000 + g);
      final o = g == 0 ? const TarneebOptions() : randomOptions(r);
      var e = TarneebEngine.newMatch(seed: g, options: o);
      final sh = Shadow(o, o.firstDealer)..newDeal(e.state);
      var moves = 0;
      while (!e.isOver && moves < 30000) {
        final seat = e.currentPlayer!;
        expect(seat, sh.turn, reason: 'g$g m$moves turn');
        expect(e.state.dealer, sh.dealer, reason: 'g$g m$moves dealer');
        final legal = e.legalMoves(seat).toSet();
        final lenient = sh.legal(strictThrowIn: false);
        final strict = sh.legal(strictThrowIn: true);
        if (!legal.containsAll(strict) || !lenient.containsAll(legal)) {
          issues.add('g$g legal differs: engine ${legal.difference(lenient)} missing ${strict.difference(legal)}');
        }
        if (legal.length != strict.length) issues.add('throwIn after a bid offered (g$g)');
        for (final m in candidates(e.state)) {
          final v = e.validate(m);
          if ((v == null) != legal.contains(m)) issues.add('validate/legal mismatch $m -> $v');
          if (v != null && !knownErrors.contains(v)) issues.add('unknown error $v');
          if (m.kind == TarneebMoveKind.bid && m.amount! > 13 && v != 'bidTooHigh') {
            issues.add('bid ${m.amount} -> $v');
          }
        }
        // Pick: AI half the time, else random (biased to pass in the auction).
        TarneebMove m;
        final ls = legal.toList();
        if (r.nextInt(5) != 0) {
          m = const TarneebAi().chooseMove(e.state, seat, AiLevel.values[r.nextInt(2)], r, AiBudget.phone);
        } else if (e.state.phase == TarneebPhase.bidding) {
          m = ls[r.nextInt(math.min(ls.length, 3))];
          if (ls.contains(const TarneebMove.throwIn()) && r.nextBool()) m = const TarneebMove.throwIn();
        } else {
          m = ls[r.nextInt(ls.length)];
        }
        final newDeal = sh.apply(m);
        e.apply(m);
        moves++;
        if (newDeal) sh.newDeal(e.state);
        expect(e.state.teamScores, sh.scores, reason: 'g$g m$moves scores');
        if (r.nextInt(25) == 0) {
          final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
          e = TarneebEngine.fromJson(json);
          expect(jsonEncode(e.toJson()), jsonEncode(json));
        }
      }
      if (!e.isOver) issues.add('g$g did not end ${o.toJson()} ${e.state.teamScores}');
      expect(e.state.winnerTeam, sh.winner, reason: 'g$g winner');
    }
    // ignore: avoid_print
    print('TARNEEB ISSUES:\n${issues.join('\n')}');
  });

  test('41: engine == shadow model over fuzzed matches', () {
    final issues = <String>{};
    for (var g = 0; g < 80; g++) {
      final r = CardRng(5000 + g);
      final o = FortyOneOptions(
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
      );
      var e = FortyOneEngine.newMatch(seed: g, options: o);
      var dealer = o.firstDealer;
      var scores = [0, 0, 0, 0];
      var moves = 0;
      int? expectWinner;
      while (!e.isOver && moves < 20000) {
        final s = e.state;
        expect(s.dealer, dealer);
        if (o.trumpMode == FortyOneTrumpMode.heartsFixed) {
          expect(s.trump, Suit.hearts);
        } else {
          expect(s.hands[s.dealer].contains(s.exposedCard) || s.playedCards.contains(s.exposedCard), isTrue);
          expect(s.trump, sister(s.exposedCard!.suit));
        }
        final seat = e.currentPlayer!;
        final legal = e.legalMoves(seat).toSet();
        if (s.phase == FortyOnePhase.bidding) {
          int step(int v) => v < 30 ? 0 : (v < 40 ? 1 : (v < 50 ? 2 : 3));
          final lo = o.minBid + (o.risingMinimums ? step(scores[seat]) : 0);
          expect(legal, {for (var b = lo; b <= 13; b++) FortyOneMove.bid(b)});
          for (var b = -1; b <= 15; b++) {
            final v = e.validate(FortyOneMove.bid(b));
            expect(v == null, b >= lo && b <= 13);
            if (b > 13) expect(v, 'bidTooHigh');
            if (b < lo) expect(v, 'bidTooLow');
          }
        }
        final ls = legal.toList();
        final m = r.nextInt(3) == 0 && s.phase == FortyOnePhase.playing
            ? ls[r.nextInt(ls.length)]
            : const FortyOneAi().chooseMove(s, seat, AiLevel.values[r.nextInt(2)], r, AiBudget.phone);
        final bidsBefore = List.of(s.bids);
        final dealBefore = s.dealNumber;
        final roundBefore = s.roundNumber;
        e.apply(m);
        moves++;
        final t = e.state;
        if (m.kind == FortyOneMoveKind.bid && seat == dealer) {
          final bids = [...bidsBefore]..[seat] = m.amount;
          final total = bids.fold<int>(0, (a, b) => a + b!);
          int step(int v) => v < 30 ? 0 : (v < 40 ? 1 : (v < 50 ? 2 : 3));
          final minTotal = o.minTotal + (o.risingMinimums ? step(scores.reduce(math.max)) : 0);
          if (total < minTotal) {
            expect(t.dealNumber, dealBefore + 1);
            if (o.throwInRedeal == FortyOneThrowIn.nextDealer) dealer = (dealer + 1) % 4;
            expect(t.currentPlayer, (dealer + 1) % 4);
          } else {
            expect(t.phase, FortyOnePhase.playing);
            var lead = (dealer + 1) % 4;
            if (o.firstLead == FortyOneFirstLead.highestBidder) {
              for (var i = 1; i < 4; i++) {
                final x = (dealer + 1 + i) % 4;
                if (bids[x]! > bids[lead]!) lead = x;
              }
            }
            expect(t.currentPlayer, lead);
          }
        }
        if (t.roundNumber != roundBefore) {
          final res = t.lastResult!;
          expect(res.tricks.fold<int>(0, (a, b) => a + b), 13);
          for (var i = 0; i < 4; i++) {
            final v = switch (o.valueTable) {
              FortyOneValueTable.faceValue => res.bids[i],
              FortyOneValueTable.doubleFrom7 => res.bids[i] >= 7 ? 2 * res.bids[i] : res.bids[i],
              FortyOneValueTable.levant400 =>
                res.bids[i] >= 10
                    ? (o.levantTenPlus == FortyOneTenPlus.flat40 ? 40 : 4 * res.bids[i])
                    : (scores[i] < 30
                          ? [1, 2, 3, 4, 10, 12, 14, 16, 27]
                          : [1, 2, 3, 4, 5, 6, 14, 16, 27])[res.bids[i] - 1],
            };
            expect(res.points[i], res.tricks[i] >= res.bids[i] ? v : -v);
          }
          scores = [for (var i = 0; i < 4; i++) scores[i] + res.points[i]];
          expect(t.playerScores, scores);
          bool ok(int v) => o.partnerRule == FortyOnePartnerRule.positive ? v > 0 : v >= 0;
          bool q(int team) =>
              (scores[team] >= 41 && ok(scores[team + 2])) || (scores[team + 2] >= 41 && ok(scores[team]));
          int? w;
          if (o.bid13WinsMatch) {
            for (var i = 0; i < 4; i++) {
              if (res.bids[i] == 13 && res.tricks[i] == 13) w = i % 2;
            }
          }
          if (w == null && q(0) != q(1)) w = q(0) ? 0 : 1;
          if (w == null && q(0) && q(1)) {
            final tot = [scores[0] + scores[2], scores[1] + scores[3]];
            final best = [math.max(scores[0], scores[2]), math.max(scores[1], scores[3])];
            for (final k in o.bothQualify == FortyOneBothQualify.higherTeamTotal ? [tot, best] : [best, tot]) {
              if (k[0] != k[1]) {
                w = k[0] > k[1] ? 0 : 1;
                break;
              }
            }
          }
          expectWinner = w;
          if (w == null) {
            dealer = (dealer + 1) % 4;
            expect(t.currentPlayer, (dealer + 1) % 4);
          } else {
            expect(t.isOver, isTrue);
            expect(t.winnerTeam, w);
          }
        }
        if (r.nextInt(30) == 0) {
          final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
          e = FortyOneEngine.fromJson(json);
        }
      }
      if (!e.isOver) issues.add('41 g$g did not end in $moves moves (options ${o.toJson()}) scores $scores');
      if (e.isOver) expect(e.state.winnerTeam, expectWinner);
    }
    // ignore: avoid_print
    print('41 ISSUES:\n${issues.join('\n')}');
  });
}
