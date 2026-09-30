// TEMPORARY probe (reviewer): AI level ordering and match length per preset.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_state.dart';

import 'support.dart';

Kit tk(String n, TarneebOptions o) =>
    Kit(n, (s) => TarneebEngine.newMatch(seed: s, options: o), TarneebEngine.fromJson, const TarneebAi());
Kit fk(String n, FortyOneOptions o) =>
    Kit(n, (s) => FortyOneEngine.newMatch(seed: s, options: o), FortyOneEngine.fromJson, const FortyOneAi());

void duel(Kit k, AiLevel strong, AiLevel weak, int n, {int base = 900, int sims = 24}) {
  var wins = 0;
  var edge = 0;
  for (var m = 0; m < n; m++) {
    final t = m % 2;
    final levels = [for (var s = 0; s < 4; s++) s % 2 == t ? strong : weak];
    final r = playMatch(k, base + m, levels, budget: AiBudget.simulations(sims));
    if (r.winners.contains(t)) wins++;
    edge += r.scores[t] + r.scores[t + 2] - r.scores[1 - t] - r.scores[3 - t];
  }
  // ignore: avoid_print
  print('${k.name}: ${strong.name}@$sims vs ${weak.name}: won $wins/$n, edge ${(edge / n).toStringAsFixed(1)}');
}

void main() {
  test('hard vs medium at 150', () {
    final w = Stopwatch()..start();
    duel(tk('t jordan', const TarneebOptions()), AiLevel.hard, AiLevel.medium, 8, base: 1300, sims: 150);
    print('t ${w.elapsed}');
    duel(fk('41', const FortyOneOptions()), AiLevel.hard, AiLevel.medium, 8, base: 1300, sims: 150);
    print('41 ${w.elapsed}');
  }, timeout: const Timeout(Duration(minutes: 15)));
  test('length per preset (all easy / all medium)', () {
    for (final k in [
      tk('t jordan', const TarneebOptions()),
      tk('t syrian', const TarneebOptions.syrianTrump()),
      tk('t lebanese', const TarneebOptions.lebaneseAuction()),
      tk('t open', const TarneebOptions.openAuction()),
      fk('41', const FortyOneOptions()),
      fk('400', const FortyOneOptions.lebanese400()),
      fk('syrian41', const FortyOneOptions.syrian()),
    ]) {
      for (final lv in [AiLevel.easy, AiLevel.medium]) {
        final deals = <int>[];
        for (var seed = 0; seed < 20; seed++) {
          final r = playMatch(k, 3000 + seed, List.filled(4, lv));
          deals.add(r.moves);
        }
        deals.sort();
        // ignore: avoid_print
        print('${k.name} ${lv.name}: moves median ${deals[10]} max ${deals.last}');
      }
    }
  });
  test('ordering', () {
    duel(tk('t jordan', const TarneebOptions()), AiLevel.medium, AiLevel.easy, 16);
    duel(fk('41', const FortyOneOptions()), AiLevel.medium, AiLevel.easy, 16);
    duel(fk('400', const FortyOneOptions.lebanese400()), AiLevel.medium, AiLevel.easy, 16);
    duel(tk('t jordan', const TarneebOptions()), AiLevel.hard, AiLevel.medium, 10);
    duel(fk('41', const FortyOneOptions()), AiLevel.hard, AiLevel.medium, 10);
  });
}
