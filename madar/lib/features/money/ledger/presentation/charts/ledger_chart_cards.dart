import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_math.dart';
import '../../domain/ledger_reports.dart';
import '../ledger_ui.dart';
import '../widgets/ledger_segmented.dart';
import 'ledger_charts.dart';

/// Which spending breakdown is shown.
enum SpendingView { byItem, byWallet }

/// Axis suffixes for compact amounts.
({String thousand, String million}) compactSuffixes(BuildContext context) {
  final l = L10n.of(context);
  final gap = MadarFormatter.of(context).isArabic ? ' ' : '';
  return (thousand: '$gap${l.ledgerCompactThousand}', million: '$gap${l.ledgerCompactMillion}');
}

/// Spending of a month or week by budget item or by wallet, in the base
/// currency, with period navigation.
class SpendingCard extends StatefulWidget {
  const SpendingCard({
    super.key,
    required this.book,
    required this.today,
    this.wallets,
    this.initialView = SpendingView.byItem,
    this.onItemTap,
    this.onWalletTap,
  });

  final LedgerBook book;
  final DateTime today;

  /// Limits the breakdown to some wallets (e.g. personal / business).
  final WalletPredicate? wallets;
  final SpendingView initialView;
  final ValueChanged<String?>? onItemTap;
  final ValueChanged<String>? onWalletTap;

