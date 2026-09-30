import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/custom_modules/domain/field_migration.dart';
import 'package:madar/features/custom_modules/domain/module_schema.dart';

EntryValuesRow _e(String id, Map<String, Object?> values) => (id: id, values: values);

void main() {
  const book = ModuleField(id: 'f1', label: 'Book', type: FieldType.text);
  const pages = ModuleField(id: 'f2', label: 'Pages', type: FieldType.number);

  test('renaming keeps the id and touches no entry', () {
    final plan = FieldMigration.plan(
      before: const [book, pages],
      after: [book.copyWith(label: 'Title'), pages],
      entries: [
        _e('e1', {'f1': 'Dune', 'f2': 30}),
      ],
    );
    expect(plan.canApply, isTrue);
    expect(plan.entryUpdates, isEmpty);
    expect(plan.issues, isEmpty);
    expect(plan.fields.first.label, 'Title');
    expect(plan.fields.first.id, 'f1');
  });

  test('a removed field with values is hidden, one without is dropped', () {
    const note = ModuleField(id: 'f3', label: 'Note', type: FieldType.text);
    final plan = FieldMigration.plan(
      before: const [book, pages, note],
      after: const [book],
      entries: [
        _e('e1', {'f1': 'Dune', 'f2': 30}),
        _e('e2', {'f1': 'Emma', 'f2': 12}),
      ],
    );
    expect(plan.fields.map((f) => (f.id, f.hidden)), [('f1', false), ('f2', true)]);
    expect(plan.entryUpdates, isEmpty, reason: 'values are never destroyed');
    final hidden = plan.issues.single;
    expect(hidden.kind, MigrationIssueKind.fieldHidden);
    expect(hidden.count, 2);
    expect(hidden.blocking, isFalse);
  });

  test('a restored hidden field is visible again with its values', () {
    final plan = FieldMigration.plan(
      before: [book, pages.copyWith(hidden: true)],
      after: const [book, pages],
      entries: [
        _e('e1', {'f1': 'Dune', 'f2': 30}),
      ],
    );
    expect(plan.fields.map((f) => f.hidden), [false, false]);
    expect(plan.issues, isEmpty);
  });

  test('text → number converts when every value is a number', () {
    const t = ModuleField(id: 'f1', label: 'Count', type: FieldType.text);
    final plan = FieldMigration.plan(
      before: const [t],
      after: [t.copyWith(type: FieldType.number)],
      entries: [
        _e('e1', {'f1': '12'}),
        _e('e2', {'f1': '١٥'}),
        _e('e3', {}),
      ],
    );
    expect(plan.canApply, isTrue);
    expect(plan.entryUpdates, {
      'e1': {'f1': 12},
      'e2': {'f1': 15},
    });
    expect(plan.issues.single.kind, MigrationIssueKind.valuesConverted);
    expect(plan.issues.single.count, 2);
  });

  test('text → number is blocked when a value is not a number', () {
    const t = ModuleField(id: 'f1', label: 'Count', type: FieldType.text);
    final plan = FieldMigration.plan(
      before: const [t],
      after: [t.copyWith(type: FieldType.number)],
      entries: [
        _e('e1', {'f1': '12'}),
        _e('e2', {'f1': 'a dozen'}),
      ],
    );
    expect(plan.canApply, isFalse);
    final issue = plan.blocking.single;
    expect(issue.kind, MigrationIssueKind.typeChangeBlocked);
    expect(issue.count, 1);
    expect(issue.from, FieldType.text);
    expect(issue.to, FieldType.number);
    expect(plan.entryUpdates, isEmpty);
  });

  test('any type change is free while no entry has a value', () {
    final plan = FieldMigration.plan(
      before: const [book],
      after: [book.copyWith(type: FieldType.checkbox)],
      entries: [
        _e('e1', {'f9': 1}),
      ],
    );
    expect(plan.canApply, isTrue);
    expect(plan.issues, isEmpty);
  });

  test('text → single select creates the options it needs', () {
    const t = ModuleField(id: 'f1', label: 'Mood', type: FieldType.text);
    final plan = FieldMigration.plan(
      before: const [t],
      after: [
        t.copyWith(type: FieldType.singleSelect, options: const [FieldOption(id: 'o1', label: 'Calm')]),
      ],
      entries: [
        _e('e1', {'f1': 'calm'}),
        _e('e2', {'f1': 'Tired'}),
        _e('e3', {'f1': 'Tired'}),
      ],
    );
    expect(plan.canApply, isTrue);
    final f = plan.fields.single;
    expect(f.options.map((o) => (o.id, o.label)), [('o1', 'Calm'), ('o2', 'Tired')]);
    expect(plan.entryUpdates['e1'], {'f1': 'o1'});
    expect(plan.entryUpdates['e2'], {'f1': 'o2'});
  });

  test('single ↔ multi select', () {
    const opts = [FieldOption(id: 'o1', label: 'A'), FieldOption(id: 'o2', label: 'B')];
    const single = ModuleField(id: 'f1', label: 'S', type: FieldType.singleSelect, options: opts);
    final toMulti = FieldMigration.plan(
      before: const [single],
      after: [single.copyWith(type: FieldType.multiSelect)],
      entries: [
        _e('e1', {'f1': 'o2'}),
      ],
    );
    expect(toMulti.entryUpdates['e1'], {
      'f1': ['o2'],
    });
    final multi = single.copyWith(type: FieldType.multiSelect);
    final back = FieldMigration.plan(
      before: [multi],
      after: const [single],
      entries: [
        _e('e1', {
          'f1': ['o1', 'o2'],
        }),
      ],
    );
    expect(back.canApply, isFalse, reason: 'two choices cannot become one');
  });

  test('number ↔ rating ↔ currency ↔ checkbox conversions', () {
    const n = ModuleField(id: 'f1', label: 'N', type: FieldType.number);
    expect(
      FieldMigration.plan(
        before: const [n],
        after: [n.copyWith(type: FieldType.rating, max: 5)],
        entries: [
          _e('e1', {'f1': 4}),
          _e('e2', {'f1': 9}),
        ],
      ).canApply,
      isFalse,
    );
    final money = FieldMigration.plan(
      before: const [n],
      after: [n.copyWith(type: FieldType.currency, currency: 'USD')],
      entries: [
        _e('e1', {'f1': 2.5}),
      ],
    );
    expect(money.entryUpdates['e1'], {
      'f1': {'milli': 2500, 'currency': 'USD'},
    });
    final bools = FieldMigration.plan(
      before: const [n],
      after: [n.copyWith(type: FieldType.checkbox)],
      entries: [
        _e('e1', {'f1': 1}),
        _e('e2', {'f1': 0}),
      ],
    );
    expect(bools.entryUpdates, {
      'e1': {'f1': true},
      'e2': {'f1': false},
    });
    const cb = ModuleField(id: 'f1', label: 'C', type: FieldType.checkbox);
    expect(FieldMigration.plan(before: const [cb], after: [cb.copyWith(type: FieldType.text)], entries: [
      _e('e1', {'f1': true}),
    ]).canApply, isFalse);
  });

  test('to text keeps a readable, neutral value', () {
    const c = ModuleField(id: 'f1', label: 'Cost', type: FieldType.currency, currency: 'JOD');
    final plan = FieldMigration.plan(
      before: const [c],
      after: [c.copyWith(type: FieldType.text)],
      entries: [
        _e('e1', {
          'f1': {'milli': 1250, 'currency': 'JOD'},
        }),
      ],
    );
    expect(plan.entryUpdates['e1'], {'f1': '1.250 JOD'});
  });

  test('a removed option still in use stays hidden', () {
    const opts = [FieldOption(id: 'o1', label: 'A'), FieldOption(id: 'o2', label: 'B'), FieldOption(id: 'o3', label: 'C')];
    const f = ModuleField(id: 'f1', label: 'S', type: FieldType.multiSelect, options: opts);
    final plan = FieldMigration.plan(
      before: const [f],
      after: [f.copyWith(options: const [FieldOption(id: 'o1', label: 'A')])],
      entries: [
        _e('e1', {
          'f1': ['o2'],
        }),
      ],
    );
    final options = plan.fields.single.options;
    expect(options.map((o) => (o.id, o.hidden)), [('o1', false), ('o2', true)]);
    expect(plan.issues.single.kind, MigrationIssueKind.optionHidden);
  });

  test('a smaller rating scale than given stars is blocked', () {
    const r = ModuleField(id: 'f1', label: 'R', type: FieldType.rating, max: 10);
    final plan = FieldMigration.plan(
      before: const [r],
      after: [r.copyWith(max: 5)],
      entries: [
        _e('e1', {'f1': 8}),
      ],
    );
    expect(plan.blocking.single.kind, MigrationIssueKind.ratingScaleBlocked);
  });

  test('new bounds and "required" only warn', () {
    final plan = FieldMigration.plan(
      before: const [pages],
      after: [pages.copyWith(min: 0, max: 10, required: true)],
      entries: [
        _e('e1', {'f2': 30}),
        _e('e2', {'f2': 5}),
        _e('e3', {}),
      ],
    );
    expect(plan.canApply, isTrue);
    expect(plan.entryUpdates, isEmpty);
    expect(plan.warnings.map((i) => (i.kind, i.count)), [
      (MigrationIssueKind.outOfRange, 1),
      (MigrationIssueKind.newlyRequired, 1),
    ]);
  });

  test('plainNumber drops trailing zeros', () {
    expect(FieldMigration.plainNumber(12), '12');
    expect(FieldMigration.plainNumber(12.50), '12.5');
    expect(FieldMigration.plainNumber(3.0), '3');
  });
}
