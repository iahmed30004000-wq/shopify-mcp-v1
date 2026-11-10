import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/dose_tracker.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/health/meds/domain/meds_settings.dart';

void main() {
  final day = DateTime(2026, 9, 29);
  DateTime at(int h, [int m = 0, int d = 0]) => DateTime(2026, 9, 29 + d, h, m);
  const settings = MedsSettings(); // late after 60 min, missed after 240
  final a = MedSpec(
    id: 'a',
    name: 'A',
    slots: const [MedSlot(ClockHm(8, 0)), MedSlot(ClockHm(20, 0))],
    createdAt: DateTime(2026, 9, 1),
  );
  final scheduler = DoseScheduler(meds: [a]);
  final plan = scheduler.planDay(day);
  final morning = plan.doses.first, evening = plan.doses.last;

  DoseLog log(String id, DoseStatus s, {DateTime? slot, DateTime? when}) =>
      DoseLog(id: id, medId: 'a', status: s, slot: slot, at: when);

  group('matching', () {
    test('by slot first, then a slot-less log close to the dose', () {
      final logs = [
        log('1', DoseStatus.taken, slot: at(20), when: at(20, 5)),
        log('2', DoseStatus.taken, when: at(9, 40)),
        log('3', DoseStatus.taken, when: at(15)), // too far from either dose
      ];
      final m = DoseTracker.match(plan.doses, logs);
      expect(m[evening.key]!.id, '1');
      expect(m[morning.key]!.id, '2');
    });

    test('a slot-less log goes to the closest dose only once', () {
      final m = DoseTracker.match(plan.doses, [log('x', DoseStatus.taken, when: at(19, 30))]);
      expect(m.keys, [evening.key]);
    });

    test('two entries for one slot: the answered one wins', () {
      final m = DoseTracker.match(plan.doses, [
        log('s', DoseStatus.snoozed, slot: at(8), when: at(8, 10)),
        log('t', DoseStatus.taken, slot: at(8), when: at(8, 20)),
      ]);
      expect(m[morning.key]!.id, 't');
    });
  });

  group('states', () {
    DoseState state(DateTime now, [DoseLog? l]) =>
        DoseTracker.stateOf(morning, l, now, settings, nextSameMed: evening);

    test('upcoming → due → late → missed', () {
      expect(state(at(7, 59)), DoseState.upcoming);
      expect(state(at(8)), DoseState.due);
      expect(state(at(8, 59)), DoseState.due);
      expect(state(at(9)), DoseState.late);
      expect(state(at(11, 59)), DoseState.late);
      expect(state(at(12)), DoseState.missed);
    });

    test('the next dose of the same medication ends the window early', () {
      const s = settings;
      final tight = MedSpec(id: 'q', name: 'Q', slots: const [MedSlot(ClockHm(8, 0)), MedSlot(ClockHm(10, 0))]);
      final doses = DoseScheduler(meds: [tight]).planDay(day).doses;
      final t = DoseTracker.track(doses.first, null, at(10, 1), s, nextSameMed: doses.last);
      expect(t.state, DoseState.missed);
      expect(t.missesAt, at(10));
    });

    test('answered doses', () {
      expect(state(at(9), log('1', DoseStatus.taken, slot: at(8), when: at(8, 5))), DoseState.taken);
      expect(state(at(9), log('1', DoseStatus.skipped, slot: at(8))), DoseState.skipped);
    });

    test('snoozed until a moment, then due again from that moment', () {
      final snooze = log('1', DoseStatus.snoozed, slot: at(8), when: at(8, 30));
      expect(state(at(8, 10), snooze), DoseState.snoozed);
      expect(state(at(8, 30), snooze), DoseState.due);
      expect(state(at(9, 29), snooze), DoseState.due);
      expect(state(at(9, 30), snooze), DoseState.late);
      final t = DoseTracker.track(morning, snooze, at(8, 10), settings);
      expect(t.dueAt, at(8, 30));
      expect(t.snoozedUntil, at(8, 30));
    });
  });

  group('adherence', () {
    test('counts per day, pending excluded from the rate, doses before the medication existed ignored', () {
      final plans = scheduler.planDays(DateTime(2026, 9, 27), 3);
      final logs = [
        log('1', DoseStatus.taken, slot: at(8, 0, -2), when: at(8, 5, -2)),
        log('2', DoseStatus.taken, slot: at(20, 0, -2), when: at(21, 30, -2)), // late
        log('3', DoseStatus.skipped, slot: at(8, 0, -1)),
        // 20:00 of the 28th: missed. Today: 08:00 taken, 20:00 still to come.
        log('4', DoseStatus.taken, slot: at(8), when: at(8, 1)),
      ];
      final s = DoseTracker.adherence(plans, logs, at(12), settings);
      expect(s.days.map((d) => (d.taken, d.skipped, d.missed, d.pending)), [
        (2, 0, 0, 0),
        (0, 1, 1, 0),
        (1, 0, 0, 1),
      ]);
      expect(s.days.first.late, 1);
      expect(s.rate, closeTo(3 / 5, 1e-9));
      expect(s.streak, 1);

      final newer = MedSpec(id: 'a', name: 'A', slots: a.slots, createdAt: at(12));
      final p2 = DoseScheduler(meds: [newer]).planDays(DateTime(2026, 9, 27), 3);
      final s2 = DoseTracker.adherence(p2, const [], at(21), settings);
      expect(s2.days.map((d) => d.total), [0, 0, 1]);
    });
  });

  group('stock', () {
    test('units per dose', () {
      expect(MedStock.unitsPerDose('caps', 2), 2);
      expect(MedStock.unitsPerDose('حبة', 2), 2);
      expect(MedStock.unitsPerDose('mg', 10), 1);
      expect(MedStock.unitsPerDose('tabs', 1.5), 1);
      expect(MedStock.unitsPerDose(null, 3), 1);
      expect(MedStock.unitsPerDose('tabs', null), 1);
    });

    test('refill threshold', () {
      expect(MedStock.needsRefill(5, 5), isTrue);
      expect(MedStock.needsRefill(6, 5), isFalse);
      expect(MedStock.needsRefill(null, 5), isFalse);
      expect(MedStock.crossedRefill(before: 6, after: 5, refillAt: 5), isTrue);
      expect(MedStock.crossedRefill(before: 5, after: 4, refillAt: 5), isFalse);
      expect(MedStock.daysLeft(10, 2), 5);
      expect(MedStock.daysLeft(null, 2), isNull);
    });
  });
}
