import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart'
    show
        FieldShell,
        GlassSwitch,
        InlineDatePicker,
        KitChip,
        PickerButton,
        SwatchPicker,
        kitInputDecoration,
        kitNumberFormatter;
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../data/growth_service.dart';
import '../domain/growth_days.dart';
import '../domain/growth_goal.dart';
import '../domain/growth_units.dart';
import 'growth_texts.dart';

/// Creates a goal, or edits [goal]; returns the draft (null when dismissed).
Future<GoalDraft?> showGoalSheet(BuildContext context, {GrowthGoal? goal}) =>
    showInteractionSheet<GoalDraft>(context, builder: (_) => GoalSheet(goal: goal));

/// Pure validation of the goal editor's fields.
abstract final class GoalSheetRules {
  static num? parse(String text) => text.trim().isEmpty ? null : LocalizedNumbers.parse(text.trim());

  /// Error codes: `name`, `target`, `initial`.
  static Set<String> validate({required String name, required String target, required String initial}) {
    final errors = <String>{};
    if (name.trim().isEmpty) errors.add('name');
    final t = parse(target);
    if (t == null || t <= 0) errors.add('target');
    final i = initial.trim().isEmpty ? 0 : parse(initial);
    if (i == null || i < 0 || (t != null && t > 0 && i >= t)) errors.add('initial');
    return errors;
  }
}

