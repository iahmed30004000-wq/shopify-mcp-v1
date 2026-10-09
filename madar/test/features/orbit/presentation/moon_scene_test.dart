// The data moons on the home orbit: people around Family, wallets around
// Money, boards around Work, trips around Travel. APK #15 drew them at ~3 px
// across, scattered up to three world-radii away and dipping under the brass
// dial – the owner reported "no moons at all".
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

import '../../../helpers/test_app.dart';
import '../data/orbit_fixtures.dart';
import 'orbit_scene_fixtures.dart';

/// A lived-in database with several people, wallets, boards and trips – the
/// four worlds the brief promises moons around.
Future<void> _seedMoonData(MadarDatabase db) async {
  final r = Repositories(db);
  await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
  await seedLivedIn(r, now: testNow, thriving: true);
  for (final name in ['جدتي', 'عمي خالد', 'خالتي سلمى']) {
    await r.people.insert(
      PeopleCompanion.insert(
        name: name,
        rhythmDays: const Value(14),
        lastContact: Value(testNow.subtract(const Duration(days: 3))),
        createdAt: Value(testNow.subtract(const Duration(days: 90))),
      ),
    );
  }
  await r.wallets.insert(WalletsCompanion.insert(name: 'التوفير', currency: 'JOD', openingMilli: const Value(900000)));
  await r.boards.insert(BoardsCompanion.insert(name: 'البيت'));
  await r.trips.insert(
    TripsCompanion.insert(destination: 'عمّان', startDate: Value(testNow.add(const Duration(days: 40)))),
  );
}

SceneController _scene(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene)).controller;

void main() {
  testWidgets('every world with sub-items wears its moons, big enough to see and to tap', (tester) async {
    final app = await pumpMadarApp(tester, beforePump: _seedMoonData);
    await tester.pump(const Duration(milliseconds: 400));
    await settleApp(tester);

    // The data layer feeds the scene.
    final snapshot = app.container.read(sceneSnapshotProvider).value!;
    for (final key in ['family', 'money', 'work', 'travel']) {
      expect(snapshot.planet(key)!.moons, isNotEmpty, reason: '$key has sub-items to wear as moons');
    }

    final c = _scene(tester);
    // Two minutes of orbiting: the moons must read all the way round, not
    // only in the pose the first frame happened to catch.
    final seen = <String>{};
    for (var step = 0; step < 60; step++) {
      final f = c.planets.frameFor(c.viewport);
      for (final b in f.bodies) {
        if (!b.visible) continue;
        expect(b.moons.length, snapshot.planet(b.key)!.moons.length, reason: '${b.key} keeps all its moons');
        for (final m in b.moons) {
          if (!m.visible) continue;
          seen.add(m.id);
          // Big enough to see (and to put a finger on).
          expect(
            m.radius,
            greaterThanOrEqualTo(MoonStyle.minScreenRadius * 0.8),
            reason: '${m.moon.label} on ${b.key} is a moon, not a speck',
          );
          expect(m.radius, greaterThan(MoonHitTest.minTappableMoonRadius));
          // Close enough to belong to its own world: inside the moon band,
          // never halfway to the next lane.
          final reach = b.radius * (PlanetStyle.moonLaneStartOf(b.body.archetype) + MoonLayout.span + 0.5);
          expect(
            (m.center - b.center).distance,
            lessThanOrEqualTo(reach),
            reason: '${m.moon.label} orbits ${b.key}, not the sky',
          );
          // Its orbit clears the world itself (it may of course pass in
          // front of it or behind it – that is what an orbit looks like).
          expect(
            (m.world - b.world).length,
            greaterThan(b.worldRadius + m.worldRadius),
            reason: '${m.moon.label} never collides with ${b.key}',
          );
        }
      }
      c.planets.advanceSeconds(2);
      c.refresh();
    }

    // Each of the four worlds showed at least one moon over the two minutes.
    for (final key in ['family', 'money', 'work', 'travel']) {
      final moons = snapshot.planet(key)!.moons.map((m) => m.id).toSet();
      expect(seen.intersection(moons), isNotEmpty, reason: '$key never showed a moon');
    }
  });

  testWidgets('moons keep to their own world and never dive under the astrolabe', (tester) async {
    await pumpMadarApp(tester, beforePump: _seedMoonData);
    await tester.pump(const Duration(milliseconds: 400));
    await settleApp(tester);
    final c = _scene(tester);
    var hiddenByDial = 0, shown = 0;
    for (var step = 0; step < 80; step++) {
      final f = c.planets.frameFor(c.viewport);
      for (final b in f.bodies) {
        if (!b.visible || b.behindCore) continue;
        for (final m in b.moons) {
          if (!m.visible) continue;
          shown++;
          // Its world is in front of the dial, so the moon must be too.
          if (m.depth > f.coreDepth && (m.center - f.coreCenter).distance < f.coreRadius) hiddenByDial++;
        }
      }
      c.planets.advanceSeconds(2);
      c.refresh();
    }
    expect(shown, greaterThan(100), reason: 'moons are on screen through the whole drift');
    expect(hiddenByDial, 0, reason: 'a moon of a world in front of the dial is never swallowed by the brass');
  });

  test('the moon band is slow, tight and clear of its world', () {
    // Slow enough to be cinematic: more than a minute a lap, never a twitch.
    expect(MoonLayout.periodOf(PlanetStyle.moonLaneStartOf(PlanetArchetype.terracotta)), greaterThan(60));
    expect(MoonLayout.periodOf(PlanetStyle.moonLaneStartOf(PlanetArchetype.terracotta)), lessThan(180));
    // The band is narrower than the gap between two planet lanes measured in
    // world units, so a moon never wanders into a neighbour's lane.
    const layout = PlanetSystemLayout();
    final band = MoonLayout.span * layout.bodyRadius;
    expect(band, lessThan(layout.outerRadius - layout.innerRadius));
    // Every moon lane clears the planet's own disc.
    for (var count = 1; count <= 12; count++) {
      for (var j = 0; j < count; j++) {
        final lane = MoonLayout.laneOf(j, count, PlanetArchetype.terracotta);
        expect(lane - MoonStyle.maxFactor, greaterThan(1), reason: 'moon $j of $count');
      }
    }
  });
}
