import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/food_log.dart';
import '../../domain/plan_compare.dart';
import '../nutrition_actions.dart';
import '../nutrition_nav.dart';
import '../nutrition_texts.dart';
import '../widgets/nutrition_today_card.dart';
import '../widgets/nutrition_widgets.dart';

/// «الأكل» on the Body planet: the day at a glance – what he ate with its
/// times, today's rating with its reasons (only when he has written a
/// rule), the next planned meal, and the quick-log button.
class FoodTab extends ConsumerWidget {
  const FoodTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = NutritionPalette.of(context);
    // Keeps the meal reminders in step with what this screen changes.
    ref.watch(nutritionReminderSyncProvider);
    final entries = ref.watch(nutritionTodayEntriesProvider);
    final hasRating = ref.watch(nutritionHasRatingProvider);
    final risk = ref.watch(nutritionTodayRiskProvider);
    final today = ref.watch(nutritionTodayPlanProvider);
    final plan = ref.watch(nutritionActivePlanProvider);
    final next = today.next;
    final fresh = entries.isEmpty && plan.isEmpty && ref.watch(nutritionFoodsProvider).isEmpty;

    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, fade: false, child: child);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, nutritionBottomPadding),
      children: [
        stagger(NutritionTodayCard(onQuickLog: () => NutritionActions.quickLog(context, ref))),
        const SizedBox(height: Space.m),

        if (fresh)
          stagger(
            AnimatedEmptyState(
              key: const ValueKey('nutrition.empty'),
              kind: EmptyStateKind.emptyList,
              title: l.nutritionEmptyTitle,
              body: l.nutritionEmptyBody,
              actionLabel: l.nutritionQuickLog,
              actionIcon: Icons.add_rounded,
              onAction: () => NutritionActions.quickLog(context, ref),
            ),
          ),

        // Today's rating, always with its reasons; or the invitation to
        // write the first rule when he has none.
        if (!hasRating)
          stagger(
            NutritionNoRulesCard(onWriteRule: () => nutritionGo(context, ref, NutritionDestination.rules)),
          )
        else if (risk != null)
          stagger(
            BodyCard(
              key: const ValueKey('nutrition.todayRating'),
              title: l.nutritionTodayRating,
              icon: nutritionLevelIcon(risk.level),
              iconColor: p.level(risk.level),
              seed: 3.3,
              trailing: NutritionLevelPill(level: risk.level, dense: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (risk.reasons.isEmpty)
                    BodyHint(l.nutritionLevelClear, icon: Icons.check_circle_outline_rounded, color: t.textSecondary)
                  else ...[
                    Text(
                      l.nutritionReasonsTitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
                    ),
                    const SizedBox(height: Space.s),
                    for (final r in risk.reasons) NutritionReasonLine(reason: r),
                  ],
                ],
              ),
            ),
          ),

        // The next planned meal: one tap logs it as planned.
        if (next != null)
          stagger(
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: NextMealCard(outcome: next),
            ),
          )
        else if (plan.isEmpty && !fresh)
          stagger(
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: BodyCard(
                key: const ValueKey('nutrition.noPlan'),
                title: l.nutritionNoPlanTitle,
                icon: Icons.event_note_rounded,
                iconColor: p.plan,
                seed: 5.1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.nutritionNoPlanBody,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                    const SizedBox(height: Space.m),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MadarButton(
                        label: l.nutritionMakePlan,
                        icon: Icons.event_note_rounded,
                        variant: MadarButtonVariant.secondary,
                        size: MadarButtonSize.small,
                        onPressed: () => nutritionGo(context, ref, NutritionDestination.plan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        stagger(BodySectionTitle(l.nutritionTodayTitle, icon: Icons.format_list_bulleted_rounded)),
        if (entries.isEmpty)
          stagger(BodyHint(l.nutritionTodayEmptyBody, icon: Icons.restaurant_outlined, color: t.textTertiary))
        else
          for (final e in entries)
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: FoodEntryTile(entry: e),
              ),
            ),

        stagger(BodySectionTitle(l.nutritionTitle, icon: Icons.auto_awesome_rounded)),
        stagger(
          NutritionToolTiles(
            tools: [
              (
                Icons.menu_book_rounded,
                l.nutritionOpenLibrary,
                l.nutritionOpenLibraryHint,
                () => nutritionGo(context, ref, NutritionDestination.library),
              ),
              (
                Icons.event_note_rounded,
                l.nutritionOpenPlan,
                l.nutritionOpenPlanHint,
                () => nutritionGo(context, ref, NutritionDestination.plan),
              ),
              (
                Icons.rule_rounded,
                l.nutritionOpenRules,
                l.nutritionOpenRulesHint,
                () => nutritionGo(context, ref, NutritionDestination.rules),
              ),
              (
                Icons.insights_rounded,
                l.nutritionOpenInsights,
                l.nutritionOpenInsightsHint,
                () => nutritionGo(context, ref, NutritionDestination.insights),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The next meal of the plan still ahead today, with «أكلتها» on it.
class NextMealCard extends ConsumerWidget {
  const NextMealCard({super.key, required this.outcome});

  final SlotOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final slot = outcome.slot;
    final foods = tx.plannedFoods([for (final f in slot.foods) f.name]);
    return BodyCard(
      key: const ValueKey('nutrition.nextMeal'),
      title: l.nutritionNextMeal,
      icon: Icons.restaurant_menu_rounded,
      iconColor: p.plan,
      seed: 5.6,
      trailing: BodyPill(label: tx.clock(slot.timeMinutes), icon: Icons.schedule_rounded, color: p.plan, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(slot.name, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(
            foods == null ? l.nutritionSlotNoFoods : l.nutritionSlotPlanned(foods),
            style: text.bodySmall?.copyWith(color: foods == null ? t.textTertiary : t.textSecondary),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: MadarButton(
                  key: const ValueKey('nutrition.nextMeal.ate'),
                  label: l.nutritionAteIt,
                  icon: Icons.check_rounded,
                  variant: MadarButtonVariant.primary,
                  size: MadarButtonSize.small,
                  sfx: Sfx.complete,
                  semanticLabel: l.nutritionAteItLabel(tx.name(slot.name)),
                  onPressed: foods == null
                      ? null
                      : () async {
                          final action = await NutritionActions.logSlotAsPlanned(context, ref, slot);
                          if (action != null && context.mounted) await showUndoToast(context, action);
                        },
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  label: l.nutritionLogSaveMore,
                  icon: Icons.edit_outlined,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => NutritionActions.quickLog(context, ref, slotId: slot.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One logged entry: its time, its amount and – only where a rating exists –
/// its own level.
class FoodEntryTile extends ConsumerWidget {
  const FoodEntryTile({super.key, required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final food = entry.foodId == null ? null : ref.watch(nutritionFoodsByIdProvider)[entry.foodId];
    final hasRating = ref.watch(nutritionHasRatingProvider);
    // A rating with a zero score has no reason behind it – and a verdict
    // without its reason is exactly what this screen must never show. So
    // nothing at all appears on a row no rule of his touched.
    final full = hasRating ? ref.watch(nutritionEntryRiskProvider(entry)) : null;
    final rating = full == null || full.score <= 0 ? null : full;
    final line = tx.entryLine(entry, food: food);
    return ActionableItem(
      key: ValueKey('nutrition.entry.${entry.id}'),
      semanticLabel: '${entry.name}, $line${rating == null ? '' : ', ${tx.level(rating.level)}'}',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => NutritionActions.editEntry(context, ref, entry),
      actions: ItemActions(
        onEdit: () => NutritionActions.editEntry(context, ref, entry),
        onDelete: () => NutritionActions.deleteEntry(context, ref, entry),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.nutritionDelete,
          tone: ActionTone.danger,
          onPressed: () => NutritionActions.deleteEntry(context, ref, entry),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48 - 2 * (Space.s + 2)),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, size: 18, color: p.food),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(line, style: text.labelMedium?.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
                // Nothing at all when he has written no rule.
                if (rating != null) ...[
                  const SizedBox(width: Space.s),
                  NutritionLevelPill(level: rating.level, dense: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A plan slot's row inside a day's planned-vs-eaten list.
class SlotOutcomeTile extends ConsumerWidget {
  const SlotOutcomeTile({super.key, required this.outcome, this.onLogPlanned});

  final SlotOutcome outcome;

  /// Shown only for a slot still ahead (or missed) on a day he can log.
  final Future<void> Function()? onLogPlanned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final slot = outcome.slot;
    final planned = tx.plannedFoods([for (final f in slot.foods) f.name]);
    final ate = tx.plannedFoods([for (final e in outcome.entries) e.name]);
    final late = outcome.status == SlotStatus.eatenLate ? tx.lateBy(outcome.lateBy) : null;
    return GlassCard(
      key: ValueKey('nutrition.slotOutcome.${slot.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      borderRadius: BorderRadius.circular(t.radiusL),
      semanticLabel: '${slot.name}, ${tx.clock(slot.timeMinutes)}, ${tx.status(outcome.status)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(nutritionStatusIcon(outcome.status), size: 18, color: p.status(outcome.status)),
                const SizedBox(width: Space.s),
                Expanded(child: Text(slot.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(tx.clock(slot.timeMinutes), style: text.labelMedium?.copyWith(color: t.textTertiary)),
              ],
            ),
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                NutritionStatusChip(status: outcome.status),
                if (late != null) BodyPill(label: late, icon: Icons.schedule_rounded, color: t.warning, dense: true),
              ],
            ),
            if (planned != null) ...[
              const SizedBox(height: Space.s),
              Text(l.nutritionSlotPlanned(planned), style: text.bodySmall?.copyWith(color: t.textSecondary)),
            ],
            if (ate != null) ...[
              const SizedBox(height: 2),
              Text(l.nutritionAteInstead(ate), style: text.bodySmall?.copyWith(color: t.textSecondary)),
            ],
            if (onLogPlanned != null && planned != null && !outcome.eaten) ...[
              const SizedBox(height: Space.m),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MadarButton(
                  key: ValueKey('nutrition.slotOutcome.${slot.id}.ate'),
                  label: l.nutritionAteIt,
                  icon: Icons.check_rounded,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  sfx: Sfx.complete,
                  semanticLabel: l.nutritionAteItLabel(tx.name(slot.name)),
                  onPressed: () => onLogPlanned!(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
