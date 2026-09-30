// TEMPORARY probe (review), deleted after the review.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

void main() {
  test('probe: detectProjects honours sequenceBeatsCarre', () {
    // Four queens or the ♠ 10-J-Q-K-A: both a hundred, they share the Q♠.
    final hand = c('QS QH QD QC TS JS KS AS');
    final def = BalootRules.detectProjects(hand, 0, BalootMode.hokom);
    // ignore: avoid_print
    print('default: ${def.map((x) => '${x.type.name} ${x.cards}')}');
  });

  test('probe: projectsDeclared event at play start carries the cards', () {
    final hs = [c('QS QH QD QC 7D'), c('7S 8S 9H TH JH'), c('8D 9D TD JD KD'), c('AH 7C 8C 9C TC')];
    final up = p('KH');
    final stock = cardsMinus(buildDeck(ranks: balootRanks), [for (final h in hs) ...h, up]);
    final e = BalootEngine(BalootState.withDeal(hands: hs, upCard: up, stock: stock));
    final evs = <CardEvent>[];
    evs.addAll(e.apply(const BalootMove.sun()));
    // ignore: avoid_print
    print('phase ${e.state.phase} turn ${e.currentPlayer}');
    while (e.state.phase != BalootPhase.playing) {
      evs.addAll(e.apply(const BalootMove.pass()));
    }
    for (final x in evs.where((x) => x.type == CardEventType.projectsDeclared)) {
      // ignore: avoid_print
      print('declared seat ${x.seat}: ${x.cards} tricks ${e.state.tricks.length}');
    }
  });

  test('probe: JSON + copy at every move, many options', () {
    final opts = [
      const BalootOptions(),
      const BalootOptions(
        kawesh: true,
        aceThirdRound: true,
        ashkalInRound2: true,
        declareProjects: BalootDeclareProjects.manual,
        firstLead: BalootFirstLead.taker,
      ),
    ];
    const ai = BalootAi();
    for (final o in opts) {
      for (var seed = 1; seed <= 4; seed++) {
        final e = BalootEngine.newMatch(seed: seed, options: BalootOptions.fromJson({...o.toJson(), 'targetScore': 60}));
        final rng = CardRng(seed);
        var n = 0;
        while (!e.isOver && n < 3000) {
          final j = jsonEncode(e.toJson());
          expect(jsonEncode(BalootState.fromJson(jsonDecode(j) as Map<String, Object?>).toJson()), j);
          expect(jsonEncode(e.state.copy().toJson()), j);
          final m = ai.chooseMove(e.state, e.currentPlayer!, AiLevel.easy, rng, AiBudget.phone);
          e.apply(m);
          n++;
        }
      }
    }
  });

  test('probe: medium vs easy (Baloot)', () {
    final k = Kit(
      'b',
      (seed) => BalootEngine.newMatch(seed: seed, options: const BalootOptions()),
      BalootEngine.fromJson,
      const BalootAi(),
    );
    var edge = 0.0;
    var wins = 0;
    for (var m = 0; m < 10; m++) {
      final med = m % 2;
      final levels = [for (var s = 0; s < 4; s++) s % 2 == med ? AiLevel.medium : AiLevel.easy];
      final r = playMatch(k, 500 + m, levels);
      edge += r.scores[med] - r.scores[1 - med];
      if (r.winners.contains(med)) wins++;
    }
    // ignore: avoid_print
    print('baloot medium vs easy: wins $wins/10 edge ${edge / 10}');
  });
}
