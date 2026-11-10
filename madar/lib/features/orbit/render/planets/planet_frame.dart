import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../../domain/orbit_moons.dart';
import '../../domain/scene_math.dart';
import 'planet_body.dart';

/// Projects world points with a camera, caching its basis for the frame (no
/// per-point basis maths, no allocation per projection: results land in
/// [x], [y], [depth], [scale]).
class ScreenProjector {
  V3 right = const V3(1, 0, 0), up = V3.up, forward = const V3(0, 0, -1), eye = V3.zero;
  double focal = 1, cx = 0, cy = 0;

  double x = 0, y = 0, depth = 0, scale = 0;

  void configure(OrbitCamera camera, Size viewport) {
    final (r, u, f) = camera.basis;
    right = r;
    up = u;
    forward = f;
    eye = camera.position;
    focal = camera.focalPx(viewport);
    cx = viewport.width * camera.principal.dx;
    cy = viewport.height * camera.principal.dy;
  }

  /// Projects ([px], [py], [pz]); returns whether it is in front of the eye.
  bool project(double px, double py, double pz) {
    final rx = px - eye.x, ry = py - eye.y, rz = pz - eye.z;
    final d = rx * forward.x + ry * forward.y + rz * forward.z;
    depth = d;
    final safe = d.abs() < 1e-6 ? 1e-6 : d;
    final s = focal / safe;
    scale = s;
    x = cx + (rx * right.x + ry * right.y + rz * right.z) * s;
    y = cy - (rx * up.x + ry * up.y + rz * up.z) * s;
    return d > 0.05;
  }
}

/// One world in one frame (mutable, reused from frame to frame).
class BodyFrame {
  BodyFrame(this.body);

  PlanetBody body;

  /// Position in the planet list (lane order).
  int index = 0;

  V3 world = V3.zero;
  double worldRadius = 0;

  /// The orbit: lane radius (world units, spring-animated after a reorder),
  /// tilt, line of nodes and the world's angle on it – for the orbit guide.
  double lane = 1, inclination = 0, node = 0, angle = 0;

  /// Disc centre and radius on screen (logical px).
  Offset center = Offset.zero;
  double radius = 0;

  /// Distance along the camera's forward axis (larger = farther).
  double depth = 0;

  /// Drawn this frame (in front of the camera, big enough, on screen).
  bool visible = false;

  /// Farther than the core star: drawn before the astrolabe.
  bool behindCore = false;

  /// How much of the disc the astrolabe covers (0..1; 0 when in front of
  /// it). Past half, the world is also drawn over the dial as a faint,
  /// gold-rimmed ghost (and stays tappable there) – no world ever hides
  /// entirely behind the brass.
  double coreOcclusion = 0;

  /// Drawn over the dial as a ghost (see [coreOcclusion]).
  bool get ghosted => behindCore && visible && coreOcclusion > PlanetViewGhost.threshold;

  /// `uLight` (view space).
  double lightX = 0, lightY = 0, lightZ = 1;

  /// `uSpin.x` / `uSpin.y`.
  double spin = 0, tilt = 0;

  /// Displayed (spring) score and pulse.
  double score = 0.6, pulse = 0;

  /// `uDetail`.
  double detail = 0.5;

  /// Shader draw rect (disc × haloFactor).
  Rect drawRect = Rect.zero;

  /// Where the name label wants to be (0 hidden … 1 shown), before fading.
  double labelTarget = 0;

  /// How much the orbit guide shows (fades with a fly-in to another world).
  double guideOpacity = 1;

  /// Draw opacity (a world between the camera and the fly-in's target fades
  /// out; 1 otherwise).
  double opacity = 1;

  /// 0 (the nearest world) … 1 (the farthest): how much sky-coloured haze
  /// and ambient light the world takes (aerial perspective).
  double haze = 0;

  /// The world's moons (same order as [PlanetBody.moons]).
  final List<MoonFrame> moons = [];

  String get key => body.key;

  /// Distance from [p] to the disc centre in disc radii.
  double normalizedDistance(Offset p) => radius <= 0 ? double.infinity : (p - center).distance / radius;

