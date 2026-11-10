import 'package:flutter/material.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/hifz_models.dart';
import 'hifz_review_screen.dart';
import 'hifz_screen.dart';

/// Opens a review (today's queue, or [only] one item).
typedef HifzStartReview = void Function(BuildContext context, {HifzCard? only});

/// Default navigation between the Hifz screens when the host passes no
/// callbacks: pushes on the nearest navigator with the shared-axis
/// transition (the app router may route instead).
abstract final class HifzNavigation {
  static Route<void> _route(Widget page, String name) => PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> openHifz(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(const HifzScreen(), 'hifz'));
  }

  static Future<void> openReview(BuildContext context, {HifzCard? only}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(HifzReviewScreen(only: only), 'hifz/review'));
  }
}
