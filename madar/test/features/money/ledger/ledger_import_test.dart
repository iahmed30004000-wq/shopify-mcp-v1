// Import check for the ledger: the prototype fixtures go through the real
// importer, and every wallet balance, entry and base-currency report the
// ledger shows is asserted (balance rule shared with the importer:
// opening = stated balance − net of the imported entries).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/core/i18n/gen/app_localizations_ar.dart';
import 'package:madar/core/i18n/gen/app_localizations_en.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/money/ledger/presentation/widgets/tx_tile.dart' show TxTile;

Future<LedgerBook> _import(String fixture, String language) async {
  final db = MadarDatabase(NativeDatabase.memory(), seed: const SeedOptions());
  addTearDown(db.close);
  final importer = PrototypeImporter(labels: ImportLabels.forLanguage(language));
  final json = File('test/fixtures/import/$fixture').readAsStringSync();
  final plan = importer.analyze(json, now: DateTime(2026, 9, 29));
  await importer.commit(db, plan);
  return LedgerService(Repositories(db), clock: () => DateTime(2026, 9, 29, 12)).book();
}

LedgerWallet _wallet(LedgerBook book, bool Function(LedgerWallet w) test) => book.wallets.singleWhere(test);

void main() {
  group('English nested prototype', () {
    late LedgerBook book;
    setUp(() async => book = await _import('prototype_nested_en.json', 'en'));

    test('wallets keep their currencies and the stated balances', () {
      final cash = _wallet(book, (w) => w.name == 'Cash');
      final card = _wallet(book, (w) => w.name == 'Dollar card');
      final egp = _wallet(book, (w) => w.currency == 'EGP');
      expect(cash.currency, 'JOD');
      expect(card.currency, 'USD');
      // Cash: opening 150 + salary 500 − groceries 42.75 − fuel 12.5.
      expect(cash.openingMilli, 150000);
      expect(book.balanceOf(cash.id), 594750);
      // The card's "balance" is after its entries: 1,250.50 exactly.
      expect(card.openingMilli, 1250500 + 19990);
      expect(book.balanceOf(card.id), 1250500);
      // An entry without a wallet lands in a wallet of its currency.
      expect(book.balanceOf(egp.id), -150000);
      expect(book.transactions, hasLength(5));
    });

    test('entries keep kinds, days, notes and budget items', () {
      final byNote = {for (final t in book.transactions) t.cleanNote ?? t.id: t};
      final groceries = byNote['Groceries']!;
      expect(groceries.kind, TxKind.expense);
      expect(groceries.amountMilli, 42750);
      expect(groceries.date, DateTime(2026, 9, 2));
      expect(book.budgetPath(groceries.budgetItemId), 'Home food › Proteins');
      final salary = byNote['Salary']!;
      expect(salary.kind, TxKind.income);
      expect(salary.amountMilli, 500000);
      // "category": "Car fuel" resolved by name; the time of day is dropped.
      final fuel = book.transactions.singleWhere((t) => t.amountMilli == 12500);
      expect(book.budgetNameOf(fuel.budgetItemId!), 'Car fuel');
      expect(fuel.date, DateTime(2026, 9, 3));
      final l = L10nEn();
      expect(TxTile.titleOf(fuel, book, l), 'Car fuel');
      expect(TxTile.titleOf(groceries, book, l), 'Groceries');
    });

    test('September spending by budget item and by wallet, in the base currency', () {
      final window = BudgetWindow.month(DateTime(2026, 9, 15));
      final usd = book.rates.toBaseExact(19990, 'USD')!;
      final egp = book.rates.toBaseExact(150000, 'EGP')!;
      final byItem = LedgerReports.spendingByBudgetItem(
        book.transactions,
        window,
        walletCurrency: book.walletCurrency,
        rates: book.rates,
        budget: book.budget,
      );
      final slices = {for (final s in byItem.slices) s.id: s.baseMilli};
      final food = book.rootIdOf(book.transactions.firstWhere((t) => t.cleanNote == 'Groceries').budgetItemId);
      expect(slices[food], 42750);
      expect(slices.values.where((v) => v == 12500), hasLength(1));
      expect(slices[null], (usd + egp).roundHalfUp());
      expect(byItem.totalMilli, (Rational.fromInt(42750 + 12500) + usd + egp).roundHalfUp());
      expect(byItem.missingRates, isEmpty);

      final byWallet = LedgerReports.spendingByWallet(
        book.transactions,
        window,
        walletCurrency: book.walletCurrency,
        rates: book.rates,
      );
      expect(byWallet.totalMilli, byItem.totalMilli);
      final flow = LedgerReports.flow(
        LedgerReports.inWindow(book.transactions, window),
        walletCurrency: book.walletCurrency,
        rates: book.rates,
      );
      expect(flow.incomeMilli, 500000);
      expect(flow.expenseMilli, byItem.totalMilli);
    });

    test('the budget tree the ledger reads is the imported one', () {
      final b = book.budget!;
      final food = b.flattened.firstWhere((r) => r.node.name == 'Home food');
      expect(food.childIds, hasLength(4));
      expect(food.monthlyMilli, 200000);
      expect(b.flattened.firstWhere((r) => r.node.name == "Wife's allowance").node.period, BudgetPeriod.weekly);
    });
  });

  group('Arabic flat prototype', () {
    late LedgerBook book;
    setUp(() async => book = await _import('prototype_flat_ar.json', 'ar'));

    test('balances, Arabic digits and the budget item of an entry', () {
      final cash = _wallet(book, (w) => w.name == 'نقدي');
      final usd = _wallet(book, (w) => w.currency == 'USD');
      final egp = _wallet(book, (w) => w.currency == 'EGP');
      expect(book.balanceOf(cash.id), 700000);
      expect(cash.openingMilli, 700000 - 600000 + 42750);
      expect(book.balanceOf(usd.id), -1234500);
      expect(book.balanceOf(egp.id), -300000);

      const fmt = LedgerMoneyFormat(arabic: true, arabicIndic: true);
      final f = fmt.withCurrencies(book.currencyByCode);
      expect(f.amount(book.balanceOf(cash.id), 'JOD'), '٧٠٠٫٠٠٠\u00A0\u2068د.أ\u2069');
      expect(f.amount(book.balanceOf(usd.id), 'USD'), startsWith('\u061C-١٬٢٣٤٫٥٠'));

      final protein = book.transactions.singleWhere((t) => t.amountMilli == 42750);
      expect(book.budgetPath(protein.budgetItemId), 'طعام البيت › بروتينات');
      expect(TxTile.titleOf(protein, book, L10nAr()), 'بروتينات');
    });
  });
}
