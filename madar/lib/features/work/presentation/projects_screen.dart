import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import 'widgets/project_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';
import 'work_navigation.dart';

/// Every project: active ones in the user's order (drag to reorder), then
/// paused and finished ones. Tap opens a project; long-press for edit /
/// duplicate / status / delete; swipe to mark one done.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final projects = ref.watch(workProjectsProvider);
    final today = ref.watch(workTodayProvider);
    final list = projects.value;

    Widget body;
    if (list == null) {
      body = const Center(child: OrbitLoader());
    } else if (list.isEmpty) {
      body = Center(
        child: AnimatedEmptyState(
          kind: EmptyStateKind.emptyList,
          title: l.workProjectsEmptyTitle,
          body: l.workProjectsEmptyBody,
          actionLabel: l.workNewProject,
          actionIcon: Icons.add_rounded,
          onAction: () => WorkActions.newProject(context, ref),
        ),
      );
    } else {
      final active = [for (final p in list) if (p.row.status == ProjectStatus.active) p];
      final rest = [for (final p in list) if (p.row.status != ProjectStatus.active) p];
      body = ReorderableGlassList<ProjectView>(
        items: active,
        itemKey: (p) => p.id,
        onReorder: (order) {
          Fx.fire(Sfx.drop);
          ref.read(workServiceProvider).reorderProjects([for (final p in order) p.id]);
        },
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        itemBuilder: (context, p, index, grip) => ProjectRowItem(project: p, today: today, grip: grip),
        footer: rest.isEmpty
            ? null
            : StaggerIn(
                children: [
                  SectionHeader(title: '${l.workStatusPaused}${l.workSep}${l.workStatusDone}'),
                  for (final p in rest)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                      child: ProjectRowItem(project: p, today: today),
                    ),
                ],
              ),
      );
    }

    return MadarScaffold(
      title: l.workProjects,
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          semanticLabel: l.workNewProject,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => WorkActions.newProject(context, ref),
        ),
      ],
      body: body,
    );
  }
}

/// A project row with its interactions (used by the projects list and the
/// Work screen).
class ProjectRowItem extends ConsumerWidget {
  const ProjectRowItem({super.key, required this.project, required this.today, this.grip});

  final ProjectView project;
  final DateTime today;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = WorkTexts.of(context).l;
    final p = project.row;
    return ActionableItem(
      onTap: () => WorkNavigation.toProject(context, ref, p.id),
      onCompleteSwipe: p.status == ProjectStatus.done
          ? null
          : () async {
              final label = l.workStatusChanged(WorkTexts.of(context).status(ProjectStatus.done));
              final undo = await ref.read(workServiceProvider).setProjectStatus(p.id, ProjectStatus.done);
              Fx.fire(Sfx.levelUp);
              return UndoableAction(label: label, undo: undo);
            },
      completeLabel: l.workStatusDone,
      borderRadius: BorderRadius.circular(t.radiusM),
      // No semanticLabel: the row's own texts are its label (a title-only
      // label made screen readers read the title twice).
      actions: ItemActions(
        onEdit: () => WorkActions.editProject(context, ref, p),
        onDuplicate: () => WorkActions.duplicateProject(context, ref, p),
        onDelete: () => WorkActions.deleteProject(context, ref, p),
        extra: [
          ItemAction(
            icon: Icons.flag_circle_rounded,
            label: l.workSetStatus,
            onSelected: () => WorkActions.pickStatus(context, ref, p),
          ),
        ],
      ),
      child: ProjectTile(project: project, today: today, trailing: grip),
    );
  }
}
