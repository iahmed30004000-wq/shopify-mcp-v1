import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';

/// Which kitchen screen to open.
enum SufraDestination { tonight, pantry, recipes, rules, history }

/// How «السفرة»'s screens open one another. The default pushes the
/// screen's own route (`/sufra/tonight`, `/sufra/pantry`,
/// `/sufra/recipes`, `/sufra/rules`, `/sufra/history`), so back always
/// returns where she came from; tests override it with a recorder.
typedef SufraNavigator = void Function(BuildContext context, SufraDestination to);

String sufraLocationOf(SufraDestination to) => switch (to) {
  SufraDestination.tonight => AppRoutes.sufraTonight,
  SufraDestination.pantry => AppRoutes.sufraPantry,
  SufraDestination.recipes => AppRoutes.sufraRecipes,
  SufraDestination.rules => AppRoutes.sufraRules,
  SufraDestination.history => AppRoutes.sufraHistory,
};

final sufraNavigatorProvider = Provider<SufraNavigator>(
  (ref) =>
      (context, to) => unawaited(context.push<void>(sufraLocationOf(to))),
);

/// How one dish opens (its own route). Overridden by tests.
typedef SufraRecipeNavigator = void Function(BuildContext context, String recipeId);

final sufraRecipeNavigatorProvider = Provider<SufraRecipeNavigator>(
  (ref) =>
      (context, id) => unawaited(context.push<void>(AppRoutes.sufraRecipeOf(id))),
);

/// How one shopping list opens – Part 3b's own screen, unchanged.
typedef SufraListNavigator = void Function(BuildContext context, String listId);

final sufraListNavigatorProvider = Provider<SufraListNavigator>(
  (ref) =>
      (context, id) => unawaited(context.push<void>(AppRoutes.recordListOf(id))),
);

/// Opens [to] from anywhere inside the kitchen.
void sufraGo(BuildContext context, WidgetRef ref, SufraDestination to) => ref.read(sufraNavigatorProvider)(context, to);

/// Opens one dish.
void sufraOpenRecipe(BuildContext context, WidgetRef ref, String recipeId) =>
    ref.read(sufraRecipeNavigatorProvider)(context, recipeId);

/// Opens one list.
void sufraOpenList(BuildContext context, WidgetRef ref, String listId) =>
    ref.read(sufraListNavigatorProvider)(context, listId);
