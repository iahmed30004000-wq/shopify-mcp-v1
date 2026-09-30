import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/goals/domain/debt_ledger.dart';
import 'package:madar/features/money/goals/domain/due_dates.dart';
import 'package:madar/features/money/goals/domain/due_reminders.dart';
import 'package:madar/features/money/goals/domain/goals_rates.dart';
import 'package:madar/features/money/goals/domain/jar_plan.dart';
import 'package:madar/features/money/goals/domain/obligation_plan.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

/// Generic rates (not anyone's real configuration): base JOD, USD 0.709,
/// EGP 0.0145, LYD 0.13 with 3 decimals, and a currency without a rate.
final rates = GoalsRates(
  base: 'JOD',
  currencies: const [
    GoalsCurrency(code: 'JOD', decimals: 3, isBase: true),
    GoalsCurrency(code: 'USD', rateToBase: 0.709, decimals: 2),
    GoalsCurrency(code: 'EGP', rateToBase: 0.0145, decimals: 2),
    GoalsCurrency(code: 'LYD', rateToBase: 0.13, decimals: 3),
    GoalsCurrency(code: 'XYZ', rateToBase: 0, decimals: 2, symbol: '¤'),
  ],
);

void main() {
  final today = d(2026, 9, 29);

  group('GoalsRates', () {
    test('decimals, minor steps and exact conversion', () {
      expect(rates.decimalsOf('JOD'), 3);
      expect(rates.decimalsOf('usd'), 2);
      expect(rates.minorStepOf('JOD'), 1);
      expect(rates.minorStepOf('USD'), 10);
      expect(GoalsRates.single('JOD').decimalsOf('JPY'), 0);
      expect(GoalsRates.single('JOD').minorStepOf('JPY'), 1000);
      // 100 USD × 0.709 = 70.900 JOD.
      expect(rates.toBase(100000, 'USD'), 70900);
      // 1 000 EGP × 0.0145 = 14.500 JOD.
      expect(rates.toBase(1000000, 'EGP'), 14500);
      // 70.900 JOD → USD = 100.000 exactly.
      expect(rates.convert(70900, 'JOD', 'USD'), 100000);
      // USD → EGP through the base: 10 USD = 7.090 JOD = 488.965… EGP.
      expect(rates.convert(10000, 'USD', 'EGP'), 488966);
      expect(rates.convert(12345, 'LYD', 'LYD'), 12345);
      expect(rates.hasRate('XYZ'), isFalse);
      expect(rates.toBase(5000, 'XYZ'), 5000);
    });

    test('ceilToMinor never rounds a requirement down', () {
      expect(rates.ceilToMinor(Rational.fromInt(100000, 3), 'JOD'), 33334);
      expect(rates.ceilToMinor(Rational.fromInt(100000, 3), 'USD'), 33340);
      expect(rates.ceilToMinor(Rational.fromInt(90000, 3), 'USD'), 30000);
      expect(rates.ceilToMinor(Rational.zero, 'USD'), 0);
      expect(rates.ceilToMinor(Rational.fromInt(-5), 'USD'), 0);
    });
  });

  group('JarPlan', () {
    JarPlan plan({
      int target = 1000000,
      String currency = 'JOD',
      List<JarMovement> moves = const [],
      DateTime? start,
      DateTime? deadline,
      DateTime? on,
    }) => JarPlan.compute(
      targetMilli: target,
      currency: currency,
      movements: moves,
      today: on ?? today,
      rates: rates,
      start: start,
      deadline: deadline,
    );

    test('saved, remaining and progress follow the signed movements', () {
      final p = plan(moves: [JarMovement(400000, d(2026, 7, 1)), JarMovement(-50000, d(2026, 8, 1))]);
      expect(p.savedMilli, 350000);
      expect(p.remainingMilli, 650000);
      expect(p.progress, closeTo(0.35, 1e-12));
      expect(p.pace, JarPace.open);
      expect(p.requiredPerMonthMilli, isNull);
    });

    test('required per month spreads the rest over whole months, rounded up', () {
      // 3 whole months (Sep 29 → Dec 29 ≤ Dec 31): 900 / 3 = 300.
      final p = plan(target: 1000000, moves: [JarMovement(100000, d(2026, 9, 1))], deadline: d(2026, 12, 31));
      expect(p.monthsLeft, 3);
      expect(p.requiredPerMonthMilli, 300000);
      // 93 days = 13 whole weeks: 900 / 13 = 69.2307… → 69.231 (up).
      expect(p.daysLeft, 93);
      expect(p.requiredPerWeekMilli, 69231);
      // In USD the step is a cent: 1 000 / 3 = 333.333… → 333.34.
      final usd = plan(currency: 'USD', deadline: d(2026, 12, 31));
      expect(usd.requiredPerMonthMilli, 333340);
    });

    test('less than a month left needs everything now', () {
      final p = plan(target: 500000, deadline: d(2026, 10, 15));
      expect(p.monthsLeft, 1);
      expect(p.requiredPerMonthMilli, 500000);
      expect(p.requiredPerWeekMilli, 250000);
    });

    test('a passed deadline is overdue and asks for the remainder', () {
      final p = plan(target: 500000, moves: [JarMovement(200000, d(2026, 5, 1))], deadline: d(2026, 9, 1));
      expect(p.pace, JarPace.overdue);
      expect(p.daysLeft, -28);
      expect(p.requiredPerMonthMilli, 300000);
      expect(p.monthsLeft, 0);
    });

    test('reached jars need nothing and keep the surplus', () {
      final p = plan(target: 500000, moves: [JarMovement(520000, d(2026, 5, 1))], deadline: d(2026, 9, 1));
      expect(p.pace, JarPace.reached);
      expect(p.reached, isTrue);
      expect(p.requiredPerMonthMilli, isNull);
      expect(p.surplusMilli, 20000);
      expect(p.progress, 1);
      expect(p.rawProgress, closeTo(1.04, 1e-12));
    });

    test('pace compares with a straight line from the start', () {
      // Start Jan 1, deadline Dec 31 2026: on Sep 29 the line is at 271/364.
      final start = d(2026, 1, 1);
      final deadline = d(2026, 12, 31);
      final behind = plan(start: start, deadline: deadline, moves: [JarMovement(500000, d(2026, 2, 1))]);
      expect(behind.expectedProgress, closeTo(271 / 364, 1e-9));
      expect(behind.pace, JarPace.behind);
      final onTrack = plan(start: start, deadline: deadline, moves: [JarMovement(740000, d(2026, 2, 1))]);
      expect(onTrack.pace, JarPace.onTrack);
    });

    test('ETA projects the average rate since the first deposit', () {
      // 300 saved over 90 days → the 700 left take 210 more days.
      final p = plan(moves: [JarMovement(300000, d(2026, 7, 1))]);
      expect(p.eta, d(2027, 4, 27));
      expect(plan().eta, isNull);
    });

    test('a jar without target is full once something is saved', () {
      expect(plan(target: 0).progress, 0);
      expect(plan(target: 0, moves: [JarMovement(1000, today)]).progress, 1);
      expect(plan(target: 0, deadline: d(2026, 12, 1)).requiredPerMonthMilli, isNull);
    });

    test('series is the running balance per day', () {
      final s = JarPlan.series([
        JarMovement(100000, d(2026, 8, 1)),
        JarMovement(-20000, d(2026, 8, 15)),
        JarMovement(50000, d(2026, 8, 1)),
      ]);
      expect(s, [(d(2026, 8, 1), 150000), (d(2026, 8, 15), 130000)]);
    });
  });

  group('DebtState and DebtTotals', () {
    DebtState state({
      DebtDirection dir = DebtDirection.iOwe,
      int amount = 300000,
      String currency = 'JOD',
      List<DebtPaymentIn> pays = const [],
      DateTime? settledAt,
      DateTime? due,
    }) => DebtState.compute(
      direction: dir,
      currency: currency,
      amountMilli: amount,
      payments: pays,
      today: today,
      settledAt: settledAt,
      dueDate: due,
    );

    test('partial payments reduce what remains', () {
      final s = state(pays: [DebtPaymentIn(100000, d(2026, 9, 1)), DebtPaymentIn(50000, d(2026, 9, 15))]);
      expect(s.paidMilli, 150000);
      expect(s.remainingMilli, 150000);
      expect(s.paidRatio, closeTo(0.5, 1e-12));
      expect(s.settled, isFalse);
      expect(s.paysOff(149999), isFalse);
      expect(s.paysOff(150000), isTrue);
    });

    test('paid in full counts as settled on the last payment day', () {
      final s = state(pays: [DebtPaymentIn(100000, d(2026, 9, 1)), DebtPaymentIn(200000, d(2026, 9, 20))]);
      expect(s.settled, isTrue);
      expect(s.explicitlySettled, isFalse);
      expect(s.settledOn, d(2026, 9, 20));
      expect(s.remainingMilli, 0);
      expect(s.dueState, DueState.none);
    });

    test('a zero-amount debt (an import without a sum) is closed, as the Money planet counts it', () {
      final s = state(amount: 0, due: d(2026, 9, 1));
      expect(s.settled, isTrue);
      expect(s.remainingMilli, 0);
      expect(s.overdue, isFalse);
      expect(s.paidRatio, 1);
    });

    test('settling by hand writes off the rest', () {
      final s = state(pays: [DebtPaymentIn(100000, d(2026, 9, 1))], settledAt: DateTime(2026, 9, 25, 18, 30));
      expect(s.settled, isTrue);
      expect(s.settledOn, d(2026, 9, 25));
      expect(s.remainingMilli, 0);
      expect(s.writtenOffMilli, 200000);
    });

    test('due states', () {
      expect(state(due: d(2026, 9, 20)).overdue, isTrue);
      expect(state(due: d(2026, 9, 20)).daysToDue, -9);
      expect(state(due: d(2026, 10, 2)).dueState, DueState.soon);
      expect(state().dueState, DueState.none);
    });

    test('totals per direction in the base currency, exact', () {
      final totals = DebtTotals.of([
        state(amount: 300000, pays: [DebtPaymentIn(100000, today)]),
        state(amount: 100000, currency: 'USD', due: d(2026, 9, 1)),
        state(dir: DebtDirection.owedToMe, amount: 1000000, currency: 'EGP', due: d(2026, 10, 1)),
        state(dir: DebtDirection.owedToMe, amount: 50000, settledAt: today),
        state(dir: DebtDirection.owedToMe, amount: 20000, currency: 'XYZ'),
      ], rates);
      // 200 JOD + 100 USD × 0.709 = 270.900 JOD.
      expect(totals.iOweBaseMilli, 270900);
      // 1 000 EGP × 0.0145 + 20 XYZ at 1:1 = 34.500 JOD.
      expect(totals.owedToMeBaseMilli, 34500);
      expect(totals.netBaseMilli, 34500 - 270900);
      expect(totals.iOweCount, 2);
      expect(totals.owedToMeCount, 2);
      expect(totals.overdueCount, 1);
      expect(totals.dueSoonCount, 1);
      expect(totals.missingRates, {'XYZ'});
    });
  });

  group('ObligationTotals', () {
    test('monthly share: weekly × weeks-per-month, yearly ÷ 12, intervals', () {
      const weekly = RecurrenceRule(Recurrence.weekly);
      expect(ObligationTotals.monthlyShare(5000, weekly).roundHalfUp(), 20000);
      expect(ObligationTotals.monthlyShare(5000, weekly, weeksPerMonth: 4.345).roundHalfUp(), 21725);
      expect(ObligationTotals.monthlyShare(5000, const RecurrenceRule(Recurrence.weekly, 2)).roundHalfUp(), 10000);
      expect(ObligationTotals.monthlyShare(120000, const RecurrenceRule(Recurrence.yearly)).roundHalfUp(), 10000);
      expect(ObligationTotals.monthlyShare(90000, const RecurrenceRule(Recurrence.monthly, 3)).roundHalfUp(), 30000);
    });

    test('totals convert once and skip paused obligations', () {
      ObligationState s(Recurrence f, DateTime due, {bool active = true}) =>
          ObligationState.compute(frequency: f, interval: 1, nextDue: due, today: today, active: active);
      final totals = ObligationTotals.of([
        (150000, 'JOD', s(Recurrence.monthly, d(2026, 10, 1))),
        (12000, 'USD', s(Recurrence.monthly, d(2026, 9, 20))),
        (5000, 'JOD', s(Recurrence.weekly, d(2026, 9, 29))),
        (600000, 'JOD', s(Recurrence.yearly, d(2027, 1, 1))),
        (99000, 'JOD', s(Recurrence.monthly, d(2026, 9, 1), active: false)),
      ], rates);
      // 150 + 12 × 0.709 (8.508) + 20 + 50 = 228.508.
      expect(totals.monthlyBaseMilli, 228508);
      expect(totals.activeCount, 4);
      expect(totals.overdueCount, 1);
      expect(totals.dueSoonCount, 2);
    });
  });

  group('DueReminderPlanner', () {
    final now = DateTime(2026, 9, 29, 20, 15);
    final items = [
      DueItem(kind: DueReminderKind.obligation, refId: 'rent', due: d(2026, 10, 1)),
      DueItem(kind: DueReminderKind.debt, refId: 'loan', due: d(2026, 9, 30)),
      DueItem(kind: DueReminderKind.obligation, refId: 'old', due: d(2026, 9, 20)),
      DueItem(kind: DueReminderKind.obligation, refId: 'far', due: d(2027, 2, 28)),
    ];

    test('early and due-day reminders at the chosen time, past ones dropped', () {
      final plan = DueReminderPlanner.plan(items: items, settings: const GoalsReminderSettings(), now: now);
      expect(
        [for (final r in plan) (r.item.refId, r.at, r.daysBefore)],
        [
          // The day-before reminder for Sep 30 (Sep 29 09:00) has passed;
          // at the same moment obligations come first.
          ('rent', DateTime(2026, 9, 30, 9), 1),
          ('loan', DateTime(2026, 9, 30, 9), 0),
          ('rent', DateTime(2026, 10, 1, 9), 0),
        ],
      );
    });

    test('lead days, due-day switch, time and disabling', () {
      final plan = DueReminderPlanner.plan(
        items: items,
        settings: const GoalsReminderSettings(leadDays: 3, onDueDay: false, minuteOfDay: 21 * 60 + 30),
        now: now,
        horizonDays: 200,
      );
      expect([for (final r in plan) (r.item.refId, r.at)], [('far', DateTime(2027, 2, 25, 21, 30))]);
      expect(
        DueReminderPlanner.plan(items: items, settings: const GoalsReminderSettings(enabled: false), now: now),
        isEmpty,
      );
    });

    test('settings survive JSON and tolerate junk', () {
      const s = GoalsReminderSettings(enabled: false, leadDays: 3, minuteOfDay: 450, onDueDay: false);
      expect(GoalsReminderSettings.fromJson(s.toJson()), s);
      expect(GoalsReminderSettings.fromJson('junk'), const GoalsReminderSettings());
      expect(GoalsReminderSettings.fromJson({'leadDays': 99, 'minuteOfDay': -4}).leadDays, 30);
      expect(GoalsReminderSettings.fromJson({'minuteOfDay': -4}).minuteOfDay, 0);
    });
  });
}
