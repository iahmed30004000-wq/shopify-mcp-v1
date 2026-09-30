/// The Money hub's small decisions (pure Dart): net worth in the base
/// currency and the Money settings stored beside the budget's.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../goals/domain/goals_snapshot.dart';
import '../ledger/domain/ledger_book.dart';
import '../ledger/domain/ledger_models.dart';

/// What the user owns and owes, in the base currency, exact to the milli
/// (each part summed exactly at the manual rates and rounded once):
///
/// * the open wallets' balances (archived wallets left out);
/// * what the savings jars hold, archived ones too (money moved into a jar
///   left its wallet, so it is counted here once; archiving a jar keeps its
///   money and its wallet entries – only a withdrawal gives it back);
/// * what is still owed to the user, minus what the user still owes.
///
/// Amounts in a currency without a rate are left out and named in
/// [missingRates] (the hub offers to set them).
@immutable
class MoneyNetWorth {
  const MoneyNetWorth({
    required this.base,
    this.walletsMilli = 0,
    this.jarsMilli = 0,
    this.owedToMeMilli = 0,
    this.iOweMilli = 0,
    this.walletCount = 0,
    this.jarCount = 0,
    this.openDebtCount = 0,
    this.missingRates = const {},
  });

  factory MoneyNetWorth.of(LedgerBook book, GoalsSnapshot? goals) {
    final missing = <String>{...book.totals.missingRates};
    final jars = BaseSum(book.rates);
    final owed = BaseSum(book.rates);
    final owe = BaseSum(book.rates);
    var jarCount = 0, debtCount = 0;
    for (final j in goals?.jars ?? const <JarView>[]) {
      jarCount++;
      jars.add(math.max(0, j.plan.savedMilli), j.jar.currency);
    }
    for (final j in goals?.archivedJars ?? const <JarView>[]) {
      if (j.plan.savedMilli <= 0) continue;
      jarCount++;
      jars.add(j.plan.savedMilli, j.jar.currency);
    }
    for (final d in goals?.openDebts ?? const <DebtView>[]) {
      final s = d.state;
      if (s.settled) continue;
      debtCount++;
      (s.direction == DebtDirection.iOwe ? owe : owed).add(s.remainingMilli, s.currency);
    }
    missing
      ..addAll(jars.missing)
      ..addAll(owed.missing)
      ..addAll(owe.missing);
    return MoneyNetWorth(
      base: book.baseCode,
      walletsMilli: book.totals.baseMilli,
      jarsMilli: jars.milli,
      owedToMeMilli: owed.milli,
      iOweMilli: owe.milli,
      walletCount: book.totals.walletCount,
      jarCount: jarCount,
      openDebtCount: debtCount,
      missingRates: Set.unmodifiable(missing),
    );
  }

  /// Base currency code.
  final String base;

  final int walletsMilli;
  final int jarsMilli;
  final int owedToMeMilli;
  final int iOweMilli;
  final int walletCount;
  /// Active jars, plus archived jars still holding money.
  final int jarCount;
  final int openDebtCount;

  /// Currency codes without a usable rate (their amounts are left out).
  final Set<String> missingRates;

  /// Wallets + jars + owed to me − I owe.
  int get totalMilli => walletsMilli + jarsMilli + owedToMeMilli - iOweMilli;

  /// Nothing to add up yet (a fresh install).
  bool get isEmpty => walletCount == 0 && jarCount == 0 && openDebtCount == 0;

  /// The positive parts' shares of what the user owns (wallets, jars, owed
  /// to me; a negative wallet total counts as nothing), for the strip.
  ({double wallets, double jars, double owed}) get shares {
    final w = math.max(0, walletsMilli), j = math.max(0, jarsMilli), o = math.max(0, owedToMeMilli);
    final sum = w + j + o;
    if (sum == 0) return (wallets: 0, jars: 0, owed: 0);
    return (wallets: w / sum, jars: j / sum, owed: o / sum);
  }
}

/// The Money settings kept in `key_values` beside the budget's own
/// weeks-per-month (`money.budget.weeksPerMonth`).
abstract final class MoneySettings {
  /// First day of a week in every weekly Money view (the budget's weekly
  /// windows, the ledger's week filter and chart): a JSON int,
  /// [DateTime.monday] … [DateTime.sunday].
  static const String weekStartKey = 'money.weekStart';

  /// Saturday: the working week in Jordan starts on Sunday, but the
  /// household week (and the budget package's default) starts on Saturday.
  static const int defaultWeekStart = DateTime.saturday;

  /// The week starts offered (Saturday, Sunday, Monday).
  static const List<int> weekStarts = [DateTime.saturday, DateTime.sunday, DateTime.monday];

  /// A stored week start, tolerant (anything else: [defaultWeekStart]).
  static int weekStartOf(Object? json) {
    final v = json is num ? json.toInt() : null;
    return v != null && v >= DateTime.monday && v <= DateTime.sunday && v == json ? v : defaultWeekStart;
  }
}
