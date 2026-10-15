import 'package:drift/drift.dart' show TableInfo;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show AppliedPlanItemRow, AppliedPlanRow;
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart' show PlanItemState;
import '../../data/data.dart' show dataClockProvider;
import '../domain/plan_catalog.dart';
import '../domain/plan_contract.dart';
import '../domain/plan_preview.dart';
import 'ai_bridge_repository.dart';
import 'plan_apply_service.dart';

/// Reads his own things for the request, and for checking an answer.
final aiBridgeRepositoryProvider = Provider<AiBridgeRepository>(
  (ref) => AiBridgeRepository(ref.watch(repositoriesProvider)),
);

/// The import engine's writes (one suggestion at a time, each undoable).
final planApplyServiceProvider = Provider<PlanApplyService>(
  (ref) => PlanApplyService(ref.watch(repositoriesProvider), clock: ref.watch(dataClockProvider)),
);

/// The plans he has imported, newest first (Part 3's history).
final planHistoryProvider = StreamProvider.autoDispose<List<AppliedPlanRow>>(
  (ref) => ref.watch(planApplyServiceProvider).watchPlans(),
);

/// «٢ من ٤» of one plan, live.
final planProgressProvider = StreamProvider.autoDispose.family<PlanProgress, String>(
  (ref, planId) => ref.watch(planApplyServiceProvider).watchProgress(planId),
);

/// The checklist of one plan (only the suggestions he approved), live.
final planChecklistProvider = StreamProvider.autoDispose.family<List<AppliedPlanItemRow>, String>(
  (ref, planId) => ref.watch(planApplyServiceProvider).watchChecklist(planId),
);

/// Every suggestion row of one plan with his decision on it, live – the
/// review screen reads the decisions from here, so an approve or a reject
/// shows the moment it is written.
final planItemRowsProvider = StreamProvider.autoDispose.family<List<AppliedPlanItemRow>, String>(
  (ref, planId) => ref.watch(planApplyServiceProvider).watchItems(planId),
);

/// One plan re-opened against his data **as it is now**: the stored row,
/// the catalogue it was checked against, and one preview per suggestion.
///
/// The review screen invalidates this after every decision, which is how a
/// suggestion that was waiting for another one turns ready in front of him
/// ([PlanApplyService.reopen]). Null when the plan is not in the history.
final planReviewProvider = FutureProvider.autoDispose.family<PlanReviewData?, String>((ref, planId) async {
  final service = ref.watch(planApplyServiceProvider);
  final plan = await service.planById(planId);
  if (plan == null) return null;
  final catalog = await ref.watch(aiBridgeRepositoryProvider).loadCatalog(ref.watch(dataClockProvider)());
  return PlanReviewData(import: await service.reopen(plan, catalog: catalog), catalog: catalog);
});

/// A re-opened plan and the catalogue behind it.
class PlanReviewData {
  const PlanReviewData({required this.import, required this.catalog});

  final PlanImport import;

  /// Everything he has right now – what a reference resolves against, and
  /// what an edit may pick from.
  final PlanCatalog catalog;

  AppliedPlanRow? get plan => import.plan;
  List<PlanItemPreview> get previews => import.previews;

  /// The suggestions of this plan he has already approved.
  Set<String> get appliedIds => {
    for (final e in import.states.entries)
      if (e.value == PlanItemState.applied) e.key,
  };

  /// The name he gave a suggestion of this plan, for «مستني موافقتك على …»
  /// (never an id).
  String titleOf(String itemId) => import.preview(itemId)?.item.title ?? itemId;

  /// Re-previews [item] after one of his edits, against the same data and
  /// the same validation – so an edited suggestion is judged exactly like
  /// the one that arrived.
  PlanItemPreview? preview(PlanItem item) {
    final plan = import.validation.plan;
    if (plan == null) return null;
    return PlanPreviewBuilder(catalog).one(item, import.validation, plan: plan, appliedIds: appliedIds);
  }
}

/// The plan he still has something to tick off – the newest one with an
/// open line – or null when there is none. Drives the card on the home
/// panel, so it is a live stream over **both** plan tables: a new plan, a
/// rename and every single tick move it.
final openPlanChecklistProvider = StreamProvider.autoDispose<OpenPlanChecklist?>((ref) {
  final repos = ref.watch(repositoriesProvider);
  final service = ref.watch(planApplyServiceProvider);
  final tables = <TableInfo<dynamic, dynamic>>{repos.appliedPlans.table, repos.appliedPlanItems.table};
  return repos.db.customSelect('SELECT 1', readsFrom: tables).watch().asyncMap((_) async {
    for (final plan in await service.plans()) {
      final rows = await service.checklist(plan.id);
      final open = [
        for (final r in rows)
          if (!r.done) r,
      ];
      if (open.isEmpty) continue;
      return OpenPlanChecklist(
        plan: plan,
        next: open.first,
        progress: PlanProgress(done: rows.length - open.length, total: rows.length),
      );
    }
    return null;
  });
});

/// One plan with lines still to tick: what the home card shows.
class OpenPlanChecklist {
  const OpenPlanChecklist({required this.plan, required this.next, required this.progress});

  final AppliedPlanRow plan;

  /// The first line he has not ticked yet.
  final AppliedPlanItemRow next;
  final PlanProgress progress;
}
