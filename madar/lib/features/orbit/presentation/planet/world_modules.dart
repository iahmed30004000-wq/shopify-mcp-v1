import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../home/home_providers.dart';
import '../../../home/widgets/task_actions.dart';
import '../../../home/widgets/task_panel.dart';

/// Every world's page: today's tasks attached to it (complete one with a
/// swipe – the world flares behind the page), or a calm line with a way to
/// plan one.
class WorldTasksModule extends ConsumerWidget {
  const WorldTasksModule({super.key, required this.planetKey});

  final String planetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final tasks = ref.watch(planetTasksTodayProvider(planetKey)).value;
    if (tasks == null) return const SizedBox(height: 48);
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: Row(
          children: [
            Icon(Icons.wb_twilight_rounded, size: 18, color: t.accent),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(l.orbitUiWorldTasksNone, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
            MadarButton.icon(
              icon: Icons.add_rounded,
              semanticLabel: l.homeAddTask,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => TaskActions(
                ref,
                context,
              ).add(window: ref.read(homeCurrentWindowProvider), day: ref.read(homeDayProvider), planetKey: planetKey),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.s),
            child: TaskItem(key: ValueKey('world-task-${task.id}'), task: task),
          ),
      ],
    );
  }
}