/// The goal editor: name, unit (free text with suggestions), target,
/// starting value, optional deadline (with presets), colour and – when
/// editing – active / paused, with a live "what it takes" preview.
class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({super.key, this.goal});

  final GrowthGoal? goal;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _target;
  late final TextEditingController _initial;
  DateTime? _deadline;
  int? _color;
  bool _active = true;
  bool _dateOpen = false;
  Set<String> _errors = const {};
  bool _formatted = false;

  bool get _editing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final row = widget.goal?.row;
    _name = TextEditingController(text: row?.name ?? '');
    _unit = TextEditingController();
    _target = TextEditingController();
    _initial = TextEditingController();
    _deadline = row?.deadline;
    _color = row?.color ?? PlanetPalettes.growth.surface.toARGB32();
    _active = row?.active ?? true;
    for (final c in [_name, _unit, _target, _initial]) {
      c.addListener(_changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formatted) return;
    _formatted = true;
    final row = widget.goal?.row;
    if (row == null) return;
    final texts = GrowthTexts.of(context);
    final unit = GrowthUnit.parse(row.unit);
    _unit.text = unit.isEmpty ? '' : texts.unitName(unit);
    _target.text = texts.fmt.formatNumber(row.target, grouping: false);
    _initial.text = row.initial == 0 ? '' : texts.fmt.formatNumber(row.initial, grouping: false);
  }

  @override
  void dispose() {
    for (final c in [_name, _unit, _target, _initial]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (_errors.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _errors = GoalSheetRules.validate(
        name: _name.text,
        target: _target.text,
        initial: _initial.text,
      ).intersection(_errors);
    });
  }

  GrowthUnit get _parsedUnit => GrowthUnit.parse(_unit.text);

  void _save() {
    final errors = GoalSheetRules.validate(name: _name.text, target: _target.text, initial: _initial.text);
    if (errors.isNotEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _errors = errors);
      return;
    }
    final unit = _parsedUnit;
    Navigator.of(context).pop(
      GoalDraft(
        name: _name.text,
        unit: unit.stored,
        target: GoalSheetRules.parse(_target.text)!.toDouble(),
        initial: (GoalSheetRules.parse(_initial.text) ?? 0).toDouble(),
        deadline: _deadline,
        color: _color,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(growthTodayProvider);
    final unit = _parsedUnit;
    final unitLabel = unit.isEmpty ? null : texts.unitName(unit);
    final color = GrowthColors.goal(t, _color);

    Widget gap([double h = Space.l]) => SizedBox(height: h);

    final presets = <(String, DateTime)>[
      (l.growthInMonth, DateTime(today.year, today.month + 1, today.day)),
      (l.growthInThreeMonths, DateTime(today.year, today.month + 3, today.day)),
      (
        l.growthEndOfYear,
        today.month == 12 && today.day == 31 ? DateTime(today.year + 1, 12, 31) : DateTime(today.year, 12, 31),
      ),
    ];

    return InteractionSheetFrame(
      title: _editing ? l.growthEditGoal : l.growthNewGoal,
      subtitle: _editing ? widget.goal!.name : null,
      icon: Icons.spa_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.growthFieldName,
            icon: Icons.edit_rounded,
            error: _errors.contains('name') ? l.growthErrorName : null,
            child: TextField(
              key: const ValueKey('growth-goal-name'),
              controller: _name,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: kitInputDecoration(context, hint: l.growthFieldNameHint, error: _errors.contains('name')),
            ),
          ),
          gap(),
          FieldShell(
            label: l.growthFieldUnit,
            icon: Icons.straighten_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('growth-goal-unit'),
                  controller: _unit,
                  maxLength: 24,
                  textInputAction: TextInputAction.next,
                  decoration: kitInputDecoration(
                    context,
                    hint: l.growthFieldUnitHint,
                    suffixIcon: Icon(GrowthColors.unitIcon(unit), size: 18, color: color),
                  ),
                ),
                gap(Space.s),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    spacing: Space.s,
                    children: [
                      for (final k in GrowthUnit.suggestions)
                        KitChip(
                          label: texts.unitName(GrowthUnit.known(k)),
                          icon: GrowthColors.unitIcon(GrowthUnit.known(k)),
                          dense: true,
                          selected: unit.kind == k,
                          onTap: () {
                            final name = texts.unitName(GrowthUnit.known(k));
                            _unit.value = TextEditingValue(
                              text: unit.kind == k ? '' : name,
                              selection: TextSelection.collapsed(offset: unit.kind == k ? 0 : name.length),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          gap(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldShell(
                  label: l.growthFieldTarget,
                  icon: Icons.flag_rounded,
                  error: _errors.contains('target') ? l.growthErrorTarget : null,
                  child: TextField(
                    key: const ValueKey('growth-goal-target'),
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [kitNumberFormatter],
                    textInputAction: TextInputAction.next,
                    decoration: kitInputDecoration(
                      context,
                      hint: texts.fmt.formatInt(300),
                      suffix: unitLabel,
                      error: _errors.contains('target'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldShell(
                      label: l.growthFieldInitial,
                      icon: Icons.start_rounded,
                      optional: true,
                      error: _errors.contains('initial') ? l.growthErrorInitial : null,
                      child: TextField(
                        key: const ValueKey('growth-goal-initial'),
                        controller: _initial,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [kitNumberFormatter],
                        decoration: kitInputDecoration(
                          context,
                          hint: texts.fmt.formatInt(0),
                          suffix: unitLabel,
                          error: _errors.contains('initial'),
                        ),
                      ),
                    ),
                    if (!_errors.contains('initial'))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: Space.xxs, top: Space.xs),
                        child: Text(l.growthFieldInitialHint, style: text.labelSmall),
                      ),
                  ],
                ),
              ),
            ],
          ),
          gap(),
          FieldShell(
            label: l.growthFieldDeadline,
            icon: Icons.event_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PickerButton(
                  icon: Icons.event_rounded,
                  text: _deadline == null
                      ? l.growthFieldNoDeadline
                      : texts.fmt.formatDate(_deadline!, style: MadarDateStyle.weekdayDayMonth),
                  placeholder: _deadline == null,
                  active: _dateOpen,
                  semanticLabel: l.growthFieldDeadline,
                  onTap: () => setState(() => _dateOpen = !_dateOpen),
                ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.emphasized,
                  alignment: AlignmentDirectional.topStart,
                  child: _dateOpen
                      ? InlineDatePicker(
                          value: _deadline,
                          now: today,
                          firstDate: _deadline != null && _deadline!.isBefore(today) ? _deadline : today,
                          onChanged: (d) => setState(() => _deadline = d),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                gap(Space.s),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final (label, date) in presets)
                      KitChip(
                        label: label,
                        dense: true,
                        selected: _deadline != null && GrowthDays.sameDay(_deadline!, date),
                        onTap: () => setState(
                          () => _deadline = _deadline != null && GrowthDays.sameDay(_deadline!, date) ? null : date,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          gap(Space.m),
          _Preview(text: _previewText(texts, today, unit), color: color),
          gap(),
          FieldShell(
            label: l.growthFieldColor,
            icon: Icons.palette_rounded,
            child: SwatchPicker(
              colors: CuratedPalette.colors,
              value: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
          ),
          if (_editing && !widget.goal!.stats.completed) ...[
            gap(),
            Row(
              children: [
                Icon(Icons.play_circle_rounded, size: 18, color: t.accent),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.growthFieldActive, style: text.titleSmall),
                      Text(l.growthFieldActiveHint, style: text.labelSmall),
                    ],
                  ),
                ),
                GlassSwitch(
                  value: _active,
                  semanticLabel: l.growthFieldActive,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ],
          gap(Space.s),
        ],
      ),
      footer: SheetButton(
        label: _editing ? l.growthSave : l.growthCreate,
        primary: true,
        icon: _editing ? Icons.check_rounded : Icons.auto_awesome_rounded,
        sfx: null,
        onPressed: _save,
      ),
    );
  }

  String _previewText(GrowthTexts texts, DateTime today, GrowthUnit unit) {
    final l = texts.l;
    final deadline = _deadline;
    if (deadline == null) return l.growthPreviewOpen;
    if (GrowthDays.between(today, deadline) < 0) return l.growthPreviewPast;
    final target = GoalSheetRules.parse(_target.text)?.toDouble();
    final initial = (GoalSheetRules.parse(_initial.text) ?? 0).toDouble();
    final logged = widget.goal?.stats.logged ?? 0;
    final date = texts.date(deadline, today: today);
    if (target == null || target <= 0) return l.growthNeededUntil(date);
    final remaining = target - initial - logged;
    if (remaining <= 0) return l.growthPaceDoneHint;
    final days = GrowthDays.between(today, deadline) + 1;
    return l.growthPreviewNeed(texts.rate(unit, remaining / days, needed: true), date);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textPrimary);
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: t.isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_rounded, size: 20, color: color),
            const SizedBox(width: Space.m),
            Expanded(
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                child: Text(text, key: ValueKey(text), style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
