import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/meds_providers.dart';
import '../data/meds_service.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'widgets/editor_frame.dart';

/// What the rule editor offers; "not together" is stored as a separation.
enum RuleTemplate { separate, notWith, beforeFood, afterFood, withFood, custom }

extension RuleTemplateX on RuleTemplate {
  MedRuleKind get kind => switch (this) {
    RuleTemplate.separate || RuleTemplate.notWith => MedRuleKind.separate,
    RuleTemplate.beforeFood => MedRuleKind.beforeFood,
    RuleTemplate.afterFood => MedRuleKind.afterFood,
    RuleTemplate.withFood => MedRuleKind.withFood,
    RuleTemplate.custom => MedRuleKind.custom,
  };

  bool get twoMeds => this == RuleTemplate.separate || this == RuleTemplate.notWith;
  bool get hasMinutes => twoMeds || this == RuleTemplate.beforeFood || this == RuleTemplate.afterFood;
  bool get isFood => this == RuleTemplate.beforeFood || this == RuleTemplate.afterFood || this == RuleTemplate.withFood;

  int get defaultMinutes => switch (this) {
    RuleTemplate.separate => 120,
    RuleTemplate.notWith => 60,
    RuleTemplate.beforeFood => 30,
    RuleTemplate.afterFood => 30,
    _ => 0,
  };

  static RuleTemplate of(RuleSpec r) => switch (r.kind) {
    MedRuleKind.separate => RuleTemplate.separate,
    MedRuleKind.beforeFood => RuleTemplate.beforeFood,
    MedRuleKind.afterFood => RuleTemplate.afterFood,
    MedRuleKind.withFood => RuleTemplate.withFood,
    MedRuleKind.custom => RuleTemplate.custom,
  };
}

/// Opens the timing-rule editor; returns the draft to save.
Future<RuleDraft?> showRuleEditor(BuildContext context, {RuleSpec? rule}) =>
    showInteractionSheet<RuleDraft>(context, builder: (_) => RuleEditor(rule: rule));

class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({super.key, this.rule});

  final RuleSpec? rule;

  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  late RuleTemplate _tpl = widget.rule == null ? RuleTemplate.separate : RuleTemplateX.of(widget.rule!);
  late String? _a = widget.rule?.medAId;
  late String? _b = widget.rule?.medBId;
  late int _minutes = widget.rule?.minutes ?? _tpl.defaultMinutes;
  late final _note = TextEditingController(text: widget.rule?.note ?? '');
  bool _dirty = false;
  bool _showErrors = false;

  static const _choices = [15, 30, 45, 60, 90, 120, 180, 240];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  String? _error(L10n l, List<MedSpec> meds) {
    if (meds.isEmpty) return l.medsRuleNeedMeds;
    if (_a == null) return l.medsRuleNeedMed;
    if (_tpl.twoMeds && (_b == null || _b == _a)) return l.medsRuleNeedTwo;
    if (_tpl == RuleTemplate.custom && _note.text.trim().isEmpty) return l.medsRuleNeedNote;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = MedsTexts(l, MadarFormatter.of(context));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final meds = ref.watch(medsListProvider).value ?? const [];
    final error = _error(l, meds);
    String nameOf(String id) => meds.where((m) => m.id == id).firstOrNull?.name ?? '';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.medsRuleKind,
          icon: Icons.rule_rounded,
          child: MedsChoiceRow<RuleTemplate>(
            values: RuleTemplate.values,
            selected: _tpl,
            label: (v) => switch (v) {
              RuleTemplate.separate => l.medsRuleKindSeparate,
              RuleTemplate.notWith => l.medsRuleKindNotWith,
              RuleTemplate.beforeFood => l.medsRuleKindBeforeFood,
              RuleTemplate.afterFood => l.medsRuleKindAfterFood,
              RuleTemplate.withFood => l.medsRuleKindWithFood,
              RuleTemplate.custom => l.medsRuleKindCustom,
            },
            onSelected: (v) => _change(() {
              _tpl = v;
              _minutes = v.defaultMinutes;
            }),
          ),
        ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsRuleMedA,
          icon: Icons.medication_rounded,
          error: _showErrors && _a == null ? error : null,
          child: meds.isEmpty
              ? Text(l.medsRuleNeedMeds, style: text.bodyMedium!.copyWith(color: t.textTertiary))
              : MedsChoiceRow<String>(
                  values: [for (final m in meds) m.id],
                  selected: _a,
                  label: nameOf,
                  onSelected: (id) => _change(() => _a = id),
                ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          child: !_tpl.twoMeds
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.l),
                  child: FieldShell(
                    label: l.medsRuleMedB,
                    icon: Icons.medication_liquid_rounded,
                    error: _showErrors && _a != null && error != null ? error : null,
                    child: MedsChoiceRow<String>(
                      values: [for (final m in meds) if (m.id != _a) m.id],
                      selected: _b,
                      label: nameOf,
                      onSelected: (id) => _change(() => _b = id),
                    ),
                  ),
                ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          child: !_tpl.hasMinutes
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.l),
                  child: FieldShell(
                    label: l.medsRuleMinutes,
                    icon: Icons.timelapse_rounded,
                    child: MedsChoiceRow<int>(
                      values: _choices,
                      selected: _minutes,
                      label: tx.duration,
                      onSelected: (m) => _change(() => _minutes = m),
                    ),
                  ),
                ),
        ),
        if (_tpl.isFood)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xxs),
            child: Text(l.medsRuleFoodHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
          ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsRuleNote,
          icon: Icons.notes_rounded,
          optional: _tpl != RuleTemplate.custom,
          error: _showErrors && _tpl == RuleTemplate.custom && _note.text.trim().isEmpty ? error : null,
          child: TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            decoration: kitInputDecoration(context),
            onChanged: (_) => _change(() {}),
          ),
        ),
        if (_a != null && error == null) ...[
          const SizedBox(height: Space.l),
          Container(
            padding: const EdgeInsetsDirectional.all(Space.m),
            decoration: BoxDecoration(
              color: t.accentSoft.withValues(alpha: t.accentSoft.a * 0.6),
              borderRadius: BorderRadius.circular(t.radiusM),
              border: Border.all(color: t.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.rule_rounded, size: 18, color: t.accent),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    tx.rule(
                      RuleSpec(
                        id: '',
                        kind: _tpl.kind,
                        medAId: _a!,
                        medBId: _b,
                        minutes: _minutes,
                        note: _note.text.trim(),
                      ),
                      nameOf,
                    ),
                    style: text.bodyMedium!.copyWith(color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return MedsEditorFrame(
      title: widget.rule == null ? l.medsRuleEditorNew : l.medsRuleEditorEdit,
      icon: Icons.rule_rounded,
      dirty: _dirty,
      canSave: error == null,
      onRejectedSave: () => setState(() => _showErrors = true),
      onSave: () => Navigator.of(context).pop(
        RuleDraft(
          id: widget.rule?.id,
          kind: _tpl.kind,
          medAId: _a!,
          medBId: _tpl.twoMeds ? _b : null,
          minutes: _tpl.hasMinutes ? _minutes : 0,
          note: _note.text,
        ),
      ),
      body: body,
    );
  }
}
