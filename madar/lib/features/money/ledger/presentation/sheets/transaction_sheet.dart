import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/domain/money.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, KitChip, PickerButton, kitInputDecoration;
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../data/ledger_service.dart';
import '../../../money_glyphs.dart';
import '../../domain/amount_entry.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_links.dart';
import '../../domain/ledger_math.dart';
import '../../domain/ledger_models.dart';
import '../../domain/tx_draft.dart';
import '../ledger_ui.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/ledger_segmented.dart';
import '../widgets/wallet_chip_row.dart';
import '../ledger_actions.dart';
import 'budget_item_picker.dart';

/// What the sheet saved (for the caller's undo toast).
class TransactionSheetResult {
  const TransactionSheetResult({required this.tx, required this.undo, required this.created});

  final LedgerTx tx;
  final LedgerUndo undo;
  final bool created;
}

/// Opens the add / edit transaction sheet and, after a save, the undo
/// toast. Returns the saved entry (null when dismissed).
///
/// * [transactionId] edits that entry; otherwise a new one is prefilled
///   with [kind], [walletId] (else the most recently used wallet),
///   [toWalletId] and [budgetItemId].
Future<LedgerTx?> showTransactionSheet(
  BuildContext context, {
  String? transactionId,
  TxKind kind = TxKind.expense,
  String? walletId,
  String? toWalletId,
  String? budgetItemId,
}) async {
  // Jar, debt and obligation entries are edited where they were made.
  if (transactionId != null && LedgerLinks.ofId(transactionId) != null) {
    Fx.fire(Sfx.error);
    return null;
  }
  final result = await showInteractionSheet<TransactionSheetResult>(
    context,
    builder: (_) => TransactionSheet(
      transactionId: transactionId,
      kind: kind,
      walletId: walletId,
      toWalletId: toWalletId,
      budgetItemId: budgetItemId,
    ),
  );
  if (result == null || !context.mounted) return result?.tx;
  final l = L10n.of(context);
  unawaited(
    showUndoToast(context, UndoableAction(label: result.created ? l.ledgerSaved : l.ledgerUpdated, undo: result.undo)),
  );
  return result.tx;
}

/// Keypad-first add / edit sheet: kind, amount in the wallet's currency,
/// wallet(s), budget item (tree picker), day, note and tags; transfers
/// between currencies (both amounts, or the rate) and balance adjustments
/// (actual balance or difference).
class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({
    super.key,
    this.transactionId,
    this.kind = TxKind.expense,
    this.walletId,
    this.toWalletId,
    this.budgetItemId,
  });

  final String? transactionId;
  final TxKind kind;
  final String? walletId;
  final String? toWalletId;
  final String? budgetItemId;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

