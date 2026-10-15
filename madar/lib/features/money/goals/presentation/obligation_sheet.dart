import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_snapshot.dart';
import 'goals_actions.dart';
import 'goals_tiles.dart' show DueLeaf;
import 'goals_ui.dart';

/// Opens [ObligationSheet] for [obligationId].
Future<void> showObligationSheet(BuildContext context, String obligationId) =>
    showInteractionSheet<void>(context, builder: (_) => ObligationSheet(obligationId: obligationId));

/// A recurring obligation in detail: the next due date (and how many
/// periods are waiting), the dates after it, where it is paid from, its
/// history of payments and skips (deletable with undo), and the actions –
/// Paid, Skip, pause / resume, edit, delete. Follows the database live.
class ObligationSheet extends ConsumerWidget {
  const ObligationSheet({super.key, required this.obligationId});

  final String obligationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final view = ref.watch(goalsObligationProvider(obligationId));
    if (view == null) {
      return InteractionSheetFrame(
        title: l.goalsObligationsTitle,
        icon: GoalsIcons.obligations,
        body: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Center(
            child: Text(l.goalsGone, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
          ),
        ),
      );
    }
    final o = view.obligation;
    final s = view.state;
    final actions = GoalsActions(context, ref);
    final snap = ref.watch(goalsSnapshotProvider);
    final wallet = o.walletId == null ? null : snap?.wallets[o.walletId];
    final item = o.budgetItemId == null ? null : snap?.budgetItems[o.budgetItemId];
    final tone = s.active ? dueColor(t, s.dueState) : t.textTertiary;

    Future<void> run(Future<UndoableAction?> Function() f, {bool close = false}) async {
      final action = await f();
      if (!close) {
        if (context.mounted) await goalsUndoToast(context, action);
        return;
      }
      if (!context.mounted) return;
      // The toast outlives this page: show it from the navigator below.
      final host = Navigator.of(context).context;
      Navigator.of(context).maybePop();
      if (host.mounted) await goalsUndoToast(host, action);
    }

    return InteractionSheetFrame(
      title: o.name,
      subtitle: '${texts.money(o.amountMilli, o.currency)} · ${texts.recurrence(o.frequency, o.interval)}',
      icon: GoalsIcons.obligations,
      footer: Row(
        children: [
          if (s.active) ...[
            Expanded(
              flex: 3,
              child: SheetButton(
                label: l.goalsMarkPaid,
                icon: GoalsIcons.paid,
                primary: true,
                onPressed: () => run(() => actions.pay(view)),
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              flex: 2,
              child: SheetButton(
                label: l.goalsSkip,
                icon: GoalsIcons.skip,
                onPressed: () => run(() => actions.skip(view)),
              ),
            ),
          ] else
            Expanded(
              child: SheetButton(
                label: l.goalsResume,
                icon: GoalsIcons.resume,
                primary: true,
                onPressed: () => run(() => actions.setActive(view, true)),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoalsHeaderCard(
            seed: 3.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DueLeaf(date: s.nextDue, color: s.active ? tone : t.brass, size: 56),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: GoalsFigure(
                        label: s.active ? l.goalsNextDue : l.goalsPaused,
                        value: s.active ? texts.dueRelative(s.nextDue, today) : texts.date(s.nextDue),
                        color: s.active && s.dueState != DueState.later ? tone : null,
                        caption: s.active ? texts.date(s.nextDue, style: MadarDateStyle.full) : null,
                      ),
                    ),
                  ],
                ),
                if (s.active && s.periodsDue > 1) ...[
                  const SizedBox(height: Space.m),
                  GoalsPill(
                    label: texts.fmt.localizeDigits(l.goalsPeriodsDue(s.periodsDue, texts.fmt.formatInt(s.periodsDue))),
                    color: t.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
                if (wallet != null || item != null) ...[
                  const SizedBox(height: Space.m),
                  if (wallet != null)
                    _InfoLine(icon: GoalsIcons.wallet, text: l.goalsPaidFrom(texts.user(wallet.name))),
                  if (item != null)
                    _InfoLine(icon: Icons.pie_chart_outline_rounded, text: l.goalsCountsToward(texts.user(item.name))),
                ] else ...[
                  const SizedBox(height: Space.m),
                  _InfoLine(icon: Icons.info_outline_rounded, text: l.goalsNoWalletHint),
                ],
              ],
            ),
          ),
          if (s.active) ...[
            GoalsSectionTitle(l.goalsComingUp),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final d in s.upcoming(5).skip(1))
                  GoalsPill(label: texts.shortDate(d, today), color: t.brass, icon: Icons.event_outlined),
              ],
            ),
          ],
          GoalsSectionTitle(
            l.goalsHistory,
            count: view.payments.isEmpty ? null : texts.fmt.formatInt(view.payments.length),
          ),
          if (view.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.m),
              child: Text(
                l.goalsNoHistory,
                style: text.bodySmall?.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final p in view.payments.take(24))
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _HistoryRow(payment: p, view: view, onDelete: () => actions.deleteObligationPayment(p)),
              ),
          if ((o.note ?? '').isNotEmpty) ...[
            const SizedBox(height: Space.s),
            _InfoLine(icon: GoalsIcons.note, text: o.note!),
          ],
          const SizedBox(height: Space.m),
          GoalsSheetActions(
            actions: [
              GoalsSheetAction(
                icon: Icons.edit_outlined,
                label: l.actionEdit,
                sfx: Sfx.sheetOpen,
                onTap: () => actions.editObligation(o),
              ),
              if (s.active) ...[
                GoalsSheetAction(
                  icon: Icons.tune_rounded,
                  label: l.goalsPayOtherShort,
                  sfx: Sfx.sheetOpen,
                  onTap: () => run(() => actions.payCustom(view)),
                ),
                GoalsSheetAction(
                  icon: GoalsIcons.pause,
                  label: l.goalsPause,
                  onTap: () => run(() => actions.setActive(view, false)),
                ),
              ],
              GoalsSheetAction(
                icon: Icons.delete_outline_rounded,
                label: l.actionDelete,
                sfx: Sfx.delete,
                danger: true,
                onTap: () => run(() => actions.deleteObligation(view), close: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.payment, required this.view, required this.onDelete});

  final ObligationPaymentRow payment;
  final ObligationView view;
  final Future<UndoableAction?> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final skipped = ObligationView.isSkip(payment);
    final amount = texts.money(payment.amountMilli, view.obligation.currency);
    final due = texts.shortDate(payment.dueDate, today);
    final paidOn = texts.shortDate(payment.paidAt, today);
    final title = skipped ? l.goalsSkippedEntry : amount;
    final sub = skipped ? l.goalsForDue(due) : l.goalsPaidOnForDue(paidOn, due);
    return ActionableItem(
      semanticLabel: '$title. $sub',
      borderRadius: BorderRadius.circular(t.radiusM),
      swipeEnabled: false,
      actions: ItemActions(onDelete: onDelete),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: Row(
          children: [
            Icon(skipped ? GoalsIcons.skip : GoalsIcons.paid, size: 18, color: skipped ? t.textTertiary : t.success),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: skipped ? FontWeight.w400 : FontWeight.w600,
                      color: skipped ? t.textSecondary : t.textPrimary,
                    ),
                  ),
                  Text(sub, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
            if (!skipped && payment.transactionId != null)
              Tooltip(
                message: l.goalsRecordedInLedger,
                child: Icon(Icons.receipt_long_outlined, size: 16, color: t.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}
