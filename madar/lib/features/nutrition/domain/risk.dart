/// The risk rating: a pure function from one logged entry (or one whole day)
/// plus the user's active conditions and his own rules to a score **and its
/// reasons**.
///
/// Three promises this file keeps:
/// 1. **No rules, no rating.** With no rule that applies, `rate…` returns
///    null – the UI shows nothing, not a zero and not a guess.
/// 2. **Never a verdict without its reason.** A rating always carries the
///    rules it came from, each with the condition it speaks about and the
///    user's own wording.
/// 3. **Nothing of ours.** Every point comes from a rule he wrote; Madar adds
///    no food knowledge, no diagnosis and no advice.
library;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';
import 'food_library.dart';
import 'food_log.dart';
import 'food_rules.dart';

/// How heavy a rating came out. `none` means "rules apply, and none of them
/// fired" – the absence of a rating is a null rating, not this.
enum RiskLevel { none, low, medium, high }

/// Why a rating came out as it did: one rule that fired.
@immutable
class RiskReason {
  const RiskReason({
    required this.ruleId,
    required this.target,
    required this.weight,
    required this.points,
    this.tag,
    this.foodName,
    this.conditionId,
    this.conditionName,
    this.note,
    this.windowLabel,
    this.minPortion,
    this.dayCount,
    this.maxPerDay,
  });

  final String ruleId;
  final FoodRuleTarget target;
  final RiskWeight weight;

  /// What the rule added to the score.
  final int points;

  /// The tag the rule matched (his word), for a tag rule.
  final String? tag;

  /// The food the rule matched, for a food rule.
  final String? foodName;

  /// The condition it speaks about (null for a general rule).
  final String? conditionId;
  final String? conditionName;

  /// His own wording of the rule, when he wrote one. The UI shows this first
  /// and only falls back to a sentence built from the fields.
  final String? note;

  /// `"22:00–06:00"` when the rule only counts inside a window.
  final String? windowLabel;

  /// The amount from which the rule counts, when it has a threshold.
  final double? minPortion;

  /// For a day rule: how many matching entries the day held, and the limit
  /// he set.
  final int? dayCount;
  final int? maxPerDay;

  bool get isDayReason => dayCount != null;

  @override
  String toString() =>
      'RiskReason($ruleId, ${target.name}${tag != null ? ' «$tag»' : ''}${foodName != null ? ' «$foodName»' : ''}'
      '${conditionName != null ? ' → $conditionName' : ''}, +$points)';
}

/// One entry's (or one day's) rating: a score, a level and the reasons.
@immutable
class RiskRating {
  const RiskRating({required this.score, required this.level, required this.reasons});

  /// Sum of the fired rules' points.
  final int score;
  final RiskLevel level;

  /// The rules that fired, heaviest first. Never empty when [score] > 0.
  final List<RiskReason> reasons;

  /// Rules applied and none fired.
  bool get isClear => score == 0;

  /// The conditions this rating touches, in reason order, without repeats.
  List<String> get conditionIds {
    final out = <String>[];
    for (final r in reasons) {
      final id = r.conditionId;
      if (id != null && !out.contains(id)) out.add(id);
    }
    return out;
  }

  @override
  String toString() => 'RiskRating($score, ${level.name}, ${reasons.length} reasons)';
}

/// One day's rating: the day's own score plus every entry's.
@immutable
class DayRisk {
  const DayRisk({
    required this.day,
    required this.rating,
    required this.perEntry,
    this.heaviestEntryId,
  });

  final DateTime day;

  /// The day's rating (entry scores plus the day rules that fired).
  final RiskRating rating;

  /// Each entry's own rating, by entry id (entries nothing applied to are
  /// absent).
  final Map<String, RiskRating> perEntry;

  /// The entry with the highest score of the day, or null.
  final String? heaviestEntryId;

  int get score => rating.score;
  RiskLevel get level => rating.level;
  List<RiskReason> get reasons => rating.reasons;

  @override
  String toString() => 'DayRisk(${BodyDays.key(day)}, ${rating.score}, ${rating.level.name})';
}

/// The rules engine. Every method is pure and side-effect free.
abstract final class RiskEngine {
  /// Entry thresholds: 1–2 points low, 3–4 medium, 5+ high.
  static const int entryMediumFrom = 3;
  static const int entryHighFrom = 5;

  /// Day thresholds: 1–3 points low, 4–7 medium, 8+ high.
  static const int dayMediumFrom = 4;
  static const int dayHighFrom = 8;

  /// The rules that count right now: switched on, complete, and either
  /// general or tied to an active condition.
  static List<FoodRule> applicable(Iterable<FoodRule> rules, Iterable<ConditionRef> conditions) => [
    for (final r in rules)
      if (r.appliesWith(conditions)) r,
  ];

  /// Rates one entry, or returns **null** when no rule of his applies at all
  /// (no rules yet, all switched off, or every rule tied to a condition he
  /// has turned off). Null means «ما في تقييم» – never show a zero for it.
  ///
  /// [food] is the entry's library food when it has one (its tags count).
  /// Day rules (a daily limit) are ignored here by design; see [rateDay].
  static RiskRating? rateEntry(
    FoodEntry entry, {
    required Iterable<FoodRule> rules,
    required Iterable<ConditionRef> conditions,
    Food? food,
  }) {
    final live = applicable(rules, conditions).where((r) => !r.isDayRule).toList();
    if (live.isEmpty) return null;
    final names = {for (final c in conditions) c.id: c.name};
    final reasons = <RiskReason>[];
    var score = 0;
    for (final rule in live) {
      if (!rule.matches(entry, food: food)) continue;
      score += rule.points;
      reasons.add(_reasonOf(rule, names));
    }
    _sortReasons(reasons);
    return RiskRating(score: score, level: levelOfEntry(score), reasons: reasons);
  }

