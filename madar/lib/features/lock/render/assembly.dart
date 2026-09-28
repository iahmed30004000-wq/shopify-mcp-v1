import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/motion/springs.dart';

/// The pieces of the lock screen's astrolabe, in the order they arrive.
enum AstrolabePart {
  /// The brass limb (the raised rim with the degree scale).
  limb,

  /// The enamel plate (tympan) with its girih engraving.
  plate,

  /// The 24 hour numerals engraved on the limb.
  numerals,

  /// The openwork rete with its flame pointers.
  rete,

  /// The star points at the tips of the rete's pointers.
  stars,

  /// The rule (the pointer turning about the centre).
  rule,

  /// The hub and the core star that ignites last.
  hub,
}

/// Where a part floats before it is assembled, relative to where it rests:
/// a pose in front of or behind the dial, turned and tilted in 3D.
@immutable
class PartPose {
  const PartPose({
    this.scale = 1,
    this.rotation = 0,
    this.tiltX = 0,
    this.tiltY = 0,
    this.offset = Offset.zero,
    this.opacity = 1,
    this.blur = 0,
  });

  static const rest = PartPose();

  /// Uniform scale (> 1: nearer the viewer, < 1: deeper in space).
  final double scale;

  /// Turn about the dial's axis (radians, clockwise).
  final double rotation;

  /// Tilt about the horizontal / vertical axis (radians).
  final double tiltX, tiltY;

  /// Displacement in units of the dial's radius.
  final Offset offset;
  final double opacity;

  /// Depth-of-field blur (logical px).
  final double blur;

  /// The pose [d] of the way from rest to this scattered pose (d may be
  /// slightly negative while a spring overshoots).
  PartPose at(double d) => PartPose(
    scale: 1 + (scale - 1) * d,
    rotation: rotation * d,
    tiltX: tiltX * d,
    tiltY: tiltY * d,
    offset: offset * d,
    opacity: opacity,
    blur: math.max(0, blur * d),
  );

  PartPose withOpacity(double value) => PartPose(
    scale: scale,
    rotation: rotation,
    tiltX: tiltX,
    tiltY: tiltY,
    offset: offset,
    opacity: value,
    blur: blur,
  );

  bool get isRest =>
      (scale - 1).abs() < 1e-4 &&
      rotation.abs() < 1e-4 &&
      tiltX.abs() < 1e-4 &&
      tiltY.abs() < 1e-4 &&
      offset.distanceSquared < 1e-8 &&
      blur < 0.05;
}

/// The assembly choreography as pure maths of one progress value p ∈ [0, 1].
///
/// Every part has a window of p in which it flies in; within its window the
/// part's displacement follows a slightly under-damped spring (it overshoots
/// a hair and settles, "clicking" into place), and it becomes opaque over
/// the first part of the window. Holding the astrolabe drives p to
/// [holdTarget]; waiting for the fingerprint creeps it towards
/// [readingTarget]; success completes it. PIN digits assemble it step by
/// step ([pinTarget]).
abstract final class AssemblyTimeline {
  /// Windows of p per part.
  static const Map<AstrolabePart, (double, double)> windows = {
    AstrolabePart.limb: (0.0, 0.36),
    AstrolabePart.plate: (0.06, 0.42),
    AstrolabePart.numerals: (0.14, 0.56),
    AstrolabePart.rete: (0.3, 0.74),
    AstrolabePart.stars: (0.5, 0.88),
    AstrolabePart.rule: (0.64, 0.94),
    AstrolabePart.hub: (0.8, 1.0),
  };

  /// Progress reached by holding (then the fingerprint prompt opens).
  static const double holdTarget = 0.5;

  /// Progress the dial creeps towards while the fingerprint is read.
  static const double readingTarget = 0.8;

  /// Progress before any digit of a PIN.
  static const double pinBase = 0.22;

  /// Progress after [digits] of a [length]-digit PIN (the last part –
  /// the hub – only ignites once the PIN is accepted).
  static double pinTarget(int digits, int length) {
    if (length <= 0) return pinBase;
    return pinBase + (0.84 - pinBase) * (digits.clamp(0, length) / length);
  }

  /// The lock-in spring: settles with a ~5 % overshoot.
  static final SpringCurve lockSpring = SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 0.66),
  );

  /// A part's own progress (0 … 1) at p.
  static double local(AstrolabePart part, double p) {
    final (s, e) = windows[part]!;
    return ((p - s) / (e - s)).clamp(0.0, 1.0);
  }

  /// Progress of the [i]-th of [count] staggered items (numerals, stars)
  /// inside [part]'s window: each takes [span] of the window.
  static double staggered(AstrolabePart part, int i, int count, double p, {double span = 0.45}) {
    final u = local(part, p);
    if (count <= 1 || u <= 0 || u >= 1) return u;
    final start = (1 - span) * i / (count - 1);
    return ((u - start) / span).clamp(0.0, 1.0);
  }

  /// Remaining displacement (1 = fully scattered, 0 = at rest; briefly
  /// negative while the spring overshoots) for a part progress [u].
  static double displacement(double u) {
    if (u <= 0) return 1;
    if (u >= 1) return 0;
    return 1 - lockSpring.transform(u);
  }

  /// Opacity for a part progress [u]: fades in over the first 40 %.
  static double opacity(double u) => Curves.easeOut.transform((u / 0.4).clamp(0.0, 1.0));

  /// The parts whose window ended between [from] and [to] (moving forward):
  /// each "clicks" into place with a tick.
  static List<AstrolabePart> lockedBetween(double from, double to) {
    if (to <= from) return const [];
    return [
      for (final e in windows.entries)
        if (from < e.value.$2 && to >= e.value.$2) e.key,
    ];
  }

  /// The scattered pose of each part (see [PartPose]); its opacity is the
  /// "ghost" the part shows while it waits, before any assembly.
  static const Map<AstrolabePart, PartPose> scattered = {
    // Deep in space, seen almost edge-on, turning as it comes.
    AstrolabePart.limb: PartPose(
      scale: 0.74,
      rotation: -1.1,
      tiltX: 1.05,
      tiltY: 0.25,
      offset: Offset(0, 0.08),
      opacity: 0.62,
      blur: 1.2,
    ),
    // From behind the viewer: large, soft, barely there at first.
    AstrolabePart.plate: PartPose(scale: 1.75, rotation: 0.5, tiltX: -0.4, tiltY: 0.2, opacity: 0.08, blur: 10),
    // Spinning in from above and to the side.
    AstrolabePart.rete: PartPose(
      scale: 1.3,
      rotation: 2.3,
      tiltX: -0.35,
      tiltY: 0.9,
      offset: Offset(-0.22, -0.4),
      opacity: 0.5,
      blur: 2.2,
    ),
    // Swinging up from below.
    AstrolabePart.rule: PartPose(
      scale: 1.15,
      rotation: 1.25,
      tiltX: 0.35,
      offset: Offset(0.04, 0.52),
      opacity: 0.34,
      blur: 2,
    ),
    AstrolabePart.hub: PartPose(scale: 0.2, rotation: -0.8, opacity: 0, blur: 2),
    AstrolabePart.numerals: PartPose(opacity: 0.32),
    AstrolabePart.stars: PartPose(opacity: 0.5),
  };

  /// The pose of [part] at progress p.
  static PartPose pose(AstrolabePart part, double p) {
    final u = local(part, p);
    final from = scattered[part] ?? PartPose.rest;
    return from.at(displacement(u)).withOpacity(from.opacity + (1 - from.opacity) * opacity(u));
  }
}