  @override
  State<SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<SpendingCard> {
  late SpendingView _view = widget.initialView;
  BudgetPeriod _period = BudgetPeriod.monthly;
  int _offset = 0;

  static const _maxSlices = 6;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = MadarFormatter.of(context);
    final book = widget.book;
    final fmt = ledgerFormatOf(context, book);
    final window = LedgerReports.shift(LedgerReports.windowOf(widget.today, _period), _offset);
    final breakdown = _view == SpendingView.byItem
        ? LedgerReports.spendingByBudgetItem(
            book.transactions,
            window,
            walletCurrency: book.walletCurrency,
            rates: book.rates,
            budget: book.budget,
            wallets: widget.wallets,
          )
        : LedgerReports.spendingByWallet(
            book.transactions,
            window,
            walletCurrency: book.walletCurrency,
            rates: book.rates,
            wallets: widget.wallets,
          );
    final roots = book.budget?.rootIds ?? const <String>[];
    DonutSlice sliceOf(SpendSlice s) {
      if (_view == SpendingView.byWallet) {
        final w = book.wallet(s.id);
        final i = w == null ? 0 : book.wallets.indexOf(w);
        return DonutSlice(
          key: s.id ?? '',
          label: w?.name ?? '—',
          milli: s.baseMilli,
          share: s.share,
          color: w == null ? t.textTertiary : LedgerStyle.wallet(t, w, i),
        );
      }
      if (s.id == null) {
        return DonutSlice(
          key: '',
          label: l.ledgerUnassigned,
          milli: s.baseMilli,
          share: s.share,
          color: t.textTertiary,
        );
      }
      return DonutSlice(
        key: s.id!,
        label: book.budgetNameOf(s.id!) ?? '—',
        milli: s.baseMilli,
        share: s.share,
        color: LedgerStyle.budgetItem(t, book.lookOf(s.id), roots.indexOf(s.id!).clamp(0, 99)),
        icon: LedgerStyle.budgetIcon(book.lookOf(s.id)),
      );
    }

    var slices = [for (final s in breakdown.slices) sliceOf(s)];
    if (slices.length > _maxSlices) {
      final rest = slices.sublist(_maxSlices - 1);
      slices = [
        ...slices.take(_maxSlices - 1),
        DonutSlice(
          key: '_other',
          label: l.ledgerOther,
          milli: rest.fold(0, (a, s) => a + s.milli),
          share: rest.fold(0.0, (a, s) => a + s.share),
          color: t.textSecondary.withValues(alpha: 0.7),
        ),
      ];
    }
    final canNext = _offset < 0;
    final periodLabel = f.window(l, window);

    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ledgerSpending, style: text.titleMedium?.copyWith(color: t.textPrimary)),
                    Text(
                      l.ledgerInBase(LedgerMoneyFormat.isolate(book.baseCode)),
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              _NavButton(label: l.ledgerPrevPeriod, back: true, onTap: () => setState(() => _offset--)),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 84, maxWidth: 150),
                child: Text(
                  periodLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: t.textSecondary),
                ),
              ),
              _NavButton(
                label: l.ledgerNextPeriod,
                back: false,
                onTap: canNext ? () => setState(() => _offset++) : null,
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: LedgerSegmented<SpendingView>(
                  values: SpendingView.values,
                  value: _view,
                  height: 36,
                  labels: {SpendingView.byItem: l.ledgerByItem, SpendingView.byWallet: l.ledgerByWallet},
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                flex: 2,
                child: LedgerSegmented<BudgetPeriod>(
                  values: const [BudgetPeriod.monthly, BudgetPeriod.weekly],
                  value: _period,
                  height: 36,
                  labels: {BudgetPeriod.monthly: l.ledgerPeriodMonth, BudgetPeriod.weekly: l.ledgerPeriodWeek},
                  onChanged: (p) => setState(() {
                    _period = p;
                    _offset = 0;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            child: breakdown.isEmpty
                ? SizedBox(
                    key: const ValueKey('empty'),
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.donut_large_rounded, size: 34, color: t.textTertiary.withValues(alpha: 0.6)),
                          const SizedBox(height: Space.s),
                          Text(l.ledgerNoSpending, style: text.bodyMedium?.copyWith(color: t.textTertiary)),
                        ],
                      ),
                    ),
                  )
                : Semantics(
                    key: ValueKey('$_view-$_period-$_offset'),
                    label: BidiIsolate.strip(
                      l.ledgerChartSpendingSemantics(
                        periodLabel,
                        fmt.amount(breakdown.totalMilli, book.baseCode),
                        slices.map((s) => '${s.label} ${fmt.amount(s.milli, book.baseCode)}').join('، '),
                      ),
                    ),
                    child: SpendingDonut(
                      slices: slices,
                      totalText: fmt.amount(breakdown.totalMilli, book.baseCode),
                      totalLabel: l.ledgerTotal,
                      format: fmt,
                      currency: book.baseCode,
                      onSliceTap: (s) {
                        if (s.key == '_other') return;
                        if (_view == SpendingView.byWallet) {
                          if (s.key.isNotEmpty) widget.onWalletTap?.call(s.key);
                        } else {
                          widget.onItemTap?.call(s.key.isEmpty ? null : s.key);
                        }
                      },
                    ),
                  ),
          ),
          if (breakdown.missingRates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                l.ledgerMissingRate(breakdown.missingRates.join('، ')),
                style: text.bodySmall?.copyWith(color: t.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.back, required this.onTap});

  final String label;
  final bool back;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // "Back in time" points to where the timeline starts: right in Arabic.
    final glyph = back
        ? (rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded)
        : (rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded);
    return Opacity(
      opacity: onTap == null ? 0.3 : 1,
      child: SpringPress(
        onTap: onTap,
        enabled: onTap != null,
        sfx: Sfx.tap,
        semanticLabel: label,
        child: Padding(
          padding: const EdgeInsets.all(Space.xs),
          child: Icon(glyph, size: 24, color: t.textSecondary),
        ),
      ),
    );
  }
}

