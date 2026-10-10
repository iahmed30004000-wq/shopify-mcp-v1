import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/body/body.dart' show BodyScreen, BodyTab;
import '../../features/custom_modules/custom_modules.dart' show CustomModulesScreen, ModuleScreen;
import '../../features/family/family.dart' show FamilyScreen, PersonScreen;
import '../../features/growth/growth.dart' show GoalScreen, GrowthScreen;
import '../../features/nutrition/presentation/nutrition_ui.dart'
    show ConditionsScreen, FoodLibraryScreen, MealPlanScreen, NutritionInsightsScreen;
import '../../features/travel/travel.dart' show PackingTemplateScreen, TravelScreen, TravelTab, TripScreen;
import '../../features/work/work.dart' show BoardScreen, ProjectScreen, ProjectsScreen, WorkRoutes, WorkScreen;
import '../settings/app_settings.dart';
import 'notification_landing.dart';
import 'routes.dart';

/// Adapters between the router and the Phase 6 life screens (Work, Family,
/// Travel, Growth, Body and the user's own trackers): every life screen is
/// a route, so the worlds' hubs, moons, reasons, Settings › Life and
/// notification taps share one stack, and back returns where the user came
/// from.
///
/// In-app links `push`; notification deep links `go` (see
/// `AppNotificationRouter`). These helpers fire no sound – the package
/// cards and the hubs' tool tiles fire `Sfx.navigate` before they call
/// them.
abstract final class LifeNav {
  static void work(BuildContext context) => unawaited(context.push<void>(AppRoutes.work));

  static void board(BuildContext context, String boardId) =>
      unawaited(context.push<void>(AppRoutes.workBoardOf(boardId)));

  static void projects(BuildContext context) => unawaited(context.push<void>(AppRoutes.workProjects));

  static void project(BuildContext context, String projectId) =>
      unawaited(context.push<void>(AppRoutes.workProjectOf(projectId)));

  static void family(BuildContext context) => unawaited(context.push<void>(AppRoutes.family));

  static void person(BuildContext context, String personId) =>
      unawaited(context.push<void>(AppRoutes.familyPersonOf(personId)));

  static void travel(BuildContext context, {TravelTab tab = TravelTab.trips}) =>
      unawaited(context.push<void>(AppRoutes.travelOf(tab: tab.name)));

  static void trip(BuildContext context, String tripId) =>
      unawaited(context.push<void>(AppRoutes.travelTripOf(tripId)));

  static void template(BuildContext context, String templateId) =>
      unawaited(context.push<void>(AppRoutes.travelTemplateOf(templateId)));

  static void growth(BuildContext context) => unawaited(context.push<void>(AppRoutes.growth));

  static void goal(BuildContext context, String goalId) =>
      unawaited(context.push<void>(AppRoutes.growthGoalOf(goalId)));

  static void body(BuildContext context, {BodyTab tab = BodyTab.today}) =>
      unawaited(context.push<void>(AppRoutes.bodyOf(tab: tab.name)));

  static void foodLibrary(BuildContext context) => unawaited(context.push<void>(AppRoutes.foodLibrary));

  static void foodPlan(BuildContext context) => unawaited(context.push<void>(AppRoutes.foodPlan));

  static void foodRules(BuildContext context) => unawaited(context.push<void>(AppRoutes.foodRules));

  static void foodInsights(BuildContext context) => unawaited(context.push<void>(AppRoutes.foodInsights));

  static void modules(BuildContext context) => unawaited(context.push<void>(AppRoutes.modules));

  static void module(BuildContext context, String moduleId) =>
      unawaited(context.push<void>(AppRoutes.moduleOf(moduleId)));
}

/// Where a life record leads (pure) – one source of truth for the Neglect
/// Radar's reasons, the moons' sheets and search results:
///
/// | table | with an id | without |
/// |---|---|---|
/// | people, contact_logs (`personId`) | `/family/person/<id>` | `/family` |
/// | boards, board_cards (`boardId`) | `/work/board/<id>` | `/work` |
/// | projects, project_items (`projectId`) | `/work/project/<id>` | `/work/projects` |
/// | trips, trip_items (`tripId`) | `/travel/trip/<id>` | `/travel` |
/// | travel_documents | `/travel?tab=documents` | same |
/// | packing_templates | `/travel/template/<id>` | `/travel?tab=templates` |
/// | learning_goals, goal_logs (`goalId`) | `/growth/goal/<id>` | `/growth` |
/// | exercises, workout_logs | `/body?tab=plan` | same |
/// | fasting_sessions / water_logs / avoid_items | `/body?tab=fasting` / `water` / `avoid` | same |
/// | food_logs | `/body?tab=food` | same |
/// | foods | `/food/library` | same |
/// | meal_plans, meal_slots, meal_slot_foods | `/food/plan` | same |
/// | food_rules | `/food/rules` | same |
/// | custom_modules, custom_entries (`moduleId`) | `/modules/module/<id>` | `/modules` |
///
/// A child record (a card, a contact, a log) opens its parent, named by
/// [extra] (the search documents carry it). Anything else: null.
abstract final class LifeRecordLinks {
  /// The tables [locationOf] maps.
  static const Set<String> tables = {
    'people',
    'contact_logs',
    'boards',
    'board_cards',
    'projects',
    'project_items',
    'trips',
    'trip_items',
    'travel_documents',
    'packing_templates',
    'learning_goals',
    'goal_logs',
    'exercises',
    'workout_logs',
    'fasting_sessions',
    'water_logs',
    'avoid_items',
    'foods',
    'food_logs',
    'meal_plans',
    'meal_slots',
    'meal_slot_foods',
    'food_rules',
    'custom_modules',
    'custom_entries',
  };

