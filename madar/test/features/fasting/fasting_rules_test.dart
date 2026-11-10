import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/fasting/domain/fasting_models.dart';
import 'package:madar/features/fasting/domain/fasting_rules.dart';
import 'package:madar/features/prayer/domain/hijri.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import 'fasting_test_support.dart';

Set<String> keys(Iterable<FastReminder> rs) => {for (final r in rs) CalendarDays.key(r.day)};

void main() {
  final y1448 = HijriYearView(1448);
  final y1449 = HijriYearView(1449);

  group('the table the tests lean on', () {
    test('month starts round-trip through the engine', () {
      for (final v in [y1448, y1449]) {
        for (var m = 1; m <= 12; m++) {
          final h = FastingRules.hijriOf(v.starts[m]!, cfg(0));
          expect((h.year, h.month, h.day), (v.year, m, 1), reason: '${v.year}/$m');
          expect(v.lengths[m], inInclusiveRange(29, 30));
        }
      }
    });
  });

  for (final offset in [-1, 0, 1]) {
    group('a full Hijri year at offset $offset', () {
      for (final v in [y1448, y1449]) {
        test('${v.year}: exactly the owner\'s set of reminded days, one per day', () {
          final config = cfg(offset);
          // The year's own civil span, shifted by the offset.
          final from = CalendarDays.add(v.firstDay, -offset);
          final to = CalendarDays.add(v.lastDay, -offset);
          final inYear = FastingRules.remindersBetween(from, to, config);
          expect(keys(inYear), v.expectedReminded(offset));
          expect(inYear.length, keys(inYear).length, reason: 'one reminder per day');
          expect(inYear.length, greaterThan(100));
        });

        test('${v.year}: the three exclusions and the Ramadan assumption', () {
          final c = cfg(offset);
          // The two Eids and the three days of Tashriq.
          for (final (m, d) in [(10, 1), (12, 10), (12, 11), (12, 12), (12, 13)]) {
            expect(FastingRules.reminderOn(v.civil(m, d, offset), c), isNull, reason: 'no reminder on $m/$d');
          }
          // 13 Dhu al-Hijjah is gone from the white days: only 14 and 15 stay.
          expect(FastingRules.reminderOn(v.civil(12, 14, offset), c)?.kind, FastKind.whiteDay);
          expect(FastingRules.reminderOn(v.civil(12, 15, offset), c)?.kind, FastKind.whiteDay);
          // The ten reminds days 1-9 and never the 10th.
          for (var d = 1; d <= 9; d++) {
            expect(FastingRules.reminderOn(v.civil(12, d, offset), c), isNotNull, reason: 'day $d of the ten');
          }
          // Every other month has all three white days.
          for (final m in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11]) {
            for (final d in [13, 14, 15]) {
              expect(FastingRules.reminderOn(v.civil(m, d, offset), c), isNotNull, reason: 'white $m/$d');
            }
          }
          // Ramadan: nothing at all, Mondays and Thursdays included.
          for (var d = 1; d <= v.lengths[9]!; d++) {
            expect(FastingRules.reminderOn(v.civil(9, d, offset), c), isNull, reason: 'Ramadan day $d');
          }
        });

        test('${v.year}: yearly kinds land on their own days', () {
          final c = cfg(offset);
          FastKind kindAt(int m, int d) => FastingRules.reminderOn(v.civil(m, d, offset), c)!.kind;
          expect(kindAt(12, 9), FastKind.arafah);
          expect(kindAt(1, 10), FastKind.ashura);
          expect(kindAt(1, 9), FastKind.tasua);
          expect(kindAt(1, 1), anyOf(FastKind.muharramMore, FastKind.monday, FastKind.thursday));
          expect(kindAt(8, 1), anyOf(FastKind.shabanMore, FastKind.monday, FastKind.thursday));
          for (var d = 2; d <= 7; d++) {
            expect(kindAt(10, d), FastKind.sixShawwal);
          }
          expect(FastingRules.reminderOn(v.civil(10, 8, offset), c)?.kind, isNot(FastKind.sixShawwal));
          expect(FastingRules.reminderOn(v.civil(10, 1, offset), c), isNull);
        });
      }

      test('two consecutive years: the year boundary has no gap and no repeat', () {
        final c = cfg(offset);
        final from = CalendarDays.add(y1448.lastDay, -4 - offset);
        final to = CalendarDays.add(y1449.firstDay, 4 - offset);
        final rs = FastingRules.remindersBetween(from, to, c);
        expect(keys(rs).length, rs.length);
        final sorted = [...rs]..sort((a, b) => a.day.compareTo(b.day));
        expect(rs.map((r) => r.day).toList(), sorted.map((r) => r.day).toList());
        // The first Hijri days of the new year carry year 1449, the last of 1448 year 1448.
        expect(rs.first.hijri.year, 1448);
        expect(rs.last.hijri.year, 1449);
        expect(rs.map((r) => r.hijri.year).toSet(), {1448, 1449});
      });
    });
  }

  group('offset moves every rule, not only the display', () {
    test('the Hijri kinds shift by exactly the offset, the weekday kinds do not', () {
      for (final (m, d, kind) in [
        (12, 9, FastKind.arafah),
        (1, 10, FastKind.ashura),
        (1, 9, FastKind.tasua),
        (10, 3, FastKind.sixShawwal),
      ]) {
        for (final offset in [-1, 0, 1]) {
          final r = FastingRules.reminderOn(y1448.civil(m, d, offset), cfg(offset));
          expect(r?.kind, kind, reason: '$m/$d at $offset');
          expect(r!.hijri.day, d);
        }
        // Same civil day, different offset => a different Hijri day.
        final g = y1448.civil(m, d, 0);
        expect(FastingRules.hijriOf(g, cfg(1)).day, isNot(FastingRules.hijriOf(g, cfg(0)).day));
      }
    });

    test('the white days, the ten and Tashriq follow the shift too', () {
      final g = y1448.civil(12, 13, 0); // 13 Dhu al-Hijjah as calculated
      expect(FastingRules.reminderOn(g, cfg(0)), isNull);
      // Offset -1 makes this civil date the 12th (still Tashriq), +1 the 14th.
      expect(FastingRules.reminderOn(g, cfg(-1)), isNull);
      expect(FastingRules.reminderOn(g, cfg(1))?.kind, FastKind.whiteDay);
      // Calculated 10 Dhu al-Hijjah (the Eid) is the 9th (Arafah) at offset -1.
      final eid = y1448.civil(12, 10, 0);
      expect(FastingRules.reminderOn(eid, cfg(0)), isNull);
      expect(FastingRules.reminderOn(eid, cfg(-1))?.kind, FastKind.arafah);
      expect(FastingRules.reminderOn(eid, cfg(1)), isNull);
    });

    test('replanning from scratch gives the same answer', () {
      final a = FastingRules.remindersBetween(y1448.firstDay, y1449.lastDay, cfg(1));
      final b = FastingRules.remindersBetween(y1448.firstDay, y1449.lastDay, FastingConfig.fromJson(cfg(1).toJson()));
      expect(a, b);
      expect(FastingRules.remindersBetween(y1448.firstDay, y1449.lastDay, cfg(-1)), isNot(a));
    });
  });

  group('29- and 30-day months, month boundary', () {
    test('white days are the 13th-15th whatever the month length', () {
      final lens = {...y1448.lengths.values, ...y1449.lengths.values};
      expect(lens, containsAll([29, 30]), reason: 'the two years hold both month lengths');
      for (final v in [y1448, y1449]) {
        for (var m = 1; m <= 12; m++) {
          if (m == 9) continue;
          final white = FastingRules.remindersBetween(v.starts[m]!, CalendarDays.add(v.starts[m]!, v.lengths[m]! - 1), cfg(0))
              .where((r) => r.kind == FastKind.whiteDay || r.alsoKinds.contains(FastKind.whiteDay))
              .map((r) => r.hijri.day)
              .toList();
          expect(white, m == 12 ? [14, 15] : [13, 14, 15], reason: '${v.year}/$m (length ${v.lengths[m]})');
        }
      }
    });

    test('the last day of one month and the first of the next carry the right month', () {
      for (var m = 1; m <= 11; m++) {
        final last = CalendarDays.add(y1448.starts[m]!, y1448.lengths[m]! - 1);
        final lastH = FastingRules.hijriOf(last, cfg(0));
        final nextH = FastingRules.hijriOf(CalendarDays.add(last, 1), cfg(0));
        expect((lastH.month, lastH.day), (m, y1448.lengths[m]));
        expect((nextH.month, nextH.day), (m + 1, 1));
      }
    });

    test('the nudge falls on its day, clamped into 1-29', () {
      final c = cfg(0, nudgeDay: 5);
      // Pick a non-Monday/Thursday day so the nudge is the winner.
      HijriDate h(int m, int d) => HijriDate(year: 1448, month: m, day: d, monthLength: 29);
      expect(FastingRules.applicable(h(1, 5), DateTime.tuesday, nudgeDay: 5), [FastKind.muharramMore]);
      expect(FastingRules.applicable(h(8, 5), DateTime.tuesday, nudgeDay: 5), [FastKind.shabanMore]);
      expect(FastingRules.applicable(h(2, 5), DateTime.tuesday, nudgeDay: 5), isEmpty);
      expect(FastingRules.applicable(h(1, 29), DateTime.tuesday, nudgeDay: 99), [FastKind.muharramMore]);
      expect(FastingRules.applicable(h(1, 1), DateTime.tuesday, nudgeDay: -4), [FastKind.muharramMore]);
      expect(c.effectiveNudgeDay, 5);
      // One nudge per month, never a daily alarm.
      final month = FastingRules.remindersBetween(y1448.starts[8]!, CalendarDays.add(y1448.starts[8]!, y1448.lengths[8]! - 1), cfg(0));
      expect(month.where((r) => r.kind == FastKind.shabanMore || r.alsoKinds.contains(FastKind.shabanMore)).length, 1);
    });
  });

  group('priority and dedupe', () {
    test('a Monday that is also a white day: one reminder, the richer kind wins', () {
      final r = _firstWhere(y1448, y1449, (g, h) => g.weekday == DateTime.monday && h.day >= 13 && h.day <= 15 && h.month != 9 && h.month != 12);
      final rem = FastingRules.reminderOn(r, cfg(0))!;
      expect(rem.kind, FastKind.whiteDay);
      expect(rem.alsoKinds, [FastKind.monday]);
    });

    test('a Thursday white day likewise', () {
      final r = _firstWhere(y1448, y1449, (g, h) => g.weekday == DateTime.thursday && h.day >= 13 && h.day <= 15 && h.month != 9 && h.month != 12);
      final rem = FastingRules.reminderOn(r, cfg(0))!;
      expect(rem.kind, FastKind.whiteDay);
      expect(rem.alsoKinds, [FastKind.thursday]);
    });

    test('Ashura / Tasu\'a / Arafah on a Monday or Thursday keep the day\'s one reminder', () {
      var seen = 0;
      for (var year = 1447; year <= 1480 && seen < 3; year++) {
        final v = HijriYearView(year);
        for (final (m, d, kind) in [(1, 10, FastKind.ashura), (1, 9, FastKind.tasua), (12, 9, FastKind.arafah)]) {
          final g = v.civil(m, d, 0);
          if (g.weekday != DateTime.monday && g.weekday != DateTime.thursday) continue;
          final rem = FastingRules.reminderOn(g, cfg(0))!;
          expect(rem.kind, kind);
          final weekday = g.weekday == DateTime.monday ? FastKind.monday : FastKind.thursday;
          expect(rem.alsoKinds, kind == FastKind.arafah ? [FastKind.dhuHijjahTen, weekday] : [weekday]);
          seen++;
        }
      }
      expect(seen, greaterThan(0));
    });

    test('the ten of Dhu al-Hijjah: day 9 is Arafah, days 1-8 the ten', () {
      for (var d = 1; d <= 8; d++) {
        final r = FastingRules.reminderOn(y1448.civil(12, d, 0), cfg(0))!;
        expect(r.kind == FastKind.dhuHijjahTen || r.alsoKinds.contains(FastKind.dhuHijjahTen), isTrue);
      }
      final nine = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      expect(nine.kind, FastKind.arafah);
      expect(nine.alsoKinds, contains(FastKind.dhuHijjahTen));
    });

    test('deterministic: asking twice gives equal reminders with equal also-order', () {
      for (var i = 0; i < 400; i++) {
        final g = CalendarDays.add(y1448.firstDay, i);
        expect(FastingRules.reminderOn(g, cfg(0)), FastingRules.reminderOn(g, cfg(0)));
      }
    });

    test('a switched-off kind steps aside for the next one', () {
      final r = _firstWhere(y1448, y1449, (g, h) => g.weekday == DateTime.monday && h.day >= 13 && h.day <= 15 && h.month != 9 && h.month != 12);
      final rem = FastingRules.reminderOn(r, cfg(0, disabled: {FastKind.whiteDay}))!;
      expect(rem.kind, FastKind.monday);
      expect(FastingRules.reminderOn(r, cfg(0, disabled: {FastKind.whiteDay, FastKind.monday})), isNull);
    });
  });

  group('the six of Shawwal', () {
    test('default 2-7; the start day is a parameter and never reaches the Eid', () {
      List<int> days(int start) => [
        for (var d = 1; d <= 30; d++)
          if (FastingRules.applicable(
            HijriDate(year: 1448, month: 10, day: d, monthLength: 30),
            DateTime.tuesday,
            shawwalStartDay: start,
          ).contains(FastKind.sixShawwal))
            d,
      ];
      expect(days(2), [2, 3, 4, 5, 6, 7]);
      expect(days(10), [10, 11, 12, 13, 14, 15]);
      expect(days(1), [2, 3, 4, 5, 6, 7], reason: '1 Shawwal is the Eid');
      expect(days(0), [2, 3, 4, 5, 6, 7]);
      expect(days(99), [24, 25, 26, 27, 28, 29]);
    });
  });

  group('known date, 1447 AH', () {
    test('Arafah, the Eid and Tashriq of 2026 (Umm al-Qura)', () {
      final v = HijriYearView(1447);
      final arafah = v.civil(12, 9, 0);
      expect(arafah.year, 2026);
      expect(arafah.month, 5);
      expect(arafah.day, inInclusiveRange(25, 27));
      expect(FastingRules.reminderOn(arafah, cfg(0))!.kind, FastKind.arafah);
      expect(FastingRules.reminderOn(CalendarDays.add(arafah, 1), cfg(0)), isNull);
      expect(FastingRules.reminderOn(CalendarDays.add(arafah, 2), cfg(0)), isNull);
      expect(FastingRules.reminderOn(CalendarDays.add(arafah, 3), cfg(0)), isNull);
      expect(FastingRules.reminderOn(CalendarDays.add(arafah, 4), cfg(0)), isNull);
      expect(FastingRules.reminderOn(CalendarDays.add(arafah, 5), cfg(0))!.kind, FastKind.whiteDay);
    });

    test('Ramadan 1447 starts 18 Feb 2026 and holds no reminder', () {
      expect(FastingRules.reminderOn(DateTime(2026, 2, 18), cfg(0)), isNull); // Wednesday
      expect(FastingRules.reminderOn(DateTime(2026, 2, 19), cfg(0)), isNull); // Thursday
      expect(FastingRules.reminderOn(DateTime(2026, 2, 23), cfg(0)), isNull); // Monday
    });
  });
}

/// The first civil day (offset 0) in the two years satisfying [test].
DateTime _firstWhere(HijriYearView a, HijriYearView b, bool Function(DateTime g, HijriDate h) test) {
  for (final v in [a, b]) {
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= v.lengths[m]!; d++) {
        final g = v.civil(m, d, 0);
        final h = HijriDate(year: v.year, month: m, day: d, monthLength: v.lengths[m]!);
        if (test(g, h)) return g;
      }
    }
  }
  throw StateError('no such day');
}
