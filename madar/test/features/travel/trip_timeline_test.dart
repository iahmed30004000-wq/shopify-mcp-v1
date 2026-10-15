import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/travel/domain/trip_timeline.dart';

void main() {
  setUpAll(MadarTimeZones.ensure);

  DateTime d(int m, int day, [int y = 2026]) => DateTime(y, m, day);
  TravelToday on(DateTime day) => TravelToday.same(day);

  group('TravelDates', () {
    test('counts calendar days, not 24-hour blocks', () {
      expect(TravelDates.daysBetween(d(10, 1), d(10, 10)), 9);
      expect(TravelDates.daysBetween(d(10, 10), d(10, 1)), -9);
      // Across the end of European summer time (25 Oct 2026) and the turn
      // of the year.
      expect(TravelDates.daysBetween(d(10, 24), d(10, 26)), 2);
      expect(TravelDates.daysBetween(DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1, 0, 1)), 1);
      expect(TravelDates.addDays(d(2, 28), 1), d(3, 1));
    });
  });

  group('status derivation', () {
    const trip = TripTimeline(start: null, end: null);
    test('an undated trip is planned (and listed as undated)', () {
      expect(trip.derive(on(d(9, 29))), TripStatus.planned);
      expect(trip.phaseOf(TripStatus.planned), TripPhase.undated);
      expect(trip.countdown(TripStatus.planned, on(d(9, 29))).kind, CountdownKind.undated);
    });

    final oct = TripTimeline(start: d(10, 8), end: d(10, 14));
    test('before, on, during, on the last day and after', () {
      expect(oct.derive(on(d(10, 7))), TripStatus.planned);
      expect(oct.derive(on(d(10, 8))), TripStatus.active);
      expect(oct.derive(on(d(10, 11))), TripStatus.active);
      expect(oct.derive(on(d(10, 14))), TripStatus.active);
      expect(oct.derive(on(d(10, 15))), TripStatus.done);
      expect(oct.phaseOf(TripStatus.planned), TripPhase.upcoming);
      expect(oct.phaseOf(TripStatus.active), TripPhase.current);
      expect(oct.phaseOf(TripStatus.done), TripPhase.past);
    });

    test('an open-ended trip stays under way until finished by hand', () {
      final open = TripTimeline(start: d(10, 8));
      expect(open.derive(on(d(10, 7))), TripStatus.planned);
      expect(open.derive(on(d(12, 30))), TripStatus.active);
      expect(open.lengthDays, isNull);
      expect(open.countdown(TripStatus.active, on(d(10, 10))), const TripCountdown(CountdownKind.underway, dayIndex: 3));
    });

    test('a return before the departure reads as a one-day trip', () {
      final odd = TripTimeline(start: d(10, 8), end: d(10, 2));
      expect(odd.lengthDays, 1);
      expect(odd.derive(on(d(10, 8))), TripStatus.active);
      expect(odd.derive(on(d(10, 9))), TripStatus.done);
    });

    test('a manual status wins over the dates', () {
      expect(oct.effective(stored: TripStatus.done, manual: true, today: on(d(10, 1))), TripStatus.done);
      expect(oct.effective(stored: TripStatus.done, manual: false, today: on(d(10, 1))), TripStatus.planned);
    });
  });

  group('countdowns', () {
    final oct = TripTimeline(start: d(10, 8), end: d(10, 14));
    test('days to departure', () {
      expect(oct.countdown(TripStatus.planned, on(d(9, 29))), const TripCountdown(CountdownKind.startsIn, days: 9));
      expect(oct.countdown(TripStatus.planned, on(d(10, 7))).days, 1);
      expect(oct.countdown(TripStatus.planned, on(d(10, 8))).days, 0);
      // Held back by hand past its date: never a negative countdown.
      expect(oct.countdown(TripStatus.planned, on(d(10, 10))).days, 0);
    });

    test('day n of the trip, and days since it ended', () {
      expect(
        oct.countdown(TripStatus.active, on(d(10, 10))),
        const TripCountdown(CountdownKind.underway, dayIndex: 3, length: 7),
      );
      expect(oct.countdown(TripStatus.done, on(d(10, 19))), const TripCountdown(CountdownKind.ended, days: 5));
      // Finished by hand before its last day.
      expect(oct.countdown(TripStatus.done, on(d(10, 12))).kind, CountdownKind.finished);
    });

    test('lists every day of the trip', () {
      expect(oct.days(fallback: d(9, 29)), [for (var i = 8; i <= 14; i++) d(10, i)]);
      expect(const TripTimeline().days(fallback: DateTime(2026, 9, 29, 15)), [d(9, 29)]);
    });
  });

  group('across time zones', () {
    // 10 Oct 2026 23:30 in Amman (UTC+3) = 20:30 UTC = 16:30 in New York.
    final now = DateTime.utc(2026, 10, 10, 20, 30);
    final amman = MadarTimeZones.find('Asia/Amman')!;
    final newYork = MadarTimeZones.find('America/New_York')!;
    final tokyo = MadarTimeZones.find('Asia/Tokyo')!;

    test('home and destination calendars can differ', () {
      final homeAmman = TravelToday(home: MadarTimeZones.dateIn(now, amman), destination: MadarTimeZones.dateIn(now, newYork));
      expect(homeAmman.home, d(10, 10));
      expect(homeAmman.destination, d(10, 10));
      // Half an hour later it is the 11th in Amman, still the 10th in New York.
      final later = now.add(const Duration(minutes: 45));
      expect(MadarTimeZones.dateIn(later, amman), d(10, 11));
      expect(MadarTimeZones.dateIn(later, newYork), d(10, 10));
      // Tokyo (UTC+9) is already on the 11th.
      expect(MadarTimeZones.dateIn(now, tokyo), d(10, 11));
    });

    test('a trip is still under way while its last day lasts at the destination', () {
      final trip = TripTimeline(start: d(10, 5), end: d(10, 10));
      final later = now.add(const Duration(minutes: 45)); // 11th in Amman, 10th in NY
      final today = TravelToday(home: MadarTimeZones.dateIn(later, amman), destination: MadarTimeZones.dateIn(later, newYork));
      expect(trip.derive(today), TripStatus.active);
      expect(trip.dayIndexOn(today), 6);
      final nextDay = later.add(const Duration(hours: 8)); // 11th in both
      final after = TravelToday(
        home: MadarTimeZones.dateIn(nextDay, amman),
        destination: MadarTimeZones.dateIn(nextDay, newYork),
      );
      expect(trip.derive(after), TripStatus.done);
    });

    test('departure counts on the home calendar; the day index on the destination\'s', () {
      final trip = TripTimeline(start: d(10, 11), end: d(10, 13));
      final later = now.add(const Duration(minutes: 45)); // 11th in Amman, 10th in NY
      final today = TravelToday(home: MadarTimeZones.dateIn(later, amman), destination: MadarTimeZones.dateIn(later, newYork));
      expect(trip.derive(today), TripStatus.active);
      // Left home on the 11th; it is still the 10th over there: day 1.
      expect(trip.dayIndexOn(today), 1);
      expect(trip.countdown(TripStatus.active, today), const TripCountdown(CountdownKind.underway, dayIndex: 1, length: 3));
      final before = TravelToday(home: MadarTimeZones.dateIn(now, amman), destination: MadarTimeZones.dateIn(now, tokyo));
      expect(trip.countdown(TripStatus.planned, before).days, 1);
    });

    test('TravelToday.at reads the destination zone', () {
      final t = TravelToday.at(now, zone: tokyo);
      expect(t.destination, d(10, 11));
    });
  });
}
