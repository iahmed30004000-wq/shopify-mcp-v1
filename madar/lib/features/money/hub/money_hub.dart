import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart' show BidiIsolate;
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/routing/money_route_pages.dart';
import '../../../core/sound/sound_api.dart';
import '../budget/budget.dart' show BudgetStatusCard, BudgetTab, budgetItemsProvider;
import '../goals/goals.dart' show GoalsIcons, GoalsTab, JarsCard, UpcomingDuesCard;
import '../ledger/ledger.dart'
    show LedgerActions, LedgerMoneyFormat, WalletsSummaryCard, ledgerBookProvider, ledgerFormatOf, showTransactionSheet;
import 'money_providers.dart';

/// The Money world's own page content – the hub of the user's money, in
/// four movements under the net worth:
///
/// * **net worth** – wallets + savings jars + what is owed to the user −
///   what the user owes, in the base currency, with its parts and a way to
///   the rates when a currency has none ([MoneyNetWorthCard]); below it one
///   tap adds an expense, income or a transfer ([MoneyQuickAddRow]);
/// * **your wallets** – the ledger's summary: net balance, personal /
///   business, the first wallets ([WalletsSummaryCard]); "Ledger" opens it;
/// * **this month's plan** – the budget's plan vs spent with its warnings
///   ([BudgetStatusCard]);
/// * **dues & savings** – the bills and debts due soon ([UpcomingDuesCard];
///   "Paid" from there advances a bill) and the savings jars' rings
///   ([JarsCard]);
/// * **tools** – ledger, entries, budget, jars, debts, bills ([MoneyTools]).
///
/// No tax, VAT, fee or zakat anywhere – only the user's own money. Every
/// part is a [StaggerItem] of the planet page's entrance, and every screen
/// opens as a route ([MoneyNav]).
class MoneyHub extends ConsumerWidget {
  const MoneyHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final noPlan = ref.watch(budgetItemsProvider).value?.isEmpty ?? true;

    var index = firstIndex;
    final children = <Widget>[];
    void card(Widget child, {Key? key}) {
      if (children.isNotEmpty && children.last is! _Header) children.add(const SizedBox(height: Space.m));
      children.add(
        StaggerItem(
          key: key,
          index: index++,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            child: child,
          ),
        ),
      );
    }

    void header(String title, {String? action, VoidCallback? onAction}) =>
        children.add(_Header(index: index, title: title, action: action, onAction: onAction));

    card(const MoneyNetWorthCard());
    card(const MoneyQuickAddRow());

    header(l.moneyHubWalletsTitle, action: l.moneyHubLedgerAction, onAction: () => MoneyNav.ledger(context));
    card(WalletsSummaryCard(onOpen: () => MoneyNav.ledger(context)));

    header(l.moneyHubPlanTitle, action: l.moneyHubBudgetAction, onAction: () => MoneyNav.budget(context));
    card(
      BudgetStatusCard(
        onTap: () {
          Fx.fire(Sfx.navigate);
          MoneyNav.budget(context, tab: noPlan ? BudgetTab.plan : BudgetTab.spending);
        },
      ),
    );

    header(l.moneyHubDuesTitle, action: l.moneyHubGoalsAction, onAction: () => MoneyNav.goals(context));
    card(UpcomingDuesCard(onSeeAll: () => MoneyNav.goals(context, tab: GoalsTab.obligations)));
    card(JarsCard(onSeeAll: () => MoneyNav.goals(context)));

    header(l.moneyHubToolsTitle);
    card(const MoneyTools());

    // The planet sheet has no Material above it: the cards the packages
    // bring would otherwise inherit the debug fallback text style.
    return Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A movement's title, rising with its first card.
class _Header extends StatelessWidget {
  const _Header({required this.index, required this.title, this.action, this.onAction});

  final int index;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StaggerItem(
    index: index,
    child: SectionHeader(
      title: title,
      actionLabel: action,
      onAction: onAction,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
    ),
  );
}

// ------------------------------------------------------------- net worth --

