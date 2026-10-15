import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/wird/wird.dart';

import '../../helpers/test_app.dart';
import 'fake_quran_catalog.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  var now = DateTime(2026, 9, 28, 17, 10);
  late WirdService service;
  final pages = QuranAxis.of(FakeQuranCatalog(), WirdUnit.pages);

  setUp(() async {
    db = testDatabase(seed: false);
    await db.customSelect('SELECT 1').get();
    repos = Repositories(db);
    now = DateTime(2026, 9, 28, 17, 10);
    service = WirdService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  WirdDraft draft({String name = 'Plan', WirdTemplate template = WirdTemplate.pages, int days = 30}) => WirdDraft(
    name: name,
    template: template,
    amount: 2,
    khatmaDays: days,
    startDate: DateTime(2026, 9, 20),
    window: PrayerWindow.asr,
    catchUp: WirdCatchUp.allAtOnce,
    remindOffsetMin: 20,
  );

  Future<WirdPlanState> stateOf(WirdPlan plan) async {
    final p = (await service.plans()).firstWhere((x) => x.id == plan.id);
    final sessions = [for (final r in await repos.quranSessions.getAll()) WirdSession.fromRow(r)];
    return WirdEngine.compute(plan: p, sessions: sessions, axis: QuranAxis.of(FakeQuranCatalog(), p.unit), today: now);
  }

  test('create: the first plan is primary; a khatma stores its pace and target date', () async {
    final (a, undoA) = await service.create(draft(name: 'A'));
    final (b, _) = await service.create(draft(name: 'B', template: WirdTemplate.khatma), pagesAxis: pages);
    expect(await repos.keyValues.getJson(WirdService.primaryKey), a.id);
    final plans = await service.plans();
    expect(plans.map((p) => p.name), ['A', 'B']);
    expect(plans.first.meta.catchUp, WirdCatchUp.allAtOnce);
    expect(plans.first.meta.remindOffsetMin, 20);
    final khatma = plans.last;
    expect(khatma.targetDate, DateTime(2026, 10, 19));
    expect(khatma.amountPerDay, closeTo(604 / 30, 1e-9));
    expect(khatma.template, WirdTemplate.khatma);
    expect(b.isKhatma, isTrue);
    expect(WirdService.primaryOf(plans, null)!.id, a.id);
    await undoA();
    expect((await service.plans()).map((p) => p.name), ['B']);
    expect(await repos.keyValues.getJson(WirdService.primaryKey), isNull);
  });

  test('update keeps the id and history; undo restores row and settings', () async {
    final (plan, _) = await service.create(draft(name: 'Before'));
    final undo = await service.update(
      plan,
      WirdDraft.of(plan).copyWith(name: 'After', amount: 4, catchUp: WirdCatchUp.spread, window: PrayerWindow.isha),
    );
    var p = (await service.plans()).single;
    expect([p.id, p.name, p.amountPerDay, p.window, p.meta.catchUp], [plan.id, 'After', 4.0, PrayerWindow.isha, WirdCatchUp.spread]);
    await undo();
    p = (await service.plans()).single;
    expect([p.name, p.amountPerDay, p.window, p.meta.catchUp], ['Before', 2.0, PrayerWindow.asr, WirdCatchUp.allAtOnce]);
  });

  test('pause and resume: paused days owe nothing and a khatma moves its target date', () async {
    final (plan, _) = await service.create(draft(template: WirdTemplate.khatma), pagesAxis: pages);
    now = DateTime(2026, 9, 24, 9);
    await service.pause(plan);
    var p = (await service.plans()).single;
    expect(p.active, isFalse);
    expect(p.meta.openPause, WirdPause(DateTime(2026, 9, 24)));
    now = DateTime(2026, 9, 29, 9);
    final undo = await service.resume(p);
    p = (await service.plans()).single;
    expect(p.active, isTrue);
    expect(p.meta.pauses, [WirdPause(DateTime(2026, 9, 24), DateTime(2026, 9, 28))]);
    // Paused for five days: 19 Oct → 24 Oct.
    expect(p.targetDate, DateTime(2026, 10, 24));
    final s = await stateOf(p);
    expect(s.days.where((d) => d.status == WirdDayStatus.paused).length, 5);
    await undo();
    p = (await service.plans()).single;
    expect(p.active, isFalse);
    expect(p.targetDate, DateTime(2026, 10, 19));
  });

  test('primary: set and undo; deleting the primary plan falls back', () async {
    final (a, _) = await service.create(draft(name: 'A'));
    final (b, _) = await service.create(draft(name: 'B'));
    final undo = await service.setPrimary(b.id);
    expect(await repos.keyValues.getJson(WirdService.primaryKey), b.id);
    await undo();
    expect(await repos.keyValues.getJson(WirdService.primaryKey), a.id);
    final undoDelete = await service.delete(a);
    final plans = await service.plans();
    expect(plans.map((p) => p.id), [b.id]);
    expect(WirdService.primaryOf(plans, await repos.keyValues.getJson(WirdService.primaryKey) as String?)!.id, b.id);
    await undoDelete();
    expect((await service.plans()).length, 2);
    expect(await repos.keyValues.getJson(WirdService.primaryKey), a.id);
  });

  test('mark done logs a tagged session, and quran.wird once; undo removes both', () async {
    final (plan, _) = await service.create(draft());
    // Behind since 20 Sep, all at once: today's portion is pages 1–18.
    var s = await stateOf(plan);
    expect(s.target.range!.first, const AyahRef(1, 1));
    final undo = await service.markDone(s, pagesAxis: pages);
    expect(undo, isNotNull);
    final session = (await repos.quranSessions.getAll()).single;
    expect(session.planId, plan.id);
    expect(session.mode, QuranSessionMode.read);
    expect(session.day, DateTime(2026, 9, 28));
    expect(session.ayahCount, greaterThan(100));
    expect(session.pages, closeTo(18, 1e-3));
    s = await stateOf(plan);
    expect(s.target.met, isTrue);
    expect(await service.syncCompletion(s), isTrue);
    expect(await service.syncCompletion(s), isFalse);
    final logged = await repos.activity.since(DateTime(2026, 9, 28), kind: WirdActivity.kind);
    expect(logged.single.refId, WirdActivity.refIdFor(plan.id, DateTime(2026, 9, 28)));
    expect(logged.single.planetKey, 'faith');
    await undo!();
    expect(await repos.quranSessions.getAll(), isEmpty);
    expect(await repos.activity.since(DateTime(2026, 9, 28), kind: WirdActivity.kind), isEmpty);
  });

  test('"I stopped at…" records a partial session; completion is removed when no longer met', () async {
    final (plan, _) = await service.create(draft());
    var s = await stateOf(plan);
    final undo = await service.readUntil(s, const AyahRef(2, 25), pagesAxis: pages);
    s = await stateOf(plan);
    expect(s.target.met, isFalse);
    expect(s.target.resumeAt, const AyahRef(2, 26));
    expect(await service.syncCompletion(s), isFalse);
    await undo!();
    // Met, logged, then the reading is deleted elsewhere: the entry goes.
    await service.markDone(await stateOf(plan));
    await service.syncCompletion(await stateOf(plan));
    await repos.quranSessions.deleteWhere((t) => t.planId.equals(plan.id));
    await service.syncCompletion(await stateOf(plan));
    expect(await repos.activity.since(DateTime(2026, 9, 28), kind: WirdActivity.kind), isEmpty);
  });
}
