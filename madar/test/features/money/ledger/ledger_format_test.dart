import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/money/ledger/domain/currency_math.dart';
import 'package:madar/features/money/ledger/domain/ledger_format.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';

import 'ledger_fixtures.dart';

void main() {
  final currencies = {for (final c in seededCurrencies) c.code: c};
  final ar = LedgerMoneyFormat(arabic: true, arabicIndic: true, currencies: currencies);
  final arWestern = LedgerMoneyFormat(arabic: true, arabicIndic: false, currencies: currencies);
  final en = LedgerMoneyFormat(arabic: false, arabicIndic: false, currencies: currencies);
  const fsi = '\u2068', pdi = '\u2069', nbsp = '\u00A0';

  group('amounts', () {
    test('English: currency decimals, grouping, prefix signs', () {
      expect(en.amount(1234500, 'JOD'), '1,234.500$nbsp${fsi}JOD$pdi');
      expect(en.amount(12500, 'USD'), r'$12.50');
      expect(en.amount(-12500, 'USD'), r'-$12.50');
      expect(en.amount(12345, 'USD'), r'$12.35'); // half-up to the cent
      expect(en.amount(12344, 'USD'), r'$12.34');
      expect(en.amount(500, 'EGP'), '0.50$nbsp${fsi}EGP$pdi');
      expect(en.amount(-4, 'USD'), r'$0.00'); // rounds to zero: no sign
      expect(en.amount(2500, 'JOD', sign: SignDisplay.always), '+2.500$nbsp${fsi}JOD$pdi');
      expect(en.amount(-2500, 'JOD', sign: SignDisplay.never), '2.500$nbsp${fsi}JOD$pdi');
    });

    test('Arabic-Indic: Arabic separators, ALM before the sign, isolated symbol', () {
      expect(ar.amount(1234500, 'JOD'), '١\u202F٢٣٤٫٥٠٠$nbsp$fsiد.أ$pdi');
      expect(ar.amount(-12500, 'JOD'), '\u061C-١٢٫٥٠٠$nbsp$fsiد.أ$pdi');
      expect(ar.amount(12500, 'USD', sign: SignDisplay.always), '\u061C+١٢٫٥٠$nbsp$fsi\$$pdi');
    });

    test('Arabic with Western digits: LRM before the sign', () {
      expect(arWestern.amount(-12500, 'JOD'), '\u200E-12.500$nbsp$fsiد.أ$pdi');
      expect(arWestern.amount(1000000, 'SYP'), '1,000.00$nbsp$fsiل.س$pdi');
    });

    test('user currencies: own decimals and symbol; unknown codes fall back', () {
      final f = ar.withCurrencies({
        ...currencies,
        'USDT': const LedgerCurrency(code: 'USDT', symbol: 'USDT', decimals: 3, rateToBase: 0.7),
      });
      expect(f.amount(1500, 'USDT'), '١٫٥٠٠$nbsp${fsi}USDT$pdi');
      expect(en.amount(1500, 'XYZ'), '1.50$nbsp${fsi}XYZ$pdi');
      expect(en.decimalsOf('LYD'), 3);
    });

    test('embedding in a sentence isolates in the UI direction', () {
      expect(ar.embed('x'), '\u2067x\u2069');
      expect(en.embed('x'), '\u2066x\u2069');
      expect(en.embed(''), '');
    });

    test('trimZeros drops a zero fraction only', () {
      expect(en.amount(200000, 'JOD', trimZeros: true), '200$nbsp${fsi}JOD$pdi');
      expect(en.amount(200500, 'JOD', trimZeros: true), '200.500$nbsp${fsi}JOD$pdi');
    });

    test('never goes through a double: huge amounts stay exact', () {
      expect(en.number(123456789012345678, decimals: 3), '123,456,789,012,345.678');
    });

    test('compact axis labels', () {
      expect(en.compact(350000), '350');
      expect(en.compact(1250000), '1.3K');
      expect(en.compact(25000000), '25K');
      expect(en.compact(3400000000), '3.4M');
      expect(en.compact(1500), '1.5');
      expect(ar.compact(1250000, thousand: ' ألف'), '١٫٣ ألف');
    });
  });

  group('rate text', () {
    test('significant digits, exact rounding', () {
      expect(RateText.decimal(Rational.fromInt(1, 3), significant: 6), '0.333333');
      expect(RateText.decimal(Rational.fromInt(2, 3), significant: 6), '0.666667');
      expect(RateText.decimal(Rational.fromNum(4.345)), '4.345');
      expect(RateText.decimal(Rational.one / Rational.fromNum(0.709), significant: 12), '1.41043723554');
      expect(RateText.decimal(Rational.fromNum(0.0000545), significant: 6), '0.0000545');
      expect(RateText.decimal(Rational.fromInt(13000)), '13000');
      expect(RateText.decimal(Rational.fromNum(9.9999999), significant: 3), '10');
      expect(ar.rate(Rational.fromNum(0.709)), '٠٫٧٠٩');
      expect(en.rate(Rational.fromNum(18348.62385)), '18,348.6');
    });
  });

  group('rates', () {
    test('parse accepts localised input, rejects zero and negatives', () {
      expect(RateMath.parse('0.709'), Rational.fromNum(0.709));
      expect(RateMath.parse('٠٫٧٠٩'), Rational.fromNum(0.709));
      expect(RateMath.parse('13,000'), Rational.fromInt(13000));
      expect(RateMath.parse('0'), isNull);
      expect(RateMath.parse('-1'), isNull);
      expect(RateMath.parse('abc'), isNull);
    });

    test('inverse entry: 1 JOD = 18,000 SYP', () {
      final r = RateMath.fromEntry(Rational.fromInt(18000), inverted: true);
      expect(r, Rational.fromInt(1, 18000));
      expect(RateMath.storable(r), 0.0000555555555556);
    });

    test('stored rates are the shortest decimal within 10⁻¹²', () {
      expect(RateMath.storable(Rational.fromNum(0.709)), 0.709);
      expect(RateMath.storable(Rational.fromInt(1, 3)), 0.333333333333);
      expect(RateMath.storable(Rational.one / Rational.fromNum(0.709)), 1.410437235543);
    });

    test('rebase keeps every conversion', () {
      final plan = RebasePlan.of(seededCurrencies, 'USD')!;
      expect(plan.oldBase, 'JOD');
      expect(plan.row('USD')!.stored, 1.0);
      expect(plan.row('JOD')!.newRate, Rational.one / Rational.fromNum(0.709));
      expect(plan.row('JOD')!.stored, 1.410437235543);
      // SYP → USD: 0.0064 / 0.709 exactly.
      expect(plan.row('SYP')!.newRate, Rational.fromNum(0.0064) / Rational.fromNum(0.709));
      // Converting 1,000,000 SYP to JOD before and after gives the same value.
      final before = LedgerRates.of(seededCurrencies);
      final after = LedgerRates.of([
        for (final c in seededCurrencies) c.copyWith(rateToBase: plan.row(c.code)!.stored, isBase: c.code == 'USD'),
      ]);
      expect(after.base, 'USD');
      expect(after.convert(1000000000, 'SYP', 'JOD'), before.convert(1000000000, 'SYP', 'JOD'));
      expect(after.convert(100000, 'USD', 'JOD'), 70900);
    });

    test('rebasing there and back restores the original rates', () {
      final there = RebasePlan.of(seededCurrencies, 'USD')!;
      final moved = [
        for (final c in seededCurrencies) c.copyWith(rateToBase: there.row(c.code)!.stored, isBase: c.code == 'USD'),
      ];
      final back = RebasePlan.of(moved, 'JOD')!;
      for (final c in seededCurrencies) {
        expect(back.row(c.code)!.stored, c.rateToBase, reason: c.code);
      }
    });

    test('no plan for the current base or an unusable rate', () {
      expect(RebasePlan.of(seededCurrencies, 'JOD'), isNull);
      expect(RebasePlan.of(seededCurrencies, 'XYZ'), isNull);
      expect(RebasePlan.of([...seededCurrencies, const LedgerCurrency(code: 'BAD', rateToBase: 0)], 'BAD'), isNull);
    });

    test('currency codes', () {
      expect(CurrencyCodes.normalize(' usdt '), 'USDT');
      expect(CurrencyCodes.normalize('eur'), 'EUR');
      expect(CurrencyCodes.normalize('1AB'), isNull);
      expect(CurrencyCodes.normalize('دينار'), isNull);
      expect(CurrencyCodes.normalize('A'), isNull);
    });
  });
}
