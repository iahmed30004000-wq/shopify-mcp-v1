import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/body_providers.dart';
import 'body_actions.dart';
import 'tabs/avoid_tab.dart';
import 'tabs/fasting_tab.dart';
import 'tabs/plan_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/water_tab.dart';
import 'widgets/body_widgets.dart';

enum BodyTab { today, plan, fasting, water, avoid }

/// The Body planet: today's session, the training plan, intermittent
/// fasting, water and the avoid list.
class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key, this.initialTab = BodyTab.today, this.animateBackdrop = true});

  final BodyTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  late BodyTab _tab = widget.initialTab;

  void _go(BodyTab tab) {
    if (tab == _tab) return;
    Fx.fire(Sfx.navigate);
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Keep the fasting notifications in step with what the screen changes.
    ref.watch(bodyReminderSyncProvider);
    final fab = switch (_tab) {
      BodyTab.today => (Icons.add_task_rounded, l.bodyLogExtra, () => BodyActions.logWithDetails(context, ref)),
      BodyTab.plan => (Icons.add_rounded, l.bodyAddExercise, () => BodyActions.addExercise(context, ref)),
      BodyTab.avoid => (Icons.add_rounded, l.bodyAvoidAdd, () => BodyActions.addAvoid(context, ref)),
      BodyTab.fasting || BodyTab.water => null,
    };
    return MadarScaffold(
      title: l.bodyTitle,
      backdropSeed: 6.2,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: fab == null
          ? null
          : MadarButton.icon(
              key: const ValueKey('body.fab'),
              icon: fab.$1,
              semanticLabel: fab.$2,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: fab.$3,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: BodyTabBar<BodyTab>(
              tabs: BodyTab.values,
              value: _tab,
              labels: {
                BodyTab.today: l.bodyTabToday,
                BodyTab.plan: l.bodyTabPlan,
                BodyTab.fasting: l.bodyTabFasting,
                BodyTab.water: l.bodyTabWater,
                BodyTab.avoid: l.bodyTabAvoid,
              },
              icons: const {
                BodyTab.today: Icons.wb_sunny_outlined,
                BodyTab.plan: Icons.event_note_rounded,
                BodyTab.fasting: Icons.nights_stay_rounded,
                BodyTab.water: Icons.water_drop_outlined,
                BodyTab.avoid: Icons.do_not_disturb_on_outlined,
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: BodyFadeStack(
                index: _tab.index,
                children: [
                  BodyTodayTab(
                    key: const ValueKey('body.today'),
                    onOpenPlan: () => _go(BodyTab.plan),
                    onOpenFasting: () => _go(BodyTab.fasting),
                    onOpenWater: () => _go(BodyTab.water),
                    onOpenAvoid: () => _go(BodyTab.avoid),
                  ),
                  const BodyPlanTab(key: ValueKey('body.plan')),
                  const BodyFastingTab(key: ValueKey('body.fasting')),
                  const BodyWaterTab(key: ValueKey('body.water')),
                  const BodyAvoidTab(key: ValueKey('body.avoid')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
