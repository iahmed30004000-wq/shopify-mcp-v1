import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Minimal immutable 3-vector for scene math (no allocation-heavy libraries on
/// the per-frame path; the scene has < 100 bodies).
class V3 {
  const V3(this.x, this.y, this.z);

  static const zero = V3(0, 0, 0);
  static const up = V3(0, 1, 0);

  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  static V3 lerp(V3 a, V3 b, double t) => a + (b - a) * t;

  @override
  String toString() => 'V3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Result of projecting a world point.
class Projected {
  const Projected(this.offset, this.depth, this.scale);

  /// Screen position in logical pixels.
  final Offset offset;

  /// Distance along the camera forward axis (larger = farther).
  final double depth;

  /// Pixels per world unit at this depth (radius of a unit sphere on screen).
  final double scale;

  bool get visible => depth > 0.05;
}

/// A perspective camera orbiting a target.
///
/// World frame: y is up; the orbital (ecliptic) plane of the planets is the
/// x–z plane. The camera sits at [distance] from [target], rotated by
/// [azimuth] around y and raised by [elevation] above the plane, then rolled
/// by [roll] around its forward axis (for a dynamic, slanted composition).
class OrbitCamera {
  const OrbitCamera({
    this.target = V3.zero,
    this.azimuth = 0,
    this.elevation = 0.36,
    this.distance = 7.5,
    this.roll = 0,
    this.fovY = 0.72,
    this.principal = const Offset(0.5, 0.40),
  });

  final V3 target;

  /// Radians.
  final double azimuth, elevation, roll, fovY;
  final double distance;

  /// Principal point as a fraction of the viewport (lens shift) – lets the
  /// scene centre sit above the glass panel.
  final Offset principal;

  V3 get position {
    final ce = math.cos(elevation);
    return target +
        V3(distance * ce * math.sin(azimuth), distance * math.sin(elevation), distance * ce * math.cos(azimuth));
  }

  /// Camera basis (right, up, forward) including roll.
  (V3, V3, V3) get basis {
    final f = (target - position).normalized;
    var r = f.cross(V3.up).normalized;
    if (r.length == 0) r = const V3(1, 0, 0);
    final u = r.cross(f);
    if (roll == 0) return (r, u, f);
    final c = math.cos(roll), s = math.sin(roll);
    return (r * c + u * s, u * c - r * s, f);
  }

  /// Focal length in pixels for a viewport.
  double focalPx(Size viewport) => viewport.height / (2 * math.tan(fovY / 2));

  Projected project(V3 p, Size viewport) {
    final (r, u, f) = basis;
    final rel = p - position;
    final depth = rel.dot(f);
    final fp = focalPx(viewport);
    final safeDepth = depth.abs() < 1e-6 ? 1e-6 : depth;
    final sx = rel.dot(r) * fp / safeDepth;
    final sy = rel.dot(u) * fp / safeDepth;
    final c = Offset(viewport.width * principal.dx, viewport.height * principal.dy);
    return Projected(Offset(c.dx + sx, c.dy - sy), depth, fp / safeDepth);
  }

  /// World-space ray direction through a screen point (for hit testing).
  V3 rayDirection(Offset screen, Size viewport) {
    final (r, u, f) = basis;
    final fp = focalPx(viewport);
    final c = Offset(viewport.width * principal.dx, viewport.height * principal.dy);
    final dx = (screen.dx - c.dx) / fp;
    final dy = -(screen.dy - c.dy) / fp;
    return (f + r * dx + u * dy).normalized;
  }

  OrbitCamera copyWith({
    V3? target,
    double? azimuth,
    double? elevation,
    double? distance,
    double? roll,
    double? fovY,
    Offset? principal,
  }) => OrbitCamera(
    target: target ?? this.target,
    azimuth: azimuth ?? this.azimuth,
    elevation: elevation ?? this.elevation,
    distance: distance ?? this.distance,
    roll: roll ?? this.roll,
    fovY: fovY ?? this.fovY,
    principal: principal ?? this.principal,
  );

  /// Interpolates every parameter (azimuth along the shortest arc).
  static OrbitCamera lerp(OrbitCamera a, OrbitCamera b, double t) {
    var dAz = (b.azimuth - a.azimuth) % (2 * math.pi);
    if (dAz > math.pi) dAz -= 2 * math.pi;
    if (dAz < -math.pi) dAz += 2 * math.pi;
    double l(double x, double y) => x + (y - x) * t;
    return OrbitCamera(
      target: V3.lerp(a.target, b.target, t),
      azimuth: a.azimuth + dAz * t,
      elevation: l(a.elevation, b.elevation),
      distance: l(a.distance, b.distance),
      roll: l(a.roll, b.roll),
      fovY: l(a.fovY, b.fovY),
      principal: Offset.lerp(a.principal, b.principal, t)!,
    );
  }
}

/// Orbital elements of one body around the astrolabe (circular orbit in a
/// plane tilted by [inclination] around the x axis, rotated by [node]).
class OrbitElements {
  const OrbitElements({
    required this.radius,
    required this.phase,
    required this.periodSeconds,
    this.inclination = 0,
    this.node = 0,
  });

  final double radius;

  /// Initial angle (radians).
  final double phase;

  /// Seconds per revolution (slow: minutes). Negative = retrograde.
  final double periodSeconds;
  final double inclination;
  final double node;

  double angleAt(double seconds, {double offset = 0}) =>
      phase + offset + (periodSeconds == 0 ? 0 : 2 * math.pi * seconds / periodSeconds);

  V3 positionAt(double seconds, {double offset = 0, V3 center = V3.zero}) {
    final a = angleAt(seconds, offset: offset);
    // Circle in the x–z plane.
    var p = V3(radius * math.cos(a), 0, radius * math.sin(a));
    // Tilt around x.
    if (inclination != 0) {
      final ci = math.cos(inclination), si = math.sin(inclination);
      p = V3(p.x, p.y * ci - p.z * si, p.y * si + p.z * ci);
    }
    // Rotate the line of nodes around y.
    if (node != 0) {
      final cn = math.cos(node), sn = math.sin(node);
      p = V3(p.x * cn + p.z * sn, p.y, -p.x * sn + p.z * cn);
    }
    return center + p;
  }
}

/// Ray/sphere intersection distance (or null).
double? raySphere(V3 origin, V3 dir, V3 center, double radius) {
  final oc = origin - center;
  final b = oc.dot(dir);
  final c = oc.dot(oc) - radius * radius;
  final h = b * b - c;
  if (h < 0) return null;
  final t = -b - math.sqrt(h);
  return t >= 0 ? t : null;
}
