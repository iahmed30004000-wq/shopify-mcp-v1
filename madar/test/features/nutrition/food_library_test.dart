import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

Food _food(String id, String name, {List<String> tags = const [], bool favorite = false, bool archived = false, double? portion, String? unit}) =>
    Food(id: id, name: name, tags: tags, favorite: favorite, archived: archived, defaultPortion: portion, unit: unit);

void main() {
  group('FoodLookup', () {
    final library = [
      _food('f1', 'بندورة', tags: ['خضار']),
      _food('f2', 'خبز أسمر', tags: ['نشويات']),
      _food('f3', 'دجاج مشوي', tags: ['بروتين', 'مشوي']),
      _food('f4', 'بطاطا مقلية', tags: ['مقلي', 'نشويات']),
      _food('f5', 'Greek yogurt', tags: ['بروتين']),
    ];

    test('an exact name beats a prefix and a prefix beats a later word', () {
      final exact = FoodLookup.search(library, 'بندورة');
      expect(exact.first.food.id, 'f1');
      expect(exact.first.score, FoodLookup.scoreExact);

      final prefix = FoodLookup.search(library, 'بطا');
      expect(prefix.first.food.id, 'f4');
      expect(prefix.first.score, FoodLookup.scorePrefix);

      final word = FoodLookup.search(library, 'مقلي');
      expect(word.first.food.id, 'f4');
      expect(word.first.score, FoodLookup.scoreWordPrefix);
    });

    test('Arabic folding: harakat, alef forms and taa marbuta all find the food', () {
      for (final query in ['بَنْدورة', 'بندوره', 'بندورة']) {
        expect(FoodLookup.search(library, query).first.food.id, 'f1', reason: query);
      }
      expect(FoodLookup.search(library, 'خبز اسمر').first.food.id, 'f2');
      expect(FoodLookup.search(library, 'دجاج مشوى').first.food.id, 'f3');
    });

    test('Latin is case-insensitive and Arabic-Indic digits read as Western ones', () {
      expect(FoodLookup.search(library, 'GREEK').first.food.id, 'f5');
      final withNumber = [..._numbered()];
      expect(FoodLookup.search(withNumber, '١٢').first.food.id, 'n1');
      expect(FoodLookup.search(withNumber, '12').first.food.id, 'n1');
    });

    test('one typo still finds a word of three letters or more, but not a two-letter query', () {
      expect(FoodLookup.search(library, 'بندروة').first.food.id, 'f1'); // swapped letters
      expect(FoodLookup.search(library, 'بندوة').first.food.id, 'f1'); // missing letter
      expect(FoodLookup.search(library, 'بن').where((m) => m.food.id == 'f1'), isNotEmpty); // prefix, not typo
      expect(FoodLookup.search(library, 'سخ'), isEmpty);
    });

    test('a tag matches too, and says so', () {
      final hits = FoodLookup.search(library, 'بروتين');
      expect(hits.map((m) => m.food.id), containsAll(['f3', 'f5']));
      expect(hits.every((m) => m.onTag), isTrue);
      expect(hits.first.score, FoodLookup.scoreTag);
    });

    test('ties break on how often he logged it', () {
      final two = [_food('a', 'لبنة', tags: const []), _food('b', 'لبنة', tags: const [])];
      expect(FoodLookup.search(two, 'لبنة', usage: {'b': 4}).first.food.id, 'b');
    });

    test('archived foods are left out unless asked for', () {
      final withArchived = [...library, _food('old', 'كنافة', archived: true)];
      expect(FoodLookup.search(withArchived, 'كنافة'), isEmpty);
      expect(FoodLookup.search(withArchived, 'كنافة', includeArchived: true).single.food.id, 'old');
    });

    test('an empty query gives the quick-pick list: favourites, then most logged', () {
      final pool = [
        _food('a', 'أ'),
        _food('b', 'ب'),
        _food('c', 'ج', favorite: true),
      ];
      final picks = FoodLookup.search(pool, '   ', usage: {'b': 9});
      expect(picks.map((m) => m.food.id), ['c', 'b', 'a']);
    });

    test('tagsOf merges spellings and sorts by how many foods carry the tag', () {
      final tags = FoodLookup.tagsOf([
        _food('a', 'أ', tags: ['نشويات', 'مقلي']),
        _food('b', 'ب', tags: ['نَشويات']),
        _food('c', 'ج', tags: ['  ']),
      ]);
      expect(tags.length, 2);
      expect(tags.first, 'نَشويات'); // the spelling he used last, 2 foods
      expect(tags.last, 'مقلي');
    });

    test('sameWord folds both sides', () {
      expect(FoodLookup.sameWord('مقلي', 'مَقلي'), isTrue);
      expect(FoodLookup.sameWord('مقلي', 'مشوي'), isFalse);
      expect(FoodLookup.sameWord(null, 'مقلي'), isFalse);
      expect(FoodLookup.sameWord('  ', 'مقلي'), isFalse);
    });
  });

  group('Portions', () {
    test('the logged amount wins, else the food default, else nothing', () {
      final food = _food('f', 'رغيف', portion: 2, unit: 'رغيف');
      expect(Portions.effective(3, food: food), 3);
      expect(Portions.effective(null, food: food), 2);
      expect(Portions.effective(null), isNull);
      expect(Portions.unitOf(null, food: food), 'رغيف');
      expect(Portions.unitOf('حبة', food: food), 'حبة');
      expect(Portions.unitOf('  ', food: food), 'رغيف');
      expect(Portions.unitOf(null), isNull);
    });

    test('amounts add up inside one unit only, and spellings of a unit merge', () {
      final totals = Portions.sumByUnit([
        (amount: 1.5, unit: 'كوب'),
        (amount: 0.5, unit: 'كُوب'),
        (amount: 2, unit: 'رغيف'),
        (amount: null, unit: 'رغيف'),
        (amount: 3, unit: null),
      ]);
      expect(totals['كوب'], 2);
      expect(totals['رغيف'], 2);
      expect(totals[Portions.noUnit], 3);
      expect(totals.length, 3);
    });

    test('no floating-point dust', () {
      expect(Portions.sumByUnit([(amount: 0.1, unit: 'ك'), (amount: 0.2, unit: 'ك')])['ك'], 0.3);
      expect(Portions.scale(1.5, 0.5), 0.75);
      expect(Portions.scale(null, 2), isNull);
    });

    test('a threshold never fires on an entry without an amount', () {
      expect(Portions.reaches(null, 2), isFalse);
      expect(Portions.reaches(1.9, 2), isFalse);
      expect(Portions.reaches(2, 2), isTrue);
    });
  });
}

List<Food> _numbered() => [_food('n1', 'عصير 12 حبة')];
