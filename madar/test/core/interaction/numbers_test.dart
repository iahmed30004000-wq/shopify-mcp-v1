import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/numbers.dart';

void main() {
  group('normalizeDigits', () {
    test('Arabic-Indic digits', () => expect(LocalizedNumbers.normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789'));
    test(
      'Extended Arabic-Indic (Persian) digits',
      () => expect(LocalizedNumbers.normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789'),
    );
    test(
      'Arabic decimal and thousands separators',
      () => expect(LocalizedNumbers.normalizeDigits('١٬٢٥٠٫٥'), '1,250.5'),
    );
    test('unicode minus and en dash', () => expect(LocalizedNumbers.normalizeDigits('−٥ – ۳'), '-5 - 3'));
    test('keeps other characters and the length', () {
      const input = 'صرفت ١٢٫٥ دينار';
      final out = LocalizedNumbers.normalizeDigits(input);
      expect(out, 'صرفت 12.5 دينار');
      expect(out.length, input.length);
    });
    test('empty stays empty', () => expect(LocalizedNumbers.normalizeDigits(''), ''));
  });

  group('canonical / parse', () {
    test('Western integers and decimals', () {
      expect(LocalizedNumbers.parse('42'), 42);
      expect(LocalizedNumbers.parse('12.5'), 12.5);
      expect(LocalizedNumbers.parse('42'), isA<int>());
    });
    test('Arabic-Indic with ٫', () => expect(LocalizedNumbers.parse('٧٢٫٥'), 72.5));
    test('Persian digits', () => expect(LocalizedNumbers.parse('۱۲'), 12));
    test('mixed scripts in one number', () => expect(LocalizedNumbers.parse('1٢3'), 123));
    test('thousands commas', () {
      expect(LocalizedNumbers.parse('1,250'), 1250);
      expect(LocalizedNumbers.parse('12,500.75'), 12500.75);
      expect(LocalizedNumbers.parse('١٬٢٥٠'), 1250);
    });
    test('a single comma between digits is a decimal comma', () => expect(LocalizedNumbers.parse('12,5'), 12.5));
    test('malformed thousands are rejected', () {
      expect(LocalizedNumbers.parse('1,25,0'), isNull);
      expect(LocalizedNumbers.parse('12,50.5'), isNull);
    });
    test('negative numbers and a leading plus', () {
      expect(LocalizedNumbers.parse('-٥'), -5);
      expect(LocalizedNumbers.parse('−3.5'), -3.5);
      expect(LocalizedNumbers.parse('+7'), 7);
    });
    test('leading / trailing dot', () {
      expect(LocalizedNumbers.canonical('.5'), '0.5');
      expect(LocalizedNumbers.canonical('٥.'), '5');
      expect(LocalizedNumbers.canonical('-.5'), '-0.5');
    });
    test('whitespace and bidi marks are ignored', () {
      expect(LocalizedNumbers.parse(' ١ ٢ '), 12);
      expect(LocalizedNumbers.parse('‏١٥‎'), 15);
    });
    test('non-numbers', () {
      expect(LocalizedNumbers.parse(''), isNull);
      expect(LocalizedNumbers.parse('abc'), isNull);
      expect(LocalizedNumbers.parse('1.2.3'), isNull);
      expect(LocalizedNumbers.parse('--1'), isNull);
    });
  });

  group('decimalPlaces', () {
    test('counts digits after the separator in any script', () {
      expect(LocalizedNumbers.decimalPlaces('12'), 0);
      expect(LocalizedNumbers.decimalPlaces('12.50'), 2);
      expect(LocalizedNumbers.decimalPlaces('١٢٫٧٥٠'), 3);
      expect(LocalizedNumbers.decimalPlaces('x'), 0);
    });
  });

  group('milli-units', () {
    test('toMilli rounds to the nearest milli', () {
      expect(LocalizedNumbers.toMilli(12.5), 12500);
      expect(LocalizedNumbers.toMilli(0.1 + 0.2), 300);
      expect(LocalizedNumbers.toMilli(-1.0005), -1001);
    });
    test('formatMilli trims trailing zeros', () {
      expect(LocalizedNumbers.formatMilli(12500), '12.5');
      expect(LocalizedNumbers.formatMilli(3000), '3');
      expect(LocalizedNumbers.formatMilli(1250), '1.25');
      expect(LocalizedNumbers.formatMilli(5), '0.005');
      expect(LocalizedNumbers.formatMilli(-2500), '-2.5');
    });
    test('formatMilli with fewer decimals rounds', () {
      expect(LocalizedNumbers.formatMilli(1255, maxDecimals: 2), '1.26');
      expect(LocalizedNumbers.formatMilli(1000, maxDecimals: 0), '1');
      expect(LocalizedNumbers.formatMilli(-4, maxDecimals: 2), '0');
    });
  });

  group('formatting', () {
    test('formatNum drops needless decimals', () {
      expect(LocalizedNumbers.formatNum(3), '3');
      expect(LocalizedNumbers.formatNum(3.0), '3');
      expect(LocalizedNumbers.formatNum(2.50), '2.5');
      expect(LocalizedNumbers.formatNum(0.125), '0.125');
    });
    test('toArabicIndic', () => expect(LocalizedNumbers.toArabicIndic('12.5 JD'), '١٢٫٥ JD'));
    test('round trip through Arabic-Indic', () {
      expect(LocalizedNumbers.parse(LocalizedNumbers.toArabicIndic('1234.75')), 1234.75);
    });
    test('isDigitUnit', () {
      expect(LocalizedNumbers.isDigitUnit('٣'.codeUnitAt(0)), isTrue);
      expect(LocalizedNumbers.isDigitUnit('۳'.codeUnitAt(0)), isTrue);
      expect(LocalizedNumbers.isDigitUnit('3'.codeUnitAt(0)), isTrue);
      expect(LocalizedNumbers.isDigitUnit('س'.codeUnitAt(0)), isFalse);
    });
  });
}
