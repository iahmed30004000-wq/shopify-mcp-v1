/// The nested budget: items set by amount or by percentage (of the parent
/// or of the total) with live recalculation, monthly / weekly periods,
/// allocation and overspending warnings, spend vs plan with projections and
/// history, a tree picker for transactions and a compact status card.
library;

export 'data/budget_providers.dart';
export 'data/budget_repository.dart';
export 'domain/budget_draft.dart';
export 'domain/budget_edits.dart';
export 'domain/budget_plan.dart';
export 'domain/budget_search.dart';
export 'domain/budget_spending.dart';
export 'presentation/budget_format.dart';
export 'presentation/budget_labels.dart';
export 'presentation/budget_actions.dart';
export 'presentation/budget_item_sheet.dart';
export 'presentation/budget_picker.dart';
export 'presentation/budget_screen.dart';
export 'presentation/budget_status_card.dart';
export 'presentation/budget_weeks_sheet.dart';
export 'presentation/plan_view.dart';
export 'presentation/spending_view.dart';
