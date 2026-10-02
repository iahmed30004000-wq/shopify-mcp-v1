import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/search/data/search_worker.dart';
import 'package:madar/features/search/domain/search_doc.dart';
import 'package:madar/features/search/domain/search_index.dart';

const _arabic = [
  'اجتماع', 'العمل', 'الصباح', 'المساء', 'دواء', 'الطبيب', 'موعد', 'المستشفى', 'زيارة', 'الأهل', 'شراء', 'خبز', //
  'حليب', 'فاتورة', 'الكهرباء', 'راتب', 'تحويل', 'محفظة', 'سفر', 'جواز', 'تذكرة', 'فندق', 'مشروع', 'تقرير', //
  'مراجعة', 'قراءة', 'كتاب', 'تمرين', 'مشي', 'سباحة', 'صيام', 'صلاة', 'الفجر', 'المغرب', 'ذكر', 'قرآن', //
  'حفظ', 'سورة', 'دعاء', 'صدقة', 'هدية', 'عيد', 'ميلاد', 'أمي', 'أبي', 'أخي', 'صديقي', 'جاري', 'المدرسة', //
  'الجامعة', 'امتحان', 'واجب', 'سيارة', 'صيانة', 'بنزين', 'إيجار', 'قرض', 'دين', 'ادخار', 'حصالة', 'ميزانية',
];

const _english = [
  'meeting', 'report', 'review', 'doctor', 'medication', 'pharmacy', 'appointment', 'blood', 'test', 'results', //
  'invoice', 'salary', 'transfer', 'wallet', 'budget', 'savings', 'trip', 'passport', 'ticket', 'hotel', //
  'project', 'deadline', 'client', 'design', 'launch', 'reading', 'book', 'workout', 'running', 'swimming', //
  'fasting', 'prayer', 'family', 'mother', 'father', 'brother', 'friend', 'birthday', 'gift', 'school', //
  'exam', 'homework', 'car', 'service', 'fuel', 'rent', 'loan', 'groceries', 'bread', 'milk', 'coffee', 'call',
];

const _planets = ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'];
const _sources = ['tasks', 'transactions', 'people', 'medications', 'board_cards', 'workout_logs', 'trips', 'custom_entries'];

List<SearchDoc> syntheticDocs(int n, {int seed = 42}) {
  final rnd = Random(seed);
  String words(int count) {
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final r = rnd.nextInt(10);
      if (r < 5) {
        out.add(_arabic[rnd.nextInt(_arabic.length)]);
      } else if (r < 9) {
        out.add(_english[rnd.nextInt(_english.length)]);
      } else {
        out.add('${rnd.nextInt(5000)}');
      }
    }
    return out.join(' ');
  }

  final base = DateTime(2026, 9, 30);
  return [
    for (var i = 0; i < n; i++)
      SearchDoc(
        id: 'd$i',
        refTable: _sources[i % _sources.length],
        refId: 'd$i',
        title: words(2 + rnd.nextInt(5)),
        subtitle: rnd.nextBool() ? words(2) : '',
        body: rnd.nextInt(10) < 4 ? words(10 + rnd.nextInt(25)) : '',
        date: base.subtract(Duration(days: rnd.nextInt(900))),
        planetKey: _planets[rnd.nextInt(_planets.length)],
        sourceId: _sources[i % _sources.length],
      ),
  ];
}

const _queries = [
  'دواء',
  'meeting',
  'الصباح',
  'medica',
  'اجتماع العمل',
  'medicatoin', // typo
  'م', // one letter
  '١٢',
  '"blood test"',
  'موعد الطبيب',
  'قران',
  'passport ticket hotel',
];

void main() {
  test('10k records index in under a second; queries answer in under 30 ms', () {
    final docs = syntheticDocs(10000);
    final index = SearchIndex(clock: () => DateTime(2026, 9, 30));
    final build = Stopwatch()..start();
    index.apply(SearchIndexDelta(upserts: docs));
    build.stop();
    final stats = index.stats;
    // ignore: avoid_print
    print('index build: ${build.elapsedMilliseconds} ms, $stats');
    expect(index.length, 10000);
    expect(build.elapsedMilliseconds, lessThan(1000));

    // One warm-up pass (JIT), then the measured passes.
    for (final q in _queries) {
      index.search(SearchIndexQuery(q));
    }
    final timings = <String, int>{};
    for (final q in _queries) {
      var worst = 0;
      for (var run = 0; run < 3; run++) {
        final w = Stopwatch()..start();
        final r = index.search(SearchIndexQuery(q));
        w.stop();
        worst = max(worst, w.elapsedMicroseconds);
        expect(r.hits, isNotEmpty, reason: 'query «$q» should match the synthetic data');
      }
      timings[q] = worst;
    }
    // ignore: avoid_print
    print('query worst-case µs: $timings');
    for (final MapEntry(key: q, value: us) in timings.entries) {
      expect(us, lessThan(30000), reason: 'query «$q» took ${us / 1000} ms');
    }
  });

  test('incremental updates on a 10k index are cheap', () {
    final docs = syntheticDocs(10000);
    final index = SearchIndex()..apply(SearchIndexDelta(upserts: docs));
    final w = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      index.upsert(docs[i].copyWith(title: 'changed title $i'));
    }
    for (var i = 200; i < 400; i++) {
      index.remove(docs[i].indexKey);
    }
    w.stop();
    expect(index.length, 9800);
    expect(w.elapsedMilliseconds, lessThan(300));
  });

  test('memory stays bounded: a 10k index is a few MB', () {
    final index = SearchIndex()..apply(SearchIndexDelta(upserts: syntheticDocs(10000)));
    expect(index.stats.approxBytes, lessThan(24 * 1024 * 1024));
  });

  test('the isolate worker indexes 10k records and answers in the background', () async {
    final worker = await IsolateSearchWorker.spawn();
    addTearDown(worker.close);
    final docs = syntheticDocs(10000);
    final build = Stopwatch()..start();
    for (var i = 0; i < docs.length; i += 2500) {
      await worker.apply(SearchIndexDelta(upserts: docs.sublist(i, min(i + 2500, docs.length))));
    }
    final stats = await worker.stats();
    build.stop();
    // ignore: avoid_print
    print('isolate build (incl. transfer): ${build.elapsedMilliseconds} ms');
    expect(stats.docs, 10000);
    expect(build.elapsedMilliseconds, lessThan(2000));

    await worker.search(const SearchIndexQuery('warm up'));
    final w = Stopwatch()..start();
    final r = await worker.search(const SearchIndexQuery('موعد الطبيب', limit: 60));
    w.stop();
    // ignore: avoid_print
    print('isolate round trip: ${w.elapsedMicroseconds} µs (index ${r.elapsedMicros} µs)');
    expect(r.hits, isNotEmpty);
    expect(r.elapsedMicros, lessThan(30000));
    expect(w.elapsedMilliseconds, lessThan(60));
  });

  test('the isolate worker reports errors and refuses work once closed', () async {
    final worker = await IsolateSearchWorker.spawn();
    await worker.apply(SearchIndexDelta(upserts: syntheticDocs(10)));
    expect((await worker.stats()).docs, 10);
    await worker.close();
    expect(() => worker.search(const SearchIndexQuery('x')), throwsStateError);
  });
}
