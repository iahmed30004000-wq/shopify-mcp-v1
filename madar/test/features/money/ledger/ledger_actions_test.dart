// Row gestures of the ledger (long-press menu, swipe tray, move between
// currencies, undo), entries owned by jars / debts / obligations, and what
// the home quick-add writes.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/domain/prayer_day.dart';
import 'package:madar/features/home/domain/quick_add_handlers.dart';
import 'package:madar/features/money/ledger/ledger.dart';

import 'ledger_test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(
  WidgetTester tester,
  MadarDatabase db,
  Widget home, {
  Locale locale = const Locale('en'),
  List<Override> extra = const [],
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(ledgerTestApp(home: home, overrides: [...ledgerOverrides(db), ...extra], locale: locale));
  await _frames(tester, 30);
}

/// Lets the undo toast time out so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) => _frames(tester, 160);

Future<List<TransactionRow>> _rows(WidgetTester tester, MadarDatabase db) async =>
    (await tester.runAsync(() => Repositories(db).transactions.getAll()))!;

Future<MadarDatabase> _twoWallets(WidgetTester tester) async {
  final db = await ledgerDb(tester, data: false, arabic: false);
  await tester.runAsync(() async {
    final repos = Repositories(db);
    await repos.wallets.insert(WalletsCompanion.insert(id: const Value('w.cash'), name: 'Cash', currency: 'JOD'));
    await repos.wallets.insert(WalletsCompanion.insert(id: const Value('w.usd'), name: 'Dollars', currency: 'USD'));
    await repos.transactions.insert(
      TransactionsCompanion.insert(
        id: const Value('t.lunch'),
        walletId: 'w.cash',
        kind: TxKind.expense,
        amountMilli: 7090,
        date: DateTime(2026, 9, 20),
        note: const Value('Lunch'),
      ),
    );
  });
  return db;
}

