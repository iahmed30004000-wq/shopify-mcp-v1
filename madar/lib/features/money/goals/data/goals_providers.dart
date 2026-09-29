import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../orbit/data/orbit_providers.dart';
import '../domain/debt_ledger.dart';
import '../domain/due_dates.dart';
import '../domain/due_reminders.dart';
import '../domain/goals_snapshot.dart';
import '../goals_texts.dart';
import 'goals_notifications.dart';
import 'goals_service.dart';

// ------------------------------------------------------------- basics ----

/// The goals wall clock (follows the orbit's, so tests freeze both).
final goalsClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final goalsTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Money-planet activity goes through the orbit's pulse hub (the crystal
/// world flares). Tests may override it with null (plain activity rows).
final goalsActivityRecorderProvider = Provider<GoalsActivityRecorder?>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (kind, table, id, {value, payload = const {}}) =>
      hub.recordCompletion(GoalsService.planetKey, kind, table, id, value: value, payload: payload);
});

final goalsServiceProvider = Provider<GoalsService>(
  (ref) => GoalsService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(goalsClockProvider),
    recorder: ref.watch(goalsActivityRecorderProvider),
  ),
);

// -------------------------------------------------------------- streams ----

final goalsJarRowsProvider = StreamProvider<List<JarRow>>((ref) => ref.watch(goalsServiceProvider).watchJars());

final goalsJarDepositRowsProvider = StreamProvider<List<JarDepositRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchJarDeposits(),
);

final goalsDebtRowsProvider = StreamProvider<List<DebtRow>>((ref) => ref.watch(goalsServiceProvider).watchDebts());

final goalsDebtPaymentRowsProvider = StreamProvider<List<DebtPaymentRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchDebtPayments(),
);

final goalsObligationRowsProvider = StreamProvider<List<ObligationRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchObligations(),
);

final goalsObligationPaymentRowsProvider = StreamProvider<List<ObligationPaymentRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchObligationPayments(),
);

/// Active (not archived) wallets, in the user's order.
final goalsWalletsProvider = StreamProvider<List<WalletRow>>((ref) => ref.watch(goalsServiceProvider).watchWallets());

final goalsBudgetItemsProvider = StreamProvider<List<BudgetItemRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchBudgetItems(),
);

final goalsCurrenciesProvider = StreamProvider<List<CurrencyRow>>(
  (ref) => ref.watch(goalsServiceProvider).watchCurrencies(),
);

final goalsReminderSettingsProvider = StreamProvider<GoalsReminderSettings>(
  (ref) => ref.watch(goalsServiceProvider).watchReminderSettings(),
);

/// `key_values['money.budget.weeksPerMonth']` (default 4) – shared with the
/// budget for the monthly cost of weekly obligations.
final goalsWeeksPerMonthProvider = StreamProvider<num>((ref) => ref.watch(goalsServiceProvider).watchWeeksPerMonth());

// ------------------------------------------------------------- snapshot ----

/// Everything the goals screens show, or null while the first rows load.
final goalsSnapshotProvider = Provider<GoalsSnapshot?>((ref) {
  final jars = ref.watch(goalsJarRowsProvider).value;
  final deposits = ref.watch(goalsJarDepositRowsProvider).value;
  final debts = ref.watch(goalsDebtRowsProvider).value;
  final debtPayments = ref.watch(goalsDebtPaymentRowsProvider).value;
  final obligations = ref.watch(goalsObligationRowsProvider).value;
  final obligationPayments = ref.watch(goalsObligationPaymentRowsProvider).value;
  final currencies = ref.watch(goalsCurrenciesProvider).value;
  final wallets = ref.watch(goalsWalletsProvider).value;
  final budgetItems = ref.watch(goalsBudgetItemsProvider).value;
  final weeksPerMonth = ref.watch(goalsWeeksPerMonthProvider).value;
  final today = ref.watch(goalsTodayProvider);
  if (jars == null ||
      deposits == null ||
      debts == null ||
      debtPayments == null ||
      obligations == null ||
      obligationPayments == null ||
      currencies == null ||
      wallets == null ||
      budgetItems == null) {
    return null;
  }
  return GoalsSnapshot.build(
    today: today,
    jars: jars,
    deposits: deposits,
    debts: debts,
    debtPayments: debtPayments,
    obligations: obligations,
    obligationPayments: obligationPayments,
    currencies: currencies,
    wallets: wallets,
    budgetItems: budgetItems,
    weeksPerMonth: weeksPerMonth ?? 4,
  );
});

/// One jar's view (null while loading or once deleted).
final goalsJarProvider = Provider.family<JarView?, String>((ref, id) => ref.watch(goalsSnapshotProvider)?.jar(id));

/// One debt's view.
final goalsDebtProvider = Provider.family<DebtView?, String>((ref, id) => ref.watch(goalsSnapshotProvider)?.debt(id));

/// One obligation's view.
final goalsObligationProvider = Provider.family<ObligationView?, String>(
  (ref, id) => ref.watch(goalsSnapshotProvider)?.obligation(id),
);

