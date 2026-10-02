import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import '../../domain/scene_math.dart';
import '../../render/astrolabe/astrolabe_geometry.dart' show AstrolabeRadii;
import '../../render/planets/planet_frame.dart' show ScreenProjector;
import '../../render/planets/planet_layout.dart';
import '../../render/planets/planet_style.dart';

/// One lane of the system as the composition sees it.
typedef LaneBody = ({PlanetArchetype archetype, double seed});

/// The overview framing of the Astrolabe Orbit on a portrait phone (pure;
/// unit-tested).
///
/// One dominant, centred object: the astrolabe (a disc of [coreRadius]
/// world units around the core star) ringed by the worlds on the lanes of
/// [layout], seen from [elevation] above the orbital plane – high enough
/// that every far-side world clears (or mostly clears) the brass – and
/// rolled by [roll] for a slightly slanted, cinematic composition.
/// [overview] solves the camera distance so the system fills the width
/// (the outermost lanes may [bleed] a little past the screen edges, as a
/// hero shot does) while its full height stays inside the scene rect (the
/// band between the header and the glass panel), then centres it at
/// [centerFraction] of that band.
@immutable
class OrbitComposition {
  const OrbitComposition({
    this.layout = defaultLayout,
    this.coreRadius = 0.58,
    this.elevation = 0.78,
    this.roll = -0.05,
    this.fovY = 1.05,
    this.margin = 6,
    this.bleed = 0.06,
    this.centerFraction = 0.53,
    this.maxCoreFraction = 0.36,
    this.heroFill = 0.8,
    this.heroPrincipal = const Offset(0.5, 0.3),
    this.zoomFill = 0.46,
    this.zoomPrincipal = const Offset(0.5, 0.36),
    this.coreZoomScale = 2.1,
  });

  /// Lanes tuned around a 0.52-unit astrolabe: the innermost world clears
  /// the brass rim with room to spare, the worlds are large enough to show
  /// their living state (auroras, cracks, moons) at overview scale, and the
  /// outermost lane still fits a 412-px-wide phone (with the bleed).
  static const defaultLayout = PlanetSystemLayout(
    innerRadius: 0.9,
    outerRadius: 1.2,
    minLaneGap: 0.042,
    bodyRadius: 0.155,
  );

  final PlanetSystemLayout layout;

  /// Limb radius of the astrolabe in world units (the dial is a billboard
  /// facing the camera, centred on the core star).
  final double coreRadius;

  /// Overview camera angles (radians). The camera sits ~37° above the
  /// orbital plane, close to the system with a wide lens: the orbits open
  /// into ellipses whose far side rises clear of the dial and the near
  /// worlds read ~1.5× the size of the far ones – a system in depth, not a
  /// clock face with stickers.
  final double elevation, roll, fovY;

  /// Gap (logical px) kept between the system and the scene rect's top and
  /// bottom edges.
  final double margin;

  /// How far (fraction of the viewport width, per side) the outermost
  /// lanes may run past the screen edges.
  final double bleed;

  /// Where the system's centre sits in the scene rect (fraction of its
  /// height from the top).
  final double centerFraction;

  /// With few (or no) worlds the dial is capped at this fraction of the
  /// viewport width (radius), so it never fills the screen.
  final double maxCoreFraction;

  /// Fly-in end: the world's disc radius as a fraction of half the
  /// viewport's shorter side, and where its centre sits (lens shift; see
  /// [heroPrincipalFor] for the one that lands it on the page's sheet).
  final double heroFill;
  final Offset heroPrincipal;

  /// Top of the planet page's glass sheet (fraction of the height) and how
  /// far (px) the world's lower edge sinks under it at the end of a fly-in:
  /// the page rises from the world's surface.
  static const double heroSheetTop = 0.455, heroSink = 24;

  /// The hero lens shift for [viewport]: horizontally centred, the world's
  /// lower edge [heroSink] px under the sheet's top edge.
  Offset heroPrincipalFor(Size viewport) {
    if (viewport.isEmpty) return heroPrincipal;
    final r = heroFill * math.min(viewport.width, viewport.height) / 2;
    final cy = heroSheetTop * viewport.height + heroSink - r;
    return Offset(heroPrincipal.dx, (cy / viewport.height).clamp(0.2, 0.5));
  }

