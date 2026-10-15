import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/data/planet_customization_service.dart';
import 'package:madar/features/orbit/domain/orbit_labels.dart';
import 'package:madar/features/orbit/domain/planet_archetypes.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';

import 'orbit_fixtures.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late PlanetCustomizationService service;
  late OrbitRepository orbit;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    service = PlanetCustomizationService(repos);
    orbit = OrbitRepository(repos, clock: () => fixtureNow);
  });
  tearDown(() => db.close());

  Future<PlanetRow> planet(String key) async => (await repos.planets.getAll(where: (p) => p.key.equals(key))).single;

  test('rename in one language; undo restores it', () async {
    final undo = await service.rename('work', '  التجارة ', languageCode: 'ar');
    expect((await planet('work')).nameAr, 'التجارة');
    expect((await planet('work')).nameEn, 'Work'); // the English name was different
    expect((await orbit.snapshot()).planet('work')!.name, 'التجارة');
    await undo();
    expect((await planet('work')).nameAr, 'العمل');
    await expectLater(service.rename('work', '   ', languageCode: 'ar'), throwsA(isA<PlanetCustomizationException>()));
  });

  test('a custom planet named once renames in both languages', () async {
    final (row, _) = await service.addPlanet(name: 'الرياضة', archetype: PlanetArchetype.volcanic);
    await service.rename(row.key, 'Sport', languageCode: 'en');
    final after = await planet(row.key);
    expect((after.nameAr, after.nameEn), ('Sport', 'Sport'));
  });

  test('recolour derives a new palette; undo brings back the curated one', () async {
    final undo = await service.recolor('faith', const Color(0xFF3366FF));
    expect((await orbit.snapshot()).planet('faith')!.palette.surface, const Color(0xFF3366FF));
    await undo();
    expect((await orbit.snapshot()).planet('faith')!.palette, same(PlanetPalettes.faith));
  });

  test('restyle and icon', () async {
    final undo = await service.setArchetype('growth', PlanetArchetype.ice);
    final snap = await orbit.snapshot();
    expect(snap.planet('growth')!.archetype, PlanetArchetype.ice);
    expect(snap.planet('growth')!.shaderArchetype, PlanetArchetype.crystal);
    await undo();
    expect((await planet('growth')).archetype, PlanetArchetype.verdant);
    await service.setIcon('growth', 'book');
    expect((await planet('growth')).icon, 'book');
  });

  test('hide / show; undo', () async {
    final undo = await service.setHidden('travel', true);
    expect((await orbit.snapshot()).planet('travel'), isNull);
    await undo();
    expect((await orbit.snapshot()).planet('travel'), isNotNull);
  });

  test('weight changes the balance; 0 leaves a planet out of it', () async {
    await seedLivedIn(repos, thriving: false);
    final before = await orbit.snapshot();
    final undo = await service.setWeight('faith', 0);
    final without = await orbit.snapshot();
    expect(without.balance, greaterThan(before.balance)); // the weakest planet no longer counts
    expect(without.radar.map((r) => r.planetKey), isNot(contains('faith')));
    await service.setWeight('faith', 99);
    expect((await planet('faith')).weight, PlanetCustomizationService.maxWeight);
    await undo();
    expect((await planet('faith')).weight, 1.0);
  });

  test('per-source weights: switching a source off removes its reasons; aliases are canonical', () async {
    await seedLivedIn(repos, thriving: false);
    expect((await orbit.snapshot()).planet('body')!.score.reasons.map((r) => r.code), contains(ReasonCode.waterLow));
    final undo = await service.setSourceWeight('body', 'water', 0);
    final body = (await orbit.snapshot()).planet('body')!;
    expect(body.score.reasons.map((r) => r.code), isNot(contains(ReasonCode.waterLow)));
    await undo();
    expect((await planet('body')).sources.containsKey('water'), isTrue);

    await service.setSourceWeight('health', 'doses', 0.9);
    final sources = (await planet('health')).sources;
    expect(sources.containsKey('medications'), isFalse); // merged into the canonical key
    expect(sources['doses'], 0.9);

    await service.setSources('health', {'medications': 1, 'mood': 0.5});
    expect((await planet('health')).sources, {'doses': 1.0, 'mood': 0.5});
    await expectLater(service.setSourceWeight('health', 'horoscope', 1), throwsA(isA<PlanetCustomizationException>()));
  });

  test('reorder; undo restores the previous order', () async {
    final keys = (await repos.planets.getAll()).map((p) => p.key).toList();
    final undo = await service.reorder(keys.reversed.toList());
    expect((await orbit.snapshot()).planets.map((p) => p.key), keys.reversed);
    await undo();
    expect((await orbit.snapshot()).planets.map((p) => p.key), keys);
  });

  test('add a custom planet in an ice style; undo removes it', () async {
    final (row, undo) = await service.addPlanet(name: 'القرآن', archetype: PlanetArchetype.ice, icon: 'book');
    expect(row.key, startsWith('custom_'));
    expect(row.color, OrbitArchetypes.defaultColor(PlanetArchetype.ice).toARGB32());
    final snap = await orbit.snapshot();
    expect(snap.planets.last.key, row.key); // appended at the end of the orbit
    expect(snap.planets.last.shaderArchetype, PlanetArchetype.crystal);
    expect(snap.planets.last.state, PlanetState.dormant);
    await undo();
    expect((await orbit.snapshot()).planet(row.key), isNull);
  });

  test('delete a custom planet: attached records are detached, undo re-attaches them', () async {
    final (row, _) = await service.addPlanet(name: 'Side project', archetype: PlanetArchetype.desert);
    final task = await repos.tasks.insert(TasksCompanion.insert(title: 'Ship', planetKey: Value(row.key)));
    final module = await repos.customModules.insert(
      CustomModulesCompanion.insert(name: 'Log', color: 0xFF888888, planetKey: Value(row.key)),
    );
    final habit = await repos.habits.insert(HabitsCompanion.insert(name: 'Code', planetKey: Value(row.key)));
    final undo = await service.deletePlanet(row.key);
    expect((await orbit.snapshot()).planet(row.key), isNull);
    expect((await repos.tasks.byId(task.id))!.planetKey, isNull);
    expect((await repos.customModules.byId(module.id))!.planetKey, isNull);
    expect((await repos.habits.byId(habit.id))!.planetKey, isNull);
    await undo();
    final restored = await planet(row.key);
    expect(restored.id, row.id);
    expect(restored.sortOrder, row.sortOrder);
    expect((await repos.tasks.byId(task.id))!.planetKey, row.key);
    expect((await repos.customModules.byId(module.id))!.planetKey, row.key);
    expect((await repos.habits.byId(habit.id))!.planetKey, row.key);
    expect((await orbit.snapshot()).planet(row.key)!.moons.single.refId, module.id);
  });

  test('built-in planets cannot be deleted; refusals carry a typed error', () async {
    Matcher refused(PlanetEditError e) =>
        throwsA(isA<PlanetCustomizationException>().having((x) => x.error, 'error', e));
    await expectLater(service.deletePlanet('faith'), refused(PlanetEditError.builtInDelete));
    await expectLater(service.rename('faith', '   ', languageCode: 'ar'), refused(PlanetEditError.needsName));
    await expectLater(service.addPlanet(name: '', archetype: PlanetArchetype.ice), refused(PlanetEditError.needsName));
    await expectLater(service.setSourceWeight('faith', 'horoscope', 1), refused(PlanetEditError.unknownSource));
    await expectLater(service.setHidden('nowhere', true), refused(PlanetEditError.notFound));
    // The activity fallback can be switched off like any source.
    await service.setSourceWeight('faith', 'activity', 0);
    expect((await planet('faith')).sources['activity'], 0);
    expect(PlanetCustomizationService.isCustomKey('faith'), isFalse);
    expect(PlanetCustomizationService.isCustomKey('custom_1'), isTrue);
  });

  test('reset a built-in to its defaults; undo', () async {
    await service.rename('money', 'الخزينة', languageCode: 'ar');
    await service.recolor('money', const Color(0xFF000000));
    await service.setHidden('money', true);
    final undo = await service.resetToDefaults('money');
    final reset = await planet('money');
    expect((reset.nameAr, reset.nameEn, reset.hidden), ('المال', 'Money', false));
    expect(reset.color, PlanetPalettes.money.surface.toARGB32());
    expect(reset.archetype, PlanetArchetype.crystal);
    await undo();
    expect((await planet('money')).nameAr, 'الخزينة');
    expect((await planet('money')).hidden, isTrue);
  });
}
