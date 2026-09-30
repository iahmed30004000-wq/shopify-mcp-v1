import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/ledger/ledger.dart';

import 'ledger_test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, MadarDatabase db, Widget home, {Locale locale = const Locale('en')}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(ledgerTestApp(home: home, overrides: ledgerOverrides(db), locale: locale));
  await _frames(tester, 30);
}

Future<void> _type(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.text(k).last);
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<List<TransactionRow>> _rows(WidgetTester tester, MadarDatabase db) async =>
    (await tester.runAsync(() => Repositories(db).transactions.getAll()))!;

void main() {
  late ({SilentSoundService sound, LedgerHaptics haptics}) fx;
  setUp(() => fx = installLedgerFx());

  testWidgets('empty ledger invites to create the first wallet', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await _pump(tester, db, const MoneyLedgerScreen());
    expect(find.text('Start with your first wallet'), findsOneWidget);
    expect(find.text('New wallet'), findsOneWidget);
    expect(find.byTooltip('New transaction'), findsNothing);
  });

  testWidgets('hub shows the net balance, wallets and recent entries', (tester) async {
    final db = await ledgerDb(tester, arabic: false);
    await _pump(tester, db, const MoneyLedgerScreen());
    expect(find.text('Net balance'), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('USD account'), findsWidgets);
    expect(find.text('Personal'), findsWidgets);
    expect(find.text('Business'), findsWidgets);
    final book = (await tester.runAsync(() => LedgerService(Repositories(db)).book()))!;
    final fmt = LedgerMoneyFormat(arabic: false, arabicIndic: false, currencies: book.currencyByCode);
    expect(find.text(fmt.amount(book.totals.baseMilli, 'JOD')), findsOneWidget);
  });

  testWidgets('keypad sheet adds an expense in the wallet currency with undo', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await tester.runAsync(() => LedgerService(Repositories(db)).addWallet(name: 'Cash', currency: 'JOD'));
    await _pump(tester, db, const MoneyLedgerScreen());
    await tester.tap(find.bySemanticsLabel('New transaction').last);
    await _frames(tester);
    expect(find.text('New transaction'), findsWidgets);
    await _type(tester, '12.5');
    expect(find.text('12.5'), findsOneWidget);
    fx.sound.played.clear();
    await tester.tap(find.text('Save'));
    await _frames(tester, 30);
    final rows = await _rows(tester, db);
    expect(rows, hasLength(1));
    expect(rows.single.kind, TxKind.expense);
    expect(rows.single.amountMilli, 12500);
    expect(rows.single.date, DateTime(2026, 9, 29));
    expect(fx.sound.played, contains(Sfx.complete));
    expect(find.text('Transaction saved'), findsOneWidget);
    // Undo removes it again.
    await tester.tap(find.text('Undo'));
    await _frames(tester, 20);
    expect(await _rows(tester, db), isEmpty);
    await _frames(tester, 140);
  });

  testWidgets('saving without an amount explains why and plays the error sound', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await tester.runAsync(() => LedgerService(Repositories(db)).addWallet(name: 'Cash', currency: 'JOD'));
    await _pump(tester, db, const MoneyLedgerScreen());
    await tester.tap(find.bySemanticsLabel('New transaction').last);
    await _frames(tester);
    fx.sound.played.clear();
    await tester.tap(find.text('Save'));
    await _frames(tester, 10);
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(fx.sound.played, contains(Sfx.error));
    expect(await _rows(tester, db), isEmpty);
  });

  testWidgets('a transfer between currencies fills the received amount from the rate', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    final service = LedgerService(Repositories(db));
    final usd = (await tester.runAsync(() => service.addWallet(name: 'Dollars', currency: 'USD')))!;
    final jod = (await tester.runAsync(() => service.addWallet(name: 'Dinars', currency: 'JOD')))!;
    await _pump(tester, db, const MoneyLedgerScreen());
    final context = tester.element(find.byType(MoneyLedgerScreen));
    showTransactionSheet(context, kind: TxKind.transfer, walletId: usd.id, toWalletId: jod.id);
    await _frames(tester);
    await _type(tester, '100');
    expect(find.text('70.900'), findsOneWidget); // received, from 0.709
    await tester.tap(find.text('Save'));
    await _frames(tester, 30);
    final row = (await _rows(tester, db)).single;
    expect(row.kind, TxKind.transfer);
    expect(row.amountMilli, 100000);
    expect(row.toWalletId, jod.id);
    expect(row.toAmountMilli, 70900);
    await _frames(tester, 140);
  });

  testWidgets('adjustment "actual balance" stores the difference', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    final w = (await tester.runAsync(
      () => LedgerService(Repositories(db)).addWallet(name: 'Cash', currency: 'JOD', openingMilli: 100000),
    ))!;
    await _pump(tester, db, WalletScreen(walletId: w.id));
    await tester.tap(find.text('Adjustment').first);
    await _frames(tester);
    await _type(tester, '97');
    await tester.tap(find.text('Save'));
    await _frames(tester, 30);
    final row = (await _rows(tester, db)).single;
    expect(row.kind, TxKind.adjustment);
    expect(row.amountMilli, -3000);
    await _frames(tester, 140);
  });

  testWidgets('transactions: search and filters narrow the list and the totals', (tester) async {
    final db = await ledgerDb(tester, arabic: false);
    await _pump(tester, db, const TransactionsScreen());
    expect(find.text('Coffee'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'knafeh');
    await _frames(tester);
    expect(find.text('Knafeh'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);
    expect(find.text('1 transaction · In base currency \u2068JOD\u2069'), findsOneWidget);
  });

  testWidgets('transactions: an initial filter by wallet shows running balances', (tester) async {
    final db = await ledgerDb(tester, arabic: false);
    await _pump(tester, db, const TransactionsScreen(filter: TxFilter(walletIds: {Ex.cash})));
    expect(find.textContaining('Balance'), findsWidgets);
    expect(find.text('Wallet'), findsNothing); // the chip shows the wallet's name instead
    expect(find.text('Cash'), findsWidgets);
  });

  testWidgets('wallet screen: balance, quick actions and its entries', (tester) async {
    final db = await ledgerDb(tester, arabic: false);
    await _pump(tester, db, const WalletScreen(walletId: Ex.usd));
    expect(find.text('USD account'), findsWidgets);
    expect(find.text('Balance over time'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.textContaining('≈'), findsOneWidget);
  });

  testWidgets('currencies: base, rates both ways, and the base can change with a preview', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await _pump(tester, db, const CurrenciesScreen());
    expect(find.text('Base currency'), findsOneWidget);
    expect(find.text('Jordanian Dinar'), findsWidgets);
    expect(find.textContaining('0.709'), findsWidgets);
    await tester.tap(find.text('Change base currency'));
    await _frames(tester);
    expect(find.text('New base currency'), findsOneWidget);
    await tester.tap(find.textContaining('Make').last);
    await _frames(tester, 30);
    final base = await tester.runAsync(() => Repositories(db).currencies.base());
    expect(base!.code, 'USD');
    await _frames(tester, 140);
  });

  testWidgets('summary card: empty and filled', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await _pump(tester, db, const Scaffold(body: WalletsSummaryCard()));
    expect(find.text('No wallets yet'), findsOneWidget);
    await tester.runAsync(
      () => LedgerService(Repositories(db)).addWallet(name: 'Cash', currency: 'JOD', openingMilli: 5000),
    );
    await _frames(tester);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('5.000\u00A0\u2068JOD\u2069'), findsWidgets);
  });

  testWidgets('Arabic: amounts use Arabic-Indic digits and isolated symbols', (tester) async {
    final db = await ledgerDb(tester, data: false);
    await tester.runAsync(
      () => LedgerService(Repositories(db)).addWallet(name: 'الصندوق', currency: 'JOD', openingMilli: 1234500),
    );
    await _pump(tester, db, const MoneyLedgerScreen(), locale: const Locale('ar'));
    expect(find.text('١٬٢٣٤٫٥٠٠\u00A0\u2068د.أ\u2069'), findsWidgets);
  });
}
