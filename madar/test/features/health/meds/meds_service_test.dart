import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/meds/data/meds_service.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late MedsService service;
  var now = DateTime(2026, 9, 29, 8, 5);

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    now = DateTime(2026, 9, 29, 8, 5);
    service = MedsService(repos, clock: () => now);
  });
  tearDown(() => db.close());

  Future<MedSpec> addMed({
    String name = 'Levo',
    List<MedSlot> slots = const [MedSlot(ClockHm(8, 0))],
    int? stock,
    int? refillAt,
    String? unit,
    double? amount,
    String? dose,
    List<TitrationStep> titration = const [],
  }) => service.saveMed(
    MedDraft(
      name: name,
      slots: slots,
      stock: stock,
      refillAt: refillAt,
      doseUnit: unit,
      doseAmount: amount,
      dose: dose,
      titration: titration,
    ),
  );

  PlannedDose doseOf(MedSpec m, {int h = 8, int min = 0, String? dose, double? amount}) {
    final slot = DateTime(2026, 9, 29, h, min);
    return PlannedDose(
      med: m,
      day: DateTime(2026, 9, 29),
      slot: slot,
      baseAt: slot,
      at: slot,
      dose: dose,
      doseAmount: amount,
    );
  }

  group('medications', () {
    test('times are stored as HH:mm, anchors beside them, both read back', () async {
      final m = await addMed(
        slots: const [MedSlot(ClockHm(20, 0)), MedSlot(ClockHm(4, 50), TimeAnchor(AnchorBase.fajr, 20))],
      );
      final row = (await repos.medications.byId(m.id))!;
      expect(row.times, ['04:50', '20:00']);
      expect(await repos.keyValues.getJson(MedsService.anchorsKey), {
        m.id: {'04:50': 'prayer:fajr:+20'},
      });
      expect(m.slots, const [MedSlot(ClockHm(4, 50), TimeAnchor(AnchorBase.fajr, 20)), MedSlot(ClockHm(20, 0))]);

      await service.saveMed(MedDraft.of(m).copyWithSlots(const [MedSlot(ClockHm(9, 0))]));
      expect(await repos.keyValues.getJson(MedsService.anchorsKey), isEmpty);
      expect((await service.med(m.id))!.slots, const [MedSlot(ClockHm(9, 0))]);
    });

    test('delete cascades rules and history, unlinks the course; undo restores everything', () async {
      final a = await addMed(slots: const [MedSlot(ClockHm(7, 0), TimeAnchor(AnchorBase.breakfast, -30))]);
      final b = await addMed(name: 'Calcium');
      await service.saveRule(RuleDraft(kind: MedRuleKind.separate, medAId: a.id, medBId: b.id, minutes: 240));
      final course = await service.saveCourse(
        CourseDraft(name: 'C', startDate: DateTime(2026, 9, 1), medicationId: a.id),
      );
      await service.take(doseOf(a));
      expect((await repos.medications.byId(a.id))!.courseId, course.id);

      final undo = await service.deleteMed(a.id);
      expect(await repos.medications.byId(a.id), isNull);
      expect(await repos.medRules.count(), 0);
      expect(await repos.medDoses.count(), 0);
      expect((await repos.medCourses.byId(course.id))!.medicationId, isNull);
      expect(await repos.keyValues.getJson(MedsService.anchorsKey), isEmpty);

      await undo();
      final back = (await service.med(a.id))!;
      expect(back.slots.single.anchor, const TimeAnchor(AnchorBase.breakfast, -30));
      expect(await repos.medRules.count(), 1);
      expect(await repos.medDoses.count(), 1);
      expect((await repos.medCourses.byId(course.id))!.medicationId, a.id);
    });

    test('pause / resume, duplicate with anchors, reorder', () async {
      final a = await addMed(slots: const [MedSlot(ClockHm(5, 0), TimeAnchor(AnchorBase.fajr))]);
      final b = await addMed(name: 'B');
      final undo = await service.setActive(a.id, false);
      expect((await service.med(a.id))!.active, isFalse);
      await undo();
      expect((await service.med(a.id))!.active, isTrue);

      final (copy, undoCopy) = await service.duplicateMed(a.id, name: 'A2');
      expect(copy.name, 'A2');
      expect(copy.slots.single.anchor, const TimeAnchor(AnchorBase.fajr));
      expect([for (final m in await service.meds()) m.id], [a.id, copy.id, b.id]);
      await undoCopy();
      expect(await repos.medications.count(), 2);

      await service.reorderMeds([b.id, a.id]);
      expect([for (final m in await service.meds()) m.id], [b.id, a.id]);
    });
  });

  group('doses', () {
    test('Taken: one row for the slot, stock down by the dose units, activity logged; repeat is a no-op', () async {
      final m = await addMed(stock: 20, refillAt: 5, unit: 'caps', amount: 2);
      final r = await service.take(doseOf(m, amount: 2));
      expect(r.changed, isTrue);
      expect(r.stockAfter, 18);
      final rows = await repos.medDoses.getAll();
      expect(rows.single.status, DoseStatus.taken);
      expect(rows.single.scheduledAt, DateTime(2026, 9, 29, 8, 0));
      expect(rows.single.takenAt, now);
      expect((await repos.medications.byId(m.id))!.stock, 18);
      final act = await repos.activity.since(DateTime(2026, 9, 1), planetKey: 'health');
      expect(act.single.kind, 'health.dose');
      expect(act.single.refTable, 'med_doses');
      expect(act.single.refId, rows.single.id);

      final again = await service.take(doseOf(m, amount: 2));
      expect(again.changed, isFalse);
      expect((await repos.medications.byId(m.id))!.stock, 18);

      await r.undo();
      expect(await repos.medDoses.count(), 0);
      expect((await repos.medications.byId(m.id))!.stock, 20);
      expect(await repos.activity.since(DateTime(2026, 9, 1)), isEmpty);
    });

    test('Snooze then Taken keeps one row; undoing Taken brings the snooze back', () async {
      final m = await addMed();
      final s = await service.snooze(doseOf(m), const Duration(minutes: 30));
      expect(s.changed, isTrue);
      var row = (await repos.medDoses.getAll()).single;
      expect(row.status, DoseStatus.snoozed);
      expect(row.takenAt, DateTime(2026, 9, 29, 8, 35));

      now = DateTime(2026, 9, 29, 8, 40);
      final t = await service.take(doseOf(m));
      row = (await repos.medDoses.getAll()).single;
      expect(row.status, DoseStatus.taken);
      expect(row.takenAt, now);
      await t.undo();
      row = (await repos.medDoses.getAll()).single;
      expect(row.status, DoseStatus.snoozed);
      expect(row.takenAt, DateTime(2026, 9, 29, 8, 35));
    });

    test('Skip after Taken gives the stock back; undo takes it again', () async {
      final m = await addMed(stock: 10);
      await service.take(doseOf(m));
      expect((await repos.medications.byId(m.id))!.stock, 9);
      final s = await service.skip(doseOf(m));
      expect((await repos.medDoses.getAll()).single.status, DoseStatus.skipped);
      expect((await repos.medications.byId(m.id))!.stock, 10);
      expect(await repos.activity.since(DateTime(2026, 9, 1)), isEmpty);
      await s.undo();
      expect((await repos.medDoses.getAll()).single.status, DoseStatus.taken);
      expect((await repos.medications.byId(m.id))!.stock, 9);
      expect(await repos.activity.since(DateTime(2026, 9, 1)), hasLength(1));
      // Snooze on an answered dose does nothing.
      expect((await service.snooze(doseOf(m), const Duration(minutes: 10))).changed, isFalse);
    });

    test('reset clears an answer; undo restores it', () async {
      final m = await addMed(stock: 3);
      await service.take(doseOf(m));
      final r = await service.reset(doseOf(m));
      expect(await repos.medDoses.count(), 0);
      expect((await repos.medications.byId(m.id))!.stock, 3);
      await r.undo();
      expect(await repos.medDoses.count(), 1);
      expect((await repos.medications.byId(m.id))!.stock, 2);
    });

    test('refill threshold crossing is reported once', () async {
      final m = await addMed(stock: 6, refillAt: 5);
      expect((await service.take(doseOf(m))).refillCrossed, isTrue);
      expect((await service.take(doseOf(m, h: 20))).refillCrossed, isFalse);
    });

    test('a dose logged by hand has no slot; undo removes it', () async {
      final m = await addMed(stock: 4, slots: const []);
      final r = await service.logNow(m.id);
      final row = (await repos.medDoses.getAll()).single;
      expect(row.scheduledAt, isNull);
      expect(row.takenAt, now);
      expect((await repos.medications.byId(m.id))!.stock, 3);
      await r.undo();
      expect(await repos.medDoses.count(), 0);
      expect((await repos.medications.byId(m.id))!.stock, 4);
    });

    test('an answer from a notification finds the day’s dose text (titration)', () async {
      final m = await addMed(
        dose: '2.5 mg',
        titration: [TitrationStep(from: DateTime(2026, 9, 20), dose: '5 mg')],
      );
      final r = await service.apply(
        MedDoseAction(medId: m.id, slot: DateTime(2026, 9, 29, 8), kind: MedDoseActionKind.taken, at: now),
      );
      expect(r.changed, isTrue);
      expect((await repos.medDoses.getAll()).single.dose, '5 mg');
      final z = await service.apply(
        MedDoseAction(
          medId: m.id,
          slot: DateTime(2026, 9, 29, 20),
          kind: MedDoseActionKind.snoozed,
          at: now,
          snooze: const Duration(minutes: 60),
        ),
      );
      expect(z.changed, isTrue);
      final snoozed = (await repos.medDoses.getAll()).firstWhere((d) => d.status == DoseStatus.snoozed);
      expect(snoozed.takenAt, now.add(const Duration(minutes: 60)));
      final action = MedDoseAction.fromJson(
        MedDoseAction(medId: 'x', slot: DateTime(2026, 9, 29, 8), kind: MedDoseActionKind.skipped, at: now).toJson(),
      )!;
      expect(action.kind, MedDoseActionKind.skipped);
      expect(action.slot, DateTime(2026, 9, 29, 8));
    });
  });

  group('courses and rules', () {
    test('saving a course links its medication both ways; deleting unlinks; undo relinks', () async {
      final a = await addMed(name: 'Inj', slots: const []);
      final c = await service.saveCourse(
        CourseDraft(
          name: 'Loading',
          startDate: DateTime(2026, 10, 1),
          medicationId: a.id,
          phases: const [CoursePhase(frequency: CourseFrequency.daily, count: 10, dose: '1 amp')],
        ),
      );
      expect(c.phases.single.count, 10);
      expect((await service.med(a.id))!.courseId, c.id);
      final undo = await service.deleteCourse(c.id);
      expect((await service.med(a.id))!.courseId, isNull);
      await undo();
      expect((await service.med(a.id))!.courseId, c.id);
      expect((await service.courses()).single.phases.single.dose, '1 amp');
    });

    test('rules save, update and delete with undo', () async {
      final a = await addMed();
      final b = await addMed(name: 'B');
      final r = await service.saveRule(RuleDraft(kind: MedRuleKind.separate, medAId: a.id, medBId: b.id, minutes: 120));
      await service.saveRule(RuleDraft.of(r).copyWithMinutes(90));
      expect((await service.rules()).single.minutes, 90);
      final food = await service.saveRule(
        RuleDraft(kind: MedRuleKind.beforeFood, medAId: a.id, medBId: b.id, minutes: 30),
      );
      expect(food.medBId, isNull);
      final undo = await service.deleteRule(r.id);
      expect(await repos.medRules.count(), 1);
      await undo();
      expect(await repos.medRules.count(), 2);
    });
  });

  test('settings round-trip through key_values', () async {
    final s = await service.settings();
    expect(s.notify, isTrue);
    await service.saveSettings(s.copyWith(snoozeMinutes: 30));
    expect((await service.settings()).snoozeMinutes, 30);
  });
}

extension on MedDraft {
  MedDraft copyWithSlots(List<MedSlot> slots) => MedDraft(
    id: id,
    name: name,
    kind: kind,
    dose: dose,
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    slots: slots,
    takenWith: takenWith,
    notes: notes,
    active: active,
    stock: stock,
    refillAt: refillAt,
    color: color,
    titration: titration,
    courseId: courseId,
  );
}

extension on RuleDraft {
  RuleDraft copyWithMinutes(int m) => RuleDraft(id: id, kind: kind, medAId: medAId, medBId: medBId, minutes: m, note: note);
}
