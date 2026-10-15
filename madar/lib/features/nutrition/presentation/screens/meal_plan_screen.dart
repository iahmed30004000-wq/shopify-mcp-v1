import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show KitChip;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/domain/body_week.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_compare.dart';
import '../nutrition_actions.dart';
import '../nutrition_texts.dart';
import '../tabs/food_tab.dart';
import '../widgets/nutrition_widgets.dart';

enum MealPlanTab { build, compare }

/// The meal plan: build it (slots with a time, weekdays, planned foods and
/// a reminder of their own), then see the plan against what he actually ate
/// – today and the last seven days.
class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key, this.initialTab = MealPlanTab.build, this.animateBackdrop = true});

  final MealPlanTab initialTab;
  final bool animateBackdrop;

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late MealPlanTab _tab = widget.initialTab;
  String? _planId;

  /// The plan being edited: the one he picked, else the active one, else the
  /// first he has.
  MealPlan _editing(List<MealPlan> plans) {
    final picked = _planId;
    if (picked != null) {
      final found = plans.where((p) => p.id == picked).firstOrNull;
      if (found != null) return found;
    }
    final active = MealPlan.activeOf(plans);
    if (!active.isEmpty) return active;
    return plans.isEmpty ? MealPlan.none : plans.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    ref.watch(nutritionReminderSyncProvider);
    final plans = ref.watch(nutritionPlansProvider);
    final editing = _editing(plans);
    return MadarScaffold(
      title: l.nutritionPlanTitle,
      backdropSeed: 8.2,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: _tab != MealPlanTab.build
          ? null
          : MadarButton.icon(
              key: const ValueKey('nutrition.plan.fab'),
              icon: Icons.add_rounded,
              semanticLabel: editing.isEmpty ? l.nutritionAddPlan : l.nutritionAddSlot,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: editing.isEmpty
                  ? () => NutritionActions.addPlan(context, ref)
                  : () => NutritionActions.addSlot(context, ref, editing.id),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: BodyTabBar<MealPlanTab>(
              tabs: MealPlanTab.values,
              value: _tab,
              labels: {MealPlanTab.build: l.nutritionPlanTabBuild, MealPlanTab.compare: l.nutritionPlanTabCompare},
              icons: const {
                MealPlanTab.build: Icons.event_note_rounded,
                MealPlanTab.compare: Icons.fact_check_outlined,
              },
              onChanged: (tab) {
                Fx.fire(Sfx.navigate);
                setState(() => _tab = tab);
              },
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: MadarFadeStack(
                index: _tab.index,
                children: [
                  _PlanBuilder(
                    key: const ValueKey('nutrition.plan.build'),
                    plans: plans,
                    editing: editing,
                    onPick: (id) => setState(() => _planId = id),
                  ),
                  const PlanCompareView(key: ValueKey('nutrition.plan.compare')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBuilder extends ConsumerWidget {
  const _PlanBuilder({super.key, required this.plans, required this.editing, required this.onPick});

  final List<MealPlan> plans;
  final MealPlan editing;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    if (plans.isEmpty) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, nutritionBottomPadding),
        children: [
          AnimatedEmptyState(
            key: const ValueKey('nutrition.plan.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.nutritionPlansEmptyTitle,
            body: l.nutritionPlansEmptyBody,
            actionLabel: l.nutritionAddPlan,
            actionIcon: Icons.add_rounded,
            onAction: () => NutritionActions.addPlan(context, ref),
          ),
        ],
      );
    }
    final slots = editing.ordered;
    return ReorderableGlassList<MealSlot>(
      items: slots,
      itemKey: (s) => s.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, nutritionBottomPadding),
      spacing: Space.s,
      itemBorderRadius: BorderRadius.circular(t.radiusL),
      header: Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (plans.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final plan in plans)
                      MadarChip(
                        key: ValueKey('nutrition.plan.pick.${plan.id}'),
                        label: plan.name,
                        selected: plan.id == editing.id,
                        dense: true,
                        icon: plan.active ? Icons.play_circle_fill_rounded : null,
                        onSelected: (_) => onPick(plan.id),
                      ),
                  ],
                ),
              ),
            PlanHeaderCard(plan: editing),
            BodySectionTitle(
              l.nutritionPlanTabBuild,
              icon: Icons.restaurant_menu_rounded,
              trailing: BodyPill(
                label: tx.fmt.localizeDigits(l.nutritionSlotsCount(slots.length, tx.fmt.formatInt(slots.length))),
                color: p.plan,
                dense: true,
              ),
            ),
          ],
        ),
      ),
      footer: slots.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                key: const ValueKey('nutrition.plan.noSlots'),
                kind: EmptyStateKind.emptyList,
                title: l.nutritionSlotsEmptyTitle,
                body: l.nutritionSlotsEmptyBody,
                actionLabel: l.nutritionAddSlot,
                actionIcon: Icons.add_rounded,
                onAction: () => NutritionActions.addSlot(context, ref, editing.id),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: BodyHint(l.nutritionSlotRemindHint, icon: Icons.notifications_active_outlined),
            ),
      onReorder: (order) => NutritionActions.reorderSlots(ref, [for (final s in order) s.id]),
      itemBuilder: (context, slot, index, grip) => MealSlotTile(slot: slot, grip: grip),
    );
  }
}

