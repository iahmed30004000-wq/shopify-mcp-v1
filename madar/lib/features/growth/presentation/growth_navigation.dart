import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import 'goal_screen.dart';
import 'growth_screen.dart';

/// Default navigation inside the Growth planet when the host passes no
/// callback: pushes on the nearest navigator with the shared-axis
/// transition (the app router may route instead through
/// [growthOpenGoalProvider]).
abstract final class GrowthNavigation {
  static Route<void> growthRoute() => PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'growth'),
    pageBuilder: (_, _, _) => const GrowthScreen(),
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Route<void> goalRoute(String goalId) => PageRouteBuilder<void>(
    settings: RouteSettings(name: 'growth/goal', arguments: goalId),
    pageBuilder: (_, _, _) => GoalScreen(goalId: goalId),
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openGrowth(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(growthRoute());
  }

  /// Opens [goalId]'s page ([growthOpenGoalProvider] when the app set one).
  static Future<void> openGoal(BuildContext context, WidgetRef ref, String goalId) async {
    final custom = ref.read(growthOpenGoalProvider);
    Fx.fire(Sfx.navigate);
    if (custom != null) {
      custom(context, goalId);
      return;
    }
    await Navigator.of(context).push(goalRoute(goalId));
  }
}
