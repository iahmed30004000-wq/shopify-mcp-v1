import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/ledger/domain/chart_scale.dart';
import 'package:madar/features/money/ledger/domain/ledger_book.dart';
import 'package:madar/features/money/ledger/domain/ledger_math.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';
import 'package:madar/features/money/ledger/domain/ledger_reports.dart';

import 'ledger_fixtures.dart';

void main() {
  group('effects and balances', () {
    const jod = LedgerWallet(id: 'cash', name: 'Cash', currency: 'JOD', openingMilli: 100000);
    const usd = LedgerWallet(id: 'bank', name: 'Bank', currency: 'USD', openingMilli: 50000);

    test('income +, expense −, adjustment signed', () {
      final txs = [
        tx('a', 'cash', TxKind.income, 25500),
        tx('b', 'cash', TxKind.expense, 12345),
        tx('c', 'cash', TxKind.adjustment, -155),
        tx('d', 'cash', TxKind.adjustment, 1000),
      ];
      expect(LedgerMath.balanceOf(jod, txs), 100000 + 25500 - 12345 - 155 + 1000);
    });

    test('transfer: out on the source, toAmount in on the destination', () {
      final t = tx('t', 'cash', TxKind.transfer, 70900, toWalletId: 'bank', toAmountMilli: 100000);
      expect(LedgerMath.effectOn(t, 'cash'), -70900);
      expect(LedgerMath.effectOn(t, 'bank'), 100000);
      expect(LedgerMath.effectOn(t, 'other'), 0);
      final b = LedgerMath.balances([jod, usd], [t]);
      expect(b['cash'], 100000 - 70900);
      expect(b['bank'], 50000 + 100000);
    });

    test('transfer without a received amount moves the same number', () {
      final t = tx('t', 'cash', TxKind.transfer, 5000, toWalletId: 'bank');
      expect(LedgerMath.effectOn(t, 'bank'), 5000);
    });

    test('transfer to nowhere only leaves the source', () {
      final t = tx('t', 'cash', TxKind.transfer, 5000);
      expect(LedgerMath.balances([jod, usd], [t]), {'cash': 95000, 'bank': 50000});
    });

    test('a self-transfer nets out', () {
      final t = tx('t', 'cash', TxKind.transfer, 5000, toWalletId: 'cash', toAmountMilli: 5000);
      expect(LedgerMath.balances([jod], [t]), {'cash': 100000});
    });

    test('amounts stored with a sign still follow the kind', () {
      // The importer writes magnitudes, but a negative expense must not add.
      expect(LedgerMath.effectOn(tx('x', 'cash', TxKind.expense, -3000), 'cash'), -3000);
      expect(LedgerMath.effectOn(tx('y', 'cash', TxKind.income, -3000), 'cash'), 3000);
    });

    test('asOf ignores later days', () {
      final txs = [
        tx('a', 'cash', TxKind.expense, 1000, date: DateTime(2026, 9, 1)),
        tx('b', 'cash', TxKind.expense, 2000, date: DateTime(2026, 9, 3)),
      ];
      expect(LedgerMath.balanceOf(jod, txs, asOf: DateTime(2026, 9, 2, 23)), 99000);
      expect(LedgerMath.balances([jod], txs, asOf: DateTime(2026, 9, 3))['cash'], 97000);
    });

    test('running balances follow day, then insertion order', () {
      final txs = [
        tx('late', 'cash', TxKind.expense, 1000, date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2, 20)),
        tx('early', 'cash', TxKind.income, 5000, date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2, 8)),
        tx('first', 'cash', TxKind.expense, 500, date: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 5)),
        tx('in', 'bank', TxKind.transfer, 2000, toWalletId: 'cash', toAmountMilli: 1418, date: DateTime(2026, 9, 3)),
      ];
      expect(LedgerMath.runningBalances(jod, txs), {'first': 99500, 'early': 104500, 'late': 103500, 'in': 104918});
    });

    test('balance series: daily closing balances, history folded in', () {
      final txs = [
        tx('old', 'cash', TxKind.expense, 10000, date: DateTime(2026, 8, 1)),
        tx('a', 'cash', TxKind.expense, 1000, date: DateTime(2026, 9, 2)),
        tx('b', 'cash', TxKind.income, 3000, date: DateTime(2026, 9, 2)),
        tx('c', 'cash', TxKind.expense, 500, date: DateTime(2026, 9, 4)),
      ];
      final s = LedgerMath.balanceSeries(jod, txs, from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 4));
      expect(s, [
        BalancePoint(DateTime(2026, 9, 1), 90000),
        BalancePoint(DateTime(2026, 9, 2), 92000),
        BalancePoint(DateTime(2026, 9, 3), 92000),
        BalancePoint(DateTime(2026, 9, 4), 91500),
      ]);
      final sampled = LedgerMath.balanceSeries(
        jod,
        txs,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 9, 4),
        maxPoints: 10,
      );
      expect(sampled, hasLength(10));
      expect(sampled.last, BalancePoint(DateTime(2026, 9, 4), 91500));
      expect(sampled.first.day, DateTime(2026, 1, 1));
    });

    test('balance series across a DST change keeps calendar days', () {
      final s = LedgerMath.balanceSeries(jod, const [], from: DateTime(2026, 3, 25), to: DateTime(2026, 4, 2));
      expect(s.map((p) => p.day.day), [25, 26, 27, 28, 29, 30, 31, 1, 2]);
    });
  });

  group('rates and totals', () {
    final rates = LedgerRates.of(seededCurrencies);

    test('conversion is exact and rounded once, half-up', () {
      expect(rates.toBase(100000, 'USD'), 70900); // 100 USD = 70.900 JOD
      expect(rates.toBase(1, 'EGP'), 0); // 0.001 EGP × 0.0145 → 0.0000145
      expect(rates.toBaseExact(1, 'EGP'), Rational.fromInt(145, 10000)); // milli-units, exact
      expect(rates.convert(70900, 'JOD', 'USD'), 100000);
      expect(rates.convert(10000, 'JOD', 'USD', decimals: 2), 14100); // 14.104… → 14.10
      expect(rates.convert(10000, 'JOD', 'USD'), 14104);
      expect(rates.convert(12345, 'USD', 'USD', decimals: 2), 12350);
      expect(rates.toBase(5, 'XYZ'), isNull);
      expect(rates.cross('USD', 'EGP'), Rational.fromInt(709, 1000) / Rational.fromInt(145, 10000));
    });

    test('totals per currency, per kind and in base; missing rates are excluded', () {
      final wallets = [
        const LedgerWallet(id: 'j', name: 'J', currency: 'JOD', openingMilli: 200000),
        const LedgerWallet(id: 'u', name: 'U', currency: 'USD', openingMilli: 100000, kind: WalletKind.business),
        const LedgerWallet(id: 'e', name: 'E', currency: 'EGP', openingMilli: 1000000, kind: WalletKind.business),
        const LedgerWallet(id: 'x', name: 'X', currency: 'XYZ', openingMilli: 5000),
        const LedgerWallet(id: 'a', name: 'A', currency: 'JOD', openingMilli: 999000, archived: true),
      ];
      final totals = LedgerTotals.of(wallets, LedgerMath.balances(wallets, const []), rates);
      expect(totals.byCurrency, {'JOD': 200000, 'USD': 100000, 'EGP': 1000000, 'XYZ': 5000});
      // 200 + 70.9 + 14.5 = 285.4 JOD
      expect(totals.baseMilli, 285400);
      expect(totals.kindMilli(WalletKind.personal), 200000);
      expect(totals.kindMilli(WalletKind.business), 85400);
      expect(totals.missingRates, {'XYZ'});
      expect(totals.walletCount, 4);
      expect(totals.hasBusiness, isTrue);
    });

    test('base total rounds the exact sum once', () {
      final wallets = [
        for (var i = 0; i < 3; i++) LedgerWallet(id: 'e$i', name: 'E', currency: 'EGP', openingMilli: 100),
      ];
      // Each wallet is 0.00145 JOD milli; rounding each would give 0.
      final totals = LedgerTotals.of(
        wallets,
        LedgerMath.balances(wallets, const []),
        LedgerRates(base: 'JOD', rates: {'EGP': Rational.fromInt(145, 10)}),
      );
      expect(totals.baseMilli, 4350);
    });
  });

  group('book', () {
    test('assembles balances, tree paths and subtree filters', () {
      final book = sampleBook();
      expect(book.baseCode, 'JOD');
      expect(book.balanceOf('cash'), 200000 - 20000 - 5000 - 30000 + 3000);
      expect(book.budgetPath('proteins'), 'Home food › Proteins');
      expect(book.budgetSubtree(['food']), {'food', 'proteins', 'spices'});
      expect(book.tags.first, 'family');
      expect(book.activeWallets.map((w) => w.id), ['cash', 'bank', 'shop']);
      expect(book.budget!.totalMonthlyMilli, 200000 + 100000 + 20000);
    });

    test('balanceWithout leaves one entry out', () {
      final book = sampleBook();
      expect(book.balanceWithout('cash', 'fuel'), book.balanceOf('cash') + 30000);
    });
  });

  group('reports', () {
    final book = sampleBook();
    final window = BudgetWindow.month(DateTime(2026, 9, 15));

    test('spending by root budget item, children rolled up, unassigned apart', () {
      final r = LedgerReports.spendingByBudgetItem(
        book.transactions,
        window,
        walletCurrency: book.walletCurrency,
        rates: book.rates,
        budget: book.budget,
      );
      expect(r.slices.map((s) => (s.id, s.baseMilli)), [
        ('car', 30000),
        ('food', 25000), // 20 proteins + 5 spices
        (null, 7090), // 10 USD unassigned = 7.090
      ]);
      expect(r.totalMilli, 62090);
      expect(r.slices.first.share, closeTo(30000 / 62090, 1e-9));
    });

    test('spending by wallet', () {
      final r = LedgerReports.spendingByWallet(
        book.transactions,
        window,
        walletCurrency: book.walletCurrency,
        rates: book.rates,
      );
      expect(r.slices.map((s) => (s.id, s.baseMilli)), [('cash', 55000), ('bank', 7090)]);
    });

    test('wallet predicate narrows the reports (business only)', () {
      final r = LedgerReports.spendingByWallet(
        book.transactions,
        window,
        walletCurrency: book.walletCurrency,
        rates: book.rates,
        wallets: (id) => book.walletKindOf(id) == WalletKind.business,
      );
      expect(r.isEmpty, isTrue);
    });

    test('income vs expense trend, oldest first, transfers ignored', () {
      final buckets = LedgerReports.trend(
        book.transactions,
        anchor: DateTime(2026, 9, 20),
        walletCurrency: book.walletCurrency,
        rates: book.rates,
        count: 3,
      );
      expect(buckets.map((b) => b.window.start), [DateTime(2026, 7), DateTime(2026, 8), DateTime(2026, 9)]);
      expect(buckets.last.incomeMilli, 354500); // 500 USD = 354.500 JOD
      expect(buckets.last.expenseMilli, 62090);
      expect(buckets[1].incomeMilli, 0);
      expect(buckets[1].expenseMilli, 1000);
    });

    test('weekly windows shift by seven days', () {
      final w = LedgerReports.windowOf(DateTime(2026, 9, 29), BudgetPeriod.weekly);
      expect(w.start, DateTime(2026, 9, 26)); // Saturday
      expect(LedgerReports.shift(w, -1).start, DateTime(2026, 9, 19));
      expect(LedgerReports.shift(BudgetWindow.month(DateTime(2026, 1, 31)), -1).start, DateTime(2025, 12));
    });

    test('flow: income and expenses in base, transfers and adjustments excluded', () {
      final f = LedgerReports.flow(book.transactions, walletCurrency: book.walletCurrency, rates: book.rates);
      expect(f.incomeMilli, 354500);
      expect(f.expenseMilli, 63090);
      expect(f.netMilli, 354500 - 63090);
      expect(f.count, book.transactions.length);
    });
  });

  group('book looks', () {
    test('items inherit icon and colour from their parents; roots are found', () {
      final book = LedgerBook(
        currencies: seededCurrencies,
        wallets: sampleWallets,
        transactions: const [],
        budgetNodes: sampleBudget,
        budgetLooks: const {
          'food': BudgetItemLook(icon: 'food', color: 0xFF112233),
          'proteins': BudgetItemLook(icon: 'heart'),
        },
      );
      expect(book.rootIdOf('spices'), 'food');
      expect(book.rootIdOf('car'), 'car');
      expect(book.rootIdOf('nope'), isNull);
      expect(book.lookOf('spices').icon, 'food');
      expect(book.lookOf('proteins').icon, 'heart');
      expect(book.lookOf('proteins').color, 0xFF112233);
      expect(book.rootIndexOf('spices'), 0);
      expect(book.rootIndexOf('emergency'), 2);
    });
  });

  group('chart scale', () {
    test('round steps that include zero', () {
      expect(ChartScale.of(0, 1432), const ChartScale(0, 1500, 500));
      expect(ChartScale.of(-438, -180), const ChartScale(-600, 0, 200));
      expect(ChartScale.of(0, 0), const ChartScale(0, 1, 0.25));
      expect(ChartScale.of(-120, 380), const ChartScale(-200, 400, 200));
    });
  });
}
