import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/features/travel/domain/documents.dart';
import 'package:madar/features/travel/domain/trip_timeline.dart';
import 'package:madar/features/travel/travel_texts.dart';

void main() {
  final ar = TravelTexts.forLanguage('ar');
  final en = TravelTexts.forLanguage('en');
  final now = DateTime(2026, 9, 30, 10);
  DateTime d(int m, int day, [int y = 2026]) => DateTime(y, m, day);

  // Bidi isolates and marks are invisible; compare what is read.
  String plain(String s) => s.replaceAll(RegExp('[⁦-⁩‎‏؜]'), '');

  group('date ranges', () {
    test('one month: the month once, in each language\'s order', () {
      expect(plain(ar.dateRange(d(10, 8), d(10, 14), now: now)), '٨ – ١٤ أكتوبر');
      expect(plain(en.dateRange(d(10, 8), d(10, 14), now: now)), 'October 8 – 14');
    });

    test('across months, and a single day', () {
      expect(plain(en.dateRange(d(9, 27), d(10, 2), now: now)), 'September 27 – October 2');
      expect(plain(ar.dateRange(d(9, 27), d(10, 2), now: now)), '٢٧ سبتمبر – ٢ أكتوبر');
      expect(plain(en.dateRange(d(10, 8), d(10, 8), now: now)), 'October 8');
    });

    test('another year shows the year', () {
      expect(plain(en.dateRange(d(1, 3, 2027), d(1, 9, 2027), now: now)), 'January 3 – 9, 2027');
      expect(plain(ar.dateRange(d(1, 3, 2027), d(1, 9, 2027), now: now)), '٣ – ٩ يناير ٢٠٢٧');
      expect(plain(en.dateRange(d(12, 28), d(1, 4, 2027), now: now)), 'December 28, 2026 – January 4, 2027');
    });

    test('no return date, no dates', () {
      expect(plain(en.dateRange(d(10, 8), null, now: now)), startsWith('October 8'));
      expect(en.dateRange(null, null, now: now), en.l.travelCountdownUndated);
    });

    test('Western digits when the user chose them', () {
      final western = TravelTexts.forLanguage('ar', digits: DigitStyle.western);
      expect(plain(western.dateRange(d(10, 8), d(10, 14), now: now)), '8 – 14 أكتوبر');
    });
  });

  group('countdowns', () {
    test('days to departure in Arabic plural forms', () {
      expect(ar.countdown(const TripCountdown(CountdownKind.startsIn, days: 9)), contains('٩'));
      expect(en.countdown(const TripCountdown(CountdownKind.startsIn, days: 9)), 'In 9 days');
      expect(en.countdown(const TripCountdown(CountdownKind.startsIn)), en.l.travelCountdownToday);
      expect(en.countdown(const TripCountdown(CountdownKind.startsIn, days: 1)), en.l.travelCountdownTomorrow);
    });

    test('day n of m, and ended', () {
      expect(en.countdown(const TripCountdown(CountdownKind.underway, dayIndex: 3, length: 6)), 'Day 3 of 6');
      expect(ar.countdown(const TripCountdown(CountdownKind.underway, dayIndex: 3, length: 6)), contains('٣'));
      expect(en.countdown(const TripCountdown(CountdownKind.ended, days: 54)), 'Ended 54 days ago');
    });
  });

  group('documents', () {
    test('expiry phrases scale from days to years', () {
      expect(en.expiry(const DocumentExpiry(ExpiryState.soon, 21)), 'Expires in 21 days');
      expect(en.expiry(const DocumentExpiry(ExpiryState.ok, 85)), 'Expires in 2 months');
      expect(en.expiry(const DocumentExpiry(ExpiryState.ok, 946)), 'Expires in 2 years');
      expect(en.expiry(const DocumentExpiry(ExpiryState.today, 0)), en.l.travelExpiresToday);
      expect(en.expiry(const DocumentExpiry(ExpiryState.none)), en.l.travelNoExpiry);
      expect(en.expiry(const DocumentExpiry(ExpiryState.expired, -3)), contains('3'));
    });

    test('only the end of a document number is shown', () {
      expect(plain(en.maskedNumber('N 1234-5678')), contains('••5678'));
      expect(plain(ar.maskedNumber('12345678')), contains('••٥٦٧٨'));
    });
  });
}
