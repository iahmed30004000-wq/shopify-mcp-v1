import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../domain/field_values.dart';
import '../domain/module_builder_rules.dart';
import '../domain/module_schema.dart';
import 'widgets/module_visuals.dart';

/// Picks the type of a new field: a grid of the nine types with what each is
/// good for. Resolves with the type (null when dismissed).
Future<FieldType?> showFieldTypePicker(BuildContext context) => showInteractionSheet<FieldType>(
  context,
  builder: (ctx) {
    final tx = CustomTexts.of(ctx);
    return InteractionSheetFrame(
      title: tx.l.cmodPickType,
      icon: Icons.add_box_outlined,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - Space.s) / 2;
          return Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final type in FieldType.values)
                SizedBox(
                  width: w,
                  child: _TypeCard(type: type, onTap: () => Navigator.of(ctx).pop(type)),
                ),
            ],
          );
        },
      ),
    );
  },
);

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.onTap});

  final FieldType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () {
        Fx.fire(Sfx.tap);
        onTap();
      },
      semanticLabel: '${tx.fieldType(type)}. ${tx.fieldTypeHint(type)}',
      borderRadius: BorderRadius.circular(t.radiusM),
      padding: const EdgeInsets.all(Space.m),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(t.radiusS)),
            child: Icon(ModuleIcons.field(type), color: t.accent, size: 20),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.fieldType(type), style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  tx.fieldTypeHint(type),
                  style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What [FieldEditorSheet] resolves with.
class FieldEditResult {
  const FieldEditResult.saved(ModuleField this.field) : deleted = false;
  const FieldEditResult.deleted() : field = null, deleted = true;

  final ModuleField? field;
  final bool deleted;
}

/// Opens the editor of [field]: its name, type and every per-type setting
/// (unit, min / max, decimals, scale, currency, options, long text) and the
/// required flag. [isNew] hides Delete.
Future<FieldEditResult?> showFieldEditorSheet(
  BuildContext context, {
  required ModuleField field,
  bool isNew = false,
  Set<String> otherLabels = const {},
}) => showInteractionSheet<FieldEditResult>(
  context,
  builder: (_) => FieldEditorSheet(field: field, isNew: isNew, otherLabels: otherLabels),
);

class FieldEditorSheet extends StatefulWidget {
  const FieldEditorSheet({super.key, required this.field, this.isNew = false, this.otherLabels = const {}});

  final ModuleField field;
  final bool isNew;

  /// Labels of the module's other fields (lower-case), to refuse duplicates.
  final Set<String> otherLabels;

  @override
  State<FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _OptionDraft {
  _OptionDraft(this.id, String label) : controller = TextEditingController(text: label);
  final String id;
  final TextEditingController controller;
}

class _FieldEditorSheetState extends State<FieldEditorSheet> {
  late final TextEditingController _label = TextEditingController(text: widget.field.label);
  late final TextEditingController _unit = TextEditingController(text: widget.field.unit ?? '');
  TextEditingController? _min;
  TextEditingController? _max;
  late FieldType _type = widget.field.type;
  late bool _required = widget.field.required;
  late bool _multiline = widget.field.multiline;
  late int _decimals = widget.field.decimals;
  late int _scale = widget.field.ratingMax;
  late String _currency = widget.field.currencyCode;
  late final List<_OptionDraft> _options = [
    for (final o in widget.field.visibleOptions) _OptionDraft(o.id, o.label),
  ];
  bool _tried = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final tx = CustomTexts.of(context);
    _min = TextEditingController(text: widget.field.min == null ? '' : tx.editableNumber(widget.field.min!));
    _max = TextEditingController(text: widget.field.max == null || widget.field.type == FieldType.rating ? '' : tx.editableNumber(widget.field.max!));
  }

  @override
  void dispose() {
    _label.dispose();
    _unit.dispose();
    _min?.dispose();
    _max?.dispose();
    for (final o in _options) {
      o.controller.dispose();
    }
    super.dispose();
  }

