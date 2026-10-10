import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';

/// The product brief's example budget (amounts in JOD milli).
List<BudgetNode> briefBudget() => const [
  BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000, sortOrder: 0),
  BudgetNode(id: 'proteins', name: 'Proteins', parentId: 'food', amountMilli: 100000, sortOrder: 0),
  BudgetNode(id: 'spices', name: 'Spices', parentId: 'food', amountMilli: 20000, sortOrder: 1),
  BudgetNode(id: 'treats', name: 'Treats', parentId: 'food', amountMilli: 30000, sortOrder: 2),
  BudgetNode(id: 'fruitveg', name: 'Fruit & vegetables', parentId: 'food', amountMilli: 50000, sortOrder: 3),
  BudgetNode(id: 'fuel', name: 'Car fuel', amountMilli: 100000, sortOrder: 1),
  BudgetNode(id: 'emergency', name: 'Emergency', amountMilli: 30000, sortOrder: 2),
  BudgetNode(id: 'allowance', name: "Wife's allowance", amountMilli: 5000, period: BudgetPeriod.weekly, sortOrder: 3),
];

void main() {
  group('weekly ↔ monthly', () {
    test('5/week is 20.000 at 4 weeks and 21.725 at 4.345 weeks', () {
      expect(BudgetMath.weeklyToMonthly(5000, 4), 20000);
      expect(BudgetMath.weeklyToMonthly(5000, 4.345), 21725);
      expect(BudgetMath.monthlyToWeekly(21725, 4.345), 5000);
      // 100/4.345 = 23.014959… → 23.015 (half-up).
      expect(BudgetMath.monthlyToWeekly(100000, 4.345), 23015);
    });

    test('a weekly node follows the configured weeks-per-month', () {
      final four = BudgetMath(briefBudget());
      expect(four['allowance']!.monthlyMilli, 20000);
      expect(four['allowance']!.weeklyMilli, 5000);
      expect(four['allowance']!.plannedMilli, 5000);
      final cal = BudgetMath(briefBudget(), settings: const BudgetSettings(weeksPerMonth: 4.345));
      expect(cal['allowance']!.monthlyMilli, 21725);
      expect(cal['allowance']!.weeklyMilli, 5000);
    });
  });

  group("the brief's example", () {
    late BudgetMath math;
    setUp(() => math = BudgetMath(briefBudget()));

    test('tree structure', () {
      expect(math.rootIds, ['food', 'fuel', 'emergency', 'allowance']);
      expect(math.childrenOf('food').map((r) => r.node.id), ['proteins', 'spices', 'treats', 'fruitveg']);
      expect(math['proteins']!.depth, 1);
      expect(math['proteins']!.parentId, 'food');
      expect(math.flattened.map((r) => r.node.id).take(3), ['food', 'proteins', 'spices']);
    });

    test('totals = sum of roots (4 weeks/month)', () {
      expect(math.totalMonthlyMilli, 350000);
      expect(math.totalMonthly, const Money(350000, 'JOD'));
      expect(math.totalWeeklyMilli, 87500);
      expect(BudgetMath(briefBudget(), settings: const BudgetSettings(weeksPerMonth: 4.345)).totalMonthlyMilli, 351725);
    });

    test('children sum and percentages', () {
      final food = math['food']!;
      expect(food.childrenSumMilli, 200000);
      expect(food.childrenDeltaMilli, 0);
      expect(math['proteins']!.percentOfParent, closeTo(50, 1e-9));
      expect(math['spices']!.percentOfParent, closeTo(10, 1e-9));
      expect(math['treats']!.percentOfParent, closeTo(15, 1e-9));
      expect(math['fruitveg']!.percentOfParent, closeTo(25, 1e-9));
      expect(math['food']!.percentOfTotal, closeTo(200 / 350 * 100, 1e-9));
      expect(math['proteins']!.percentOfTotal, closeTo(100 / 350 * 100, 1e-9));
      expect(math['food']!.percentOfParent, isNull);
      expect(math.percentOfBase('proteins'), closeTo(50, 1e-9));
    });

    test('no warnings while the children match their parent', () {
      expect(math.warnings, isEmpty);
    });

    test('changing a child so the sum mismatches warns over / under', () {
      final over = math.replace(math.setAmount('proteins', 120000));
      expect(over['food']!.childrenSumMilli, 220000);
      expect(
        over.warnings,
        contains(const BudgetWarning(BudgetWarningKind.childrenOver, nodeId: 'food', amountMilli: 20000)),
      );
      // The parent keeps its own plan; the total is the sum of roots.
      expect(over.totalMonthlyMilli, 350000);

      final under = math.replace(math.setAmount('spices', 5000));
      expect(
        under.warnings,
        contains(const BudgetWarning(BudgetWarningKind.childrenUnder, nodeId: 'food', amountMilli: 15000)),
      );
    });

    test('setAmount recomputes the percent of its base', () {
      final spices = math.setAmount('spices', 40000);
      expect(spices.mode, BudgetMode.amount);
      expect(spices.amountMilli, 40000);
      expect(spices.percent, closeTo(20, 1e-9));
    });

    test('setPercent recomputes the amount from its base', () {
      final proteins = math.setPercent('proteins', 60);
      expect(proteins.mode, BudgetMode.percent);
      expect(proteins.percent, 60);
      expect(proteins.amountMilli, 120000);
      final next = math.replace(proteins);
      expect(next['proteins']!.monthlyMilli, 120000);
      expect(next['proteins']!.percentOfParent, closeTo(60, 1e-9));
      expect(next.warnings.single.kind, BudgetWarningKind.childrenOver);
    });

    test('a percent child follows its parent when the parent changes', () {
      final pct = math.replace(math.setPercent('proteins', 50));
      final bigger = pct.replace(pct.nodes.firstWhere((n) => n.id == 'food').copyWith(amountMilli: 300000));
      expect(bigger['proteins']!.monthlyMilli, 150000);
      expect(bigger['proteins']!.plannedMilli, 150000);
    });

    test('spend vs plan in a monthly window', () {
      final txs = [
        BudgetTx(budgetItemId: 'proteins', amountMilli: 60000, date: DateTime(2026, 9, 3)),
        BudgetTx(budgetItemId: 'proteins', amountMilli: 55000, date: DateTime(2026, 9, 20)),
        BudgetTx(budgetItemId: 'fuel', amountMilli: 40000, date: DateTime(2026, 9, 21)),
        BudgetTx(budgetItemId: 'fuel', amountMilli: 90000, date: DateTime(2026, 8, 30)), // other month
        BudgetTx(budgetItemId: 'fuel', amountMilli: 5000, date: DateTime(2026, 9, 5), kind: TxKind.income),
        BudgetTx(budgetItemId: null, amountMilli: 7000, date: DateTime(2026, 9, 9)),
      ];
      final report = math.spend(txs, BudgetWindow.month(DateTime(2026, 9, 15)));
      expect(report.byId['proteins']!.spentMilli, 115000);
      expect(report.byId['proteins']!.overspent, isTrue);
      expect(report.byId['food']!.spentMilli, 115000); // rolls up to the parent
      expect(report.byId['food']!.overspent, isFalse);
      expect(report.byId['fuel']!.spentMilli, 40000);
      expect(report.byId['fuel']!.remainingMilli, 60000);
      expect(report.totalSpentMilli, 155000);
      expect(report.totalPlannedMilli, 350000);
      expect(report.unassignedMilli, 7000);
      expect(
        report.warnings,
        contains(const BudgetWarning(BudgetWarningKind.overspent, nodeId: 'proteins', amountMilli: 15000)),
      );
      expect(report.warnings.where((w) => w.kind == BudgetWarningKind.overspent), hasLength(1));
    });

    test('spend vs plan in a weekly window (weeks start on Saturday)', () {
      // 2026-09-26 is a Saturday.
      final window = BudgetWindow.week(DateTime(2026, 9, 29));
      expect(window.start, DateTime(2026, 9, 26));
      expect(window.end, DateTime(2026, 10, 3));
      final report = math.spend([
        BudgetTx(budgetItemId: 'allowance', amountMilli: 6000, date: DateTime(2026, 9, 27)),
        BudgetTx(budgetItemId: 'allowance', amountMilli: 6000, date: DateTime(2026, 9, 25)), // previous week
      ], window);
      expect(report.byId['allowance']!.plannedMilli, 5000);
      expect(report.byId['allowance']!.spentMilli, 6000);
      expect(report.warnings.single, const BudgetWarning(BudgetWarningKind.overspent, nodeId: 'allowance', amountMilli: 1000));
      expect(report.totalPlannedMilli, 87500);
    });
  });

  group('percent chains', () {
    test('percent of total at the root level is solved in closed form', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'rent', name: 'Rent', amountMilli: 300000),
        BudgetNode(id: 'save', name: 'Savings', mode: BudgetMode.percent, percent: 10, percentOf: PercentBase.total),
      ]);
      // T = 300 + 0.1 T → T = 333.333…
      expect(m.totalMonthlyMilli, 333333);
      expect(m['save']!.monthlyMilli, 33333);
      expect(m['save']!.percentOfTotal, closeTo(10, 1e-9));
      expect(m.warnings, isEmpty);
    });

    test('a parent derived from its children, some of them percents of it', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home'),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', amountMilli: 150000),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: 25),
      ]);
      // x = 150 + 0.25 x → x = 200.
      expect(m['home']!.monthlyMilli, 200000);
      expect(m['home']!.derivedFromChildren, isTrue);
      expect(m['b']!.monthlyMilli, 50000);
      expect(m['home']!.childrenDeltaMilli, 0);
      expect(m.warnings, isEmpty);
    });

    test('children that are all 100 % of a derived parent are circular', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home'),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: 60),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: 40),
      ]);
      expect(m.warnings.map((w) => w.kind), contains(BudgetWarningKind.circularPercent));
      expect(m['home']!.monthlyMilli, 0);
    });

    test('percent siblings above 100 % of an amount parent warn', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home', amountMilli: 100000),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: 70),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: 50),
      ]);
      final w = m.warnings.firstWhere((w) => w.kind == BudgetWarningKind.percentOver100);
      expect(w.nodeId, 'home');
      expect(w.percent, closeTo(120, 1e-9));
      expect(m.warnings.map((w) => w.kind), contains(BudgetWarningKind.childrenOver));
    });

    test('a single percent above 100 warns on the node', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home', amountMilli: 100000),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: 150),
      ]);
      expect(m.warnings, contains(const BudgetWarning(BudgetWarningKind.percentOver100, nodeId: 'a', percent: 150)));
    });

    test('root percents of the total reaching 100 % are circular, above are over', () {
      final full = BudgetMath(const [
        BudgetNode(id: 'a', name: 'A', mode: BudgetMode.percent, percent: 50, percentOf: PercentBase.total),
        BudgetNode(id: 'b', name: 'B', mode: BudgetMode.percent, percent: 50, percentOf: PercentBase.total),
      ]);
      expect(full.warnings.single.kind, BudgetWarningKind.circularPercent);
      final over = BudgetMath(const [
        BudgetNode(id: 'x', name: 'X', amountMilli: 1000),
        BudgetNode(id: 'a', name: 'A', mode: BudgetMode.percent, percent: 80, percentOf: PercentBase.total),
        BudgetNode(id: 'b', name: 'B', mode: BudgetMode.percent, percent: 30, percentOf: PercentBase.total),
      ]);
      expect(over.warnings.map((w) => w.kind), contains(BudgetWarningKind.percentOver100));
    });

    test('float thirds of an amount parent are exactly 100 % (no warning)', () {
      const third = 100 / 3; // 33.333333333333336
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home', amountMilli: 100000),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: third),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: third, sortOrder: 1),
        BudgetNode(id: 'c', name: 'C', parentId: 'home', mode: BudgetMode.percent, percent: third, sortOrder: 2),
      ]);
      expect(m.warnings, isEmpty);
      expect(m['a']!.monthlyMilli, 33333);
      expect(m.totalMonthlyMilli, 100000);
    });

    test('float thirds of the total are circular, not over 100 %', () {
      const third = 100 / 3;
      final m = BudgetMath(const [
        BudgetNode(id: 'a', name: 'A', mode: BudgetMode.percent, percent: third, percentOf: PercentBase.total),
        BudgetNode(id: 'b', name: 'B', mode: BudgetMode.percent, percent: third, percentOf: PercentBase.total),
        BudgetNode(id: 'c', name: 'C', mode: BudgetMode.percent, percent: third, percentOf: PercentBase.total),
      ]);
      expect(m.warnings.single.kind, BudgetWarningKind.circularPercent);
    });

    test('float thirds of a derived parent are circular, not over 100 %', () {
      const third = 100 / 3;
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home'),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: third),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: third, sortOrder: 1),
        BudgetNode(id: 'c', name: 'C', parentId: 'home', mode: BudgetMode.percent, percent: third, sortOrder: 2),
      ]);
      expect(m.warnings.map((w) => w.kind).toSet(), {BudgetWarningKind.circularPercent});
    });

    test('90 split by amount, then switched to percent, gives no warning', () {
      var m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home', amountMilli: 90000),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', amountMilli: 10000),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', amountMilli: 10000, sortOrder: 1),
        BudgetNode(id: 'c', name: 'C', parentId: 'home', amountMilli: 10000, sortOrder: 2),
      ]);
      for (final id in ['a', 'b', 'c']) {
        m = m.replace(m.setAmount(id, 30000));
      }
      expect(m.warnings, isEmpty);
      for (final id in ['a', 'b', 'c']) {
        final n = m[id]!.node;
        m = m.replace(n.copyWith(mode: BudgetMode.percent));
      }
      expect([for (final id in ['a', 'b', 'c']) m[id]!.node.mode], everyElement(BudgetMode.percent));
      expect(m.warnings, isEmpty);
      expect(m['a']!.monthlyMilli, 30000);
      expect(m['home']!.childrenDeltaMilli, 0);
    });

    test('a real overshoot above the tolerance still warns', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'home', name: 'Home', amountMilli: 100000),
        BudgetNode(id: 'a', name: 'A', parentId: 'home', mode: BudgetMode.percent, percent: 50.0001),
        BudgetNode(id: 'b', name: 'B', parentId: 'home', mode: BudgetMode.percent, percent: 50, sortOrder: 1),
      ]);
      expect(m.warnings.map((w) => w.kind), contains(BudgetWarningKind.percentOver100));
    });
  });

  group('structure problems', () {
    test('orphans become roots, parent loops are cut', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'a', name: 'A', parentId: 'b', amountMilli: 1000),
        BudgetNode(id: 'b', name: 'B', parentId: 'a', amountMilli: 1000),
        BudgetNode(id: 'c', name: 'C', parentId: 'ghost', amountMilli: 2000),
      ]);
      final kinds = m.warnings.map((w) => w.kind).toList();
      expect(kinds, contains(BudgetWarningKind.orphanParent));
      expect(kinds, contains(BudgetWarningKind.circularParent));
      expect(m['c']!.parentId, isNull);
      expect(m.rootIds, containsAll(['a', 'c']));
      expect(m['b']!.parentId, 'a');
    });
  });

  group('currencies', () {
    test('foreign items convert with manual rates, half-up to the milli', () {
      final m = BudgetMath(
        const [
          BudgetNode(id: 'sub', name: 'Subscription', amountMilli: 9990, currency: 'USD'),
          BudgetNode(id: 'rent', name: 'Rent', amountMilli: 100000),
        ],
        settings: const BudgetSettings(ratesToBase: {'USD': 0.709}),
      );
      // 9.99 × 0.709 = 7.08291 → 7.083
      expect(m['sub']!.monthlyMilli, 7083);
      expect(m['sub']!.plannedMilli, 9990);
      expect(m.totalMonthlyMilli, 107083);
      expect(m.warnings, isEmpty);
    });

    test('a missing rate assumes 1:1 and warns once', () {
      final m = BudgetMath(const [
        BudgetNode(id: 'a', name: 'A', amountMilli: 1000, currency: 'EGP'),
        BudgetNode(id: 'b', name: 'B', amountMilli: 1000, currency: 'EGP'),
      ]);
      expect(m.totalMonthlyMilli, 2000);
      expect(m.warnings, [const BudgetWarning(BudgetWarningKind.missingRate, currency: 'EGP')]);
      final spend = m.spend([
        BudgetTx(budgetItemId: 'a', amountMilli: 500, date: DateTime(2026, 1, 2), currency: 'SYP'),
      ], BudgetWindow.month(DateTime(2026, 1, 1)));
      expect(spend.warnings.map((w) => w.currency), contains('SYP'));
      // Structural warnings are not polluted by spend().
      expect(m.warnings, hasLength(1));
    });
  });
}
