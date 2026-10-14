import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/import/sha256.dart';
import '../../custom_modules/domain/module_templates.dart' show ModuleTemplates;
import '../domain/plan_catalog.dart';
import '../domain/plan_contract.dart';
import '../domain/plan_preview.dart';
import '../domain/plan_problems.dart';
import '../domain/plan_validator.dart';

/// Reverses one decision (the UI wraps it in an undo toast), exactly like
/// `NutritionUndo` and `TaskUndo`.
typedef PlanUndo = Future<void> Function();

/// What one payload became: the history row, the problems, and one preview
/// per suggestion.
class PlanImport {
  PlanImport({
    required this.validation,
    required this.previews,
    this.plan,
    this.isNew = false,
    this.states = const {},
  });

  /// Nothing usable arrived (not a plan, a newer version, no items): the
  /// problems say why, in codes the UI reads out in Arabic.
  factory PlanImport.refused(PlanValidation validation) => PlanImport(validation: validation, previews: const []);

  /// The stored plan, or null when the payload was refused outright.
  final AppliedPlanRow? plan;

  final PlanValidation validation;

  /// One card per suggestion, in the plan's own order.
  final List<PlanItemPreview> previews;

  /// False when this exact answer had already been imported (his earlier
  /// decisions are in [states]).
  final bool isNew;

  /// Suggestion id → what he decided before, for a re-import.
  final Map<String, PlanItemState> states;

  List<PlanProblem> get problems => validation.problems;

  bool get isUsable => plan != null && previews.isNotEmpty;

  PlanItemPreview? preview(String itemId) {
    for (final p in previews) {
      if (p.id == itemId) return p;
    }
    return null;
  }
}

/// How many of a plan's approved suggestions he has ticked off.
class PlanProgress {
  const PlanProgress({required this.done, required this.total});

  static const PlanProgress none = PlanProgress(done: 0, total: 0);

  final int done;
  final int total;

  bool get isComplete => total > 0 && done == total;
  double get fraction => total == 0 ? 0 : done / total;
}

/// One applied suggestion plus its undo.
class PlanApplyOutcome {
  const PlanApplyOutcome({required this.row, required this.undo, this.alreadyApplied = false});

  final AppliedPlanItemRow row;

  /// Puts his data – and the history row – back exactly as they were.
  final PlanUndo undo;

  /// True when this suggestion had already been applied: nothing was
  /// written this time (applying twice changes nothing).
  final bool alreadyApplied;
}

/// Thrown when a caller asks for something the engine must not do: ticking
/// a suggestion he never approved, or applying one the validator refused.
class PlanApplyRefused implements Exception {
  PlanApplyRefused(this.reason);

  final String reason;

  @override
  String toString() => 'PlanApplyRefused: $reason';
}

