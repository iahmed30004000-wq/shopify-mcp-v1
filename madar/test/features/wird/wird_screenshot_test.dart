@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/wird/wird.dart';

import '../../helpers/screenshot_harness.dart';
import 'wird_harness.dart';

const _dir = 'phase3/wird';

/// A 30-day khatma (primary, after Fajr) read on schedule for eight days,
/// yesterday missed and 40 % of today read; four pages a day after Isha
/// since 1 Sep; ten ayat a day, paused.
Future<void> seedScenario(MadarDatabase db, {String lang = 'ar', bool metToday = false}) async {
  final ar = lang == 'ar';
  final khatma = await seedPlan(
    db,
    WirdDraft(
      name: ar ? 'ختمة رمضانية في ٣٠ يومًا' : 'Khatma in 30 days',
      template: WirdTemplate.khatma,
      khatmaDays: 30,
      startDate: DateTime(2026, 9, 19),
      window: PrayerWindow.fajr,
    ),
  );
  await seedReading(
    db,
    khatma,
    days: metToday ? [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] : [0, 1, 2, 3, 4, 5, 6, 7],
    partialToday: metToday ? null : 0.4,
  );
  final daily = await seedPlan(
    db,
    WirdDraft(
      name: ar ? 'تدبّر بعد العشاء' : 'Reflection after Isha',
      template: WirdTemplate.pages,
      amount: 4,
      start: const AyahRef(18, 1),
      startDate: DateTime(2026, 9, 1),
      window: PrayerWindow.isha,
      catchUp: WirdCatchUp.allAtOnce,
    ),
  );
  await seedReading(
    db,
    daily,
    days: [
      for (var d = 0; d < 27; d++)
        if (d != 5 && d != 12 && d != 13 && d != 20) d,
    ],
  );
  final amma = await seedPlan(
    db,
    WirdDraft(
      name: ar ? 'حفظ جزء عمّ' : 'Juz Amma, ten ayat',
      template: WirdTemplate.ayat,
      amount: 10,
      start: const AyahRef(78, 1),
      startDate: DateTime(2026, 9, 20),
      window: PrayerWindow.maghrib,
    ),
  );
  await seedReading(db, amma, days: [0, 1, 2, 3]);
  await WirdService(Repositories(db), clock: () => DateTime(2026, 9, 25, 9)).pause(amma);
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

  group('wird screen', () {
    testWidgets('behind, partly read today – Arabic, Lapis', (tester) async {
      await shot(tester, 'wird_ar_lapis', const WirdScreen(), beforePump: seedScenario);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'wird_en_pearl',
        const WirdScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedScenario(db, lang: 'en'),
      );
    });

    testWidgets('done today, scrolled to the history – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'wird_history_ar_emerald',
        const WirdScreen(),
        theme: MadarThemeId.emerald,
        beforePump: (db) => seedScenario(db, metToday: true),
        beforeCapture: (tester) async {
          await tester.drag(find.byType(ListView), const Offset(0, -720));
        },
      );
    });

    testWidgets('history, English, Pearl', (tester) async {
      await shot(
        tester,
        'wird_history_en_pearl',
        const WirdScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedScenario(db, lang: 'en'),
        beforeCapture: (tester) async {
          await tester.drag(find.byType(ListView), const Offset(0, -720));
        },
      );
    });

    testWidgets('empty – Arabic, Aurora', (tester) async {
      await shot(tester, 'wird_empty_ar_aurora', const WirdScreen(), theme: MadarThemeId.aurora);
    });
  });

  group('plan sheet', () {
    testWidgets('new plan – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'plan_sheet_ar_lapis',
        const WirdScreen(),
        beforePump: seedScenario,
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).first);
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
      );
    });

    testWidgets('new plan – English, Pearl', (tester) async {
      await shot(
        tester,
        'plan_sheet_en_pearl',
        const WirdScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedScenario(db, lang: 'en'),
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).first);
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
      );
    });
  });

  group('today card', () {
    Widget host() => MadarScaffold(
      body: const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
        child: Column(children: [WirdTodayCard()]),
      ),
    );

    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'today_card_ar_lapis', host(), beforePump: seedScenario, size: const Size(412, 330));
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'today_card_en_pearl',
        host(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => seedScenario(db, lang: 'en'),
        size: const Size(412, 330),
      );
    });

    testWidgets('no plan yet, Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'today_card_empty_ar_emerald',
        host(),
        theme: MadarThemeId.emerald,
        size: const Size(412, 330),
      );
    });
  });
}
