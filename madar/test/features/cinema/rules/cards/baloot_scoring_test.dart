// Baloot scoring as commonly played in Jordan (the Saudi tournament rules):
// final spec §12 (conversion, counting team, rounding tie-break, doubled
// deals, kaboot), its worked examples BX1–BX12, the 23 worked examples of the
// Saudi sources, belote on a loss, the project multiplier and the match.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

const hokom = BalootMode.hokom;
const sun = BalootMode.sun;

/// [BalootRules.scoreFigures] with the arguments of the reference scorer:
/// taker team, card points, projects, belote, level, gahwa, kaboot team.
BalootDealScore score(
  BalootMode mode,
  int taker,
  List<int> raw, {
  List<int> proj = const [0, 0],
  List<int> bel = const [0, 0],
  int level = 1,
  bool gahwa = false,
  int? kaboot,
  BalootBeloteOnLoss beloteOnLoss = BalootBeloteOnLoss.toWinner,
  int? cap = 2,
}) => BalootRules.scoreFigures(
  mode: mode,
  takerTeam: taker,
  raw: raw,
  projects: proj,
  belote: bel,
  level: level,
  gahwa: gahwa,
  kabootTeam: kaboot,
  beloteOnLoss: beloteOnLoss,
  projectMultiplierCap: cap,
);

/// A finished deal state: eight completed tricks (Hokom ♠ in mind): team 0
/// takes 121 card points (last trick included), team 1 takes 41.
Trick t(List<int> seats, String cards) => Trick(seats.first, seats: seats, cards: c(cards));

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

BalootState finished({
  int buyer = 0,
  BalootMode mode = hokom,
  List<Trick>? played,
  BalootOptions options = const BalootOptions(),
}) {
  final s = BalootState.withDeal(
    hands: [for (var i = 0; i < 4; i++) c('7H 8H 9H TH JH')],
    upCard: p('9D'),
    stock: const [],
    options: options,
  );
  s
    ..phase = BalootPhase.playing
    ..mode = mode
    ..trump = mode == hokom ? Suit.spades : null
    ..buyer = buyer
    ..bidder = buyer
    ..hands = [for (var i = 0; i < 4; i++) <PlayingCard>[]]
    ..upCard = null
    ..trick = null
    ..tricks = played ?? tricks();
  return s;
}

/// All eight tricks to team 0.
List<Trick> kabootTricks(BalootMode mode) => [
  for (final x in tricks())
    x.winner((card, led) => BalootRules.power(card, led, mode, mode == hokom ? Suit.spades : null)) % 2 == 0
        ? x
        : Trick(0, seats: [x.seats[1], x.seats[0], x.seats[3], x.seats[2]], cards: x.cards),
];

