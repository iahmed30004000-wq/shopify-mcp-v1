// The orrery must stay an orrery at any number of worlds.
//
// Madar was composed for eight; «السفرة» and «الألعاب» made ten and the
// owner can add his own, which is when the sky stopped reading as a system:
// «الكواكب مش منظمة». A world hung half off the left edge, four of them
// clumped down one side, and the discs' sizes jumped. These are the four
// guarantees that broke, asserted at every count from one to sixteen so
// none of them can quietly break again:
//
//   1. nothing is ever cut off – every disc, all the way round its tilted
//      orbit, stands clear of all four edges of its frame;
//   2. the worlds are spread evenly – the smallest angle between two of
//      them is a known fraction of their even share of the circle, and on
//      screen no two discs touch at rest;
//   3. no lane crosses the astrolabe's brass limb;
//   4. the discs are a family – the biggest is at most
//      [PlanetStyle.maxSizeRatio] times the smallest.
//
// The eye-check behind these numbers is `orbit_counts_screenshot_test.dart`.
import 'dart:math' as math;
import 'dart:ui' show Locale, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/presentation/scene/scene_composition.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import '../render/planets/planet_fixtures.dart';

/// How far outside the brass limb the innermost lane has to stay, as a
/// multiple of the dial's own radius. The lane rings are drawn over the
/// sky, so one that grazes the limb reads as a scratch on the brass. The
/// composition holds 1.04–1.14 at the counts below; this is the floor.
const double _limbClearance = 1.035;

const _phone = Size(412, 915);
const _small = Size(360, 740);

/// The band home leaves for the system: under the 64-px header, above the
/// collapsed glass panel (57.5 % of the height).
Rect _bandOf(Size v) => Rect.fromLTRB(0, 68, v.width, v.height * 0.575 - 8);

/// Counts worth asserting: one world, a nearly empty sky, the old eight,
/// today's ten, and well past them.
const _counts = [1, 2, 5, 8, 10, 13, 16];

/// The ten seeded worlds in orbit order, then user-added worlds in the
/// styles a new world can take.
const _seeded = [
  ('faith', PlanetArchetype.faith),
  ('health', PlanetArchetype.ocean),
  ('family', PlanetArchetype.terracotta),
  ('work', PlanetArchetype.industrial),
  ('money', PlanetArchetype.crystal),
  ('growth', PlanetArchetype.verdant),
  ('body', PlanetArchetype.volcanic),
  ('travel', PlanetArchetype.gasGiant),
  ('sufra', PlanetArchetype.desert),
  ('games', PlanetArchetype.ice),
];

const _extraStyles = [
  PlanetArchetype.ice,
  PlanetArchetype.desert,
  PlanetArchetype.verdant,
  PlanetArchetype.crystal,
  PlanetArchetype.gasGiant,
  PlanetArchetype.ocean,
];

List<PlanetBody> _worlds(int count) => [
  for (var i = 0; i < count; i++)
    if (i < _seeded.length)
      PlanetFixtures.body(_seeded[i].$1, archetype: _seeded[i].$2, score: 0.3 + 0.07 * (i % 9), moons: i < 8)
    else
      PlanetFixtures.custom('x$i', _extraStyles[(i - _seeded.length) % _extraStyles.length], score: 0.7),
];

List<LaneBody> _lanesOf(List<PlanetBody> bodies) => [for (final b in bodies) (archetype: b.archetype, seed: b.seed)];

/// A scene laid out exactly as home lays it out, with [bodies] in orbit.
SceneController _scene(List<PlanetBody> bodies, {Size size = _phone}) {
  final c = SceneController(initialTime: 12, now: DateTime(2026, 9, 27, 12, 30))
    ..setBodies(bodies, animate: false)
    ..layout(size, _bandOf(size))
    ..setAstrolabeState(
      AstrolabeState.fromSchedule(
        schedule: PrayerSchedule(const PrayerSettings()),
        now: DateTime(2026, 9, 27, 12, 30),
        labels: AstrolabeLabels(lookupL10n(const Locale('ar')), MadarFormatter()),
      ),
      animate: false,
    )
    ..refresh();
  addTearDown(c.dispose);
  return c;
}

double _wrapTau(double a) {
  final d = a % (2 * math.pi);
  return d < 0 ? d + 2 * math.pi : d;
}

