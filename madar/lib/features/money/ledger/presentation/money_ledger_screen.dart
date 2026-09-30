import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
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
import 'sheets/transaction_sheet.dart';
import 'widgets/ledger_segmented.dart';
import 'widgets/tx_tile.dart';
import 'widgets/wallet_tile.dart';

/// The ledger hub: net balance (personal / business, per currency), the
/// wallets (drag to reorder, long-press / swipe for actions), spending and
/// income-vs-spending charts, and the latest transactions. The "+" button
/// opens the keypad sheet.
class MoneyLedgerScreen extends ConsumerStatefulWidget {
  const MoneyLedgerScreen({super.key, this.animateBackdrop = true, this.recentCount = 8});

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  /// How many recent transactions are listed.
  final int recentCount;

  @override
  ConsumerState<MoneyLedgerScreen> createState() => _MoneyLedgerScreenState();
}

class _MoneyLedgerScreenState extends ConsumerState<MoneyLedgerScreen> {
  bool _showArchived = false;
  WalletKind? _scope;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final bookAsync = ref.watch(ledgerBookProvider);
    final now = ref.watch(ledgerClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final book = bookAsync.value;
    return MadarScaffold(
      title: l.ledgerTitle,
      backdropSeed: 4.2,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.search_rounded,
          semanticLabel: l.ledgerSearch,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: book == null ? null : () => LedgerActions.openTransactions(context, ref),
        ),
        MadarButton.icon(
          icon: Icons.currency_exchange_rounded,
          semanticLabel: l.ledgerCurrencies,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: book == null ? null : () => LedgerActions.openCurrencies(context, ref),
        ),
      ],
      floatingAction: book == null || book.activeWallets.isEmpty
          ? null
          : MadarButton.icon(
              icon: Icons.add_rounded,
              semanticLabel: l.ledgerAddTx,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: () => showTransactionSheet(context),
            ),
      body: switch (bookAsync) {
        AsyncData(:final value) => value.wallets.isEmpty ? _empty(context) : _content(context, value, today),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.ledgerTitle, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _empty(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      child: AnimatedEmptyState(
        kind: EmptyStateKind.emptyList,
        title: l.ledgerEmptyTitle,
        body: l.ledgerEmptyBody,
        actionLabel: l.ledgerAddWallet,
        actionIcon: Icons.account_balance_wallet_rounded,
        onAction: () => LedgerActions.editWallet(context, ref),
      ),
    );
  }

  bool Function(String)? get _scopePredicate {
    final scope = _scope;
    final book = ref.read(ledgerBookProvider).value;
    if (scope == null || book == null) return null;
    return (id) => book.walletKindOf(id) == scope;
  }

  Widget _content(BuildContext context, LedgerBook book, DateTime today) {
    final l = L10n.of(context);
    final t = context.tokens;
    final active = book.activeWallets;
    final archived = book.archivedWallets;
    final recent = book.transactions.take(widget.recentCount).toList();
    final rows = TxListRows.of(recent);
    final builder = TxRowBuilder(
      context: context,
      book: book,
      today: today,
      actions: LedgerActions.txActions(context, ref),
    );
    var i = 0;
    return EntranceChoreo(
      id: 'ledger',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
        children: [
          StaggerItem(
            index: i++,
            child: NetBalancePanel(book: book, onFixRates: () => LedgerActions.openCurrencies(context, ref)),
          ),
          if (book.ratesAreDefaults)
            StaggerItem(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: RatesNotice(onReview: () => LedgerActions.openCurrencies(context, ref)),
              ),
            ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.ledgerWallets,
              actionLabel: l.ledgerAddWallet,
              onAction: () => LedgerActions.editWallet(context, ref),
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          StaggerItem(
            index: i++,
            child: ReorderableGlassList<LedgerWallet>(
              items: active,
              itemKey: (w) => w.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              animateEntrance: false,
              onReorder: (order) => ref.read(ledgerServiceProvider).reorderWallets([for (final w in order) w.id]),
              itemBuilder: (context, w, index, handle) => _walletRow(context, book, w, handle),
            ),
          ),
          if (archived.isNotEmpty)
            StaggerItem(
              index: i++,
              child: _ArchivedToggle(
                label: l.ledgerArchivedCount(MadarFormatter.of(context).formatInt(archived.length)),
                open: _showArchived,
                onTap: () => setState(() => _showArchived = !_showArchived),
              ),
            ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.emphasized,
            alignment: AlignmentDirectional.topStart,
            child: !_showArchived
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      for (final w in archived)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: Opacity(opacity: 0.72, child: _walletRow(context, book, w, null)),
                        ),
                    ],
                  ),
          ),
          if (book.totals.hasBusiness && book.totals.hasPersonal)
            StaggerItem(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.xl),
                child: LedgerSegmented3(value: _scope, onChanged: (s) => setState(() => _scope = s)),
              ),
            ),
          StaggerItem(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: SpendingCard(
                key: ValueKey('spend-$_scope'),
                book: book,
                today: today,
                wallets: _scopePredicate,
                onItemTap: (id) => LedgerActions.openTransactions(
                  context,
                  ref,
                  filter: id == null
                      ? TxFilter(unassignedOnly: true, kinds: const {TxKind.expense}, walletKind: _scope)
                      : TxFilter(budgetItemIds: {id}, walletKind: _scope),
                ),
                onWalletTap: (id) => LedgerActions.openWallet(context, ref, id),
              ),
            ),
          ),
          StaggerItem(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: TrendCard(key: ValueKey('trend-$_scope'), book: book, today: today, wallets: _scopePredicate),
            ),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.ledgerRecent,
              actionLabel: book.transactions.isEmpty ? null : l.ledgerSeeAll,
              onAction: book.transactions.isEmpty ? null : () => LedgerActions.openTransactions(context, ref),
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, 0),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                l.ledgerNoTxBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textTertiary),
              ),
            )
          else
            for (final row in rows) builder.build(row),
        ],
      ),
    );
  }

  Widget _walletRow(BuildContext context, LedgerBook book, LedgerWallet w, Widget? handle) {
    final l = L10n.of(context);
    final fmt = ledgerFormatOf(context, book);
    final index = book.wallets.indexOf(w);
    return ActionableItem(
      key: ValueKey('wallet-${w.id}'),
      onTap: () => LedgerActions.openWallet(context, ref, w.id),
      semanticLabel: BidiIsolate.strip(l.ledgerWalletSemantics(w.name, fmt.amount(book.balanceOf(w.id), w.currency))),
      actions: LedgerActions.walletItemActions(context, ref, w),
      quickActions: [
        QuickAction(
          icon: Icons.add_card_rounded,
          label: l.ledgerAddTx,
          tone: ActionTone.accent,
          onPressed: () async {
            await showTransactionSheet(context, walletId: w.id);
            return null;
          },
        ),
        QuickAction(
          icon: w.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
          label: w.archived ? l.ledgerUnarchive : l.ledgerArchive,
          tone: ActionTone.warning,
          onPressed: () => LedgerActions.toggleArchive(context, ref, w),
        ),
      ],
      child: WalletCard(wallet: w, book: book, index: index, trailing: handle),
    );
  }
}

