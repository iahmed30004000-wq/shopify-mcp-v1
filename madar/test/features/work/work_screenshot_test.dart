@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/work/work.dart';

import '../../helpers/screenshot_harness.dart';
import 'work_harness.dart';

const _dir = 'phase6/work';

/// A hub-like page around one compact card.
class _Hub extends StatelessWidget {
  const _Hub(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: WorkTexts.of(context).l.workTitle,
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: [
        for (final c in children) Padding(padding: const EdgeInsetsDirectional.only(bottom: Space.l), child: c),
      ],
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget Function(WorkSeed seed) home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool top3AllDone = false,
    DateTime? now,
    DateTime? seedAt,
    bool seed = true,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    Size size = const Size(412, 915),
  }) async {
    late WorkSeed s;
    final (app, _) = await buildWorkApp(
      tester,
      home: Builder(builder: (context) => home(s)),
      theme: theme,
      locale: locale,
      now: now,
      beforePump: (env) async {
        s = seed ? await seedWork(env, lang: locale.languageCode, top3AllDone: top3AllDone, at: seedAt) : WorkSeed();
      },
    );
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('board', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'board_ar_lapis', (s) => BoardScreen(boardId: s.store.id));
    });

    testWidgets('Arabic, Pearl, scrolled to Doing', (tester) async {
      await shot(
        tester,
        'board_doing_ar_pearl',
        (s) => BoardScreen(boardId: s.store.id),
        theme: MadarThemeId.pearl,
        beforeCapture: (tester) => tapText(tester, 'قيد التنفيذ'),
      );
    });

    testWidgets('Arabic, Desert, Done column', (tester) async {
      await shot(
        tester,
        'board_done_ar_desert',
        (s) => BoardScreen(boardId: s.store.id),
        theme: MadarThemeId.desert,
        beforeCapture: (tester) => tapText(tester, 'تمّ'),
      );
    });

    testWidgets('Arabic, Lapis, tablet width: every column, right to left', (tester) async {
      await shot(
        tester,
        'board_wide_ar_lapis',
        (s) => BoardScreen(boardId: s.store.id),
        size: const Size(1100, 760),
      );
    });

    testWidgets('English, Pearl (left to right)', (tester) async {
      await shot(
        tester,
        'board_en_pearl',
        (s) => BoardScreen(boardId: s.store.id),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('English, Lapis, filter open', (tester) async {
      await shot(
        tester,
        'board_filter_en_lapis',
        (s) => BoardScreen(boardId: s.store.id),
        locale: const Locale('en'),
        beforeCapture: (tester) async {
          await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tapText(tester, 'Sara');
        },
      );
    });
  });

  group('work screen', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'work_ar_lapis', (s) => const WorkScreen());
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(tester, 'work_en_pearl', (s) => const WorkScreen(), theme: MadarThemeId.pearl, locale: const Locale('en'));
    });

    testWidgets('fresh install: empty, Arabic, Emerald', (tester) async {
      await shot(tester, 'work_empty_ar_emerald', (s) => const WorkScreen(), theme: MadarThemeId.emerald, seed: false);
    });
  });

  group('Top 3', () {
    testWidgets('all done, Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'top3_done_ar_emerald',
        (s) => const _Hub([Top3Card(), WorkTodayCard()]),
        theme: MadarThemeId.emerald,
        top3AllDone: true,
      );
    });

    testWidgets('next morning carry-over, Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'top3_carry_ar_pearl',
        (s) => const _Hub([Top3Card(), WorkTodayCard()]),
        theme: MadarThemeId.pearl,
        seedAt: workTestNow,
        now: workTestNow.add(const Duration(days: 1, hours: -4)),
      );
    });

    testWidgets('English, Lapis, with the today card', (tester) async {
      await shot(
        tester,
        'top3_today_en_lapis',
        (s) => const _Hub([Top3Card(), WorkTodayCard()]),
        locale: const Locale('en'),
      );
    });
  });

  group('projects', () {
    testWidgets('project with checklist, Arabic, Lapis', (tester) async {
      await shot(tester, 'project_ar_lapis', (s) => ProjectScreen(projectId: s.project.id));
    });

    testWidgets('project, English, Pearl', (tester) async {
      await shot(
        tester,
        'project_en_pearl',
        (s) => ProjectScreen(projectId: s.project.id),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('project, Arabic, Desert', (tester) async {
      await shot(tester, 'project_ar_desert', (s) => ProjectScreen(projectId: s.project.id), theme: MadarThemeId.desert);
    });

    testWidgets('projects list, Arabic, Pearl', (tester) async {
      await shot(tester, 'projects_ar_pearl', (s) => const ProjectsScreen(), theme: MadarThemeId.pearl);
    });
  });

  group('card sheet', () {
    testWidgets('editing a card, Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'card_sheet_ar_lapis',
        (s) => BoardScreen(boardId: s.store.id),
        beforeCapture: (tester) async {
          await tester.tap(find.text('تأكيد طلبات الدفع عند الاستلام').first);
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
      );
    });

    testWidgets('editing a card, English, Pearl', (tester) async {
      await shot(
        tester,
        'card_sheet_en_pearl',
        (s) => BoardScreen(boardId: s.store.id),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (tester) async {
          await tester.tap(find.text('Confirm cash-on-delivery orders').first);
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
      );
    });
  });
}
