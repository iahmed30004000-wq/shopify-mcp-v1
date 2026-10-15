import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/food_rules.dart';
import '../../domain/risk.dart';
import '../nutrition_actions.dart';
import '../nutrition_texts.dart';
import '../widgets/nutrition_widgets.dart';

/// His chronic conditions and, under each one, the rules he wrote himself.
///
/// This screen is the only place a rating ever comes from: no rule here,
/// no rating anywhere.
class ConditionsScreen extends ConsumerWidget {
  const ConditionsScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = NutritionPalette.of(context);
    final conditions = ref.watch(nutritionConditionsProvider);
    final rules = ref.watch(nutritionRulesProvider);
    final general = [
      for (final r in rules)
        if (r.conditionId == null || conditions.every((c) => c.id != r.conditionId)) r,
    ];

    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, fade: false, child: child);

    return MadarScaffold(
      title: l.nutritionConditionsTitle,
      backdropSeed: 9.6,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('nutrition.conditions.fab'),
        icon: Icons.add_rounded,
        semanticLabel: l.nutritionAddCondition,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => NutritionActions.addCondition(context, ref),
      ),
      body: EntranceChoreo(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, nutritionBottomPadding),
          children: [
            if (conditions.isEmpty && general.isEmpty)
              stagger(
                AnimatedEmptyState(
                  key: const ValueKey('nutrition.conditions.empty'),
                  kind: EmptyStateKind.emptyList,
                  title: l.nutritionConditionsEmptyTitle,
                  body: l.nutritionConditionsEmptyBody,
                  actionLabel: l.nutritionAddCondition,
                  actionIcon: Icons.add_rounded,
                  onAction: () => NutritionActions.addCondition(context, ref),
                ),
              ),
            for (final c in conditions)
              stagger(
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: ConditionCard(
                    condition: c,
                    rules: [
                      for (final r in rules)
                        if (r.conditionId == c.id) r,
                    ],
                  ),
                ),
              ),
            stagger(
              BodySectionTitle(
                l.nutritionGeneralRules,
                icon: Icons.rule_rounded,
                trailing: MadarButton(
                  key: const ValueKey('nutrition.rules.addGeneral'),
                  label: l.nutritionAddRule,
                  icon: Icons.add_rounded,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => NutritionActions.addRule(context, ref),
                ),
              ),
            ),
            if (general.isEmpty)
              stagger(BodyHint(l.nutritionRulesEmptyBody, icon: Icons.rule_rounded, color: t.textTertiary))
            else
              for (final r in general)
                stagger(
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: RuleTile(rule: r),
                  ),
                ),
            stagger(
              Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: BodyHint(l.nutritionNoRulesBody, color: p.condition),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One condition, with his own rules under it.
class ConditionCard extends ConsumerWidget {
  const ConditionCard({super.key, required this.condition, required this.rules});

  final ConditionRef condition;
  final List<FoodRule> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final color = condition.color == null ? p.condition : Color(condition.color!);
    final since = condition.since;
    final notes = condition.notes;
    Future<void> run(Future<UndoableAction?> Function() work) async {
      final action = await work();
      if (action != null && context.mounted) await showUndoToast(context, action);
    }

    return BodyCard(
      key: ValueKey('nutrition.condition.${condition.id}'),
      title: condition.name,
      icon: Icons.favorite_outline_rounded,
      iconColor: color,
      seed: 9.6,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!condition.active)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.s),
              child: BodyPill(label: l.nutritionConditionPaused, color: t.textTertiary, dense: true),
            ),
          MadarSwitch(
            key: ValueKey('nutrition.condition.${condition.id}.active'),
            value: condition.active,
            activeColor: color,
            semanticLabel: '${l.nutritionConditionActive}: ${condition.name}',
            onChanged: (_) => run(() => NutritionActions.toggleCondition(context, ref, condition)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              if (since != null)
                BodyPill(
                  label: l.nutritionConditionSinceLabel(tx.fmt.formatDate(since, style: MadarDateStyle.medium)),
                  icon: Icons.calendar_today_rounded,
                  color: color,
                  dense: true,
                ),
              BodyPill(
                label: tx.fmt.localizeDigits(l.nutritionRulesCount(rules.length, tx.fmt.formatInt(rules.length))),
                icon: Icons.rule_rounded,
                color: color,
                dense: true,
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(notes, style: text.bodySmall?.copyWith(color: t.textSecondary)),
          ],
          const SizedBox(height: Space.m),
          if (rules.isEmpty)
            BodyHint(l.nutritionRulesEmptyTitle, icon: Icons.rule_rounded, color: t.textTertiary)
          else
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: RuleTile(rule: r),
              ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                key: ValueKey('nutrition.condition.${condition.id}.addRule'),
                label: l.nutritionAddRule,
                icon: Icons.add_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => NutritionActions.addRule(context, ref, conditionId: condition.id),
              ),
              MadarButton(
                label: l.nutritionEdit,
                icon: Icons.edit_outlined,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => NutritionActions.editCondition(context, ref, condition),
              ),
              MadarButton(
                key: ValueKey('nutrition.condition.${condition.id}.delete'),
                label: l.nutritionDelete,
                icon: Icons.delete_outline_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () => run(() => NutritionActions.deleteCondition(context, ref, condition)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One rule as his own sentence, with its weight and its switch.
class RuleTile extends ConsumerWidget {
  const RuleTile({super.key, required this.rule});

  final FoodRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final entries = ref.watch(nutritionEntriesProvider);
    final hits = rule.isComplete
        ? RiskEngine.entriesHit(rule, entries, foodsById: ref.watch(nutritionFoodsByIdProvider)).length
        : 0;
    return ActionableItem(
      key: ValueKey('nutrition.rule.${rule.id}'),
      semanticLabel: '${tx.rule(rule)}. ${rule.active ? l.nutritionRuleActive : l.nutritionRulePaused}',
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => NutritionActions.editRule(context, ref, rule),
      actions: ItemActions(
        onEdit: () => NutritionActions.editRule(context, ref, rule),
        onDelete: () => NutritionActions.deleteRule(context, ref, rule),
        extra: [
          ItemAction(
            icon: rule.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: rule.active ? l.nutritionRulePaused : l.nutritionRuleActive,
            onSelected: () => NutritionActions.toggleRule(context, ref, rule),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.nutritionDelete,
          tone: ActionTone.danger,
          onPressed: () => NutritionActions.deleteRule(context, ref, rule),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.s, Space.s + 2),
        borderRadius: BorderRadius.circular(t.radiusM),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(
                rule.isDayRule ? Icons.repeat_rounded : Icons.rule_rounded,
                size: 18,
                color: rule.active ? p.condition : t.textTertiary,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.rule(rule),
                      style: text.bodyMedium?.copyWith(color: rule.active ? t.textPrimary : t.textTertiary),
                    ),
                    if (!rule.active)
                      Text(l.nutritionRulePaused, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                    if (rule.active && entries.isNotEmpty && hits > 0)
                      Text(
                        tx.fmt.localizeDigits(l.nutritionRulePreview(hits, tx.fmt.formatInt(hits))),
                        style: text.labelSmall?.copyWith(color: t.textTertiary),
                      ),
                  ],
                ),
              ),
              MadarSwitch(
                key: ValueKey('nutrition.rule.${rule.id}.active'),
                value: rule.active,
                semanticLabel: tx.rule(rule),
                onChanged: (_) async {
                  final action = await NutritionActions.toggleRule(context, ref, rule);
                  if (action != null && context.mounted) await showUndoToast(context, action);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
