import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ramadan/domain/last_ten_nights.dart';
import 'package:madar/features/ramadan/domain/ramadan_calendar.dart';
import 'package:madar/features/ramadan/domain/ramadan_notification_ids.dart';

void main() {
  group('last ten nights', () {
    test('nights 21 to the end of the month', () {
      expect(LastTenNights.nights(), [for (var n = 21; n <= 30; n++) n]);
      expect(LastTenNights.nights(monthLength: 29), [for (var n = 21; n <= 29; n++) n]);
      expect(LastTenNights.isLastTen(20), isFalse);
      expect(LastTenNights.isLastTen(21), isTrue);
      expect(LastTenNights.isLastTen(30), isTrue);
      expect(LastTenNights.isLastTen(30, monthLength: 29), isFalse);
      expect(LastTenNights.isLastTen(0), isFalse);
    });

    test('the odd nights are 21, 23, 25, 27, 29 and only those', () {
      expect(LastTenNights.oddSoughtNights, [21, 23, 25, 27, 29]);
      for (var n = 1; n <= 30; n++) {
        expect(LastTenNights.isOddSought(n), [21, 23, 25, 27, 29].contains(n), reason: 'night $n');
      }
      final m = LastTenNights.markOf(27);
      expect((m.isLastTen, m.isOddSought), (true, true));
      final even = LastTenNights.markOf(28);
      expect((even.isLastTen, even.isOddSought), (true, false));
      final early = LastTenNights.markOf(15);
      expect((early.isLastTen, early.isOddSought), (false, false));
    });

    test('night 21 begins on the evening of day 20 (the stated convention)', () {
      const c = RamadanCalendar();
      final s = c.spanOfYear(1448);
      expect(s.eveningOfNight(21), s.dateOfDay(20));
    });

    test('the Qadr supplication is a slot id only, no text', () {
      expect(LastTenNights.qadrSupplicationSlotId, 'ramadan.qadr.supplication');
    });
  });

  group('notification ids', () {
    test('the block is 210000-210999 and owns exactly that', () {
      expect(RamadanNotificationIds.first, 210000);
      expect(RamadanNotificationIds.last, 210999);
      expect(RamadanNotificationIds.owns(209999), isFalse);
      expect(RamadanNotificationIds.owns(210000), isTrue);
      expect(RamadanNotificationIds.owns(210999), isTrue);
      expect(RamadanNotificationIds.owns(211000), isFalse);
    });

    test('every kind x every day is inside the block, unique and stable', () {
      final seen = <int>{};
      for (final kind in RamadanReminderKind.values) {
        for (var day = 1; day <= 30; day++) {
          final id = RamadanNotificationIds.forDay(kind, day);
          expect(RamadanNotificationIds.owns(id), isTrue, reason: '$kind $day');
          expect(seen.add(id), isTrue, reason: 'duplicate $kind $day');
          expect(RamadanNotificationIds.forDay(kind, day), id);
          // Day-bound ids never reach the one-off range.
          expect(id, lessThan(RamadanNotificationIds.startingSoon));
        }
      }
      expect(RamadanNotificationIds.forDay(RamadanReminderKind.suhoor, 1), 210001);
      expect(seen, hasLength(RamadanReminderKind.values.length * 30));
    });

    test('one-off ids are inside the block and not day ids', () {
      for (final id in [RamadanNotificationIds.startingSoon, RamadanNotificationIds.eid]) {
        expect(RamadanNotificationIds.owns(id), isTrue);
        expect(seen(id), isFalse);
      }
    });

    test('a day outside 1..30 is rejected, not wrapped into another id', () {
      expect(() => RamadanNotificationIds.forDay(RamadanReminderKind.iftar, 0), throwsRangeError);
      expect(() => RamadanNotificationIds.forDay(RamadanReminderKind.iftar, 31), throwsRangeError);
    });
  });
}

bool seen(int id) => [
  for (final k in RamadanReminderKind.values)
    for (var d = 1; d <= 30; d++) RamadanNotificationIds.forDay(k, d),
].contains(id);
