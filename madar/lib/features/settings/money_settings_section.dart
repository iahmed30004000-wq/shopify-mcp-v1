import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/repositories/repositories.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart' show ChoiceOption;
import '../../core/domain/budget_math.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/interaction.dart';
import '../../core/routing/routes.dart';
import '../money/budget/budget.dart'
    show BudgetCurrencies, BudgetFormat, budgetCurrenciesProvider, budgetRepositoryProvider, budgetWeeksPerMonthProvider,
        showBudgetWeeksSheet;
import '../money/goals/goals.dart' show GoalsActions, GoalsReminderSettings, goalsReminderSettingsProvider;
import '../money/hub/money_hub_logic.dart';
import '../money/hub/money_providers.dart';
import '../money/ledger/ledger.dart' show LedgerCurrency, ledgerCurrenciesProvider;
import 'widgets/settings_widgets.dart';

/// Settings › Money: the base currency and the manual rates (the
/// currencies screen), weeks per month (weekly ↔ monthly budget amounts),
/// the first day of the week (the budget's weekly items and the ledger's
/// weekly views) and the debts' and bills' due reminders. Every change is
/// saved through its package's own store, so the budget, the ledger and the
/// reminders follow at once.
class MoneySettingsSection extends ConsumerWidget {
  const MoneySettingsSection({super.key, this.seed = 0.27});

  final double seed;

  static String weekdayName(L10n l, int day) => switch (day) {
    DateTime.sunday => l.moneyHubWeekSunday,
    DateTime.monday => l.moneyHubWeekMonday,
    _ => l.moneyHubWeekSaturday,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final currencies = ref.watch(ledgerCurrenciesProvider).value;
    final weeks = ref.watch(budgetWeeksPerMonthProvider).value ?? BudgetSettings.defaultWeeksPerMonth;
    final weekStart = ref.watch(moneyWeekStartProvider);
    final reminders = ref.watch(goalsReminderSettingsProvider).value;
    final budgetCurrencies = ref.watch(budgetCurrenciesProvider).value ?? BudgetCurrencies.fallback;
    return SettingsSection(
      title: l.moneyHubSettingsSection,
      subtitle: l.moneyHubSettingsSectionHint,
      seed: seed,
      children: [
        SettingsTile(
          icon: Icons.currency_exchange_rounded,
          iconColor: t.gold,
          title: l.moneyHubSettingsCurrencies,
          subtitle: currencies == null ? null : MoneySettingsSummary.currencies(l, fmt, currencies),
          navigates: true,
          // push: back returns here (the currencies live under the ledger).
          onTap: () => context.push(AppRoutes.currencies),
        ),
        SettingsTile(
          icon: Icons.date_range_rounded,
          title: l.moneyHubSettingsWeeks,
          subtitle: l.moneyHubSettingsWeeksSummary(fmt.formatNumber(weeks, maxDecimals: 3, grouping: false)),
          navigates: true,
          onTap: () => unawaited(_editWeeks(context, ref, weeks, budgetCurrencies)),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.calendar_view_week_rounded,
          title: l.moneyHubSettingsWeekStart,
          subtitle: l.moneyHubSettingsWeekStartHint,
          selected: weekStart,
          options: [
            for (final day in MoneySettings.weekStarts) ChoiceOption(value: day, label: weekdayName(l, day)),
          ],
          onChanged: (day) => unawaited(setMoneyWeekStart(ref.read(repositoriesProvider), day)),
        ),
        SettingsTile(
          icon: Icons.notifications_active_rounded,
          title: l.moneyHubSettingsReminders,
          subtitle: reminders == null ? null : MoneySettingsSummary.reminders(l, fmt, reminders),
          navigates: true,
          onTap: () => unawaited(GoalsActions(context, ref).reminderSettings()),
        ),
      ],
    );
  }

  Future<void> _editWeeks(BuildContext context, WidgetRef ref, num current, BudgetCurrencies currencies) async {
    final value = await showBudgetWeeksSheet(
      context,
      current: current,
      format: BudgetFormat.of(context, currencies),
    );
    if (value == null || value == current || !context.mounted) return;
    final l = L10n.of(context);
    final undo = await ref.read(budgetRepositoryProvider).setWeeksPerMonth(value);
    if (context.mounted) unawaited(showUndoToast(context, UndoableAction(label: l.budgetWeeksSaved, undo: undo)));
  }
}

/// The Money entries' one-line summaries (pure).
abstract final class MoneySettingsSummary {
  /// "JOD · 5 currencies" – the base currency and how many are set up.
  static String currencies(L10n l, MadarFormatter fmt, List<LedgerCurrency> currencies) {
    final base = currencies.where((c) => c.isBase).firstOrNull?.code ?? currencies.firstOrNull?.code ?? '—';
    final n = currencies.length;
    return l.orbitUiListSeparator(BidiIsolate.isolate(base), l.moneyHubSettingsCurrencyCount(n, fmt.formatInt(n)));
  }

  /// "1 day before and on the day · at 9:00 AM", "On the due day · at …",
  /// or "Off".
  static String reminders(L10n l, MadarFormatter fmt, GoalsReminderSettings s) {
    final early = s.leadDays > 0;
    if (!s.enabled || (!early && !s.onDueDay)) return l.moneyHubSettingsRemindersOff;
    final lead = early ? fmt.localizeDigits(l.goalsRemindersLeadDays(s.leadDays, fmt.formatInt(s.leadDays))) : null;
    final when = lead == null
        ? l.moneyHubSettingsRemindersOnDay
        : (s.onDueDay ? l.moneyHubSettingsRemindersBoth(lead) : lead);
    return l.moneyHubSettingsRemindersAt(when, fmt.formatClock(s.hour, s.minute));
  }
}
