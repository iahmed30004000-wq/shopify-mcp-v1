import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/seed/seeder.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/ledger/data/ledger_service.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';
import 'package:madar/features/money/ledger/domain/tx_draft.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late LedgerService service;
  final now = DateTime(2026, 9, 29, 14, 30);

  setUp(() async {
    db = MadarDatabase(NativeDatabase.memory(), seed: const SeedOptions());
    repos = Repositories(db);
    service = LedgerService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  TxWrite expense(String wallet, int milli, {String? item, List<String> tags = const []}) => TxWrite(
    walletId: wallet,
    kind: TxKind.expense,
    amountMilli: milli,
    date: DateTime(2026, 9, 28),
    budgetItemId: item,
    tags: tags,
  );

  test('a fresh database has the seeded currencies and nothing else', () async {
    final book = await service.book();
    expect(book.currencies.map((c) => c.code), ['JOD', 'USD', 'SYP', 'EGP', 'LYD']);
    expect(book.baseCode, 'JOD');
    expect(book.wallets, isEmpty);
    expect(book.transactions, isEmpty);
    expect(book.budget, isNull);
  });

  test('wallets, entries and balances; activity logged as money.tx', () async {
    final cash = await service.addWallet(name: ' Cash ', currency: 'jod', openingMilli: 100000);
    final bank = await service.addWallet(name: 'Bank', currency: 'USD', kind: WalletKind.business);
    expect(cash.name, 'Cash');
    expect(cash.currency, 'JOD');
    await service.add(expense(cash.id, 12500, tags: ['food']));
    await service.add(
      TxWrite(
        walletId: cash.id,
        kind: TxKind.transfer,
        amountMilli: 70900,
        date: DateTime(2026, 9, 28),
        toWalletId: bank.id,
        toAmountMilli: 100000,
      ),
    );
    final book = await service.book();
    expect(book.balanceOf(cash.id), 100000 - 12500 - 70900);
    expect(book.balanceOf(bank.id), 100000);
    expect(book.totals.baseMilli, 100000 - 12500); // transfer keeps the total
    final activity = await repos.activity.since(DateTime(2026), planetKey: 'money');
    expect(activity.map((a) => a.kind), everyElement('money.tx'));
    expect(activity, hasLength(2));
  });

  test('delete removes the activity too and undo restores both', () async {
    final w = await service.addWallet(name: 'W', currency: 'JOD');
    final t = await service.add(expense(w.id, 5000));
    final undo = await service.delete(t.id);
    expect(await repos.transactions.count(), 0);
    expect(await repos.activity.since(DateTime(2026)), isEmpty);
    await undo();
    expect((await repos.transactions.byId(t.id))?.amountMilli, 5000);
    expect(await repos.activity.since(DateTime(2026)), hasLength(1));
  });

  test('update and its undo', () async {
    final w = await service.addWallet(name: 'W', currency: 'JOD');
    final t = await service.add(expense(w.id, 5000, item: 'x'));
    final undo = await service.update(t.id, expense(w.id, 7000));
    final row = await repos.transactions.byId(t.id);
    expect(row!.amountMilli, 7000);
    expect(row.budgetItemId, isNull);
    await undo();
    expect((await repos.transactions.byId(t.id))!.budgetItemId, 'x');
  });

  test('duplicate lands today; move converts between currencies', () async {
    final cash = await service.addWallet(name: 'Cash', currency: 'JOD');
    final usd = await service.addWallet(name: 'USD', currency: 'USD');
    final t = await service.add(expense(cash.id, 70900));
    final (copy, undoCopy) = await service.duplicate(t.id);
    expect(copy.date, DateTime(2026, 9, 29));
    expect(copy.amountMilli, 70900);
    await undoCopy();
    expect(await repos.transactions.count(), 1);

    final undoMove = await service.move(t.id, usd.id, await service.book());
    final moved = await repos.transactions.byId(t.id);
    expect(moved!.walletId, usd.id);
    expect(moved.amountMilli, 100000); // 70.900 JOD = 100.00 USD
    await undoMove!();
    expect((await repos.transactions.byId(t.id))!.walletId, cash.id);
  });

  test('the wallet currency locks once entries exist', () async {
    final w = await service.addWallet(name: 'W', currency: 'JOD');
    await service.updateWallet(w.id, name: 'W2', currency: 'USD', openingMilli: 0, kind: WalletKind.personal);
    await service.add(expense(w.id, 1000));
    expect(
      () => service.updateWallet(w.id, name: 'W', currency: 'JOD', openingMilli: 0, kind: WalletKind.personal),
      throwsA(isA<WalletCurrencyLockedException>()),
    );
  });

  test('deleting a wallet takes its entries (and transfers into it); undo restores all', () async {
    final a = await service.addWallet(name: 'A', currency: 'JOD');
    final b = await service.addWallet(name: 'B', currency: 'JOD');
    await service.add(expense(a.id, 1000));
    await service.add(
      TxWrite(walletId: b.id, kind: TxKind.transfer, amountMilli: 500, date: DateTime(2026, 9, 1), toWalletId: a.id),
    );
    await service.add(expense(b.id, 200));
    final undo = await service.deleteWallet(a.id);
    expect(await repos.transactions.count(), 1);
    expect(await repos.wallets.count(), 1);
    await undo();
    expect(await repos.transactions.count(), 3);
    expect(await repos.wallets.count(), 2);
    expect(await repos.activity.since(DateTime(2026)), hasLength(3));
  });

  test('archive and undo', () async {
    final w = await service.addWallet(name: 'W', currency: 'JOD');
    final undo = await service.setArchived(w.id, true);
    expect((await repos.wallets.byId(w.id))!.archived, isTrue);
    await undo();
    expect((await repos.wallets.byId(w.id))!.archived, isFalse);
  });

  test('user currency: add with a rate, clears the defaults flag, undo removes it', () async {
    expect(await repos.keyValues.getJson(SeedKeys.currencyRatesAreDefaults), isTrue);
    final undo = await service.saveCurrency(
      const LedgerCurrency(code: 'usdt', nameAr: 'تيثر', nameEn: 'Tether', symbol: '', decimals: 3),
      rate: RateOf.parse('0.709'),
    );
    final row = await repos.currencies.byCode('USDT');
    expect(row!.rateToBase, 0.709);
    expect(row.symbol, 'USDT');
    expect(row.sortOrder, 5);
    expect(await repos.keyValues.getJson(SeedKeys.currencyRatesAreDefaults), isNull);
    await undo();
    expect(await repos.currencies.byCode('USDT'), isNull);
  });

  test('rebase is exact, keeps converted totals and can be undone', () async {
    final cash = await service.addWallet(name: 'Cash', currency: 'JOD', openingMilli: 709000);
    await service.addWallet(name: 'Lira', currency: 'SYP', openingMilli: 1000000000);
    final before = await service.book();
    final undo = await service.rebase('USD');
    final after = await service.book();
    expect(after.baseCode, 'USD');
    expect(after.currency('USD')!.rateToBase, 1.0);
    expect(after.currency('JOD')!.rateToBase, 1.410437235543);
    expect(after.rates.convert(before.balanceOf(cash.id), 'JOD', 'USD'), 1000000);
    // Base total in USD equals the old JOD total converted.
    expect(after.totals.baseMilli, before.rates.convert(before.totals.baseMilli, 'JOD', 'USD'));
    await undo();
    final restored = await service.book();
    expect(restored.baseCode, 'JOD');
    expect(restored.currency('USD')!.rateToBase, 0.709);
  });

  test('a currency in use cannot be deleted; an unused one can, with undo', () async {
    await service.addWallet(name: 'W', currency: 'EGP');
    expect(() => service.deleteCurrency('EGP'), throwsA(isA<CurrencyInUseException>()));
    final undo = await service.deleteCurrency('LYD');
    expect(await repos.currencies.byCode('LYD'), isNull);
    await undo();
    expect(await repos.currencies.byCode('LYD'), isNotNull);
  });

  test('the quick-add shape (expense, note, no budget item) reads back fine', () async {
    final w = await repos.wallets.insert(WalletsCompanion.insert(name: 'محفظة', currency: 'JOD'));
    await repos.transactions.insert(
      TransactionsCompanion.insert(
        walletId: w.id,
        kind: TxKind.expense,
        amountMilli: 5000,
        date: DateTime(2026, 9, 29, 13, 5),
        note: const Value('غداء'),
      ),
    );
    final book = await service.book();
    final t = book.transactions.single;
    expect(t.date, DateTime(2026, 9, 29));
    expect(t.cleanNote, 'غداء');
    expect(t.tags, isEmpty);
    expect(book.balanceOf(w.id), -5000);
  });
}

/// Test shorthand for parsed rates.
abstract final class RateOf {
  static Rational parse(String s) => Rational.tryParse(s)!;
}