/// The import engine's writes.
///
/// ## What the review UI builds on
///
/// * [take] – text in (a picked file, a share intent, a paste), a
///   [PlanImport] out: the problems, one [PlanItemPreview] per suggestion,
///   and the stored plan. Importing stores nothing of his: the suggestions
///   are `pending` rows of the plan's own tables until he decides.
/// * [applyItem] – **one** suggestion at a time, only when
///   [PlanItemPreview.canApply]. Idempotent (the second call writes
///   nothing) and it returns an undo closure. There is deliberately no
///   "apply all": approval is per item, by hand.
/// * [reopen] – the same previews again for a plan already in the history,
///   measured against his data as it is now (call it after every apply, and
///   to open an old plan from the history).
/// * [rejectItem] – he said no; also undoable.
/// * [watchChecklist] / [checklist] – the suggestions he approved, in
///   order, as the list he ticks off.
/// * [setDone] – tick or untick one line, with an undo. Only an approved
///   line can be ticked ([PlanApplyRefused] otherwise).
/// * [watchProgress] / [progress] – «٢ من ٤».
/// * [rename] – his own name for the list.
/// * [watchPlans] / [plans] – the history, newest first.
///
/// Nothing in here writes to `tasks`: an approved suggestion is a line of
/// the plan's checklist, never a task of the home panel.
class PlanApplyService {
  PlanApplyService(this.repos, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  // ------------------------------------------------------------------ take --

  /// Validates [text] against [catalog] and, when there is anything to
  /// review, stores (or finds) the plan and its suggestions as `pending`.
  ///
  /// [name] is his own name for the list; the caller passes the localised
  /// default («خطة ١٠ تشرين الأول»).
  Future<PlanImport> take(
    String text, {
    required PlanCatalog catalog,
    required PlanOrigin origin,
    required String name,
  }) async {
    final validation = PlanValidator(catalog).parse(text);
    final plan = validation.plan;
    if (plan == null) return PlanImport.refused(validation);

    final key = Sha256.ofString(plan.canonical());
    final existing = (await repos.appliedPlans.getAll(where: (t) => t.planKey.equals(key))).firstOrNull;
    final states = existing == null ? const <String, PlanItemState>{} : await this.states(existing.id);
    final previews = PlanPreviewBuilder(catalog).build(
      validation,
      appliedIds: {
        for (final MapEntry(:key, :value) in states.entries)
          if (value == PlanItemState.applied) key,
      },
    );
    // A plan and its suggestions arrive together or not at all.
    final row = existing ??
        await repos.db.transaction(() async {
          final created = await _insertPlan(plan, key: key, origin: origin, name: name, raw: text);
          await _insertItems(created.id, previews);
          return created;
        });
    return PlanImport(
      plan: row,
      validation: validation,
      previews: previews,
      isNew: existing == null,
      states: states,
    );
  }

  /// Re-reads a plan already in the history (its original payload is kept
  /// in [AppliedPlanRow.raw]) and previews it against his data **as it is
  /// now**: what he has already approved is marked applied, and a
  /// suggestion that was waiting for another one is ready once that one is
  /// in. The review screen calls this after every apply, and the history
  /// screen calls it to open an old plan.
  Future<PlanImport> reopen(AppliedPlanRow plan, {required PlanCatalog catalog}) async {
    final validation = PlanValidator(catalog).parse(plan.raw);
    if (validation.plan == null) {
      return PlanImport(plan: plan, validation: validation, previews: const [], states: await states(plan.id));
    }
    final decided = await states(plan.id);
    final previews = PlanPreviewBuilder(catalog).build(
      validation,
      appliedIds: {
        for (final MapEntry(:key, :value) in decided.entries)
          if (value == PlanItemState.applied) key,
      },
    );
    return PlanImport(plan: plan, validation: validation, previews: previews, states: decided);
  }

  Future<AppliedPlanRow> _insertPlan(
    MadarPlan plan, {
    required String key,
    required PlanOrigin origin,
    required String name,
    required String raw,
  }) => repos.appliedPlans.insert(
    AppliedPlansCompanion.insert(
      planKey: key,
      name: name.trim().isEmpty ? key.substring(0, 8) : name.trim(),
      raw: raw,
      formatVersion: Value(plan.version),
      title: Value(plan.title),
      summary: Value(plan.summary),
      origin: Value(origin),
      source: Value(plan.source.isEmpty ? const {} : plan.source.toJson()),
      importedAt: Value(clock()),
      itemCount: Value(plan.items.length),
    ),
  );

  Future<void> _insertItems(String planId, List<PlanItemPreview> previews) async {
    for (var i = 0; i < previews.length; i++) {
      final p = previews[i];
      await repos.appliedPlanItems.insert(
        AppliedPlanItemsCompanion.insert(
          planId: planId,
          itemKey: p.id,
          kind: p.kind.name,
          title: p.item.title,
          reason: p.item.reason,
          state: Value(
            p.status == PlanItemStatus.rejected
                ? PlanItemState.rejected
                : p.status == PlanItemStatus.deferred
                ? PlanItemState.deferred
                : PlanItemState.pending,
          ),
          payload: Value(p.item.map),
          beforeJson: Value(p.before.toJson()),
          sortOrder: Value(i),
        ),
      );
    }
  }

  // ----------------------------------------------------------------- reads --

  Future<List<AppliedPlanRow>> plans() async {
    final rows = await repos.appliedPlans.getAll();
    return rows..sort((a, b) => b.importedAt.compareTo(a.importedAt));
  }

  Stream<List<AppliedPlanRow>> watchPlans() => repos.appliedPlans.watchAll().map(
    (rows) => rows..sort((a, b) => b.importedAt.compareTo(a.importedAt)),
  );

  Future<AppliedPlanRow?> planById(String id) => repos.appliedPlans.byId(id);

  /// Every suggestion row of a plan, in the plan's own order.
  Future<List<AppliedPlanItemRow>> items(String planId) =>
      repos.appliedPlanItems.getAll(where: (t) => t.planId.equals(planId));

  Stream<List<AppliedPlanItemRow>> watchItems(String planId) =>
      repos.appliedPlanItems.watchAll(where: (t) => t.planId.equals(planId));

  /// The checklist: only what he approved.
  Future<List<AppliedPlanItemRow>> checklist(String planId) async => _approved(await items(planId));

  Stream<List<AppliedPlanItemRow>> watchChecklist(String planId) => watchItems(planId).map(_approved);

  static List<AppliedPlanItemRow> _approved(List<AppliedPlanItemRow> rows) => [
    for (final r in rows)
      if (r.state == PlanItemState.applied) r,
  ];

  Future<PlanProgress> progress(String planId) async => _progress(await items(planId));

  Stream<PlanProgress> watchProgress(String planId) => watchItems(planId).map(_progress);

  static PlanProgress _progress(List<AppliedPlanItemRow> rows) {
    final approved = _approved(rows);
    return PlanProgress(done: approved.where((r) => r.done).length, total: approved.length);
  }

  /// What he decided about each suggestion of a plan.
  Future<Map<String, PlanItemState>> states(String planId) async => {
    for (final r in await items(planId)) r.itemKey: r.state,
  };

  Future<AppliedPlanItemRow?> itemRow(String planId, String itemKey) async =>
      (await repos.appliedPlanItems.getAll(
        where: (t) => t.planId.equals(planId) & t.itemKey.equals(itemKey),
      )).firstOrNull;

  // ---------------------------------------------------------------- decide --

  /// Applies **one** approved suggestion.
  ///
  /// Idempotent: a second call on an already applied suggestion writes
  /// nothing and returns [PlanApplyOutcome.alreadyApplied]. The returned
  /// undo restores his data and the history row together.
  Future<PlanApplyOutcome> applyItem(AppliedPlanRow plan, PlanItemPreview preview) async {
    if (!preview.canApply) {
      throw PlanApplyRefused('${preview.id}: ${preview.status.name}');
    }
    final existing = await itemRow(plan.id, preview.id);
    if (existing != null && existing.state == PlanItemState.applied) {
      return PlanApplyOutcome(row: existing, undo: () async {}, alreadyApplied: true);
    }
    final now = clock();
    // One suggestion is one write: his data and the history row land
    // together, so a failure half-way leaves nothing behind.
    final (effect, row) = await repos.db.transaction(() async {
      final written = await _write(plan, preview);
      final stored = await _settle(
        plan,
        preview,
        state: PlanItemState.applied,
        refTable: written.table,
        refId: written.id,
        after: written.after,
        at: now,
      );
      return (written, stored);
    });
    return PlanApplyOutcome(
      row: row,
      undo: () async => repos.db.transaction(() async {
        await effect.undo();
        await _settle(plan, preview, state: PlanItemState.undone, at: now, clearDone: true);
      }),
    );
  }

  /// He said no. Undoable, and it writes nothing to his data.
  Future<PlanUndo> rejectItem(AppliedPlanRow plan, PlanItemPreview preview) async {
    final before = await itemRow(plan.id, preview.id);
    await _settle(plan, preview, state: PlanItemState.rejected, at: clock());
    return () async {
      if (before != null) await repos.appliedPlanItems.update(before);
    };
  }

  /// Ticks ([done] true) or unticks one line of the checklist.
  ///
  /// Only an approved suggestion can be ticked: anything else throws
  /// [PlanApplyRefused], and nothing is written.
  Future<PlanUndo> setDone(AppliedPlanItemRow row, bool done) async {
    final current = await repos.appliedPlanItems.byId(row.id) ?? row;
    if (current.state != PlanItemState.applied) {
      throw PlanApplyRefused('${current.itemKey}: ${current.state.name} is not on the checklist');
    }
    if (current.done == done) {
      return () async {};
    }
    await repos.appliedPlanItems.setColumns(current.id, {'done': done, 'doneAt': done ? clock() : null});
    return () async =>
        repos.appliedPlanItems.setColumns(current.id, {'done': current.done, 'doneAt': current.doneAt});
  }

  /// His own name for the list.
  Future<PlanUndo> rename(AppliedPlanRow plan, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw PlanApplyRefused('empty name');
    await repos.appliedPlans.setColumns(plan.id, {'name': trimmed});
    return () async => repos.appliedPlans.setColumns(plan.id, {'name': plan.name});
  }

  Future<AppliedPlanItemRow> _settle(
    AppliedPlanRow plan,
    PlanItemPreview preview, {
    required PlanItemState state,
    required DateTime at,
    String? refTable,
    String? refId,
    Map<String, Object?> after = const {},
    bool clearDone = false,
  }) async {
    final existing = await itemRow(plan.id, preview.id);
    if (existing == null) {
      return repos.appliedPlanItems.insert(
        AppliedPlanItemsCompanion.insert(
          planId: plan.id,
          itemKey: preview.id,
          kind: preview.kind.name,
          title: preview.item.title,
          reason: preview.item.reason,
          state: Value(state),
          payload: Value(preview.item.map),
          beforeJson: Value(preview.before.toJson()),
          afterJson: Value(after),
          refTable: Value(refTable),
          refId: Value(refId),
          decidedAt: Value(at),
        ),
      );
    }
    await repos.appliedPlanItems.setColumns(existing.id, {
      'state': state,
      'decidedAt': at,
      'refTable': refTable,
      'refId': refId,
      'afterJson': after,
      if (clearDone) 'done': false,
      if (clearDone) 'doneAt': null,
    });
    return (await repos.appliedPlanItems.byId(existing.id))!;
  }

  // ----------------------------------------------------------- the writes --

  Future<_Effect> _write(AppliedPlanRow plan, PlanItemPreview p) async {
    final item = p.item;
    switch (item.kind) {
      // Checklist-only kinds: the line he ticks off IS the change.
      case PlanItemKind.task:
      case PlanItemKind.note:
        return _Effect.checklist();
      case PlanItemKind.reminder:
        final owner = p.target(PlanTargetSlot.owner);
        if (owner == null) return _Effect.checklist();
        final table = (item.data['ownerRef'] as Map?)?['table'] as String? ?? 'habits';
        final row = await repos.reminders.insert(
          RemindersCompanion.insert(
            ownerTable: table,
            ownerId: owner.id,
            title: Value(item.title),
            rule: _reminderRule(item),
          ),
        );
        return _Effect(
          table: 'reminders',
          id: row.id,
          after: {'ownerTable': table, 'ownerId': owner.id, 'rule': row.rule},
          undo: () async => repos.reminders.delete(row.id).then((_) {}),
        );

      case PlanItemKind.habit:
      case PlanItemKind.routine:
        final existing = p.target(PlanTargetSlot.habit);
        if (existing != null) {
          final wasActive = existing.extra['active'] != false;
          await repos.habits.setColumns(existing.id, {'active': true});
          final reminders = item.kind == PlanItemKind.routine ? await _routineReminders(item, existing.id) : <String>[];
          return _Effect(
            table: 'habits',
            id: existing.id,
            after: {'active': true, if (reminders.isNotEmpty) 'reminderIds': reminders},
            undo: () async {
              for (final id in reminders) {
                await repos.reminders.delete(id);
              }
              await repos.habits.setColumns(existing.id, {'active': wasActive});
            },
          );
        }
        final row = await repos.habits.insert(
          HabitsCompanion.insert(
            name: item.title,
            category: Value(item.str('category') ?? 'stress'),
            planetKey: Value(item.str('planetKey') ?? item.area),
          ),
        );
        final reminders = item.kind == PlanItemKind.routine ? await _routineReminders(item, row.id) : <String>[];
        return _Effect(
          table: 'habits',
          id: row.id,
          after: {'name': row.name, if (reminders.isNotEmpty) 'reminderIds': reminders},
          undo: () async {
            for (final id in reminders) {
              await repos.reminders.delete(id);
            }
            await repos.habits.delete(row.id);
          },
        );

      case PlanItemKind.food:
        final existing = p.target(PlanTargetSlot.food);
        if (existing != null && !existing.id.startsWith('logged:')) {
          final before = await repos.foods.byId(existing.id);
          await repos.foods.setColumns(existing.id, {
            'tags': item.strings('tags').isEmpty ? (before?.tags ?? const <String>[]) : item.strings('tags'),
            'defaultPortion': item.number('portion') ?? before?.defaultPortion,
            'unit': item.str('unit') ?? before?.unit,
          });
          return _Effect(
            table: 'foods',
            id: existing.id,
            after: {'updated': true},
            undo: () async {
              if (before != null) await repos.foods.update(before);
            },
          );
        }
        final row = await repos.foods.insert(
          FoodsCompanion.insert(
            name: item.title,
            tags: Value(item.strings('tags')),
            defaultPortion: Value(item.number('portion')),
            unit: Value(item.str('unit')),
            notes: Value(item.str('notes')),
          ),
        );
        return _Effect(
          table: 'foods',
          id: row.id,
          after: {'name': row.name},
          undo: () async => repos.foods.delete(row.id).then((_) {}),
        );

      case PlanItemKind.mealChange:
        return _mealChange(plan, p);

      case PlanItemKind.avoidItem:
        final existing = p.target(PlanTargetSlot.food);
        if (existing != null) {
          final before = await repos.avoidItems.byId(existing.id);
          await repos.avoidItems.setColumns(existing.id, {'reason': item.reason});
          return _Effect(
            table: 'avoid_items',
            id: existing.id,
            after: {'reason': item.reason},
            undo: () async {
              if (before != null) await repos.avoidItems.update(before);
            },
          );
        }
        final row = await repos.avoidItems.insert(
          AvoidItemsCompanion.insert(body: item.title, reason: Value(item.reason)),
        );
        return _Effect(
          table: 'avoid_items',
          id: row.id,
          after: {'body': row.body},
          undo: () async => repos.avoidItems.delete(row.id).then((_) {}),
        );

      case PlanItemKind.trackedSign:
        final existing = p.target(PlanTargetSlot.tracker);
        if (existing != null) {
          return _Effect(table: 'custom_modules', id: existing.id, after: {'existing': true}, undo: () async {});
        }
        final zeroToTen = item.str('scale') == 'zeroToTen';
        // A sign to watch lives on the planet the item named (its `area`),
        // and on Health when it named none.
        final planet = item.area ?? 'health';
        final row = await repos.customModules.insert(
          CustomModulesCompanion.insert(
            name: item.title,
            kind: const Value(CustomModuleKind.tracker),
            planetKey: Value(planet),
            color: ModuleTemplates.planetColors[planet] ?? ModuleTemplates.planetColors['health']!,
            fields: Value([
              {
                'id': 'f1',
                'label': item.title,
                'type': zeroToTen ? FieldType.number.name : FieldType.checkbox.name,
                'unit': ?item.str('unit'),
                if (zeroToTen) 'min': 0,
                if (zeroToTen) 'max': 10,
              },
            ]),
          ),
        );
        return _Effect(
          table: 'custom_modules',
          id: row.id,
          after: {'name': row.name, 'scale': item.str('scale')},
          undo: () async => repos.customModules.delete(row.id).then((_) {}),
        );

      case PlanItemKind.labTracker:
        final existing = p.target(PlanTargetSlot.lab);
        if (existing != null) {
          final before = await repos.labTests.byId(existing.id);
          await repos.labTests.setColumns(existing.id, {
            'unit': item.str('unit') ?? before?.unit,
            'low': item.number('low') ?? before?.low,
            'high': item.number('high') ?? before?.high,
          });
          return _Effect(
            table: 'lab_tests',
            id: existing.id,
            after: {'updated': true},
            undo: () async {
              if (before != null) await repos.labTests.update(before);
            },
          );
        }
        final row = await repos.labTests.insert(
          LabTestsCompanion.insert(
            name: item.title,
            unit: Value(item.str('unit')),
            low: Value(item.number('low')),
            high: Value(item.number('high')),
            category: Value(item.str('category')),
          ),
        );
        return _Effect(
          table: 'lab_tests',
          id: row.id,
          after: {'name': row.name},
          undo: () async => repos.labTests.delete(row.id).then((_) {}),
        );

      case PlanItemKind.budgetTweak:
        final envelope = p.target(PlanTargetSlot.envelope)!;
        final before = await repos.budgetItems.byId(envelope.id);
        if (before == null) throw PlanApplyRefused('${envelope.id}: gone');
        final amount = item.number('newAmount');
        final percent = item.number('newPercent');
        final period = item.str('period');
        await repos.budgetItems.setColumns(envelope.id, {
          if (amount != null) 'amountMilli': (amount * 1000).round(),
          'percent': ?percent,
          if (period != null) 'period': period == 'weekly' ? BudgetPeriod.weekly : BudgetPeriod.monthly,
          'currency': ?item.str('currency'),
        });
        return _Effect(
          table: 'budget_items',
          id: envelope.id,
          after: {
            if (amount != null) 'amountMilli': (amount * 1000).round(),
            'percent': ?percent,
            'period': period ?? before.period.name,
          },
          undo: () async => repos.budgetItems.update(before),
        );

      case PlanItemKind.learningProgram:
        final existing = p.target(PlanTargetSlot.goal);
        if (existing != null) {
          final before = await repos.learningGoals.byId(existing.id);
          await repos.learningGoals.setColumns(existing.id, {
            'active': true,
            if (item.number('target') != null) 'target': item.number('target'),
            if (item.str('unit') != null) 'unit': item.str('unit'),
          });
          return _Effect(
            table: 'learning_goals',
            id: existing.id,
            after: {'updated': true},
            undo: () async {
              if (before != null) await repos.learningGoals.update(before);
            },
          );
        }
        final steps = item.maps('steps');
        final deadline = item.str('deadline');
        final row = await repos.learningGoals.insert(
          LearningGoalsCompanion.insert(
            name: item.title,
            target: item.number('target') ?? (steps.isEmpty ? 1 : steps.length).toDouble(),
            unit: Value(item.str('unit') ?? ''),
            deadline: Value(deadline == null ? null : planParseDay(deadline)),
          ),
        );
        return _Effect(
          table: 'learning_goals',
          id: row.id,
          after: {'name': row.name, 'steps': steps.length},
          undo: () async => repos.learningGoals.delete(row.id).then((_) {}),
        );

      case PlanItemKind.recipe:
        return _recipe(plan, p);

      case PlanItemKind.pantryItem:
        return _pantryItem(p);
    }
  }

  /// A dish into «السفرة».
  ///
  /// A dish she already has by that name is **never overwritten**: only the
  /// facts she left empty are filled in (servings, minutes, the method, the
  /// notes), and her ingredient list is touched only when it is empty. The
  /// undo restores the row exactly and removes anything that was added.
  ///
  /// A new dish is stored with its source set to `ai` and the plan's name
  /// as `sourceName`, so she always knows this recipe came from an AI
  /// answer and not from her aunt.
  Future<_Effect> _recipe(AppliedPlanRow plan, PlanItemPreview p) async {
    final item = p.item;
    final ingredients = item.maps('ingredients');
    final steps = item.strings('steps');
    final servings = item.integer('servings');
    final minutes = item.integer('minutes');
    final existing = p.target(PlanTargetSlot.recipe);

    RecipeIngredientsCompanion line(String recipeId, Map<String, Object?> m) {
      final name = m['name'];
      final quantity = m['quantity'];
      final unit = m['unit'];
      final note = m['note'];
      return RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        name: name is String ? name.trim() : '',
        quantity: Value(quantity is num && quantity.isFinite ? quantity.toDouble() : null),
        unit: Value(unit is String && unit.trim().isNotEmpty ? unit.trim() : null),
        optional: Value(m['optional'] == true),
        note: Value(note is String && note.trim().isNotEmpty ? note.trim() : null),
      );
    }

    if (existing != null) {
      final before = await repos.recipes.byId(existing.id);
      if (before == null) throw PlanApplyRefused('${existing.id}: gone');
      final had = await repos.recipeIngredients.getAll(where: (t) => t.recipeId.equals(existing.id));
      await repos.recipes.setColumns(existing.id, {
        if (before.steps.isEmpty && steps.isNotEmpty) 'steps': steps,
        if (before.servings == null && servings != null) 'servings': servings,
        if (before.minutes == null && minutes != null) 'minutes': minutes,
        if (before.tags.isEmpty && item.strings('tags').isNotEmpty) 'tags': item.strings('tags'),
        if (before.notes == null && item.str('notes') != null) 'notes': item.str('notes'),
      });
      final added = <String>[];
      if (had.isEmpty) {
        for (final m in ingredients) {
          final row = await repos.recipeIngredients.insert(line(existing.id, m));
          added.add(row.id);
        }
      }
      return _Effect(
        table: 'recipes',
        id: existing.id,
        after: {'updated': true, 'ingredientsAdded': added.length},
        undo: () async {
          for (final id in added) {
            await repos.recipeIngredients.delete(id);
          }
          await repos.recipes.update(before);
        },
      );
    }

    final row = await repos.recipes.insert(
      RecipesCompanion.insert(
        name: item.title,
        steps: Value(steps),
        servings: Value(servings),
        minutes: Value(minutes),
        tags: Value(item.strings('tags')),
        notes: Value(item.str('notes')),
        source: const Value(RecipeSource.ai),
        sourceName: Value(plan.name),
      ),
    );
    for (final m in ingredients) {
      await repos.recipeIngredients.insert(line(row.id, m));
    }
    return _Effect(
      table: 'recipes',
      id: row.id,
      after: {'name': row.name, 'ingredients': ingredients.length, 'steps': steps.length},
      undo: () async {
        await repos.recipeIngredients.deleteWhere((t) => t.recipeId.equals(row.id));
        await repos.recipes.delete(row.id);
      },
    );
  }