  static String? locationOf(String? refTable, String? refId, {Map<String, Object?> extra = const {}}) {
    final id = (refId == null || refId.isEmpty) ? null : refId;
    String? of(String key) {
      final v = extra[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    String either(String? id, String Function(String id) withId, String without) =>
        id == null ? without : withId(id);

    return switch (refTable) {
      'people' => either(id, AppRoutes.familyPersonOf, AppRoutes.family),
      'contact_logs' => either(of('personId'), AppRoutes.familyPersonOf, AppRoutes.family),
      'boards' => either(id, AppRoutes.workBoardOf, AppRoutes.work),
      'board_cards' => either(of('boardId'), AppRoutes.workBoardOf, AppRoutes.work),
      'projects' => either(id, AppRoutes.workProjectOf, AppRoutes.workProjects),
      'project_items' => either(of('projectId'), AppRoutes.workProjectOf, AppRoutes.workProjects),
      'trips' => either(id, AppRoutes.travelTripOf, AppRoutes.travel),
      'trip_items' => either(of('tripId'), AppRoutes.travelTripOf, AppRoutes.travel),
      'travel_documents' => AppRoutes.travelOf(tab: TravelTab.documents.name),
      'packing_templates' => either(
        id,
        AppRoutes.travelTemplateOf,
        AppRoutes.travelOf(tab: TravelTab.templates.name),
      ),
      'learning_goals' => either(id, AppRoutes.growthGoalOf, AppRoutes.growth),
      'goal_logs' => either(of('goalId'), AppRoutes.growthGoalOf, AppRoutes.growth),
      'exercises' || 'workout_logs' => AppRoutes.bodyOf(tab: BodyTab.plan.name),
      'fasting_sessions' => AppRoutes.bodyOf(tab: BodyTab.fasting.name),
      'water_logs' => AppRoutes.bodyOf(tab: BodyTab.water.name),
      'avoid_items' => AppRoutes.bodyOf(tab: BodyTab.avoid.name),
      'food_logs' => AppRoutes.bodyOf(tab: BodyTab.food.name),
      'foods' => AppRoutes.foodLibrary,
      'meal_plans' || 'meal_slots' || 'meal_slot_foods' => AppRoutes.foodPlan,
      'food_rules' => AppRoutes.foodRules,
      'custom_modules' => either(id, AppRoutes.moduleOf, AppRoutes.modules),
      'custom_entries' => either(of('moduleId'), AppRoutes.moduleOf, AppRoutes.modules),
      _ => null,
    };
  }
}

/// The Work package's own navigation, routed (installed app-wide through
/// `lifeHookOverrides`): its boards, projects and the Work screen open as
/// routes. `WorkNavigation.toX` already fires `Sfx.navigate`.
class RoutedWorkRoutes implements WorkRoutes {
  const RoutedWorkRoutes();

  @override
  void work(BuildContext context) => LifeNav.work(context);

  @override
  void board(BuildContext context, String boardId) => LifeNav.board(context, boardId);

  @override
  void projects(BuildContext context) => LifeNav.projects(context);

  @override
  void project(BuildContext context, String projectId) => LifeNav.project(context, projectId);
}

/// Whether decorative backdrops rest (battery saver).
bool _saver(WidgetRef ref) => ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));

/// The enum value of [values] named [name], else [fallback] (pure).
T _named<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// `/work` (the Work screens have no backdrop switch of their own).
class WorkRoutePage extends StatelessWidget {
  const WorkRoutePage({super.key});

  @override
  Widget build(BuildContext context) => const WorkScreen();
}

/// `/work/board/:id` (an unknown board shows the screen's own "missing").
class BoardRoutePage extends StatelessWidget {
  const BoardRoutePage({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context) => BoardScreen(key: ValueKey('board:$boardId'), boardId: boardId);
}

/// `/work/projects`.
class ProjectsRoutePage extends StatelessWidget {
  const ProjectsRoutePage({super.key});

