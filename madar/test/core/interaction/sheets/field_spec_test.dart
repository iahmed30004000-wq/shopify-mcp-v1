import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/sheets/field_spec.dart';

void main() {
  group('FieldSpec.coerce', () {
    test('text trims and turns blank into null', () {
      final f = FieldSpec.text('t', 'T');
      expect(f.coerce('  hi '), 'hi');
      expect(f.coerce('   '), isNull);
      expect(f.coerce(null), isNull);
    });
    test('number: int when decimals = 0, double otherwise; strings in any script', () {
      expect(FieldSpec.number('n', 'N').coerce(3.0), 3);
      expect(FieldSpec.number('n', 'N').coerce('١٢'), 12);
      expect(FieldSpec.number('n', 'N', decimals: 2).coerce(3), 3.0);
      expect(FieldSpec.number('n', 'N', decimals: 2).coerce(3), isA<double>());
      expect(FieldSpec.number('n', 'N').coerce('x'), isNull);
    });
    test('currency accepts MoneyValue, maps and plain numbers', () {
      final f = FieldSpec.currency('c', 'C', defaultCurrency: 'USD');
      expect(
        f.coerce(const MoneyValue(amountMilli: 5, currency: 'JOD')),
        const MoneyValue(amountMilli: 5, currency: 'JOD'),
      );
      expect(f.coerce({'amountMilli': 2500, 'currency': 'EGP'}), const MoneyValue(amountMilli: 2500, currency: 'EGP'));
      expect(f.coerce({'amount': '١٢٫٥'}), const MoneyValue(amountMilli: 12500, currency: 'USD'));
      expect(f.coerce(7), const MoneyValue(amountMilli: 7000, currency: 'USD'));
      expect(f.coerce('nope'), isNull);
    });
    test('date drops the time; ISO strings with Arabic digits parse', () {
      final f = FieldSpec.date('d', 'D');
      expect(f.coerce(DateTime(2026, 3, 4, 17, 30)), DateTime(2026, 3, 4));
      expect(f.coerce('٢٠٢٦-١٠-٠١'), DateTime(2026, 10, 1));
    });
    test('time and time lists normalise to HH:mm, sorted and unique', () {
      expect(FieldSpec.time('t', 'T').coerce('8:5'), '08:05');
      expect(FieldSpec.time('t', 'T').coerce('٨:٣٠'), '08:30');
      expect(FieldSpec.time('t', 'T').coerce(const TimeOfDay(hour: 21, minute: 0)), '21:00');
      expect(FieldSpec.time('t', 'T').coerce('25:00'), isNull);
      expect(FieldSpec.timeList('l', 'L').coerce(['20:00', '8:00', '08:00', 'bad']), ['08:00', '20:00']);
    });
    test('selects keep only known options unless adding is allowed', () {
      const options = [SelectOption(id: 'a', label: 'A'), SelectOption(id: 'b', label: 'B')];
      expect(FieldSpec.singleSelect('s', 'S', options: options).coerce('b'), 'b');
      expect(FieldSpec.singleSelect('s', 'S', options: options).coerce('z'), isNull);
      expect(FieldSpec.multiSelect('m', 'M', options: options).coerce(['a', 'z', 'a']), ['a']);
      expect(FieldSpec.multiSelect('m', 'M', options: options, allowAdd: true).coerce(['a', 'z']), ['a', 'z']);
    });
    test('rating, slider, colour, icon and prayer window', () {
      expect(FieldSpec.rating('r', 'R').coerce(9), 5);
      expect(FieldSpec.rating('r', 'R').coerce(0), isNull);
      expect(FieldSpec.slider('s', 'S').coerce(14), 10);
      expect(FieldSpec.slider('s', 'S').coerce(null), 0);
      expect(FieldSpec.color('c', 'C').coerce(const Color(0xFF112233)), 0xFF112233);
      expect(FieldSpec.icon('i', 'I', icons: const {'star': Icons.star}).coerce('moon'), isNull);
      expect(FieldSpec.prayerWindow('w', 'W').coerce('asr'), PrayerWindow.asr);
      expect(FieldSpec.prayerWindow('w', 'W', includeAnytime: false).coerce(PrayerWindow.anytime), isNull);
    });
  });

  group('EditFormModel', () {
    test('initial values populate text and values; untouched form is clean', () {
      final m = EditFormModel(
        [FieldSpec.text('title', 'T'), FieldSpec.currency('price', 'P')],
        {'title': 'قهوة', 'price': const MoneyValue(amountMilli: 2500, currency: 'JOD')},
      );
      expect(m.textOf('title'), 'قهوة');
      expect(m.textOf('price'), '2.5');
      expect(m.currencyOf('price'), 'JOD');
      expect(m.isDirty, isFalse);
      expect(m.isValid, isTrue);
    });

    test('number text normalises Arabic-Indic digits and ٫', () {
      final m = EditFormModel([FieldSpec.number('w', 'W', decimals: 1)]);
      m.setText('w', '٧٢٫٥');
      expect(m.valueOf('w'), 72.5);
      expect(m.isDirty, isTrue);
      expect(m.result(), {'w': 72.5});
    });

    test('number issues: required, invalid, decimals, min, max', () {
      final m = EditFormModel([FieldSpec.number('n', 'N', required: true, min: 1, max: 10)]);
      expect(m.issueOf('n'), const FieldIssue(FieldIssueCode.required));
      expect(m.visibleIssueOf('n'), isNull, reason: 'hidden until touched');
      m.setText('n', 'x');
      expect(m.visibleIssueOf('n'), const FieldIssue(FieldIssueCode.invalidNumber));
      m.setText('n', '2.5');
      expect(m.issueOf('n'), const FieldIssue(FieldIssueCode.tooManyDecimals, limit: 0));
      m.setText('n', '0');
      expect(m.issueOf('n'), const FieldIssue(FieldIssueCode.belowMin, limit: 1));
      m.setText('n', '١١');
      expect(m.issueOf('n'), const FieldIssue(FieldIssueCode.aboveMax, limit: 10));
      m.setText('n', '٧');
      expect(m.issueOf('n'), isNull);
      expect(m.result(), {'n': 7});
    });

    test('revealAll shows issues of untouched fields', () {
      final m = EditFormModel([FieldSpec.text('t', 'T', required: true)]);
      expect(m.visibleIssueOf('t'), isNull);
      m.revealAll();
      expect(m.visibleIssueOf('t'), const FieldIssue(FieldIssueCode.required));
      expect(m.firstInvalidKey, 't');
    });

    test('text maxLength', () {
      final m = EditFormModel([FieldSpec.text('t', 'T', maxLength: 3)]);
      m.setText('t', 'abcd');
      expect(m.issueOf('t'), const FieldIssue(FieldIssueCode.tooLong, limit: 3));
    });

    test('currency keeps the picked currency and rebuilds the value', () {
      final m = EditFormModel([FieldSpec.currency('c', 'C', required: true)]);
      expect(m.currencyOf('c'), 'JOD');
      m.setText('c', '١٥٫٧٥');
      m.setCurrency('c', 'USD');
      expect(m.valueOf('c'), const MoneyValue(amountMilli: 15750, currency: 'USD'));
      m.setCurrency('c', 'EGP');
      expect(m.result()['c'], const MoneyValue(amountMilli: 15750, currency: 'EGP'));
    });

    test('multi-select add option: new label selected; existing label reused', () {
      final m = EditFormModel([
        FieldSpec.multiSelect(
          'm',
          'M',
          allowAdd: true,
          options: const [SelectOption(id: 'stress', label: 'توتر')],
        ),
      ]);
      expect(m.addOption('m', ' برد '), isTrue);
      expect(m.addOption('m', 'توتر'), isTrue);
      expect(m.addOption('m', '  '), isFalse);
      expect(m.result()['m'], ['برد', 'stress']);
      expect(m.addedOptions('m').map((o) => o.label), ['برد']);
    });

    test('count limits on multi-select and time lists', () {
      final m = EditFormModel([
        FieldSpec.multiSelect(
          'm',
          'M',
          minCount: 2,
          maxCount: 3,
          options: const [
            SelectOption(id: 'a', label: 'A'),
            SelectOption(id: 'b', label: 'B'),
            SelectOption(id: 'c', label: 'C'),
            SelectOption(id: 'd', label: 'D'),
          ],
        ),
        FieldSpec.timeList('t', 'T', required: true),
      ]);
      m.setValue('m', ['a']);
      expect(m.issueOf('m'), const FieldIssue(FieldIssueCode.selectAtLeast, limit: 2));
      m.setValue('m', ['a', 'b', 'c', 'd']);
      expect(m.issueOf('m'), const FieldIssue(FieldIssueCode.selectAtMost, limit: 3));
      expect(m.issueOf('t'), const FieldIssue(FieldIssueCode.required));
      m.setValue('t', ['21:00', '9:00']);
      expect(m.result()['t'], ['09:00', '21:00']);
    });

    test('date range', () {
      final m = EditFormModel([
        FieldSpec.date('d', 'D', firstDate: DateTime(2026, 1, 1), lastDate: DateTime(2026, 12, 31)),
      ]);
      m.setValue('d', DateTime(2027, 1, 1));
      expect(m.issueOf('d'), const FieldIssue(FieldIssueCode.dateOutOfRange));
      m.setValue('d', DateTime(2026, 12, 31, 23));
      expect(m.issueOf('d'), isNull);
    });

    test('custom validators see every value', () {
      final m = EditFormModel([
        FieldSpec.number('min', 'Min'),
        FieldSpec.number(
          'max',
          'Max',
          validator: (v, all) => (v as num? ?? 0) < (all['min'] as num? ?? 0) ? 'bad' : null,
        ),
      ]);
      m.setText('min', '10');
      m.setText('max', '5');
      expect(m.issueOf('max'), const FieldIssue(FieldIssueCode.custom, message: 'bad'));
      m.setText('max', '15');
      expect(m.isValid, isTrue);
    });

    test('result always has every key with canonical types', () {
      final m = EditFormModel([
        FieldSpec.toggle('on', 'On'),
        FieldSpec.slider('s', 'S'),
        FieldSpec.multiSelect('m', 'M', options: const []),
        FieldSpec.rating('r', 'R'),
      ]);
      expect(m.result(), {'on': false, 's': 0, 'm': <String>[], 'r': null});
    });

    test('notifies listeners on every edit', () {
      final m = EditFormModel([FieldSpec.text('t', 'T')]);
      var n = 0;
      m.addListener(() => n++);
      m.setText('t', 'a');
      m.setValue('t', 'b');
      m.revealAll();
      expect(n, 3);
    });
  });

  group('ClockTime', () {
    test('parts / format / sortUnique', () {
      expect(ClockTime.parts('07:45'), (7, 45));
      expect(ClockTime.format(7, 5), '07:05');
      expect(ClockTime.sortUnique(['10:00', '09:00', '10:00']), ['09:00', '10:00']);
    });
    test('accepts Arabic separators and digits', () {
      expect(ClockTime.normalize('١٧٫٣٠'), '17:30');
      expect(ClockTime.normalize(DateTime(2026, 1, 1, 6, 7)), '06:07');
      expect(ClockTime.normalize(5), isNull);
    });
  });
}