  /// Rates a whole day: every entry of [entries] (already the day's, e.g.
  /// from `FoodLogStats.onDay`) plus the day rules (a daily limit he set).
  /// Returns null when no rule applies at all.
  ///
  /// [foodsById] resolves each entry's library food, so its tags count.
  static DayRisk? rateDay({
    required DateTime day,
    required Iterable<FoodEntry> entries,
    required Iterable<FoodRule> rules,
    required Iterable<ConditionRef> conditions,
    Map<String, Food> foodsById = const {},
  }) {
    final live = applicable(rules, conditions);
    if (live.isEmpty) return null;
    final names = {for (final c in conditions) c.id: c.name};
    final list = entries.toList()..sort((a, b) => a.at.compareTo(b.at));
    final perEntry = <String, RiskRating>{};
    final reasons = <RiskReason>[];
    var score = 0;
    String? heaviest;
    var heaviestScore = 0;

    for (final entry in list) {
      final rating = rateEntry(
        entry,
        rules: live,
        conditions: conditions,
        food: entry.foodId == null ? null : foodsById[entry.foodId],
      );
      if (rating == null) continue;
      perEntry[entry.id] = rating;
      score += rating.score;
      reasons.addAll(rating.reasons);
      if (rating.score > heaviestScore) {
        heaviestScore = rating.score;
        heaviest = entry.id;
      }
    }

    for (final rule in live.where((r) => r.isDayRule)) {
      final count = list
          .where((e) => rule.matchesSubject(e, food: foodsById[e.foodId]) && rule.gatesPass(e, food: foodsById[e.foodId]))
          .length;
      if (count <= rule.maxPerDay!) continue;
      score += rule.points;
      reasons.add(_reasonOf(rule, names, dayCount: count));
    }

    _sortReasons(reasons);
    return DayRisk(
      day: BodyDays.of(day),
      rating: RiskRating(score: score, level: levelOfDay(score), reasons: _merged(reasons)),
      perEntry: perEntry,
      heaviestEntryId: heaviest,
    );
  }

  /// The level of one entry's [score].
  static RiskLevel levelOfEntry(int score) => score <= 0
      ? RiskLevel.none
      : score >= entryHighFrom
          ? RiskLevel.high
          : score >= entryMediumFrom
              ? RiskLevel.medium
              : RiskLevel.low;

  /// The level of a day's [score].
  static RiskLevel levelOfDay(int score) => score <= 0
      ? RiskLevel.none
      : score >= dayHighFrom
          ? RiskLevel.high
          : score >= dayMediumFrom
              ? RiskLevel.medium
              : RiskLevel.low;

  /// The entries a rule fired on, for "show me why" (and for the rule
  /// editor's preview of what a new rule would have flagged).
  static List<FoodEntry> entriesHit(
    FoodRule rule,
    Iterable<FoodEntry> entries, {
    Map<String, Food> foodsById = const {},
  }) => [
    for (final e in entries)
      if (rule.matchesSubject(e, food: foodsById[e.foodId]) && rule.gatesPass(e, food: foodsById[e.foodId])) e,
  ];

  static RiskReason _reasonOf(FoodRule rule, Map<String, String> conditionNames, {int? dayCount}) => RiskReason(
    ruleId: rule.id,
    target: rule.target,
    weight: rule.weight,
    points: rule.points,
    tag: rule.tag,
    foodName: rule.foodName,
    conditionId: rule.conditionId,
    conditionName: rule.conditionId == null ? null : conditionNames[rule.conditionId],
    note: rule.note,
    windowLabel: rule.windowLabel,
    minPortion: rule.minPortion,
    dayCount: dayCount,
    maxPerDay: dayCount == null ? null : rule.maxPerDay,
  );

  static void _sortReasons(List<RiskReason> reasons) {
    reasons.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      return byPoints != 0 ? byPoints : a.ruleId.compareTo(b.ruleId);
    });
  }

  /// One line per rule for a day: a rule that fired on three entries is one
  /// reason worth the sum of its points.
  static List<RiskReason> _merged(List<RiskReason> reasons) {
    final out = <String, RiskReason>{};
    for (final r in reasons) {
      final prev = out[r.ruleId];
      out[r.ruleId] = prev == null
          ? r
          : RiskReason(
              ruleId: r.ruleId,
              target: r.target,
              weight: r.weight,
              points: prev.points + r.points,
              tag: r.tag,
              foodName: r.foodName,
              conditionId: r.conditionId,
              conditionName: r.conditionName,
              note: r.note,
              windowLabel: r.windowLabel,
              minPortion: r.minPortion,
              dayCount: r.dayCount ?? prev.dayCount,
              maxPerDay: r.maxPerDay ?? prev.maxPerDay,
            );
    }
    final list = out.values.toList();
    _sortReasons(list);
    return list;
  }
}
