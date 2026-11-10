/// «أيام التمرين» · his named training days (Part 8, «#24 – Body / gym»).
///
/// A day is his: a name («يوم صدر»), the weekdays it falls on, and his own
/// exercises in the order he wants to do them — each with the numbers that
/// day gives it, or the exercise's own when he leaves them empty.
///
/// Nothing of ours is written: a fresh install has no day until he builds
/// one, and the plan he already had by weekday keeps working beside them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/body_week.dart';
import '../../domain/gym.dart';
import '../../domain/training.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../gym_actions.dart';
import '../gym_texts.dart';
import '../widgets/body_widgets.dart';
import '../widgets/gym_widgets.dart';

/// His training days, in his own order.
class GymTemplatesScreen extends ConsumerWidget {
  const GymTemplatesScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final templates = ref.watch(bodyTemplatesProvider);
    return MadarScaffold(
      title: l.gymTemplatesTitle,
      backdropSeed: 5.6,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      floatingAction: MadarButton.icon(
        key: const ValueKey('gym.templates.add'),
        icon: Icons.add_rounded,
        semanticLabel: l.gymAddTemplate,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => unawaited(GymActions.editTemplate(context, ref)),
      ),
      body: templates.isEmpty
          ? Center(
              child: AnimatedEmptyState(
                key: const ValueKey('gym.templates.empty'),
                kind: EmptyStateKind.emptyList,
                title: l.gymTemplatesEmptyTitle,
                body: l.gymTemplatesEmptyBody,
                actionLabel: l.gymAddTemplate,
                actionIcon: Icons.add_rounded,
                onAction: () => unawaited(GymActions.editTemplate(context, ref)),
              ),
            )
          : ReorderableGlassList<WorkoutTemplate>(
              key: const ValueKey('gym.templates.list'),
              items: templates,
              itemKey: (t) => t.id,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
              spacing: Space.s,
              header: Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: BodyHint(l.gymTemplatesSubtitle, icon: Icons.event_note_rounded),
              ),
              onReorder: (order) =>
                  ref.read(bodyServiceProvider).reorderTemplates([for (final t in order) t.id]),
              itemBuilder: (context, template, index, grip) => _TemplateCard(template: template, grip: grip),
            ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template, this.grip});

  final WorkoutTemplate template;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final day = template;
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    final days = day.weekdays.isEmpty
        ? l.gymTemplateNoDays
        : tx.weekdayList(BodyWeek.inDisplayOrder(day.weekdays, start));
    final library = {for (final e in ref.watch(bodyExercisesProvider)) e.id: e};
    return ActionableItem(
      key: ValueKey('gym.template.${day.id}'),
      semanticLabel: [day.name, days, tx.fmt.localizeDigits(l.gymTemplateCount(day.items.length))].join('. '),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => unawaited(
        GymActions.editTemplate(context, ref, row: ref.read(bodyTemplateRowsProvider).value?.where((r) => r.id == day.id).firstOrNull),
      ),
      actions: ItemActions(
        onEdit: () => unawaited(
          GymActions.editTemplate(context, ref, row: ref.read(bodyTemplateRowsProvider).value?.where((r) => r.id == day.id).firstOrNull),
        ),
        onDelete: () => GymActions.deleteTemplate(context, ref, day.id),
        extra: [
          ItemAction(
            icon: Icons.add_rounded,
            label: l.gymAddTemplateItem,
            tone: ActionTone.info,
            onSelected: () async {
              await GymActions.addTemplateItem(context, ref, day.id);
              return null;
            },
          ),
          ItemAction(
            icon: day.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: day.active ? l.bodyPause : l.bodyResume,
            tone: day.active ? ActionTone.warning : ActionTone.success,
            onSelected: () => GymActions.toggleTemplateActive(context, ref, day.id),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.add_rounded,
          label: l.gymAddTemplateItem,
          tone: ActionTone.info,
          onPressed: () async {
            await GymActions.addTemplateItem(context, ref, day.id);
            return null;
          },
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => GymActions.deleteTemplate(context, ref, day.id),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(day.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                          if (!day.active) ...[
                            const SizedBox(width: Space.xs),
                            BodyPill(label: l.bodyPaused, icon: Icons.pause_rounded, color: t.warning, dense: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      WeekdayDots(weekdays: day.weekdays, color: p.training, size: 19, dimmed: !day.active),
                      const SizedBox(height: Space.xs),
                      Text(
                        '$days${tx.sep}${tx.fmt.localizeDigits(l.gymTemplateCount(day.items.length))}',
                        style: text.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                ?grip,
              ],
            ),
            if (day.items.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              for (final item in day.items)
                _ItemRow(item: item, exercise: library[item.exerciseId]),
            ],
            if (day.notes != null) ...[
              const SizedBox(height: Space.xs),
              Text(day.notes!, style: text.bodySmall?.copyWith(color: t.textTertiary), maxLines: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// One exercise inside the day: its name, the numbers this day gives it,
/// and the two things he can do to it.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.exercise});

  final TemplateExercise item;
  final PlannedExercise? exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = BodyTexts.of(context);
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final effective = e == null ? null : item.applyTo(e);
    final name = e?.name ?? l.gymPickExercise;
    final numbers = effective == null ? '' : tx.planSummary(effective);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.xs, bottom: 2),
      child: Row(
        children: [
          GymPhotoView(photo: e?.photo, name: name, size: 34),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (numbers.isNotEmpty)
                  Text(
                    [
                      numbers,
                      if (effective?.restSec != null) '${l.gymRestShort} ${gx.seconds(effective!.restSec!)}',
                    ].join(tx.sep),
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          MadarButton.icon(
            key: ValueKey('gym.template.item.numbers.${item.id}'),
            icon: Icons.tune_rounded,
            semanticLabel: '${l.gymTemplateItemNumbers}: $name',
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetOpen,
            onPressed: () => unawaited(GymActions.editTemplateItem(context, ref, item.id)),
          ),
          MadarButton.icon(
            key: ValueKey('gym.template.item.remove.${item.id}'),
            icon: Icons.remove_circle_outline_rounded,
            semanticLabel: '${l.bodyDelete}: $name',
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            onPressed: () => unawaited(_remove(context, ref, name)),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final undo = await GymActions.removeTemplateItem(context, ref, item.id, name);
    if (undo != null && context.mounted) await showUndoToast(context, undo);
  }
}
