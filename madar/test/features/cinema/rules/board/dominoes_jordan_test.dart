// Dominoes «دومينو» as commonly played in Jordan – one test per rule of the
// final spec (rule ids D-…, F-…, E-… as in RULES.md §4).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show BoardGameId, boardGameKits;
import 'package:madar/features/cinema/rules/board/core/engine.dart';
import 'package:madar/features/cinema/rules/board/core/game_types.dart';
import 'package:madar/features/cinema/rules/board/core/rng.dart';
import 'package:madar/features/cinema/rules/board/dominoes/dominoes_rules.dart';

import 'board_test_utils.dart';

Domino d(int a, int b) => Domino.of(a, b);

/// A line from (left, right) pairs, left to right.
List<PlacedDomino> chain(List<(int, int)> tiles) => [for (final (a, b) in tiles) PlacedDomino(d(a, b), a, b)];

/// A state with explicit hands; the rest of the set is the stock unless
/// [boneyard] is given.
DominoState dom(
  List<List<Domino>> hands, {
  List<PlacedDomino> line = const [],
  List<Domino>? boneyard,
  int player = 0,
  DominoConfig? config,
  List<int>? scores,
  int? lastMover,
  int roundStarter = 0,
}) {
  final cfg = config ?? DominoConfig(players: hands.length, targetScore: 0);
  final used = {for (final h in hands) ...h, for (final p in line) p.tile};
  final s = DominoState(
    config: cfg,
    hands: hands,
    boneyard:
        boneyard ??
        [
          for (final t in Domino.doubleSix)
            if (!used.contains(t)) t,
        ],
    line: line,
    currentPlayer: player,
    phase: DominoPhase.playing,
    scores: scores ?? List.filled(cfg.sides, 0),
    voids: List.filled(cfg.players, 0),
    rng: const [5, 6, 7, 8],
    lastMover: lastMover,
    roundStarter: roundStarter,
  );
  if (boneyard == null) checkInvariants(s);
  return s;
}

/// Brute force: no tile outside the line matches either end.
bool bruteLocked(DominoState s) {
  if (s.line.isEmpty) return false;
  final outside = [for (final h in s.hands) ...h, ...s.boneyard];
  return !outside.any((t) => t.matches(s.leftEnd) || t.matches(s.rightEnd));
}

/// Nine tiles with ends 5 (left) and 6 (right) holding six of the seven
/// 5-tiles; [5|6] on the right completes the lock on 5 (3 joints on 5).
final List<PlacedDomino> almostLocked = chain([(5, 0), (0, 1), (1, 5), (5, 5), (5, 2), (2, 3), (3, 5), (5, 4), (4, 6)]);

const rules = dominoRules;

DominoState playOut(DominoState s, {int cap = 200}) {
  for (var i = 0; i < cap && s.phase == DominoPhase.playing; i++) {
    s = rules.apply(s, rules.legalMoves(s).first);
  }
  return s;
}

