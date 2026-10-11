// The honest half of the before/after: what became of an approved
// suggestion, measured against his data as it is now rather than against
// the number the apply wrote.
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';

final _now = DateTime(2026, 10, 10, 9);

MadarDatabase _db() => MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

const String _plan = '''
{"madar": "plan", "version": 1, "items": [
  {"id": "b1", "kind": "budgetTweak", "title": "نزّل البقالة لمية",
   "reason": "صرفت أقل من المرصود", "data": {"envelopeRef": "env-grocery", "newAmount": 100}},
  {"id": "h1", "kind": "habit", "title": "امشي بعد العشا",
   "reason": "المشي مسجّل ستة أيام بس", "data": {"existingRef": "habit-walk"}},
  {"id": "n1", "kind": "note", "title": "ملاحظة",
   "reason": "إشي يستاهل القراية", "data": {"body": "جرّب تربط المشي بالرجعة من المسجد."}}
]}
''';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late PlanApplyService service;
  late AiBridgeRepository bridge;

  setUp(() async {
    db = _db();
    repos = Repositories(db);
    service = PlanApplyService(repos, clock: () => _now);
    bridge = AiBridgeRepository(repos);
    await repos.budgetItems.insert(
      BudgetItemsCompanion.insert(
        id: const Value('env-grocery'),
        name: 'بقالة',
        mode: const Value(BudgetMode.amount),
        amountMilli: const Value(120000),
        period: const Value(BudgetPeriod.monthly),
      ),
    );
    await repos.habits.insert(
      HabitsCompanion.insert(id: const Value('habit-walk'), name: 'مشي', active: const Value(false)),
    );
  });

  tearDown(() => db.close());

  /// Imports the plan and approves [id], then re-opens it against his data
  /// as it is **now** – which is exactly what the checklist tile does.
  Future<(AppliedPlanItemRow, PlanItemPreview?)> apply(String id) async {
    final import = await service.take(
      _plan,
      catalog: await bridge.loadCatalog(_now),
      origin: PlanOrigin.paste,
      name: 'خطة',
    );
    final plan = import.plan!;
    await service.applyItem(plan, import.preview(id)!);
    final reopened = await service.reopen(plan, catalog: await bridge.loadCatalog(_now));
    return ((await service.itemRow(plan.id, id))!, reopened.preview(id));
  }

  test('an envelope that still holds what the plan wrote reads as held', () async {
    final (row, preview) = await apply('b1');
    expect(PlanAfter.of(row, preview), PlanAfterState.held);
  });

  test('an envelope he moved himself afterwards reads as moved, not as the plan`s doing', () async {
    final (row, _) = await apply('b1');
    await repos.budgetItems.setColumns('env-grocery', {'amountMilli': 90000});
    final reopened = await service.reopen(
      (await service.planById(row.planId))!,
      catalog: await bridge.loadCatalog(_now),
    );
    expect(PlanAfter.of(row, reopened.preview('b1')), PlanAfterState.moved);
  });

  test('an envelope he deleted afterwards reads as gone', () async {
    final (row, _) = await apply('b1');
    await repos.budgetItems.delete('env-grocery');
    final reopened = await service.reopen(
      (await service.planById(row.planId))!,
      catalog: await bridge.loadCatalog(_now),
    );
    expect(PlanAfter.of(row, reopened.preview('b1')), PlanAfterState.gone);
  });

  test('a habit the plan switched on and he switched off again reads as moved', () async {
    final (row, preview) = await apply('h1');
    expect(PlanAfter.of(row, preview), PlanAfterState.held);
    await repos.habits.setColumns('habit-walk', {'active': false});
    final reopened = await service.reopen(
      (await service.planById(row.planId))!,
      catalog: await bridge.loadCatalog(_now),
    );
    expect(PlanAfter.of(row, reopened.preview('h1')), PlanAfterState.moved);
  });

  test('a suggestion whose only effect is the checklist line has no pair to show', () async {
    final (row, preview) = await apply('n1');
    expect(PlanAfter.of(row, preview), PlanAfterState.nothingToShow);
  });

  test('the stored snapshot comes back as the before it was', () async {
    final (row, _) = await apply('b1');
    final before = PlanAfter.beforeOf(row);
    expect(before, isNotNull);
    expect(before!.kind, PlanBeforeKind.envelope);
    expect(before.ref?.name, 'بقالة');
    // The number the apply replaced, not the one in his data now.
    expect(before.ref?.detail, contains('120'));
  });

  test('a row with no snapshot is simply not drawn', () async {
    final (row, _) = await apply('n1');
    expect(PlanAfter.beforeOf(row.copyWith(beforeJson: const {})), isNull);
  });
}
