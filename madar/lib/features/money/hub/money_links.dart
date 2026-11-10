/// Where a Money record leads (pure mapping + one database look-up for the
/// ledger's linked entries): the Money world's reasons, the Neglect Radar,
/// the ledger's jar / debt / obligation entries and the due reminders all
/// open the same screens and sheets.
library;

import 'package:meta/meta.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/routing/routes.dart';
import '../ledger/domain/ledger_links.dart';
import '../ledger/domain/ledger_models.dart';

/// What opening a Money record shows.
@immutable
sealed class MoneyTarget {
  const MoneyTarget();
}

/// A money screen, pushed as its route.
final class MoneyRouteTarget extends MoneyTarget {
  const MoneyRouteTarget(this.location);

  final String location;

  @override
  bool operator ==(Object other) => other is MoneyRouteTarget && other.location == location;

  @override
  int get hashCode => location.hashCode;

  @override
  String toString() => 'MoneyRouteTarget($location)';
}

/// A debt's sheet, over whatever is open.
final class MoneyDebtTarget extends MoneyTarget {
  const MoneyDebtTarget(this.debtId);

  final String debtId;

  @override
  bool operator ==(Object other) => other is MoneyDebtTarget && other.debtId == debtId;

  @override
  int get hashCode => Object.hash('debt', debtId);

  @override
  String toString() => 'MoneyDebtTarget($debtId)';
}

/// A recurring obligation's sheet, over whatever is open.
final class MoneyObligationTarget extends MoneyTarget {
  const MoneyObligationTarget(this.obligationId);

  final String obligationId;

  @override
  bool operator ==(Object other) => other is MoneyObligationTarget && other.obligationId == obligationId;

  @override
  int get hashCode => Object.hash('obligation', obligationId);

  @override
  String toString() => 'MoneyObligationTarget($obligationId)';
}

abstract final class MoneyLinks {
  /// Tables whose records open a Money screen or sheet.
  static const Set<String> tables = {
    'wallets',
    'transactions',
    'currencies',
    'budget_items',
    'jars',
    'debts',
    'obligations',
  };

  /// Where the record `refTable:refId` leads (a reason about a whole table
  /// has no [refId]), or null when it is not a Money record:
  ///
  /// * a wallet → its screen; entries → the ledger; currencies → the rates;
  /// * a budget item (overspent) → the budget's spending tab;
  /// * a jar → its screen; a debt or an obligation → its sheet (the tab of
  ///   all of them without an id).
  static MoneyTarget? targetOf(String? refTable, String? refId) {
    final id = refId == null || refId.isEmpty ? null : refId;
    return switch (refTable) {
      'wallets' => MoneyRouteTarget(id == null ? AppRoutes.ledger : AppRoutes.walletOf(id)),
      'transactions' => const MoneyRouteTarget(AppRoutes.ledger),
      'currencies' => const MoneyRouteTarget(AppRoutes.currencies),
      'budget_items' => MoneyRouteTarget(AppRoutes.budgetOf(tab: 'spending')),
      'jars' => MoneyRouteTarget(id == null ? AppRoutes.goalsOf(tab: 'jars') : AppRoutes.jarOf(id)),
      'debts' => id == null ? MoneyRouteTarget(AppRoutes.goalsOf(tab: 'debts')) : MoneyDebtTarget(id),
      'obligations' => id == null ? MoneyRouteTarget(AppRoutes.goalsOf(tab: 'obligations')) : MoneyObligationTarget(id),
      _ => null,
    };
  }

  /// The jar, debt or obligation a linked ledger entry belongs to (its
  /// other half is looked up: a jar movement, a debt payment, an obligation
  /// payment; a debt's opening entry names the debt itself). A missing other
  /// half (deleted meanwhile) opens the tab of its kind.
  static Future<MoneyTarget?> linkedTarget(Repositories repos, LedgerTx tx, LedgerLink link) async {
    final source = LedgerLinks.sourceId(tx);
    if (source == null) return null;
    switch (link) {
      case LedgerLink.jar:
        final move = await repos.jarDeposits.byId(source);
        return MoneyRouteTarget(move == null ? AppRoutes.goalsOf(tab: 'jars') : AppRoutes.jarOf(move.jarId));
      case LedgerLink.debt:
        if (LedgerLinks.isDebtOpening(tx)) {
          return await repos.debts.byId(source) == null
              ? MoneyRouteTarget(AppRoutes.goalsOf(tab: 'debts'))
              : MoneyDebtTarget(source);
        }
        final payment = await repos.debtPayments.byId(source);
        return payment == null ? MoneyRouteTarget(AppRoutes.goalsOf(tab: 'debts')) : MoneyDebtTarget(payment.debtId);
      case LedgerLink.obligation:
        final payment = await repos.obligationPayments.byId(source);
        return payment == null
            ? MoneyRouteTarget(AppRoutes.goalsOf(tab: 'obligations'))
            : MoneyObligationTarget(payment.obligationId);
    }
  }
}
