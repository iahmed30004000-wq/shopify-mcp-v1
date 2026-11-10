/// The add / edit transaction form model (pure Dart): kind, wallets,
/// amounts, budget item, day, note and tags, with validation and the
/// resolution of transfer and adjustment amounts.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import 'ledger_math.dart';
import 'ledger_models.dart';

/// How a balance adjustment is entered.
enum AdjustMode {
  /// The keypad amount is the wallet's real balance; the entry stores the
  /// difference.
  setBalance,

  /// The keypad amount is the difference itself (± via [TxDraft.negative]).
  delta,
}

enum TxDraftError {
  noWallet,
  noAmount,
  noDestination,
  sameWallet,

  /// A transfer between currencies without a received amount or a rate.
  noRate,

  /// "Set balance" to the balance the wallet already has.
  noChange,
}

@immutable
class TxDraft {
  const TxDraft({
    this.kind = TxKind.expense,
    this.walletId,
    this.amountMilli = 0,
    this.toWalletId,
    this.toAmountMilli,
    this.budgetItemId,
    required this.date,
    this.note = '',
    this.tags = const [],
    this.adjustMode = AdjustMode.setBalance,
    this.negative = false,
  });

  /// A draft editing [tx] (adjustments open in [AdjustMode.delta]).
  factory TxDraft.fromTx(LedgerTx tx) => TxDraft(
    kind: tx.kind,
    walletId: tx.walletId,
    amountMilli: tx.amountMilli.abs(),
    toWalletId: tx.toWalletId,
    toAmountMilli: tx.isTransfer ? tx.toAmountMilli : null,
    budgetItemId: tx.budgetItemId,
    date: LedgerMath.dayOf(tx.date),
    note: tx.note ?? '',
    tags: tx.tags,
    adjustMode: AdjustMode.delta,
    negative: tx.kind == TxKind.adjustment && tx.amountMilli < 0,
  );

  final TxKind kind;
  final String? walletId;

  /// Magnitude typed on the keypad, in the wallet's currency (for
  /// [AdjustMode.setBalance], the new balance's magnitude).
  final int amountMilli;
  final String? toWalletId;

  /// Received amount, in the destination's currency; null = derive it from
  /// the rates (or the same number for the same currency).
  final int? toAmountMilli;
  final String? budgetItemId;
  final DateTime date;
  final String note;
  final List<String> tags;
  final AdjustMode adjustMode;

  /// Adjustments: the typed amount is negative (an overdrawn balance, or a
  /// downward correction).
  final bool negative;

  bool get isTransfer => kind == TxKind.transfer;
  bool get isAdjustment => kind == TxKind.adjustment;

  /// Whether a budget item applies (expenses and income).
  bool get usesBudgetItem => kind == TxKind.expense || kind == TxKind.income;

  /// The typed amount with its sign (adjustments).
  int get signedAmountMilli => negative ? -amountMilli : amountMilli;

  TxDraft copyWith({
    TxKind? kind,
    String? walletId,
    int? amountMilli,
    String? toWalletId,
    bool clearToWallet = false,
    int? toAmountMilli,
    bool clearToAmount = false,
    String? budgetItemId,
    bool clearBudgetItem = false,
    DateTime? date,
    String? note,
    List<String>? tags,
    AdjustMode? adjustMode,
    bool? negative,
  }) => TxDraft(
    kind: kind ?? this.kind,
    walletId: walletId ?? this.walletId,
    amountMilli: amountMilli ?? this.amountMilli,
    toWalletId: clearToWallet ? null : (toWalletId ?? this.toWalletId),
    toAmountMilli: clearToAmount ? null : (toAmountMilli ?? this.toAmountMilli),
    budgetItemId: clearBudgetItem ? null : (budgetItemId ?? this.budgetItemId),
    date: date ?? this.date,
    note: note ?? this.note,
    tags: tags ?? this.tags,
    adjustMode: adjustMode ?? this.adjustMode,
    negative: negative ?? this.negative,
  );

  /// The received amount of a transfer: always the same number between two
  /// wallets of one currency (money moved there is neither lost nor made,
  /// whatever an earlier save stored); else the typed one, else converted
  /// with [rates] and rounded to the destination's minor unit
  /// ([toDecimals]). Null when it cannot be known.
  int? resolvedToAmount({
    required String? fromCurrency,
    required String? toCurrency,
    required LedgerRates rates,
    int? toDecimals,
  }) {
    if (!isTransfer) return null;
    final same = fromCurrency != null && toCurrency != null && fromCurrency.toUpperCase() == toCurrency.toUpperCase();
    if (same) return amountMilli;
    if (toAmountMilli != null && toAmountMilli! > 0) return toAmountMilli;
    if (fromCurrency == null || toCurrency == null) return null;
    return rates.convert(amountMilli, fromCurrency, toCurrency, decimals: toDecimals);
  }

  /// What arrives when a stored cross-currency transfer of [sentMilli] →
  /// [receivedMilli] is edited to send [newSentMilli]: the transfer's own
  /// rate is kept (not today's), exactly, rounded half-up once to the
  /// destination's minor unit ([toDecimals]; 3 = milli).
  static int rescaleReceived({
    required int sentMilli,
    required int receivedMilli,
    required int newSentMilli,
    int toDecimals = 3,
  }) {
    if (sentMilli == 0 || newSentMilli == 0) return 0;
    final exact = Rational.fromInt(receivedMilli.abs()) * Rational.fromInt(newSentMilli.abs(), sentMilli.abs());
    final d = toDecimals.clamp(0, 3);
    if (d >= 3) return exact.roundHalfUp();
    final step = BigInt.from(10).pow(3 - d).toInt();
    return (exact / Rational.fromInt(step)).roundHalfUp() * step;
  }

