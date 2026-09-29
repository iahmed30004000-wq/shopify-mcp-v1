import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/amount_entry.dart';
import '../ledger_ui.dart';

/// The amount keypad: 1–9, the decimal point, 0 and backspace (long-press
/// clears). Laid out like every phone keypad – 1 at the top-left – in both
/// directions; digits follow the user's digit style.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey, this.decimalEnabled = true, this.keyHeight = 50});

  final ValueChanged<KeypadKey> onKey;
  final bool decimalEnabled;
  final double keyHeight;

  static const _rows = [
    [KeypadKey.d1, KeypadKey.d2, KeypadKey.d3],
    [KeypadKey.d4, KeypadKey.d5, KeypadKey.d6],
    [KeypadKey.d7, KeypadKey.d8, KeypadKey.d9],
    [KeypadKey.decimal, KeypadKey.d0, KeypadKey.backspace],
  ];

  @override
  Widget build(BuildContext context) {
    final fmt = MadarFormatter.of(context);
    final l = L10n.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs + 2),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.xs + 2),
                    Expanded(
                      child: _Key(
                        keyValue: row[i],
                        height: keyHeight,
                        enabled: row[i] != KeypadKey.decimal || decimalEnabled,
                        label: switch (row[i]) {
                          KeypadKey.decimal => fmt.arabicIndic ? Digits.arabicDecimal : '.',
                          KeypadKey.backspace => null,
                          final k => fmt.localizeDigits('${k.digit}'),
                        },
                        semanticLabel: switch (row[i]) {
                          KeypadKey.decimal => l.ledgerKeyDecimal,
                          KeypadKey.backspace => l.ledgerKeyBackspace,
                          final k => fmt.localizeDigits('${k.digit}'),
                        },
                        onKey: onKey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.keyValue,
    required this.height,
    required this.enabled,
    required this.label,
    required this.semanticLabel,
    required this.onKey,
  });

  final KeypadKey keyValue;
  final double height;
  final bool enabled;
  final String? label;
  final String semanticLabel;
  final ValueChanged<KeypadKey> onKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isBack = keyValue == KeypadKey.backspace;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: SpringPress(
        enabled: enabled,
        sfx: Sfx.tap,
        pressScale: 0.92,
        semanticLabel: semanticLabel,
        onTap: () => onKey(keyValue),
        onLongPress: isBack ? () => onKey(KeypadKey.clear) : null,
        longPressSfx: Sfx.delete,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: t.glassBorder, width: 0.8),
          ),
          child: label == null
              ? Icon(Icons.backspace_outlined, size: 21, color: t.textSecondary)
              : Text(
                  label!,
                  style: LedgerStyle.amount(t, size: 22, color: t.textPrimary, weight: FontWeight.w500),
                ),
        ),
      ),
    );
  }
}
