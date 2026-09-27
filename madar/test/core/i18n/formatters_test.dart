import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:flutter/widgets.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  group('Digits', () {
    test('Western → Arabic-Indic, separators only between digits', () {
      expect(Digits.toArabicIndic('12,345.67'), '١٢٬٣٤٥٫٦٧');
      expect(Digits.toArabicIndic('42%'), '٤٢٪');
      expect(Digits.toArabicIndic('Done. 3, then 4.'), 'Done. ٣, then ٤.');
      expect(Digits.toArabicIndic(''), '');
    });

    test('Arabic-Indic and Persian → Western', () {
      expect(Digits.toWestern('١٢٬٣٤٥٫٦٧'), '12,345.67');
      expect(Digits.toWestern('۱۲۳'), '123');
      expect(Digits.toWestern('٤٢٪'), '42%');
      expect(Digits.toWestern('abc'), 'abc');
    });

    test('round trip', () {
      const s = 'Pay 1,250.5 JOD on 27/9';
      expect(Digits.toWestern(Digits.toArabicIndic(s)), s);
      expect(Digits.hasEasternDigits(Digits.toArabicIndic('7')), isTrue);
      expect(Digits.hasEasternDigits('7'), isFalse);
    });
  });

  group('BidiIsolate', () {
    test('wraps runs in isolates and strips them again', () {
      expect(BidiIsolate.isolate('John'), '\u2068John\u2069');
      expect(BidiIsolate.ltr('JOD'), '\u2066JOD\u2069');
      expect(BidiIsolate.rtl('مدار'), '\u2067مدار\u2069');
      expect(BidiIsolate.isolate(''), '');
      expect(BidiIsolate.strip('اتصل بـ ${BidiIsolate.isolate('John')}'), 'اتصل بـ John');
    });
  });

  group('MadarFormatter digits', () {
    const arAuto = MadarFormatter(languageCode: 'ar');
    const enAuto = MadarFormatter(languageCode: 'en');
    const arWestern = MadarFormatter(languageCode: 'ar', digits: DigitStyle.western);
    const enIndic = MadarFormatter(languageCode: 'en', digits: DigitStyle.arabicIndic);

    test('auto = Arabic-Indic in Arabic, Western in English', () {
      expect(arAuto.arabicIndic, isTrue);
      expect(enAuto.arabicIndic, isFalse);
      expect(arWestern.arabicIndic, isFalse);
      expect(enIndic.arabicIndic, isTrue);
    });

    test('formatInt groups thousands', () {
      expect(enAuto.formatInt(1234567), '1,234,567');
      expect(arAuto.formatInt(1234567), '١٬٢٣٤٬٥٦٧');
      expect(arAuto.formatInt(1234, grouping: false), '١٢٣٤');
      expect(enAuto.formatInt(-1200), '-1,200');
    });

    test('formatNumber trims or fixes decimals', () {
      expect(enAuto.formatNumber(12345.678), '12,345.68');
      expect(enAuto.formatNumber(3.5), '3.5');
      expect(enAuto.formatNumber(3), '3');
      expect(enAuto.formatNumber(3, decimals: 3), '3.000');
      expect(arAuto.formatNumber(12345.67), '١٢٬٣٤٥٫٦٧');
    });

    test('formatPercent', () {
      expect(enAuto.formatPercent(0.42), '42%');
      expect(arAuto.formatPercent(0.42), '٤٢٪');
      expect(arWestern.formatPercent(0.425, decimals: 1), '42.5%');
    });

    test('localizeDigits converts both ways', () {
      expect(arAuto.localizeDigits('3 tasks'), '٣ tasks');
      expect(arWestern.localizeDigits('٣ مهام'), '3 مهام');
    });
  });

  group('MadarFormatter dates and times', () {
    final d = DateTime(2026, 9, 27, 15, 45);

    test('dates use localised names and the digit style', () {
      expect(const MadarFormatter(languageCode: 'en').formatDate(d), 'September 27, 2026');
      final ar = const MadarFormatter(languageCode: 'ar').formatDate(d);
      expect(ar, contains('٢٧'));
      expect(ar, contains('٢٠٢٦'));
      expect(Digits.hasEasternDigits(ar), isTrue);
      final arWestern = const MadarFormatter(languageCode: 'ar', digits: DigitStyle.western).formatDate(d);
      expect(arWestern, contains('27'));
      expect(Digits.hasEasternDigits(arWestern), isFalse);
    });

    test('every date style formats', () {
      for (final style in MadarDateStyle.values) {
        expect(const MadarFormatter(languageCode: 'en').formatDate(d, style: style), isNotEmpty);
        expect(const MadarFormatter(languageCode: 'ar').formatDate(d, style: style), isNotEmpty);
      }
    });

    test('times', () {
      // intl separates the day period with a narrow no-break space.
      expect(const MadarFormatter(languageCode: 'en').formatTime(d).replaceAll('\u202F', ' '), '3:45 PM');
      final ar = const MadarFormatter(languageCode: 'ar').formatClock(15, 45);
      expect(ar, contains('٣:٤٥'));
      expect(const MadarFormatter(languageCode: 'ar', digits: DigitStyle.western).formatClock(9, 5), contains('9:05'));
    });

    test('stopwatch durations', () {
      const en = MadarFormatter(languageCode: 'en');
      expect(en.formatDuration(const Duration(hours: 1, minutes: 5)), '1:05');
      expect(en.formatDuration(const Duration(minutes: 5, seconds: 3), seconds: true), '5:03');
      expect(en.formatDuration(const Duration(minutes: -90)), '1:30');
      expect(const MadarFormatter(languageCode: 'ar').formatDuration(const Duration(hours: 2, minutes: 7)), '٢:٠٧');
    });

    test('durations in words round up to whole minutes', () {
      final en = lookupL10n(const Locale('en'));
      final ar = lookupL10n(const Locale('ar'));
      const fEn = MadarFormatter(languageCode: 'en');
      const fAr = MadarFormatter(languageCode: 'ar');
      expect(fEn.formatDurationWords(en, const Duration(hours: 1, minutes: 23)), '1h 23m');
      expect(fEn.formatDurationWords(en, const Duration(minutes: 40)), '40 min');
      expect(fEn.formatDurationWords(en, const Duration(minutes: 39, seconds: 1)), '40 min');
      expect(fEn.formatDurationWords(en, const Duration(hours: 2)), '2h');
      expect(fEn.formatDurationWords(en, Duration.zero), en.shellDurationLessThanMinute);
      expect(fAr.formatDurationWords(ar, const Duration(hours: 1, minutes: 23)), '١ س ٢٣ د');
    });
  });

  testWidgets('MadarFormatter.of reads locale and MadarFormatScope', (tester) async {
    late MadarFormatter f;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: L10n.localizationsDelegates,
        child: MadarFormatScope(
          digits: DigitStyle.western,
          child: Builder(
            builder: (context) {
              f = context.formatter;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(f, const MadarFormatter(languageCode: 'ar', digits: DigitStyle.western));
  });
}
