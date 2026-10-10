// Adversarial review of the Money domain (pure Dart): exact milli-unit
// math, transfers across currencies, re-basing, nested budget
// recalculation, spend windows, obligations, debts, jars and reminders.
// Each case pins a behaviour the review checked by hand.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/domain/debt_ledger.dart';
import 'package:madar/features/money/goals/domain/due_dates.dart';
import 'package:madar/features/money/goals/domain/due_reminders.dart';
import 'package:madar/features/money/goals/domain/goals_rates.dart';
import 'package:madar/features/money/goals/domain/jar_plan.dart';
import 'package:madar/features/money/goals/domain/obligation_plan.dart';
import 'package:madar/features/money/ledger/ledger.dart';

LedgerRates _rates() => LedgerRates.of(const [
  LedgerCurrency(code: 'JOD', decimals: 3, isBase: true),
  LedgerCurrency(code: 'USD', decimals: 2, rateToBase: 0.709),
  LedgerCurrency(code: 'EGP', decimals: 2, rateToBase: 0.0145),
  LedgerCurrency(code: 'SYP', decimals: 0, rateToBase: 0.0000545),
  LedgerCurrency(code: 'LYD', decimals: 3, rateToBase: 0.13),
]);

void main() {
  group('ledger: transfers', () {
    final day = DateTime(2026, 9, 29);
    String? currencyOf(String id) => const {'cash': 'JOD', 'bank': 'JOD', 'usd': 'USD', 'egp': 'EGP'}[id];

    test('editing the amount of a same-currency transfer moves the new amount into the destination', () {
      final stored = TxWrite.of(
        TxDraft(kind: TxKind.transfer, walletId: 'cash', toWalletId: 'bank', amountMilli: 100000, date: day),
        currencyOf: currencyOf,
        rates: _rates(),
      )!;
      final tx = LedgerTx(
        id: 't1',
        walletId: stored.walletId,
        kind: stored.kind,
        amountMilli: stored.amountMilli,
        date: stored.date,
        toWalletId: stored.toWalletId,
        toAmountMilli: stored.toAmountMilli,
      );
      // The sheet opens the stored entry and the user types 150.
      final edited = TxWrite.of(
        TxDraft.fromTx(tx).copyWith(amountMilli: 150000),
        currencyOf: currencyOf,
        rates: _rates(),
      )!;
      expect(edited.amountMilli, 150000);
      expect(edited.toAmountMilli, 150000, reason: 'a same-currency transfer cannot lose or create money');
      final wallets = [
        const LedgerWallet(id: 'cash', name: 'Cash', currency: 'JOD', openingMilli: 500000),
        const LedgerWallet(id: 'bank', name: 'Bank', currency: 'JOD'),
      ];
      final after = LedgerTx(
        id: 't1',
        walletId: 'cash',
        kind: TxKind.transfer,
        amountMilli: edited.amountMilli,
        date: day,
        toWalletId: 'bank',
        toAmountMilli: edited.toAmountMilli,
      );
      final b = LedgerMath.balances(wallets, [after]);
      expect(b['cash']! + b['bank']!, 500000, reason: 'the JOD total is unchanged by a transfer');
    });

    test('USD → JOD at 0.709 and JOD → EGP round to the destination minor unit, exactly', () {
      final toJod = TxWrite.of(
        TxDraft(kind: TxKind.transfer, walletId: 'usd', toWalletId: 'cash', amountMilli: 100000, date: day),
        currencyOf: currencyOf,
        rates: _rates(),
        decimalsOf: (c) => c == 'JOD' ? 3 : 2,
      )!;
      expect(toJod.toAmountMilli, 70900);
      final toEgp = TxWrite.of(
        TxDraft(kind: TxKind.transfer, walletId: 'cash', toWalletId: 'egp', amountMilli: 1000, date: day),
        currencyOf: currencyOf,
        rates: _rates(),
        decimalsOf: (c) => c == 'JOD' ? 3 : 2,
      )!;
      // 1 JOD / 0.0145 = 68.9655… EGP → 68.97 EGP (cents).
      expect(toEgp.toAmountMilli, 68970);
    });

    test('editing what a cross-currency transfer sent keeps its own rate for what arrived', () {
      // 100 USD arrived as 70.500 JOD at the exchange shop (not the 0.709
      // set today); 110 USD sent → 77.550 JOD, rounded once to the fils.
      expect(TxDraft.rescaleReceived(sentMilli: 100000, receivedMilli: 70500, newSentMilli: 110000), 77550);
      // To cents: 1 JOD → 1.41 USD stored; 3 JOD → 4.23 USD.
      expect(TxDraft.rescaleReceived(sentMilli: 1000, receivedMilli: 1410, newSentMilli: 3000, toDecimals: 2), 4230);
      expect(TxDraft.rescaleReceived(sentMilli: 3000, receivedMilli: 1000, newSentMilli: 1000, toDecimals: 0), 0);
      expect(TxDraft.rescaleReceived(sentMilli: 3000, receivedMilli: 1000, newSentMilli: 1500, toDecimals: 0), 1000);
    });

    test('a transfer without a rate is refused, never assumed 1:1', () {
      final errors = TxDraft(
        kind: TxKind.transfer,
        walletId: 'cash',
        toWalletId: 'eur',
        amountMilli: 1000,
        date: day,
      ).validate(currencyOf: (id) => id == 'eur' ? 'EUR' : 'JOD', rates: _rates());
      expect(errors, contains(TxDraftError.noRate));
    });
  });

  group('Arabic-Indic amounts', () {
    test('group thousands with a narrow no-break space: the decimal comma is the only comma', () {
      const f = LedgerMoneyFormat(arabic: true, arabicIndic: true);
      final s = f.amount(1878750, 'JOD');
      expect(s, startsWith('١\u202F٨٧٨٫٧٥٠'));
      expect(s, isNot(contains('\u066C')));
      expect(f.amount(26896550, 'EGP'), startsWith('٢٦\u202F٨٩٦٫٥٥'));
      // Western digits keep their comma.
      expect(const LedgerMoneyFormat(arabic: true, arabicIndic: false).amount(1878750, 'JOD'), startsWith('1,878.750'));
      // Every Money parser reads it back.
      expect(MoneyText.canonicalDecimal('١\u202F٨٧٨٫٧٥٠'), '1878.750');
    });
  });

  group('ledger: re-basing keeps every total', () {
    test('JOD → USD → JOD returns to the typed rates and the same totals', () {
      const currencies = [
        LedgerCurrency(code: 'JOD', decimals: 3, isBase: true),
        LedgerCurrency(code: 'USD', decimals: 2, rateToBase: 0.709),
        LedgerCurrency(code: 'EGP', decimals: 2, rateToBase: 0.0145),
        LedgerCurrency(code: 'SYP', decimals: 0, rateToBase: 0.0000545),
      ];
      const wallets = [
        LedgerWallet(id: 'a', name: 'A', currency: 'JOD', openingMilli: 1234567),
        LedgerWallet(id: 'b', name: 'B', currency: 'USD', openingMilli: 999990),
        LedgerWallet(id: 'c', name: 'C', currency: 'EGP', openingMilli: 20000000),
        LedgerWallet(id: 'd', name: 'D', currency: 'SYP', openingMilli: 13000000000),
      ];
      final before = LedgerTotals.of(wallets, const {}, LedgerRates.of(currencies));
      final plan = RebasePlan.of(currencies, 'USD')!;
      final usd = [
        for (final c in currencies) c.copyWith(isBase: c.code == 'USD', rateToBase: plan.row(c.code)!.stored),
      ];
      final inUsd = LedgerTotals.of(wallets, const {}, LedgerRates.of(usd));
      // The same wealth, expressed in USD (to the milli of a cent).
      expect(
        (Rational.fromInt(inUsd.baseMilli) * Rational.fromNum(0.709) - Rational.fromInt(before.baseMilli)).abs() <=
            Rational.fromInt(1),
        isTrue,
        reason: '${inUsd.baseMilli} USD vs ${before.baseMilli} JOD',
      );
      final back = RebasePlan.of(usd, 'JOD')!;
      for (final c in currencies) {
        expect(back.row(c.code)!.stored, c.isBase ? 1.0 : c.rateToBase, reason: c.code);
      }
    });
  });

  group('ledger: balances with goals-linked entries', () {
    test('jar, debt and obligation entries move wallet balances exactly once', () {
      const cash = LedgerWallet(id: 'cash', name: 'Cash', currency: 'JOD', openingMilli: 300000);
      const bank = LedgerWallet(id: 'bank', name: 'Bank', currency: 'JOD', openingMilli: 1500000);
      final d = DateTime(2026, 9, 15);
      final txs = [
        LedgerTx(id: 'jar-tx-1', walletId: 'bank', kind: TxKind.adjustment, amountMilli: -300000, date: d),
        LedgerTx(id: 'debt-open-tx-2', walletId: 'cash', kind: TxKind.adjustment, amountMilli: -75000, date: d),
        LedgerTx(id: 'debt-tx-3', walletId: 'cash', kind: TxKind.adjustment, amountMilli: 25000, date: d),
        LedgerTx(id: 'ob-tx-4', walletId: 'bank', kind: TxKind.expense, amountMilli: 25000, date: d),
        LedgerTx(id: 'x', walletId: 'bank', kind: TxKind.adjustment, amountMilli: 1, date: d),
      ];
      final b = LedgerMath.balances([cash, bank], txs);
      expect(b, {'cash': 250000, 'bank': 1175001});
      expect(LedgerMath.runningBalances(bank, txs).values.last, 1175001);
    });
  });

  group('budget: amount / percent recalculation', () {
    BudgetMath math(List<BudgetNode> nodes, {num wpm = 4, Map<String, num> rates = const {}}) => BudgetMath(
      nodes,
      settings: BudgetSettings(weeksPerMonth: wpm, ratesToBase: rates),
    );

    final spec = [
      const BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000),
      const BudgetNode(id: 'p', name: 'Proteins', parentId: 'food', amountMilli: 100000),
      const BudgetNode(id: 's', name: 'Spices', parentId: 'food', amountMilli: 20000, sortOrder: 1),
      const BudgetNode(id: 't', name: 'Treats', parentId: 'food', amountMilli: 30000, sortOrder: 2),
      const BudgetNode(id: 'f', name: 'Fruit & vegetables', parentId: 'food', amountMilli: 50000, sortOrder: 3),
      const BudgetNode(id: 'fuel', name: 'Car fuel', amountMilli: 100000, sortOrder: 1),
      const BudgetNode(id: 'em', name: 'Emergency', amountMilli: 30000, sortOrder: 2),
      const BudgetNode(id: 'w', name: 'Allowance', amountMilli: 5000, period: BudgetPeriod.weekly, sortOrder: 3),
    ];

    test('weekly → monthly follows weeks-per-month exactly (4 and 4.345)', () {
      expect(math(spec).totalMonthlyMilli, 350000);
      final m = math(spec, wpm: 4.345);
      expect(m['w']!.monthlyMilli, 21725);
      expect(m.totalMonthlyMilli, 351725);
      expect(m.totalWeeklyMilli, (Rational.fromInt(351725) / Rational.fromNum(4.345)).roundHalfUp());
      expect(m['w']!.percentOfTotal, closeTo(21725 / 351725 * 100, 1e-9));
    });

    test('switching Proteins to 60 % of its parent recalculates the amount and warns the parent', () {
      final m = math(spec);
      final p = m.setPercent('p', 60);
      expect(p.amountMilli, 120000);
      final next = m.replace(p);
      expect(next['food']!.childrenSumMilli, 220000);
      expect(
        next.warnings,
        contains(const BudgetWarning(BudgetWarningKind.childrenOver, nodeId: 'food', amountMilli: 20000)),
      );
      // Back to an amount: the percent follows.
      final back = next.setAmount('p', 100000);
      expect(back.percent, closeTo(50, 1e-12));
      expect(next.replace(back).warnings, isEmpty);
    });

    test('changing the parent live-recalculates every percent child (nested percent of parent)', () {
      final nodes = [
        const BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000),
        const BudgetNode(id: 'p', name: 'P', parentId: 'food', mode: BudgetMode.percent, percent: 50),
        const BudgetNode(id: 'pp', name: 'PP', parentId: 'p', mode: BudgetMode.percent, percent: 10),
        const BudgetNode(id: 'r', name: 'R', parentId: 'food', mode: BudgetMode.percent, percent: 50, sortOrder: 1),
      ];
      final m = math(nodes);
      expect(m['pp']!.monthlyMilli, 10000);
      final bigger = m.replace(m.setAmount('food', 300000));
      expect(bigger['p']!.monthlyMilli, 150000);
      expect(bigger['pp']!.monthlyMilli, 15000);
      expect(bigger['r']!.plannedMilli, 150000);
      // pp alone under p: p's children fall short of p.
      expect(bigger.warnings.where((w) => w.kind == BudgetWarningKind.childrenUnder).single.nodeId, 'p');
    });

    test('percent of the total nested under a parent solves the circular total (T = A / (1 − p))', () {
      final nodes = [
        const BudgetNode(id: 'fixed', name: 'Fixed'), // sum of its children
        const BudgetNode(id: 'rent', name: 'Rent', parentId: 'fixed', amountMilli: 300000),
        const BudgetNode(
          id: 'save',
          name: 'Savings',
          parentId: 'fixed',
          mode: BudgetMode.percent,
          percent: 10,
          percentOf: PercentBase.total,
          sortOrder: 1,
        ),
      ];
      final m = math(nodes);
      expect(m.totalMonthlyMilli, 333333);
      expect(m['save']!.monthlyMilli, 33333);
      expect(m['save']!.percentOfTotal, closeTo(10, 1e-9));
      expect(m['fixed']!.derivedFromChildren, isTrue);
      expect(m.warnings, isEmpty);
    });

    test('a weekly percent child of a monthly parent shows its weekly share', () {
      final nodes = [
        const BudgetNode(id: 'a', name: 'A', amountMilli: 200000),
        const BudgetNode(
          id: 'b',
          name: 'B',
          parentId: 'a',
          mode: BudgetMode.percent,
          percent: 25,
          period: BudgetPeriod.weekly,
        ),
      ];
      final m = math(nodes);
      expect(m['b']!.monthlyMilli, 50000);
      expect(m['b']!.plannedMilli, 12500);
    });

    test('an item in USD converts at the manual rate (exactly)', () {
      final m = math(
        [
          const BudgetNode(id: 'a', name: 'Ads', amountMilli: 100000, currency: 'USD'),
          const BudgetNode(id: 'b', name: 'Rent', amountMilli: 29100, sortOrder: 1),
        ],
        rates: const {'USD': 0.709},
      );
      expect(m['a']!.monthlyMilli, 70900);
      expect(m.totalMonthlyMilli, 100000);
      expect(m['a']!.percentOfTotal, closeTo(70.9, 1e-12));
    });

    test('over 100 %: one item, siblings together, and percent-of-total roots', () {
      final m = math([
        const BudgetNode(id: 'a', name: 'A', amountMilli: 100000),
        const BudgetNode(id: 'x', name: 'X', parentId: 'a', mode: BudgetMode.percent, percent: 70),
        const BudgetNode(id: 'y', name: 'Y', parentId: 'a', mode: BudgetMode.percent, percent: 40, sortOrder: 1),
        const BudgetNode(
          id: 'z',
          name: 'Z',
          mode: BudgetMode.percent,
          percent: 120,
          percentOf: PercentBase.total,
          sortOrder: 2,
        ),
      ]);
      final kinds = [for (final w in m.warnings) (w.kind, w.nodeId)];
      expect(kinds, contains((BudgetWarningKind.percentOver100, 'a')));
      expect(kinds, contains((BudgetWarningKind.percentOver100, 'z')));
      expect(kinds, contains((BudgetWarningKind.percentOver100, null)));
      expect(kinds, contains((BudgetWarningKind.childrenOver, 'a')));
    });

    test('overspent counts children for their parents and converts foreign expenses', () {
      final m = math(spec, rates: const {'USD': 0.709});
      final sep = BudgetWindow.month(DateTime(2026, 9, 1));
      final r = m.spend([
        BudgetTx(budgetItemId: 'p', amountMilli: 90000, date: DateTime(2026, 9, 30)),
        BudgetTx(budgetItemId: 's', amountMilli: 100000, currency: 'USD', date: DateTime(2026, 9, 1)),
        // Outside the window on both sides.
        BudgetTx(budgetItemId: 'p', amountMilli: 1000000, date: DateTime(2026, 8, 31)),
        BudgetTx(budgetItemId: 'p', amountMilli: 1000000, date: DateTime(2026, 10, 1)),
        // Income never counts.
        BudgetTx(budgetItemId: 'p', amountMilli: 1000000, date: DateTime(2026, 9, 2), kind: TxKind.income),
      ], sep);
      expect(r.byId['s']!.spentMilli, 70900);
      expect(r.byId['food']!.spentMilli, 160900);
      expect(r.byId['s']!.overspent, isTrue);
      expect(r.byId['food']!.overspent, isFalse);
      expect(r.totalSpentMilli, 160900);
      expect(r.warnings.single.nodeId, 's');
      expect(r.warnings.single.amountMilli, 50900);
    });
  });

  group('budget: legend shares', () {
    test('largest remainder: the legend adds up to exactly 100 %', () {
      // Spec: 200 / 100 / 30 / 20 of 350 – rounded alone 57 + 29 + 9 + 6 = 101.
      expect(BudgetShares.largestRemainder([200000, 100000, 30000, 20000]), [57.1, 28.6, 8.6, 5.7]);
      expect(BudgetShares.largestRemainder([200000, 100000, 30000, 20000], decimals: 0), [57, 29, 8, 6]);
      final thirds = BudgetShares.largestRemainder([1, 1, 1]);
      expect(thirds, [33.4, 33.3, 33.3]);
      expect(BudgetShares.largestRemainder([0, 5]), [0, 100]);
      expect(BudgetShares.largestRemainder([0, 0]), isEmpty);
      for (final parts in [
        [1, 2, 3, 4, 5, 6, 7],
        [999, 1, 1, 1],
        [123457, 98765, 4321, 1],
      ]) {
        final shares = BudgetShares.largestRemainder(parts);
        final sum = shares.fold<int>(0, (a, s) => a + (s * 10).round());
        expect(sum, 1000, reason: '$parts → $shares');
      }
    });
  });

  group('goals: wallet amounts', () {
    test('what a goal writes into a wallet is a whole number of its minor unit', () {
      final rates = GoalsRates(
        base: 'JOD',
        currencies: const [
          GoalsCurrency(code: 'USD', rateToBase: 0.709, decimals: 2),
          GoalsCurrency(code: 'SYP', rateToBase: 0.0000545, decimals: 0),
        ],
      );
      expect(rates.convertToMinor(100000, 'JOD', 'USD'), 141040);
      expect(rates.convertToMinor(150000, 'JOD', 'USD'), 211570);
      expect(rates.convertToMinor(100000, 'USD', 'JOD'), 70900);
      expect(rates.convertToMinor(1000, 'JOD', 'SYP'), 18349000);
      expect(rates.convertToMinor(12345, 'USD', 'USD'), 12345);
    });
  });

  group('budget: spend windows', () {
    test('weeks start on the chosen day and cross month and year ends', () {
      final w = BudgetWindow.week(DateTime(2026, 12, 31), weekStart: DateTime.saturday);
      expect(w.start, DateTime(2026, 12, 26));
      expect(w.end, DateTime(2027, 1, 2));
      final mon = BudgetWindow.week(DateTime(2027, 1, 3), weekStart: DateTime.monday);
      expect(mon.start, DateTime(2026, 12, 28));
      final sun = BudgetWindow.week(DateTime(2026, 10, 4), weekStart: DateTime.sunday);
      expect(sun.start, DateTime(2026, 10, 4));
      expect(BudgetPeriods.days(sun), 7);
      expect(BudgetPeriods.days(BudgetWindow.month(DateTime(2028, 2, 10))), 29);
      expect(BudgetPeriods.shift(BudgetWindow.month(DateTime(2026, 1, 31)), 1).start, DateTime(2026, 2));
    });

    test('a weekly plan and a weekly window agree (5/week allowance)', () {
      final m = BudgetMath([
        const BudgetNode(id: 'w', name: 'Allowance', amountMilli: 5000, period: BudgetPeriod.weekly),
      ]);
      final week = BudgetWindow.week(DateTime(2026, 9, 29));
      final r = m.spend([BudgetTx(budgetItemId: 'w', amountMilli: 6000, date: DateTime(2026, 9, 26))], week);
      expect(r.byId['w']!.plannedMilli, 5000);
      expect(r.byId['w']!.overspent, isTrue);
    });

    test('projection is exact and absent before the period starts', () {
      final sep = BudgetWindow.month(DateTime(2026, 9, 1));
      expect(BudgetPeriods.project(100000, sep, DateTime(2026, 9, 10)), 300000);
      expect(BudgetPeriods.project(100000, sep, DateTime(2026, 8, 31)), isNull);
      expect(BudgetPeriods.project(100000, sep, DateTime(2026, 10, 5)), 100000);
    });
  });

  group('obligations: next due', () {
    DateTime pay(Recurrence f, DateTime due, List<DateTime> history, {int interval = 1}) => ObligationState.compute(
      frequency: f,
      interval: interval,
      nextDue: due,
      today: due,
      history: history,
    ).advance().nextDue;

    test('the 31st clamps through February (leap and common) and comes back', () {
      final chain = <DateTime>[DateTime(2027, 12, 31)];
      for (var i = 0; i < 4; i++) {
        chain.add(pay(Recurrence.monthly, chain.last, chain.sublist(0, chain.length - 1)));
      }
      expect(chain, [
        DateTime(2027, 12, 31),
        DateTime(2028, 1, 31),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 31),
        DateTime(2028, 4, 30),
      ]);
      expect(pay(Recurrence.monthly, DateTime(2028, 4, 30), chain.sublist(0, 4)), DateTime(2028, 5, 31));
    });

    test('the 30th stays the 30th after February', () {
      final feb = pay(Recurrence.monthly, DateTime(2027, 1, 30), const []);
      expect(feb, DateTime(2027, 2, 28));
      expect(pay(Recurrence.monthly, feb, [DateTime(2027, 1, 30)]), DateTime(2027, 3, 30));
    });

    test('yearly Feb 29 returns in the next leap year; intervals step whole periods', () {
      var d = DateTime(2028, 2, 29);
      final hist = <DateTime>[];
      final seen = <DateTime>[];
      for (var i = 0; i < 4; i++) {
        final n = pay(Recurrence.yearly, d, hist);
        hist.add(d);
        d = n;
        seen.add(n);
      }
      expect(seen, [DateTime(2029, 2, 28), DateTime(2030, 2, 28), DateTime(2031, 2, 28), DateTime(2032, 2, 29)]);
      expect(pay(Recurrence.monthly, DateTime(2026, 11, 30), const [], interval: 3), DateTime(2027, 2, 28));
      expect(pay(Recurrence.weekly, DateTime(2026, 12, 29), const [], interval: 2), DateTime(2027, 1, 12));
    });

    test('periods due count whole missed periods', () {
      final s = ObligationState.compute(
        frequency: Recurrence.monthly,
        interval: 1,
        nextDue: DateTime(2026, 7, 31),
        today: DateTime(2026, 9, 30),
      );
      expect(s.periodsDue, 3); // Jul 31, Aug 31, Sep 30
      expect(s.overdue, isTrue);
    });

    test('monthly share: weekly × weeks-per-month, yearly ÷ 12 (exact)', () {
      expect(
        ObligationTotals.monthlyShare(10000, const RecurrenceRule(Recurrence.weekly), weeksPerMonth: 4.345),
        Rational.fromInt(43450),
      );
      expect(ObligationTotals.monthlyShare(100000, const RecurrenceRule(Recurrence.yearly)).roundHalfUp(), 8333);
    });
  });

  group('debts', () {
    test('partial payments: remaining, settled when covered, overpaid', () {
      final today = DateTime(2026, 9, 29);
      DebtState s(List<int> pays) => DebtState.compute(
        direction: DebtDirection.owedToMe,
        currency: 'JOD',
        amountMilli: 100000,
        payments: [for (final p in pays) DebtPaymentIn(p, today)],
        today: today,
        dueDate: DateTime(2026, 9, 27),
      );
      expect(s([30000]).remainingMilli, 70000);
      expect(s([30000]).overdue, isTrue);
      expect(s([30000, 30000, 40000]).settled, isTrue);
      expect(s([30000, 30000, 40000]).overdue, isFalse);
      expect(s([60000, 60000]).overpaidMilli, 20000);
      expect(s([30000]).paysOff(70000), isTrue);
      expect(s([30000]).paysOff(69999), isFalse);
    });

    test('totals per direction convert exactly and round once', () {
      final today = DateTime(2026, 9, 29);
      final rates = GoalsRates(
        base: 'JOD',
        currencies: const [GoalsCurrency(code: 'USD', rateToBase: 0.709, decimals: 2)],
      );
      DebtState d(DebtDirection dir, int milli, String cur) =>
          DebtState.compute(direction: dir, currency: cur, amountMilli: milli, payments: const [], today: today);
      final t = DebtTotals.of([
        d(DebtDirection.iOwe, 10, 'USD'), // 0.00709 JOD
        d(DebtDirection.iOwe, 10, 'USD'),
        d(DebtDirection.iOwe, 10, 'USD'),
        d(DebtDirection.owedToMe, 75000, 'JOD'),
      ], rates);
      expect(t.iOweBaseMilli, 21); // 21.27 → 21, not 3 × 7
      expect(t.owedToMeBaseMilli, 75000);
      expect(t.netBaseMilli, 74979);
    });
  });

  group('jars', () {
    test('plan: rounds the monthly need up to the minor unit and paces a straight line', () {
      final rates = GoalsRates(
        base: 'JOD',
        currencies: const [GoalsCurrency(code: 'USD', rateToBase: 0.709, decimals: 2)],
      );
      final p = JarPlan.compute(
        targetMilli: 1000000,
        currency: 'USD',
        movements: [JarMovement(100000, DateTime(2026, 9, 1))],
        today: DateTime(2026, 9, 29),
        rates: rates,
        start: DateTime(2026, 9, 1),
        deadline: DateTime(2027, 4, 1),
      );
      // 900 USD over 6 whole months (Sep 29 → Mar 29) = 150.00.
      expect(p.monthsLeft, 6);
      expect(p.requiredPerMonthMilli, 150000);
      // 900 / 26 weeks = 34.615… → 34.62 (cents, rounded up).
      expect(p.requiredPerWeekMilli, 34620);
      expect(p.pace, JarPace.behind);
    });
  });

  group('reminders', () {
    test('lead-day and due-day reminders at the chosen time, none in the past', () {
      final now = DateTime(2026, 9, 29, 13, 10);
      final plan = DueReminderPlanner.plan(
        items: [
          DueItem(kind: DueReminderKind.obligation, refId: 'o', due: DateTime(2026, 10, 1)),
          DueItem(kind: DueReminderKind.debt, refId: 'd', due: DateTime(2026, 9, 29)),
          DueItem(kind: DueReminderKind.debt, refId: 'late', due: DateTime(2026, 9, 27)),
          DueItem(kind: DueReminderKind.debt, refId: 'far', due: DateTime(2027, 1, 1)),
        ],
        settings: const GoalsReminderSettings(minuteOfDay: 9 * 60 + 30),
        now: now,
      );
      expect(
        [for (final r in plan) (r.item.refId, r.at, r.daysBefore)],
        [('o', DateTime(2026, 9, 30, 9, 30), 1), ('o', DateTime(2026, 10, 1, 9, 30), 0)],
      );
      expect(CalendarDays.between(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });
  });
}
