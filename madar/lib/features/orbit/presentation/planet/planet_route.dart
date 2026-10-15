import 'package:flutter/widgets.dart';

import '../../../../core/motion/motion.dart';
import '../scene/flight.dart';
import 'planet_page.dart';

/// The go_router page of `/planet/:key`: a transparent route over home. Its
/// animation is the fly-in – the orbit scene underneath follows it (see
/// `OrbitFlight`) – and popping it (back button, system back gesture) plays
/// the exact reverse. Home stays put underneath (no fade-through), so the
/// persistent orbit scene is what the user sees fly.
class PlanetRoutePage extends Page<void> {
  const PlanetRoutePage({super.key, super.name, required this.planetKey, this.item, this.reducedMotion = false});

  /// The world to open.
  final String planetKey;

  /// A moon / record to highlight (`refTable:refId`).
  final String? item;

  /// Reduced motion: a quick cross-fade instead of the flight.
  final bool reducedMotion;

  /// Fly-in and fly-out duration (< 800 ms quality gate).
  Duration get duration => reducedMotion ? MadarMotion.reduced : FlightTiming.duration;

  @override
  Route<void> createRoute(BuildContext context) => _PlanetRoute(this);
}

class _PlanetRoute extends PageRoute<void> {
  _PlanetRoute(PlanetRoutePage page) : super(settings: page);

  PlanetRoutePage get _page => settings as PlanetRoutePage;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _page.duration;

  @override
  Duration get reverseTransitionDuration => _page.duration;

  /// Home underneath must not run its own exit transition: the scene is the
  /// transition.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: PlanetModulePage(key: ValueKey(_page.planetKey), planetKey: _page.planetKey, item: _page.item),
      );

  /// The flight is the transition; under reduced motion the scene stays
  /// still and the page simply cross-fades in.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _page.reducedMotion ? FadeTransition(opacity: animation, child: child) : child;
}
