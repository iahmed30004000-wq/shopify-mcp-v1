@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/growth/growth.dart';

import '../../helpers/screenshot_harness.dart';
import 'growth_harness.dart';

const _dir = 'phase6/growth';

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
    final (app, _) = await buildGrowthApp(tester, home: home, theme: theme, locale: locale, beforePump: beforePump);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  Future<void> seedAr(MadarDatabase db) => seedScenario(db);
  Future<void> seedEn(MadarDatabase db) => seedScenario(db, lang: 'en');

  /// The book's id, found after seeding.
  Future<String> bookId(MadarDatabase db) async => (await (db.select(
    db.learningGoals,
  )..where((g) => g.unit.equals('pages'))).get()).firstWhere((g) => g.initial > 0).id;

  Future<void> openFirstGoal(WidgetTester tester) async {
    await tester.tap(find.byType(GoalTile).first);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String logLabel(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(GoalScreen))).languageCode == 'ar'
      ? 'سجّل تقدّمًا'
      : 'Log progress';

  Future<void> pumpFrames(WidgetTester tester, [int n = 30]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('growth screen', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'growth_ar_lapis', const GrowthScreen(), beforePump: seedAr);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'growth_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
      );
    });

    testWidgets('scrolled to completed and paused – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'growth_sections_ar_emerald',
        const GrowthScreen(),
        theme: MadarThemeId.emerald,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        },
      );
    });

    testWidgets('empty – Arabic, Aurora', (tester) async {
      await shot(tester, 'growth_empty_ar_aurora', const GrowthScreen(), theme: MadarThemeId.aurora);
    });

    testWidgets('empty – English, Pearl', (tester) async {
      await shot(
        tester,
        'growth_empty_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });

  group('goal screen', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'goal_ar_lapis', const GrowthScreen(), beforePump: seedAr, beforeCapture: openFirstGoal);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'goal_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: openFirstGoal,
      );
    });

    testWidgets('pace and chart – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'goal_chart_ar_lapis',
        const GrowthScreen(),
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.drag(find.byType(ListView).last, const Offset(0, -620));
        },
      );
    });

    testWidgets('pace and chart – English, Pearl', (tester) async {
      await shot(
        tester,
        'goal_chart_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.drag(find.byType(ListView).last, const Offset(0, -620));
        },
      );
    });

    testWidgets('history – Arabic, Desert', (tester) async {
      await shot(
        tester,
        'goal_history_ar_desert',
        const GrowthScreen(),
        theme: MadarThemeId.desert,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
        },
      );
    });

    testWidgets('direct, by id – English, Aurora', (tester) async {
      late String id;
      await shot(
        tester,
        'goal_direct_en_aurora',
        Builder(builder: (_) => GoalScreen(goalId: id)),
        theme: MadarThemeId.aurora,
        locale: const Locale('en'),
        beforePump: (db) async {
          await seedEn(db);
          id = await bookId(db);
        },
      );
    });
  });

  group('sheets', () {
    testWidgets('new goal – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'goal_sheet_ar_lapis',
        const GrowthScreen(),
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.tap(find.text('هدف جديد').first);
          await pumpFrames(tester);
          await tester.enterText(find.byKey(const ValueKey('growth-goal-name')), 'قراءة كتاب في الإدارة');
          await tester.tap(find.text('صفحات'));
          await tester.enterText(find.byKey(const ValueKey('growth-goal-target')), '٢٤٠');
          await tester.tap(find.text('بعد شهر'));
          await pumpFrames(tester, 10);
        },
      );
    });

    testWidgets('edit goal – English, Pearl', (tester) async {
      await shot(
        tester,
        'goal_sheet_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.tap(find.byIcon(Icons.edit_rounded).first);
          await pumpFrames(tester);
        },
      );
    });

    testWidgets('log progress – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'log_sheet_ar_lapis',
        const GrowthScreen(),
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.tap(find.text(logLabel(tester)).last);
          await pumpFrames(tester);
        },
      );
    });

    testWidgets('log progress – English, Pearl', (tester) async {
      await shot(
        tester,
        'log_sheet_en_pearl',
        const GrowthScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: (tester) async {
          await openFirstGoal(tester);
          await tester.tap(find.text(logLabel(tester)).last);
          await pumpFrames(tester);
          await tester.tap(find.text('+20'));
          await pumpFrames(tester, 6);
        },
      );
    });

    testWidgets('celebration – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'celebration_ar_emerald',
        const Scaffold(body: SizedBox.shrink()),
        theme: MadarThemeId.emerald,
        beforeCapture: (tester) async {
          final context = tester.element(find.byType(SizedBox).last);
          showGoalCelebration(
            context,
            GoalCelebrationInfo(
              name: 'قراءة «العادات الذرية»',
              amount: GrowthTexts.of(context).amount(const GrowthUnit.known(GrowthUnitKind.pages), 320),
              days: 38,
              color: null,
            ),
          );
          await pumpFrames(tester, 14);
        },
      );
    });
  });

  group('today card', () {
    Widget host() => MadarScaffold(
      body: const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
        child: Column(children: [GrowthTodayCard()]),
      ),
    );

    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'today_card_ar_lapis', host(), beforePump: seedAr, size: const Size(412, 420));
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'today_card_en_pearl',
        host(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        size: const Size(412, 420),
      );
    });

    testWidgets('no goals yet – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'today_card_empty_ar_emerald',
        host(),
        theme: MadarThemeId.emerald,
        size: const Size(412, 260),
      );
    });
  });
}
