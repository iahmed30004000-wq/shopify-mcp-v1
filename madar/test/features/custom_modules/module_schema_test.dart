import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/custom_modules/domain/module_builder_rules.dart';
import 'package:madar/features/custom_modules/domain/module_schema.dart';
import 'package:madar/features/custom_modules/domain/module_templates.dart';

ModuleDefinition _module(List<ModuleField> fields, {CustomModuleKind kind = CustomModuleKind.tracker}) =>
    ModuleDefinition(id: 'm1', name: 'Test', kind: kind, colorArgb: 0xFF4CC96B, fields: fields);

void main() {
  group('ModuleField JSON', () {
    test('round trips every setting and keeps unknown keys', () {
      const f = ModuleField(
        id: 'f2',
        label: 'Pages',
        type: FieldType.number,
        unit: 'p',
        required: true,
        min: 0,
        max: 500,
        decimals: 1,
        extra: {'sourceKey': 'pages'},
      );
      final json = f.toJson();
      expect(json['sourceKey'], 'pages');
      expect(json['decimals'], 1);
      final back = ModuleField.fromJson(json)!;
      expect(back, f);
      expect(back.extra, {'sourceKey': 'pages'});
    });

    test('reads imported shapes: plain string options, rating max', () {
      final f = ModuleField.fromJson({
        'id': 'f3',
        'label': 'Tags',
        'type': 'multiSelect',
        'options': ['red', 'blue', 'red', ''],
        'sourceKey': 'tags',
      })!;
      expect(f.options.map((o) => o.id), ['red', 'blue']);
      expect(f.options.first.label, 'red');
      final r = ModuleField.fromJson({'id': 'r', 'label': 'Mood', 'type': 'rating', 'max': 10})!;
      expect(r.ratingMax, 10);
      expect(ModuleField.fromJson({'id': 'x', 'type': 'rating'})!.ratingMax, 5);
      expect(ModuleField.fromJson({'id': 'x', 'type': 'rating', 'max': 40})!.ratingMax, 10);
    });

    test('unknown type falls back to text; missing id is rejected', () {
      expect(ModuleField.fromJson({'id': 'a', 'type': 'hologram'})!.type, FieldType.text);
      expect(ModuleField.fromJson({'label': 'no id'}), isNull);
      expect(ModuleField.fromJson('nope'), isNull);
    });

    test('currency code defaults to JOD and is upper-cased', () {
      expect(const ModuleField(id: 'c', label: 'c', type: FieldType.currency).currencyCode, 'JOD');
      expect(ModuleField.fromJson({'id': 'c', 'type': 'currency', 'currency': 'usd'})!.currencyCode, 'USD');
    });

    test('parseFields drops duplicates and junk', () {
      final fields = ModuleDefinition.parseFields([
        {'id': 'f1', 'label': 'A', 'type': 'text'},
        {'id': 'f1', 'label': 'dup', 'type': 'text'},
        42,
        {'id': 'f2', 'label': 'B', 'type': 'checkbox', 'hidden': true},
      ]);
      expect(fields.map((f) => f.id), ['f1', 'f2']);
      expect(fields.last.hidden, isTrue);
    });
  });

  group('chart config', () {
    test('parses and snaps the range', () {
      expect(ModuleChartConfig.fromJson({'type': 'line', 'fieldId': 'f1', 'range': 30}),
          const ModuleChartConfig(type: ModuleChartType.line, fieldId: 'f1', range: 30));
      expect(ModuleChartConfig.fromJson({'type': 'bar', 'range': 14})!.range, 30);
      expect(ModuleChartConfig.fromJson({'type': 'heat', 'range': 365})!.range, 90);
      expect(ModuleChartConfig.fromJson({'type': 'pie'}), isNull);
    });

    test('effective chart falls back when the field is gone or hidden', () {
      final m = _module(const [
        ModuleField(id: 'f1', label: 'Done', type: FieldType.checkbox),
        ModuleField(id: 'f2', label: 'Pages', type: FieldType.number, hidden: true),
      ]).copyWith(chart: const ModuleChartConfig(type: ModuleChartType.line, fieldId: 'f2', range: 7));
      final c = m.effectiveChart;
      expect(c.fieldId, 'f1');
      expect(c.type, ModuleChartType.streak);
      expect(c.range, 7);
    });
  });

  group('quick entry', () {
    test('checkbox tracker is one-tap', () {
      final m = _module(const [
        ModuleField(id: 'f1', label: 'Done', type: FieldType.checkbox),
        ModuleField(id: 'f2', label: 'Note', type: FieldType.text),
      ]);
      expect(m.quickEntry, const QuickCheck('f1'));
    });

    test('rating tracker is one-tap unless another field is required', () {
      final m = _module(const [ModuleField(id: 'f1', label: 'Mood', type: FieldType.rating, max: 10)]);
      expect(m.quickEntry, const QuickRate('f1', 10));
      final m2 = _module(const [
        ModuleField(id: 'f1', label: 'Mood', type: FieldType.rating),
        ModuleField(id: 'f2', label: 'Why', type: FieldType.text, required: true),
      ]);
      expect(m2.quickEntry, isNull);
    });

    test('field-less tracker is a counter; lists never are', () {
      expect(_module(const []).quickEntry, const QuickCount());
      expect(
        _module(const [
          ModuleField(id: 'f1', label: 'Done', type: FieldType.checkbox),
        ], kind: CustomModuleKind.list).quickEntry,
        isNull,
      );
    });

    test('hidden fields do not count', () {
      final m = _module(const [
        ModuleField(id: 'f1', label: 'Done', type: FieldType.checkbox),
        ModuleField(id: 'f2', label: 'Old', type: FieldType.text, required: true, hidden: true),
      ]);
      expect(m.quickEntry, const QuickCheck('f1'));
    });
  });

  group('ids', () {
    test('next field id never reuses hidden or taken ids', () {
      expect(ModuleIds.nextFieldId(const []), 'f1');
      expect(ModuleIds.nextFieldId(const ['f1', 'f7', 'x']), 'f8');
      expect(ModuleIds.nextOptionId(const ['o2']), 'o3');
    });
  });

  group('builder rules', () {
    test('valid template drafts', () {
      for (final key in ModuleTemplates.all) {
        final d = ModuleTemplates.build(key, (t) => t.name);
        expect(ModuleBuilderRules.check(d), isEmpty, reason: key.name);
        expect(d.id, '');
        expect(d.planetKey, isNotNull);
      }
    });

    test('templates are generic and chart a real field', () {
      final reading = ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name);
      expect(reading.chart!.fieldId, 'f2');
      expect(reading.field('f2')!.type, FieldType.number);
      final habit = ModuleTemplates.build(ModuleTemplateKey.dailyHabit, (t) => t.name);
      expect(habit.quickEntry, const QuickCheck('f1'));
      final gifts = ModuleTemplates.build(ModuleTemplateKey.giftIdeas, (t) => t.name);
      expect(gifts.isList, isTrue);
      expect(gifts.field('f3')!.type, FieldType.currency);
    });

    test('reports name, labels, options, range and currency problems', () {
      final d = _module(const [
        ModuleField(id: 'f1', label: ' ', type: FieldType.text),
        ModuleField(id: 'f2', label: 'A', type: FieldType.number, min: 10, max: 1),
        ModuleField(id: 'f3', label: 'a', type: FieldType.singleSelect),
        ModuleField(id: 'f4', label: 'Cost', type: FieldType.currency, currency: 'JD'),
        ModuleField(
          id: 'f5',
          label: 'Pick',
          type: FieldType.multiSelect,
          options: [FieldOption(id: 'o1', label: 'x'), FieldOption(id: 'o2', label: 'X')],
        ),
      ]).copyWith(name: '');
      final problems = ModuleBuilderRules.check(d);
      expect(problems, contains(const DraftProblem(DraftIssue.nameMissing)));
      expect(problems, contains(const DraftProblem(DraftIssue.labelMissing, 'f1')));
      expect(problems, contains(const DraftProblem(DraftIssue.rangeInverted, 'f2')));
      expect(problems, contains(const DraftProblem(DraftIssue.labelDuplicate, 'f3')));
      expect(problems, contains(const DraftProblem(DraftIssue.noOptions, 'f3')));
      expect(problems, contains(const DraftProblem(DraftIssue.currencyCode, 'f4')));
      expect(problems, contains(const DraftProblem(DraftIssue.optionDuplicate, 'f5')));
    });

    test('a list needs a field, a tracker may be a plain counter', () {
      expect(
        ModuleBuilderRules.check(_module(const [], kind: CustomModuleKind.list)),
        contains(const DraftProblem(DraftIssue.noFields)),
      );
      expect(ModuleBuilderRules.check(_module(const [])), isEmpty);
    });

    test('add / duplicate / remove / restore / reorder keep hidden fields last', () {
      var d = _module(const [
        ModuleField(id: 'f1', label: 'A', type: FieldType.text),
        ModuleField(id: 'f2', label: 'Old', type: FieldType.number, hidden: true),
      ]);
      final (d2, added) = ModuleBuilderRules.addField(d, FieldType.rating, 'Stars', takenIds: const ['f5']);
      expect(added.id, 'f6');
      expect(added.ratingMax, 5);
      expect(d2.fields.map((f) => f.id), ['f1', 'f6', 'f2']);
      d = ModuleBuilderRules.duplicateField(d2, 'f1', 'A copy');
      expect(d.fields.map((f) => f.id), ['f1', 'f7', 'f6', 'f2']);
      d = ModuleBuilderRules.reorderFields(d, const ['f6', 'f1', 'f7']);
      expect(d.fields.map((f) => f.id), ['f6', 'f1', 'f7', 'f2']);
      d = ModuleBuilderRules.restoreField(d, 'f2');
      expect(d.visibleFields.map((f) => f.id), ['f6', 'f1', 'f7', 'f2']);
      d = ModuleBuilderRules.removeField(d, 'f1');
      expect(d.fields.map((f) => f.id), ['f6', 'f7', 'f2']);
    });

    test('reconcileChart follows the remaining chartable fields', () {
      final d = _module(const [
        ModuleField(id: 'f1', label: 'A', type: FieldType.text),
        ModuleField(id: 'f3', label: 'N', type: FieldType.number),
      ]).copyWith(chart: const ModuleChartConfig(type: ModuleChartType.line, fieldId: 'f2'));
      expect(ModuleBuilderRules.reconcileChart(d)!.fieldId, 'f3');
      final none = d.copyWith(fields: const [ModuleField(id: 'f1', label: 'A', type: FieldType.text)]);
      expect(ModuleBuilderRules.reconcileChart(none)!.fieldId, isNull);
    });
  });
}
