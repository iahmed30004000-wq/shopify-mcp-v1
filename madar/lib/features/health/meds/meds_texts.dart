import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import 'domain/course_schedule.dart';
import 'domain/dose_scheduler.dart';
import 'domain/dose_tracker.dart';
import 'domain/med_models.dart';

/// Every user-facing text of the medication tracker, built from the
/// localisations and the digit style (names, doses and numbers bidi-isolated
/// so a Latin drug name or "10 mg" never scrambles an Arabic sentence).
class MedsTexts {
  const MedsTexts(this.l, this.fmt);

  /// Texts outside the widget tree (notifications, the background isolate):
  /// loads intl's date symbols first (compiled in, synchronous).
  factory MedsTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) {
    _ensureDateSymbols();
    final lang = languageCode == 'en' ? 'en' : 'ar';
    return MedsTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits));
  }

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  final L10n l;
  final MadarFormatter fmt;

  /// A medication's name, isolated.
  String name(String name) => fmt.isolate(name);

  /// A dose text ("10 mg"), digits localised, isolated.
  String dose(String dose) => fmt.isolate(fmt.localizeDigits(dose));

  String time(DateTime t) => fmt.formatTime(t);

  String clock(ClockHm t) => fmt.formatClock(t.hour, t.minute);

  String count(int n) => fmt.formatInt(n);

  /// Compact duration ("٣٠ د", "٢ س").
  String duration(int minutes) => fmt.formatDurationWords(l, Duration(minutes: minutes.abs()));

  String kind(MedKind k) => switch (k) {
    MedKind.medication => l.medsKindMedication,
    MedKind.supplement => l.medsKindSupplement,
    MedKind.injection => l.medsKindInjection,
    MedKind.other => l.medsKindOther,
  };

  String takenWith(TakenWith w) => switch (w) {
    TakenWith.emptyStomach => l.medsWithEmptyStomach,
    TakenWith.breakfast => l.medsWithBreakfast,
    TakenWith.lunch => l.medsWithLunch,
    TakenWith.dinner => l.medsWithDinner,
    TakenWith.bedtime => l.medsWithBedtime,
    TakenWith.other => l.medsWithOther,
    TakenWith.perCourse => l.medsWithPerCourse,
    TakenWith.anytime => l.medsWithAnytime,
  };

  /// "breakfast" as used inside a sentence.
  String meal(MealSlot m) => switch (m) {
    MealSlot.breakfast => l.medsMealBreakfast,
    MealSlot.lunch => l.medsMealLunch,
    MealSlot.dinner => l.medsMealDinner,
    MealSlot.bedtime => l.medsMealBedtime,
  };

  /// "Breakfast" as a title.
  String mealTitle(MealSlot m) => switch (m) {
    MealSlot.breakfast => l.medsMealBreakfastTitle,
    MealSlot.lunch => l.medsMealLunchTitle,
    MealSlot.dinner => l.medsMealDinnerTitle,
    MealSlot.bedtime => l.medsMealBedtimeTitle,
  };

  /// The prayer / meal an anchor follows.
  String anchorPlace(AnchorBase b) => switch (b) {
    AnchorBase.fajr => l.prayerFajr,
    AnchorBase.sunrise => l.prayerSunrise,
    AnchorBase.dhuhr => l.prayerDhuhr,
    AnchorBase.asr => l.prayerAsr,
    AnchorBase.maghrib => l.prayerMaghrib,
    AnchorBase.isha => l.prayerIsha,
    _ => meal(b.meal!),
  };

  String anchorPlaceTitle(AnchorBase b) => b.isMeal ? mealTitle(b.meal!) : anchorPlace(b);

  /// "20 min after Fajr", "With breakfast", "At Maghrib".
  String anchor(TimeAnchor a) {
    final place = anchorPlace(a.base);
    if (a.offsetMinutes == 0) {
      if (a.base == AnchorBase.bedtime) return l.medsAnchorBedtime;
      return a.base.isMeal ? l.medsAnchorWithMeal(place) : l.medsAnchorAtPrayer(place);
    }
    final d = duration(a.offsetMinutes);
    return a.offsetMinutes < 0 ? l.medsAnchorBefore(place, d) : l.medsAnchorAfter(place, d);
  }

  /// A daily time as the user set it: "8:00 AM" or "20 min after Fajr".
  String slot(MedSlot s) => s.anchor == null ? clock(s.key) : anchor(s.anchor!);

  String state(TrackedDose t) => switch (t.state) {
    DoseState.upcoming => l.medsStateUpcoming,
    DoseState.due => l.medsStateDue,
    DoseState.late => l.medsStateLate,
    DoseState.missed => l.medsStateMissed,
    DoseState.taken => t.takenAt == null ? l.medsStatTaken : l.medsStateTakenAt(time(t.takenAt!)),
    DoseState.skipped => l.medsStateSkipped,
    DoseState.snoozed => l.medsStateSnoozedUntil(time(t.dueAt)),
  };

  String frequency(CoursePhase p) => switch (p.frequency) {
    CourseFrequency.daily => l.medsEveryDays(p.interval),
    CourseFrequency.weekly => l.medsEveryWeeks(p.interval),
    CourseFrequency.monthly => l.medsEveryMonths(p.interval),
  };

  /// "Daily × 10", "Monthly, ongoing".
  String phase(CoursePhase p) {
    final f = fmt.localizeDigits(frequency(p));
    return p.count == null ? l.medsPhaseOngoingLine(f) : l.medsPhaseTimes(f, count(p.count!));
  }

  String rule(RuleSpec r, String Function(String id) medName) {
    final a = name(medName(r.medAId));
    return switch (r.kind) {
      MedRuleKind.separate => l.medsRuleSeparateText(a, name(medName(r.medBId ?? '')), duration(r.minutes)),
      MedRuleKind.beforeFood => l.medsRuleBeforeFoodText(a, duration(r.minutes)),
      MedRuleKind.afterFood => l.medsRuleAfterFoodText(a, duration(r.minutes)),
      MedRuleKind.withFood => l.medsRuleWithFoodText(a),
      MedRuleKind.custom => l.medsRuleCustomText(a, fmt.isolate(r.note ?? '')),
    };
  }

  String conflict(DoseConflict c) => switch (c.kind) {
    DoseConflictKind.separation => l.medsConflictSeparation(
      name(c.a.med.name),
      name(c.b?.med.name ?? ''),
      duration(c.requiredMinutes),
      c.actualMinutes <= 0 ? l.medsAtTheSameTime : duration(c.actualMinutes),
    ),
    DoseConflictKind.noMeal => l.medsConflictNoMeal(name(c.a.med.name)),
    DoseConflictKind.ruleClash => l.medsConflictClash(name(c.a.med.name)),
  };

  /// "Moved 30 min later by a timing rule".
  String? shift(PlannedDose d) {
    // Only a rule's move (a taken dose sits at its real time instead).
    if (!d.shifted || d.ruleIds.isEmpty) return null;
    final minutes = d.shift.inMinutes;
    if (d.meal != null && d.pinned) return l.medsPinnedToMeal;
    return minutes > 0 ? l.medsShiftedLater(duration(minutes)) : l.medsShiftedEarlier(duration(minutes));
  }

  /// "5 mg · With breakfast".
  String doseLine(PlannedDose d) {
    final parts = <String>[
      if (d.dose != null && d.dose!.isNotEmpty) dose(d.dose!),
      if (d.anchor == null && d.med.takenWith != TakenWith.anytime) takenWith(d.med.takenWith),
      if (d.anchor != null) anchor(d.anchor!),
    ];
    return parts.join(' · ');
  }

  String courseProgress(CourseSpec c, CourseProgress p) {
    if (p.dosesInPhase == null) return l.medsCoursePhaseOngoingProgress(count(p.phase + 1));
    return l.medsCoursePhaseProgress(count(p.phase + 1), count(p.doneInPhase), count(p.dosesInPhase!));
  }
}
