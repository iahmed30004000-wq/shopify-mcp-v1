import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/guide/guide.dart';

GuideEntry _e(
  String id,
  String title, {
  String purpose = 'p',
  String example = 'e',
  List<String> doItems = const ['d1', 'd2'],
  String keywords = '',
}) => GuideEntry(id: id, title: title, purpose: purpose, example: example, doItems: doItems, keywords: keywords);

void main() {
  final entries = [
    _e('today', 'اليوم', purpose: 'صلواتك ومهامك ومواعيدك على شاشة وحدة', keywords: 'الرئيسية يومي'),
    _e('faith', 'الإيمان', purpose: 'الصلاة والأذكار والقرآن', keywords: 'مواقيت قبلة أذان'),
    _e('expense', 'إضافة مصروف', purpose: 'سجّل أي مبلغ دفعته', example: 'مثال: ٥ دنانير بنزين', keywords: 'فلوس شراء'),
    _e('english', 'Add a task', purpose: 'Tasks you need to do', keywords: 'todo reminder'),
  ];
  final search = GuideSearch(entries);

  List<String> ids(String q) => [for (final h in search.search(q)) h.entry.id];

  test('an empty or blank query has no hits', () {
    expect(ids(''), isEmpty);
    expect(ids('   '), isEmpty);
    expect(ids('،؟'), isEmpty);
  });

  group('Arabic normalisation', () {
    test('diacritics are ignored on either side', () {
      expect(ids('الإِيمَان'), ['faith']);
      expect(ids('اَلْيَوْم'), ['today']);
    });

    test('alef forms are one letter: ايمان, إيمان, أيمان', () {
      expect(ids('ايمان'), ['faith']);
      expect(ids('إيمان'), ['faith']);
      expect(ids('أيمان'), ['faith']);
      expect(ids('اضافة'), ['expense']);
    });

    test('ya and alef-maqsura are one letter, ta marbuta and ha are one letter', () {
      expect(ids('الصلاه'), ['faith']);
      expect(ids('الصلاة'), ['faith']);
      expect(ids('القرآن'), ids('القران'));
      expect(ids('على شاشه'), ['today']);
      expect(ids('علي شاشة'), ['today']);
    });

    test('the article is optional: صلاة finds الصلاة and الصلاة finds صلاة', () {
      final s = GuideSearch([_e('a', 'صلاة'), _e('b', 'الكتاب')]);
      expect([for (final h in s.search('الصلاة')) h.entry.id], ['a']);
      expect([for (final h in s.search('كتاب')) h.entry.id], ['b']);
    });

    test('Arabic-Indic and Western digits are the same', () {
      expect(ids('٥'), ['expense']);
      expect(ids('5'), ['expense']);
    });

    test('Latin is case-insensitive', () {
      expect(ids('ADD TASK'), ['english']);
    });
  });

  group('ranking', () {
    test('a title word beats the same word in a purpose', () {
      final s = GuideSearch([
        _e('later', 'شي ثاني', purpose: 'بتسجل مصروف هون'),
        _e('first', 'المصروف'),
      ]);
      final hits = s.search('مصروف');
      expect([for (final h in hits) h.entry.id], ['first', 'later']);
      expect(hits.first.field, GuideMatchField.title);
      expect(hits.last.field, GuideMatchField.purpose);
    });

    test('keywords find an entry by a word its title does not have', () {
      final hits = search.search('فلوس');
      expect([for (final h in hits) h.entry.id], ['expense']);
      expect(hits.single.field, GuideMatchField.keywords);
    });

    test('an exact word beats a prefix', () {
      final s = GuideSearch([_e('long', 'مصروفات'), _e('exact', 'مصروف')]);
      expect([for (final h in s.search('مصروف')) h.entry.id], ['exact', 'long']);
    });

    test('the last word may be unfinished', () {
      expect(ids('اضاف'), ['expense']);
      expect(ids('مصر'), ['expense']);
    });

    test('every word must match: a query with a stranger word finds nothing', () {
      expect(ids('مصروف طيارة'), isEmpty);
      expect(ids('إضافة مصروف'), ['expense']);
    });

    test('a title holding the query as a phrase gets a bonus', () {
      final s = GuideSearch([
        _e('split', 'مصروف', purpose: 'اضافة سريعة'),
        _e('phrase', 'اضافة مصروف'),
      ]);
      expect([for (final h in s.search('اضافة مصروف')) h.entry.id].first, 'phrase');
    });

    test('a one-letter typo still finds a long word, below real matches', () {
      final s = GuideSearch([_e('a', 'مواقيت الصلاة'), _e('b', 'x', purpose: 'مواقيط')]);
      final hits = s.search('مواقيت');
      expect([for (final h in hits) h.entry.id], ['a', 'b']);
    });

    test('ties keep the registry order; limit cuts the list', () {
      final s = GuideSearch([_e('1', 'تمرين'), _e('2', 'تمرين'), _e('3', 'تمرين')]);
      expect([for (final h in s.search('تمرين')) h.entry.id], ['1', '2', '3']);
      expect(s.search('تمرين', limit: 2), hasLength(2));
      expect(s.search('تمرين', limit: 0), isEmpty);
    });
  });

  test('works over the real sample entries in Arabic', () {
    // The samples' own keywords are searched, not just titles.
    final registry = GuideSamples.registry();
    String resolve(String k) => switch (k) {
      'guideExpenseTitle' => 'إضافة مصروف',
      'guideExpenseKeywords' => 'مصروف بنزين',
      _ => 'نص',
    };
    final s = GuideSearch(registry.all(resolve));
    expect(s.search('بنزين').first.entry.id, 'add.expense');
  });
}
