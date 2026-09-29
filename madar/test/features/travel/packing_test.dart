import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/travel/domain/packing.dart';

typedef Item = ({String id, String? category, bool packed});

void main() {
  Item it(String id, String? category, [bool packed = false]) => (id: id, category: category, packed: packed);

  group('PackingProgress', () {
    test('counts, fraction and completion', () {
      final p = PackingProgress.of([true, false, true, true]);
      expect(p.packed, 3);
      expect(p.total, 4);
      expect(p.remaining, 1);
      expect(p.fraction, 0.75);
      expect(p.complete, isFalse);
      expect(PackingProgress.of([true, true]).complete, isTrue);
    });

    test('an empty list is never complete and has no fraction', () {
      expect(PackingProgress.empty.complete, isFalse);
      expect(PackingProgress.empty.fraction, 0);
    });

    test('knows the moment the last item goes in', () {
      const before = PackingProgress(2, 3);
      const after = PackingProgress(3, 3);
      expect(after.completes(before), isTrue);
      expect(after.completes(after), isFalse);
      expect(before.completes(const PackingProgress(1, 3)), isFalse);
    });
  });

  group('grouping', () {
    final items = [
      it('a', null),
      it('b', PackingCategories.clothes, true),
      it('c', 'Gifts'),
      it('d', PackingCategories.documents),
      it('e', PackingCategories.clothes),
      it('f', '  '),
      it('g', 'Camping'),
    ];
    final groups = PackingLayout.group(items, categoryOf: (i) => i.category, packedOf: (i) => i.packed);

    test('standard categories first, then the user\'s own, "other" last', () {
      expect(groups.map((g) => g.category), [
        PackingCategories.documents,
        PackingCategories.clothes,
        'Gifts',
        'Camping',
        PackingCategories.misc,
      ]);
    });

    test('items keep their order inside a group, with its progress', () {
      final clothes = groups[1];
      expect(clothes.items.map((i) => i.id), ['b', 'e']);
      expect(clothes.progress, const PackingProgress(1, 2));
      expect(groups.last.items.map((i) => i.id), ['a', 'f']);
    });

    test('entries put a header before each group', () {
      final entries = PackingLayout.entries(groups);
      expect(entries.first, isA<PackingHeader<Item>>());
      expect(entries.whereType<PackingHeader<Item>>().length, groups.length);
      expect(entries.whereType<PackingItemEntry<Item>>().length, items.length);
    });
  });

  group('drag and drop', () {
    final items = [it('p', PackingCategories.documents), it('s', PackingCategories.clothes), it('t', PackingCategories.clothes)];
    final groups = PackingLayout.group(items, categoryOf: (i) => i.category, packedOf: (i) => i.packed);
    final entries = PackingLayout.entries(groups);
    // [H docs, p, H clothes, s, t]

    test('reordering inside a group changes no category', () {
      final moved = [entries[0], entries[1], entries[2], entries[4], entries[3]];
      final r = PackingLayout.applyReorder(moved);
      expect(r.order.map((i) => i.id), ['p', 't', 's']);
      expect(r.recategorized, isEmpty);
    });

    test('an item dropped under another header joins that category', () {
      final moved = [entries[0], entries[1], entries[3], entries[2], entries[4]];
      final r = PackingLayout.applyReorder(moved);
      expect(r.order.map((i) => i.id), ['p', 's', 't']);
      expect(r.recategorized.map((k, v) => MapEntry(k.id, v)), {'s': PackingCategories.documents});
    });

    test('an item dropped above the first header joins the first group', () {
      final moved = [entries[3], entries[0], entries[1], entries[2], entries[4]];
      final r = PackingLayout.applyReorder(moved);
      expect(r.order.first.id, 's');
      expect(r.recategorized.map((k, v) => MapEntry(k.id, v)), {'s': PackingCategories.documents});
    });
  });

  group('templates', () {
    test('items round-trip with and without a category', () {
      const a = PackingTemplateItem('Charger', PackingCategories.electronics);
      const b = PackingTemplateItem('Snacks');
      expect(PackingTemplateItem.decode(a.encode()), a);
      expect(PackingTemplateItem.decode(b.encode()), b);
      expect(b.encode(), 'Snacks');
      // "misc" is the default: stored without a category.
      expect(const PackingTemplateItem('Book', PackingCategories.misc).encode(), 'Book');
      expect(PackingTemplateMath.decodeAll(['', '  ', a.encode()]), [a]);
    });

    test('merging templates adds each item once, and nothing already packed', () {
      final essentials = [
        const PackingTemplateItem('Phone charger', PackingCategories.electronics),
        const PackingTemplateItem('جواز السفر', PackingCategories.documents),
        const PackingTemplateItem('Toothbrush'),
      ];
      final business = [
        const PackingTemplateItem('phone  CHARGER', PackingCategories.electronics),
        const PackingTemplateItem('Laptop', PackingCategories.electronics),
      ];
      final merged = PackingTemplateMath.merge([essentials, business], existingBodies: ['جَواز السّفر']);
      expect(merged.map((i) => i.body), ['Phone charger', 'Toothbrush', 'Laptop']);
    });
  });
}
