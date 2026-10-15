import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../../body/domain/body_clock.dart';
import '../../body/domain/body_week.dart';
import '../data/nutrition_providers.dart';
import '../data/nutrition_service.dart';
import '../domain/food_library.dart';
import '../domain/food_log.dart';
import '../domain/food_rules.dart';
import '../domain/meal_plan.dart';
import 'nutrition_texts.dart';
import 'sheets/quick_log_sheet.dart';
import 'sheets/rule_sheet.dart';

UndoableAction _undo(String label, NutritionUndo undo) => UndoableAction(label: label, undo: undo);

/// Every write the food screens make, with the undo the service handed back.
///
/// Actions that return an [UndoableAction] are called from an
/// [ActionableItem], which shows the undo toast itself; the others show
/// their own. Nothing here computes a rating – that is the pure engine.
abstract final class NutritionActions {
  // ------------------------------------------------------------ the log ----

  /// The fastest path: one tap on a frequent or recent thing logs it now.
  static Future<UndoableAction?> logAgain(BuildContext context, WidgetRef ref, FoodUsage usage, {DateTime? at}) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final (_, undo) = await ref.read(nutritionServiceProvider).logAgain(usage, at: at);
    Fx.fire(Sfx.complete);
    return _undo(l.nutritionLoggedToast(isolate(usage.name)), undo);
  }

  /// One tap on a library food.
  static Future<UndoableAction?> logFood(
    BuildContext context,
    WidgetRef ref,
    Food food, {
    DateTime? at,
    double? portion,
    String? unit,
    String? note,
    String? slotId,
  }) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final when = at ?? ref.read(nutritionClockProvider)();
    final (_, undo) = await ref.read(nutritionServiceProvider).logFood(
      FoodLogDraft(
        foodId: food.id,
        name: food.name,
        at: when,
        portion: portion ?? food.defaultPortion,
        unit: unit ?? food.unit,
        note: note,
        slotId: slotId,
      ),
    );
    Fx.fire(Sfx.complete);
    return _undo(l.nutritionLoggedToast(isolate(food.name)), undo);
  }

  /// Something that is not in his library yet: the food is created on the
  /// fly (so next time it is one tap) and logged in the same breath. The
  /// undo removes both.
  static Future<UndoableAction?> logNewFood(
    BuildContext context,
    WidgetRef ref,
    String name, {
    DateTime? at,
    double? portion,
    String? unit,
    String? note,
    String? slotId,
    List<String> tags = const [],
  }) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final text = name.trim();
    if (text.isEmpty) return null;
    final service = ref.read(nutritionServiceProvider);
    final when = at ?? ref.read(nutritionClockProvider)();
    final (food, undoFood) = await service.addFood(FoodDraft(name: text, tags: tags, defaultPortion: portion, unit: unit));
    final (_, undoLog) = await service.logFood(
      FoodLogDraft(foodId: food.id, name: food.name, at: when, portion: portion, unit: unit, note: note, slotId: slotId),
    );
    Fx.fire(Sfx.complete);
    return _undo(l.nutritionLoggedToast(isolate(text)), () async {
      await undoLog();
      await undoFood();
    });
  }

  /// "I ate my breakfast": logs every planned food of the slot at once.
  static Future<UndoableAction?> logSlotAsPlanned(
    BuildContext context,
    WidgetRef ref,
    MealSlot slot, {
    DateTime? at,
  }) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealSlots.byId(slot.id);
    if (row == null) return null;
    final (rows, undo) = await ref.read(nutritionServiceProvider).logSlotAsPlanned(row, at: at);
    if (rows.isEmpty) return null;
    Fx.fire(Sfx.complete);
    return _undo(l.nutritionSlotLoggedToast(isolate(slot.name)), undo);
  }

  /// The quick-log sheet (chips, search, free text, time, portion).
  static Future<void> quickLog(BuildContext context, WidgetRef ref, {String? slotId, DateTime? at}) =>
      showQuickLogSheet(context, slotId: slotId, at: at);

  static List<FieldSpec> _entryFields(L10n l, {required bool withName}) => [
    if (withName)
      FieldSpec.text('name', l.nutritionEntryName, required: true, hint: l.nutritionFoodNameHint, icon: Icons.restaurant_rounded, maxLength: 80),
    FieldSpec.time('time', l.nutritionLogWhen, required: true, icon: Icons.schedule_rounded),
    FieldSpec.number('portion', l.nutritionPortionLabel, min: 0, max: 9999, decimals: 2, icon: Icons.straighten_rounded),
    FieldSpec.text('unit', l.nutritionUnitLabel, hint: l.nutritionUnitHint, maxLength: 24),
    FieldSpec.multiline('note', l.nutritionEntryNote, hint: l.nutritionEntryNoteHint, maxLength: 240),
  ];

  static Future<void> editEntry(BuildContext context, WidgetRef ref, FoodEntry entry) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).foodLogs.byId(entry.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.nutritionEditEntry,
      icon: Icons.restaurant_rounded,
      fields: _entryFields(l, withName: true),
      initial: {
        'name': row.name,
        'time': BodyTimes.format(row.at.hour * 60 + row.at.minute),
        'portion': row.portion,
        'unit': row.unit,
        'note': row.note,
      },
    );
    if (v == null) return;
    final minutes = BodyTimes.parse(v['time'] as String?) ?? (row.at.hour * 60 + row.at.minute);
    final undo = await ref.read(nutritionServiceProvider).updateLog(
      row,
      FoodLogDraft(
        foodId: row.foodId,
        name: (v['name'] as String?)?.trim() ?? row.name,
        at: DateTime(row.at.year, row.at.month, row.at.day, minutes ~/ 60, minutes % 60),
        portion: (v['portion'] as num?)?.toDouble(),
        unit: v['unit'] as String?,
        tags: row.tags,
        note: v['note'] as String?,
        slotId: row.slotId,
      ),
    );
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionLogUpdated, undo)));
  }

  static Future<UndoableAction?> deleteEntry(BuildContext context, WidgetRef ref, FoodEntry entry) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).foodLogs.byId(entry.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteLog(row);
    return _undo(l.nutritionLogDeleted(isolate(row.name)), undo);
  }

  // ------------------------------------------------------- food library ----

  static List<FieldSpec> _foodFields(L10n l, List<String> tags) => [
    FieldSpec.text('name', l.nutritionFoodName, required: true, hint: l.nutritionFoodNameHint, icon: Icons.restaurant_rounded, maxLength: 80, autofocus: true),
    FieldSpec.multiSelect(
      'tags',
      l.nutritionFoodTags,
      options: [for (final t in tags) SelectOption(id: t, label: t)],
      allowAdd: true,
      icon: Icons.label_outline_rounded,
    ),
    FieldSpec.number('portion', l.nutritionFoodPortion, min: 0, max: 9999, decimals: 2, icon: Icons.straighten_rounded),
    FieldSpec.text('unit', l.nutritionUnitLabel, hint: l.nutritionUnitHint, maxLength: 24),
    FieldSpec.toggle('favorite', l.nutritionFavorite, icon: Icons.star_rounded),
    FieldSpec.multiline('notes', l.nutritionFoodNotes, maxLength: 400),
  ];

  static FoodDraft _foodDraft(Map<String, Object?> v, {bool archived = false}) => FoodDraft(
    name: (v['name'] as String?)?.trim() ?? '',
    tags: [...?(v['tags'] as List<String>?)],
    defaultPortion: (v['portion'] as num?)?.toDouble(),
    unit: v['unit'] as String?,
    favorite: v['favorite'] == true,
    notes: v['notes'] as String?,
    archived: archived,
  );

  static Future<void> addFood(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final v = await showEditSheet(
      context,
      title: l.nutritionAddFood,
      icon: Icons.add_rounded,
      fields: _foodFields(l, ref.read(nutritionTagsProvider)),
    );
    if (v == null) return;
    final draft = _foodDraft(v);
    if (draft.name.isEmpty) return;
    final (_, undo) = await ref.read(nutritionServiceProvider).addFood(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionFoodSaved(isolate(draft.name)), undo)));
  }

  static Future<void> editFood(BuildContext context, WidgetRef ref, Food food) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).foods.byId(food.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.nutritionEditFood,
      icon: Icons.restaurant_rounded,
      fields: _foodFields(l, ref.read(nutritionTagsProvider)),
      initial: {
        'name': row.name,
        'tags': row.tags,
        'portion': row.defaultPortion,
        'unit': row.unit,
        'favorite': row.favorite,
        'notes': row.notes,
      },
    );
    if (v == null) return;
    final draft = _foodDraft(v, archived: row.archived);
    if (draft.name.isEmpty) return;
    final undo = await ref.read(nutritionServiceProvider).updateFood(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionFoodSaved(isolate(draft.name)), undo)));
  }

  static Future<UndoableAction?> toggleFavorite(BuildContext context, WidgetRef ref, Food food) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).foods.byId(food.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).setFoodFavorite(row, !row.favorite);
    Fx.fire(row.favorite ? Sfx.toggleOff : Sfx.toggleOn);
    final name = isolate(row.name);
    return _undo(row.favorite ? l.nutritionUnfavoritedToast(name) : l.nutritionFavoritedToast(name), undo);
  }

  static Future<UndoableAction?> toggleArchived(BuildContext context, WidgetRef ref, Food food) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).foods.byId(food.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).setFoodArchived(row, !row.archived);
    Fx.fire(row.archived ? Sfx.toggleOn : Sfx.toggleOff);
    final name = isolate(row.name);
    return _undo(row.archived ? l.nutritionUnarchivedToast(name) : l.nutritionArchivedToast(name), undo);
  }

  static Future<UndoableAction?> deleteFood(BuildContext context, WidgetRef ref, Food food) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).foods.byId(food.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteFood(row);
    return _undo(l.nutritionFoodDeleted(isolate(row.name)), undo);
  }

  // --------------------------------------------------------- meal plans ----

  static Future<void> addPlan(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.nutritionAddPlan,
      icon: Icons.add_rounded,
      fields: [
        FieldSpec.text('name', l.nutritionPlanName, required: true, hint: l.nutritionPlanNameHint, icon: Icons.event_note_rounded, maxLength: 80, autofocus: true),
        FieldSpec.multiline('notes', l.nutritionPlanNotes, maxLength: 400),
      ],
    );
    if (v == null) return;
    final name = (v['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return;
    // The first plan is the active one: a plan nobody activated would
    // compare against nothing.
    final first = ref.read(nutritionPlansProvider).isEmpty;
    await ref.read(nutritionServiceProvider).addPlan(MealPlanDraft(name: name, notes: v['notes'] as String?, active: first));
    Fx.fire(Sfx.complete);
  }

  static Future<void> editPlan(BuildContext context, WidgetRef ref, MealPlan plan) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).mealPlans.byId(plan.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.nutritionEditPlan,
      icon: Icons.event_note_rounded,
      fields: [
        FieldSpec.text('name', l.nutritionPlanName, required: true, hint: l.nutritionPlanNameHint, icon: Icons.event_note_rounded, maxLength: 80),
        FieldSpec.multiline('notes', l.nutritionPlanNotes, maxLength: 400),
      ],
      initial: {'name': row.name, 'notes': row.notes},
    );
    if (v == null) return;
    final name = (v['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return;
    await ref.read(nutritionServiceProvider).updatePlan(row, MealPlanDraft(name: name, notes: v['notes'] as String?, active: row.active));
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> setPlanActive(BuildContext context, WidgetRef ref, MealPlan plan, bool active) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealPlans.byId(plan.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).setPlanActive(row, active);
    Fx.fire(active ? Sfx.toggleOn : Sfx.toggleOff);
    final name = isolate(row.name);
    return _undo(active ? l.nutritionActivatedToast(name) : l.nutritionDeactivatedToast(name), undo);
  }

  static Future<UndoableAction?> duplicatePlan(BuildContext context, WidgetRef ref, MealPlan plan) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealPlans.byId(plan.id);
    if (row == null) return null;
    final (_, undo) = await ref.read(nutritionServiceProvider).duplicatePlan(row, name: l.nutritionCopyName(row.name));
    return _undo(l.nutritionDuplicatedToast(isolate(row.name)), undo);
  }

  static Future<UndoableAction?> deletePlan(BuildContext context, WidgetRef ref, MealPlan plan) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealPlans.byId(plan.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deletePlan(row);
    return _undo(l.nutritionPlanDeleted(isolate(row.name)), undo);
  }

  // --------------------------------------------------------- meal slots ----

  static List<FieldSpec> _slotFields(BuildContext context, L10n l) {
    final tx = NutritionTexts.of(context);
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    return [
      FieldSpec.text('name', l.nutritionSlotName, required: true, hint: l.nutritionSlotNameHint, icon: Icons.restaurant_menu_rounded, maxLength: 60, autofocus: true),
      FieldSpec.time('time', l.nutritionSlotTime, required: true, icon: Icons.schedule_rounded),
      FieldSpec.multiSelect(
        'days',
        l.nutritionSlotDays,
        options: [for (final d in BodyWeek.ordered(start)) SelectOption(id: '$d', label: tx.weekdayName(d))],
        icon: Icons.calendar_view_week_rounded,
      ),
      FieldSpec.toggle('remind', l.nutritionSlotRemind, hint: l.nutritionSlotRemindHint, icon: Icons.notifications_active_outlined),
      FieldSpec.multiline('notes', l.nutritionSlotNotes, maxLength: 240),
    ];
  }

  static MealSlotDraft _slotDraft(Map<String, Object?> v, String planId, {int fallbackMinutes = 8 * 60}) => MealSlotDraft(
    planId: planId,
    name: (v['name'] as String?)?.trim() ?? '',
    timeMinutes: BodyTimes.parse(v['time'] as String?) ?? fallbackMinutes,
    weekdays: [
      for (final d in (v['days'] as List<String>?) ?? const <String>[])
        if (int.tryParse(d) != null) int.parse(d),
    ],
    remind: v['remind'] == true,
    notes: v['notes'] as String?,
  );

  static Future<void> addSlot(BuildContext context, WidgetRef ref, String planId) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final v = await showEditSheet(context, title: l.nutritionAddSlot, icon: Icons.add_rounded, fields: _slotFields(context, l));
    if (v == null) return;
    final draft = _slotDraft(v, planId);
    if (draft.name.isEmpty) return;
    final (_, undo) = await ref.read(nutritionServiceProvider).addSlot(draft);
    if (!context.mounted) return;
    if (draft.remind) await _ensureRemindPermission(context, ref);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionSlotSaved(isolate(draft.name)), undo)));
  }

  static Future<void> editSlot(BuildContext context, WidgetRef ref, MealSlot slot) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealSlots.byId(slot.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.nutritionEditSlot,
      icon: Icons.restaurant_menu_rounded,
      fields: _slotFields(context, l),
      initial: {
        'name': row.name,
        'time': BodyTimes.format(row.timeMinutes),
        'days': [for (final d in row.weekdays) '$d'],
        'remind': row.remind,
        'notes': row.notes,
      },
    );
    if (v == null) return;
    final draft = _slotDraft(v, row.planId, fallbackMinutes: row.timeMinutes);
    if (draft.name.isEmpty) return;
    final undo = await ref.read(nutritionServiceProvider).updateSlot(row, draft);
    if (!context.mounted) return;
    if (draft.remind && !row.remind) await _ensureRemindPermission(context, ref);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionSlotSaved(isolate(draft.name)), undo)));
  }

  static Future<UndoableAction?> toggleRemind(BuildContext context, WidgetRef ref, MealSlot slot) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealSlots.byId(slot.id);
    if (row == null) return null;
    final want = !row.remind;
    if (want && context.mounted) {
      final granted = await _ensureRemindPermission(context, ref);
      if (!granted) return null;
    }
    final undo = await ref.read(nutritionServiceProvider).setSlotRemind(row, want);
    Fx.fire(want ? Sfx.toggleOn : Sfx.toggleOff);
    final name = isolate(row.name);
    return _undo(want ? l.nutritionRemindOnToast(name) : l.nutritionRemindOffToast(name), undo);
  }

  static Future<bool> _ensureRemindPermission(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final granted = await ref.read(nutritionReminderSchedulerProvider).ensurePermission();
    if (granted || !context.mounted) return granted;
    unawaited(
      showUndoToast(context, UndoableAction(label: l.nutritionRemindNeedsPermission, undo: () async {})),
    );
    return false;
  }

  static Future<UndoableAction?> deleteSlot(BuildContext context, WidgetRef ref, MealSlot slot) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealSlots.byId(slot.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteSlot(row);
    return _undo(l.nutritionSlotDeleted(isolate(row.name)), undo);
  }

  static Future<void> reorderSlots(WidgetRef ref, List<String> ids) =>
      ref.read(nutritionServiceProvider).reorderSlots(ids);

  // ---------------------------------------------------- planned in a slot ----

  static List<FieldSpec> _slotFoodFields(L10n l, List<Food> foods) => [
    FieldSpec.singleSelect(
      'food',
      l.nutritionRuleFood,
      options: [
        for (final f in foods)
          if (!f.archived) SelectOption(id: f.id, label: f.name),
      ],
      icon: Icons.restaurant_rounded,
    ),
    FieldSpec.text('name', l.nutritionEntryName, hint: l.nutritionFoodNameHint, maxLength: 80),
    FieldSpec.number('portion', l.nutritionPortionLabel, min: 0, max: 9999, decimals: 2, icon: Icons.straighten_rounded),
    FieldSpec.text('unit', l.nutritionUnitLabel, hint: l.nutritionUnitHint, maxLength: 24),
  ];

  static Future<void> addSlotFood(BuildContext context, WidgetRef ref, MealSlot slot) async {
    final l = L10n.of(context);
    final foods = ref.read(nutritionFoodsProvider);
    final v = await showEditSheet(
      context,
      title: l.nutritionAddSlotFood,
      icon: Icons.add_rounded,
      fields: _slotFoodFields(l, foods),
    );
    if (v == null) return;
    final id = v['food'] as String?;
    final picked = id == null ? null : foods.where((f) => f.id == id).firstOrNull;
    final typed = (v['name'] as String?)?.trim();
    final name = picked?.name ?? typed;
    if (name == null || name.isEmpty) return;
    await ref.read(nutritionServiceProvider).addSlotFood(
      PlannedFoodDraft(
        slotId: slot.id,
        foodId: picked?.id,
        name: name,
        portion: (v['portion'] as num?)?.toDouble() ?? picked?.defaultPortion,
        unit: (v['unit'] as String?) ?? picked?.unit,
      ),
    );
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> deleteSlotFood(BuildContext context, WidgetRef ref, PlannedFood food) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).mealSlotFoods.byId(food.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteSlotFood(row);
    return _undo(l.nutritionSlotFoodDeleted(isolate(row.name)), undo);
  }

  // --------------------------------------------------------- conditions ----

  static List<FieldSpec> _conditionFields(L10n l) => [
    FieldSpec.text('name', l.nutritionConditionName, required: true, hint: l.nutritionConditionNameHint, icon: Icons.favorite_outline_rounded, maxLength: 80, autofocus: true),
    FieldSpec.multiline('notes', l.nutritionConditionNotes, maxLength: 1000),
    FieldSpec.date('since', l.nutritionConditionSince, icon: Icons.calendar_today_rounded),
    FieldSpec.color('color', l.nutritionConditionColor),
    FieldSpec.toggle('active', l.nutritionConditionActive, hint: l.nutritionConditionActiveHint, icon: Icons.power_settings_new_rounded),
  ];

  static ConditionDraft _conditionDraft(Map<String, Object?> v, {bool activeDefault = true}) => ConditionDraft(
    name: (v['name'] as String?)?.trim() ?? '',
    notes: v['notes'] as String?,
    since: v['since'] as DateTime?,
    color: v['color'] as int?,
    active: v.containsKey('active') ? v['active'] == true : activeDefault,
  );

  static Future<void> addCondition(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final v = await showEditSheet(
      context,
      title: l.nutritionAddCondition,
      icon: Icons.add_rounded,
      fields: _conditionFields(l),
      initial: const {'active': true},
    );
    if (v == null) return;
    final draft = _conditionDraft(v);
    if (draft.name.isEmpty) return;
    final (_, undo) = await ref.read(nutritionServiceProvider).addCondition(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionConditionSaved(isolate(draft.name)), undo)));
  }

  static Future<void> editCondition(BuildContext context, WidgetRef ref, ConditionRef condition) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).conditions.byId(condition.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.nutritionEditCondition,
      icon: Icons.favorite_outline_rounded,
      fields: _conditionFields(l),
      initial: {'name': row.name, 'notes': row.notes, 'since': row.since, 'color': row.color, 'active': row.active},
    );
    if (v == null) return;
    final draft = _conditionDraft(v, activeDefault: row.active);
    if (draft.name.isEmpty) return;
    final undo = await ref.read(nutritionServiceProvider).updateCondition(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.nutritionConditionSaved(isolate(draft.name)), undo)));
  }

  static Future<UndoableAction?> toggleCondition(BuildContext context, WidgetRef ref, ConditionRef condition) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).conditions.byId(condition.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).setConditionActive(row, !row.active);
    Fx.fire(row.active ? Sfx.toggleOff : Sfx.toggleOn);
    final name = isolate(row.name);
    return _undo(row.active ? l.nutritionConditionStopped(name) : l.nutritionConditionResumed(name), undo);
  }

  static Future<UndoableAction?> deleteCondition(BuildContext context, WidgetRef ref, ConditionRef condition) async {
    final l = L10n.of(context);
    final isolate = NutritionTexts.of(context).name;
    final row = await ref.read(repositoriesProvider).conditions.byId(condition.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteCondition(row);
    return _undo(l.nutritionConditionDeleted(isolate(row.name)), undo);
  }

  // -------------------------------------------------------- his own rules ----

  /// The rule editor (a sentence of his, with a live preview of how many of
  /// his past entries it would have matched).
  static Future<void> addRule(BuildContext context, WidgetRef ref, {String? conditionId}) =>
      showRuleSheet(context, ref, conditionId: conditionId);

  static Future<void> editRule(BuildContext context, WidgetRef ref, FoodRule rule) =>
      showRuleSheet(context, ref, rule: rule);

  static Future<UndoableAction?> toggleRule(BuildContext context, WidgetRef ref, FoodRule rule) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).foodRules.byId(rule.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).setRuleActive(row, !row.active);
    Fx.fire(row.active ? Sfx.toggleOff : Sfx.toggleOn);
    return _undo(row.active ? l.nutritionRuleTurnedOff : l.nutritionRuleTurnedOn, undo);
  }

  static Future<UndoableAction?> deleteRule(BuildContext context, WidgetRef ref, FoodRule rule) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).foodRules.byId(rule.id);
    if (row == null) return null;
    final undo = await ref.read(nutritionServiceProvider).deleteRule(row);
    return _undo(l.nutritionRuleDeleted, undo);
  }
}

/// How much room the food screens leave under their lists for the floating
/// action and the tab bar.
const double nutritionBottomPadding = 112;
