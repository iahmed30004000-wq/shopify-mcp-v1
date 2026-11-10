import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/import/sha256.dart';

void main() {
  group('ImportText', () {
    test('keys ignore case, separators, diacritics, hamza forms and the article', () {
      expect(ImportText.key('taken_with'), ImportText.key('Taken With'));
      expect(ImportText.key('takenWith'), 'takenwith');
      expect(ImportText.key('الميزانية'), ImportText.key('ميزانية'));
      expect(ImportText.key('أدوية'), ImportText.key('ادويه'));
      expect(ImportText.key('النص'), ImportText.key('نص'));
      expect(ImportText.key('ألم'), isNot(ImportText.key('لم')));
    });

    test('humanize', () {
      expect(ImportText.humanize('readingList'), 'Reading list');
      expect(ImportText.humanize('reading_list'), 'Reading list');
      expect(ImportText.humanize('قائمة_الكتب'), 'قائمة الكتب');
    });
  });

  group('ImportValues.date', () {
    DateTime d(int y, int m, int day, [int h = 0, int min = 0]) => DateTime(y, m, day, h, min);

    test('ISO, with and without time', () {
      expect(ImportValues.date('2026-01-10'), d(2026, 1, 10));
      expect(ImportValues.date('2026-01-10T08:30:00'), d(2026, 1, 10, 8, 30));
      expect(ImportValues.date('2026-01-10T08:30:00Z'), DateTime.utc(2026, 1, 10, 8, 30).toLocal());
    });

    test('epoch milliseconds / seconds and yyyyMMdd', () {
      final ms = DateTime(2026, 5, 1, 12).millisecondsSinceEpoch;
      expect(ImportValues.date(ms), DateTime.fromMillisecondsSinceEpoch(ms));
      expect(ImportValues.date(ms ~/ 1000), DateTime.fromMillisecondsSinceEpoch(ms ~/ 1000 * 1000));
      expect(ImportValues.date('$ms'), DateTime.fromMillisecondsSinceEpoch(ms));
      expect(ImportValues.date(20260110), d(2026, 1, 10));
      expect(ImportValues.date('20260110'), d(2026, 1, 10));
    });

    test('dd/MM/yyyy day-first, MM/dd only when unambiguous', () {
      expect(ImportValues.date('05/03/2026'), d(2026, 3, 5));
      expect(ImportValues.date('25/12/2026'), d(2026, 12, 25));
      expect(ImportValues.date('12/25/2026'), d(2026, 12, 25));
      expect(ImportValues.date('1.2.26'), d(2026, 2, 1));
      expect(ImportValues.date('2026/1/9 7:05'), d(2026, 1, 9, 7, 5));
      expect(ImportValues.date('31/02/2026'), isNull);
    });

    test('Arabic-Indic digits and month names', () {
      expect(ImportValues.date('١٠/٠١/٢٠٢٦'), d(2026, 1, 10));
      expect(ImportValues.date('١٠ يناير ٢٠٢٦'), d(2026, 1, 10));
      expect(ImportValues.date('10 كانون الثاني 2026'), d(2026, 1, 10));
      expect(ImportValues.date('3 تشرين الأول 2026'), d(2026, 10, 3));
      expect(ImportValues.date('Jan 10, 2026'), d(2026, 1, 10));
      expect(ImportValues.date('10th October 2026 14:30'), d(2026, 10, 10, 14, 30));
    });

    test('garbage', () {
      expect(ImportValues.date('soon'), isNull);
      expect(ImportValues.date('08:00'), isNull);
      expect(ImportValues.date(12), isNull);
      expect(ImportValues.isDateKey('2026-09-01'), isTrue);
      expect(ImportValues.isDateKey('m1'), isFalse);
      expect(ImportValues.isDateKey('12'), isFalse);
    });
  });

  group('ImportValues.times', () {
    test('lists, separators and suffixes', () {
      expect(ImportValues.times('08:00, 20:00').times, ['08:00', '20:00']);
      expect(ImportValues.times('07:30 and 13:00').times, ['07:30', '13:00']);
      expect(ImportValues.times(['8', '20:30']).times, ['08:00', '20:30']);
      expect(ImportValues.times('9pm').times, ['21:00']);
      expect(ImportValues.times('8:30 PM').times, ['20:30']);
      expect(ImportValues.times('12 am').times, ['00:00']);
      expect(ImportValues.times('٨:٠٠ ص').times, ['08:00']);
      expect(ImportValues.times('٨:٣٠ م').times, ['20:30']);
      expect(ImportValues.times('08:00 20:00').times, ['08:00', '20:00']);
      expect(ImportValues.times('0830').times, ['08:30']);
      expect(ImportValues.times(20.5).times, ['20:30']);
      expect(ImportValues.times([{'time': '06:15'}]).times, ['06:15']);
      expect(ImportValues.times('08:00, 08:00').times, ['08:00']);
    });

    test('words become inferred default times, unknown tokens are rejected', () {
      final p = ImportValues.times('morning, bedtime, with food');
      expect(p.times, ['08:00', '22:00']);
      expect(p.inferred, ['morning', 'bedtime']);
      expect(p.rejected, ['with food']);
      expect(ImportValues.times('صباحًا').times, ['08:00']);
    });
  });

  test('booleans', () {
    for (final v in [true, 1, 'yes', 'Done', '✓', 'نعم', 'تم']) {
      expect(ImportValues.boolean(v), isTrue, reason: '$v');
    }
    for (final v in [false, 0, 'no', 'لا', '✗']) {
      expect(ImportValues.boolean(v), isFalse, reason: '$v');
    }
    expect(ImportValues.boolean('maybe'), isNull);
  });

  test('weekdays: names, ISO numbers and JavaScript numbers', () {
    expect(ImportValues.weekdays(['Mon', 'Wed', 'Fri']), [1, 3, 5]);
    expect(ImportValues.weekdays('الاثنين، الخميس'), [1, 4]);
    expect(ImportValues.weekdays([1, 7]), [1, 7]);
    expect(ImportValues.weekdays([0, 6]), [6, 7]); // JS: Sunday = 0, Saturday = 6
  });

  test('enum aliases in both languages', () {
    expect(ImportValues.enumOf('على الريق', ImportAliases.takenWith), TakenWith.emptyStomach);
    expect(ImportValues.enumOf('مع الفطور', ImportAliases.takenWith), TakenWith.breakfast);
    expect(ImportValues.enumOf('with breakfast please', ImportAliases.takenWith), TakenWith.breakfast);
    expect(ImportValues.enumOf('Before bed', ImportAliases.takenWith), TakenWith.bedtime);
    expect(ImportValues.enumOf('أسبوعي', ImportAliases.budgetPeriod), BudgetPeriod.weekly);
    expect(ImportValues.enumOf('owed to me', ImportAliases.debtDirection), DebtDirection.owedToMe);
    expect(ImportValues.enumOf('الفجر', ImportAliases.prayer), Prayer.fajr);
    expect(ImportValues.enumOf('متأخرة', ImportAliases.prayerStatus), PrayerStatus.late);
    expect(ImportValues.enumOf('xyz', ImportAliases.severity), isNull);
  });

  test('section aliases', () {
    expect(ImportAliases.sectionFor('meds')?.section, ImportSection.medications);
    expect(ImportAliases.sectionFor('مكملات')?.hint, 'supplement');
    expect(ImportAliases.sectionFor('lab_tests')?.section, ImportSection.labTests);
    expect(ImportAliases.sectionFor('تحاليل')?.section, ImportSection.labTests);
    expect(ImportAliases.sectionFor('budgetItems')?.section, ImportSection.budgetItems);
    expect(ImportAliases.sectionFor('stressLogs')?.hint, 'stress');
    expect(ImportAliases.sectionFor('painLogs')?.section, ImportSection.painEntries);
    expect(ImportAliases.sectionFor('prayerLog')?.section, ImportSection.prayerLogs);
    expect(ImportAliases.sectionFor('habitsList')?.section, ImportSection.habits);
    expect(ImportAliases.sectionFor('readingList'), isNull);
    expect(ImportSection.medications.logVariant, ImportSection.medDoses);
  });

  test('SHA-256 known vectors and canonical JSON', () {
    expect(Sha256.ofString(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(Sha256.ofString('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(
      Sha256.ofString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(Sha256.canonicalJson({'b': 1, 'a': [{'d': 1, 'c': 2}]}), '{"a":[{"c":2,"d":1}],"b":1}');
  });
}
