import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/motion_kit.dart';
import 'goals_screen.dart';
import 'jar_screen.dart';

/// How the goals package opens its own screens. The default pushes them
/// with the shared-axis transition; the app may override
/// [goalsNavigationProvider] to route them through go_router instead.
class GoalsNavigation {
  const GoalsNavigation();

  Future<void> _push(BuildContext context, Widget child) =>
      Navigator.of(context)
          .push<void>(MadarTransitions.sharedAxis<void>(context: context, child: child).createRoute(context));

  /// A jar's detail screen.
  Future<void> openJar(BuildContext context, String jarId) => _push(context, JarScreen(jarId: jarId));

  /// The goals screen on [tab] (the Money hub's "see all").
  Future<void> openGoals(BuildContext context, {GoalsTab tab = GoalsTab.jars}) =>
      _push(context, GoalsScreen(initialTab: tab));
}

final goalsNavigationProvider = Provider<GoalsNavigation>((ref) => const GoalsNavigation());
