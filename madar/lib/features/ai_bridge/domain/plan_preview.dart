/// Turns a validated plan into exactly what the review screen needs, one
/// card per suggestion:
///
/// * what it would change – [PlanItemPreview.item] plus the records it
///   resolved to ([PlanItemPreview.targets]); `AiBridgeTexts.changeLines`
///   writes that as a sentence in his words;
/// * the reason the AI gave – `item.reason`, never empty;
/// * what it is today – [PlanItemPreview.before];
/// * whether it can be applied as it stands – [PlanItemPreview.status]
///   ([PlanItemStatus.needsEdit] when he has to choose something first,
///   [PlanItemStatus.blocked] while another suggestion it needs is not
///   approved yet);
/// * the one short line it adds to the plan's checklist –
///   [PlanItemPreview.oneLine].
///
/// Pure Dart: no database, no Flutter. The apply service reads the same
/// previews, so what he saw is exactly what gets written.
library;

import 'package:meta/meta.dart';

import 'health_guard.dart';
import 'plan_catalog.dart';
import 'plan_contract.dart';
import 'plan_problems.dart';
import 'plan_validator.dart';

/// Whether a suggestion can be applied, and if not why.
enum PlanItemStatus {
  /// Everything resolved: Apply is allowed.
  ready,

  /// He has to choose or fix something first (a day that has passed, an
  /// envelope set as a percentage while the AI gave an amount).
  needsEdit,

  /// Another suggestion of this plan has to be approved first.
  blocked,

  /// A kind this version keeps but cannot write yet (Part 5's kitchen).
  deferred,

  /// Refused by the validator; shown with its reasons, never applied.
  rejected,
}

/// Which existing record a suggestion points at.
enum PlanTargetSlot { food, slot, mealPlan, envelope, habit, project, owner, goal, tracker, lab }

/// What his data says today about the thing a suggestion touches.
enum PlanBeforeKind {
  /// Nothing like it yet.
  nothingYet,

  /// He has the habit, switched off.
  habitOff,

  /// He has the habit, already on.
  habitOn,

  /// The envelope's current amount / percentage.
  envelope,

  /// The meal's current time.
  slotTime,

  /// The food is already in his library.
  foodKnown,

  /// The food is already planned in that meal.
  foodInSlot,

  /// A learning goal with the same name.
  goal,

  /// A lab test with the same name.
  lab,

  /// A tracker with the same name.
  tracker,

  /// The line is already on his avoid list.
  avoidKnown,
}

/// The "before" half of the before/after.
@immutable
class PlanBefore {
  const PlanBefore(this.kind, {this.ref});

  static const PlanBefore nothing = PlanBefore(PlanBeforeKind.nothingYet);

  final PlanBeforeKind kind;

  /// The record it is about, with its current detail («٨٠ شهري»).
  final PlanRef? ref;

  Map<String, Object?> toJson() => {'kind': kind.name, if (ref != null) 'ref': ref!.toJson()};
}

/// Why a suggestion needs editing before it can apply.
enum PlanEditReason {
  /// The day it names has already passed.
  dayPassed,

  /// The envelope is set as a percentage and the plan gave an amount (or
  /// the other way round).
  envelopeMode,

  /// The food is not in his library yet and the plan does not add it.
  foodMissing,
}

/// One card of the review screen.
@immutable
class PlanItemPreview {
  const PlanItemPreview({
    required this.item,
    required this.status,
    this.problems = const [],
    this.targets = const {},
    this.before = PlanBefore.nothing,
    this.waitingFor = const [],
    this.editReasons = const [],
  });

  final PlanItem item;
  final PlanItemStatus status;

  /// Why it was refused, or what is odd about it. Empty for a clean item.
  final List<PlanProblem> problems;

  /// The records it resolved to (an envelope, a food, a meal …).
  final Map<PlanTargetSlot, PlanRef> targets;

  /// What it is today.
  final PlanBefore before;

  /// Ids of suggestions of the same plan that have to be approved first.
  final List<String> waitingFor;

  /// What he has to settle before Apply is allowed.
  final List<PlanEditReason> editReasons;

