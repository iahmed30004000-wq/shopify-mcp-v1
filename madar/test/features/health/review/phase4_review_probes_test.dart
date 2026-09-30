// Phase 4 review probes: adversarial cases found by the combined review of
// the Health packages – each one failed before its fix and stays as a
// regression test.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/features/health/meds/data/meds_service.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/dose_tracker.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/health/record/domain/lab_flags.dart';
import 'package:madar/features/health/record/domain/lab_series.dart';
import 'package:madar/features/health/wellbeing/domain/worry_window.dart';

void main() {
  group('stock', () {
    late MadarDatabase db;
    late Repositories repos;
    late MedsService service;
    final now = DateTime(2026, 9, 29, 8, 5);

    setUp(() {
      db = MadarDatabase(NativeDatabase.memory());
      repos = Repositories(db);
      service = MedsService(repos, clock: () => now);
    });
    tearDown(() => db.close());

    Future<int?> stockOf(String id) async => (await repos.medications.byId(id))!.stock;

    test('Skip after Taken gives back exactly the units the Taken used (titration step of 2 tablets)', () async {
      final m = await service.saveMed(
        MedDraft(
          name: 'Levo',
          dose: '1 tab',
          doseAmount: 1,
          doseUnit: 'tab',
          slots: const [MedSlot(ClockHm(8, 0))],
          stock: 20,
          titration: [TitrationStep(from: DateTime(2026, 9, 20), dose: '2 tab', doseAmount: 2)],
        ),
      );
      final slot = DateTime(2026, 9, 29, 8);
      await service.apply(MedDoseAction(medId: m.id, slot: slot, kind: MedDoseActionKind.taken, at: now));
      expect(await stockOf(m.id), 18);
      await service.apply(MedDoseAction(medId: m.id, slot: slot, kind: MedDoseActionKind.skipped, at: now));
      expect(await stockOf(m.id), 20, reason: 'the skip must return the 2 tablets the Taken used');
    });

    test('Clear answer after a course dose of 3 ampoules gives the 3 back; undo takes them again', () async {
      final m = await service.saveMed(
        MedDraft(name: 'Inj', dose: '1 amp', doseAmount: 1, doseUnit: 'amp', stock: 30),
      );
      await service.saveCourse(
        CourseDraft(
          name: 'Loading',
          startDate: DateTime(2026, 9, 29),
          medicationId: m.id,
          phases: const [CoursePhase(frequency: CourseFrequency.daily, count: 5, dose: '3 amp', doseAmount: 3)],
        ),
      );
      final scheduler = DoseScheduler(meds: await service.meds(), courses: await service.courses());
      final dose = scheduler.planDay(DateTime(2026, 9, 29)).doses.single;
      expect(dose.doseAmount, 3);
      await service.take(dose);
      expect(await stockOf(m.id), 27);
      final r = await service.reset(dose);
      expect(await stockOf(m.id), 30);
      await r.undo();
      expect(await stockOf(m.id), 27);
    });
  });

  group('labs', () {
    test('a period ending on the 31st starts on the clamped day, not in the next month', () {
      expect(LabPeriod.months3.start(DateTime(2026, 5, 31)), DateTime(2026, 2, 28));
      expect(LabPeriod.months6.start(DateTime(2026, 8, 31)), DateTime(2026, 2, 28));
      expect(LabPeriod.months12.start(DateTime(2028, 2, 29)), DateTime(2027, 2, 28));
      expect(LabPeriod.months3.start(DateTime(2026, 9, 29)), DateTime(2026, 6, 29));
    });

    test('flags at the exact bounds and with one bound missing', () {
      const both = LabRange(low: 10, high: 20);
      expect(LabFlags.classify(10, both), LabFlag.borderlineLow);
      expect(LabFlags.classify(20, both), LabFlag.borderlineHigh);
      expect(LabFlags.classify(9.999, both), LabFlag.low);
      expect(LabFlags.classify(20.001, both), LabFlag.high);
      expect(LabFlags.classify(15, both), LabFlag.inRange);
      const upTo = LabRange(high: 200);
      expect(LabFlags.classify(-5, upTo), LabFlag.inRange);
      expect(LabFlags.classify(195, upTo), LabFlag.borderlineHigh);
      expect(LabFlags.classify(201, upTo), LabFlag.high);
      const atLeast = LabRange(low: 0);
      expect(LabFlags.classify(0, atLeast), LabFlag.inRange);
      expect(LabFlags.classify(-0.1, atLeast), LabFlag.low);
      const point = LabRange(low: 5, high: 5);
      expect(LabFlags.classify(5, point), LabFlag.inRange);
      expect(LabFlags.classify(5.1, point), LabFlag.high);
      expect(LabFlags.classify(double.nan, both), LabFlag.qualitative);
      expect(LabFlags.classify(3, const LabRange()), LabFlag.noRange);
    });
  });

  group('worry window', () {
    test('a window that crosses midnight is still open just after midnight', () {
      const s = WorryWindowSettings(enabled: true, minuteOfDay: 23 * 60 + 50, durationMinutes: 20);
      final status = WorryWindow.statusAt(s, DateTime(2026, 9, 30, 0, 5));
      expect(status.phase, WorryWindowPhase.open);
      expect(status.end, DateTime(2026, 9, 30, 0, 10));
      expect(status.remaining(DateTime(2026, 9, 30, 0, 5)), const Duration(minutes: 5));
      final later = WorryWindow.statusAt(s, DateTime(2026, 9, 30, 0, 10));
      expect(later.phase, WorryWindowPhase.before);
      expect(later.start, DateTime(2026, 9, 30, 23, 50));
    });
  });

  group('importer compatibility', () {
    late MadarDatabase db;

    setUpAll(() async {
      db = MadarDatabase(NativeDatabase.memory());
      final importer = PrototypeImporter(labels: ImportLabels.forLanguage('en'));
      final json = File('test/fixtures/import/prototype_nested_en.json').readAsStringSync();
      final plan = importer.analyze(json, now: DateTime(2026, 9, 6), knownImports: const {});
      await importer.commit(db, plan);
    });
    tearDownAll(() => db.close());

    test('imported medications plan their doses at the imported times', () async {
      final service = MedsService(Repositories(db), clock: () => DateTime(2026, 9, 6, 12));
      final scheduler = DoseScheduler(meds: await service.meds(), courses: await service.courses());
      final plan = scheduler.planDay(DateTime(2026, 9, 6));
      String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      final byMed = <String, List<String>>{};
      for (final d in plan.doses) {
        (byMed[d.med.name] ??= []).add(hm(d.at));
      }
      expect(byMed['Vitamin D'], ['08:00']);
      expect(byMed['Omega 3'], ['08:00', '20:00']);
      expect(byMed['Magnesium'], ['21:00']);
      expect(byMed['Iron'], ['07:30', '13:00']);
      final omega = plan.doses.firstWhere((d) => d.med.name == 'Omega 3');
      expect((omega.dose, omega.doseAmount), ('2 caps', 2.0));
      // The imported dose history is matched to the plan it belongs to.
      final logs = await service.logs(DateTime(2020));
      expect(logs, isNotEmpty);
      final tracked = DoseTracker.trackAll(plan.doses, logs, DateTime(2026, 9, 6, 23), await service.settings());
      expect(tracked, hasLength(6));
    });

    test('imported lab tests chart every reading against their range', () async {
      final repos = Repositories(db);
      final tests = await repos.labTests.getAll();
      final readings = await repos.labReadings.getAll();
      final hba1c = tests.firstWhere((t) => t.name == 'HbA1c');
      final points = LabSeries.points(readings, hba1c);
      expect([for (final p in points) p.value], [5.4, 5.5, 5.3]);
      expect([for (final p in points) p.flag], everyElement(isNot(LabFlag.qualitative)));
      final ferritin = tests.firstWhere((t) => t.name == 'Ferritin');
      final f = LabSeries.points(readings, ferritin);
      expect(f.first.value, 18);
      expect(f.first.flag, LabFlag.low);
    });
  });
}
