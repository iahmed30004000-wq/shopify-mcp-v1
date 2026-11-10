import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/home/domain/home_tasks.dart';
import 'package:madar/features/orbit/data/orbit_pulses.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';

import 'orbit_fixtures.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late OrbitPulseHub hub;
  late List<PlanetPulse> pulses;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    hub = OrbitPulseHub(repos, clock: () => fixtureNow);
    pulses = [];
  });
  tearDown(() async {
    await hub.dispose();
    await db.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

  Future<void> listen() async {
    hub.pulses.listen(pulses.add);
    await settle(); // the hub reads its watermark
  }

  test('recordCompletion logs the activity and pulses the planet once', () async {
    await listen();
    await hub.recordCompletion('family', 'contact.logged', 'people', 'p1');
    await settle();
    expect(pulses, hasLength(1));
    final p = pulses.single;
    expect(
      (p.planetKey, p.kind, p.refTable, p.refId, p.origin),
      ('family', 'contact.logged', 'people', 'p1', PulseOrigin.recorded),
    );
    final rows = await repos.activity.since(DateTime(2026));
    expect(rows.single.planetKey, 'family');
    expect(rows.single.at, fixtureNow);
    expect(p.activityId, rows.single.id);
  });

  test('the completion changes the planet: fresh activity lifts its score', () async {
    final repo = OrbitRepository(repos, clock: () => fixtureNow);
    await repos.tasks.insert(TasksCompanion.insert(title: 't', planetKey: const Value('growth')));
    final before = (await repo.snapshot()).planet('growth')!.uScore;
    await hub.recordCompletion('growth', 'goal.logged', null, null);
    final after = (await repo.snapshot()).planet('growth')!.uScore;
    expect(after, greaterThan(before));
  });

  test('completions logged by other features pulse too (a task ticked on home)', () async {
    await listen();
    final service = HomeTasksService(repos, clock: () => fixtureNow);
    final task = await repos.tasks.insert(TasksCompanion.insert(title: 'Call dad', planetKey: const Value('family')));
    await service.toggleDone(task);
    await settle();
    expect(pulses.single.planetKey, 'family');
    expect(pulses.single.kind, HomeTasksService.doneKind);
    expect(pulses.single.origin, PulseOrigin.observed);
    expect(pulses.single.refId, task.id);
  });

  test('a cancel and re-listen while starting subscribes once (no doubled pulses)', () async {
    // Listen → cancel → listen again before the first start read its
    // watermark: only the newest start subscribes.
    final first = hub.pulses.listen((_) {});
    await first.cancel();
    hub.pulses.listen(pulses.add);
    await settle();
    await repos.activity.log(planetKey: 'body', kind: 'workout.logged', at: fixtureNow);
    await settle();
    expect(pulses, hasLength(1));
    expect(pulses.single.planetKey, 'body');
  });

  test('a batch pulses each planet once with the count', () async {
    await listen();
    await db.transaction(() async {
      for (var i = 0; i < 3; i++) {
        await repos.activity.log(planetKey: 'body', kind: 'workout.logged', at: fixtureNow);
      }
      await repos.activity.log(planetKey: 'faith', kind: 'prayer.logged', at: fixtureNow);
    });
    await settle();
    expect(pulses, hasLength(2));
    final body = pulses.firstWhere((p) => p.planetKey == 'body');
    expect(body.count, 3);
    expect(pulses.firstWhere((p) => p.planetKey == 'faith').isPrayer, isTrue);
  });

  test('restoring an old completion (undo of a delete) does not pulse', () async {
    await listen();
    await repos.activity.log(planetKey: 'money', kind: 'bill.paid', at: fixtureNow.subtract(const Duration(days: 3)));
    await settle();
    expect(pulses, isEmpty);
  });

  test('nothing is observed without listeners; dispose closes the stream', () async {
    await repos.activity.log(planetKey: 'money', kind: 'x', at: fixtureNow);
    await hub.recordCompletion('money', 'y', null, null); // no listener: dropped
    var done = false;
    hub.pulses.listen((_) {}, onDone: () => done = true);
    await hub.dispose();
    await settle();
    expect(done, isTrue);
  });
}
