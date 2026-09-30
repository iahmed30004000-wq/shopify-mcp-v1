import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/ledger_providers.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_models.dart';
import '../domain/tx_filter.dart';
import 'charts/ledger_chart_cards.dart';
import 'ledger_actions.dart';
import 'ledger_ui.dart';
import 'money_ledger_screen.dart' show showLedgerUndo;
import 'sheets/transaction_sheet.dart';
import 'widgets/tx_tile.dart';

/// One wallet: its balance (and value in the base currency), quick actions
/// (expense, income, transfer, adjust), the balance-over-time chart and its
/// transactions with the running balance after each.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key, required this.walletId, this.animateBackdrop = true});

  final String walletId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final bookAsync = ref.watch(ledgerBookProvider);
    final now = ref.watch(ledgerClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final book = bookAsync.value;
    final wallet = book?.wallet(walletId);
    return MadarScaffold(
      title: wallet?.name ?? l.ledgerWallet,
      backdropSeed: 5.1,
      animateBackdrop: animateBackdrop,
      actions: [
        if (wallet != null) ...[
          MadarButton.icon(
            icon: wallet.archived ? Icons.unarchive_rounded : Icons.archive_outlined,
            semanticLabel: wallet.archived ? l.ledgerUnarchive : l.ledgerArchive,
            variant: MadarButtonVariant.ghost,
            sfx: wallet.archived ? Sfx.toggleOn : Sfx.toggleOff,
            onPressed: () =>
                showLedgerUndo(context, LedgerActions.toggleArchive(context, ref, wallet, feedback: false)),
          ),
          MadarButton.icon(
            icon: Icons.edit_rounded,
            semanticLabel: l.ledgerWalletEdit,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.sheetOpen,
            onPressed: () => LedgerActions.editWallet(context, ref, wallet: wallet),
          ),
        ],
      ],
      body: switch (bookAsync) {
        AsyncData() when wallet == null => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.ledgerWalletMissing, body: ''),
        ),
        AsyncData(:final value) => _WalletBody(book: value, wallet: wallet!, today: today),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.ledgerWalletMissing, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({required this.book, required this.wallet, required this.today});

  final LedgerBook book;
  final LedgerWallet wallet;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    final index = book.wallets.indexOf(wallet);
    final color = LedgerStyle.wallet(t, wallet, index);
    final txs = book.transactionsOf(wallet.id);
    final rows = TxListRows.of(txs);
    final builder = TxRowBuilder(
      context: context,
      book: book,
      today: today,
      perspectiveWalletId: wallet.id,
      showWallet: false,
      actions: LedgerActions.txActions(context, ref),
    );
    const head = 4;
    return EntranceChoreo(
      id: 'wallet-${wallet.id}',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 0),
            sliver: SliverList.list(
              children: [
                StaggerItem(
                  index: 0,
                  child: _Hero(book: book, wallet: wallet, color: color),
                ),
                const SizedBox(height: Space.m),
                StaggerItem(
                  index: 1,
                  child: _QuickActions(wallet: wallet, hasOthers: book.activeWallets.length > 1),
                ),
                const SizedBox(height: Space.l),
                StaggerItem(
                  index: 2,
                  child: BalanceCard(book: book, walletId: wallet.id, today: today, color: color),
                ),
                StaggerItem(
                  index: 3,
                  child: SectionHeader(
                    title: l.ledgerTransactions,
                    subtitle: MadarFormatter.of(context).localizeDigits(l.ledgerTxCount(txs.length)),
                    actionLabel: txs.isEmpty ? null : l.ledgerSearch,
                    onAction: txs.isEmpty
                        ? null
                        : () => LedgerActions.openTransactions(context, ref, filter: TxFilter(walletIds: {wallet.id})),
                    padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, 0),
                  ),
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xl),
                    child: Text(
                      l.ledgerNoTxBody,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: t.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) =>
                  i < 12 ? StaggerItem(index: head + i, child: builder.build(rows[i])) : builder.build(rows[i]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, Space.xxxl + Space.xl),
            sliver: SliverToBoxAdapter(
              child: Text(
                l.ledgerOpeningLine(fmt.embed(fmt.amount(wallet.openingMilli, wallet.currency))),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.book, required this.wallet, required this.color});

  final LedgerBook book;
  final LedgerWallet wallet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    final balance = book.balanceOf(wallet.id);
    final foreign = wallet.currency != book.baseCode;
    final base = foreign ? book.rates.toBase(balance, wallet.currency) : null;
    final currency = book.currency(wallet.currency);
    return GlassPanel(
      glowColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              LedgerMedallion(icon: LedgerStyle.walletIcon(wallet), color: color, size: 46),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ledgerBalance, style: text.labelLarge?.copyWith(color: t.textSecondary)),
                    Text(
                      [
                        l.walletKind(wallet.kind),
                        LedgerMoneyFormat.isolate(currency?.name(arabic: fmt.arabic) ?? wallet.currency),
                        if (wallet.archived) l.ledgerArchivedBadge,
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: Text(
                fmt.amount(balance, wallet.currency),
                key: ValueKey(balance),
                style: LedgerStyle.amount(
                  t,
                  size: 36,
                  color: balance < 0 ? t.danger : t.textPrimary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (base != null)
            Text(
              l.ledgerApprox(fmt.embed(fmt.amount(base, book.baseCode))),
              style: LedgerStyle.amount(t, size: 13, color: t.textTertiary, weight: FontWeight.w500),
            )
          else if (foreign)
            Text(l.ledgerNoRate, style: text.bodySmall?.copyWith(color: t.warning)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.wallet, required this.hasOthers});

  final LedgerWallet wallet;
  final bool hasOthers;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    Widget action(TxKind kind, IconData icon, String label, Color color, {bool enabled = true}) => Expanded(
      child: _ActionButton(
        icon: icon,
        label: label,
        color: color,
        onTap: enabled ? () => showTransactionSheet(context, kind: kind, walletId: wallet.id) : null,
      ),
    );
    return Row(
      children: [
        action(TxKind.expense, Icons.arrow_outward_rounded, l.ledgerKindExpense, t.accent),
        const SizedBox(width: Space.s),
        action(TxKind.income, Icons.south_west_rounded, l.ledgerKindIncome, t.success),
        const SizedBox(width: Space.s),
        action(TxKind.transfer, Icons.swap_horiz_rounded, l.ledgerKindTransfer, t.info, enabled: hasOthers),
        const SizedBox(width: Space.s),
        action(TxKind.adjustment, Icons.tune_rounded, l.ledgerKindAdjustment, t.warning),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: SpringPress(
        onTap: onTap,
        enabled: onTap != null,
        sfx: Sfx.sheetOpen,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Space.m),
          decoration: BoxDecoration(
            color: t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 0.9),
          ),
          child: Column(
            children: [
              LedgerMedallion(icon: icon, color: color, size: 36),
              const SizedBox(height: Space.xs + 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
