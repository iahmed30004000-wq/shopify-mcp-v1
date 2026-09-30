import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../domain/field_values.dart';
import '../domain/module_schema.dart';
import 'widgets/module_visuals.dart';

/// What [EntrySheet] resolves with: validated values ready to store.
class EntrySheetResult {
  const EntrySheetResult({required this.values, required this.at, required this.done});

  /// Field id → stored value (hidden / unknown values of an edited entry
  /// carried over).
  final Map<String, Object?> values;

  /// When the entry happened (trackers; lists keep their creation time).
  final DateTime at;

  /// A list item's state.
  final bool done;
}

/// Opens the entry form of [module] – new, or editing [entry] – and
/// resolves with the validated values (null when dismissed). Persisting is
/// the caller's job (see `CustomModulesActions`).
Future<EntrySheetResult?> showEntrySheet(
  BuildContext context, {
  required ModuleDefinition module,
  ModuleEntry? entry,
  DateTime? now,
}) => showInteractionSheet<EntrySheetResult>(
  context,
  builder: (_) => EntrySheet(module: module, entry: entry, now: now),
);

/// The entry form, generated from the module's visible fields: validation
/// per type (inline, after a field is touched or Save is tried), sensible
/// keyboards, numbers shown in the user's digits (Arabic-Indic in Arabic)
/// and read from any digit script.
class EntrySheet extends StatefulWidget {
  const EntrySheet({super.key, required this.module, this.entry, this.now});

  final ModuleDefinition module;
  final ModuleEntry? entry;

  /// "Now" for a new entry's time (tests); defaults to the wall clock.
  final DateTime? now;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, Object?> _inputs = {};
  final Set<String> _touched = {};
  late DateTime _at;
  late bool _done;
  String? _expanded;
  bool _triedSave = false;
  bool _dirty = false;
  bool _initialised = false;

  ModuleDefinition get _m => widget.module;
  List<ModuleField> get _fields => _m.visibleFields;

  static bool _typed(FieldType t) => t == FieldType.text || t == FieldType.number || t == FieldType.currency;

