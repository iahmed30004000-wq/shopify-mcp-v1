import '../../../core/db/database.dart' show AppliedPlanItemRow;
import '../domain/plan_catalog.dart';
import '../domain/plan_preview.dart';

/// The before/after of an approved suggestion, read honestly.
///
/// The "before" is the snapshot the apply stored ([AppliedPlanItemRow.beforeJson]);
/// the "after" is **not** a stored number but his data as it is right now
/// (the re-opened preview's own `before`). That is deliberate: a number he
/// changed himself after approving must not be shown as the plan's doing.
///
/// [PlanAfter.of] says which of the three cases it is, and the screens put
/// the plain sentence beside the pair:
///
/// * [PlanAfterState.held] – his data still holds what the plan wrote;
/// * [PlanAfterState.moved] – the number moved afterwards, for a reason of
///   his own («الرقم اللي عندك هلأ مختلف…»);
/// * [PlanAfterState.gone] – the record the apply touched is not there any
///   more (he deleted the envelope, the habit, the food);
/// * [PlanAfterState.nothingToShow] – the apply only added the checklist
///   line, or it touched something the catalogue does not carry (a
///   reminder row), so there is no honest pair to draw.
///
/// Pure except for the stored row: unit-tested on its own.
enum PlanAfterState { held, moved, gone, nothingToShow }

abstract final class PlanAfter {
  /// Tables the catalogue carries, so a record missing from it really is
  /// gone rather than merely invisible to the preview.
  static const Set<String> catalogTables = {
    'budget_items',
    'habits',
    'foods',
    'lab_tests',
    'custom_modules',
    'avoid_items',
    'learning_goals',
    'meal_slots',
    'meal_plans',
  };

  /// Numbers worth comparing: the ones an apply really writes.
  static const List<String> numbers = ['amountMilli', 'percent', 'target'];

  /// Where [row] stands now, measured against [preview] (the same
  /// suggestion re-previewed against his current data; null when the plan
  /// can no longer be read).
  static PlanAfterState of(AppliedPlanItemRow row, PlanItemPreview? preview) {
    final after = row.afterJson;
    final table = row.refTable;
    final id = row.refId;
    if (after['checklistOnly'] == true || table == null || id == null || id.isEmpty) {
      return PlanAfterState.nothingToShow;
    }
    final live = preview;
    if (live == null) return PlanAfterState.nothingToShow;
    if (catalogTables.contains(table) && !live.targets.values.any((r) => r.id == id)) {
      return PlanAfterState.gone;
    }
    final ref = live.before.ref;
    if (ref == null || ref.id != id) return PlanAfterState.nothingToShow;
    for (final key in numbers) {
      final written = after[key];
      if (written is! num) continue;
      final now = ref.extra[key];
      if (now is! num || (written - now).abs() > 0.0001) return PlanAfterState.moved;
    }
    // A habit the apply switched on and he switched off again.
    if (after['active'] == true && ref.extra['active'] == false) return PlanAfterState.moved;
    return PlanAfterState.held;
  }

  /// The snapshot the apply stored, back as a [PlanBefore] so the same
  /// sentences describe it (null when the row carries none).
  static PlanBefore? beforeOf(AppliedPlanItemRow row) {
    final raw = row.beforeJson['kind'];
    if (raw is! String) return null;
    for (final kind in PlanBeforeKind.values) {
      if (kind.name != raw) continue;
      final ref = row.beforeJson['ref'];
      return PlanBefore(
        kind,
        ref: ref is Map
            ? PlanRef(
                id: ref['id'] as String? ?? '',
                name: ref['name'] as String? ?? '',
                detail: ref['detail'] as String?,
              )
            : null,
      );
    }
    return null;
  }
}
