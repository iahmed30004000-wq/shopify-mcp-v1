import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../domain/countdown.dart';
import '../domain/top3.dart';
import '../domain/work_days.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';
import 'work_navigation.dart';

/// Compact card for the Work planet hub: today's Top 3 at a glance, how
/// many cards are due today / overdue, and the most urgent cards (tap to
/// edit, swipe to finish). Tapping the header opens the Work screen
/// ([onOpen], else [WorkNavigation]).
class WorkTodayCard extends ConsumerWidget {
  const WorkTodayCard({super.key, this.onOpen, this.maxCards = 3});

  final void Function(BuildContext context)? onOpen;
  final int maxCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workCardTaskSyncProvider);
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(workTodayProvider);
    final boards = ref.watch(workBoardsProvider).value;
    final cards = ref.watch(workCardsProvider).value;
    final top3 = ref.watch(workTop3Provider).value;
    final items = ref.watch(workFocusItemsProvider).value ?? const <FocusItem>[];
    final windowDays = {for (final i in items) if (i.kind == FocusKind.card) i.id: i.date};

    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context);
      } else {
        WorkNavigation.toWork(context, ref);
      }
    }

    final header = MadarPressable(
      onTap: open,
      sfx: null,
      semanticLabel: l.workOpenAll,
      child: Row(
        children: [
          Icon(Icons.work_rounded, size: 18, color: t.accent),
          const SizedBox(width: Space.s),
          Expanded(child: Text(l.workTodayTitle, style: text.titleMedium)),
          Text(l.workOpenAll, style: text.labelLarge!.copyWith(color: t.accent)),
          Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
        ],
      ),
    );

    if (boards == null || cards == null) {
      return _frame(t, [header, const SizedBox(height: 64, child: Center(child: OrbitLoader(size: 28)))]);
    }

    final byBoard = {for (final b in boards) b.id: b};
    final open0 = <(BoardCardRow, WorkBoard, int)>[];
    var dueToday = 0, overdue = 0;
    for (final c in cards) {
      final b = byBoard[c.boardId];
      if (b == null || b.archived || b.isDone(c)) continue;
      final s = DueRules.of(c.dueDate, today);
      final placedToday = c.window != null && WorkDays.same(windowDays[c.id] ?? today, today);
      if (s == DueStatus.today) dueToday++;
      if (s == DueStatus.overdue) overdue++;
      final rank = switch (s) {
        DueStatus.overdue => 0,
        DueStatus.today => 1,
        _ => placedToday ? 2 : (c.isTop3 ? 3 : -1),
      };
      if (rank >= 0) open0.add((c, b, rank));
    }
    open0.sort((a, b) => a.$3 != b.$3 ? a.$3.compareTo(b.$3) : a.$1.sortOrder.compareTo(b.$1.sortOrder));

    final done3 = top3?.doneCount ?? 0;
    final chosen = top3?.items.length ?? 0;
    final summary = Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WorkPill(
          label: l.workTodayTop3Line(texts.n(done3), texts.n(Top3Rules.max)),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < Top3Rules.max; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 1),
                  child: IslamicStar(
                    size: 10,
                    color: i < done3 ? t.success : (i < chosen ? t.gold : t.textTertiary),
                    filled: i < chosen,
                  ),
                ),
            ],
          ),
          color: top3?.allDone == true ? t.success : t.gold,
          dense: false,
        ),
        if (overdue > 0) WorkPill(label: texts.d(l.workOverdueCount(overdue)), icon: Icons.error_outline_rounded, color: t.danger, filled: true, dense: false),
        if (dueToday > 0) WorkPill(label: texts.d(l.workDueTodayCount(dueToday)), icon: Icons.event_rounded, color: t.warning, dense: false),
      ],
    );

    final rows = <Widget>[
      for (final (c, b, _) in open0.take(maxCards))
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.s),
          child: ActionableItem(
            onTap: () => WorkActions.editCard(context, ref, c),
            onCompleteSwipe: b.doneColumnId == null ? null : () => WorkActions.moveToColumn(context, ref, b, c, b.doneColumnId!),
            borderRadius: BorderRadius.circular(t.radiusM),
            semanticLabel: c.title,
            actions: ItemActions(
              onEdit: () => WorkActions.editCard(context, ref, c),
              extra: [
                ItemAction(
                  icon: c.isTop3 ? Icons.star_outline_rounded : Icons.star_rounded,
                  label: c.isTop3 ? l.workTop3Remove : l.workTop3Add,
                  onSelected: () => WorkActions.toggleCardTop3(context, ref, c),
                ),
                ItemAction(
                  icon: Icons.mosque_rounded,
                  label: l.workPlaceInWindow,
                  onSelected: () => WorkActions.placeInWindow(context, ref, c),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
              decoration: BoxDecoration(
                color: t.glassFill,
                borderRadius: BorderRadius.circular(t.radiusM),
                border: Border.all(color: t.glassBorder),
              ),
              child: Row(
                children: [
                  ColorOrb(color: workColor(t, b.color), size: 9),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                        Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  if (c.dueDate != null)
                    DueBadge(due: c.dueDate!, today: today)
                  else if (c.window != null)
                    WindowPill(window: c.window!, day: windowDays[c.id], today: today),
                ],
              ),
            ),
          ),
        ),
    ];

    return _frame(t, [
      header,
      const SizedBox(height: Space.m),
      summary,
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.m),
          child: Row(
            children: [
              Icon(Icons.spa_outlined, size: 18, color: t.success),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.workTodayAllClear, style: text.bodyMedium)),
            ],
          ),
        )
      else
        ...rows,
    ]);
  }

  Widget _frame(MadarTokens t, List<Widget> children) => GlassCard(
    borderRadius: BorderRadius.circular(t.radiusL),
    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}
