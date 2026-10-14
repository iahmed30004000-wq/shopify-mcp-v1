// What is missing becomes a shopping list – with a number only when Madar
// really knows the number.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_fixtures.dart';

void main() {
  test('a near match becomes lines: the whole amount for a missing thing, the gap for a short one', () {
    final m = PantryMatcher.match(
      dish(
        'r1',
        'مقلوبة',
        ingredients: [
          ing('رز', quantity: 2, unit: 'كيلو'),
          ing('دجاج', quantity: 1, unit: 'فرخة'),
          ing('لوز', quantity: 50, unit: 'غرام', optional: true),
        ],
      ),
      pantry: board([item('رز', quantity: 1200, unit: 'غرام')]),
    );
    final lines = ShoppingLines.ofMatch(m);
    expect([for (final l in lines) l.title], ['رز', 'دجاج']);
    expect(lines.first.quantity, 0.8);
    expect(lines.first.unit, 'كيلو');
    expect(lines.last.quantity, 1);
    expect(lines.last.unit, 'فرخة');
  });

  test('an ingredient Madar is unsure about goes on the list WITHOUT a number', () {
    final m = PantryMatcher.match(
      dish('r1', 'كبسة', ingredients: [ing('رز', quantity: 2, unit: 'كوب')]),
      pantry: board([item('رز', quantity: 5, unit: 'كيلو')]),
    );
    final lines = ShoppingLines.ofMatch(m);
    expect(lines.single.title, 'رز');
    expect(lines.single.quantity, isNull);
    expect(ShoppingLines.ofMatch(m, includeUnsure: false), isEmpty);
  });

  test('what is low or finished becomes lines, with her threshold as the amount', () {
    final lines = ShoppingLines.ofPantry(
      board([
        item('زيت', quantity: 0, unit: 'لتر'),
        item('رز', quantity: 0.5, unit: 'كيلو', lowAt: 2),
        item('سكر', low: true),
        item('بندورة', quantity: 5, unit: 'حبة'),
      ]),
    );
    expect([for (final l in lines) l.title], ['زيت', 'رز', 'سكر']);
    expect(lines[0].quantity, isNull, reason: 'she set no threshold for the oil');
    expect(lines[1].quantity, 2);
    expect(lines[1].unit, 'كيلو');
    expect(lines[2].quantity, isNull);
  });

  test('adding the same thing twice does not double the list', () {
    final lines = [
      const ShoppingLine(title: 'رز'),
      const ShoppingLine(title: 'بندوره'),
      const ShoppingLine(title: 'دجاج'),
    ];
    final fresh = ShoppingLines.without(lines, ['رز', 'بندورة']);
    expect([for (final l in fresh) l.title], ['دجاج']);
  });

  test('a blank title never reaches the list', () {
    expect(ShoppingLines.without([const ShoppingLine(title: '   ')], const []), isEmpty);
  });
}
