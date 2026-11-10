import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../body/domain/body_clock.dart';
import '../domain/food_library.dart';
import '../domain/food_log.dart';
import '../domain/food_rules.dart';
import '../domain/nutrition_insights.dart';
import '../domain/plan_compare.dart';
import '../domain/risk.dart';

/// Every sentence the food screens say, in the user's language and digits.
///
/// Two rules this class keeps, because the screens on top of it must never
/// break them:
/// * a rating is never worded as a verdict – [reason] always starts from
///   *his* rule («لأنك علّمت…») and prefers his own note over anything we
///   would compose;
/// * an observation is never worded as a cause – [metric] names what was
///   counted and nothing more.
class NutritionTexts {
  NutritionTexts(this.l, this.fmt);

  factory NutritionTexts.of(BuildContext context) => NutritionTexts(L10n.of(context), context.formatter);

  final L10n l;
  final MadarFormatter fmt;

  // A Monday used to name ISO weekdays.
  static final DateTime _monday = DateTime(2026, 9, 28);

  /// Between the parts of a one-line summary (an Arabic comma in Arabic:
  /// a middle dot beside Arabic-Indic digits reads as a zero).
  String get sep => l.nutritionPartsSep;

  /// A user-typed name, bidi-isolated for a sentence around it.
  String name(String value) => fmt.isolate(value);

  String weekdayName(int iso) => DateFormat('EEEE', fmt.languageCode).format(_monday.add(Duration(days: iso - 1)));

  /// One letter in Arabic («س»), two elsewhere («Sa») – a day of the week
  /// strip, where three letters do not fit and one is ambiguous.
  String weekdayTiny(int iso) {
    final day = _monday.add(Duration(days: iso - 1));
    if (fmt.isArabic) return DateFormat('EEEEE', fmt.languageCode).format(day);
    final s = DateFormat('E', fmt.languageCode).format(day);
    return s.length <= 2 ? s : s.substring(0, 2);
  }

  /// «السبت، الإثنين والأربعاء»; empty days read as «كل يوم».
  String weekdays(List<int> ordered) {
    if (ordered.isEmpty) return l.nutritionEveryDay;
    final names = [for (final d in ordered) weekdayName(d)];
    if (names.length == 1) return names.first;
    return l.nutritionListAnd(names.sublist(0, names.length - 1).join(l.nutritionListSep), names.last);
  }

  /// `"08:00"` → the local clock format in the user's digits.
  String clock(int minutes) => fmt.formatClock(minutes ~/ 60, minutes % 60);

  String time(DateTime at) => fmt.formatTime(at);

  /// A window label the engine built (`"22:00–06:00"`), re-read in the
  /// user's clock format and digits.
  String window(String label) {
    final parts = label.split('–');
    if (parts.length != 2) return fmt.localizeDigits(label);
    final from = BodyTimes.parse(parts[0]);
    final to = BodyTimes.parse(parts[1]);
    if (from == null || to == null) return fmt.localizeDigits(label);
    return '${clock(from)} – ${clock(to)}';
  }

  /// «رغيف ونص» → «١٫٥ رغيف»; no unit → «كمية ١٫٥»; no amount → null.
  String? portion(double? amount, String? unit) {
    if (amount == null) return null;
    final value = fmt.formatNumber(amount, maxDecimals: 2);
    final u = unit?.trim();
    return u == null || u.isEmpty ? l.nutritionPortionPlain(value) : l.nutritionPortionValue(value, name(u));
  }

  /// The portion an entry really stands for (its own, else its food's).
  String? entryPortion(FoodEntry entry, {Food? food}) =>
      portion(Portions.effective(entry.portion, food: food), Portions.unitOf(entry.unit, food: food));

  /// «٨:٣٠ ص، رغيف ونص» – one line under a logged entry.
  String entryLine(FoodEntry entry, {Food? food}) {
    final p = entryPortion(entry, food: food);
    return [time(entry.at), ?p].join(sep);
  }

  String level(RiskLevel value) => switch (value) {
    RiskLevel.none => l.nutritionLevelClear,
    RiskLevel.low => l.nutritionLevelLow,
    RiskLevel.medium => l.nutritionLevelMedium,
    RiskLevel.high => l.nutritionLevelHigh,
  };

  String weight(RiskWeight value) => switch (value) {
    RiskWeight.low => l.nutritionWeightLow,
    RiskWeight.medium => l.nutritionWeightMedium,
    RiskWeight.high => l.nutritionWeightHigh,
  };

  String target(FoodRuleTarget value) => switch (value) {
    FoodRuleTarget.food => l.nutritionTargetFood,
    FoodRuleTarget.tag => l.nutritionTargetTag,
    FoodRuleTarget.anyFood => l.nutritionTargetAny,
  };

