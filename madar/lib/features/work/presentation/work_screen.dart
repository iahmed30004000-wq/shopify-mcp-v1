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
import 'projects_screen.dart';
import 'top3_card.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';
import 'work_navigation.dart';

/// The Work planet's home: today's Top 3, the boards (one per country /
/// business, with counts and what is due today; drag to reorder, archived
/// ones folded away) and the active projects.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.maxProjects = 3});

  /// Active projects shown before "All projects".
  final int maxProjects;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(workCardTaskSyncProvider);
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final summaries = ref.watch(workBoardSummariesProvider).value;
    final projects = ref.watch(workProjectsProvider).value;
    final today = ref.watch(workTodayProvider);

    final active = [for (final s in summaries ?? const <BoardSummary>[]) if (!s.board.archived) s];
    final archived = [for (final s in summaries ?? const <BoardSummary>[]) if (s.board.archived) s];
    final activeProjects = [
      for (final p in projects ?? const <ProjectView>[]) if (p.row.status != ProjectStatus.done) p,
    ];

    Widget boardItem(BoardSummary s, {Widget? grip}) => ActionableItem(
      onTap: () => WorkNavigation.toBoard(context, ref, s.board.id),
      borderRadius: BorderRadius.circular(t.radiusL),
      // No semanticLabel: the row's own texts are its label (a title-only
      // label made screen readers read the title twice).
      actions: ItemActions(
        onEdit: () async {
          final a = await WorkActions.editBoard(context, ref, s.board);
          if (a != null && context.mounted) await showUndoToast(context, a);
        },
        onDelete: () => WorkActions.deleteBoard(context, ref, s.board),
        extra: [
          ItemAction(
            icon: Icons.view_column_rounded,
            label: l.workEditColumns,
            onSelected: () async {
              await WorkActions.editColumns(context, s.board);
              return null;
            },
          ),
          ItemAction(
            icon: s.board.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            label: s.board.archived ? l.workUnarchive : l.workArchive,
            onSelected: () => WorkActions.setArchived(context, ref, s.board, !s.board.archived),
          ),
        ],
      ),
      child: BoardTile(summary: s, grip: grip),
    );

    final children = <Widget>[
      const Top3Card(),
      const SizedBox(height: Space.l),
      SectionHeader(
        title: l.workBoards,
        actionLabel: l.workNewBoard,
        onAction: () => WorkActions.newBoard(context, ref),
      ),
      if (summaries == null)
        const SizedBox(height: 96, child: Center(child: OrbitLoader()))
      else if (active.isEmpty)
        AnimatedEmptyState(
          kind: EmptyStateKind.emptyList,
          title: l.workBoardsEmptyTitle,
          body: l.workBoardsEmptyBody,
          actionLabel: l.workNewBoard,
          actionIcon: Icons.add_rounded,
          illustrationSize: 112,
          onAction: () => WorkActions.newBoard(context, ref),
        )
      else
        ReorderableGlassList<BoardSummary>(
          items: active,
          itemKey: (s) => s.board.id,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.zero,
          itemBorderRadius: BorderRadius.circular(t.radiusL),
          onReorder: (order) {
            Fx.fire(Sfx.drop);
            ref.read(workServiceProvider).reorderBoards([for (final s in order) s.board.id]);
          },
          itemBuilder: (context, s, index, grip) => boardItem(s, grip: grip),
        ),
      if (archived.isNotEmpty) ...[
        MadarPressable(
          onTap: () => setState(() => _showArchived = !_showArchived),
          sfx: _showArchived ? Sfx.toggleOff : Sfx.toggleOn,
          toggled: _showArchived,
          semanticLabel: l.workArchivedSection,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: Space.m, horizontal: Space.xs),
            child: Row(
              children: [
                Icon(Icons.archive_outlined, size: 18, color: t.textTertiary),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(texts.d(l.workArchivedCount(archived.length)), style: text.labelLarge!.copyWith(color: t.textSecondary)),
                ),
                AnimatedRotation(
                  turns: _showArchived ? 0.5 : 0,
                  duration: context.motion(MadarMotion.short),
                  child: Icon(Icons.expand_more_rounded, color: t.textTertiary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topStart,
          child: _showArchived
              ? Column(
                  children: [
                    for (final s in archived)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                        child: Opacity(opacity: 0.75, child: boardItem(s)),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
      const SizedBox(height: Space.l),
      SectionHeader(
        title: l.workProjects,
        actionLabel: (projects ?? const []).isEmpty ? l.workNewProject : l.workAllProjects,
        onAction: (projects ?? const []).isEmpty
            ? () => WorkActions.newProject(context, ref)
            : () => WorkNavigation.toProjects(context, ref),
      ),
      if (projects != null && projects.isEmpty)
        GlassCard(
          padding: const EdgeInsetsDirectional.all(Space.l),
          child: Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: t.accent),
              const SizedBox(width: Space.m),
              Expanded(child: Text(l.workProjectsEmptyBody, style: text.bodySmall)),
            ],
          ),
        )
      else
        for (final p in activeProjects.take(widget.maxProjects))
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            child: ProjectRowItem(project: p, today: today),
          ),
    ];

    return MadarScaffold(
      title: l.workTitle,
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          semanticLabel: l.workNewBoard,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => WorkActions.newBoard(context, ref),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [for (final (i, c) in children.indexed) StaggerItem(index: i, child: c)],
      ),
    );
  }
}

