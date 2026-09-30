import 'dart:math' as math;
import 'dart:ui' show Locale, Offset, Rect, Size;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/presentation/scene/camera_rig.dart';
import 'package:madar/features/orbit/presentation/scene/flight.dart';
import 'package:madar/features/orbit/presentation/scene/scene_composition.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import '../render/planets/planet_fixtures.dart';

const _phone = Size(412, 915);

/// The band home leaves for the system: under the 64-px header, above the
/// collapsed glass panel (57.5 % of the height).
final _band = Rect.fromLTRB(0, 68, 412, 915 * 0.575 - 8);

List<LaneBody> _lanesOf(List<PlanetBody> bodies) => [for (final b in bodies) (archetype: b.archetype, seed: b.seed)];

/// Every world's disc (all the way round its orbit) inside [rect] – the
/// sides widened by the composition's bleed (a world may graze the screen
/// edge for a moment).
void _expectFits(OrbitComposition c, OrbitCamera cam, Size viewport, Rect band, List<PlanetBody> bodies) {
  final l = c.layout;
  final rect = Rect.fromLTRB(
    band.left - viewport.width * c.bleed,
    band.top,
    band.right + viewport.width * c.bleed,
    band.bottom,
  );
  for (var i = 0; i < bodies.length; i++) {
    final b = bodies[i];
    final lane = l.laneRadius(i, bodies.length);
    for (var k = 0; k < 180; k++) {
      final p = PlanetSystemLayout.orbitPoint(
        lane,
        2 * math.pi * k / 180,
        inclination: l.inclinationOf(b.seed),
        node: l.nodeOf(b.seed),
      );
      final pr = cam.project(p, viewport);
      final r = l.bodyRadiusOf(b.archetype) * pr.scale;
      final disc = Rect.fromCircle(center: pr.offset, radius: r);
      expect(
        rect.inflate(0.5).contains(disc.topLeft) && rect.inflate(0.5).contains(disc.bottomRight),
        isTrue,
        reason: '${b.key} at ${(k * 2)}° → $disc outside $rect',
      );
    }
  }
}

SceneController _scene({List<PlanetBody>? bodies, Size size = _phone, Rect? band}) {
  final c = SceneController(initialTime: 12, now: DateTime(2026, 9, 27, 12, 30));
  c.setBodies(bodies ?? PlanetFixtures.system(), animate: false);
  c.layout(size, band ?? _band);
  final labels = AstrolabeLabels(lookupL10n(const Locale('ar')), MadarFormatter());
  c.setAstrolabeState(
    AstrolabeState.fromSchedule(
      schedule: PrayerSchedule(const PrayerSettings()),
      now: DateTime(2026, 9, 27, 12, 30),
      labels: labels,
    ),
    animate: false,
  );
  c.refresh();
  return c;
}

/// A route animation the test drives by hand.
AnimationController _route() => AnimationController(
  vsync: const TestVSync(),
  duration: FlightTiming.duration,
  reverseDuration: FlightTiming.duration,
);

