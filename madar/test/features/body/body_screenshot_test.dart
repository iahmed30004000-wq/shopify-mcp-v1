@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/body/body.dart';

import '../../helpers/screenshot_harness.dart';
import 'body_harness.dart';
import 'body_seed.dart';

const _dir = 'phase6/body';

/// Shows [behind] and opens a sheet over it on the first frame.
class OpenOnStart extends ConsumerStatefulWidget {
  const OpenOnStart({super.key, required this.behind, required this.open});

  final Widget behind;
  final Future<void> Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<OpenOnStart> createState() => _OpenOnStartState();
}

class _OpenOnStartState extends ConsumerState<OpenOnStart> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.open(context, ref);
      });
    }
    return widget.behind;
  }
}

/// The Body planet hub's card, as the hub would place it.
class HubPreview extends StatelessWidget {
  const HubPreview({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).bodyTitle,
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: [
        BodyTodayCard(onOpen: () {}),
        const SizedBox(height: Space.m),
        const FastingCard(compact: true),
        const SizedBox(height: Space.s),
        const WaterCard(compact: true),
      ],
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    BodySeed? seed = BodySeed.full,
    DateTime? now,
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    int trailingFrames = 12,
  }) async {
    final (app, _) = await buildBodyApp(tester, home: home, theme: theme, locale: locale, seed: seed, now: now, beforePump: beforePump);
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      trailingFrames: trailingFrames,
      beforeCapture: (tester) async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  Future<void> scroll(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).last, Offset(0, -dy));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('today – Arabic, Lapis', (tester) async {
    await shot(tester, 'today_ar_lapis', const BodyScreen());
  });

  testWidgets('today – English, Pearl', (tester) async {
    await shot(tester, 'today_en_pearl', const BodyScreen(), theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('today – fresh install, Arabic, Emerald', (tester) async {
    await shot(tester, 'today_empty_ar_emerald', const BodyScreen(), theme: MadarThemeId.emerald, seed: null);
  });

  testWidgets('plan – Arabic, Pearl', (tester) async {
    await shot(tester, 'plan_ar_pearl', const BodyScreen(initialTab: BodyTab.plan), theme: MadarThemeId.pearl);
  });

  testWidgets('plan – English, Lapis', (tester) async {
    await shot(tester, 'plan_en_lapis', const BodyScreen(initialTab: BodyTab.plan), locale: const Locale('en'));
  });

  testWidgets('fasting – Arabic, Lapis (fasting)', (tester) async {
    await shot(tester, 'fasting_ar_lapis', const BodyScreen(initialTab: BodyTab.fasting));
  });

  testWidgets('fasting – English, Pearl (eating window)', (tester) async {
    await shot(
      tester,
      'fasting_eating_en_pearl',
      const BodyScreen(initialTab: BodyTab.fasting),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: BodySeed.eating,
      now: DateTime(2026, 9, 29, 15),
    );
  });

  testWidgets('fasting – Arabic, Emerald (goal reached), history', (tester) async {
    await shot(
      tester,
      'fasting_reached_ar_emerald',
      const BodyScreen(initialTab: BodyTab.fasting),
      theme: MadarThemeId.emerald,
      now: DateTime(2026, 9, 29, 12, 40),
    );
  });

  testWidgets('fasting plan and history – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'fasting_plan_ar_pearl',
      const BodyScreen(initialTab: BodyTab.fasting),
      theme: MadarThemeId.pearl,
      beforeCapture: (tester) => scroll(tester, 560),
    );
  });

  testWidgets('water – Arabic, Pearl', (tester) async {
    await shot(tester, 'water_ar_pearl', const BodyScreen(initialTab: BodyTab.water), theme: MadarThemeId.pearl);
  });

  testWidgets('water – English, Emerald', (tester) async {
    await shot(
      tester,
      'water_en_emerald',
      const BodyScreen(initialTab: BodyTab.water),
      theme: MadarThemeId.emerald,
      locale: const Locale('en'),
    );
  });

  testWidgets('avoid – Arabic, Lapis', (tester) async {
    await shot(tester, 'avoid_ar_lapis', const BodyScreen(initialTab: BodyTab.avoid));
  });

  testWidgets('avoid – empty, English, Pearl', (tester) async {
    await shot(
      tester,
      'avoid_empty_en_pearl',
      const BodyScreen(initialTab: BodyTab.avoid),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: BodySeed.planOnly,
    );
  });

  testWidgets('exercise sheet – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'exercise_sheet_ar_lapis',
      OpenOnStart(
        behind: const BodyScreen(initialTab: BodyTab.plan),
        open: (context, ref) async {
          final row = (await ref.read(bodyExerciseRowsProvider.future)).first;
          if (context.mounted) await showExerciseSheet(context, exercise: row);
        },
      ),
      trailingFrames: 24,
    );
  });

  testWidgets('workout log sheet – English, Pearl', (tester) async {
    await shot(
      tester,
      'workout_log_sheet_en_pearl',
      OpenOnStart(
        behind: const BodyScreen(),
        open: (context, ref) async {
          await ref.read(bodyExerciseRowsProvider.future);
          final e = ref.read(bodyExercisesProvider)[1];
          if (context.mounted) await showWorkoutLogSheet(context, exercise: e);
        },
      ),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      trailingFrames: 24,
    );
  });

  testWidgets('workout log sheet, day and time open – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'workout_log_sheet_when_ar_lapis',
      OpenOnStart(
        behind: const BodyScreen(),
        open: (context, ref) async {
          await ref.read(bodyExerciseRowsProvider.future);
          final e = ref.read(bodyExercisesProvider)[1];
          if (context.mounted) await showWorkoutLogSheet(context, exercise: e);
        },
      ),
      trailingFrames: 24,
      beforeCapture: (tester) async {
        await tester.tap(find.text(lookupL10n(const Locale('ar')).bodyLogWhen));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.tap(find.text(lookupL10n(const Locale('ar')).bodyYesterday));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('history sheet – Arabic, Emerald', (tester) async {
    await shot(
      tester,
      'history_sheet_ar_emerald',
      OpenOnStart(
        behind: const BodyScreen(initialTab: BodyTab.plan),
        open: (context, ref) async {
          final row = (await ref.read(bodyExerciseRowsProvider.future)).first;
          await ref.read(bodyWorkoutRowsProvider.future);
          if (context.mounted) await showExerciseHistorySheet(context, row.id);
        },
      ),
      theme: MadarThemeId.emerald,
      trailingFrames: 30,
    );
  });

  testWidgets('hub card – Arabic, Lapis', (tester) async {
    await shot(tester, 'hub_ar_lapis', const HubPreview());
  });

  testWidgets('hub card – English, Pearl', (tester) async {
    await shot(tester, 'hub_en_pearl', const HubPreview(), theme: MadarThemeId.pearl, locale: const Locale('en'));
  });
}
