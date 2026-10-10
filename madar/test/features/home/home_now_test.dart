import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/home/domain/prayer_day.dart';
import 'package:madar/features/home/home_providers.dart';

void main() {
  // Real times keep their seconds (Asr at 15:51:14).
  const times = PrayerDayTimes(
    fajr: Duration(hours: 5, minutes: 6, seconds: 40),
    sunrise: Duration(hours: 6, minutes: 27, seconds: 3),
    dhuhr: Duration(hours: 12, minutes: 27, seconds: 30),
    asr: Duration(hours: 15, minutes: 51, seconds: 14),
    maghrib: Duration(hours: 18, minutes: 31, seconds: 50),
    isha: Duration(hours: 19, minutes: 47, seconds: 5),
  );

  test('ticks at the next minute boundary inside a window', () {
    final now = DateTime(2026, 9, 27, 14, 10, 20, 500);
    expect(HomeNow.nextTick(now, times), const Duration(seconds: 39, milliseconds: 500));
    expect(HomeNow.nextTick(now, null), const Duration(seconds: 39, milliseconds: 500));
  });

  test('ticks at the window start when it comes before the next minute – chips switch with the dial', () {
    final now = DateTime(2026, 9, 27, 15, 51, 2);
    final wait = HomeNow.nextTick(now, times);
    expect(wait, const Duration(seconds: 12));
    final at = now.add(wait);
    expect(times.windowAt(now), PrayerWindow.dhuhr);
    expect(times.windowAt(at), PrayerWindow.asr, reason: 'the chip switches on the very tick');
  });

  test("after Isha the next start is tomorrow's Fajr (or the next minute first)", () {
    final now = DateTime(2026, 9, 27, 23, 59, 59);
    expect(HomeNow.nextTick(now, times), const Duration(seconds: 1));
    final lateNight = DateTime(2026, 9, 28, 5, 6, 30);
    expect(HomeNow.nextTick(lateNight, times), const Duration(seconds: 10));
  });
}