  /// Screen rect of the disc.
  Rect get discRect => Rect.fromCircle(center: center, radius: radius);
}

/// One data moon in one frame (mutable, reused).
class MoonFrame {
  MoonFrame(this.moon);

  OrbitMoon moon;
  V3 world = V3.zero;
  double worldRadius = 0;
  Offset center = Offset.zero;
  double radius = 0;
  double depth = 0;
  bool visible = false;

  /// Nearer than its planet: drawn after (over) it.
  bool front = true;

  double lightX = 0, lightY = 0, lightZ = 1;
  double spin = 0, tilt = 0;
  double score = 0.6, pulse = 0, detail = 0.3;

  /// `uExtra.y` – the selection ring.
  double selected = 0;

  /// 0 → 1 as a new moon arrives.
  double appear = 1;

  /// Draw opacity (fades with its world when that world hides a fly-in's
  /// target).
  double opacity = 1;

  Rect drawRect = Rect.zero;

  /// Where the name label wants to be (0 hidden … 1 shown), before fading.
  double labelTarget = 0;

  String get id => moon.id;

  /// Touch target: the disc, never smaller than a comfortable fingertip.
  Rect get hitRect => Rect.fromCircle(center: center, radius: math.max(radius * 1.3, MoonHitTest.minTouchRadius));
}

/// The ghost of a world hidden behind the astrolabe.
abstract final class PlanetViewGhost {
  /// Occlusion above which a world behind the dial is ghosted over it.
  static const double threshold = 0.5;

  /// Fraction of the disc of radius [r] at [c] covered by the disc of
  /// radius [coreR] at [core] (exact circle–circle intersection).
  static double occlusion(Offset c, double r, Offset core, double coreR) {
    if (r <= 0 || coreR <= 0) return 0;
    final d = (c - core).distance;
    if (d >= r + coreR) return 0;
    if (d <= (coreR - r).abs()) return coreR >= r ? 1 : (coreR * coreR) / (r * r);
    final r2 = r * r, cr2 = coreR * coreR;
    final a1 = r2 * math.acos(((d * d + r2 - cr2) / (2 * d * r)).clamp(-1.0, 1.0));
    final a2 = cr2 * math.acos(((d * d + cr2 - r2) / (2 * d * coreR)).clamp(-1.0, 1.0));
    final k = 0.5 * math.sqrt(math.max(0.0, (-d + r + coreR) * (d + r - coreR) * (d - r + coreR) * (d + r + coreR)));
    return ((a1 + a2 - k) / (math.pi * r2)).clamp(0.0, 1.0);
  }
}

/// Touch targets of the orbit.
abstract final class MoonHitTest {
  /// Smallest touch radius of a moon (logical px): a 48 dp target.
  static const minTouchRadius = 24.0;

  /// Smallest touch radius of a planet (logical px).
  static const minPlanetTouchRadius = 24.0;

  /// Moons smaller than this on screen cannot be tapped (zoom in first).
  static const minTappableMoonRadius = 2.2;
}

/// What a tap at a point of the orbit landed on.
@immutable
class OrbitHit {
  const OrbitHit.planet(this.planetKey, this.rect) : moon = null;
  const OrbitHit.moon(this.planetKey, OrbitMoon this.moon, this.rect);

  final String planetKey;

  /// The moon, or null for the planet itself.
  final OrbitMoon? moon;

  /// Screen rect of what was hit (for a cosmic-zoom origin, a burst …).
  final Rect rect;

  bool get isMoon => moon != null;

  @override
  bool operator ==(Object other) =>
      other is OrbitHit && other.planetKey == planetKey && other.moon?.id == moon?.id && other.rect == rect;

  @override
  int get hashCode => Object.hash(planetKey, moon?.id, rect);

  @override
  String toString() => isMoon ? 'OrbitHit(moon ${moon!.id} of $planetKey)' : 'OrbitHit(planet $planetKey)';
}

/// The whole planet layer in one frame.
class PlanetFrame {
  PlanetFrame();

