// The Health world's balance and the Neglect Radar, end to end from the
// health packages' own services (not hand-written rows), with the orbit
// reading doses the way the app wires it (the medication tracker's plan,
// `trackerDoseSlots`): medications saved by the tracker and answered
// through it (taken, snoozed, skipped) become "2 doses past due" →
// "Vitamin D — 1 dose past due" → nothing; an injection course is only
// "past due" on its own dose days; wellbeing check-ins, pain logs and a
// stress habit, and an appointment marked done, all feed the Health score.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/hub/health_dose_slots.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/neglect_text.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/score_sources.dart';

const _fsi = '\u2068', _pdi = '\u2069';
String _iso(String s) => '$_fsi$s$_pdi';

void main() {
  var now = DateTime(2026, 9, 29, 13, 10);
  final today = DateTime(2026, 9, 29);
  DateTime at(int h, int m) => DateTime(2026, 9, 29, h, m);
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  const arFmt = MadarFormatter();
  const enFmt = MadarFormatter(languageCode: 'en');

  late MadarDatabase db;
  late Repositories repos;
  late MedsService meds;
  late OrbitRepository orbit;

  setUp(() async {
    now = DateTime(2026, 9, 29, 13, 10);
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    meds = MedsService(repos, clock: () => now);
    orbit = OrbitRepository(repos, clock: () => now, doseSlots: trackerDoseSlots(repos));
  });
  tearDown(() => db.close());

  /// Saved through the tracker, then back-dated to last week (a new row's
  /// `createdAt` is the real clock's).
  Future<String> med(String name, List<MedSlot> slots) async {
    final id = (await meds.saveMed(MedDraft(name: name, dose: '1', slots: slots))).id;
    await repos.medications.update(
      MedicationsCompanion(id: Value(id), createdAt: Value(today.subtract(const Duration(days: 7)))),
    );
    return id;
  }

  /// Answers every dose of the two days before today (only today's count as
  /// "past due").
  Future<void> answerEarlierDays(String id, List<(int, int)> times) async {
    for (var d = 1; d <= 2; d++) {
      for (final (h, m) in times) {
        await meds.takeSlot(id, DateTime(2026, 9, 29 - d, h, m));
      }
    }
  }

  Future<List<NeglectReason>> healthReasons() async => (await orbit.snapshot()).planet('health')!.score.reasons;

  Future<NeglectReason?> doses() async =>
      (await healthReasons()).where((r) => r.code == ReasonCode.dosesPastDue).firstOrNull;

  test('doses answered in the tracker move the reason: 2 past due → one, named → none', () async {
    final metformin = await med('Metformin', const [MedSlot(ClockHm(8, 0))]);
    final vitD = await med('Vitamin D', const [MedSlot(ClockHm(9, 0))]);
    await answerEarlierDays(metformin, [(8, 0)]);
    await answerEarlierDays(vitD, [(9, 0)]);

    var r = await doses();
    expect(r, isNotNull);
    expect(neglectReasonText(en, r!, enFmt), '2 doses past due');
    expect(neglectReasonText(ar, r, arFmt), 'جرعتان فائتتان');
    expect(r.refTable, 'medications');
    expect(r.refId, isNull, reason: 'two medications: the reason opens today\'s doses');

    // Taken (late) in the tracker.
    await meds.takeSlot(metformin, at(8, 0), at: at(12, 40));
    r = await doses();
    expect(neglectReasonText(en, r!, enFmt), '${_iso('Vitamin D')} — 1 dose past due');
    expect(r.refId, vitD);

    // A snooze asks for a little time: not past due while it runs …
    await meds.snoozeSlot(vitD, at(9, 0), const Duration(minutes: 30), from: at(13, 5));
    expect(await doses(), isNull);
    // … and past due again once it has run out (and its grace with it).
    now = at(14, 10);
    expect((await doses())?.refId, vitD);

    // Skipped is an answer.
    await meds.skipSlot(vitD, at(9, 0));
    expect(await doses(), isNull);
    final health = (await orbit.snapshot()).planet('health')!.score;
    expect(health.sources[ScoreSources.doses], closeTo(1, 1e-9));
  });

  test('an injection course is past due only on its own dose days', () async {
    final b12 = await med('B12', const [MedSlot(ClockHm(10, 0))]);
    // Daily ×10 from 1 Aug, weekly ×4 (every Tuesday from 11 Aug to 1 Sep),
    // then monthly on the 8th: nothing falls on 27–29 Sep.
    await meds.saveCourse(
      CourseDraft(
        name: 'B12',
        startDate: DateTime(2026, 8, 1),
        medicationId: b12,
        phases: const [
          CoursePhase(frequency: CourseFrequency.daily, count: 10),
          CoursePhase(frequency: CourseFrequency.weekly, count: 4),
          CoursePhase(frequency: CourseFrequency.monthly),
        ],
      ),
    );
    expect(await doses(), isNull);
    final health = (await orbit.snapshot()).planet('health')!.score;
    expect(health.sources.containsKey(ScoreSources.doses), isFalse, reason: 'no dose was due');

    // The same course started a week ago is in its daily phase: today's
    // 10:00 injection not recorded is past due.
    final c = (await meds.courses()).single;
    await meds.saveCourse(
      CourseDraft(id: c.id, name: 'B12', startDate: DateTime(2026, 9, 25), medicationId: b12, phases: c.phases),
    );
    final r = await doses();
    expect(r?.refId, b12);
    expect(neglectReasonText(en, r!, enFmt), '${_iso('B12')} — 1 dose past due');
  });

  test('a paused medication and an as-needed one are never past due', () async {
    final paused = await med('Iron', const [MedSlot(ClockHm(8, 0))]);
    await meds.setActive(paused, false);
    await med('Paracetamol', const []);
    expect(await doses(), isNull);
  });

  test('a dose logged by the notification action (MedDoseAction) counts the same', () async {
    final id = await med('Levothyroxine', const [MedSlot(ClockHm(6, 0))]);
    await answerEarlierDays(id, [(6, 0)]);
    expect((await doses())?.args['count'], 1);
    await meds.apply(MedDoseAction(medId: id, slot: at(6, 0), kind: MedDoseActionKind.taken, at: at(6, 20)));
    expect(await doses(), isNull);
  });

  test('wellbeing, pain, stress habits and appointments feed the Health sources', () async {
    final wellbeing = WellbeingService(repos, clock: () => now);
    await wellbeing.logMood(MoodDraft(at: at(9, 0), mood: 4, stress: 3));
    await wellbeing.logPain(PainDraft(at: at(10, 0), score: 3));
    final habit = (await wellbeing.addHabit('Walk'))!;
    for (var d = 0; d < 5; d++) {
      await wellbeing.setHabitDone(habit.id, today.subtract(Duration(days: d)), true);
    }
    final record = RecordService(repos, clock: () => now);
    final (appt, _) = await record.addAppointment(title: 'Check-up', at: at(9, 30).subtract(const Duration(days: 2)));
    await record.setAppointmentDone(appt.id, true);

    final health = (await orbit.snapshot()).planet('health')!.score;
    expect(health.dormant, isFalse);
    expect(health.sources.keys, containsAll([ScoreSources.mood, ScoreSources.pain, ScoreSources.appointments]));
    expect(health.sources[ScoreSources.appointments], 1);
    // Completions are logged on the Health world.
    final activity = await repos.activity.since(today, planetKey: 'health');
    expect(activity.map((a) => a.kind), containsAll(['health.mood', 'health.pain', 'appointment.done']));
  });
}