  @override
  Widget build(BuildContext context) => const ProjectsScreen();
}

/// `/work/project/:id` (an unknown project shows the screen's own
/// "missing").
class ProjectRoutePage extends StatelessWidget {
  const ProjectRoutePage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) => ProjectScreen(key: ValueKey('project:$projectId'), projectId: projectId);
}

/// `/family`: a person opens as their route.
class FamilyRoutePage extends ConsumerWidget {
  const FamilyRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FamilyScreen(onOpenPerson: LifeNav.person, animateBackdrop: !_saver(ref));
}

/// `/family/person/:id` (someone deleted shows the screen's own "gone").
class PersonRoutePage extends ConsumerWidget {
  const PersonRoutePage({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PersonScreen(key: ValueKey('person:$personId'), personId: personId, animateBackdrop: !_saver(ref));
}

/// `/travel[?tab=documents|templates]`.
class TravelRoutePage extends ConsumerWidget {
  const TravelRoutePage({super.key, this.tab = TravelTab.trips});

  final TravelTab tab;

  static TravelTab tabOf(String? name) => _named(TravelTab.values, name, TravelTab.trips);

  /// A notification that lands here again opens the screen afresh on [tab]
  /// (see [notificationLandingProvider]).
  @override
  Widget build(BuildContext context, WidgetRef ref) => TravelScreen(
    key: ValueKey('travel:${tab.name}:${ref.watch(notificationLandingProvider)}'),
    initialTab: tab,
    animateBackdrop: !_saver(ref),
  );
}

/// `/travel/trip/:id` (an unknown trip shows the screen's own "not found").
class TripRoutePage extends ConsumerWidget {
  const TripRoutePage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TripScreen(key: ValueKey('trip:$tripId'), tripId: tripId, animateBackdrop: !_saver(ref));
}

/// `/travel/template/:id` – a packing template's items (search results and
/// deep links).
class PackingTemplateRoutePage extends ConsumerWidget {
  const PackingTemplateRoutePage({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PackingTemplateScreen(
    key: ValueKey('template:$templateId'),
    templateId: templateId,
    animateBackdrop: !_saver(ref),
  );
}

/// `/growth` – the learning goals.
class GrowthRoutePage extends ConsumerWidget {
  const GrowthRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GrowthScreen(animateBackdrop: !_saver(ref));
}

/// `/growth/goal/:id` (an unknown goal shows the screen's own "missing").
/// Not Money's savings goals (`GoalsRoutePage`).
class GrowthGoalRoutePage extends ConsumerWidget {
  const GrowthGoalRoutePage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      GoalScreen(key: ValueKey('goal:$goalId'), goalId: goalId, animateBackdrop: !_saver(ref));
}

/// `/body[?tab=plan|fasting|water|avoid]`.
class BodyRoutePage extends ConsumerWidget {
  const BodyRoutePage({super.key, this.tab = BodyTab.today});

  final BodyTab tab;

  static BodyTab tabOf(String? name) => _named(BodyTab.values, name, BodyTab.today);

  /// A notification that lands here again opens the screen afresh on [tab]
  /// (see [notificationLandingProvider]).
  @override
  Widget build(BuildContext context, WidgetRef ref) => BodyScreen(
    key: ValueKey('body:${tab.name}:${ref.watch(notificationLandingProvider)}'),
    initialTab: tab,
    animateBackdrop: !_saver(ref),
  );
}

/// `/food/library` – his food library.
class FoodLibraryRoutePage extends ConsumerWidget {
  const FoodLibraryRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FoodLibraryScreen(animateBackdrop: !_saver(ref));
}

/// `/food/plan` – the meal plan, built and compared against what he ate.
class FoodPlanRoutePage extends ConsumerWidget {
  const FoodPlanRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MealPlanScreen(animateBackdrop: !_saver(ref));
}

/// `/food/rules` – his chronic conditions and his own food rules.
class FoodRulesRoutePage extends ConsumerWidget {
  const FoodRulesRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConditionsScreen(animateBackdrop: !_saver(ref));
}

/// `/food/insights` – the plain observations over his own log.
class FoodInsightsRoutePage extends ConsumerWidget {
  const FoodInsightsRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => NutritionInsightsScreen(animateBackdrop: !_saver(ref));
}

/// `/modules` – the user's own trackers and lists; each opens as its
/// route (the builder stays a pushed flow: it returns the saved id).
class ModulesRoutePage extends ConsumerWidget {
  const ModulesRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CustomModulesScreen(onOpenModule: LifeNav.module, animateBackdrop: !_saver(ref));
}

/// `/modules/module/:id` (an unknown module shows the screen's own empty
/// state).
class ModuleRoutePage extends ConsumerWidget {
  const ModuleRoutePage({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ModuleScreen(key: ValueKey('module:$moduleId'), moduleId: moduleId, animateBackdrop: !_saver(ref));
}
