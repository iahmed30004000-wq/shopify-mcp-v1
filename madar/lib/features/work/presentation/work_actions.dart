import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../../home/widgets/window_chips.dart' show windowIcon;
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../data/work_service.dart';
import '../domain/board_columns.dart';
import '../domain/project_math.dart';
import '../domain/top3.dart';
import 'board_sheet.dart';
import 'card_sheet.dart';
import 'columns_sheet.dart';
import 'project_sheet.dart';
import 'work_labels.dart';

/// The Work planet's user actions, shared by every screen and card: each
/// writes through [WorkService], plays its sound and haptic, and offers
/// undo. Menu callbacks return an [UndoableAction] (the kit shows the
/// toast); direct calls show it themselves.
abstract final class WorkActions {
  static WorkService _service(WidgetRef ref) => ref.read(workServiceProvider);

  static UndoableAction _u(String label, WorkUndo undo) => UndoableAction(label: label, undo: undo);

  static void _toast(BuildContext context, UndoableAction? a) {
    if (a != null && context.mounted) unawaited(showUndoToast(context, a));
  }

  // ------------------------------------------------------------- boards ----

  static Future<void> newBoard(BuildContext context, WidgetRef ref) async {
    final draft = await showBoardSheet(context);
    if (draft == null) return;
    await _service(ref).createBoard(name: draft.name, country: draft.country, color: draft.color);
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> editBoard(BuildContext context, WidgetRef ref, WorkBoard board) async {
    final draft = await showBoardSheet(context, board: board);
    if (draft == null || !context.mounted) return null;
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).updateBoard(board.id, name: draft.name, country: draft.country, color: draft.color);
    return _u(l.itemSaved, undo);
  }

  static Future<void> editColumns(BuildContext context, WorkBoard board) => showColumnsSheet(context, boardId: board.id);

