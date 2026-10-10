// "Reset view": the camera rig back to the exact pose of a fresh start, the
// worlds back to their even starting layout, the control's visibility, and
// the pinch-opened page that used to leave its world filling the scene.
import 'dart:math' as math;
import 'dart:ui' as ui show PictureRecorder;
import 'dart:ui' show Canvas, Locale, Offset, Rect, Size, TextDirection;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/presentation/scene/camera_rig.dart';
import 'package:madar/features/orbit/presentation/scene/flight.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import '../render/planets/planet_fixtures.dart';

const _phone = Size(412, 915);
final _band = Rect.fromLTRB(0, 68, 412, 915 * 0.575 - 8);
const _base = OrbitCamera(elevation: 0.78, distance: 7.8, roll: -0.05);

SceneController _scene({List<PlanetBody>? bodies}) {
  final c = SceneController(initialTime: 12, now: DateTime(2026, 9, 27, 12, 30));
  c.setBodies(bodies ?? PlanetFixtures.system(), animate: false);
  c.layout(_phone, _band);
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

/// Ticks [c] at 60 Hz for [seconds].
void _run(SceneController c, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    c.tick(1 / 60);
  }
}

/// A rig pushed far from home in every way it can be.
CameraRig _messyRig() {
  final rig = CameraRig();
  for (var i = 0; i < 90; i++) {
    rig.advance(1 / 60); // some drift
  }
  rig
    ..begin(pinch: true, zoomKey: 'faith')
    ..pinchTo(1.6)
    ..dragBy(const Offset(-900, 260), _phone, baseElevation: 0.78)
    ..end(velocity: const Offset(-2400, 0), viewport: _phone);
  // Several turns of accumulated spin as well.
  for (var i = 0; i < 20; i++) {
    rig
      ..begin()
      ..dragBy(const Offset(-400, 0), _phone, baseElevation: 0.78)
      ..end(velocity: const Offset(-1800, 0), viewport: _phone);
    rig.advance(1 / 60);
  }
  rig.advance(0.2);
  return rig;
}