  Size viewport = Size.zero;
  OrbitCamera camera = const OrbitCamera();

  /// Monotonic id (increments with every rebuilt frame).
  int id = 0;

  /// The core star on screen and its depth (splits the planets into those
  /// behind the astrolabe and those in front of it).
  Offset coreCenter = Offset.zero;
  double coreDepth = 0;

  /// Radius (px) of the astrolabe disc around [coreCenter]: labels avoid it
  /// and worlds hidden behind it keep their labels down.
  double coreRadius = 0;

  /// Every body, in lane order (visible or not).
  final List<BodyFrame> bodies = [];

  /// Visible bodies, farthest first (painter's order).
  final List<BodyFrame> drawOrder = [];

  BodyFrame? body(String key) {
    for (final b in bodies) {
      if (b.key == key) return b;
    }
    return null;
  }

  MoonFrame? moon(String id) {
    for (final b in bodies) {
      for (final m in b.moons) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  /// Screen rect of a visible planet's disc.
  Rect? planetRect(String key) {
    final b = body(key);
    return b == null || !b.visible ? null : b.discRect;
  }

  /// Screen rect (touch target) of a visible moon.
  Rect? moonRect(String id) {
    final m = moon(id);
    return m == null || !m.visible ? null : m.hitRect;
  }

  /// Touch targets of every visible, tappable moon (`people:<id>` → rect).
  Map<String, Rect> moonRects() => {
    for (final b in drawOrder)
      for (final m in b.moons)
        if (m.visible && m.radius >= MoonHitTest.minTappableMoonRadius) m.id: m.hitRect,
  };

  /// What a tap at [p] lands on: the topmost disc under the finger, else
  /// the nearest target within a fingertip's reach, else null (empty sky).
  OrbitHit? hitTest(Offset p) {
    // 1. Exact: topmost first (reverse painter's order).
    for (var i = drawOrder.length - 1; i >= 0; i--) {
      final b = drawOrder[i];
      if (b.opacity < 0.5) continue;
      for (final m in _moonsNearFirst(b, front: true)) {
        if (_tappable(m) && (p - m.center).distance <= math.max(m.radius * 1.1, 3)) {
          return OrbitHit.moon(b.key, m.moon, m.hitRect);
        }
      }
      // Only a world actually drawn can be tapped (a body kept in the draw
      // order for its moons, or behind the camera, is not).
      if (b.visible && (p - b.center).distance <= b.radius * 1.02) return OrbitHit.planet(b.key, b.discRect);
      for (final m in _moonsNearFirst(b, front: false)) {
        if (_tappable(m) && (p - m.center).distance <= math.max(m.radius * 1.1, 3)) {
          return OrbitHit.moon(b.key, m.moon, m.hitRect);
        }
      }
    }
    // 2. Forgiving: the nearest target relative to its reach.
    OrbitHit? best;
    var bestScore = 1.0;
    for (var i = drawOrder.length - 1; i >= 0; i--) {
      final b = drawOrder[i];
      if (b.opacity < 0.5) continue;
      if (b.visible) {
        final reach = math.max(b.radius * 1.18, MoonHitTest.minPlanetTouchRadius);
        final s = (p - b.center).distance / reach;
        if (s < bestScore) {
          bestScore = s;
          best = OrbitHit.planet(b.key, b.discRect);
        }
      }
      for (final m in b.moons) {
        if (!_tappable(m)) continue;
        final r = math.max(m.radius * 1.4, MoonHitTest.minTouchRadius);
        final ms = (p - m.center).distance / r;
        if (ms < bestScore) {
          bestScore = ms;
          best = OrbitHit.moon(b.key, m.moon, m.hitRect);
        }
      }
    }
    return best;
  }

  static bool _tappable(MoonFrame m) => m.visible && m.radius >= MoonHitTest.minTappableMoonRadius;

  static Iterable<MoonFrame> _moonsNearFirst(BodyFrame b, {required bool front}) {
    final list = [
      for (final m in b.moons)
        if (m.front == front) m,
    ]..sort((a, c) => a.depth.compareTo(c.depth));
    return list;
  }
}
