// Baloot (بلوت) as commonly played in Jordan (the Saudi game): cards,
// projects, belote and which cards may be played (final spec §6, §10, §11).
// The auction is in baloot_auction_test.dart, the scoring in
// baloot_scoring_test.dart, self-play and the AI in baloot_play_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Five cards each, the up card 9D and the eleven cards left (drawn from the
/// end of the stock). The dealer is seat 3, so seat 0 speaks and leads first.
BalootState dealt({BalootOptions options = const BalootOptions()}) => BalootState.withDeal(
  hands: [c('JS 9S AS 7H 8H'), c('TS KS QS 9H TH'), c('8S 7S JH QH KH'), c('AH 7D 8D JD QD')],
  upCard: p('9D'),
  stock: c('KD TD AD 7C 8C 9C TC JC QC KC AC'),
  options: options,
);

/// A state in the middle of play (no validation of how it got there):
/// [played] is the current trick as `seat:card` pairs, [done] earlier tricks.
BalootState at(
  List<String> hands, {
  BalootMode mode = BalootMode.hokom,
  Suit? trump = Suit.spades,
  int buyer = 0,
  String played = '',
  List<Trick> done = const [],
  bool locked = false,
  BalootOptions options = const BalootOptions(),
}) {
  final s = dealt(options: options);
  final pairs = played.split(' ').where((x) => x.isNotEmpty).toList();
  final seats = [for (final x in pairs) int.parse(x.split(':')[0])];
  final cards = [for (final x in pairs) p(x.split(':')[1])];
  final leader = seats.isEmpty ? s.firstPlayer : seats.first;
  s
    ..phase = BalootPhase.playing
    ..mode = mode
    ..trump = mode == BalootMode.hokom ? trump : null
    ..buyer = buyer
    ..bidder = buyer
    ..hands = [for (final h in hands) c(h)]
    ..stock = []
    ..upCard = null
    ..locked = locked
    ..projectsDecided = List.filled(4, true)
    ..tricks = List.of(done)
    ..trick = Trick(leader, seats: seats, cards: cards)
    ..turn = seats.isEmpty ? leader : (seats.last + 1) % 4;
  return s;
}

List<PlayingCard> legal(BalootState s) => [for (final m in BalootEngine(s).legalMoves(s.turn)) m.card!];

