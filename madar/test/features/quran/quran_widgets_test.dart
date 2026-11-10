import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/quran/presentation/quran_labels.dart';
import 'package:madar/features/quran/presentation/widgets/mushaf_page.dart';
import 'package:madar/features/quran/presentation/widgets/quran_ornaments.dart';
import 'package:madar/features/quran/presentation/widgets/verse_list.dart';
import 'package:madar/features/quran/quran.dart';

import 'quran_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Future<void> _prefs(MadarDatabase db, QuranReaderPrefs prefs, {QuranLastRead? last}) async {
  final store = QuranPrefsStore(Repositories(db).keyValues);
  await store.savePrefs(prefs);
  if (last != null) await store.saveLastRead(last);
}

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(MushafFit.clearCache);

  group('home', () {
    testWidgets('ar: suras, juz and bookmarks tabs; a sura opens the reader', (tester) async {
      final env = await pumpQuranApp(tester, home: const QuranHomeScreen());
      expect(find.text(_ar.quranTitle), findsOneWidget);
      expect(find.text('الفاتحة'), findsWidgets);
      expect(find.text(_ar.quranContinueEmpty), findsOneWidget);
      await tester.tap(find.text(_ar.quranTabJuz));
      await settleQuran(tester);
      expect(find.text(_ar.quranJuzLabel('١')), findsOneWidget);
      await tester.tap(find.text(_ar.quranTabBookmarks));
      await settleQuran(tester);
      expect(find.text(_ar.quranBookmarksEmptyTitle), findsOneWidget);
      await tester.tap(find.text(_ar.quranTabSurahs));
      await settleQuran(tester);
      await tester.tap(find.text('البقرة').first);
      await settleQuran(tester);
      expect(find.byType(QuranReaderScreen), findsOneWidget);
      expect(env.sound.played, contains(Sfx.navigate));
    });

    testWidgets('en: continue card shows the last place and opens it', (tester) async {
      await pumpQuranApp(
        tester,
        home: const QuranHomeScreen(),
        locale: const Locale('en'),
        beforePump: (db) => _prefs(
          db,
          const QuranReaderPrefs(mode: QuranReaderMode.list),
          last: QuranLastRead(ref: const AyahRef(18, 10), page: 294, at: DateTime(2026, 9, 27), mode: QuranReaderMode.list),
        ),
      );
      expect(find.text(_en.quranContinueTitle), findsOneWidget);
      expect(find.text('Al-Kahf · Ayah 10'), findsOneWidget);
      expect(find.textContaining('Page 294 of 604'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.auto_stories_rounded));
      await settleQuran(tester);
      expect(find.byType(SurahVerseList), findsOneWidget);
      final card = tester.widget<VerseCard>(find.byType(VerseCard).first);
      expect(card.content.ref, const AyahRef(18, 10));
    });

    testWidgets('go to: typing a place opens the reader there', (tester) async {
      await pumpQuranApp(tester, home: const QuranHomeScreen(), locale: const Locale('en'));
      await tester.tap(find.text(_en.quranGoTo));
      await settleQuran(tester);
      await tester.enterText(find.byType(TextField).last, 'Baqarah 255');
      await settleQuran(tester);
      expect(find.text('Al-Baqarah · Ayah 255'), findsOneWidget);
      await tester.tap(find.text('Al-Baqarah · Ayah 255'));
      await settleQuran(tester);
      final reader = tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen));
      expect(reader.start, const AyahRef(2, 255));
    });
  });

  group('reader', () {
    testWidgets('mushaf: page header, RTL swipe to the next page, last read saved', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(page: 1, mode: QuranReaderMode.mushaf),
        locale: const Locale('en'),
      );
      expect(find.text('Juz 1 · Hizb 1'), findsOneWidget);
      expect(find.byType(MushafPage), findsOneWidget);
      // Next page lies to the left: drag from left to right.
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await settleQuran(tester);
      await tester.pump(const Duration(seconds: 1));
      await settleQuran(tester);
      final page = tester.widget<MushafPage>(find.byType(MushafPage));
      expect(page.page, 2);
      expect(env.sound.played, contains(Sfx.swipe));
      final last = await tester.runAsync(() => QuranPrefsStore(Repositories(env.db).keyValues).lastRead());
      expect(last?.page, 2);
      expect(last?.ref, const AyahRef(2, 1));
    });

    testWidgets('mushaf follows the recitation to the page of the recited ayah', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(page: 1, mode: QuranReaderMode.mushaf),
      );
      env.audio.recite(const AyahRef(2, 255));
      await settleQuran(tester);
      expect(tester.widget<MushafPage>(find.byType(MushafPage)).page, 42);
      expect(tester.widget<MushafPage>(find.byType(MushafPage)).marks.playing, const AyahRef(2, 255));
    });

    // Review finding: while the basmala before ayah 1 was recited, ayah 1
    // was lit instead of the basmala line.
    for (final mode in QuranReaderMode.values) {
      testWidgets('the basmala is lit while it is recited ($mode)', (tester) async {
        final env = await pumpQuranApp(tester, home: QuranReaderScreen(start: const AyahRef(67, 1), mode: mode));
        env.audio.recite(const AyahRef(67, 1), range: const AyahRange(AyahRef(67, 1), AyahRef(67, 30)), basmala: true);
        await settleQuran(tester);
        final basmala = tester.widget<BasmalaLine>(find.byType(BasmalaLine));
        expect(basmala.highlight, isNotNull);
        if (mode == QuranReaderMode.mushaf) {
          final marks = tester.widget<MushafPage>(find.byType(MushafPage)).marks;
          expect(marks.playing, isNull);
          expect(marks.playingBasmala, 67);
        }
        // Then ayah 1 itself.
        env.audio.recite(const AyahRef(67, 1), range: const AyahRange(AyahRef(67, 1), AyahRef(67, 30)));
        await settleQuran(tester);
        expect(tester.widget<BasmalaLine>(find.byType(BasmalaLine)).highlight, isNull);
        if (mode == QuranReaderMode.mushaf) {
          expect(tester.widget<MushafPage>(find.byType(MushafPage)).marks.playing, const AyahRef(67, 1));
        }
      });
    }

    testWidgets('verse list: actions sheet plays, repeats, copies, shares, adds to Hifz', (tester) async {
      final hifz = <AyahRange>[];
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(start: AyahRef(112, 1), mode: QuranReaderMode.list),
        overrides: [
          quranAddToHifzProvider.overrideWithValue((context, range) async {
            hifz.add(range);
            return true;
          }),
        ],
      );
      Future<void> open() async {
        await tester.tap(find.byType(VerseCard).first);
        await settleQuran(tester);
      }

      await open();
      expect(find.text(_ar.quranActionPlay), findsOneWidget);
      await tester.tap(find.text(_ar.quranActionPlay));
      await settleQuran(tester);
      expect(env.audio.played.last.$1, const AyahRange(AyahRef(112, 1), AyahRef(112, 4)));

      await open();
      await tester.tap(find.text('٥ مرات'));
      await tester.pump();
      await tester.tap(find.text(_ar.quranActionRepeat).first);
      await settleQuran(tester);
      expect(env.audio.played.last.$1, const AyahRange.single(AyahRef(112, 1)));
      expect(env.audio.played.last.$2, 5);

      await open();
      await tester.tap(find.text(_ar.quranActionCopy));
      await tester.pump();
      await _frames(tester);
      expect(env.share.copied.single, startsWith('﴿'));
      expect(env.share.copied.single, endsWith('[الإخلاص: ١]'));
      expect(find.text(_ar.quranCopied), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await settleQuran(tester);

      await open();
      await tester.tap(find.text(_ar.quranActionShare));
      await settleQuran(tester);
      expect(env.share.shared, hasLength(1));

      await open();
      await tester.tap(find.text(_ar.quranActionHifz));
      await settleQuran(tester);
      expect(hifz, [const AyahRange.single(AyahRef(112, 1))]);
      await tester.pump(const Duration(seconds: 3));
      await settleQuran(tester);

      await open();
      await tester.tap(find.text(_ar.quranActionTafsir));
      await tester.pump();
      await _frames(tester);
      expect(find.text(_ar.quranTafsirSoon), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await settleQuran(tester);
      expect(env.haptics.fired, isNotEmpty);
    });

    testWidgets('verse list: quick bookmark, then the reader marks it', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(start: AyahRef(1, 1), mode: QuranReaderMode.list),
        locale: const Locale('en'),
      );
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded).first);
      await settleQuran(tester);
      final rows = await tester.runAsync(() => Repositories(env.db).quranBookmarks.getAll());
      expect(rows!.single.surah, 1);
      expect(rows.single.ayah, 1);
      expect(tester.widget<VerseCard>(find.byType(VerseCard).first).marks.bookmarks.keys, contains(const AyahRef(1, 1)));
      await tester.pump(const Duration(seconds: 3));
      await settleQuran(tester);
    });

    testWidgets('translation: download on request, then shown under each ayah', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(start: AyahRef(1, 1), mode: QuranReaderMode.list),
        locale: const Locale('en'),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(mode: QuranReaderMode.list, translation: true)),
      );
      expect(env.http.requests, isEmpty, reason: 'no network without an explicit tap');
      expect(find.text(_en.quranTranslationMissing), findsOneWidget);
      await tester.tap(find.text(_en.quranDownloadTranslation));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settleQuran(tester);
      expect(env.http.requests.single.toString(), contains('translations/20?chapter_number=1'));
      expect(find.textContaining('the Entirely Merciful, the Especially Merciful.'), findsOneWidget);
      expect(find.text(_en.quranTranslationMissing), findsNothing);
    });

    testWidgets('translation download offline: says so, stays usable', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(start: AyahRef(1, 1), mode: QuranReaderMode.list),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(mode: QuranReaderMode.list, translation: true)),
        setup: (env) => env.http.offline = true,
      );
      await tester.tap(find.text(_ar.quranDownloadTranslation));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settleQuran(tester);
      expect(find.text(_ar.quranDownloadOffline), findsOneWidget);
      expect(env.sound.played, contains(Sfx.error));
    });

    testWidgets('switching layout keeps the place and is remembered', (tester) async {
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(start: AyahRef(36, 1), mode: QuranReaderMode.mushaf),
        locale: const Locale('en'),
      );
      expect(tester.widget<MushafPage>(find.byType(MushafPage)).page, 440);
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await settleQuran(tester);
      expect(tester.widget<SurahVerseList>(find.byType(SurahVerseList)).surah.number, 36);
      final prefs = await tester.runAsync(() => QuranPrefsStore(Repositories(env.db).keyValues).prefs());
      expect(prefs!.mode, QuranReaderMode.list);
    });

    testWidgets('a reading session is logged with its real time only', (tester) async {
      var now = DateTime(2026, 9, 28, 21);
      final env = await pumpQuranApp(
        tester,
        home: const QuranReaderScreen(page: 582, mode: QuranReaderMode.mushaf),
        clock: () => now,
      );
      now = now.add(const Duration(seconds: 75));
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await settleQuran(tester);
      expect(tester.widget<MushafPage>(find.byType(MushafPage)).page, 583);
      now = now.add(const Duration(seconds: 60));
      await tester.tap(find.byType(MushafPage));
      await tester.pump();
      // Leave the reader.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      final rows = await tester.runAsync(() => Repositories(env.db).quranSessions.getAll());
      expect(rows, hasLength(1));
      final s = rows!.single;
      expect(s.seconds, 135);
      expect((s.fromSurah, s.fromAyah), (78, 1));
      expect((s.toSurah, s.toAyah), (79, 15), reason: 'page 583 ends inside an-Naziat');
      expect(s.pages, closeTo(2, 0.01));
      expect(s.mode, QuranSessionMode.read);
      final activity = await tester.runAsync(() => Repositories(env.db).activity.since(DateTime(2026, 9, 28)));
      expect(activity!.single.kind, 'quran.read');
      expect(activity.single.planetKey, 'faith');
      expect(activity.single.refId, s.id);
    });

    testWidgets('a glance is not a session', (tester) async {
      final env = await pumpQuranApp(tester, home: const QuranReaderScreen(page: 10));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(await tester.runAsync(() => Repositories(env.db).quranSessions.getAll()), isEmpty);
    });
  });

  group('search', () {
    testWidgets('finds ayat ignoring diacritics and lights the words', (tester) async {
      await pumpQuranApp(tester, home: const QuranSearchScreen(initialQuery: 'قل هو الله احد'), locale: const Locale('en'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settleQuran(tester);
      expect(find.textContaining('1 ayah'), findsOneWidget);
      expect(find.text('Al-Ikhlas · Ayah 1'), findsOneWidget);
    });

    testWidgets('too short and no results', (tester) async {
      await pumpQuranApp(tester, home: const QuranSearchScreen(initialQuery: 'ق'));
      await settleQuran(tester);
      expect(find.text(_ar.quranSearchTooShort), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'زززز');
      await tester.pump(const Duration(milliseconds: 300));
      await settleQuran(tester);
      expect(find.text(_ar.quranSearchNoResults), findsOneWidget);
    });
  });

  group('catalog provider', () {
    testWidgets('quranCatalogProvider serves the bundled catalog', (tester) async {
      final env = await pumpQuranApp(tester, home: const SizedBox());
      final catalog = env.container.read(quranCatalogProvider);
      await tester.runAsync(catalog.ensureLoaded);
      expect(catalog.surahName(36, arabic: true), 'يس');
      expect(catalog.pageOf(const AyahRef(36, 1)), 440);
    });
  });

  group('legend', () {
    testWidgets('lists every rule with an example', (tester) async {
      await pumpQuranApp(
        tester,
        home: Builder(
          builder: (context) => MadarScaffold(
            title: 'x',
            body: Center(child: MadarButton(label: 'go', onPressed: () => showTajweedLegend(context))),
          ),
        ),
        locale: const Locale('en'),
      );
      await tester.tap(find.text('go'));
      await settleQuran(tester);
      for (final rule in TajweedRule.values) {
        expect(find.text(_en.quranRuleName(rule)), findsOneWidget, reason: rule.name);
      }
    });
  });
}