void main() {
  group('B9.1 conversion of the counting team\'s card points', () {
    test('Hokom: nearest ten, a 5 rounds down, ÷ 10 (§12.1)', () {
      final rows = {(0, 5): 0, (6, 15): 1, (16, 25): 2, (56, 65): 6, (66, 75): 7, (76, 85): 8, (146, 155): 15};
      for (final e in rows.entries) {
        for (var raw = e.key.$1; raw <= e.key.$2; raw++) {
          expect(BalootRules.gamePoints(hokom, raw), e.value, reason: '$raw');
        }
      }
      for (var raw = 156; raw <= 162; raw++) {
        expect(BalootRules.gamePoints(hokom, raw), 16);
      }
    });

    test('Sun: nearest ten, a total ending in 5 kept, ÷ 5 (§12.1)', () {
      final rows = {
        (0, 4): 0,
        (5, 5): 1,
        (6, 14): 2,
        (15, 15): 3,
        (16, 24): 4,
        (55, 55): 11,
        (56, 64): 12,
        (65, 65): 13,
        (66, 74): 14,
        (126, 130): 26,
      };
      for (final e in rows.entries) {
        for (var raw = e.key.$1; raw <= e.key.$2; raw++) {
          expect(BalootRules.gamePoints(sun, raw), e.value, reason: '$raw');
        }
      }
      // The old ÷ 5 rounding differed here.
      expect(BalootRules.gamePoints(sun, 57), 12);
      expect(BalootRules.gamePoints(sun, 66), 14);
      expect(BalootRules.gamePoints(sun, 67), 14);
      expect(BalootRules.gamePoints(sun, 88), 18);
      expect(BalootRules.gamePoints(sun, 42), 8);
    });

    test('§13.1 the two teams\' card game points always add up to 16 / 26', () {
      for (final mode in [hokom, sun]) {
        final total = mode == hokom ? 162 : 130;
        for (var raw = 0; raw <= total; raw++) {
          final r = score(mode, 0, [total - raw, raw]);
          expect(r.gamePoints[0] + r.gamePoints[1], BalootRules.basePoints(mode), reason: '$mode $raw');
          expect(r.gamePoints[r.countingTeam!], inInclusiveRange(0, BalootRules.basePoints(mode)));
        }
      }
    });
  });

  group('counting team and winner (§12 steps 2–5)', () {
    test('B9.1 no double: the defenders count', () {
      expect(score(hokom, 0, [105, 57]).countingTeam, 1);
      expect(score(hokom, 1, [105, 57]).countingTeam, 0);
    });

    test('B9.1 doubled: the opponents of the last raiser count (double/four → takers, triple/gahwa → defenders)', () {
      expect(score(hokom, 0, [81, 81], level: 2).countingTeam, 0);
      expect(score(hokom, 0, [81, 81], level: 3).countingTeam, 1);
      expect(score(hokom, 0, [81, 81], level: 4).countingTeam, 0);
      expect(score(hokom, 0, [81, 81], level: 4, gahwa: true).countingTeam, 1);
      expect(score(sun, 1, [65, 65], level: 2).countingTeam, 1);
    });

    test('B9.5 a tie in game points goes to the team that lost more to rounding, then to the taker', () {
      // Hokom, counting total ending in 2–5: the counting team wins.
      expect(score(hokom, 0, [70, 92], bel: [2, 0]).winner, 1);
      // … ending in 6–0: the counting team loses.
      expect(score(hokom, 1, [77, 85]).winner, 1);
      // … ending in 1: equal losses, the taker wins.
      expect(score(hokom, 0, [71, 91], bel: [2, 0]).winner, 0);
      // Sun, ending in 0 or 5: no rounding, the taker wins.
      expect(score(sun, 0, [65, 65]).winner, 0);
      expect(score(sun, 0, [75, 55], proj: [0, 4]).winner, 0);
    });

    test('§13 Hokom 96 / 66: only the counting team converts, so 9 / 7 (never 17 in all)', () {
      expect(score(hokom, 0, [96, 66]).points, [9, 7]);
    });
  });

  group('§12.3 worked examples BX1–BX12', () {
    final cases = <String, (BalootDealScore, List<int>)>{
      'BX1 Hokom, B counts 57 → 6; A 10': (score(hokom, 0, [105, 57]), [10, 6]),
      'BX2 Hokom 96 / 66: B counts 66 → 7; A 9': (score(hokom, 0, [96, 66]), [9, 7]),
      'BX3 Hokom 81 / 81, A belote: 10 / 8': (score(hokom, 0, [81, 81], bel: [2, 0]), [10, 8]),
      'BX4 Hokom 70 / 92, A belote: tie, B lost more to rounding → 0 / 18': (
        score(hokom, 0, [70, 92], bel: [2, 0]),
        [0, 18],
      ),
      'BX5 Sun 73 / 57: B counts 57 → 12; A 14': (score(sun, 0, [73, 57]), [14, 12]),
      'BX6 Sun 66 / 64, B a fifty: A fails → 0 / 36': (score(sun, 0, [66, 64], proj: [0, 10]), [0, 36]),
      'BX7 Sun 65 / 65: no rounding, the taker → 13 / 13': (score(sun, 0, [65, 65]), [13, 13]),
      'BX8 Hokom doubled by B, A sira, 76 / 86: A counts → 36 / 0': (
        score(hokom, 0, [76, 86], proj: [2, 0], level: 2),
        [36, 0],
      ),
      'BX9 Hokom tripled, A belote, 76 / 86: tie, A lost more → 50 / 0': (
        score(hokom, 0, [76, 86], bel: [2, 0], level: 3),
        [50, 0],
      ),
      'BX10 Hokom kaboot by A with a fifty and the belote → 32 / 0': (
        score(hokom, 0, [162, 0], proj: [5, 0], bel: [2, 0], kaboot: 0),
        [32, 0],
      ),
      'BX11 Sun kaboot by B; A\'s fifty had beaten B\'s sira → 0 / 44': (
        score(sun, 0, [0, 130], proj: [10, 0], kaboot: 1),
        [0, 44],
      ),
      'BX12 Hokom at four by B, B a fifty, 60 / 102 → 0 / 74': (
        score(hokom, 0, [60, 102], proj: [0, 5], level: 4),
        [0, 74],
      ),
    };
    for (final e in cases.entries) {
      test(e.key, () => expect(e.value.$1.points, e.value.$2));
    }
  });

  group('the 23 worked examples of the Saudi sources (PGL P1–P19, SAR S1–S3)', () {
    // (name, result, expected points, expected winner); teams 0 / 1.
    final cases = <(String, BalootDealScore, List<int>, int)>[
      ('P1 Hokum 77/85, team 1 takes: 8/8', score(hokom, 1, [77, 85]), [8, 8], 1),
      ('P2 Hokum 71/91 with belote: 9/9', score(hokom, 0, [71, 91], bel: [2, 0]), [9, 9], 0),
      ('P2b Hokum 70/92 with belote: 0/18', score(hokom, 0, [70, 92], bel: [2, 0]), [0, 18], 1),
      ('P3 Hokum 56/106, the counters\' fifty: 21/0', score(hokom, 1, [56, 106], proj: [5, 0]), [21, 0], 0),
      ('P4 same, doubled: 0/42', score(hokom, 1, [56, 106], proj: [5, 0], level: 2), [0, 42], 1),
      ('P5 Sun 64/66, the taker\'s fifty: 22/14', score(sun, 0, [64, 66], proj: [10, 0]), [22, 14], 0),
      ('P6 Sun 75/55, a siri: 15/15', score(sun, 0, [75, 55], proj: [0, 4]), [15, 15], 0),
      ('P7 Sun 89/41, a fifty: 0/36', score(sun, 0, [89, 41], proj: [0, 10]), [0, 36], 1),
      ('P8 Sun doubled 63/67: 0/52', score(sun, 1, [63, 67], level: 2), [0, 52], 1),
      ('P9 Hokum 81/81: 8/8', score(hokom, 0, [81, 81]), [8, 8], 0),
      ('P10 Hokum 80/82: 0/16', score(hokom, 0, [80, 82]), [0, 16], 1),
      ('P11 Hokum 82/80: 8/8', score(hokom, 0, [82, 80]), [8, 8], 0),
      ('P12 Sun 65/65: 13/13', score(sun, 0, [65, 65]), [13, 13], 0),
      ('P13 Sun 65/65 doubled: 52/0', score(sun, 0, [65, 65], level: 2), [52, 0], 0),
      ('P14 Sun 91/39, a fifty: 18/18', score(sun, 0, [91, 39], proj: [0, 10]), [18, 18], 0),
      ('P15 Sun 89/41, a fifty: 0/36', score(sun, 0, [89, 41], proj: [0, 10]), [0, 36], 1),
      ('P16 Sun 90/40, a fifty: 18/18', score(sun, 0, [90, 40], proj: [0, 10]), [18, 18], 0),
      ('P17 Hokum tripled 100/62, a siri: 52/0', score(hokom, 0, [100, 62], proj: [2, 0], level: 3), [52, 0], 0),
      (
        'P18 Hokum doubled kaboot, fifty + belote: 62/0',
        score(hokom, 0, [162, 0], proj: [5, 0], bel: [2, 0], level: 2, kaboot: 0),
        [62, 0],
        0,
      ),
      ('P19 Sun doubled kaboot, a siri: 96/0', score(sun, 0, [130, 0], proj: [4, 0], level: 2, kaboot: 0), [96, 0], 0),
      ('S1 Sun 54/76: 0/26', score(sun, 0, [54, 76]), [0, 26], 1),
      ('S2 Sun 95/35: 19/7', score(sun, 0, [95, 35]), [19, 7], 0),
      ('S3 Sun 60/70, a fifty: 22/14', score(sun, 0, [60, 70], proj: [10, 0]), [22, 14], 0),
    ];
    for (final (name, r, pts, winner) in cases) {
      test(name, () {
        expect(r.points, pts);
        expect(r.winner, winner);
      });
    }
  });

  group('belote on a lost or doubled deal (B7.7, option beloteOnLoss)', () {
    test('toWinner (default): the winners score every belote', () {
      expect(score(hokom, 0, [70, 92], bel: [2, 0]).points, [0, 18]);
      expect(score(hokom, 0, [100, 62], bel: [0, 2], level: 2).points, [34, 0]);
    });

    test('keptByHolder: each belote stays with its team (BX4 → 2 / 16)', () {
      expect(score(hokom, 0, [70, 92], bel: [2, 0], beloteOnLoss: BalootBeloteOnLoss.keptByHolder).points, [2, 16]);
    });

    test('voided: a loser\'s belote is lost', () {
      expect(score(hokom, 0, [70, 92], bel: [2, 0], beloteOnLoss: BalootBeloteOnLoss.voided).points, [0, 16]);
      expect(score(hokom, 0, [50, 112], bel: [0, 2], beloteOnLoss: BalootBeloteOnLoss.voided).points, [0, 18]);
    });

    test('B7.7 the belote is never multiplied', () {
      expect(score(hokom, 0, [120, 42], bel: [2, 0], level: 4).points, [64 + 2, 0]);
    });
  });

  group('doubled deals (B9.8, §12.2)', () {
    test('Hokom 32 / 48 / 64, Sun 52; projects doubled at most (option: × the level)', () {
      expect(score(hokom, 0, [120, 42], level: 2).points, [32, 0]);
      expect(score(hokom, 0, [120, 42], level: 3).points, [48, 0]);
      expect(score(hokom, 0, [120, 42], level: 4).points, [64, 0]);
      expect(score(sun, 0, [100, 30], level: 2).points, [52, 0]);
      expect(score(hokom, 0, [120, 42], proj: [5, 0], level: 3).points, [48 + 10, 0]);
      expect(score(hokom, 0, [120, 42], proj: [5, 0], level: 3, cap: null).points, [48 + 15, 0]);
      expect(score(hokom, 0, [60, 102], proj: [0, 5], level: 4, cap: null).points, [0, 84]);
    });

    test('B9.8 kaboot doubled / tripled / at four: 50 / 75 / 100 (Hokom), 88 (Sun)', () {
      expect(score(hokom, 0, [162, 0], level: 2, kaboot: 0).points, [50, 0]);
      expect(score(hokom, 0, [162, 0], level: 3, kaboot: 0).points, [75, 0]);
      expect(score(hokom, 0, [162, 0], level: 4, kaboot: 0).points, [100, 0]);
      expect(score(sun, 0, [130, 0], level: 2, kaboot: 0).points, [88, 0]);
    });

    test('§13 a doubled deal tied with equal rounding: the taker\'s team wins (the doubler loses)', () {
      expect(score(sun, 0, [65, 65], level: 2).winner, 0);
      expect(score(hokom, 1, [81, 81], level: 2).winner, 1);
    });

    test('B9.9 gahwa: the figures of level 1, winner takes all', () {
      final r = score(hokom, 0, [120, 42], level: 4, gahwa: true);
      expect(r.points, [16, 0]);
      expect(r.winner, 0);
    });
  });

  group('dealResult on real tricks', () {
    test('raw points per team (last trick included)', () {
      expect(BalootRules.rawPoints(finished()), [121, 41]);
    });

    test('made, failed, projects, belote, doubled', () {
      final made = BalootRules.dealResult(finished());
      expect(made.points, [12, 4]);
      expect(made.made, isTrue);
      expect(made.countingTeam, 1);
      expect(made.gamePoints, [12, 4]);
      final failed = BalootRules.dealResult(finished(buyer: 1));
      expect(failed.points, [16, 0]);
      expect(failed.made, isFalse);
      expect(failed.winner, 0);
      // A hundred for the takers (10 in Hokom) turns the failure around.
      final withProject = finished(buyer: 1)
        ..projects = [
          BalootProject(BalootProjectType.hundred, 1, c('KD KH KC KS')),
          BalootProject(BalootProjectType.sira, 0, c('7H 8H 9H')),
        ];
      final r = BalootRules.dealResult(withProject);
      expect(r.points, [12, 14]);
      expect(r.projectPoints, [0, 10]);
      expect(BalootRules.dealResult(finished()..belote = 2).points, [14, 4]);
      // B7.7 the takers' belote goes to the defenders when the takers fail.
      final lost = BalootRules.dealResult(finished(buyer: 1)..belote = 3);
      expect(lost.points, [18, 0]);
      expect(lost.belotePoints, [0, 2]);
      expect(
        BalootRules.dealResult(
          finished(buyer: 1, options: const BalootOptions(beloteOnLoss: BalootBeloteOnLoss.keptByHolder))..belote = 3,
        ).points,
        [16, 2],
      );
      // Doubled: the winner takes everything twice.
      final doubled = BalootRules.dealResult(finished()..level = 2);
      expect(doubled.points, [32, 0]);
      expect(doubled.countingTeam, 0);
      expect(BalootRules.dealResult(finished(buyer: 1)..level = 3).points, [48, 0]);
    });

    test('B7.8 no belote for a holder whose team scores four kings with the trump K', () {
      final s = finished()
        ..belote = 2
        ..projects = [BalootProject(BalootProjectType.hundred, 2, c('KD KH KC KS'))];
      final r = BalootRules.dealResult(s);
      expect(r.belotePoints, [0, 0]);
      expect(r.points, [12 + 10, 4]);
      // The same holder with a trump sira K-Q-J: both count.
      final t = finished()
        ..belote = 2
        ..projects = [BalootProject(BalootProjectType.sira, 2, c('JS QS KS'))];
      expect(BalootRules.dealResult(t).points, [12 + 2 + 2, 4]);
    });

    test('B9.7 kaboot: 25 (Hokom) / 44 (Sun) plus the kaboot team\'s own projects; the others\' are void', () {
      final hokomAll = finished(played: kabootTricks(hokom));
      expect(BalootRules.dealResult(hokomAll).points, [25, 0]);
      expect(BalootRules.dealResult(hokomAll).kabootTeam, 0);
      expect(BalootRules.dealResult(finished(mode: sun, played: kabootTricks(sun))).points, [44, 0]);
      // Kaboot by the defenders: they score the kaboot, not 16.
      expect(BalootRules.dealResult(finished(buyer: 1, played: kabootTricks(hokom))).points, [25, 0]);
      // The kabooted team's projects and belote are void.
      final losers = finished(played: kabootTricks(hokom))
        ..belote = 1
        ..projects = [BalootProject(BalootProjectType.fifty, 1, c('7H 8H 9H TH'))];
      expect(BalootRules.dealResult(losers).points, [25, 0]);
      final own = finished(played: kabootTricks(hokom))
        ..belote = 2
        ..projects = [BalootProject(BalootProjectType.fifty, 0, c('7H 8H 9H TH'))];
      expect(BalootRules.dealResult(own).points, [25 + 5 + 2, 0]);
    });
  });

  group('match (B10)', () {
    /// Seven tricks done; the last one to be played (seat 0 leads and wins).
    BalootEngine lastTrick({required List<int> scores, int level = 1, bool gahwa = false}) {
      final all = tricks();
      final s = finished()
        ..tricks = all.sublist(0, 7)
        ..hands = [for (final card in all[7].cards) <PlayingCard>[card]]
        ..trick = Trick(0)
        ..turn = 0
        ..teamScores = List.of(scores)
        ..level = level
        ..gahwa = gahwa;
      return BalootEngine(s);
    }

    void finish(BalootEngine e) {
      for (final id in ['TC', 'JC', 'QC', 'KC']) {
        e.apply(BalootMove.play(p(id)));
      }
    }

    test('B10.1–B10.2 first team to 152 wins, checked after each deal', () {
      final e = lastTrick(scores: [145, 100]);
      finish(e);
      expect(e.state.teamScores, [157, 104]);
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0, 2]);
    });

    test('B10.3 both over 152: the higher total wins', () {
      final e = lastTrick(scores: [145, 150]);
      finish(e);
      expect(e.state.teamScores, [157, 154]);
      expect(e.state.winners, [0, 2]);
    });

    test('B10.3 both over 152 and exactly equal: another deal is played', () {
      final e = lastTrick(scores: [140, 148]);
      finish(e);
      expect(e.state.teamScores, [152, 152]);
      expect(e.isOver, isFalse);
      expect(e.state.phase, BalootPhase.bidding);
      expect(e.state.dealNumber, 2);
    });

    test('below the target the next dealer deals', () {
      final e = lastTrick(scores: [0, 0]);
      finish(e);
      expect(e.state.results.single.points, [12, 4]);
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
    });

    test('B9.9 B10.4 gahwa: the winner of the deal wins the match at once', () {
      final e = lastTrick(scores: [0, 140], level: 4, gahwa: true);
      finish(e);
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0, 2]);
      expect(e.state.results.single.level, 5);
    });

    test('a gahwa played out from the auction ends the match after one deal', () {
      final e = BalootEngine(
        BalootState.withDeal(
          hands: [c('JS 9S AS 7H 8H'), c('TS KS QS 9H TH'), c('8S 7S JH QH KH'), c('AH 7D 8D JD QD')],
          upCard: p('9D'),
          stock: c('KD TD AD 7C 8C 9C TC JC QC KC AC'),
        ),
      );
      e.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      e.apply(const BalootMove.confirm());
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
