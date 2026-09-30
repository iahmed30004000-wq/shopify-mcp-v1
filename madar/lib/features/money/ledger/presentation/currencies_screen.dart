import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart' show EntranceChoreo, StaggerItem;
import '../../../../core/sound/sound_api.dart';
import '../data/ledger_providers.dart';
import '../domain/currency_math.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_models.dart';
import 'ledger_ui.dart';
import 'money_ledger_screen.dart' show RatesNotice;
import 'sheets/currency_sheet.dart';
import 'sheets/rebase_sheet.dart';

/// Currencies and manual exchange rates: the base currency (change it with
/// an exact re-basing preview), the others with "1 X = … base" and the
/// inverse, drag to reorder, tap to edit, long-press for more; add your own
/// currencies. No rate is ever fetched online.
class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key, this.animateBackdrop = true});

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final bookAsync = ref.watch(ledgerBookProvider);
    return MadarScaffold(
      title: l.ledgerCurrenciesTitle,
      backdropSeed: 3.3,
      animateBackdrop: animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          semanticLabel: l.ledgerAddCurrency,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: bookAsync.value == null ? null : () => showCurrencySheet(context, ref),
        ),
      ],
      body: switch (bookAsync) {
        AsyncData(:final value) => _CurrenciesBody(book: value),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.ledgerCurrenciesTitle, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _CurrenciesBody extends ConsumerWidget {
  const _CurrenciesBody({required this.book});

  final LedgerBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final base = book.currency(book.baseCode);
    final others = [
      for (final c in book.currencies)
        if (!c.isBase) c,
    ];
    final usage = <String, int>{};
    for (final w in book.wallets) {
      usage[w.currency] = (usage[w.currency] ?? 0) + 1;
    }
    return EntranceChoreo(
      id: 'currencies',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          if (base != null)
            StaggerItem(
              index: 0,
              child: _BaseCard(book: book, base: base, hasOthers: others.isNotEmpty),
            ),
          if (book.ratesAreDefaults)
            StaggerItem(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: RatesNotice(
                  onReview: () {
                    final first = others.firstOrNull;
                    if (first != null) showCurrencySheet(context, ref, currency: first);
                  },
                ),
              ),
            ),
          StaggerItem(
            index: 2,
            child: SectionHeader(
              title: l.ledgerOtherCurrencies,
              subtitle: l.ledgerRatesStale,
              actionLabel: l.ledgerAddCurrency,
              onAction: () => showCurrencySheet(context, ref),
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          ReorderableGlassList<LedgerCurrency>(
            items: others,
            itemKey: (c) => c.code,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            onReorder: (order) =>
                ref.read(ledgerServiceProvider).reorderCurrencies([book.baseCode, for (final c in order) c.code]),
            itemBuilder: (context, c, index, handle) => _CurrencyRow(
              key: ValueKey(c.code),
              book: book,
              currency: c,
              usedBy: usage[c.code] ?? 0,
              handle: handle,
            ),
          ),
          const SizedBox(height: Space.m),
          Text(
            l.ledgerRateHint,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends ConsumerWidget {
  const _BaseCard({required this.book, required this.base, required this.hasOthers});

  final LedgerBook book;
  final LedgerCurrency base;
  final bool hasOthers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    return GlassPanel(
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _CodeBadge(code: base.code, symbol: fmt.symbolOf(base.code), color: t.gold, large: true),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ledgerBaseCurrency, style: text.labelLarge?.copyWith(color: t.gold)),
                    Text(
                      base.name(arabic: fmt.arabic),
                      style: text.titleLarge?.copyWith(color: t.textPrimary),
                    ),
                    Text(l.ledgerBaseHint, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: MadarButton(
                  label: l.ledgerChangeBase,
                  icon: Icons.published_with_changes_rounded,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: hasOthers ? () => showRebaseSheet(context, ref) : null,
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.edit_rounded,
                semanticLabel: l.ledgerEditCurrency,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => showCurrencySheet(context, ref, currency: base),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends ConsumerWidget {
  const _CurrencyRow({
    super.key,
    required this.book,
    required this.currency,
    required this.usedBy,
    required this.handle,
  });

  final LedgerBook book;
  final LedgerCurrency currency;
  final int usedBy;
  final Widget handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, book);
    final f = MadarFormatter.of(context);
    final rate = currency.rate;
    final one = fmt.number(1000, decimals: 0);
    // Arabic reads best with the symbols; English with the codes
    // ("1 JOD = 1.41044 USD", not "… 1.41044 $").
    String label(String code) => LedgerMoneyFormat.isolate(fmt.arabic ? fmt.symbolOf(code) : code);
    final baseSym = label(book.baseCode);
    final sym = label(currency.code);
    final line = rate == null ? l.ledgerNoRate : l.ledgerRateLine(one, sym, fmt.rate(rate), baseSym);
    final inverse = rate == null ? null : l.ledgerRateLine(one, baseSym, fmt.rate(RateMath.inverse(rate)), sym);
    final service = ref.read(ledgerServiceProvider);
    Future<UndoableAction?> delete() async {
      final undo = await service.deleteCurrency(currency.code);
      return UndoableAction(label: l.ledgerCurrencyDeleted, undo: undo);
    }

    return ActionableItem(
      onTap: () => showCurrencySheet(context, ref, currency: currency),
      semanticLabel: BidiIsolate.strip('${currency.code} ${currency.name(arabic: fmt.arabic)}، $line'),
      quickActions: [
        QuickAction(
          icon: Icons.edit_rounded,
          label: l.ledgerEditCurrency,
          tone: ActionTone.accent,
          onPressed: () async {
            await showCurrencySheet(context, ref, currency: currency);
            return null;
          },
        ),
        if (usedBy == 0)
          QuickAction(
            icon: Icons.delete_outline_rounded,
            label: l.actionDelete,
            tone: ActionTone.danger,
            onPressed: () {
              Fx.fire(Sfx.delete);
              return delete();
            },
          ),
      ],
      actions: ItemActions(
        onEdit: () => showCurrencySheet(context, ref, currency: currency),
        onDelete: usedBy > 0 ? null : delete,
        extra: [
          if (rate != null)
            ItemAction(
              icon: Icons.published_with_changes_rounded,
              label: l.ledgerMakeBase,
              tone: ActionTone.accent,
              onSelected: () async {
                await showRebaseSheet(context, ref, initial: currency.code);
                return null;
              },
            ),
          if (usedBy > 0)
            ItemAction(
              icon: Icons.lock_outline_rounded,
              label: f.localizeDigits(l.ledgerCurrencyInUse(usedBy)),
              enabled: false,
              onSelected: () => null,
            ),
        ],
      ),
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        child: Row(
          children: [
            _CodeBadge(code: currency.code, symbol: fmt.symbolOf(currency.code), color: t.highlight),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currency.name(arabic: fmt.arabic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: LedgerStyle.amount(
                      t,
                      size: 13,
                      color: rate == null ? t.warning : t.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (inverse != null)
                    Text(
                      inverse,
                      style: LedgerStyle.amount(t, size: 11.5, color: t.textTertiary, weight: FontWeight.w500),
                    ),
                  if (usedBy > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        f.localizeDigits(l.ledgerCurrencyInUse(usedBy)),
                        style: text.labelSmall?.copyWith(color: t.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
            handle,
          ],
        ),
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code, required this.symbol, required this.color, this.large = false});

  final String code;
  final String symbol;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = large ? 58.0 : 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: t.isDark ? 0.26 : 0.16),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.9),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            maxLines: 1,
            style: LedgerStyle.amount(t, size: large ? 15 : 13, color: color, weight: FontWeight.w700),
          ),
          if (symbol != code)
            Text(
              code,
              style: LedgerStyle.amount(t, size: 9, color: t.textTertiary, weight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}
