// Regression tests (from systems probes): performance of the global search
// at the sizes the spec allows (20k–60k records) – removals linear in their
// number, the UI isolate never blocked for long, keystrokes answered fast,
// edits never grow the index. All but the memory test failed before.
//
// Run alone: flutter test test/features/search/systems_perf_regression_test.dart -j 1 -r expanded --exclude-tags screenshot
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';

/// Like the app (`core/db/open.dart`): SQLite on a background isolate, so
/// only Dart-side work lands on the UI isolate.
MadarDatabase _backgroundDb() {
  final dir = Directory.systemTemp.createTempSync('madar_search_probe');
  addTearDown(() => dir.deleteSync(recursive: true));
  return MadarDatabase(DatabaseConnection(NativeDatabase.createInBackground(File('${dir.path}/db.sqlite'))));
}

final DateTime _now = DateTime(2026, 9, 30, 12);

SearchEngine _engine(MadarDatabase db, {SearchWorkerFactory? worker, String language = 'ar'}) => SearchEngine(
  db: db,
  registry: SearchRegistry(BuiltInSearchSources.all()),
  workerFactory: worker ?? () => IsolateSearchWorker.spawn(),
  clock: () => _now,
  debounce: const Duration(milliseconds: 50),
  context: () async => SearchLoadContext(
    repos: Repositories(db),
    l10n: lookupL10n(Locale(language)),
    formatter: MadarFormatter(languageCode: language),
  ),
);

const _notes = [
  'خبز وحليب', 'فاتورة الكهرباء', 'بنزين السيارة', 'غداء مع الزملاء', 'دواء الضغط', 'هدية عيد ميلاد', //
  'إيجار الشقة', 'صيانة السيارة', 'قهوة', 'اشتراك الإنترنت', 'ملابس العيد', 'كتب المدرسة', 'تبرع للمسجد', //
  'فطور رمضان', 'تذكرة سفر', 'فندق إسطنبول', 'مواصلات', 'خضار وفواكه', 'لحم ودجاج', 'حلويات',
];

const _taskWords = [
  'اجتماع', 'العمل', 'مراجعة', 'تقرير', 'الاتصال', 'بأمي', 'شراء', 'دواء', 'الطبيب', 'موعد', 'زيارة', 'الأهل', //
  'قراءة', 'كتاب', 'تمرين', 'مشي', 'حفظ', 'سورة', 'صدقة', 'المشروع', 'العميل', 'التصميم', 'إطلاق', 'الموقع',
];

/// [transactions] transactions in two wallets (half each) and [tasks] tasks,
/// spread over five years, written straight into the database.
Future<({String bigWallet})> _seed(MadarDatabase db, {required int transactions, required int tasks}) async {
  final rnd = Random(7);
  final r = Repositories(db);
  final cash = await r.wallets.insert(WalletsCompanion.insert(name: 'المحفظة النقدية', currency: 'JOD'));
  final bank = await r.wallets.insert(WalletsCompanion.insert(name: 'الحساب البنكي', currency: 'JOD'));
  const chunk = 5000;
  for (var start = 0; start < transactions; start += chunk) {
    await db.batch((b) {
      b.insertAll(db.transactions, [
        for (var i = start; i < min(start + chunk, transactions); i++)
          TransactionsCompanion.insert(
            walletId: i.isEven ? cash.id : bank.id,
            kind: TxKind.expense,
            amountMilli: 500 + rnd.nextInt(90000),
            date: _now.subtract(Duration(days: rnd.nextInt(1800))),
            note: Value('${_notes[rnd.nextInt(_notes.length)]} $i'),
          ),
      ]);
    });
  }
  for (var start = 0; start < tasks; start += chunk) {
    await db.batch((b) {
      b.insertAll(db.tasks, [
        for (var i = start; i < min(start + chunk, tasks); i++)
          TasksCompanion.insert(
            title: [for (var k = 0; k < 3 + rnd.nextInt(3); k++) _taskWords[rnd.nextInt(_taskWords.length)]].join(' '),
            date: Value(_now.subtract(Duration(days: rnd.nextInt(1800)))),
            notes: Value(rnd.nextInt(4) == 0 ? 'ملاحظة رقم $i عن ${_taskWords[rnd.nextInt(_taskWords.length)]}' : null),
          ),
      ]);
    });
  }
  return (bigWallet: cash.id);
}

