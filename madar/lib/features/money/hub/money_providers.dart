import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../goals/data/goals_providers.dart' show goalsSnapshotProvider;
import '../ledger/data/ledger_providers.dart' show ledgerBookProvider;
import 'money_hub_logic.dart';

/// The user's week start as stored ([MoneySettings.weekStartKey]).
final moneyWeekStartStoredProvider = StreamProvider<int>(
  (ref) => ref
      .watch(repositoriesProvider)
      .keyValues
      .watchJson(MoneySettings.weekStartKey)
      .map(MoneySettings.weekStartOf)
      .distinct(),
);

/// First day of a week in every weekly Money view (Saturday until the
/// stored value has loaded). The app hands it to the budget and the ledger
/// (see `moneyHookOverrides`).
final moneyWeekStartProvider = Provider<int>(
  (ref) => ref.watch(moneyWeekStartStoredProvider).value ?? MoneySettings.defaultWeekStart,
);

/// Stores the week start [day] ([DateTime.monday] … [DateTime.sunday]).
Future<void> setMoneyWeekStart(Repositories repos, int day) =>
    repos.keyValues.setJson(MoneySettings.weekStartKey, MoneySettings.weekStartOf(day));

/// Net worth in the base currency, from the ledger and the goals (null
/// while they load).
final moneyNetWorthProvider = Provider<MoneyNetWorth?>((ref) {
  final book = ref.watch(ledgerBookProvider).value;
  if (book == null) return null;
  return MoneyNetWorth.of(book, ref.watch(goalsSnapshotProvider));
});
