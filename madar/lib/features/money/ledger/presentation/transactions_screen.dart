import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show KitChip, kitInputDecoration;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/ledger_providers.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_reports.dart';
import '../domain/tx_filter.dart';
import 'ledger_actions.dart';
import 'ledger_ui.dart';
import 'sheets/budget_item_picker.dart';
import 'sheets/choice_sheet.dart';
import 'sheets/transaction_sheet.dart';
import 'widgets/tx_tile.dart';

/// Every transaction, grouped by day, with search, filters (wallet, type,
/// budget item, tag, dates, personal / business) and the running totals of
/// what is shown. Rows swipe (duplicate, delete with undo) and long-press
/// (edit, duplicate, move to another wallet, delete).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.filter = TxFilter.none, this.animateBackdrop = true});

  /// The filters to start with.
  final TxFilter filter;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TxFilter _filter = widget.filter;
  late final _search = TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(TxFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final bookAsync = ref.watch(ledgerBookProvider);
    final now = ref.watch(ledgerClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final book = bookAsync.value;
    final singleWallet = _filter.walletIds.length == 1 ? _filter.walletIds.single : null;
    return MadarScaffold(
      title: l.ledgerTransactions,
      backdropSeed: 6.3,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: book == null || book.activeWallets.isEmpty
          ? null
          : MadarButton.icon(
              icon: Icons.add_rounded,
              semanticLabel: l.ledgerAddTx,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: () => showTransactionSheet(
                context,
                walletId: singleWallet,
                budgetItemId: _filter.budgetItemIds.length == 1 ? _filter.budgetItemIds.single : null,
              ),
            ),
      body: switch (bookAsync) {
        AsyncData(:final value) => _content(context, value, today),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.ledgerTransactions, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _content(BuildContext context, LedgerBook book, DateTime today) {
    final l = L10n.of(context);
    final shown = _filter.apply(book.transactions, book);
    final rows = TxListRows.of(shown);
    final perspective = _filter.walletIds.length == 1 ? _filter.walletIds.single : null;
    final builder = TxRowBuilder(
      context: context,
      book: book,
      today: today,
      perspectiveWalletId: perspective,
      showWallet: perspective == null,
      actions: LedgerActions.txActions(context, ref),
    );
    final flow = LedgerReports.flow(shown, walletCurrency: book.walletCurrency, rates: book.rates);
    return EntranceChoreo(
      id: 'transactions',
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 0),
            sliver: SliverList.list(
              children: [
                StaggerItem(index: 0, child: _searchField(context)),
                const SizedBox(height: Space.m),
                StaggerItem(index: 1, child: _filterChips(context, book, today)),
                const SizedBox(height: Space.m),
                StaggerItem(
                  index: 2,
                  child: _TotalsStrip(book: book, flow: flow),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: AnimatedEmptyState(
                  kind: _filter.isEmpty ? EmptyStateKind.emptyList : EmptyStateKind.noResults,
                  title: _filter.isEmpty ? l.ledgerNoTxTitle : l.ledgerNoResults,
                  body: _filter.isEmpty ? l.ledgerNoTxBody : l.ledgerNoResultsBody,
                  actionLabel: _filter.isEmpty ? null : l.ledgerFilterClear,
                  actionIcon: Icons.filter_alt_off_rounded,
                  onAction: _filter.isEmpty
                      ? null
                      : () {
                          _search.clear();
                          _setFilter(TxFilter.none);
                        },
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, 120),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) =>
                    i < 10 ? StaggerItem(index: 3 + i, child: builder.build(rows[i])) : builder.build(rows[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (v) => _setFilter(_filter.copyWith(query: v)),
      decoration: kitInputDecoration(
        context,
        hint: l.ledgerSearch,
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: l.actionClose,
                icon: Icon(Icons.close_rounded, color: t.textTertiary),
                onPressed: () {
                  Fx.fire(Sfx.toggleOff);
                  _search.clear();
                  _setFilter(_filter.copyWith(query: ''));
                },
              ),
      ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textTertiary)),
    );
  }

  Widget _filterChips(BuildContext context, LedgerBook book, DateTime today) {
    final l = L10n.of(context);
    final f = MadarFormatter.of(context);
    final t = context.tokens;
    final fl = _filter;
    final walletNames = [for (final id in fl.walletIds) book.walletNameOf(id) ?? '—'];
    final itemNames = fl.unassignedOnly
        ? [l.ledgerUnassigned]
        : [for (final id in fl.budgetItemIds) book.budgetNameOf(id) ?? '—'];
    String dateLabel() {
      if (!fl.hasDateRange) return l.ledgerFilterDate;
      final from = fl.from == null ? '…' : f.formatDate(fl.from!, style: MadarDateStyle.dayMonth);
      final to = fl.to == null ? '…' : f.formatDate(fl.to!, style: MadarDateStyle.dayMonth);
      return l.ledgerRangeLabel(from, to);
    }

    _FilterChipEntry chip({
      required String label,
      required bool active,
      required IconData icon,
      required VoidCallback onTap,
    }) => _FilterChipEntry(
      active,
      Padding(
        key: ValueKey(icon),
        padding: const EdgeInsetsDirectional.only(end: Space.s),
        child: KitChip(dense: true, label: label, icon: icon, selected: active, sfx: Sfx.sheetOpen, onTap: onTap),
      ),
    );

    final chips = <_FilterChipEntry>[
      chip(
        label: fl.walletIds.isEmpty ? l.ledgerFilterWallet : choiceSummary(l, f, walletNames),
        active: fl.walletIds.isNotEmpty,
        icon: Icons.account_balance_wallet_outlined,
        onTap: () async {
          final picked = await showChoiceSheet<String>(
            context,
            title: l.ledgerFilterWallet,
            icon: Icons.account_balance_wallet_rounded,
            selected: fl.walletIds,
            items: [
              for (final (i, w) in book.wallets.indexed)
                ChoiceItem(
                  value: w.id,
                  label: w.name,
                  icon: LedgerStyle.walletIcon(w),
                  color: LedgerStyle.wallet(t, w, i),
                ),
            ],
          );
          if (picked != null) _setFilter(_filter.copyWith(walletIds: picked));
        },
      ),
      chip(
        label: fl.kinds.isEmpty ? l.ledgerFilterKind : choiceSummary(l, f, [for (final k in fl.kinds) l.kind(k)]),
        active: fl.kinds.isNotEmpty,
        icon: Icons.swap_vert_rounded,
        onTap: () async {
          final picked = await showChoiceSheet<TxKind>(
            context,
            title: l.ledgerFilterKind,
            icon: Icons.swap_vert_rounded,
            selected: fl.kinds,
            items: [
              for (final k in TxKind.values)
                ChoiceItem(value: k, label: l.kind(k), icon: LedgerStyle.kindIcon(k), color: LedgerStyle.kind(t, k)),
            ],
          );
          if (picked != null) _setFilter(_filter.copyWith(kinds: picked));
        },
      ),
      if (book.budget != null)
        chip(
          label: itemNames.isEmpty ? l.ledgerFilterItem : choiceSummary(l, f, itemNames),
          active: itemNames.isNotEmpty,
          icon: Icons.account_tree_outlined,
          onTap: () async {
            final picked = await showBudgetItemPicker(
              context,
              book: book,
              selected: fl.budgetItemIds.length == 1 ? fl.budgetItemIds.single : null,
              today: today,
              title: l.ledgerFilterItem,
            );
            if (picked == null) return;
            _setFilter(
              picked == BudgetPick.none
                  ? _filter.copyWith(budgetItemIds: const {}, unassignedOnly: true)
                  : _filter.copyWith(budgetItemIds: {picked}, unassignedOnly: false),
            );
          },
        ),
      chip(
        label: fl.tags.isEmpty ? l.ledgerFilterTag : choiceSummary(l, f, [for (final tag in fl.tags) '#$tag']),
        active: fl.tags.isNotEmpty,
        icon: Icons.sell_outlined,
        onTap: () async {
          final picked = await showChoiceSheet<String>(
            context,
            title: l.ledgerTags,
            icon: Icons.sell_rounded,
            selected: fl.tags,
            emptyText: l.ledgerNoTags,
            items: [for (final tag in book.tags) ChoiceItem(value: tag, label: '#$tag')],
          );
          if (picked != null) _setFilter(_filter.copyWith(tags: picked));
        },
      ),
      chip(
        label: dateLabel(),
        active: fl.hasDateRange,
        icon: Icons.date_range_rounded,
        onTap: () => _pickDates(context, today),
      ),
      if (book.totals.hasBusiness)
        chip(
          label: fl.walletKind == null ? l.ledgerFilterScope : l.walletKind(fl.walletKind!),
          active: fl.walletKind != null,
          icon: Icons.storefront_outlined,
          onTap: () async {
            final picked = await showChoiceSheet<WalletKind>(
              context,
              title: l.ledgerFilterScope,
              icon: Icons.storefront_rounded,
              multi: false,
              selected: {?fl.walletKind},
              items: [
                ChoiceItem(value: WalletKind.personal, label: l.ledgerPersonal, icon: Icons.person_rounded),
                ChoiceItem(value: WalletKind.business, label: l.ledgerBusiness, icon: Icons.storefront_rounded),
              ],
            );
            if (picked == null) return;
            _setFilter(
              picked.isEmpty ? _filter.copyWith(clearWalletKind: true) : _filter.copyWith(walletKind: picked.single),
            );
          },
        ),
    ];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // The selected chips' glow reaches past the row.
        clipBehavior: Clip.none,
        children: [
          if (fl.activeCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.s),
              child: KitChip(
                dense: true,
                label: l.ledgerFilterClear,
                icon: Icons.filter_alt_off_rounded,
                selected: false,
                sfx: Sfx.toggleOff,
                onTap: () => _setFilter(TxFilter(query: fl.query)),
              ),
            ),
          // Active filters first, so they show without scrolling.
          for (final c in chips)
            if (c.active) c.chip,
          for (final c in chips)
            if (!c.active) c.chip,
        ],
      ),
    );
  }

  Future<void> _pickDates(BuildContext context, DateTime today) async {
    final l = L10n.of(context);
    const presets = ['week', 'month', 'lastMonth', 'days30', 'custom'];
    final week = LedgerReports.windowOf(today, BudgetPeriod.weekly);
    final month = LedgerReports.windowOf(today, BudgetPeriod.monthly);
    final lastMonth = LedgerReports.shift(month, -1);
    final picked = await showChoiceSheet<String>(
      context,
      title: l.ledgerFilterDate,
      icon: Icons.date_range_rounded,
      multi: false,
      selected: const {},
      items: [
        ChoiceItem(value: presets[0], label: l.ledgerThisWeek),
        ChoiceItem(value: presets[1], label: l.ledgerThisMonth),
        ChoiceItem(value: presets[2], label: l.ledgerLastMonth),
        ChoiceItem(value: presets[3], label: MadarFormatter.of(context).localizeDigits(l.ledgerLastDays(30))),
        ChoiceItem(value: presets[4], label: l.ledgerCustomRange, icon: Icons.edit_calendar_rounded),
      ],
    );
    if (picked == null || !context.mounted) return;
    DateTime last(DateTime end) => DateTime(end.year, end.month, end.day - 1);
    switch (picked.firstOrNull) {
      case null:
        _setFilter(_filter.copyWith(clearDates: true));
      case 'week':
        _setFilter(_filter.copyWith(from: week.start, to: last(week.end)));
      case 'month':
        _setFilter(_filter.copyWith(from: month.start, to: last(month.end)));
      case 'lastMonth':
        _setFilter(_filter.copyWith(from: lastMonth.start, to: last(lastMonth.end)));
      case 'days30':
        _setFilter(_filter.copyWith(from: DateTime(today.year, today.month, today.day - 29), to: today));
      case 'custom':
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(today.year - 20),
          lastDate: DateTime(today.year + 5, 12, 31),
          currentDate: today,
          initialDateRange: _filter.from != null && _filter.to != null
              ? DateTimeRange(start: _filter.from!, end: _filter.to!)
              : DateTimeRange(start: month.start, end: today),
        );
        if (range != null) _setFilter(_filter.copyWith(from: range.start, to: range.end));
    }
  }
}

