import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/meds_providers.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'meds_actions.dart';
import 'widgets/meds_widgets.dart';

/// Every medication (drag to reorder; tap for its history; long-press or
/// swipe for edit, duplicate, pause, delete), then the timing rules.
class MedsListView extends ConsumerWidget {
  const MedsListView({super.key, this.bottomPadding = 110});

  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final meds = ref.watch(medsListProvider).value;
    final rules = ref.watch(medRulesProvider).value ?? const <RuleSpec>[];
    final courses = ref.watch(medCoursesProvider).value ?? const <CourseSpec>[];
    if (meds == null) return const Center(child: OrbitLoader());
    if (meds.isEmpty) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xl, Space.gutter, bottomPadding),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.medsEmptyTitle,
            body: l.medsEmptyBody,
            actionLabel: l.medsAddMed,
            actionIcon: Icons.add_rounded,
            onAction: () => MedsActions.addMed(context, ref),
          ),
        ],
      );
    }
    String nameOf(String id) => meds.where((m) => m.id == id).firstOrNull?.name ?? '';
    return ReorderableGlassList<MedSpec>(
      items: meds,
      itemKey: (m) => m.id,
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomPadding),
      itemBorderRadius: BorderRadius.circular(context.tokens.radiusL),
      onReorder: (order) => unawaited(ref.read(medsServiceProvider).reorderMeds([for (final m in order) m.id])),
      itemBuilder: (context, med, index, handle) => MedCard(
        med: med,
        dragHandle: handle,
        course: courses.where((c) => c.medicationId == med.id || c.id == med.courseId).firstOrNull,
      ),
      footer: _RulesSection(rules: rules, nameOf: nameOf),
    );
  }
}

/// One medication in the list.
class MedCard extends ConsumerWidget {
  const MedCard({super.key, required this.med, this.dragHandle, this.course});

  final MedSpec med;
  final Widget? dragHandle;
  final CourseSpec? course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final sub = [
      if (med.dose != null) tx.dose(med.dose!),
      tx.kind(med.kind),
      if (med.takenWith != TakenWith.anytime) tx.takenWith(med.takenWith),
    ].join(' · ');
    final times = course != null
        ? [tx.phase(course!.phases.isEmpty ? const CoursePhase(frequency: CourseFrequency.daily) : course!.phases.first)]
        : [for (final s in med.slots) tx.slot(s)];
    return ActionableItem(
      semanticLabel: '${med.name}. $sub',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => MedsActions.openHistory(context, ref, med),
      actions: ItemActions(
        onEdit: () => MedsActions.editMed(context, ref, med),
        onDuplicate: () => MedsActions.duplicateMed(context, ref, med),
        onDelete: () => MedsActions.deleteMed(context, ref, med),
        extra: [
          ItemAction(
            icon: med.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: med.active ? l.medsPause : l.medsResume,
            onSelected: () => MedsActions.togglePause(context, ref, med),
            tone: med.active ? ActionTone.warning : ActionTone.success,
          ),
          if (med.stock != null)
            ItemAction(
              icon: Icons.inventory_2_rounded,
              label: l.medsRefilled,
              onSelected: () async {
                await MedsActions.refill(context, ref, med);
                return null;
              },
            ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: med.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: med.active ? l.medsPause : l.medsResume,
          onPressed: () => MedsActions.togglePause(context, ref, med),
          tone: ActionTone.warning,
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.medsDelete,
          onPressed: () => MedsActions.deleteMed(context, ref, med),
          tone: ActionTone.danger,
        ),
      ],
      child: AnimatedOpacity(
        duration: context.motion(MadarMotion.short),
        opacity: med.active ? 1 : 0.62,
        child: GlassCard(
          borderRadius: BorderRadius.circular(t.radiusL),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
          child: Row(
            children: [
              MedOrb(med: med, size: 44),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            med.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: BidiIsolate.directionOf(med.name),
                            style: text.titleMedium,
                          ),
                        ),
                        if (!med.active) ...[
                          const SizedBox(width: Space.xs),
                          MedBadge(label: l.medsPaused, color: t.textTertiary, icon: Icons.pause_rounded),
                        ],
                        if (med.active && med.needsRefill) ...[
                          const SizedBox(width: Space.xs),
                          MedBadge(label: l.medsLowStock, color: t.warning, icon: Icons.inventory_2_rounded, filled: true),
                        ],
                      ],
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                    if (times.isNotEmpty || med.asNeeded) ...[
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          if (course != null)
                            MedBadge(label: course!.name, color: t.info, icon: Icons.vaccines_rounded),
                          for (final s in times)
                            MedBadge(label: s, color: t.gold, icon: course == null ? Icons.schedule_rounded : Icons.repeat_rounded),
                          if (times.isEmpty) MedBadge(label: l.medsAsNeeded, color: t.textSecondary),
                        ],
                      ),
                    ],
                    if (med.stock != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        [
                          l.medsStockLine(fmt.formatInt(med.stock!)),
                          if (med.refillAt != null) l.medsRefillAtLine(fmt.formatInt(med.refillAt!)),
                        ].join(' · '),
                        style: text.labelSmall!.copyWith(color: med.needsRefill ? t.warning : t.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              ?dragHandle,
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesSection extends ConsumerWidget {
  const _RulesSection({required this.rules, required this.nameOf});

  final List<RuleSpec> rules;
  final String Function(String id) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final tx = MedsTexts(l, MadarFormatter.of(context));
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l.medsRulesTitle,
          actionLabel: l.medsAddRule,
          onAction: () => MedsActions.addRule(context, ref),
          padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.s),
        ),
        if (rules.isEmpty)
          Text(l.medsRulesEmpty, style: text.bodySmall!.copyWith(color: t.textSecondary)),
        for (final r in rules)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            child: ActionableItem(
              semanticLabel: tx.rule(r, nameOf),
              onTap: () => MedsActions.editRule(context, ref, r),
              actions: ItemActions(
                onEdit: () => MedsActions.editRule(context, ref, r),
                onDelete: () => MedsActions.deleteRule(context, ref, r),
              ),
              quickActions: [
                QuickAction(
                  icon: Icons.delete_outline_rounded,
                  label: l.medsDelete,
                  onPressed: () => MedsActions.deleteRule(context, ref, r),
                  tone: ActionTone.danger,
                ),
              ],
              child: GlassCard(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
                child: Row(
                  children: [
                    Icon(
                      switch (r.kind) {
                        MedRuleKind.separate => Icons.swap_horiz_rounded,
                        MedRuleKind.beforeFood || MedRuleKind.afterFood || MedRuleKind.withFood =>
                          Icons.restaurant_rounded,
                        MedRuleKind.custom => Icons.sticky_note_2_rounded,
                      },
                      size: 20,
                      color: t.accent,
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.rule(r, nameOf), style: text.bodyMedium!.copyWith(color: t.textPrimary)),
                          if (r.note != null && r.kind != MedRuleKind.custom)
                            Text(
                              r.note!,
                              textDirection: BidiIsolate.directionOf(r.note!),
                              style: text.bodySmall!.copyWith(color: t.textTertiary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