/// Net worth in the base currency: the total (gold, or danger when it is
/// below zero), a strip of what it is made of (wallets, jars, owed to the
/// user) and the four parts, "You owe" subtracted. A currency without a
/// rate is named, with "Set rates". "Currencies" opens the rates.
class MoneyNetWorthCard extends ConsumerWidget {
  const MoneyNetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final book = ref.watch(ledgerBookProvider).value;
    final worth = ref.watch(moneyNetWorthProvider);
    if (book == null || worth == null) {
      return const GlassCard(
        child: SizedBox(height: 132, child: Center(child: OrbitLoader(size: 30))),
      );
    }
    final fmt = ledgerFormatOf(context, book);
    String money(int milli) => fmt.amount(milli, worth.base);
    final total = worth.totalMilli;

    final title = Row(
      children: [
        _Medallion(icon: Icons.account_balance_rounded, color: t.gold),
        const SizedBox(width: Space.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(l.moneyHubNetWorthTitle, style: text.titleMedium)),
              Text(
                l.moneyHubNetWorthIn(BidiIsolate.isolate(fmt.symbolOf(worth.base))),
                style: text.bodySmall!.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
        MadarButton(
          label: l.moneyHubRatesAction,
          icon: Icons.currency_exchange_rounded,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.navigate,
          semanticLabel: l.ledgerCurrencies,
          onPressed: () => MoneyNav.currencies(context),
        ),
      ],
    );

    if (worth.isEmpty) {
      return GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.l),
        seed: 1.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: Space.m),
            Text(l.moneyHubNetWorthEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
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

    final shares = worth.shares;
    final parts = <_Part>[
      (l.moneyHubPartWallets, worth.walletsMilli, t.info, false),
      (l.moneyHubPartJars, worth.jarsMilli, t.gold, false),
      (l.moneyHubPartOwedToMe, worth.owedToMeMilli, t.success, false),
      (l.moneyHubPartIOwe, worth.iOweMilli, t.danger, true),
    ];
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.l),
      seed: 1.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: Space.s),
          Semantics(
            label: BidiIsolate.strip(
              l.moneyHubNetWorthSemantics(
                money(total),
                money(worth.walletsMilli),
                money(worth.jarsMilli),
                money(worth.owedToMeMilli),
                money(worth.iOweMilli),
              ),
            ),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                money(total),
                key: const ValueKey('money-net-worth'),
                style: MadarTypography.numerals(
                  t,
                  size: 30,
                  color: total < 0 ? t.danger : t.gold,
                ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          _ShareStrip(
            segments: [(shares.wallets, t.info), (shares.jars, t.gold), (shares.owed, t.success)],
          ),
          const SizedBox(height: Space.m),
          for (var i = 0; i < parts.length; i += 2) ...[
            if (i > 0) const SizedBox(height: Space.xs),
            Row(
              children: [
                Expanded(child: _PartCell(part: parts[i], fmt: fmt, base: worth.base)),
                const SizedBox(width: Space.m),
                Expanded(child: _PartCell(part: parts[i + 1], fmt: fmt, base: worth.base)),
              ],
            ),
          ],
          if (worth.missingRates.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            _MissingRates(codes: worth.missingRates.toList()..sort()),
          ],
        ],
      ),
    );
  }
}

/// Label, amount, colour and whether it is subtracted.
typedef _Part = (String, int, Color, bool);

class _PartCell extends StatelessWidget {
  const _PartCell({required this.part, required this.fmt, required this.base});