void main() {
  group('cards (§6)', () {
    test('B6 card points: 120 without trumps, 152 with, plus 10 for the last trick (130 / 162)', () {
      final deck = buildDeck(ranks: balootRanks);
      expect(deck.length, 32);
      expect(deck.fold<int>(0, (a, x) => a + BalootRules.cardPoints(x, BalootMode.sun, null)) + 10, 130);
      expect(deck.fold<int>(0, (a, x) => a + BalootRules.cardPoints(x, BalootMode.hokom, Suit.hearts)) + 10, 162);
    });

    test('B6 orders: Sun A 10 K Q J 9 8 7; trumps J 9 A 10 K Q 8 7', () {
      final sun = [Rank.ace, Rank.ten, Rank.king, Rank.queen, Rank.jack, Rank.nine, Rank.eight, Rank.seven];
      for (var i = 1; i < sun.length; i++) {
        expect(BalootRules.sunRank(sun[i - 1]), greaterThan(BalootRules.sunRank(sun[i])));
      }
      final trumps = [Rank.jack, Rank.nine, Rank.ace, Rank.ten, Rank.king, Rank.queen, Rank.eight, Rank.seven];
      for (var i = 1; i < trumps.length; i++) {
        expect(BalootRules.trumpRank(trumps[i - 1]), greaterThan(BalootRules.trumpRank(trumps[i])));
      }
    });

    test('B3.1 the deal: 5 each, the 21st card face up, 11 kept back', () {
      final s = BalootState.newMatch(seed: 3);
      expect(s.hands.every((h) => h.length == 5), isTrue);
      expect(s.upCard, isNotNull);
      expect(s.stock.length, 11);
      expect(sortedCards(s.cardsInPlay()), sortedCards(s.fullDeck()));
    });
  });

  group('projects (§11)', () {
    List<BalootProjectType> types(String hand, [BalootMode mode = BalootMode.sun]) =>
        BalootRules.detectProjects(c(hand), 0, mode).map((x) => x.type).toList()..sort((a, b) => a.index - b.index);
    BalootProject pr(BalootProjectType type, int seat, String cards) => BalootProject(type, seat, c(cards));

    test('B7 sira 3, fifty 4, hundred 5 in sequence or four 10/K/Q/J, four aces 400 (Sun) / 100 (Hokom)', () {
      expect(types('7H 8H 9H TS JS QS KS AD'), [BalootProjectType.sira, BalootProjectType.fifty]);
      expect(types('9C TC JC QC KC 7D 8H AH'), [BalootProjectType.hundred]);
      expect(types('KS KH KD KC 7H 9D 8C AS'), [BalootProjectType.hundred]);
      expect(types('TS TH TD TC 7H 9D 8C AS'), [BalootProjectType.hundred]);
      expect(types('AS AH AD AC 7H 9D 8C KS'), [BalootProjectType.fourHundred]);
      expect(types('AS AH AD AC 7H 9D 8C KS', BalootMode.hokom), [BalootProjectType.hundred]);
      final values = {
        BalootProjectType.sira: (4, 2),
        BalootProjectType.fifty: (10, 5),
        BalootProjectType.hundred: (20, 10),
      };
      for (final e in values.entries) {
        final x = BalootProject(e.key, 0, c('7H 8H 9H'));
        expect((x.value(BalootMode.sun), x.value(BalootMode.hokom)), e.value);
      }
      expect(pr(BalootProjectType.fourHundred, 0, 'AS AH AD AC').value(BalootMode.sun), 40);
    });

    test('B7.1–B7.2 natural sequence order (A-K-Q is a sira, A-10-K is not); four 9/8/7 are worthless', () {
      expect(types('AH KH QH 7S 8D 9C TC JD'), [BalootProjectType.sira]);
      expect(types('AH TH KH 7S 8D 9C JC QD'), isEmpty);
      expect(types('9S 9H 9D 9C 7H 8D TC KS'), isEmpty);
      expect(types('7S 7H 7D 7C 8H 9D TC KS'), isEmpty);
    });

    test('B7.3 a card counts in one project only: the best combination is kept (at most two)', () {
      // Four kings + T J Q of hearts: carré (20) + sira (4) beats the 50.
      expect(types('KS KH KD KC QH JH TH 7S'), [BalootProjectType.sira, BalootProjectType.hundred]);
      // K♦K♣K♥ + A K Q J 10 of spades: four kings + the Q J 10 sira.
      final best = BalootRules.detectProjects(c('KD KC KH AS KS QS JS TS'), 0, BalootMode.sun);
      expect(best.length, 2);
      expect(best.any((x) => x.isCarre), isTrue);
    });

    test('B7.5 only the team with the single best project scores, all its projects', () {
      final sira = pr(BalootProjectType.sira, 1, '7H 8H 9H');
      final fifty = pr(BalootProjectType.fifty, 2, '7S 8S 9S TS');
      expect(BalootRules.projectTeam([sira, fifty], 0, BalootMode.sun), 0);
    });

    test('B7.6 higher value first; among hundreds four of a kind beats a sequence (option: the reverse)', () {
      final carre = pr(BalootProjectType.hundred, 1, 'TS TH TD TC');
      final sequence = pr(BalootProjectType.hundred, 0, 'TC JC QC KC AC');
      expect(BalootRules.projectTeam([sequence, carre], 0, BalootMode.sun), 1);
      expect(
        BalootRules.projectTeam(
          [sequence, carre],
          0,
          BalootMode.sun,
          options: const BalootOptions(sequenceBeatsCarre: true),
        ),
        0,
      );
    });

    test('B7.6 then the higher top card, then the player nearer the first speaker', () {
      final sira = pr(BalootProjectType.sira, 1, '7H 8H 9H');
      final siraHigh = pr(BalootProjectType.sira, 3, 'QD KD AD');
      expect(BalootRules.projectTeam([sira, siraHigh], 0, BalootMode.sun), 1);
      final kings = pr(BalootProjectType.hundred, 0, 'KS KH KD KC');
      final queens = pr(BalootProjectType.hundred, 1, 'QS QH QD QC');
      expect(BalootRules.projectTeam([queens, kings], 0, BalootMode.sun), 0);
      final siraSame = pr(BalootProjectType.sira, 2, '7C 8C 9C');
      // Equal: the one nearer the first speaker (seat 0 → seat 1 first).
      expect(BalootRules.projectTeam([siraSame, sira], 0, BalootMode.sun), 1);
      expect(BalootRules.projectTeam([siraSame, sira], 2, BalootMode.sun), 0);
    });

    test('B7.6 option trumpSequencePriority: of two equal sequences the trump one wins (Hokom)', () {
      final clubs = pr(BalootProjectType.sira, 0, 'JC QC KC');
      final hearts = pr(BalootProjectType.sira, 1, 'JH QH KH');
      expect(BalootRules.projectTeam([clubs, hearts], 0, BalootMode.hokom, trump: Suit.hearts), 0);
      expect(
        BalootRules.projectTeam(
          [clubs, hearts],
          0,
          BalootMode.hokom,
          trump: Suit.hearts,
          options: const BalootOptions(trumpSequencePriority: true),
        ),
        1,
      );
    });

    test('B7.4 automatic declaration: every player\'s projects when play starts', () {
      final e = BalootEngine(dealt(options: const BalootOptions(doubling: false)));
      e.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      final events = e.apply(const BalootMove.confirm());
      expect(e.state.phase, BalootPhase.playing);
      final declared = events.where((x) => x.type == CardEventType.projectsDeclared).map((x) => x.seat).toSet();
      expect(declared, e.state.projects.map((x) => x.seat).toSet());
      expect(e.state.projectsDecided, [true, true, true, true]);
    });

    test('option manual declaration: declare or skip before the first card; skipped projects do not count', () {
      const o = BalootOptions(declareProjects: BalootDeclareProjects.manual);
      final s = at(
        ['7H 8H 9H JS 9S AS 7C 8C', 'TS KS QS 9C TH 7D 8D JD', '8S 7S JH QH KH AH TC JC', 'QD KD AD TD JD QC KC AC'],
        options: o,
      )..projectsDecided = List.filled(4, false);
      final e = BalootEngine(s);
      // Seat 0 holds a sira: it must decide first.
      expect(e.legalMoves(0), const [BalootMove.declareProjects(), BalootMove.skipProjects()]);
      expect(e.validate(BalootMove.play(p('7H'))), 'declareProjectsFirst');
      e.apply(const BalootMove.declareProjects());
      expect(e.state.projects.single.type, BalootProjectType.sira);
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0).every((m) => m.kind == BalootMoveKind.play), isTrue);
      e.apply(BalootMove.play(p('JS')));
      // Seat 1 has no project: it plays at once.
      expect(e.legalMoves(1).every((m) => m.kind == BalootMoveKind.play), isTrue);
      e.apply(BalootMove.play(p('TS')));
      // Seat 2 (J Q K A of hearts: a fifty) skips.
      expect(e.legalMoves(2).first, const BalootMove.declareProjects());
      e.apply(const BalootMove.skipProjects());
      e.apply(BalootMove.play(p('8S')));
      // Seat 3: 10 J Q K A of diamonds (a hundred) and Q K A of clubs.
      e.apply(const BalootMove.declareProjects());
      e.apply(BalootMove.play(p('QD')));
      expect(e.state.projects.map((x) => x.seat).toSet(), {0, 3});
      expect(e.state.projects.where((x) => x.seat == 3).length, 2);
      expect(e.state.tricks.length, 1);
      // From the second trick on nobody declares.
      expect(e.legalMoves(e.currentPlayer!).every((m) => m.kind == BalootMoveKind.play), isTrue);
    });
  });

  group('belote (§11)', () {
    test('B7.7 K+Q of trumps in one hand: 2, announced with the second card', () {
      final s = at(['KS QS 7H', '8H 9H TH', 'JH QH KH', 'AH 7D 8D'], buyer: 1)..belote = 0;
      final e = BalootEngine(s);
      var events = e.apply(BalootMove.play(p('KS')));
      expect(events.any((x) => x.type == CardEventType.belote), isFalse);
      for (final id in ['8H', 'JH', 'AH']) {
        e.apply(BalootMove.play(p(id)));
      }
      // Seat 0 won with the trump: it leads the queen.
      events = e.apply(BalootMove.play(p('QS')));
      expect(events.singleWhere((x) => x.type == CardEventType.belote).seat, 0);
    });

    test('the belote holder is found from the hands when play starts', () {
      final e = BalootEngine(dealt(options: const BalootOptions(doubling: false)));
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.hokom(Suit.diamonds));
      // Priority for the earlier speakers, then the confirmation.
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      e.apply(const BalootMove.confirm());
      // Seat 3 had Q♦ J♦ … and took the up card 9♦ + 2; K♦ is in the stock.
      final holder = [
        for (var seat = 0; seat < 4; seat++)
          if (e.state.hands[seat].contains(p('KD')) && e.state.hands[seat].contains(p('QD'))) seat,
      ];
      expect(e.state.belote, holder.isEmpty ? -1 : holder.single);
      expect(BalootRules.beloteHolder(e.state), e.state.belote);
    });

    test('B7.8 no belote for a holder whose team scores a hundred with the trump K or Q', () {
      final s = at(['', '', '', ''])
        ..belote = 2
        ..projects = [BalootProject(BalootProjectType.hundred, 2, c('KS KH KD KC'))];
      expect(BalootRules.beloteCounts(s), isFalse);
      s.projects = [BalootProject(BalootProjectType.hundred, 2, c('QS QH QD QC'))];
      expect(BalootRules.beloteCounts(s), isFalse);
      s.projects = [BalootProject(BalootProjectType.hundred, 2, c('9S TS JS QS KS'))];
      expect(BalootRules.beloteCounts(s), isFalse);
      // A hundred without the trump K/Q (four jacks) does not cancel it.
      s.projects = [BalootProject(BalootProjectType.hundred, 2, c('JS JH JD JC'))];
      expect(BalootRules.beloteCounts(s), isTrue);
    });

    test('B7.8 inside a sira or fifty the belote counts as well', () {
      final s = at(['', '', '', ''])
        ..belote = 2
        ..projects = [BalootProject(BalootProjectType.sira, 2, c('JS QS KS'))];
      expect(BalootRules.beloteCounts(s), isTrue);
      s.projects = [BalootProject(BalootProjectType.fifty, 2, c('JS QS KS AS'))];
      expect(BalootRules.beloteCounts(s), isTrue);
    });

    test('B7.8 a hundred that does not score (the opponents have better) does not cancel it', () {
      final s = at(['', '', '', ''])
        ..belote = 2
        ..projects = [
          BalootProject(BalootProjectType.hundred, 2, c('KS KH KD KC')),
          BalootProject(BalootProjectType.hundred, 1, c('AS AH AD AC')),
        ];
      expect(BalootRules.projectTeam(s.projects, s.firstPlayer, BalootMode.hokom), 1);
      expect(BalootRules.beloteCounts(s), isTrue);
    });

    test('no belote in Sun', () {
      final s = at(['', '', '', ''], mode: BalootMode.sun)..belote = 2;
      expect(BalootRules.beloteCounts(s), isFalse);
      expect(BalootRules.beloteHolder(s), -1);
    });
  });

  group('which cards may be played (§10)', () {
    test('B8.1 leading: any card', () {
      final s = at(['JS 9S 7H 8H AD', '7S 8S TH', '9H 7D 8D', 'TD JD QD']);
      expect(legal(s).length, 5);
    });

    test('B5.4 locked: no trump lead unless the hand is all trumps; following is unaffected', () {
      final s = at(['JS 9S 7H 8H AD', '7S 8S TH', '9H 7D 8D', 'TD JD QD'], locked: true);
      expect(legal(s), unorderedEquals(c('7H 8H AD')));
      expect(BalootEngine(s).validate(BalootMove.play(p('JS'))), 'lockedTrumpLead');
      final allTrumps = at(['JS 9S 7S', 'AS 8S TH', '9H 7D 8D', 'TD JD QD'], locked: true);
      expect(legal(allTrumps), unorderedEquals(c('JS 9S 7S')));
      // A trump led by a player with only trumps: the others follow as usual.
      final follow = at(['9S 7S', 'AS 8S TH', '9H 7D 8D', 'TD JD QD'], locked: true, played: '0:JS');
      expect(legal(follow), unorderedEquals(c('AS 8S')));
      // Sun has no locked play.
      final sun = at(['JS 9S 7H', '7S 8S TH', '9H 7D 8D', 'TD JD QD'], mode: BalootMode.sun, locked: true);
      expect(legal(sun).length, 3);
    });

    test('B8.2 holding a led side suit: any card of it (no need to beat)', () {
      final s = at(['', '7H AH TD', '', ''], played: '0:KH');
      expect(legal(s), unorderedEquals(c('7H AH')));
      expect(BalootEngine(s).validate(BalootMove.play(p('TD'))), 'mustFollowSuit');
    });

    test('B8.4 trump led, an opponent winning: a higher trump if possible, else any trump', () {
      final s = at(['', '7S 9S AD', '', ''], played: '0:AS');
      expect(legal(s), c('9S'));
      expect(BalootEngine(s).validate(BalootMove.play(p('7S'))), 'mustOvertrump');
      final cannot = at(['', '', '8S TS KD', ''], played: '0:AS 1:9S');
      expect(legal(cannot), unorderedEquals(c('8S TS')));
    });

    test('B8.4 trump led, the partner winning: any trump (option always: must beat)', () {
      final s = at(['', '', '7S JS AD', ''], played: '0:AS 1:8S');
      expect(legal(s), unorderedEquals(c('7S JS')));
      final always = at(
        ['', '', '7S JS AD', ''],
        played: '0:AS 1:8S',
        options: const BalootOptions(trumpLedOvertrump: BalootTrumpLedOvertrump.always),
      );
      expect(legal(always), c('JS'));
      // Trump led and no trump in hand: any card.
      final none = at(['', '', 'AD KC', ''], played: '0:AS 1:8S');
      expect(legal(none).length, 2);
    });

    test('B8.3 Sun: void in the led suit → any card', () {
      final s = at(['', '9S 7D 8D', '', ''], mode: BalootMode.sun, played: '0:8H');
      expect(legal(s).length, 3);
    });

    test('Hokom, void and no trump: any card', () {
      final s = at(['', '7D 8D 9C', '', ''], played: '0:8H');
      expect(legal(s).length, 3);
    });

    test('B8.5 void, an opponent winning with a side card: any trump', () {
      final s = at(['', '9S 7S 7D 8D', '', ''], played: '0:8H');
      expect(legal(s), unorderedEquals(c('9S 7S')));
      expect(BalootEngine(s).validate(BalootMove.play(p('7D'))), 'mustTrump');
    });

    test('B8.5 void, an opponent winning with a trump: a higher trump, else any card', () {
      // Seat 3: void in diamonds; seat 2 trumped with the 8♠.
      final s = at(['', '', '', '7S TS AS QH'], played: '0:AD 1:7D 2:8S');
      // Seat 2 is seat 3's opponent: must over-trump.
      expect(legal(s), unorderedEquals(c('TS AS')));
      final lower = at(['', '', '', '7S QH KH'], played: '0:AD 1:7D 2:8S');
      expect(legal(lower), unorderedEquals(c('7S QH KH')));
    });

    test('B8.6 void, the partner winning, playing 4th: any card', () {
      // Seat 1 trumped; seat 3 (its partner) is void in diamonds.
      final s = at(['', '', '', '7S TS QH KH'], played: '0:AD 1:9S 2:7D');
      expect(legal(s).length, 4);
      final side = at(['', '', '', '7S TS QH KH'], played: '0:7D 1:AD 2:8D');
      expect(legal(side).length, 4);
    });

    test('B8.6 void, the partner led and is winning, playing 3rd: free after an Ace', () {
      final s = at(['', '', '8S JS 7C 8C 9C TC JC QC', ''], played: '0:AD 1:7D');
      expect(legal(s).length, 8);
    });

    test('B8.6 … free after an Ekka (the highest diamond still out)', () {
      final earlier = [
        Trick(0, seats: [0, 1, 2, 3], cards: c('AD TD 7H 8H')),
      ];
      final s = at(['', '', '8S JS 7C 8C 9C TC', ''], played: '0:KD 1:7D', done: earlier);
      expect(BalootRules.isEkka(s, p('KD')), isTrue);
      expect(legal(s).length, 6);
    });

    test('B8.6 … must trump after any other lead (PGL: ♣K with the ♣10 still out)', () {
      // Trumps ♥. North (seat 0) leads ♣K, the ♣A already played but the ♣10
      // still out; West follows ♣7; South, void in clubs, must trump.
      final earlier = [
        Trick(1, seats: [1, 2, 3, 0], cards: c('AC 8C 9C JC')),
      ];
      final s = at(['', '', 'QH 9D', ''], trump: Suit.hearts, played: '0:KC 1:7C', done: earlier);
      expect(BalootRules.isEkka(s, p('KC')), isFalse);
      expect(legal(s), c('QH'));
    });

    test('Ekka: the lead is announced on the card-played event; an Ace is always one', () {
      final s = at(['KD AC 7H', '7D 8D 8C', '9D 9C TH', 'QD TC JH'], done: [
        Trick(0, seats: [0, 1, 2, 3], cards: c('AD TD 7S 8S')),
      ]);
      final e = BalootEngine(s);
      final events = e.apply(BalootMove.play(p('KD')));
      expect(events.first.detail, 'ekka');
      expect(BalootRules.isEkka(s, p('AC')), isTrue);
      expect(BalootRules.isEkka(s, p('TC')), isFalse);
      // A trump lead or a Sun lead is never an Ekka.
      expect(BalootRules.isEkka(s, p('JS')), isFalse);
      final sun = at(['KD'], mode: BalootMode.sun);
      expect(BalootRules.isEkka(sun, p('AD')), isFalse);
    });

    test('option partnerWinningVoid alwaysTrump: must trump and over-trump over the partner', () {
      const o = BalootOptions(partnerWinningVoid: BalootPartnerWinningVoid.alwaysTrump);
      final third = at(['', '', '8S JS 7C 8C', ''], played: '0:AD 1:7D', options: o);
      expect(legal(third), unorderedEquals(c('8S JS')));
      final fourth = at(['', '', '', '7S TS AS QS KS'], played: '0:AD 1:7D 2:8S', options: o);
      expect(legal(fourth), unorderedEquals(c('TS AS QS KS')));
      expect(o.mustTrumpWhenPartnerWinning, isTrue);
    });

    test('option partnerWinningVoid free: any card while the partner wins', () {
      const o = BalootOptions(partnerWinningVoid: BalootPartnerWinningVoid.free);
      final s = at(['', '', '8S JS 7C 8C', ''], played: '0:KD 1:7D', options: o);
      expect(legal(s).length, 4);
    });

    test('option voidMustTrump off: a void player may always play any card', () {
      final s = at(['', '9S 7S 7D 8D', '', ''], played: '0:8H', options: const BalootOptions(voidMustTrump: false));
      expect(legal(s).length, 4);
    });

    test('option mustOvertrump off: any trump will do', () {
      const o = BalootOptions(mustOvertrump: false);
      final led = at(['', '7S 9S AD', '', ''], played: '0:AS', options: o);
      expect(legal(led), unorderedEquals(c('7S 9S')));
      final ruff = at(['', '', '', '7S TS AS QH'], played: '0:AD 1:7D 2:8S', options: o);
      expect(legal(ruff), unorderedEquals(c('7S TS AS')));
    });

    test('B8.8 the highest trump, else the highest card of the led suit, wins; the winner leads', () {
      final s = at(['8H AS', '9S AD', '7H KC', 'AH 7C']);
      final e = BalootEngine(s);
      for (final id in ['8H', '9S', '7H', 'AH']) {
        e.apply(BalootMove.play(p(id)));
      }
      expect(e.state.tricks.single.winner((x, l) => BalootRules.power(x, l, BalootMode.hokom, Suit.spades)), 1);
      expect(e.currentPlayer, 1);
    });
  });
}