/// The plan itself: its name, whether it is the active one, and what can be
/// done with it.
class PlanHeaderCard extends ConsumerWidget {
  const PlanHeaderCard({super.key, required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = NutritionPalette.of(context);
    final notes = plan.notes;
    Future<void> run(Future<UndoableAction?> Function() work) async {
      final action = await work();
      if (action != null && context.mounted) await showUndoToast(context, action);
    }

    return BodyCard(
      key: ValueKey('nutrition.plan.header.${plan.id}'),
      title: plan.name,
      icon: Icons.event_note_rounded,
      iconColor: p.plan,
      seed: 8.2,
      trailing: BodyPill(
        label: plan.active ? l.nutritionActiveLabel : l.nutritionDraftLabel,
        icon: plan.active ? Icons.play_circle_fill_rounded : Icons.edit_note_rounded,
        color: plan.active ? t.success : t.textTertiary,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notes != null && notes.isNotEmpty) ...[
            Text(notes, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.m),
          ],
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                key: ValueKey('nutrition.plan.activate.${plan.id}'),
                label: plan.active ? l.nutritionDeactivate : l.nutritionActivate,
                icon: plan.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                variant: plan.active ? MadarButtonVariant.secondary : MadarButtonVariant.primary,
                size: MadarButtonSize.small,
                onPressed: () => run(() => NutritionActions.setPlanActive(context, ref, plan, !plan.active)),
              ),
              MadarButton(
                label: l.nutritionEdit,
                icon: Icons.edit_outlined,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => NutritionActions.editPlan(context, ref, plan),
              ),
              MadarButton(
                label: l.nutritionDuplicate,
                icon: Icons.copy_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () => run(() => NutritionActions.duplicatePlan(context, ref, plan)),
              ),
              MadarButton(
                key: ValueKey('nutrition.plan.delete.${plan.id}'),
                label: l.nutritionDelete,
                icon: Icons.delete_outline_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () => run(() => NutritionActions.deletePlan(context, ref, plan)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One meal of the plan: its time, its weekdays, the foods he planned for it
/// and its own reminder switch.
class MealSlotTile extends ConsumerWidget {
  const MealSlotTile({super.key, required this.slot, this.grip});

  final MealSlot slot;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    return ActionableItem(
      key: ValueKey('nutrition.slot.${slot.id}'),
      semanticLabel: '${slot.name}, ${tx.clock(slot.timeMinutes)}, ${tx.weekdays(BodyWeek.inDisplayOrder(slot.weekdays, start))}',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => NutritionActions.editSlot(context, ref, slot),
      actions: ItemActions(
        onEdit: () => NutritionActions.editSlot(context, ref, slot),
        onDelete: () => NutritionActions.deleteSlot(context, ref, slot),
        extra: [
          ItemAction(
            icon: Icons.add_rounded,
            label: l.nutritionAddSlotFood,
            onSelected: () async {
              await NutritionActions.addSlotFood(context, ref, slot);
              return null;
            },
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.nutritionDelete,
          tone: ActionTone.danger,
          onPressed: () => NutritionActions.deleteSlot(context, ref, slot),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 4, Space.s, 4),
                    decoration: BoxDecoration(
                      color: p.plan.withValues(alpha: t.isDark ? 0.14 : 0.10),
                      borderRadius: BorderRadius.circular(t.radiusS),
                      border: Border.all(color: p.plan.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      tx.clock(slot.timeMinutes),
                      style: text.labelMedium?.copyWith(color: p.plan, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(slot.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                MadarSwitch(
                  key: ValueKey('nutrition.slot.${slot.id}.remind'),
                  value: slot.remind,
                  semanticLabel: '${l.nutritionSlotRemind}: ${slot.name}',
                  onChanged: (_) async {
                    final action = await NutritionActions.toggleRemind(context, ref, slot);
                    if (action != null && context.mounted) await showUndoToast(context, action);
                  },
                ),
                ?grip,
              ],
            ),
            const SizedBox(height: Space.s),
            ExcludeSemantics(child: WeekdayDots(weekdays: slot.weekdays, color: p.plan, size: 18)),
            const SizedBox(height: Space.s),
            if (slot.foods.isEmpty)
              BodyHint(l.nutritionSlotNoFoods, icon: Icons.restaurant_outlined, color: t.textTertiary)
            else
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final f in slot.foods)
                    KitChip(
                      key: ValueKey('nutrition.slotFood.${f.id}'),
                      label: [f.name, ?tx.portion(f.portion, f.unit)].join(tx.sep),
                      selected: false,
                      dense: true,
                      icon: Icons.restaurant_rounded,
                      removeLabel: l.nutritionSlotFoodRemove(tx.name(f.name)),
                      onTap: () => NutritionActions.addSlotFood(context, ref, slot),
                      onRemove: () async {
                        final action = await NutritionActions.deleteSlotFood(context, ref, f);
                        if (action != null && context.mounted) await showUndoToast(context, action);
                      },
                    ),
                ],
              ),
            const SizedBox(height: Space.s),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarButton(
                key: ValueKey('nutrition.slot.${slot.id}.addFood'),
                label: l.nutritionAddSlotFood,
                icon: Icons.add_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => NutritionActions.addSlotFood(context, ref, slot),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Planned against eaten: today by default, any of the last seven days on a
/// tap, each slot with what became of it and everything eaten off plan.
class PlanCompareView extends ConsumerStatefulWidget {
  const PlanCompareView({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  ConsumerState<PlanCompareView> createState() => _PlanCompareViewState();
}

class _PlanCompareViewState extends ConsumerState<PlanCompareView> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final today = ref.watch(nutritionTodayProvider);
    final week = ref.watch(nutritionWeekPlanProvider);
    final day = _day ?? widget.initialDay ?? today;
    final chosen = ref.watch(nutritionDayPlanProvider(day));
    final hasPlan = !ref.watch(nutritionActivePlanProvider).isEmpty;

    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, fade: false, child: child);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, nutritionBottomPadding),
      children: [
        stagger(
          BodyCard(
            title: l.nutritionLast7Days,
            icon: Icons.calendar_month_rounded,
            iconColor: p.plan,
            seed: 8.8,
            child: Row(
              children: [
                for (final d in week)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 2),
                      child: _DayCell(
                        plan: d,
                        today: today,
                        selected: d.day.year == day.year && d.day.month == day.month && d.day.day == day.day,
                        onTap: () => setState(() => _day = d.day),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        stagger(
          BodySectionTitle(
            tx.day(day, today),
            icon: Icons.fact_check_outlined,
            trailing: BodyPill(
              label: tx.adherence(chosen.adherence),
              icon: Icons.verified_outlined,
              color: p.plan,
              dense: true,
            ),
          ),
        ),
        if (!hasPlan)
          stagger(
            AnimatedEmptyState(
              key: const ValueKey('nutrition.compare.noPlan'),
              kind: EmptyStateKind.noData,
              title: l.nutritionNoPlanTitle,
              body: l.nutritionCompareNoPlanBody,
            ),
          )
        else if (chosen.outcomes.isEmpty)
          stagger(BodyHint(l.nutritionDayNothing, icon: Icons.event_busy_rounded, color: t.textTertiary))
        else
          for (final o in chosen.outcomes)
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SlotOutcomeTile(
                  outcome: o,
                  onLogPlanned: o.status == SlotStatus.pending || o.status == SlotStatus.skipped
                      ? () async {
                          final action = await NutritionActions.logSlotAsPlanned(
                            context,
                            ref,
                            o.slot,
                            at: o.plannedAt,
                          );
                          if (action != null && context.mounted) await showUndoToast(context, action);
                        }
                      : null,
                ),
              ),
            ),
        stagger(BodySectionTitle(l.nutritionUnplannedTitle, icon: Icons.open_in_new_rounded)),
        if (chosen.unplanned.isEmpty)
          stagger(BodyHint(l.nutritionDayNothing, icon: Icons.check_rounded, color: t.textTertiary))
        else
          for (final e in chosen.unplanned)
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: FoodEntryTile(entry: e),
              ),
            ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.plan, required this.today, required this.selected, required this.onTap});

  final DayPlan plan;
  final DateTime today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final text = Theme.of(context).textTheme;
    final adherence = plan.adherence;
    final color = adherence == null
        ? t.textTertiary
        : (adherence >= 0.75 ? t.success : (adherence >= 0.4 ? t.warning : t.danger));
    final isToday = plan.day.year == today.year && plan.day.month == today.month && plan.day.day == today.day;
    return MadarPressable(
      semanticLabel: '${tx.day(plan.day, today)}, ${tx.adherence(adherence)}',
      selected: selected,
      sfx: Sfx.tap,
      excludeChildSemantics: true,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: selected ? color.withValues(alpha: t.isDark ? 0.18 : 0.12) : t.glassFill,
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : (isToday ? t.textPrimary.withValues(alpha: 0.5) : t.glassBorder),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tx.weekdayTiny(plan.day.weekday),
              style: text.labelSmall?.copyWith(color: t.textSecondary),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: adherence == null ? Colors.transparent : color,
                border: Border.all(color: color.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
