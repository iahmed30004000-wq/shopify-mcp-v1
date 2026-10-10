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
library;

export 'data/ai_bridge_providers.dart';
export 'data/ai_bridge_repository.dart' show AiBridgeRepository;
export 'data/plan_apply_service.dart'
    show PlanApplyOutcome, PlanApplyRefused, PlanApplyService, PlanImport, PlanProgress, PlanUndo;
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
