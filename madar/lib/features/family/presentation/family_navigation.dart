import 'package:flutter/material.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import 'family_screen.dart';
import 'person_screen.dart';

/// Opens a person's page (the app router may route instead).
typedef FamilyOpenPerson = void Function(BuildContext context, String personId);

/// Default navigation between the Family screens when the host passes no
/// callbacks: pushes on the nearest navigator with the shared-axis
/// transition.
abstract final class FamilyNavigation {
  static Route<void> _route(Widget page, String name) => PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openFamily(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(const FamilyScreen(), 'family'));
  }

  static Future<void> openPerson(BuildContext context, String personId) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(PersonScreen(personId: personId), 'family/person'));
  }
}