/// Longest time the event loop of this (the UI) isolate was blocked while
/// [body] ran.
Future<(T, Duration)> _maxBlock<T>(Future<T> Function() body) async {
  var last = DateTime.now();
  var worst = Duration.zero;
  final timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    final t = DateTime.now();
    final gap = t.difference(last);
    if (gap > worst) worst = gap;
    last = t;
  });
  try {
    final v = await body();
    return (v, worst);
  } finally {
    timer.cancel();
  }
}

SearchDoc _txDoc(int i, {required String wallet}) => SearchDoc(
  id: 'tx$i',
  refTable: 'transactions',
  refId: 'tx$i',
  title: '${_notes[i % _notes.length]} $i',
  subtitle: '${(i % 90) + 1}.500 د.أ، مصروف، $wallet',
  date: _now.subtract(Duration(days: i % 1800)),
  planetKey: 'money',
  sourceId: 'transactions',
);

Duration _timeRemoval(int total) {
  final index = SearchIndex(clock: () => _now);
  index.apply(
    SearchIndexDelta(
      upserts: [for (var i = 0; i < total; i++) _txDoc(i, wallet: i.isEven ? 'المحفظة النقدية' : 'الحساب البنكي')],
    ),
  );
  final w = Stopwatch()..start();
  index.apply(SearchIndexDelta(removals: [for (var i = 0; i < total; i += 2) 'transactions\u0001tx$i']));
  w.stop();
  expect(index.length, total - total ~/ 2);
  return w.elapsed;
}

