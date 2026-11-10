import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

/// 2026-10-10 is a Saturday (weekday 6).
final _day = DateTime(2026, 10, 10);

MealSlot _slot(
  String id,
  String name,
  int minutes, {
  List<int> weekdays = const [],
  List<PlannedFood> foods = const [],
  bool remind = false,
}) => MealSlot(id: id, planId: 'p1', name: name, timeMinutes: minutes, weekdays: weekdays, foods: foods, remind: remind);

PlannedFood _planned(String id, String name, {String? foodId}) => PlannedFood(id: id, name: name, foodId: foodId);

FoodEntry _entry(String id, String name, int hour, int minute, {String? foodId, String? slotId}) => FoodEntry(
  id: id,
  name: name,
  at: DateTime(2026, 10, 10, hour, minute),
  foodId: foodId,
  slotId: slotId,
);

MealPlan _plan(List<MealSlot> slots) => MealPlan(id: 'p1', name: 'خطتي', active: true, slots: slots);

void main() {
  group('slots of a day', () {
    test('a slot without weekdays is every day; weekdays are DateTime.weekday', () {
      final plan = _plan([
        _slot('s1', 'فطور', 8 * 60),
        _slot('s2', 'غدا', 13 * 60, weekdays: [6]), // Saturday
        _slot('s3', 'عشا', 19 * 60, weekdays: [1]), // Monday
      ]);
      expect(_day.weekday, 6);
      expect(plan.slotsOn(_day).map((s) => s.id), ['s1', 's2']);
      expect(plan.ordered.map((s) => s.id), ['s1', 's2', 's3']);
      expect(plan.slotsPerWeekday[1], 2);
      expect(plan.slotsPerWeekday[6], 2);
      expect(_slot('s', 'فطور', 8 * 60 + 30).timeLabel, '08:30');
    });

    test('a draft plan still answers slotsOn (only reminders care about active)', () {
      final draft = MealPlan(id: 'p2', name: 'مسودة', slots: [_slot('s1', 'فطور', 480)]);
      expect(draft.active, isFalse);
      expect(draft.slotsOn(_day), hasLength(1));
      expect(MealPlan.activeOf([draft]), MealPlan.none);
    });
  });

  group('planned vs eaten', () {
    final plan = _plan([
      _slot('s1', 'فطور', 8 * 60, foods: [_planned('pf1', 'شوفان', foodId: 'f-oats'), _planned('pf2', 'بيض')]),
      _slot('s2', 'غدا', 13 * 60, foods: [_planned('pf3', 'دجاج')]),
      _slot('s3', 'عشا', 19 * 60, foods: [_planned('pf4', 'لبنة')]),
    ]);

    DayPlan compare(List<FoodEntry> entries, {int nowHour = 23}) => PlanCompare.compare(
      plan: plan,
      entries: entries,
      day: _day,
      now: DateTime(2026, 10, 10, nowHour),
    );

    test('a planned food at its time is eaten on time', () {
      final result = compare([_entry('e1', 'شوفان', 8, 10, foodId: 'f-oats')]);
      final breakfast = result.outcomes.first;
      expect(breakfast.status, SlotStatus.eatenOnTime);
      expect(breakfast.matchedNames, ['شوفان']);
      expect(breakfast.lateBy, const Duration(minutes: 10));
      expect(result.onTime, 1);
      expect(result.unplanned, isEmpty);
    });

    test('later than the late window is eaten late, not skipped', () {
      final result = compare([_entry('e1', 'بيض', 9, 30)]);
      expect(result.outcomes.first.status, SlotStatus.eatenLate);
      expect(result.late, 1);
      expect(result.outcomes.first.lateBy, const Duration(minutes: 90));
    });

    test('something else at that meal is a swap, not a skip', () {
      final result = compare([_entry('e1', 'منسف', 13, 20)]);
      expect(result.outcomes[1].status, SlotStatus.swapped);
      expect(result.outcomes[1].entries.single.id, 'e1');
      expect(result.swapped, 1);
      expect(result.unplanned, isEmpty);
    });

    test('a meal with nothing logged and its window past is skipped', () {
      final result = compare(const []);
      expect(result.outcomes.map((o) => o.status), [SlotStatus.skipped, SlotStatus.skipped, SlotStatus.skipped]);
      expect(result.skipped, 3);
      expect(result.adherence, 0);
    });

    test('a meal still ahead is pending, and pending slots are not counted against him', () {
      final result = compare([_entry('e1', 'شوفان', 8, 0, foodId: 'f-oats')], nowHour: 9);
      expect(result.outcomes.map((o) => o.status), [
        SlotStatus.eatenOnTime,
        SlotStatus.pending,
        SlotStatus.pending,
      ]);
      expect(result.pending, 2);
      expect(result.settled, 1);
      expect(result.adherence, 1);
      expect(result.next!.slot.id, 's2');
    });

    test('nothing settled yet: adherence is absent, not zero', () {
      final result = compare(const [], nowHour: 6);
      expect(result.settled, 0);
      expect(result.adherence, isNull);
    });

    test('anything outside every window is unplanned', () {
      final result = compare([_entry('e1', 'شوكولاتة', 16, 30)]);
      expect(result.unplanned.single.id, 'e1');
      expect(result.outcomes.every((o) => o.status == SlotStatus.skipped), isTrue);
    });

    test('an entry he tied to a slot himself counts for it whatever the time', () {
      final result = compare([_entry('e1', 'دجاج', 17, 0, slotId: 's2')]);
      expect(result.outcomes[1].status, SlotStatus.eatenLate);
      expect(result.unplanned, isEmpty);
      // A slotId of another plan's slot is simply unplanned here.
      final foreign = compare([_entry('e2', 'دجاج', 17, 0, slotId: 'gone')]);
      expect(foreign.unplanned.single.id, 'e2');
    });

    test('an entry a little early still answers its slot', () {
      final result = compare([_entry('e1', 'لبنة', 18, 0), _entry('e2', 'دجاج', 13, 5)]);
      expect(result.outcomes[1].entries.map((e) => e.id), ['e2']);
      expect(result.outcomes[2].entries.map((e) => e.id), ['e1']);
      expect(result.outcomes[2].status, SlotStatus.eatenOnTime);
      expect(result.unplanned, isEmpty);
    });

    test('when two meals are close together, the entry answers the nearest one', () {
      final close = _plan([
        _slot('a', 'غدا', 12 * 60, foods: [_planned('pa', 'رز')]),
        _slot('b', 'بعد الغدا', 13 * 60, foods: [_planned('pb', 'رز')]),
      ]);
      final result = PlanCompare.compare(
        plan: close,
        entries: [_entry('e1', 'رز', 12, 40)],
        day: _day,
        now: DateTime(2026, 10, 10, 23),
      );
      expect(result.outcomes.first.entries, isEmpty);
      expect(result.outcomes.first.status, SlotStatus.skipped);
      expect(result.outcomes.last.entries.map((e) => e.id), ['e1']);
      expect(result.outcomes.last.status, SlotStatus.eatenOnTime);
    });

    test('a slot with no planned food at all reads as a swap once he eats at its time', () {
      final empty = _plan([_slot('s1', 'فطور', 8 * 60)]);
      final result = PlanCompare.compare(
        plan: empty,
        entries: [_entry('e1', 'أي شي', 8, 5)],
        day: _day,
        now: DateTime(2026, 10, 10, 23),
      );
      expect(result.outcomes.single.status, SlotStatus.swapped);
    });

    test('no plan: no outcomes and everything unplanned', () {
      final result = PlanCompare.compare(
        plan: MealPlan.none,
        entries: [_entry('e1', 'فلافل', 9, 0)],
        day: _day,
        now: DateTime(2026, 10, 10, 23),
      );
      expect(result.hasPlan, isFalse);
      expect(result.outcomes, isEmpty);
      expect(result.unplanned, hasLength(1));
      expect(result.adherence, isNull);
    });

    test('the last days come back oldest first', () {
      final week = PlanCompare.lastDays(
        plan: plan,
        entries: const [],
        today: _day,
        now: DateTime(2026, 10, 10, 23),
      );
      expect(week, hasLength(7));
      expect(week.first.day, DateTime(2026, 10, 4));
      expect(week.last.day, _day);
    });
  });
}