  static Future<UndoableAction?> setArchived(BuildContext context, WidgetRef ref, WorkBoard board, bool archived) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).setArchived(board.id, archived);
    Fx.fire(archived ? Sfx.swipe : Sfx.toggleOn);
    return _u(archived ? l.workBoardArchived : l.workBoardRestored, undo);
  }

  static Future<UndoableAction?> deleteBoard(BuildContext context, WidgetRef ref, WorkBoard board) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).deleteBoard(board.id);
    return _u(l.workBoardDeleted, undo);
  }

  // -------------------------------------------------------------- cards ----

  /// Opens the editor for a new card and saves it.
  static Future<void> newCard(BuildContext context, WidgetRef ref, WorkBoard board, {String? columnId}) async {
    final draft = await showCardSheet(context, board: board, columnId: columnId);
    if (draft == null || !context.mounted) return;
    final l = WorkTexts.of(context).l;
    final card = await _service(ref).addCard(board.id, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    final service = _service(ref);
    _toast(context, _u(l.workCardSaved, () async => service.deleteCard(card.id).then((_) {})));
  }

  /// Opens the editor for [card] and saves the changes.
  static Future<void> editCard(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final board = await _service(ref).board(card.boardId);
    if (board == null || !context.mounted) return;
    final items = ref.read(workFocusItemsProvider).value ?? const <FocusItem>[];
    final day = items.where((i) => i.kind == FocusKind.card && i.id == card.id).firstOrNull?.date;
    final draft = await showCardSheet(context, board: board, card: card, windowDay: day);
    if (draft == null || !context.mounted) return;
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).editCard(card, draft);
    if (!context.mounted) return;
    _toast(context, _u(l.workCardSaved, undo));
  }

  static Future<UndoableAction?> duplicateCard(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final l = WorkTexts.of(context).l;
    final (_, undo) = await _service(ref).duplicateCard(card.id);
    return _u(l.workCardDuplicated, undo);
  }

  static Future<UndoableAction?> deleteCard(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).deleteCard(card.id);
    return _u(l.workCardDeleted, undo);
  }

  /// Moves [card] to [columnId] (reordering the column when [order] is
  /// given). Finishing it celebrates at [celebrateAt] (global) or the card.
  static Future<UndoableAction?> moveToColumn(
    BuildContext context,
    WidgetRef ref,
    WorkBoard board,
    BoardCardRow card,
    String columnId, {
    List<String>? order,
    Offset? celebrateAt,
  }) async {
    final texts = WorkTexts.of(context);
    final column = BoardColumns.byId(board.columns, columnId);
    if (column == null) return null;
    final (undo, result) = await _service(ref).moveCard(card.id, columnId, orderInColumn: order);
    if (!context.mounted) return null;
    if (result.completed) {
      Fx.fire(Sfx.complete);
      if (celebrateAt != null) {
        Celebrate.burst(context, celebrateAt, kind: CelebrationKind.stardust, intensity: 0.8);
      } else {
        Celebrate.burstFrom(context, kind: CelebrationKind.stardust, intensity: 0.8);
      }
      return _u(texts.l.workCardDoneToast, undo);
    }
    Fx.fire(Sfx.drop);
    if (board.columnOf(card) == columnId) return null;
    final name = texts.name(texts.column(column));
    return _u(result.reopened ? texts.l.workCardReopened(name) : texts.l.workCardMovedTo(name), undo);
  }

  /// Picks a column from a move sheet.
  static Future<UndoableAction?> pickColumn(BuildContext context, WidgetRef ref, WorkBoard board, BoardCardRow card) async {
    final texts = WorkTexts.of(context);
    final current = board.columnOf(card);
    final target = await showMoveSheet(
      context,
      title: texts.l.workMoveToColumn,
      icon: Icons.view_column_rounded,
      targets: [
        for (final c in board.columns)
          MoveTarget(
            id: c.id,
            label: texts.column(c),
            icon: c.isDone ? Icons.task_alt_rounded : Icons.view_agenda_outlined,
            isCurrent: c.id == current,
          ),
      ],
    );
    if (target == null || target.id == current || !context.mounted) return null;
    return moveToColumn(context, ref, board, card, target.id);
  }

  static Future<UndoableAction?> moveToBoard(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final texts = WorkTexts.of(context);
    final boards = [for (final b in await _service(ref).boards()) if (!b.archived) b];
    if (!context.mounted) return null;
    final target = await showMoveSheet(
      context,
      title: texts.l.workMoveToBoard,
      icon: Icons.view_kanban_rounded,
      targets: [
        for (final b in boards)
          MoveTarget(
            id: b.id,
            label: b.name,
            subtitle: texts.country(b.country),
            color: b.color == null ? null : Color(b.color!),
            isCurrent: b.id == card.boardId,
          ),
      ],
    );
    if (target == null || target.id == card.boardId || !context.mounted) return null;
    final undo = await _service(ref).moveCardToBoard(card.id, target.id);
    Fx.fire(Sfx.drop);
    return _u(texts.l.workCardMovedBoard(texts.name(target.label)), undo);
  }

  /// Places a card in a prayer window today (or takes it out).
  static Future<UndoableAction?> placeInWindow(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final texts = WorkTexts.of(context);
    const remove = '__none';
    final target = await showMoveSheet(
      context,
      title: texts.l.workPlaceInWindow,
      subtitle: texts.l.workCardWindowHint,
      icon: Icons.mosque_rounded,
      targets: [
        for (final w in PrayerWindow.values)
          MoveTarget(id: w.name, label: texts.window(w), icon: windowIcon(w), isCurrent: card.window == w),
        if (card.window != null) MoveTarget(id: remove, label: texts.l.workRemoveFromWindow, icon: Icons.block_rounded),
      ],
    );
    if (target == null || !context.mounted) return null;
    final window = target.id == remove ? null : PrayerWindow.values.byName(target.id);
    if (window == card.window) return null;
    final undo = await _service(ref).placeCard(card, window);
    Fx.fire(Sfx.drop);
    return _u(window == null ? texts.l.workUnplacedToast : texts.l.workPlacedToast(texts.window(window)), undo);
  }

  static Future<UndoableAction?> setDue(BuildContext context, WidgetRef ref, BoardCardRow card) async {
    final l = WorkTexts.of(context).l;
    final res = await showEditSheet(
      context,
      title: l.workCardDue,
      icon: Icons.event_rounded,
      fields: [FieldSpec.date('due', l.workCardDue)],
      initial: {'due': card.dueDate},
    );
    if (res == null || !context.mounted) return null;
    final due = res['due'] as DateTime?;
    final undo = await _service(ref).editCard(card, CardDraft.of(card).copyWith(dueDate: due, clearDue: due == null));
    return _u(l.workDueSetToast, undo);
  }

  // -------------------------------------------------------------- Top 3 ----

  /// Flags / unflags a card for the Top 3 (menus).
  static Future<UndoableAction?> toggleCardTop3(BuildContext context, WidgetRef ref, BoardCardRow card) =>
      setTop3(
        context,
        ref,
        FocusItem(kind: FocusKind.card, id: card.id, title: card.title, flagged: card.isTop3),
        !card.isTop3,
        showToast: false,
      );

  /// Flags / unflags [item]; a full Top 3 offers to swap one out.
  static Future<UndoableAction?> setTop3(
    BuildContext context,
    WidgetRef ref,
    FocusItem item,
    bool on, {
    bool showToast = true,
  }) async {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final (result, undo) = await _service(ref).setFocusTop3(item, on);
    if (!context.mounted) return null;
    UndoableAction? action;
    if (result == Top3AddResult.full) {
      final state = await _service(ref).top3State();
      if (!context.mounted) return null;
      Fx.fire(Sfx.error);
      final out = await showMoveSheet(
        context,
        title: l.workTop3FullTitle,
        subtitle: l.workTop3FullBody(texts.name(item.title)),
        icon: Icons.swap_horiz_rounded,
        targets: [
          for (final i in state.items)
            MoveTarget(id: i.key, label: i.title, subtitle: i.boardName ?? l.workKindTask, icon: Icons.star_rounded),
        ],
      );
      if (out == null || !context.mounted) return null;
      final replaced = state.items.firstWhere((i) => i.key == out.id);
      final swapUndo = await _service(ref).swapTop3(replaced, item);
      Fx.fire(Sfx.toggleOn);
      action = _u(l.workTop3Swapped, swapUndo);
    } else if (undo != null) {
      Fx.fire(on ? Sfx.toggleOn : Sfx.toggleOff);
      action = _u(on ? l.workTop3Added : l.workTop3Removed, undo);
    }
    if (showToast && context.mounted) _toast(context, action);
    return action;
  }

  /// Completes / reopens a Top 3 item; the last of the three celebrates
  /// (particles + chime) from [celebrateFrom] when given.
  static Future<void> toggleFocusDone(
    BuildContext context,
    WidgetRef ref,
    FocusItem item, {
    BuildContext? celebrateFrom,
  }) async {
    final l = WorkTexts.of(context).l;
    final (undo, done) = await _service(ref).toggleFocusDone(item);
    if (!context.mounted) return;
    if (done) {
      final state = await _service(ref).top3State();
      if (!context.mounted) return;
      if (state.allDone && state.items.any((i) => i.key == item.key)) {
        final from = celebrateFrom != null && celebrateFrom.mounted ? celebrateFrom : context;
        Fx.fire(Sfx.levelUp);
        Celebrate.burstFrom(from, kind: CelebrationKind.orbitalRing, sfx: Sfx.sparkle);
        Celebrate.burstFrom(from, kind: CelebrationKind.stardust, intensity: 1.2);
      } else {
        Fx.fire(Sfx.complete);
      }
    } else {
      Fx.fire(Sfx.toggleOff);
    }
    _toast(context, _u(done ? l.workItemDoneToast : l.workItemReopenedToast, undo));
  }

  static Future<void> carryOver(BuildContext context, WidgetRef ref) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).carryOverTop3();
    Fx.fire(Sfx.complete);
    if (context.mounted) _toast(context, _u(l.workCarriedToast, undo));
  }

  static Future<void> startFresh(BuildContext context, WidgetRef ref) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).startFreshTop3();
    Fx.fire(Sfx.swipe);
    if (context.mounted) _toast(context, _u(l.workFreshToast, undo));
  }

  // ----------------------------------------------------------- projects ----

  static Future<void> newProject(BuildContext context, WidgetRef ref, {void Function(ProjectRow p)? then}) async {
    final draft = await showProjectSheet(context, ref);
    if (draft == null || !context.mounted) return;
    final l = WorkTexts.of(context).l;
    final p = await _service(ref).createProject(draft);
    Fx.fire(Sfx.complete);
    final service = _service(ref);
    if (context.mounted) _toast(context, _u(l.itemSaved, () async => service.deleteProject(p.id).then((_) {})));
    then?.call(p);
  }

  static Future<void> editProject(BuildContext context, WidgetRef ref, ProjectRow project) async {
    final draft = await showProjectSheet(context, ref, project: project);
    if (draft == null || !context.mounted) return;
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).editProject(project, draft);
    if (draft.status == ProjectStatus.done && project.status != ProjectStatus.done) {
      Fx.fire(Sfx.levelUp);
      if (context.mounted) Celebrate.burstFrom(context, kind: CelebrationKind.lanternSparks);
    }
    if (context.mounted) _toast(context, _u(l.itemSaved, undo));
  }

  static Future<UndoableAction?> duplicateProject(BuildContext context, WidgetRef ref, ProjectRow project) async {
    final l = WorkTexts.of(context).l;
    final (_, undo) = await _service(ref).duplicateProject(project.id);
    return _u(l.workProjectDuplicated, undo);
  }

  static Future<UndoableAction?> deleteProject(BuildContext context, WidgetRef ref, ProjectRow project) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).deleteProject(project.id);
    return _u(l.workProjectDeleted, undo);
  }

  static Future<UndoableAction?> pickStatus(BuildContext context, WidgetRef ref, ProjectRow project) async {
    final texts = WorkTexts.of(context);
    final target = await showMoveSheet(
      context,
      title: texts.l.workSetStatus,
      subtitle: project.name,
      icon: Icons.flag_circle_rounded,
      targets: [
        for (final s in ProjectStatus.values)
          MoveTarget(id: s.name, label: texts.status(s), icon: workStatusIcon(s), isCurrent: project.status == s),
      ],
    );
    if (target == null || !context.mounted) return null;
    final status = ProjectStatus.values.byName(target.id);
    if (status == project.status) return null;
    final undo = await _service(ref).setProjectStatus(project.id, status);
    if (!context.mounted) return null;
    if (status == ProjectStatus.done) {
      Fx.fire(Sfx.levelUp);
      Celebrate.burstFrom(context, kind: CelebrationKind.lanternSparks);
    } else {
      Fx.fire(Sfx.toggleOn);
    }
    return _u(texts.l.workStatusChanged(texts.status(status)), undo);
  }

  /// Ticks / unticks a checklist item; reaching 100 % celebrates from
  /// [celebrateFrom] (the progress ring) with particles and a chime.
  static Future<UndoableAction?> toggleItem(
    BuildContext context,
    WidgetRef ref,
    ProjectItemRow item, {
    BuildContext? celebrateFrom,
  }) async {
    final l = WorkTexts.of(context).l;
    final (result, undo) = await _service(ref).toggleItem(item);
    if (!context.mounted) return null;
    if (result.completedProject) {
      final from = celebrateFrom != null && celebrateFrom.mounted ? celebrateFrom : context;
      Fx.fire(Sfx.levelUp);
      Celebrate.burstFrom(from, kind: CelebrationKind.orbitalRing, sfx: Sfx.sparkle);
      Celebrate.burstFrom(from, kind: CelebrationKind.lanternSparks, intensity: 1.1);
      return _u(l.workProjectComplete, undo);
    }
    Fx.fire(result.done ? Sfx.complete : Sfx.toggleOff);
    return _u(result.done ? l.workItemDoneToast : l.workItemReopenedToast, undo);
  }

  static Future<void> addItem(BuildContext context, WidgetRef ref, String projectId, String body) async {
    if (body.trim().isEmpty) {
      Fx.fire(Sfx.error);
      return;
    }
    await _service(ref).addItem(projectId, body);
    Fx.fire(Sfx.drop);
  }

  static Future<UndoableAction?> editItem(BuildContext context, WidgetRef ref, ProjectItemRow item) async {
    final l = WorkTexts.of(context).l;
    final res = await showEditSheet(
      context,
      title: l.workEditItem,
      icon: Icons.checklist_rounded,
      fields: [
        FieldSpec.text('body', l.workItemBody, required: true, maxLength: 200),
        FieldSpec.date('due', l.workItemDue),
      ],
      initial: {'body': item.body, 'due': item.dueDate},
    );
    if (res == null || !context.mounted) return null;
    final undo = await _service(ref).editItem(item, body: (res['body'] as String?) ?? item.body, dueDate: res['due'] as DateTime?);
    return _u(l.itemSaved, undo);
  }

  static Future<UndoableAction?> deleteItem(BuildContext context, WidgetRef ref, ProjectItemRow item) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).deleteItem(item.id);
    return _u(l.workItemDeleted, undo);
  }

  /// Adds a project task placed in a prayer window (it shows in the home
  /// panel's list of that window).
  static Future<void> addProjectTask(BuildContext context, WidgetRef ref, ProjectRow project) async {
    final l = WorkTexts.of(context).l;
    final today = ref.read(workTodayProvider);
    final res = await showEditSheet(
      context,
      title: l.workAddProjectTask,
      subtitle: project.name,
      icon: Icons.mosque_rounded,
      fields: [
        FieldSpec.text('title', l.workTaskTitle, required: true, maxLength: 140),
        FieldSpec.prayerWindow('window', l.workTaskWindow, required: true),
        FieldSpec.date('date', l.workTaskDay),
      ],
      initial: {'title': '', 'window': PrayerWindow.anytime, 'date': today},
    );
    if (res == null || !context.mounted) return;
    final task = await _service(ref).addProjectTask(
      project,
      title: (res['title'] as String?) ?? '',
      window: (res['window'] as PrayerWindow?) ?? PrayerWindow.anytime,
      date: res['date'] as DateTime?,
    );
    Fx.fire(Sfx.complete);
    final service = _service(ref);
    if (context.mounted) _toast(context, _u(l.itemSaved, () async => service.deleteTask(task.id).then((_) {})));
  }

  static Future<UndoableAction?> toggleTask(BuildContext context, WidgetRef ref, TaskRow task) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).toggleTaskDone(task);
    Fx.fire(task.done ? Sfx.toggleOff : Sfx.complete);
    return _u(task.done ? l.workItemReopenedToast : l.workItemDoneToast, undo);
  }

  static Future<UndoableAction?> moveTask(BuildContext context, WidgetRef ref, TaskRow task) async {
    final texts = WorkTexts.of(context);
    final target = await showMoveSheet(
      context,
      title: texts.l.workPlaceInWindow,
      icon: Icons.mosque_rounded,
      targets: [
        for (final w in PrayerWindow.values)
          MoveTarget(id: w.name, label: texts.window(w), icon: windowIcon(w), isCurrent: task.window == w),
      ],
    );
    if (target == null || !context.mounted) return null;
    final window = PrayerWindow.values.byName(target.id);
    if (window == task.window) return null;
    final undo = await _service(ref).moveTask(task, window);
    Fx.fire(Sfx.drop);
    return _u(texts.l.workPlacedToast(texts.window(window)), undo);
  }

  static Future<UndoableAction?> deleteTask(BuildContext context, WidgetRef ref, TaskRow task) async {
    final l = WorkTexts.of(context).l;
    final undo = await _service(ref).deleteTask(task.id);
    return _u(l.itemDeleted, undo);
  }

  /// Planet choices for a project (visible planets with their colours).
  static List<SelectOption> planetOptions(BuildContext context, List<PlanetRow> planets) {
    final texts = WorkTexts.of(context);
    final out = [for (final p in planets) SelectOption(id: p.key, label: texts.planet(p), color: Color(p.color))];
    if (!out.any((o) => o.id == ProjectRules.defaultPlanet)) {
      out.insert(0, SelectOption(id: ProjectRules.defaultPlanet, label: texts.l.planetWork));
    }
    return out;
  }
}
