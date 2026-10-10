import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show AppliedPlanItemRow, AppliedPlanRow;
import '../../../core/db/repositories/repositories.dart';
import '../../data/data.dart' show dataClockProvider;
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
