import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_providers.dart';
import '../domain/project_math.dart';
import 'widgets/project_widgets.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';

/// One project: progress ring and deadline countdown, description, status
/// and planet; the checklist (tick with a celebration at 100 %, drag to
/// reorder, due dates, add inline); and the project's tasks placed in
/// prayer windows.
class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({super.key, required this.projectId, this.onDeleted});

  final String projectId;

  /// Called after the project was deleted from its menu (default: pop).
  final VoidCallback? onDeleted;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  final _ring = GlobalKey();
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _add.text;
    _add.clear();
    await WorkActions.addItem(context, ref, widget.projectId, body);
    if (mounted) _addFocus.requestFocus();
  }

  Future<void> _menu(ProjectRow p, WorkTexts texts) async {
    final l = texts.l;
    final target = await showMoveSheet(
      context,
      title: p.name,
      icon: Icons.tune_rounded,
      targets: [
        MoveTarget(id: 'edit', label: l.workEditProject, icon: Icons.edit_rounded),
        MoveTarget(id: 'status', label: l.workSetStatus, icon: Icons.flag_circle_rounded),
        MoveTarget(id: 'dup', label: l.actionDuplicate, icon: Icons.copy_rounded),
        MoveTarget(id: 'delete', label: l.actionDelete, icon: Icons.delete_outline_rounded),
      ],
    );
    if (target == null || !mounted) return;
    UndoableAction? action;
    switch (target.id) {
      case 'edit':
        await WorkActions.editProject(context, ref, p);
      case 'status':
        action = await WorkActions.pickStatus(context, ref, p);
      case 'dup':
        action = await WorkActions.duplicateProject(context, ref, p);
      case 'delete':
        Fx.fire(Sfx.delete);
        action = await WorkActions.deleteProject(context, ref, p);
        if (mounted) widget.onDeleted != null ? widget.onDeleted!() : Navigator.of(context).maybePop();
    }
    if (action != null && mounted) unawaited(showUndoToast(context, action));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workCardTaskSyncProvider);
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final view = ref.watch(workProjectProvider(widget.projectId));
    final items = ref.watch(workProjectItemsProvider(widget.projectId)).value ?? const <ProjectItemRow>[];
    final tasks = ref.watch(workProjectTasksProvider(widget.projectId)).value ?? const <TaskRow>[];
    final planets = ref.watch(workPlanetsProvider).value ?? const <PlanetRow>[];
    final today = ref.watch(workTodayProvider);
    final pv = view.value;

    if (pv == null) {
      return MadarScaffold(
        title: l.workProjects,
        body: view.isLoading
            ? const Center(child: OrbitLoader())
            : AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.workProjectMissing),
      );
    }
    final p = pv.row;
    final prog = pv.progress;
    final color = workColor(t, p.color);
    final done = p.status == ProjectStatus.done;
    final planetKey = ProjectRules.planetOf(p.planetKey);
    final planet = planets.where((x) => x.key == planetKey).firstOrNull;

    final header = GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      borderColor: prog.complete ? t.success.withValues(alpha: 0.5) : color.withValues(alpha: 0.45),
      glowColor: (prog.complete ? t.success : color).withValues(alpha: 0.25),
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                key: _ring,
                value: prog.fraction,
                size: 112,
                strokeWidth: 9,
                color: prog.complete ? t.success : color,
                gradientEnd: prog.complete ? null : Color.lerp(color, t.gold, 0.5),
                glow: true,
                semanticLabel: l.workChecklist,
                semanticValue: texts.fmt.formatPercent(prog.fraction),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prog.complete)
                      Icon(Icons.check_rounded, color: t.success, size: 34)
                    else
                      Text(
                        texts.fmt.formatPercent(prog.fraction),
                        style: MadarTypography.numerals(t, size: 24).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                      ),
                    if (prog.total > 0)
                      Text(
                        l.workTop3Progress(texts.n(prog.done), texts.n(prog.total)),
                        style: text.labelSmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.xl),
              Expanded(child: CountdownBlock(deadline: p.deadline, today: today, done: done)),
            ],
          ),
          if ((p.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: Space.l),
            Text(p.description!.trim(), style: text.bodyMedium),
          ],
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              WorkPill(
                label: texts.status(p.status),
                icon: workStatusIcon(p.status),
                color: done ? t.success : (p.status == ProjectStatus.paused ? t.info : t.accent),
                dense: false,
              ),
              WorkPill(
                label: planet == null ? l.planetWork : texts.planet(planet),
                leading: ColorOrb(color: planet == null ? t.accent : Color(planet.color), size: 9),
                dense: false,
              ),
            ],
          ),
        ],
      ),
    );

    final checklist = ReorderableGlassList<ProjectItemRow>(
      items: items,
      itemKey: (i) => i.id,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.zero,
      onReorder: (order) {
        Fx.fire(Sfx.drop);
        ref.read(workServiceProvider).reorderItems([for (final i in order) i.id]);
      },
      itemBuilder: (context, item, index, grip) => _ItemRow(item: item, grip: grip, today: today, ring: _ring),
    );

    return MadarScaffold(
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorOrb(color: color, size: 12),
          const SizedBox(width: Space.s),
          Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge)),
        ],
      ),
      actions: [
        MadarButton.icon(
          icon: Icons.edit_rounded,
          semanticLabel: l.workEditProject,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => WorkActions.editProject(context, ref, p),
        ),
        MadarButton.icon(
          icon: Icons.more_horiz_rounded,
          semanticLabel: l.workSetStatus,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => _menu(p, texts),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(index: 0, child: header),
          const SizedBox(height: Space.l),
          SectionHeader(
            title: l.workChecklist,
            subtitle: prog.total == 0 ? null : l.workItemsProgress(texts.n(prog.done), texts.n(prog.total)),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s, horizontal: Space.xs),
              child: Text(l.workChecklistEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            )
          else
            checklist,
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _add,
                  focusNode: _addFocus,
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: kitInputDecoration(context, hint: l.workAddItemHint),
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.add_rounded,
                semanticLabel: l.workAddItem,
                variant: MadarButtonVariant.primary,
                sfx: Sfx.tap,
                onPressed: _submit,
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          // The action sits under the title: beside it, "Task in a prayer
          // window" ran past a phone's width in English.
          SectionHeader(title: l.workProjectTasks),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: l.workAddProjectTask,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: () => WorkActions.addProjectTask(context, ref, p),
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s, horizontal: Space.xs),
              child: Text(l.workProjectTasksEmpty, style: text.bodySmall),
            )
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: _TaskRow(task: task, today: today),
              ),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.grip, required this.today, required this.ring});

  final ProjectItemRow item;
  final Widget grip;
  final DateTime today;
  final GlobalKey ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = WorkTexts.of(context).l;
    final text = Theme.of(context).textTheme;
    Future<UndoableAction?> toggle() => WorkActions.toggleItem(context, ref, item, celebrateFrom: ring.currentContext);
    return ActionableItem(
      onTap: () async {
        final a = await toggle();
        if (a != null && context.mounted) unawaited(showUndoToast(context, a));
      },
      onCompleteSwipe: item.done ? null : toggle,
      borderRadius: BorderRadius.circular(t.radiusM),
      // No semanticLabel: the row's own texts are its label (a title-only
      // label made screen readers read the title twice).
      actions: ItemActions(
        onEdit: () async {
          final a = await WorkActions.editItem(context, ref, item);
          if (a != null && context.mounted) unawaited(showUndoToast(context, a));
        },
        onDelete: () => WorkActions.deleteItem(context, ref, item),
      ),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.xs, Space.xs),
        decoration: BoxDecoration(
          color: item.done ? t.success.withValues(alpha: 0.06) : t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: item.done ? t.success.withValues(alpha: 0.3) : t.glassBorder),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: context.motion(MadarMotion.short),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.done ? t.success : Colors.transparent,
                border: Border.all(color: item.done ? t.success : t.textTertiary, width: 1.6),
              ),
              child: item.done ? Icon(Icons.check_rounded, size: 15, color: t.textOnAccent) : null,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.body,
                      style: text.bodyMedium!.copyWith(
                        color: item.done ? t.textTertiary : t.textPrimary,
                        decoration: item.done ? TextDecoration.lineThrough : null,
                        decorationColor: t.textTertiary,
                      ),
                    ),
                    if (item.dueDate != null) ...[
                      const SizedBox(height: Space.xs),
                      DueBadge(due: item.dueDate!, today: today, done: item.done),
                    ],
                  ],
                ),
              ),
            ),
            Semantics(label: l.workChecklist, child: grip),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.today});

  final TaskRow task;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return ActionableItem(
      onTap: () async {
        final a = await WorkActions.toggleTask(context, ref, task);
        if (a != null && context.mounted) unawaited(showUndoToast(context, a));
      },
      onCompleteSwipe: task.done ? null : () => WorkActions.toggleTask(context, ref, task),
      borderRadius: BorderRadius.circular(t.radiusM),
      // No semanticLabel: the row's own texts are its label (a title-only
      // label made screen readers read the title twice).
      actions: ItemActions(
        onMove: () => WorkActions.moveTask(context, ref, task),
        onDelete: () => WorkActions.deleteTask(context, ref, task),
      ),
      child: Container(
        // A 48 dp target (Android) for a one-line task.
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder),
        ),
        child: Row(
          children: [
            Icon(
              task.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: task.done ? t.success : t.textTertiary,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(
                  color: task.done ? t.textTertiary : t.textPrimary,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            WindowPill(window: task.window, day: task.date, today: today),
          ],
        ),
      ),
    );
  }
}