  @override
  void initState() {
    super.initState();
    _at = widget.entry?.at ?? widget.now ?? DateTime.now();
    _done = widget.entry?.done ?? false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final tx = CustomTexts.of(context);
    final values = widget.entry?.values ?? const {};
    for (final f in _fields) {
      final v = values[f.id];
      switch (f.type) {
        case FieldType.text:
          _inputs[f.id] = FieldValues.text(v) ?? '';
        case FieldType.number:
          final n = FieldValues.number(v);
          _inputs[f.id] = n == null ? '' : tx.editableNumber(n);
        case FieldType.currency:
          final m = FieldValues.money(v, fallbackCurrency: f.currencyCode);
          _inputs[f.id] = m == null ? '' : tx.editableAmount(m);
        case FieldType.date:
          _inputs[f.id] = FieldValues.date(v);
        case FieldType.time:
          _inputs[f.id] = FieldValues.time(v);
        case FieldType.checkbox:
          _inputs[f.id] = FieldValues.checkbox(v) ?? false;
        case FieldType.singleSelect:
          _inputs[f.id] = FieldValues.single(v);
        case FieldType.multiSelect:
          _inputs[f.id] = FieldValues.multi(v);
        case FieldType.rating:
          _inputs[f.id] = FieldValues.rating(v);
      }
      if (_typed(f.type)) {
        _controllers[f.id] = TextEditingController(text: _inputs[f.id] as String);
        _focus[f.id] = FocusNode()
          ..addListener(() {
            if (!_focus[f.id]!.hasFocus && mounted) setState(() => _touched.add(f.id));
          });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  EntryCheck get _check => EntryValidator.checkAll(_m.fields, _inputs, keep: widget.entry?.values ?? const {});

  void _set(String id, Object? value) {
    setState(() {
      _inputs[id] = value;
      _touched.add(id);
      _dirty = true;
    });
  }

  void _toggle(String key) {
    FocusScope.of(context).unfocus();
    Fx.fire(Sfx.tap);
    setState(() => _expanded = _expanded == key ? null : key);
  }

  void _save() {
    final check = _check;
    if (!check.ok) {
      Fx.fire(Sfx.error);
      setState(() => _triedSave = true);
      return;
    }
    Fx.fire(Sfx.complete);
    Navigator.of(context).pop(EntrySheetResult(values: check.values, at: _at, done: _done));
  }

  Future<void> _maybeDiscard() async {
    final tx = CustomTexts.of(context);
    final nav = Navigator.of(context);
    final discard = await showInteractionSheet<bool>(
      context,
      builder: (ctx) => InteractionSheetFrame(
        title: tx.l.cmodDiscardTitle,
        icon: Icons.edit_off_rounded,
        body: Text(tx.l.cmodDiscardBody, style: Theme.of(ctx).textTheme.bodyMedium),
        footer: Row(
          children: [
            Expanded(child: SheetButton(label: tx.l.cmodKeepEditing, onPressed: () => Navigator.of(ctx).pop(false))),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: tx.l.cmodDiscard,
                primary: true,
                tone: ctx.tokens.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final check = _check;
    final isNew = widget.entry == null;
    final title = _m.isTracker
        ? (isNew ? l.cmodEntryNew : l.cmodEntryEdit)
        : (isNew ? l.cmodItemNew : l.cmodItemEdit);
    final textKeys = [
      for (final f in _fields)
        if (_typed(f.type)) f.id,
    ];
    final colors = ModuleColors.of(_m.colorArgb, t);

    String? errorOf(ModuleField f) {
      final issue = check.issues[f.id];
      if (issue == null) return null;
      if (!_triedSave && !_touched.contains(f.id)) return null;
      return tx.entryIssue(f, issue);
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_maybeDiscard());
      },
      child: InteractionSheetFrame(
        title: title,
        subtitle: tx.name(_m.name),
        icon: ModuleIcons.module(_m.iconKey),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_m.isTracker) ...[_whenField(tx), const SizedBox(height: Space.m)],
            if (_fields.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: colors.ink, size: 20),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(l.cmodEntryCounter, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary)),
                    ),
                  ],
                ),
              ),
            for (final f in _fields) ...[
              FieldShell(
                label: f.label,
                icon: ModuleIcons.field(f.type),
                optional: !f.isRequired && f.type != FieldType.checkbox,
                error: errorOf(f),
                child: _input(f, tx, textKeys, errorOf(f) != null),
              ),
              const SizedBox(height: Space.m),
            ],
            if (_m.isList && !isNew)
              _SwitchRow(
                label: l.cmodEntryDone,
                icon: Icons.task_alt_rounded,
                value: _done,
                onChanged: (v) => setState(() {
                  _done = v;
                  _dirty = true;
                }),
              ),
          ],
        ),
        footer: Row(
          children: [
            Expanded(
              child: SheetButton(
                label: l.cmodCancel,
                sfx: Sfx.sheetClose,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              flex: 2,
              child: SheetButton(
                label: l.cmodSave,
                primary: true,
                icon: Icons.check_rounded,
                enabled: check.ok,
                sfx: null,
                onDisabledTap: _save,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- inputs --

  Widget _whenField(CustomTexts tx) {
    final l = tx.l;
    final now = widget.now ?? DateTime.now();
    return FieldShell(
      label: l.cmodEntryWhen,
      icon: Icons.history_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PickerButton(
                  icon: Icons.event_rounded,
                  text: tx.dayLabel(_at, now),
                  active: _expanded == '@date',
                  onTap: () => _toggle('@date'),
                  semanticLabel: '${l.cmodEntryWhen}: ${tx.date(_at)}',
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                flex: 2,
                child: PickerButton(
                  icon: Icons.schedule_rounded,
                  text: tx.clock(_at),
                  active: _expanded == '@time',
                  onTap: () => _toggle('@time'),
                ),
              ),
            ],
          ),
          _Expand(
            open: _expanded == '@date',
            child: InlineDatePicker(
              value: DateTime(_at.year, _at.month, _at.day),
              allowClear: false,
              lastDate: DateTime(now.year + 1, now.month, now.day),
              now: now,
              onChanged: (d) {
                if (d == null) return;
                setState(() {
                  _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute);
                  _dirty = true;
                });
              },
            ),
          ),
          _Expand(
            open: _expanded == '@time',
            child: TimeWheel(
              value: FieldValues.encodeTime(_at.hour, _at.minute),
              onChanged: (v) {
                final m = FieldValues.minutesOf(v);
                if (m == null) return;
                setState(() {
                  _at = DateTime(_at.year, _at.month, _at.day, m ~/ 60, m % 60);
                  _dirty = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(ModuleField f, CustomTexts tx, List<String> textKeys, bool error) {
    final t = context.tokens;
    final l = tx.l;
    switch (f.type) {
      case FieldType.text:
        return TextField(
          controller: _controllers[f.id],
          focusNode: _focus[f.id],
          autofocus: textKeys.isNotEmpty && textKeys.first == f.id && widget.entry == null,
          keyboardType: f.multiline ? TextInputType.multiline : TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          minLines: f.multiline ? 3 : 1,
          maxLines: f.multiline ? 6 : 1,
          maxLength: EntryValidator.maxTextLength,
          textInputAction: f.multiline ? TextInputAction.newline : _action(f.id, textKeys),
          decoration: kitInputDecoration(context, error: error),
          onChanged: (v) => _set(f.id, v),
          onSubmitted: (_) => _next(f.id, textKeys),
        );
      case FieldType.number:
        final whole = f.decimals == 0;
        return TextField(
          controller: _controllers[f.id],
          focusNode: _focus[f.id],
          autofocus: textKeys.isNotEmpty && textKeys.first == f.id && widget.entry == null,
          keyboardType: TextInputType.numberWithOptions(decimal: !whole, signed: f.min == null || f.min! < 0),
          inputFormatters: [kitNumberFormatter],
          textInputAction: _action(f.id, textKeys),
          style: MadarTypography.numerals(t, size: 17),
          decoration: kitInputDecoration(
            context,
            error: error,
            suffix: f.unit,
            suffixIcon: whole ? _Stepper(onStep: (d) => _step(f, d, tx)) : null,
          ),
          onChanged: (v) => _set(f.id, v),
          onSubmitted: (_) => _next(f.id, textKeys),
        );
      case FieldType.currency:
        final arabic = tx.arabic;
        return TextField(
          controller: _controllers[f.id],
          focusNode: _focus[f.id],
          autofocus: textKeys.isNotEmpty && textKeys.first == f.id && widget.entry == null,
          keyboardType: TextInputType.numberWithOptions(
            decimal: CurrencyCatalog.decimalsFor(f.currencyCode) > 0,
            signed: f.min != null && f.min! < 0,
          ),
          inputFormatters: [kitNumberFormatter],
          textInputAction: _action(f.id, textKeys),
          style: MadarTypography.numerals(t, size: 18),
          decoration: kitInputDecoration(
            context,
            error: error,
            suffix: CurrencyCatalog.symbolFor(f.currencyCode, arabic: arabic),
          ),
          onChanged: (v) => _set(f.id, v),
          onSubmitted: (_) => _next(f.id, textKeys),
        );
      case FieldType.date:
        final d = _inputs[f.id] as DateTime?;
        final now = widget.now ?? DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerButton(
              icon: Icons.event_rounded,
              text: d == null ? l.cmodPickDate : tx.date(d),
              placeholder: d == null,
              active: _expanded == f.id,
              error: error,
              onTap: () => _toggle(f.id),
            ),
            _Expand(
              open: _expanded == f.id,
              child: InlineDatePicker(value: d, now: now, onChanged: (v) => _set(f.id, v)),
            ),
          ],
        );
      case FieldType.time:
        final v = _inputs[f.id] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: PickerButton(
                    icon: Icons.schedule_rounded,
                    text: v == null ? l.cmodPickTime : tx.time(v),
                    placeholder: v == null,
                    active: _expanded == f.id,
                    error: error,
                    onTap: () {
                      if (v == null) _set(f.id, FieldValues.encodeTime(_at.hour, _at.minute));
                      _toggle(f.id);
                    },
                  ),
                ),
                if (v != null && !f.isRequired) ...[
                  const SizedBox(width: Space.xs),
                  IconButton(
                    tooltip: l.cmodClear,
                    icon: Icon(Icons.close_rounded, color: t.textTertiary, size: 20),
                    onPressed: () {
                      Fx.fire(Sfx.tap);
                      setState(() {
                        _inputs[f.id] = null;
                        _expanded = null;
                        _dirty = true;
                      });
                    },
                  ),
                ],
              ],
            ),
            _Expand(
              open: _expanded == f.id && v != null,
              child: TimeWheel(value: v ?? '00:00', onChanged: (x) => _set(f.id, x)),
            ),
          ],
        );
      case FieldType.checkbox:
        final v = _inputs[f.id] as bool? ?? false;
        return _CheckTile(
          value: v,
          color: ModuleColors.of(_m.colorArgb, t),
          label: v ? l.cmodChecked : l.cmodUnchecked,
          semanticLabel: f.label,
          onChanged: (x) => _set(f.id, x),
        );
      case FieldType.singleSelect:
        final v = _inputs[f.id] as String?;
        final hiddenSelected = v != null && (f.option(v)?.hidden ?? false);
        return Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final o in f.options)
              if (!o.hidden || (hiddenSelected && o.id == v))
                KitChip(
                  label: o.label,
                  selected: v == o.id,
                  onTap: () => _set(f.id, v == o.id && !f.isRequired ? null : o.id),
                ),
          ],
        );
      case FieldType.multiSelect:
        final v = (_inputs[f.id] as List?)?.cast<String>() ?? const <String>[];
        return Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final o in f.options)
              if (!o.hidden || v.contains(o.id))
                KitChip(
                  label: o.label,
                  selected: v.contains(o.id),
                  showCheck: true,
                  onTap: () => _set(f.id, v.contains(o.id) ? [...v]..remove(o.id) : [...v, o.id]),
                ),
          ],
        );
      case FieldType.rating:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: StarRating(
            value: _inputs[f.id] as int?,
            max: f.ratingMax,
            allowClear: !f.isRequired,
            semanticLabel: f.label,
            onChanged: (v) => _set(f.id, v),
          ),
        );
    }
  }

  void _step(ModuleField f, int delta, CustomTexts tx) {
    final current = FieldValues.number(_controllers[f.id]!.text) ?? (delta > 0 ? (f.min ?? 0) - 1 : (f.min ?? 0) + 1);
    var next = current.round() + delta;
    if (f.min != null && next < f.min!) next = f.min!.ceil();
    if (f.max != null && next > f.max!) next = f.max!.floor();
    final text = tx.editableNumber(next);
    _controllers[f.id]!.text = text;
    _set(f.id, text);
  }

  TextInputAction _action(String id, List<String> keys) =>
      keys.isNotEmpty && keys.last == id ? TextInputAction.done : TextInputAction.next;

  void _next(String id, List<String> keys) {
    final i = keys.indexOf(id);
    if (i >= 0 && i < keys.length - 1) {
      _focus[keys[i + 1]]?.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      if (_check.ok) _save();
    }
  }
}

