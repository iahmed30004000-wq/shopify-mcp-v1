// Regression tests (from systems probes): robustness of the global search –
// worker failures and hangs, rapid typing, the opener contract, disposal.
// Each test failed before its fix.
import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';

import 'search_harness.dart';

final DateTime _now = DateTime(2026, 9, 30, 12);

MadarDatabase _db() => MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

SearchEngine _engine(MadarDatabase db, SearchWorker worker) => SearchEngine(
  db: db,
  registry: SearchRegistry(BuiltInSearchSources.all()),
  workerFactory: () async => worker,
  clock: () => _now,
  debounce: const Duration(milliseconds: 20),
  context: () async => SearchLoadContext(
    repos: Repositories(db),
    l10n: lookupL10n(const Locale('en')),
    formatter: MadarFormatter(languageCode: 'en'),
  ),
);

List<String> _titles(SearchResults r) => [for (final h in r.hits) h.doc.title];

/// The index worker failing one request (the isolate's own failure mode:
/// [SearchWorkerException]).
class _FlakyWorker extends InlineSearchWorker {
  bool failNextApply = false;

  @override
  Future<void> apply(SearchIndexDelta delta) {
    if (failNextApply) {
      failNextApply = false;
      return Future.error(SearchWorkerException('simulated isolate failure'));
    }
    return super.apply(delta);
  }
}

/// A worker whose isolate stopped answering queries.
class _SilentWorker extends InlineSearchWorker {
  bool silent = false;

  @override
  Future<SearchIndexResult> search(SearchIndexQuery query) =>
      silent ? Completer<SearchIndexResult>().future : super.search(query);
}

void main() {
  group('worker failures', () {
    late MadarDatabase db;
    late Repositories repos;

    setUp(() {
      db = _db();
      repos = Repositories(db);
    });

    tearDown(() => db.close());

    // Engine work runs inside one guarded zone (as in an app that guards
    // `runApp`); assertions run outside it.
    test('one failed index update does not stop every later update', () async {
      final worker = _FlakyWorker();
      final engine = _engine(db, worker);
      addTearDown(engine.dispose);
      final uncaught = <Object>[];
      late List<String> found;
      await runZonedGuarded(() async {
        await engine.warmUp();
        final screen = engine.changes.listen((_) {}); // a search screen is open
        worker.failNextApply = true;
        await repos.tasks.insert(TasksCompanion.insert(title: 'first errand'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await repos.tasks.insert(TasksCompanion.insert(title: 'second errand'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        found = _titles(await engine.search(const SearchRequest('errand')));
        await screen.cancel();
      }, (e, _) => uncaught.add(e));

      expect(found, contains('second errand'), reason: 'later changes are never indexed again; uncaught: $uncaught');
      expect(found, contains('first errand'), reason: 'the failed record is marked as indexed and never re-sent');
    });

    test('after a failed update, queries still answer (screen closed, then reopened)', () async {
      final worker = _FlakyWorker();
      final engine = _engine(db, worker);
      addTearDown(engine.dispose);
      SearchResults? results;
      Object? searchError;
      await runZonedGuarded(() async {
        await engine.warmUp();
        final screen = engine.changes.listen((_) {});
        worker.failNextApply = true;
        await repos.tasks.insert(TasksCompanion.insert(title: 'first errand'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await screen.cancel(); // the search screen is closed
        await repos.tasks.insert(TasksCompanion.insert(title: 'second errand'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // The next time the user searches:
        try {
          results = await engine.search(const SearchRequest('errand'));
        } on Object catch (e) {
          searchError = e;
        }
      }, (e, _) {});

      expect(searchError, isNull, reason: 'search() throws – the screen never shows results again');
      expect(_titles(results!), contains('second errand'));
    });

    test('a failed update while indexing at start-up does not leave the other sources out for good', () async {
      await repos.tasks.insert(TasksCompanion.insert(title: 'task errand'));
      await repos.people.insert(PeopleCompanion.insert(name: 'Umm Ahmad'));
      final worker = _FlakyWorker()..failNextApply = true; // tasks are indexed first
      final engine = _engine(db, worker);
      addTearDown(engine.dispose);
      await engine.warmUp();
      final r = await engine.search(const SearchRequest('ahmad'));
      expect(engine.status.value, isNot(SearchEngineStatus.failed));
      expect(_titles(r), ['Umm Ahmad']);
    });

    test('a worker that stops answering does not hang the search forever', () async {
      await repos.tasks.insert(TasksCompanion.insert(title: 'tea'));
      final worker = _SilentWorker();
      final engine = _engine(db, worker);
      addTearDown(engine.dispose);
      expect(_titles(await engine.search(const SearchRequest('tea'))), ['tea']);
      worker.silent = true; // e.g. the isolate died or is stuck in a long update
      await expectLater(
        engine.search(const SearchRequest('tea')).timeout(const Duration(seconds: 8)),
        completes,
        reason: 'no timeout or fallback on worker calls',
      );
    });
  });

  group('screen', () {
    testWidgets('results of a query typed before «clear» never show up for the next query', (tester) async {
      final env = await pumpSearchApp(tester, locale: const Locale('en'));
      // A live source the probe can hold, so a query stays in flight.
      Completer<void>? gate;
      env.container
          .read(searchRegistryProvider)
          .register(
            LiveSearchSource(
              id: 'slow',
              planetKey: 'work',
              icon: Icons.hourglass_empty,
              labelKey: 'slow',
              search: (q, ctx, {int limit = 20}) async {
                await gate?.future;
                return LiveSearchResult.empty;
              },
            ),
          );
      await settle(tester);

      // Steps 300 ms apart (longer than the screen's 220 ms cross-fade).
      gate = Completer<void>();
      await tester.enterText(find.byType(TextField), 'pharmacy');
      await tester.pump(const Duration(milliseconds: 300)); // the query is sent and waits
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'zzqx'); // matches nothing
      await tester.pump(const Duration(milliseconds: 10));
      gate.complete(); // the old «pharmacy» answer arrives now
      await tester.pump();
      await tester.pump();

      expect(find.byType(SearchResultTile), findsNothing, reason: '«pharmacy» results shown under «zzqx»');
      await settle(tester);
    });

    testWidgets('an opener that throws: the screen stays usable and says it cannot open', (tester) async {
      await pumpSearchApp(
        tester,
        locale: const Locale('en'),
        opener: (context, doc) => throw StateError('no route for ${doc.openKey}'),
      );
      await typeQuery(tester, 'pharmacy');
      expect(find.byType(SearchResultTile), findsWidgets);
      await tester.tap(find.byType(SearchResultTile).first);
      await settle(tester);
      expect(find.text('This result can’t be opened from here yet.'), findsOneWidget);
    });

    testWidgets('closing the search screen stops the engine (no index isolate or DB listener left)', (tester) async {
      final env = await pumpSearchApp(
        tester,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => GlobalSearchScreen.open(context), child: const Text('open search')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open search'));
      await settle(tester);
      await typeQuery(tester, 'pharmacy');
      expect(find.byType(SearchResultTile), findsWidgets);
      final engine = env.container.read(searchEngineProvider);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      expect(find.byType(GlobalSearchScreen), findsNothing);

      // The screen is gone: the engine (its isolate and index) should be too.
      expect(engine.status.value, isNot(SearchEngineStatus.ready), reason: 'engine still running with its index');
    });
  });
}
