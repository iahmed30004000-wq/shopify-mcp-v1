import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// All money amounts are stored as integer *milli-units* (amount × 1000) so
// 3-decimal currencies (JOD, LYD) and 2-decimal ones share exact integer math.
// No tax / VAT / government-fee / zakat fields exist anywhere by design.

/// Currencies with manual exchange rates to the base currency.
@DataClassName('CurrencyRow')
class Currencies extends Table {
  TextColumn get code => text()(); // ISO-like code: JOD, USD, SYP, EGP, LYD …
  TextColumn get nameAr => text()();
  TextColumn get nameEn => text()();
  TextColumn get symbol => text()();
  IntColumn get decimals => integer().withDefault(const Constant(2))();

  /// 1 unit of this currency = [rateToBase] units of the base currency.
  RealColumn get rateToBase => real().withDefault(const Constant(1.0))();
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

@DataClassName('WalletRow')
class Wallets extends Table with Entity, Ordered {
  TextColumn get name => text()();
  TextColumn get currency => text()();
  IntColumn get openingMilli => integer().withDefault(const Constant(0))();
  TextColumn get kind => textEnum<WalletKind>().withDefault(Constant(WalletKind.personal.name))();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Nested budget. Each item is set by amount OR percentage (of its parent or of
/// the total); the other value is derived (see `BudgetMath`).
@DataClassName('BudgetItemRow')
class BudgetItems extends Table with Entity, Ordered {
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get mode => textEnum<BudgetMode>().withDefault(Constant(BudgetMode.amount.name))();
  IntColumn get amountMilli => integer().nullable()();
  RealColumn get percent => real().nullable()();
  TextColumn get percentOf => textEnum<PercentBase>().withDefault(Constant(PercentBase.parent.name))();

  /// Period the amount is expressed in (weekly amounts are converted with the
  /// configurable weeks-per-month setting).
  TextColumn get period => textEnum<BudgetPeriod>().withDefault(Constant(BudgetPeriod.monthly.name))();

  /// Null = base currency.
  TextColumn get currency => text().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
}

@DataClassName('TransactionRow')
class Transactions extends Table with Entity {
  TextColumn get walletId => text()();
  TextColumn get kind => textEnum<TxKind>()();

  /// Positive, with the direction coming from [kind] – except for
  /// [TxKind.adjustment], whose amount is signed (a negative adjustment
  /// lowers the wallet balance).
  IntColumn get amountMilli => integer()();
  DateTimeColumn get date => dateTime().map(const CalendarDayConverter())();
  TextColumn get budgetItemId => text().nullable()();

  /// Transfers: destination wallet and the amount received there (may differ
  /// when currencies differ).
  TextColumn get toWalletId => text().nullable()();
  IntColumn get toAmountMilli => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
}

/// Savings jars (e.g. travel) with target and deadline.
@DataClassName('JarRow')
class Jars extends Table with Entity, Ordered {
  TextColumn get name => text()();
  IntColumn get targetMilli => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get deadline => dateTime().map(const CalendarDayConverter()).nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('JarDepositRow')
class JarDeposits extends Table with Entity {
  TextColumn get jarId => text()();

  /// Negative for withdrawals.
  IntColumn get amountMilli => integer()();
  DateTimeColumn get date => dateTime().map(const CalendarDayConverter())();
  TextColumn get walletId => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('DebtRow')
class Debts extends Table with Entity, Ordered {
  TextColumn get direction => textEnum<DebtDirection>()();
  TextColumn get person => text()();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get dueDate => dateTime().map(const CalendarDayConverter()).nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get settledAt => dateTime().nullable()();
}

@DataClassName('DebtPaymentRow')
class DebtPayments extends Table with Entity {
  TextColumn get debtId => text()();
  IntColumn get amountMilli => integer()();
  DateTimeColumn get date => dateTime().map(const CalendarDayConverter())();
  TextColumn get note => text().nullable()();
}

/// Recurring obligations; "Paid" advances [nextDue].
@DataClassName('ObligationRow')
class Obligations extends Table with Entity, Ordered {
  TextColumn get name => text()();
  IntColumn get amountMilli => integer()();
  TextColumn get currency => text()();
  TextColumn get walletId => text().nullable()();
  TextColumn get budgetItemId => text().nullable()();
  TextColumn get frequency => textEnum<Recurrence>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDue => dateTime().map(const CalendarDayConverter())();
  TextColumn get note => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('ObligationPaymentRow')
class ObligationPayments extends Table with Entity {
  TextColumn get obligationId => text()();
  DateTimeColumn get dueDate => dateTime().map(const CalendarDayConverter())();
  DateTimeColumn get paidAt => dateTime()();
  IntColumn get amountMilli => integer()();
  TextColumn get transactionId => text().nullable()();
}
