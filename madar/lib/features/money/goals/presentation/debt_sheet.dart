import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/goals_snapshot.dart';
import 'goals_actions.dart';
import 'goals_ui.dart';

/// Opens [DebtSheet] for [debtId].
Future<void> showDebtSheet(BuildContext context, String debtId) =>
    showInteractionSheet<void>(context, builder: (_) => DebtSheet(debtId: debtId));

/// A debt in detail: what is left of what, when it is due, every payment
/// (deletable with undo), and the actions – record a payment, settle or
/// reopen, edit, delete. Follows the database live.
class DebtSheet extends ConsumerWidget {
  const DebtSheet({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final debt = ref.watch(goalsDebtProvider(debtId));
    if (debt == null) {
      return InteractionSheetFrame(
        title: l.goalsDebtsTitle,
        icon: GoalsIcons.debts,
        body: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Center(
            child: Text(l.goalsGone, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
          ),
        ),
      );
    }
    final d = debt.debt;
    final s = debt.state;
    final iOwe = d.direction == DebtDirection.iOwe;
    final color = debtColor(t, d.direction);
    final actions = GoalsActions(context, ref);

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
      title: d.person,
      subtitle: iOwe ? l.goalsDebtIOweSubtitle : l.goalsDebtOwedSubtitle,
      icon: iOwe ? GoalsIcons.iOwe : GoalsIcons.owedToMe,
      footer: Row(
        children: [
          if (!s.settled) ...[
            Expanded(
              child: SheetButton(
                label: l.goalsRecordPayment,
                icon: GoalsIcons.paid,
                primary: true,
                sfx: Sfx.sheetOpen,
                onPressed: () => run(() => actions.recordPayment(debt)),
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: SheetButton(
                label: l.goalsSettle,
                icon: GoalsIcons.settle,
                tone: t.success,
                onPressed: () => run(() => actions.settle(debt)),
              ),
            ),
          ] else if (s.explicitlySettled)
            Expanded(
              child: SheetButton(
                label: l.goalsReopen,
                icon: GoalsIcons.reopen,
                onPressed: () => run(() => actions.reopen(debt)),
              ),
            )
          else
            Expanded(
              child: SheetButton(
                label: l.actionClose,
                sfx: Sfx.sheetClose,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DebtHero(debt: debt, color: color),
          if ((d.note ?? '').isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Container(
              padding: const EdgeInsets.all(Space.m),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusM),
                color: t.glassFill,
                border: Border.all(color: t.glassBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(GoalsIcons.note, size: 16, color: t.textTertiary),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      d.note!,
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                      textDirection: BidiIsolate.directionOf(d.note!),
                    ),
                  ),
                ],
              ),
            ),
          ],
          GoalsSectionTitle(
            l.goalsPayments,
            count: debt.payments.isEmpty ? null : texts.fmt.formatInt(debt.payments.length),
          ),
          if (debt.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.m),
              child: Text(
                l.goalsNoPayments,
                style: text.bodySmall?.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final p in debt.payments)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _PaymentRow(payment: p, debt: debt, onDelete: () => actions.deleteDebtPayment(p)),
              ),
          if (s.explicitlySettled && s.settledOn != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs, bottom: Space.s),
              child: Row(
                children: [
                  Icon(GoalsIcons.settle, size: 16, color: t.success),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      s.writtenOffMilli > 0
                          ? l.goalsSettledWrittenOff(
                              texts.shortDate(s.settledOn!, today),
                              texts.money(s.writtenOffMilli, d.currency),
                            )
                          : l.goalsSettledOn(texts.shortDate(s.settledOn!, today)),
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.m),
          GoalsSheetActions(
            actions: [
              GoalsSheetAction(
                icon: Icons.edit_outlined,
                label: l.actionEdit,
                sfx: Sfx.sheetOpen,
                onTap: () => actions.editDebt(d),
              ),
              if (!s.settled)
                GoalsSheetAction(
                  icon: GoalsIcons.paid,
                  label: l.goalsRecordPayment,
                  sfx: Sfx.sheetOpen,
                  onTap: () => run(() => actions.recordPayment(debt)),
                ),
              GoalsSheetAction(
                icon: Icons.delete_outline_rounded,
                label: l.actionDelete,
                sfx: Sfx.delete,
                danger: true,
                onTap: () => run(() => actions.deleteDebt(debt), close: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtHero extends ConsumerWidget {
  const _DebtHero({required this.debt, required this.color});

  final DebtView debt;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final s = debt.state;
    final d = debt.debt;
    final due = debtDuePhrase(texts, s, today);
    return GoalsHeaderCard(
      seed: 2.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GoalsMedallion(
                color: color,
                label: goalsInitial(d.person),
                size: 52,
                badge: d.direction == DebtDirection.iOwe ? GoalsIcons.iOwe : GoalsIcons.owedToMe,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: GoalsFigure(
                  label: s.settled ? l.goalsSettled : l.goalsRemaining,
                  value: texts.money(s.settled ? s.paidMilli : s.remainingMilli, d.currency),
                  color: s.settled ? t.success : (t.isDark ? color : t.textPrimary),
                  large: true,
                  caption: l.goalsOfTotal(texts.money(s.amountMilli, d.currency)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          GoalsBar(value: s.paidRatio, color: s.settled ? t.success : color, height: 6),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.goalsPaidSoFar(texts.money(s.paidMilli, d.currency)),
                  style: text.labelMedium?.copyWith(color: t.textSecondary),
                ),
              ),
              GoalsPill(
                label: due,
                color: s.settled ? t.success : (s.dueDate == null ? t.textTertiary : dueColor(t, s.dueState)),
                icon: s.dueDate == null && !s.settled ? null : GoalsIcons.calendar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment, required this.debt, required this.onDelete});

  final DebtPaymentRow payment;
  final DebtView debt;
  final Future<UndoableAction?> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final color = debtColor(t, debt.debt.direction);
    final amount = texts.money(payment.amountMilli, debt.debt.currency);
    final date = texts.shortDate(payment.date, today);
    return ActionableItem(
      semanticLabel: '$amount, $date${payment.note == null ? '' : ', ${payment.note}'}',
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
            Icon(GoalsIcons.paid, size: 18, color: color),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(amount, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if ((payment.note ?? '').isNotEmpty)
                    Text(
                      payment.note!,
                      style: text.labelSmall?.copyWith(color: t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(date, style: text.labelMedium?.copyWith(color: t.textSecondary)),
          ],
        ),
      ),
    );
  }
}
