import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/domain/money.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, kitInputDecoration, kitNumberFormatter;
import '../../../../../core/sound/sound_api.dart';
import '../../data/ledger_providers.dart';
import '../../domain/currency_math.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_format.dart';
import '../../domain/ledger_models.dart';
import '../ledger_ui.dart';
import '../widgets/ledger_segmented.dart';

/// Opens the currency editor ([currency] null = add a currency, with
/// [code] prefilled when given), saves and shows the undo toast. The rate
/// can be typed either way round ("1 SYP = … JOD" or "1 JOD = … SYP") and
/// is stored exactly.
Future<void> showCurrencySheet(BuildContext context, WidgetRef ref, {LedgerCurrency? currency, String? code}) async {
  final book = ref.read(ledgerBookProvider).value;
  if (book == null) return;
  final saved = await showInteractionSheet<bool>(
    context,
    builder: (_) => CurrencySheet(book: book, currency: currency, initialCode: code),
  );
  if (saved != true || !context.mounted) return;
}

class CurrencySheet extends ConsumerStatefulWidget {
  const CurrencySheet({super.key, required this.book, this.currency, this.initialCode});

  final LedgerBook book;
  final LedgerCurrency? currency;

  /// Prefills the code of a new currency.
  final String? initialCode;

  @override
  ConsumerState<CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends ConsumerState<CurrencySheet> {
  late final _code = TextEditingController(text: widget.currency?.code ?? widget.initialCode ?? '');
  late final _nameAr = TextEditingController(text: widget.currency?.nameAr ?? '');
  late final _nameEn = TextEditingController(text: widget.currency?.nameEn ?? '');
  late final _symbol = TextEditingController(text: widget.currency?.symbol ?? '');
  late final _rate = TextEditingController();
  late int _decimals = widget.currency?.decimals ?? 2;
  bool _inverted = false;

  /// Whether the user typed a rate (else an edit keeps the stored one
  /// exactly, instead of re-reading the displayed decimal).
  bool _rateTouched = false;
  bool _tried = false;
  bool _saving = false;

  bool get _isNew => widget.currency == null;
  bool get _isBase => widget.currency?.isBase ?? false;

  @override
  void initState() {
    super.initState();
    final r = widget.currency?.rate;
    if (r != null && !_isBase) {
      // Weak currencies read better the other way round (1 JOD = 18,000 SYP).
      _inverted = r < Rational.fromNum(0.01);
      _rate.text = RateText.decimal(_inverted ? RateMath.inverse(r) : r, significant: 10);
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _nameAr, _nameEn, _symbol, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _codeError(L10n l) {
    if (!_isNew) return null;
    final code = CurrencyCodes.normalize(_code.text);
    if (code == null) return l.ledgerErrCode;
    if (widget.book.currency(code) != null) return l.ledgerErrCodeExists;
    return null;
  }

  Rational? get _rateValue {
    final v = RateMath.parse(_rate.text);
    return v == null ? null : RateMath.fromEntry(v, inverted: _inverted);
  }

  String? _rateError(L10n l) => _isBase || _rateValue != null ? null : l.ledgerErrRate;

  String? _nameError(L10n l) => _nameAr.text.trim().isEmpty && _nameEn.text.trim().isEmpty ? l.ledgerErrName : null;

  Future<void> _save() async {
    final l = L10n.of(context);
    if (_codeError(l) != null || _rateError(l) != null || _nameError(l) != null) {
      Fx.fire(Sfx.error);
      setState(() => _tried = true);
      return;
    }
    setState(() => _saving = true);
    final code = _isNew ? CurrencyCodes.normalize(_code.text)! : widget.currency!.code;
    final service = ref.read(ledgerServiceProvider);
    final undo = await service.saveCurrency(
      LedgerCurrency(code: code, nameAr: _nameAr.text, nameEn: _nameEn.text, symbol: _symbol.text, decimals: _decimals),
      rate: _isBase || (!_isNew && !_rateTouched) ? null : _rateValue,
    );
    Fx.fire(Sfx.complete);
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    Navigator.of(context).pop(true);
    unawaited(UndoToast.show(overlay, UndoableAction(label: l.ledgerCurrencySaved, undo: undo)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = ledgerFormatOf(context, widget.book);
    final base = widget.book.baseCode;
    final code = CurrencyCodes.normalize(_code.text) ?? (_isNew ? '…' : widget.currency!.code);
    final one = fmt.number(1000, decimals: 0);
    final rate = _rateValue;
    final preview = rate == null || _isBase
        ? null
        : l.ledgerRateLine(
            one,
            LedgerMoneyFormat.isolate(code),
            fmt.rate(rate),
            LedgerMoneyFormat.isolate(fmt.symbolOf(base)),
          );
    final previewInverse = rate == null || _isBase
        ? null
        : l.ledgerRateLine(
            one,
            LedgerMoneyFormat.isolate(fmt.symbolOf(base)),
            fmt.rate(RateMath.inverse(rate)),
            LedgerMoneyFormat.isolate(code),
          );

    Widget field(
      String label,
      TextEditingController c, {
      String? hint,
      String? error,
      bool enabled = true,
      IconData? icon,
      List<TextInputFormatter>? formatters,
      TextInputType? keyboard,
      TextCapitalization caps = TextCapitalization.none,
      bool optional = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.l),
        child: FieldShell(
          label: label,
          icon: icon,
          optional: optional,
          error: _tried ? error : null,
          child: TextField(
            controller: c,
            enabled: enabled,
            inputFormatters: formatters,
            keyboardType: keyboard,
            textCapitalization: caps,
            onChanged: (_) => setState(() {}),
            decoration: kitInputDecoration(context, hint: hint, error: _tried && error != null),
          ),
        ),
      );
    }

    return InteractionSheetFrame(
      title: _isNew ? l.ledgerNewCurrency : l.ledgerEditCurrency,
      subtitle: _isNew ? null : '${widget.currency!.code} · ${widget.currency!.name(arabic: fmt.arabic)}',
      icon: Icons.currency_exchange_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isNew)
            field(
              l.ledgerCode,
              _code,
              hint: l.ledgerCodeHint,
              error: _codeError(l),
              icon: Icons.tag_rounded,
              caps: TextCapitalization.characters,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          field(l.ledgerNameAr, _nameAr, error: _nameError(l), icon: Icons.translate_rounded),
          field(l.ledgerNameEn, _nameEn, icon: Icons.translate_rounded, optional: true),
          field(l.ledgerSymbol, _symbol, hint: code, icon: Icons.short_text_rounded, optional: true),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.l),
            child: FieldShell(
              label: l.ledgerDecimals,
              icon: Icons.pin_rounded,
              child: LedgerSegmented<int>(
                values: const [0, 2, 3],
                value: _decimals,
                labels: {
                  for (final d in const [0, 2, 3]) d: fmt.number(0, decimals: d),
                },
                onChanged: (d) => setState(() => _decimals = d),
              ),
            ),
          ),
          if (!_isBase) ...[
            FieldShell(
              label: l.ledgerRate,
              icon: Icons.swap_vert_rounded,
              error: _tried ? _rateError(l) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LedgerSegmented<bool>(
                    values: const [false, true],
                    value: _inverted,
                    height: 40,
                    labels: {
                      false: l.ledgerRateLine(
                        one,
                        LedgerMoneyFormat.isolate(code),
                        '…',
                        LedgerMoneyFormat.isolate(base),
                      ),
                      true: l.ledgerRateLine(
                        one,
                        LedgerMoneyFormat.isolate(base),
                        '…',
                        LedgerMoneyFormat.isolate(code),
                      ),
                    },
                    onChanged: (inv) {
                      final current = _rateValue;
                      setState(() {
                        _inverted = inv;
                        if (current != null) {
                          _rate.text = RateText.decimal(inv ? RateMath.inverse(current) : current, significant: 10);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: Space.s),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [kitNumberFormatter],
                    onChanged: (_) => setState(() => _rateTouched = true),
                    decoration: kitInputDecoration(
                      context,
                      hint: l.ledgerRateHint,
                      error: _tried && _rateError(l) != null,
                      suffix: _inverted ? code : base,
                    ),
                  ),
                  if (preview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s),
                      child: Text(
                        '$preview   ·   $previewInverse',
                        textAlign: TextAlign.center,
                        style: LedgerStyle.amount(t, size: 12, color: t.textTertiary, weight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ] else
            Text(l.ledgerBaseHint, style: text.bodySmall?.copyWith(color: t.textTertiary)),
          const SizedBox(height: Space.s),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: SheetButton(
          label: l.actionSave,
          icon: Icons.check_rounded,
          primary: true,
          sfx: null,
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}
