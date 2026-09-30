import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_snapshot.dart';
import '../domain/jar_plan.dart';
import '../goals_texts.dart';
import 'astrolabe_ring.dart';
import 'debt_sheet.dart';
import 'goals_actions.dart';
import 'goals_navigation.dart';
import 'goals_ui.dart';
import 'obligation_sheet.dart';

/// The colour of a jar (its own, or the theme accent).
Color jarColor(MadarTokens t, JarView jar) => jar.jar.color == null ? t.accent : Color(jar.jar.color!);

/// A short pace phrase for a jar.
String jarPacePhrase(GoalsTexts texts, JarPlan plan, DateTime today) {
  final l = texts.l;
  return switch (plan.pace) {
    JarPace.reached => l.goalsPaceReached,
    JarPace.overdue => l.goalsPaceOverdue,
    JarPace.behind => l.goalsPaceBehind,
    JarPace.onTrack => l.goalsPaceOnTrack,
    JarPace.open => l.goalsPaceOpen,
  };
}

Color jarPaceColor(MadarTokens t, JarPace pace) => switch (pace) {
  JarPace.reached => t.gold,
  JarPace.onTrack => t.success,
  JarPace.behind => t.warning,
  JarPace.overdue => t.danger,
  JarPace.open => t.textTertiary,
};

// ================================================================ jars ==

/// A jar row: its astrolabe ring, saved of target, and what it needs.
/// Tap opens the jar; swipe right deposits; swipe left offers deposit and
/// withdraw; long-press edits, archives or deletes.
class JarTile extends ConsumerWidget {
  const JarTile({super.key, required this.jar, this.grip});

