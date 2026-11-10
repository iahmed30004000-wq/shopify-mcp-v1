import 'dart:math' as math;

/// The four tilings the generator knows. Each is a periodic tiling with a
/// single "medallion" polygon at the origin whose rotational symmetry gives
/// the family its name.
enum PatternFamily {
  /// 4-fold lattice, octagon + square (4.8.8): the 8-point khatam.
  square4(medallionSymmetry: 8, latticeSymmetry: 4, defaultContactAngle: math.pi / 4, maxContactAngle: 1.5),

  /// 6-fold lattice, hexagon + triangles (3.6.3.6): six-pointed stars.
  hex6(medallionSymmetry: 6, latticeSymmetry: 6, defaultContactAngle: math.pi / 3, maxContactAngle: 1.5),

  /// 5/10-fold girih-style: decagons whose gaps are the girih "bow-tie"
  /// (a periodic approximant; true 10-fold order cannot tile a lattice).
  /// The bow-tie's reflex corners cap how open the rays may be.
  girih10(medallionSymmetry: 10, latticeSymmetry: 2, defaultContactAngle: 0.46, maxContactAngle: 0.52),

  /// 12-fold rosette: dodecagons + triangles (3.12.12).
  rosette12(medallionSymmetry: 12, latticeSymmetry: 6, defaultContactAngle: math.pi / 3, maxContactAngle: 1.5);

  const PatternFamily({
    required this.medallionSymmetry,
    required this.latticeSymmetry,
    required this.defaultContactAngle,
    required this.maxContactAngle,
  });

  /// Rotational symmetry order of the central medallion (8, 6, 10, 12).
  final int medallionSymmetry;

  /// Rotational symmetry order of the whole infinite pattern's lattice.
  final int latticeSymmetry;

  /// Angle (radians) between each ray and its tile edge when none is given.
  final double defaultContactAngle;

  /// Largest angle for which every ray still meets inside its tile.
  final double maxContactAngle;

  /// Smallest useful angle: below this the rays hug the edges and the
  /// pattern collapses to the tile outlines.
  static const double minContactAngle = 0.1;
}

/// What to build: the tiling, the contact angle of the Hankin rays and the
/// paint-time look (line width, density). Value-equal, so usable as a cache
/// key. Geometry depends only on [family] and the resolved contact angle.
class PatternSpec {
  const PatternSpec({required this.family, this.contactAngle, this.lineWidth = 1.2, this.repeat = 6});

  final PatternFamily family;

  /// Radians between a ray and its edge; `null`, NaN or out-of-range values
  /// fall back to the family default / are clamped (never throws, never NaN).
  final double? contactAngle;

  /// Stroke width in logical pixels at paint time (clamped 0.2 to 24).
  final double lineWidth;

  /// Cells across the painted width in tiled use (clamped 1 to 40).
  final int repeat;

  double get resolvedContactAngle {
    final a = contactAngle;
    if (a == null || a.isNaN) return family.defaultContactAngle;
    return a.clamp(PatternFamily.minContactAngle, family.maxContactAngle).toDouble();
  }

  double get resolvedLineWidth {
    if (lineWidth.isNaN) return 1.2;
    return lineWidth.clamp(0.2, 24.0).toDouble();
  }

  int get resolvedRepeat => repeat.clamp(1, 40);

  PatternSpec copyWith({PatternFamily? family, double? contactAngle, double? lineWidth, int? repeat}) => PatternSpec(
    family: family ?? this.family,
    contactAngle: contactAngle ?? this.contactAngle,
    lineWidth: lineWidth ?? this.lineWidth,
    repeat: repeat ?? this.repeat,
  );

  @override
  bool operator ==(Object other) =>
      other is PatternSpec &&
      other.family == family &&
      other.resolvedContactAngle == resolvedContactAngle &&
      other.resolvedLineWidth == resolvedLineWidth &&
      other.resolvedRepeat == resolvedRepeat;

  @override
  int get hashCode => Object.hash(family, resolvedContactAngle, resolvedLineWidth, resolvedRepeat);

  @override
  String toString() => 'PatternSpec($family, angle: $resolvedContactAngle, line: $resolvedLineWidth, x$resolvedRepeat)';
}
