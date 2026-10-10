import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import 'planet_fixtures.dart';

const _phone = Size(412, 915);

void _advance(PlanetSceneController c, double seconds, {double dt = 1 / 60}) {
  for (var t = 0.0; t < seconds - 1e-9; t += dt) {
    c.advanceSeconds(dt);
  }
}

PlanetSceneController _system({String lang = 'ar', double time = 12}) =>
    PlanetSceneController(initialTime: time)..setBodies(PlanetFixtures.system(lang: lang), animate: false);

/// The end of a fly-in to [key]: framed at [fill], focus complete.
PlanetSceneController _zoomedOn(String key, {double fill = 0.36}) {
  final c = _system();
  c
    ..camera = c.framingCamera(key, from: c.camera, viewport: _phone, fill: fill)!
    ..setFocus(key, 1);
  return c;
}

void main() {
  group('frame', () {
    test('every world is projected; far worlds are drawn first', () {
      final c = _system();
      final f = c.frameFor(_phone);
      expect(f.bodies.map((b) => b.key), PlanetFixtures.keys);
      expect(f.drawOrder, isNotEmpty);
      for (var i = 1; i < f.drawOrder.length; i++) {
        expect(f.drawOrder[i].depth, lessThanOrEqualTo(f.drawOrder[i - 1].depth));
      }
      for (final b in f.bodies) {
        expect(b.behindCore, b.depth > f.coreDepth);
        expect(b.world.length, closeTo(b.lane, 0.02), reason: 'on its lane');
      }
      expect(identical(c.frameFor(_phone), f), isTrue, reason: 'cached until something changes');
    });

    test('the worlds start spread around the astrolabe (no clusters)', () {
      final f = _system(time: 0).frameFor(_phone);
      final longitudes = [for (final b in f.bodies) math.atan2(b.world.z, b.world.x)]..sort();
      for (var i = 0; i < longitudes.length; i++) {
        final next = i + 1 < longitudes.length ? longitudes[i + 1] : longitudes.first + 2 * math.pi;
        expect(next - longitudes[i], greaterThan(0.4), reason: 'gap $i');
      }
    });

    test('overview: the worlds are ~18–30 px discs around the astrolabe', () {
      final f = _system().frameFor(_phone);
      for (final b in f.bodies.where((b) => b.visible)) {
        expect(b.radius, inInclusiveRange(14, 34), reason: b.key);
        expect(b.drawRect.width, closeTo(b.radius * 2 * b.body.haloFactor, 1e-6));
      }
      // The inner orbit clears the astrolabe.
      expect(f.coreRadius, greaterThan(40));
      final inner = f.bodies.first;
      expect((inner.center - f.coreCenter).distance, greaterThan(f.coreRadius * 0.3));
    });

    test('bodies behind the camera or off screen are culled', () {
      final c = _system();
      c.camera = const OrbitCamera(distance: 0.9, elevation: 0.1);
      final f = c.frameFor(_phone);
      expect(f.bodies.where((b) => b.visible).length, lessThan(8));
      for (final b in f.bodies.where((b) => b.visible)) {
        expect(b.depth, greaterThan(0));
        expect(b.drawRect.overlaps((Offset.zero & _phone).inflate(2)), isTrue);
      }
      c.camera = const OrbitCamera(target: V3(40, 0, 0));
      expect(c.frameFor(_phone).drawOrder, isEmpty, reason: 'looking away');
    });

    test('level of detail rises as the camera flies in', () {
      final far = _system().frameFor(_phone).body('family')!;
      final near = _zoomedOn('family', fill: 0.9).frameFor(_phone).body('family')!;
      expect(far.detail, lessThan(0.2));
      expect(near.detail, greaterThan(0.75));
      expect(near.radius, closeTo(0.9 * _phone.width / 2, 2));
    });

    test('light comes from the core star (on screen too)', () {
      final f = _system().frameFor(_phone);
      for (final b in f.bodies.where((b) => b.visible)) {
        expect(math.sqrt(b.lightX * b.lightX + b.lightY * b.lightY + b.lightZ * b.lightZ), closeTo(1, 1e-9));
        final toCore = f.coreCenter - b.center;
        // View y is up, screen y is down.
        final dot = b.lightX * toCore.dx - b.lightY * toCore.dy;
        expect(dot, greaterThan(0), reason: b.key);
      }
    });

    test('worlds orbit, spin and keep their tilt as time passes', () {
      final c = _system();
      final before = c.frameFor(_phone).body('work')!;
      final pos = before.world, spin = before.spin, tilt = before.tilt;
      _advance(c, 2);
      final after = c.frameFor(_phone).body('work')!;
      expect((after.world - pos).length, greaterThan(0.01));
      expect(after.world.length, closeTo(pos.length, 1e-6));
      expect(after.spin, isNot(spin));
      expect(after.spin, inInclusiveRange(0, 2 * math.pi));
      expect(after.tilt, tilt);
      expect(c.time, closeTo(14, 1e-6));
    });

    test('the same time gives the same sky (deterministic)', () {
      final a = _system(time: 40).frameFor(_phone);
      final b = _system(time: 40).frameFor(_phone);
      for (var i = 0; i < 8; i++) {
        expect(a.bodies[i].center, b.bodies[i].center);
      }
      // A controller that ticked from 12 to 40 agrees with one born at 40.
      final ticked = _system();
      _advance(ticked, 28, dt: 0.5);
      final t = ticked.frameFor(_phone);
      for (var i = 0; i < 8; i++) {
        expect((t.bodies[i].center - a.bodies[i].center).distance, lessThan(0.5));
      }
    });
  });

  group('living state', () {
    test('a changed score morphs visibly; the frame follows the spring', () {
      final c = _system();
      expect(c.frameFor(_phone).body('body')!.score, closeTo(0.18, 1e-9));
      c.setBodies(PlanetFixtures.system(scores: const {'body': 0.95}));
      expect(c.isAnimating, isTrue);
      _advance(c, 0.3);
      final mid = c.frameFor(_phone).body('body')!.score;
      expect(mid, inInclusiveRange(0.3, 0.9));
      _advance(c, 2);
      expect(c.frameFor(_phone).body('body')!.score, closeTo(0.95, 1e-9));
      expect(c.isAnimating, isFalse);
    });

    test('a completion pulses the world; the named moon flares, siblings glow softly', () {
      final c = _system();
      final heard = <PlanetPulse>[];
      c.addPulseListener(heard.add);
      final p = PlanetPulse(
        planetKey: 'family',
        kind: 'contact.logged',
        at: DateTime(2026),
        refTable: 'people',
        refId: 'p2',
      );
      expect(c.pulse(p), isTrue);
      expect(heard, [p]);
      _advance(c, 0.22);
      final f = c.frameFor(_phone);
      final family = f.body('family')!;
      expect(family.pulse, greaterThan(0.8));
      final named = family.moons.firstWhere((m) => m.moon.refId == 'p2');
      final other = family.moons.firstWhere((m) => m.moon.refId == 'p3');
      expect(named.pulse, greaterThan(0.9));
      expect(other.pulse, inInclusiveRange(0.2, 0.4));
      expect(f.body('money')!.pulse, 0, reason: 'only that world');
      _advance(c, 1.4);
      expect(c.frameFor(_phone).body('family')!.pulse, 0);
      expect(c.pulse(PlanetPulse(planetKey: 'hidden', kind: 'x', at: DateTime(2026))), isFalse);
    });

    test('reordering moves worlds to their new lanes on a spring', () {
      final c = _system();
      var guidePings = 0;
      c.guides.addListener(() => guidePings++);
      final keys = [...PlanetFixtures.keys.reversed];
      final bodies = {for (final b in PlanetFixtures.system()) b.key: b};
      c.setBodies([for (final k in keys) bodies[k]!]);
      expect(guidePings, greaterThan(0));
      final faithLane = c.frameFor(_phone).body('faith')!.lane;
      expect(faithLane, closeTo(c.layout.innerRadius, 1e-9), reason: 'still where it was');
      _advance(c, 0.4);
      final moving = c.frameFor(_phone).body('faith')!.lane;
      expect(moving, inExclusiveRange(c.layout.innerRadius, c.layout.outerRadius));
      _advance(c, 3);
      expect(c.frameFor(_phone).body('faith')!.lane, closeTo(c.layout.outerRadius, 1e-6));
      expect(c.bodies.first.key, 'travel');
    });

    test('equal content is not a change; new content bumps the version', () {
      final c = _system();
      final v = c.bodiesVersion;
      var notified = 0;
      c.addListener(() => notified++);
      c.setBodies(PlanetFixtures.system());
      expect(c.bodiesVersion, v);
      expect(notified, 0);
      c.setBodies(PlanetFixtures.system().take(7).toList());
      expect(c.bodiesVersion, v + 1);
      expect(c.liveIds.planets, isNot(contains('travel')));
      expect(c.liveIds.moons, isNot(contains('trips:t0')));
    });

    test('reduced motion: a static scene', () {
      final c = _system()..reducedMotion = true;
      final t = c.time;
      final pos = c.frameFor(_phone).body('faith')!.center;
      _advance(c, 1);
      expect(c.time, t);
      expect(c.frameFor(_phone).body('faith')!.center, pos);
      c.setBodies(PlanetFixtures.system(scores: const {'faith': 0.1}));
      expect(c.frameFor(_phone).body('faith')!.score, 0.1, reason: 'jumps');
      c.pulse(PlanetPulse(planetKey: 'faith', kind: 'prayer.logged', at: DateTime(2026)));
      expect(c.frameFor(_phone).body('faith')!.pulse, 0);
      expect(c.isAnimating, isFalse);
    });
  });

  group('moons', () {
    test('every moon maps to its record and orbits its own world', () {
      final c = _zoomedOn('family');
      final f = c.frameFor(_phone);
      final family = f.body('family')!;
      expect(family.moons.length, 8);
      for (var j = 0; j < 8; j++) {
        final m = family.moons[j];
        expect(m.moon.refTable, 'people');
        expect(m.id, 'people:p$j');
        final lane = MoonLayout.laneOf(j, 8, PlanetArchetype.terracotta);
        expect((m.world - family.world).length, closeTo(lane * family.worldRadius, 1e-9));
        expect(m.front, m.depth < family.depth);
        expect(m.radius, lessThan(family.radius * 0.3));
      }
      expect(family.moons.where((m) => m.front), isNotEmpty);
      expect(family.moons.where((m) => !m.front), isNotEmpty);
    });

    test('moon names show only when zoomed in enough', () {
      final overview = _system().frameFor(_phone).body('family')!;
      expect(overview.moons.every((m) => m.labelTarget == 0), isTrue);
      final zoomed = _zoomedOn('family').frameFor(_phone).body('family')!;
      expect(zoomed.radius, greaterThan(62));
      expect(zoomed.moons.where((m) => m.visible).every((m) => m.labelTarget == 1), isTrue);
    });

    test('new moons pop into their lanes; removed moons are gone', () {
      final c = _system();
      final family = PlanetFixtures.body('family', moonList: PlanetFixtures.familyMoons(count: 3));
      c.setBodies([for (final b in PlanetFixtures.system()) b.key == 'family' ? family : b]);
      expect(c.frameFor(_phone).body('family')!.moons.length, 3);
      final more = PlanetFixtures.body('family', moonList: PlanetFixtures.familyMoons(count: 4));
      c.setBodies([for (final b in PlanetFixtures.system()) b.key == 'family' ? more : b]);
      final arriving = c.frameFor(_phone).body('family')!.moons.last;
      expect(arriving.appear, 0);
      expect(c.isAnimating, isTrue);
      _advance(c, 0.6);
      expect(c.frameFor(_phone).body('family')!.moons.last.appear, 1);
    });

    test('the selected moon wears its ring', () {
      final c = _zoomedOn('family')..selectedMoonId = 'people:p1';
      final moons = c.frameFor(_phone).body('family')!.moons;
      expect(moons.map((m) => m.selected), [0, 1, 0, 0, 0, 0, 0, 0]);
    });
  });

  group('hit testing', () {
    test('a tap on a world hits it; empty sky hits nothing', () {
      final c = _system();
      final f = c.frameFor(_phone);
      for (final b in f.drawOrder.where((b) => b.visible)) {
        final hit = f.hitTest(b.center);
        expect(hit, isNotNull);
        // A front moon or a nearer world may sit on top; otherwise it's this world.
        if (!hit!.isMoon) expect(hit.planetKey, anyOf(b.key, isIn(PlanetFixtures.keys)));
      }
      expect(f.hitTest(const Offset(4, 4)), isNull);
      expect(c.hitTest(const Offset(406, 900), _phone), isNull);
    });

    test('a tap on a moon opens its record; its rect is the touch target', () {
      final c = _zoomedOn('family');
      final f = c.frameFor(_phone);
      final rects = f.moonRects();
      expect(rects.keys, containsAll(['people:p0', 'people:p1']));
      final family0 = f.body('family')!;
      var checked = 0;
      final discs = [
        for (final b in f.drawOrder) ...[
          if (b.visible) (b.center, b.radius * 1.02, b.depth),
          for (final o in b.moons)
            if (o.visible) (o.center, o.radius * 1.1, o.depth),
        ],
      ];
      for (final m in family0.moons.where((m) => m.visible)) {
        expect(rects[m.id]!.contains(m.center), isTrue);
        expect(rects[m.id]!.width, greaterThanOrEqualTo(2 * MoonHitTest.minTouchRadius));
        // Something nearer may cover it (then that is what's under the finger).
        final covered = discs.any((d) => d.$3 < m.depth - 1e-9 && (m.center - d.$1).distance <= d.$2);
        final hit = f.hitTest(m.center)!;
        if (covered) continue;
        expect(hit.isMoon, isTrue, reason: m.id);
        expect(hit.moon!.id, m.id);
        expect(hit.moon!.refTable, 'people');
        expect(hit.planetKey, 'family');
        checked++;
      }
      expect(checked, greaterThanOrEqualTo(3));
      final family = f.body('family')!;
      expect(f.hitTest(family.center)!.planetKey, 'family');
      expect(f.planetRect('family')!.center, family.center);
    });

    test('near-misses reach the closest target within a fingertip', () {
      final f = _system().frameFor(_phone);
      final b = f.drawOrder.last;
      final hit = f.hitTest(b.center + Offset(b.radius * 1.1, 0));
      expect(hit, isNotNull);
    });
  });

  group('camera helpers', () {
    test('framing camera fills the requested share of the screen', () {
      final c = _system();
      for (final key in ['faith', 'travel']) {
        final cam = c.framingCamera(key, from: c.camera, viewport: _phone, fill: 0.5)!;
        c.camera = cam;
        final b = c.frameFor(_phone).body(key)!;
        expect(b.radius, closeTo(0.5 * _phone.width / 2, 1.5));
        expect(b.center.dx, closeTo(_phone.width * cam.principal.dx, 0.5));
      }
      expect(c.framingCamera('nope', from: c.camera, viewport: _phone), isNull);
      expect(c.worldOf('faith'), isNotNull);
    });

    test('the fly-in camera sees the world three-quarter lit, never through the astrolabe', () {
      final c = _system();
      for (final key in PlanetFixtures.keys) {
        final cam = c.framingCamera(key, from: c.camera, viewport: _phone, fill: 0.4)!;
        final probe = PlanetSceneController()
          ..setBodies(PlanetFixtures.system(), animate: false)
          ..camera = cam;
        final f = probe.frameFor(_phone);
        final b = f.body(key)!;
        // The astrolabe's disc stays clear of the world.
        expect((f.coreCenter - b.center).distance, greaterThan(f.coreRadius + b.radius), reason: key);
        expect(b.lightZ, greaterThan(0.2), reason: '$key: lit face toward the camera');
        expect(cam.elevation, lessThanOrEqualTo(PlanetFraming.maxElevation));
      }
    });

    test('worlds between the camera and the fly-in target fade out and stop taking taps', () {
      final c = _zoomedOn('family', fill: 0.36);
      final f = c.frameFor(_phone);
      final family = f.body('family')!;
      final occluders = f.bodies.where((b) => b.opacity < 1).toList();
      for (final b in occluders) {
        expect(b.depth, lessThan(family.depth));
        expect(b.opacity, closeTo(0, 1e-9));
        expect(b.moons.every((m) => m.opacity == b.opacity), isTrue);
      }
      expect(f.hitTest(family.center)!.planetKey, 'family');
      c.setFocus('family', 0);
      expect(c.frameFor(_phone).bodies.every((b) => b.opacity == 1), isTrue);
    });

    test('a fly-in fades the other worlds\' labels and guides', () {
      final c = _system()..setFocus('family', 1);
      final f = c.frameFor(_phone);
      for (final b in f.bodies) {
        if (b.key == 'family') {
          expect(b.guideOpacity, closeTo(0.4, 1e-9));
        } else {
          expect(b.labelTarget, 0);
          expect(b.guideOpacity, 0);
        }
      }
      c.setFocus(null, 1);
      expect(c.focus, 0);
    });
  });

  test('dispose releases listeners', () {
    final c = _system()..addPulseListener((_) {});
    c.dispose();
  });
}
