/// How the gym's screens open one another.
///
/// Every hop goes through a provider, so the app pushes a real route (back
/// returns where he came from) and a test can record where a tap would have
/// led without building the whole router.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';

/// Where the gym can go.
abstract final class GymRoutes {
  /// Today's session, set by set.
  static String get session => AppRoutes.gymSession;

  /// His named training days.
  static String get templates => AppRoutes.gymTemplates;

  /// One exercise's own page.
  static String exercise(String id) => AppRoutes.gymExerciseOf(id);
}

typedef GymNavigator = void Function(BuildContext context, String location);

final gymNavigatorProvider = Provider<GymNavigator>(
  (ref) => (context, location) => unawaited(context.push<void>(location)),
);

/// Opens [location] from anywhere inside the Body planet.
void gymGo(BuildContext context, WidgetRef ref, String location) =>
    ref.read(gymNavigatorProvider)(context, location);