void main() {
  group('configuration', () {
    test('D-C4: DominoConfig() and the kit are the Jordanian game', () {
      const c = DominoConfig();
      expect(c, const DominoConfig.jordan(players: 2));
      expect(c.drawFromBoneyard, isTrue);
      expect(c.handSize, 7);
      expect(c.targetScore, 101);
      expect(c.endWhenLocked, isTrue);
      expect(c.scoring, DominoScoring.count);
      expect(c.rounding, DominoRounding.none);
      expect(c.noDoubleOpening, DominoNoDoubleOpening.heaviestTile);
      expect(c.stockReserve, 0);
      expect(c.blockedScoring, DominoBlockedScoring.opponentsPips);
      expect(c.blockedTie, DominoBlockedTie.noScore);
      expect(c.blockedCompare, DominoBlockedCompare.sideTotal);
      expect(c.highestDoubleEveryRound, isFalse);
      for (final n in [2, 3, 4]) {
        final kit = boardGameKits[BoardGameId.dominoes]!.newGame(players: n, seed: 3) as DominoState;
        expect(kit.config, DominoConfig.jordan(players: n));
      }
    });

    test('N4 / D-4: four players play in partnerships by default; 2–3 play alone', () {
      expect(const DominoConfig(players: 2).teams, isFalse);
      expect(const DominoConfig(players: 3).teams, isFalse);
      expect(const DominoConfig(players: 4).teams, isTrue);
      expect(const DominoConfig(players: 4, teams: false).teams, isFalse);
      expect(const DominoConfig(players: 4).sides, 2);
      expect(const DominoConfig(players: 4).copyWith(players: 3).teams, isFalse);
    });

    test('presets: «الخمسات» to 150 (F-6), block game (D-27), played-out lock (D-19 option)', () {
      const f = DominoConfig.allFives(players: 2);
      expect(f.scoring, DominoScoring.allFives);
      expect(f.targetScore, 150);
      expect(f.roundsToFive, isTrue);
      expect(const DominoConfig.block(players: 3).drawFromBoneyard, isFalse);
      expect(const DominoConfig.playOutLock(players: 2).endWhenLocked, isFalse);
    });

    test('D-C2 / E-16: an old save without the new keys keeps its old behaviour', () {
      final old = {'players': 2, 'teams': false, 'draw': true, 'hand': 7, 'target': 101, 'doubleEveryRound': false};
      final c = DominoConfig.fromJson(old);
      expect(c.endWhenLocked, isFalse);
      expect(c, const DominoConfig.playOutLock(players: 2));
      // A whole old engine save replays move for move.
      final e = BoardGameEngine<DominoState, DominoMove>(
        rules,
        DominoState.initial(seed: 21, config: const DominoConfig.playOutLock(players: 2)),
      );
      final rng = BoardRng(4);
      for (var i = 0; i < 60 && !e.isOver; i++) {
        e.apply(rng.pick(e.legalMoves()));
      }
      final json = roundTrip(e.toJson());
      final initial = jsonMap(json['initial']);
      final cfg = jsonMap(initial['config']);
      for (final k in [
        'lockEnds',
        'noDouble',
        'reserve',
        'scoring',
        'round',
        'blockedScore',
        'blockedTie',
        'blockedCompare',
      ]) {
        cfg.remove(k);
      }
      expect(cfg.keys.toSet(), {'players', 'teams', 'draw', 'hand', 'target', 'doubleEveryRound'});
      initial['config'] = cfg;
      json['initial'] = initial;
      final restored = BoardGameEngine<DominoState, DominoMove>.fromJson(rules, json);
      expect(canonical(restored.state), canonical(e.state));
    });

    test('every option survives a JSON round-trip', () {
      const c = DominoConfig(
        players: 4,
        teams: false,
        drawFromBoneyard: false,
        handSize: 5,
        targetScore: 151,
        highestDoubleEveryRound: true,
        endWhenLocked: false,
        noDoubleOpening: DominoNoDoubleOpening.reshuffle,
        stockReserve: 2,
        scoring: DominoScoring.allFives,
        rounding: DominoRounding.nearestFive,
        blockedScoring: DominoBlockedScoring.allHands,
        blockedTie: DominoBlockedTie.lockerLoses,
        blockedCompare: DominoBlockedCompare.lowestPlayer,
      );
      expect(DominoConfig.fromJson(roundTrip(c.toJson())), c);
    });
  });

  group('deal and lead', () {
    test('D-1–D-3: 28 tiles; 7 each; stock 14 / 7 / 0; D-3′ option: 5 each', () {
      expect(Domino.doubleSix.fold<int>(0, (a, t) => a + t.pips), 168);
      for (final players in [2, 3, 4]) {
        final s = DominoState.initial(
          seed: players,
          config: DominoConfig(players: players),
        );
        checkInvariants(s);
        expect(s.hands.every((h) => h.length == 7), isTrue);
        expect(s.boneyard, hasLength(28 - 7 * players));
      }
      final gulf = DominoState.initial(seed: 1, config: const DominoConfig(players: 4, handSize: 5));
      expect(gulf.hands.every((h) => h.length == 5), isTrue);
      expect(gulf.boneyard, hasLength(8));
    });

    test('D-5, D-6, E-1: round 1 is led by the highest double dealt, and it must be played', () {
      for (var seed = 0; seed < 60; seed++) {
        final s = DominoState.initial(seed: seed);
        final doubles = [
          for (final h in s.hands)
            for (final t in h)
              if (t.isDouble) t,
        ]..sort((a, b) => b.high - a.high);
        if (doubles.isEmpty) continue;
        expect(s.mustLead, doubles.first);
        expect(s.hands[s.currentPlayer], contains(doubles.first));
        expect(rules.legalMoves(s), [DominoMove.play(doubles.first, DominoEnd.left)]);
      }
      // Four players: all 28 are dealt, so 6-6 always opens.
      for (var seed = 0; seed < 10; seed++) {
        expect(DominoState.initial(seed: seed, config: const DominoConfig(players: 4)).mustLead, d(6, 6));
      }
    });

    int? noDoubleSeed({bool Function(DominoState)? also}) {
      for (var seed = 0; seed < 400000; seed++) {
        final s = DominoState.initial(seed: seed);
        if (s.hands.any((h) => h.any((t) => t.isDouble))) continue;
        if (also == null || also(s)) return seed;
      }
      return null;
    }

    test('D-7, E-2: no double dealt → the heaviest tile leads; equal pips → the higher number (6-3 over 5-4)', () {
      final seed = noDoubleSeed()!;
      final s = DominoState.initial(seed: seed);
      final all = [for (final h in s.hands) ...h]..sort((a, b) => a.pips != b.pips ? b.pips - a.pips : b.high - a.high);
      expect(s.mustLead, all.first);
      bool dealt(DominoState x, Domino t) => x.hands.any((h) => h.contains(t));
      final tie = noDoubleSeed(
        also: (x) => !dealt(x, d(5, 6)) && !dealt(x, d(4, 6)) && dealt(x, d(3, 6)) && dealt(x, d(4, 5)),
      )!;
      expect(DominoState.initial(seed: tie).mustLead, d(3, 6));
    });

    test('D-7 option `reshuffle`: deal again until a double is dealt (deterministic)', () {
      final seed = noDoubleSeed()!;
      const cfg = DominoConfig(noDoubleOpening: DominoNoDoubleOpening.reshuffle);
      final s = DominoState.initial(seed: seed, config: cfg);
      expect(s.hands.any((h) => h.any((t) => t.isDouble)), isTrue);
      expect(s.mustLead!.isDouble, isTrue);
      expect(canonical(DominoState.initial(seed: seed, config: cfg)), canonical(s));
      checkInvariants(s);
    });

    test('D-8: later rounds are led by the previous winner with any tile', () {
      final s = dom(
        [
          [d(6, 1)],
          [d(4, 4)],
        ],
        line: chain([(6, 6)]),
        config: const DominoConfig(targetScore: 101),
      );
      final won = rules.apply(s, DominoMove.play(d(6, 1), DominoEnd.left));
      expect(won.lastRound!.winner, 0);
      final next = rules.apply(won, DominoMove.nextRound);
      expect(next.round, 2);
      expect(next.currentPlayer, 0);
      expect(next.mustLead, isNull);
      expect(rules.legalMoves(next), hasLength(7));
    });

    test('D-9: after a tied blocked round, the player after the previous leader leads', () {
      var s = dom(
        [
          [d(0, 3)],
          [d(1, 2)],
        ],
        line: chain([(5, 5)]),
        boneyard: const [],
        config: const DominoConfig(targetScore: 101),
      );
      s = rules.apply(rules.apply(s, DominoMove.pass), DominoMove.pass);
      expect(s.lastRound!.winner, isNull);
      expect(s.lastRound!.points, 0);
      expect(rules.apply(s, DominoMove.nextRound).currentPlayer, 1);
    });

    test('D-28 option: the highest double leads every round', () {
      final s = dom(
        [
          [d(6, 1)],
          [d(4, 4)],
        ],
        line: chain([(6, 6)]),
        config: const DominoConfig(targetScore: 101, highestDoubleEveryRound: true),
      );
      final next = rules.apply(rules.apply(s, DominoMove.play(d(6, 1), DominoEnd.left)), DominoMove.nextRound);
      expect(next.mustLead, isNotNull);
      expect(next.mustLead!.isDouble, isTrue);
      expect(next.hands[next.currentPlayer], contains(next.mustLead));
    });
  });

  group('play', () {
    test('D-11–D-13: match an end, two ends only, and a playable tile must be played (no drawing)', () {
      var s = dom([
        [d(6, 6), d(6, 3), d(1, 1)],
        [d(6, 2), d(0, 0), d(4, 4)],
      ]);
      s = rules.apply(s, DominoMove.play(d(6, 6), DominoEnd.left));
      expect(rules.legalMoves(s).toSet(), {
        DominoMove.play(d(6, 2), DominoEnd.left),
        DominoMove.play(d(6, 2), DominoEnd.right),
      });
      expect(rules.legalMoves(s), isNot(contains(DominoMove.draw)));
      expect(rules.isLegal(s, DominoMove.play(d(0, 0), DominoEnd.left)), isFalse);
      s = rules.apply(s, DominoMove.play(d(6, 2), DominoEnd.right));
      expect((s.leftEnd, s.rightEnd), (6, 2));
      s = rules.apply(s, DominoMove.play(d(6, 3), DominoEnd.left));
      expect([for (final p in s.line) '${p.left}${p.right}'], ['36', '66', '62']);
    });

    test('D-14, E-3: draw one tile at a time until able, then stop and play', () {
      var s = dom(
        [
          [d(0, 1)],
          [d(2, 2)],
        ],
        line: chain([(5, 5)]),
        boneyard: [d(0, 5), d(3, 4), d(1, 3)],
      );
      expect(rules.legalMoves(s), [DominoMove.draw]);
      s = rules.apply(s, DominoMove.draw); // [1|3]
      s = rules.apply(s, DominoMove.draw); // [3|4]
      expect(rules.legalMoves(s), [DominoMove.draw]);
      s = rules.apply(s, DominoMove.draw); // [0|5] – playable
      expect(s.currentPlayer, 0);
      expect(rules.legalMoves(s).toSet(), {
        DominoMove.play(d(0, 5), DominoEnd.left),
        DominoMove.play(d(0, 5), DominoEnd.right),
      });
      expect(s.voids[0], 1 << 5, reason: 'the drawing player is publicly void in 5');
    });

    test('D-15: block game – a player who cannot play passes at once', () {
      final s = dom(
        [
          [d(0, 1)],
          [d(2, 2)],
        ],
        line: chain([(5, 5)]),
        config: const DominoConfig.block(players: 2, targetScore: 0),
      );
      expect(rules.legalMoves(s), [DominoMove.pass]);
    });

    test('E-4: with an empty stock the player passes, and passes by everyone block the round', () {
      var s = dom(
        [
          [d(0, 1)],
          [d(2, 2)],
        ],
        line: chain([(5, 5)]),
        boneyard: const [],
      );
      expect(rules.legalMoves(s), [DominoMove.pass]);
      s = rules.apply(s, DominoMove.pass);
      expect(s.phase, DominoPhase.playing);
      s = rules.apply(s, DominoMove.pass);
      expect(s.phase, DominoPhase.roundOver);
      expect(s.lastRound!.end, DominoRoundEnd.blocked);
      expect(s.lastRound!.locked, isFalse);
    });

    test('D-16, E-15 option: the stock reserve is never drawn', () {
      const cfg = DominoConfig(stockReserve: 2, targetScore: 0);
      final two = dom(
        [
          [d(0, 1)],
          [d(2, 2)],
        ],
        line: chain([(5, 5)]),
        boneyard: [d(0, 5), d(3, 5)],
        config: cfg,
      );
      expect(two.drawableStock, 0);
      expect(rules.legalMoves(two), [DominoMove.pass]);
      final three = dom(
        [
          [d(0, 1)],
          [d(2, 2)],
        ],
        line: chain([(5, 5)]),
        boneyard: [d(0, 5), d(3, 5), d(3, 4)],
        config: cfg,
      );
      expect(rules.legalMoves(three), [DominoMove.draw]);
      final after = rules.apply(three, DominoMove.draw);
      expect(rules.legalMoves(after), [DominoMove.pass]);
    });
  });

  group('the locked line «قفلت» (D-19)', () {
    // P0 holds 23 pips, P1 [5|6] + 17 pips, 11 tiles in the stock.
    DominoState probe(DominoConfig config) => dom(
      [
        [d(6, 6), d(2, 4), d(1, 2), d(0, 2)],
        [d(5, 6), d(3, 6), d(2, 6), d(0, 0)],
      ],
      line: almostLocked,
      player: 1,
      config: config,
    );

    test('E-13: the line is never locked while the ends differ', () {
      expect(DominoState.isLocked(almostLocked), isFalse);
      expect(DominoState.isLocked(const []), isFalse);
      expect(DominoState.isLocked(chain([(5, 5)])), isFalse);
      expect(DominoState.isLocked([...almostLocked, PlacedDomino(d(5, 6), 6, 5)]), isTrue);
    });

    test('D-19, E-5: a lock with tiles left in the stock ends the round at once; nobody draws', () {
      final s = probe(const DominoConfig(targetScore: 0));
      expect(s.handPips(0), 23);
      final end = rules.apply(s, DominoMove.play(d(5, 6), DominoEnd.right));
      expect(end.phase, DominoPhase.roundOver);
      expect(end.lastRound!.end, DominoRoundEnd.blocked);
      expect(end.lastRound!.locked, isTrue);
      expect(end.lastRound!.stockLeft, 11);
      expect(end.boneyard, hasLength(11));
      expect(end.lastRound!.winner, 1);
      expect(end.lastRound!.points, 23, reason: 'the stock is not counted');
      expect(end.result!.winners, [1]);
    });

    test('D-19 option `endWhenLocked: false`: the player to move draws the whole stock, then all pass', () {
      var s = rules.apply(
        probe(const DominoConfig.playOutLock(players: 2, targetScore: 0)),
        DominoMove.play(d(5, 6), DominoEnd.right),
      );
      expect(s.phase, DominoPhase.playing);
      final stockPips = s.boneyard.fold<int>(0, (a, t) => a + t.pips);
      var draws = 0;
      while (rules.legalMoves(s).single == DominoMove.draw) {
        s = rules.apply(s, DominoMove.draw);
        draws++;
      }
      expect(draws, 11);
      s = rules.apply(rules.apply(s, DominoMove.pass), DominoMove.pass);
      expect(s.lastRound!.end, DominoRoundEnd.blocked);
      expect(s.lastRound!.locked, isTrue);
      expect(s.lastRound!.winner, 1);
      expect(s.lastRound!.points, 23 + stockPips);
    });

    test('E-6: a last tile that also locks the line is a going-out win', () {
      final s = dom(
        [
          [d(6, 6), d(2, 4)],
          [d(5, 6)],
        ],
        line: almostLocked,
        player: 1,
      );
      final end = rules.apply(s, DominoMove.play(d(5, 6), DominoEnd.right));
      expect(end.lastRound!.end, DominoRoundEnd.domino);
      expect(end.lastRound!.winner, 1);
      expect(end.lastRound!.points, 18);
      expect(end.lastRound!.locked, isFalse);
    });

    test('E-14: with four players a lock gives the same result as four passes, only sooner', () {
      List<List<Domino>> hands() => [
        [d(0, 0), d(0, 2), d(0, 3), d(0, 4), d(0, 6)],
        [d(5, 6), d(1, 1), d(1, 2), d(1, 3), d(1, 4)],
        [d(1, 6), d(2, 2), d(2, 4), d(2, 6), d(3, 3)],
        [d(3, 4), d(3, 6), d(4, 4), d(6, 6)],
      ];
      DominoState start(DominoConfig c) => dom(hands(), line: almostLocked, player: 1, boneyard: const [], config: c);
      final now = rules.apply(
        start(const DominoConfig(players: 4, targetScore: 0)),
        DominoMove.play(d(5, 6), DominoEnd.right),
      );
      var later = rules.apply(
        start(const DominoConfig.playOutLock(players: 4, targetScore: 0)),
        DominoMove.play(d(5, 6), DominoEnd.right),
      );
      var passes = 0;
      while (later.phase == DominoPhase.playing) {
        expect(rules.legalMoves(later), [DominoMove.pass]);
        later = rules.apply(later, DominoMove.pass);
        passes++;
      }
      expect(passes, 4);
      expect(now.lastRound!.locked, isTrue);
      expect(now.lastRound!.winner, later.lastRound!.winner);
      expect(now.lastRound!.points, later.lastRound!.points);
      expect(now.scores, later.scores);
    });

    test('D-C8 (d): the lock check equals a brute-force check on self-play states', () {
      var lockedSeen = 0;
      for (final cfg in [
        const DominoConfig.playOutLock(players: 2, targetScore: 0),
        const DominoConfig.playOutLock(players: 3, targetScore: 0),
        const DominoConfig(players: 2, targetScore: 0),
        const DominoConfig(players: 4, targetScore: 0),
      ]) {
        for (var seed = 0; seed < 40; seed++) {
          var s = DominoState.initial(seed: seed, config: cfg);
          final rng = BoardRng(seed + 1000);
          while (!s.isOver) {
            expect(s.lineLocked, bruteLocked(s), reason: 'seed $seed ${s.line}');
            if (s.leftEnd != s.rightEnd) expect(s.lineLocked, isFalse);
            if (s.lineLocked) lockedSeen++;
            s = rules.apply(s, rng.pick(rules.legalMoves(s)));
          }
          if (s.lastRound!.end == DominoRoundEnd.blocked && s.line.isNotEmpty && bruteLocked(s)) {
            expect(s.leftEnd, s.rightEnd, reason: 'a blocked lock always has equal ends');
          }
        }
      }
      expect(lockedSeen, greaterThan(0));
    });
  });

  group('count scoring', () {
    test('D-20, E-7: going out scores the opponents\' pips; the partner and the stock do not count', () {
      final s = dom(
        [
          [d(5, 5), d(4, 6)],
          [d(3, 4), d(2, 4)],
          [d(1, 6)],
          [d(4, 5)],
        ],
        line: chain([(6, 6)]),
        player: 2,
      );
      expect(s.config.teams, isTrue);
      expect(s.boneyard, isNotEmpty);
      final end = rules.apply(s, DominoMove.play(d(1, 6), DominoEnd.left));
      expect(end.lastRound!.end, DominoRoundEnd.domino);
      expect(end.lastRound!.points, 13 + 9);
      expect(end.scores, [22, 0]);
      expect(end.result!.winners, [0, 2]);
      expect(end.result!.scores, [22, 0, 22, 0]);
    });

    test('D-21: no rounding by default; option `nearestFive` rounds hand points', () {
      DominoState out(DominoConfig c) => rules.apply(
        dom(
          [
            [d(6, 1)],
            [d(4, 5), d(0, 4)],
          ],
          line: chain([(6, 6)]),
          config: c,
        ),
        DominoMove.play(d(6, 1), DominoEnd.left),
      );
      expect(out(const DominoConfig(targetScore: 0)).lastRound!.points, 13);
      expect(out(const DominoConfig(targetScore: 0, rounding: DominoRounding.nearestFive)).lastRound!.points, 15);
    });

    test('E-12, F-3: round5 – to the nearest five, halves up', () {
      const table = {0: 0, 2: 0, 3: 5, 7: 5, 8: 10, 12: 10, 13: 15, 22: 20, 23: 25};
      table.forEach((x, y) => expect(DominoRules.round5(x), y, reason: '$x'));
    });

    DominoState blocked(List<List<Domino>> hands, DominoConfig config, {List<PlacedDomino>? line}) {
      var s = dom(hands, line: line ?? chain([(5, 5)]), boneyard: const [], config: config);
      for (var i = 0; i < config.players; i++) {
        s = rules.apply(s, DominoMove.pass);
      }
      expect(s.lastRound!.end, DominoRoundEnd.blocked);
      return s;
    }

    test('D-22: blocked – the lowest side wins the opponents\' pips; its lightest hand leads next', () {
      final s = blocked([
        [d(6, 6)],
        [d(4, 6)],
        [d(3, 4)],
        [d(3, 6), d(0, 1)],
      ], const DominoConfig(players: 4, targetScore: 101));
      expect(s.lastRound!.winner, 2);
      expect(s.lastRound!.points, 20);
      expect(s.scores, [20, 0]);
      expect(rules.apply(s, DominoMove.nextRound).currentPlayer, 2);
    });

    test('D-23, E-8: a tie for the lowest scores nothing (three players 8, 8, 15)', () {
      final s = blocked(
        [
          [d(2, 6)],
          [d(3, 5)],
          [d(4, 5), d(1, 5)],
        ],
        const DominoConfig(players: 3, targetScore: 101),
        line: chain([(0, 0)]),
      );
      expect(s.lastRound!.winner, isNull);
      expect(s.lastRound!.points, 0);
      expect(s.scores, [0, 0, 0]);
    });

    test('E-9: equal team totals score nothing; option `lowestPlayer` lets the lightest hand decide', () {
      final hands = [
        [d(1, 4)], // 5 – team A
        [d(3, 4)], // 7 – team B
        [d(4, 6)], // 10 – team A
        [d(2, 6)], // 8 – team B
      ];
      final tie = blocked(hands, const DominoConfig(players: 4, targetScore: 0));
      expect(tie.lastRound!.winner, isNull);
      expect(tie.result!.isDraw, isTrue);
      final lowest = blocked(
        hands,
        const DominoConfig(players: 4, targetScore: 0, blockedCompare: DominoBlockedCompare.lowestPlayer),
      );
      expect(lowest.lastRound!.winner, 0);
      expect(lowest.lastRound!.points, 15);
      expect(lowest.scores, [15, 0]);
    });

    test('D-29 options: blocked scoring by `difference` or `allHands`', () {
      final hands = [
        [d(4, 6)], // 10
        [d(6, 6), d(6, 1), d(2, 4)], // 25
      ];
      int points(DominoBlockedScoring b) =>
          blocked(hands, DominoConfig(targetScore: 0, blockedScoring: b)).lastRound!.points;
      expect(points(DominoBlockedScoring.opponentsPips), 25);
      expect(points(DominoBlockedScoring.difference), 15);
      expect(points(DominoBlockedScoring.allHands), 35);
    });

    test('D-24 with `difference` + `lowestPlayer`: the winning side never scores below 0', () {
      // Team A (0 + 2) holds the single lightest hand (1 pip) but the larger
      // total, 1 + 22 = 23; team B (1 + 3) holds 7 + 8 = 15. `lowestPlayer`
      // makes A the winner, and `difference` (15 − 23) must not take points.
      final hands = [
        [d(0, 1)], // 1 – team A
        [d(3, 4)], // 7 – team B
        [d(4, 6), d(6, 6)], // 22 – team A
        [d(2, 6)], // 8 – team B
      ];
      for (final scoring in [DominoScoring.count, DominoScoring.allFives]) {
        final cfg = DominoConfig(
          players: 4,
          scoring: scoring,
          blockedScoring: DominoBlockedScoring.difference,
          blockedCompare: DominoBlockedCompare.lowestPlayer,
        );
        expect(DominoRules.settle(cfg, const [1, 7, 22, 8], null, 3), (winner: 0, points: 0));
        var s = dom(hands, line: chain([(5, 5)]), boneyard: const [], config: cfg, scores: [40, 30]);
        for (var i = 0; i < 4; i++) {
          s = rules.apply(s, DominoMove.pass);
        }
        expect(s.lastRound!.end, DominoRoundEnd.blocked);
        expect(s.lastRound!.winner, 0, reason: 'A still wins the round and leads next');
        expect(s.lastRound!.points, 0, reason: scoring.name);
        expect(s.scores, [40, 30], reason: 'scores never fall (${scoring.name})');
      }
    });

    test('D-30 option `lockerLoses`: of two tied sides, the one that did not lock wins', () {
      DominoState lock(DominoConfig c) => rules.apply(
        dom(
          [
            [d(3, 4), d(0, 2)], // 9
            [d(5, 6), d(3, 6)], // 9 after the lock
          ],
          line: almostLocked,
          player: 1,
          config: c,
        ),
        DominoMove.play(d(5, 6), DominoEnd.right),
      );
      expect(lock(const DominoConfig(targetScore: 0)).lastRound!.winner, isNull);
      final s = lock(const DominoConfig(targetScore: 0, blockedTie: DominoBlockedTie.lockerLoses));
      expect(s.lastRound!.winner, 0);
      expect(s.lastRound!.points, 9);
      // Three players, the locker is not among the tied: nobody scores.
      final three = rules.apply(
        dom(
          [
            [d(2, 6)], // 8
            [d(4, 4)], // 8
            [d(5, 6), d(6, 6), d(0, 3)], // 15 after the lock
          ],
          line: almostLocked,
          player: 2,
          config: const DominoConfig(players: 3, targetScore: 0, blockedTie: DominoBlockedTie.lockerLoses),
        ),
        DominoMove.play(d(5, 6), DominoEnd.right),
      );
      expect(three.lastRound!.locked, isTrue);
      expect(three.lastRound!.winner, isNull);
    });

    test('E-10: the opponent holds only [0|0] – the winner scores 0 but wins the round and leads', () {
      final s = rules.apply(
        dom(
          [
            [d(6, 1)],
            [d(0, 0)],
          ],
          line: chain([(6, 6)]),
          config: const DominoConfig(targetScore: 101),
        ),
        DominoMove.play(d(6, 1), DominoEnd.left),
      );
      expect(s.lastRound!.winner, 0);
      expect(s.lastRound!.points, 0);
      expect(s.isOver, isFalse);
      expect(rules.apply(s, DominoMove.nextRound).currentPlayer, 0);
    });

    test('D-25, E-11: the match goes to 101, checked only at the end of a round', () {
      DominoState out(List<int> scores) => rules.apply(
        dom(
          [
            [d(6, 1)],
            [d(3, 4)],
          ],
          line: chain([(6, 6)]),
          config: const DominoConfig(),
          scores: scores,
        ),
        DominoMove.play(d(6, 1), DominoEnd.left),
      );
      final short = out([90, 50]);
      expect(short.scores, [97, 50]);
      expect(short.isOver, isFalse);
      final won = out([95, 50]);
      expect(won.result, const GameResult(winners: [0], reason: GameEndReason.targetScoreReached, scores: [102, 50]));
    });

    test('D-26: target 0 plays a single round', () {
      final s = rules.apply(
        dom([
          [d(6, 1)],
          [d(3, 4)],
        ], line: chain([(6, 6)])),
        DominoMove.play(d(6, 1), DominoEnd.left),
      );
      expect(s.isOver, isTrue);
      expect(s.result!.winners, [0]);
    });
  });

  group('«الخمسات» All Fives (option)', () {
    test('F-1: the end count – one tile is its pips; an end double counts both halves', () {
      expect(DominoState.endCountOf(const []), 0);
      expect(DominoState.endCountOf(chain([(5, 5)])), 10);
      expect(DominoState.endCountOf(chain([(6, 4)])), 10);
      expect(DominoState.endCountOf(chain([(3, 2)])), 5);
      expect(DominoState.endCountOf(chain([(5, 5), (5, 3)])), 13);
      expect(DominoState.endCountOf(chain([(3, 5), (5, 5)])), 13);
      expect(DominoState.endCountOf(chain([(5, 6), (6, 1), (1, 0)])), 5);
      expect(DominoState.endCountOf(chain([(6, 6), (6, 4), (4, 4)])), 20);
    });

    test('F-2: a play making a multiple of five scores it at once for the mover\'s side', () {
      const cfg = DominoConfig.allFives(players: 2);
      var s = dom(
        [
          [d(0, 5), d(1, 1)],
          [d(0, 3), d(2, 2)],
        ],
        line: chain([(5, 5)]),
        config: cfg,
      );
      s = rules.apply(s, DominoMove.play(d(0, 5), DominoEnd.right)); // 10 + 0
      expect(s.scores, [10, 0]);
      expect(s.roundEndPoints, [10, 0]);
      s = rules.apply(s, DominoMove.play(d(0, 3), DominoEnd.right)); // 10 + 3
      expect(s.scores, [10, 0]);
      expect(DominoState.fromJson(roundTrip(s.toJson())).roundEndPoints, [10, 0]);
    });

    test('F-3, F-4: going out adds round5(opponents\' pips) after the end count', () {
      final s = rules.apply(
        dom(
          [
            [d(0, 5)],
            [d(6, 6), d(1, 1)],
          ],
          line: chain([(5, 5)]),
          config: const DominoConfig.allFives(players: 2),
        ),
        DominoMove.play(d(0, 5), DominoEnd.right),
      );
      expect(s.lastRound!.end, DominoRoundEnd.domino);
      expect(s.lastRound!.endPoints, [10, 0]);
      expect(s.lastRound!.points, 15);
      expect(s.scores, [25, 0]);
    });

    test('F-5: a blocked round adds round5 of the opponents\' pips to the lowest side', () {
      var s = dom(
        [
          [d(0, 1)], // 1
          [d(6, 6), d(1, 2)], // 15 → 15
        ],
        line: chain([(4, 4)]),
        boneyard: const [],
        config: const DominoConfig.allFives(players: 2),
      );
      s = rules.apply(rules.apply(s, DominoMove.pass), DominoMove.pass);
      expect(s.lastRound!.winner, 0);
      expect(s.lastRound!.points, 15);
      final odd = rules.apply(
        rules.apply(
          dom(
            [
              [d(0, 1)],
              [d(6, 6), d(0, 2)], // 14 → 15
            ],
            line: chain([(4, 4)]),
            boneyard: const [],
            config: const DominoConfig.allFives(players: 2),
          ),
          DominoMove.pass,
        ),
        DominoMove.pass,
      );
      expect(odd.lastRound!.points, 15);
    });

    test('E-11 (fives): an end count reaching the target ends the match at once, before any bonus', () {
      final s = rules.apply(
        dom(
          [
            [d(0, 5)],
            [d(6, 6), d(1, 1)],
          ],
          line: chain([(5, 5)]),
          config: const DominoConfig.allFives(players: 2),
          scores: [145, 60],
        ),
        DominoMove.play(d(0, 5), DominoEnd.right),
      );
      expect(s.isOver, isTrue);
      expect(s.scores, [155, 60], reason: 'no going-out bonus after the match is won');
      expect(s.lastRound!.end, DominoRoundEnd.targetReached);
      expect(s.result, const GameResult(winners: [0], reason: GameEndReason.targetScoreReached, scores: [155, 60]));
      expect(rules.legalMoves(s), isEmpty);
    });

    test('F-2 with partners: the end count goes to the mover\'s team', () {
      final s = rules.apply(
        dom(
          [
            [d(1, 1)],
            [d(2, 2)],
            [d(0, 5), d(3, 3)],
            [d(4, 4)],
          ],
          line: chain([(5, 5)]),
          player: 2,
          config: const DominoConfig.allFives(players: 4),
        ),
        DominoMove.play(d(0, 5), DominoEnd.left),
      );
      expect(s.scores, [10, 0]);
    });

    test('single-round All Fives: the side with more points wins', () {
      final s = rules.apply(
        dom(
          [
            [d(0, 5)],
            [d(0, 0), d(1, 1)],
          ],
          line: chain([(5, 5)]),
          config: const DominoConfig.allFives(players: 2, targetScore: 0),
          scores: [0, 40],
        ),
        DominoMove.play(d(0, 5), DominoEnd.right),
      );
      expect(s.scores, [10, 40], reason: '10 from the end count, round5(2) = 0 from the hand');
      expect(s.result!.winners, [1]);
    });
  });

  group('whole matches', () {
    const variants = <String, DominoConfig>{
      'jordan ×2': DominoConfig.jordan(players: 2),
      'jordan ×3': DominoConfig.jordan(players: 3),
      'jordan ×4 partners': DominoConfig.jordan(players: 4),
      'fives ×2': DominoConfig.allFives(players: 2),
      'fives ×4 partners': DominoConfig.allFives(players: 4),
      'block ×2': DominoConfig.block(players: 2),
      'played-out lock ×3': DominoConfig.playOutLock(players: 3),
      'reserve, reshuffle, locker loses, difference': DominoConfig(
        stockReserve: 2,
        noDoubleOpening: DominoNoDoubleOpening.reshuffle,
        blockedTie: DominoBlockedTie.lockerLoses,
        blockedScoring: DominoBlockedScoring.difference,
        rounding: DominoRounding.nearestFive,
      ),
      'gulf deal ×4 alone, lowest player': DominoConfig(
        players: 4,
        teams: false,
        handSize: 5,
        blockedCompare: DominoBlockedCompare.lowestPlayer,
      ),
      'partners, lowest player, difference': DominoConfig(
        players: 4,
        blockedCompare: DominoBlockedCompare.lowestPlayer,
        blockedScoring: DominoBlockedScoring.difference,
      ),
    };

    test('E-17, D-24: seeded random matches end; scores never fall; JSON and replay round-trip', () {
      variants.forEach((name, cfg) {
        for (var seed = 0; seed < 4; seed++) {
          final e = BoardGameEngine<DominoState, DominoMove>(rules, DominoState.initial(seed: seed, config: cfg));
          final rng = BoardRng(seed * 31 + 7);
          var prev = e.state.scores;
          var rounds = 0;
          while (!e.isOver) {
            final s = e.state;
            checkInvariants(s);
            final pips = s.hands.fold<int>(0, (a, h) => a + h.fold<int>(0, (b, t) => b + t.pips));
            expect(
              pips + s.boneyard.fold<int>(0, (a, t) => a + t.pips) + s.line.fold<int>(0, (a, p) => a + p.tile.pips),
              168,
            );
            e.apply(rng.pick(e.legalMoves()));
            final now = e.state.scores;
            for (var i = 0; i < now.length; i++) {
              expect(now[i], greaterThanOrEqualTo(prev[i]), reason: name);
            }
            if (cfg.scoring == DominoScoring.count) {
              var changed = 0;
              for (var i = 0; i < now.length; i++) {
                if (now[i] != prev[i]) changed++;
              }
              expect(changed, lessThanOrEqualTo(1), reason: 'only one side scores per round');
            }
            if (e.state.phase == DominoPhase.roundOver) rounds++;
            prev = now;
            expect(e.history.length, lessThan(5000), reason: '$name seed $seed does not end');
          }
          expect(rounds, greaterThanOrEqualTo(1));
          expect(e.result!.reason, GameEndReason.targetScoreReached);
          final w = e.result!.winners.first;
          expect(e.state.scores[cfg.sideOf(w)], greaterThanOrEqualTo(cfg.targetScore), reason: name);
          final restored = BoardGameEngine<DominoState, DominoMove>.fromJson(rules, roundTrip(e.toJson()));
          expect(canonical(restored.state), canonical(e.state), reason: name);
          expect(canonical(DominoState.fromJson(roundTrip(e.state.toJson()))), canonical(e.state));
        }
      });
    });

    test('state JSON round-trip keeps the last mover, end points and the round summary', () {
      final s =
          dom(
            [
              [d(1, 1)],
              [d(2, 2)],
            ],
            line: chain([(5, 5), (5, 0)]),
            config: const DominoConfig.allFives(players: 2),
            lastMover: 1,
          ).copyWith(
            roundEndPoints: [0, 10],
            lastRound: const DominoRoundSummary(
              round: 1,
              end: DominoRoundEnd.blocked,
              winner: 0,
              points: 20,
              handPips: [3, 23],
              endPoints: [5, 15],
              stockLeft: 9,
              locked: true,
            ),
          );
      final back = DominoState.fromJson(roundTrip(s.toJson()));
      expect(canonical(back), canonical(s));
      expect(back.lastMover, 1);
      expect(back.roundEndPoints, [0, 10]);
      expect(back.lastRound!.locked, isTrue);
      expect(back.lastRound!.stockLeft, 9);
      expect(back.lastRound!.endPoints, [5, 15]);
    });

    test('D-C1 probe: a locked round ends as soon as the line locks in a real game', () {
      // Find a seeded game in which the line locks with tiles in the stock.
      var found = false;
      for (var seed = 0; seed < 300 && !found; seed++) {
        var s = DominoState.initial(seed: seed, config: const DominoConfig(targetScore: 0));
        final rng = BoardRng(seed);
        while (s.phase == DominoPhase.playing) {
          s = rules.apply(s, rng.pick(rules.legalMoves(s)));
        }
        if (s.lastRound!.locked && s.boneyard.isNotEmpty) {
          found = true;
          expect(s.lastRound!.end, DominoRoundEnd.blocked);
          expect(s.lineLocked, isTrue);
          expect(s.lastRound!.stockLeft, s.boneyard.length);
        }
      }
      expect(found, isTrue);
    });
  });

  test('playOut helper sanity: a hand-built round always finishes', () {
    final s = playOut(DominoState.initial(seed: 5, config: const DominoConfig(targetScore: 0)));
    expect(s.phase, DominoPhase.roundOver);
  });
}
