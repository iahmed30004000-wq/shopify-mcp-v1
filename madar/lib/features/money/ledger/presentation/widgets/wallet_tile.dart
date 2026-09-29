import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../data/ledger_providers.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_models.dart';
import '../ledger_ui.dart';

/// The visual of a wallet row: medallion in the wallet's colour, name,
/// type · currency, the balance and – for foreign currencies – its value in
/// the base currency.
class WalletTileBody extends StatelessWidget {
  const WalletTileBody({
    super.key,
    required this.wallet,
    required this.book,
    required this.index,
    this.trailing,
    this.dense = false,
  });

  final LedgerWallet wallet;
  final LedgerBook book;
  final int index;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    final color = LedgerStyle.wallet(t, wallet, index);
    final balance = book.balanceOf(wallet.id);
    final foreign = wallet.currency != book.baseCode;
    final base = foreign ? book.rates.toBase(balance, wallet.currency) : null;
    final currencyName = book.currency(wallet.currency)?.name(arabic: fmt.arabic) ?? wallet.currency;
    final caption = [l.walletKind(wallet.kind), LedgerMoneyFormat.isolate(currencyName)].join(' · ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAmountWidth = constraints.maxWidth.isFinite ? constraints.maxWidth * 0.46 : 200.0;
        return Row(
          children: [
            LedgerMedallion(icon: LedgerStyle.walletIcon(wallet), color: color, size: dense ? 36 : 44),
            SizedBox(width: dense ? Space.s + 2 : Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: BidiIsolate.directionOf(wallet.name),
                    textAlign: TextAlign.start,
                    style: (dense ? text.bodyMedium : text.titleMedium)?.copyWith(
                      color: wallet.archived ? t.textSecondary : t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!dense)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: t.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxAmountWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyLabel(
                      milli: balance,
                      currency: wallet.currency,
                      book: book,
                      size: dense ? 14 : 16,
                      color: balance < 0 ? t.danger : t.textPrimary,
                    ),
                    if (base != null && !dense)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Text(
                          l.ledgerApprox(fmt.embed(fmt.amount(base, book.baseCode))),
                          maxLines: 1,
                          style: LedgerStyle.amount(t, size: 11.5, color: t.textTertiary, weight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        );
      },
    );
  }
}

/// A wallet as a glass card (used in lists).
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.wallet, required this.book, required this.index, this.trailing});

  final LedgerWallet wallet;
  final LedgerBook book;
  final int index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = LedgerStyle.wallet(t, wallet, index);
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
      borderColor: color.withValues(alpha: t.isDark ? 0.28 : 0.35),
      child: WalletTileBody(wallet: wallet, book: book, index: index, trailing: trailing),
    );
  }
}
