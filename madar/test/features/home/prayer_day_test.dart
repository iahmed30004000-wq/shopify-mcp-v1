import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/home/domain/prayer_day.dart';

void main() {
  const times = PrayerDayTimes.placeholder;
  DateTime at(int h, int m, {int day = 27}) => DateTime(2026, 9, day, h, m);

  group('PrayerDayTimes', () {
    test('placeholder is flagged so the UI can say "approximate"', () {
      expect(times.isPlaceholder, isTrue);
      expect(PrayerDayTimes.windows, hasLength(6));
      expect(PrayerDayTimes.windows, isNot(contains(PrayerWindow.anytime)));
    });

    test('windowAt covers the whole day', () {
      expect(times.windowAt(at(3, 0)), PrayerWindow.isha);
      expect(times.windowAt(at(4, 45)), PrayerWindow.fajr);
      expect(times.windowAt(at(6, 9)), PrayerWindow.fajr);
      expect(times.windowAt(at(6, 10)), PrayerWindow.duha);
      expect(times.windowAt(at(13, 10)), PrayerWindow.dhuhr);
      expect(times.windowAt(at(16, 0)), PrayerWindow.asr);
      expect(times.windowAt(at(18, 45)), PrayerWindow.maghrib);
      expect(times.windowAt(at(21, 0)), PrayerWindow.isha);
      expect(times.windowAt(at(23, 59)), PrayerWindow.isha);
    });

    test('an Isha after midnight keeps the Maghrib window running until it begins', () {
      const late = PrayerDayTimes(
        fajr: Duration(hours: 3),
        sunrise: Duration(hours: 4, minutes: 40),
        dhuhr: Duration(hours: 13, minutes: 20),
        asr: Duration(hours: 17, minutes: 30),
        maghrib: Duration(hours: 21, minutes: 50),
        isha: Duration(hours: 24, minutes: 30),
      );
      expect(late.windowAt(at(23, 0)), PrayerWindow.maghrib);
      expect(late.windowAt(at(0, 15)), PrayerWindow.maghrib);
      expect(late.windowAt(at(0, 45)), PrayerWindow.isha);
      expect(late.windowAt(at(3, 5)), PrayerWindow.fajr);
      expect(times.windowAt(at(0, 15)), PrayerWindow.isha, reason: 'an ordinary evening is unchanged');
    });

    test('each window ends where the next begins; after Isha ends at the next Fajr', () {
      for (var i = 0; i + 1 < PrayerDayTimes.windows.length; i++) {
        expect(times.endOf(PrayerDayTimes.windows[i]), times.startOf(PrayerDayTimes.windows[i + 1]));
      }
      expect(times.endOf(PrayerWindow.isha), times.fajr + const Duration(days: 1));
      final day = DateTime(2026, 9, 27);
      expect(times.endOn(PrayerWindow.isha, day), DateTime(2026, 9, 28, 4, 45));
      expect(times.startOn(PrayerWindow.asr, day), DateTime(2026, 9, 27, 15, 50));
    });

    test('the small hours belong to the previous prayer day', () {
      expect(times.prayerDayOf(at(2, 0)), DateTime(2026, 9, 26));
      expect(times.prayerDayOf(at(5, 0)), DateTime(2026, 9, 27));
      expect(times.prayerDayOf(at(23, 0)), DateTime(2026, 9, 27));
    });

    test('nextPrayer skips sunrise and rolls over midnight', () {
      expect(times.nextPrayer(at(13, 10)), (prayer: Prayer.asr, at: at(15, 50)));
      expect(times.nextPrayer(at(5, 0)), (prayer: Prayer.dhuhr, at: at(12, 25)));
      expect(times.nextPrayer(at(15, 50)), (prayer: Prayer.maghrib, at: at(18, 30)));
      expect(times.nextPrayer(at(22, 0)), (prayer: Prayer.fajr, at: at(4, 45, day: 28)));
    });

    test('progressAt runs 0 → 1 through a window, across midnight too', () {
      expect(times.progressAt(at(12, 25)), 0);
      expect(times.progressAt(at(15, 49)), closeTo(1, 0.01));
      final midIsha = times.progressAt(at(0, 17));
      expect(midIsha, greaterThan(0.4));
      expect(midIsha, lessThan(0.6));
    });
  });
}
