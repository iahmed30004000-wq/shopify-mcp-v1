import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/notifications/notifications.dart';
import '../core/routing/money_route_pages.dart';
import '../core/routing/routes.dart';
import '../features/money/budget/budget.dart' show budgetWeekStartProvider;
import '../features/money/goals/goals.dart'
    show DueReminderKind, GoalsReminderTaps, goalsNavigationProvider, goalsReminderSyncProvider;
import '../features/money/hub/money_providers.dart';
import '../features/money/ledger/ledger.dart' show ledgerRoutesProvider, ledgerWeekStartProvider;

/// The Phase 5 money packages' cross-feature hooks, wired once for the
/// whole app (bootstrap and the test harness share them through
/// `madarAppOverrides`):
///
/// * the ledger's screens open as routes, an entry booked by a jar, a debt
///   or an obligation opens its jar / debt / obligation, and the ledger's
///   budget item picker is the budget package's tree picker
///   ([routedLedgerRoutes]);
/// * the goals' "see all" and jars open as routes ([RoutedGoalsNavigation]);
/// * every weekly Money view – the budget's weeks and the ledger's week
///   filter and chart – starts on the user's week start (Settings › Money,
///   [moneyWeekStartProvider]).
List<Override> moneyHookOverrides() => [
  ledgerRoutesProvider.overrideWith(routedLedgerRoutes),
  goalsNavigationProvider.overrideWithValue(const RoutedGoalsNavigation()),
  budgetWeekStartProvider.overrideWith((ref) => ref.watch(moneyWeekStartProvider)),
  ledgerWeekStartProvider.overrideWith((ref) => ref.watch(moneyWeekStartProvider)),
];

/// The money services the unlocked app keeps running (watched by
/// `AppServices`, inside the database gate and outside the app lock): the
/// next 62 days of debt and obligation due reminders, re-planned whenever a
/// due date, an amount, the reminder settings, the language or the day
/// changes ([goalsReminderSyncProvider]).
void watchMoneyServices(WidgetRef ref) {
  ref.watch(goalsReminderSyncProvider);
}

/// Where a tap on a money notification leads (pure), or null when [tap] is
/// not one: a due reminder opens the goals on its tab with that debt's or
/// obligation's sheet up (`/goals?tab=debts&debt=<id>`).
String? moneyNotificationLocation(NotificationTap tap) {
  final target = GoalsReminderTaps.targetOf(tap);
  if (target == null) return null;
  return switch (target.kind) {
    DueReminderKind.debt => AppRoutes.goalsOf(debt: target.id),
    DueReminderKind.obligation => AppRoutes.goalsOf(obligation: target.id),
  };
}
