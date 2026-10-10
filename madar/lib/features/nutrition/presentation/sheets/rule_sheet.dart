import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/domain/body_clock.dart';
import '../../data/nutrition_providers.dart';
import '../../data/nutrition_service.dart';
import '../../domain/food_rules.dart';
import '../../domain/risk.dart';
import '../nutrition_texts.dart';

/// The id of the "no condition" option (a rule he wants anyway, not tied to
/// one of his conditions).
const String _noCondition = '-';

/// Opens the rule editor: his own sentence, with a live preview of how many
/// of his past entries the rule would have matched.
///
/// The editor never suggests a rule. Every part of it – the food, the word,
/// the amount, the window, the weight and the wording – is his.
Future<void> showRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  FoodRule? rule,
  String? conditionId,
}) async {
  final l = L10n.of(context);
  final tx = NutritionTexts.of(context);
  final foods = ref.read(nutritionFoodsProvider);
  final tags = ref.read(nutritionTagsProvider);
  final conditions = ref.read(nutritionConditionsProvider);
  final entries = ref.read(nutritionEntriesProvider);
  final foodsById = ref.read(nutritionFoodsByIdProvider);

  String? requireFor(FoodRuleTarget target, Object? value, Map<String, Object?> values, String message) {
    if (values['target'] != target.name) return null;
    final empty = value == null || (value is List && value.isEmpty) || (value is String && value.trim().isEmpty);
    return empty ? message : null;
  }

  final fields = <FieldSpec>[
    FieldSpec.singleSelect(
      'target',
      l.nutritionRuleTarget,
      required: true,
      icon: Icons.rule_rounded,
      options: [
        for (final t in FoodRuleTarget.values) SelectOption(id: t.name, label: tx.target(t)),
      ],
    ),
    FieldSpec.singleSelect(
      'food',
      l.nutritionRuleFood,
      icon: Icons.restaurant_rounded,
      options: [
        for (final f in foods)
          if (!f.archived || f.id == rule?.foodId) SelectOption(id: f.id, label: f.name),
      ],
      validator: (v, values) => requireFor(FoodRuleTarget.food, v, values, l.nutritionRuleNeedsFood),
    ),
    FieldSpec.multiSelect(
      'tag',
      l.nutritionRuleTag,
      icon: Icons.label_outline_rounded,
      allowAdd: true,
      maxCount: 1,
      options: [
        for (final t in {...tags, ?rule?.tag}) SelectOption(id: t, label: t),
      ],
      validator: (v, values) => requireFor(FoodRuleTarget.tag, v, values, l.nutritionRuleNeedsTag),
    ),
    FieldSpec.number('minPortion', l.nutritionRuleMinPortion, min: 0, max: 9999, decimals: 2, icon: Icons.straighten_rounded),
    FieldSpec.time('from', l.nutritionRuleFrom, icon: Icons.schedule_rounded),
    FieldSpec.time('to', l.nutritionRuleTo, icon: Icons.schedule_rounded),
    FieldSpec.number('maxPerDay', l.nutritionRuleMaxPerDay, min: 0, max: 50, icon: Icons.repeat_rounded),
    FieldSpec.singleSelect(
      'weight',
      l.nutritionRuleWeight,
      required: true,
      icon: Icons.speed_rounded,
      options: [
        for (final w in RiskWeight.values) SelectOption(id: w.name, label: tx.weight(w)),
      ],
    ),
    FieldSpec.singleSelect(
      'condition',
      l.nutritionRuleCondition,
      icon: Icons.favorite_outline_rounded,
      options: [
        SelectOption(id: _noCondition, label: l.nutritionRuleNoCondition),
        for (final c in conditions) SelectOption(id: c.id, label: c.name),
      ],
    ),
    FieldSpec.multiline('note', l.nutritionRuleNote, hint: l.nutritionRuleNoteHint, maxLength: 240),
    FieldSpec.toggle('active', l.nutritionRuleActive, icon: Icons.power_settings_new_rounded),
  ];

  /// Reads the sheet's current values as a rule, so the preview and the save
  /// agree on exactly one reading of the form.
  FoodRule ruleOf(Map<String, Object?> v) {
    final target = FoodRuleTarget.values.where((t) => t.name == v['target']).firstOrNull ?? FoodRuleTarget.anyFood;
    final weight = RiskWeight.values.where((w) => w.name == v['weight']).firstOrNull ?? RiskWeight.medium;
    final tag = ((v['tag'] as List<String>?) ?? const <String>[]).firstOrNull;
    final foodId = v['food'] as String?;
    final conditionId = v['condition'] as String?;
    final maxPerDay = (v['maxPerDay'] as num?)?.toInt();
    return FoodRule(
      id: rule?.id ?? '',
      target: target,
      weight: weight,
      conditionId: conditionId == null || conditionId == _noCondition ? null : conditionId,
      foodId: target == FoodRuleTarget.food ? foodId : null,
      foodName: target == FoodRuleTarget.food ? foods.where((f) => f.id == foodId).firstOrNull?.name : null,
      tag: target == FoodRuleTarget.tag ? tag : null,
      minPortion: (v['minPortion'] as num?)?.toDouble(),
      fromMinutes: BodyTimes.parse(v['from'] as String?),
      toMinutes: BodyTimes.parse(v['to'] as String?),
      maxPerDay: maxPerDay == null || maxPerDay <= 0 ? null : maxPerDay,
      note: v['note'] as String?,
      active: v['active'] != false,
    );
  }

  final values = await showEditSheet(
    context,
    title: rule == null ? l.nutritionAddRule : l.nutritionEditRule,
    subtitle: l.nutritionRuleSubtitle,
    icon: Icons.rule_rounded,
    fields: fields,
    initial: {
      'target': (rule?.target ?? FoodRuleTarget.tag).name,
      'food': rule?.foodId,
      'tag': [?rule?.tag],
      'minPortion': rule?.minPortion,
      'from': rule?.fromMinutes == null ? null : BodyTimes.format(rule!.fromMinutes!),
      'to': rule?.toMinutes == null ? null : BodyTimes.format(rule!.toMinutes!),
      'maxPerDay': rule?.maxPerDay,
      'weight': (rule?.weight ?? RiskWeight.medium).name,
      'condition': rule?.conditionId ?? conditionId ?? _noCondition,
      'note': rule?.note,
      'active': rule?.active ?? true,
    },
    preview: (context, v) {
      final draft = ruleOf(v);
      final hits = draft.isComplete ? RiskEngine.entriesHit(draft, entries, foodsById: foodsById).length : 0;
      return RulePreview(rule: draft, hits: hits);
    },
  );
  if (values == null) return;
  final draft = ruleOf(values);
  if (!draft.isComplete) return;
  final service = ref.read(nutritionServiceProvider);
  final data = FoodRuleDraft(
    target: draft.target,
    weight: draft.weight,
    conditionId: draft.conditionId,
    foodId: draft.foodId,
    tag: draft.tag,
    minPortion: draft.minPortion,
    fromMinutes: draft.fromMinutes,
    toMinutes: draft.toMinutes,
    maxPerDay: draft.maxPerDay,
    note: draft.note,
    active: draft.active,
  );
  final NutritionUndo undo;
  if (rule == null) {
    final (_, u) = await service.addRule(data);
    undo = u;
  } else {
    final row = await ref.read(repositoriesProvider).foodRules.byId(rule.id);
    if (row == null) return;
    undo = await service.updateRule(row, data);
  }
  if (!context.mounted) return;
  Fx.fire(Sfx.complete);
  unawaited(showUndoToast(context, UndoableAction(label: l.nutritionRuleSaved, undo: undo)));
}

/// The live preview above the rule editor: the rule read back as his own
/// sentence, and how many of his past entries it would have matched.
class RulePreview extends StatelessWidget {
  const RulePreview({super.key, required this.rule, required this.hits});

  final FoodRule rule;
  final int hits;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.nutritionRulePreviewTitle, style: text.labelSmall?.copyWith(color: t.textTertiary)),
        const SizedBox(height: Space.xxs),
        if (rule.isComplete)
          Text(tx.rule(rule), style: text.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Space.xxs),
        Text(
          key: const ValueKey('nutrition.rule.preview'),
          tx.fmt.localizeDigits(l.nutritionRulePreview(hits, tx.fmt.formatInt(hits))),
          style: text.bodySmall?.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}
