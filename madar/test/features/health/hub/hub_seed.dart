// Example data for the Health hub's tests and screenshots only (a fresh
// install starts empty): the medications scenario (a day at 13:10 with
// doses taken, skipped, due and late), two standing alerts, an appointment
// in a week with its questions, a general question, three lab tests (one
// low, one borderline, one in range) and sixty days of wellbeing.
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

import '../../orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;
import '../meds/meds_harness.dart' show seedMedsScenario;
import '../wellbeing/wellbeing_seed.dart';

/// Tuesday 29 Sep 2026, 13:10 (the medications scenario's "now").
final DateTime hubTestNow = DateTime(2026, 9, 29, 13, 10);

class HubSeed {
  const HubSeed({this.meds = true, this.record = true, this.wellbeing = WellbeingSeed.full});

  static const lived = HubSeed();
  static const lowMood = HubSeed(wellbeing: WellbeingSeed.lowMoodWeek);

  final bool meds;
  final bool record;
  final WellbeingSeed? wellbeing;
}

Future<void> seedHealthHub(MadarDatabase db, {String lang = 'ar', DateTime? now, HubSeed seed = HubSeed.lived}) async {
  final n = now ?? hubTestNow;
  final ar = lang == 'ar';
  String tr(String a, String e) => ar ? a : e;
  final repos = Repositories(db);
  await OrbitRepository(repos).setPrayerSettings(hostPrayerSettings());
  if (seed.meds) await seedMedsScenario(db, lang: lang, now: n);
  if (seed.record) {
    final s = RecordService(repos, clock: () => n);
    await s.addAlert(body: tr('ممنوع الكورتيزون بكل أشكاله', 'No cortisone in any form'));
    final day = DateTime(n.year, n.month, n.day);
    final (appt, _) = await s.addAppointment(
      title: tr('مراجعة الغدد الصماء', 'Endocrinology follow-up'),
      at: day.add(const Duration(days: 7, hours: 10, minutes: 30)),
      doctor: tr('د. سلمى الخطيب', 'Dr. Salma Khatib'),
      place: tr('عيادات الأردن', 'Jordan Clinics'),
    );
    await s.addQuestion(
      question: tr('هل أغيّر موعد حبّة الغدة؟', 'Should the thyroid pill move?'),
      appointmentId: appt.id,
    );
    await s.addQuestion(
      question: tr('متى أعيد تحليل فيتامين د؟', 'When do I repeat the vitamin D test?'),
      appointmentId: appt.id,
    );
    await s.addQuestion(question: tr('هل أحتاج إلى فحص كثافة العظام؟', 'Do I need a bone density scan?'));

    Future<void> lab(String name, String unit, double low, double high, List<(int, double)> values) async {
      final (t, _) = await s.addTest(name: name, unit: unit, low: low, high: high);
      for (final (monthsAgo, v) in values) {
        await s.addReading(
          testId: t.id,
          date: DateTime(n.year, n.month - monthsAgo, 12),
          input: LabValueInput.parse(v.toString()),
        );
      }
    }

    await lab(tr('الفيريتين', 'Ferritin'), 'ng/mL', 15, 150, [(9, 22), (5, 16), (1, 12)]);
    await lab('TSH', 'mIU/L', 0.4, 4.0, [(9, 2.1), (5, 3.2), (1, 3.85)]);
    await lab(tr('فيتامين د', 'Vitamin D'), 'ng/mL', 30, 100, [(9, 18), (5, 27), (1, 41)]);
    // A resolved question stays out of the hub.
    final (done, _) = await s.addQuestion(question: tr('هل أستمر على الحديد؟', 'Do I keep taking iron?'));
    await s.setAnswered(done.id, true);
  }
  final wb = seed.wellbeing;
  if (wb != null) await seedWellbeing(db, wb, now: n);
}
