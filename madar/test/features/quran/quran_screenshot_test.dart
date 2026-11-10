@Tags(['screenshot'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/presentation/widgets/mushaf_page.dart';
import 'package:madar/features/quran/presentation/widgets/verse_list.dart';
import 'package:madar/features/quran/quran.dart';

import '../../helpers/screenshot_harness.dart';
import 'quran_harness.dart';

const _dir = 'phase3/quran';

Future<void> _prefs(MadarDatabase db, QuranReaderPrefs prefs, {QuranLastRead? last}) async {
  final store = QuranPrefsStore(Repositories(db).keyValues);
  await store.savePrefs(prefs);
  if (last != null) await store.saveLastRead(last);
}

final _lastRead = QuranLastRead(
  ref: const AyahRef(2, 255),
  page: 42,
  at: DateTime(2026, 9, 28, 6),
  mode: QuranReaderMode.mushaf,
);

Future<void> _bookmarks(MadarDatabase db) async {
  final r = Repositories(db).quranBookmarks;
  await r.insert(
    QuranBookmarksCompanion.insert(surah: 18, ayah: 10, label: const Value('وِرد الجمعة'), color: const Value(0xFFE8C77A)),
  );
  await r.insert(QuranBookmarksCompanion.insert(surah: 2, ayah: 255, color: const Value(0xFF7FB8FF)));
  await r.insert(
    QuranBookmarksCompanion.insert(
      surah: 36,
      ayah: 1,
      label: const Value('يس'),
      note: const Value('قبل النوم ليلة الجمعة'),
      color: const Value(0xFF4FD69C),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(MushafFit.clearCache);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    Future<void> Function(MadarDatabase db)? beforePump,
    void Function(QuranTestEnv env)? setup,
    Future<void> Function(WidgetTester tester, QuranTestEnv env)? before,
    Size size = const Size(412, 915),
  }) async {
    late QuranTestEnv env;
    final (app, e) = await buildQuranApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      beforePump: beforePump,
      setup: setup,
      overrides: [quranAddToHifzProvider.overrideWithValue((context, range) async => true)],
    );
    env = e;
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      logicalSize: size,
      beforeCapture: before == null ? null : (t) => before(t, env),
    );
  }

  group('mushaf', () {
    testWidgets('page 2 – al-Baqarah opens – ar lapis', (tester) async {
      await shot(tester, 'mushaf_p2_ar_lapis', const QuranReaderScreen(page: 2, mode: QuranReaderMode.mushaf));
    });

    testWidgets('page 50 – ar pearl', (tester) async {
      await shot(
        tester,
        'mushaf_p50_ar_pearl',
        const QuranReaderScreen(page: 50, mode: QuranReaderMode.mushaf),
        theme: MadarThemeId.pearl,
      );
    });

    testWidgets('page 604 – three suras – en desert', (tester) async {
      await shot(
        tester,
        'mushaf_p604_en_desert',
        const QuranReaderScreen(page: 604, mode: QuranReaderMode.mushaf),
        theme: MadarThemeId.desert,
        locale: const Locale('en'),
      );
    });

    testWidgets('page 42 – Ayat al-Kursi being recited – ar aurora', (tester) async {
      await shot(
        tester,
        'mushaf_p42_reciting_ar_aurora',
        const QuranReaderScreen(page: 42, mode: QuranReaderMode.mushaf),
        theme: MadarThemeId.aurora,
        setup: (env) => env.audio.recite(const AyahRef(2, 255)),
      );
    });

    testWidgets('page 42 – tajweed off, bookmark marker – en pearl', (tester) async {
      await shot(
        tester,
        'mushaf_p42_plain_en_pearl',
        const QuranReaderScreen(page: 42, mode: QuranReaderMode.mushaf),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) async {
          await _prefs(db, const QuranReaderPrefs(tajweed: false));
          await _bookmarks(db);
        },
      );
    });
  });

  group('verse list', () {
    testWidgets('al-Fatihah with translation – en emerald', (tester) async {
      await shot(
        tester,
        'verses_translation_en_emerald',
        const QuranReaderScreen(start: AyahRef(1, 1), mode: QuranReaderMode.list),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(mode: QuranReaderMode.list, translation: true)),
        setup: (env) => env.cache.entries['translation-20-s1'] = FixtureQuranHttp.fixtureText(
          'qurancom_translation_20_chapter_1.json',
        ),
      );
    });

    testWidgets('as-Sajdah around its sajdah, bookmarked – ar pearl', (tester) async {
      await shot(
        tester,
        'verses_sajdah_ar_pearl',
        const QuranReaderScreen(start: AyahRef(32, 15), mode: QuranReaderMode.list),
        theme: MadarThemeId.pearl,
        beforePump: (db) async {
          await Repositories(db).quranBookmarks.insert(
            QuranBookmarksCompanion.insert(surah: 32, ayah: 16, color: const Value(0xFFE07A5F)),
          );
        },
      );
    });

    testWidgets('translation not downloaded – ar lapis', (tester) async {
      await shot(
        tester,
        'verses_translation_missing_ar_lapis',
        const QuranReaderScreen(start: AyahRef(112, 1), mode: QuranReaderMode.list),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(mode: QuranReaderMode.list, translation: true)),
      );
    });

    testWidgets('ayah actions sheet – ar lapis', (tester) async {
      await shot(
        tester,
        'ayah_actions_ar_lapis',
        const QuranReaderScreen(start: AyahRef(2, 255), mode: QuranReaderMode.list),
        before: (tester, env) async {
          await tester.tap(find.byType(VerseCard).first);
          await _pumpFrames(tester);
        },
      );
    });

    testWidgets('ayah actions sheet – en pearl', (tester) async {
      await shot(
        tester,
        'ayah_actions_en_pearl',
        const QuranReaderScreen(start: AyahRef(1, 5), mode: QuranReaderMode.list),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        before: (tester, env) async {
          await tester.tap(find.byType(VerseCard).first);
          await _pumpFrames(tester);
        },
      );
    });
  });

  group('index', () {
    testWidgets('suras – ar lapis', (tester) async {
      await shot(
        tester,
        'home_surahs_ar_lapis',
        const QuranHomeScreen(),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(), last: _lastRead),
      );
    });

    testWidgets('suras – en pearl', (tester) async {
      await shot(
        tester,
        'home_surahs_en_pearl',
        const QuranHomeScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(), last: _lastRead),
      );
    });

    testWidgets('juz with quarters – ar desert', (tester) async {
      await shot(
        tester,
        'home_juz_ar_desert',
        const QuranHomeScreen(initialTab: QuranHomeTab.juz),
        theme: MadarThemeId.desert,
        before: (tester, env) async {
          await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
          await _pumpFrames(tester);
          await tester.drag(find.byType(ListView).first, const Offset(0, -330));
          await _pumpFrames(tester);
        },
      );
    });

    testWidgets('bookmarks – ar lapis', (tester) async {
      await shot(
        tester,
        'home_bookmarks_ar_lapis',
        const QuranHomeScreen(initialTab: QuranHomeTab.bookmarks),
        beforePump: (db) async {
          await _prefs(db, const QuranReaderPrefs(), last: _lastRead);
          await _bookmarks(db);
        },
      );
    });

    testWidgets('bookmarks empty – en emerald', (tester) async {
      await shot(
        tester,
        'home_bookmarks_empty_en_emerald',
        const QuranHomeScreen(initialTab: QuranHomeTab.bookmarks),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
      );
    });

    testWidgets('go to – ar lapis', (tester) async {
      await shot(
        tester,
        'goto_ar_lapis',
        const QuranHomeScreen(),
        before: (tester, env) async {
          await tester.tap(find.byIcon(Icons.near_me_outlined).first);
          await _pumpFrames(tester);
          await tester.enterText(find.byType(TextField).last, 'الكهف ١٠');
          await _pumpFrames(tester);
        },
      );
    });
  });

  group('search', () {
    testWidgets('al-Hayy al-Qayyum – ar lapis', (tester) async {
      await shot(tester, 'search_ar_lapis', const QuranSearchScreen(initialQuery: 'الحي القيوم'));
    });

    testWidgets('ar-Rahman – en pearl', (tester) async {
      await shot(
        tester,
        'search_en_pearl',
        const QuranSearchScreen(initialQuery: 'الرحمن'),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });

  group('sheets and cards', () {
    testWidgets('tajweed legend – ar lapis', (tester) async {
      await shot(
        tester,
        'legend_ar_lapis',
        const _Opener(kind: _Sheet.legend),
        before: (tester, env) async {
          await tester.tap(find.byType(MadarButton));
          await _pumpFrames(tester);
        },
        size: const Size(412, 1500),
      );
    });

    testWidgets('tajweed legend – en pearl', (tester) async {
      await shot(
        tester,
        'legend_en_pearl',
        const _Opener(kind: _Sheet.legend),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        before: (tester, env) async {
          await tester.tap(find.byType(MadarButton));
          await _pumpFrames(tester);
        },
        size: const Size(412, 1500),
      );
    });

    testWidgets('reader settings – ar emerald', (tester) async {
      await shot(
        tester,
        'settings_ar_emerald',
        const _Opener(kind: _Sheet.settings),
        theme: MadarThemeId.emerald,
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(translation: true, tajweedSource: TajweedSource.quranCom)),
        before: (tester, env) async {
          await tester.tap(find.byType(MadarButton));
          await _pumpFrames(tester);
        },
        size: const Size(412, 1100),
      );
    });

    testWidgets('continue cards – ar lapis', (tester) async {
      await shot(
        tester,
        'continue_cards_ar_lapis',
        const _Cards(),
        beforePump: (db) => _prefs(db, const QuranReaderPrefs(), last: _lastRead),
        size: const Size(412, 520),
      );
    });

    testWidgets('continue cards (nothing read yet) – en pearl', (tester) async {
      await shot(
        tester,
        'continue_cards_empty_en_pearl',
        const _Cards(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        size: const Size(412, 520),
      );
    });
  });
}

enum _Sheet { legend, settings }

class _Opener extends StatelessWidget {
  const _Opener({required this.kind});

  final _Sheet kind;

  @override
  Widget build(BuildContext context) {
    return MadarScaffold(
      title: 'Quran',
      body: Center(
        child: MadarButton(
          label: 'open',
          onPressed: () => kind == _Sheet.legend ? showTajweedLegend(context) : showReaderSettings(context, surah: 1),
        ),
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    return MadarScaffold(
      title: 'Faith',
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: const [
          QuranContinueCard(prominent: true),
          SizedBox(height: Space.l),
          QuranContinueCard(),
        ],
      ),
    );
  }
}
