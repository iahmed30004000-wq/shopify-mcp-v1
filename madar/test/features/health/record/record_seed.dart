// Test-only sample medical record (a fresh install starts empty – this is
// fixture data for tests and screenshots).
import 'package:drift/drift.dart' show Value;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/record/data/record_service.dart';
import 'package:madar/features/health/record/domain/lab_series.dart';

/// Tuesday 29 Sep 2026, 10:00.
final DateTime recordTestNow = DateTime(2026, 9, 29, 10);

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Seeds alerts, conditions, labs (three categories + an uncategorised
/// qualitative test), appointments, questions, medications, pain and mood.
Future<void> seedRecord(MadarDatabase db, {bool arabic = true, DateTime? now}) async {
  final t = now ?? recordTestNow;
  final s = RecordService(Repositories(db), clock: () => t);
  String tr(String ar, String en) => arabic ? ar : en;

  await s.addAlert(body: tr('ممنوع الكورتيزون بكل أشكاله', 'No cortisone in any form'));
  await s.addAlert(body: tr('حساسية من البنسلين', 'Allergic to penicillin'), severity: Severity.warning);
  await s.addAlert(body: tr('فصيلة الدم O+', 'Blood type O+'), severity: Severity.info);

  await s.addCondition(
    name: tr('قصور الغدة الدرقية', 'Hypothyroidism'),
    notes: tr('متابعة كل ستة أشهر', 'Follow-up every six months'),
    since: _d(2021, 3, 1),
  );
  await s.addCondition(name: tr('نقص فيتامين د', 'Vitamin D deficiency'), since: _d(2025, 3, 10));
  await s.addCondition(name: tr('التهاب الجيوب الأنفية', 'Sinusitis'), since: _d(2024, 1, 5), active: false);

  Future<String> test(
    String name, {
    String? unit,
    double? low,
    double? high,
    String? category,
    required List<(DateTime, Object)> values,
  }) async {
    final (row, _) = await s.addTest(name: name, unit: unit, low: low, high: high, category: category);
    for (final (date, v) in values) {
      await s.addReading(
        testId: row.id,
        date: date,
        input: v is num ? LabValueInput.parse('$v') : LabValueInput.parse(v as String),
      );
    }
    return row.id;
  }

  final thyroid = tr('الغدة الدرقية', 'Thyroid');
  final vitamins = tr('الفيتامينات', 'Vitamins');
  final blood = tr('الدم', 'Blood');
  await test(
    'TSH',
    unit: 'mIU/L',
    low: 0.4,
    high: 4.0,
    category: thyroid,
    values: [
      (_d(2025, 10, 4), 5.2),
      (_d(2026, 1, 10), 3.9),
      (_d(2026, 4, 2), 2.1),
      (_d(2026, 7, 1), 1.8),
      (_d(2026, 9, 12), 3.85),
    ],
  );
  await test(
    'FT4',
    unit: 'ng/dL',
    low: 0.8,
    high: 1.8,
    category: thyroid,
    values: [(_d(2026, 4, 2), 1.1), (_d(2026, 9, 12), 1.3)],
  );
  await test(
    tr('فيتامين د', 'Vitamin D'),
    unit: 'ng/mL',
    low: 30,
    high: 100,
    category: vitamins,
    values: [
      (_d(2025, 11, 20), 14),
      (_d(2026, 2, 1), 22),
      (_d(2026, 4, 28), 31),
      (_d(2026, 6, 30), 29),
      (_d(2026, 9, 12), 48),
    ],
  );
  await test('B12', unit: 'pg/mL', low: 200, high: 900, category: vitamins, values: [(_d(2026, 9, 12), 420)]);
  await test(
    tr('الهيموغلوبين', 'Hemoglobin'),
    unit: 'g/dL',
    low: 12,
    high: 16,
    category: blood,
    values: [(_d(2026, 1, 10), 12.9), (_d(2026, 5, 15), 13.4), (_d(2026, 9, 12), 12.3)],
  );
  await test(
    tr('الفيريتين', 'Ferritin'),
    unit: 'ng/mL',
    low: 15,
    high: 150,
    category: blood,
    values: [(_d(2026, 5, 15), 18), (_d(2026, 9, 12), 12)],
  );
  await test(
    'LDL',
    unit: 'mg/dL',
    high: 130,
    category: blood,
    values: [(_d(2026, 1, 10), 142), (_d(2026, 9, 12), 128)],
  );
  await test(tr('تحليل البول', 'Urinalysis'), values: [(_d(2026, 9, 12), tr('سلبي', 'Negative'))]);

  final (endo, _) = await s.addAppointment(
    title: tr('مراجعة الغدد الصماء', 'Endocrinology follow-up'),
    doctor: tr('د. سلمى الخطيب', 'Dr. Salma Khatib'),
    place: tr('المستشفى التخصصي', 'Specialty Hospital'),
    at: DateTime(2026, 10, 6, 10, 30),
  );
  await s.addAppointment(
    title: tr('تحاليل دورية', 'Routine labs'),
    place: tr('مختبرات المدينة', 'City Labs'),
    at: DateTime(2026, 10, 20, 8),
  );
  final (family, _) = await s.addAppointment(
    title: tr('طبيب العائلة', 'Family doctor'),
    doctor: tr('د. عمر حداد', 'Dr. Omar Haddad'),
    at: DateTime(2026, 8, 15, 17),
  );
  await s.setAppointmentDone(family.id, true);

  await s.addQuestion(
    question: tr(
      'هل أغيّر موعد حبة الغدة بسبب القهوة الصباحية؟',
      'Should I move my thyroid pill because of morning coffee?',
    ),
    appointmentId: endo.id,
  );
  await s.addQuestion(
    question: tr('متى أعيد تحليل فيتامين د؟', 'When should I repeat the vitamin D test?'),
    appointmentId: endo.id,
  );
  await s.addQuestion(question: tr('هل أحتاج إلى فحص كثافة العظام؟', 'Do I need a bone density scan?'));
  final (answered, _) = await s.addQuestion(
    question: tr('هل يمكن أخذ المكمّلات معًا؟', 'Can I take the supplements together?'),
  );
  await s.setAnswered(
    answered.id,
    true,
    answer: tr('نعم، بفصل ساعتين عن دواء الغدة', 'Yes, two hours apart from the thyroid pill'),
  );

  await db
      .into(db.medications)
      .insert(
        MedicationsCompanion.insert(
          name: tr('ليفوثيروكسين', 'Levothyroxine'),
          dose: const Value('50 mcg'),
          times: const Value(['06:30']),
          takenWith: const Value(TakenWith.emptyStomach),
        ),
      );
  await db
      .into(db.medications)
      .insert(
        MedicationsCompanion.insert(
          name: tr('فيتامين د٣', 'Vitamin D3'),
          kind: const Value(MedKind.supplement),
          doseAmount: const Value(5000),
          doseUnit: const Value('IU'),
          times: const Value(['14:00']),
          takenWith: const Value(TakenWith.lunch),
        ),
      );
  await db
      .into(db.medications)
      .insert(
        MedicationsCompanion.insert(
          name: 'Omega 3',
          kind: const Value(MedKind.supplement),
          dose: Value(tr('كبسولة', '1 capsule')),
          times: const Value(['08:00', '20:00']),
          takenWith: const Value(TakenWith.breakfast),
        ),
      );

  final back = tr('أسفل الظهر', 'Lower back');
  final knee = tr('الركبة اليمنى', 'Right knee');
  final sitting = tr('الجلوس الطويل', 'Long sitting');
  for (final (days, score, where) in [(2, 4, back), (5, 6, back), (9, 3, knee), (14, 5, back), (20, 2, knee)]) {
    await db
        .into(db.painEntries)
        .insert(
          PainEntriesCompanion.insert(
            at: t.subtract(Duration(days: days)),
            score: score,
            locations: Value([where]),
            triggers: Value([sitting]),
          ),
        );
  }
  final work = tr('العمل', 'Work');
  final sleep = tr('قلة النوم', 'Short sleep');
  for (final (days, mood, stress, hours) in [(1, 4, 4, 7.5), (3, 3, 6, 6.0), (6, 2, 7, 5.5), (10, 4, 3, 8.0)]) {
    await db
        .into(db.moodEntries)
        .insert(
          MoodEntriesCompanion.insert(
            at: t.subtract(Duration(days: days)),
            mood: Value(mood),
            stress: Value(stress),
            anxiety: Value(stress - 1),
            energy: Value(10 - stress),
            sleepHours: Value(hours),
            caffeineCups: const Value(2),
            factors: Value([work, if (hours < 6.5) sleep]),
          ),
        );
  }
}
