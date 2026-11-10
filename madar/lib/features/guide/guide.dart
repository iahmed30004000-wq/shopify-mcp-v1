/// The in-app guide: «؟» help sheets, the coach tour, the first-run flow,
/// guide search and the teaching empty state.
///
/// Integration notes
/// * Persistence: adapt the app's existing small-flag storage (the
///   SharedPreferences-backed settings store) to [GuideSeenStore], a string
///   set under one key. Keep [FirstRunFlow.encode] in the same place.
/// * Put a [GuideScope] above the router, then `HelpButton(entryId: …)` in
///   app bars and `CoachTour.run(...)` after a screen's first frame.
library;

export 'domain/bubble_placement.dart';
export 'domain/first_run_flow.dart';
export 'domain/guide_entry.dart';
export 'domain/guide_samples.dart';
export 'domain/guide_search.dart';
export 'domain/guide_seen_store.dart';
export 'domain/tour.dart';
export 'presentation/coach_tour.dart';
export 'presentation/empty_state_card.dart';
export 'presentation/guide_scope.dart';
export 'presentation/guide_sheet.dart';
export 'presentation/help_button.dart';