  String status(SlotStatus value) => switch (value) {
    SlotStatus.eatenOnTime => l.nutritionStatusOnTime,
    SlotStatus.eatenLate => l.nutritionStatusLate,
    SlotStatus.swapped => l.nutritionStatusSwapped,
    SlotStatus.skipped => l.nutritionStatusSkipped,
    SlotStatus.pending => l.nutritionStatusPending,
  };

  String metric(NutritionMetric value) => switch (value) {
    NutritionMetric.pain => l.nutritionMetricPain,
    NutritionMetric.mood => l.nutritionMetricMood,
    NutritionMetric.sleep => l.nutritionMetricSleep,
    NutritionMetric.water => l.nutritionMetricWater,
    NutritionMetric.fasting => l.nutritionMetricFasting,
  };

  /// A metric's own average, in its own unit (water in millilitres, the
  /// rest as plain numbers – Madar invents no scale of its own).
  String metricValue(NutritionMetric m, double value) =>
      fmt.formatNumber(value, maxDecimals: m == NutritionMetric.water ? 0 : 1);

  /// Why a rating came out as it did, in one line.
  ///
  /// His own note comes first and whole: it is his sentence. Only when he
  /// wrote none is a line composed from the rule's parts, and it still
  /// starts from him («لأنك علّمت…»).
  String reason(RiskReason r) {
    final note = r.note?.trim();
    final head = note != null && note.isNotEmpty
        ? name(note)
        : switch (r.target) {
            FoodRuleTarget.tag => l.nutritionReasonTag(name(r.tag ?? '')),
            FoodRuleTarget.food => l.nutritionReasonFood(name(r.foodName ?? '')),
            FoodRuleTarget.anyFood => l.nutritionReasonAny,
          };
    return [head, ...reasonDetails(r)].join(sep);
  }

  /// The parts of a reason beside its sentence: the condition it speaks
  /// about, its window, its threshold and (for a day rule) the count.
  List<String> reasonDetails(RiskReason r) {
    final condition = r.conditionName;
    final windowLabel = r.windowLabel;
    final min = r.minPortion;
    final count = r.dayCount;
    final max = r.maxPerDay;
    return [
      if (condition != null && condition.isNotEmpty) l.nutritionReasonForCondition(name(condition)),
      if (windowLabel != null) l.nutritionReasonWindow(window(windowLabel)),
      if (min != null) l.nutritionReasonMinPortion(fmt.formatNumber(min, maxDecimals: 2)),
      if (count != null && max != null)
        fmt.localizeDigits(l.nutritionReasonDayCount(count, fmt.formatInt(count), fmt.formatInt(max))),
    ];
  }

  /// A rule as a sentence of his own, for the rules list.
  String rule(FoodRule r) {
    final note = r.note?.trim();
    final head = note != null && note.isNotEmpty
        ? name(note)
        : switch (r.target) {
            FoodRuleTarget.tag => l.nutritionReasonTag(name(r.tag ?? '')),
            FoodRuleTarget.food => l.nutritionReasonFood(name(r.foodName ?? '')),
            FoodRuleTarget.anyFood => l.nutritionReasonAny,
          };
    final windowLabel = r.windowLabel;
    final min = r.minPortion;
    final max = r.maxPerDay;
    return [
      head,
      if (windowLabel != null) l.nutritionReasonWindow(window(windowLabel)),
      if (min != null) l.nutritionReasonMinPortion(fmt.formatNumber(min, maxDecimals: 2)),
      if (max != null) l.nutritionRuleWholeDay,
      weight(r.weight),
    ].join(sep);
  }

  /// «التزامك ٧٥٪» or «ما بعد» when nothing is settled yet.
  String adherence(double? value) =>
      value == null ? l.nutritionAdherenceNone : l.nutritionAdherence(fmt.formatPercent(value));

  /// How late a slot was eaten, in words.
  String lateBy(Duration d) => l.nutritionLateBy(fmt.formatDurationWords(l, d));

  /// «السبت ٢٧ سبتمبر», or «اليوم» for today.
  String day(DateTime d, DateTime today) => BodyDays.same(BodyDays.of(d), BodyDays.of(today))
      ? l.nutritionCompareToday
      : fmt.formatDate(d, style: MadarDateStyle.weekdayDayMonth);

  /// The planned foods of a slot as one phrase, or null when it has none.
  String? plannedFoods(Iterable<String> names) {
    final list = [for (final n in names) name(n)];
    if (list.isEmpty) return null;
    return list.join(l.nutritionListSep);
  }
}
