@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/health/meds/meds.dart';

import '../../../helpers/screenshot_harness.dart';
import 'meds_harness.dart';

const _dir = 'phase4/meds';

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
    final (app, _) = await buildMedsApp(tester, home: home, theme: theme, locale: locale, beforePump: beforePump);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  Future<void> seedAr(MadarDatabase db) => seedMedsScenario(db);
  Future<void> seedEn(MadarDatabase db) => seedMedsScenario(db, lang: 'en');

  Future<void> pumpFrames(WidgetTester tester, [int n = 30]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('today', () {
    testWidgets('mixed states – Arabic, Lapis', (tester) async {
      await shot(tester, 'today_ar_lapis', const MedsScreen(), beforePump: seedAr);
    });

    testWidgets('mixed states – English, Pearl', (tester) async {
      await shot(
        tester,
        'today_en_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
      );
    });

    testWidgets('scrolled to the afternoon – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'today_scrolled_ar_emerald',
        const MedsScreen(),
        theme: MadarThemeId.emerald,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.drag(find.byType(ListView).first, const Offset(0, -620));
        },
      );
    });

    testWidgets('scrolled – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'today_scrolled_ar_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.drag(find.byType(ListView).first, const Offset(0, -620));
        },
      );
    });

    testWidgets('empty – Arabic, Lapis', (tester) async {
      await shot(tester, 'today_empty_ar_lapis', const MedsScreen());
    });
  });

  group('my meds and rules', () {
    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).first);
      await pumpFrames(tester, 20);
    }

    testWidgets('Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'meds_ar_lapis',
        const MedsScreen(),
        beforePump: seedAr,
        beforeCapture: (tester) => openTab(tester, 'أدويتي'),
      );
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'meds_en_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: (tester) => openTab(tester, 'My meds'),
      );
    });

    testWidgets('rules – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'rules_ar_emerald',
        const MedsScreen(),
        theme: MadarThemeId.emerald,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await openTab(tester, 'أدويتي');
          await tester.drag(find.byType(MedCard).first, const Offset(0, -900));
        },
      );
    });
  });

  group('courses', () {
    testWidgets('course card – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'courses_ar_lapis',
        const MedsScreen(),
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.tap(find.text('الدورات').first);
          await pumpFrames(tester, 20);
        },
      );
    });

    testWidgets('course timeline – Arabic, Pearl', (tester) async {
      late MedsScenario s;
      await shot(
        tester,
        'course_timeline_ar_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        beforePump: (db) async => s = await seedMedsScenario(db),
        beforeCapture: (tester) async {
          showCourseSheet(tester.element(find.byType(MedsScreen)), courseId: s.course);
          await pumpFrames(tester);
        },
      );
    });

    testWidgets('course timeline – English, Emerald', (tester) async {
      late MedsScenario s;
      await shot(
        tester,
        'course_timeline_en_emerald',
        const MedsScreen(),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
        beforePump: (db) async => s = await seedMedsScenario(db, lang: 'en'),
        beforeCapture: (tester) async {
          showCourseSheet(tester.element(find.byType(MedsScreen)), courseId: s.course);
          await pumpFrames(tester);
        },
      );
    });
  });

  group('editor', () {
    Future<void> openEditor(WidgetTester tester, String medId) async {
      final context = tester.element(find.byType(MedsScreen));
      final container = ProviderScope.containerOf(context);
      final med = (await tester.runAsync(() => container.read(medsServiceProvider).med(medId)))!;
      showMedicationEditor(context, med: med);
      await pumpFrames(tester);
    }

    testWidgets('anchored time open – Arabic, Lapis', (tester) async {
      late MedsScenario s;
      await shot(
        tester,
        'editor_ar_lapis',
        const MedsScreen(),
        beforePump: (db) async => s = await seedMedsScenario(db),
        beforeCapture: (tester) async {
          await openEditor(tester, s.levo);
          await tester.tap(
            find.descendant(of: find.byType(MedicationEditor), matching: find.textContaining('بعد الفجر')).first,
          );
          await pumpFrames(tester, 16);
          await tester.drag(find.byType(AnchorPicker), const Offset(0, -420));
          await pumpFrames(tester, 16);
        },
      );
    });

    testWidgets('English, Pearl', (tester) async {
      late MedsScenario s;
      await shot(
        tester,
        'editor_en_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) async => s = await seedMedsScenario(db, lang: 'en'),
        beforeCapture: (tester) => openEditor(tester, s.calcium),
      );
    });

    testWidgets('new medication – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'editor_new_ar_emerald',
        const MedsScreen(),
        theme: MadarThemeId.emerald,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.add_rounded).last);
          await pumpFrames(tester);
        },
      );
    });
  });

  group('sheets', () {
    testWidgets('history – Arabic, Lapis', (tester) async {
      late MedsScenario s;
      await shot(
        tester,
        'history_ar_lapis',
        const MedsScreen(),
        beforePump: (db) async => s = await seedMedsScenario(db),
        beforeCapture: (tester) async {
          showMedHistorySheet(tester.element(find.byType(MedsScreen)), medId: s.calcium);
          await pumpFrames(tester);
        },
      );
    });

    testWidgets('rule editor – English, Pearl', (tester) async {
      await shot(
        tester,
        'rule_editor_en_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        beforeCapture: (tester) async {
          showRuleEditor(tester.element(find.byType(MedsScreen)));
          await pumpFrames(tester);
        },
      );
    });

    testWidgets('settings – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'settings_ar_pearl',
        const MedsScreen(),
        theme: MadarThemeId.pearl,
        beforePump: seedAr,
        beforeCapture: (tester) async {
          showMedsSettingsSheet(tester.element(find.byType(MedsScreen)), settings: const MedsSettings());
          await pumpFrames(tester);
        },
      );
    });
  });

  group('today card', () {
    Widget host() => MadarScaffold(
      body: const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
        child: Column(children: [TodayDosesCard()]),
      ),
    );

    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'card_ar_lapis', host(), beforePump: seedAr, size: const Size(412, 360));
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'card_en_pearl',
        host(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        size: const Size(412, 360),
      );
    });

    testWidgets('empty – Arabic, Emerald', (tester) async {
      await shot(tester, 'card_empty_ar_emerald', host(), theme: MadarThemeId.emerald, size: const Size(412, 300));
    });
  });
}
