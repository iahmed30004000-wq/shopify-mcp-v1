/// The AI bridge (Part 3): hand your own data to any AI app as one file,
/// and bring a «خطة مدار» back.
///
/// No login, no API key, no network: Madar writes a file (or the clipboard)
/// and reads a file (or a paste). The own-key chat in `features/ai_chat`
/// stays as an optional shortcut for the very same round trip.
///
/// Going out: [showAiBridgeExportSheet] reuses the data package's own
/// per-section chooser, then [AiBridgeRepository.buildRequest] builds one
/// JSON carrying his approved summary, his own names ([PlanCatalog]), the
/// ready prompt and the exact answer shape ([PlanPrompt]).
///
/// Coming back: [PlanValidator] checks a payload against the contract in
/// `domain/plan_contract.dart` and against his data; [PlanPreviewBuilder]
/// turns it into one card per suggestion; [PlanApplyService] applies **one
/// approved suggestion at a time**, idempotently, each with an undo
/// closure, and keeps the plan's checklist and history.
///
/// The screens on top of that engine:
///
/// * [PlanImportScreen] – paste it, pick its file, or let another app
///   share it in ([ShareIntake]); a refused payload shows its problems in
///   plain Arabic and nothing else;
/// * [PlanScreen] – the review: one card per suggestion with what it would
///   change, the AI's reason, what his data says today, and **one**
///   Approve / Edit / Refuse per card. There is no apply-all anywhere;
/// * [PlanChecklistView] – the suggestions he approved as the named list
///   he ticks off, «٢ من ٤», with the before/after measured against his
///   data as it is now ([PlanAfter]);
/// * [PlanHistoryScreen] – every plan, newest first, each re-opened
///   through [PlanApplyService.reopen];
/// * [PlanChecklistStrip] – the one line on the home panel that brings him
///   back to an unfinished list.
library;

export 'data/ai_bridge_providers.dart';
export 'data/ai_bridge_repository.dart' show AiBridgeRepository;
export 'data/plan_apply_service.dart'
    show PlanApplyOutcome, PlanApplyRefused, PlanApplyService, PlanImport, PlanProgress, PlanUndo;
export 'data/share_intake.dart'
    show MethodChannelShareIntake, NoShareIntake, PendingSharedPlan, ShareIntake, SharedPlanPayload,
        pendingSharedPlanProvider, shareIntakeProvider;
export 'domain/health_guard.dart' show HealthFlag, HealthFlagKind, HealthGuard;
export 'domain/plan_catalog.dart' show PlanCatalog, PlanRef, PlanRefSet;
export 'domain/plan_contract.dart';
export 'domain/plan_preview.dart'
    show PlanBefore, PlanBeforeKind, PlanEditReason, PlanItemPreview, PlanItemStatus, PlanPreviewBuilder, PlanTargetSlot;
export 'domain/plan_problems.dart' show PlanProblem, PlanProblemCode;
export 'domain/plan_request.dart' show PlanOmissions, PlanPrompt, PlanRequest, madarRequestMarker;
export 'domain/plan_validator.dart' show PlanValidation, PlanValidator, planOwnerTables;
export 'presentation/ai_bridge_export_sheet.dart' show AiBridgeExportSheet, showAiBridgeExportSheet;
export 'presentation/ai_bridge_texts.dart' show AiBridgeTexts;
export 'presentation/plan_actions.dart' show PlanActions;
export 'presentation/plan_after.dart' show PlanAfter, PlanAfterState;
export 'presentation/plan_checklist_view.dart' show PlanChecklistTile, PlanChecklistView;
export 'presentation/plan_history_screen.dart' show PlanHistoryScreen;
export 'presentation/plan_import_screen.dart' show PlanImportScreen;
export 'presentation/plan_screen.dart' show PlanScreen, PlanTab;
export 'presentation/widgets/plan_checklist_strip.dart' show PlanChecklistStrip;
export 'presentation/widgets/plan_item_card.dart' show PlanItemCard;
export 'presentation/widgets/plan_widgets.dart' show PlanLabel, PlanLines, PlanPill;
