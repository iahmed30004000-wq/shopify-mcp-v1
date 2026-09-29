import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show FieldShell, kitInputDecoration, kitNumberFormatter;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import 'budget_format.dart';

/// Opens the weeks-per-month sheet (presets 4 and 4.345, or any number
/// from [BudgetWeeksSheet.min] to [BudgetWeeksSheet.max]) with a live
/// conversion example. Returns the chosen value, or null when dismissed.
Future<num?> showBudgetWeeksSheet(BuildContext context, {required num current, required BudgetFormat format}) {
  return showInteractionSheet<num>(
    context,
    builder: (_) => BudgetWeeksSheet(
      current: current,
      format: format,
      onDone: (v) => Navigator.of(context, rootNavigator: true).pop(v),
    ),
  );
}

class BudgetWeeksSheet extends StatefulWidget {
  const BudgetWeeksSheet({super.key, required this.current, required this.format, required this.onDone});

  static const num min = 1;
  static const num max = 6;
  static const presets = <num>[4, 4.345];

  final num current;
  final BudgetFormat format;
  final ValueChanged<num> onDone;

  /// A valid weeks-per-month from [text] (any digits), or null.
  static num? parse(String text) {
    final v = MoneyText.parseNumber(text);
    if (v == null || v < min || v > max) return null;
    return v == v.roundToDouble() ? v.round() : v;
  }

  @override
  State<BudgetWeeksSheet> createState() => _BudgetWeeksSheetState();
}

class _BudgetWeeksSheetState extends State<BudgetWeeksSheet> {
  late num _value = widget.current;
  late final TextEditingController _custom = TextEditingController(
    text: BudgetWeeksSheet.presets.contains(widget.current) ? '' : widget.format.weeks(widget.current),
  );
  String? _error;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _choose(num v) {
    Fx.fire(Sfx.tap);
    setState(() {
      _value = v;
      _error = null;
      _custom.text = '';
    });
  }

  void _onCustom(String text) {
    final l = L10n.of(context);
    final f = widget.format;
    final v = BudgetWeeksSheet.parse(text);
    setState(() {
      if (text.trim().isEmpty) {
        _error = null;
      } else if (v == null) {
        _error = l.budgetWeeksInvalid(f.weeks(BudgetWeeksSheet.min), f.weeks(BudgetWeeksSheet.max));
      } else {
        _error = null;
        _value = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final f = widget.format;
    const weekly = 5000;
    final monthly = BudgetMath.weeklyToMonthly(weekly, _value);
    return InteractionSheetFrame(
      title: l.budgetWeeksTitle,
      subtitle: l.budgetWeeksSubtitle,
      icon: Icons.date_range_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, p) in BudgetWeeksSheet.presets.indexed) ...[
                if (i > 0) const SizedBox(width: Space.m),
                Expanded(
                  child: _PresetCard(
                    value: f.weeks(p),
                    label: p == 4 ? l.budgetWeeksRound : l.budgetWeeksCalendar,
                    selected: _value == p && _custom.text.trim().isEmpty,
                    onTap: () => _choose(p),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.budgetWeeksCustom,
            icon: Icons.edit_outlined,
            error: _error,
            child: TextField(
              controller: _custom,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [kitNumberFormatter],
              onChanged: _onCustom,
              decoration: kitInputDecoration(context, hint: f.weeks(4.33), error: _error != null),
            ),
          ),
          const SizedBox(height: Space.l),
          Semantics(
            liveRegion: true,
            child: Text(
              l.budgetWeeksExample(f.money(weekly), f.money(monthly)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.gold),
            ),
          ),
        ],
      ),
      footer: SheetButton(
        label: l.actionSave,
        icon: Icons.check_rounded,
        primary: true,
        enabled: _error == null && _value != widget.current,
        sfx: Sfx.complete,
        onPressed: () => widget.onDone(_value),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.value, required this.label, required this.selected, required this.onTap});

  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      selected: selected,
      semanticLabel: '$value, $label',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusL),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        padding: const EdgeInsets.symmetric(vertical: Space.l, horizontal: Space.m),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusL),
          color: selected ? t.accent.withValues(alpha: t.isDark ? 0.16 : 0.12) : t.glassFill,
          border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.4 : 1),
          boxShadow: selected && t.isDark
              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.3), blurRadius: 16)]
              : null,
        ),
        child: Column(
          children: [
            Text(value, style: text.headlineSmall?.copyWith(color: selected ? t.gold : t.textPrimary)),
            const SizedBox(height: Space.xs),
            Text(label, textAlign: TextAlign.center, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