  /// Pinch-zoom end on a world.
  final double zoomFill;
  final Offset zoomPrincipal;

  /// Pinch-zoom on the astrolabe: how much larger the dial gets at full zoom.
  final double coreZoomScale;

  /// How much of a world's halo must stay inside the scene rect (× disc).
  static const double haloAllowance = 1.22;

  /// The overview camera for [lanes] (lane order) in [viewport], fitting the
  /// system inside [sceneRect] (see the class docs).
  OrbitCamera overview({required Size viewport, required Rect sceneRect, required List<LaneBody> lanes}) {
    if (viewport.isEmpty) return PlanetSystemLayout.overviewCamera;
    final maxW = viewport.width * (1 + 2 * bleed);
    final maxH = math.max(1.0, sceneRect.height - 2 * margin);
    var cam = OrbitCamera(elevation: elevation, roll: roll, fovY: fovY, distance: 8, principal: const Offset(0.5, 0.5));
    // Distance: the nearest camera whose projected system fits.
    var lo = 1.5, hi = 80.0;
    for (var i = 0; i < 28; i++) {
      final mid = math.sqrt(lo * hi);
      final b = bounds(cam.copyWith(distance: mid), viewport, lanes);
      final fits = b.width <= maxW && b.height <= maxH;
      if (fits) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    cam = cam.copyWith(distance: hi);
    // Few worlds: never let the dial grow beyond maxCoreFraction.
    final coreMax = viewport.width * maxCoreFraction;
    final corePx = coreRadius * cam.focalPx(viewport) / cam.distance;
    if (corePx > coreMax) cam = cam.copyWith(distance: cam.distance * corePx / coreMax);
    // Lens shift: centred across, at centerFraction of the band down (kept
    // inside the band).
    final b = bounds(cam, viewport, lanes);
    var cy = sceneRect.top + centerFraction * sceneRect.height;
    final half = b.height / 2;
    final top = sceneRect.top + margin, bottom = sceneRect.bottom - margin;
    if (b.height <= bottom - top) cy = cy.clamp(top + half, bottom - half);
    final targetCenter = Offset(sceneRect.center.dx, cy);
    final shift = targetCenter - b.center;
    return cam.copyWith(principal: Offset(0.5 + shift.dx / viewport.width, 0.5 + shift.dy / viewport.height));
  }

  /// Screen bounds (logical px) of the whole system through [camera]: the
  /// astrolabe with its halo, and every lane's world disc × halo sampled all
  /// the way round its (inclined) orbit.
  Rect bounds(OrbitCamera camera, Size viewport, List<LaneBody> lanes, {int samples = 48}) {
    final pr = ScreenProjector()..configure(camera, viewport);
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    void add(double x, double y, double r) {
      minX = math.min(minX, x - r);
      maxX = math.max(maxX, x + r);
      minY = math.min(minY, y - r);
      maxY = math.max(maxY, y + r);
    }

    if (pr.project(0, 0, 0)) add(pr.x, pr.y, coreRadius * AstrolabeRadii.halo * pr.scale);
    for (var i = 0; i < lanes.length; i++) {
      final lane = layout.laneRadius(i, lanes.length);
      final body = lanes[i];
      // The disc and the brightest part of its glow (a gas giant's faint
      // outer rings may brush the edge).
      final r = layout.bodyRadiusOf(body.archetype) * math.min(PlanetStyle.haloFactorOf(body.archetype), haloAllowance);
      final inc = layout.inclinationOf(body.seed), node = layout.nodeOf(body.seed);
      for (var k = 0; k < samples; k++) {
        final p = PlanetSystemLayout.orbitPoint(lane, 2 * math.pi * k / samples, inclination: inc, node: node);
        if (pr.project(p.x, p.y, p.z)) add(pr.x, pr.y, r * pr.scale);
      }
    }
    if (minX == double.infinity) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// The astrolabe's limb radius (px) through [camera].
  double corePixels(OrbitCamera camera, Size viewport) {
    final core = camera.project(V3.zero, viewport);
    return core.visible ? coreRadius * core.scale : 0;
  }
}
