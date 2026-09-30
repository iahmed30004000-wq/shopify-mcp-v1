import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/features/custom_modules/domain/field_values.dart';
import 'package:madar/features/custom_modules/domain/module_schema.dart';

ModuleField _f(FieldType type, {bool required = false, num? min, num? max, int decimals = 0, List<FieldOption>? options, String? currency}) =>
    ModuleField(
      id: 'f',
      label: 'F',
      type: type,
      required: required,
      min: min,
      max: max,
      decimals: decimals,
      options: options ?? const [],
      currency: currency,
    );

const _opts = [FieldOption(id: 'o1', label: 'One'), FieldOption(id: 'o2', label: 'Two'), FieldOption(id: 'o3', label: 'Old', hidden: true)];

void main() {
  group('reading values', () {
    test('numbers from any digit script and separator', () {
      expect(FieldValues.number('12'), 12);
      expect(FieldValues.number('١٢٫٥'), 12.5);
      expect(FieldValues.number('1,234.5'), 1234.5);
      expect(FieldValues.number('۳'), 3);
      expect(FieldValues.number(' -4 '), -4);
      expect(FieldValues.number('12 pages'), isNull);
      expect(FieldValues.number('abc'), isNull);
      expect(FieldValues.number(double.nan), isNull);
    });

    test('dates, times, checkboxes', () {
      expect(FieldValues.date('2026-09-01'), DateTime(2026, 9, 1));
      expect(FieldValues.date('2026-09-01T00:00:00.000'), DateTime(2026, 9, 1));
      expect(FieldValues.date('٢٠٢٦-٠٩-٠١'), DateTime(2026, 9, 1));
      expect(FieldValues.date('2026-02-30'), isNull);
      expect(FieldValues.time('7:05'), '07:05');
      expect(FieldValues.time('٢١:٣٠'), '21:30');
      expect(FieldValues.time('25:00'), isNull);
      expect(FieldValues.checkbox('نعم'), isTrue);
      expect(FieldValues.checkbox(0), isFalse);
      expect(FieldValues.checkbox('maybe'), isNull);
    });

    test('money keeps integer milli-units', () {
      final m = FieldValues.money({'milli': 12500, 'currency': 'JOD'})!;
      expect(m.milli, 12500);
      expect(FieldValues.money(3.5, fallbackCurrency: 'USD'), const Money(3500, 'USD'));
    });

    test('numeric view for charts', () {
      expect(FieldValues.numeric(_f(FieldType.checkbox), true), 1);
      expect(FieldValues.numeric(_f(FieldType.rating), 4), 4);
      expect(FieldValues.numeric(_f(FieldType.currency), {'milli': 2500, 'currency': 'JOD'}), 2.5);
      expect(FieldValues.numeric(_f(FieldType.text), 'x'), isNull);
    });
  });

  group('validation per type', () {
    test('required and empty', () {
      expect(EntryValidator.check(_f(FieldType.text, required: true), '  ').issue, EntryIssue.required);
      expect(EntryValidator.check(_f(FieldType.text), '').value, isNull);
      expect(EntryValidator.check(_f(FieldType.text), '  hi ').value, 'hi');
      // A checkbox is always answered.
      expect(EntryValidator.check(_f(FieldType.checkbox, required: true), null).value, false);
    });

    test('text length', () {
      expect(EntryValidator.check(_f(FieldType.text), 'x' * 5000).issue, EntryIssue.tooLong);
    });

    test('number: whole, decimals, bounds, Arabic-Indic input', () {
      final whole = _f(FieldType.number, min: 0, max: 100);
      expect(EntryValidator.check(whole, '٤٢').value, 42);
      expect(EntryValidator.check(whole, '4.5').issue, EntryIssue.notWhole);
      expect(EntryValidator.check(whole, '-1').issue, EntryIssue.belowMin);
      expect(EntryValidator.check(whole, '101').issue, EntryIssue.aboveMax);
      expect(EntryValidator.check(whole, '101').bound, 100);
      expect(EntryValidator.check(whole, 'x').issue, EntryIssue.notANumber);
      final dec = _f(FieldType.number, decimals: 1);
      expect(EntryValidator.check(dec, '٧٫٥').value, 7.5);
      expect(EntryValidator.check(dec, '7.25').issue, EntryIssue.tooPrecise);
      expect(EntryValidator.check(dec, 8).value, 8.0);
    });

    test('currency: milli-units, currency decimals, no negatives by default', () {
      final jod = _f(FieldType.currency, currency: 'JOD');
      expect(EntryValidator.check(jod, '12.345').value, {'milli': 12345, 'currency': 'JOD'});
      expect(EntryValidator.check(jod, '١٢٫٥').value, {'milli': 12500, 'currency': 'JOD'});
      expect(EntryValidator.check(jod, '-3').issue, EntryIssue.belowMin);
      final usd = _f(FieldType.currency, currency: 'USD');
      expect(EntryValidator.check(usd, '1.005').issue, EntryIssue.tooPrecise);
      expect(EntryValidator.check(usd, const Money(2000, 'EGP')).value, {'milli': 2000, 'currency': 'EGP'});
      expect(EntryValidator.check(usd, 'ten').issue, EntryIssue.notANumber);
    });

    test('date and time', () {
      expect(EntryValidator.check(_f(FieldType.date), DateTime(2026, 9, 3, 14)).value, '2026-09-03');
      expect(EntryValidator.check(_f(FieldType.date), 'soon').issue, EntryIssue.invalidDate);
      expect(EntryValidator.check(_f(FieldType.time), '6:30').value, '06:30');
      expect(EntryValidator.check(_f(FieldType.time), '6h').issue, EntryIssue.invalidTime);
    });

    test('single and multi select', () {
      final single = _f(FieldType.singleSelect, options: _opts);
      expect(EntryValidator.check(single, 'o2').value, 'o2');
      expect(EntryValidator.check(single, 'o3').value, 'o3', reason: 'a hidden option on an old entry stays valid');
      expect(EntryValidator.check(single, 'o9').issue, EntryIssue.unknownOption);
      final multi = _f(FieldType.multiSelect, options: _opts, required: true);
      expect(EntryValidator.check(multi, ['o2', 'o1', 'o2']).value, ['o1', 'o2']);
      expect(EntryValidator.check(multi, <String>[]).issue, EntryIssue.required);
      expect(EntryValidator.check(multi, ['o1', 'zz']).issue, EntryIssue.unknownOption);
    });

    test('rating within its scale', () {
      final r = _f(FieldType.rating, max: 5);
      expect(EntryValidator.check(r, 4).value, 4);
      expect(EntryValidator.check(r, 0).value, isNull);
      expect(EntryValidator.check(_f(FieldType.rating, required: true), 0).issue, EntryIssue.required);
      expect(EntryValidator.check(r, 6).issue, EntryIssue.outOfScale);
      expect(EntryValidator.check(r, 2.5).issue, EntryIssue.outOfScale);
    });

    test('checkAll keeps hidden and unknown values of the edited entry', () {
      final fields = [
        _f(FieldType.number, required: true),
        const ModuleField(id: 'h', label: 'Hidden', type: FieldType.text, hidden: true),
      ];
      final check = EntryValidator.checkAll(fields, {'f': '٣'}, keep: {'h': 'old', 'ghost': 7, 'f': 1});
      expect(check.ok, isTrue);
      expect(check.values, {'f': 3, 'h': 'old', 'ghost': 7});
      final bad = EntryValidator.checkAll(fields, {'f': ''});
      expect(bad.ok, isFalse);
      expect(bad.issues['f']!.issue, EntryIssue.required);
    });
  });

  group('normalize', () {
    test('canonical stored forms', () {
      expect(FieldValues.normalize(_f(FieldType.number), 3.0), 3);
      expect(FieldValues.normalize(_f(FieldType.date), '2026-09-01T00:00:00.000'), '2026-09-01');
      expect(FieldValues.normalize(_f(FieldType.multiSelect), 'a'), ['a']);
      expect(FieldValues.normalize(_f(FieldType.currency, currency: 'USD'), 2), {'milli': 2000, 'currency': 'USD'});
      expect(FieldValues.normalize(_f(FieldType.text), '  '), isNull);
    });
  });
}
