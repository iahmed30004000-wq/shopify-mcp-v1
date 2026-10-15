// The one rule that matters: convert where it is certain, refuse where it
// is not. A wrong conversion would tell her she can cook a dish she
// cannot, so "unknown" has to be a first-class answer.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/sufra/sufra.dart';

void main() {
  group('folding her words', () {
    test('every spelling of a kilo is one unit', () {
      for (final w in ['كيلو', 'كغم', 'كغ', 'كجم', 'kg', 'KG', 'kilo', 'كيلوغرام']) {
        expect(KitchenUnits.normalize(w).family, UnitFamily.mass, reason: w);
        expect(KitchenUnits.normalize(w).inBase, 1000, reason: w);
      }
    });

    test('grams, litres and millilitres fold too', () {
      expect(KitchenUnits.normalize('غرام').inBase, 1);
      expect(KitchenUnits.normalize('جرام').family, UnitFamily.mass);
      expect(KitchenUnits.normalize('g').inBase, 1);
      expect(KitchenUnits.normalize('لتر').family, UnitFamily.volume);
      expect(KitchenUnits.normalize('ليتر').inBase, 1000);
      expect(KitchenUnits.normalize('مل').inBase, 1);
      expect(KitchenUnits.normalize('ml').family, UnitFamily.volume);
    });

    test('ta marbuta, harakat and tatweel do not make a new unit', () {
      expect(KitchenUnits.normalize('حبة'), KitchenUnits.normalize('حبه'));
      expect(KitchenUnits.normalize('ملعقة'), KitchenUnits.normalize('مَلعقـة'));
      expect(KitchenUnits.normalize('حبة').family, UnitFamily.count);
    });

    test('a cup and a spoon are household measures, not volumes', () {
      expect(KitchenUnits.normalize('كوب').family, UnitFamily.household);
      expect(KitchenUnits.normalize('cup').family, UnitFamily.household);
      expect(KitchenUnits.normalize('ملعقة').family, UnitFamily.household);
      expect(KitchenUnits.normalize('كوب').convertible, isFalse);
    });

    test('a word Madar does not know stays hers', () {
      final unit = KitchenUnits.normalize('شنينة');
      expect(unit.family, UnitFamily.other);
      expect(unit.canonical, 'شنينه');
      expect(unit.convertible, isFalse);
    });

    test('no unit at all is its own thing', () {
      expect(KitchenUnits.normalize(null), KitchenUnit.none);
      expect(KitchenUnits.normalize('   '), KitchenUnit.none);
      expect(KitchenUnit.none.isNone, isTrue);
    });
  });

  group('converting', () {
    test('kilo ↔ gram and litre ↔ millilitre, exactly', () {
      expect(KitchenUnits.convert(2, KitchenUnits.normalize('كيلو'), KitchenUnits.normalize('غرام')), 2000);
      expect(KitchenUnits.convert(500, KitchenUnits.normalize('غم'), KitchenUnits.normalize('كغم')), 0.5);
      expect(KitchenUnits.convert(1.5, KitchenUnits.normalize('لتر'), KitchenUnits.normalize('مل')), 1500);
      expect(KitchenUnits.convert(250, KitchenUnits.normalize('ml'), KitchenUnits.normalize('l')), 0.25);
    });

    test('the same word needs no conversion', () {
      expect(KitchenUnits.convert(3, KitchenUnits.normalize('حبة'), KitchenUnits.normalize('حبه')), 3);
      expect(KitchenUnits.convert(2, KitchenUnits.normalize('كوب'), KitchenUnits.normalize('cup')), 2);
    });

    test('a cup into grams is null – never a guess', () {
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('كوب'), KitchenUnits.normalize('غرام')), isNull);
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('كوب'), KitchenUnits.normalize('مل')), isNull);
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('ملعقة'), KitchenUnits.normalize('غم')), isNull);
    });

    test('a mass is never a volume, and a tin is never either', () {
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('كيلو'), KitchenUnits.normalize('لتر')), isNull);
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('علبة'), KitchenUnits.normalize('مل')), isNull);
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('حبة'), KitchenUnits.normalize('علبة')), isNull);
    });

    test('one of her own words never converts into another', () {
      expect(KitchenUnits.convert(1, KitchenUnits.normalize('شنينة'), KitchenUnits.normalize('كوب')), isNull);
    });
  });

  group('comparing what is there against what is needed', () {
    test('same unit: the numbers as they are', () {
      final c = KitchenUnits.compare(have: 3, haveUnit: 'كيلو', need: 2, needUnit: 'كيلو');
      expect(c.match, UnitMatch.same);
      expect(c.enough, isTrue);
      expect(c.short, 0);
    });

    test('converted: both numbers come back in the unit the dish asked for', () {
      final c = KitchenUnits.compare(have: 1.2, haveUnit: 'كيلو', need: 300, needUnit: 'غرام');
      expect(c.match, UnitMatch.converted);
      expect(c.unit.canonical, KitchenUnits.normalize('غرام').canonical);
      expect(c.have, 1200);
      expect(c.need, 300);
      expect(c.enough, isTrue);
    });

    test('short: the gap is in the needed unit', () {
      final c = KitchenUnits.compare(have: 200, haveUnit: 'غرام', need: 0.5, needUnit: 'كيلو');
      expect(c.match, UnitMatch.converted);
      expect(c.enough, isFalse);
      expect(c.short, 0.3);
    });

    test('a unit it will not convert: unknown, and NO number to read off it', () {
      final c = KitchenUnits.compare(have: 2, haveUnit: 'كيلو', need: 1, needUnit: 'كوب');
      expect(c.match, UnitMatch.unknown);
      expect(c.isKnown, isFalse);
      expect(c.short, isNull);
      expect(c.enough, isFalse);
    });

    test('rounding never lies about "just enough"', () {
      final c = KitchenUnits.compare(have: 0.9, haveUnit: 'كيلو', need: 900, needUnit: 'غم');
      expect(c.enough, isTrue);
      expect(c.short, 0);
    });
  });
}
