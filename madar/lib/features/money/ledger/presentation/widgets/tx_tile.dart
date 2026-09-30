import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_links.dart';
import '../../domain/ledger_math.dart';
import '../../domain/ledger_models.dart';
import '../../domain/tx_filter.dart';
import '../ledger_ui.dart';

/// What a transaction row can do (wired by the screen).
///
/// Entries linked to a jar, debt or obligation ([LedgerLinks]) only offer
/// [onOpenLinked]: they are edited where they were made.
class TxTileActions {
  const TxTileActions({this.onEdit, this.onDuplicate, this.onMove, this.onDelete, this.onOpenLinked});

  final FutureOr<void> Function(LedgerTx tx)? onEdit;
  final FutureOr<UndoableAction?> Function(LedgerTx tx)? onDuplicate;
  final FutureOr<UndoableAction?> Function(LedgerTx tx)? onMove;
  final FutureOr<UndoableAction?> Function(LedgerTx tx)? onDelete;
  final FutureOr<void> Function(LedgerTx tx, LedgerLink link)? onOpenLinked;
}

/// One ledger entry: medallion, title (note, budget item or kind), details
/// (budget path, wallet, tags) and the signed amount – seen from
/// [perspectiveWalletId] when given (transfers in are +, out are −), with
/// the wallet's running balance under it.
class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.tx,
    required this.book,
    this.perspectiveWalletId,
    this.runningBalance,
    this.showWallet = true,
    this.actions = const TxTileActions(),
  });

  final LedgerTx tx;
  final LedgerBook book;
  final String? perspectiveWalletId;
  final int? runningBalance;
  final bool showWallet;
  final TxTileActions actions;

  /// "From → To" in the UI's direction. The arrow belongs to the
  /// translation (`←` in Arabic), so the route must lay out in the UI
  /// direction even when both wallet names are in the other script.
  static String routeOf(LedgerTx tx, LedgerBook book, L10n l) {
    final from = book.walletNameOf(tx.walletId) ?? '—';
    final to = tx.toWalletId == null ? '—' : (book.walletNameOf(tx.toWalletId!) ?? '—');
    final route = l.ledgerTransferRoute(LedgerMoneyFormat.isolate(from), LedgerMoneyFormat.isolate(to));
    return l.localeName.startsWith('ar') ? BidiIsolate.rtl(route) : BidiIsolate.ltr(route);
  }

  /// The row's title.
  static String titleOf(LedgerTx tx, LedgerBook book, L10n l, {String? perspectiveWalletId}) {
    final note = tx.cleanNote;
    final link = LedgerLinks.of(tx);
    if (link != null && tx.kind == TxKind.adjustment) return note ?? l.link(link);
    switch (tx.kind) {
      case TxKind.transfer:
        final from = book.walletNameOf(tx.walletId) ?? '—';
        final to = tx.toWalletId == null ? '—' : (book.walletNameOf(tx.toWalletId!) ?? '—');
        if (note != null) return note;
        if (perspectiveWalletId != null && perspectiveWalletId == tx.toWalletId) {
          return l.ledgerTransferIn(LedgerMoneyFormat.isolate(from));
        }
        if (perspectiveWalletId != null) return l.ledgerTransferOut(LedgerMoneyFormat.isolate(to));
        return routeOf(tx, book, l);
      case TxKind.adjustment:
        return note ?? l.ledgerAdjustmentTitle;
      case TxKind.expense:
      case TxKind.income:
        return note ?? book.budgetNameOf(tx.budgetItemId ?? '') ?? l.kind(tx.kind);
    }
  }

  /// The row's detail line.
  static String detailOf(
    LedgerTx tx,
    LedgerBook book,
    L10n l, {
    required bool showWallet,
    String? perspectiveWalletId,
  }) {
    // Each part is isolated on its own; the route keeps the UI direction.
    final parts = <String>[];
    void add(String part) => parts.add(LedgerMoneyFormat.isolate(part));
    switch (tx.kind) {
      case TxKind.expense:
      case TxKind.income:
        final path = book.budgetPath(tx.budgetItemId);
        if (tx.cleanNote != null) {
          add(path ?? (tx.kind == TxKind.income ? l.ledgerKindIncome : l.ledgerUnassigned));
        } else if (path != null && path.contains(' › ')) {
          add(path.substring(0, path.lastIndexOf(' › ')));
        } else if (tx.budgetItemId == null && tx.kind == TxKind.expense) {
          add(l.ledgerUnassigned);
        }
      case TxKind.transfer:
        if (tx.cleanNote != null) {
          parts.add(routeOf(tx, book, l));
        } else {
          add(l.ledgerKindTransfer);
        }
      case TxKind.adjustment:
        final link = LedgerLinks.of(tx);
        if (link != null) {
          if (tx.cleanNote != null) add(l.link(link));
        } else if (tx.cleanNote != null) {
          add(l.ledgerAdjustmentTitle);
        }
    }
    if (showWallet && tx.kind != TxKind.transfer) {
      final w = book.walletNameOf(tx.walletId);
      if (w != null) add(w);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = ledgerFormatOf(context, book);
    final wallet = book.wallet(tx.walletId);
    final walletCurrency = wallet?.currency ?? book.baseCode;

    // Amount from the chosen perspective.
    final int shownMilli;
    final String shownCurrency;
    final SignDisplay sign;
    if (perspectiveWalletId != null) {
      shownMilli = LedgerMath.effectOn(tx, perspectiveWalletId!);
      shownCurrency = book.currencyOfWallet(perspectiveWalletId!) ?? walletCurrency;
      sign = SignDisplay.always;
    } else {
      shownCurrency = walletCurrency;
      (shownMilli, sign) = switch (tx.kind) {
        TxKind.expense => (-tx.amountMilli.abs(), SignDisplay.always),
        TxKind.income => (tx.amountMilli.abs(), SignDisplay.always),
        TxKind.transfer => (tx.amountMilli.abs(), SignDisplay.never),
        TxKind.adjustment => (tx.amountMilli, SignDisplay.always),
      };
    }
    final amountColor = switch (tx.kind) {
      TxKind.transfer when perspectiveWalletId == null => t.info,
      _ => signedColor(t, shownMilli),
    };

    // Medallion: the budget item's look (inherited from its parents) for
    // expenses / income, else the kind.
    final hasItem = tx.budgetItemId != null && book.budget?[tx.budgetItemId!] != null;
    final look = hasItem ? book.lookOf(tx.budgetItemId) : null;
    final medallionColor = switch (tx.kind) {
      TxKind.income => t.success,
      TxKind.transfer => t.info,
      TxKind.adjustment => t.warning,
      TxKind.expense =>
        hasItem ? LedgerStyle.budgetItem(t, look, book.rootIndexOf(tx.budgetItemId).clamp(0, 99)) : t.textSecondary,
    };
    final link = LedgerLinks.of(tx);
    final icon = link != null
        ? LedgerStyle.linkIcon(link)
        : (tx.kind == TxKind.expense || tx.kind == TxKind.income)
        ? (LedgerStyle.budgetIcon(look) ?? LedgerStyle.kindIcon(tx.kind))
        : LedgerStyle.kindIcon(tx.kind);
    final tint = switch (link) {
      LedgerLink.jar => t.gold,
      LedgerLink.debt => t.highlight,
      _ => medallionColor,
    };
    final tags = LedgerLinks.visibleTags(tx);

    final title = titleOf(tx, book, l, perspectiveWalletId: perspectiveWalletId);
    final detail = detailOf(tx, book, l, showWallet: showWallet, perspectiveWalletId: perspectiveWalletId);
    final amountText = fmt.amount(shownMilli, shownCurrency, sign: sign);

    // A transfer between currencies shows what arrived, too.
    String? secondary;
    if (runningBalance != null) {
      secondary = l.ledgerBalanceAfter(fmt.embed(fmt.amount(runningBalance!, shownCurrency)));
    } else if (tx.hasDestination && perspectiveWalletId == null) {
      final toCurrency = book.currencyOfWallet(tx.toWalletId!);
      if (toCurrency != null && toCurrency != walletCurrency) {
        secondary = fmt.amount(tx.receivedMilli, toCurrency);
      }
    }

    final semantic = [
      title,
      amountText,
      if (detail.isNotEmpty) detail,
      ?secondary,
      if (link != null) l.ledgerLinkedHint(l.link(link)),
    ].join('، ');

    if (link != null) {
      final open = actions.onOpenLinked;
      return ActionableItem(
        onTap: open == null ? null : () => open(tx, link),
        semanticLabel: BidiIsolate.strip(semantic),
        swipeEnabled: false,
        actions: open == null
            ? ItemActions.none
            : ItemActions(
                extra: [
                  ItemAction(
                    icon: LedgerStyle.linkIcon(link),
                    label: l.openLink(link),
                    tone: ActionTone.accent,
                    onSelected: () async {
                      await open(tx, link);
                      return null;
                    },
                  ),
                ],
              ),
        child: _body(context, title, detail, tags, icon, tint, amountText, amountColor, secondary, link: link),
      );
    }

    return ActionableItem(
      onTap: actions.onEdit == null ? null : () => actions.onEdit!(tx),
      semanticLabel: BidiIsolate.strip(semantic),
      actions: ItemActions(
        onEdit: actions.onEdit == null ? null : () => actions.onEdit!(tx),
        onDuplicate: actions.onDuplicate == null ? null : () => actions.onDuplicate!(tx),
        onMove: actions.onMove == null ? null : () => actions.onMove!(tx),
        onDelete: actions.onDelete == null ? null : () => actions.onDelete!(tx),
      ),
      quickActions: [
        if (actions.onDuplicate != null)
          QuickAction(
            icon: Icons.copy_rounded,
            label: l.ledgerDuplicateToday,
            onPressed: () {
              Fx.fire(Sfx.complete);
              return actions.onDuplicate!(tx);
            },
            tone: ActionTone.accent,
          ),
        if (actions.onDelete != null)
          QuickAction(
            icon: Icons.delete_outline_rounded,
            label: l.actionDelete,
            onPressed: () {
              Fx.fire(Sfx.delete);
              return actions.onDelete!(tx);
            },
            tone: ActionTone.danger,
          ),
      ],
      child: _body(context, title, detail, tags, icon, tint, amountText, amountColor, secondary),
    );
  }

  Widget _body(
    BuildContext context,
    String title,
    String detail,
    List<String> tags,
    IconData icon,
    Color tint,
    String amountText,
    Color amountColor,
    String? secondary, {
    LedgerLink? link,
  }) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          _medallion(icon, tint, link),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // A route ("A → B") follows the UI; a note its own script.
                  textDirection: tx.isTransfer && tx.cleanNote == null
                      ? Directionality.of(context)
                      : BidiIsolate.directionOf(title),
                  textAlign: TextAlign.start,
                  style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                ),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.xs),
                    child: Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xxs,
                      children: [for (final tag in tags.take(3)) TagPill(tag: tag)],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(amountText, maxLines: 1, style: LedgerStyle.amount(t, size: 15, color: amountColor)),
                  if (secondary != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(
                        secondary,
                        maxLines: 1,
                        style: LedgerStyle.amount(t, size: 11.5, color: t.textTertiary, weight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The medallion; a linked entry wears a small link badge.
  Widget _medallion(IconData icon, Color color, LedgerLink? link) {
    const size = 40.0;
    final medallion = LedgerMedallion(icon: icon, color: color, size: size);
    if (link == null) return medallion;
    return Builder(
      builder: (context) {
        final t = context.tokens;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              medallion,
              PositionedDirectional(
                end: -3,
                bottom: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.space2,
                    border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: Icon(Icons.link_rounded, size: 11, color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small tag pill.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = L10n.of(context).tag(tag);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 1),
      decoration: BoxDecoration(
        color: t.accentSoft.withValues(alpha: t.accentSoft.a * 0.6),
        borderRadius: BorderRadius.circular(t.radiusXL),
        border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.7),
      ),
      child: Text(
        '#$label',
        maxLines: 1,
        textDirection: BidiIsolate.directionOf(label),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.accent, fontSize: 11),
      ),
    );
  }
}

/// A day header: the day and, on the far side, the day's total.
class TxDayHeader extends StatelessWidget {
  const TxDayHeader({super.key, required this.label, this.total, this.totalColor});

  final String label;
  final String? total;
  final Color? totalColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: text.labelLarge?.copyWith(color: t.textSecondary, letterSpacing: 0.2)),
            ),
            if (total != null)
              Text(
                total!,
                style: LedgerStyle.amount(t, size: 12.5, color: totalColor ?? t.textTertiary, weight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flattened rows of a day-grouped list (header, entry, header, …).
sealed class TxListRow {
  const TxListRow();
}

class TxHeaderRow extends TxListRow {
  const TxHeaderRow(this.group);
  final TxDayGroup group;
}

class TxEntryRow extends TxListRow {
  const TxEntryRow(this.tx);
  final LedgerTx tx;
}

abstract final class TxListRows {
  static List<TxListRow> of(Iterable<LedgerTx> txs) => [
    for (final g in TxGrouping.byDay(txs)) ...[TxHeaderRow(g), for (final tx in g.txs) TxEntryRow(tx)],
  ];
}

/// Builds the row widgets of a day-grouped list.
class TxRowBuilder {
  TxRowBuilder({
    required this.context,
    required this.book,
    required this.today,
    this.perspectiveWalletId,
    this.actions = const TxTileActions(),
    this.showWallet = true,
  }) : _running = perspectiveWalletId == null || book.wallet(perspectiveWalletId) == null
           ? const {}
           : LedgerMath.runningBalances(book.wallet(perspectiveWalletId)!, book.transactions);

  final BuildContext context;
  final LedgerBook book;
  final DateTime today;
  final String? perspectiveWalletId;
  final TxTileActions actions;
  final bool showWallet;
  final Map<String, int> _running;

  Widget build(TxListRow row) {
    switch (row) {
      case TxHeaderRow(:final group):
        final l = L10n.of(context);
        final t = context.tokens;
        final fmt = ledgerFormatOf(context, book);
        final label = MadarFormatter.of(context).day(l, group.day, today);
        String? total;
        Color? color;
        final w = perspectiveWalletId;
        if (w != null) {
          var sum = 0;
          for (final tx in group.txs) {
            sum += LedgerMath.effectOn(tx, w);
          }
          if (sum != 0) {
            total = fmt.amount(sum, book.currencyOfWallet(w) ?? book.baseCode, sign: SignDisplay.always);
            color = sum > 0 ? t.success.withValues(alpha: 0.85) : t.textTertiary;
          }
        } else {
          final flow = LedgerFlowOf.day(group.txs, book);
          if (flow != 0) {
            total = fmt.amount(flow, book.baseCode, sign: SignDisplay.always);
            color = flow > 0 ? t.success.withValues(alpha: 0.85) : t.textTertiary;
          }
        }
        return TxDayHeader(key: ValueKey('day-${group.day}'), label: label, total: total, totalColor: color);
      case TxEntryRow(:final tx):
        return Padding(
          key: ValueKey('tx-${tx.id}'),
          padding: const EdgeInsetsDirectional.only(bottom: Space.s),
          child: TxTile(
            tx: tx,
            book: book,
            perspectiveWalletId: perspectiveWalletId,
            runningBalance: _running[tx.id],
            showWallet: showWallet,
            actions: actions,
          ),
        );
    }
  }
}

/// Day totals in the base currency (income − spending).
abstract final class LedgerFlowOf {
  static int day(Iterable<LedgerTx> txs, LedgerBook book) {
    final income = BaseSum(book.rates), expense = BaseSum(book.rates);
    for (final tx in txs) {
      final code = book.currencyOfWallet(tx.walletId) ?? book.baseCode;
      if (tx.kind == TxKind.income) income.add(tx.amountMilli.abs(), code);
      if (tx.kind == TxKind.expense) expense.add(tx.amountMilli.abs(), code);
    }
    return (income.exact - expense.exact).roundHalfUp();
  }
}