/// A filter chip and whether its filter is on.
class _FilterChipEntry {
  const _FilterChipEntry(this.active, this.chip);

  final bool active;
  final Widget chip;
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.book, required this.flow});

  final LedgerBook book;
  final LedgerFlow flow;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    Widget cell(String label, int milli, Color color, {SignDisplay sign = SignDisplay.auto}) => Expanded(
      child: Column(
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: t.textTertiary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              fmt.amount(milli, book.baseCode, sign: sign),
              style: LedgerStyle.amount(t, size: 14, color: color),
            ),
          ),
        ],
      ),
    );
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              cell(l.ledgerIncomeTotal, flow.incomeMilli, flow.incomeMilli > 0 ? t.success : t.textSecondary),
              Container(width: 0.8, height: 30, color: t.glassBorder),
              cell(l.ledgerExpenseTotal, flow.expenseMilli, t.textPrimary),
              Container(width: 0.8, height: 30, color: t.glassBorder),
              cell(l.ledgerNet, flow.netMilli, signedColor(t, flow.netMilli), sign: SignDisplay.always),
            ],
          ),
          const SizedBox(height: Space.xs),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: Text(
              [
                MadarFormatter.of(context).localizeDigits(l.ledgerTxCount(flow.count)),
                l.ledgerInBase(LedgerMoneyFormat.isolate(book.baseCode)),
              ].join(' · '),
              key: ValueKey(flow.count),
              style: text.bodySmall?.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
