import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/ledger/domain/ledger_book.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';

/// A transaction for tests.
LedgerTx tx(
  String id,
  String walletId,
  TxKind kind,
  int amountMilli, {
  DateTime? date,
  DateTime? createdAt,
  String? budgetItemId,
  String? toWalletId,
  int? toAmountMilli,
  String? note,
  List<String> tags = const [],
}) => LedgerTx(
  id: id,
  walletId: walletId,
  kind: kind,
  amountMilli: amountMilli,
  date: date ?? DateTime(2026, 9, 10),
  createdAt: createdAt,
  budgetItemId: budgetItemId,
  toWalletId: toWalletId,
  toAmountMilli: toAmountMilli,
  note: note,
  tags: tags,
);

/// The generic seeded currencies (JOD base).
const seededCurrencies = [
  LedgerCurrency(
    code: 'JOD',
    nameAr: 'دينار أردني',
    nameEn: 'Jordanian dinar',
    symbol: 'د.أ',
    decimals: 3,
    isBase: true,
  ),
  LedgerCurrency(
    code: 'USD',
    nameAr: 'دولار أمريكي',
    nameEn: 'US dollar',
    symbol: r'$',
    decimals: 2,
    rateToBase: 0.709,
    sortOrder: 1,
  ),
  LedgerCurrency(
    code: 'SYP',
    nameAr: 'ليرة سورية',
    nameEn: 'Syrian pound',
    symbol: 'ل.س',
    decimals: 2,
    rateToBase: 0.0064,
    sortOrder: 2,
  ),
  LedgerCurrency(
    code: 'EGP',
    nameAr: 'جنيه مصري',
    nameEn: 'Egyptian pound',
    symbol: 'ج.م',
    decimals: 2,
    rateToBase: 0.0145,
    sortOrder: 3,
  ),
  LedgerCurrency(
    code: 'LYD',
    nameAr: 'دينار ليبي',
    nameEn: 'Libyan dinar',
    symbol: 'ل.د',
    decimals: 3,
    rateToBase: 0.13,
    sortOrder: 4,
  ),
];

const sampleWallets = [
  LedgerWallet(id: 'cash', name: 'Cash', currency: 'JOD', openingMilli: 200000),
  LedgerWallet(id: 'bank', name: 'Bank', currency: 'USD', sortOrder: 1),
  LedgerWallet(id: 'shop', name: 'Shop', currency: 'JOD', kind: WalletKind.business, sortOrder: 2),
  LedgerWallet(id: 'old', name: 'Old', currency: 'EGP', archived: true, sortOrder: 3),
];

const sampleBudget = [
  BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000),
  BudgetNode(id: 'proteins', name: 'Proteins', parentId: 'food', amountMilli: 100000),
  BudgetNode(id: 'spices', name: 'Spices', parentId: 'food', amountMilli: 20000, sortOrder: 1),
  BudgetNode(id: 'car', name: 'Car fuel', amountMilli: 100000, sortOrder: 1),
  BudgetNode(id: 'emergency', name: 'Emergency', amountMilli: 20000, sortOrder: 2),
];

List<LedgerTx> sampleTransactions() => [
  tx('salary', 'bank', TxKind.income, 500000, date: DateTime(2026, 9, 1), note: 'Salary'),
  tx(
    'meat',
    'cash',
    TxKind.expense,
    20000,
    date: DateTime(2026, 9, 3),
    budgetItemId: 'proteins',
    tags: ['family'],
    note: 'Chicken',
  ),
  tx('spice', 'cash', TxKind.expense, 5000, date: DateTime(2026, 9, 4), budgetItemId: 'spices', tags: ['family']),
  tx(
    'fuel',
    'cash',
    TxKind.expense,
    30000,
    date: DateTime(2026, 9, 5),
    budgetItemId: 'car',
    tags: ['car'],
    note: 'Full tank',
  ),
  tx('adj', 'cash', TxKind.adjustment, 3000, date: DateTime(2026, 9, 6)),
  tx('lunch', 'bank', TxKind.expense, 10000, date: DateTime(2026, 9, 7), note: 'Lunch in Cairo'),
  tx('xfer', 'bank', TxKind.transfer, 100000, date: DateTime(2026, 9, 8), toWalletId: 'shop', toAmountMilli: 70900),
  tx('aug', 'shop', TxKind.expense, 1000, date: DateTime(2026, 8, 10)),
];

LedgerBook sampleBook() => LedgerBook(
  currencies: seededCurrencies,
  wallets: sampleWallets,
  transactions: sampleTransactions(),
  budgetNodes: sampleBudget,
);
