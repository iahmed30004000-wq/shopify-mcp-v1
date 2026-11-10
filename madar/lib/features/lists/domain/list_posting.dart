/// What turning the ticked part of a list into one money entry would do,
/// and the reasons it cannot be done. Pure Dart – the arithmetic the
/// preview («٣ أغراض — ٨٫٠٠٠ د.أ») and the write both read.
library;

import 'package:meta/meta.dart';

import 'record_list.dart';

/// Why a list cannot be posted right now.
enum ListPostRefusal {
  /// It was already posted. The entry exists; posting again would charge
  /// him twice for one shop, so it is refused, not repeated.
  alreadyPosted,

  /// Nothing is ticked – he has bought nothing yet.
  nothingTicked,

  /// Ticked lines, but none carries a price: there is no amount to post.
  noAmount,

  /// No wallet in the list's currency to take the money from.
  noWallet,

  /// The list itself is gone (deleted while the bar was on screen).
  listGone,

  /// Its host is not a budget envelope, so there is nothing to post it
  /// on (a trip's list is never an expense on its own).
  notAnEnvelope,
}

/// The one entry posting would write.
@immutable
class ListPostPlan {
  const ListPostPlan({
    required this.itemCount,
    required this.amountMilli,
    required this.currency,
    required this.pricedCount,
    this.refusal,
  });

  /// The plan for a list with [totals] in [currency].
  ///
  /// [posted] is the list's own posted mark (the only thing that makes
  /// posting idempotent); [hasWallet] whether a wallet in [currency]
  /// exists to take the money from.
  factory ListPostPlan.of({
    required ListTotals totals,
    required String currency,
    required bool posted,
    required bool hasWallet,
  }) {
    final refusal = posted
        ? ListPostRefusal.alreadyPosted
        : totals.done == 0
        ? ListPostRefusal.nothingTicked
        : totals.pricedDone == 0 || totals.doneAmountMilli == 0
        ? ListPostRefusal.noAmount
        : hasWallet
        ? null
        : ListPostRefusal.noWallet;
    return ListPostPlan(
      itemCount: totals.done,
      amountMilli: totals.doneAmountMilli,
      currency: currency.toUpperCase(),
      pricedCount: totals.pricedDone,
      refusal: refusal,
    );
  }

  /// How many ticked lines the entry stands for («٣ أغراض»).
  final int itemCount;

  /// The exact amount, in milli-units of [currency].
  final int amountMilli;

  final String currency;

  /// How many of those lines carry a price (the rest cost nothing he
  /// typed, and are simply listed with the entry).
  final int pricedCount;

  /// Null when it can be posted.
  final ListPostRefusal? refusal;

  /// The same plan, refused for [reason] (the race a second tap loses).
  ListPostPlan refused(ListPostRefusal reason) => ListPostPlan(
    itemCount: itemCount,
    amountMilli: amountMilli,
    currency: currency,
    pricedCount: pricedCount,
    refusal: reason,
  );

  /// A refusal with nothing to show (the list is gone, the host is not an
  /// envelope).
  static ListPostPlan nothing(ListPostRefusal reason, {String currency = 'JOD'}) =>
      ListPostPlan(itemCount: 0, amountMilli: 0, currency: currency, pricedCount: 0, refusal: reason);

  bool get canPost => refusal == null;

  /// Ticked lines he gave no price for – they travel with the entry but
  /// add nothing to it.
  int get unpricedCount => itemCount - pricedCount;

  @override
  bool operator ==(Object other) =>
      other is ListPostPlan &&
      other.itemCount == itemCount &&
      other.amountMilli == amountMilli &&
      other.currency == currency &&
      other.pricedCount == pricedCount &&
      other.refusal == refusal;

  @override
  int get hashCode => Object.hash(itemCount, amountMilli, currency, pricedCount, refusal);

  @override
  String toString() => 'ListPostPlan($itemCount × $amountMilli $currency${refusal == null ? '' : ', $refusal'})';
}
