import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/money.dart';

void main() {
  group('Rational', () {
    test('normalises sign and reduces', () {
      final r = Rational(BigInt.from(-6), BigInt.from(-8));
      expect(r.numerator, BigInt.from(3));
      expect(r.denominator, BigInt.from(4));
      expect(Rational.fromInt(2, -4).toString(), '-1/2');
    });

    test('fromNum uses the printed decimal of a double', () {
      expect(Rational.fromNum(4.345), Rational.fromInt(869, 200));
      expect(Rational.fromNum(0.709), Rational.fromInt(709, 1000));
      expect(Rational.fromNum(0.1) + Rational.fromNum(0.2), Rational.fromNum(0.3));
      expect(() => Rational.fromNum(double.nan), throwsArgumentError);
    });

    test('tryParse accepts Arabic-Indic digits and exponents', () {
      expect(Rational.tryParse('٤٫٣٤٥'), Rational.fromInt(869, 200));
      expect(Rational.tryParse('1e-3'), Rational.fromInt(1, 1000));
      expect(Rational.tryParse('-.5'), Rational.fromInt(-1, 2));
      expect(Rational.tryParse('abc'), isNull);
      expect(Rational.tryParse(''), isNull);
    });

    test('roundHalfUp: ties away from zero', () {
      expect(Rational.fromInt(5, 2).roundHalfUp(), 3);
      expect(Rational.fromInt(-5, 2).roundHalfUp(), -3);
      expect(Rational.fromInt(7, 3).roundHalfUp(), 2);
      expect(Rational.fromInt(-7, 3).roundHalfUp(), -2);
      expect(Rational.fromInt(217249, 10000).roundHalfUp(), 22);
    });
  });

  group('MoneyText.canonicalDecimal', () {
    final cases = <String, String?>{
      '1,234.5': '1234.5',
      '1٬234٫5': '1234.5',
      '١٬٢٣٤٫٥': '1234.5',
      '۱۲۳': '123',
      '12,5': '12.5',
      '1.234.567': '1234567',
      '1.234,5': '1234.5',
      '(12.50)': '-12.50',
      '-7': '-7',
      '−7': '-7',
      'JOD 12.5': '12.5',
      '١٢٫٥ د.أ': '12.5',
      r'$ 1,000': '1000',
      '.5': '0.5',
      '5.': '5',
      '1 234,5': '1234.5',
      'abc': null,
      '12 and 13': null,
      '1,23,4': null,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () => expect(MoneyText.canonicalDecimal(input), expected));
    });

    test('parseMilli is exact and half-up', () {
      expect(MoneyText.parseMilli('0.0005'), 1);
      expect(MoneyText.parseMilli('-0.0005'), -1);
      expect(MoneyText.parseMilli('0.0004'), 0);
      expect(MoneyText.parseMilli('1٬234٫5'), 1234500);
    });

    test('foldDigits / toArabicIndic round-trip', () {
      expect(MoneyText.foldDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(MoneyText.toArabicIndic('2026'), '٢٠٢٦');
    });
  });

  group('Money parsing', () {
    test('numbers are units', () {
      expect(Money.tryParse(12.5, currency: 'JOD'), const Money(12500, 'JOD'));
      expect(Money.tryParse(200), const Money(200000, 'JOD'));
      expect(Money.tryParse(0.1 + 0.2, currency: 'USD'), const Money(300, 'USD'));
      expect(Money.tryParse(double.infinity), isNull);
    });

    test('strings with separators and scripts', () {
      expect(Money.parse('1,234.5', currency: 'USD'), const Money(1234500, 'USD'));
      expect(Money.parse('1٬234٫5'), const Money(1234500, 'JOD'));
      expect(Money.parse('١٢٫٥'), const Money(12500, 'JOD'));
    });

    test('currency written in the text wins', () {
      expect(Money.parse('200 JOD', currency: 'USD'), const Money(200000, 'JOD'));
      expect(Money.parse(r'$12.50'), const Money(12500, 'USD'));
      expect(Money.parse('١٢٫٥ د.أ', currency: 'USD'), const Money(12500, 'JOD'));
      expect(Money.parse('5 دنانير', currency: 'USD'), const Money(5000, 'JOD'));
      expect(Money.parse('150 جنيه'), const Money(150000, 'EGP'));
      expect(Money.parse('EGP 99.99'), const Money(99990, 'EGP'));
      expect(Money.parse('30 LYD'), const Money(30000, 'LYD'));
    });

    test('percentages and garbage are rejected', () {
      expect(Money.tryParse('10%'), isNull);
      expect(Money.tryParse('١٠٪'), isNull);
      expect(Money.tryParse('lots'), isNull);
      expect(Money.tryParse(null), isNull);
      expect(Money.tryParse(true), isNull);
      expect(() => Money.parse('x'), throwsFormatException);
    });
  });

  group('Money arithmetic', () {
    test('exact integer addition and subtraction', () {
      const a = Money(100, 'JOD');
      const b = Money(200, 'JOD');
      expect(a + b, const Money(300, 'JOD'));
      expect(a - b, const Money(-100, 'JOD'));
      expect(-a, const Money(-100, 'JOD'));
      expect(Money.sum([a, b, a], 'JOD'), const Money(400, 'JOD'));
      expect(a < b, isTrue);
    });

    test('mixing currencies throws', () {
      expect(() => const Money(1, 'JOD') + const Money(1, 'USD'), throwsArgumentError);
    });

    test('percent and multiply round half-up to the milli', () {
      expect(const Money(200000, 'JOD').percent(50), const Money(100000, 'JOD'));
      expect(const Money(1, 'JOD').percent(50), const Money(1, 'JOD')); // 0.5 → 1
      expect(const Money(-1, 'JOD').percent(50), const Money(-1, 'JOD'));
      expect(const Money(5000, 'JOD').multiply(4.345), const Money(21725, 'JOD'));
      expect(const Money(10000, 'JOD').multiplyRatio(Rational.fromInt(1, 3)), const Money(3333, 'JOD'));
    });

    test('conversion with manual rates, exact then half-up', () {
      // 100 USD × 0.709 = 70.900 JOD.
      expect(const Money(100000, 'USD').toBase(0.709, 'JOD'), const Money(70900, 'JOD'));
      // 1 JOD → USD at 0.709: 1 / 0.709 = 1.41043723… → 1.410 USD.
      expect(
        const Money(1000, 'JOD').convert('USD', fromRateToBase: 1, toRateToBase: 0.709),
        const Money(1410, 'USD'),
      );
      // 0.0064 JOD per SYP: 12 345.678 SYP → 79.012 JOD (79.0123392 → 79.012).
      expect(const Money(12345678, 'SYP').toBase(0.0064, 'JOD'), const Money(79012, 'JOD'));
      // Tie: 0.0015 JOD → 0.002.
      expect(const Money(3, 'USD').toBase(0.5, 'JOD'), const Money(2, 'JOD'));
      expect(const Money(5, 'JOD').convert('jod', fromRateToBase: 9, toRateToBase: 1), const Money(5, 'JOD'));
      expect(() => const Money(5, 'USD').toBase(0, 'JOD'), throwsArgumentError);
    });

    test('roundToMinor follows the currency decimals', () {
      expect(const Money(12345, 'USD').roundToMinor(), const Money(12350, 'USD'));
      expect(const Money(12344, 'USD').roundToMinor(), const Money(12340, 'USD'));
      expect(const Money(12345, 'JOD').roundToMinor(), const Money(12345, 'JOD'));
      expect(const Money(12500, 'JPY').roundToMinor(), const Money(13000, 'JPY'));
    });
  });

  group('CurrencyCatalog', () {
    test('decimals: JOD/LYD 3, USD/EGP/SYP 2, overrides win', () {
      expect(CurrencyCatalog.decimalsFor('JOD'), 3);
      expect(CurrencyCatalog.decimalsFor('lyd'), 3);
      expect(CurrencyCatalog.decimalsFor('USD'), 2);
      expect(CurrencyCatalog.decimalsFor('EGP'), 2);
      expect(CurrencyCatalog.decimalsFor('SYP'), 2);
      expect(CurrencyCatalog.decimalsFor('SYP', overrides: {'SYP': 0}), 0);
    });

    test('normalize and detect', () {
      expect(CurrencyCatalog.normalize('usd'), 'USD');
      expect(CurrencyCatalog.normalize('دينار'), 'JOD');
      expect(CurrencyCatalog.normalize(r'$'), 'USD');
      expect(CurrencyCatalog.normalize('ليرة'), 'SYP');
      expect(CurrencyCatalog.normalize(''), isNull);
      expect(CurrencyCatalog.detect('no currency here 12'), isNull);
    });
  });

  group('Money formatting', () {
    test('English: grouping, per-currency decimals, symbol placement', () {
      const nb = '\u00A0'; // amount and symbol never wrap apart
      expect(const Money(1234500, 'JOD').format(), '1,234.500${nb}JOD');
      expect(const Money(1234500, 'USD').format(), r'$1,234.50');
      expect(const Money(-1234500, 'USD').format(), r'-$1,234.50');
      expect(const Money(99990, 'EGP').format(), '99.99${nb}EGP');
      expect(const Money(20000, 'JOD').format(withSymbol: false), '20.000');
      expect(const Money(20000, 'SYP').format(decimals: 0), '20${nb}SYP');
    });

    test('Arabic: Arabic-Indic digits and Arabic symbol after the amount', () {
      final s = const Money(1234500, 'JOD').format(locale: 'ar');
      expect(MoneyText.foldDigits(s), contains('1,234.500'));
      expect(s, contains('١'));
      expect(s, endsWith('د.أ'));
      final western = const Money(1234500, 'JOD').format(locale: 'ar', digits: MoneyDigits.western);
      expect(western, contains('1,234.500'));
      expect(western, endsWith('د.أ'));
    });

    test('English with Arabic-Indic digits', () {
      final s = const Money(5000, 'USD').formatAmount(digits: MoneyDigits.arabicIndic);
      expect(s, '٥.٠٠');
    });

    test('toString and json round-trip', () {
      expect(const Money(-1500, 'JOD').toString(), '-1.500 JOD');
      expect(Money.fromJson(const Money(42, 'USD').toJson()), const Money(42, 'USD'));
      expect(Money.fromJson('x'), isNull);
    });
  });
}
