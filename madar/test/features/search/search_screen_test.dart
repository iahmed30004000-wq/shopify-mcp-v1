// A hang (a future waiting on fake time) fails fast instead of after 10 min.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/search/search.dart';

import 'search_harness.dart';

/// The filter chip whose label starts with [name].
Finder chip(String name) => find.byWidgetPredicate((w) => w is MadarChip && w.label.startsWith('$name ('));

/// Every text on screen, rich texts included.
Iterable<String> texts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText(includeSemanticsLabels: false));

bool shows(WidgetTester tester, String fragment) => texts(tester).any((t) => t.contains(fragment));

/// The lit (highlighted) stretches of every result tile.
List<String> litStretches(WidgetTester tester) {
  final out = <String>[];
  for (final r in tester.widgetList<RichText>(find.descendant(of: find.byType(SearchResultTile), matching: find.byType(RichText)))) {
    r.text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null && span.text != null) out.add(span.text!);
      return true;
    });
  }
  return out;
}

void main() {
  group('Arabic', () {
    testWidgets('empty field: introduction, then recent searches that can be reused and cleared', (tester) async {
      await pumpSearchApp(tester);
      expect(find.text('ابحث في مدارك كله'), findsOneWidget);
      await tearDownApp(tester);

      final env = await pumpSearchApp(tester, recent: ['الطبيب', 'راتب']);
      expect(find.text('عمليات البحث الأخيرة'), findsOneWidget);
      expect(find.text('الطبيب'), findsOneWidget);
      await tester.tap(find.text('راتب'));
      await settle(tester);
      expect(find.byType(SearchResultTile), findsWidgets);
      expect(shows(tester, 'راتب أيلول'), isTrue);

      // Back to the empty field: remove one, then clear the rest.
      await tester.tap(find.byTooltip('مسح النص'));
      await settle(tester);
      await tester.tap(find.byTooltip('حذف «الطبيب» من السجل'));
      await settle(tester);
      expect(await RecentSearchesStore(env.repos.keyValues).read(), ['راتب']);
      await tester.tap(find.text('مسح السجل'));
      await settle(tester);
      expect(await RecentSearchesStore(env.repos.keyValues).read(), isEmpty);
      expect(find.text('ابحث في مدارك كله'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('results are grouped by module with counts, matches lit, dates at the end', (tester) async {
      await pumpSearchApp(tester);
      await typeQuery(tester, 'الطبيب');
      // Groups: tasks, appointments? («طبيب» without the article), cards, module entries.
      expect(find.text('المهام'), findsWidgets);
      expect(find.text('البطاقات'), findsWidgets);
      expect(find.text('سجل القراءة'), findsWidgets); // the custom module is its own group
      expect(shows(tester, 'موعد مع الطبيب لمراجعة التحاليل'), isTrue);
      expect(litStretches(tester), contains('الطبيب'));
      expect(find.text('اليوم'), findsWidgets); // today's task
      // Counts in the planet chips (Arabic digits).
      expect(chip('الكل'), findsOneWidget);
      expect(find.text('الصحة (٢)'), findsOneWidget); // the task and the appointment
      await tearDownApp(tester);
    });

    testWidgets('planet chips filter, module chips narrow further, "all" clears', (tester) async {
      await pumpSearchApp(tester);
      await typeQuery(tester, 'دواء');
      final before = tester.widgetList(find.byType(SearchResultTile)).length;
      expect(before, greaterThan(2));
      await tapVisible(tester, chip('المال'));
      final tiles = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).toList();
      expect(tiles, isNotEmpty);
      expect(tiles.every((t) => t.hit.doc.planetKey == 'money'), isTrue);
      await tapVisible(tester, chip('الكل'));
      expect(tester.widgetList(find.byType(SearchResultTile)).length, before);

      // Health has several modules: its module chips appear.
      await tapVisible(tester, chip('الصحة'));
      expect(chip('الأدوية'), findsOneWidget);
      await tapVisible(tester, chip('الأدوية'));
      final meds = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).toList();
      expect(meds.map((t) => t.hit.doc.sourceId).toSet(), {'medications'});
      await tearDownApp(tester);
    });

    testWidgets('Arabic-Indic digits in the query find Western digits', (tester) async {
      await pumpSearchApp(tester);
      await typeQuery(tester, '٧٫٥');
      expect(shows(tester, 'دواء الضغط من الصيدلية'), isTrue);
      await tearDownApp(tester);
    });

    testWidgets('no results', (tester) async {
      await pumpSearchApp(tester);
      await typeQuery(tester, 'زرافة');
      expect(find.text('لا نتائج لـ «زرافة»'), findsOneWidget);
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('document numbers and phone numbers are not searchable', (tester) async {
      await pumpSearchApp(tester);
      await typeQuery(tester, 'N1234567');
      expect(find.byType(SearchResultTile), findsNothing);
      await typeQuery(tester, '962790000000');
      expect(find.byType(SearchResultTile), findsNothing);
      await tearDownApp(tester);
    });

    testWidgets('Quran ayat are found through the Quran index', (tester) async {
      await pumpSearchApp(tester, withQuran: true);
      await typeQuery(tester, 'الرحمن الرحيم');
      await settle(tester, frames: 20);
      expect(find.text('آيات القرآن'), findsOneWidget);
      final ayah = tester
          .widgetList<SearchResultTile>(find.byType(SearchResultTile))
          .firstWhere((t) => t.hit.doc.openKey == 'quran.ayah');
      expect(ayah.hit.doc.title, 'الفاتحة، الآية ١');
      expect(ayah.hit.snippetRanges, isNotEmpty);
      await tearDownApp(tester);
    });

    testWidgets('results follow the database while the screen is open', (tester) async {
      final env = await pumpSearchApp(tester);
      await typeQuery(tester, 'زرافة');
      expect(find.byType(SearchResultTile), findsNothing);
      await tester.runAsync(() => env.repos.tasks.insert(TasksCompanion.insert(title: 'رسم زرافة للأطفال')));
      await settle(tester, frames: 20);
      expect(shows(tester, 'رسم زرافة للأطفال'), isTrue);
      await tearDownApp(tester);
    });
  });

  group('English', () {
    testWidgets('tapping a result opens it through the opener and remembers the search', (tester) async {
      final env = await pumpSearchApp(tester, locale: const Locale('en'));
      await typeQuery(tester, 'cardio');
      expect(find.text('Appointments'), findsOneWidget);
      expect(litStretches(tester), contains('Cardio'));
      await tester.tap(find.byType(SearchResultTile).first);
      await settle(tester);
      expect(env.opened.single.refTable, 'appointments');
      expect(env.opened.single.openKey, 'appointments');
      expect(await RecentSearchesStore(env.repos.keyValues).read(), ['cardio']);
      await tearDownApp(tester);
    });

    testWidgets('an unhandled result says it cannot be opened yet', (tester) async {
      await pumpSearchApp(tester, locale: const Locale('en'), opener: (context, doc) => false);
      await typeQuery(tester, 'salary');
      await tester.tap(find.byType(SearchResultTile).first);
      await settle(tester);
      expect(find.text('This result can’t be opened from here yet.'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('keyboard: arrows move, Enter opens the selection, Escape clears', (tester) async {
      final env = await pumpSearchApp(tester, locale: const Locale('en'));
      await typeQuery(tester, 'blood');
      final tiles = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).toList();
      expect(tiles.length, greaterThanOrEqualTo(2));
      expect(tiles.any((t) => t.selected), isFalse); // no ring until the keyboard is used

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester, frames: 4);
      var selected = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).where((t) => t.selected).toList();
      expect(selected, hasLength(1));
      expect(selected.single.hit.doc.id, tiles[1].hit.doc.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // stays on the first
      await settle(tester, frames: 4);
      selected = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).where((t) => t.selected).toList();
      expect(selected.single.hit.doc.id, tiles[0].hit.doc.id);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(env.opened.single.id, tiles[1].hit.doc.id);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(SearchResultTile), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      await tearDownApp(tester);
    });

    testWidgets('"show all" filters to one module', (tester) async {
      await pumpSearchApp(
        tester,
        locale: const Locale('en'),
        beforePump: (db) async {
          for (var i = 1; i <= 8; i++) {
            await db.into(db.tasks).insert(TasksCompanion.insert(title: 'Quarterly report $i'));
          }
          await db.into(db.projects).insert(ProjectsCompanion.insert(name: 'Quarterly planning'));
        },
      );
      await typeQuery(tester, 'quarterly');
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(tester.widgetList(find.byType(SearchResultTile)).length, 6); // 5 tasks + 1 project
      await tapVisible(tester, find.text('Show all (8)'));
      final tiles = tester.widgetList<SearchResultTile>(find.byType(SearchResultTile)).toList();
      expect(tiles, hasLength(8));
      expect(tiles.map((t) => t.hit.doc.groupKey).toSet(), {'tasks'});
      expect(find.text('Tasks (8)'), findsOneWidget); // the module chip, selected
      await tearDownApp(tester);
    });
  });

  group('launcher', () {
    testWidgets('the pill opens the search screen', (tester) async {
      await pumpSearchApp(
        tester,
        locale: const Locale('en'),
        home: const MadarScaffold(title: 'Home', body: Padding(padding: EdgeInsets.all(20), child: SearchLauncher())),
      );
      expect(find.text('Search Madar'), findsOneWidget);
      await tester.tap(find.byType(SearchLauncher));
      await settle(tester, frames: 16);
      expect(find.byType(GlobalSearchScreen), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('the icon variant calls onOpen', (tester) async {
      var opened = 0;
      await pumpSearchApp(
        tester,
        home: MadarScaffold(title: '', actions: [SearchLauncher.icon(onOpen: () => opened++)], body: const SizedBox()),
      );
      await tester.tap(find.bySemanticsLabel('البحث في كل شيء'));
      await settle(tester, frames: 4);
      expect(opened, 1);
      await tearDownApp(tester);
    });
  });

  testWidgets('result tile: highlights, trailing date and semantics', (tester) async {
    final hit = SearchHit(
      doc: SearchDoc(
        id: 'x',
        refTable: 'tasks',
        refId: 'x',
        title: 'Meeting with Omar',
        subtitle: 'Asr',
        date: searchTestNow.subtract(const Duration(days: 1)),
        planetKey: 'work',
      ),
      score: 1,
      titleRanges: const [HighlightRange(13, 17)],
      snippet: 'bring the report',
    );
    var taps = 0;
    await pumpSearchApp(
      tester,
      locale: const Locale('en'),
      seed: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SearchResultTile(hit: hit, now: searchTestNow, onTap: () => taps++),
        ),
      ),
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(litStretches(tester), ['Omar']);
    expect(find.bySemanticsLabel(RegExp('Meeting with Omar.*Yesterday')), findsOneWidget);
    await tester.tap(find.byType(SearchResultTile));
    expect(taps, 1);
    await tearDownApp(tester);
  });
}