void main() {
  group('CameraRig.reset', () {
    test('from any state it lands on the exact default pose of a fresh start', () {
      final rig = _messyRig();
      expect(rig.isAway, isTrue);
      expect(rig.interacting, isTrue, reason: 'still spinning');
      expect(rig.zoom, greaterThan(0.3));
      rig.reset(gyroYaw: 0.05, gyroPitch: -0.04);
      expect(rig.isHoming, isTrue);
      expect(rig.interacting, isFalse, reason: 'the spin carries into the spring, it does not keep going');
      var t = 0.0;
      while (rig.isMoving && t < 5) {
        rig.advance(1 / 60);
        t += 1 / 60;
      }
      expect(t, lessThan(3), reason: 'settles in a moment');
      expect(rig.yaw, 0);
      expect(rig.tilt, 0);
      expect(rig.zoom, 0);
      expect(rig.zoomKey, isNull);
      expect(rig.isAway, isFalse);
      expect(rig.isHoming, isFalse);
      // Identical to a rig that started fresh the same time ago (drift too).
      final fresh = CameraRig();
      for (var i = 0; i < (t * 60).round(); i++) {
        fresh.advance(1 / 60);
      }
      final a = rig.user(_base), b = fresh.user(_base);
      expect(a.azimuth, closeTo(b.azimuth, 1e-9));
      expect(a.elevation, closeTo(b.elevation, 1e-9));
      expect(a.roll, closeTo(b.roll, 1e-9));
      expect(rig.driftTime, closeTo(fresh.driftTime, 1e-9));
    });

    test('glides from exactly where the view is (drift and gyro folded in, no jump)', () {
      final rig = CameraRig();
      for (var i = 0; i < 60 * 40; i++) {
        rig.advance(1 / 60); // the drift is well away from its start
      }
      rig
        ..begin()
        ..dragBy(const Offset(120, -60), _phone, baseElevation: 0.78)
        ..end();
      const gy = 0.06, gp = -0.05;
      final before = rig.user(_base, gyroYaw: gy, gyroPitch: gp);
      rig.reset(gyroYaw: gy, gyroPitch: gp);
      final after = rig.user(_base);
      expect(after.azimuth, closeTo(before.azimuth, 1e-9));
      expect(after.elevation, closeTo(before.elevation, 1e-9));
      expect(after.roll, closeTo(before.roll, 1e-9));
    });

    test('the short way round after many turns', () {
      final rig = CameraRig()
        ..begin()
        ..dragBy(const Offset(-2000 * 7.3, 0), _phone, baseElevation: 0.78)
        ..end();
      expect(rig.yaw.abs(), greaterThan(10));
      rig.reset();
      var maxDeviation = 0.0;
      for (var i = 0; i < 60 * 3; i++) {
        rig.advance(1 / 60);
        maxDeviation = math.max(maxDeviation, rig.yaw.abs());
      }
      expect(maxDeviation, lessThanOrEqualTo(math.pi + 0.2));
      expect(rig.yaw, 0);
    });

    test('a touch takes over a reset in progress', () {
      final rig = CameraRig()
        ..begin()
        ..dragBy(const Offset(-300, 0), _phone, baseElevation: 0.78)
        ..end();
      rig.reset();
      rig.advance(0.1);
      expect(rig.isHoming, isTrue);
      rig.begin();
      expect(rig.isHoming, isFalse);
      final y = rig.yaw;
      rig.advance(0.5);
      expect(rig.yaw, y, reason: 'the camera stays under the finger');
    });

    test('a gesture cut off without its end lets go: no fling, an unreleased pinch springs out', () {
      final rig = CameraRig()
        ..begin(pinch: true, zoomKey: 'faith')
        ..pinchTo(1.8)
        ..dragBy(const Offset(-120, 40), _phone, baseElevation: 0.78);
      final yaw = rig.yaw, tilt = rig.tilt;
      expect(rig.zoom, greaterThan(0.5));
      rig.cancelGesture();
      expect(rig.interacting, isFalse);
      for (var i = 0; i < 60 * 3; i++) {
        rig.advance(1 / 60);
      }
      expect(rig.zoom, 0);
      expect(rig.zoomKey, isNull);
      expect((rig.yaw, rig.tilt), (yaw, tilt), reason: 'the turn stays where the finger left it');
      expect(rig.isMoving, isFalse);
      // Nothing in progress: a no-op.
      rig.cancelGesture();
      expect(rig.isMoving, isFalse);
    });

    test('snapHome is the same pose at once', () {
      final rig = _messyRig()..snapHome();
      expect(rig.isMoving, isFalse);
      expect((rig.yaw, rig.tilt, rig.zoom, rig.zoomKey, rig.driftTime), (0, 0, 0, null, 0));
    });
  });

  group('PlanetSceneController.respread', () {
    test('the fresh layout has no overlapping worlds; minutes of orbiting do', () {
      final c = _scene();
      addTearDown(c.dispose);
      expect(c.planets.crowded(_phone), isFalse);
      var crowdedAt = -1;
      for (var s = 1; s <= 600 && crowdedAt < 0; s++) {
        c.planets.advanceSeconds(1);
        c.refresh();
        if (c.planets.crowded(_phone)) crowdedAt = s;
      }
      expect(crowdedAt, greaterThan(0), reason: 'the worlds orbit at different speeds and drift into each other');
    });

    test('glides every world and moon back: exactly a fresh start, non-overlapping', () {
      final bodies = [...PlanetFixtures.system()];
      final a = _scene(bodies: bodies);
      addTearDown(a.dispose);
      a.planets.advanceSeconds(300);
      a.refresh();
      expect(a.planets.crowded(_phone), isTrue);
      a.planets.respread();
      expect(a.planets.respreading, isTrue);
      expect(a.planets.isAnimating, isTrue);
      const dt = 1 / 60;
      final frames = (PlanetSceneController.respreadSeconds / dt).ceil() + 30;
      for (var i = 0; i < frames; i++) {
        a.planets.advanceSeconds(dt);
      }
      a.refresh();
      expect(a.planets.respreading, isFalse);

      final b = _scene(bodies: bodies);
      addTearDown(b.dispose);
      for (var i = 0; i < frames; i++) {
        b.planets.advanceSeconds(dt);
      }
      b.refresh();
      final fa = a.planets.frameFor(_phone), fb = b.planets.frameFor(_phone);
      for (final body in fb.bodies) {
        final other = fa.body(body.key)!;
        expect(other.center.dx, closeTo(body.center.dx, 1e-6), reason: body.key);
        expect(other.center.dy, closeTo(body.center.dy, 1e-6), reason: body.key);
        for (final m in body.moons) {
          final om = fa.moon(m.moon.id)!;
          expect((om.center - m.center).distance, lessThan(1e-6), reason: m.moon.id);
        }
      }
      expect(a.planets.crowded(_phone), isFalse);
    });

    test('the glide is smooth: no world jumps more than a few px a frame', () {
      final c = _scene();
      addTearDown(c.dispose);
      c.planets.advanceSeconds(300);
      c.refresh();
      c.planets.respread();
      var last = {for (final b in c.planets.frameFor(_phone).bodies) b.key: b.center};
      var maxStep = 0.0;
      for (var i = 0; i < 80; i++) {
        c.planets.advanceSeconds(1 / 60);
        c.refresh();
        final now = {for (final b in c.planets.frameFor(_phone).bodies) b.key: b.center};
        for (final e in now.entries) {
          maxStep = math.max(maxStep, (e.value - last[e.key]!).distance);
        }
        last = now;
      }
      expect(maxStep, lessThan(24));
    });

    test('without animation (reduced motion) it is a cut', () {
      final c = _scene();
      addTearDown(c.dispose);
      c.planets.advanceSeconds(300);
      c.refresh();
      c.planets.respread(animate: false);
      expect(c.planets.respreading, isFalse);
      c.refresh();
      expect(c.planets.crowded(_phone), isFalse);
    });
  });

  group('SceneController.resetView', () {
    test('drag + pinch + fling + gyro + drifted worlds → the composed overview of a fresh start', () {
      final c = _scene();
      addTearDown(c.dispose);
      c.planets.advanceSeconds(300);
      _run(c, 1);
      c.rig
        ..begin(pinch: true, zoomKey: 'family')
        ..pinchTo(1.7)
        ..dragBy(const Offset(-500, 180), _phone, baseElevation: c.baseCamera.elevation)
        ..end(velocity: const Offset(-2000, 0), viewport: _phone);
      c.gyro.addRates(0.6, -0.8, 0.1);
      _run(c, 0.3);
      expect(c.resetCue, isTrue);
      final epoch = c.planets.labelLayoutEpoch;
      c.resetView();
      expect(c.resetCue, isFalse, reason: 'the control steps aside while everything springs home');
      expect(c.planets.labelLayoutEpoch, epoch + 1, reason: 'labels choose their spots afresh');
      var t = 0.0;
      while ((c.isAnimating || c.rig.isMoving) && t < 6) {
        c.tick(1 / 60);
        t += 1 / 60;
      }
      expect(t, lessThan(4));
      expect(c.planets.labelLayoutEpoch, epoch + 2, reason: '… and once more when everything has landed');
      expect(c.rig.yaw, 0);
      expect(c.rig.tilt, 0);
      expect(c.rig.zoom, 0);
      expect(c.rig.zoomKey, isNull);
      expect(c.planets.selectedKey, isNull);
      expect(c.planets.labelCluster, isNull);
      expect(c.resetCue, isFalse);

      // A fresh scene that ran the same time since the reset.
      final fresh = _scene();
      addTearDown(fresh.dispose);
      for (var i = 0; i < (t * 60).round(); i++) {
        fresh.tick(1 / 60);
      }
      expect(CameraPath.same(c.camera, fresh.camera, eps: 1e-6), isTrue, reason: '${c.camera} vs ${fresh.camera}');
      for (final b in fresh.planets.frameFor(_phone).bodies) {
        final mine = c.planetDisc(b.key)!;
        expect((mine.$1 - b.center).distance, lessThan(1e-3), reason: b.key);
      }
      expect(c.planets.crowded(_phone), isFalse);
    });

    test('reduced motion: a cut to the same pose', () {
      final c = _scene()..reducedMotion = true;
      addTearDown(c.dispose);
      final overview = c.camera;
      c.rig
        ..begin()
        ..dragBy(const Offset(200, 100), _phone, baseElevation: c.baseCamera.elevation)
        ..end();
      c.tick(1 / 60);
      expect(c.resetCue, isTrue);
      c.resetView(animate: false);
      expect(c.rig.isMoving, isFalse);
      expect(c.resetCue, isFalse);
      expect(CameraPath.same(c.camera, overview), isTrue);
    });
  });

  group('the reset control', () {
    test('hidden at the default overview; shown once the view is turned, tilted or zoomed', () {
      final c = _scene();
      addTearDown(c.dispose);
      _run(c, 2);
      expect(c.resetCue, isFalse);
      c.rig
        ..begin()
        ..dragBy(const Offset(30, 0), _phone, baseElevation: c.baseCamera.elevation);
      c.tick(1 / 60);
      expect(c.resetCue, isTrue, reason: 'a few degrees of turn already differ');
      c.rig.end();
      c.resetView();
      _run(c, 3);
      expect(c.resetCue, isFalse);
      c.rig
        ..begin(pinch: true)
        ..pinchTo(1.2)
        ..end();
      c.tick(1 / 60);
      expect(c.resetCue, isTrue);
    });

    test('also when the worlds drift into each other – after a moment, and it leaves again', () {
      final c = _scene();
      addTearDown(c.dispose);
      // Orbit on until two worlds overlap (the worlds drift slowly now –
      // minutes, not seconds – so this watches for the best part of an hour
      // of scene time; it stops the moment they touch).
      for (var s = 0; s < 3600 && !c.planets.crowded(_phone); s++) {
        c.planets.advanceSeconds(1);
        c.refresh();
      }
      expect(c.planets.crowded(_phone), isTrue);
      c.tick(1 / 60);
      expect(c.resetCue, isFalse, reason: 'not for a passing brush');
      _run(c, SceneController.crowdShowAfter + 0.1);
      if (c.planets.crowded(_phone)) expect(c.resetCue, isTrue);
      c.resetView();
      expect(c.resetCue, isFalse);
      _run(c, 3);
      expect(c.resetCue, isFalse, reason: 'the worlds are back apart');
      expect(c.planets.crowded(_phone), isFalse);
    });

    test('never while a planet page is open', () {
      final c = _scene();
      addTearDown(c.dispose);
      c.rig
        ..begin()
        ..dragBy(const Offset(200, 0), _phone, baseElevation: c.baseCamera.elevation)
        ..end();
      c.tick(1 / 60);
      expect(c.resetCue, isTrue);
      c.bindFlight('faith', kAlwaysCompleteAnimation);
      expect(c.resetCue, isFalse);
      c.bindFlight(null, null);
      expect(c.resetCue, isTrue);
    });
  });

  group('labels after a reset', () {
    /// Paints the scene's name labels (the painter keeps its spots in
    /// [cache], as the labels view does between frames).
    void paintLabels(SceneController c, PlanetLabelCache cache) {
      final recorder = ui.PictureRecorder();
      PlanetLabelsPainter(
        controller: c.planets,
        style: PlanetLayerStyle.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis)),
        cache: cache,
        textDirection: TextDirection.ltr,
      ).paint(Canvas(recorder), _phone);
      recorder.endRecording().dispose();
    }

    /// Ticks [c] for [seconds], painting its labels every frame.
    void runPainting(SceneController c, PlanetLabelCache cache, double seconds) {
      for (var i = 0; i < (seconds * 60).round(); i++) {
        c.tick(1 / 60);
        paintLabels(c, cache);
      }
    }

    testWidgets('the names sit exactly where a fresh start puts them, whatever the first frames did', (tester) async {
      // A fresh start whose first frames saw something else (here: a
      // keep-out over the middle of the band, as data still arriving or
      // moons appearing would): the spots those frames chose are dropped
      // once the opening has settled.
      final fresh = _scene();
      addTearDown(fresh.dispose);
      final freshCache = PlanetLabelCache();
      addTearDown(freshCache.clear);
      fresh.planets.labelKeepOut = [Rect.fromLTRB(0, 300, 412, 520)];
      runPainting(fresh, freshCache, 0.4);
      final early = Map.of(freshCache.slots);
      fresh.planets.labelKeepOut = const [];
      runPainting(fresh, freshCache, 2.6);

      // The same system, turned, zoomed and drifted – then reset.
      final c = _scene();
      addTearDown(c.dispose);
      final cache = PlanetLabelCache();
      addTearDown(cache.clear);
      runPainting(c, cache, 1.5);
      c.planets.advanceSeconds(200);
      c.rig
        ..begin()
        ..dragBy(const Offset(-160, 70), _phone, baseElevation: c.baseCamera.elevation)
        ..end();
      c.rig
        ..begin(pinch: true, zoomKey: 'family')
        ..pinchTo(1.5)
        ..end();
      runPainting(c, cache, 1);
      c.resetView();
      runPainting(c, cache, 3);

      expect(freshCache.slots, isNotEmpty);
      expect(early, isNot(equals(freshCache.slots)), reason: 'the first frames did choose other spots');
      expect(cache.slots, freshCache.slots);
      for (final e in freshCache.lastRect.entries) {
        final mine = cache.lastRect[e.key];
        expect(mine, isNotNull, reason: e.key);
        expect((mine!.center - e.value.center).distance, lessThan(2), reason: e.key);
      }
    });
  });

  test('a page opened by pinching deep into a world never leaves that world filling the scene', () {
    final c = _scene();
    addTearDown(c.dispose);
    final overview = c.camera;
    // Pinch into Faith past the opening threshold and let go (the scene
    // widget then opens its page).
    c.rig
      ..begin(pinch: true, zoomKey: 'faith')
      ..pinchTo(20)
      ..end();
    _run(c, 0.1);
    expect(c.rig.zoom, greaterThan(SceneController.pinchOpenZoom));
    final route = AnimationController(
      vsync: const TestVSync(),
      duration: FlightTiming.duration,
      reverseDuration: FlightTiming.duration,
    );
    addTearDown(route.dispose);
    c.bindFlight('faith', route);
    for (var i = 1; i <= 50; i++) {
      route.value = math.min(1, i / 45);
      c.tick(1 / 60);
    }
    expect(c.rig.zoom, 0, reason: 'let go once the page has landed');
    // Back: the fly-out lands on the overview, not on a giant Faith.
    for (var i = 1; i <= 50; i++) {
      route.value = math.max(0, 1 - i / 45);
      c.tick(1 / 60);
    }
    c.bindFlight(null, null);
    _run(c, 0.1);
    expect(c.camera.distance, closeTo(overview.distance, 1e-6));
    expect(c.planetDisc('faith')!.$2, lessThan(40));
  });

  test('a pinch-opened page closed before it landed (cancelled fly-in): the world springs back to its size', () {
    final c = _scene();
    addTearDown(c.dispose);
    _run(c, 0.1);
    final small = c.planetDisc('faith')!.$2;
    c.rig
      ..begin(pinch: true, zoomKey: 'faith')
      ..pinchTo(20)
      ..end();
    _run(c, 0.1);
    final route = AnimationController(
      vsync: const TestVSync(),
      duration: FlightTiming.duration,
      reverseDuration: FlightTiming.duration,
    );
    addTearDown(route.dispose);
    c.bindFlight('faith', route);
    // Back pressed half way through the fly-in.
    for (var i = 1; i <= 20; i++) {
      route.value = i / 45;
      c.tick(1 / 60);
    }
    for (var i = 19; i >= 0; i--) {
      route.value = i / 45;
      c.tick(1 / 60);
    }
    c.bindFlight(null, null);
    c.tick(1 / 60);
    expect(c.rig.isMoving, isTrue, reason: 'springs out from the zoomed view – no jump');
    expect(c.resetCue, isTrue);
    _run(c, 3);
    expect(c.rig.zoom, 0);
    expect(c.rig.zoomKey, isNull);
    expect(c.planets.selectedKey, isNull);
    expect(c.planetDisc('faith')!.$2, closeTo(small, small * 0.25), reason: 'not left enlarged');
  });

  test('reduced motion: the same cancelled pinch-open is a cut back to the overview', () {
    final c = _scene()..reducedMotion = true;
    addTearDown(c.dispose);
    c.rig
      ..begin(pinch: true, zoomKey: 'faith')
      ..pinchTo(20)
      ..end();
    c.tick(1 / 60);
    c.bindFlight('faith', kAlwaysDismissedAnimation);
    c.bindFlight(null, null);
    expect(c.rig.zoom, 0);
    expect(c.rig.isMoving, isFalse);
  });
}
