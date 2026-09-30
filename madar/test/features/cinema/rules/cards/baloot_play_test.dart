// Baloot self-play for the Jordanian rules and every option: all AI levels,
// legal moves only, card conservation, JSON save / resume (including saves
// made before the Jordanian defaults), deterministic replay, no peeking at
// hidden cards, and the hard AI beating the easy one.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

Kit balootKit(String name, BalootOptions o) => Kit(
  name,
  (seed) => BalootEngine.newMatch(seed: seed, options: o),
  BalootEngine.fromJson,
  const BalootAi(),
);

final variants = <String, BalootOptions>{
  'jordan': const BalootOptions(),
  'legacy relaxed': const BalootOptions(
    mustTrumpWhenPartnerWinning: false,
    mustOvertrump: false,
    sunDoubleOnlyWhenBehind: false,
  ),
  'every option on': const BalootOptions(
    kawesh: true,
    aceThirdRound: true,
    ashkalInRound2: true,
    ashkalOnAce: true,
    firstLead: BalootFirstLead.taker,
    declareProjects: BalootDeclareProjects.manual,
    sequenceBeatsCarre: true,
    trumpSequencePriority: true,
    beloteOnLoss: BalootBeloteOnLoss.keptByHolder,
    projectMultiplierCap: null,
    partnerWinningVoid: BalootPartnerWinningVoid.alwaysTrump,
    trumpLedOvertrump: BalootTrumpLedOvertrump.always,
    sunDoubleRule: BalootSunDoubleRule.always,
  ),
  'no priority, no switch, no ashkal': const BalootOptions(
    sunPriority: false,
    takerMaySwitchToSun: false,
    ashkal: false,
    beloteOnLoss: BalootBeloteOnLoss.voided,
    sunDoubleRule: BalootSunDoubleRule.oneOver100OneUnder,
  ),
  'free voids, no doubling': const BalootOptions(
    voidMustTrump: false,
    partnerWinningVoid: BalootPartnerWinningVoid.free,
    doubling: false,
  ),
};

BalootOptions shortMatch(BalootOptions o, int target) => BalootOptions.fromJson({
  ...o.toJson(),
  'targetScore': target,
});

