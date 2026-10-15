/// The user's own rules: what he himself says is heavy for which of his
/// conditions, and how heavily.
///
/// Madar brings **no** food knowledge of its own. A rule exists because he
/// wrote it (or imported one and approved it); its weight is the one he
/// picked; its wording is his. Nothing here diagnoses or advises.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../body/domain/body_clock.dart';
import 'food_library.dart';
import 'food_log.dart';

export '../../../core/domain/enums.dart' show FoodRuleTarget, RiskWeight;

/// One of his chronic conditions (a plain copy of a `conditions` row).
@immutable
class ConditionRef {
  const ConditionRef({required this.id, required this.name, this.active = true, this.color, this.notes, this.since});

  final String id;
  final String name;
  final bool active;
  final int? color;
  final String? notes;
  final DateTime? since;

  @override
  String toString() => 'ConditionRef($id, $name${active ? '' : ', inactive'})';
}

/// One rule the user wrote (a plain copy of a `food_rules` row, with the
/// matched food's current name resolved for convenience).
@immutable
class FoodRule {
  const FoodRule({
    required this.id,
    required this.target,
    required this.weight,
    this.conditionId,
    this.foodId,
    this.foodName,
    this.tag,
    this.minPortion,
    this.fromMinutes,
    this.toMinutes,
    this.maxPerDay,
    this.note,
    this.active = true,
  });

  final String id;

  /// The condition it speaks about, or null for a general rule.
  final String? conditionId;
  final FoodRuleTarget target;
  final String? foodId;

  /// The matched food's name as it reads today (resolved from the library;
  /// null when the rule matches a tag or anything).
  final String? foodName;

  /// The tag it matches (his own word).
  final String? tag;

  /// Only from this amount up, in the food's own unit.
  final double? minPortion;

  /// Only inside this wall-clock window (minutes after midnight); it wraps
  /// when `from > to` (22:00 → 06:00).
  final int? fromMinutes;
  final int? toMinutes;

  /// Set: the rule counts for a **day**, once the day holds more than this
  /// many matching entries. It never rates a single entry.
  final int? maxPerDay;
  final RiskWeight weight;

  /// His own wording, shown as the reason.
  final String? note;
  final bool active;

  /// A rule about the whole day rather than one entry.
  bool get isDayRule => maxPerDay != null;

  /// What this rule weighs: low 1, medium 2, high 3.
  int get points => weightPoints(weight);

  /// `"22:00–06:00"`, or null when the rule has no window.
  String? get windowLabel {
    final from = fromMinutes, to = toMinutes;
    if (from == null && to == null) return null;
    return '${BodyTimes.format(from ?? 0)}–${BodyTimes.format(to ?? 0)}';
  }

  static int weightPoints(RiskWeight w) => switch (w) {
    RiskWeight.low => 1,
    RiskWeight.medium => 2,
    RiskWeight.high => 3,
  };

  /// Whether the rule is usable at all: a tag rule needs a tag, a food rule
  /// needs a food. The editor uses this to block a half-written rule.
  bool get isComplete => switch (target) {
    FoodRuleTarget.tag => (tag?.trim().isNotEmpty ?? false),
    FoodRuleTarget.food => foodId != null,
    FoodRuleTarget.anyFood => true,
  };

  /// Whether the rule counts right now: it is switched on, complete, and
  /// either general or tied to a condition that is still active.
  bool appliesWith(Iterable<ConditionRef> conditions) {
    if (!active || !isComplete) return false;
    final id = conditionId;
    if (id == null) return true;
    final c = conditions.where((c) => c.id == id).firstOrNull;
    return c != null && c.active;
  }

  /// Whether this rule's *subject* matches [entry] – the food or the tag,
  /// ignoring the portion threshold and the time window ([gatesPass] checks
  /// those).
  ///
  /// [food] is the entry's library food, when it has one: its tags count
  /// along with the entry's own.
  bool matchesSubject(FoodEntry entry, {Food? food}) => switch (target) {
    FoodRuleTarget.anyFood => true,
    FoodRuleTarget.food =>
      (foodId != null && entry.foodId == foodId) ||
          (entry.foodId == null && FoodLookup.sameWord(foodName, entry.name)),
    FoodRuleTarget.tag => FoodLogStats.tagsFor(entry, food: food).any((t) => FoodLookup.sameWord(tag, t)),
  };

  /// Whether the portion threshold and the time window let the rule through.
  bool gatesPass(FoodEntry entry, {Food? food}) {
    final min = minPortion;
    if (min != null && !Portions.reaches(Portions.effective(entry.portion, food: food), min)) return false;
    return inWindow(entry.minuteOfDay);
  }

  /// Whether [minuteOfDay] is inside the rule's window (always true when it
  /// has none). A window that wraps midnight includes both sides.
  bool inWindow(int minuteOfDay) {
    final from = fromMinutes, to = toMinutes;
    if (from == null && to == null) return true;
    final a = from ?? 0;
    final b = to ?? 24 * 60;
    if (a <= b) return minuteOfDay >= a && minuteOfDay < b;
    return minuteOfDay >= a || minuteOfDay < b;
  }

  /// Whether the rule counts for [entry] (subject and gates, day rules
  /// excluded – they only ever rate a day).
  bool matches(FoodEntry entry, {Food? food}) =>
      !isDayRule && matchesSubject(entry, food: food) && gatesPass(entry, food: food);

  @override
  String toString() =>
      'FoodRule($id, ${target.name}${tag != null ? ' «$tag»' : ''}${foodName != null ? ' «$foodName»' : ''}, '
      '${weight.name}${isDayRule ? ', >$maxPerDay/day' : ''})';
}
