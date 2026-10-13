import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../../lists/lists.dart'
    show ListCurrencies, ListHost, ListPostPlan, ListPostRefusal, ListService, ListUndo, listCurrenciesProvider, listServiceProvider;
import '../../ledger/data/ledger_providers.dart';
import '../../ledger/data/ledger_service.dart';
import '../../ledger/domain/ledger_math.dart';
import '../../ledger/domain/tx_draft.dart';

/// What one attempt to post a shopping list did.
@immutable
class ShoppingPost {
  const ShoppingPost({required this.plan, this.txId, this.undo, this.envelopeName, this.walletId});

  /// What was posted – or, when [plan.refusal] is set, why nothing was.
  final ListPostPlan plan;

  /// The `transactions` row that was written (null when refused).
  final String? txId;

  /// Takes the entry back and opens the list again (null when refused).
  final ListUndo? undo;

  /// The envelope it was posted on («بقالة»).
  final String? envelopeName;

  /// The wallet it was taken from.
  final String? walletId;

  bool get posted => txId != null;
}

/// Turns the ticked part of a shopping list into **one** expense on the
/// budget envelope the list hangs on.
///
/// The money is always written by [LedgerService] – this service never
/// touches `transactions` itself – and the amount is the exact integer sum
/// the list engine computed ([ListPostPlan]); nothing is converted,
/// because a list's prices are typed in the envelope's own currency and
/// only a wallet in that currency can pay for it.
///
/// **It cannot charge him twice.** The list engine's [ListService.claimPost]
/// stamps the list inside one database transaction and returns false when
/// it was already stamped, and the entry is written only after a true
/// claim. A second tap – or a second screen – reads the stamp and is
/// refused with [ListPostRefusal.alreadyPosted]; if writing the entry
/// itself fails, the stamp is taken off again, so a list is never marked
/// posted without an entry behind it.
///
/// Un-ticked lines are never touched: he did not buy them, so they stay on
/// the list after a post.
class ShoppingPostService {
  ShoppingPostService({
    required this.lists,
    required this.ledger,
    required this.repos,
    DateTime Function()? clock,
    this.currencies = ListCurrencies.fallback,
  }) : clock = clock ?? DateTime.now;

  final ListService lists;
  final LedgerService ledger;
  final Repositories repos;
  final DateTime Function() clock;

  /// The base currency and each currency's decimals (a list with no
  /// currency of its own holds base-currency prices).
  final ListCurrencies currencies;

  /// The envelope a list hangs on, or null (it was deleted, or the list
  /// hangs on something else).
  Future<BudgetItemRow?> envelopeOf(RecordListRow row) async {
    if (row.hostTable != ListHost.budgetItems) return null;
    return repos.budgetItems.byId(row.hostId);
  }

  /// The wallets that can pay for [currency] (archived ones cannot).
  Future<List<WalletRow>> walletsIn(String currency) async {
    final code = currency.toUpperCase();
    final rows = await repos.wallets.getAll(where: (w) => w.archived.equals(false));
    return [
      for (final w in rows)
        if (w.currency.toUpperCase() == code) w,
    ];
  }

  /// What posting [listId] would do, without doing it.
  Future<ListPostPlan> preview(String listId) async {
    final bundle = await lists.bundle(listId);
    if (bundle == null) return ListPostPlan.nothing(ListPostRefusal.listGone, currency: currencies.base);
    final code = currencies.of(bundle.currency);
    if (bundle.row.hostTable != ListHost.budgetItems) {
      return ListPostPlan.nothing(ListPostRefusal.notAnEnvelope, currency: code);
    }
    final wallets = await walletsIn(code);
    return bundle.plan(currency: code, hasWallet: wallets.isNotEmpty);
  }

  /// Posts the ticked part of [listId] as one expense on its envelope.
  ///
  /// [walletId] is the wallet it comes out of; the only wallet in the
  /// list's currency when he was not asked. Returns what happened – a
  /// written entry with its undo, or the refusal.
  Future<ShoppingPost> post(String listId, {String? walletId, DateTime? date}) async {
    final bundle = await lists.bundle(listId);
    if (bundle == null) {
      return ShoppingPost(plan: ListPostPlan.nothing(ListPostRefusal.listGone, currency: currencies.base));
    }
    final code = currencies.of(bundle.currency);
    if (bundle.row.hostTable != ListHost.budgetItems) {
      return ShoppingPost(plan: ListPostPlan.nothing(ListPostRefusal.notAnEnvelope, currency: code));
    }
    final envelope = await envelopeOf(bundle.row);
    final wallets = await walletsIn(code);
    final plan = bundle.plan(currency: code, hasWallet: wallets.isNotEmpty);
    if (!plan.canPost) return ShoppingPost(plan: plan, envelopeName: envelope?.name);

    final wallet = wallets.where((w) => w.id == walletId).firstOrNull ?? wallets.first;

    // The guard: stamp the list first. A second attempt reads the stamp
    // and never reaches the ledger.
    final claimed = await lists.claimPost(
      listId,
      amountMilli: plan.amountMilli,
      itemCount: plan.itemCount,
      at: clock(),
    );
    if (!claimed) {
      return ShoppingPost(plan: plan.refused(ListPostRefusal.alreadyPosted), envelopeName: envelope?.name);
    }

    final day = LedgerMath.dayOf(date ?? clock());
    try {
      final tx = await ledger.add(
        TxWrite(
          walletId: wallet.id,
          kind: TxKind.expense,
          amountMilli: plan.amountMilli,
          date: day,
          budgetItemId: bundle.row.hostId,
          note: bundle.name,
        ),
      );
      await lists.attachPostTx(listId, tx.id);
      return ShoppingPost(
        plan: plan,
        txId: tx.id,
        envelopeName: envelope?.name,
        walletId: wallet.id,
        undo: () async {
          // `LedgerService.delete` performs the delete and hands back the
          // restore – the entry is gone, and the list opens again.
          await ledger.delete(tx.id);
          await lists.clearPost(listId);
        },
      );
    } catch (_) {
      // Never leave a list marked posted with no entry behind it.
      await lists.clearPost(listId);
      rethrow;
    }
  }
}

/// Posting a shopping list to the ledger (reads the currencies, so a
/// price in a two-decimal currency keeps its two decimals).
final shoppingPostServiceProvider = Provider<ShoppingPostService>((ref) {
  return ShoppingPostService(
    lists: ref.watch(listServiceProvider),
    ledger: ref.watch(ledgerServiceProvider),
    repos: ref.watch(repositoriesProvider),
    clock: ref.watch(ledgerClockProvider),
    currencies: ref.watch(listCurrenciesProvider).value ?? ListCurrencies.fallback,
  );
});
