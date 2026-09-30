import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../orbit/data/orbit_providers.dart' show orbitClockProvider, orbitPulseHubProvider, orbitTodayProvider;
import '../domain/card_filter.dart';
import '../domain/project_math.dart';
import '../domain/top3.dart';
import 'work_focus.dart';
import 'work_models.dart';
import 'work_service.dart';

// --------------------------------------------------------------- basics ----

/// The Work planet's wall clock (follows the orbit's, so tests freeze both).
final workClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final workTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Completions go through the orbit's pulse hub (the Work planet pulses).
final workRecorderProvider = Provider<WorkRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (planetKey, kind, refTable, refId, at) => hub.recordCompletion(planetKey, kind, refTable, refId, at: at);
});

final workServiceProvider = Provider<WorkService>(
  (ref) => WorkService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(workClockProvider),
    recorder: ref.watch(workRecorderProvider),
  ),
);

/// Keeps cards placed in prayer windows in step with their tasks while it
/// is watched (the Work screens watch it; the app shell should watch it
/// once so the home panel's changes reach cards at any time).
final workCardTaskSyncProvider = Provider<WorkSyncRunner>((ref) {
  final runner = WorkSyncRunner(ref.watch(workServiceProvider))..start();
  ref.onDispose(runner.dispose);
  return runner;
});

// ---------------------------------------------------------------- boards ----

final workBoardRowsProvider = StreamProvider<List<BoardRow>>((ref) => ref.watch(workServiceProvider).watchBoardRows());

final workArchivedIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(workServiceProvider).watchArchivedIds(),
);

/// Every board (archived ones flagged), in the user's order.
final workBoardsProvider = Provider<AsyncValue<List<WorkBoard>>>((ref) {
  final rows = ref.watch(workBoardRowsProvider);
  final archived = ref.watch(workArchivedIdsProvider);
  return _combine2(rows, archived, (r, a) => [for (final b in r) WorkBoard(b, archived: a.contains(b.id))]);
});

final workBoardProvider = Provider.family<AsyncValue<WorkBoard?>, String>((ref, id) {
  return ref.watch(workBoardsProvider).whenData((all) => all.where((b) => b.id == id).firstOrNull);
});

/// Every card of every board.
final workCardsProvider = StreamProvider<List<BoardCardRow>>((ref) => ref.watch(workServiceProvider).watchCards());

final workBoardCardsProvider = Provider.family<AsyncValue<List<BoardCardRow>>, String>((ref, boardId) {
  return ref.watch(workCardsProvider).whenData((all) => [for (final c in all) if (c.boardId == boardId) c]);
});

/// Board tiles: counts per column, due today, overdue.
final workBoardSummariesProvider = Provider<AsyncValue<List<BoardSummary>>>((ref) {
  final today = ref.watch(workTodayProvider);
  return _combine2(
    ref.watch(workBoardsProvider),
    ref.watch(workCardsProvider),
    (boards, cards) => [for (final b in boards) BoardSummary.of(b, cards, today)],
  );
});

/// Distinct past assignees, most used first (for the card editor and the
/// board filter).
final workAssigneeUsesProvider = StreamProvider<List<AssigneeUse>>(
  (ref) => ref.watch(workServiceProvider).watchAssigneeUses(),
);

// ----------------------------------------------------------------- Top 3 ----

final workFocusTasksProvider = StreamProvider<List<TaskRow>>((ref) => ref.watch(workServiceProvider).watchFocusTasks());

final workTop3DayProvider = StreamProvider<DateTime?>((ref) => ref.watch(workServiceProvider).watchTop3Day());

/// Every card and relevant task as a focus item.
final workFocusItemsProvider = Provider<AsyncValue<List<FocusItem>>>((ref) {
  final today = ref.watch(workTodayProvider);
  return _combine3(
    ref.watch(workBoardsProvider),
    ref.watch(workCardsProvider),
    ref.watch(workFocusTasksProvider),
    (boards, cards, tasks) => WorkFocus.collect(
      boards: boards,
      cards: cards,
      tasks: [for (final t in tasks) if (WorkFocus.taskRelevant(t, today)) t],
    ),
  );
});

