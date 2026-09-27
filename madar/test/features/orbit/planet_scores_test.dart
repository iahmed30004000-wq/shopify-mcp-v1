import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';

void main() {
  const engine = PlanetScoreEngine();
  final now = DateTime(2026, 9, 27, 16, 0);

  test('fresh install: every planet is dormant and the radar is empty', () {
    final scores = engine.compute(ScoreInputs(now: now));
    expect(scores.values.every((s) => s.dormant), isTrue);
    expect(engine.neglectRadar(scores), isEmpty);
  });

  test('overdue person produces a concrete reason with days overdue', () {
    final scores = engine.compute(ScoreInputs(now: now, people: [
      PersonIn(id: 'p1', name: 'Father', rhythmDays: 2, lastContact: now.subtract(const Duration(days: 5)), createdAt: DateTime(2026)),
      PersonIn(id: 'p2', name: 'Sister', rhythmDays: 7, lastContact: now.subtract(const Duration(days: 1)), createdAt: DateTime(2026)),
    ]));
    final family = scores['family']!;
    expect(family.dormant, isFalse);
    expect(family.reasons.single.code, ReasonCode.personOverdue);
    expect(family.reasons.single.args, {'name': 'Father', 'days': 3});
    expect(family.reasons.single.refId, 'p1');
    expect(family.score, closeTo(0.5 * 0 + 0.5 * 1, 0.01)); // father 0 (3/2 overdue → clamped), sister 1
  });

  test('past-due doses today are flagged; taken doses count', () {
    final today = DateTime(2026, 9, 27);
    final scores = engine.compute(ScoreInputs(now: now, doses3d: [
      DoseIn(medId: 'm1', medName: 'A', scheduledAt: today.add(const Duration(hours: 8)), taken: true),
      DoseIn(medId: 'm2', medName: 'B', scheduledAt: today.add(const Duration(hours: 9)), taken: false),
      DoseIn(medId: 'm3', medName: 'C', scheduledAt: today.add(const Duration(hours: 13)), taken: false),
      DoseIn(medId: 'm4', medName: 'D', scheduledAt: today.add(const Duration(hours: 15, minutes: 50)), taken: false), // within grace
    ]));
    final health = scores['health']!;
    expect(health.sources['doses'], closeTo(1 / 3, 1e-9));
    expect(health.reasons.first.code, ReasonCode.dosesPastDue);
    expect(health.reasons.first.args['count'], 2);
  });

  test('prayers: all logged in jamaah → thriving faith', () {
    final logs = [for (var i = 0; i < 35; i++) PrayerLogIn(day: now, status: 'prayed', inJamaah: true)];
    final scores = engine.compute(ScoreInputs(now: now, prayerLogs7d: logs, obligatoryPrayersExpected7d: 35));
    expect(scores['faith']!.score, closeTo(1.0, 1e-9));
    expect(scores['faith']!.state, PlanetState.thriving);
  });

  test('prayers: missed ones become a reason and lower the score', () {
    final logs = [for (var i = 0; i < 20; i++) PrayerLogIn(day: now, status: 'prayed')];
    final scores = engine.compute(ScoreInputs(now: now, prayerLogs7d: logs, obligatoryPrayersExpected7d: 35));
    expect(scores['faith']!.score, lessThan(0.75));
    expect(scores['faith']!.reasons.first.args['count'], 15);
  });

  test('budget overspend reason with percent; obligations overdue', () {
    final scores = engine.compute(ScoreInputs(now: now, budget: const [
      BudgetStatusIn(id: 'b1', name: 'Fuel', planMilli: 100000, spentMilli: 130000),
      BudgetStatusIn(id: 'b2', name: 'Food', planMilli: 200000, spentMilli: 150000),
    ], obligations: [
      ObligationIn(id: 'o1', name: 'Internet', nextDue: now.subtract(const Duration(days: 4))),
    ]));
    final money = scores['money']!;
    expect(money.sources['budget'], closeTo(200 / 300, 1e-9));
    expect(money.sources['obligations'], 0);
    final codes = money.reasons.map((r) => r.code).toSet();
    expect(codes, containsAll([ReasonCode.budgetOverspent, ReasonCode.obligationOverdue]));
    final over = money.reasons.firstWhere((r) => r.code == ReasonCode.budgetOverspent);
    expect(over.args['percent'], 30);
  });

  test('neglect radar returns the three weakest planets with their top reason', () {
    final scores = engine.compute(ScoreInputs(
      now: now,
      people: [PersonIn(id: 'p', name: 'Mother', rhythmDays: 3, lastContact: now.subtract(const Duration(days: 9)), createdAt: DateTime(2026))],
      obligations: [ObligationIn(id: 'o', name: 'Rent', nextDue: now.subtract(const Duration(days: 2)))],
      workoutsExpected7d: 4,
      workoutsDone7d: 1,
      documents: [DocumentIn(id: 'd', name: 'Passport', expiry: now.add(const Duration(days: 10)))],
      goals: [GoalIn(id: 'g', name: 'Course', target: 10, progress: 9, start: DateTime(2026, 9), deadline: DateTime(2026, 10, 30))],
    ));
    final radar = engine.neglectRadar(scores);
    expect(radar, hasLength(3));
    for (var i = 1; i < radar.length; i++) {
      expect(radar[i - 1].$1.score, lessThanOrEqualTo(radar[i].$1.score));
    }
    expect(radar.map((r) => r.$1.planetKey), isNot(contains('growth'))); // ahead of schedule
  });

  test('custom weights override defaults', () {
    final inputs = ScoreInputs(now: now, workoutsExpected7d: 4, workoutsDone7d: 4, waterTargetMl: 2000, waterTodayMl: 0);
    final a = engine.compute(inputs)['body']!.score;
    final b = engine.compute(inputs, weights: {'body': {'water': 0.0}})['body']!.score;
    expect(b, greaterThan(a));
    expect(b, closeTo(1.0, 1e-9));
  });
}
