import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show KitChip;
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../domain/currency_math.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_math.dart';
import '../../domain/ledger_models.dart';
import '../ledger_ui.dart';

/// Opens the "change base currency" sheet: pick a currency, preview every
/// rate before / after and the net balance in the new base, confirm.
Future<void> showRebaseSheet(BuildContext context, WidgetRef ref, {String? initial}) async {
  final book = ref.read(ledgerBookProvider).value;
  if (book == null) return;
  await showInteractionSheet<void>(
    context,
    builder: (_) => RebaseSheet(book: book, initial: initial),
  );
}

class RebaseSheet extends ConsumerStatefulWidget {
  const RebaseSheet({super.key, required this.book, this.initial});

  final LedgerBook book;
  final String? initial;

  @override
  ConsumerState<RebaseSheet> createState() => _RebaseSheetState();
}

class _RebaseSheetState extends ConsumerState<RebaseSheet> {
  late String? _code = widget.initial ?? _candidates.firstOrNull?.code;
  bool _saving = false;

  List<LedgerCurrency> get _candidates => [
    for (final c in widget.book.currencies)
      if (!c.isBase && c.rate != null) c,
  ];

  Future<void> _confirm() async {
    final code = _code;
    if (code == null) return;
    final l = L10n.of(context);
    setState(() => _saving = true);
    final undo = await ref.read(ledgerServiceProvider).rebase(code);
    Fx.fire(Sfx.complete);
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    Navigator.of(context).pop();
    unawaited(
      UndoToast.show(overlay, UndoableAction(label: l.ledgerRebaseDone(LedgerMoneyFormat.isolate(code)), undo: undo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final book = widget.book;
    final fmt = ledgerFormatOf(context, book);
    final plan = _code == null ? null : RebasePlan.of(book.currencies, _code!);
    final one = fmt.number(1000, decimals: 0);

    // The net balance re-expressed in the new base.
    LedgerRates? after;
    if (plan != null) {
      after = LedgerRates.of([
        for (final c in book.currencies)
          c.copyWith(rateToBase: plan.row(c.code)?.stored ?? c.rateToBase, isBase: c.code == plan.newBase),
      ]);
    }
    final totalsAfter = after == null ? null : LedgerTotals.of(book.wallets, book.balances, after);

    return InteractionSheetFrame(
      title: l.ledgerRebaseTitle,
      subtitle: l.ledgerRebaseChoose,
      icon: Icons.published_with_changes_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final c in _candidates)
                KitChip(
                  label: '${c.code} · ${c.name(arabic: fmt.arabic)}',
                  selected: c.code == _code,
                  sfx: Sfx.tap,
                  onTap: () => setState(() => _code = c.code),
                ),
            ],
          ),
          if (plan != null) ...[
            const SizedBox(height: Space.l),
            Text(
              l.ledgerRebaseExplain(LedgerMoneyFormat.isolate(plan.newBase)),
              style: text.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.m),
            AnimatedSwitcher(
              duration: context.motion(MadarMotion.short),
              child: Column(
                key: ValueKey(plan.newBase),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(context, label: '', now: l.ledgerRebaseNow, next: l.ledgerRebaseAfter, header: true),
                  for (final r in plan.rows)
                    _row(
                      context,
                      label: r.code,
                      now: r.oldRate == null
                          ? l.ledgerNoRate
                          : (r.code == plan.oldBase
                                ? '—'
                                : l.ledgerRateLine(
                                    one,
                                    LedgerMoneyFormat.isolate(r.code),
                                    fmt.rate(r.oldRate!),
                                    LedgerMoneyFormat.isolate(plan.oldBase),
                                  )),
                      next: r.newRate == null
                          ? l.ledgerNoRate
                          : (r.code == plan.newBase
                                ? '—'
                                : l.ledgerRateLine(
                                    one,
                                    LedgerMoneyFormat.isolate(r.code),
                                    fmt.rate(r.newRate!),
                                    LedgerMoneyFormat.isolate(plan.newBase),
                                  )),
                      highlight: r.code == plan.newBase || r.code == plan.oldBase,
                    ),
                  if (totalsAfter != null && book.totals.walletCount > 0) ...[
                    const SizedBox(height: Space.s),
                    _row(
                      context,
                      label: l.ledgerNetBalance,
                      now: fmt.amount(book.totals.baseMilli, book.baseCode),
                      next: fmt.amount(totalsAfter.baseMilli, plan.newBase),
                      highlight: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.s),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: SheetButton(
          label: _code == null ? l.ledgerChangeBase : l.ledgerRebaseConfirm(LedgerMoneyFormat.isolate(_code!)),
          icon: Icons.check_rounded,
          primary: true,
          sfx: null,
          onPressed: plan == null || _saving ? null : _confirm,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String now,
    required String next,
    bool header = false,
    bool highlight = false,
  }) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final style = header
        ? text.labelMedium?.copyWith(color: t.textTertiary)
        : LedgerStyle.amount(
            t,
            size: 12.5,
            color: highlight ? t.textPrimary : t.textSecondary,
            weight: FontWeight.w500,
          );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s, horizontal: Space.s),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.glassBorder.withValues(alpha: 0.5), width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 2,
              style: (header ? style : text.labelLarge?.copyWith(color: highlight ? t.accent : t.textPrimary)),
            ),
          ),
          Expanded(child: Text(now, style: style)),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(next, style: style?.copyWith(color: header ? null : (highlight ? t.accent : t.textPrimary))),
          ),
        ],
      ),
    );
  }
}
