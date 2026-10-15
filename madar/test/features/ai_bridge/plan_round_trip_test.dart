// The whole round trip against a real database: export → a realistic AI
// answer → import → previews → approve one → his data really changed →
// undo → it is back. Plus idempotence, the plan's checklist, and the rule
// that nothing is ever applied without his yes.
import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';
import 'package:madar/features/data/domain/ai_summary.dart' show AiSummaryOptions, SummarySectionId;

import 'plan_fixtures.dart';

final _now = DateTime(2026, 10, 10, 9);

MadarDatabase _db() => MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// His own data: a budget envelope, a food, a meal plan with one meal, a
/// switched-off habit, a lab test, a project, a goal and a tracker.
Future<void> seed(Repositories repos) async {
  await repos.db.into(repos.db.currencies).insert(
    CurrenciesCompanion.insert(
      code: 'JOD',
      nameAr: 'دينار',
      nameEn: 'Dinar',
      symbol: 'د.أ',
      decimals: const Value(3),
      isBase: const Value(true),
    ),
  );
  await repos.budgetItems.insert(
    BudgetItemsCompanion.insert(
      id: const Value('env-grocery'),
      name: 'بقالة',
      mode: const Value(BudgetMode.amount),
      amountMilli: const Value(120000),
      period: const Value(BudgetPeriod.monthly),
    ),
  );
  await repos.foods.insert(
    FoodsCompanion.insert(
      id: const Value('food-maqluba'),
      name: 'مقلوبة',
      tags: const Value(['نشويات']),
      defaultPortion: const Value(1.5),
      unit: const Value('طبق'),
      notes: const Value('ملاحظة خاصة ما بتنبعت'),
    ),
  );
  await repos.mealPlans.insert(
    MealPlansCompanion.insert(id: const Value('mplan-1'), name: 'خطتي', active: const Value(true)),
  );
  await repos.mealSlots.insert(
    MealSlotsCompanion.insert(id: const Value('slot-lunch'), planId: 'mplan-1', name: 'غدا', timeMinutes: 780),
  );
  await repos.habits.insert(
    HabitsCompanion.insert(
      id: const Value('habit-walk'),
      name: 'مشي',
      category: const Value('حركة'),
      active: const Value(false),
    ),
  );
  await repos.labTests.insert(
    LabTestsCompanion.insert(id: const Value('lab-a1c'), name: 'سكر صائم', unit: const Value('mg/dL')),
  );
  await repos.projects.insert(ProjectsCompanion.insert(id: const Value('proj-1'), name: 'البيت'));
  await repos.learningGoals.insert(
    LearningGoalsCompanion.insert(id: const Value('goal-1'), name: 'حفظ', target: 10, unit: const Value('صفحة')),
  );
  await repos.customModules.insert(
    CustomModulesCompanion.insert(id: const Value('mod-1'), name: 'مزاجي', color: 0xFF1FB5C9),
  );
}

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late AiBridgeRepository bridge;
  late PlanApplyService service;

  setUp(() async {
    db = _db();
    repos = Repositories(db);
    bridge = AiBridgeRepository(repos);
    service = PlanApplyService(repos, clock: () => _now);
    await seed(repos);
  });

  tearDown(() => db.close());

  Future<PlanImport> import(Object payload, {String name = 'خطة تشرين الأول'}) async => service.take(
    payload is String ? payload : jsonEncode(payload),
    catalog: await bridge.loadCatalog(_now),
    origin: PlanOrigin.share,
    name: name,
  );

  // ----------------------------------------------------------- the export --

  group('the request that goes out', () {
    test('carries his own names, the prompt, the answer contract and what was left behind', () async {
      final request = await bridge.buildRequest(
        now: _now,
        languageCode: 'ar',
        summaryMarkdown: '# خلاصة\n\n- صلاة: ٢٨ من ٣٠',
        sections: AiSummaryOptions.defaultIncluded,
        ask: 'شو أحسن إشي أعمله الشهر الجاي؟',
      );
      final json = jsonDecode(request.encode()) as Map<String, Object?>;

      expect(json['madar'], madarRequestMarker);
      expect(json['version'], madarPlanVersion);
      expect(json['language'], 'ar');
      expect(json['ask'], 'شو أحسن إشي أعمله الشهر الجاي؟');

      final things = json['myThings']! as Map<String, Object?>;
      expect(things['baseCurrency'], 'JOD');
      expect((things['budgetItems']! as List).map((e) => (e as Map)['name']), contains('بقالة'));
      expect((things['foods']! as List).map((e) => (e as Map)['name']), contains('مقلوبة'));
      expect((things['habits']! as List).map((e) => (e as Map)['name']), contains('مشي'));

      // His own free text never travels – not even a food's note.
      expect(request.encode(), isNot(contains('ملاحظة خاصة')));
      expect(json['leftOutOnPurpose'], contains('free-text notes'));

      // The prompt and the answer shape ride along, so he types nothing.
      final instructions = (json['instructions']! as List).join('\n');
      expect(instructions, contains('خطة مدار'));
      expect(instructions, contains('reason'));
      expect(instructions, contains('myThings'));
      expect(json['answerContract'], isA<Map<String, Object?>>());
      expect(json['answerExample'], isA<Map<String, Object?>>());

      // The clipboard form puts the instructions before the JSON.
      expect(request.asText().indexOf('madar'), greaterThan(0));
      expect(request.asText(), contains('```json'));
      expect(request.byteSize, greaterThan(200));
    });

    test('a section he did not choose sends none of its names', () async {
      final request = await bridge.buildRequest(
        now: _now,
        languageCode: 'ar',
        summaryMarkdown: '# خلاصة',
        sections: const {SummarySectionId.faith},
      );
      final things = jsonDecode(request.encode())! as Map<String, Object?>;
      final myThings = things['myThings']! as Map<String, Object?>;
      expect(myThings.containsKey('budgetItems'), isFalse);
      expect(myThings.containsKey('foods'), isFalse);
      expect(myThings.containsKey('habits'), isFalse);
      expect(request.encode(), isNot(contains('بقالة')));
    });

    test('an import checks against everything he has, whatever he sent', () async {
      final catalog = await bridge.loadCatalog(_now, sections: const {SummarySectionId.faith});
      expect(catalog.budgetItems.isEmpty, isTrue);
      final all = await bridge.loadCatalog(_now);
      expect(all.budgetItems.resolve('بقالة')?.id, 'env-grocery');
      expect(all.foods.resolve('مقلوبة')?.id, 'food-maqluba');
      expect(all.mealSlots.resolve('غدا')?.detail, '13:00');
      expect(all.budgetItems.resolve('env-grocery')?.detail, '120.000 JOD monthly');
    });
  });

  // ----------------------------------------------------------- the import --

  group('the answer that comes back', () {
    test('every suggestion is previewed with its change, its reason and the before', () async {
      final result = await import(goodPlan());
      expect(result.isUsable, isTrue);
      expect(result.isNew, isTrue);
      expect(result.previews, hasLength(8));
      expect(result.plan!.name, 'خطة تشرين الأول');
      expect(result.plan!.origin, PlanOrigin.share);
      expect(result.plan!.itemCount, 8);

      final habit = result.preview('h1')!;
      expect(habit.status, PlanItemStatus.ready);
      expect(habit.item.reason, isNotEmpty);
      expect(habit.before.kind, PlanBeforeKind.habitOff);
      expect(habit.before.ref?.name, 'مشي');
      expect(habit.target(PlanTargetSlot.habit)?.id, 'habit-walk');
      expect(habit.oneLine, 'مشي عشرين دقيقة بعد العشا');
      expect(habit.oneLine.length, lessThanOrEqualTo(60));

      final budget = result.preview('b1')!;
      expect(budget.status, PlanItemStatus.ready);
      expect(budget.before.kind, PlanBeforeKind.envelope);
      expect(budget.before.ref?.detail, '120.000 JOD monthly');

      // The meal change waits for the new food to be approved first.
      final meal = result.preview('m1')!;
      expect(meal.status, PlanItemStatus.blocked);
      expect(meal.waitingFor, ['f1']);

      // A task is a line of the checklist and nothing else.
      expect(result.preview('t1')!.isChecklistOnly, isTrue);
      expect(result.preview('n1')!.isChecklistOnly, isTrue);
      // A reminder with an owner does change something.
      expect(result.preview('r1')!.isChecklistOnly, isFalse);

      // Nothing has been applied by importing.
      expect(await service.checklist(result.plan!.id), isEmpty);
      expect((await service.progress(result.plan!.id)).total, 0);
      final states = await service.states(result.plan!.id);
      expect(states.values.where((s) => s == PlanItemState.pending), hasLength(8));
    });

    test('the same answer imported twice is the same plan, with his decisions kept', () async {
      final first = await import(goodPlan());
      await service.applyItem(first.plan!, first.preview('b1')!);
      final again = await import(goodPlan(), name: 'اسم ثاني');
      expect(again.isNew, isFalse);
      expect(again.plan!.id, first.plan!.id);
      expect(again.plan!.name, 'خطة تشرين الأول', reason: 'his own name is kept');
      expect(again.states['b1'], PlanItemState.applied);
      expect(await service.items(again.plan!.id), hasLength(8));
    });

    test('a refused payload stores nothing at all', () async {
      final result = await import({'madar': 'plan', 'version': 9, 'items': <Object?>[]});
      expect(result.isUsable, isFalse);
      expect(result.plan, isNull);
      expect(result.problems, isNotEmpty);
      expect(await service.plans(), isEmpty);
    });
  });

  // ------------------------------------------------------------ the apply --

  group('approving one suggestion', () {
    test('a budget tweak changes the envelope, and undo puts it back', () async {
      final result = await import(goodPlan());
      final outcome = await service.applyItem(result.plan!, result.preview('b1')!);
      expect(outcome.alreadyApplied, isFalse);
      expect((await repos.budgetItems.byId('env-grocery'))!.amountMilli, 100000);
      expect(outcome.row.state, PlanItemState.applied);
      expect(outcome.row.refTable, 'budget_items');
      expect(outcome.row.refId, 'env-grocery');
      expect(outcome.row.beforeJson['kind'], 'envelope');
      expect(outcome.row.afterJson['amountMilli'], 100000);

      await outcome.undo();
      expect((await repos.budgetItems.byId('env-grocery'))!.amountMilli, 120000);
      final row = await service.itemRow(result.plan!.id, 'b1');
      expect(row!.state, PlanItemState.undone);
      expect(await service.checklist(result.plan!.id), isEmpty);
    });

    test('applying the same suggestion twice changes nothing the second time', () async {
      final result = await import(goodPlan());
      await service.applyItem(result.plan!, result.preview('b1')!);
      final again = await service.applyItem(result.plan!, result.preview('b1')!);
      expect(again.alreadyApplied, isTrue);
      expect((await repos.budgetItems.byId('env-grocery'))!.amountMilli, 100000);
      expect(await service.items(result.plan!.id), hasLength(8));
      expect((await service.progress(result.plan!.id)).total, 1);
    });

    test('a habit he already has is switched back on, not duplicated', () async {
      final result = await import(goodPlan());
      final outcome = await service.applyItem(result.plan!, result.preview('h1')!);
      expect(await repos.habits.count(), 1);
      expect((await repos.habits.byId('habit-walk'))!.active, isTrue);
      await outcome.undo();
      expect((await repos.habits.byId('habit-walk'))!.active, isFalse);
    });

    test('a new food, then the meal change that needed it', () async {
      final first = await import(goodPlan());
      expect(first.preview('m1')!.canApply, isFalse);

      final food = await service.applyItem(first.plan!, first.preview('f1')!);
      expect(food.row.refTable, 'foods');
      final foodId = food.row.refId!;
      expect((await repos.foods.byId(foodId))!.name, 'شوفان');

      // Re-previewing now unblocks the meal change (the history screen and
      // the review screen both re-open a plan this way).
      final again = await service.reopen(first.plan!, catalog: await bridge.loadCatalog(_now));
      expect(again.states['f1'], PlanItemState.applied);
      final meal = again.preview('m1')!;
      expect(meal.status, PlanItemStatus.ready);
      final applied = await service.applyItem(again.plan!, meal);
      final planned = await repos.mealSlotFoods.getAll();
      expect(planned, hasLength(1));
      expect(planned.single.slotId, 'slot-lunch');
      expect(planned.single.foodId, foodId);
      expect(planned.single.name, 'شوفان');

      await applied.undo();
      expect(await repos.mealSlotFoods.getAll(), isEmpty);
      await food.undo();
      expect(await repos.foods.byId(foodId), isNull);
    });

    test('a reminder is set on the record it names, and nothing is written to his task list', () async {
      final result = await import(goodPlan());
      await service.applyItem(result.plan!, result.preview('r1')!);
      final reminders = await repos.reminders.getAll();
      expect(reminders, hasLength(1));
      expect(reminders.single.ownerTable, 'habits');
      expect(reminders.single.ownerId, 'habit-walk');
      expect(reminders.single.rule['time'], '20:30');

      // A task suggestion is a checklist line only.
      final task = await service.applyItem(result.plan!, result.preview('t1')!);
      expect(task.row.refTable, isNull);
      expect(task.row.afterJson['checklistOnly'], isTrue);
      expect(await repos.tasks.count(), 0, reason: 'an approved suggestion is never a task of the home panel');
    });

    test('a tracked sign becomes a tracker he can fill in, and undo removes it', () async {
      final result = await import(goodPlan());
      final outcome = await service.applyItem(result.plan!, result.preview('s1')!);
      final modules = await repos.customModules.getAll(where: (m) => m.name.equals('نوم متقطع'));
      expect(modules, hasLength(1));
      expect(modules.single.kind, CustomModuleKind.tracker);
      expect((modules.single.fields.single! as Map)['type'], 'number');
      await outcome.undo();
      expect(await repos.customModules.getAll(where: (m) => m.name.equals('نوم متقطع')), isEmpty);
    });

    test('a suggestion the validator refused can never be applied', () async {
      final result = await import(
        planWith({
          'id': 'bad',
          'kind': 'budgetTweak',
          'title': 'نزّل مصروف المطاعم',
          'reason': 'لأنه أكبر بند.',
          'data': {'envelopeRef': 'مطاعم', 'newAmount': 50},
        }, only: false),
      );
      final bad = result.preview('bad')!;
      expect(bad.status, PlanItemStatus.rejected);
      await expectLater(() => service.applyItem(result.plan!, bad), throwsA(isA<PlanApplyRefused>()));
      expect(await service.checklist(result.plan!.id), isEmpty);
    });

    test('an AI recipe lands in «السفرة» with its ingredients, and undoes', () async {
      final result = await import(
        planWith({
          'id': 'k1',
          'kind': 'recipe',
          'title': 'شوربة عدس',
          'reason': 'لأن المونة عندك فيها عدس.',
          'area': 'kitchen',
          'data': {
            'servings': 4,
            'minutes': 30,
            'tags': ['سريع'],
            'ingredients': [
              {'name': 'عدس', 'quantity': 1, 'unit': 'كوب'},
              {'name': 'كزبرة', 'optional': true},
            ],
            'steps': ['اغلي العدس', 'اضربيه بالخلاط'],
          },
        }, only: false),
      );
      final preview = result.preview('k1')!;
      expect(preview.status, PlanItemStatus.ready);
      final outcome = await service.applyItem(result.plan!, preview);
      final recipe = (await repos.recipes.getAll()).single;
      expect(recipe.name, 'شوربة عدس');
      expect(recipe.servings, 4);
      expect(recipe.minutes, 30);
      expect(recipe.steps, ['اغلي العدس', 'اضربيه بالخلاط']);
      expect(recipe.source, RecipeSource.ai, reason: 'she must always know it came from an AI answer');
      expect(recipe.sourceName, isNotNull);
      final ingredients = await repos.recipeIngredients.getAll();
      expect([for (final i in ingredients) i.name], ['عدس', 'كزبرة']);
      expect(ingredients.first.quantity, 1);
      expect(ingredients.first.unit, 'كوب');
      expect(ingredients.last.optional, isTrue);
      expect((await service.itemRow(result.plan!.id, 'k1'))!.state, PlanItemState.applied);
      await outcome.undo();
      expect(await repos.recipes.count(), 0);
      expect(await repos.recipeIngredients.count(), 0);
      expect((await service.itemRow(result.plan!.id, 'k1'))!.state, PlanItemState.undone);
    });

    test('a dish she already has is filled in, never overwritten, and undoes', () async {
      await repos.recipes.insert(
        RecipesCompanion.insert(id: const Value('r-mine'), name: 'شوربة عدس', notes: const Value('طريقتي')),
      );
      await repos.recipeIngredients.insert(
        RecipeIngredientsCompanion.insert(recipeId: 'r-mine', name: 'عدس أحمر', quantity: const Value(2)),
      );
      final result = await import(
        planWith({
          'id': 'k1',
          'kind': 'recipe',
          'title': 'شوربة عدس',
          'reason': 'لأن المونة عندك فيها عدس.',
          'data': {
            'servings': 6,
            'ingredients': [
              {'name': 'عدس'},
            ],
          },
        }, only: false),
      );
      final preview = result.preview('k1')!;
      expect(preview.before.kind, PlanBeforeKind.recipeKnown);
      final outcome = await service.applyItem(result.plan!, preview);
      final recipe = (await repos.recipes.getAll()).single;
      expect(recipe.id, 'r-mine', reason: 'no near-duplicate dish was created');
      expect(recipe.servings, 6, reason: 'the empty field was filled in');
      expect(recipe.notes, 'طريقتي', reason: 'what she wrote is untouched');
      final ingredients = await repos.recipeIngredients.getAll();
      expect([for (final i in ingredients) i.name], ['عدس أحمر'], reason: 'her ingredient list is never replaced');
      await outcome.undo();
      expect((await repos.recipes.getAll()).single.servings, isNull);
    });

    test('a pantry item lands in the house, and an existing one is updated', () async {
      final result = await import(
        planWith({
          'id': 'p1',
          'kind': 'pantryItem',
          'title': 'عدس',
          'reason': 'لأنك بتطبخيه كثير.',
          'data': {'quantity': 2, 'unit': 'كيلو', 'place': 'خزانة المونة', 'expires': '2026-12-01'},
        }, only: false),
      );
      final outcome = await service.applyItem(result.plan!, result.preview('p1')!);
      final item = (await repos.pantryItems.getAll()).single;
      expect(item.name, 'عدس');
      expect(item.quantity, 2);
      expect(item.unit, 'كيلو');
      expect(item.place, 'خزانة المونة');
      expect(item.expires, DateTime(2026, 12, 1));
      await outcome.undo();
      expect(await repos.pantryItems.count(), 0);

      // Now she already has it: the same suggestion updates the row.
      await repos.pantryItems.insert(
        PantryItemsCompanion.insert(id: const Value('p-lentils'), name: 'عدس', quantity: const Value(0)),
      );
      final second = await import(
        planWith({
          'id': 'p2',
          'kind': 'pantryItem',
          'title': 'عدس',
          'reason': 'لأنها خلصت.',
          'data': {'quantity': 3, 'unit': 'كيلو'},
        }, only: false),
      );
      final preview = second.preview('p2')!;
      expect(preview.before.kind, PlanBeforeKind.pantryKnown);
      final outcome2 = await service.applyItem(second.plan!, preview);
      expect(await repos.pantryItems.count(), 1);
      expect((await repos.pantryItems.byId('p-lentils'))!.quantity, 3);
      await outcome2.undo();
      expect((await repos.pantryItems.byId('p-lentils'))!.quantity, 0);
    });

    test('he can say no, and change his mind', () async {
      final result = await import(goodPlan());
      final undo = await service.rejectItem(result.plan!, result.preview('t1')!);
      expect((await service.itemRow(result.plan!.id, 't1'))!.state, PlanItemState.rejected);
      await undo();
      expect((await service.itemRow(result.plan!.id, 't1'))!.state, PlanItemState.pending);
    });
  });

  // -------------------------------------------------------- the checklist --

  group('the checklist of an imported plan', () {
    test('holds the approved suggestions in order, and counts what is done', () async {
      final result = await import(goodPlan());
      for (final id in ['h1', 'b1', 't1', 'n1']) {
        await service.applyItem(result.plan!, result.preview(id)!);
      }
      final planId = result.plan!.id;
      final list = await service.checklist(planId);
      expect(list.map((r) => r.itemKey), ['h1', 'b1', 't1', 'n1']);
      expect(list.map((r) => r.reason).every((r) => r.isNotEmpty), isTrue);
      expect(await service.progress(planId), isA<PlanProgress>().having((p) => p.total, 'total', 4));
      expect((await service.progress(planId)).done, 0);

      final tick = await service.setDone(list[1], true);
      await service.setDone(list[2], true);
      var progress = await service.progress(planId);
      expect(progress.done, 2);
      expect(progress.total, 4);
      expect(progress.isComplete, isFalse);
      expect((await service.itemRow(planId, 'b1'))!.doneAt, _now);

      await tick();
      expect((await service.progress(planId)).done, 1);
      expect((await service.itemRow(planId, 'b1'))!.done, isFalse);
      expect((await service.itemRow(planId, 'b1'))!.doneAt, isNull);
    });

    test('all four ticked reads as complete', () async {
      final result = await import(goodPlan());
      for (final id in ['h1', 'b1', 't1', 'n1']) {
        await service.applyItem(result.plan!, result.preview(id)!);
      }
      for (final row in await service.checklist(result.plan!.id)) {
        await service.setDone(row, true);
      }
      final progress = await service.progress(result.plan!.id);
      expect(progress.done, 4);
      expect(progress.isComplete, isTrue);
    });

    test('a suggestion he never approved cannot be ticked', () async {
      final result = await import(goodPlan());
      final pending = (await service.items(result.plan!.id)).firstWhere((r) => r.itemKey == 't1');
      await expectLater(() => service.setDone(pending, true), throwsA(isA<PlanApplyRefused>()));
      expect((await service.itemRow(result.plan!.id, 't1'))!.done, isFalse);
      expect((await service.progress(result.plan!.id)).total, 0);
    });

    test('an undone suggestion leaves the list and loses its tick', () async {
      final result = await import(goodPlan());
      final outcome = await service.applyItem(result.plan!, result.preview('h1')!);
      await service.setDone(outcome.row, true);
      expect((await service.progress(result.plan!.id)).done, 1);
      await outcome.undo();
      expect(await service.checklist(result.plan!.id), isEmpty);
      expect((await service.itemRow(result.plan!.id, 'h1'))!.done, isFalse);
    });

    test('he can rename the list, and undo the rename', () async {
      final result = await import(goodPlan());
      final undo = await service.rename(result.plan!, 'خطة الهدوء');
      expect((await service.planById(result.plan!.id))!.name, 'خطة الهدوء');
      await undo();
      expect((await service.planById(result.plan!.id))!.name, 'خطة تشرين الأول');
      await expectLater(() => service.rename(result.plan!, '  '), throwsA(isA<PlanApplyRefused>()));
    });

    test('the history keeps the original answer and what the source flagged', () async {
      await import(goodPlan());
      final plans = await service.plans();
      expect(plans, hasLength(1));
      expect(plans.single.source['claimsFlagged'], hasLength(1));
      final raw = PlanApplyService.rawOf(plans.single)!;
      expect(raw['madar'], 'plan');
      expect((raw['items']! as List), hasLength(8));
    });
  });
}
