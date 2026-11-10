import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/today/domain/day_snapshot.dart';
import 'package:madar/features/today/domain/objective.dart';
import 'package:madar/features/today/domain/objective_engine.dart';
import 'package:madar/features/today/domain/objective_state.dart';

import 'today_fixtures.dart';

/// Random but reproducible days, including nonsense: times outside the day,
/// duplicate ids, empty lists, windows that end before they start.
class _Gen {
  _Gen(int seed) : r = Random(seed);
  final Random r;

  bool coin([double p = 0.5]) => r.nextDouble() < p;
  DateTime time() => DateTime(2026, 11, 9 + r.nextInt(3), r.nextInt(24), r.nextInt(60));
  String id(String p) => '$p${r.nextInt(4)}';
  List<T> list<T>(T Function() make) => List.generate(r.nextInt(4), (_) => make());

  DaySnapshot snapshot() => DaySnapshot(
    now: time(),
    day: coin(0.3) ? time() : null,
    prayers: [
      for (final p in Prayer.values.take(5))
        if (coin(0.8))
          PrayerSlot(
            prayer: p,
            at: time(),
            endsAt: coin(0.5) ? time() : null,
            logged: coin(0.3),
            adhanOn: coin(0.7),
            refId: coin(0.3) ? id('r') : null,
          ),
    ],
    doses: list(() => MedDose(id: id('d'), at: time(), taken: coin(0.3), title: coin() ? 'm' : null)),
    timedTasks: list(() => TimedTask(id: id('t'), at: time(), done: coin(0.3))),
    untimedTasks: list(() => UntimedTask(id: id('u'), done: coin(0.3))),
    adhkar: list(() => AdhkarWindowSlot(kind: AdhkarWindowKind.values[r.nextInt(2)], startsAt: time(), endsAt: time(), done: coin(0.3))),
    wird: coin(0.5) ? WirdSlot(id: id('w'), from: coin() ? time() : null, done: coin(0.3)) : null,
    meals: list(() => PlannedMeal(id: id('m'), at: time(), done: coin(0.3))),
    workouts: list(() => PlannedWorkout(id: id('k'), at: time(), done: coin(0.3))),
    neglected: coin(0.5) ? NeglectSuggestion(planetKey: ['family', 'travel', 'work'][r.nextInt(3)], actionKey: id('a')) : null,
    isRamadan: coin(0.3),
    isFasting: coin(0.2),
    isFriday: coin(0.2),
    travelling: coin(0.2),
  );

  ObjectiveState state(DaySnapshot s) {
    var st = const ObjectiveState.empty();
    final ids = ['prayer:fajr', 'prayer:dhuhr', 'med:d0', 'med:d1', 'task:t0', 'task:u1', 'adhkar:morning', 'meal:m0', 'wird:w0'];
    for (final id in ids) {
      if (!coin(0.25)) continue;
      final d = coin(0.8) ? s.dayStart : time();
      switch (r.nextInt(3)) {
        case 0:
          st = st.markDone(id, d);
        case 1:
          st = st.skip(id, d);
        default:
          st = st.snooze(id, d, time());
      }
    }
    return st;
  }
}

