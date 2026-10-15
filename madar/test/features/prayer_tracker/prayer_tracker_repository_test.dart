import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/data/orbit_pulses.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/prayer_tracker/data/prayer_tracker_repository.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_days.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  var now = DateTime(2026, 9, 28, 16, 20);
  final day = DateTime(2026, 9, 28);

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    now = DateTime(2026, 9, 28, 16, 20);
  });
  tearDown(() => db.close());

  PrayerTrackerRepository repo({OrbitPulseHub? hub}) => PrayerTrackerRepository(repos, hub: hub, clock: () => now);
  Future<List<ActivityRow>> completions() => repos.activity.since(DateTime(2026), planetKey: 'faith');

  /// Everything the tracker owns, comparable (deeply) across an undo.
  Future<List<List<Object>>> state() async {
    final logs = await repos.prayerLogs.getAll();
    final acts = await completions();
    logs.sort((a, b) => a.id.compareTo(b.id));
    acts.sort((a, b) => a.id.compareTo(b.id));
    // ActivityRow's payload is a map (compared by identity): compare text.
    return [
      logs,
      [for (final a in acts) '${a.id}|${a.kind}|${a.refTable}|${a.refId}|${a.at}|${a.createdAt}|${a.payload}'],
    ];
  }

  test('the tap cycle: prayed → late → missed → none, each step undone exactly', () async {
    final r = repo();
    final before = await state();
    final prayed = await r.cycle(day, Prayer.asr);
    expect(prayed.status, PrayerStatus.prayed);
    expect((await completions()).single.kind, PrayerTrackerRepository.obligatoryKind);
    expect((await completions()).single.payload['prayer'], 'asr');
    final afterPrayed = await state();

    now = now.add(const Duration(minutes: 3));
    final late = await r.cycle(day, Prayer.asr);
    expect(late.status, PrayerStatus.late);
    expect(late.after!.id, prayed.after!.id, reason: 'the log keeps its id');
    expect((await completions()).single.at, now, reason: 'a new status re-stamps the completion');
    final afterLate = await state();

    final missed = await r.cycle(day, Prayer.asr);
    expect(missed.status, PrayerStatus.missed);
    expect(await completions(), isEmpty, reason: 'a missed prayer is no completion');
    final afterMissed = await state();

    final none = await r.cycle(day, Prayer.asr);
    expect(none.after, isNull);
    expect(await repos.prayerLogs.getAll(), isEmpty);

    await none.undo();
    expect(await state(), afterMissed);
    await missed.undo();
    expect(await state(), afterLate);
    await late.undo();
    expect(await state(), afterPrayed);
    await prayed.undo();
    expect(await state(), before);
  });

  test('jamaah and mosque: marking an unlogged prayer logs it; toggling keeps the completion', () async {
    final r = repo();
    final j = await r.setJamaah(day, Prayer.fajr, true);
    expect((j.status, j.after!.inJamaah, j.after!.atMosque), (PrayerStatus.prayed, true, false));
    final completion = (await completions()).single;
    final loggedAt = j.after!.loggedAt;

    now = now.add(const Duration(minutes: 5));
    final m = await r.setMosque(day, Prayer.fajr, true);
    expect((m.after!.inJamaah, m.after!.atMosque, m.after!.loggedAt), (true, true, loggedAt));
    expect((await completions()).single.id, completion.id, reason: 'a mark never re-stamps the completion');

    final same = await r.setMosque(day, Prayer.fajr, true);
    expect(same.changed, isFalse, reason: 'nothing to change');

    await m.undo();
    final back = (await r.logOf(day, Prayer.fajr))!;
    expect((back.inJamaah, back.atMosque, back.loggedAt), (true, false, loggedAt));
    expect((await completions()).single.id, completion.id);

    await j.undo();
    expect(await r.logOf(day, Prayer.fajr), isNull);
    expect(await completions(), isEmpty);
  });

  test('a missed prayer loses its marks; marking it jamaah turns it into prayed', () async {
    final r = repo();
    await r.setJamaah(day, Prayer.isha, true);
    await r.setMosque(day, Prayer.isha, true);
    await r.setStatus(day, Prayer.isha, PrayerStatus.missed);
    final missed = (await r.logOf(day, Prayer.isha))!;
    expect((missed.inJamaah, missed.atMosque), (false, false));
    final c = await r.setJamaah(day, Prayer.isha, true);
    expect((c.status, c.after!.inJamaah), (PrayerStatus.prayed, true));
    expect(await completions(), hasLength(1));
    // Clearing a mark on nothing does nothing.
    expect((await r.setMosque(day, Prayer.maghrib, false)).changed, isFalse);
  });

  test('voluntary prayers toggle on and off with their own completion kind', () async {
    final r = repo();
    final on = await r.toggleVoluntary(day, Prayer.witr);
    expect(on.status, PrayerStatus.prayed);
    expect((await completions()).single.kind, PrayerTrackerRepository.voluntaryKind);
    final off = await r.toggleVoluntary(day, Prayer.witr);
    expect(off.after, isNull);
    expect(await completions(), isEmpty);
    await off.undo();
    expect((await r.logOf(day, Prayer.witr))?.id, on.after!.id);
    expect(await completions(), hasLength(1));
  });

  test('made up (qada): keeps the day it was missed, counts as a completion now, undo restores missed', () async {
    final r = repo();
    final missedDay = DateTime(2026, 9, 20);
    await r.setStatus(missedDay, Prayer.fajr, PrayerStatus.missed);
    final before = await state();
    now = DateTime(2026, 9, 28, 21, 5);
    final c = await r.makeUp(missedDay, Prayer.fajr);
    expect(c.after!.day, '2026-09-20');
    expect(c.status, PrayerStatus.qada);
    expect(c.after!.loggedAt, now);
    final done = (await completions()).single;
    expect((done.at, done.payload['status'], done.payload['day']), (now, 'qada', '2026-09-20'));
    await c.undo();
    expect(await state(), before);
  });

  test('make up several with one undo', () async {
    final r = repo();
    final days = [DateTime(2026, 9, 1), DateTime(2026, 9, 2), DateTime(2026, 9, 3)];
    for (final d in days) {
      await r.setStatus(d, Prayer.isha, PrayerStatus.missed);
    }
    final before = await state();
    final undo = await r.makeUpAll([for (final d in days) (d, Prayer.isha)]);
    final logs = await repos.prayerLogs.getAll();
    expect(logs.map((l) => l.status).toSet(), {PrayerStatus.qada});
    expect(await completions(), hasLength(3));
    await undo();
    expect(await state(), before);
  });

  test('clear() and setStatus on the same status', () async {
    final r = repo();
    expect((await r.clear(day, Prayer.dhuhr)).changed, isFalse);
    final first = await r.setStatus(day, Prayer.dhuhr, PrayerStatus.prayed);
    final firstCompletion = (await completions()).single;
    now = now.add(const Duration(minutes: 1));
    final again = await r.setStatus(day, Prayer.dhuhr, PrayerStatus.prayed);
    expect(again.after!.loggedAt, now, reason: 're-logging re-stamps');
    await again.undo();
    final back = (await r.logOf(day, Prayer.dhuhr))!;
    expect((back.id, back.loggedAt), (first.after!.id, first.after!.loggedAt));
    expect((await completions()).single.id, firstCompletion.id);
  });

  test('completions pulse the Faith world through the orbit hub', () async {
    final hub = OrbitPulseHub(repos, clock: () => now);
    addTearDown(hub.dispose);
    final pulses = <PlanetPulse>[];
    final sub = hub.pulses.listen(pulses.add);
    addTearDown(sub.cancel);
    await repo(hub: hub).cycle(day, Prayer.maghrib);
    await repo(hub: hub).toggleVoluntary(day, Prayer.sunnahMaghrib);
    await pumpEventQueue();
    expect(pulses.map((p) => (p.planetKey, p.kind)), [
      ('faith', PrayerTrackerRepository.obligatoryKind),
      ('faith', PrayerTrackerRepository.voluntaryKind),
    ]);
    // …and the Neglect Radar sees Faith as fresh.
    expect((await repos.activity.watchLastByPlanet().first)['faith'], now);
  });

  test('day and range streams follow every write', () async {
    final r = repo();
    final dayLogs = <List<PrayerLogRow>>[];
    final sub = r.watchDay(day).listen(dayLogs.add);
    addTearDown(sub.cancel);
    final range = r.watchRange(DateTime(2026, 9, 27), day);
    await r.setStatus(DateTime(2026, 9, 27), Prayer.fajr, PrayerStatus.prayed);
    await r.setStatus(day, Prayer.fajr, PrayerStatus.late);
    await r.setStatus(DateTime(2026, 9, 29), Prayer.fajr, PrayerStatus.prayed);
    await pumpEventQueue();
    expect(dayLogs.last.single.status, PrayerStatus.late);
    final inRange = await range.first;
    expect(inRange.map((l) => l.day).toSet(), {'2026-09-27', TrackerDays.key(day)});
    expect(await r.range(DateTime(2026, 9, 29), DateTime(2026, 9, 30)), hasLength(1));
    expect(await r.dayLogs(day), hasLength(1));
    await expectLater(r.watchAll().first.then((l) => l.length), completion(3));
    unawaited(Future<void>.value());
  });
}
