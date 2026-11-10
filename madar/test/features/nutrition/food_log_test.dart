import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

FoodEntry _entry(String id, String name, DateTime at, {String? foodId, List<String> tags = const []}) =>
    FoodEntry(id: id, name: name, at: at, foodId: foodId, tags: tags);

final _today = DateTime(2026, 10, 10);

void main() {
  group('FoodLogStats', () {
    test('onDay keeps one local day, earliest first', () {
      final entries = [
        _entry('e3', 'عشا', DateTime(2026, 10, 10, 20)),
        _entry('e1', 'فطور', DateTime(2026, 10, 10, 8)),
        _entry('e0', 'أمس', DateTime(2026, 10, 9, 23, 59)),
        _entry('e4', 'بكرا', DateTime(2026, 10, 11, 0, 1)),
      ];
      expect(FoodLogStats.onDay(entries, _today).map((e) => e.id), ['e1', 'e3']);
    });

    test('mostUsed counts a food by id and free text by its folded words', () {
      final entries = [
        _entry('e1', 'فلافل', DateTime(2026, 10, 10, 8), foodId: 'f1'),
        _entry('e2', 'فلافل', DateTime(2026, 10, 9, 8), foodId: 'f1'),
        _entry('e3', 'قهوة', DateTime(2026, 10, 9, 9)),
        _entry('e4', 'قَهوة', DateTime(2026, 10, 8, 9)),
        _entry('e5', 'كنافة', DateTime(2026, 10, 7, 20)),
        // Outside the 30-day window.
        _entry('e6', 'كنافة', DateTime(2026, 8, 1, 20)),
      ];
      final used = FoodLogStats.mostUsed(entries, today: _today);
      expect(used.first.foodId, 'f1');
      expect(used.first.count, 2);
      expect(used[1].count, 2, reason: 'the two spellings of «قهوة» are one thing');
      expect(used[1].name, 'قهوة', reason: 'the most recent spelling');
      expect(used.last.count, 1, reason: 'the old كنافة is outside the window');
      expect(FoodLogStats.useCountById(entries), {'f1': 2});
    });

    test('mostRecent lists each thing once, newest first', () {
      final entries = [
        _entry('e1', 'فلافل', DateTime(2026, 10, 10, 8), foodId: 'f1'),
        _entry('e2', 'فلافل', DateTime(2026, 10, 10, 13), foodId: 'f1'),
        _entry('e3', 'شاي', DateTime(2026, 10, 10, 10)),
      ];
      final recent = FoodLogStats.mostRecent(entries);
      expect(recent.map((u) => u.name), ['فلافل', 'شاي']);
      expect(recent.first.lastAt, DateTime(2026, 10, 10, 13));
    });

    test('daysLogged and streak count days, not entries', () {
      final entries = [
        _entry('e1', 'أ', DateTime(2026, 10, 10, 8)),
        _entry('e2', 'ب', DateTime(2026, 10, 10, 20)),
        _entry('e3', 'ج', DateTime(2026, 10, 9, 8)),
        _entry('e4', 'د', DateTime(2026, 10, 7, 8)),
      ];
      expect(FoodLogStats.daysLogged(entries, today: _today), 3);
      expect(FoodLogStats.streak(entries, today: _today), 2);
      expect(FoodLogStats.countByDay(entries)['2026-10-10'], 2);
      // Nothing today: no streak, whatever yesterday held.
      expect(FoodLogStats.streak(entries, today: DateTime(2026, 10, 11)), 0);
    });

    test('tagsFor adds the food\'s tags to the entry\'s own, without repeats', () {
      final food = const Food(id: 'f1', name: 'فلافل', tags: ['مقلي', 'نشويات']);
      final entry = _entry('e1', 'فلافل', DateTime(2026, 10, 10, 8), foodId: 'f1', tags: ['مَقلي', 'زيارة']);
      expect(FoodLogStats.tagsFor(entry, food: food), ['مقلي', 'نشويات', 'زيارة']);
      expect(FoodLogStats.tagsFor(entry), ['مَقلي', 'زيارة']);
    });

    test('minuteOfDay and repeatKey', () {
      final entry = _entry('e1', 'قهوة', DateTime(2026, 10, 10, 21, 30));
      expect(entry.minuteOfDay, 21 * 60 + 30);
      expect(entry.repeatKey, 'text:قهوه');
      expect(_entry('e2', 'قهوة', DateTime(2026, 10, 10, 8), foodId: 'f9').repeatKey, 'f9');
    });
  });
}