/// All / personal / business scope for the charts.
class LedgerSegmented3 extends StatelessWidget {
  const LedgerSegmented3({super.key, required this.value, required this.onChanged});

  final WalletKind? value;
  final ValueChanged<WalletKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    const all = 'all';
    final values = [all, WalletKind.personal.name, WalletKind.business.name];
    return LedgerSegmented<String>(
      values: values,
      height: 38,
      value: value?.name ?? all,
      labels: {
        all: l.ledgerAllWallets,
        WalletKind.personal.name: l.ledgerPersonal,
        WalletKind.business.name: l.ledgerBusiness,
      },
      onChanged: (v) => onChanged(v == all ? null : WalletKind.values.byName(v)),
    );
  }
}

/// The net balance of every active wallet in the base currency, the
/// personal / business split and the native total of each currency.
class NetBalancePanel extends StatelessWidget {
  const NetBalancePanel({super.key, required this.book, this.onFixRates});

  final LedgerBook book;

  /// Where "Set rates" leads when some currencies have no rate (hidden
  /// when null).
  final VoidCallback? onFixRates;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    final totals = book.totals;
    final split = totals.hasBusiness && totals.hasPersonal;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.ledgerNetBalance, style: text.labelLarge?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: Text(
                fmt.amount(totals.baseMilli, book.baseCode),
                key: ValueKey(totals.baseMilli),
                style: LedgerStyle.amount(
                  t,
                  size: 34,
                  color: totals.baseMilli < 0 ? t.danger : t.gold,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (split) ...[
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(
                  child: _SplitTile(
                    icon: Icons.person_rounded,
                    label: l.ledgerPersonal,
                    value: fmt.amount(totals.kindMilli(WalletKind.personal), book.baseCode),
                    color: t.highlight,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: _SplitTile(
                    icon: Icons.storefront_rounded,
                    label: l.ledgerBusiness,
                    value: fmt.amount(totals.kindMilli(WalletKind.business), book.baseCode),
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ],
          if (totals.byCurrency.length > 1 ||
              (totals.byCurrency.length == 1 && totals.byCurrency.keys.first != book.baseCode)) ...[
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final e in totals.byCurrency.entries)
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.xs),
                    decoration: BoxDecoration(
                      color: t.glassFill,
                      borderRadius: BorderRadius.circular(t.radiusXL),
                      border: Border.all(color: t.glassBorder, width: 0.8),
                    ),
                    child: Text(
                      fmt.amount(e.value, e.key),
                      style: LedgerStyle.amount(t, size: 12.5, color: t.textSecondary, weight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
          if (totals.missingRates.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: t.warning),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l.ledgerMissingRate(totals.missingRates.map(LedgerMoneyFormat.isolate).join('، ')),
                    style: text.bodySmall?.copyWith(color: t.warning),
                  ),
                ),
                if (onFixRates != null)
                  MadarButton(
                    label: l.ledgerFixRates,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    sfx: Sfx.navigate,
                    onPressed: onFixRates,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: Space.xs),
              Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: LedgerStyle.amount(t, size: 15, color: t.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// "Rates are still defaults" notice with a review action.
class RatesNotice extends StatelessWidget {
  const RatesNotice({super.key, required this.onReview});

  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      borderColor: t.warning.withValues(alpha: 0.45),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.s),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: t.warning),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(l.ledgerRatesDefaults, style: text.bodySmall?.copyWith(color: t.textSecondary)),
          ),
          MadarButton(
            label: l.ledgerReview,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.navigate,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

class _ArchivedToggle extends StatelessWidget {
  const _ArchivedToggle({required this.label, required this.open, required this.onTap});

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SpringPress(
      onTap: onTap,
      sfx: open ? Sfx.toggleOff : Sfx.toggleOn,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 17, color: t.textTertiary),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(label, style: text.labelLarge?.copyWith(color: t.textTertiary)),
            ),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: context.motion(MadarMotion.short),
              child: Icon(Icons.expand_more_rounded, color: t.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows an undo toast for an action result (helper for callers outside an
/// [ActionableItem]).
Future<void> showLedgerUndo(BuildContext context, Future<UndoableAction?> action) async {
  final undo = await action;
  if (undo != null && context.mounted) unawaited(showUndoToast(context, undo));
}