  String get id => item.id;
  PlanItemKind get kind => item.kind;

  /// The line the checklist shows: his own short sentence.
  String get oneLine => item.title;

  /// Whether Apply may be offered.
  bool get canApply => status == PlanItemStatus.ready;

  /// Whether it only ever becomes a checklist line (nothing else in his
  /// data changes).
  bool get isChecklistOnly => switch (kind) {
    PlanItemKind.task || PlanItemKind.note => true,
    PlanItemKind.reminder => targets[PlanTargetSlot.owner] == null,
    _ => false,
  };

  PlanRef? target(PlanTargetSlot slot) => targets[slot];

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': item.title,
    'reason': item.reason,
    'status': status.name,
    'checklistOnly': isChecklistOnly,
    'before': before.toJson(),
    if (waitingFor.isNotEmpty) 'waitingFor': waitingFor,
    if (editReasons.isNotEmpty) 'needsEdit': [for (final r in editReasons) r.name],
    if (problems.isNotEmpty) 'problems': [for (final p in problems) p.toJson()],
    if (targets.isNotEmpty)
      'targets': {for (final MapEntry(:key, :value) in targets.entries) key.name: value.toJson()},
  };
}

/// Builds one [PlanItemPreview] per item of a validated plan.
class PlanPreviewBuilder {
  PlanPreviewBuilder(this.catalog);

  final PlanCatalog catalog;

  /// Previews every item of [validation] in the plan's own order.
  /// [appliedIds] are the suggestions of this plan he has already approved
  /// (so a blocked item unblocks once its dependency is applied).
  List<PlanItemPreview> build(PlanValidation validation, {Set<String> appliedIds = const {}}) {
    final plan = validation.plan;
    if (plan == null) return const [];
    return [
      for (final item in plan.items) one(item, validation, plan: plan, appliedIds: appliedIds),
    ];
  }

