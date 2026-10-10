/// What exists in his data right now, as names and ids the AI may refer to.
///
/// The catalogue does two jobs, and it is the same object for both:
///
/// 1. **Going out** – it travels inside the request ([PlanRequest]) so the
///    AI names *his* envelope, *his* food, *his* habit instead of inventing
///    one. Only the sections he chose to send are filled (an export without
///    Money carries no envelopes), and it holds names only: never a note,
///    never an amount he did not already share in the summary.
/// 2. **Coming back** – [PlanValidator] resolves every reference against
///    it, so a budget tweak on an envelope that does not exist, or a meal
///    change naming a food he never logged, is refused before he ever sees
///    an Apply button.
///
/// Pure Dart: the repository fills it from the database.
library;

import 'package:meta/meta.dart';

import 'health_guard.dart';

/// One thing he already has: its id, the name he gave it, and a short
/// human detail for the "what it is today" line.
@immutable
class PlanRef {
  const PlanRef({required this.id, required this.name, this.detail, this.extra = const {}});

  final String id;

  /// His own name for it.
  final String name;

  /// A short read-only description («٨٠ دينار شهري»، «٠٨:٠٠ كل يوم»).
  final String? detail;

  /// Structured facts the preview needs for the before/after (`amountMilli`,
  /// `percent`, `period`, `timeMinutes`, `active` …).
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'detail': ?detail};

  @override
  String toString() => 'PlanRef($id, $name)';
}

/// A named set of [PlanRef]s with id and name lookup.
@immutable
class PlanRefSet {
  PlanRefSet(List<PlanRef> refs)
    : refs = List.unmodifiable(refs),
      _byId = {for (final r in refs) r.id: r},
      _byName = {
        for (final r in refs.reversed) HealthGuard.fold(r.name): r,
      };

  static final PlanRefSet empty = PlanRefSet(const []);

  final List<PlanRef> refs;
  final Map<String, PlanRef> _byId;
  final Map<String, PlanRef> _byName;

  bool get isEmpty => refs.isEmpty;
  int get length => refs.length;

  /// Resolves [reference] as an id first, then as a name (Arabic spelling
  /// folded, case-insensitive). Null when he has no such thing.
  PlanRef? resolve(String? reference) {
    final raw = reference?.trim();
    if (raw == null || raw.isEmpty) return null;
    return _byId[raw] ?? _byName[HealthGuard.fold(raw)];
  }

  PlanRef? byId(String? id) => id == null ? null : _byId[id];

  /// The names, for the request (ids included so the AI can be exact).
  List<Map<String, Object?>> toJson() => [for (final r in refs) r.toJson()];
}

/// Everything the AI may point at, plus the few settings an item needs to
/// be checked against (today, the base currency).
@immutable
class PlanCatalog {
  PlanCatalog({
    required this.today,
    this.baseCurrency = '',
    this.currencyCodes = const {},
    PlanRefSet? budgetItems,
    PlanRefSet? wallets,
    PlanRefSet? foods,
    PlanRefSet? mealPlans,
    PlanRefSet? mealSlots,
    PlanRefSet? habits,
    PlanRefSet? conditions,
    PlanRefSet? labTests,
    PlanRefSet? projects,
    PlanRefSet? learningGoals,
    PlanRefSet? trackers,
    PlanRefSet? avoidItems,
    PlanRefSet? tasks,
  }) : budgetItems = budgetItems ?? PlanRefSet.empty,
       wallets = wallets ?? PlanRefSet.empty,
       foods = foods ?? PlanRefSet.empty,
       mealPlans = mealPlans ?? PlanRefSet.empty,
       mealSlots = mealSlots ?? PlanRefSet.empty,
       habits = habits ?? PlanRefSet.empty,
       conditions = conditions ?? PlanRefSet.empty,
       labTests = labTests ?? PlanRefSet.empty,
       projects = projects ?? PlanRefSet.empty,
       learningGoals = learningGoals ?? PlanRefSet.empty,
       trackers = trackers ?? PlanRefSet.empty,
       avoidItems = avoidItems ?? PlanRefSet.empty,
       tasks = tasks ?? PlanRefSet.empty;

  /// The day the request was built / the plan is checked against.
  final DateTime today;

  /// His base currency code (empty when Money was not shared).
  final String baseCurrency;

  /// Currency codes he has (a budget tweak may not name another one).
  final Set<String> currencyCodes;

  /// Money.
  final PlanRefSet budgetItems;
  final PlanRefSet wallets;

  /// Food and the meal plan.
  final PlanRefSet foods;
  final PlanRefSet mealPlans;
  final PlanRefSet mealSlots;

  /// Health and the body.
  final PlanRefSet habits;
  final PlanRefSet conditions;
  final PlanRefSet labTests;
  final PlanRefSet avoidItems;

  /// Work and growth.
  final PlanRefSet projects;
  final PlanRefSet learningGoals;

  /// His own trackers (custom modules).
  final PlanRefSet trackers;

  /// Open tasks (so a reminder can attach to one he already has).
  final PlanRefSet tasks;

  /// The catalogue as it travels in the request – only the non-empty sets.
  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    void add(String key, PlanRefSet set) {
      if (set.refs.isNotEmpty) out[key] = set.toJson();
    }

    if (baseCurrency.isNotEmpty) out['baseCurrency'] = baseCurrency;
    add('budgetItems', budgetItems);
    add('wallets', wallets);
    add('foods', foods);
    add('mealPlans', mealPlans);
    add('mealSlots', mealSlots);
    add('habits', habits);
    add('conditions', conditions);
    add('labTests', labTests);
    add('avoidItems', avoidItems);
    add('projects', projects);
    add('learningGoals', learningGoals);
    add('trackers', trackers);
    add('tasks', tasks);
    return out;
  }
}
