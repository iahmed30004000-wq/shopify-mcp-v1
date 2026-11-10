import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ramadan/domain/ramadan_year_log.dart';
import 'package:madar/features/ramadan/domain/taraweeh_log.dart';

T roundTrip<T>(Object json, T Function(Object?) read) => read(jsonDecode(jsonEncode(json)));

void main() {
  group('TaraweehLog', () {
    test('one tap marks a night, a second tap un-marks it', () {
      final a = TaraweehLog().toggle(5);
      expect(a.isDone(5), isTrue);
      expect(a.nightsPrayed, 1);
      final b = a.toggle(5);
      expect(b.isDone(5), isFalse);
      expect(b.nightsPrayed, 0);
      // The old value is untouched, so it doubles as the undo.
      expect(a.isDone(5), isTrue);
    });

    test('rakaat and note are optional, a toggle keeps them', () {
      var log = TaraweehLog().withEntry(const TaraweehEntry(night: 3, rakaat: 8, note: 'with family'));
      log = log.withEntry(const TaraweehEntry(night: 4));
      expect(log.entryOf(4)!.rakaat, isNull);
      expect(log.entryOf(4)!.note, isNull);
      expect(log.totalRakaat, 8);
      final off = log.toggle(3);
      expect(off.entryOf(3)!.rakaat, 8);
      expect(off.entryOf(3)!.note, 'with family');
      expect(off.totalRakaat, 0, reason: 'only prayed nights count');
      expect(off.toggle(3).isDone(3), isTrue);
    });

    test('nights outside 1..30 are ignored', () {
      final log = TaraweehLog().toggle(0).toggle(31).toggle(-2);
      expect(log.entries, isEmpty);
      expect(TaraweehLog([const TaraweehEntry(night: 99)]).entries, isEmpty);
    });

    test('JSON round trip keeps every field and ignores junk', () {
      final log = TaraweehLog([
        const TaraweehEntry(night: 27, rakaat: 20, note: 'long night'),
        const TaraweehEntry(night: 1),
        const TaraweehEntry(night: 2, done: false, note: 'sick'),
      ]);
      final back = roundTrip(log.toJson(), TaraweehLog.fromJson);
      expect(back, log);
      expect(back.hashCode, log.hashCode);
      expect(back.entryOf(2)!.done, isFalse);
      // Sorted by night in the output.
      expect([for (final e in log.toJson()['entries'] as List) (e as Map)['night']], [1, 2, 27]);

      final junk = TaraweehLog.fromJson({
        'entries': [
          {'night': 'x'},
          {'night': 5, 'rakaat': -3, 'note': ''},
          'nope',
          {'night': 40},
        ],
      });
      expect(junk.entries.keys, [5]);
      expect(junk.entryOf(5)!.rakaat, isNull);
      expect(junk.entryOf(5)!.note, isNull);
      expect(TaraweehLog.fromJson(null).entries, isEmpty);
      expect(TaraweehLog.fromJson('x').entries, isEmpty);
    });
  });

  group('RamadanYearLog and the book', () {
    RamadanYearLog year(int y, List<int> nights, {int pages = 0, List<int>? fasting, int? rakaat}) => RamadanYearLog(
      hijriYear: y,
      taraweeh: TaraweehLog([for (final n in nights) TaraweehEntry(night: n, rakaat: rakaat)]),
      pagesRead: pages,
      fastingDays: fasting,
    );

    test('JSON round trip of a year, with and without fasting', () {
      final a = year(1447, [1, 2, 3], pages: 604, fasting: [1, 2, 4], rakaat: 8);
      expect(roundTrip(a.toJson(), (j) => RamadanYearLog.fromJson(j! as Map<String, dynamic>)), a);
      final b = year(1446, [5]);
      final back = roundTrip(b.toJson(), (j) => RamadanYearLog.fromJson(j! as Map<String, dynamic>));
      expect(back, b);
      expect(back.fastingDays, isNull, reason: 'not tracked stays not tracked');
      expect(year(1446, [], fasting: const []).fastingDays, isEmpty, reason: 'tracked but zero days is not null');
    });

    test('two or more years coexist, keyed by Hijri year, newest first', () {
      var book = RamadanLogBook();
      book = book.withYear(year(1446, [1, 2]));
      book = book.withYear(year(1447, [1, 2, 3]));
      book = book.withYear(year(1445, [9]));
      expect(book.years, [1447, 1446, 1445]);
      expect(book.of(1446)!.taraweeh.nightsPrayed, 2);
      expect(book.of(1447)!.taraweeh.nightsPrayed, 3);
      expect(book.of(1448), isNull);
      expect(book.ofOrEmpty(1448).taraweeh.nightsPrayed, 0);
      expect(book.previousOf(1447)!.hijriYear, 1446);
      expect(book.previousOf(1448)!.hijriYear, 1447);
      expect(book.previousOf(1445), isNull);
      // Replacing a year leaves the others alone.
      final edited = book.withYear(year(1446, [1, 2, 3, 4]));
      expect(edited.of(1446)!.taraweeh.nightsPrayed, 4);
      expect(edited.of(1447), book.of(1447));
      expect(book.of(1446)!.taraweeh.nightsPrayed, 2);
    });

    test('book JSON round trip and tolerance', () {
      final book = RamadanLogBook([
        year(1446, [1], pages: 100),
        year(1447, [2, 3], fasting: [1]),
      ]);
      final back = roundTrip(book.toJson(), RamadanLogBook.fromJson);
      expect(back, book);
      expect(back.hashCode, book.hashCode);
      expect(back.years, [1447, 1446]);
      final tolerant = RamadanLogBook.fromJson({
        'years': [
          {'hijriYear': 1447},
          {'hijriYear': 'x'},
          {'hijriYear': -1},
          'junk',
        ],
      });
      expect(tolerant.years, [1447]);
      expect(RamadanLogBook.fromJson(null).years, isEmpty);
    });

    test('compare: per night and totals for two years', () {
      final last = year(1446, [1, 2, 3, 27], pages: 400, fasting: [1, 2, 3, 4, 5], rakaat: 8);
      final now = year(1447, [2, 3, 4, 5, 6, 27], pages: 604, fasting: [1, 2, 3], rakaat: 20);
      final cmp = RamadanComparison.compare(now, last);
      expect(cmp.nights, hasLength(30));
      NightDifference diff(int n) => cmp.nights[n - 1].difference;
      expect(diff(1), NightDifference.onlyLastYear);
      expect(diff(2), NightDifference.both);
      expect(diff(4), NightDifference.onlyThisYear);
      expect(diff(10), NightDifference.neither);
      expect(diff(27), NightDifference.both);
      expect(cmp.nights[3].thisYear!.rakaat, 20);
      expect(cmp.nights[0].lastYear!.rakaat, 8);
      expect(cmp.nights[9].thisYear, isNull);
      expect(cmp.thisYear.nightsPrayed, 6);
      expect(cmp.lastYear.nightsPrayed, 4);
      expect(cmp.nightsPrayedDelta, 2);
      expect(cmp.rakaatDelta, 6 * 20 - 4 * 8);
      expect(cmp.pagesReadDelta, 204);
      expect(cmp.thisYear.fastingDays, 3);
      expect(cmp.lastYear.fastingDays, 5);
      expect(cmp.fastingDaysDelta, -2);
    });

    test('compare: fasting is only compared when both years tracked it', () {
      final a = RamadanComparison.compare(year(1447, [1], fasting: [1, 2]), year(1446, [1]));
      expect(a.fastingDaysDelta, isNull);
      expect(a.lastYear.fastingDays, isNull);
      expect(a.thisYear.fastingDays, 2);
      final b = RamadanComparison.compare(year(1447, [1]), year(1446, [1]));
      expect(b.fastingDaysDelta, isNull);
    });

    test('compare: nothing logged, a shorter night list, and purity', () {
      final empty = RamadanComparison.compare(year(1447, []), year(1446, []));
      expect(empty.nightsPrayedDelta, 0);
      expect(empty.nights.every((n) => n.difference == NightDifference.neither), isTrue);
      final short = RamadanComparison.compare(year(1447, [1]), year(1446, [1]), nightCount: 29);
      expect(short.nights, hasLength(29));
      final x = year(1447, [1, 2]), y = year(1446, [2]);
      expect(RamadanComparison.compare(x, y).nightsPrayedDelta, RamadanComparison.compare(x, y).nightsPrayedDelta);
      expect(x.taraweeh.nightsPrayed, 2, reason: 'inputs are not touched');
    });

    test('fasting days outside 1..30 are dropped', () {
      expect(year(1447, [], fasting: [0, 1, 31, 30]).fastingDays, {1, 30});
    });
  });
}
