import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/today/domain/day_snapshot.dart';
import 'package:madar/features/today/domain/objective.dart';
import 'package:madar/features/today/domain/objective_engine.dart';
import 'package:madar/features/today/domain/objective_state.dart';

import 'today_fixtures.dart';

void main() {
  const engine = ObjectiveEngine();

  group('rule 1: prayers (whole day, 5-minute steps from 04:00)', () {
    test('adhan on: wins from 15 minutes before, earliest unlogged first, ends with its window', () {
      final t = timeline((now) => DaySnapshot(now: now, prayers: prayers()));
      expect(t, [
        '04:00=-',
        '04:30=prayer:fajr',
        '06:10=-',
        '12:10=prayer:dhuhr',
        // Asr's look-ahead opens at 15:35 but the unlogged Dhuhr is earlier.
        '15:50=prayer:asr',
        '18:30=prayer:maghrib',
        '19:50=prayer:isha',
      ]);
    });

    test('adhan off: only "the time has begun" triggers it', () {
      final t = timeline(
        (now) => DaySnapshot(now: now, prayers: prayers(adhanOff: {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha})),
      );
      expect(t, ['04:00=-', '04:45=prayer:fajr', '06:10=-', '12:25=prayer:dhuhr', '15:50=prayer:asr', '18:30=prayer:maghrib', '19:50=prayer:isha']);
    });

    test('adhan off for one prayer only changes that prayer', () {
      final t = timeline((now) => DaySnapshot(now: now, prayers: prayers(adhanOff: {Prayer.fajr}, logged: {Prayer.dhuhr})));
      expect(t.take(3), ['04:00=-', '04:45=prayer:fajr', '06:10=-']);
      // Dhuhr logged, so Asr's look-ahead is free to open at 15:35.
      expect(t, contains('15:35=prayer:asr'));
    });

    test('a prayer logged by hand elsewhere disappears at once', () {
      DaySnapshot snap(DateTime now, {bool logged = false}) =>
          DaySnapshot(now: now, prayers: prayers(logged: {if (logged) Prayer.fajr}));
      expect(engine.next(snap(at(5, 0)), const ObjectiveState.empty()).current?.id, 'prayer:fajr');
      expect(engine.next(snap(at(5, 0), logged: true), const ObjectiveState.empty()).current, isNull);
      // ... and an upcoming one disappears before it ever shows.
      expect(engine.next(snap(at(4, 40), logged: true), const ObjectiveState.empty()).current, isNull);
    });

    test('reason and urgency: adhan soon vs time begun', () {
      final soon = engine.next(DaySnapshot(now: at(12, 15), prayers: prayers()), const ObjectiveState.empty()).current!;
      expect(soon.reason, ObjectiveReason.prayerAdhanSoon);
      expect(soon.urgency, ObjectiveUrgency.soon);
      expect(soon.prayer, Prayer.dhuhr);
      expect(soon.at, at(12, 25));
      final begun = engine.next(DaySnapshot(now: at(12, 30), prayers: prayers()), const ObjectiveState.empty()).current!;
      expect(begun.reason, ObjectiveReason.prayerBegun);
      expect(begun.urgency, ObjectiveUrgency.now);
      expect(begun.rule, 1);
    });

    test('Friday only changes the Dhuhr reason', () {
      final dhuhr = engine.next(DaySnapshot(now: at(12, 30), prayers: prayers(), isFriday: true), const ObjectiveState.empty()).current!;
      expect(dhuhr.reason, ObjectiveReason.fridayPrayerBegun);
      final soon = engine.next(DaySnapshot(now: at(12, 15), prayers: prayers(), isFriday: true), const ObjectiveState.empty()).current!;
      expect(soon.reason, ObjectiveReason.fridayPrayerSoon);
      final asr = engine.next(DaySnapshot(now: at(16, 0), prayers: prayers(), isFriday: true), const ObjectiveState.empty()).current!;
      expect(asr.reason, ObjectiveReason.prayerBegun);
    });

    test('a window without endsAt ends at the next prayer, the last at the end of the day', () {
      final slots = [
        PrayerSlot(prayer: Prayer.dhuhr, at: at(12, 25)),
        PrayerSlot(prayer: Prayer.asr, at: at(15, 50), logged: true),
        PrayerSlot(prayer: Prayer.isha, at: at(19, 50)),
      ];
      final t = timeline((now) => DaySnapshot(now: now, prayers: slots));
      expect(t, ['04:00=-', '12:10=prayer:dhuhr', '15:50=-', '19:35=prayer:isha']);
    });
  });

  group('rule 2: medicine, 30 minutes either side', () {
    final doses = [MedDose(id: 'a', at: at(8, 0), title: 'X'), MedDose(id: 'b', at: at(13, 10))];
    test('wins in its window (inclusive) and loses outside it', () {
      final t = timeline((now) => DaySnapshot(now: now, doses: doses));
      expect(t, ['04:00=-', '07:30=med:a', '08:35=-', '12:40=med:b', '13:45=-']);
    });

    test('taken disappears; reasons run soon -> due now -> late', () {
      final d = [MedDose(id: 'a', at: at(8, 0), title: 'X')];
      ObjectiveReason? at_(DateTime n) => engine.next(DaySnapshot(now: n, doses: d), const ObjectiveState.empty()).current?.reason;
      expect(at_(at(7, 45)), ObjectiveReason.medicineSoon);
      expect(at_(at(8, 5)), ObjectiveReason.medicineDueNow);
      expect(at_(at(8, 25)), ObjectiveReason.medicineLate);
      final taken = [MedDose(id: 'a', at: at(8, 0), taken: true)];
      expect(engine.next(DaySnapshot(now: at(8, 5), doses: taken), const ObjectiveState.empty()).current, isNull);
      final o = engine.next(DaySnapshot(now: at(8, 5), doses: d), const ObjectiveState.empty()).current!;
      expect(o.title, 'X');
      expect(o.sourceTable, ObjectiveSources.medDoses);
      expect(o.sourceId, 'a');
    });

    test('beats every lower rule, loses to a prayer', () {
      final snap = DaySnapshot(
        now: at(12, 20),
        prayers: prayers(),
        doses: [MedDose(id: 'a', at: at(12, 20))],
        timedTasks: [TimedTask(id: 't', at: at(12, 20))],
      );
      expect(engine.eligibleNow(snap, const ObjectiveState.empty()).map((o) => o.id), ['prayer:dhuhr', 'med:a', 'task:t']);
    });
  });

  group('rule 3: timed task within the hour', () {
    final tasks = [TimedTask(id: 't', at: at(10, 0), title: 'Call')];
    test('wins from one hour before, loses an hour after', () {
      expect(timeline((now) => DaySnapshot(now: now, timedTasks: tasks)), ['04:00=-', '09:00=task:t', '11:05=-']);
    });

    test('done disappears; untimed tasks never take the card but are in the day list', () {
      final done = [TimedTask(id: 't', at: at(10, 0), done: true)];
      expect(timeline((now) => DaySnapshot(now: now, timedTasks: done)), ['04:00=-']);
      final r = engine.next(
        DaySnapshot(now: at(10, 0), untimedTasks: const [UntimedTask(id: 'u1'), UntimedTask(id: 'u2', done: true)]),
        const ObjectiveState.empty(),
      );
      expect(r.current, isNull);
      expect(r.agenda.map((e) => (e.id, e.status)), [('task:u1', DayEntryStatus.pending), ('task:u2', DayEntryStatus.done)]);
      expect(r.agenda.every((e) => !e.hasClock), isTrue);
    });
  });

  group('rule 4: adhkar windows and the wird', () {
    test('morning from Fajr until Dhuhr, evening from Asr until Isha', () {
      final t = timeline((now) => DaySnapshot(now: now, adhkar: standardAdhkar()));
      expect(t, ['04:00=-', '04:45=adhkar:morning', '12:25=-', '15:50=adhkar:evening', '19:50=-']);
    });

    test('done sets disappear', () {
      expect(
        timeline((now) => DaySnapshot(now: now, adhkar: standardAdhkar(morningDone: true))),
        ['04:00=-', '15:50=adhkar:evening', '19:50=-'],
      );
    });

    test('the wird is owed all day from its time; an open window comes first when earlier', () {
      WirdSlot w({bool done = false}) => WirdSlot(id: 'p', from: at(9, 0), done: done);
      expect(
        timeline((now) => DaySnapshot(now: now, adhkar: standardAdhkar(), wird: w())),
        ['04:00=-', '04:45=adhkar:morning', '12:25=wird:p'],
      );
      expect(
        timeline((now) => DaySnapshot(now: now, adhkar: standardAdhkar(morningDone: true), wird: w())),
        ['04:00=-', '09:00=wird:p'],
      );
      expect(
        timeline((now) => DaySnapshot(now: now, adhkar: standardAdhkar(), wird: w(done: true))),
        ['04:00=-', '04:45=adhkar:morning', '12:25=-', '15:50=adhkar:evening', '19:50=-'],
      );
    });

    test('a wird without a time starts at Fajr, and ties with the morning adhkar by id', () {
      final snap = DaySnapshot(now: at(5, 0), prayers: prayers(logged: {Prayer.fajr}), adhkar: standardAdhkar(), wird: const WirdSlot(id: 'p'));
      expect(engine.eligibleNow(snap, const ObjectiveState.empty()).map((o) => o.id), ['adhkar:morning', 'wird:p']);
      // Before Fajr nothing is owed yet.
      expect(engine.next(DaySnapshot(now: at(4, 0), prayers: prayers(), wird: const WirdSlot(id: 'p')), const ObjectiveState.empty()).current, isNull);
    });

    test('a prayer outranks the adhkar window that opens with it', () {
      final snap = DaySnapshot(now: at(5, 0), prayers: prayers(), adhkar: standardAdhkar());
      expect(engine.next(snap, const ObjectiveState.empty()).current?.id, 'prayer:fajr');
      final logged = DaySnapshot(now: at(5, 0), prayers: prayers(logged: {Prayer.fajr}), adhkar: standardAdhkar());
      expect(engine.next(logged, const ObjectiveState.empty()).current?.id, 'adhkar:morning');
    });
  });

  group('rule 5: planned meal / workout', () {
    final meals = [PlannedMeal(id: 'm', at: at(13, 0))];
    final workouts = [PlannedWorkout(id: 'w', at: at(17, 0))];

    test('wins 30 minutes before to an hour after, loses outside', () {
      final t = timeline((now) => DaySnapshot(now: now, meals: meals, workouts: workouts));
      expect(t, ['04:00=-', '12:30=meal:m', '14:05=-', '16:30=workout:w', '18:05=-']);
    });

    test('done disappears', () {
      final t = timeline((now) => DaySnapshot(now: now, meals: [PlannedMeal(id: 'm', at: at(13, 0), done: true)]));
      expect(t, ['04:00=-']);
    });

    test('Ramadan: no meal objective between Fajr and Maghrib, none leaking into it', () {
      final m = [
        PlannedMeal(id: 'lunch', at: at(13, 0)),
        PlannedMeal(id: 'iftar', at: at(18, 40)),
        PlannedMeal(id: 'suhoor', at: at(4, 30)),
      ];
      final t = timeline((now) => DaySnapshot(now: now, prayers: prayers(logged: {...Prayer.values}), meals: m, isRamadan: true));
      // Suhoor window is cut at Fajr; lunch never shows; the iftar-time meal
      // waits for Maghrib instead of starting at 18:10.
      expect(t, ['04:00=meal:suhoor', '04:45=-', '18:30=meal:iftar', '19:45=-']);
      final noFlag = timeline((now) => DaySnapshot(now: now, prayers: prayers(logged: {...Prayer.values}), meals: m));
      expect(noFlag, contains('12:30=meal:lunch'));
    });

    test('a voluntary fasting day behaves like Ramadan; the lunch is also out of the day list', () {
      final snap = DaySnapshot(now: at(13, 0), prayers: prayers(), meals: meals, isFasting: true);
      final r = engine.next(snap, const ObjectiveState.empty());
      expect(r.agenda.any((e) => e.id == 'meal:m'), isFalse);
    });

    test('Ramadan keeps workouts (after iftar) and medicine', () {
      final t = timeline(
        (now) => DaySnapshot(
          now: now,
          prayers: prayers(logged: {...Prayer.values}),
          workouts: [PlannedWorkout(id: 'w', at: at(21, 0))],
          doses: [MedDose(id: 'd', at: at(13, 0))],
          isRamadan: true,
        ),
      );
      expect(t, ['04:00=-', '12:30=med:d', '13:35=-', '20:30=workout:w', '22:05=-']);
    });

    test('without Fajr/Maghrib the fasting span is unknown and nothing is suppressed', () {
      final r = engine.next(DaySnapshot(now: at(13, 0), meals: meals, isRamadan: true), const ObjectiveState.empty());
      expect(r.current?.id, 'meal:m');
    });
  });

  group('rule 6: the neglected planet', () {
    const n = NeglectSuggestion(planetKey: 'family', actionKey: 'personOverdue', refTable: 'people', refId: 'p1');
    test('shows from Fajr to midnight when nothing else is on', () {
      expect(timeline((now) => DaySnapshot(now: now, prayers: prayers(logged: {...Prayer.values}), neglected: n)), ['04:00=-', '04:45=planet:family:personOverdue']);
    });

    test('carries the record and loses to every other rule', () {
      final o = engine.next(DaySnapshot(now: at(10, 0), neglected: n), const ObjectiveState.empty()).current!;
      expect((o.planetKey, o.actionKey, o.sourceTable, o.sourceId), ('family', 'personOverdue', 'people', 'p1'));
      expect(o.kind, ObjectiveKind.planet);
      expect(o.urgency, ObjectiveUrgency.later);
      final withMeal = DaySnapshot(now: at(13, 0), neglected: n, meals: [PlannedMeal(id: 'm', at: at(13, 0))]);
      expect(engine.next(withMeal, const ObjectiveState.empty()).current?.id, 'meal:m');
    });

    test('mostNeglected picks the lowest score, ties by key', () {
      final pick = NeglectSuggestion.mostNeglected(const [
        NeglectSuggestion(planetKey: 'work', actionKey: 'a', score: 0.3),
        NeglectSuggestion(planetKey: 'family', actionKey: 'b', score: 0.3),
        NeglectSuggestion(planetKey: 'money', actionKey: 'c', score: 0.5),
      ]);
      expect(pick?.planetKey, 'family');
      expect(NeglectSuggestion.mostNeglected(const []), isNull);
    });

    test('travelling steps the nudges and the workout aside, but the travel planet stays', () {
      expect(engine.next(DaySnapshot(now: at(10, 0), neglected: n, travelling: true), const ObjectiveState.empty()).current, isNull);
      const t = NeglectSuggestion(planetKey: 'travel', actionKey: 'x');
      expect(engine.next(DaySnapshot(now: at(10, 0), neglected: t, travelling: true), const ObjectiveState.empty()).current?.id, 'planet:travel:x');
      final w = DaySnapshot(now: at(17, 0), workouts: [PlannedWorkout(id: 'w', at: at(17, 0))], travelling: true);
      final r = engine.next(w, const ObjectiveState.empty());
      expect(r.current, isNull);
      expect(r.agenda.map((e) => e.id), ['workout:w']);
    });
  });

  group('the whole day, every rule at once', () {
    DaySnapshot rich(DateTime now) => DaySnapshot(
      now: now,
      prayers: prayers(),
      doses: [MedDose(id: 'a', at: at(8, 0)), MedDose(id: 'b', at: at(13, 10))],
      timedTasks: [TimedTask(id: 't', at: at(10, 0))],
      adhkar: standardAdhkar(),
      wird: WirdSlot(id: 'p', from: at(9, 0)),
      meals: [PlannedMeal(id: 'm', at: at(13, 0))],
      workouts: [PlannedWorkout(id: 'w', at: at(17, 0))],
      neglected: const NeglectSuggestion(planetKey: 'work', actionKey: 'x'),
    );

    test('the card is always the best-ranked eligible objective and nothing is ever missing', () {
      for (var t = at(4, 0); !t.isAfter(at(23, 55)); t = t.add(const Duration(minutes: 5))) {
        final s = rich(t);
        final r = engine.next(s, const ObjectiveState.empty());
        final eligible = engine.eligibleNow(s, const ObjectiveState.empty());
        expect(r.current, eligible.isEmpty ? isNull : eligible.first, reason: hhmm(t));
        for (var i = 1; i < eligible.length; i++) {
          expect(eligible[i - 1].rule <= eligible[i].rule, isTrue, reason: hhmm(t));
        }
        // The planet nudge is eligible from Fajr, so after 04:45 the card is never empty.
        if (!t.isBefore(at(4, 45))) expect(r.current, isNotNull, reason: hhmm(t));
        if (r.current != null && r.current!.kind != ObjectiveKind.planet) {
          expect(r.agenda.where((e) => e.isCurrent).map((e) => e.id), [r.current!.id], reason: hhmm(t));
        }
      }
    });

    test('hand-checked checkpoints through the day', () {
      String id(int h, int m) => engine.next(rich(at(h, m)), const ObjectiveState.empty()).current?.id ?? '-';
      expect(id(4, 30), 'prayer:fajr');
      expect(id(6, 15), 'adhkar:morning');
      expect(id(7, 30), 'med:a');
      expect(id(9, 0), 'task:t');
      expect(id(11, 5), 'adhkar:morning');
      expect(id(12, 15), 'prayer:dhuhr');
      // Dhuhr stays until it is logged or its window (to Asr) is over.
      expect(id(13, 0), 'prayer:dhuhr');
      expect(id(16, 0), 'prayer:asr');
      expect(id(17, 0), 'prayer:asr');
      expect(id(23, 0), 'prayer:isha');
    });

    test('with everything handled by hand the day ends in "nothing now" and says what is next', () {
      final s = DaySnapshot(
        now: at(9, 0),
        prayers: prayers(logged: {...Prayer.values}),
        doses: [MedDose(id: 'b', at: at(13, 10))],
        timedTasks: [TimedTask(id: 'z', at: at(15, 0), done: true)],
      );
      final r = engine.next(s, const ObjectiveState.empty());
      expect(r.isNothingNow, isTrue);
      expect(r.later?.objective.id, 'med:b');
      expect(r.later?.showAt, at(12, 40));
    });
  });

  group('agenda («يومك») and later', () {
    test('time order, statuses, current flag, upNext without current and done', () {
      final s = DaySnapshot(
        now: at(12, 30),
        prayers: prayers(logged: {Prayer.fajr}),
        doses: [MedDose(id: 'a', at: at(8, 0), taken: true), MedDose(id: 'miss', at: at(9, 0)), MedDose(id: 'b', at: at(13, 0))],
        meals: [PlannedMeal(id: 'm', at: at(13, 30))],
        untimedTasks: const [UntimedTask(id: 'u')],
      );
      final r = engine.next(s, const ObjectiveState.empty());
      expect(r.current?.id, 'prayer:dhuhr');
      expect(r.agenda.map((e) => e.id), [
        'prayer:fajr',
        'med:a',
        'med:miss',
        'prayer:dhuhr',
        'med:b',
        'meal:m',
        'prayer:asr',
        'prayer:maghrib',
        'prayer:isha',
        'task:u',
      ]);
      DayEntryStatus st(String id) => r.agenda.firstWhere((e) => e.id == id).status;
      expect(st('prayer:fajr'), DayEntryStatus.done);
      expect(st('med:a'), DayEntryStatus.done);
      expect(st('med:miss'), DayEntryStatus.lapsed);
      expect(st('prayer:dhuhr'), DayEntryStatus.pending);
      expect(r.agenda.firstWhere((e) => e.id == 'prayer:dhuhr').isCurrent, isTrue);
      expect(r.upNext.map((e) => e.id), ['med:b', 'meal:m', 'prayer:asr', 'prayer:maghrib', 'prayer:isha', 'task:u']);
      // Behind the current one waits the medicine.
      expect(r.later?.objective.id, 'med:b');
    });

    test('a slot with no endsAt and an unsorted input still sorts the day', () {
      final s = DaySnapshot(
        now: at(10, 0),
        prayers: prayers().reversed.toList(),
      );
      expect(engine.next(s, const ObjectiveState.empty()).agenda.map((e) => e.id), [
        'prayer:fajr',
        'prayer:dhuhr',
        'prayer:asr',
        'prayer:maghrib',
        'prayer:isha',
      ]);
    });
  });

  group('«تم» / «بعدين» / «تخطّي»', () {
    const s0 = ObjectiveState.empty();
    DaySnapshot dhuhr(DateTime now, {List<Prayer> logged = const []}) => DaySnapshot(
      now: now,
      prayers: prayers(logged: {Prayer.fajr, ...logged}),
      doses: [MedDose(id: 'a', at: at(12, 30))],
    );

    test('done removes it at once (before the source catches up) and the next slides in', () {
      final before = engine.next(dhuhr(at(12, 30)), s0);
      expect(before.current?.id, 'prayer:dhuhr');
      final state = s0.markDone(before.current!.id, day);
      final after = engine.next(dhuhr(at(12, 30)), state);
      expect(after.current?.id, 'med:a');
      expect(after.agenda.firstWhere((e) => e.id == 'prayer:dhuhr').status, DayEntryStatus.done);
      // The undo brings it back.
      expect(engine.next(dhuhr(at(12, 30)), state.clear('prayer:dhuhr', day)).current?.id, 'prayer:dhuhr');
    });

    test('snooze 15 / 30 / 60 hides it until the exact minute, then it is back at its own priority', () {
      for (final option in SnoozeOption.values) {
        // The prayer is the card at 12:30 (the medicine, on from 12:00 to 13:00, waits behind it).
        final back = at(12, 30).add(option.duration);
        final state = s0.snooze('prayer:dhuhr', day, back);
        final before = engine.next(dhuhr(back.subtract(const Duration(minutes: 5))), state).current?.id;
        expect(before, isNot('prayer:dhuhr'), reason: '$option');
        expect(engine.next(dhuhr(back), state).current?.id, 'prayer:dhuhr', reason: '$option');
        expect(engine.next(dhuhr(back.add(const Duration(minutes: 5))), state).current?.id, 'prayer:dhuhr', reason: '$option');
      }
      // While hidden the medicine fills in, as long as its window is open.
      expect(engine.next(dhuhr(at(12, 40)), s0.snooze('prayer:dhuhr', day, at(12, 45))).current?.id, 'med:a');
    });

    test('a snoozed item shows in the day list as snoozed with the minute it returns', () {
      final until = at(12, 45);
      final r = engine.next(dhuhr(at(12, 30)), s0.snooze('prayer:dhuhr', day, until));
      final e = r.agenda.firstWhere((e) => e.id == 'prayer:dhuhr');
      expect(e.status, DayEntryStatus.snoozed);
      expect(e.hiddenUntil, until);
      expect(r.upNext.map((e) => e.id), contains('prayer:dhuhr'));
      expect(r.current?.id, 'med:a');
    });

    test('a snooze that outlasts the window means it never comes back (lapsed)', () {
      final state = s0.snooze('med:a', day, at(13, 30));
      final snap = DaySnapshot(now: at(13, 35), doses: [MedDose(id: 'a', at: at(12, 30))]);
      final r = engine.next(snap, state);
      expect(r.current, isNull);
      expect(r.agenda.single.status, DayEntryStatus.lapsed);
    });

    test('skip hides it for the rest of the day, survives a restart, and is gone next day', () {
      final skipped = s0.skip('prayer:dhuhr', day);
      final restarted = ObjectiveState.decode(skipped.encode());
      expect(restarted, skipped);
      final t = timeline((now) => dhuhr(now), state: restarted, from: at(12, 0), to: at(23, 55));
      expect(t.any((e) => e.endsWith('=prayer:dhuhr')), isFalse);
      expect(engine.next(dhuhr(at(12, 40)), restarted).agenda.firstWhere((e) => e.id == 'prayer:dhuhr').status, DayEntryStatus.skipped);

      // Tomorrow: same stored state, new day, the prayer is back.
      DaySnapshot tomorrow(DateTime now) => DaySnapshot(now: now, prayers: prayers(dayOffset: 1));
      expect(engine.next(tomorrow(at(12, 30, dayOffset: 1)), restarted).current?.id, 'prayer:dhuhr');
      // ... and a skip made on a different day never leaks into this one.
      expect(engine.next(dhuhr(at(12, 30)), s0.skip('prayer:dhuhr', day.subtract(const Duration(days: 1)))).current?.id, 'prayer:dhuhr');
    });

    test('a snooze made yesterday does not hide today', () {
      final y = day.subtract(const Duration(days: 1));
      final state = s0.snooze('prayer:dhuhr', y, at(13, 0));
      expect(engine.next(dhuhr(at(12, 30)), state).current?.id, 'prayer:dhuhr');
    });
  });

  group('tie-breaks', () {
    test('two simultaneous items: lower id first, whatever the input order', () {
      for (final order in [
        [MedDose(id: 'b', at: at(8, 0)), MedDose(id: 'a', at: at(8, 0))],
        [MedDose(id: 'a', at: at(8, 0)), MedDose(id: 'b', at: at(8, 0))],
      ]) {
        final r = engine.next(DaySnapshot(now: at(8, 0), doses: order), const ObjectiveState.empty());
        expect(r.current?.id, 'med:a');
        expect(r.later?.objective.id, 'med:b');
        expect(r.agenda.map((e) => e.id), ['med:a', 'med:b']);
      }
    });

    test('inside a rule the earliest first', () {
      final s = DaySnapshot(now: at(8, 10), doses: [MedDose(id: 'a', at: at(8, 20)), MedDose(id: 'z', at: at(8, 0))]);
      expect(engine.next(s, const ObjectiveState.empty()).current?.id, 'med:z');
    });

    test('duplicate ids collapse to one', () {
      final s = DaySnapshot(now: at(8, 0), doses: [MedDose(id: 'a', at: at(8, 0)), MedDose(id: 'a', at: at(8, 0))]);
      expect(engine.next(s, const ObjectiveState.empty()).agenda, hasLength(1));
    });
  });

  group('config', () {
    test('rules can be changed (e.g. a 5 minute prayer look-ahead)', () {
      const custom = ObjectiveEngine(rules: ObjectiveRules(prayerLead: Duration(minutes: 5)));
      final s = DaySnapshot(now: at(12, 15), prayers: prayers());
      expect(custom.next(s, const ObjectiveState.empty()).current, isNull);
      expect(custom.next(DaySnapshot(now: at(12, 20), prayers: prayers()), const ObjectiveState.empty()).current?.id, 'prayer:dhuhr');
    });
  });
}
