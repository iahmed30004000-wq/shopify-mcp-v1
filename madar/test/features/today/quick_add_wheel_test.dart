import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/today/domain/quick_add_wheel.dart';

void main() {
  const defaultIds = ['task', 'expense', 'medicine_taken', 'meal', 'water', 'prayer_log', 'note', 'workout'];

  test('the default wheel has the eight actions in the agreed order', () {
    expect(QuickAddWheel.slotCount, 8);
    expect(QuickAddWheel.defaults.slots, defaultIds);
    expect(QuickAddWheel.defaults.isDefault, isTrue);
    expect(QuickAddWheel.defaults.slots.toSet(), hasLength(8));
    expect(QuickAddAction.values, hasLength(8));
    expect(QuickAddAction.tryParse('water'), QuickAddAction.water);
    expect(QuickAddAction.tryParse('nope'), isNull);
  });

  test('slots are unmodifiable', () {
    expect(() => QuickAddWheel.defaults.slots.add('x'), throwsUnsupportedError);
  });

  test('move drags a slice and shifts the others', () {
    final w = QuickAddWheel.defaults.move(0, 3);
    expect(w.slots, ['expense', 'medicine_taken', 'meal', 'task', 'water', 'prayer_log', 'note', 'workout']);
    expect(w.isDefault, isFalse);
    expect(QuickAddWheel.defaults.slots, defaultIds, reason: 'immutable');
    expect(identical(w.move(2, 2), w), isTrue);
    expect(identical(w.move(-1, 2), w), isTrue);
    expect(identical(w.move(0, 8), w), isTrue);
  });

  test('swap exchanges two slices', () {
    final w = QuickAddWheel.defaults.swap(0, 7);
    expect(w.slots.first, 'workout');
    expect(w.slots.last, 'task');
  });

  test('assign keeps it a permutation: an id already present swaps places', () {
    final w = QuickAddWheel.defaults.assign(0, 'water');
    expect(w.slots[0], 'water');
    expect(w.slots[4], 'task');
    expect(w.slots.toSet(), hasLength(8));
    expect(identical(QuickAddWheel.defaults.assign(0, 'task'), QuickAddWheel.defaults), isTrue);
    expect(identical(QuickAddWheel.defaults.assign(0, 'unknown'), QuickAddWheel.defaults), isTrue);
  });

  test('a bigger catalog lets a new id replace a slice', () {
    final cat = {...QuickAddWheel.defaultCatalog, 'sleep'};
    final w = QuickAddWheel.defaults.assign(1, 'sleep', catalog: cat);
    expect(w.slots[1], 'sleep');
    expect(w.slots, isNot(contains('expense')));
    expect(w.slots, hasLength(8));
    expect(QuickAddWheel.fromJson(w.toJson(), catalog: cat), w);
    // Without the catalog the unknown id is dropped and the default refills.
    expect(QuickAddWheel.fromJson(w.toJson()).slots.toSet(), QuickAddWheel.defaultCatalog);
  });

  test('reset', () {
    expect(QuickAddWheel.defaults.move(0, 5).reset(), QuickAddWheel.defaults);
  });

  test('JSON round trip', () {
    final w = QuickAddWheel.defaults.move(7, 0).swap(2, 4);
    expect(QuickAddWheel.decode(w.encode()), w);
    expect(QuickAddWheel.fromJson(w.toJson()), w);
    expect(w.toJson()['v'], QuickAddWheel.version);
    expect(QuickAddWheel.decode(w.encode()).hashCode, w.hashCode);
  });

  test('a damaged value always gives a full wheel and never throws', () {
    expect(QuickAddWheel.decode(null), QuickAddWheel.defaults);
    expect(QuickAddWheel.decode('{broken'), QuickAddWheel.defaults);
    expect(QuickAddWheel.fromJson(7), QuickAddWheel.defaults);
    expect(QuickAddWheel.fromJson({'slots': 'x'}), QuickAddWheel.defaults);
    final repaired = QuickAddWheel.fromJson({
      'slots': ['note', 'note', 3, null, 'nope', 'water'],
    });
    expect(repaired.slots.take(2), ['note', 'water']);
    expect(repaired.slots, hasLength(8));
    expect(repaired.slots.toSet(), QuickAddWheel.defaultCatalog);
    // Too many entries are cut.
    final long = QuickAddWheel.fromJson({'slots': [...defaultIds.reversed, 'extra', 'extra2']});
    expect(long.slots, defaultIds.reversed.toList());
  });
}
