import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Five cards each, the up card 9D and the eleven cards left (drawn from the
/// end of the stock).
BalootState dealt({BalootOptions options = const BalootOptions()}) => BalootState.withDeal(
  hands: [c('JS 9S AS 7H 8H'), c('TS KS QS 9H TH'), c('8S 7S JH QH KH'), c('AH 7D 8D JD QD')],
  upCard: p('9D'),
  stock: c('KD TD AD 7C 8C 9C TC JC QC KC AC'),
  options: options,
);

/// A state in the middle of play (no validation of how it got there).
BalootState playing(
  List<List<PlayingCard>> hands, {
  BalootMode mode = BalootMode.hokom,
  Suit? trump = Suit.spades,
  int buyer = 0,
  BalootOptions options = const BalootOptions(),
}) {
  final s = dealt(options: options);
  s
    ..phase = BalootPhase.playing
    ..mode = mode
    ..trump = mode == BalootMode.hokom ? trump : null
    ..buyer = buyer
    ..hands = [for (final h in hands) List.of(h)]
    ..stock = []
    ..upCard = null
    ..trick = Trick(s.firstPlayer)
    ..turn = s.firstPlayer;
  return s;
}

Trick t(List<int> seats, String cards) => Trick(seats.first, seats: seats, cards: c(cards));

/// Eight completed tricks (Hokom ♠ in mind): team 0 takes spades, hearts
/// and the last trick (121 card points), team 1 diamonds and one club (41).
List<Trick> tricks() => [
  t([0, 1, 2, 3], 'JS 7S 8S QS'),
  t([0, 1, 2, 3], '9S KS AS TS'),
  t([0, 1, 2, 3], 'AH 7H TH 8H'),
  t([0, 1, 2, 3], 'QH JH KH 9H'),
  t([0, 1, 2, 3], '7D AD 8D 9D'),
  t([0, 1, 2, 3], 'JD TD QD KD'),
  t([0, 1, 2, 3], '7C 8C 9C AC'),
  t([0, 1, 2, 3], 'TC JC QC KC'),
];

BalootState finished({int buyer = 0, BalootMode mode = BalootMode.hokom, List<Trick>? played}) {
  final s = playing([for (var i = 0; i < 4; i++) <PlayingCard>[]], mode: mode, buyer: buyer)
    ..trick = null
    ..tricks = played ?? tricks();
  return s;
}

void main() {
  test('card points: 120 without trumps, 152 with (plus 10 for the last trick)', () {
    final deck = buildDeck(ranks: balootRanks);
    expect(deck.fold<int>(0, (a, x) => a + BalootRules.cardPoints(x, BalootMode.sun, null)), 120);
    expect(deck.fold<int>(0, (a, x) => a + BalootRules.cardPoints(x, BalootMode.hokom, Suit.hearts)), 152);
    expect(BalootRules.trumpRank(Rank.jack), greaterThan(BalootRules.trumpRank(Rank.nine)));
    expect(BalootRules.trumpRank(Rank.nine), greaterThan(BalootRules.trumpRank(Rank.ace)));
    expect(BalootRules.sunRank(Rank.ten), greaterThan(BalootRules.sunRank(Rank.king)));
  });

  group('auction', () {
    test('round 1: Hokom in the up card\'s suit or Sun; Sun overrides Hokom', () {
      final e = BalootEngine(dealt());
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [const BalootMove.pass(), const BalootMove.hokom(Suit.diamonds), const BalootMove.sun()]);
      e.apply(const BalootMove.hokom(Suit.diamonds));
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(1), [const BalootMove.pass(), const BalootMove.sun()]);
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.sun());
      expect(e.state.mode, BalootMode.sun);
      expect(e.state.buyer, 2);
      // The buyer takes the up card and two more; everyone holds eight.
      expect(e.state.hands[2], contains(p('9D')));
      expect(e.state.hands.every((h) => h.length == 8), isTrue);
      expect(e.state.stock, isEmpty);
    });

    test('a Hokom stands when the other three pass', () {
      final e = BalootEngine(dealt(options: const BalootOptions(doubling: false)));
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.mode, BalootMode.hokom);
      expect(e.state.trump, Suit.diamonds);
      expect(e.state.buyer, 1);
      expect(e.currentPlayer, 0); // the first player leads
    });

    test('round 2 offers the other suits; two silent rounds redeal', () {
      final e = BalootEngine(dealt());
      for (var i = 0; i < 4; i++) {
        e.apply(const BalootMove.pass());
      }
      expect(e.state.bidRound, 2);
      expect(e.legalMoves(0).where((m) => m.kind == BalootMoveKind.hokom).map((m) => m.suit), [
        Suit.clubs,
        Suit.hearts,
        Suit.spades,
      ]);
      expect(e.validate(const BalootMove.hokom(Suit.diamonds)), 'hokomSuitNotAllowed');
      for (var i = 0; i < 4; i++) {
        e.apply(const BalootMove.pass());
      }
      expect(e.state.dealNumber, 2);
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
    });

    test('doubling ladder in Hokom: double, triple, four, gahwa', () {
      final e = BalootEngine(dealt());
      e.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      expect(e.state.phase, BalootPhase.doubling);
      expect(e.currentPlayer, 1);
      e.apply(const BalootMove.raise());
      expect((e.state.level, e.currentPlayer), (2, 0));
      e.apply(const BalootMove.raise());
      expect((e.state.level, e.currentPlayer), (3, 1));
      e.apply(const BalootMove.raise());
      expect((e.state.level, e.currentPlayer), (4, 0));
      e.apply(const BalootMove.raise());
      expect(e.state.gahwa, isTrue);
      expect(e.state.phase, BalootPhase.playing);
    });

    test('Sun may be doubled only by defenders under 100 against buyers over 100', () {
      final e = BalootEngine(dealt());
      e.apply(const BalootMove.sun());
      expect(e.state.phase, BalootPhase.playing);
      final s = dealt()..teamScores = [120, 40];
      final f = BalootEngine(s);
      f.apply(const BalootMove.sun());
      expect(f.state.phase, BalootPhase.doubling);
      f.apply(const BalootMove.raise());
      expect(f.state.level, 2);
      expect(f.state.phase, BalootPhase.playing);
    });
  });

  group('play', () {
    test('follow suit; void must trump and over-trump; unable to over-trump is free', () {
      final s = playing([
        c('8H AD 7C 8C 9C TC JC QC'),
        c('9S 7D 8D 9D TD JD QD KD'),
        c('8S JS KC AC 7H 9H TH JH'),
        c('7S AH KH QH TS AS QS KS'),
      ]);
      final e = BalootEngine(s);
      e.apply(BalootMove.play(p('8H')));
      // Seat 1 has no hearts: it must trump.
      expect(e.legalMoves(1), [BalootMove.play(p('9S'))]);
      expect(e.validate(BalootMove.play(p('7D'))), 'mustTrump');
      e.apply(BalootMove.play(p('9S')));
      // Seat 2 follows hearts.
      expect(e.legalMoves(2).every((m) => m.card!.suit == Suit.hearts), isTrue);
      e.apply(BalootMove.play(p('7H')));
      // Seat 3 follows hearts too.
      expect(e.legalMoves(3).every((m) => m.card!.suit == Suit.hearts), isTrue);
    });

    test('trump led: must play a higher trump when able', () {
      final s = playing([
        c('AS 7H 8H 9H TH JH QH KH'),
        c('7S 9S 7D 8D 9D TD JD QD'),
        c('8S TS KD AD 7C 8C 9C TC'),
        c('JS QS KS JC QC KC AC AH'),
      ]);
      final e = BalootEngine(s);
      e.apply(BalootMove.play(p('AS')));
      expect(e.legalMoves(1), [BalootMove.play(p('9S'))]);
      e.apply(BalootMove.play(p('9S')));
      // Seat 2 cannot beat the 9: any trump.
      expect(e.legalMoves(2).map((m) => m.card), unorderedEquals(c('8S TS')));
    });

    test('over-trumping; no trump able to beat → any card; partner option', () {
      final hands = [
        c('8H AD 7C 8C 9C TC JC QC'),
        c('9S 7D 8D 9D TD JD QD KD'),
        c('8S JS KC AC 7H 9H TH JH'),
        c('7S AH KH QH TS AS QS KS'),
      ];
      final e = BalootEngine(playing(hands));
      e.apply(BalootMove.play(p('AD')));
      e.apply(BalootMove.play(p('7D')));
      // Seat 2 has no diamond: must trump, higher than nothing yet → any trump.
      expect(e.legalMoves(2).map((m) => m.card), unorderedEquals(c('8S JS')));
      e.apply(BalootMove.play(p('8S')));
      // Seat 3 has no diamond; its trumps (7S TS AS QS KS)… all beat 8S
      // except 7S.
      expect(e.legalMoves(3).map((m) => m.card), unorderedEquals(c('TS AS QS KS')));

      final relaxed = BalootEngine(
        playing(hands, options: const BalootOptions(mustTrumpWhenPartnerWinning: false)),
      );
      relaxed.apply(BalootMove.play(p('AD')));
      relaxed.apply(BalootMove.play(p('7D')));
      // Partner (seat 0) is winning: seat 2 may play anything.
      expect(relaxed.legalMoves(2).length, 8);
    });

    test('Sun: no obligation to trump', () {
      final e = BalootEngine(
        playing([
          c('8H AD 7C 8C 9C TC JC QC'),
          c('9S 7D 8D 9D TD JD QD KD'),
          c('8S JS KC AC 7H 9H TH JH'),
          c('7S AH KH QH TS AS QS KS'),
        ], mode: BalootMode.sun),
      );
      e.apply(BalootMove.play(p('8H')));
      expect(e.legalMoves(1).length, 8);
    });
  });

  group('projects', () {
    List<BalootProjectType> types(String hand, [BalootMode mode = BalootMode.sun]) =>
        BalootRules.detectProjects(c(hand), 0, mode).map((x) => x.type).toList()..sort((a, b) => a.index - b.index);

    test('sira, fifty, hundred, four hundred', () {
      expect(types('7H 8H 9H TS JS QS KS AD'), [BalootProjectType.sira, BalootProjectType.fifty]);
      expect(types('9C TC JC QC KC 7D 8H AH'), [BalootProjectType.hundred]);
      expect(types('KS KH KD KC 7H 9D 8C AS'), [BalootProjectType.hundred]);
      expect(types('AS AH AD AC 7H 9D 8C KS'), [BalootProjectType.fourHundred]);
      expect(types('AS AH AD AC 7H 9D 8C KS', BalootMode.hokom), [BalootProjectType.hundred]);
      expect(types('9S 9H 9D 9C 7H 8D TC KS'), isEmpty);
    });

    test('a card counts in one project only: the best combination is kept', () {
      // Four kings + T J Q of hearts: carré (20) + sira (4) beats the 50.
      expect(types('KS KH KD KC QH JH TH 7S'), [BalootProjectType.sira, BalootProjectType.hundred]);
    });

    test('only the team with the best project scores projects', () {
      BalootProject pr(BalootProjectType type, int seat, String cards) => BalootProject(type, seat, c(cards));
      final sira = pr(BalootProjectType.sira, 1, '7H 8H 9H');
      final fifty = pr(BalootProjectType.fifty, 2, '7S 8S 9S TS');
      expect(BalootRules.projectTeam([sira, fifty], 0, BalootMode.sun), 0);
      final siraHigh = pr(BalootProjectType.sira, 3, 'QD KD AD');
      expect(BalootRules.projectTeam([sira, siraHigh], 0, BalootMode.sun), 1);
      final siraSame = pr(BalootProjectType.sira, 2, '7C 8C 9C');
      // Equal: the one nearer the first player (seat 0 → seat 1 first).
      expect(BalootRules.projectTeam([siraSame, sira], 0, BalootMode.sun), 1);
    });
  });

  group('scoring', () {
    test('raw points and rounding', () {
      final s = finished();
      expect(BalootRules.rawPoints(s), [121, 41]);
      expect(BalootRules.buyerAbnat(BalootMode.hokom, 121), 12);
      expect(BalootRules.buyerAbnat(BalootMode.hokom, 85), 8);
      expect(BalootRules.buyerAbnat(BalootMode.hokom, 86), 9);
      expect(BalootRules.buyerAbnat(BalootMode.sun, 67), 13);
      expect(BalootRules.buyerAbnat(BalootMode.sun, 68), 14);
    });

    test('made, failed, projects, belote, doubled, kaboot', () {
      expect(BalootRules.dealResult(finished()).points, [12, 4]);
      final failed = BalootRules.dealResult(finished(buyer: 1));
      expect(failed.points, [16, 0]);
      expect(failed.made, isFalse);
      // A hundred for the buyers (10 in Hokom) turns the failure around.
      final withProject = finished(buyer: 1)
        ..projects = [
          BalootProject(BalootProjectType.hundred, 1, c('KS KH KD KC')),
          BalootProject(BalootProjectType.sira, 0, c('7H 8H 9H')),
        ];
      expect(BalootRules.dealResult(withProject).points, [12, 14]);
      // Belote always counts for its holder's team.
      expect(BalootRules.dealResult(finished()..belote = 2).points, [14, 4]);
      expect(BalootRules.dealResult(finished(buyer: 1)..belote = 3).points, [16, 2]);
      // Doubled: the winner takes everything twice.
      expect(BalootRules.dealResult(finished()..level = 2).points, [32, 0]);
      expect(BalootRules.dealResult(finished(buyer: 1)..level = 3).points, [48, 0]);
      // Kaboot: 25 in Hokom, 44 in Sun.
      final all = [
        for (final x in tricks())
          x.winner((card, led) => BalootRules.power(card, led, BalootMode.hokom, Suit.spades)) % 2 == 0
              ? x
              : Trick(0, seats: [x.seats[1], x.seats[0], x.seats[3], x.seats[2]], cards: x.cards),
      ];
      expect(BalootRules.dealResult(finished(played: all)).points, [25, 0]);
      final sunAll = [
        for (final x in tricks())
          x.winner((card, led) => BalootRules.power(card, led, BalootMode.sun, null)) % 2 == 0
              ? x
              : Trick(0, seats: [x.seats[1], x.seats[0], x.seats[3], x.seats[2]], cards: x.cards),
      ];
      expect(BalootRules.dealResult(finished(mode: BalootMode.sun, played: sunAll)).points, [44, 0]);
    });

    test('match to 152; gahwa wins the match outright', () {
      final e = BalootEngine(dealt());
      e.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      for (var i = 0; i < 4; i++) {
        e.apply(const BalootMove.raise());
      }
      while (!e.isOver) {
        e.apply(e.legalMoves(e.currentPlayer!).first);
      }
      expect(e.state.results.length, 1);
      expect(e.state.results.single.level, 5);
      expect(e.state.winners, isNotEmpty);
    });
  });
}
