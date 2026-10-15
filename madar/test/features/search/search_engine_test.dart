import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/domain/arabic_search.dart';
import 'package:madar/features/search/search.dart';

import '../../core/db/fixtures.dart';

MadarDatabase memoryDb() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

final DateTime now = DateTime(2026, 9, 30, 12);

SearchEngine engineFor(
  MadarDatabase db, {
  SearchRegistry? registry,
  String language = 'en',
  SearchWorkerFactory? worker,
  Duration debounce = const Duration(milliseconds: 20),
}) => SearchEngine(
  db: db,
  registry: registry ?? SearchRegistry(BuiltInSearchSources.all()),
  workerFactory: worker ?? () async => InlineSearchWorker(),
  clock: () => now,
  debounce: debounce,
  context: () async => SearchLoadContext(
    repos: Repositories(db),
    l10n: lookupL10n(Locale(language)),
    formatter: MadarFormatter(languageCode: language),
  ),
);

List<String> titles(SearchResults r) => [for (final h in r.hits) h.doc.title];

/// Waits for the engine's next index update.
Future<void> nextUpdate(SearchEngine e) => e.changes.first.timeout(const Duration(seconds: 5));

/// Polls [condition] until it holds (the database reports table changes
/// asynchronously, then the engine debounces them).
Future<void> eventually(FutureOr<bool> Function() condition, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  group('engine over the fixtures', () {
    late MadarDatabase db;
    late SearchEngine engine;

    setUp(() async {
      db = memoryDb();
      await populateAllTables(db);
      engine = engineFor(db);
    });

    tearDown(() async {
      await engine.dispose();
      await db.close();
    });

    test('is lazy: nothing is read until first use', () async {
      expect(engine.status.value, SearchEngineStatus.idle);
      await engine.warmUp();
      expect(engine.status.value, SearchEngineStatus.ready);
      final stats = await engine.stats();
      expect(stats.docs, greaterThan(50));
      expect(stats.docsBySource.keys, containsAll(['tasks', 'transactions', 'custom_entries', 'board_cards']));
    });

    test('finds records of every planet', () async {
      Future<List<String>> sources(String q) async => [for (final h in (await engine.search(SearchRequest(q))).hits) h.doc.sourceId];
      expect(await sources('مهمة'), contains('tasks'));
      expect(await sources('checkup'), contains('appointments'));
      expect(await sources('someone'), containsAll(['debts', 'board_cards']));
      expect(await sources('Somewhere'), contains('trips'));
      expect(await sources('exercise'), containsAll(['exercises', 'workout_logs']));
      expect(await sources('pages'), containsAll(['custom_modules', 'custom_entries', 'learning_goals']));
      expect(await sources('الكرسي'), contains('quran_bookmarks'));
    });

    test('results carry counts per planet and group, and filters apply', () async {
      final all = await engine.search(const SearchRequest('sparse'));
      expect(all.unfilteredTotal, greaterThan(10));
      expect(all.planetTotals.keys, containsAll(['health', 'money', 'work', 'travel', 'body']));
      final money = await engine.search(const SearchRequest('sparse', planets: {'money'}));
      expect(money.hits.map((h) => h.doc.planetKey).toSet(), {'money'});
      expect(money.counts, all.counts); // counts ignore the filter
      final wallets = await engine.search(const SearchRequest('sparse', groups: {'wallets'}));
      expect(wallets.hits.map((h) => h.doc.sourceId).toSet(), {'wallets'});
      expect(wallets.groups.single.key, 'wallets');
    });

    test('grouping: groups in order of their best hit, with full counts', () async {
      final r = await engine.search(const SearchRequest('sparse', limit: 5));
      expect(r.hits, hasLength(5));
      final groups = r.groups;
      expect(groups.first.hits.first, r.hits.first);
      for (final g in groups) {
        expect(g.count, greaterThanOrEqualTo(g.hits.length));
      }
    });
  });

  group('incremental updates', () {
    late MadarDatabase db;
    late Repositories repos;
    late SearchEngine engine;

    setUp(() async {
      db = memoryDb();
      repos = Repositories(db);
      engine = engineFor(db);
      await engine.warmUp();
    });

    tearDown(() async {
      await engine.dispose();
      await db.close();
    });

    test('insert, update and delete are followed', () async {
      expect((await engine.search(const SearchRequest('pharmacy'))).hits, isEmpty);

      var update = nextUpdate(engine);
      final task = await repos.tasks.insert(TasksCompanion.insert(title: 'Pharmacy run', notes: const Value('insulin')));
      await update;
      expect(titles(await engine.search(const SearchRequest('pharmacy'))), ['Pharmacy run']);
      expect(titles(await engine.search(const SearchRequest('insulin'))), ['Pharmacy run']);

      update = nextUpdate(engine);
      await repos.tasks.update(task.copyWith(title: 'Bakery run'));
      await update;
      expect((await engine.search(const SearchRequest('pharmacy'))).hits, isEmpty);
      expect(titles(await engine.search(const SearchRequest('bakery'))), ['Bakery run']);

      update = nextUpdate(engine);
      await repos.tasks.delete(task.id);
      await update;
      expect((await engine.search(const SearchRequest('bakery'))).hits, isEmpty);
    });

    test('bursts of changes are debounced into one update', () async {
      final slow = engineFor(db, debounce: const Duration(milliseconds: 250));
      addTearDown(slow.dispose);
      await slow.warmUp();
      final updates = <int>[];
      final sub = slow.changes.listen(updates.add);
      addTearDown(sub.cancel);
      await db.transaction(() async {
        for (var i = 0; i < 20; i++) {
          await repos.tasks.insert(TasksCompanion.insert(title: 'burst $i'));
        }
      });
      for (var i = 0; i < 5; i++) {
        await repos.tasks.insert(TasksCompanion.insert(title: 'burst extra $i'));
      }
      await eventually(() => updates.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(updates, hasLength(1));
      expect((await slow.search(const SearchRequest('burst'))).total, 25);
    });

    test('a parent change re-writes dependent records (wallet renamed)', () async {
      final wallet = await repos.wallets.insert(WalletsCompanion.insert(name: 'Pocket', currency: 'JOD'));
      await repos.transactions.insert(
        TransactionsCompanion.insert(walletId: wallet.id, kind: TxKind.expense, amountMilli: 2500, date: now, note: const Value('lunch')),
      );
      await eventually(() async {
        final r = await engine.search(const SearchRequest('lunch pocket'));
        return !r.partial && r.hits.length == 1;
      });
      await repos.wallets.update(wallet.copyWith(name: 'Travel card'));
      await eventually(() async {
        final r = await engine.search(const SearchRequest('lunch travel card'));
        return !r.partial && r.hits.length == 1 && r.hits.single.doc.sourceId == 'transactions';
      });
      expect((await engine.search(const SearchRequest('lunch pocket'))).partial, isTrue);
    });

    test('only changed records are sent to the index', () async {
      final recorder = _RecordingWorker();
      final e = engineFor(db, worker: () async => recorder);
      addTearDown(e.dispose);
      final listening = e.changes.listen((_) {}); // an open search screen
      addTearDown(listening.cancel);
      await repos.tasks.insert(TasksCompanion.insert(title: 'first'));
      await repos.tasks.insert(TasksCompanion.insert(title: 'second'));
      await e.warmUp();
      recorder.deltas.clear();
      final third = await repos.tasks.insert(TasksCompanion.insert(title: 'third'));
      await eventually(() => recorder.deltas.isNotEmpty);
      final upserts = [for (final d in recorder.deltas) ...d.upserts];
      expect(upserts.map((d) => d.title), ['third']);
      recorder.deltas.clear();
      await repos.tasks.delete(third.id);
      await eventually(() => recorder.deltas.isNotEmpty);
      expect([for (final d in recorder.deltas) ...d.removals], ['tasks\u0001${third.id}']);
      expect([for (final d in recorder.deltas) ...d.upserts], isEmpty);
    });

    test('while no search screen listens, changes wait for the next query', () async {
      final recorder = _RecordingWorker();
      final e = engineFor(db, worker: () async => recorder);
      addTearDown(e.dispose);
      await e.warmUp();
      recorder.deltas.clear();
      await repos.tasks.insert(TasksCompanion.insert(title: 'Deferred errand'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(recorder.deltas, isEmpty); // nothing re-read in the background
      expect(titles(await e.search(const SearchRequest('errand'))), ['Deferred errand']);
      expect(recorder.deltas, isNotEmpty);
    });

    test('key/value writes (settings, recent searches) never touch the index', () async {
      final updates = <int>[];
      final sub = engine.changes.listen(updates.add);
      addTearDown(sub.cancel);
      await RecentSearchesStore(repos.keyValues).add('secret query');
      await repos.keyValues.setJson('prayer.config', {'x': 1});
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updates, isEmpty);
      expect((await engine.search(const SearchRequest('secret'))).hits, isEmpty);
    });
  });

  group('registry', () {
    test('sources registered later are indexed; unregistered ones leave the index', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final registry = SearchRegistry(BuiltInSearchSources.all());
      final engine = engineFor(db, registry: registry);
      addTearDown(engine.dispose);
      await engine.warmUp();

      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      var games = ['Sudoku', 'Word search'];
      var update = nextUpdate(engine);
      registry.register(
        SearchSource.static(
          id: 'games',
          planetKey: 'growth',
          icon: Icons.sports_esports_rounded,
          labelKey: 'games',
          label: (l) => 'Games',
          changes: changes.stream,
          docs: (ctx) => [
            for (final g in games) SearchDoc(id: g, refTable: 'games', refId: g, title: g, planetKey: 'growth'),
          ],
        ),
      );
      await update;
      final r = await engine.search(const SearchRequest('sudoku'));
      expect(titles(r), ['Sudoku']);
      expect(r.hits.single.doc.sourceId, 'games');
      expect(registry['games']!.label(lookupL10n(const Locale('en'))), 'Games');

      games = ['Chess'];
      update = nextUpdate(engine);
      changes.add(null);
      await update;
      expect((await engine.search(const SearchRequest('sudoku'))).hits, isEmpty);
      expect(titles(await engine.search(const SearchRequest('chess'))), ['Chess']);

      update = nextUpdate(engine);
      expect(registry.unregister('games'), isTrue);
      await update;
      expect((await engine.search(const SearchRequest('chess'))).hits, isEmpty);
    });

    test('a failing source does not break the others', () async {
      final db = memoryDb();
      addTearDown(db.close);
      await Repositories(db).tasks.insert(TasksCompanion.insert(title: 'still here'));
      final registry = SearchRegistry([
        ...BuiltInSearchSources.all(),
        SearchSource(
          id: 'broken',
          planetKey: 'work',
          icon: Icons.error,
          labelKey: 'broken',
          load: (ctx) => throw StateError('boom'),
        ),
      ]);
      final engine = engineFor(db, registry: registry);
      addTearDown(engine.dispose);
      expect(titles(await engine.search(const SearchRequest('still'))), ['still here']);
      expect(engine.status.value, SearchEngineStatus.ready);
    });
  });

  group('live sources', () {
    const ayat = [
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
      'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
      'ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    ];
    final refs = [const AyahRef(1, 1), const AyahRef(1, 2), const AyahRef(1, 3)];
    final quran = QuranSearchSource.create(
      () async => (index: QuranSearchIndex(ayat, refs), ayahText: (int i) => ayat[i]),
    );

    test('Quran ayat are searched by the Quran index and merged in', () async {
      final db = memoryDb();
      addTearDown(db.close);
      await Repositories(db).tasks.insert(TasksCompanion.insert(title: 'تأمل الرحمن'));
      final engine = engineFor(db, registry: SearchRegistry([...BuiltInSearchSources.all(), quran]), language: 'ar');
      addTearDown(engine.dispose);
      final r = await engine.search(const SearchRequest('الرحمن'));
      final ayahHits = r.hits.where((h) => h.doc.sourceId == 'quran').toList();
      expect(ayahHits.map((h) => h.doc.refId), ['1:1', '1:3']);
      final first = ayahHits.first;
      expect(first.doc.openKey, 'quran.ayah');
      expect(first.doc.extra, {'surah': '1', 'ayah': '1'});
      expect(first.doc.title, 'سورة ١، الآية ١');
      expect(first.snippet, ayat[0]);
      expect(first.snippet.substring(first.snippetRanges.single.start, first.snippetRanges.single.end), 'ٱلرَّحْمَـٰنِ');
      expect(r.counts['faith']!['quran'], 2);
      expect(r.hits.any((h) => h.doc.sourceId == 'tasks'), isTrue);

      final onlyWork = await engine.search(const SearchRequest('الرحمن', planets: {'work'}));
      expect(onlyWork.hits.every((h) => h.doc.sourceId == 'tasks'), isTrue);
      expect(onlyWork.counts['faith']!['quran'], 2); // still counted for the chips
      final onlyQuran = await engine.search(const SearchRequest('الرحمن', groups: {'quran'}));
      expect(onlyQuran.hits.map((h) => h.doc.sourceId).toSet(), {'quran'});
    });

    test('a slow or failing live source never blocks the results', () async {
      final db = memoryDb();
      addTearDown(db.close);
      await Repositories(db).tasks.insert(TasksCompanion.insert(title: 'tea'));
      final failing = LiveSearchSource(
        id: 'broken',
        planetKey: 'faith',
        icon: Icons.error,
        labelKey: 'x',
        search: (q, ctx, {int limit = 20}) async => throw StateError('offline'),
      );
      final engine = engineFor(db, registry: SearchRegistry([...BuiltInSearchSources.all(), failing]));
      addTearDown(engine.dispose);
      expect(titles(await engine.search(const SearchRequest('tea'))), ['tea']);
    });

    test('long ayat are cut around the match', () {
      final text = '${'كلمة ' * 60}الرحمن ${'كلمة ' * 60}';
      final start = text.indexOf('الرحمن');
      final (snippet, ranges) = QuranSearchSource.cutAyah(text, [(start, start + 6)]);
      expect(snippet.startsWith('… '), isTrue);
      expect(snippet.endsWith(' …'), isTrue);
      expect(snippet.substring(ranges.single.start, ranges.single.end), 'الرحمن');
    });
  });

  group('recent searches', () {
    test('newest first, folded duplicates merged, capped, removable, clearable', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final store = RecentSearchesStore(Repositories(db).keyValues, max: 3);
      await store.add('الصلاة');
      await store.add('  meeting   omar ');
      await store.add('الصلاه'); // folds like «الصلاة»
      expect(await store.read(), ['الصلاه', 'meeting omar']);
      await store.add('a');
      await store.add('b');
      expect(await store.read(), ['b', 'a', 'الصلاه']);
      await store.add('   ');
      await store.add('?!');
      expect(await store.read(), hasLength(3));
      await store.remove('a');
      expect(await store.read(), ['b', 'الصلاه']);
      final watched = store.watch().first;
      expect(await watched, ['b', 'الصلاه']);
      await store.clear();
      expect(await store.read(), isEmpty);
    });
  });

  test('the isolate worker drives the engine end to end', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await populateAllTables(db);
    final engine = engineFor(db, worker: () => IsolateSearchWorker.spawn());
    addTearDown(engine.dispose);
    final r = await engine.search(const SearchRequest('checkup'));
    expect(r.hits.map((h) => h.doc.sourceId), contains('appointments'));
    expect(r.hits.first.titleRanges, isNotEmpty);
  });

  test('10k database rows are indexed through the engine in about a second', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await db.batch((b) {
      b.insertAll(db.tasks, [
        for (var i = 0; i < 10000; i++)
          TasksCompanion.insert(title: 'مهمة رقم $i اجتماع', notes: Value(i.isEven ? 'meeting notes $i' : null)),
      ]);
    });
    final engine = engineFor(db, worker: () => IsolateSearchWorker.spawn());
    addTearDown(engine.dispose);
    final w = Stopwatch()..start();
    await engine.warmUp();
    w.stop();
    // ignore: avoid_print
    print('engine warm-up with 10k rows (read + write-up + isolate index): ${w.elapsedMilliseconds} ms');
    expect((await engine.stats()).docs, 10000);
    expect(w.elapsedMilliseconds, lessThan(1500));
    final q = Stopwatch()..start();
    final r = await engine.search(const SearchRequest('اجتماع meeting'));
    q.stop();
    expect(r.total, 5000);
    expect(q.elapsedMilliseconds, lessThan(60));
  });
}

class _RecordingWorker extends InlineSearchWorker {
  final List<SearchIndexDelta> deltas = [];

  @override
  Future<void> apply(SearchIndexDelta delta) {
    deltas.add(delta);
    return super.apply(delta);
  }
}
