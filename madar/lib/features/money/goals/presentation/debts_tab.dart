import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/debt_ledger.dart';
import '../domain/goals_snapshot.dart';
import 'goals_actions.dart';
import 'goals_tiles.dart';
import 'goals_ui.dart';

/// Which debts the list shows.
enum DebtFilter { all, iOwe, owedToMe }

/// Debts: totals per direction in the base currency, a direction filter,
/// open debts (soonest due first), then the settled ones.
class DebtsTab extends ConsumerStatefulWidget {
  const DebtsTab({super.key});

  @override
  ConsumerState<DebtsTab> createState() => _DebtsTabState();
}

class _DebtsTabState extends ConsumerState<DebtsTab> {
  DebtFilter _filter = DebtFilter.all;
  bool _showSettled = false;

  bool _keep(DebtView d) => switch (_filter) {
    DebtFilter.all => true,
    DebtFilter.iOwe => d.debt.direction == DebtDirection.iOwe,
    DebtFilter.owedToMe => d.debt.direction == DebtDirection.owedToMe,
  };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final snap = ref.watch(goalsSnapshotProvider);
    if (snap == null) return const Center(child: OrbitLoader());
    final texts = goalsTexts(context, ref);
    final open = snap.openDebts.where(_keep).toList();
    final settled = snap.settledDebts.where(_keep).toList();
    final empty = snap.openDebts.isEmpty && snap.settledDebts.isEmpty;
    var index = 0;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, goalsTabBottomPadding),
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: Space.l),
            child: AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.goalsDebtsEmptyTitle,
              body: l.goalsDebtsEmptyBody,
              actionLabel: l.goalsDebtNew,
              actionIcon: Icons.add_rounded,
              onAction: () => GoalsActions(context, ref).addDebt(),
            ),
          )
        else ...[
          StaggerItem(
            index: index++,
            child: DebtTotalsCard(totals: snap.debtTotals),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: index++,
            child: ChoicePills<DebtFilter>.single(
              options: [
                ChoiceOption(value: DebtFilter.all, label: l.goalsFilterAll),
                ChoiceOption(value: DebtFilter.iOwe, label: l.goalsIOwe, icon: GoalsIcons.iOwe, color: t.warning),
                ChoiceOption(
                  value: DebtFilter.owedToMe,
                  label: l.goalsOwedToMe,
                  icon: GoalsIcons.owedToMe,
                  color: t.success,
                ),
              ],
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f ?? DebtFilter.all),
              dense: true,
            ),
          ),
          const SizedBox(height: Space.s),
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: Text(
                l.goalsNoOpenDebts,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              ),
            ),
          for (final d in open)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: StaggerItem(
                index: index++,
                child: DebtTile(key: ValueKey(d.id), debt: d),
              ),
            ),
          if (settled.isNotEmpty) ...[
            GoalsSectionTitle(
              l.goalsSettledDebts,
              count: texts.fmt.formatInt(settled.length),
              color: t.textSecondary,
              trailing: MadarButton(
                label: _showSettled ? l.goalsHide : l.goalsShow,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: _showSettled ? Sfx.toggleOff : Sfx.toggleOn,
                onPressed: () => setState(() => _showSettled = !_showSettled),
              ),
            ),
            AnimatedSize(
              duration: context.motion(MadarMotion.medium),
              curve: MadarMotion.emphasized,
              alignment: AlignmentDirectional.topCenter,
              child: _showSettled
                  ? Column(
                      children: [
                        for (final d in settled)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.s),
                            child: DebtTile(key: ValueKey(d.id), debt: d),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: Space.m),
            child: Text(
              l.goalsDebtsHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Open debts per direction in the base currency, and the balance.
class DebtTotalsCard extends ConsumerWidget {
  const DebtTotalsCard({super.key, required this.totals});

  final DebtTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final fmt = texts.fmt;
    final net = totals.netBaseMilli;
    return GoalsHeaderCard(
      seed: 2.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DirectionTotal(
                    icon: GoalsIcons.iOwe,
                    color: t.warning,
                    label: l.goalsIOwe,
                    value: texts.base(totals.iOweBaseMilli),
                    count: fmt.localizeDigits(l.goalsDebtsCount(totals.iOweCount, fmt.formatInt(totals.iOweCount))),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: Space.m),
                  color: t.glassBorder,
                ),
                Expanded(
                  child: _DirectionTotal(
                    icon: GoalsIcons.owedToMe,
                    color: t.success,
                    label: l.goalsOwedToMe,
                    value: texts.base(totals.owedToMeBaseMilli),
                    count: fmt.localizeDigits(
                      l.goalsDebtsCount(totals.owedToMeCount, fmt.formatInt(totals.owedToMeCount)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          MadarDivider(height: 14, color: t.brass.withValues(alpha: 0.5)),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Icon(Icons.balance_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  net == 0
                      ? l.goalsNetEven
                      : (net > 0 ? l.goalsNetOwedToMe(texts.base(net)) : l.goalsNetIOwe(texts.base(-net))),
                  style: text.bodyMedium?.copyWith(color: t.textPrimary),
                ),
              ),
              if (totals.overdueCount > 0)
                GoalsPill(
                  label: fmt.localizeDigits(
                    l.goalsOverdueCount(totals.overdueCount, fmt.formatInt(totals.overdueCount)),
                  ),
                  color: t.danger,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          if (totals.missingRates.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(
              l.goalsMissingRates(totals.missingRates.join('، ')),
              style: text.labelSmall?.copyWith(color: t.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectionTotal extends StatelessWidget {
  const _DirectionTotal({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value. $count',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: Space.xs),
              Text(label, style: text.labelMedium?.copyWith(color: t.isDark ? color : t.textSecondary)),
            ],
          ),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: t.textPrimary),
            ),
          ),
          Text(count, style: text.labelSmall?.copyWith(color: t.textTertiary)),
        ],
      ),
    );
  }
}
