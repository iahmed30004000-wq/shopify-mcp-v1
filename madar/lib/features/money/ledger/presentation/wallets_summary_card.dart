import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/ledger_providers.dart';
import 'ledger_actions.dart';
import 'ledger_ui.dart';
import 'widgets/wallet_tile.dart';

/// Compact card for the Money hub: the net balance in the base currency,
/// the personal / business split and the first wallets. Tapping opens
/// [onOpen] (default: the ledger screen).
class WalletsSummaryCard extends ConsumerWidget {
  const WalletsSummaryCard({super.key, this.onOpen, this.maxWallets = 3});

  final VoidCallback? onOpen;
  final int maxWallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final book = ref.watch(ledgerBookProvider).value;
    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!();
      } else {
        LedgerActions.openLedger(context, ref);
      }
    }

    if (book == null) {
      return const GlassCard(
        child: SizedBox(height: 120, child: Center(child: OrbitLoader(size: 30))),
      );
    }
    final fmt = ledgerFormatOf(context, book);
    final active = book.activeWallets;
    final totals = book.totals;
    final header = Row(
      children: [
        LedgerMedallion(icon: Icons.account_balance_wallet_rounded, color: t.accent, size: 34),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(l.ledgerWallets, style: text.titleMedium?.copyWith(color: t.textPrimary)),
        ),
        Icon(
          Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: t.textTertiary,
        ),
      ],
    );
    if (active.isEmpty) {
      return GlassCard(
        onTap: open,
        semanticLabel: l.ledgerWallets,
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: Space.m),
            Text(l.ledgerSummaryEmpty, style: text.titleSmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.xs),
            Text(l.ledgerEmptyBody, style: text.bodySmall?.copyWith(color: t.textTertiary)),
            const SizedBox(height: Space.m),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarButton(
                label: l.ledgerAddWallet,
                icon: Icons.add_rounded,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => LedgerActions.editWallet(context, ref),
              ),
            ),
          ],
        ),
      );
    }
    final shown = active.take(maxWallets).toList();
    final more = active.length - shown.length;
    return GlassCard(
      onTap: open,
      semanticLabel: BidiIsolate.strip(
        '${l.ledgerWallets}، ${l.ledgerNetBalance} ${fmt.amount(totals.baseMilli, book.baseCode)}',
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: Space.m),
          Text(l.ledgerNetBalance, style: text.labelMedium?.copyWith(color: t.textTertiary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              fmt.amount(totals.baseMilli, book.baseCode),
              style: LedgerStyle.amount(
                t,
                size: 26,
                color: totals.baseMilli < 0 ? t.danger : t.gold,
                weight: FontWeight.w700,
              ),
            ),
          ),
          if (totals.hasBusiness && totals.hasPersonal)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  '${l.ledgerPersonal} ${fmt.embed(fmt.amount(totals.kindMilli(WalletKind.personal), book.baseCode))}',
                  '${l.ledgerBusiness} ${fmt.embed(fmt.amount(totals.kindMilli(WalletKind.business), book.baseCode))}',
                ].join('   ·   '),
                style: text.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ),
          const SizedBox(height: Space.m),
          for (final w in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: WalletTileBody(wallet: w, book: book, index: book.wallets.indexOf(w), dense: true),
            ),
          if (more > 0)
            Text(
              MadarFormatter.of(context).localizeDigits(l.ledgerMoreWallets(more)),
              style: text.bodySmall?.copyWith(color: t.textTertiary),
            ),
        ],
      ),
    );
  }
}
