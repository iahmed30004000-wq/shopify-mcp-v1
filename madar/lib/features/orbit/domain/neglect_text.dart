import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import 'planet_scores.dart';
import 'score_sources.dart';

/// Localised, human sentence for a Neglect Radar reason, e.g.
/// «أبي — متأخر ٣ أيام» / "Father — 3 days overdue",
/// «جرعتان فائتتان» / "2 doses past due".
///
/// Numbers follow [fmt]'s digit style (Arabic-Indic in Arabic by default);
/// names typed by the user are bidi-isolated so a Latin name inside an Arabic
/// sentence (or the reverse) never reorders its neighbours. Plural forms
/// (Arabic: one, two, few 3–10, many 11–99, other 100+) come from ICU
/// messages in `80_orbit.json`.
String neglectReasonText(L10n l, NeglectReason reason, MadarFormatter fmt) {
  final args = reason.args;
  String name(String key) => fmt.isolate('${args[key] ?? ''}'.trim());
  int count(String key) => switch (args[key]) {
    final num v => v.round(),
    _ => 0,
  };
  String n(String key) => fmt.formatInt(count(key));
  String percent(String key) => fmt.formatPercent(count(key) / 100);

  switch (reason.code) {
    case ReasonCode.personOverdue:
      return l.orbitReasonPersonOverdue(name('name'), count('days'), n('days'));
    case ReasonCode.dosesPastDue:
      return args['name'] == null
          ? l.orbitReasonDosesPastDue(count('count'), n('count'))
          : l.orbitReasonDosesPastDueNamed(name('name'), count('count'), n('count'));
    case ReasonCode.prayersMissed:
      return l.orbitReasonPrayersMissed(count('count'), n('count'));
    case ReasonCode.tasksOverdue:
      return l.orbitReasonTasksOverdue(count('count'), n('count'));
    case ReasonCode.cardsOverdue:
      return l.orbitReasonCardsOverdue(name('board'), count('count'), n('count'));
    case ReasonCode.budgetOverspent:
      return l.orbitReasonBudgetOverspent(name('item'), percent('percent'));
    case ReasonCode.obligationOverdue:
      return l.orbitReasonObligationOverdue(name('name'), count('days'), n('days'));
    case ReasonCode.debtOverdue:
      return l.orbitReasonDebtOverdue(name('person'), count('days'), n('days'));
    case ReasonCode.goalBehind:
      return args['days'] == null
          ? l.orbitReasonGoalBehind(name('name'), percent('percent'))
          : l.orbitReasonGoalQuiet(name('name'), count('days'), n('days'));
    case ReasonCode.workoutsMissed:
      return l.orbitReasonWorkoutsMissed(count('count'), n('count'));
    case ReasonCode.waterLow:
      return l.orbitReasonWaterLow(percent('percent'));
    case ReasonCode.documentExpiring:
      final days = count('days');
      if (days < 0) return l.orbitReasonDocumentExpired(name('name'));
      if (days == 0) return l.orbitReasonDocumentExpiresToday(name('name'));
      return l.orbitReasonDocumentExpiring(name('name'), days, n('days'));
    case ReasonCode.tripUnpacked:
      return l.orbitReasonTripUnpacked(name('destination'), count('days'), n('days'), percent('percent'));
    case ReasonCode.moduleStale:
      return l.orbitReasonModuleStale(name('name'), count('days'), n('days'));
    case ReasonCode.noActivity:
      return l.orbitReasonNoActivity(count('days'), n('days'));
    case ReasonCode.habitsSlipping:
      return args['name'] != null && args['days'] != null
          ? l.orbitReasonHabitSlipping(name('name'), count('days'), n('days'))
          : l.orbitReasonHabitsSlipping(count('count'), n('count'));
    case ReasonCode.projectItemsOverdue:
      return l.orbitReasonProjectItemsOverdue(name('project'), count('count'), n('count'));
    case ReasonCode.jarBehind:
      return l.orbitReasonJarBehind(name('name'), percent('percent'));
    case ReasonCode.sourceStale:
      return l.orbitReasonSourceStale(scoreSourceLabel(l, '${args['source']}'), count('days'), n('days'));
  }
}

/// Display name of a score source key (`prayers`, `medications` …). Module
/// sources (`module:<id>`) and unknown keys fall back to the key itself;
/// callers show module names from the module row.
String scoreSourceLabel(L10n l, String source) => switch (ScoreSources.canonical(source)) {
  ScoreSources.prayers => l.orbitSourcePrayers,
  ScoreSources.adhkar => l.orbitSourceAdhkar,
  ScoreSources.quran => l.orbitSourceQuran,
  ScoreSources.doses => l.orbitSourceDoses,
  ScoreSources.habits => l.orbitSourceHabits,
  ScoreSources.mood => l.orbitSourceMood,
  ScoreSources.pain => l.orbitSourcePain,
  ScoreSources.appointments => l.orbitSourceAppointments,
  ScoreSources.contacts => l.orbitSourceContacts,
  ScoreSources.tasks => l.orbitSourceTasks,
  ScoreSources.cards => l.orbitSourceCards,
  ScoreSources.projects => l.orbitSourceProjects,
  ScoreSources.budget => l.orbitSourceBudget,
  ScoreSources.transactions => l.orbitSourceTransactions,
  ScoreSources.jars => l.orbitSourceJars,
  ScoreSources.obligations => l.orbitSourceObligations,
  ScoreSources.debts => l.orbitSourceDebts,
  ScoreSources.goals => l.orbitSourceGoals,
  ScoreSources.workouts => l.orbitSourceWorkouts,
  ScoreSources.fasting => l.orbitSourceFasting,
  ScoreSources.water => l.orbitSourceWater,
  ScoreSources.documents => l.orbitSourceDocuments,
  ScoreSources.trips => l.orbitSourceTrips,
  ScoreSources.activity => l.orbitSourceActivity,
  final other => other,
};

/// Display name of a planet style.
String planetArchetypeLabel(L10n l, PlanetArchetype a) => switch (a) {
  PlanetArchetype.faith => l.orbitArchetypeFaith,
  PlanetArchetype.ocean => l.orbitArchetypeOcean,
  PlanetArchetype.terracotta => l.orbitArchetypeTerracotta,
  PlanetArchetype.industrial => l.orbitArchetypeIndustrial,
  PlanetArchetype.crystal => l.orbitArchetypeCrystal,
  PlanetArchetype.verdant => l.orbitArchetypeVerdant,
  PlanetArchetype.volcanic => l.orbitArchetypeVolcanic,
  PlanetArchetype.gasGiant => l.orbitArchetypeGasGiant,
  PlanetArchetype.ice => l.orbitArchetypeIce,
  PlanetArchetype.desert => l.orbitArchetypeDesert,
};

/// Display name of a planet's living state.
String planetStateLabel(L10n l, PlanetState s) => switch (s) {
  PlanetState.thriving => l.orbitStateThriving,
  PlanetState.steady => l.orbitStateSteady,
  PlanetState.neglected => l.orbitStateNeglected,
  PlanetState.dormant => l.orbitStateDormant,
};