  /// The signed amount an adjustment stores, given the wallet's current
  /// balance (excluding the entry being edited).
  int adjustmentDelta(int currentBalanceMilli) =>
      adjustMode == AdjustMode.setBalance ? signedAmountMilli - currentBalanceMilli : signedAmountMilli;

  /// Problems preventing a save. [currentBalanceMilli] is needed for
  /// "set balance" adjustments; [currencyOf] maps wallet ids to currencies.
  List<TxDraftError> validate({
    int? currentBalanceMilli,
    String? Function(String walletId)? currencyOf,
    LedgerRates? rates,
  }) {
    final errors = <TxDraftError>[];
    if (walletId == null) errors.add(TxDraftError.noWallet);
    if (isAdjustment) {
      if (adjustMode == AdjustMode.delta && amountMilli == 0) errors.add(TxDraftError.noAmount);
      if (adjustMode == AdjustMode.setBalance &&
          currentBalanceMilli != null &&
          adjustmentDelta(currentBalanceMilli) == 0) {
        errors.add(TxDraftError.noChange);
      }
      return errors;
    }
    if (amountMilli <= 0) errors.add(TxDraftError.noAmount);
    if (isTransfer) {
      if (toWalletId == null) {
        errors.add(TxDraftError.noDestination);
      } else if (toWalletId == walletId) {
        errors.add(TxDraftError.sameWallet);
      } else if (walletId != null && currencyOf != null && rates != null && amountMilli > 0) {
        final resolved = resolvedToAmount(
          fromCurrency: currencyOf(walletId!),
          toCurrency: currencyOf(toWalletId!),
          rates: rates,
        );
        if (resolved == null) errors.add(TxDraftError.noRate);
      }
    }
    return errors;
  }

  @override
  bool operator ==(Object other) =>
      other is TxDraft &&
      other.kind == kind &&
      other.walletId == walletId &&
      other.amountMilli == amountMilli &&
      other.toWalletId == toWalletId &&
      other.toAmountMilli == toAmountMilli &&
      other.budgetItemId == budgetItemId &&
      other.date == date &&
      other.note == note &&
      _eq(other.tags, tags) &&
      other.adjustMode == adjustMode &&
      other.negative == negative;

  @override
  int get hashCode => Object.hash(
    kind,
    walletId,
    amountMilli,
    toWalletId,
    toAmountMilli,
    budgetItemId,
    date,
    note,
    Object.hashAll(tags),
    adjustMode,
    negative,
  );
}

bool _eq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The values a draft writes (after resolution).
@immutable
class TxWrite {
  const TxWrite({
    required this.walletId,
    required this.kind,
    required this.amountMilli,
    required this.date,
    this.budgetItemId,
    this.toWalletId,
    this.toAmountMilli,
    this.note,
    this.tags = const [],
  });

  final String walletId;
  final TxKind kind;

  /// Positive, except adjustments (signed).
  final int amountMilli;
  final DateTime date;
  final String? budgetItemId;
  final String? toWalletId;
  final int? toAmountMilli;
  final String? note;
  final List<String> tags;

  /// Resolves [draft] into the row to write, or null when it is invalid.
  /// [currentBalanceMilli] = the wallet's balance without the entry being
  /// edited (for "set balance" adjustments).
  static TxWrite? of(
    TxDraft draft, {
    required String? Function(String walletId) currencyOf,
    required LedgerRates rates,
    int currentBalanceMilli = 0,
    int? Function(String code)? decimalsOf,
  }) {
    final errors = draft.validate(currentBalanceMilli: currentBalanceMilli, currencyOf: currencyOf, rates: rates);
    if (errors.isNotEmpty) return null;
    final wallet = draft.walletId!;
    final note = draft.note.trim();
    final tags = <String>[
      for (final t in draft.tags)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    final uniqueTags = <String>{...tags}.toList();
    switch (draft.kind) {
      case TxKind.adjustment:
        return TxWrite(
          walletId: wallet,
          kind: TxKind.adjustment,
          amountMilli: draft.adjustmentDelta(currentBalanceMilli),
          date: LedgerMath.dayOf(draft.date),
          note: note.isEmpty ? null : note,
          tags: uniqueTags,
        );
      case TxKind.transfer:
        final toCurrency = currencyOf(draft.toWalletId!);
        final received = draft.resolvedToAmount(
          fromCurrency: currencyOf(wallet),
          toCurrency: toCurrency,
          rates: rates,
          toDecimals: toCurrency == null ? null : decimalsOf?.call(toCurrency),
        );
        return TxWrite(
          walletId: wallet,
          kind: TxKind.transfer,
          amountMilli: draft.amountMilli,
          date: LedgerMath.dayOf(draft.date),
          toWalletId: draft.toWalletId,
          toAmountMilli: received,
          note: note.isEmpty ? null : note,
          tags: uniqueTags,
        );
      case TxKind.expense:
      case TxKind.income:
        return TxWrite(
          walletId: wallet,
          kind: draft.kind,
          amountMilli: draft.amountMilli,
          date: LedgerMath.dayOf(draft.date),
          budgetItemId: draft.budgetItemId,
          note: note.isEmpty ? null : note,
          tags: uniqueTags,
        );
    }
  }
}
