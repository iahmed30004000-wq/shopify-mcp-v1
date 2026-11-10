import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/adhkar_models.dart';
import 'adhkar_home_screen.dart';
import 'adhkar_reader_screen.dart';
import 'tasbeeh_screen.dart';

/// Default navigation between the adhkar screens when the host passes no
/// callbacks: pushes on the nearest navigator with the shared-axis
/// transition (the app router may route instead).
abstract final class AdhkarNavigation {
  static Route<void> _route(Widget page, String name) => PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openSet(BuildContext context, AdhkarCategoryId category, {Prayer? prayer}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context)
        .push(_route(AdhkarReaderScreen(category: category, prayer: prayer), 'adhkar/${category.name}'));
  }

  static Future<void> openTasbeeh(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(const TasbeehScreen(), 'adhkar/tasbeeh'));
  }

  static Future<void> openHome(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(const AdhkarHomeScreen(), 'adhkar'));
  }
}

/// Opens a set (the host's router, or [AdhkarNavigation.openSet]).
typedef AdhkarOpenSet = void Function(BuildContext context, AdhkarCategoryId category, Prayer? prayer);

/// Opens the tasbeeh / the adhkar home.
typedef AdhkarOpenScreen = void Function(BuildContext context);
