/// Her constraints: allergies, what to avoid, a special request for
/// tonight, who is eating, how much time there is – and the diet mode that
/// is **off** unless the owner turns it on.
///
/// Pure Dart (no Flutter, no database).
///
/// **The health rule.** Nothing in here is a diagnosis, a treatment or a
/// dose, and nothing in here reads his health data. A rule is her own word
/// plus who it is for; Madar holds a dish back and says which word did it.
/// «السفرة» knows about Part 4's meal plan only through [DietLink], which
/// the **caller** fills after the owner switches it on: the kitchen never
/// reaches into Health or Nutrition by itself.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../search/domain/search_text.dart';

/// One standing constraint of hers (a plain copy of a `kitchen_rules` row).
@immutable
class KitchenRule {
  const KitchenRule({
    required this.id,
    required this.kind,
    required this.term,
    this.who,
    this.note,
    this.active = true,
    this.sortOrder = 0,
  });

  final String id;
  final KitchenRuleKind kind;

  /// The word it is about – an ingredient name or one of her recipe tags.
  final String term;

  /// Who it is for, in her words.
  final String? who;
  final String? note;
  final bool active;
  final int sortOrder;

  String get word => SearchText.fold(term);

  /// An allergy or a request is a hard no; «avoid» is a soft no she can
  /// still override; «prefer» only nudges a dish up the list.
  bool get blocks => kind == KitchenRuleKind.allergy || kind == KitchenRuleKind.request;
  bool get discourages => kind == KitchenRuleKind.avoid;
  bool get encourages => kind == KitchenRuleKind.prefer;

  @override
  String toString() => 'KitchenRule(${kind.name}, $term${who == null ? '' : ' / $who'})';
}

/// Part 4's meal plan, as «السفرة» is willing to see it: a set of words to
/// prefer and a set to hold back, handed in from outside.
///
/// [off] is the default and the only thing a fresh install knows. When the
/// owner turns the tie-in on, the caller fills this from **his** plan; the
/// kitchen still only ever sees words.
@immutable
class DietLink {
  const DietLink({this.on = false, this.prefer = const [], this.avoid = const [], this.label});

  /// The default: «السفرة» knows nothing about his plan.
  static const DietLink off = DietLink();

  /// Whether the owner switched the tie-in on.
  final bool on;

  /// Words to nudge up the list (his planned foods).
  final List<String> prefer;

  /// Words to hold back, softly – never an allergy and never a dose.
  final List<String> avoid;

  /// What to call it on screen («خطة الأكل»).
  final String? label;

  bool get isEmpty => !on || (prefer.isEmpty && avoid.isEmpty);

  List<String> get preferWords => [
    for (final w in prefer)
      if (SearchText.fold(w).isNotEmpty) SearchText.fold(w),
  ];

  List<String> get avoidWords => [
    for (final w in avoid)
      if (SearchText.fold(w).isNotEmpty) SearchText.fold(w),
  ];
}

/// Everything she asked for, for one round of suggestions: her standing
/// rules plus tonight's choices.
@immutable
class KitchenConstraints {
  const KitchenConstraints({
    this.rules = const [],
    this.people,
    this.maxMinutes,
    this.mustTags = const [],
    this.diet = DietLink.off,
    this.ignoreNoRepeat = false,
    this.windowDays,
  });

  /// Nothing asked for – what the suggestions screen opens with.
  static const KitchenConstraints none = KitchenConstraints();

  /// Her standing rules (inactive ones are ignored).
  final List<KitchenRule> rules;

  /// How many are eating (null = she did not say, and then nothing is
  /// scaled).
  final int? people;

  /// How long she has, in minutes (null = no limit). A dish with no time
  /// written on it is **never** filtered out by this: Madar does not know
  /// how long it takes, so it does not pretend.
  final int? maxMinutes;

  /// Tags a dish must carry tonight («سريع»، «نباتي») – her words.
  final List<String> mustTags;

  /// Part 4's plan, off unless the owner turned it on.
  final DietLink diet;

  /// She asked to see the repeats too.
  final bool ignoreNoRepeat;

  /// Her no-repeat window for this round (null = the stored one).
  final int? windowDays;

  bool get isEmpty =>
      activeRules.isEmpty &&
      people == null &&
      maxMinutes == null &&
      mustTags.isEmpty &&
      diet.isEmpty &&
      !ignoreNoRepeat;

  List<KitchenRule> get activeRules => [
    for (final r in rules)
      if (r.active && r.word.isNotEmpty) r,
  ];

  List<String> get mustTagWords => [
    for (final t in mustTags)
      if (SearchText.fold(t).isNotEmpty) SearchText.fold(t),
  ];

  KitchenConstraints copyWith({
    List<KitchenRule>? rules,
    int? people,
    int? maxMinutes,
    List<String>? mustTags,
    DietLink? diet,
    bool? ignoreNoRepeat,
    int? windowDays,
    bool clearPeople = false,
    bool clearMinutes = false,
  }) => KitchenConstraints(
    rules: rules ?? this.rules,
    people: clearPeople ? null : (people ?? this.people),
    maxMinutes: clearMinutes ? null : (maxMinutes ?? this.maxMinutes),
    mustTags: mustTags ?? this.mustTags,
    diet: diet ?? this.diet,
    ignoreNoRepeat: ignoreNoRepeat ?? this.ignoreNoRepeat,
    windowDays: windowDays ?? this.windowDays,
  );
}

/// Why a dish was held back by a constraint, in a form a screen can read
/// as one sentence.
enum ConstraintBreach {
  /// An ingredient (or a tag) is on an allergy rule – a hard no.
  allergy,

  /// A special request for tonight says no.
  request,

  /// One of her «أفضل أبعد عنه» words.
  avoid,

  /// It takes longer than she has.
  tooLong,

  /// It does not carry a tag she asked for tonight.
  missingTag,

  /// His meal plan (only when the owner turned the tie-in on).
  diet,
}

/// One breach, with the word and the person behind it.
@immutable
class ConstraintHit {
  const ConstraintHit(this.breach, {this.term, this.who, this.rule});

  final ConstraintBreach breach;

  /// The word that did it, in her spelling.
  final String? term;

  /// Who it is for («أحمد»).
  final String? who;

  /// The rule it came from (null for a time or a tag breach).
  final KitchenRule? rule;

  /// A hard no: an allergy or a request. She can still override a soft one
  /// without being told twice.
  bool get hard => breach == ConstraintBreach.allergy || breach == ConstraintBreach.request;

  @override
  String toString() => 'ConstraintHit(${breach.name}${term == null ? '' : ', $term'})';
}
