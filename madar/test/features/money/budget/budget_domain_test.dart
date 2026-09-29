import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/budget/budget.dart';

import 'budget_fixtures.dart';

BudgetTx tx(String? item, int milli, DateTime date, {String? currency, TxKind kind = TxKind.expense}) =>
    BudgetTx(budgetItemId: item, amountMilli: milli, date: date, currency: currency, kind: kind);

void main() {
  group('BudgetPlan', () {
    test('the spec example: totals, periods and shares', () {
      final plan = BudgetPlan(specMath());
      expect(plan.totalMonthlyMilli, 350000);
      expect(plan.totalWeeklyMilli, 87500);
      expect([for (final l in plan.lines) l.id], ['food', 'prot', 'spice', 'treat', 'fv', 'fuel', 'emerg', 'wife']);
      expect([for (final l in plan.lines) l.depth], [0, 1, 1, 1, 1, 0, 0, 0]);
      expect(plan['food']!.percentOfBase, closeTo(400 / 7, 1e-9));
      expect(plan['food']!.percentBase, PercentBase.total);
      expect(plan['prot']!.percentBase, PercentBase.parent);
      expect(plan['prot']!.percentOfBase, closeTo(50, 1e-12));
      expect(plan['prot']!.percentOfTotal, closeTo(200 / 7, 1e-9));
      expect(plan['spice']!.percentOfBase, closeTo(10, 1e-12));
      expect(plan['treat']!.percentOfBase, closeTo(15, 1e-12));
      expect(plan['fv']!.percentOfBase, closeTo(25, 1e-12));
      expect(plan['wife']!.plannedMilli, 5000);
      expect(plan['wife']!.monthlyMilli, 20000);
      expect(plan['wife']!.period, BudgetPeriod.weekly);
      expect(plan['food']!.childrenSumMilli, 200000);
      expect(plan['food']!.childrenDeltaMilli, 0);
      expect(plan.issues, isEmpty);
      expect(plan.pathOf('fv'), ['Home food', 'Fruit & vegetables']);
      expect([for (final l in plan.childrenOf('food')) l.id], ['prot', 'spice', 'treat', 'fv']);
      expect([for (final l in plan.roots) l.id], ['food', 'fuel', 'emerg', 'wife']);
    });

    test('children over / under the parent become ranked issues on the parent', () {
      final nodes = specNodes();
      final over = BudgetPlan(specMath([for (final n in nodes) n.id == 'spice' ? n.copyWith(amountMilli: 40000) : n]));
      expect(over['food']!.issues.single.kind, BudgetWarningKind.childrenOver);
      expect(over['food']!.issues.single.amountMilli, 20000);
      expect(over['food']!.worstSeverity, BudgetIssueSeverity.danger);
      final under = BudgetPlan(specMath([for (final n in nodes) n.id == 'spice' ? n.copyWith(amountMilli: 5000) : n]));
      expect(under['food']!.issues.single.kind, BudgetWarningKind.childrenUnder);
      expect(under['food']!.issues.single.amountMilli, 15000);
      expect(under['food']!.worstSeverity, BudgetIssueSeverity.warning);
      expect(under.dangerCount, 0);
    });

    test('overspending of the report window is attached to the item and its parent', () {
      final math = specMath();
      final report = math.spend([
        tx('prot', 112500, DateTime(2026, 9, 2)),
        tx('spice', 18000, DateTime(2026, 9, 3)),
        tx('fv', 90000, DateTime(2026, 9, 4)),
      ], BudgetWindow.month(DateTime(2026, 9, 29)));
      final plan = BudgetPlan(math, report: report);
      expect(plan['prot']!.issues.single.kind, BudgetWarningKind.overspent);
      expect(plan['prot']!.issues.single.amountMilli, 12500);
      expect(plan['fv']!.issues.single.amountMilli, 40000);
      expect(plan['food']!.issues.single.amountMilli, 20500);
      expect(plan['prot']!.spend!.spentMilli, 112500);
      expect(plan.issues.first.severity, BudgetIssueSeverity.danger);
      // Tree order within a severity.
      expect([for (final i in plan.issues) i.nodeId], ['food', 'prot', 'fv']);
    });

    test('percent over 100: an item itself vs the sub-items together vs the roots', () {
      final self = BudgetPlan(
        specMath([
          ...specNodes(),
          const BudgetNode(id: 'x', parentId: 'fuel', name: 'X', mode: BudgetMode.percent, percent: 150),
        ]),
      );
      final xi = self['x']!.issues.firstWhere((i) => i.kind == BudgetWarningKind.percentOver100);
      expect(xi.selfPercent, isTrue);
      final group = BudgetPlan(
        specMath([
          ...specNodes(),
          const BudgetNode(id: 'a', parentId: 'fuel', name: 'A', mode: BudgetMode.percent, percent: 60),
          const BudgetNode(id: 'b', parentId: 'fuel', name: 'B', mode: BudgetMode.percent, percent: 70),
        ]),
      );
      final gi = group['fuel']!.issues.firstWhere((i) => i.kind == BudgetWarningKind.percentOver100);
      expect(gi.selfPercent, isFalse);
      expect(gi.percent, closeTo(130, 1e-9));
      final roots = BudgetPlan(
        BudgetMath(const [
          BudgetNode(id: 'a', name: 'A', mode: BudgetMode.percent, percentOf: PercentBase.total, percent: 70),
          BudgetNode(id: 'b', name: 'B', mode: BudgetMode.percent, percentOf: PercentBase.total, percent: 40),
        ]),
      );
      expect(roots.globalIssues.single.kind, BudgetWarningKind.percentOver100);
      expect(roots.globalIssues.single.nodeId, isNull);
    });

    test('empty budget', () {
      final plan = BudgetPlan(BudgetMath(const []));
      expect(plan.isEmpty, isTrue);
      expect(plan.totalMonthlyMilli, 0);
      expect(plan.issues, isEmpty);
    });
  });

  group('BudgetEdits', () {
    test('switching mode keeps the effective amount', () {
      final math = specMath();
      final p = BudgetEdits.switchMode(math, 'prot', BudgetMode.percent);
      expect((p.mode, p.percent, p.amountMilli), (BudgetMode.percent, 50.0, 100000));
      final after = math.replace(p);
      expect(after['prot']!.plannedMilli, 100000);
      final back = BudgetEdits.switchMode(after, 'prot', BudgetMode.amount);
      expect((back.mode, back.amountMilli), (BudgetMode.amount, 100000));
      // A weekly root as a share of the total keeps 5.000 a week.
      final w = BudgetEdits.switchMode(math, 'wife', BudgetMode.percent);
      expect(w.percent, closeTo(40 / 7, 1e-12));
      final m2 = math.replace(w);
      expect(m2['wife']!.plannedMilli, 5000);
      expect(m2.totalMonthlyMilli, 350000);
    });

    test('moving keeps the amount; a percent item gets the matching percent of its new parent', () {
      final math = specMath();
      final treats = BudgetEdits.moveTo(math, 'treat', null);
      expect((treats.parentId, treats.amountMilli, treats.mode), (null, 30000, BudgetMode.amount));
      // Home food keeps its own 200, so the total grows to 380.
      expect(treats.percent, closeTo(30000 / 380000 * 100, 1e-9));
      final pct = math.replace(BudgetEdits.switchMode(math, 'prot', BudgetMode.percent));
      final moved = BudgetEdits.moveTo(pct, 'prot', 'fuel');
      expect((moved.parentId, moved.mode, moved.percentOf), ('fuel', BudgetMode.percent, PercentBase.parent));
      expect(moved.percent, closeTo(100, 1e-12));
      expect(pct.replace(moved)['prot']!.plannedMilli, 100000);
      final toRoot = BudgetEdits.moveTo(pct, 'prot', null);
      expect(toRoot.percentOf, PercentBase.total);
      expect(pct.replace(toRoot)['prot']!.monthlyMilli, 100000);
      expect(() => BudgetEdits.moveTo(math, 'food', 'prot'), throwsArgumentError);
    });

    test('percent base change keeps the amount', () {
      final math = specMath();
      final pct = math.replace(BudgetEdits.switchMode(math, 'prot', BudgetMode.percent));
      final ofTotal = BudgetEdits.setPercentBase(pct, 'prot', PercentBase.total);
      expect(ofTotal.percent, closeTo(200 / 7, 1e-9));
      expect(pct.replace(ofTotal)['prot']!.plannedMilli, 100000);
    });

    test('subtree, parent candidates and sibling placement', () {
      final math = specMath();
      expect(BudgetEdits.subtree(math, 'food'), ['food', 'prot', 'spice', 'treat', 'fv']);
      expect(BudgetEdits.subtree(math, 'nope'), isEmpty);
      expect([for (final r in BudgetEdits.parentCandidates(math, 'food')) r.node.id], ['fuel', 'emerg', 'wife']);
      expect(BudgetEdits.siblings(math, 'spice'), ['prot', 'spice', 'treat', 'fv']);
      expect(BudgetEdits.placeAfter(['a', 'b', 'c', 'n'], 'n', 'a'), ['a', 'n', 'b', 'c']);
      expect(BudgetEdits.placeAfter(['a', 'b'], 'n', 'zz'), ['a', 'b']);
    });
  });

  group('BudgetDraft', () {
    test('typing an amount shows the percent; typing a percent shows the amount', () {
      final d = BudgetDraft.edit(specMath(), 'prot');
      expect(d.mode, BudgetDraftMode.amount);
      expect(d.percent, closeTo(50, 1e-12));
      final a = d.withAmount(80000);
      expect(a.percent, closeTo(40, 1e-12));
      expect(a.percentOfTotal, closeTo(80 / 350 * 100, 1e-9));
      expect(a.warnings.single.kind, BudgetWarningKind.childrenUnder);
      expect(a.warnings.single.amountMilli, 20000);
      final p = a.withPercent(25);
      expect(p.mode, BudgetDraftMode.percent);
      expect(p.amountMilli, 50000);
      expect(p.toSave.amountMilli, 50000);
      expect(p.dirty, isTrue);
      expect(d.dirty, isFalse);
    });

    test('mode switches and percent base changes keep the amount', () {
      final d = BudgetDraft.edit(specMath(), 'prot').withMode(BudgetDraftMode.percent);
      expect((d.percent, d.amountMilli), (50.0, 100000));
      final t = d.withPercentBase(PercentBase.total);
      expect(t.percent, closeTo(200 / 7, 1e-9));
      expect(t.amountMilli, 100000);
      expect(t.withMode(BudgetDraftMode.amount).amountMilli, 100000);
    });

    test('period and currency keep the typed number', () {
      final d = BudgetDraft.edit(specMath(), 'fuel');
      final w = d.withPeriod(BudgetPeriod.weekly);
      expect((w.amountMilli, w.monthlyMilli, w.weeklyMilli), (100000, 400000, 100000));
      expect(w.percent, closeTo(400 / 650 * 100, 1e-9));
      final usd = d.withCurrency('USD');
      expect((usd.currency, usd.amountMilli, usd.monthlyMilli), ('USD', 100000, 70900));
      expect(usd.withCurrency('JOD').node.currency, isNull);
    });

    test('sum mode adopts the sub-items total', () {
      final d = BudgetDraft.edit(specMath(), 'food');
      final s = d.withMode(BudgetDraftMode.sum);
      expect(s.mode, BudgetDraftMode.sum);
      expect(s.node.amountMilli, isNull);
      expect(s.monthlyMilli, 200000);
      expect(s.withMode(BudgetDraftMode.amount).node.amountMilli, 200000);
      // A leaf cannot be the sum of nothing.
      final leaf = BudgetDraft.edit(specMath(), 'fuel');
      expect(identical(leaf.withMode(BudgetDraftMode.sum), leaf), isTrue);
    });

    test('a new sub-item previews its effect on the parent', () {
      final n = BudgetDraft.create(specMath(), id: 'nuts', parentId: 'food', name: '  Nuts ');
      expect(n.isNew, isTrue);
      expect(n.percentBase, PercentBase.parent);
      final a = n.withAmount(10000);
      expect(a.percent, closeTo(5, 1e-12));
      expect(a.warnings.single.kind, BudgetWarningKind.childrenOver);
      expect(a.warnings.single.amountMilli, 10000);
      expect(a.totalMonthlyMilli, 350000);
      expect(a.toSave.name, 'Nuts');
      expect(a.toSave.percent, closeTo(5, 1e-12));
      final root = BudgetDraft.create(specMath(), id: 'save', name: 'Savings').withPercent(10);
      expect(root.percentBase, PercentBase.total);
      // T = 350 / 0.9 = 388.888…, 10 % of it.
      expect(root.amountMilli, 38889);
      expect(root.totalMonthlyMilli, 388889);
      expect(BudgetDraft.create(specMath(), id: 'e').nameValid, isFalse);
    });

    test('moving the draft under another parent keeps the amount', () {
      final d = BudgetDraft.edit(specMath(), 'treat').withParent('fuel');
      expect(d.node.parentId, 'fuel');
      expect(d.amountMilli, 30000);
      expect(d.percent, closeTo(30, 1e-12));
      expect(d.parent!.node.id, 'fuel');
      expect(d.warnings.map((w) => w.kind), contains(BudgetWarningKind.childrenUnder));
    });
  });

  group('BudgetPeriods', () {
    test('days, elapsed days and shifts', () {
      final sep = BudgetWindow.month(DateTime(2026, 9, 29));
      expect(BudgetPeriods.days(sep), 30);
      expect(BudgetPeriods.days(BudgetWindow.month(DateTime(2028, 2, 3))), 29);
      expect(BudgetPeriods.elapsedDays(sep, DateTime(2026, 9, 29, 23)), 29);
      expect(BudgetPeriods.elapsedDays(sep, DateTime(2026, 8, 31)), 0);
      expect(BudgetPeriods.elapsedDays(sep, DateTime(2026, 10, 2)), 30);
      expect(BudgetPeriods.shift(BudgetWindow.month(DateTime(2026, 1, 5)), -1).start, DateTime(2025, 12));
      final week = BudgetPeriods.containing(BudgetPeriod.weekly, DateTime(2026, 9, 29));
      expect(week.start, DateTime(2026, 9, 26)); // Saturday
      expect(BudgetPeriods.days(week), 7);
      expect(BudgetPeriods.shift(week, -2).start, DateTime(2026, 9, 12));
      expect(BudgetPeriods.isCurrent(week, DateTime(2026, 9, 29, 22)), isTrue);
    });

    test('projection is exact and only reliable after a fifth of the period', () {
      final sep = BudgetWindow.month(DateTime(2026, 9, 1));
      expect(BudgetPeriods.project(29000, sep, DateTime(2026, 9, 10)), 87000);
      expect(BudgetPeriods.project(1000, sep, DateTime(2026, 9, 7)), 4286); // 30/7
      expect(BudgetPeriods.project(1000, sep, DateTime(2026, 8, 7)), isNull);
      expect(BudgetPeriods.project(1234, sep, DateTime(2026, 11, 7)), 1234);
      expect(BudgetPeriods.projectionReliable(sep, DateTime(2026, 9, 5)), isFalse);
      expect(BudgetPeriods.projectionReliable(sep, DateTime(2026, 9, 6)), isTrue);
    });
  });

  group('BudgetSpending', () {
    final txs = [
      tx('prot', 112500, DateTime(2026, 9, 2)),
      tx('spice', 18250, DateTime(2026, 9, 8)),
      tx('fuel', 20000, DateTime(2026, 9, 3)),
      tx(null, 19990, DateTime(2026, 9, 4), currency: 'USD'),
      tx('fuel', 91000, DateTime(2026, 8, 10)),
      tx('prot', 50000, DateTime(2026, 8, 6)),
      tx('prot', 999999, DateTime(2026, 9, 1), kind: TxKind.income),
    ];

    test('spend vs plan, statuses and the unassigned spend', () {
      final s = BudgetSpending.build(
        math: specMath(),
        transactions: txs,
        window: BudgetWindow.month(DateTime(2026, 9, 1)),
        today: DateTime(2026, 9, 29),
      );
      expect(s.plannedMilli, 350000);
      expect(s.spentMilli, 150750);
      expect(s.remainingMilli, 199250);
      expect(s.unassignedMilli, 14173); // 19.99 USD × 0.709
      expect(s.line('prot')!.status, SpendStatus.over);
      expect(s.line('prot')!.remainingMilli, -12500);
      expect(s.line('spice')!.status, SpendStatus.near);
      expect(s.line('food')!.spentMilli, 130750);
      expect(s.line('fuel')!.status, SpendStatus.calm);
      expect(s.line('emerg')!.status, SpendStatus.calm);
      expect(s.line('wife')!.plannedMilli, 20000);
      expect(s.projectedMilli, (150750 * 30 / 29).round());
      expect(s.projectionReliable, isTrue);
      expect(s.isCurrent, isTrue);
      expect((s.days, s.elapsedDays), (30, 29));
      expect([for (final l in s.overspent) l.id], ['prot']);
      expect(s.history, hasLength(6));
      expect(s.history.last.spentMilli, 150750);
      expect(s.history[4].window.start, DateTime(2026, 8));
      expect(s.history[4].spentMilli, 141000);
      expect(s.history[4].overspentItems, 0);
      expect(s.history.last.overspentItems, 1);
    });

    test('a weekly window plans weekly amounts', () {
      final s = BudgetSpending.build(
        math: specMath(),
        transactions: txs,
        window: BudgetPeriods.containing(BudgetPeriod.weekly, DateTime(2026, 9, 3)),
        today: DateTime(2026, 9, 29),
        historyCount: 8,
      );
      expect(s.window.start, DateTime(2026, 8, 29));
      expect(s.plannedMilli, 87500);
      expect(s.line('wife')!.plannedMilli, 5000);
      expect(s.line('fuel')!.spentMilli, 20000);
      expect(s.isPast, isTrue);
      expect(s.projectedMilli, s.spentMilli);
      expect(s.history, hasLength(8));
    });

    test('status thresholds', () {
      expect(BudgetSpending.statusOf(plannedMilli: 0, spentMilli: 0), SpendStatus.idle);
      expect(BudgetSpending.statusOf(plannedMilli: 0, spentMilli: 1), SpendStatus.unplanned);
      expect(BudgetSpending.statusOf(plannedMilli: 100, spentMilli: 101), SpendStatus.over);
      expect(BudgetSpending.statusOf(plannedMilli: 100, spentMilli: 85), SpendStatus.near);
      expect(BudgetSpending.statusOf(plannedMilli: 100, spentMilli: 50, projectedMilli: 120), SpendStatus.atRisk);
      expect(BudgetSpending.statusOf(plannedMilli: 100, spentMilli: 50, projectedMilli: 90), SpendStatus.calm);
    });
  });

  group('BudgetSearch', () {
    test('folds Arabic variants and digits', () {
      expect(BudgetSearch.fold('أُسرة'), 'اسره');
      expect(BudgetSearch.fold('فاتورة ٥'), 'فاتوره 5');
      expect(BudgetSearch.fold('  Fuel '), 'fuel');
    });

    test('keeps the ancestors of every match', () {
      final tree = [for (final n in specMath().flattened) (id: n.node.id, parentId: n.parentId, name: n.node.name)];
      expect(BudgetSearch.filter(tree, ''), hasLength(8));
      expect(BudgetSearch.filter(tree, 'spi'), ['food', 'spice']);
      expect(BudgetSearch.filter(tree, 'FOOD'), ['food']);
      expect(BudgetSearch.filter(tree, 'zzz'), isEmpty);
    });
  });
}