void main() {
  group('OrbitComposition', () {
    const c = OrbitComposition();

    test('the eight default worlds fit a portrait phone above the panel', () {
      final bodies = PlanetFixtures.system();
      final cam = c.overview(viewport: _phone, sceneRect: _band, lanes: _lanesOf(bodies));
      _expectFits(c, cam, _phone, _band, bodies);
    });

    test('the astrolabe dominates: big enough to read, centred in the upper 40 %', () {
      final bodies = PlanetFixtures.system();
      final cam = c.overview(viewport: _phone, sceneRect: _band, lanes: _lanesOf(bodies));
      final core = cam.project(V3.zero, _phone);
      final r = c.corePixels(cam, _phone);
      expect(
        AstrolabeGeometry.lodFor(r).index,
        greaterThanOrEqualTo(AstrolabeLod.medium.index),
        reason: 'dial radius $r px shows the countdown and prayer names',
      );
      expect(r, greaterThan(_phone.width * 0.18));
      expect(core.offset.dy / _phone.height, lessThan(0.4));
      // Worlds render ~20–40 px: the dial is several times larger.
      final world = c.layout.bodyRadiusOf(PlanetArchetype.faith) * core.scale;
      expect(r / world, greaterThan(3));
    });

    test('a slight slant: the camera rolls a few degrees', () {
      final cam = c.overview(viewport: _phone, sceneRect: _band, lanes: _lanesOf(PlanetFixtures.system()));
      expect(cam.roll.abs(), inInclusiveRange(0.02, 0.2));
    });

    test('fits small phones, few worlds and many worlds', () {
      const small = Size(360, 740);
      final smallBand = Rect.fromLTRB(0, 68, 360, 740 * 0.575 - 8);
      final eight = PlanetFixtures.system();
      _expectFits(
        c,
        c.overview(viewport: small, sceneRect: smallBand, lanes: _lanesOf(eight)),
        small,
        smallBand,
        eight,
      );

      final three = eight.take(3).toList();
      final cam3 = c.overview(viewport: _phone, sceneRect: _band, lanes: _lanesOf(three));
      _expectFits(c, cam3, _phone, _band, three);
      expect(c.corePixels(cam3, _phone), lessThanOrEqualTo(_phone.width * c.maxCoreFraction + 0.5));

      final twelve = [
        ...eight,
        for (var i = 0; i < 4; i++) PlanetFixtures.custom('c$i', PlanetArchetype.values[i % 10], score: 0.7),
      ];
      _expectFits(c, c.overview(viewport: _phone, sceneRect: _band, lanes: _lanesOf(twelve)), _phone, _band, twelve);
    });

    test('an empty orbit keeps the dial at a sensible size', () {
      final cam = c.overview(viewport: _phone, sceneRect: _band, lanes: const []);
      expect(c.corePixels(cam, _phone), closeTo(_phone.width * c.maxCoreFraction, 1));
    });
  });

  group('CameraRig', () {
    test('dragging right turns the near side of the system to the right', () {
      final rig = CameraRig();
      const base = OrbitCamera(elevation: 0.6, distance: 8);
      // A point on the near side of the orbit plane (toward the camera).
      const near = V3(0, 0, 1);
      final before = rig.user(base, drift: false).project(near, _phone).offset.dx;
      rig
        ..begin()
        ..dragBy(const Offset(60, 0), _phone, baseElevation: base.elevation);
      final after = rig.user(base, drift: false).project(near, _phone).offset.dx;
      expect(after, greaterThan(before + 10));
    });

    test('vertical drag tilts within limits', () {
      final rig = CameraRig()..begin();
      for (var i = 0; i < 50; i++) {
        rig.dragBy(const Offset(0, 80), _phone, baseElevation: 0.6);
      }
      expect(rig.user(const OrbitCamera(elevation: 0.6), drift: false).elevation, closeTo(rig.maxElevation, 1e-9));
      for (var i = 0; i < 100; i++) {
        rig.dragBy(const Offset(0, -80), _phone, baseElevation: 0.6);
      }
      expect(rig.user(const OrbitCamera(elevation: 0.6), drift: false).elevation, closeTo(rig.minElevation, 1e-9));
    });

    test('a fling keeps spinning, then friction stops it', () {
      final rig = CameraRig()
        ..begin()
        ..dragBy(const Offset(20, 0), _phone, baseElevation: 0.6)
        ..end(velocity: const Offset(1500, 0), viewport: _phone);
      expect(rig.interacting, isTrue);
      final y0 = rig.yaw;
      rig.advance(0.1);
      expect(rig.yaw, lessThan(y0), reason: 'keeps turning the same way as the drag');
      for (var i = 0; i < 60 * 4; i++) {
        rig.advance(1 / 60);
      }
      expect(rig.interacting, isFalse);
      final settled = rig.yaw;
      rig.advance(1);
      expect(rig.yaw, closeTo(settled, 1e-9));
    });

    test('pinch zooms 0 → 1 and a tiny zoom springs back', () {
      final rig = CameraRig()..begin(pinch: true, zoomKey: 'faith');
      rig.pinchTo(1.5);
      expect(rig.zoom, closeTo(math.log(1.5) * CameraRig.zoomPerLogScale, 1e-9));
      rig.pinchTo(10);
      expect(rig.zoom, 1);
      expect(rig.zoomKey, 'faith');
      rig
        ..pinchTo(1.05)
        ..end();
      for (var i = 0; i < 120; i++) {
        rig.advance(1 / 60);
      }
      expect(rig.zoom, 0);
      expect(rig.zoomKey, isNull);
    });

    test('reset springs home the short way round', () {
      final rig = CameraRig()
        ..begin()
        ..dragBy(const Offset(-2000, 0), _phone, baseElevation: 0.6)
        ..end();
      expect(rig.isAway, isTrue);
      rig.reset();
      for (var i = 0; i < 60 * 3; i++) {
        rig.advance(1 / 60);
      }
      expect(rig.yaw.abs(), lessThan(0.01));
      expect(rig.isAway, isFalse);
      expect(rig.isMoving, isFalse);
    });

    test('drift is a gentle breath, off when asked', () {
      final rig = CameraRig();
      const base = OrbitCamera(elevation: 0.6);
      var maxDelta = 0.0;
      for (var i = 0; i < 60 * 60; i++) {
        rig.advance(1 / 60);
        maxDelta = math.max(maxDelta, (rig.user(base).azimuth - base.azimuth).abs());
      }
      expect(maxDelta, greaterThan(0.01));
      expect(maxDelta, lessThan(0.05));
      expect(rig.user(base, drift: false).azimuth, base.azimuth);
    });
  });

  group('fly-in / fly-out', () {
    test('the flight is under 800 ms and eases in and out', () {
      expect(FlightTiming.duration.inMilliseconds, lessThan(800));
      expect(FlightTiming.camera(0), 0);
      expect(FlightTiming.camera(1), 1);
      var last = 0.0;
      for (var i = 1; i <= 100; i++) {
        final v = FlightTiming.camera(i / 100);
        expect(v, greaterThanOrEqualTo(last));
        last = v;
      }
      expect(FlightTiming.camera(0.1), lessThan(0.1), reason: 'slow start');
      expect(1 - FlightTiming.camera(0.9), lessThan(0.1), reason: 'soft landing');
      expect(FlightTiming.motionBlur(0), 0);
      expect(FlightTiming.motionBlur(1), 0);
      expect(FlightTiming.motionBlur(0.5), greaterThan(0.5));
      expect(FlightTiming.astrolabe(1), 0);
      expect(FlightTiming.sheet(0.3), 0);
      expect(FlightTiming.sheet(1), 1);
    });

    test('CameraPath interpolates distance geometrically and azimuth the short way', () {
      const a = OrbitCamera(azimuth: 0.1, distance: 8);
      const b = OrbitCamera(azimuth: 2 * math.pi - 0.1, distance: 2);
      final mid = CameraPath.lerp(a, b, 0.5);
      expect(mid.distance, closeTo(4, 1e-9));
      expect(mid.azimuth, closeTo(0, 1e-9));
      expect(CameraPath.same(CameraPath.lerp(a, b, 0), a), isTrue);
      expect(CameraPath.same(CameraPath.lerp(a, b, 1), b), isTrue);
    });

    test('a fly-in lands the world big and high on the screen, the dial gone', () {
      final c = _scene();
      addTearDown(c.dispose);
      final route = _route();
      addTearDown(route.dispose);
      final start = c.planetDisc('faith')!;
      c.bindFlight('faith', route);
      // 760 ms of 60 Hz frames.
      final frames = (FlightTiming.duration.inMicroseconds / 16667).ceil();
      for (var i = 1; i <= frames; i++) {
        route.value = math.min(1, i * 16667 / FlightTiming.duration.inMicroseconds);
        c.tick(1 / 60);
      }
      expect(route.value, 1);
      final end = c.planetDisc('faith')!;
      final expected = c.composition.heroFill * _phone.shortestSide / 2;
      expect(end.$2, closeTo(expected, expected * 0.08));
      expect(end.$2, greaterThan(start.$2 * 4));
      expect(end.$1.dx, closeTo(_phone.width * c.composition.heroPrincipal.dx, 12));
      expect(end.$1.dy, closeTo(_phone.height * c.composition.heroPrincipal.dy, 12));
      expect(c.coreOpacity, 0);
      expect(c.backgroundBlur, greaterThan(SceneController.maxBlur * 0.9));
      expect(c.planets.focusKey, 'faith');
    });

    test('mid-flight the background blurs and streaks', () {
      final c = _scene();
      addTearDown(c.dispose);
      final route = _route();
      addTearDown(route.dispose);
      c.bindFlight('travel', route);
      route.value = 0.5;
      c.tick(1 / 60);
      expect(c.backgroundBlur, greaterThan(1));
      expect(c.motionBlur, greaterThan(0.3));
      expect(c.motionCenter, isNotNull);
      expect(c.coreOpacity, lessThan(0.5));
    });

    test('the fly-out is the exact reverse and lands on the overview', () {
      final c = _scene();
      addTearDown(c.dispose);
      final route = _route();
      addTearDown(route.dispose);
      final overview = c.camera;
      c.bindFlight('money', route);
      final path = <double>[];
      for (final t in [0.25, 0.5, 0.75, 1.0]) {
        route.value = t;
        c.refresh();
        path.add(c.camera.distance);
      }
      final back = <double>[];
      for (final t in [0.75, 0.5, 0.25]) {
        route.value = t;
        c.refresh();
        back.add(c.camera.distance);
      }
      expect(back, [path[2], path[1], path[0]]);
      route.value = 0;
      c.bindFlight(null, null);
      expect(CameraPath.same(c.camera, overview), isTrue);
      expect(c.coreOpacity, 1);
      expect(c.backgroundBlur, 0);
    });

    test('a deep link (route already complete) opens straight at the hero', () {
      final c = _scene();
      addTearDown(c.dispose);
      c.bindFlight('work', kAlwaysCompleteAnimation);
      final disc = c.planetDisc('work')!;
      expect(disc.$2, closeTo(c.composition.heroFill * _phone.shortestSide / 2, 20));
    });
  });

  group('hit testing', () {
    test('a tap on a world hits it; on empty sky nothing', () {
      final c = _scene();
      addTearDown(c.dispose);
      final f = c.planets.frameFor(_phone);
      for (final b in f.bodies.where((b) => b.visible)) {
        final hit = c.hitTest(b.center);
        // A world behind the dial is covered by the brass where they overlap.
        final covered = b.behindCore && (b.center - c.coreRect.center).distance < c.coreRadius;
        if (covered) continue;
        expect(hit?.kind, SceneHitKind.planet, reason: b.key);
        expect(hit?.planetKey, b.key);
      }
      expect(c.hitTest(const Offset(8, 80)), isNull);
    });

    test('moons map to their records', () {
      final c = _scene();
      addTearDown(c.dispose);
      // Zoom in on Family so its people are big enough to tap.
      c.rig
        ..begin(pinch: true, zoomKey: 'family')
        ..pinchTo(20)
        ..end();
      c.refresh();
      final f = c.planets.frameFor(_phone);
      final moons = f.body('family')!.moons.where((m) => m.visible && m.radius > 3 && m.front).toList();
      expect(moons, isNotEmpty);
      for (final m in moons) {
        final hit = c.hitTest(m.center);
        expect(hit?.kind, SceneHitKind.moon);
        expect(hit?.moon?.refTable, 'people');
        expect(hit?.moon?.refId, m.moon.refId);
      }
    });

    test('prayer pointers are tappable; the dial centre is the core', () {
      final c = _scene();
      addTearDown(c.dispose);
      var hits = 0;
      for (final p in AstrolabeGeometry.prayers) {
        final rect = c.prayerRect(p)!;
        final hit = c.hitTest(rect.center);
        // A world in front of the dial can cover a pointer.
        if (hit?.kind == SceneHitKind.planet || hit?.kind == SceneHitKind.moon) continue;
        expect(hit?.kind, SceneHitKind.prayer, reason: p.name);
        expect(hit?.prayer, p);
        hits++;
      }
      expect(hits, greaterThanOrEqualTo(3));
      expect(c.hitTest(c.coreRect.center)?.kind, SceneHitKind.core);
    });

    test('a world off screen or behind the camera is never hit', () {
      final c = _scene();
      addTearDown(c.dispose);
      // Zoom into Family: the far side of the system leaves the screen.
      c.rig
        ..begin(pinch: true, zoomKey: 'family')
        ..pinchTo(20)
        ..end();
      c.refresh();
      final f = c.planets.frameFor(_phone);
      expect(f.bodies.where((b) => !b.visible), isNotEmpty, reason: 'the fixture must hide some world');
      for (final b in f.bodies.where((b) => !b.visible)) {
        final hit = c.hitTest(b.center);
        expect(hit?.planetKey == b.key && hit?.moon == null, isFalse, reason: '${b.key} is not drawn');
      }
    });

    test('a world behind the dial is ghosted over the brass and takes the touch there', () {
      final c = _scene();
      addTearDown(c.dispose);
      // At rest no world is ever mostly hidden: tilt the camera down to
      // the orbital plane, then turn the system until one sits behind the
      // dial.
      c.rig
        ..begin()
        ..dragBy(Offset(0, -_phone.height * 0.3), _phone, baseElevation: c.baseCamera.elevation);
      c.refresh();
      for (var step = 0; step < 600; step++) {
        final f = c.planets.frameFor(_phone);
        final hidden = f.bodies.where(
          (b) => b.visible && b.behindCore && (b.center - c.coreRect.center).distance < c.coreRadius * 0.95,
        );
        if (hidden.isNotEmpty) {
          // Mostly covered by the dial: drawn over it as a ghost, so what
          // is seen there is what a tap opens.
          final b = hidden.first;
          expect(b.ghosted, isTrue);
          final hit = c.hitTest(b.center);
          expect(hit?.kind, SceneHitKind.planet);
          expect(hit?.planetKey, b.key);
          return;
        }
        c.planets.advanceSeconds(0.5);
        c.refresh();
      }
      fail('no world passed behind the dial');
    });
  });

  test('reduced motion freezes the orbits and the drift but keeps gestures', () {
    final c = _scene()..reducedMotion = true;
    addTearDown(c.dispose);
    final before = c.planetDisc('faith')!.$1;
    final cam = c.camera;
    c.tick(5);
    expect(c.planetDisc('faith')!.$1, before);
    expect(CameraPath.same(c.camera, cam), isTrue);
    c.rig
      ..begin()
      ..dragBy(const Offset(80, 0), _phone, baseElevation: c.baseCamera.elevation);
    c.tick(1 / 60);
    expect(c.camera.azimuth, isNot(cam.azimuth));
  });

  test('reduced motion: the fly-in keeps the camera on the overview (the page cross-fades)', () {
    final c = _scene()..reducedMotion = true;
    addTearDown(c.dispose);
    final route = _route();
    addTearDown(route.dispose);
    final overview = c.camera;
    final disc = c.planetDisc('faith')!;
    c.bindFlight('faith', route);
    for (final t in [0.25, 0.5, 1.0]) {
      route.value = t;
      c.tick(1 / 60);
      expect(CameraPath.same(c.camera, overview), isTrue, reason: 'no camera flight at $t');
      expect(c.planetDisc('faith')!.$1, disc.$1);
    }
    route.value = 0;
    c.bindFlight(null, null);
    expect(CameraPath.same(c.camera, overview), isTrue);
  });

  test('every world is lit from the star: its light points at the dial on screen', () {
    final c = _scene();
    addTearDown(c.dispose);
    final f = c.planets.frameFor(_phone);
    final star = c.coreRect.center;
    var checked = 0;
    for (final b in f.bodies.where((b) => b.visible)) {
      final toStar = star - b.center;
      if (toStar.distance < 40) continue;
      // View space is y-up; the screen is y-down.
      final light = Offset(b.lightX, -b.lightY);
      if (light.distance < 1e-3) continue;
      final cos = (light.dx * toStar.dx + light.dy * toStar.dy) / (light.distance * toStar.distance);
      expect(
        cos,
        greaterThan(math.cos(12 * math.pi / 180)),
        reason: '${b.key}: light ${light.direction} vs star ${toStar.direction}',
      );
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(5));
  });

  test('pulses flare the world and the core', () {
    final c = _scene();
    addTearDown(c.dispose);
    expect(c.isAnimating, isFalse);
    c.pulse(PlanetPulse(planetKey: 'family', kind: 'contact.logged', at: DateTime(2026, 9, 27, 12, 30)));
    expect(c.isAnimating, isTrue);
    c.tick(0.2);
    expect(c.planets.living.pulseOf('family'), greaterThan(0));
    expect(c.astrolabe.pulse, greaterThan(0));
  });

  test('changing the worlds reframes smoothly', () {
    final c = _scene();
    addTearDown(c.dispose);
    final before = c.camera;
    c.setBodies(PlanetFixtures.system().take(5).toList());
    expect(c.isAnimating, isTrue);
    c.refresh();
    expect(CameraPath.same(c.camera, before, eps: 1e-6), isTrue, reason: 'no jump');
    for (var i = 0; i < 60; i++) {
      c.tick(1 / 60);
    }
    expect(c.camera.distance, isNot(closeTo(before.distance, 1e-3)));
    final target = c.composition.overview(
      viewport: _phone,
      sceneRect: _band,
      lanes: _lanesOf(PlanetFixtures.system().take(5).toList()),
    );
    expect(c.camera.distance, closeTo(target.distance, 0.05));
  });

  test('a score change morphs the world between thriving and neglected', () {
    final c = _scene(bodies: PlanetFixtures.system(scores: const {'growth': 0.95}));
    addTearDown(c.dispose);
    final f = c.planets.frameFor(_phone);
    expect(f.body('growth')!.score, closeTo(0.95, 1e-6));
    c.setBodies(PlanetFixtures.system(scores: const {'growth': 0.12}));
    c.tick(1 / 60);
    final mid = c.planets.frameFor(_phone).body('growth')!.score;
    expect(mid, lessThan(0.95));
    expect(mid, greaterThan(0.12));
    for (var i = 0; i < 180; i++) {
      c.tick(1 / 60);
    }
    expect(c.planets.frameFor(_phone).body('growth')!.score, closeTo(0.12, 0.01));
  });
}
