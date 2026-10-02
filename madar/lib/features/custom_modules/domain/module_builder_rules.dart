/// The builder's pure rules: what a module needs before it can be saved, and
/// the field-list operations (add / duplicate / remove / restore / move).
library;

import '../../../core/domain/enums.dart';
import 'module_schema.dart';

enum DraftIssue {
  nameMissing,
  nameTooLong,
  noFields,
  tooManyFields,
  labelMissing,
  labelDuplicate,
  noOptions,
  optionLabelMissing,
  optionDuplicate,
  rangeInverted,
  currencyCode,
}

class DraftProblem {
  const DraftProblem(this.issue, [this.fieldId]);

  final DraftIssue issue;

  /// The field concerned (null for module-level problems).
  final String? fieldId;

  @override
  bool operator ==(Object other) => other is DraftProblem && other.issue == issue && other.fieldId == fieldId;

  @override
  int get hashCode => Object.hash(issue, fieldId);

  @override
  String toString() => 'DraftProblem(${issue.name}${fieldId == null ? '' : ', $fieldId'})';
}

abstract final class ModuleBuilderRules {
  static const int maxNameLength = 60;
  static const int maxFields = 30;
  static const int maxLabelLength = 60;
  static final RegExp _currency = RegExp(r'^[A-Z]{3}$');

  /// Every reason [draft] cannot be saved (empty = valid).
  static List<DraftProblem> check(ModuleDefinition draft) {
    final out = <DraftProblem>[];
    final name = draft.name.trim();
    if (name.isEmpty) out.add(const DraftProblem(DraftIssue.nameMissing));
    if (name.length > maxNameLength) out.add(const DraftProblem(DraftIssue.nameTooLong));
    final visible = draft.visibleFields;
    if (visible.isEmpty && draft.isList) out.add(const DraftProblem(DraftIssue.noFields));
    if (visible.length > maxFields) out.add(const DraftProblem(DraftIssue.tooManyFields));
    final labels = <String>{};
    for (final f in visible) {
      final label = f.label.trim();
      if (label.isEmpty) {
        out.add(DraftProblem(DraftIssue.labelMissing, f.id));
      } else if (!labels.add(label.toLowerCase())) {
        out.add(DraftProblem(DraftIssue.labelDuplicate, f.id));
      }
      out.addAll(checkField(f));
    }
    return out;
  }

  /// Problems of one field's own settings.
  static List<DraftProblem> checkField(ModuleField f) {
    final out = <DraftProblem>[];
    if (f.isSelect) {
      final visible = f.visibleOptions;
      if (visible.isEmpty) out.add(DraftProblem(DraftIssue.noOptions, f.id));
      final seen = <String>{};
      for (final o in visible) {
        final l = o.label.trim();
        if (l.isEmpty) {
          out.add(DraftProblem(DraftIssue.optionLabelMissing, f.id));
          break;
        }
        if (!seen.add(l.toLowerCase())) {
          out.add(DraftProblem(DraftIssue.optionDuplicate, f.id));
          break;
        }
      }
    }
    if ((f.type == FieldType.number || f.type == FieldType.currency) &&
        f.min != null &&
        f.max != null &&
        f.min! > f.max!) {
      out.add(DraftProblem(DraftIssue.rangeInverted, f.id));
    }
    if (f.type == FieldType.currency && !_currency.hasMatch(f.currencyCode)) {
      out.add(DraftProblem(DraftIssue.currencyCode, f.id));
    }
    return out;
  }

  /// A new, empty module.
  static ModuleDefinition blank({required int colorArgb, String? planetKey, CustomModuleKind kind = CustomModuleKind.tracker}) =>
      ModuleDefinition(id: '', name: '', kind: kind, colorArgb: colorArgb, planetKey: planetKey);

  // --------------------------------------------------------- operations --

  /// Adds a field of [type] labelled [label] at the end of the visible
  /// fields. Its id is new to the module *and* to every value key in
  /// [takenIds] (ids entries hold), so it can never adopt old data.
  static (ModuleDefinition, ModuleField) addField(
    ModuleDefinition d,
    FieldType type,
    String label, {
    Iterable<String> takenIds = const [],
    List<FieldOption> options = const [],
  }) {
    final id = ModuleIds.nextFieldId([...d.fields.map((f) => f.id), ...takenIds]);
    final field = ModuleField(
      id: id,
      label: label,
      type: type,
      options: options,
      max: type == FieldType.rating ? ModuleField.defaultRatingMax : null,
      currency: type == FieldType.currency ? ModuleField.defaultCurrency : null,
    );
    return (d.copyWith(fields: _withVisible(d, [...d.visibleFields, field])), field);
  }

  /// Replaces the field with the same id.
  static ModuleDefinition replaceField(ModuleDefinition d, ModuleField field) =>
      d.copyWith(fields: [for (final f in d.fields) f.id == field.id ? field : f]);

  /// A copy of field [id] right after it, labelled [label].
  static ModuleDefinition duplicateField(
    ModuleDefinition d,
    String id,
    String label, {
    Iterable<String> takenIds = const [],
  }) {
    final src = d.field(id);
    if (src == null) return d;
    final newId = ModuleIds.nextFieldId([...d.fields.map((f) => f.id), ...takenIds]);
    final copy = src.withId(newId).copyWith(label: label, hidden: false);
    final visible = [...d.visibleFields];
    final at = visible.indexWhere((f) => f.id == id);
    visible.insert(at < 0 ? visible.length : at + 1, copy);
    return d.copyWith(fields: _withVisible(d, visible));
  }

  /// Takes field [id] out of the module. Saving decides whether it is
  /// dropped (no values) or kept hidden (see `FieldMigration`).
  static ModuleDefinition removeField(ModuleDefinition d, String id) =>
      d.copyWith(fields: [for (final f in d.fields) if (f.id != id) f]);

  /// Shows a hidden field again (at the end of the visible fields).
  static ModuleDefinition restoreField(ModuleDefinition d, String id) {
    final f = d.field(id);
    if (f == null || !f.hidden) return d;
    final visible = [...d.visibleFields, f.copyWith(hidden: false)];
    return d.copyWith(fields: [...visible, for (final h in d.hiddenFields) if (h.id != id) h]);
  }

  /// Reorders the visible fields ([ids] = the new visible order); hidden
  /// fields stay behind them.
  static ModuleDefinition reorderFields(ModuleDefinition d, List<String> ids) {
    final byId = {for (final f in d.visibleFields) f.id: f};
    final ordered = [
      for (final id in ids)
        ?byId[id],
      for (final f in d.visibleFields)
        if (!ids.contains(f.id)) f,
    ];
    return d.copyWith(fields: _withVisible(d, ordered));
  }

  static List<ModuleField> _withVisible(ModuleDefinition d, List<ModuleField> visible) => [...visible, ...d.hiddenFields];

  /// The chart after a schema edit: kept when its field is still a visible
  /// chartable field, else pointed at the first chartable field (or at the
  /// entry count).
  static ModuleChartConfig? reconcileChart(ModuleDefinition d) {
    final c = d.chart;
    if (c == null) return null;
    if (c.fieldId == null || d.chartableFields.any((f) => f.id == c.fieldId)) return c;
    final first = d.chartableFields.firstOrNull;
    return first == null ? c.copyWith(clearField: true) : c.copyWith(fieldId: first.id);
  }
}