/// Income vs spending over the last [count] months, in the base currency.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.book, required this.today, this.count = 6, this.wallets});

  final LedgerBook book;
  final DateTime today;
  final int count;
  final WalletPredicate? wallets;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = MadarFormatter.of(context);
    final fmt = ledgerFormatOf(context, book);
    final buckets = LedgerReports.trend(
      book.transactions,
      anchor: today,
      walletCurrency: book.walletCurrency,
      rates: book.rates,
      count: count,
      wallets: wallets,
    );
    final suffix = compactSuffixes(context);
    final incomeColor = t.success;
    final expenseColor = t.accent;
    Widget legend(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: Space.xs),
        Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary)),
      ],
    );
    final totalIncome = buckets.fold(0, (a, b) => a + b.incomeMilli);
    final totalExpense = buckets.fold(0, (a, b) => a + b.expenseMilli);
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.ledgerTrend, style: text.titleMedium?.copyWith(color: t.textPrimary)),
          Text(
            '${f.localizeDigits(l.ledgerTrendSubtitle(count))} · ${l.ledgerInBase(LedgerMoneyFormat.isolate(book.baseCode))}',
            style: text.bodySmall?.copyWith(color: t.textTertiary),
          ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.l,
            runSpacing: Space.xs,
            children: [
              legend(incomeColor, '${l.ledgerIncomeTotal} ${fmt.amount(totalIncome, book.baseCode, decimals: 0)}'),
              legend(expenseColor, '${l.ledgerExpenseTotal} ${fmt.amount(totalExpense, book.baseCode, decimals: 0)}'),
            ],
          ),
          const SizedBox(height: Space.m),
          TrendBars(
            points: [
              for (final b in buckets)
                TrendPoint(
                  label: f.monthShort(b.window.start),
                  incomeMilli: b.incomeMilli,
                  expenseMilli: b.expenseMilli,
                  semantics: BidiIsolate.strip(
                    l.ledgerChartTrendSemantics(
                      f.monthYear(b.window.start),
                      fmt.amount(b.incomeMilli, book.baseCode),
                      fmt.amount(b.expenseMilli, book.baseCode),
                    ),
                  ),
                ),
            ],
            format: fmt,
            currency: book.baseCode,
            incomeColor: incomeColor,
            expenseColor: expenseColor,
            thousand: suffix.thousand,
            million: suffix.million,
          ),
        ],
      ),
    );
  }
}

/// Chart ranges of a wallet's balance history.
enum BalanceRange { month, quarter, year, all }

/// A wallet's balance over time with range chips.
class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key, required this.book, required this.walletId, required this.today, required this.color});

  final LedgerBook book;
  final String walletId;
  final DateTime today;
  final Color color;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  BalanceRange _range = BalanceRange.quarter;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = MadarFormatter.of(context);
    final book = widget.book;
    final wallet = book.wallet(widget.walletId);
    if (wallet == null) return const SizedBox.shrink();
    final fmt = ledgerFormatOf(context, book);
    final today = widget.today;
    final first = LedgerMath.firstDay(wallet, book.transactions) ?? today;
    final from = switch (_range) {
      BalanceRange.month => DateTime(today.year, today.month - 1, today.day),
      BalanceRange.quarter => DateTime(today.year, today.month - 3, today.day),
      BalanceRange.year => DateTime(today.year - 1, today.month, today.day),
      BalanceRange.all => first.isBefore(today) ? first : DateTime(today.year, today.month, today.day - 7),
    };
    final points = LedgerMath.balanceSeries(wallet, book.transactions, from: from, to: today, maxPoints: 90);
    final suffix = compactSuffixes(context);
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.ledgerBalanceHistory, style: text.titleMedium?.copyWith(color: t.textPrimary)),
              ),
              SizedBox(
                width: 200,
                child: LedgerSegmented<BalanceRange>(
                  values: BalanceRange.values,
                  value: _range,
                  height: 32,
                  labels: {
                    BalanceRange.month: l.ledgerRange1M,
                    BalanceRange.quarter: f.localizeDigits(l.ledgerRange3M),
                    BalanceRange.year: l.ledgerRange1Y,
                    BalanceRange.all: l.ledgerRangeAll,
                  },
                  onChanged: (r) => setState(() => _range = r),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          BalanceLine(
            points: points,
            color: widget.color,
            format: fmt,
            currency: wallet.currency,
            dateLabel: (d) => _range == BalanceRange.year || _range == BalanceRange.all && points.length > 60
                ? f.monthShort(d)
                : f.formatDate(d, style: MadarDateStyle.dayMonth),
            thousand: suffix.thousand,
            million: suffix.million,
          ),
        ],
      ),
    );
  }
}
