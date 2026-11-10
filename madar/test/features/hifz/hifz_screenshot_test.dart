@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/wird/wird.dart';

import '../../helpers/screenshot_harness.dart';
import '../wird/wird_harness.dart';
import '../wird/wird_screenshot_test.dart' show seedScenario;
import 'hifz_seed.dart';

const _dir = 'phase3/hifz';
final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    Size size = const Size(412, 915),
  }) async {
    final (app, _) = await buildFaithApp(tester, home: home, theme: theme, locale: locale, beforePump: beforePump);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  group('hifz screen', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'hifz_ar_lapis', const HifzScreen(), beforePump: seedHifz);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'hifz_en_pearl',
        const HifzScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedHifz(db, arabic: false),
      );
    });

    testWidgets('learned tab, Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'hifz_learned_ar_emerald',
        const HifzScreen(initialTab: HifzTab.learned),
        theme: MadarThemeId.emerald,
        beforePump: seedHifz,
        beforeCapture: (tester) => tester.drag(find.byType(ListView), const Offset(0, -560)),
      );
    });

    testWidgets('new tab, English, Aurora', (tester) async {
      await shot(
        tester,
        'hifz_new_en_aurora',
        const HifzScreen(initialTab: HifzTab.fresh),
        theme: MadarThemeId.aurora,
        locale: const Locale('en'),
        beforePump: (db) => seedHifz(db, arabic: false),
        beforeCapture: (tester) => tester.drag(find.byType(ListView), const Offset(0, -560)),
      );
    });

    testWidgets('empty, Arabic, Emerald', (tester) async {
      await shot(tester, 'hifz_empty_ar_emerald', const HifzScreen(), theme: MadarThemeId.emerald);
    });
  });

  group('review', () {
    testWidgets('ayat, first letters and a few words – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'review_ayat_ar_lapis',
        const HifzReviewScreen(),
        beforePump: seedHifz,
        beforeCapture: (tester) async {
          await tester.tap(find.text(_ar.hifzRevealFirstLetters));
          await _frames(tester, 4);
          for (var i = 0; i < 7; i++) {
            await tester.tap(find.text(_ar.hifzRevealNextWord));
            await _frames(tester, 2);
          }
        },
      );
    });

    testWidgets('ayat, hidden – English, Pearl', (tester) async {
      await shot(
        tester,
        'review_ayat_en_pearl',
        const HifzReviewScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedHifz(db, arabic: false),
      );
    });

    testWidgets('hadith revealed after a grade – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'review_hadith_ar_emerald',
        const HifzReviewScreen(),
        theme: MadarThemeId.emerald,
        beforePump: seedHifz,
        beforeCapture: (tester) async {
          // Grade the overdue Al-Mulk chunk, reaching the hadith.
          for (var i = 0; i < 1; i++) {
            await tester.tap(find.text(_ar.hifzGrade5));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
            await _frames(tester, 10);
          }
          await tester.tap(find.text(_ar.hifzRevealAll));
          await _frames(tester, 6);
        },
      );
    });

    testWidgets('summary – English, Pearl', (tester) async {
      await shot(
        tester,
        'review_summary_en_pearl',
        const HifzReviewScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedHifz(db, arabic: false),
        beforeCapture: (tester) async {
          for (final g in [5, 2, 4, 5, 4, 4, 4]) {
            final label = switch (g) {
              5 => _en.hifzGrade5,
              4 => _en.hifzGrade4,
              _ => _en.hifzGrade2,
            };
            if (find.text(label).evaluate().isEmpty) break;
            await tester.tap(find.text(label));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
            await _frames(tester, 10);
          }
          await _frames(tester, 20);
        },
      );
    });
  });

  group('sheets', () {
    testWidgets('add chooser – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'add_sheet_ar_lapis',
        const HifzScreen(),
        beforePump: seedHifz,
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).first);
          await _frames(tester, 20);
        },
      );
    });

    testWidgets('hadith picker – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'hadith_picker_ar_lapis',
        const HifzScreen(),
        beforePump: seedHifz,
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).first);
          await _frames(tester, 20);
          await tester.tap(find.text(_ar.hifzAddHadith));
          await _frames(tester, 24);
          await tester.tap(find.text('الدين النصيحة'));
          await _frames(tester, 6);
        },
      );
    });

    testWidgets('ayat sheet – English, Pearl', (tester) async {
      await shot(
        tester,
        'ayat_sheet_en_pearl',
        const HifzScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedHifz(db, arabic: false),
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).first);
          await _frames(tester, 20);
          await tester.tap(find.text(_en.hifzAddAyat));
          await _frames(tester, 24);
        },
      );
    });
  });

  group('faith hub cards', () {
    Widget hub() => const MadarScaffold(
      body: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
        child: Column(
          children: [
            WirdTodayCard(),
            SizedBox(height: Space.m),
            HifzTodayCard(),
          ],
        ),
      ),
    );

    Future<void> both(MadarDatabase db, {bool arabic = true}) async {
      await seedScenario(db, lang: arabic ? 'ar' : 'en');
      await seedHifz(db, arabic: arabic);
    }

    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'cards_ar_lapis', hub(), beforePump: both, size: const Size(412, 480));
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'cards_en_pearl',
        hub(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => both(db, arabic: false),
        size: const Size(412, 480),
      );
    });

    testWidgets('nothing yet, Arabic, Aurora', (tester) async {
      await shot(tester, 'cards_empty_ar_aurora', hub(), theme: MadarThemeId.aurora, size: const Size(412, 480));
    });
  });
}