  ModuleField _build() {
    final f = widget.field;
    final hiddenOptions = [
      for (final o in f.options)
        if (o.hidden) o,
    ];
    final bounded = _type == FieldType.number || _type == FieldType.currency;
    final min = bounded ? FieldValues.number(_min!.text) : null;
    final max = switch (_type) {
      FieldType.rating => _scale,
      FieldType.number || FieldType.currency => FieldValues.number(_max!.text),
      _ => null,
    };
    return ModuleField(
      id: f.id,
      label: _label.text.trim(),
      type: _type,
      unit: _type == FieldType.number && _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
      required: _type == FieldType.checkbox ? false : _required,
      options: _type == FieldType.singleSelect || _type == FieldType.multiSelect
          ? [
              for (final o in _options) FieldOption(id: o.id, label: o.controller.text.trim()),
              ...hiddenOptions,
            ]
          : (f.isSelect ? f.options : const []),
      min: min,
      max: max,
      decimals: _type == FieldType.number ? _decimals : 0,
      currency: _type == FieldType.currency ? _currency : null,
      multiline: _type == FieldType.text && _multiline,
      hidden: f.hidden,
      extra: f.extra,
    );
  }

  List<String> _problems(CustomTexts tx) {
    final f = _build();
    final out = <String>[];
    if (f.label.isEmpty) out.add(tx.l.cmodIssueLabelMissing);
    if (f.label.isNotEmpty && widget.otherLabels.contains(f.label.toLowerCase())) out.add(tx.l.cmodIssueLabelDuplicate);
    for (final p in ModuleBuilderRules.checkField(f)) {
      out.add(tx.issue(p.issue));
    }
    return out;
  }

