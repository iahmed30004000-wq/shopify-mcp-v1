import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';

/// Which food screen to open.
enum NutritionDestination { library, plan, rules, insights }

/// How the food screens open one another. The default pushes the screen's
/// own route (`/food/library`, `/food/plan`, `/food/rules`,
/// `/food/insights`), so back always returns where he came from; tests
/// override it with a recorder.
typedef NutritionNavigator = void Function(BuildContext context, NutritionDestination to);

String nutritionLocationOf(NutritionDestination to) => switch (to) {
  NutritionDestination.library => AppRoutes.foodLibrary,
  NutritionDestination.plan => AppRoutes.foodPlan,
  NutritionDestination.rules => AppRoutes.foodRules,
  NutritionDestination.insights => AppRoutes.foodInsights,
};

final nutritionNavigatorProvider = Provider<NutritionNavigator>(
  (ref) => (context, to) => unawaited(context.push<void>(nutritionLocationOf(to))),
);

/// Opens [to] from anywhere inside the food screens.
void nutritionGo(BuildContext context, WidgetRef ref, NutritionDestination to) =>
    ref.read(nutritionNavigatorProvider)(context, to);