  final JarView jar;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final plan = jar.plan;
    final color = jarColor(t, jar);
    final currency = jar.jar.currency;
    final actions = GoalsActions(context, ref);
    final archived = jar.jar.archived;
    final meta = <String>[
      if (plan.requiredPerMonthMilli != null && plan.pace != JarPace.overdue)
        l.goalsNeedPerMonth(texts.money(plan.requiredPerMonthMilli!, currency))
      else if (plan.deadline != null && !plan.reached)
        l.goalsDeadlineOn(texts.shortDate(plan.deadline!, today)),
      if (plan.reached && plan.surplusMilli > 0) l.goalsSurplus(texts.money(plan.surplusMilli, currency)),
    ];
    final saved = texts.money(plan.savedMilli, currency);
    final target = plan.targetMilli > 0 ? texts.money(plan.targetMilli, currency) : null;
    return ActionableItem(
      semanticLabel: [
        jar.jar.name,
        target == null ? saved : l.goalsSavedOfTarget(saved, target),
        jarPacePhrase(texts, plan, today),
        ...meta,
      ].join('. '),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => ref.read(goalsNavigationProvider).openJar(context, jar.id),
      completeIcon: GoalsIcons.deposit,
      completeLabel: l.goalsDeposit,
      onCompleteSwipe: archived ? null : () => actions.moveMoney(jar),
      actions: ItemActions(
        onEdit: () => actions.editJar(jar.jar),
        onDelete: () => actions.deleteJar(jar),
        extra: [
          if (!archived)
            ItemAction(
              icon: GoalsIcons.withdraw,
              label: l.goalsWithdraw,
              onSelected: () => actions.moveMoney(jar, withdraw: true),
            ),
          ItemAction(
            icon: archived ? GoalsIcons.unarchive : GoalsIcons.archive,
            label: archived ? l.goalsUnarchive : l.goalsArchive,
            tone: ActionTone.warning,
            onSelected: () => actions.setArchived(jar, !archived),
          ),
        ],
      ),
      quickActions: [
        if (!archived) ...[
          QuickAction(
            icon: GoalsIcons.deposit,
            label: l.goalsDeposit,
            tone: ActionTone.success,
            onPressed: () => actions.moveMoney(jar),
          ),
          QuickAction(
            icon: GoalsIcons.withdraw,
            label: l.goalsWithdraw,
            tone: ActionTone.warning,
            onPressed: () => actions.moveMoney(jar, withdraw: true),
          ),
        ] else
          QuickAction(
            icon: GoalsIcons.unarchive,
            label: l.goalsUnarchive,
            onPressed: () => actions.setArchived(jar, false),
          ),
      ],
      child: AnimatedOpacity(
        opacity: archived ? 0.6 : 1,
        duration: context.motion(MadarMotion.short),
        child: GlassCard(
          padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, grip == null ? Space.m : Space.xs, Space.m),
          borderRadius: BorderRadius.circular(t.radiusL),
          glow: plan.reached,
          glowColor: t.metalGold.withValues(alpha: 0.25),
          borderColor: plan.reached ? t.brass.withValues(alpha: 0.7) : null,
          child: Row(
            children: [
              AstrolabeProgressRing(
                progress: plan.progress,
                expected: plan.expectedProgress,
                size: 66,
                dense: true,
                color: color,
                reached: plan.reached,
                child: GoalsJarGlyph(icon: jar.jar.icon, color: plan.reached ? t.gold : color),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            jar.jar.name,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plan.targetMilli > 0)
                          Text(
                            texts.percent(plan.progress),
                            style: text.labelMedium?.copyWith(
                              color: plan.reached ? t.gold : t.textSecondary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: saved,
                            style: text.bodyMedium?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          if (target != null)
                            TextSpan(
                              text: ' ${l.goalsOf} $target',
                              style: text.bodySmall?.copyWith(color: t.textTertiary),
                            ),
                        ],
                      ),
                      // Wraps "of 1,200.000 JOD" at a large text size
                      // rather than cutting the target.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (plan.pace != JarPace.open || plan.targetMilli > 0)
                          GoalsPill(
                            label: jarPacePhrase(texts, plan, today),
                            color: jarPaceColor(t, plan.pace),
                            filled: plan.reached,
                          ),
                        for (final m in meta)
                          Text(m, style: text.labelSmall?.copyWith(color: t.textSecondary), maxLines: 1),
                      ],
                    ),
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================== debts ==

/// A debt row: who, how much is left of how much, and when it is due.
/// Tap opens the debt; swipe right settles it (undo); swipe left records a
/// payment; long-press edits or deletes.
class DebtTile extends ConsumerWidget {
  const DebtTile({super.key, required this.debt, this.grip});

  final DebtView debt;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final s = debt.state;
    final d = debt.debt;
    final iOwe = d.direction == DebtDirection.iOwe;
    final color = debtColor(t, d.direction);
    final actions = GoalsActions(context, ref);
    final due = debtDuePhrase(texts, s, today);
    final dueTone = s.settled ? t.success : dueColor(t, s.dueState);
    final remaining = texts.money(s.settled ? s.amountMilli : s.remainingMilli, d.currency);
    return ActionableItem(
      semanticLabel: [
        iOwe ? l.goalsIOweTo(d.person) : l.goalsOwedBy(d.person),
        s.settled ? l.goalsSettled : l.goalsRemainingOf(remaining, texts.money(s.amountMilli, d.currency)),
        due,
      ].join('. '),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => showDebtSheet(context, debt.id),
      completeIcon: s.settled ? GoalsIcons.reopen : GoalsIcons.settle,
      completeLabel: s.settled ? l.goalsReopen : l.goalsSettle,
      onCompleteSwipe: s.settled
          ? (s.explicitlySettled ? () => actions.reopen(debt) : null)
          : () => actions.settle(debt),
      actions: ItemActions(
        onEdit: () => actions.editDebt(d),
        onDelete: () => actions.deleteDebt(debt),
        extra: [
          if (!s.settled)
            ItemAction(
              icon: GoalsIcons.paid,
              label: l.goalsRecordPayment,
              onSelected: () => actions.recordPayment(debt),
            ),
        ],
      ),
      quickActions: [
        if (!s.settled) ...[
          QuickAction(
            icon: GoalsIcons.paid,
            label: l.goalsRecordPayment,
            tone: ActionTone.accent,
            onPressed: () => actions.recordPayment(debt),
          ),
          QuickAction(
            icon: GoalsIcons.settle,
            label: l.goalsSettle,
            tone: ActionTone.success,
            onPressed: () => actions.settle(debt),
          ),
        ] else if (s.explicitlySettled)
          QuickAction(icon: GoalsIcons.reopen, label: l.goalsReopen, onPressed: () => actions.reopen(debt)),
      ],
      child: AnimatedOpacity(
        opacity: s.settled ? 0.62 : 1,
        duration: context.motion(MadarMotion.short),
        child: GlassCard(
          padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, grip == null ? Space.m : Space.xs, Space.m),
          borderRadius: BorderRadius.circular(t.radiusL),
          borderColor: s.overdue ? t.danger.withValues(alpha: 0.55) : null,
          glow: s.overdue,
          glowColor: t.danger.withValues(alpha: 0.18),
          child: Row(
            children: [
              GoalsMedallion(
                color: color,
                label: goalsInitial(d.person),
                badge: iOwe ? GoalsIcons.iOwe : GoalsIcons.owedToMe,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            d.person,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        Text(
                          remaining,
                          style: text.titleSmall?.copyWith(
                            color: s.settled ? t.textTertiary : (t.isDark ? color : t.textPrimary),
                            fontWeight: FontWeight.w700,
                            decoration: s.settled ? TextDecoration.lineThrough : null,
                            decorationColor: t.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          iOwe ? l.goalsIOwe : l.goalsOwedToMe,
                          style: text.labelSmall?.copyWith(color: t.isDark ? color : t.textSecondary),
                        ),
                        Text(' · ', style: text.labelSmall?.copyWith(color: t.textTertiary)),
                        Flexible(
                          child: Text(
                            due,
                            style: text.labelSmall?.copyWith(
                              color: s.dueState == DueState.later || s.dueState == DueState.none && !s.settled
                                  ? t.textSecondary
                                  : dueTone,
                              fontWeight: s.overdue ? FontWeight.w600 : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!s.settled && s.paidMilli > 0) ...[
                          const SizedBox(width: Space.s),
                          Text(
                            l.goalsOfTotal(texts.money(s.amountMilli, d.currency)),
                            style: text.labelSmall?.copyWith(color: t.textTertiary),
                          ),
                        ],
                      ],
                    ),
                    if (!s.settled && s.paidMilli > 0) ...[
                      const SizedBox(height: Space.s),
                      GoalsBar(value: s.paidRatio, color: color, height: 4),
                    ],
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================= obligations ==

/// A small calendar leaf: the day number over the month name, tinted by
/// how close the date is.
class DueLeaf extends StatelessWidget {
  const DueLeaf({super.key, required this.date, required this.color, this.size = 48});

  final DateTime date;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    return Container(
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fmt.formatInt(date.day),
            style: text.titleMedium?.copyWith(
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: t.isDark ? t.textPrimary : Color.lerp(color, t.textPrimary, 0.55),
            ),
          ),
          Text(
            goalsMonthShort(fmt, date),
            style: text.labelSmall?.copyWith(height: 1.1, color: t.isDark ? color : t.textSecondary),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// An obligation row: its next due date, amount, recurrence and where it
/// is paid from. Swipe right = "Paid" (undo); swipe left = Paid / Skip;
/// long-press edits, pauses or deletes; tap opens its history.
class ObligationTile extends ConsumerWidget {
  const ObligationTile({super.key, required this.obligation, this.grip});

  final ObligationView obligation;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final snap = ref.watch(goalsSnapshotProvider);
    final today = ref.watch(goalsTodayProvider);
    final o = obligation.obligation;
    final s = obligation.state;
    final actions = GoalsActions(context, ref);
    final tone = s.active ? dueColor(t, s.dueState) : t.textTertiary;
    final wallet = o.walletId == null ? null : snap?.wallets[o.walletId];
    final item = o.budgetItemId == null ? null : snap?.budgetItems[o.budgetItemId];
    final due = s.active ? texts.dueRelative(s.nextDue, today) : l.goalsPaused;
    final where = [?wallet?.name, ?item?.name].join(' · ');
    return ActionableItem(
      semanticLabel: [
        o.name,
        texts.money(o.amountMilli, o.currency),
        texts.recurrence(o.frequency, o.interval),
        due,
        if (s.periodsDue > 1) l.goalsPeriodsDue(s.periodsDue, texts.fmt.formatInt(s.periodsDue)),
      ].join('. '),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => showObligationSheet(context, obligation.id),
      completeIcon: GoalsIcons.paid,
      completeLabel: l.goalsMarkPaid,
      onCompleteSwipe: s.active ? () => actions.pay(obligation) : null,
      actions: ItemActions(
        onEdit: () => actions.editObligation(o),
        onDelete: () => actions.deleteObligation(obligation),
        extra: [
          if (s.active) ...[
            ItemAction(icon: GoalsIcons.paid, label: l.goalsPayOther, onSelected: () => actions.payCustom(obligation)),
            ItemAction(icon: GoalsIcons.skip, label: l.goalsSkip, onSelected: () => actions.skip(obligation)),
          ],
          ItemAction(
            icon: s.active ? GoalsIcons.pause : GoalsIcons.resume,
            label: s.active ? l.goalsPause : l.goalsResume,
            tone: s.active ? ActionTone.warning : ActionTone.success,
            onSelected: () => actions.setActive(obligation, !s.active),
          ),
        ],
      ),
      quickActions: [
        if (s.active) ...[
          QuickAction(
            icon: GoalsIcons.paid,
            label: l.goalsMarkPaid,
            tone: ActionTone.success,
            onPressed: () => actions.pay(obligation),
          ),
          QuickAction(
            icon: GoalsIcons.skip,
            label: l.goalsSkip,
            tone: ActionTone.warning,
            onPressed: () => actions.skip(obligation),
          ),
        ] else
          QuickAction(
            icon: GoalsIcons.resume,
            label: l.goalsResume,
            onPressed: () => actions.setActive(obligation, true),
          ),
      ],
      child: AnimatedOpacity(
        opacity: s.active ? 1 : 0.55,
        duration: context.motion(MadarMotion.short),
        child: GlassCard(
          padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, grip == null ? Space.m : Space.xs, Space.m),
          borderRadius: BorderRadius.circular(t.radiusL),
          borderColor: s.overdue ? t.danger.withValues(alpha: 0.55) : null,
          glow: s.overdue,
          glowColor: t.danger.withValues(alpha: 0.18),
          child: Row(
            children: [
              DueLeaf(date: s.nextDue, color: s.active && s.dueState != DueState.later ? tone : t.brass),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            o.name,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        Text(
                          texts.money(o.amountMilli, o.currency),
                          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            due,
                            style: text.labelSmall?.copyWith(
                              color: s.dueState == DueState.later ? t.textSecondary : tone,
                              fontWeight: s.overdue || s.dueState == DueState.today ? FontWeight.w600 : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(' · ', style: text.labelSmall?.copyWith(color: t.textTertiary)),
                        Flexible(
                          child: Text(
                            texts.recurrence(o.frequency, o.interval),
                            style: text.labelSmall?.copyWith(color: t.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.periodsDue > 1) ...[
                          const SizedBox(width: Space.s),
                          GoalsPill(
                            label: texts.fmt.localizeDigits(
                              l.goalsPeriodsDue(s.periodsDue, texts.fmt.formatInt(s.periodsDue)),
                            ),
                            color: t.danger,
                          ),
                        ],
                      ],
                    ),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(GoalsIcons.wallet, size: 12, color: t.textTertiary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              where,
                              style: text.labelSmall?.copyWith(color: t.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}
