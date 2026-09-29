import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import 'debts_tab.dart';
import 'goals_actions.dart';
import 'goals_ui.dart';
import 'jars_tab.dart';
import 'obligations_tab.dart';

enum GoalsTab { jars, debts, obligations }

/// Savings jars, debts and recurring obligations in three tabs, each with
/// its own floating "add" button. The bell sets when due reminders fire.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key, this.initialTab = GoalsTab.jars, this.animateBackdrop = true});

  final GoalsTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late GoalsTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Keep the due reminders in step with what the screen changes.
    ref.watch(goalsReminderSyncProvider);
    final snap = ref.watch(goalsSnapshotProvider);
    final actions = GoalsActions(context, ref);
    final fab = switch (_tab) {
      GoalsTab.jars => (Icons.add_rounded, l.goalsJarNew, actions.addJar),
      GoalsTab.debts => (Icons.person_add_alt_rounded, l.goalsDebtNew, actions.addDebt),
      GoalsTab.obligations => (Icons.add_alarm_rounded, l.goalsObligationNew, actions.addObligation),
    };
    return MadarScaffold(
      title: l.goalsTitle,
      backdropSeed: 5.3,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: GoalsIcons.reminders,
          semanticLabel: l.goalsRemindersTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: actions.reminderSettings,
        ),
      ],
      floatingAction: MadarButton.icon(
        icon: fab.$1,
        semanticLabel: fab.$2,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => fab.$3(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: GoalsTabBar<GoalsTab>(
              values: GoalsTab.values,
              value: _tab,
              labels: {
                GoalsTab.jars: l.goalsTabJars,
                GoalsTab.debts: l.goalsTabDebts,
                GoalsTab.obligations: l.goalsTabObligations,
              },
              icons: const {
                GoalsTab.jars: GoalsIcons.jars,
                GoalsTab.debts: GoalsIcons.debts,
                GoalsTab.obligations: GoalsIcons.obligations,
              },
              badges: {
                GoalsTab.debts: snap?.debtTotals.overdueCount ?? 0,
                GoalsTab.obligations: snap?.obligationTotals.overdueCount ?? 0,
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: GoalsFadeStack(
                index: _tab.index,
                children: const [
                  JarsTab(key: ValueKey('goals.jars')),
                  DebtsTab(key: ValueKey('goals.debts')),
                  ObligationsTab(key: ValueKey('goals.obligations')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