  void _save() {
    final tx = CustomTexts.of(context);
    if (_problems(tx).isNotEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _tried = true);
      return;
    }
    Fx.fire(Sfx.complete);
    Navigator.of(context).pop(FieldEditResult.saved(_build()));
  }

  void _addOption() {
    Fx.fire(Sfx.tap);
    final taken = [
      ..._options.map((o) => o.id),
      ...widget.field.options.map((o) => o.id),
    ];
    setState(() => _options.add(_OptionDraft(ModuleIds.nextOptionId(taken), '')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final problems = _tried ? _problems(tx) : const <String>[];
    final typeChanged = !widget.isNew && _type != widget.field.type;
    return InteractionSheetFrame(
      title: widget.isNew ? l.cmodFieldNew : l.cmodFieldEdit,
      subtitle: tx.fieldType(_type),
      icon: ModuleIcons.field(_type),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.cmodFieldLabel,
            icon: Icons.label_outline_rounded,
            error: problems.isEmpty ? null : problems.first,
            child: TextField(
              controller: _label,
              autofocus: widget.isNew,
              maxLength: ModuleBuilderRules.maxLabelLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: kitInputDecoration(context, hint: l.cmodFieldLabelHint, error: problems.isNotEmpty),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Space.m),
          FieldShell(
            label: l.cmodPickType,
            icon: Icons.category_outlined,
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final type in FieldType.values)
                  KitChip(
                    label: tx.fieldType(type),
                    icon: ModuleIcons.field(type),
                    selected: _type == type,
                    dense: true,
                    onTap: () => setState(() {
                      _type = type;
                      if (type == FieldType.rating && (_scale < 2 || _scale > 10)) _scale = 5;
                    }),
                  ),
              ],
            ),
          ),
          if (typeChanged) ...[
            const SizedBox(height: Space.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: t.warning),
                const SizedBox(width: Space.s),
                Expanded(child: Text(l.cmodFieldTypeNote, style: text.bodySmall!.copyWith(color: t.textSecondary))),
              ],
            ),
          ],
          const SizedBox(height: Space.m),
          ..._settings(tx),
          if (_type != FieldType.checkbox) ...[
            const SizedBox(height: Space.s),
            _ToggleRow(
              label: l.cmodFieldRequired,
              hint: l.cmodFieldRequiredHint,
              icon: Icons.priority_high_rounded,
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          if (!widget.isNew) ...[
            SheetButton(
              label: l.cmodFieldDelete,
              icon: Icons.delete_outline_rounded,
              tone: t.danger,
              sfx: Sfx.delete,
              onPressed: () => Navigator.of(context).pop(const FieldEditResult.deleted()),
            ),
            const SizedBox(width: Space.s),
          ] else ...[
            Expanded(
              child: SheetButton(label: l.cmodCancel, sfx: Sfx.sheetClose, onPressed: () => Navigator.of(context).maybePop()),
            ),
            const SizedBox(width: Space.m),
          ],
          Expanded(
            flex: 2,
            child: SheetButton(
              label: l.cmodSave,
              icon: Icons.check_rounded,
              primary: true,
              sfx: null,
              enabled: _problems(tx).isEmpty,
              onDisabledTap: _save,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _settings(CustomTexts tx) {
    final l = tx.l;
    final t = context.tokens;
    switch (_type) {
      case FieldType.text:
        return [
          _ToggleRow(
            label: l.cmodFieldMultiline,
            hint: l.cmodFieldMultilineHint,
            icon: Icons.notes_rounded,
            value: _multiline,
            onChanged: (v) => setState(() => _multiline = v),
          ),
        ];
      case FieldType.number:
        return [
          FieldShell(
            label: l.cmodFieldUnit,
            icon: Icons.straighten_rounded,
            optional: true,
            child: TextField(
              controller: _unit,
              maxLength: 16,
              decoration: kitInputDecoration(context, hint: l.cmodFieldUnitHint),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Space.m),
          _bounds(tx),
          const SizedBox(height: Space.m),
          FieldShell(
            label: l.cmodFieldDecimals,
            icon: Icons.more_horiz_rounded,
            child: Wrap(
              spacing: Space.s,
              children: [
                for (final d in const [0, 1, 2, 3])
                  KitChip(
                    label: tx.count(d),
                    selected: _decimals == d,
                    dense: true,
                    onTap: () => setState(() => _decimals = d),
                  ),
              ],
            ),
          ),
        ];
      case FieldType.currency:
        final codes = {...kMadarCurrencies, _currency};
        return [
          FieldShell(
            label: l.cmodFieldCurrency,
            icon: Icons.currency_exchange_rounded,
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final c in codes)
                  KitChip(label: c, selected: _currency == c, dense: true, onTap: () => setState(() => _currency = c)),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          _bounds(tx),
        ];
      case FieldType.rating:
        return [
          FieldShell(
            label: l.cmodFieldScale,
            icon: Icons.star_outline_rounded,
            child: Wrap(
              spacing: Space.s,
              children: [
                for (final s in const [3, 5, 7, 10])
                  KitChip(
                    label: tx.stars(s),
                    selected: _scale == s,
                    dense: true,
                    onTap: () => setState(() => _scale = s),
                  ),
              ],
            ),
          ),
        ];
      case FieldType.singleSelect || FieldType.multiSelect:
        return [
          FieldShell(
            label: l.cmodFieldOptions,
            icon: Icons.list_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    key: ObjectKey(_options[i]),
                    padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                    child: Row(
                      children: [
                        Icon(
                          _type == FieldType.singleSelect ? Icons.radio_button_unchecked_rounded : Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: t.textTertiary,
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: TextField(
                            controller: _options[i].controller,
                            autofocus: _options[i].controller.text.isEmpty && i == _options.length - 1,
                            maxLength: ModuleBuilderRules.maxLabelLength,
                            textInputAction: TextInputAction.next,
                            decoration: kitInputDecoration(context, hint: l.cmodOptionHint),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _addOption(),
                          ),
                        ),
                        IconButton(
                          tooltip: l.cmodRemoveOption,
                          icon: Icon(Icons.remove_circle_outline_rounded, color: t.textTertiary),
                          onPressed: () {
                            Fx.fire(Sfx.delete);
                            setState(() => _options.removeAt(i).controller.dispose());
                          },
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MadarButton(
                    label: l.cmodAddOption,
                    icon: Icons.add_rounded,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    onPressed: _addOption,
                    sfx: Sfx.tap,
                  ),
                ),
              ],
            ),
          ),
        ];
      case FieldType.date || FieldType.time || FieldType.checkbox:
        return const [];
    }
  }

  Widget _bounds(CustomTexts tx) {
    final l = tx.l;
    Widget box(String label, TextEditingController c) => Expanded(
      child: FieldShell(
        label: label,
        optional: true,
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [kitNumberFormatter],
          decoration: kitInputDecoration(context, hint: l.cmodFieldNoLimit),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [box(l.cmodFieldMin, _min!), const SizedBox(width: Space.m), box(l.cmodFieldMax, _max!)],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.hint, required this.icon, required this.value, required this.onChanged});

  final String label;
  final String hint;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: t.textSecondary),
        const SizedBox(width: Space.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              Text(hint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
            ],
          ),
        ),
        GlassSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }
}