void main() {
  test('removing records costs time linear in their number (wallet deleted: its half of the transactions)', () {
    _timeRemoval(4000); // warm the JIT
    final small = _timeRemoval(20000);
    final large = _timeRemoval(60000);
    final ratio = large.inMicroseconds / small.inMicroseconds;
    print(
      'remove 10k of 20k: ${small.inMilliseconds} ms; remove 30k of 60k: ${large.inMilliseconds} ms; ratio ${ratio.toStringAsFixed(1)} (linear = 3)',
    );
    // Three times the records should cost about three times as long.
    expect(ratio, lessThan(5));
  });

  test('a restore that replaces every record (60k new ids) keeps the index responsive', () {
    final index = SearchIndex(clock: () => _now);
    index.apply(
      SearchIndexDelta(
        upserts: [for (var i = 0; i < 60000; i++) _txDoc(i, wallet: i.isEven ? 'المحفظة النقدية' : 'الحساب البنكي')],
      ),
    );
    final w = Stopwatch()..start();
    index.apply(SearchIndexDelta(removals: [for (var i = 0; i < 60000; i++) 'transactions\u0001tx$i']));
    w.stop();
    print('remove all 60k: ${w.elapsedMilliseconds} ms');
    expect(index.length, 0);
    expect(w.elapsedMilliseconds, lessThan(1000));
  });

  test('memory: many rounds of edits leave the index the size of a freshly built one', () {
    SearchDoc doc(int i, int round) => SearchDoc(
      id: 'd$i',
      refTable: 'tasks',
      refId: 'd$i',
      title: 'مهمة $i نسخة$round كلمة${i * 31 + round}',
      body: round.isEven ? 'ملاحظة جديدة ${i + round}' : '',
      date: _now.subtract(Duration(days: i % 500)),
      planetKey: 'work',
      sourceId: 'tasks',
    );
    final index = SearchIndex(clock: () => _now);
    index.apply(SearchIndexDelta(upserts: [for (var i = 0; i < 5000; i++) doc(i, 0)]));
    final latest = {for (var i = 0; i < 5000; i++) i: 0};
    for (var round = 1; round <= 40; round++) {
      final edited = [for (var i = round % 7; i < 5000; i += 7) i];
      index.apply(SearchIndexDelta(upserts: [for (final i in edited) doc(i, round)]));
      for (final i in edited) {
        latest[i] = round;
      }
      // Some records deleted and re-added.
      index.apply(SearchIndexDelta(removals: [for (var i = round; i < 5000; i += 97) 'tasks\u0001d$i']));
      index.apply(SearchIndexDelta(upserts: [for (var i = round; i < 5000; i += 97) doc(i, latest[i]!)]));
    }
    final fresh = SearchIndex(clock: () => _now)
      ..apply(SearchIndexDelta(upserts: [for (var i = 0; i < 5000; i++) doc(i, latest[i]!)]));
    final a = index.stats, b = fresh.stats;
    expect((a.docs, a.terms, a.postings), (b.docs, b.terms, b.postings));
    expect(a.approxBytes, b.approxBytes);
  });

  group('engine with 60k database rows (real isolate)', () {
    late MadarDatabase db;
    late SearchEngine engine;
    late String bigWallet;

    setUpAll(() async {
      db = _backgroundDb();
      final seeded = await _seed(db, transactions: 40000, tasks: 20000);
      bigWallet = seeded.bigWallet;
      engine = _engine(db);
    });

    tearDownAll(() async {
      await engine.dispose();
      await db.close();
    });

    test('first query: warm-up time and longest UI-isolate block', () async {
      final total = Stopwatch()..start();
      final (_, block) = await _maxBlock(() => engine.search(const SearchRequest('فاتورة')));
      total.stop();
      final stats = await engine.stats();
      print(
        'first query over ${stats.docs} records: ${total.elapsedMilliseconds} ms, '
        'UI isolate blocked up to ${block.inMilliseconds} ms, index ~${stats.approxBytes ~/ (1 << 20)} MB',
      );
      expect(stats.docs, lessThanOrEqualTo(60000));
      // A frame is 16 ms; the UI must never freeze for more than a few frames.
      expect(block.inMilliseconds, lessThan(100));
    });

    test('per-keystroke latency while typing (median of 3 per keystroke)', () async {
      await engine.warmUp();
      const typed = [
        'ف',
        'فا',
        'فات',
        'فاتو',
        'فاتور',
        'فاتورة',
        'فاتورة ا',
        'فاتورة ال',
        'فاتورة الكهرباء',
        'م',
        'ا',
        'ال',
        '1',
      ];
      final medians = <String, int>{};
      for (final q in typed) {
        final runs = <int>[];
        for (var i = 0; i < 3; i++) {
          final w = Stopwatch()..start();
          await engine.search(SearchRequest(q));
          runs.add(w.elapsedMilliseconds);
        }
        runs.sort();
        medians[q] = runs[1];
      }
      print('per-keystroke median ms: $medians');
      // Results "as you type": each keystroke should answer well within
      // 100 ms on this host (a phone is several times slower).
      expect(medians.values.reduce(max), lessThan(100), reason: '$medians');
    });

    test('an edit while a search screen is open blocks the UI isolate briefly', () async {
      await engine.warmUp();
      final listening = engine.changes.listen((_) {});
      addTearDown(listening.cancel);
      final repos = Repositories(db);
      final tx = (await repos.transactions.getAll(where: (t) => t.walletId.equals(bigWallet))).first;
      final (_, block) = await _maxBlock(() async {
        final update = engine.changes.first;
        await repos.transactions.update(tx.copyWith(note: const Value('تعديل واحد')));
        await update.timeout(const Duration(seconds: 30));
      });
      print('one transaction edited (screen open): UI isolate blocked up to ${block.inMilliseconds} ms');
      expect(block.inMilliseconds, lessThan(100));
    });

    test('deleting a wallet with 20k transactions: the next query answers promptly', () async {
      await engine.warmUp();
      final listening = engine.changes.listen((_) {});
      addTearDown(listening.cancel);
      final repos = Repositories(db);
      final applied = engine.changes.first;
      await repos.transactions.deleteWhere((t) => t.walletId.equals(bigWallet));
      await repos.wallets.delete(bigWallet);
      final w = Stopwatch()..start();
      await applied.timeout(const Duration(seconds: 120));
      final r = await engine.search(const SearchRequest('فاتورة'));
      w.stop();
      print('wallet with 20k transactions deleted: update + next query ${w.elapsedMilliseconds} ms');
      expect(r.hits.every((h) => h.doc.extra['walletId'] != bigWallet), isTrue);
      expect(w.elapsedMilliseconds, lessThan(1500));
    });
  });
}
