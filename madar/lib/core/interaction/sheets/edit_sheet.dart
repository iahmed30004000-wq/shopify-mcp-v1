import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../numbers.dart';
import '../src/labels.dart';
import '../src/pressable.dart';
import '../src/stagger.dart';
import 'curated.dart';
import 'field_inputs.dart';
import 'field_spec.dart';
import 'sheet.dart';

/// Opens the universal edit sheet and resolves with the normalised values
/// (see [FieldSpec] for each kind's value type), or null when dismissed.
///
/// * Spring-animated glass sheet (Sfx.sheetOpen / Sfx.sheetClose).
/// * Drag-to-dismiss; with unsaved changes the sheet asks before discarding.
/// * Keyboard-aware; validation with inline animated errors; Save stays
///   disabled until the form is valid (tapping it reveals what is missing).
/// * Numbers accept Arabic-Indic / Persian digits and `٫`.
Future<Map<String, Object?>?> showEditSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, Object?> initial = const {},
  String? saveLabel,
  String? subtitle,
  IconData? icon,
}) {
  return showInteractionSheet<Map<String, Object?>>(
    context,
    builder: (_) =>
        EditSheet(title: title, fields: fields, initial: initial, saveLabel: saveLabel, subtitle: subtitle, icon: icon),
  );
}

