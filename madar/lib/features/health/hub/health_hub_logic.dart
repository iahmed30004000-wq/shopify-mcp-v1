import '../../../core/db/database.dart';
import '../../../core/routing/routes.dart';
import '../record/data/record_providers.dart' show LabTestView;

/// The Health hub's small decisions (pure – unit-tested).
abstract final class HealthHubLogic {
  /// The questions still waiting for the doctor, in the user's order.
  static List<DoctorQuestionRow> openQuestions(List<DoctorQuestionRow> all) => [
    for (final q in all)
      if (!q.answered) q,
  ];

  /// Whether any lab test has a reading (the flags card shows then).
  static bool hasReadings(List<LabTestView> views) => views.any((v) => v.points.isNotEmpty);

  /// Today's pain entries: how many, and the highest score (null when none).
  static ({int count, int highest})? painToday(List<PainEntryRow> today) {
    if (today.isEmpty) return null;
    var highest = 0;
    for (final e in today) {
      if (e.score > highest) highest = e.score;
    }
    return (count: today.length, highest: highest.clamp(0, 10));
  }
}

/// Where a Health record a Neglect Radar entry or a planet reason points at
/// opens (pure): the records with no sheet of their own become their
/// screens, as routes.
///
/// * `medications` (a dose past due – one medication or several): today's
///   doses, where it is answered;
/// * `med_doses`: likewise;
/// * `habits` of the Health world (the stress-habit checklist): wellbeing's
///   habits;
/// * `appointments`: the appointments, that one lit;
/// * `lab_tests`: that test's readings and trend;
/// * `mood_entries` / `pain_entries`: wellbeing (today / pain).
///
/// Null for every other table (another world's record).
abstract final class HealthRecordLinks {
  static String? locationOf(String? refTable, String? refId, {String? planetKey}) {
    switch (refTable) {
      case 'medications' || 'med_doses':
        return AppRoutes.meds;
      case 'habits':
        return planetKey == 'health' ? AppRoutes.wellbeingOf(tab: 'habits') : null;
      case 'appointments':
        return AppRoutes.appointmentsOf(highlightId: refId);
      case 'lab_tests':
        return refId == null ? AppRoutes.record : AppRoutes.labTestOf(refId);
      case 'mood_entries':
        return AppRoutes.wellbeing;
      case 'pain_entries':
        return AppRoutes.wellbeingOf(tab: 'pain');
    }
    return null;
  }
}