/// Animated open / close of an inline picker.
class _Expand extends StatelessWidget {
  const _Expand({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.emphasized,
      alignment: Alignment.topCenter,
      child: open
          ? Padding(padding: const EdgeInsetsDirectional.only(top: Space.s), child: child)
          : const SizedBox(width: double.infinity),
    );
  }
}

/// − / + for whole numbers.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.onStep});

  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = CustomTexts.of(context).fmt;
    Widget b(IconData icon, int d, String label) => Semantics(
      button: true,
      label: label,
      child: InkResponse(
        radius: 20,
        onTap: () {
          Fx.fire(Sfx.countTick);
          onStep(d);
        },
        child: Padding(
          padding: const EdgeInsets.all(Space.s),
          child: Icon(icon, size: 20, color: t.accent),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        b(Icons.remove_rounded, -1, fmt.localizeDigits('−1')),
        b(Icons.add_rounded, 1, fmt.localizeDigits('+1')),
        const SizedBox(width: Space.xs),
      ],
    );
  }
}

/// A big tappable "done / not done" tile for checkbox fields.
class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.value,
    required this.color,
    required this.label,
    required this.semanticLabel,
    required this.onChanged,
  });

  final bool value;
  final ModuleColors color;
  final String label;
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      button: true,
      child: SpringPress(
        sfx: value ? Sfx.toggleOff : Sfx.toggleOn,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.m),
          decoration: BoxDecoration(
            color: value ? color.soft : t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: value ? color.base.withValues(alpha: 0.7) : t.glassBorder),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: context.motion(MadarMotion.short),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? color.base : Colors.transparent,
                  border: Border.all(color: value ? color.base : t.textTertiary, width: 1.6),
                  boxShadow: value ? [BoxShadow(color: color.glow, blurRadius: 10)] : null,
                ),
                child: value ? Icon(Icons.check_rounded, size: 18, color: color.onBase) : null,
              ),
              const SizedBox(width: Space.m),
              Text(label, style: text.titleSmall!.copyWith(color: value ? color.ink : t.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.icon, required this.value, required this.onChanged});

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 20, color: t.textSecondary),
        const SizedBox(width: Space.s),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
        GlassSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }
}