  PlanItemPreview one(
    PlanItem item,
    PlanValidation validation, {
    required MadarPlan plan,
    Set<String> appliedIds = const {},
  }) {
    final problems = validation.problemsFor(item.id);
    final rejected = problems.any((p) => p.rejects);
    final targets = <PlanTargetSlot, PlanRef>{};
    final edits = <PlanEditReason>[];
    final waiting = <String>[];
    var before = PlanBefore.nothing;

    PlanRef? pick(PlanTargetSlot slot, String key, PlanRefSet set) {
      final ref = set.resolve(item.str(key));
      if (ref != null) targets[slot] = ref;
      return ref;
    }

    /// A food of the plan itself the item points at (not his library yet).
    PlanItem? localItem(String? reference, bool Function(PlanItem) matches) {
      if (reference == null) return null;
      final folded = HealthGuard.fold(reference);
      for (final other in plan.items) {
        if (other.id == item.id || !matches(other)) continue;
        if (other.id == reference || HealthGuard.fold(other.title) == folded) return other;
      }
      return null;
    }

    switch (item.kind) {
      case PlanItemKind.task:
        final day = item.str('day');
        final parsed = day == null ? null : planParseDay(day);
        if (parsed != null && parsed.isBefore(_today)) edits.add(PlanEditReason.dayPassed);
        pick(PlanTargetSlot.project, 'projectRef', catalog.projects);
      case PlanItemKind.habit:
        final existing = pick(PlanTargetSlot.habit, 'existingRef', catalog.habits) ?? _sameName(catalog.habits, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.habit] = existing;
          final active = existing.extra['active'] != false;
          before = PlanBefore(active ? PlanBeforeKind.habitOn : PlanBeforeKind.habitOff, ref: existing);
        }
      case PlanItemKind.routine:
        final existing = _sameName(catalog.habits, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.habit] = existing;
          before = PlanBefore(
            existing.extra['active'] != false ? PlanBeforeKind.habitOn : PlanBeforeKind.habitOff,
            ref: existing,
          );
        }
      case PlanItemKind.reminder:
        final owner = item.data['ownerRef'];
        if (owner is Map) {
          final table = owner['table'], id = owner['id'];
          if (table is String && id is String) {
            final ref = _ownerSet(table)?.resolve(id);
            if (ref != null) targets[PlanTargetSlot.owner] = ref;
          }
        }
      case PlanItemKind.note:
        break;
      case PlanItemKind.food:
        final existing = _sameName(catalog.foods, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.food] = existing;
          before = PlanBefore(PlanBeforeKind.foodKnown, ref: existing);
        }
      case PlanItemKind.mealChange:
        final slot = pick(PlanTargetSlot.slot, 'slotRef', catalog.mealSlots);
        pick(PlanTargetSlot.mealPlan, 'planRef', catalog.mealPlans);
        final food = pick(PlanTargetSlot.food, 'foodRef', catalog.foods);
        if (food == null && (item.str('foodRef') != null)) {
          final local = localItem(item.str('foodRef'), (o) => o.kind == PlanItemKind.food);
          if (local == null) {
            edits.add(PlanEditReason.foodMissing);
          } else if (!appliedIds.contains(local.id)) {
            waiting.add(local.id);
          }
        }
        if (slot != null) {
          before = PlanBefore(
            item.str('op') == 'moveSlot' ? PlanBeforeKind.slotTime : PlanBeforeKind.foodInSlot,
            ref: slot,
          );
        }
      case PlanItemKind.avoidItem:
        final existing = _sameName(catalog.avoidItems, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.food] = existing;
          before = PlanBefore(PlanBeforeKind.avoidKnown, ref: existing);
        }
      case PlanItemKind.trackedSign:
        final existing = _sameName(catalog.trackers, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.tracker] = existing;
          before = PlanBefore(PlanBeforeKind.tracker, ref: existing);
        }
      case PlanItemKind.labTracker:
        final existing = _sameName(catalog.labTests, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.lab] = existing;
          before = PlanBefore(PlanBeforeKind.lab, ref: existing);
        }
      case PlanItemKind.budgetTweak:
        final envelope = pick(PlanTargetSlot.envelope, 'envelopeRef', catalog.budgetItems);
        if (envelope != null) {
          before = PlanBefore(PlanBeforeKind.envelope, ref: envelope);
          final mode = envelope.extra['mode'];
          final givesAmount = item.number('newAmount') != null;
          if (mode == 'percent' && givesAmount) edits.add(PlanEditReason.envelopeMode);
          if (mode == 'amount' && !givesAmount) edits.add(PlanEditReason.envelopeMode);
        }
      case PlanItemKind.learningProgram:
        final existing = _sameName(catalog.learningGoals, item.title);
        if (existing != null) {
          targets[PlanTargetSlot.goal] = existing;
          before = PlanBefore(PlanBeforeKind.goal, ref: existing);
        }
      case PlanItemKind.recipe:
      case PlanItemKind.pantryItem:
        break;
    }

    // Dependencies the AI declared, on top of the ones we worked out.
    for (final dep in item.dependsOn) {
      if (!appliedIds.contains(dep) && !waiting.contains(dep)) waiting.add(dep);
    }

    final status = rejected
        ? PlanItemStatus.rejected
        : !item.kind.isApplicable
        ? PlanItemStatus.deferred
        : waiting.isNotEmpty
        ? PlanItemStatus.blocked
        : edits.isNotEmpty
        ? PlanItemStatus.needsEdit
        : PlanItemStatus.ready;

    return PlanItemPreview(
      item: item,
      status: status,
      problems: problems,
      targets: Map.unmodifiable(targets),
      before: before,
      waitingFor: List.unmodifiable(waiting),
      editReasons: List.unmodifiable(edits),
    );
  }

  DateTime get _today => DateTime(catalog.today.year, catalog.today.month, catalog.today.day);

  PlanRef? _sameName(PlanRefSet set, String name) => set.resolve(name);

  PlanRefSet? _ownerSet(String table) => switch (table) {
    'habits' => catalog.habits,
    'custom_modules' => catalog.trackers,
    'learning_goals' => catalog.learningGoals,
    'meal_slots' => catalog.mealSlots,
    _ => null,
  };
}
