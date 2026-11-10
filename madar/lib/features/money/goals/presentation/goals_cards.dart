import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_snapshot.dart';
import 'astrolabe_ring.dart';
import 'debt_sheet.dart';
import 'goals_actions.dart';
import 'goals_navigation.dart';
import 'goals_screen.dart' show GoalsTab;
import 'goals_tiles.dart';
import 'goals_ui.dart';
import 'obligation_sheet.dart';

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, this.trailing, this.onSeeAll});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: t.gold),
        const SizedBox(width: Space.s),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: text.titleSmall?.copyWith(color: t.gold, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        ?trailing,
        if (onSeeAll != null)
          MadarButton(
            label: l.goalsSeeAll,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.navigate,
            onPressed: onSeeAll,
          ),
      ],
    );
  }
}

/// Compact card for the Money hub: overdue and upcoming obligations and
/// debts (next [withinDays] days), each with its amount and when it is
/// due; obligations can be marked paid right here (with undo).
class UpcomingDuesCard extends ConsumerWidget {
  const UpcomingDuesCard({
    super.key,
    this.withinDays = 14,
    this.maxItems = 4,
    this.onSeeAll,
    this.hideWhenEmpty = false,
  });

  final int withinDays;
  final int maxItems;

  /// Defaults to the goals screen on the obligations tab.
  final VoidCallback? onSeeAll;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final snap = ref.watch(goalsSnapshotProvider);
    if (snap == null) return const SizedBox.shrink();
    final texts = goalsTexts(context, ref);
    final dues = snap.dues(withinDays: withinDays);
    if (dues.isEmpty && hideWhenEmpty) return const SizedBox.shrink();
    final seeAll = onSeeAll ?? () => ref.read(goalsNavigationProvider).openGoals(context, tab: GoalsTab.obligations);
    final overdue = dues.where((d) => d.state == DueState.overdue).length;
    return GlassCard(
      seed: 4.1,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: GoalsIcons.obligations,
            title: l.goalsUpcomingTitle,
            onSeeAll: seeAll,
            trailing: overdue > 0
                ? GoalsPill(
                    label: texts.fmt.localizeDigits(l.goalsOverdueCount(overdue, texts.fmt.formatInt(overdue))),
                    color: t.danger,
                    filled: true,
                  )
                : null,
          ),
          const SizedBox(height: Space.s),
          if (dues.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s),
              child: Text(texts.nothingDue(withinDays), style: text.bodySmall?.copyWith(color: t.textSecondary)),
            )
          else
            for (final (i, d) in dues.take(maxItems).indexed)
              StaggerItem(
                index: i,
                child: _DueRow(entry: d, today: snap.today),
              ),
          if (dues.length > maxItems)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                texts.fmt.localizeDigits(
                  l.goalsMoreDues(dues.length - maxItems, texts.fmt.formatInt(dues.length - maxItems)),
                ),
                style: text.labelSmall?.copyWith(color: t.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.entry, required this.today});

  final DueEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final tone = dueColor(t, entry.state);
    final o = entry.obligation;
    final d = entry.debt;
    final subtitle = o != null
        ? texts.recurrence(o.obligation.frequency, o.obligation.interval)
        : (d!.debt.direction == DebtDirection.iOwe ? l.goalsIOwe : l.goalsOwedToMe);
    final due = texts.dueRelative(entry.due, today);
    final amount = texts.money(entry.amountMilli, entry.currency);
    return MadarPressable(
      semanticLabel: '${entry.title}. $amount. $due. $subtitle',
      sfx: Sfx.sheetOpen,
      onTap: () => o != null ? showObligationSheet(context, o.id) : showDebtSheet(context, d!.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            DueLeaf(date: entry.due, color: entry.state == DueState.later ? t.brass : tone, size: 38),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1),
                  Text(
                    '$due · $subtitle',
                    style: text.labelSmall?.copyWith(color: entry.state == DueState.later ? t.textTertiary : tone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(amount, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: Space.xs),
            // Obligations are marked paid in place; debts take a payment
            // (both undoable) – one column of actions keeps the amounts aligned.
            MadarButton.icon(
              icon: GoalsIcons.paid,
              semanticLabel: o != null
                  ? l.goalsMarkPaidFor(entry.title)
                  : (d!.debt.direction == DebtDirection.iOwe
                        ? l.goalsPayTo(texts.user(entry.title))
                        : l.goalsReceiveFrom(texts.user(entry.title))),
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: o != null ? Sfx.tap : Sfx.sheetOpen,
              onPressed: () async {
                final actions = GoalsActions(context, ref);
                final action = o != null ? await actions.pay(o) : await actions.recordPayment(d!);
                if (context.mounted) await goalsUndoToast(context, action);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card for the Money hub: the first active jars as small
/// astrolabe rings and the total saved (base currency).
class JarsCard extends ConsumerWidget {
  const JarsCard({super.key, this.maxJars = 3, this.onSeeAll, this.hideWhenEmpty = false});

  final int maxJars;

  /// Defaults to the goals screen on the jars tab.
  final VoidCallback? onSeeAll;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final snap = ref.watch(goalsSnapshotProvider);
    if (snap == null) return const SizedBox.shrink();
    final texts = goalsTexts(context, ref);
    final jars = snap.jars;
    if (jars.isEmpty && hideWhenEmpty) return const SizedBox.shrink();
    final nav = ref.read(goalsNavigationProvider);
    final seeAll = onSeeAll ?? () => nav.openGoals(context, tab: GoalsTab.jars);
    return GlassCard(
      seed: 1.2,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.l),
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(icon: GoalsIcons.jars, title: l.goalsTabJars, onSeeAll: seeAll),
          if (jars.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.goalsJarsEmptyBody, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ),
                  const SizedBox(width: Space.s),
                  MadarButton(
                    label: l.goalsJarNew,
                    icon: Icons.add_rounded,
                    size: MadarButtonSize.small,
                    variant: MadarButtonVariant.secondary,
                    sfx: Sfx.sheetOpen,
                    onPressed: () => GoalsActions(context, ref).addJar(),
                  ),
                ],
              ),
            )
          else ...[
            const SizedBox(height: Space.xs),
            Text(
              l.goalsSavedTotal(texts.base(snap.jarsSavedBaseMilli)),
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, j) in jars.take(maxJars).indexed)
                  Expanded(
                    child: StaggerItem(
                      index: i,
                      child: MadarPressable(
                        semanticLabel: '${j.jar.name}. ${texts.percent(j.plan.progress)}',
                        sfx: Sfx.navigate,
                        onTap: () => nav.openJar(context, j.id),
                        child: Column(
                          children: [
                            AstrolabeProgressRing(
                              progress: j.plan.progress,
                              expected: j.plan.expectedProgress,
                              size: 74,
                              dense: true,
                              color: jarColor(t, j),
                              reached: j.plan.reached,
                              child: Text(
                                texts.percent(j.plan.progress),
                                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Text(
                              j.jar.name,
                              style: text.labelMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              texts.money(j.plan.savedMilli, j.jar.currency),
                              style: text.labelSmall?.copyWith(color: t.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
