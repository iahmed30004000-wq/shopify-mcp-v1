import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

final _today = DateTime(2026, 10, 10);

FoodEntry _entry(String id, String name, DateTime at, {String? foodId}) =>
    FoodEntry(id: id, name: name, at: at, foodId: foodId);

MealPlan _plan() => MealPlan(
  id: 'p1',
  name: 'خطتي',
  active: true,
  slots: [
    MealSlot(
      id: 's1',
      planId: 'p1',
      name: 'فطور',
      timeMinutes: 8 * 60,
      foods: const [PlannedFood(id: 'pf1', name: 'شوفان')],
    ),
    MealSlot(
      id: 's2',
      planId: 'p1',
      name: 'غدا',
      timeMinutes: 13 * 60,
      foods: const [PlannedFood(id: 'pf2', name: 'دجاج')],
    ),
  ],
);

void main() {
  test('a fresh install: everything empty, nothing invented', () {
    final summary = NutritionSummary.empty(_today);
    expect(summary.loggedToday, isFalse);
    expect(summary.hasPlan, isFalse);
    expect(summary.hasRules, isFalse);
    expect(summary.risk, isNull);
    expect(summary.level, isNull);
    expect(summary.reasons, isEmpty);
    expect(summary.adherenceToday, isNull);
    expect(summary.planetScore, isNull);
    expect(summary.lastEntryAt, isNull);
  });

  test('today\'s log, plan and streak come out as plain numbers', () {
    final entries = [
      _entry('e1', 'شوفان', DateTime(2026, 10, 10, 8, 10)),
      _entry('e2', 'منسف', DateTime(2026, 10, 10, 13, 20)),
      _entry('e3', 'فلافل', DateTime(2026, 10, 9, 9)),
    ];
    final summary = NutritionSummary.build(
      today: _today,
      now: DateTime(2026, 10, 10, 23),
      plan: _plan(),
      entries: entries,
      foods: [const Food(id: 'f1', name: 'شوفان'), const Food(id: 'f2', name: 'كنافة', archived: true)],
      ruleCount: 0,
    );
    expect(summary.entryCountToday, 2);
    expect(summary.entriesToday.first.id, 'e1');
    expect(summary.lastEntryAt, DateTime(2026, 10, 10, 13, 20));
    expect(summary.today.onTime, 1);
    expect(summary.today.swapped, 1);
    expect(summary.adherenceToday, 0.5);
    expect(summary.loggedDays7, 2);
    expect(summary.streakDays, 2);
    expect(summary.foodCount, 1, reason: 'archived foods are not counted');
    expect(summary.hasRules, isFalse);
    expect(summary.risk, isNull);
  });

  test('the planet score averages what exists, and stays null when nothing does', () {
    final noData = NutritionSummary.build(
      today: _today,
      now: DateTime(2026, 10, 10, 23),
      plan: MealPlan.none,
      entries: const [],
      foods: const [],
      ruleCount: 0,
    );
    expect(noData.planetScore, isNull);

    final logOnly = NutritionSummary.build(
      today: _today,
      now: DateTime(2026, 10, 10, 23),
      plan: MealPlan.none,
      entries: [for (var i = 0; i < 7; i++) _entry('e$i', 'أكل', DateTime(2026, 10, 10 - i, 13))],
      foods: const [],
      ruleCount: 0,
    );
    expect(logOnly.planetScore, 1);

    final halfKept = NutritionSummary.build(
      today: _today,
      now: DateTime(2026, 10, 10, 23),
      plan: _plan(),
      entries: [_entry('e1', 'شوفان', DateTime(2026, 10, 10, 8, 5))],
      foods: const [],
      ruleCount: 0,
    );
    // One of seven days logged, one of two settled slots eaten.
    expect(halfKept.planetScore, closeTo((1 / 7 + 0.5) / 2, 1e-9));
  });

  test('a rating is carried through with its reasons when he has rules', () {
    final entries = [FoodEntry(id: 'e1', name: 'فلافل', at: DateTime(2026, 10, 10, 8), tags: const ['مقلي'])];
    final risk = RiskEngine.rateDay(
      day: _today,
      entries: entries,
      rules: [
        const FoodRule(
          id: 'r1',
          target: FoodRuleTarget.tag,
          tag: 'مقلي',
          weight: RiskWeight.high,
          conditionId: 'c1',
          note: 'المقلي يتعب معدتي',
        ),
      ],
      conditions: [const ConditionRef(id: 'c1', name: 'المعدة')],
    );
    final summary = NutritionSummary.build(
      today: _today,
      now: DateTime(2026, 10, 10, 23),
      plan: MealPlan.none,
      entries: entries,
      foods: const [],
      ruleCount: 1,
      risk: risk,
    );
    expect(summary.hasRules, isTrue);
    expect(summary.level, RiskLevel.low, reason: 'three points is still low for a whole day');
    expect(summary.reasons.single.note, 'المقلي يتعب معدتي');
    expect(summary.reasons.single.conditionName, 'المعدة');
  });
}
