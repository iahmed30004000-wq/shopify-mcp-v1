/// Money · ledger: wallets, currencies & manual exchange rates, and the
/// transactions that move money between them.
///
/// * Screens: [MoneyLedgerScreen], [WalletScreen], [TransactionsScreen],
///   [CurrenciesScreen]; the compact [WalletsSummaryCard] for the Money hub.
/// * Sheets: [showTransactionSheet] (keypad-first add / edit), plus the
///   wallet, currency and base-currency sheets through [LedgerActions].
/// * Data: [ledgerBookProvider] (the whole ledger as one [LedgerBook]),
///   [ledgerServiceProvider] (every write, each with an undo).
/// * Pure logic: balances and totals ([LedgerMath], [LedgerTotals]),
///   reports ([LedgerReports]), money text ([LedgerMoneyFormat]), rates
///   ([RateMath], [RebasePlan]), filters ([TxFilter]), the keypad
///   ([AmountEntry]) and the form model ([TxDraft], [TxWrite]).
library;

export 'data/ledger_providers.dart';
export 'data/ledger_service.dart';
export 'domain/amount_entry.dart';
export 'domain/chart_scale.dart';
export 'domain/currency_math.dart';
export 'domain/ledger_book.dart';
export 'domain/ledger_format.dart';
export 'domain/ledger_math.dart';
export 'domain/ledger_models.dart';
export 'domain/ledger_reports.dart';
export 'domain/tx_draft.dart';
export 'domain/tx_filter.dart';
export 'presentation/charts/ledger_chart_cards.dart'
    show SpendingCard, TrendCard, BalanceCard, SpendingView, BalanceRange;
export 'presentation/currencies_screen.dart';
export 'presentation/ledger_actions.dart';
export 'presentation/money_ledger_screen.dart' show MoneyLedgerScreen, NetBalancePanel, RatesNotice;
export 'presentation/sheets/currency_sheet.dart' show showCurrencySheet;
export 'presentation/sheets/rebase_sheet.dart' show showRebaseSheet;
export 'presentation/sheets/transaction_sheet.dart' show showTransactionSheet, TransactionSheet, TransactionSheetResult;
export 'presentation/transactions_screen.dart';
export 'presentation/wallet_screen.dart';
export 'presentation/wallets_summary_card.dart';