  /// A thing into the house. Something already there has its amount, unit,
  /// place and expiry set to what the suggestion says; the undo restores
  /// the row exactly.
  Future<_Effect> _pantryItem(PlanItemPreview p) async {
    final item = p.item;
    final quantity = item.number('quantity');
    final unit = item.str('unit');
    final place = item.str('place');
    final expires = item.str('expires');
    final day = expires == null ? null : planParseDay(expires);
    final existing = p.target(PlanTargetSlot.pantryItem);

    if (existing != null) {
      final before = await repos.pantryItems.byId(existing.id);
      if (before == null) throw PlanApplyRefused('${existing.id}: gone');
      await repos.pantryItems.setColumns(existing.id, {
        'quantity': ?quantity,
        'unit': ?unit,
        'place': ?place,
        'expires': ?day,
        'note': ?item.str('notes'),
      });
      return _Effect(
        table: 'pantry_items',
        id: existing.id,
        after: {'updated': true},
        undo: () async => repos.pantryItems.update(before),
      );
    }

    final row = await repos.pantryItems.insert(
      PantryItemsCompanion.insert(
        name: item.title,
        quantity: Value(quantity),
        unit: Value(unit),
        place: Value(place),
        expires: Value(day),
        note: Value(item.str('notes')),
      ),
    );
    return _Effect(
      table: 'pantry_items',
      id: row.id,
      after: {'name': row.name, 'quantity': ?quantity, 'unit': ?unit},
      undo: () async => repos.pantryItems.delete(row.id).then((_) {}),
    );
  }

