// Basra: problems found in the adversarial rules review, each proved by a
// test that failed before its fix (final spec §3, §6.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

void main() {
  group('R1 hand sizes: only 4, 5 or 6 cards a round (spec §3, §6.1)', () {
    test('sizes that are not Basra deals are refused, even when the pack divides', () {
      // All of these split the pack into whole rounds, and all were accepted
      // before the fix (one round of 12, a 24-card hand, 1–3 cards a round…).
      for (final o in [
        const BasraOptions(handSize: 12),
        const BasraOptions(handSize: 2),
        const BasraOptions(handSize: 3),
        const BasraOptions(handSize: 1),
        const BasraOptions(players: 2, handSize: 8),
        const BasraOptions(players: 2, handSize: 24),
        const BasraOptions(players: 3, handSize: 8),
        const BasraOptions(players: 2, deck: BasraDeck.short44, handSize: 10),
      ]) {
        expect(o.configError, 'handSize', reason: 'players ${o.players} hand ${o.handSize} ${o.deck.name}');
        expect(() => BasraState.newMatch(options: o, seed: 1), throwsArgumentError);
      }
    });

    test('the sizes of the spec stay allowed', () {
      for (final o in [
        const BasraOptions(),
        const BasraOptions(handSize: 4),
        const BasraOptions(handSize: 6),
        const BasraOptions(players: 2, handSize: 6),
        const BasraOptions(players: 3),
        const BasraOptions.palestinian44(),
        const BasraOptions(deck: BasraDeck.short44, sevenDiamonds: BasraSevenDiamonds.normal, handSize: 5),
        const BasraOptions.palestinian44(players: 2),
        const BasraOptions(players: 2, deck: BasraDeck.short44, handSize: 5),
      ]) {
        expect(o.configError, isNull, reason: 'players ${o.players} hand ${o.handSize} ${o.deck.name}');
      }
    });
  });

  group('R2 an explicit hand size equal to the automatic one is the same rule set', () {
    test('handSize 4 is the Jordanian preset; 5 with 44 cards is the Palestinian one', () {
      // Before the fix both were `custom` and unequal to the preset.
      expect(const BasraOptions(handSize: 4), const BasraOptions());
      expect(const BasraOptions(handSize: 4).hashCode, const BasraOptions().hashCode);
      expect(const BasraOptions(handSize: 4).preset, BasraPreset.jordan);
      expect(
        const BasraOptions(deck: BasraDeck.short44, sevenDiamonds: BasraSevenDiamonds.normal, handSize: 5).preset,
        BasraPreset.palestinian44,
      );
      expect(const BasraOptions(handSize: 6).preset, BasraPreset.custom);
      expect(const BasraOptions(handSize: 6), isNot(const BasraOptions()));
    });
  });
}
