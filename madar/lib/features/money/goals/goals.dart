/// Money › savings jars, debts and recurring obligations.
///
/// Screens and widgets: [GoalsScreen] (jars / debts / obligations tabs),
/// [JarScreen], [DebtSheet] / [showDebtSheet], [ObligationSheet] /
/// [showObligationSheet], and the Money hub cards [UpcomingDuesCard] and
/// [JarsCard]. Logic: [GoalsService] (every write, with undo) over the pure
/// domain in `domain/` (due dates, jar plans, debt ledgers, obligation
/// steps, reminder plans).
library;

export 'data/goals_notifications.dart';
export 'data/goals_providers.dart';
export 'data/goals_service.dart';
export 'domain/debt_ledger.dart';
// CalendarDays stays internal: Family and Wird have their own.
export 'domain/due_dates.dart' hide CalendarDays;
export 'domain/due_reminders.dart';
export 'domain/goals_rates.dart';
export 'domain/goals_snapshot.dart';
export 'domain/jar_plan.dart';
export 'domain/obligation_plan.dart';
export 'goals_texts.dart';
export 'presentation/astrolabe_ring.dart' show AstrolabeProgressRing, AstrolabeProgressRingPainter;
export 'presentation/debt_sheet.dart' show DebtSheet, showDebtSheet;
export 'presentation/goals_actions.dart' show GoalsActions;
export 'presentation/goals_cards.dart' show JarsCard, UpcomingDuesCard;
export 'presentation/goals_navigation.dart' show GoalsNavigation, goalsNavigationProvider;
export 'presentation/goals_screen.dart' show GoalsScreen, GoalsTab;
export 'presentation/goals_tiles.dart' show DebtTile, DueLeaf, JarTile, ObligationTile;
export 'presentation/goals_ui.dart' show GoalsIcons;
export 'presentation/jar_screen.dart' show JarScreen, JarTrajectoryChart;
export 'presentation/obligation_sheet.dart' show ObligationSheet, showObligationSheet;
