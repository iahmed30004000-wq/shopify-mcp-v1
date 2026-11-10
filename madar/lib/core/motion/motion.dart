import 'package:flutter/widgets.dart';

/// Madar's single motion language.
///
/// * Everything physical (sheets, cards, drag release, planets) moves on
///   springs.
/// * Everything choreographed (entrances, page transitions) uses the durations
///   and curves below.
/// * When reduced motion is on, durations collapse to [reduced] and springs are
///   replaced by short cross-fades – see [MotionScope].
abstract final class MadarMotion {
  static const micro = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 360);
  static const long = Duration(milliseconds: 560);

  /// Planet fly-in / fly-out. Quality gate: must complete in < 800 ms.
  static const cinematic = Duration(milliseconds: 760);

  /// Used instead of any duration when reduced motion is on.
  static const reduced = Duration(milliseconds: 90);

  /// Delay between siblings in a staggered entrance.
  static const staggerStep = Duration(milliseconds: 45);

  /// Max total stagger so long lists never feel slow.
  static const staggerCap = Duration(milliseconds: 400);

  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Camera moves through space: slow start, confident middle, soft landing.
  static const Curve orbital = Cubic(0.65, 0.0, 0.25, 1.0);

  /// Springs (mass 1). `ratio` < 1 overshoots.
  static final SpringDescription gentle =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 180, ratio: 0.92);
  static final SpringDescription snappy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 0.82);
  static final SpringDescription bouncy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.58);
  static final SpringDescription cinematicSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 95, ratio: 1.0);

  /// Scale applied to pressed interactive surfaces.
  static const double pressScale = 0.965;
}

/// Provides the effective reduced-motion flag (system accessibility setting OR
/// the in-app override) to the widget tree.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool reducedOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    if (scope != null) return scope.reduced;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) => oldWidget.reduced != reduced;
}

extension MotionContext on BuildContext {
  bool get reducedMotion => MotionScope.reducedOf(this);

  /// [d] unless reduced motion is on.
  Duration motion(Duration d) => reducedMotion ? MadarMotion.reduced : d;
}