void main() {
  const composition = OrbitComposition();
  final layout = composition.layout;

  // --------------------------------------------------------- the four rules --

  group('every world count reads as one orrery', () {
    for (final size in [_phone, _small]) {
      final band = _bandOf(size);
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      for (final n in _counts) {
        test('$n worlds on a $label phone: nothing is cut off', () {
          final bodies = _worlds(n);
          final cam = composition.overview(viewport: size, sceneRect: band, lanes: _lanesOf(bodies));
          final frame = Rect.fromLTRB(0, band.top, size.width, band.bottom).deflate(composition.margin);
          for (var i = 0; i < n; i++) {
            final b = bodies[i];
            final lane = layout.laneRadius(i, n);
            final r = layout.bodyRadiusOf(b.archetype, count: n);
            // All the way round the orbit, at its own tilt and node.
            for (var k = 0; k < 360; k++) {
              final p = PlanetSystemLayout.orbitPoint(
                lane,
                2 * math.pi * k / 360,
                inclination: layout.inclinationOf(b.seed),
                node: layout.nodeOf(b.seed),
              );
              final pr = cam.project(p, size);
              expect(pr.visible, isTrue, reason: '${b.key} at $k° is behind the camera');
              final disc = Rect.fromCircle(center: pr.offset, radius: r * pr.scale);
              expect(
                frame.inflate(0.5).contains(disc.topLeft) && frame.inflate(0.5).contains(disc.bottomRight),
                isTrue,
                reason: '${b.key} at $k° → $disc leaves $frame',
              );
            }
          }
        });
      }
    }

    for (final n in _counts) {
      test('$n worlds stand an even share of the circle apart', () {
        final bodies = _worlds(n);
        final longitudes = [for (var i = 0; i < n; i++) _wrapTau(layout.initialAngle(i, n, bodies[i].seed))]..sort();
        if (n == 1) return;
        for (var i = 0; i < n; i++) {
          final gap = i == 0
              ? longitudes.first + 2 * math.pi - longitudes.last
              : longitudes[i] - longitudes[i - 1];
          expect(
            gap,
            greaterThanOrEqualTo(layout.minAngularGap(n) - 1e-9),
            reason: 'worlds $i and ${i - 1} of $n are only ${(gap * 180 / math.pi).toStringAsFixed(1)}° apart',
          );
        }
        // …and not a mechanical ring either: the shares are nudged.
        final even = [for (var i = 0; i < n; i++) _wrapTau(layout.initialAngle(0, n, bodies[0].seed) + i * 2 * math.pi / n)]
          ..sort();
        expect(longitudes, isNot(orderedEquals(even)));
      });

      test('$n worlds: no two discs touch at rest, and none lies on the dial', () {
        final c = _scene(_worlds(n));
        expect(c.planets.crowded(c.viewport), isFalse, reason: 'a fresh sky is never crowded');
        final frame = c.planets.frameFor(c.viewport);
        final bodies = frame.bodies.toList();
        for (var i = 0; i < bodies.length; i++) {
          for (var j = i + 1; j < bodies.length; j++) {
            final gap = (bodies[i].center - bodies[j].center).distance - bodies[i].radius - bodies[j].radius;
            expect(gap, greaterThan(0), reason: '${bodies[i].key} and ${bodies[j].key} overlap by ${-gap} px');
          }
        }
      });

      test('$n worlds: no lane crosses the astrolabe\'s brass limb', () {
        final bodies = _worlds(n);
        final cam = composition.overview(viewport: _phone, sceneRect: _bandOf(_phone), lanes: _lanesOf(bodies));
        final corePx = composition.corePixels(cam, _phone);
        final core = cam.project(V3.zero, _phone).offset;
        for (var i = 0; i < n; i++) {
          final b = bodies[i];
          final lane = layout.laneRadius(i, n);
          for (var k = 0; k < 360; k++) {
            final p = PlanetSystemLayout.orbitPoint(
              lane,
              2 * math.pi * k / 360,
              inclination: layout.inclinationOf(b.seed),
              node: layout.nodeOf(b.seed),
            );
            final d = (cam.project(p, _phone).offset - core).distance;
            expect(
              d / corePx,
              greaterThan(_limbClearance),
              reason: '${b.key}\'s lane passes ${(d / corePx).toStringAsFixed(3)} × the limb at $k°',
            );
          }
        }
      });
    }

    test('the discs are a family, not a jumble', () {
      final sizes = PlanetArchetype.values.map((a) => layout.bodyRadiusOf(a, count: 10));
      expect(sizes.reduce(math.max) / sizes.reduce(math.min), lessThanOrEqualTo(PlanetStyle.maxSizeRatio + 1e-9));
      // Character is kept: Travel is still the big one, ice the small one.
      expect(sizes.reduce(math.max), layout.bodyRadiusOf(PlanetArchetype.gasGiant, count: 10));
      expect(sizes.reduce(math.min), layout.bodyRadiusOf(PlanetArchetype.ice, count: 10));
      // …and on screen, where depth adds its own spread, still well under 2.
      final c = _scene(_worlds(10));
      final discs = c.planets.frameFor(c.viewport).bodies.map((b) => b.radius);
      expect(discs.reduce(math.max) / discs.reduce(math.min), lessThan(1.6));
    });

    test('past ten worlds the discs give way, never the frame', () {
      expect(layout.crowdingScale(layout.fullSizeCount), 1);
      expect(layout.crowdingScale(1), 1);
      for (var n = layout.fullSizeCount + 1; n <= 20; n++) {
        expect(layout.crowdingScale(n), lessThan(layout.crowdingScale(n - 1)), reason: '$n worlds');
        expect(layout.crowdingScale(n), greaterThan(0.65), reason: '$n worlds must not be specks');
      }
    });

    test('the dial stays readable at every count', () {
      for (final n in _counts) {
        final cam = composition.overview(
          viewport: _phone,
          sceneRect: _bandOf(_phone),
          lanes: _lanesOf(_worlds(n)),
        );
        final r = composition.corePixels(cam, _phone);
        expect(
          AstrolabeGeometry.lodFor(r).index,
          greaterThanOrEqualTo(AstrolabeLod.medium.index),
          reason: '$n worlds leave the dial $r px – too small for the countdown',
        );
      }
    });
  });

  // ------------------------------------------------------------ pure layout --

  group('the lane band', () {
    test('holds its width up to laneFloorCount worlds, then grows', () {
      for (var n = 2; n <= layout.laneFloorCount; n++) {
        expect(layout.outermostLane(n), lessThanOrEqualTo(layout.outerRadius + 1e-9), reason: '$n worlds');
        expect(layout.laneRadius(0, n), greaterThanOrEqualTo(layout.innerRadius - 1e-9), reason: '$n worlds');
      }
      expect(layout.outermostLane(layout.laneFloorCount + 4), greaterThan(layout.outerRadius));
    });

    test('lanes are ordered and never closer than the floor', () {
      for (final n in [..._counts, 20, 24]) {
        if (n < 2) continue;
        for (var i = 1; i < n; i++) {
          final gap = layout.laneRadius(i, n) - layout.laneRadius(i - 1, n);
          expect(gap, greaterThanOrEqualTo(layout.minLaneGap - 1e-9), reason: '$n worlds, lane $i');
          expect(gap, lessThanOrEqualTo(layout.maxLaneGap + 1e-9), reason: '$n worlds, lane $i');
        }
      }
    });

    test('the floor is the band divided among laneFloorCount worlds', () {
      expect(
        layout.minLaneGap * (layout.laneFloorCount - 1),
        closeTo(layout.outerRadius - layout.innerRadius, 1e-12),
      );
    });

    test('the same worlds always give the same sky', () {
      for (final n in _counts) {
        for (var i = 0; i < n; i++) {
          final seed = _worlds(n)[i].seed;
          expect(layout.initialAngle(i, n, seed), layout.initialAngle(i, n, seed));
        }
      }
    });
  });

  group('what already worked must keep working', () {
    test('the orbital periods are untouched (the owner asked for a livelier sky)', () {
      const plain = PlanetSystemLayout();
      expect(plain.innerPeriod, 170);
      expect(plain.periodFor(plain.innerRadius), closeTo(170, 1e-9));
      expect(MoonLayout.periodOf(1.62), closeTo(42, 1e-9));
      // The moon band is where it was fixed.
      expect(MoonLayout.span, 0.38);
    });

    test('outer worlds are still the slower ones', () {
      expect(layout.periodFor(layout.outerRadius), greaterThan(layout.periodFor(layout.innerRadius)));
    });
  });
}
