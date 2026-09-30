import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../orbit/data/orbit_providers.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_models.dart';
import 'ledger_service.dart';

/// The ledger's wall clock (follows the orbit's, so tests freeze both).
final ledgerClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// First day of the ledger's weeks (the app follows the user's Money
/// setting; Saturday by default).
final ledgerWeekStartProvider = Provider<int>((ref) => DateTime.saturday);

/// Records `money.tx` through the orbit's pulse hub, so the Money world
/// pulses at once.
final ledgerActivityRecorderProvider = Provider<LedgerActivityRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required kind, required refTable, required refId, required at, value, payload = const {}}) =>
      hub.recordCompletion(LedgerService.planetKey, kind, refTable, refId, at: at, value: value, payload: payload);
});

final ledgerServiceProvider = Provider<LedgerService>(
  (ref) => LedgerService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(ledgerClockProvider),
    recorder: ref.watch(ledgerActivityRecorderProvider),
  ),
);

final ledgerCurrenciesProvider = StreamProvider<List<LedgerCurrency>>(
  (ref) => ref.watch(ledgerServiceProvider).watchCurrencies(),
);

final ledgerWalletsProvider = StreamProvider<List<LedgerWallet>>(
  (ref) => ref.watch(ledgerServiceProvider).watchWallets(),
);

final ledgerTransactionsProvider = StreamProvider<List<LedgerTx>>(
  (ref) => ref.watch(ledgerServiceProvider).watchTransactions(),
);

final ledgerBudgetItemsProvider = StreamProvider<List<BudgetItemRow>>(
  (ref) => ref.watch(ledgerServiceProvider).watchBudgetItems(),
);

final ledgerWeeksPerMonthProvider = StreamProvider<num?>(
  (ref) => ref.watch(ledgerServiceProvider).watchWeeksPerMonth(),
);

final ledgerRatesAreDefaultsProvider = StreamProvider<bool>(
  (ref) => ref.watch(ledgerServiceProvider).watchRatesAreDefaults(),
);

/// The whole ledger as one consistent snapshot, recomputed when any table
/// changes.
final ledgerBookProvider = Provider<AsyncValue<LedgerBook>>((ref) {
  final currencies = ref.watch(ledgerCurrenciesProvider);
  final wallets = ref.watch(ledgerWalletsProvider);
  final txs = ref.watch(ledgerTransactionsProvider);
  final items = ref.watch(ledgerBudgetItemsProvider);
  final weeks = ref.watch(ledgerWeeksPerMonthProvider);
  final defaults = ref.watch(ledgerRatesAreDefaultsProvider);
  for (final a in <AsyncValue<Object?>>[currencies, wallets, txs, items]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  }
  final c = currencies.value, w = wallets.value, t = txs.value, b = items.value;
  if (c == null || w == null || t == null || b == null) return const AsyncLoading();
  return AsyncData(
    LedgerBook(
      currencies: c,
      wallets: w,
      transactions: t,
      budgetNodes: [for (final r in b) LedgerRows.budgetNode(r)],
      budgetLooks: {for (final r in b) r.id: BudgetItemLook(color: r.color, icon: r.icon)},
      weeksPerMonth: weeks.value ?? BudgetSettings.defaultWeeksPerMonth,
      ratesAreDefaults: defaults.value ?? false,
      weekStart: ref.watch(ledgerWeekStartProvider),
    ),
  );
});

/// The money formatter for [context] (locale + the user's digit style)
/// with the book's currencies.
LedgerMoneyFormat ledgerFormatOf(BuildContext context, [LedgerBook? book]) {
  final f = MadarFormatter.of(context);
  return LedgerMoneyFormat(
    arabic: f.isArabic,
    arabicIndic: f.arabicIndic,
    currencies: book?.currencyByCode ?? const {},
  );
}