/// The body of [showEditSheet] (public for embedding / tests).
class EditSheet extends StatefulWidget {
  const EditSheet({
    super.key,
    required this.title,
    required this.fields,
    this.initial = const {},
    this.saveLabel,
    this.subtitle,
    this.icon,
  });

  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  final String? saveLabel;
  final String? subtitle;
  final IconData? icon;

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> with SingleTickerProviderStateMixin {
  late final EditFormModel _model = EditFormModel(widget.fields, widget.initial);
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, GlobalKey> _keys = {};
  late final AnimationController _shake = AnimationController(vsync: this, duration: MadarMotion.long);
  String? _expanded;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      _keys[f.key] = GlobalKey();
      if (f.isTextEntry) {
        _controllers[f.key] = TextEditingController(text: _model.textOf(f.key));
        final node = FocusNode();
        node.addListener(() {
          if (!node.hasFocus) _model.touch(f.key);
        });
        _focus[f.key] = node;
      }
    }
    _model.addListener(_onModel);
  }

  void _onModel() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _model.removeListener(_onModel);
    _model.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focus.values) {
      n.dispose();
    }
    _shake.dispose();
    super.dispose();
  }

  void _save() {
    if (!_model.isValid) {
      _rejectSave();
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_model.result());
  }

  void _rejectSave() {
    Fx.fire(Sfx.error);
    _model.revealAll();
    if (!context.reducedMotion) _shake.forward(from: 0);
    final key = _model.firstInvalidKey;
    final ctx = key == null ? null : _keys[key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.standard,
        alignment: 0.15,
      );
      _focus[key]?.requestFocus();
    }
  }

  void _askDiscard() {
    if (_confirming) return;
    FocusScope.of(context).unfocus();
    Fx.fire(Sfx.notify, haptic: Haptic.warning);
    setState(() => _confirming = true);
  }

  void _toggle(String key) {
    FocusScope.of(context).unfocus();
    setState(() => _expanded = _expanded == key ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final dirty = _model.isDirty;
    final textKeys = [
      for (final f in widget.fields)
        if (f.isTextEntry) f.key,
    ];
    final children = <Widget>[];
    for (final (i, f) in widget.fields.indexed) {
      if (i > 0) children.add(const SizedBox(height: Space.xl));
      children.add(
        KitStaggerIn(
          index: i + 1,
          child: KeyedSubtree(key: _keys[f.key], child: _field(f, textKeys)),
        ),
      );
    }

    final footer = AnimatedSize(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.emphasized,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
        ),
        child: _confirming ? _discardBar(l10n) : _actionBar(l10n),
      ),
    );

    return PopScope<Map<String, Object?>>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askDiscard();
      },
      child: InteractionSheetFrame(
        title: widget.title,
        subtitle: widget.subtitle,
        icon: widget.icon,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        footer: footer,
      ),
    );
  }

  Widget _actionBar(L10n l10n) {
    final valid = _model.isValid;
    return Row(
      key: const ValueKey('actions'),
      children: [
        Expanded(
          flex: 2,
          child: SheetButton(label: l10n.actionCancel, onPressed: () => Navigator.of(context).maybePop()),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          flex: 3,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final v = _shake.value;
              final dx = v == 0 ? 0.0 : math.sin(v * math.pi * 6) * (1 - v) * 10;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Tooltip(
              message: valid ? '' : l10n.interactionSaveDisabledHint,
              excludeFromSemantics: true,
              child: SheetButton(
                label: widget.saveLabel ?? l10n.actionSave,
                icon: Icons.check_rounded,
                primary: true,
                enabled: valid,
                sfx: null,
                onPressed: _save,
                onDisabledTap: _rejectSave,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _discardBar(L10n l10n) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('discard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: t.warning, size: 20),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l10n.interactionDiscardTitle}  ', style: text.titleMedium),
                      TextSpan(text: l10n.interactionDiscardBody, style: text.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: SheetButton(
                label: l10n.interactionDiscardConfirm,
                tone: t.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: l10n.interactionKeepEditing,
                primary: true,
                onPressed: () => setState(() => _confirming = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- fields ----

  Widget _field(FieldSpec f, List<String> textKeys) {
    final l10n = L10n.of(context);
    final issue = _model.visibleIssueOf(f.key);
    final error = issue == null ? null : KitLabels.issue(l10n, issue);
    final optional = !f.required && f.kind != FieldKind.toggle && f.kind != FieldKind.slider;
    Widget shell(Widget child, {Widget? trailing}) =>
        FieldShell(label: f.label, icon: f.icon, optional: optional, error: error, trailing: trailing, child: child);

    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.multiline:
        return shell(_textField(f, textKeys, error != null));
      case FieldKind.number:
        return shell(_numberField(f, textKeys, error != null));
      case FieldKind.currency:
        return shell(_currencyField(f, textKeys, error != null, l10n));
      case FieldKind.date:
        final v = _model.valueOf(f.key) as DateTime?;
        return shell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                icon: Icons.event_rounded,
                text: v == null ? l10n.interactionFieldPickDate : KitLabels.date(context, v),
                placeholder: v == null,
                active: _expanded == f.key,
                error: error != null,
                semanticLabel: f.label,
                onTap: () => _toggle(f.key),
              ),
              _Expander(
                open: _expanded == f.key,
                child: InlineDatePicker(
                  value: v,
                  firstDate: f.firstDate,
                  lastDate: f.lastDate,
                  allowClear: !f.required,
                  onChanged: (d) => _model.setValue(f.key, d),
                ),
              ),
            ],
          ),
        );
      case FieldKind.time:
        final v = _model.valueOf(f.key) as String?;
        return shell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                icon: Icons.schedule_rounded,
                text: v == null ? l10n.interactionFieldPickTime : KitLabels.time(context, v),
                placeholder: v == null,
                active: _expanded == f.key,
                error: error != null,
                semanticLabel: f.label,
                onTap: () {
                  if (v == null) _model.setValue(f.key, _defaultTime());
                  _toggle(f.key);
                },
              ),
              _Expander(
                open: _expanded == f.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.s),
                    TimeWheel(value: v ?? _defaultTime(), onChanged: (x) => _model.setValue(f.key, x)),
                    if (!f.required && v != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: KitChip(
                          dense: true,
                          label: l10n.interactionFieldClear,
                          icon: Icons.close_rounded,
                          selected: false,
                          sfx: Sfx.toggleOff,
                          onTap: () {
                            _model.setValue(f.key, null);
                            setState(() => _expanded = null);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      case FieldKind.timeList:
        return shell(
          _TimeListInput(
            times: (_model.valueOf(f.key) as List<String>?) ?? const [],
            open: _expanded == f.key,
            maxCount: f.maxCount,
            onToggle: () => _toggle(f.key),
            onChanged: (list) => _model.setValue(f.key, list),
          ),
        );
      case FieldKind.singleSelect:
        final v = _model.valueOf(f.key) as String?;
        return shell(
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final o in f.options)
                KitChip(
                  label: o.label,
                  icon: o.icon,
                  swatch: o.color,
                  selected: v == o.id,
                  sfx: Sfx.tap,
                  onTap: () => _model.setValue(f.key, !f.required && v == o.id ? null : o.id),
                ),
            ],
          ),
        );
      case FieldKind.multiSelect:
        return shell(
          _MultiSelectInput(spec: f, model: _model, adding: _expanded == f.key, onToggleAdd: () => _toggle(f.key)),
        );
      case FieldKind.toggle:
        final v = _model.valueOf(f.key) == true;
        return FieldShell(
          label: '',
          error: error,
          child: _ToggleRow(
            label: f.label,
            description: f.hint,
            icon: f.icon,
            value: v,
            onChanged: (x) => _model.setValue(f.key, x),
          ),
        );
      case FieldKind.rating:
        return shell(
          StarRating(
            value: _model.valueOf(f.key) as int?,
            max: (f.max ?? 5).toInt(),
            allowClear: !f.required,
            semanticLabel: f.label,
            onChanged: (v) => _model.setValue(f.key, v),
          ),
        );
      case FieldKind.slider:
        final v = _model.valueOf(f.key) as int;
        final t = context.tokens;
        return shell(
          LabeledSlider(
            value: v,
            min: (f.min ?? 0).toInt(),
            max: (f.max ?? 10).toInt(),
            labels: f.sliderLabels,
            semanticLabel: f.label,
            onChanged: (x) => _model.setValue(f.key, x),
          ),
          trailing: AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: a,
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Text(
              '$v',
              key: ValueKey(v),
              style: MadarTypography.numerals(t, size: 20, color: t.accent).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
      case FieldKind.color:
        return shell(
          SwatchPicker(
            colors: f.palette ?? CuratedPalette.colors,
            value: _model.valueOf(f.key) as int?,
            onChanged: (v) => _model.setValue(f.key, !f.required && v == _model.valueOf(f.key) ? null : v),
          ),
        );
      case FieldKind.icon:
        return shell(
          IconGrid(
            icons: f.icons ?? InteractionIcons.curated,
            value: _model.valueOf(f.key) as String?,
            onChanged: (v) => _model.setValue(f.key, !f.required && v == _model.valueOf(f.key) ? null : v),
          ),
        );
      case FieldKind.prayerWindow:
        return shell(
          PrayerWindowPicker(
            value: _model.valueOf(f.key) as PrayerWindow?,
            includeAnytime: f.includeAnytime,
            allowClear: !f.required,
            onChanged: (w) => _model.setValue(f.key, w),
          ),
        );
    }
  }

  String _defaultTime() {
    final n = DateTime.now();
    return ClockTime.format((n.hour + 1) % 24, 0);
  }

  TextInputAction _action(String key, List<String> textKeys) =>
      textKeys.indexOf(key) < textKeys.length - 1 ? TextInputAction.next : TextInputAction.done;

  void _next(String key, List<String> textKeys) {
    final i = textKeys.indexOf(key);
    if (i >= 0 && i < textKeys.length - 1) {
      _focus[textKeys[i + 1]]?.requestFocus();
    } else {
      _focus[key]?.unfocus();
    }
  }

  Widget _textField(FieldSpec f, List<String> textKeys, bool error) {
    final multi = f.kind == FieldKind.multiline;
    return TextField(
      controller: _controllers[f.key],
      focusNode: _focus[f.key],
      autofocus: f.autofocus,
      minLines: multi ? 3 : 1,
      maxLines: multi ? 8 : 1,
      maxLength: f.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      keyboardType: multi ? TextInputType.multiline : TextInputType.text,
      textInputAction: multi ? TextInputAction.newline : _action(f.key, textKeys),
      textCapitalization: TextCapitalization.sentences,
      decoration: kitInputDecoration(context, hint: f.hint, error: error),
      onChanged: (v) => _model.setText(f.key, v),
      onSubmitted: multi ? null : (_) => _next(f.key, textKeys),
      onTap: () => setState(() => _expanded = null),
    );
  }

  Widget _numberField(FieldSpec f, List<String> textKeys, bool error) {
    final l10n = L10n.of(context);
    final t = context.tokens;
    final step = f.step;
    Widget? stepper;
    if (step != null) {
      void nudge(int dir) {
        final current = LocalizedNumbers.parse(_model.textOf(f.key)) ?? f.min ?? 0;
        var next = current + step * dir;
        if (f.min != null) next = math.max(next, f.min!);
        if (f.max != null) next = math.min(next, f.max!);
        final text = kitNumberText(f.decimals == 0 ? next.round() : double.parse(next.toStringAsFixed(f.decimals)));
        _controllers[f.key]!.text = text;
        Fx.fire(Sfx.countTick, pitch: dir > 0 ? 1.1 : 0.9);
        _model.setText(f.key, text);
      }

      stepper = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KitPressable(
            onTap: () => nudge(-1),
            sfx: null,
            semanticLabel: l10n.interactionFieldDecrease,
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: Icon(Icons.remove_rounded, color: t.textSecondary, size: 20),
            ),
          ),
          KitPressable(
            onTap: () => nudge(1),
            sfx: null,
            semanticLabel: l10n.interactionFieldIncrease,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.xs, end: Space.m, top: Space.s, bottom: Space.s),
              child: Icon(Icons.add_rounded, color: t.accent, size: 20),
            ),
          ),
        ],
      );
    }
    return TextField(
      controller: _controllers[f.key],
      focusNode: _focus[f.key],
      autofocus: f.autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: f.decimals > 0, signed: f.min == null || f.min! < 0),
      inputFormatters: [kitNumberFormatter],
      textInputAction: _action(f.key, textKeys),
      style: MadarTypography.numerals(t, size: 17),
      decoration: kitInputDecoration(context, hint: f.hint, error: error, suffix: f.unit, suffixIcon: stepper),
      onChanged: (v) => _model.setText(f.key, v),
      onSubmitted: (_) => _next(f.key, textKeys),
      onTap: () => setState(() => _expanded = null),
    );
  }

  Widget _currencyField(FieldSpec f, List<String> textKeys, bool error, L10n l10n) {
    final t = context.tokens;
    final code = _model.currencyOf(f.key);
    final open = _expanded == f.key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controllers[f.key],
                focusNode: _focus[f.key],
                autofocus: f.autofocus,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: f.decimals > 0,
                  signed: f.min == null || f.min! < 0,
                ),
                inputFormatters: [kitNumberFormatter],
                textInputAction: _action(f.key, textKeys),
                style: MadarTypography.numerals(t, size: 18),
                decoration: kitInputDecoration(context, hint: f.hint ?? l10n.interactionFieldAmount, error: error),
                onChanged: (v) => _model.setText(f.key, v),
                onSubmitted: (_) => _next(f.key, textKeys),
                onTap: () => setState(() => _expanded = null),
              ),
            ),
            const SizedBox(width: Space.s),
            KitPressable(
              onTap: () => _toggle(f.key),
              semanticLabel: '${l10n.interactionFieldCurrency}: ${KitLabels.currencyName(l10n, code)}',
              excludeSemantics: true,
              child: AnimatedContainer(
                duration: context.motion(MadarMotion.short),
                height: 52,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusM),
                  color: open ? t.accentSoft : t.glassFill,
                  border: Border.all(color: open ? t.accent : t.glassBorder, width: open ? 1.4 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      KitLabels.currencySymbol(l10n, code),
                      style: MadarTypography.numerals(t, size: 16, color: t.accent),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(code, style: Theme.of(context).textTheme.labelMedium),
                    Icon(Icons.expand_more_rounded, size: 18, color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ),
        _Expander(
          open: open,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.m),
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final c in f.currencies)
                  KitChip(
                    dense: true,
                    label: '${KitLabels.currencySymbol(l10n, c)}  ${KitLabels.currencyName(l10n, c)}',
                    selected: c == code,
                    sfx: Sfx.tap,
                    onTap: () {
                      _model.setCurrency(f.key, c);
                      setState(() => _expanded = null);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated open/close of an inline picker.
class _Expander extends StatelessWidget {
  const _Expander({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion(MadarMotion.medium);
    return AnimatedSize(
      duration: motion,
      curve: MadarMotion.emphasized,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: motion,
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: open ? KeyedSubtree(key: const ValueKey('open'), child: child) : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged, this.description, this.icon});

  final String label;
  final String? description;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: KitPressable(
        onTap: () => onChanged(!value),
        sfx: value ? Sfx.toggleOff : Sfx.toggleOn,
        pressScale: 0.99,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.m),
          decoration: BoxDecoration(
            color: t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: t.glassBorder),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: value ? t.accent : t.textSecondary),
                const SizedBox(width: Space.m),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text.titleMedium),
                    if (description != null) Text(description!, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.m),
              GlassSwitch(value: value, onChanged: onChanged, semanticLabel: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeListInput extends StatefulWidget {
  const _TimeListInput({
    required this.times,
    required this.open,
    required this.onToggle,
    required this.onChanged,
    this.maxCount,
  });

  final List<String> times;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<List<String>> onChanged;
  final int? maxCount;

  @override
  State<_TimeListInput> createState() => _TimeListInputState();
}

class _TimeListInputState extends State<_TimeListInput> {
  late String _draft = _suggest();
  bool _duplicate = false;

  String _suggest() {
    if (widget.times.isEmpty) return '08:00';
    final (h, m) = ClockTime.parts(widget.times.last);
    return ClockTime.format((h + 4) % 24, m);
  }

  void _add() {
    if (widget.times.contains(_draft)) {
      Fx.fire(Sfx.error);
      setState(() => _duplicate = true);
      return;
    }
    Fx.fire(Sfx.toggleOn);
    widget.onChanged(ClockTime.sortUnique([...widget.times, _draft]));
    setState(() {
      _duplicate = false;
      _draft = ClockTime.format((ClockTime.parts(_draft).$1 + 4) % 24, ClockTime.parts(_draft).$2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final t = context.tokens;
    final full = widget.maxCount != null && widget.times.length >= widget.maxCount!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final time in widget.times)
              KitChip(
                key: ValueKey(time),
                label: KitLabels.time(context, time),
                icon: Icons.schedule_rounded,
                selected: true,
                sfx: Sfx.tap,
                removeLabel: l10n.interactionFieldRemove(KitLabels.time(context, time)),
                onRemove: () => widget.onChanged([...widget.times]..remove(time)),
                onTap: () {},
              ),
            if (!full)
              KitChip(
                label: l10n.interactionFieldAddTime,
                icon: widget.open ? Icons.close_rounded : Icons.add_rounded,
                selected: false,
                sfx: Sfx.tap,
                onTap: widget.onToggle,
              ),
          ],
        ),
        _Expander(
          open: widget.open && !full,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.s),
              TimeWheel(
                value: _draft,
                onChanged: (v) => setState(() {
                  _draft = v;
                  _duplicate = false;
                }),
              ),
              if (_duplicate)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: Text(
                    l10n.interactionFieldTimeExists,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.warning),
                  ),
                ),
              Center(
                child: SheetButton(label: l10n.actionAdd, icon: Icons.add_rounded, sfx: null, onPressed: _add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MultiSelectInput extends StatefulWidget {
  const _MultiSelectInput({required this.spec, required this.model, required this.adding, required this.onToggleAdd});

  final FieldSpec spec;
  final EditFormModel model;
  final bool adding;
  final VoidCallback onToggleAdd;

  @override
  State<_MultiSelectInput> createState() => _MultiSelectInputState();
}

class _MultiSelectInputState extends State<_MultiSelectInput> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.model.addOption(widget.spec.key, _text.text)) {
      Fx.fire(Sfx.toggleOn);
      _text.clear();
    } else {
      Fx.fire(Sfx.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final f = widget.spec;
    final selected = (widget.model.valueOf(f.key) as List<String>?) ?? const [];
    final options = [...f.options, ...widget.model.addedOptions(f.key)];
    void toggle(String id) {
      final next = [...selected];
      next.contains(id) ? next.remove(id) : next.add(id);
      widget.model.setValue(f.key, next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final o in options)
              KitChip(
                label: o.label,
                icon: o.icon,
                swatch: o.color,
                showCheck: true,
                selected: selected.contains(o.id),
                onTap: () => toggle(o.id),
              ),
            if (f.allowAdd)
              KitChip(
                label: l10n.interactionFieldAddOption,
                icon: widget.adding ? Icons.close_rounded : Icons.add_rounded,
                selected: false,
                sfx: Sfx.tap,
                onTap: widget.onToggleAdd,
              ),
          ],
        ),
        if (f.allowAdd)
          _Expander(
            open: widget.adding,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.m),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: kitInputDecoration(context, hint: l10n.interactionFieldAddOptionHint),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  SheetButton(label: l10n.actionAdd, sfx: null, onPressed: _submit),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
