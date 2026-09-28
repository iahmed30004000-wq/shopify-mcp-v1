import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/application/prayer_providers.dart';
import 'package:madar/features/prayer/domain/hijri.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/prayer/presentation/prayer_labels.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(MadarTimeZones.ensure);
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  const fmtAr = MadarFormatter();
  const fmtEn = MadarFormatter(languageCode: 'en');

  group('Umm al-Qura conversion', () {
    test('published month starts of 1447–1448 AH', () {
      // Umm al-Qura calendar: 1 Ramadan 1447 = 18 Feb 2026, 1 Shawwal =
      // 20 Mar 2026, 1 Muharram 1448 = 16 Jun 2026.
      expect(
        HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18)),
        const HijriDate(year: 1447, month: 9, day: 1, monthLength: 29),
      );
      expect(HijriCalendarMath.fromGregorian(DateTime(2026, 3, 20)).month, 10);
      expect(HijriCalendarMath.fromGregorian(DateTime(2026, 3, 20)).day, 1);
      final muharram = HijriCalendarMath.fromGregorian(DateTime(2026, 6, 16));
      expect((muharram.year, muharram.month, muharram.day), (1448, 1, 1));
      expect(HijriCalendarMath.fromGregorian(DateTime(2026, 2, 17)).month, 8);
    });

    test('Ramadan flag and month length', () {
      final h = HijriCalendarMath.fromGregorian(DateTime(2026, 3, 1));
      expect(h.isRamadan, isTrue);
      expect(h.monthLength, inInclusiveRange(29, 30));
    });

    test('round trip Hijri → Gregorian', () {
      expect(HijriCalendarMath.toGregorian(1447, 9, 1), DateTime.utc(2026, 2, 18));
      final back = HijriCalendarMath.toGregorian(1448, 4, 16)!;
      final h = HijriCalendarMath.fromGregorian(back);
      expect((h.year, h.month, h.day), (1448, 4, 16));
    });

    test('outside the Umm al-Qura table the tabular calendar takes over', () {
      final h = HijriCalendarMath.fromGregorian(DateTime(1900, 1, 1));
      expect((h.year, h.month), (1317, 8));
      expect(h.day, inInclusiveRange(28, 30));
      final far = HijriCalendarMath.fromGregorian(DateTime(2100, 6, 1));
      expect((far.year, far.month), (1524, 3)); // 1 Muharram 1524 ≈ 12 Mar 2100
    });
  });

  group('user offset and Maghrib rollover', () {
    test('the day offset shifts the date (−2…+2, clamped)', () {
      final base = HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18));
      expect(base.day, 1);
      expect(HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18), offsetDays: 1).day, 2);
      expect(HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18), offsetDays: -1).month, 8);
      expect(
        HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18), offsetDays: 9),
        HijriCalendarMath.fromGregorian(DateTime(2026, 2, 18), offsetDays: 2),
      );
    });

    test('with rollover the Hijri day begins at Maghrib', () {
      final amman = tz.getLocation('Asia/Amman');
      final maghrib = tz.TZDateTime(amman, 2026, 2, 17, 17, 41);
      final before = tz.TZDateTime(amman, 2026, 2, 17, 17, 30);
      final after = tz.TZDateTime(amman, 2026, 2, 17, 18, 0);
      expect(HijriCalendarMath.at(before, rollAtMaghrib: true, maghrib: maghrib).month, 8);
      final eve = HijriCalendarMath.at(after, rollAtMaghrib: true, maghrib: maghrib);
      expect((eve.month, eve.day), (9, 1), reason: 'the first night of Ramadan begins at Maghrib');
      expect(HijriCalendarMath.at(after, maghrib: maghrib).month, 8, reason: 'rollover off by default');
    });

    test('hijriAt() reads the schedule\'s Maghrib in the location zone', () {
      const s = PrayerSettings(timeZone: 'Asia/Amman', hijriAtMaghrib: true);
      final schedule = PrayerSchedule(s);
      final maghrib = schedule.timesFor(DateTime(2026, 2, 17)).maghrib;
      expect(hijriAt(schedule, s, maghrib.subtract(const Duration(minutes: 1))).month, 8);
      expect(hijriAt(schedule, s, maghrib.add(const Duration(minutes: 1))).month, 9);
      final plain = PrayerSettings(timeZone: 'Asia/Amman', hijriOffsetDays: -1);
      expect(hijriAt(PrayerSchedule(plain), plain, maghrib.add(const Duration(minutes: 1))).month, 8);
    });
  });

  group('formatting', () {
    test('Arabic month names and Arabic-Indic digits', () {
      const h = HijriDate(year: 1448, month: 3, day: 12, monthLength: 30);
      expect(ar.hijriDate(h, fmtAr), '١٢ ربيع الأول ١٤٤٨ هـ');
      expect(ar.hijriDayMonth(h, fmtAr), '١٢ ربيع الأول');
      expect(en.hijriDate(h, fmtEn), '12 Rabi’ al-Awwal 1448 AH');
      const western = MadarFormatter(digits: DigitStyle.western);
      expect(ar.hijriDate(h, western), '12 ربيع الأول 1448 هـ');
    });

    test('all twelve months are named', () {
      final names = [for (var m = 1; m <= 12; m++) ar.hijriMonth(m)];
      expect(names, [
        'محرّم',
        'صفر',
        'ربيع الأول',
        'ربيع الآخر',
        'جمادى الأولى',
        'جمادى الآخرة',
        'رجب',
        'شعبان',
        'رمضان',
        'شوّال',
        'ذو القعدة',
        'ذو الحجة',
      ]);
      expect(names.toSet().length, 12);
      expect({for (var m = 1; m <= 12; m++) en.hijriMonth(m)}.length, 12);
    });
  });
}
