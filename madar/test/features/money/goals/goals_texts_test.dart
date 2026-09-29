import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/goals/goals.dart';

final _rates = GoalsRates(
  base: 'JOD',
  currencies: const [
    GoalsCurrency(code: 'JOD', decimals: 3, isBase: true, symbol: 'د.أ'),
    GoalsCurrency(code: 'USD', rateToBase: 0.709, decimals: 2),
    GoalsCurrency(code: 'QQQ', rateToBase: 2, decimals: 2, symbol: '¤'),
  ],
);

GoalsTexts texts(String lang, {DigitStyle digits = DigitStyle.auto}) =>
    GoalsTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits), _rates);

/// Without the bidi isolate / mark characters, for readable expectations.
String plain(String s) => BidiIsolate.strip(s).replaceAll('؜', '').replaceAll(' ', ' ');

void main() {
  setUpAll(() => initializeDateFormatting());

  group('money', () {
    test('whole amounts drop their decimals; fractions keep at least two', () {
      final ar = texts('ar');
      expect(plain(ar.money(500000, 'JOD')), '٥٠٠ د.أ');
      expect(plain(ar.money(1200000, 'JOD')), '١٬٢٠٠ د.أ');
      expect(plain(ar.money(87500, 'JOD')), '٨٧٫٥٠ د.أ');
      expect(plain(ar.money(282475, 'JOD')), '٢٨٢٫٤٧٥ د.أ');
      expect(plain(ar.money(12500, 'USD')), '١٢٫٥٠ \$');
      final en = texts('en');
      expect(plain(en.money(500000, 'JOD')), '500 JOD');
      expect(plain(en.money(87500, 'JOD')), '87.50 JOD');
      expect(plain(en.money(282475, 'JOD')), '282.475 JOD');
      expect(plain(en.money(350000, 'USD')), '\$350');
      expect(plain(en.money(4990, 'USD')), '\$4.99');
    });

    test('decimalsFor never hides a significant digit', () {
      final t = texts('en');
      expect(t.decimalsFor(1000, 'JOD'), 0);
      expect(t.decimalsFor(1500, 'JOD'), 2);
      expect(t.decimalsFor(1550, 'JOD'), 2);
      expect(t.decimalsFor(1555, 'JOD'), 3);
      expect(t.decimalsFor(1001, 'JOD'), 3);
      expect(t.decimalsFor(1010, 'USD'), 2);
      expect(t.decimalsFor(-2500, 'JOD'), 2);
    });

    test('isolated in the UI direction; negatives and signed amounts', () {
      final ar = texts('ar');
      final s = ar.money(-50000, 'JOD');
      expect(s.startsWith(BidiIsolate.rli), isTrue);
      expect(s.endsWith(BidiIsolate.pdi), isTrue);
      expect(plain(s), '-٥٠ د.أ');
      expect(plain(ar.money(50000, 'JOD', signed: true)), '+٥٠ د.أ');
      final en = texts('en');
      expect(en.money(1000, 'JOD').startsWith(BidiIsolate.lri), isTrue);
      expect(plain(en.money(-12500, 'USD')), '-\$12.50');
      expect(plain(en.money(12500, 'USD', signed: true)), '+\$12.50');
    });

    test('Western digits in Arabic and the user\'s own symbol', () {
      expect(plain(texts('ar', digits: DigitStyle.western).money(1234500, 'JOD')), '1,234.50 د.أ');
      expect(plain(texts('en').money(3000, 'QQQ')), '3 ¤');
      expect(texts('ar').symbol('QQQ'), '¤');
      expect(texts('ar').symbol('JOD'), 'د.أ');
    });
  });

  group('phrases', () {
    final today = DateTime(2026, 9, 29);
    test('due dates relative to today', () {
      final ar = texts('ar');
      expect(ar.dueRelative(today, today), 'اليوم');
      expect(ar.dueRelative(DateTime(2026, 9, 30), today), 'غدًا');
      expect(ar.dueRelative(DateTime(2026, 10, 2), today), 'بعد ٣ أيام');
      expect(ar.dueRelative(DateTime(2026, 9, 27), today), 'متأخر يومين');
      expect(ar.dueRelative(DateTime(2026, 9, 28), today), 'متأخر يومًا');
      final en = texts('en');
      expect(en.dueRelative(DateTime(2026, 10, 9), today), 'In 10 days');
      expect(en.dueRelative(DateTime(2026, 9, 18), today), '11 days overdue');
      expect(en.dueRelative(DateTime(2026, 12, 1), today), 'On December 1');
    });

    test('recurrences', () {
      final ar = texts('ar');
      expect(ar.recurrence(Recurrence.monthly, 1), 'كل شهر');
      expect(ar.recurrence(Recurrence.weekly, 2), 'كل أسبوعين');
      expect(ar.recurrence(Recurrence.monthly, 3), 'كل ٣ أشهر');
      expect(ar.recurrence(Recurrence.yearly, 0), 'كل سنة');
      final en = texts('en');
      expect(en.recurrence(Recurrence.weekly, 1), 'Every week');
      expect(en.recurrence(Recurrence.monthly, 2), 'Every 2 months');
    });

    test('days left and nothing due', () {
      expect(texts('ar').daysLeft(12), 'باقٍ ١٢ يومًا');
      expect(texts('en').daysLeft(1), '1 day left');
      expect(texts('ar').nothingDue(14), 'لا شيء مستحق خلال ١٤ يومًا');
      expect(texts('en').nothingDue(14), 'Nothing due in the next 14 days');
    });
  });
}