void main() {
  late ({SilentSoundService sound, LedgerHaptics haptics}) fx;
  setUp(() => fx = installLedgerFx());

  testWidgets('long-press → Duplicate copies the entry to today, with undo', (tester) async {
    final db = await _twoWallets(tester);
    await _pump(tester, db, const TransactionsScreen());
    await tester.longPress(find.text('Lunch'));
    await _frames(tester);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await _frames(tester);
    final rows = await _rows(tester, db);
    expect(rows, hasLength(2));
    final copy = rows.firstWhere((r) => r.id != 't.lunch');
    expect(copy.date, DateTime(2026, 9, 29));
    expect(copy.amountMilli, 7090);
    expect(find.text('Duplicated to today'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _frames(tester);
    expect((await _rows(tester, db)).map((r) => r.id), ['t.lunch']);
    await _settleToast(tester);
  });

  testWidgets('swipe → Delete removes the entry; undo brings it back', (tester) async {
    final db = await _twoWallets(tester);
    await _pump(tester, db, const TransactionsScreen());
    await tester.drag(find.text('Lunch'), const Offset(-160, 0));
    await _frames(tester);
    expect(find.text('Duplicate to today'), findsOneWidget);
    fx.sound.played.clear();
    await tester.tap(find.text('Delete'));
    await _frames(tester, 30);
    expect(fx.sound.played, contains(Sfx.delete));
    expect(await _rows(tester, db), isEmpty);
    expect(find.text('Transaction deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _frames(tester, 30);
    expect((await _rows(tester, db)).single.id, 't.lunch');
    expect(find.text('Lunch'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('Move to a wallet in another currency converts at the manual rate', (tester) async {
    final db = await _twoWallets(tester);
    await _pump(tester, db, const TransactionsScreen());
    await tester.longPress(find.text('Lunch'));
    await _frames(tester);
    await tester.tap(find.text('Move'));
    await _frames(tester);
    expect(find.text('Move to…'), findsOneWidget);
    // 7.090 JOD ÷ 0.709 = 10.00 USD, shown before the move.
    expect(find.textContaining('10.00'), findsWidgets);
    await tester.tap(find.text('Dollars').last);
    await _frames(tester, 30);
    final row = (await _rows(tester, db)).single;
    expect(row.walletId, 'w.usd');
    expect(row.amountMilli, 10000);
    expect(find.textContaining('Moved to'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _frames(tester, 30);
    final back = (await _rows(tester, db)).single;
    expect((back.walletId, back.amountMilli), ('w.cash', 7090));
    await _settleToast(tester);
  });

  testWidgets('what the home quick-add writes shows as a normal expense', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    final handler = MoneyQuickAdd(
      QuickAddContext(
        repositories: () => Repositories(db),
        clock: () => ledgerNow,
        prayerDay: () => PrayerDayTimes.placeholder,
        focusedWindow: () => PrayerWindow.dhuhr,
        defaultWalletName: () => 'Wallet',
      ),
    );
    final handled = await tester.runAsync(
      () => handler.handle(QuickAddParser.parse('expense 5 JOD coffee beans', now: ledgerNow)),
    );
    expect(handled, isTrue);
    await _pump(tester, db, const TransactionsScreen());
    // The note is the title; no budget item, in the wallet quick-add made.
    expect(find.text('coffee beans'), findsOneWidget);
    expect(find.text('\u2068No budget item\u2069 · \u2068Wallet\u2069'), findsOneWidget);
    expect(find.text('-5.000\u00A0\u2068JOD\u2069'), findsWidgets);
    final book = (await tester.runAsync(() => LedgerService(Repositories(db)).book()))!;
    expect(book.totals.baseMilli, -5000);
    expect(book.transactions.single.date, DateTime(2026, 9, 29));
  });

  testWidgets('a wallet in a currency missing from the list can be priced from the notice', (tester) async {
    final db = await ledgerDb(tester, data: false, arabic: false);
    await tester.runAsync(
      () => LedgerService(Repositories(db)).addWallet(name: 'Travel card', currency: 'EUR', openingMilli: 100000),
    );
    await _pump(tester, db, const MoneyLedgerScreen());
    expect(find.textContaining('No exchange rate'), findsOneWidget);
    await tester.tap(find.text('Set rates'));
    await _frames(tester, 30);
    expect(find.text('Add \u2068EUR\u2069'), findsOneWidget);
    await tester.tap(find.text('Add \u2068EUR\u2069'));
    await _frames(tester, 30);
    final fields = find.descendant(of: find.byType(CurrencySheet), matching: find.byType(TextField));
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'EUR');
    await tester.enterText(fields.at(2), 'Euro');
    await tester.enterText(fields.at(4), '0.8');
    await _frames(tester, 4);
    await tester.tap(find.text('Save'));
    await _frames(tester, 30);
    final book = (await tester.runAsync(() => LedgerService(Repositories(db)).book()))!;
    expect(book.currency('EUR')!.rateToBase, 0.8);
    expect(book.totals.missingRates, isEmpty);
    expect(book.totals.baseMilli, 80000);
    expect(find.text('Add \u2068EUR\u2069'), findsNothing);
    await _settleToast(tester);
  });

  group('entries owned by a jar, debt or obligation', () {
    Future<MadarDatabase> linkedDb(WidgetTester tester) async {
      final db = await _twoWallets(tester);
      await tester.runAsync(
        () => Repositories(db).transactions.insert(
          TransactionsCompanion.insert(
            id: const Value('jar-tx-m1'),
            walletId: 'w.cash',
            kind: TxKind.adjustment,
            amountMilli: -20000,
            date: DateTime(2026, 9, 28),
            note: const Value('Travel'),
            tags: const Value(['jar']),
          ),
        ),
      );
      return db;
    }

    testWidgets('read as their source, with no edit, move or delete', (tester) async {
      final db = await linkedDb(tester);
      await _pump(tester, db, const TransactionsScreen());
      expect(find.text('Travel'), findsOneWidget);
      expect(find.textContaining('Savings jar'), findsOneWidget);
      expect(find.text('#jar'), findsNothing);
      await tester.longPress(find.text('Travel'));
      await _frames(tester);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Move'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      await tester.drag(find.text('Travel'), const Offset(-160, 0));
      await _frames(tester);
      expect(find.text('Delete'), findsNothing);
      expect(await _rows(tester, db), hasLength(2));
    });

    testWidgets('open their owner through LedgerRoutes.linked', (tester) async {
      final db = await linkedDb(tester);
      final opened = <(String, LedgerLink)>[];
      await _pump(
        tester,
        db,
        const TransactionsScreen(),
        extra: [
          ledgerRoutesProvider.overrideWithValue(
            LedgerRoutes(linked: (context, tx, link) => opened.add((LedgerLinks.sourceId(tx)!, link))),
          ),
        ],
      );
      await tester.tap(find.text('Travel'));
      await _frames(tester);
      expect(opened, [('m1', LedgerLink.jar)]);
      await tester.longPress(find.text('Travel'));
      await _frames(tester);
      await tester.tap(find.text('Open the jar'));
      await _frames(tester);
      expect(opened, hasLength(2));
    });

    testWidgets('Arabic shows the tag and source in Arabic', (tester) async {
      final db = await linkedDb(tester);
      await tester.runAsync(
        () => Repositories(db).transactions.insert(
          TransactionsCompanion.insert(
            id: const Value('t.rent'),
            walletId: 'w.cash',
            kind: TxKind.expense,
            amountMilli: 1000,
            date: DateTime(2026, 9, 27),
            note: const Value('إيجار'),
            tags: const Value(['obligation']),
          ),
        ),
      );
      await _pump(tester, db, const TransactionsScreen(), locale: const Locale('ar'));
      expect(find.textContaining('حصّالة'), findsOneWidget);
      // A plain entry that carries a system tag shows it translated.
      expect(find.text('#التزام'), findsOneWidget);
    });
  });
}
