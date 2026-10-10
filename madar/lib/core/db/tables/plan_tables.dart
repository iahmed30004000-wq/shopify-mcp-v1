import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// ------------------------------------------------ the AI bridge (v4) ----
//
// Part 3: the user hands his own data to any AI app and brings a «خطة مدار»
// JSON back. These two tables are the history of that round trip: which
// plans arrived, what every suggestion said, what he decided, and – for the
// before/after view – what his data looked like before an item was applied
// and what the apply wrote.
//
// They are also the plan's **checklist**: the suggestions he approved are
// the list he ticks off one by one («خطة تشرين الأول»، ٢ من ٤), so the
// counter and the before/after read from the same rows. A checklist line is
// a record of an approved suggestion – never a task in the home panel's
// task list, and nothing here ever writes into `tasks`.
//
// Nothing here is a medical record and nothing here is applied on its own:
// a row only ever reaches [PlanItemState.applied] through his explicit
// approval of that one item.

/// One imported plan. [raw] keeps exactly what arrived, so the history can
/// always show the original even after the schema of the contract moves on
/// (the same reason the prototype importer keeps `import_archive`).
@DataClassName('AppliedPlanRow')
class AppliedPlans extends Table with Entity {
  /// SHA-256 of the normalised payload: the same file imported twice is the
  /// same plan, which is what makes applying idempotent.
  TextColumn get planKey => text().unique()();

  /// His own name for the list, editable and the one he sees («خطة تشرين
  /// الأول»). Defaults to a plain name built from the day it arrived.
  TextColumn get name => text()();

  /// `version` of the plan contract the payload declared.
  IntColumn get formatVersion => integer().withDefault(const Constant(1))();

  /// The AI's own title and one-paragraph overview (its words, not ours).
  TextColumn get title => text().nullable()();
  TextColumn get summary => text().nullable()();

  TextColumn get origin => textEnum<PlanOrigin>().withDefault(Constant(PlanOrigin.file.name))();

  /// The payload's `source` block: what the AI read (a video, an article),
  /// how complete it was, and the claims it flagged rather than obeyed.
  TextColumn get source => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  DateTimeColumn get importedAt => dateTime().clientDefault(DateTime.now)();

  /// Suggestions the payload carried (including the ones he rejected).
  IntColumn get itemCount => integer().withDefault(const Constant(0))();

  /// The payload as it arrived (pretty-printed JSON text).
  TextColumn get raw => text()();
}

/// One suggestion of an imported plan, with his decision.
@DataClassName('AppliedPlanItemRow')
class AppliedPlanItems extends Table with Entity, Ordered {
  TextColumn get planId => text()();

  /// The item's `id` inside the payload – unique within one plan, which is
  /// what `(planId, itemKey)` keys idempotence on.
  TextColumn get itemKey => text()();

  /// `PlanItemKind.name`. Plain text, not an enum column, so a plan written
  /// against a newer contract still stores and still shows in the history.
  TextColumn get kind => text()();

  /// What he saw on the card: the suggestion and the AI's reason for it.
  TextColumn get title => text()();
  TextColumn get reason => text()();

  TextColumn get state => textEnum<PlanItemState>().withDefault(Constant(PlanItemState.pending.name))();

  /// The item's payload as approved (his edits included).
  TextColumn get payload => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  /// His data before the apply, and what the apply wrote – the two halves
  /// of the before/after view.
  TextColumn get beforeJson => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();
  TextColumn get afterJson => text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  /// The record the apply created or changed (`habits`, `budget_items`, …;
  /// never `tasks`).
  TextColumn get refTable => text().nullable()();
  TextColumn get refId => text().nullable()();

  /// When he decided (applied, rejected or undone).
  DateTimeColumn get decidedAt => dateTime().nullable()();

  /// Ticked off the checklist. Only an approved ([PlanItemState.applied])
  /// item can be ticked.
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// When he ticked it (null while it is open again).
  DateTimeColumn get doneAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {planId, itemKey},
      ];
}
