import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../domain/project_math.dart';
import 'work_actions.dart';
import 'work_labels.dart';

/// Creates or edits a project (name, description, deadline, status, the
/// planet it feeds – Work by default – and colour) with the kit's edit
/// sheet; returns the draft (null when dismissed).
Future<ProjectDraft?> showProjectSheet(BuildContext context, WidgetRef ref, {ProjectRow? project}) async {
  final texts = WorkTexts.of(context);
  final l = texts.l;
  final List<PlanetRow> planets = ref.read(workPlanetsProvider).value ?? await ref.read(workPlanetsProvider.future);
  if (!context.mounted) return null;
  final res = await showEditSheet(
    context,
    title: project == null ? l.workNewProject : l.workEditProject,
    icon: Icons.rocket_launch_rounded,
    saveLabel: project == null ? l.workCreate : l.workSave,
    fields: [
      FieldSpec.text('name', l.workProjectName, required: true, hint: l.workProjectNameHint, maxLength: 80),
      FieldSpec.multiline('description', l.workProjectDescription, maxLength: 1000),
      FieldSpec.date('deadline', l.workProjectDeadline),
      FieldSpec.singleSelect(
        'status',
        l.workProjectStatus,
        options: [
          for (final s in ProjectStatus.values) SelectOption(id: s.name, label: texts.status(s), icon: workStatusIcon(s)),
        ],
      ),
      FieldSpec.singleSelect('planet', l.workProjectPlanet, options: WorkActions.planetOptions(context, planets)),
      FieldSpec.color('color', l.workProjectColor),
    ],
    initial: {
      'name': project?.name ?? '',
      'description': project?.description,
      'deadline': project?.deadline,
      'status': (project?.status ?? ProjectStatus.active).name,
      'planet': ProjectRules.planetOf(project?.planetKey),
      'color': project?.color,
    },
  );
  if (res == null) return null;
  return ProjectDraft(
    name: (res['name'] as String?) ?? '',
    description: res['description'] as String?,
    deadline: res['deadline'] as DateTime?,
    status: ProjectStatus.values.byName((res['status'] as String?) ?? ProjectStatus.active.name),
    planetKey: (res['planet'] as String?) ?? ProjectRules.defaultPlanet,
    color: res['color'] as int?,
  );
}