  final _Part part;
  final LedgerMoneyFormat fmt;
  final String base;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (label, milli, color, minus) = part;
    final amount = minus && milli > 0 ? fmt.amount(-milli, base) : fmt.amount(milli, base);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 5),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall!.copyWith(color: t.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  amount,
                  style: MadarTypography.numerals(
                    t,
                    size: 14,
                    color: minus && milli > 0 ? t.danger : t.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the net worth is made of, as one rounded strip (in the reading
/// direction; empty parts take no room).
class _ShareStrip extends StatelessWidget {
  const _ShareStrip({required this.segments});

  final List<(double, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = [
      for (final s in segments)
        if (s.$1 > 0) s,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: shown.isEmpty
            ? ColoredBox(color: t.glassBorder)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (share, color) in shown)
                    Expanded(
                      flex: (share * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: color.withValues(alpha: t.isDark ? 0.85 : 0.75)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MissingRates extends StatelessWidget {
  const _MissingRates({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: t.warning),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(
            l.ledgerMissingRate(BidiIsolate.isolate(codes.join(l.localeName == 'ar' ? '، ' : ', '))),
            style: text.bodySmall!.copyWith(color: t.textSecondary),
          ),
        ),
        MadarButton(
          label: l.ledgerFixRates,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.navigate,
          onPressed: () => MoneyNav.currencies(context),
        ),
      ],
    );
  }
}

/// A soft round seal behind a card's icon.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: t.isDark ? 0.30 : 0.18), color.withValues(alpha: t.isDark ? 0.08 : 0.05)],
        ),
        border: Border.all(color: color.withValues(alpha: t.isDark ? 0.55 : 0.45), width: 0.9),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

// ------------------------------------------------------------- quick add --

/// One tap to the keypad-first entry sheet: an expense, income or a
/// transfer (the sheet saves with undo, and the Money world pulses).
class MoneyQuickAddRow extends StatelessWidget {
  const MoneyQuickAddRow({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final kinds = <(TxKind, String, String, IconData, Color)>[
      (TxKind.expense, l.ledgerKindExpense, l.moneyHubAddExpenseHint, Icons.arrow_outward_rounded, t.accent),
      (TxKind.income, l.ledgerKindIncome, l.moneyHubAddIncomeHint, Icons.south_west_rounded, t.success),
      (TxKind.transfer, l.ledgerKindTransfer, l.moneyHubAddTransferHint, Icons.swap_horiz_rounded, t.info),
    ];
    return Semantics(
      container: true,
      label: l.moneyHubQuickTitle,
      child: Row(
        children: [
          for (var i = 0; i < kinds.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.s),
            Expanded(child: _QuickAddPill(kind: kinds[i])),
          ],
        ],
      ),
    );
  }
}

class _QuickAddPill extends StatelessWidget {
  const _QuickAddPill({required this.kind});

  final (TxKind, String, String, IconData, Color) kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (k, label, hint, icon, color) = kind;
    return MadarPressable(
      onTap: () => unawaited(showTransactionSheet(context, kind: k)),
      sfx: Sfx.sheetOpen,
      semanticLabel: hint,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.m),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall!.copyWith(color: t.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- tools --

/// The money tools: a grid of three by two glass tiles, each a brass seal
/// around its icon over its name – ledger, entries and budget, then savings
/// jars, debts and bills.
class MoneyTools extends StatelessWidget {
  const MoneyTools({super.key});

  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tools = <_Tool>[
      (
        Icons.account_balance_wallet_rounded,
        l.moneyHubToolLedger,
        l.moneyHubToolLedgerHint,
        () => MoneyNav.ledger(context),
      ),
      (
        Icons.receipt_long_rounded,
        l.moneyHubToolTransactions,
        l.moneyHubToolTransactionsHint,
        () => MoneyNav.transactions(context),
      ),
      (Icons.account_tree_rounded, l.moneyHubToolBudget, l.moneyHubToolBudgetHint, () => MoneyNav.budget(context)),
      (GoalsIcons.jars, l.moneyHubToolJars, l.moneyHubToolJarsHint, () => MoneyNav.goals(context)),
      (
        GoalsIcons.debts,
        l.moneyHubToolDebts,
        l.moneyHubToolDebtsHint,
        () => MoneyNav.goals(context, tab: GoalsTab.debts),
      ),
      (
        GoalsIcons.obligations,
        l.moneyHubToolBills,
        l.moneyHubToolBillsHint,
        () => MoneyNav.goals(context, tab: GoalsTab.obligations),
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tools.length; i += columns) {
      if (i > 0) rows.add(const SizedBox(height: Space.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) const SizedBox(width: Space.s),
                Expanded(child: j < tools.length ? _ToolTile(tool: tools[j]) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Icon, name, hint (for screen readers) and where it leads.
typedef _Tool = (IconData, String, String, VoidCallback);

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (icon, title, hint, onTap) = tool;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.navigate,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Seal(icon: icon),
            const SizedBox(height: Space.s),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brass eight-point seal holding a tool's icon (the Faith and Health
/// tools' seal).
class _Seal extends StatelessWidget {
  const _Seal({required this.icon});

  final IconData icon;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass.withValues(alpha: 0.8), strokeWidth: 1.2),
          Icon(icon, size: 20, color: t.accent),
        ],
      ),
    );
  }
}
