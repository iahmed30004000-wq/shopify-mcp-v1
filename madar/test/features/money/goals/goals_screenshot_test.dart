@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/money/goals/goals.dart';

import '../../../helpers/screenshot_harness.dart';
import 'goals_harness.dart';

const _dir = 'phase5/goals';

/// Shows [behind] and runs [open] (a sheet) on the first frame.
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the snapshot load before the sheet reads it.
        for (var i = 0; i < 40 && ref.read(goalsSnapshotProvider) == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        if (mounted) await widget.open(context, ref);
      });
    }
    return widget.behind;
  }
}

/// The Money hub's goals cards, as the hub would place them.
class HubPreview extends StatelessWidget {
  const HubPreview({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).planetMoney,
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: const [
        UpcomingDuesCard(),
        SizedBox(height: Space.m),
        JarsCard(),
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
    bool seed = true,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildGoalsApp(tester, home: home, theme: theme, locale: locale, seed: seed);
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: (tester) async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
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

  const en = Locale('en');

  group('jars', () {
    testWidgets('Arabic, Lapis', (t) => shot(t, 'jars_ar_lapis', const GoalsScreen()));
    testWidgets(
      'English, Pearl',
      (t) => shot(t, 'jars_en_pearl', const GoalsScreen(), theme: MadarThemeId.pearl, locale: en),
    );
    testWidgets('Arabic, Emerald', (t) => shot(t, 'jars_ar_emerald', const GoalsScreen(), theme: MadarThemeId.emerald));
    testWidgets(
      'fresh install – Arabic, Lapis',
      (t) => shot(t, 'jars_empty_ar_lapis', const GoalsScreen(), seed: false),
    );
  });

  group('debts', () {
    const screen = GoalsScreen(initialTab: GoalsTab.debts);
    testWidgets('Arabic, Lapis', (t) => shot(t, 'debts_ar_lapis', screen));
    testWidgets('English, Pearl', (t) => shot(t, 'debts_en_pearl', screen, theme: MadarThemeId.pearl, locale: en));
    testWidgets('Arabic, Desert', (t) => shot(t, 'debts_ar_desert', screen, theme: MadarThemeId.desert));
  });

  group('obligations', () {
    const screen = GoalsScreen(initialTab: GoalsTab.obligations);
    testWidgets('Arabic, Lapis', (t) => shot(t, 'obligations_ar_lapis', screen));
    testWidgets(
      'English, Pearl',
      (t) => shot(t, 'obligations_en_pearl', screen, theme: MadarThemeId.pearl, locale: en),
    );
    testWidgets(
      'English, Aurora',
      (t) => shot(t, 'obligations_en_aurora', screen, theme: MadarThemeId.aurora, locale: en),
    );
  });

  group('jar screen', () {
    const screen = JarScreen(jarId: GoalsSeedIds.jarTrip);
    testWidgets('Arabic, Lapis', (t) => shot(t, 'jar_ar_lapis', screen));
    testWidgets('English, Pearl', (t) => shot(t, 'jar_en_pearl', screen, theme: MadarThemeId.pearl, locale: en));
    testWidgets(
      'chart and history – Arabic, Aurora',
      (t) => shot(t, 'jar_history_ar_aurora', screen, theme: MadarThemeId.aurora, beforeCapture: (t) => scroll(t, 560)),
    );
    testWidgets(
      'chart and history – English, Pearl',
      (t) => shot(
        t,
        'jar_history_en_pearl',
        screen,
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: (t) => scroll(t, 560),
      ),
    );
    testWidgets(
      'reached – Arabic, Pearl',
      (t) => shot(t, 'jar_reached_ar_pearl', const JarScreen(jarId: GoalsSeedIds.jarEid), theme: MadarThemeId.pearl),
    );
  });

  group('sheets', () {
    testWidgets(
      'debt – Arabic, Lapis',
      (t) => shot(
        t,
        'debt_sheet_ar_lapis',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.debts),
          open: (context, ref) => showDebtSheet(context, GoalsSeedIds.debtSupplier),
        ),
      ),
    );
    testWidgets(
      'debt – English, Pearl',
      (t) => shot(
        t,
        'debt_sheet_en_pearl',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.debts),
          open: (context, ref) => showDebtSheet(context, GoalsSeedIds.debtColleague),
        ),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
    );
    testWidgets(
      'obligation – Arabic, Pearl',
      (t) => shot(
        t,
        'obligation_sheet_ar_pearl',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.obligations),
          open: (context, ref) => showObligationSheet(context, GoalsSeedIds.obRent),
        ),
        theme: MadarThemeId.pearl,
      ),
    );
    testWidgets(
      'obligation – English, Lapis',
      (t) => shot(
        t,
        'obligation_sheet_en_lapis',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.obligations),
          open: (context, ref) => showObligationSheet(context, GoalsSeedIds.obInternet),
        ),
        locale: en,
      ),
    );
    testWidgets(
      'deposit – Arabic, Lapis',
      (t) => shot(
        t,
        'deposit_sheet_ar_lapis',
        OpenOnStart(
          behind: const GoalsScreen(),
          open: (context, ref) async {
            final jar = ref.read(goalsJarProvider(GoalsSeedIds.jarTrip));
            if (jar != null) await GoalsActions(context, ref).moveMoney(jar);
          },
        ),
      ),
    );
    testWidgets(
      'jar editor – English, Pearl',
      (t) => shot(
        t,
        'jar_editor_en_pearl',
        OpenOnStart(
          behind: const GoalsScreen(),
          open: (context, ref) async {
            final jar = ref.read(goalsJarProvider(GoalsSeedIds.jarLaptop));
            if (jar != null) await GoalsActions(context, ref).editJar(jar.jar);
          },
        ),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
    );
    testWidgets(
      'obligation editor – Arabic, Emerald',
      (t) => shot(
        t,
        'obligation_editor_ar_emerald',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.obligations),
          open: (context, ref) async {
            final o = ref.read(goalsObligationProvider(GoalsSeedIds.obAllowance));
            if (o != null) await GoalsActions(context, ref).editObligation(o.obligation);
          },
        ),
        theme: MadarThemeId.emerald,
      ),
    );
    testWidgets(
      'debt editor – Arabic, Pearl',
      (t) => shot(
        t,
        'debt_editor_ar_pearl',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.debts),
          open: (context, ref) async {
            final d = ref.read(goalsDebtProvider(GoalsSeedIds.debtSupplier));
            if (d != null) await GoalsActions(context, ref).editDebt(d.debt);
          },
        ),
        theme: MadarThemeId.pearl,
      ),
    );
    testWidgets(
      'reminder settings – English, Lapis',
      (t) => shot(
        t,
        'reminders_sheet_en_lapis',
        OpenOnStart(
          behind: const GoalsScreen(initialTab: GoalsTab.obligations),
          open: (context, ref) => GoalsActions(context, ref).reminderSettings(),
        ),
        locale: en,
      ),
    );
  });

  group('hub cards', () {
    testWidgets('Arabic, Lapis', (t) => shot(t, 'hub_cards_ar_lapis', const HubPreview()));
    testWidgets(
      'English, Pearl',
      (t) => shot(t, 'hub_cards_en_pearl', const HubPreview(), theme: MadarThemeId.pearl, locale: en),
    );
    testWidgets(
      'Arabic, Desert',
      (t) => shot(t, 'hub_cards_ar_desert', const HubPreview(), theme: MadarThemeId.desert),
    );
  });
}
