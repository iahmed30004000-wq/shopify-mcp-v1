// What is in the house, and «شو قلّ أو خلص» – the view she opens first.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_fixtures.dart';

void main() {
  group('low and finished', () {
    test('a typed zero is finished, not low', () {
      final s = PantryStock.of(item('زيت', quantity: 0, unit: 'لتر'), today: today);
      expect(s.state, PantryState.out);
      expect(s.isOut, isTrue);
      expect(s.isLow, isFalse);
      expect(s.shouldBuy, isTrue);
    });

    test('at her threshold it is already low, and below it too', () {
      expect(PantryStock.of(item('رز', quantity: 1, unit: 'كيلو', lowAt: 1), today: today).state, PantryState.low);
      expect(PantryStock.of(item('رز', quantity: 0.8, unit: 'كيلو', lowAt: 1), today: today).state, PantryState.low);
      expect(PantryStock.of(item('رز', quantity: 1.1, unit: 'كيلو', lowAt: 1), today: today).state, PantryState.ok);
    });

    test('she can mark it low with no quantity at all', () {
      final s = PantryStock.of(item('زيت', low: true), today: today);
      expect(s.isLow, isTrue);
      expect(s.shouldBuy, isTrue);
      expect(s.item.amountUnknown, isTrue);
    });

    test('a threshold alone never fires without an amount she typed', () {
      expect(PantryStock.of(item('رز', lowAt: 1), today: today).state, PantryState.ok);
    });
  });

  group('expiry', () {
    test('inside the warning window it warns, outside it does not', () {
      final soon = PantryStock.of(item('لبن', expires: today.add(const Duration(days: 2))), today: today);
      expect(soon.state, PantryState.expiringSoon);
      expect(soon.daysToExpiry, 2);
      final later = PantryStock.of(item('لبن', expires: today.add(const Duration(days: 9))), today: today);
      expect(later.state, PantryState.ok);
    });

    test('the window boundary warns, one day past it does not', () {
      expect(
        PantryStock.of(item('لبن', expires: today.add(const Duration(days: 3))), today: today, warningDays: 3).state,
        PantryState.expiringSoon,
      );
      expect(
        PantryStock.of(item('لبن', expires: today.add(const Duration(days: 4))), today: today, warningDays: 3).state,
        PantryState.ok,
      );
    });

    test('today is the last day, and yesterday has passed', () {
      expect(PantryStock.of(item('لبن', expires: today), today: today).state, PantryState.expiringSoon);
      final gone = PantryStock.of(item('لبن', expires: today.subtract(const Duration(days: 1))), today: today);
      expect(gone.state, PantryState.expired);
      expect(gone.expired, isTrue);
      expect(gone.daysToExpiry, -1);
    });

    test('an expired thing is to throw out, not to buy – unless she keeps it always', () {
      final plain = PantryStock.of(item('لبن', expires: today.subtract(const Duration(days: 2))), today: today);
      expect(plain.shouldBuy, isFalse);
      final staple = PantryStock.of(
        item('لبن', expires: today.subtract(const Duration(days: 2)), staple: true),
        today: today,
      );
      expect(staple.shouldBuy, isTrue);
    });

    test('low and nearly off at once still reads as low', () {
      final s = PantryStock.of(
        item('لبن', quantity: 0.2, unit: 'لتر', lowAt: 0.5, expires: today.add(const Duration(days: 1))),
        today: today,
      );
      expect(s.state, PantryState.low);
      expect(s.isLow, isTrue);
      expect(s.daysToExpiry, 1);
    });
  });

  group('the board', () {
    test('the attention list is worst first and keeps her order inside a group', () {
      final b = board([
        item('بندورة', quantity: 3, unit: 'حبة'),
        item('لبن', expires: today.subtract(const Duration(days: 1))),
        item('رز', quantity: 0.5, unit: 'كيلو', lowAt: 1),
        item('زيت', quantity: 0),
        item('سكر', quantity: 0.5, unit: 'كيلو', lowAt: 1),
      ]);
      expect([for (final s in b.attention) s.item.name], ['زيت', 'لبن', 'رز', 'سكر']);
      expect([for (final s in b.toBuy) s.item.name], ['زيت', 'رز', 'سكر']);
    });

    test('an archived thing is kept but never resolves an ingredient', () {
      final b = board([item('رز', quantity: 2, unit: 'كيلو', archived: true)]);
      expect(b.stocks, hasLength(1));
      expect(b.live, isEmpty);
      expect(b.isEmpty, isTrue);
      expect(b.exact('رز'), isNull);
    });

    test('her aliases find the same thing', () {
      final b = board([item('بندورة', quantity: 3, unit: 'حبة', aliases: ['طماطم'])]);
      expect(b.exact('بندورة')!.item.name, 'بندورة');
      expect(b.exact('طماطم')!.item.name, 'بندورة');
      expect(b.exact('بندوره')!.item.name, 'بندورة');
    });

    test('her places group what is in them, and the unplaced land together', () {
      final b = board([
        item('رز', place: 'خزانة المونة'),
        item('لبن', place: 'الفريزر'),
        item('زيت'),
        item('سكر', place: 'خزانة المونة'),
      ]);
      expect(b.byPlace['خزانة المونة'], hasLength(2));
      expect(b.byPlace['الفريزر'], hasLength(1));
      expect(b.byPlace[PantryBoard.noPlace], hasLength(1));
    });

    test('a loose candidate is found by containment, both ways', () {
      final b = board([item('رز بسمتي', quantity: 2, unit: 'كيلو')]);
      expect(b.exact('رز'), isNull);
      expect([for (final s in b.contains('رز')) s.item.name], ['رز بسمتي']);
    });
  });
}