void main() {
  group('self-play, every variant', () {
    for (final v in variants.entries) {
      final k = balootKit(v.key, v.value);
      test('${v.key}: easy and medium, whole matches, JSON every 11 moves', () {
        for (var seed = 1; seed <= 3; seed++) {
          for (final level in [AiLevel.easy, AiLevel.medium]) {
            final r = playMatch(k, seed, List.filled(4, level), jsonEvery: seed == 1 ? 11 : 0);
            // Partners win together; without a gahwa the winners lead at 152+.
            expect(r.winners.length, 2);
            expect(r.winners[1] - r.winners[0], 2);
            final state = BalootState.fromJson(jsonDecode(r.finalJson) as Map<String, Object?>);
            if (state.results.last.level != 5) {
              expect(r.scores[r.winners[0]], greaterThanOrEqualTo(v.value.targetScore));
              expect(r.scores[r.winners[0]], greaterThan(r.scores[1 - r.winners[0] % 2]));
            }
          }
        }
      });
    }

    for (final v in variants.entries) {
      final k = balootKit(v.key, shortMatch(v.value, 60));
      test('${v.key}: hard (tiny budget) and a mixed table', () {
        playMatch(k, 1, List.filled(4, AiLevel.hard), budget: const AiBudget.simulations(8), jsonEvery: 13);
        playMatch(k, 2, [
          AiLevel.hard,
          AiLevel.easy,
          AiLevel.medium,
          AiLevel.easy,
        ], budget: const AiBudget.simulations(8));
      });
    }

    test('the AI uses the new moves: Sun priority, confirm, declarations', () {
      final seen = <String>{};
      for (final v in [variants['jordan']!, variants['every option on']!]) {
        final k = balootKit('moves', v);
        for (var seed = 1; seed <= 6; seed++) {
          playMatch(
            k,
            seed,
            List.filled(4, AiLevel.medium),
            onMove: (engine, move) {
              final m = move as BalootMove;
              final s = engine.state as BalootState;
              seen.add(m.kind.name);
              if (s.phase == BalootPhase.bidding && s.bidStage == BalootBidStage.priority) seen.add('priority');
              if (m.kind == BalootMoveKind.raise && m.locked) seen.add('locked');
            },
          );
        }
      }
      expect(seen, containsAll(['pass', 'hokom', 'sun', 'confirm', 'play', 'priority', 'declareProjects']));
    });
  });

  test('deterministic replay: same seed and levels → same match; the move log replays it', () {
    final k = balootKit('replay', const BalootOptions(targetScore: 80));
    const levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard];
    const budget = AiBudget.simulations(6);
    final a = playMatch(k, 42, levels, budget: budget);
    final b = playMatch(k, 42, levels, budget: budget);
    expect(b.finalJson, a.finalJson);
    final replay = k.create(42);
    for (final mj in a.moveLog) {
      replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
    }
    expect(jsonEncode(replay.toJson()), a.finalJson);
  });

  group('serialisation', () {
    Map<String, Object?> roundTrip(BalootEngine e) {
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      final back = BalootEngine.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(json));
      return json;
    }

    BalootEngine dealt([BalootOptions o = const BalootOptions()]) => BalootEngine(
      BalootState.withDeal(
        hands: [c('JS 9S AS 7H 8H'), c('TS KS QS 9H TH'), c('8S 7S JH QH KH'), c('AH 7D 8D JD QD')],
        upCard: p('9D'),
        stock: c('KD TD AD 7C 8C 9C TC JC QC KC AC'),
        options: o,
      ),
    );

    test('mid-auction (priority and confirmation), doubling (locked) and manual declarations survive JSON', () {
      final e = dealt();
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.pass());
      e.apply(const BalootMove.ashkal());
      var back = BalootEngine.fromJson(roundTrip(e));
      expect(back.state.bidStage, BalootBidStage.priority);
      expect(back.state.ashkal, isTrue);
      expect(back.state.bidder, 2);
      expect(back.legalMoves(0), const [BalootMove.pass(), BalootMove.sun()]);

      final f = dealt(const BalootOptions(declareProjects: BalootDeclareProjects.manual));
      f.apply(const BalootMove.hokom(Suit.diamonds));
      for (var i = 0; i < 3; i++) {
        f.apply(const BalootMove.pass());
      }
      back = BalootEngine.fromJson(roundTrip(f));
      expect(back.state.bidStage, BalootBidStage.confirm);
      f.apply(const BalootMove.confirm());
      f.apply(const BalootMove.raise(locked: true));
      back = BalootEngine.fromJson(roundTrip(f));
      expect(back.state.locked, isTrue);
      expect(back.state.level, 2);
      f.apply(const BalootMove.pass());
      back = BalootEngine.fromJson(roundTrip(f));
      expect(back.state.projectsDecided, f.state.projectsDecided);
      expect(back.legalMoves(back.currentPlayer!), f.legalMoves(f.currentPlayer!));
    });

    test('moves round-trip, including a locked raise', () {
      for (final m in [
        const BalootMove.raise(locked: true),
        const BalootMove.raise(),
        const BalootMove.ashkal(),
        const BalootMove.confirm(),
        const BalootMove.kawesh(),
        const BalootMove.declareProjects(),
        const BalootMove.skipProjects(),
        const BalootMove.hokom(Suit.clubs),
        BalootMove.play(p('JS')),
      ]) {
        expect(BalootMove.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>), m);
      }
      expect(const BalootMove.raise(locked: true), isNot(const BalootMove.raise()));
    });

    test('options round-trip; the default is the Jordanian preset', () {
      expect(const BalootOptions(), const BalootOptions.jordan());
      for (final o in variants.values) {
        expect(BalootOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>), o);
      }
      const d = BalootOptions();
      expect(d.firstLead, BalootFirstLead.dealerRight);
      expect(d.sunPriority, isTrue);
      expect(d.ashkal, isTrue);
      expect(d.ashkalOnAce, isFalse);
      expect(d.ashkalInRound2, isFalse);
      expect(d.takerMaySwitchToSun, isTrue);
      expect(d.kawesh, isFalse);
      expect(d.aceThirdRound, isFalse);
      expect(d.sunDoubleRule, BalootSunDoubleRule.takersOver100DoublersUnder100);
      expect(d.voidMustTrump, isTrue);
      expect(d.trumpLedOvertrump, BalootTrumpLedOvertrump.againstOpponent);
      expect(d.partnerWinningVoid, BalootPartnerWinningVoid.saudi);
      expect(d.declareProjects, BalootDeclareProjects.auto);
      expect(d.beloteOnLoss, BalootBeloteOnLoss.toWinner);
      expect(d.projectMultiplierCap, 2);
      expect(d.targetScore, 152);
    });

    test('a save made before the Jordanian defaults still loads (legacy keys mapped)', () {
      final e = BalootEngine.newMatch(seed: 9);
      final rng = CardRng(3);
      for (var i = 0; i < 30; i++) {
        e.apply(const BalootAi().chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
      }
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      json['options'] = {
        'targetScore': 152,
        'doubling': true,
        'sunDoubleOnlyWhenBehind': false,
        'mustTrumpWhenPartnerWinning': true,
        'mustOvertrump': true,
        'buyerWinsTies': false,
        'firstDealer': 3,
      };
      for (final key in ['bidStage', 'bidder', 'ashkal', 'locked', 'projectsDecided']) {
        json.remove(key);
      }
      final results = json['results']! as List;
      for (final r in results.cast<Map<String, Object?>>()) {
        r.removeWhere((k, _) => !['buyer', 'mode', 'trump', 'raw', 'points', 'level', 'made'].contains(k));
      }
      final back = BalootEngine.fromJson(json);
      expect(back.state.options.partnerWinningVoid, BalootPartnerWinningVoid.alwaysTrump);
      expect(back.state.options.sunDoubleRule, BalootSunDoubleRule.always);
      expect(back.state.options.sunPriority, isTrue);
      expect(back.state.bidder, back.state.buyer);
      expect(back.state.projectsDecided, [false, false, false, false]);
      for (final r in back.state.results) {
        expect(r.winner, r.made ? r.buyer % 2 : 1 - r.buyer % 2);
      }
      // And it plays on to the end.
      final rng2 = CardRng(4);
      while (!back.isOver) {
        back.apply(const BalootAi().chooseMove(back.state, back.currentPlayer!, AiLevel.easy, rng2, AiBudget.phone));
      }
      expect(back.state.winners, isNotEmpty);
    });
  });

  group('the AI never peeks', () {
    for (final v in {
      'jordan': variants['jordan']!,
      'every option on': variants['every option on']!,
    }.entries) {
      test('${v.key}: decisions depend only on what the seat can see', () {
        const ai = BalootAi();
        final e = BalootEngine.newMatch(seed: 5, options: v.value);
        final rng = CardRng(1);
        var checked = 0;
        for (var move = 0; move < 300 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          if (move % 7 == 3) {
            final real = e.state;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(other.hands[seat], real.hands[seat]);
            expect(sortedCards(other.cardsInPlay()), sortedCards(real.cardsInPlay()));
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
              expect(b, a, reason: '${v.key} move $move ${level.name}');
            }
            checked++;
          }
          e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(10));
      });
    }

    test('the belote holder is re-sampled with the hidden hands until it is announced', () {
      const ai = BalootAi();
      for (var seed = 1; seed < 40; seed++) {
        final e = BalootEngine.newMatch(seed: seed);
        final rng = CardRng(seed);
        while (e.state.phase != BalootPhase.playing && !e.isOver) {
          e.apply(ai.chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
        }
        if (e.state.mode != BalootMode.hokom || e.state.belote < 0) continue;
        final holder = e.state.belote;
        final observer = (holder + 1) % 4;
        var moved = false;
        for (var i = 0; i < 20; i++) {
          final w = ai.determinize(e.state, observer, CardRng(i));
          expect(w.belote, BalootRules.beloteHolder(w));
          if (w.belote != holder) moved = true;
        }
        expect(moved, isTrue, reason: 'seed $seed');
        return;
      }
      fail('no Hokom deal with a belote found');
    });
  });

  group('the hard AI beats the easy AI', () {
    const matches = 10;
    for (final v in {
      'jordan': const BalootOptions(),
      'manual declarations, kawesh, ace round': const BalootOptions(
        declareProjects: BalootDeclareProjects.manual,
        kawesh: true,
        aceThirdRound: true,
      ),
    }.entries) {
      test(v.key, () {
        var wins = 0;
        var edge = 0.0;
        final k = balootKit(v.key, v.value);
        for (var m = 0; m < matches; m++) {
          final hardSeats = [m % 2, m % 2 + 2];
          final levels = [for (var s = 0; s < 4; s++) hardSeats.contains(s) ? AiLevel.hard : AiLevel.easy];
          final r = playMatch(k, 1000 + m, levels, budget: const AiBudget.simulations(24));
          edge += r.scores[hardSeats.first] - r.scores[1 - m % 2];
          if (r.winners.contains(hardSeats.first)) wins++;
        }
        // ignore: avoid_print
        print('baloot ${v.key}: hard won $wins/$matches, average edge ${(edge / matches).toStringAsFixed(1)}');
        expect(edge / matches, greaterThan(10));
        expect(wins, greaterThan(matches / 2));
      });
    }
  });
}
