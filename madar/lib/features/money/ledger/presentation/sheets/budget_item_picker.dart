import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/domain/budget_math.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../../../core/interaction/src/pressable.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../domain/ledger_book.dart';
import '../../domain/tx_filter.dart';
import '../ledger_ui.dart';

/// The picker's result: an item id, or [BudgetPick.none] for "no item".
/// Null (dismissed) means "unchanged".
abstract final class BudgetPick {
  static const none = '';
}

/// Opens the budget item picker: the budget tree (indented), each item with
/// what is left of it this month, searchable, plus "no item".
Future<String?> showBudgetItemPicker(
  BuildContext context, {
  required LedgerBook book,
  required String? selected,
  required DateTime today,
  bool allowNone = true,
  String? title,
}) {
  return showInteractionSheet<String>(
    context,
    builder: (_) => BudgetItemPicker(book: book, selected: selected, today: today, allowNone: allowNone, title: title),
  );
}

class BudgetItemPicker extends StatefulWidget {
  const BudgetItemPicker({
    super.key,
    required this.book,
    required this.selected,
    required this.today,
    this.allowNone = true,
    this.title,
  });

  final LedgerBook book;
  final String? selected;
  final DateTime today;
  final bool allowNone;
  final String? title;

  @override
  State<BudgetItemPicker> createState() => _BudgetItemPickerState();
}

class _BudgetItemPickerState extends State<BudgetItemPicker> {
  String _query = '';
  late final BudgetSpendReport? _report = _spend();

  BudgetSpendReport? _spend() {
    final b = widget.book.budget;
    if (b == null) return null;
    final book = widget.book;
    return b.spend([
      for (final tx in book.transactions)
        if (tx.kind == TxKind.expense)
          BudgetTx(
            budgetItemId: tx.budgetItemId,
            amountMilli: tx.amountMilli.abs(),
            date: tx.date,
            currency: book.currencyOfWallet(tx.walletId),
          ),
    ], BudgetWindow.month(widget.today));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final book = widget.book;
    final tree = book.budgetTree;
    final q = LedgerSearch.normalize(_query);
    final visible = q.isEmpty
        ? tree
        : [
            for (final r in tree)
              if (LedgerSearch.normalize(book.budgetPath(r.node.id) ?? r.node.name).contains(q)) r,
          ];
    final roots = book.budget?.rootIds ?? const <String>[];
    int rootIndexOf(BudgetNodeResult r) {
      var cur = r;
      while (cur.parentId != null && book.budget![cur.parentId!] != null) {
        cur = book.budget![cur.parentId!]!;
      }
      return roots.indexOf(cur.node.id);
    }

    return InteractionSheetFrame(
      title: widget.title ?? l.ledgerBudgetItem,
      icon: Icons.account_tree_rounded,
      toolbar: tree.length > 7
          ? TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: kitInputDecoration(
                context,
                hint: l.ledgerSearchItems,
              ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textTertiary, size: 20), isDense: true),
            )
          : null,
      body: tree.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                l.ledgerNoBudget,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: t.textSecondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.allowNone && q.isEmpty)
                  _ItemRow(
                    depth: 0,
                    icon: Icons.remove_circle_outline_rounded,
                    color: t.textTertiary,
                    title: l.ledgerUnassigned,
                    selected: widget.selected == null,
                    onTap: () => Navigator.of(context).pop(BudgetPick.none),
                  ),
                for (final r in visible)
                  _ItemRow(
                    depth: q.isEmpty ? r.depth : 0,
                    icon: LedgerStyle.budgetIcon(book.lookOf(r.node.id)) ?? Icons.label_outline_rounded,
                    color: LedgerStyle.budgetItem(t, book.lookOf(r.node.id), rootIndexOf(r).clamp(0, 99)),
                    title: q.isEmpty ? r.node.name : (book.budgetPath(r.node.id) ?? r.node.name),
                    trailing: _remaining(context, r.node.id),
                    over: (_report?.byId[r.node.id]?.overspent ?? false),
                    selected: widget.selected == r.node.id,
                    onTap: () => Navigator.of(context).pop(r.node.id),
                  ),
              ],
            ),
    );
  }

  String? _remaining(BuildContext context, String id) {
    final s = _report?.byId[id];
    if (s == null || s.plannedMilli == 0) return null;
    final l = L10n.of(context);
    final fmt = ledgerFormatOf(context, widget.book);
    final amount = fmt.embed(fmt.amount(s.remainingMilli.abs(), widget.book.baseCode, trimZeros: true));
    return s.overspent ? l.ledgerItemOver(amount) : l.ledgerItemLeft(amount);
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.depth,
    required this.icon,
    required this.color,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.over = false,
  });

  final int depth;
  final IconData icon;
  final Color color;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 22.0, bottom: Space.xs + 2),
      child: KitPressable(
        onTap: onTap,
        sfx: Sfx.tap,
        selected: selected,
        semanticLabel: [title, ?trailing].join('، '),
        pressScale: 0.98,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft.withValues(alpha: t.accentSoft.a * 0.8) : t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.3 : 0.8),
          ),
          child: Row(
            children: [
              if (depth > 0) ...[
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.subdirectory_arrow_left_rounded
                      : Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: t.textTertiary,
                ),
                const SizedBox(width: Space.xs),
              ],
              LedgerMedallion(icon: icon, color: color, size: depth > 0 ? 30 : 34),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: BidiIsolate.directionOf(title),
                  textAlign: TextAlign.start,
                  style: (depth > 0 ? text.bodyMedium : text.titleSmall)?.copyWith(
                    color: t.textPrimary,
                    fontWeight: depth > 0 ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: LedgerStyle.amount(
                    t,
                    size: 12,
                    color: over ? t.danger : t.textTertiary,
                    weight: FontWeight.w500,
                  ),
                ),
              if (selected) ...[const SizedBox(width: Space.s), Icon(Icons.check_rounded, size: 18, color: t.accent)],
            ],
          ),
        ),
      ),
    );
  }
}
