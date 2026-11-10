/// One small object with everything a card, a planet score or the daily
/// summary needs from Nutrition – built once, read everywhere.
library;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';
import 'food_library.dart';
import 'food_log.dart';
import 'meal_plan.dart';
import 'plan_compare.dart';
import 'risk.dart';

/// Nutrition in one glance: today's log, today's plan and today's rating.
///
/// Every field is a plain number or a plain string, so the UI needs no logic
/// and the orbit's planet score can read it as it is. A field that has no
/// honest answer yet is null (no plan, no rules, nothing logged) – never a
/// zero standing in for "unknown".
@immutable
class NutritionSummary {
  const NutritionSummary({
    required this.day,
    required this.entriesToday,
    required this.lastEntryAt,
    required this.plan,
    required this.today,
    required this.risk,
    required this.loggedDays7,
    required this.streakDays,
    required this.foodCount,
    required this.ruleCount,
  });

  /// A summary before anything exists (a fresh install).
  factory NutritionSummary.empty(DateTime day) => NutritionSummary(
    day: BodyDays.of(day),
    entriesToday: const [],
    lastEntryAt: null,
    plan: MealPlan.none,
    today: DayPlan.unplannedOnly(day, const []),
    risk: null,
    loggedDays7: 0,
    streakDays: 0,
    foodCount: 0,
    ruleCount: 0,
  );

  /// Builds the summary from the pieces the providers already hold.
  factory NutritionSummary.build({
    required DateTime today,
    required DateTime now,
    required MealPlan plan,
    required Iterable<FoodEntry> entries,
    required Iterable<Food> foods,
    required int ruleCount,
    DayRisk? risk,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final day = BodyDays.of(today);
    final all = entries.toList();
    final todays = FoodLogStats.onDay(all, day, clock: clock);
    final comparison = PlanCompare.compare(plan: plan, entries: all, day: day, now: now, clock: clock);
    final countByDay = FoodLogStats.countByDay(all, clock: clock);
    var logged = 0;
    for (var i = 0; i < 7; i++) {
      if ((countByDay[BodyDays.key(BodyDays.add(day, -i))] ?? 0) > 0) logged++;
    }
    return NutritionSummary(
      day: day,
      entriesToday: todays,
      lastEntryAt: all.isEmpty ? null : all.map((e) => e.at).reduce((a, b) => a.isAfter(b) ? a : b),
      plan: plan,
      today: comparison,
      risk: risk,
      loggedDays7: logged,
      streakDays: FoodLogStats.streak(all, today: day, clock: clock),
      foodCount: foods.where((f) => !f.archived).length,
      ruleCount: ruleCount,
    );
  }

  /// The local day this summary describes.
  final DateTime day;

  /// Today's entries, earliest first.
  final List<FoodEntry> entriesToday;

  /// When he last logged anything at all (null: never).
  final DateTime? lastEntryAt;

  /// The active plan, or `MealPlan.none`.
  final MealPlan plan;

  /// Today's planned-vs-eaten comparison.
  final DayPlan today;

  /// Today's rating, or **null** when he has written no rule that applies –
  /// then the UI shows no rating at all.
  final DayRisk? risk;

  /// Days of the last 7 (today included) with at least one entry.
  final int loggedDays7;

  /// Days in a row up to today with at least one entry.
  final int streakDays;

  /// Foods in his library (archived ones excluded).
  final int foodCount;

  /// Rules he has written (active or not).
  final int ruleCount;

  bool get hasPlan => !plan.isEmpty;
  bool get hasRules => ruleCount > 0;
  bool get loggedToday => entriesToday.isNotEmpty;
  int get entryCountToday => entriesToday.length;

  /// Today's share of settled slots that were eaten, 0‥1, or null when
  /// nothing is settled (no plan, or the day has not reached a meal yet).
  double? get adherenceToday => today.adherence;

  /// The next meal still ahead today, or null.
  SlotOutcome? get nextMeal => today.next;

  /// Today's risk level, or null when there is no rating.
  RiskLevel? get level => risk?.level;

  /// Today's reasons, heaviest first (empty when there is no rating).
  List<RiskReason> get reasons => risk?.reasons ?? const [];

  /// What the orbit's Body planet can read: 0‥1 for "he is keeping his own
  /// plan and log", or null when he has neither logged nor planned anything
  /// (so a planet is never punished for a feature he does not use).
  ///
  /// It is the plain average of what exists: the share of the last 7 days he
  /// logged on, and today's plan adherence when there is a plan.
  double? get planetScore {
    final parts = <double>[];
    if (loggedDays7 > 0 || lastEntryAt != null) parts.add(loggedDays7 / 7);
    final a = adherenceToday;
    if (a != null) parts.add(a);
    if (parts.isEmpty) return null;
    return parts.reduce((x, y) => x + y) / parts.length;
  }

  @override
  String toString() =>
      'NutritionSummary(${BodyDays.key(day)}: $entryCountToday entries, plan ${plan.name}, '
      'risk ${risk?.level.name ?? 'none'}, $loggedDays7/7 days)';
}
