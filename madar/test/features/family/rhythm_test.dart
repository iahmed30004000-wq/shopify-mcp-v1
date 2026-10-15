import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/family/domain/birthdays.dart';
import 'package:madar/features/family/domain/contact_stats.dart';
import 'package:madar/features/family/domain/rhythm.dart';

void main() {
  final now = DateTime(2026, 9, 29, 14, 30);
  final created = DateTime(2026, 1, 1, 9);

  RhythmState eval(int? rhythm, DateTime? last, {DateTime? at}) =>
      RhythmEngine.evaluate(rhythmDays: rhythm, lastContact: last, createdAt: created, now: at ?? now);

  group('calendar days', () {
    test('counts whole local days, not 24-hour blocks', () {
      expect(CalendarDays.between(DateTime(2026, 9, 28, 23, 50), DateTime(2026, 9, 29, 0, 10)), 1);
      expect(CalendarDays.between(DateTime(2026, 9, 29, 0, 10), DateTime(2026, 9, 29, 23, 50)), 0);
      expect(CalendarDays.between(DateTime(2026, 9, 30), DateTime(2026, 9, 29)), -1);
      expect(CalendarDays.add(DateTime(2026, 12, 30, 18), 3), DateTime(2027, 1, 2));
    });
  });

  group('rhythm math', () {
    test('next due = last contact day + rhythm; days until due', () {
      final s = eval(7, DateTime(2026, 9, 25, 20));
      expect(s.nextDue, DateTime(2026, 10, 2));
      expect(s.daysSince, 4);
      expect(s.daysUntilDue, 3);
      expect(s.status, RhythmStatus.dueSoon);
      expect(s.group, FamilyGroup.thisWeek);
      expect(s.isDue, isFalse);
      expect(s.progress, closeTo(4 / 7, 1e-9));
    });

    test('due today and overdue by N days', () {
      final today = eval(3, DateTime(2026, 9, 26, 8));
      expect(today.daysUntilDue, 0);
      expect(today.status, RhythmStatus.dueToday);
      expect(today.isDue, isTrue);
      expect(today.daysOverdue, 0);

      final late = eval(2, DateTime(2026, 9, 24, 21));
      expect(late.daysUntilDue, -3);
      expect(late.daysOverdue, 3);
      expect(late.status, RhythmStatus.overdue);
      expect(late.group, FamilyGroup.overdue);
    });

    test('matches the Neglect Radar: overdue = days since − rhythm', () {
      // orbit_repository / planet_scores: since = calendar days, overdue = since - rhythm.
      for (final (rhythm, daysAgo) in [(1, 0), (1, 3), (7, 7), (7, 10), (30, 45)]) {
        final s = eval(rhythm, now.subtract(Duration(days: daysAgo)));
        expect(s.daysOverdue, daysAgo - rhythm > 0 ? daysAgo - rhythm : 0, reason: 'rhythm $rhythm, $daysAgo ago');
      }
    });

    test('never contacted counts from when the person was added', () {
      final s = RhythmEngine.evaluate(rhythmDays: 7, lastContact: null, createdAt: DateTime(2026, 9, 20, 10), now: now);
      expect(s.neverContacted, isTrue);
      expect(s.anchor, DateTime(2026, 9, 20, 10));
      expect(s.daysOverdue, 2);
      expect(s.daysSinceContact, isNull);
    });

    test('no rhythm: never due, grouped last', () {
      final s = eval(null, DateTime(2026, 6, 1));
      expect(s.status, RhythmStatus.none);
      expect(s.group, FamilyGroup.noRhythm);
      expect(s.nextDue, isNull);
      expect(s.isDue, isFalse);
      expect(eval(0, null).hasRhythm, isFalse);
      expect(eval(-4, null).hasRhythm, isFalse);
    });

    test('a rhythm change re-derives next due from the same last contact', () {
      final last = DateTime(2026, 9, 22, 18);
      expect(eval(14, last).status, RhythmStatus.dueSoon);
      expect(eval(21, last).status, RhythmStatus.ok);
      expect(eval(7, last).status, RhythmStatus.dueToday);
      expect(eval(5, last).daysOverdue, 2);
      expect(eval(30, last).daysUntilDue, 23);
      // Rhythm set where there was none: due immediately if long enough ago.
      expect(eval(3, DateTime(2026, 9, 1)).status, RhythmStatus.overdue);
    });

    test('future-dated values never count as a last contact in the future', () {
      final future = DateTime(2026, 10, 3);
      final s = eval(7, future);
      expect(s.lastContact, now);
      expect(s.daysSince, 0);
      expect(s.daysUntilDue, 7);

      expect(
        RhythmEngine.effectiveLastContact(
          stored: DateTime(2026, 9, 20),
          logs: [DateTime(2026, 9, 25), DateTime(2026, 12, 1)],
          now: now,
        ),
        DateTime(2026, 9, 25),
      );
      expect(RhythmEngine.effectiveLastContact(stored: future, now: now), now);
      expect(RhythmEngine.effectiveLastContact(logs: [future], now: now), isNull);
      expect(RhythmEngine.clampToNow(future, now), now);
    });

    test('logging moves the last contact forward only', () {
      final stored = DateTime(2026, 9, 27, 10);
      expect(
        RhythmEngine.lastContactAfterLog(stored: stored, at: DateTime(2026, 9, 28), now: now),
        DateTime(2026, 9, 28),
      );
      // A back-dated log never rewinds it.
      expect(RhythmEngine.lastContactAfterLog(stored: stored, at: DateTime(2026, 9, 20), now: now), stored);
      expect(
        RhythmEngine.lastContactAfterLog(stored: null, at: DateTime(2026, 9, 20), now: now),
        DateTime(2026, 9, 20),
      );
      // …nor sets it in the future.
      expect(RhythmEngine.lastContactAfterLog(stored: stored, at: DateTime(2027), now: now), now);
    });

    test('removing a contact falls back only when it was the source', () {
      final a = DateTime(2026, 9, 20), b = DateTime(2026, 9, 27);
      expect(RhythmEngine.lastContactAfterRemoval(stored: b, removedAt: b, remaining: [a], now: now), a);
      expect(RhythmEngine.lastContactAfterRemoval(stored: b, removedAt: a, remaining: [b], now: now), b);
      // The value before the removed log (e.g. imported without logs) wins
      // when later than the remaining logs.
      expect(
        RhythmEngine.lastContactAfterRemoval(
          stored: b,
          removedAt: b,
          remaining: [a],
          fallback: DateTime(2026, 9, 24),
          now: now,
        ),
        DateTime(2026, 9, 24),
      );
      expect(RhythmEngine.lastContactAfterRemoval(stored: b, removedAt: b, remaining: const [], now: now), isNull);
      // Remaining future logs are ignored.
      expect(
        RhythmEngine.lastContactAfterRemoval(stored: b, removedAt: b, remaining: [DateTime(2026, 11, 1)], now: now),
        isNull,
      );
    });

    test('normalises rhythms', () {
      expect(RhythmEngine.normalizeRhythm(null), isNull);
      expect(RhythmEngine.normalizeRhythm(0), isNull);
      expect(RhythmEngine.normalizeRhythm(9999), RhythmEngine.maxRhythmDays);
      expect(RhythmEngine.suggestedRhythm('mother'), 2);
      expect(RhythmEngine.suggestedRhythm('wife'), isNull);
      expect(RhythmEngine.suggestedRhythm('whatever'), isNull);
    });
  });

  group('urgency and grouping', () {
    final people = <String, RhythmState>{
      'friend late 20/14': eval(14, now.subtract(const Duration(days: 20))),
      'father late 1/2': eval(2, now.subtract(const Duration(days: 3))),
      'sister due today': eval(7, now.subtract(const Duration(days: 7))),
      'brother in 2': eval(7, now.subtract(const Duration(days: 5))),
      'colleague in 20': eval(30, now.subtract(const Duration(days: 10))),
      'neighbour no rhythm': eval(null, now.subtract(const Duration(days: 90))),
      'uncle in 5': eval(7, now.subtract(const Duration(days: 2))),
      'mother late 3/2': eval(2, now.subtract(const Duration(days: 5))),
    };

    test('overdue first (largest share of the rhythm), then due today, then soonest', () {
      final order = RhythmEngine.byUrgency(people.keys, (k) => people[k]!);
      expect(order, [
        'mother late 3/2',
        'father late 1/2',
        'friend late 20/14',
        'sister due today',
        'brother in 2',
        'uncle in 5',
        'colleague in 20',
        'neighbour no rhythm',
      ]);
    });

    test('ties keep the manual order', () {
      final twins = {'b': eval(7, now), 'a': eval(7, now), 'c': eval(7, now)};
      expect(RhythmEngine.byUrgency(twins.keys, (k) => twins[k]!), ['b', 'a', 'c']);
    });

    test('groups: overdue / due today / this week / in touch / no rhythm, empty ones omitted', () {
      final groups = RhythmEngine.group(people.keys, (k) => people[k]!);
      expect(groups.keys, [
        FamilyGroup.overdue,
        FamilyGroup.dueToday,
        FamilyGroup.thisWeek,
        FamilyGroup.inTouch,
        FamilyGroup.noRhythm,
      ]);
      expect(groups[FamilyGroup.overdue], ['mother late 3/2', 'father late 1/2', 'friend late 20/14']);
      expect(groups[FamilyGroup.dueToday], ['sister due today']);
      expect(groups[FamilyGroup.thisWeek], ['brother in 2', 'uncle in 5']);
      expect(groups[FamilyGroup.inTouch], ['colleague in 20']);
      expect(groups[FamilyGroup.noRhythm], ['neighbour no rhythm']);

      final calm = RhythmEngine.group(['x'], (_) => eval(30, now));
      expect(calm.keys, [FamilyGroup.inTouch]);
    });

    test('this week is due within seven days', () {
      expect(eval(14, now.subtract(const Duration(days: 7))).group, FamilyGroup.thisWeek);
      expect(eval(14, now.subtract(const Duration(days: 6))).group, FamilyGroup.inTouch);
    });

    test('digest projection: due on a later day', () {
      final s = eval(7, DateTime(2026, 9, 25));
      expect(RhythmEngine.dueOn(s, DateTime(2026, 10, 1)), isFalse);
      expect(RhythmEngine.dueOn(s, DateTime(2026, 10, 2)), isTrue);
      expect(RhythmEngine.dueOn(s, DateTime(2026, 10, 9)), isTrue);
      expect(RhythmEngine.dueOn(eval(null, null), DateTime(2027)), isFalse);
    });
  });

  group('birthdays', () {
    test('next occurrence, countdown and age', () {
      final b = Birthdays.next(DateTime(1990, 10, 12), now)!;
      expect(b.next, DateTime(2026, 10, 12));
      expect(b.daysUntil, 13);
      expect(b.turning, 36);

      final passed = Birthdays.next(DateTime(1990, 3, 1), now)!;
      expect(passed.next, DateTime(2027, 3, 1));
      expect(passed.turning, 37);

      final today = Birthdays.next(DateTime(2000, 9, 29), DateTime(2026, 9, 29, 23, 59))!;
      expect(today.isToday, isTrue);
      expect(today.turning, 26);
      expect(Birthdays.next(DateTime(2000, 9, 30), now)!.isTomorrow, isTrue);
      expect(Birthdays.next(null, now), isNull);
    });

    test('29 February falls on 28 February in a common year', () {
      final b = Birthdays.next(DateTime(2004, 2, 29), DateTime(2027, 1, 10))!;
      expect(b.next, DateTime(2027, 2, 28));
      final leap = Birthdays.next(DateTime(2004, 2, 29), DateTime(2028, 1, 10))!;
      expect(leap.next, DateTime(2028, 2, 29));
    });

    test('unknown year: no age', () {
      final stored = Birthdays.normalize(DateTime(1985, 11, 3), yearKnown: false);
      expect(stored.year, Birthdays.unknownYear);
      expect(Birthdays.yearKnown(stored), isFalse);
      expect(Birthdays.next(stored, now)!.turning, isNull);
      expect(Birthdays.next(stored, now)!.next, DateTime(2026, 11, 3));
    });

    test('upcoming within a window, soonest first', () {
      final items = {'a': DateTime(1990, 10, 20), 'b': DateTime(1990, 10, 1), 'c': DateTime(1990, 12, 25), 'd': null};
      final soon = Birthdays.upcoming(items.keys, (k) => items[k], now, withinDays: 30);
      expect([for (final (k, _) in soon) k], ['b', 'a']);
    });
  });

  group('contact statistics', () {
    ContactPoint at(DateTime t, [ContactChannel c = ContactChannel.call]) => (at: t, channel: c);

    test('average interval vs rhythm, on-rhythm share, longest gap, recent count', () {
      final logs = [
        at(DateTime(2026, 6, 1, 10)),
        at(DateTime(2026, 6, 6, 20), ContactChannel.visit),
        at(DateTime(2026, 6, 6, 21)), // same day: one interval point
        at(DateTime(2026, 6, 20, 9), ContactChannel.message),
        at(DateTime(2026, 6, 27, 9)),
        at(DateTime(2026, 9, 27, 9)),
        at(DateTime(2026, 10, 5, 9)), // future: ignored
      ];
      final s = ContactStatsMath.of(logs, rhythmDays: 7, now: now);
      expect(s.total, 6);
      expect(s.intervals, [5, 14, 7, 92]);
      expect(s.averageInterval, closeTo((5 + 14 + 7 + 92) / 4, 1e-9));
      expect(s.longestGap, 92);
      expect(s.onRhythmShare, 0.5);
      expect(s.recent, 1);
      expect(s.byChannel[ContactChannel.call], 4);
      expect(s.favouriteChannel, ContactChannel.call);
      expect(s.last, DateTime(2026, 9, 27, 9));
    });

    test('empty and single contact', () {
      expect(ContactStatsMath.of(const [], now: now).total, 0);
      final one = ContactStatsMath.of([at(DateTime(2026, 9, 1))], rhythmDays: 7, now: now);
      expect(one.total, 1);
      expect(one.averageInterval, isNull);
      expect(one.onRhythmShare, isNull);
      expect(one.hasIntervals, isFalse);
    });

    test('the chart keeps the last twelve intervals', () {
      final logs = [for (var i = 0; i < 20; i++) at(DateTime(2026, 1, 1).add(Duration(days: i * 3)))];
      final s = ContactStatsMath.of(logs, now: now);
      expect(s.intervals.length, 19);
      expect(ContactStatsMath.chart(s).length, ContactStatsMath.chartIntervals);
    });
  });
}
