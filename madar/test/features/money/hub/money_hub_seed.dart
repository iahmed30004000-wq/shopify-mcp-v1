// Example data for the Money hub's tests only (a fresh install starts
// empty): written through the money packages' own services, so every
// linked entry (a jar deposit from a wallet, a debt lent from a wallet)
// exists exactly as the app writes it.
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

import '../../orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;

/// Tuesday 29 Sep 2026, 13:10.
final DateTime moneyHubNow = DateTime(2026, 9, 29, 13, 10);

/// Ids of the example.
class MoneyHubIds {
  MoneyHubIds();

  late String cash, bank, egypt, jar, debtIOwe, debtOwed, internet, food, fuel;
}

/// The planet page needs prayer times; nothing else.
Future<void> seedMoneyFresh(MadarDatabase db) =>
    OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

/// Three wallets (JOD cash and bank, an EGP business wallet), a budget of
/// two items (fuel overspent this month), three entries, a jar funded from
/// the bank, a debt the user owes (overdue two days), money lent from cash,
/// and a monthly internet bill due in two days.
///
/// Net worth: wallets 105 + 1 570 + 290 (20 000 EGP × 0.0145) = 1 965,
/// jars 300, owed to you 75, you owe 150 → 2 190.000 JOD.
Future<MoneyHubIds> seedMoneyHub(MadarDatabase db, {bool arabic = false, DateTime? now}) async {
  final n = now ?? moneyHubNow;
  String tr(String ar, String en) => arabic ? ar : en;
  final repos = Repositories(db);
  await OrbitRepository(repos).setPrayerSettings(hostPrayerSettings());
  final ids = MoneyHubIds();
  final ledger = LedgerService(repos, clock: () => n);
  final goals = GoalsService(repos, clock: () => n);
  final budget = BudgetRepository(repos, clock: () => n);

  ids.cash = (await ledger.addWallet(name: tr('الصندوق', 'Cash'), currency: 'JOD', openingMilli: 300000)).id;
  ids.bank = (await ledger.addWallet(name: tr('البنك', 'Bank'), currency: 'JOD', openingMilli: 1500000)).id;
  ids.egypt = (await ledger.addWallet(
    name: tr('مبيعات مصر', 'Egypt sales'),
    currency: 'EGP',
    openingMilli: 20000000,
    kind: WalletKind.business,
  )).id;

  ids.food = 'b.food';
  ids.fuel = 'b.fuel';
  await budget.add(BudgetNode(id: ids.food, name: tr('طعام البيت', 'Home food'), amountMilli: 200000));
  await budget.add(BudgetNode(id: ids.fuel, name: tr('وقود السيارة', 'Car fuel'), amountMilli: 100000));

  await ledger.add(
    TxWrite(
      walletId: ids.cash,
      kind: TxKind.expense,
      amountMilli: 120000,
      date: DateTime(n.year, n.month, 10),
      budgetItemId: ids.food,
      note: tr('مشتريات البيت', 'Groceries'),
    ),
  );
  await ledger.add(
    TxWrite(
      walletId: ids.bank,
      kind: TxKind.expense,
      amountMilli: 130000,
      date: DateTime(n.year, n.month, 20),
      budgetItemId: ids.fuel,
      note: tr('وقود', 'Fuel'),
    ),
  );
  await ledger.add(
    TxWrite(
      walletId: ids.bank,
      kind: TxKind.income,
      amountMilli: 500000,
      date: DateTime(n.year, n.month, 25),
      note: tr('تحصيل الطلبات', 'COD payout'),
    ),
  );

  ids.jar = (await goals.addJar(
    JarDraft(
      name: tr('سفر العائلة', 'Family trip'),
      targetMilli: 1200000,
      currency: 'JOD',
      deadline: DateTime(2027, 6, 1),
    ),
  )).id;
  await goals.moveJarMoney(ids.jar, amountMilli: 300000, walletId: ids.bank, date: DateTime(n.year, n.month, 15));

  ids.debtIOwe = (await goals.addDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      person: tr('خالد', 'Khaled'),
      amountMilli: 150000,
      currency: 'JOD',
      dueDate: DateTime(n.year, n.month, n.day - 2),
    ),
  )).id;
  ids.debtOwed = (await goals.addDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      person: tr('سامر', 'Samer'),
      amountMilli: 75000,
      currency: 'JOD',
      walletId: ids.cash,
    ),
  )).id;

  ids.internet = (await goals.addObligation(
    ObligationDraft(
      name: tr('الإنترنت', 'Internet'),
      amountMilli: 25000,
      currency: 'JOD',
      frequency: Recurrence.monthly,
      nextDue: DateTime(n.year, n.month, n.day + 2),
      walletId: ids.bank,
    ),
  )).id;
  return ids;
}
