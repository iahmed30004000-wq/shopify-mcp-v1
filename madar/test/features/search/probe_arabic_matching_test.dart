// Adversarial probes: Arabic + bilingual matching quality of the global
// search index. Each test FAILS while the problem it names exists.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/features/search/domain/search_doc.dart';
import 'package:madar/features/search/domain/search_index.dart';

final DateTime now = DateTime(2026, 9, 30, 12);

SearchDoc doc(
  String id, {
  String title = '',
  String subtitle = '',
  String body = '',
  DateTime? date,
  String planet = 'work',
  String source = 'tasks',
}) => SearchDoc(
  id: id,
  refTable: source,
  refId: id,
  title: title,
  subtitle: subtitle,
  body: body,
  date: date,
  planetKey: planet,
  sourceId: source,
);

SearchIndex indexOf(List<SearchDoc> docs) =>
    SearchIndex(clock: () => now)..apply(SearchIndexDelta(upserts: docs));

SearchIndexResult find(SearchIndex index, String q) => index.search(SearchIndexQuery(q, now: now));

List<String> ids(SearchIndexResult r) => [for (final h in r.hits) h.doc.id];

void main() {
  group('false negatives', () {
    test('a word glued to the conjunction و / ب / ل (no article) is found by the bare word', () {
      final index = indexOf([
        doc('milk', title: 'شراء خبز وحليب'),
        doc('sara', title: 'موعد مع أحمد وسارة'),
        doc('mahmoud', title: 'اتصلت بمحمود بخصوص الإيجار'),
        doc('gift', title: 'هدية لسارة'),
      ]);
      expect(ids(find(index, 'حليب')), ['milk'], reason: '«حليب» inside «وحليب»');
      expect(ids(find(index, 'سارة')), unorderedEquals(['sara', 'gift']), reason: '«سارة» inside «وسارة» / «لسارة»');
      expect(ids(find(index, 'محمود')), ['mahmoud'], reason: '«محمود» inside «بمحمود»');
    });

    test('two-letter nouns with the article (الدم، الماء، اليد) are found by the bare noun', () {
      final index = indexOf([
        doc('blood', title: 'تحليل الدم'),
        doc('water', title: 'شرب الماء'),
        doc('hand', title: 'ألم في اليد'),
      ]);
      expect(ids(find(index, 'دم')), contains('blood'));
      expect(ids(find(index, 'ماء')), contains('water'));
      expect(ids(find(index, 'يد')), contains('hand'));
      // Typed as the user would: «ضغط دم» must fully match «ضغط الدم».
      final bp = indexOf([doc('bp', title: 'قياس ضغط الدم'), doc('work', title: 'ضغط العمل')]);
      final r = find(bp, 'ضغط دم');
      expect(r.partial, isFalse, reason: '«دم» should match «الدم»');
      expect(ids(r), ['bp']);
    });

    test('typing a word with its article: results do not vanish one letter before the end', () {
      final index = indexOf([
        doc('a', title: 'موعد بالمستشفى'),
        doc('b', title: 'مستشفى الجامعة الأردنية'),
      ]);
      // The whole word finds both …
      expect(ids(find(index, 'المستشفى')), unorderedEquals(['a', 'b']));
      // … so every shorter prefix typed on the way must too.
      expect(ids(find(index, 'المستشف')), unorderedEquals(['a', 'b']), reason: '«المستشف» (one letter short)');
      expect(ids(find(index, 'المستش')), unorderedEquals(['a', 'b']), reason: '«المستش»');
    });

    test('compound names are found whether written joined or apart (عبدالله / عبد الله)', () {
      final index = indexOf([
        doc('split', title: 'اتصال مع عبد الله الخطيب'),
        doc('joined', title: 'موعد عبدالرحمن'),
      ]);
      expect(ids(find(index, 'عبدالله')), ['split']);
      final r = find(index, 'عبد الرحمن');
      expect(r.partial, isFalse, reason: '«عبد الرحمن» should fully match «عبدالرحمن»');
      expect(ids(r), ['joined']);
    });

    final kin = [
      doc('wife', title: 'عيد ميلاد زوجتي', planet: 'family', source: 'people'),
      doc('aunt', title: 'زيارة خالتي يوم الجمعة', planet: 'family'),
      doc('flat', title: 'إيجار شقتنا في عبدون', planet: 'money'),
      doc('trip', title: 'حجز فندق رحلتنا إلى العقبة', planet: 'travel'),
    ];
    for (final (query, expected) in [('زوجة', 'wife'), ('خالة', 'aunt'), ('شقة', 'flat'), ('رحلة', 'trip')]) {
      test('«$query» finds the word with a possessive ending (ة → ت: زوجتي، خالتي، شقتنا، رحلتنا)', () {
        expect(ids(find(indexOf(kin), query)), [expected]);
      });
    }

    test('an amount of 1,000 or more is found by its plain digits', () {
      // Exactly what SearchLoadContext.money writes in Arabic with Arabic-Indic digits.
      final ar = Digits.toArabicIndic(Money(1250000, 'JOD').format(locale: 'ar', digits: MoneyDigits.western));
      final en = Money(1250000, 'JOD').format(locale: 'en', digits: MoneyDigits.western);
      final index = indexOf([
        doc('ar', title: 'إيجار الشقة', subtitle: '$ar، مصروف، المحفظة النقدية', planet: 'money', source: 'transactions'),
        doc('en', title: 'Rent', subtitle: '$en · Expense · Cash', planet: 'money', source: 'transactions'),
      ]);
      expect(ids(find(index, '1250')), unorderedEquals(['ar', 'en']), reason: 'subtitles: «$ar» / «$en»');
      expect(ids(find(index, '١٢٥٠')), unorderedEquals(['ar', 'en']));
    });
  });

  group('false positives', () {
    test('an amount with decimals does not find a thousands amount: «12.5» ≠ 12,500', () {
      String ar(int milli) => Digits.toArabicIndic(Money(milli, 'JOD').format(locale: 'ar', digits: MoneyDigits.western));
      final index = indexOf([
        doc('small', title: 'غداء', subtitle: '${ar(12500)}، مصروف', planet: 'money', source: 'transactions'),
        doc('big', title: 'دفعة السيارة', subtitle: '${ar(12500000)}، مصروف', planet: 'money', source: 'transactions'),
      ]);
      expect(ids(find(index, '12.5')), ['small'], reason: '«${ar(12500)}» vs «${ar(12500000)}»');
      expect(ids(find(index, '12500')), ['big']);
    });

    test('typo tolerance does not count the article: «الصوم» (fasting) ≠ «اليوم» (today) / «النوم» (sleep)', () {
      final index = indexOf([
        doc('fast', title: 'نية الصوم يوم الخميس'),
        doc('today', title: 'مراجعة البنك اليوم'),
        doc('sleep', title: 'النوم قبل الساعة ١١'),
      ]);
      // «الصوم» is «ال» + a 3-letter word; 3-letter words never tolerate a typo.
      expect(ids(find(index, 'صوم')), ['fast']);
      expect(ids(find(index, 'الصوم')), ['fast']);
    });

    final hamzaDocs = [
      doc('lunch', title: 'غداء عائلي عند أم أحمد'),
      doc('tomorrow', title: 'تجديد الإقامة غداً'),
      doc('shift', title: 'الدوام يبدأ الساعة ٨'),
      doc('med', title: 'موعد الدواء بعد الإفطار'),
      doc('meeting', title: 'لقاء مع المدير'),
      doc('vaccine', title: 'لقاح الإنفلونزا للأولاد'),
    ];
    for (final (query, expected, why) in [
      ('غداء', 'lunch', '«غداء» (lunch) ≠ «غداً» (tomorrow)'),
      ('دواء', 'med', '«دواء» (medicine) is not a prefix of «الدوام» (work shift)'),
      ('لقاء', 'meeting', '«لقاء» (meeting) is not a prefix of «لقاح» (vaccine)'),
    ]) {
      test('a word ending in hamza is a whole word: $why', () {
        expect(ids(find(indexOf(hamzaDocs), query)), [expected]);
      });
    }

    test('ranking: the record holding the exact word beats one where it is only a folded prefix', () {
      final index = indexOf([
        doc('shift', title: 'الدوام يبدأ الساعة ٨'),
        doc('med', title: 'موعد الدواء بعد الإفطار'),
      ]);
      expect(ids(find(index, 'الدواء')).first, 'med');
    });

    test('ranking: the name «علي» (Ali) beats the preposition «على» (on) for the query «علي»', () {
      final index = indexOf([
        doc('ali', title: 'اتصال مع علي بخصوص السيارة', date: now.subtract(const Duration(days: 20))),
        doc('ala', title: 'الدور على سارة في التوصيل', date: now),
      ]);
      expect(ids(find(index, 'علي')).first, 'ali');
    });

    test('a quoted phrase is literal: "محمود علي" does not find «محمد علي»', () {
      final index = indexOf([
        doc('mohammad', title: 'زيارة محمد علي'),
        doc('mahmoud', title: 'زيارة محمود علي'),
      ]);
      expect(ids(find(index, '"محمود علي"')), ['mahmoud']);
    });

    test('a single quoted word is literal: "محمود" does not find «محمد»', () {
      final index = indexOf([
        doc('mohammad', title: 'زيارة محمد'),
        doc('mahmoud', title: 'زيارة محمود'),
      ]);
      expect(ids(find(index, '"محمود"')), ['mahmoud']);
    });

    test('ranking: the exact name in a note beats a one-typo name in a title («محمود» vs «محمد»)', () {
      final index = indexOf([
        doc('mohammad', title: 'محمد العلي', source: 'people', planet: 'family'),
        doc('transfer', title: 'تحويل الإيجار', body: 'أرسلت المبلغ إلى محمود اليوم', planet: 'money', source: 'transactions'),
      ]);
      expect(ids(find(index, 'محمود')).first, 'transfer');
    });

    test('Arabic guillemets «…» make a phrase just like "…"', () {
      final index = indexOf([
        doc('adjacent', title: 'دواء الضغط'),
        doc('apart', title: 'دواء السكري وقياس الضغط'),
      ]);
      expect(ids(find(index, '"دواء الضغط"')), ['adjacent']);
      expect(ids(find(index, '«دواء الضغط»')), ['adjacent']);
    });

    test('a name starting with «إل» is not taken for the article: «إلهام» ≠ «هام»', () {
      final index = indexOf([
        doc('important', title: 'مهمة هام: تجديد جواز السفر'),
        doc('ilham', title: 'عيد ميلاد إلهام'),
      ]);
      expect(ids(find(index, 'إلهام')), ['ilham']);
      expect(ids(find(index, 'هام')), ['important']);
    });
  });
}
