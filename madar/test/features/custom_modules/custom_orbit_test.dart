import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MadarDatabase db;
  late Repositories repos;
  final now = DateTime(2026, 9, 30, 13, 0);

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
  });
  tearDown(() => db.close());

  test('the orbit sees builder modules: tracker score input + moons, lists as moons only', () async {
    final service = CustomModulesService(repos, clock: () => now);
    final reading = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name));
    final gifts = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.giftIdeas, (t) => t.name));
    final archived = await service.createModule(
      ModuleTemplates.build(ModuleTemplateKey.sleepLog, (t) => t.name).copyWith(name: 'Old'),
    );
    await service.setArchived(archived.id, true);
    await service.addEntry(reading.id, {'f1': 'x', 'f2': 10}, at: now.subtract(const Duration(hours: 2)));

    final data = await OrbitRepository(repos, clock: () => now).load(now: now);
    final scoreModules = data.scoreInputs.modules;
    expect(scoreModules.map((m) => m.id), [reading.id]);
    expect(scoreModules.single.planetKey, 'growth');
    expect(scoreModules.single.lastEntry, now.subtract(const Duration(hours: 2)));
    final moons = data.moonInputs.modules;
    expect(moons.map((m) => m.id).toSet(), {reading.id, gifts.id});
    expect(moons.firstWhere((m) => m.id == gifts.id).planetKey, 'family');

    // The entry's activity feeds the planet's freshness too.
    final acts = await repos.activityLog.getAll();
    expect(acts.single.planetKey, 'growth');
  });
}
