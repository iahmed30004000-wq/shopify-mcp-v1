import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/cinema/hall/hall.dart' show IrisRouteTransition;
import '../motion/motion.dart';
import '../motion/transitions.dart';
import 'routes.dart';

/// Adapters between the router and Madar Cinema (Phase 7): the hall, one
/// programme entry and the saved web games are routes, so back, deep links
/// and (later) search hits and shared links share one stack.
///
/// In-app links `push` (back returns to the page they were opened from –
/// the Growth world's page, Settings …). Inside the hall, the hall itself
/// pushes its game screen (through its iris) and the Saved Games page.
abstract final class CinemaNav {
  /// The cinema hall.
  static void hall(BuildContext context) => unawaited(context.push<void>(AppRoutes.cinema));

  /// The programme entry [gameId], full screen.
  static void game(BuildContext context, String gameId) =>
      unawaited(context.push<void>(AppRoutes.cinemaGameOf(gameId)));

  /// The saved web games.
  static void savedGames(BuildContext context) => unawaited(context.push<void>(AppRoutes.savedGames));
}

/// Pages of the cinema routes.
abstract final class CinemaRoutePages {
  /// How long a show's iris takes to open / close (the hall's own
  /// `CinemaGameScreen.route`).
  static const Duration irisIn = Duration(milliseconds: 560);
  static const Duration irisOut = Duration(milliseconds: 420);

  /// A show opening through the hall's iris (a circle growing from the
  /// centre over black); a quick fade under reduced motion. Opaque: the
  /// show is full screen.
  static MadarTransitionPage<void> iris({required BuildContext context, required Widget child, LocalKey? key}) =>
      MadarTransitionPage<void>(
        key: key,
        transitionDuration: context.motion(irisIn),
        reverseTransitionDuration: context.motion(irisOut),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            IrisRouteTransition(animation: animation, child: child),
        child: child,
      );
}