enum _AmountField { main, received }

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  TxDraft? _draft;
  AmountEntry _amount = const AmountEntry();
  AmountEntry? _received;

  /// The stored (sent, received) amounts of the cross-currency transfer
  /// being edited, until the user types a received amount or changes a
  /// currency: editing what was sent then rescales what arrived at the
  /// transfer's own rate.
  (int, int)? _storedPair;
  _AmountField _field = _AmountField.main;
  bool _showCalendar = false;
  bool _tried = false;
  bool _saving = false;
  final _note = TextEditingController();
  final _tag = TextEditingController();

  bool get _editing => widget.transactionId != null;

  @override
  void dispose() {
    _note.dispose();
    _tag.dispose();
    super.dispose();
  }

  DateTime get _today {
    final n = ref.read(ledgerClockProvider)();
    return DateTime(n.year, n.month, n.day);
  }

  void _init(LedgerBook book, LedgerMoneyFormat fmt) {
    final existing = widget.transactionId == null ? null : book.transaction(widget.transactionId!);
    if (existing != null) {
      final d = TxDraft.fromTx(existing);
      _draft = d;
      _amount = AmountEntry.exact(d.amountMilli, decimals: fmt.decimalsOf(book.currencyOfWallet(d.walletId!) ?? ''));
      final fromCur = book.currencyOfWallet(existing.walletId) ?? '';
      final toCur = existing.toWalletId == null ? '' : (book.currencyOfWallet(existing.toWalletId!) ?? '');
      // Between two wallets of one currency the received amount is always
      // the sent one (see TxDraft.resolvedToAmount).
      if (existing.isTransfer && existing.toAmountMilli != null && existing.toWalletId != null && fromCur != toCur) {
        _received = AmountEntry.exact(existing.toAmountMilli!, decimals: fmt.decimalsOf(toCur));
        if (existing.amountMilli != 0) _storedPair = (existing.amountMilli.abs(), existing.toAmountMilli!.abs());
      }
      _note.text = d.note;
      return;
    }
    final active = book.activeWallets;
    String? wallet = widget.walletId;
    if (wallet == null || book.wallet(wallet) == null) {
      final recent = book.transactions.where((t) => book.wallet(t.walletId)?.archived == false).firstOrNull;
      wallet = recent?.walletId ?? active.firstOrNull?.id;
    }
    String? to = widget.toWalletId;
    if (widget.kind == TxKind.transfer && to == null) {
      to = active.where((w) => w.id != wallet).firstOrNull?.id;
    }
    _draft = TxDraft(
      kind: widget.kind,
      walletId: wallet,
      toWalletId: to,
      budgetItemId: widget.budgetItemId,
      date: _today,
    );
    _amount = AmountEntry('', fmt.decimalsOf(book.currencyOfWallet(wallet ?? '') ?? book.baseCode));
  }

  // ------------------------------------------------------------ edits --

  String _currencyOf(LedgerBook book, String? walletId) =>
      (walletId == null ? null : book.currencyOfWallet(walletId)) ?? book.baseCode;

  void _set(TxDraft d) => setState(() => _draft = d);

  void _onKey(KeypadKey key, LedgerMoneyFormat fmt, LedgerBook book) {
    final d = _draft!;
    if (_field == _AmountField.received && d.isTransfer) {
      final base = _received ?? AmountEntry('', fmt.decimalsOf(_currencyOf(book, d.toWalletId)));
      final next = base.press(key);
      if (next == base && key != KeypadKey.clear) {
        Fx.fire(Sfx.error);
        return;
      }
      setState(() {
        _storedPair = null;
        _received = next.isEmpty ? null : next;
        _draft = d.copyWith(toAmountMilli: next.milli, clearToAmount: next.isEmpty || next.milli == 0);
      });
      return;
    }
    final next = _amount.press(key);
    if (next == _amount && key != KeypadKey.clear) {
      Fx.fire(Sfx.error);
      return;
    }
    setState(() {
      _amount = next;
      _draft = d.copyWith(amountMilli: next.milli);
      final pair = _storedPair;
      if (pair != null && d.isTransfer) {
        final decimals = fmt.decimalsOf(_currencyOf(book, d.toWalletId));
        final received = TxDraft.rescaleReceived(
          sentMilli: pair.$1,
          receivedMilli: pair.$2,
          newSentMilli: next.milli,
          toDecimals: decimals,
        );
        _received = received == 0 ? null : AmountEntry.exact(received, decimals: decimals);
        _draft = _draft!.copyWith(toAmountMilli: received, clearToAmount: received == 0);
      }
    });
  }

  void _setKind(TxKind kind, LedgerBook book) {
    final d = _draft!;
    var next = d.copyWith(kind: kind);
    if (kind == TxKind.transfer && d.toWalletId == null) {
      final to = book.activeWallets.where((w) => w.id != d.walletId).firstOrNull;
      if (to != null) next = next.copyWith(toWalletId: to.id);
    }
    if (kind != TxKind.transfer) _field = _AmountField.main;
    _set(next);
  }

  void _setWallet(String id, LedgerBook book, LedgerMoneyFormat fmt) {
    final d = _draft!;
    final decimals = fmt.decimalsOf(_currencyOf(book, id));
    final amount = _amount.withDecimals(decimals);
    var next = d.copyWith(walletId: id, amountMilli: amount.milli);
    if (d.isTransfer && d.toWalletId == id) {
      final other = book.activeWallets.where((w) => w.id != id).firstOrNull;
      next = other == null ? next.copyWith(clearToWallet: true) : next.copyWith(toWalletId: other.id);
    }
    setState(() {
      if (_currencyOf(book, id) != _currencyOf(book, d.walletId)) _storedPair = null;
      _amount = amount;
      _draft = next;
    });
  }

  void _setToWallet(String id, LedgerBook book, LedgerMoneyFormat fmt) {
    final d = _draft!;
    final changedCurrency = _currencyOf(book, id) != _currencyOf(book, d.toWalletId);
    setState(() {
      if (changedCurrency) {
        _received = null;
        _storedPair = null;
        _draft = d.copyWith(toWalletId: id, clearToAmount: true);
      } else {
        _draft = d.copyWith(toWalletId: id);
      }
    });
  }

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '');
    if (tag.isEmpty) return;
    final d = _draft!;
    if (!d.tags.contains(tag)) {
      Fx.fire(Sfx.toggleOn);
      _set(d.copyWith(tags: [...d.tags, tag]));
    }
    _tag.clear();
  }

  Future<void> _pickItem(LedgerBook book) async {
    final d = _draft!;
    final picked = await LedgerActions.pickBudgetItem(
      context,
      ref,
      book: book,
      selected: d.budgetItemId,
      today: _today,
    );
    if (picked == null || !mounted) return;
    _set(picked == BudgetPick.none ? d.copyWith(clearBudgetItem: true) : d.copyWith(budgetItemId: picked));
  }

  Future<void> _save(LedgerBook book, LedgerMoneyFormat fmt) async {
    if (_saving) return;
    final d = _draft!.copyWith(note: _note.text);
    final current = d.walletId == null ? 0 : book.balanceWithout(d.walletId!, widget.transactionId);
    final errors = d.validate(currentBalanceMilli: current, currencyOf: book.currencyOfWallet, rates: book.rates);
    if (errors.isNotEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _tried = true);
      return;
    }
    final write = TxWrite.of(
      d,
      currencyOf: book.currencyOfWallet,
      rates: book.rates,
      currentBalanceMilli: current,
      decimalsOf: fmt.decimalsOf,
    );
    if (write == null) return;
    setState(() => _saving = true);
    final service = ref.read(ledgerServiceProvider);
    try {
      TransactionSheetResult result;
      if (_editing) {
        final undo = await service.update(widget.transactionId!, write);
        final tx = (await service.book()).transaction(widget.transactionId!)!;
        result = TransactionSheetResult(tx: tx, undo: undo, created: false);
      } else {
        final tx = await service.add(write);
        result = TransactionSheetResult(tx: tx, undo: () => service.delete(tx.id).then((_) {}), created: true);
      }
      Fx.fire(Sfx.complete);
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------ build --

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final bookAsync = ref.watch(ledgerBookProvider);
    final book = bookAsync.value;
    if (book == null) {
      return InteractionSheetFrame(
        title: _editing ? l.ledgerEditTx : l.ledgerAddTx,
        body: const Padding(
          padding: EdgeInsets.all(Space.xxl),
          child: Center(child: OrbitLoader(size: 36)),
        ),
      );
    }
    final fmt = ledgerFormatOf(context, book);
    if (_draft == null) _init(book, fmt);
    final d = _draft!;
    final t = context.tokens;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (book.activeWallets.isEmpty && !_editing) {
      return InteractionSheetFrame(
        title: l.ledgerAddTx,
        icon: Icons.receipt_long_rounded,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl),
          child: AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.ledgerSummaryEmpty,
            body: l.ledgerNeedWallet,
          ),
        ),
      );
    }

    final walletCurrency = _currencyOf(book, d.walletId);
    final decimals = fmt.decimalsOf(walletCurrency);
    final current = d.walletId == null ? 0 : book.balanceWithout(d.walletId!, widget.transactionId);
    final errors = _tried
        ? d.validate(currentBalanceMilli: current, currencyOf: book.currencyOfWallet, rates: book.rates)
        : const <TxDraftError>[];
    final kindTint = LedgerStyle.kind(t, d.kind);
    final activeDecimals = _field == _AmountField.received && d.isTransfer
        ? fmt.decimalsOf(_currencyOf(book, d.toWalletId))
        : decimals;

    return InteractionSheetFrame(
      title: _editing ? l.ledgerEditTx : l.ledgerAddTx,
      icon: LedgerStyle.kindIcon(d.kind),
      toolbar: LedgerSegmented<TxKind>(
        values: TxKind.values,
        value: d.kind,
        labels: {for (final k in TxKind.values) k: l.kind(k)},
        tints: {TxKind.income: t.success, TxKind.transfer: t.info, TxKind.adjustment: t.warning},
        onChanged: (k) => _setKind(k, book),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _amountArea(context, book, fmt, d, walletCurrency, current, kindTint),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: errors.isEmpty
                ? const SizedBox(width: double.infinity)
                : Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.s),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 16, color: t.danger),
                          const SizedBox(width: Space.xs),
                          Flexible(
                            child: Text(
                              l.draftError(errors.first),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: Space.l),
          ..._walletFields(context, book, fmt, d),
          if (d.usesBudgetItem && book.budget != null) ...[
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.ledgerBudgetItem,
              icon: Icons.account_tree_outlined,
              optional: true,
              child: PickerButton(
                icon: LedgerStyle.budgetIcon(book.lookOf(d.budgetItemId)) ?? Icons.account_tree_outlined,
                text: book.budgetPath(d.budgetItemId) ?? l.ledgerChooseItem,
                placeholder: d.budgetItemId == null,
                onTap: () => _pickItem(book),
              ),
            ),
          ],
          const SizedBox(height: Space.l),
          _dateField(context, d),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.ledgerNote,
            icon: Icons.notes_rounded,
            optional: true,
            child: TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: kitInputDecoration(context, hint: l.noteHint(d.kind)),
              onChanged: (v) => _draft = _draft!.copyWith(note: v),
            ),
          ),
          const SizedBox(height: Space.l),
          _tagsField(context, book, d),
          const SizedBox(height: Space.s),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            child: keyboard
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: AmountKeypad(decimalEnabled: activeDecimals > 0, onKey: (k) => _onKey(k, fmt, book)),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: SheetButton(
              label: l.actionSave,
              icon: Icons.check_rounded,
              primary: true,
              sfx: null,
              onPressed: _saving ? null : () => _save(book, fmt),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ amount area --

  String _entryText(AmountEntry e, LedgerMoneyFormat fmt) {
    if (e.isEmpty) return fmt.number(0, decimals: 0);
    final parts = e.text.split('.');
    final whole = parts[0].isEmpty ? '0' : parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
      grouped.write(whole[i]);
    }
    var s = grouped.toString();
    if (e.hasDecimal) s = '$s.${parts.length > 1 ? parts[1] : ''}';
    if (!fmt.arabicIndic) return s;
    return _indic(s);
  }

  static String _indic(String s) {
    final out = StringBuffer();
    for (final c in s.codeUnits) {
      if (c >= 0x30 && c <= 0x39) {
        out.writeCharCode(0x0660 + c - 0x30);
      } else if (c == 0x2E) {
        out.write('\u066B');
      } else if (c == 0x2C) {
        out.write(MoneyGlyphs.arabicGroup);
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  Widget _bigAmount(
    BuildContext context, {
    required String text,
    required int milli,
    required String currency,
    required LedgerMoneyFormat fmt,
    required Color color,
    required bool placeholder,
    double size = 40,
    String? semanticLabel,
  }) {
    final t = context.tokens;
    final symbol = fmt.symbolOf(currency);
    final prefix = !fmt.arabic && CurrencyCatalog.isPrefixSign(currency);
    final numberStyle = LedgerStyle.amount(
      t,
      size: size,
      color: placeholder ? t.textTertiary : color,
      weight: FontWeight.w600,
    );
    final symbolStyle = LedgerStyle.amount(t, size: size * 0.45, color: t.textSecondary, weight: FontWeight.w500);
    final number = Text(text, maxLines: 1, style: numberStyle);
    final sym = Text(symbol, style: symbolStyle, textDirection: BidiIsolate.directionOf(symbol));
    return Semantics(
      label: semanticLabel,
      value: BidiIsolate.strip(fmt.amount(milli, currency)),
      liveRegion: true,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: prefix ? [sym, const SizedBox(width: 4), number] : [number, const SizedBox(width: 8), sym],
        ),
      ),
    );
  }

  Widget _amountArea(
    BuildContext context,
    LedgerBook book,
    LedgerMoneyFormat fmt,
    TxDraft d,
    String walletCurrency,
    int current,
    Color tint,
  ) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (d.isTransfer) {
      final toCurrency = _currencyOf(book, d.toWalletId);
      final sameCurrency = toCurrency == walletCurrency;
      final resolved = d.resolvedToAmount(
        fromCurrency: walletCurrency,
        toCurrency: toCurrency,
        rates: book.rates,
        toDecimals: fmt.decimalsOf(toCurrency),
      );
      final manual = _received != null;
      final cross = book.rates.cross(walletCurrency, toCurrency);
      Widget box({required _AmountField field, required String label, required Widget child, Widget? footer}) {
        final active = _field == field && !sameCurrency;
        return KitPressableBox(
          active: active,
          onTap: sameCurrency ? null : () => setState(() => _field = field),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: text.labelMedium?.copyWith(color: active ? t.accent : t.textTertiary)),
              const SizedBox(height: Space.xs),
              child,
              ?footer,
            ],
          ),
        );
      }

      final sent = box(
        field: _AmountField.main,
        label: l.ledgerSent,
        child: _bigAmount(
          context,
          text: _entryText(_amount, fmt),
          milli: _amount.milli,
          currency: walletCurrency,
          fmt: fmt,
          color: tint,
          placeholder: _amount.isEmpty,
          size: sameCurrency ? 40 : 30,
          semanticLabel: l.ledgerSent,
        ),
      );
      if (sameCurrency) return sent;
      final receivedText = manual
          ? _entryText(_received!, fmt)
          : (resolved == null
                ? (fmt.number(0, decimals: 0))
                : fmt.number(resolved, decimals: fmt.decimalsOf(toCurrency)));
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: sent),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: Icon(Icons.arrow_forward_rounded, color: t.textTertiary, size: 20),
              ),
              Expanded(
                child: box(
                  field: _AmountField.received,
                  label: l.ledgerReceived,
                  child: _bigAmount(
                    context,
                    text: receivedText,
                    milli: manual ? _received!.milli : (resolved ?? 0),
                    currency: toCurrency,
                    fmt: fmt,
                    color: manual ? tint : t.textSecondary,
                    placeholder: resolved == null && !manual,
                    size: 30,
                    semanticLabel: l.ledgerReceived,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cross != null)
                Flexible(
                  child: Text(
                    l.ledgerRateLine(
                      fmt.number(1000, decimals: 0),
                      LedgerMoneyFormat.isolate(fmt.symbolOf(walletCurrency)),
                      fmt.rate(cross),
                      LedgerMoneyFormat.isolate(fmt.symbolOf(toCurrency)),
                    ),
                    style: LedgerStyle.amount(t, size: 12, color: t.textTertiary, weight: FontWeight.w500),
                  ),
                ),
              if (manual && cross != null) ...[
                const SizedBox(width: Space.s),
                KitChip(
                  dense: true,
                  label: l.ledgerUseRate,
                  icon: Icons.currency_exchange_rounded,
                  selected: false,
                  sfx: Sfx.toggleOff,
                  onTap: () => setState(() {
                    _received = null;
                    _storedPair = null;
                    _draft = d.copyWith(clearToAmount: true);
                  }),
                ),
              ],
            ],
          ),
        ],
      );
    }

    if (d.isAdjustment) {
      final delta = d.adjustmentDelta(current);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LedgerSegmented<AdjustMode>(
                  values: AdjustMode.values,
                  value: d.adjustMode,
                  height: 38,
                  labels: {AdjustMode.setBalance: l.ledgerSetBalance, AdjustMode.delta: l.ledgerDifference},
                  onChanged: (m) => _set(d.copyWith(adjustMode: m)),
                ),
              ),
              const SizedBox(width: Space.s),
              KitChip(
                dense: true,
                label: l.ledgerNegative,
                icon: Icons.remove_rounded,
                selected: d.negative,
                onTap: () => _set(d.copyWith(negative: !d.negative)),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Center(
            child: _bigAmount(
              context,
              text: '${d.negative ? (fmt.arabic ? '\u061C-' : '-') : ''}${_entryText(_amount, fmt)}',
              milli: d.signedAmountMilli,
              currency: walletCurrency,
              fmt: fmt,
              color: tint,
              placeholder: _amount.isEmpty,
              semanticLabel: d.adjustMode == AdjustMode.setBalance ? l.ledgerSetBalance : l.ledgerDifference,
            ),
          ),
          const SizedBox(height: Space.s),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.m,
            children: [
              Text(
                '${l.ledgerCurrentBalance}: ${fmt.embed(fmt.amount(current, walletCurrency))}',
                style: text.bodySmall?.copyWith(color: t.textTertiary),
              ),
              if (d.adjustMode == AdjustMode.setBalance && !_amount.isEmpty)
                Text(
                  '${l.ledgerDifference}: ${fmt.embed(fmt.amount(delta, walletCurrency, sign: SignDisplay.always))}',
                  style: text.bodySmall?.copyWith(color: delta == 0 ? t.textTertiary : t.warning),
                ),
            ],
          ),
        ],
      );
    }

    final balance = d.walletId == null ? null : book.balanceOf(d.walletId!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Space.s),
        _bigAmount(
          context,
          text: _entryText(_amount, fmt),
          milli: _amount.milli,
          currency: walletCurrency,
          fmt: fmt,
          color: tint,
          placeholder: _amount.isEmpty,
          size: 44,
          semanticLabel: l.ledgerAmount,
        ),
        if (balance != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              l.ledgerBalanceAfter(fmt.embed(fmt.amount(balance, walletCurrency))),
              style: text.bodySmall?.copyWith(color: t.textTertiary),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------- wallets --

  List<Widget> _walletFields(BuildContext context, LedgerBook book, LedgerMoneyFormat fmt, TxDraft d) {
    final l = L10n.of(context);
    final wallets = [
      for (final w in book.wallets)
        if (!w.archived || w.id == d.walletId || w.id == d.toWalletId) w,
    ];
    Widget row(String? selected, ValueChanged<String> onPick, {String? disabled}) =>
        WalletChipRow(book: book, wallets: wallets, selected: selected, onPick: onPick, disabled: disabled);

    if (d.isTransfer) {
      return [
        FieldShell(
          label: l.ledgerFrom,
          icon: Icons.logout_rounded,
          child: row(d.walletId, (id) => _setWallet(id, book, fmt)),
        ),
        const SizedBox(height: Space.m),
        FieldShell(
          label: l.ledgerTo,
          icon: Icons.login_rounded,
          child: row(d.toWalletId, (id) => _setToWallet(id, book, fmt), disabled: d.walletId),
        ),
      ];
    }
    return [
      FieldShell(
        label: l.ledgerWallet,
        icon: Icons.account_balance_wallet_outlined,
        child: row(d.walletId, (id) => _setWallet(id, book, fmt)),
      ),
    ];
  }

  // ------------------------------------------------------------- date --

  Widget _dateField(BuildContext context, TxDraft d) {
    final l = L10n.of(context);
    final f = MadarFormatter.of(context);
    final today = _today;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final day = LedgerMath.dayOf(d.date);
    final other = day != today && day != yesterday;
    return FieldShell(
      label: l.ledgerDate,
      icon: Icons.event_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              KitChip(
                dense: true,
                label: l.ledgerToday,
                selected: day == today,
                sfx: Sfx.tap,
                onTap: () => setState(() {
                  _showCalendar = false;
                  _draft = d.copyWith(date: today);
                }),
              ),
              KitChip(
                dense: true,
                label: l.ledgerYesterday,
                selected: day == yesterday,
                sfx: Sfx.tap,
                onTap: () => setState(() {
                  _showCalendar = false;
                  _draft = d.copyWith(date: yesterday);
                }),
              ),
              KitChip(
                dense: true,
                icon: Icons.calendar_month_rounded,
                label: other ? f.day(l, day, today) : l.ledgerOtherDay,
                selected: other || _showCalendar,
                sfx: _showCalendar ? Sfx.sheetClose : Sfx.sheetOpen,
                onTap: () => setState(() => _showCalendar = !_showCalendar),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.emphasized,
            alignment: AlignmentDirectional.topStart,
            child: !_showCalendar
                ? const SizedBox(width: double.infinity)
                : CalendarDatePicker(
                    key: ValueKey(day),
                    initialDate: day,
                    currentDate: today,
                    firstDate: DateTime(today.year - 20),
                    lastDate: DateTime(today.year + 5, 12, 31),
                    onDateChanged: (v) {
                      Fx.fire(Sfx.tap);
                      setState(() {
                        _draft = _draft!.copyWith(date: DateTime(v.year, v.month, v.day));
                        _showCalendar = false;
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- tags --

  Widget _tagsField(BuildContext context, LedgerBook book, TxDraft d) {
    final l = L10n.of(context);
    final suggestions = [
      for (final tag in book.tags)
        if (!d.tags.contains(tag)) tag,
    ].take(6).toList();
    return FieldShell(
      label: l.ledgerTags,
      icon: Icons.sell_outlined,
      optional: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.tags.isNotEmpty || suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final tag in d.tags)
                    KitChip(
                      dense: true,
                      label: '#$tag',
                      selected: true,
                      onTap: () => _set(d.copyWith(tags: [...d.tags]..remove(tag))),
                      onRemove: () => _set(d.copyWith(tags: [...d.tags]..remove(tag))),
                      removeLabel: l.actionDelete,
                    ),
                  for (final tag in suggestions)
                    KitChip(dense: true, label: '#$tag', selected: false, onTap: () => _addTag(tag)),
                ],
              ),
            ),
          TextField(
            controller: _tag,
            textInputAction: TextInputAction.done,
            onSubmitted: _addTag,
            decoration: kitInputDecoration(
              context,
              hint: l.ledgerTagHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: l.actionAdd,
                onPressed: () => _addTag(_tag.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable framed box (the transfer amounts).
class KitPressableBox extends StatelessWidget {
  const KitPressableBox({super.key, required this.active, required this.child, this.onTap});

  final bool active;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
      decoration: BoxDecoration(
        color: active ? t.accentSoft.withValues(alpha: t.accentSoft.a * 0.6) : t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: active ? t.accent : t.glassBorder, width: active ? 1.3 : 0.8),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return SpringPress(onTap: onTap, sfx: Sfx.tap, pressScale: 0.98, child: box);
  }
}
