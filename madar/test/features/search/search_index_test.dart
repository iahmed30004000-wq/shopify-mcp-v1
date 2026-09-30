import 'package:flutter_test/flutter_test.dart';
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
  String? group,
}) => SearchDoc(
  id: id,
  refTable: source,
  refId: id,
  title: title,
  subtitle: subtitle,
  body: body,
  date: date,
  planetKey: planet,
  group: group,
  sourceId: source,
);

SearchIndex indexOf(List<SearchDoc> docs, {SearchIndexLimits limits = const SearchIndexLimits()}) =>
    SearchIndex(limits: limits, clock: () => now)..apply(SearchIndexDelta(upserts: docs));

List<String> ids(SearchIndexResult r) => [for (final h in r.hits) h.doc.id];

SearchIndexResult find(
  SearchIndex index,
  String q, {
  Set<String> planets = const {},
  Set<String> groups = const {},
  Map<String, double> planetWeights = const {},
  Map<String, double> sourceWeights = const {},
}) => index.search(
  SearchIndexQuery(q, planets: planets, groups: groups, now: now, planetWeights: planetWeights, sourceWeights: sourceWeights),
);

String lit(String text, List<HighlightRange> ranges) => [for (final r in ranges) text.substring(r.start, r.end)].join('|');

void main() {
  group('matching', () {
    test('Arabic: diacritics, alef forms and taa marbuta are ignored both ways', () {
      final index = indexOf([
        doc('a', title: 'أَذْكَارُ الصَّبَاحِ'),
        doc('b', title: 'زيارة المستشفى'),
      ]);
      expect(ids(find(index, 'اذكار الصباح')), ['a']);
      expect(ids(find(index, 'أذكار')), ['a']);
      expect(ids(find(index, 'زياره')), ['b']);
      expect(ids(find(index, 'المستشفي')), ['b']);
    });

    test('digits: Arabic-Indic query finds Western digits and back', () {
      final index = indexOf([
        doc('a', title: 'دفعة ١٢٠ دينار'),
        doc('b', title: 'Room 12 booking'),
      ]);
      expect(ids(find(index, '120')), ['a']);
      expect(ids(find(index, '١٢')), unorderedEquals(['b', 'a']));
      expect(ids(find(index, 'room ١٢')), ['b']);
    });

    test('English is case-insensitive and matches prefixes', () {
      final index = indexOf([
        doc('a', title: 'Medication review'),
        doc('b', title: 'Meeting with Omar'),
        doc('c', title: 'Buy bread'),
      ]);
      expect(ids(find(index, 'MED')), ['a']);
      expect(ids(find(index, 'me')), unorderedEquals(['a', 'b']));
      expect(ids(find(index, 'om')), ['b']);
    });

    test('the Arabic article: «كتاب» finds «الكتاب» and «الكتاب» finds «كتاب»', () {
      final index = indexOf([
        doc('a', title: 'قراءة الكتاب'),
        doc('b', title: 'كتاب جديد'),
        doc('c', title: 'بالقلم'),
      ]);
      expect(ids(find(index, 'كتاب')), unorderedEquals(['a', 'b']));
      expect(ids(find(index, 'الكتاب')), unorderedEquals(['a', 'b']));
      expect(ids(find(index, 'قلم')), ['c']);
    });

    test('one typo is tolerated in words of five letters or more only', () {
      final index = indexOf([
        doc('a', title: 'Medicine cabinet'),
        doc('b', title: 'Meds list'),
        doc('c', title: 'موعد المستشفى'),
      ]);
      expect(ids(find(index, 'medecine')), ['a']); // substitution
      expect(ids(find(index, 'mediicne')), ['a']); // swapped letters
      expect(ids(find(index, 'medicin')), ['a']); // prefix anyway
      expect(ids(find(index, 'mads')), isEmpty); // 4 letters: exact or prefix only
      expect(ids(find(index, 'مستشفا')), ['c']);
    });

    test('a typo in a word still being typed', () {
      final index = indexOf([doc('a', title: 'Vaccination schedule')]);
      expect(ids(find(index, 'vacinat')), ['a']);
    });

    test('every word must match; otherwise the closest records are returned as partial', () {
      final index = indexOf([
        doc('a', title: 'Meeting with Omar'),
        doc('b', title: 'Meeting with Sara'),
        doc('c', title: 'Omar birthday'),
      ]);
      final both = find(index, 'omar meeting');
      expect(ids(both), ['a']);
      expect(both.partial, isFalse);
      final partial = find(index, 'omar zzzz');
      expect(partial.partial, isTrue);
      expect(ids(partial), unorderedEquals(['a', 'c']));
    });

    test('quoted words must appear together', () {
      final index = indexOf([
        doc('a', title: 'blood test results'),
        doc('b', title: 'test the blood pressure'),
      ]);
      expect(ids(find(index, 'blood test')), unorderedEquals(['a', 'b']));
      expect(ids(find(index, '"blood test"')), ['a']);
    });

    test('single letters and punctuation-only queries', () {
      final index = indexOf([doc('a', title: 'alpha'), doc('b', title: 'beta')]);
      expect(ids(find(index, 'a')), ['a']);
      expect(find(index, ' ،.? ').hits, isEmpty);
      expect(find(index, '').hits, isEmpty);
    });
  });

  group('ranking', () {
    test('a title match beats a subtitle match beats a body match', () {
      final index = indexOf([
        doc('body', title: 'Weekly plan', body: 'call the dentist'),
        doc('title', title: 'Dentist appointment'),
        doc('sub', title: 'Checkup', subtitle: 'Dentist clinic'),
      ]);
      expect(ids(find(index, 'dentist')), ['title', 'sub', 'body']);
    });

    test('an exact word beats a prefix; a shorter completion beats a longer one', () {
      final index = indexOf([
        doc('long', title: 'Carpentry'),
        doc('exact', title: 'Car'),
        doc('mid', title: 'Carpet'),
      ]);
      expect(ids(find(index, 'car')), ['exact', 'mid', 'long']);
    });

    test('an exact title and the words as a phrase are boosted', () {
      final index = indexOf([
        doc('scattered', title: 'test of blood levels'),
        doc('phrase', title: 'my blood test'),
        doc('exact', title: 'Blood test'),
      ]);
      expect(ids(find(index, 'blood test')), ['exact', 'phrase', 'scattered']);
    });

    test('recent (or soon due) records rank above old ones', () {
      final index = indexOf([
        doc('old', title: 'Pharmacy', date: now.subtract(const Duration(days: 400))),
        doc('recent', title: 'Pharmacy', date: now.subtract(const Duration(days: 2))),
        doc('soon', title: 'Pharmacy', date: now.add(const Duration(days: 10))),
      ]);
      expect(ids(find(index, 'pharmacy')), ['recent', 'soon', 'old']);
    });

    test('planet weight and source weight tip equal matches', () {
      final index = indexOf([
        doc('work', title: 'Review', planet: 'work'),
        doc('faith', title: 'Review', planet: 'faith'),
      ]);
      expect(ids(find(index, 'review', planetWeights: {'faith': 2, 'work': 1})).first, 'faith');
      expect(ids(find(index, 'review', planetWeights: {'faith': 0.5, 'work': 1})).first, 'work');
      final logs = indexOf([
        doc('log', title: 'Fajr', source: 'prayer_logs'),
        doc('task', title: 'Fajr', source: 'tasks'),
      ]);
      expect(ids(find(logs, 'fajr', sourceWeights: {'prayer_logs': 0.6})).first, 'task');
    });

    test('rare words weigh more than common ones', () {
      final index = indexOf([
        for (var i = 0; i < 20; i++) doc('common$i', title: 'note', body: 'note'),
        doc('rare', title: 'note', body: 'zakat'),
        doc('both', title: 'zakat'),
      ]);
      expect(ids(find(index, 'zakat')).first, 'both');
    });
  });

  group('filters and counts', () {
    final index = indexOf([
      doc('t1', title: 'Omar call', planet: 'family', source: 'people'),
      doc('t2', title: 'Omar lunch', planet: 'family', source: 'contact_logs'),
      doc('t3', title: 'Omar invoice', planet: 'money', source: 'transactions'),
      doc('t4', title: 'Omar reading log', planet: 'custom', source: 'custom_entries', group: 'module:m1'),
    ]);

    test('counts are before the filters, hits after', () {
      final r = find(index, 'omar', planets: {'family'});
      expect(ids(r), unorderedEquals(['t1', 't2']));
      expect(r.total, 2);
      expect(r.counts, {
        'family': {'people': 1, 'contact_logs': 1},
        'money': {'transactions': 1},
        'custom': {'module:m1': 1},
      });
    });

    test('group filter uses the custom module group', () {
      expect(ids(find(index, 'omar', groups: {'module:m1'})), ['t4']);
      expect(ids(find(index, 'omar', groups: {'transactions', 'people'})), unorderedEquals(['t1', 't3']));
    });
  });

  group('highlights', () {
    test('ranges point into the original text, diacritics included', () {
      const title = 'أَذْكَارُ المَسَاءِ';
      final r = find(indexOf([doc('a', title: title)]), 'اذكار');
      expect(lit(title, r.hits.single.titleRanges), 'أَذْكَارُ');
    });

    test('a prefix lights only the typed part; an article-less match skips the article', () {
      final index = indexOf([doc('a', title: 'Medication', subtitle: 'في الكتاب')]);
      final r = find(index, 'medi كتاب');
      final hit = r.hits.single;
      expect(lit('Medication', hit.titleRanges), 'Medi');
      expect(lit('في الكتاب', hit.subtitleRanges), 'كتاب');
    });

    test('Arabic-Indic digits in the text light up for a Western query', () {
      const title = 'غرفة ١٢٠';
      final r = find(indexOf([doc('a', title: title)]), '120');
      expect(lit(title, r.hits.single.titleRanges), '١٢٠');
    });

    test('long bodies become a one-line snippet around the first match', () {
      final body = '${'filler words here. ' * 20}\nthe insulin dose changed\n${'more text. ' * 20}';
      final r = find(indexOf([doc('a', title: 'Notes', body: body)]), 'insulin');
      final hit = r.hits.single;
      expect(hit.doc.body, isEmpty); // the body travels as the snippet only
      expect(hit.snippet.startsWith('…'), isTrue);
      expect(hit.snippet.endsWith('…'), isTrue);
      expect(hit.snippet.contains('\n'), isFalse);
      expect(hit.snippet.length, lessThanOrEqualTo(SearchIndex.snippetLength + 2));
      expect(lit(hit.snippet, hit.snippetRanges), 'insulin');
    });

    test('short bodies are shown whole', () {
      final r = find(indexOf([doc('a', title: 'x', body: 'take with water')]), 'water');
      expect(r.hits.single.snippet, 'take with water');
      expect(lit('take with water', r.hits.single.snippetRanges), 'water');
    });

    test('highlightQuery helper', () {
      expect(lit('Call Omar at noon', SearchIndex.highlightQuery('Call Omar at noon', 'omar no')), 'Omar|no');
    });
  });

  group('incremental updates', () {
    test('upsert replaces a record; its old words stop matching', () {
      final index = indexOf([doc('a', title: 'Buy milk')]);
      expect(ids(find(index, 'milk')), ['a']);
      index.upsert(doc('a', title: 'Buy bread'));
      expect(find(index, 'milk').hits, isEmpty);
      expect(ids(find(index, 'bread')), ['a']);
      expect(index.length, 1);
    });

    test('remove and clearSource drop records and their terms', () {
      final index = indexOf([
        doc('a', title: 'alpha unique1'),
        doc('b', title: 'beta unique2'),
        doc('c', title: 'gamma', source: 'people'),
      ]);
      final before = index.stats;
      expect(index.remove('tasks\u0001a'), isTrue);
      expect(index.remove('tasks\u0001a'), isFalse);
      expect(find(index, 'unique1').hits, isEmpty);
      expect(index.stats.terms, lessThan(before.terms));
      index.clearSource('tasks');
      expect(index.length, 1);
      expect(ids(find(index, 'gamma')), ['c']);
      expect(index.stats.docsBySource, {'people': 1});
    });

    test('freed slots are reused and postings stay consistent', () {
      final index = indexOf([]);
      for (var round = 0; round < 5; round++) {
        index.apply(SearchIndexDelta(upserts: [for (var i = 0; i < 50; i++) doc('d$i', title: 'round$round item$i')]));
      }
      expect(index.length, 50);
      expect(find(index, 'round4').total, 50);
      expect(find(index, 'round3').total, 0);
      expect(index.stats.postings, index.stats.docs * 2 + 0); // «roundN» + «itemI» per record
    });

    test('a delta applies clears, removals and upserts in order', () {
      final index = indexOf([doc('a', title: 'one'), doc('b', title: 'two', source: 'people')]);
      index.apply(
        SearchIndexDelta(
          clearSources: {'people'},
          removals: ['tasks\u0001a'],
          upserts: [doc('c', title: 'three')],
        ),
      );
      expect(index.length, 1);
      expect(index.contains('tasks\u0001c'), isTrue);
    });
  });

  group('limits', () {
    test('beyond maxDocs the oldest dated records are dropped first', () {
      final index = indexOf(
        [
          for (var i = 0; i < 30; i++) doc('d$i', title: 'entry', date: DateTime(2020).add(Duration(days: i))),
          doc('undated', title: 'entry'),
        ],
        limits: const SearchIndexLimits(maxDocs: 20),
      );
      expect(index.length, lessThanOrEqualTo(20));
      expect(index.contains('tasks\u0001undated'), isTrue);
      expect(index.contains('tasks\u0001d29'), isTrue);
      expect(index.contains('tasks\u0001d0'), isFalse);
      expect(index.stats.evicted, greaterThan(0));
    });

    test('long fields are cut before indexing', () {
      final index = indexOf([
        doc('a', title: 'x', body: '${'word ' * 1000}needle'),
      ], limits: const SearchIndexLimits(maxBodyChars: 200));
      expect(find(index, 'needle').hits, isEmpty);
      expect(index.doc('tasks\u0001a')!.body.length, 200);
    });
  });
}