/// Today's Top 3 (with the morning carry-over when due).
final workTop3Provider = Provider<AsyncValue<Top3State>>((ref) {
  final today = ref.watch(workTodayProvider);
  return _combine2(
    ref.watch(workFocusItemsProvider),
    ref.watch(workTop3DayProvider),
    (items, day) => Top3Rules.evaluate(flagged: [for (final i in items) if (i.flagged) i], storedDay: day, today: today),
  );
});

/// What can be picked for the Top 3 now.
final workTop3CandidatesProvider = Provider<AsyncValue<List<FocusItem>>>((ref) {
  final today = ref.watch(workTodayProvider);
  return ref.watch(workFocusItemsProvider).whenData((items) => Top3Rules.candidates(items, today));
});

// -------------------------------------------------------------- projects ----

final workProjectRowsProvider = StreamProvider<List<ProjectRow>>((ref) => ref.watch(workServiceProvider).watchProjects());

final workAllItemsProvider = StreamProvider<List<ProjectItemRow>>((ref) => ref.watch(workServiceProvider).watchItems());

/// Projects with progress: active, then paused, then done; the user's
/// order within each.
final workProjectsProvider = Provider<AsyncValue<List<ProjectView>>>((ref) {
  return _combine2(ref.watch(workProjectRowsProvider), ref.watch(workAllItemsProvider), (projects, items) {
    final byProject = <String, List<bool>>{};
    for (final i in items) {
      byProject.putIfAbsent(i.projectId, () => []).add(i.done);
    }
    final out = [for (final p in projects) ProjectView(p, ProjectProgress.of(byProject[p.id] ?? const []))];
    final index = {for (var i = 0; i < out.length; i++) out[i].id: i};
    out.sort((a, b) {
      final s = ProjectRules.statusRank(a.row.status).compareTo(ProjectRules.statusRank(b.row.status));
      return s != 0 ? s : index[a.id]!.compareTo(index[b.id]!);
    });
    return out;
  });
});

final workProjectProvider = Provider.family<AsyncValue<ProjectView?>, String>((ref, id) {
  return ref.watch(workProjectsProvider).whenData((all) => all.where((p) => p.id == id).firstOrNull);
});

final workProjectItemsProvider = Provider.family<AsyncValue<List<ProjectItemRow>>, String>((ref, id) {
  return ref.watch(workAllItemsProvider).whenData((all) => [for (final i in all) if (i.projectId == id) i]);
});

final workProjectTasksProvider = StreamProvider.family<List<TaskRow>, String>(
  (ref, id) => ref.watch(workServiceProvider).watchProjectTasks(id),
);

/// Visible planets (for a project's planet and its colour).
final workPlanetsProvider = StreamProvider<List<PlanetRow>>(
  (ref) => ref.watch(repositoriesProvider).planets.watchAll(where: (p) => p.hidden.equals(false)),
);

// --------------------------------------------------------------- helpers ----

AsyncValue<R> _combine2<A, B, R>(AsyncValue<A> a, AsyncValue<B> b, R Function(A, B) f) {
  for (final x in [a, b]) {
    if (x.hasError) return AsyncError(x.error!, x.stackTrace ?? StackTrace.current);
  }
  if (!a.hasValue || !b.hasValue) return const AsyncLoading();
  return AsyncData(f(a.requireValue, b.requireValue));
}

AsyncValue<R> _combine3<A, B, C, R>(AsyncValue<A> a, AsyncValue<B> b, AsyncValue<C> c, R Function(A, B, C) f) {
  for (final x in [a, b, c]) {
    if (x.hasError) return AsyncError(x.error!, x.stackTrace ?? StackTrace.current);
  }
  if (!a.hasValue || !b.hasValue || !c.hasValue) return const AsyncLoading();
  return AsyncData(f(a.requireValue, b.requireValue, c.requireValue));
}