  Future<_Effect> _mealChange(AppliedPlanRow plan, PlanItemPreview p) async {
    final item = p.item;
    final op = item.str('op');
    final slot = p.target(PlanTargetSlot.slot);
    switch (op) {
      case 'addFood':
        final foodId = await _foodIdFor(plan, p);
        final food = foodId == null ? null : await repos.foods.byId(foodId);
        final row = await repos.mealSlotFoods.insert(
          MealSlotFoodsCompanion.insert(
            slotId: slot!.id,
            foodId: Value(foodId),
            name: food?.name ?? item.str('foodRef') ?? item.title,
            portion: Value(item.number('portion') ?? food?.defaultPortion),
            unit: Value(item.str('unit') ?? food?.unit),
          ),
        );
        return _Effect(
          table: 'meal_slot_foods',
          id: row.id,
          after: {'slotId': slot.id, 'name': row.name},
          undo: () async => repos.mealSlotFoods.delete(row.id).then((_) {}),
        );
      case 'removeFood':
        final foodId = await _foodIdFor(plan, p);
        final name = item.str('foodRef');
        final gone = await repos.mealSlotFoods.deleteWhere(
          (t) =>
              t.slotId.equals(slot!.id) &
              (foodId == null ? t.name.equals(name ?? '') : t.foodId.equals(foodId)),
        );
        return _Effect(
          table: 'meal_slot_foods',
          id: gone.isEmpty ? null : gone.first.id,
          after: {'removed': gone.length},
          undo: () async => repos.mealSlotFoods.restoreAll(gone),
        );
      case 'newSlot':
        final planId = p.target(PlanTargetSlot.mealPlan)?.id ?? await _defaultMealPlanId();
        if (planId == null) throw PlanApplyRefused('${item.id}: no meal plan to add to');
        final row = await repos.mealSlots.insert(
          MealSlotsCompanion.insert(
            planId: planId,
            name: item.str('slotName') ?? item.title,
            timeMinutes: planMinutes(item.str('time') ?? '') ?? 0,
            weekdays: Value(item.ints('weekdays')),
          ),
        );
        return _Effect(
          table: 'meal_slots',
          id: row.id,
          after: {'planId': planId, 'name': row.name, 'timeMinutes': row.timeMinutes},
          undo: () async => repos.mealSlots.delete(row.id).then((_) {}),
        );
      case 'moveSlot':
        final before = await repos.mealSlots.byId(slot!.id);
        if (before == null) throw PlanApplyRefused('${slot.id}: gone');
        final minutes = planMinutes(item.str('time') ?? '');
        if (minutes == null) throw PlanApplyRefused('${item.id}: no time');
        await repos.mealSlots.setColumns(slot.id, {'timeMinutes': minutes});
        return _Effect(
          table: 'meal_slots',
          id: slot.id,
          after: {'timeMinutes': minutes},
          undo: () async => repos.mealSlots.setColumns(slot.id, {'timeMinutes': before.timeMinutes}),
        );
      default:
        throw PlanApplyRefused('${item.id}: $op');
    }
  }

