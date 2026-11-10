import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import 'budget_actions.dart';
import 'plan_view.dart';
import 'spending_view.dart';
import 'widgets/budget_widgets.dart';

enum BudgetTab { plan, spending }

/// The budget: a Plan tab (the nested tree editor with totals, allocation
/// and warnings) and a Spending tab (spend vs plan per month or week,
/// projections and history).
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key, this.initialTab = BudgetTab.plan, this.animateBackdrop = true});

  final BudgetTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late BudgetTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final plan = _tab == BudgetTab.plan;
    return MadarScaffold(
      title: l.budgetTitle,
      backdropSeed: 7.7,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: AnimatedScale(
        scale: plan ? 1 : 0,
        duration: context.motion(MadarMotion.medium),
        curve: plan ? Curves.easeOutBack : MadarMotion.accelerate,
        child: ExcludeSemantics(
          excluding: !plan,
          child: MadarButton.icon(
            icon: Icons.add_rounded,
            variant: MadarButtonVariant.primary,
            size: MadarButtonSize.large,
            semanticLabel: l.budgetAddItem,
            onPressed: plan ? () => BudgetActions(ref, context).add() : null,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: BudgetSegmented<BudgetTab>(
              values: BudgetTab.values,
              value: _tab,
              height: 54,
              labels: {BudgetTab.plan: l.budgetTabPlan, BudgetTab.spending: l.budgetTabSpending},
              icons: const {BudgetTab.plan: Icons.account_tree_rounded, BudgetTab.spending: Icons.insights_rounded},
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: ('budget', _tab),
              child: _FadeStack(
                index: _tab.index,
                children: [
                  const _EdgeFade(child: BudgetPlanView(key: ValueKey('budget.plan'))),
                  _EdgeFade(
                    child: BudgetSpendingView(
                      key: const ValueKey('budget.spending'),
                      onEmptyAction: () {
                        setState(() => _tab = BudgetTab.plan);
                        BudgetActions(ref, context).add();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Softens the top edge where the list scrolls under the tab bar.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, (18 / rect.height).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Shows the selected tab only and cross-fades between them: a thin name
/// for [MadarFadeStack] (see it for why nothing is kept hidden behind).
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MadarFadeStack(index: index, children: children);
}

