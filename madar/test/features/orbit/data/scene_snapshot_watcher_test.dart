import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/data/scene_snapshot_watcher.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';

import 'orbit_fixtures.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late OrbitRepository repo;
  late int computes;
  late DateTime clock;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    clock = fixtureNow;
    repo = OrbitRepository(repos, clock: () => clock);
    computes = 0;
  });
  tearDown(() => db.close());

  SceneSnapshotWatcher watcher({Duration? tick, ValueListenable<bool>? active}) => SceneSnapshotWatcher.forTables(
    db,
    repo.watchedTables,
    clock: () => clock,
    debounce: const Duration(milliseconds: 30),
    maxWait: const Duration(milliseconds: 200),
    tick: tick,
    active: active,
    compute: (now) {
      computes++;
      return repo.snapshot(now: now);
    },
  );

  Future<void> settle([int ms = 150]) => Future<void>.delayed(Duration(milliseconds: ms));

  test('emits once on listen, then again when a relevant table changes', () async {
    final seen = <SceneSnapshot>[];
    final sub = watcher().watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    expect(seen, hasLength(1));
    expect(seen.single.planet('family')!.state, PlanetState.dormant);

    await repos.people.insert(
      PeopleCompanion.insert(
        name: 'أبي',
        rhythmDays: const Value(2),
        lastContact: Value(fixtureNow.subtract(const Duration(days: 6))),
      ),
    );
    await settle();
    expect(seen, hasLength(2));
    expect(seen.last.planet('family')!.state, PlanetState.neglected);
    expect(seen.last.planet('family')!.moons.single.label, 'أبي');
    expect(seen.last.radar.single.text, contains('فات الموعد بـ٤ أيام'));
  });

  test('paused (or in the background) it does no work; resuming catches up once', () async {
    final seen = <SceneSnapshot>[];
    final sub = watcher(tick: const Duration(milliseconds: 40)).watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    sub.pause();
    final paused = computes;
    await repos.boards.insert(BoardsCompanion.insert(name: 'While paused'));
    await settle(300);
    expect(computes, paused, reason: 'no ticks and no table-driven queries while paused');
    sub.resume();
    await settle();
    expect(computes, greaterThan(paused));
    expect(seen.last.planet('work')!.moons.map((m) => m.label), contains('While paused'));
  });

  test('the app in the background stops the watch until it returns', () async {
    final foreground = ValueNotifier(true);
    addTearDown(foreground.dispose);
    final seen = <SceneSnapshot>[];
    final sub = watcher(tick: const Duration(milliseconds: 40), active: foreground).watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    foreground.value = false;
    final before = computes;
    await repos.boards.insert(BoardsCompanion.insert(name: 'In the background'));
    await settle(300);
    expect(computes, before);
    foreground.value = true;
    await settle();
    expect(seen.last.planet('work')!.moons.map((m) => m.label), contains('In the background'));
  });

  test('a burst of writes costs one recomputation', () async {
    final seen = <SceneSnapshot>[];
    final sub = watcher().watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    final before = computes;
    for (var i = 0; i < 10; i++) {
      await repos.boards.insert(BoardsCompanion.insert(name: 'B$i'));
    }
    await settle();
    expect(computes - before, lessThanOrEqualTo(2));
    expect(seen.last.planet('work')!.moons, hasLength(10));
  });

  test('irrelevant tables do not recompute; unchanged content is not re-emitted', () async {
    final seen = <SceneSnapshot>[];
    final sub = watcher().watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    final before = computes;
    await repos.worries.insert(WorriesCompanion.insert(body: 'x'));
    await repos.reminders.insert(
      RemindersCompanion.insert(ownerTable: 'tasks', ownerId: 't', rule: const {'kind': 'once'}),
    );
    await settle();
    expect(computes, before);
    // A relevant write that changes nothing visible: recomputed, not emitted.
    final faith = (await repos.planets.getAll(where: (p) => p.key.equals('faith'))).single;
    await repos.planets.setColumn(faith.id, 'icon', faith.icon);
    await settle();
    expect(computes, before + 1);
    expect(seen, hasLength(1));
  });

  test('the clock tick refreshes time-based state', () async {
    final med = await repos.medications.insert(
      MedicationsCompanion.insert(
        name: 'Metformin',
        times: const Value(['16:10']),
        createdAt: Value(fixtureNow.subtract(const Duration(days: 1))),
      ),
    );
    await repos.medDoses.insert(
      MedDosesCompanion.insert(
        medicationId: med.id,
        scheduledAt: Value(DateTime(2026, 9, 26, 16, 10)),
        status: DoseStatus.taken,
      ),
    );
    final seen = <SceneSnapshot>[];
    final sub = watcher(tick: const Duration(milliseconds: 40)).watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    expect(seen.last.planet('health')!.score.reasons, isEmpty);
    // 50 minutes later today's 16:10 dose is past due – no table changed.
    clock = fixtureNow.add(const Duration(minutes: 50));
    await settle(200);
    expect(seen.last.planet('health')!.score.reasons.single.code, ReasonCode.dosesPastDue);
  });

  test('cancelling stops every timer and query', () async {
    final sub = watcher(tick: const Duration(milliseconds: 20)).watch().listen((_) {});
    await settle(80);
    await sub.cancel();
    final after = computes;
    await repos.people.insert(PeopleCompanion.insert(name: 'x'));
    await settle(120);
    expect(computes, after);
  });

  test('a burst that never pauses still refreshes within maxWait', () async {
    final seen = <SceneSnapshot>[];
    final sub = watcher().watch().listen(seen.add);
    addTearDown(sub.cancel);
    await settle();
    final stop = DateTime.now().add(const Duration(milliseconds: 450));
    var i = 0;
    while (DateTime.now().isBefore(stop)) {
      await repos.boards.insert(BoardsCompanion.insert(name: 'B${i++}'));
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    // Writes every 15 ms never leave a 30 ms gap, yet maxWait forced updates.
    expect(seen.length, greaterThanOrEqualTo(2));
  });
}