  /// The food a meal change points at: one of his own, or the one another
  /// suggestion of the same plan created when he approved it.
  Future<String?> _foodIdFor(AppliedPlanRow plan, PlanItemPreview p) async {
    final direct = p.target(PlanTargetSlot.food);
    if (direct != null && !direct.id.startsWith('logged:')) return direct.id;
    for (final dep in p.waitingFor) {
      final row = await itemRow(plan.id, dep);
      if (row != null && row.state == PlanItemState.applied && row.refTable == 'foods') return row.refId;
    }
    // A dependency he approved before this preview was built.
    final reference = p.item.str('foodRef');
    if (reference != null) {
      for (final row in await items(plan.id)) {
        if (row.state == PlanItemState.applied &&
            row.refTable == 'foods' &&
            (row.itemKey == reference || row.title == reference)) {
          return row.refId;
        }
      }
    }
    return null;
  }

  Future<String?> _defaultMealPlanId() async {
    final plans = await repos.mealPlans.getAll();
    if (plans.isEmpty) return null;
    return (plans.where((p) => p.active).firstOrNull ?? plans.first).id;
  }

  Future<List<String>> _routineReminders(PlanItem item, String habitId) async {
    final out = <String>[];
    final weekdays = item.ints('weekdays');
    for (final raw in item.strings('times')) {
      final minutes = planMinutes(raw);
      if (minutes == null) continue;
      final row = await repos.reminders.insert(
        RemindersCompanion.insert(
          ownerTable: 'habits',
          ownerId: habitId,
          title: Value(item.title),
          rule: weekdays.isEmpty
              ? {'kind': 'daily', 'time': planTime(minutes)}
              : {'kind': 'weekly', 'time': planTime(minutes), 'weekdays': weekdays},
        ),
      );
      out.add(row.id);
    }
    return out;
  }

  static Map<String, Object?> _reminderRule(PlanItem item) {
    final at = item.str('at');
    if (at != null) {
      final parsed = DateTime.tryParse(at);
      if (parsed != null) return {'kind': 'once', 'at': parsed.toIso8601String()};
    }
    final minutes = planMinutes(item.str('time') ?? '');
    final time = planTime(minutes ?? 0);
    final weekdays = item.ints('weekdays');
    if (item.str('repeat') == 'week' || weekdays.isNotEmpty) {
      return {'kind': 'weekly', 'time': time, 'weekdays': weekdays.isEmpty ? const [1] : weekdays};
    }
    return {'kind': 'daily', 'time': time};
  }

  /// The raw payload of a stored plan, for the history.
  static Map<String, Object?>? rawOf(AppliedPlanRow plan) {
    try {
      final decoded = jsonDecode(plan.raw);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }
}

/// What one apply wrote, and how to take it back.
class _Effect {
  _Effect({required this.undo, this.table, this.id, this.after = const {}});

  factory _Effect.checklist() => _Effect(undo: () async {}, after: const {'checklistOnly': true});

  final String? table;
  final String? id;
  final Map<String, Object?> after;
  final PlanUndo undo;
}