/// Debt totals per direction (base currency).
final goalsDebtTotalsProvider = Provider<DebtTotals?>((ref) => ref.watch(goalsSnapshotProvider)?.debtTotals);

/// Overdue and upcoming (14 days) obligations and debts, soonest first.
final goalsUpcomingDuesProvider = Provider<List<DueEntry>>(
  (ref) => ref.watch(goalsSnapshotProvider)?.dues() ?? const [],
);

// ----------------------------------------------------------- reminders ----

(L10n, MadarFormatter) goalsTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

final goalsNotificationSchedulerProvider = Provider<GoalsReminderScheduler>(
  (ref) => NotificationGoalsReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = goalsTextsOf(ref);
      return (group: l.goalsNotifyGroup, name: l.goalsNotifyChannel, description: l.goalsNotifyChannelDescription);
    },
  ),
);

/// Delivers due reminders; tests override it with
/// [RecordingGoalsReminderScheduler].
final goalsReminderSchedulerProvider = Provider<GoalsReminderScheduler>(
  (ref) => ref.watch(goalsNotificationSchedulerProvider),
);

/// Builds the notices for [reminders] (pure apart from the texts).
List<GoalsNotice> goalsNoticesFor(List<DueReminder> reminders, GoalsSnapshot snapshot, GoalsTexts texts) {
  final l = texts.l;
  final out = <GoalsNotice>[];
  for (var i = 0; i < reminders.length && i < GoalsReminderIds.size; i++) {
    final r = reminders[i];
    final when = r.daysBefore == 0 ? l.goalsDueToday : texts.dueRelative(r.item.due, CalendarDays.of(r.at));
    String title, body;
    switch (r.item.kind) {
      case DueReminderKind.obligation:
        final o = snapshot.obligation(r.item.refId);
        if (o == null) continue;
        title = l.goalsNotifyObligationTitle(texts.user(o.obligation.name));
        body = l.goalsNotifyObligationBody(texts.money(o.obligation.amountMilli, o.obligation.currency), when);
      case DueReminderKind.debt:
        final d = snapshot.debt(r.item.refId);
        if (d == null) continue;
        final amount = texts.money(d.state.remainingMilli, d.debt.currency);
        final person = texts.user(d.debt.person);
        if (d.debt.direction == DebtDirection.iOwe) {
          title = l.goalsNotifyDebtIOweTitle(person);
          body = l.goalsNotifyDebtIOweBody(amount, when);
        } else {
          title = l.goalsNotifyDebtOwedTitle(person);
          body = l.goalsNotifyDebtOwedBody(amount, when);
        }
    }
    out.add(
      GoalsNotice(
        id: GoalsReminderIds.of(out.length),
        at: r.at,
        title: title,
        body: texts.fmt.localizeDigits(body),
        kind: r.item.kind,
        refId: r.item.refId,
      ),
    );
  }
  return out;
}

/// Keeps debt and obligation due reminders planned (next two months)
/// whenever the dues, the reminder settings, the language or the day
/// change. Watch it once from the app root (the goals screen also watches
/// it); its state is the last plan.
final goalsReminderSyncProvider = NotifierProvider<GoalsReminderSync, List<GoalsNotice>?>(GoalsReminderSync.new);

class GoalsReminderSync extends Notifier<List<GoalsNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<GoalsNotice>? build() {
    ref.listen(goalsSnapshotProvider.select(_signature), (_, _) => _schedule());
    ref.listen(goalsReminderSettingsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(goalsTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  /// What the reminders depend on: every due item with its text inputs.
  static String? _signature(GoalsSnapshot? s) {
    if (s == null) return null;
    final b = StringBuffer();
    for (final o in s.obligations) {
      b.write('o${o.id}|${o.state.nextDue}|${o.obligation.name}|${o.obligation.amountMilli}${o.obligation.currency};');
    }
    for (final d in s.openDebts) {
      b.write(
        'd${d.id}|${d.state.dueDate}|${d.debt.person}|${d.state.remainingMilli}${d.debt.currency}|${d.debt.direction.name};',
      );
    }
    for (final c in s.rates.currencies) {
      b.write('c${c.code}${c.decimals}${c.symbol};');
    }
    return b.toString();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _run);
  }

  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    final snapshot = ref.read(goalsSnapshotProvider);
    final settings = ref.read(goalsReminderSettingsProvider).value;
    if (snapshot == null || settings == null) return;
    _running = true;
    try {
      await initializeDateFormatting();
      final (l, fmt) = goalsTextsOf(ref);
      final reminders = DueReminderPlanner.plan(
        items: snapshot.dueItems,
        settings: settings,
        now: ref.read(goalsClockProvider)(),
        max: GoalsReminderIds.size,
      );
      final notices = goalsNoticesFor(reminders, snapshot, GoalsTexts(l, fmt, snapshot.rates));
      await ref.read(goalsReminderSchedulerProvider).replaceAll(notices);
      state = notices;
    } catch (e) {
      debugPrint('money goals reminders: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Plans now (skips the debounce).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}