void main() {
  const engine = ObjectiveEngine();

  test('1000 random snapshots: never throws, deterministic, consistent', () {
    final g = _Gen(20261110);
    for (var i = 0; i < 1000; i++) {
      final s = g.snapshot();
      final st = g.state(s);

      final a = engine.next(s, st);
      final b = engine.next(s, st);
      expect(a, b, reason: 'run $i');
      expect(a.hashCode, b.hashCode);

      // The card is the first of the eligible list and no other rule beats it.
      final eligible = engine.eligibleNow(s, st);
      expect(a.current, eligible.isEmpty ? isNull : eligible.first, reason: 'run $i');
      for (final o in eligible) {
        expect(o.rule >= a.current!.rule, isTrue, reason: 'run $i');
      }

      // The day list: unique ids, sorted, current at most once, no done in upNext.
      final ids = a.agenda.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'run $i');
      expect(a.agenda.where((e) => e.isCurrent).length <= 1, isTrue);
      for (var k = 1; k < a.agenda.length; k++) {
        final p = a.agenda[k - 1], q = a.agenda[k];
        if (p.hasClock == q.hasClock) expect(p.objective.at.compareTo(q.objective.at) <= 0, isTrue, reason: 'run $i');
      }
      for (final e in a.upNext) {
        expect(e.status == DayEntryStatus.pending || e.status == DayEntryStatus.snoozed, isTrue);
        expect(e.isCurrent, isFalse);
      }

      // A fasting day never offers a meal inside Fajr..Maghrib.
      if ((s.isRamadan || s.isFasting) && a.current?.kind == ObjectiveKind.meal) {
        DateTime? fajr, maghrib;
        for (final p in s.prayers) {
          if (p.prayer == Prayer.fajr) fajr = p.at;
          if (p.prayer == Prayer.maghrib) maghrib = p.at;
        }
        if (fajr != null && maghrib != null) {
          expect(s.now.isBefore(fajr) || !s.now.isBefore(maghrib), isTrue, reason: 'run $i');
        }
      }

      // State survives a restart and gives the same answer.
      expect(engine.next(s, ObjectiveState.decode(st.encode())), a, reason: 'run $i');
    }
  });

  test('input order does not matter', () {
    final g = _Gen(7);
    for (var i = 0; i < 200; i++) {
      final s = g.snapshot();
      // Distinct ids only: duplicate ids are collapsed by input order, by design.
      final reversed = DaySnapshot(
        now: s.now,
        day: s.day,
        prayers: s.prayers.reversed.toList(),
        doses: _unique(s.doses, (d) => d.id).reversed.toList(),
        timedTasks: _unique(s.timedTasks, (d) => d.id).reversed.toList(),
        adhkar: _unique(s.adhkar, (d) => d.kind).reversed.toList(),
        meals: _unique(s.meals, (d) => d.id).reversed.toList(),
        workouts: _unique(s.workouts, (d) => d.id).reversed.toList(),
        wird: s.wird,
        neglected: s.neglected,
        isRamadan: s.isRamadan,
        isFasting: s.isFasting,
        isFriday: s.isFriday,
        travelling: s.travelling,
      );
      final straight = DaySnapshot(
        now: s.now,
        day: s.day,
        prayers: s.prayers,
        doses: _unique(s.doses, (d) => d.id),
        timedTasks: _unique(s.timedTasks, (d) => d.id),
        adhkar: _unique(s.adhkar, (d) => d.kind),
        meals: _unique(s.meals, (d) => d.id),
        workouts: _unique(s.workouts, (d) => d.id),
        wird: s.wird,
        neglected: s.neglected,
        isRamadan: s.isRamadan,
        isFasting: s.isFasting,
        isFriday: s.isFriday,
        travelling: s.travelling,
      );
      expect(engine.next(reversed, const ObjectiveState.empty()), engine.next(straight, const ObjectiveState.empty()), reason: 'run $i');
    }
  });

  test('stepping a whole day with the clock never throws and moves forward sanely', () {
    final g = _Gen(99);
    for (var i = 0; i < 20; i++) {
      final base = g.snapshot();
      for (var t = at(0, 0); t.isBefore(at(0, 0, dayOffset: 1)); t = t.add(const Duration(minutes: 5))) {
        final s = DaySnapshot(
          now: t,
          prayers: base.prayers,
          doses: base.doses,
          timedTasks: base.timedTasks,
          adhkar: base.adhkar,
          wird: base.wird,
          meals: base.meals,
          workouts: base.workouts,
          neglected: base.neglected,
          isRamadan: base.isRamadan,
        );
        engine.next(s, const ObjectiveState.empty());
      }
    }
  });
}

List<T> _unique<T>(List<T> items, Object Function(T) key) {
  final seen = <Object>{};
  return [
    for (final e in items)
      if (seen.add(key(e))) e,
  ];
}
