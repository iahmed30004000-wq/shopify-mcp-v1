import 'package:flutter/material.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/wird_providers.dart';
import 'wird_screen.dart';

/// Default navigation to the wird screen when the host passes no callback:
/// pushes on the nearest navigator with the shared-axis transition (the app
/// router may route instead).
abstract final class WirdNavigation {
  static Route<void> route({WirdReadNow? onReadNow, String? planId}) => PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'wird'),
    pageBuilder: (_, _, _) => WirdScreen(onReadNow: onReadNow, initialPlanId: planId),
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openWird(BuildContext context, {WirdReadNow? onReadNow, String? planId}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(route(onReadNow: onReadNow, planId: planId));
  }
}