/// A board row: colour orb, name and country, open / done counts, what is
/// due today or overdue, and a bar of cards per column.
class BoardTile extends StatelessWidget {
  const BoardTile({super.key, required this.summary, this.grip});

  final BoardSummary summary;
  final Widget? grip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final b = summary.board;
    final color = workColor(t, b.color);
    final country = texts.country(b.country);
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.xs, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ColorOrb(color: color, size: 16),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium)),
                        if (country != null) ...[
                          const SizedBox(width: Space.s),
                          Flexible(child: WorkPill(label: country, icon: Icons.flag_rounded)),
                        ],
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        Text(texts.d(l.workOpenCount(summary.open)), style: text.labelMedium),
                        if (summary.overdue > 0)
                          WorkPill(
                            label: texts.d(l.workOverdueCount(summary.overdue)),
                            icon: Icons.error_outline_rounded,
                            color: t.danger,
                            filled: true,
                          ),
                        if (summary.dueToday > 0)
                          WorkPill(
                            label: texts.d(l.workDueTodayCount(summary.dueToday)),
                            icon: Icons.event_rounded,
                            color: t.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ?grip,
              if (grip == null) Icon(Icons.chevron_right_rounded, color: t.textTertiary),
            ],
          ),
          const SizedBox(height: Space.m),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.m),
            child: _ColumnBar(summary: summary, color: color),
          ),
        ],
      ),
    );
  }
}

class _ColumnBar extends StatelessWidget {
  const _ColumnBar({required this.summary, required this.color});

  final BoardSummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final cols = summary.board.columns;
    final total = summary.total;
    return Semantics(
      label: [for (final c in cols) '${texts.column(c)} ${texts.n(summary.perColumn[c.id] ?? 0)}'].join(texts.l.workSep),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: total == 0
                ? Container(color: t.glassBorder)
                : Row(
                    children: [
                      for (final (i, c) in cols.indexed)
                        if ((summary.perColumn[c.id] ?? 0) > 0)
                          Expanded(
                            flex: summary.perColumn[c.id]!,
                            child: Container(
                              margin: const EdgeInsetsDirectional.only(end: 2),
                              color: c.isDone
                                  ? t.success.withValues(alpha: 0.85)
                                  : color.withValues(alpha: 0.35 + 0.5 * (i + 1) / cols.length),
                            ),
                          ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
