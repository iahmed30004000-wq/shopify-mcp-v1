import 'package:flutter/material.dart' show Icons;

import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import '../../custom_modules/domain/field_values.dart';
import '../../custom_modules/domain/module_schema.dart';
import '../domain/search_doc.dart';
import 'search_source.dart';

/// Custom modules in the global search, generically: every module is a
/// group of its own (its name, icon and colour, next to the built-in
/// modules), its entries are written up from the module's field labels and
/// the entry values.
abstract final class CustomModuleSearch {
  static const String modulesSourceId = 'custom_modules';
  static const String entriesSourceId = 'custom_entries';

  /// The group of a module's records.
  static String groupOf(String moduleId) => 'module:$moduleId';

  /// Planet of a module (`custom` when it has none).
  static String planetOf(CustomModuleRowLike m) => (m.planetKey == null || m.planetKey!.isEmpty) ? 'custom' : m.planetKey!;

  /// The modules themselves (name, field labels).
  static SearchSource modules() => SearchSource(
    id: modulesSourceId,
    planetKey: 'custom',
    icon: Icons.widgets_rounded,
    labelKey: 'searchSourceCustomModules',
    tables: const {'custom_modules'},
    load: (c) async => [
      for (final m in await c.repos.customModules.getAll())
        () {
          final like = CustomModuleRowLike(m.id, m.name, m.planetKey, m.icon, m.color);
          final fields = ModuleDefinition.parseFields(m.fields).where((f) => !f.hidden);
          return SearchDoc(
            id: m.id,
            refTable: 'custom_modules',
            refId: m.id,
            title: m.name,
            subtitle: SearchLoadContext.join([
              fields.map((f) => f.label).join('، '),
              if (m.archived) c.l10n.searchArchived,
            ]),
            planetKey: planetOf(like),
            group: groupOf(m.id),
            groupLabel: m.name,
            groupIcon: m.icon,
            groupColor: m.color,
            extra: {'moduleId': m.id},
          );
        }(),
    ],
  );

  /// Every entry of every module.
  static SearchSource entries() => SearchSource(
    id: entriesSourceId,
    planetKey: 'custom',
    icon: Icons.dashboard_customize_rounded,
    labelKey: 'searchSourceCustomEntries',
    tables: const {'custom_entries', 'custom_modules'},
    load: (c) async {
      final modules = {
        for (final m in await c.repos.customModules.getAll())
          m.id: (
            row: CustomModuleRowLike(m.id, m.name, m.planetKey, m.icon, m.color),
            fields: ModuleDefinition.parseFields(m.fields).where((f) => !f.hidden).toList(),
          ),
      };
      final out = <SearchDoc>[];
      for (final e in await c.repos.customEntries.getAll()) {
        final m = modules[e.moduleId];
        if (m == null) continue;
        out.add(entryDoc(c, m.row, m.fields, e.id, e.at, e.entryValues, done: e.done));
      }
      return out;
    },
  );

  /// One entry written up: the first text field is the title (else the
  /// module's name), the other answered fields become «Label: value».
  static SearchDoc entryDoc(
    SearchLoadContext c,
    CustomModuleRowLike module,
    List<ModuleField> fields,
    String entryId,
    DateTime at,
    Map<String, Object?> values, {
    bool done = false,
  }) {
    ModuleField? titleField;
    for (final f in fields) {
      if (f.type == FieldType.text && FieldValues.text(values[f.id]) != null) {
        titleField = f;
        break;
      }
    }
    final parts = <String>[];
    for (final f in fields) {
      if (identical(f, titleField)) continue;
      final v = describe(c, f, values[f.id]);
      if (v == null) continue;
      parts.add(f.type == FieldType.checkbox ? v : '${f.label}: $v');
    }
    return SearchDoc(
      id: entryId,
      refTable: 'custom_entries',
      refId: entryId,
      title: titleField == null ? module.name : FieldValues.text(values[titleField.id])!,
      subtitle: SearchLoadContext.join([if (titleField != null) module.name, if (done) c.l10n.searchDone]),
      body: parts.join(' · '),
      date: at,
      planetKey: planetOf(module),
      group: groupOf(module.id),
      groupLabel: module.name,
      groupIcon: module.icon,
      groupColor: module.color,
      extra: {'moduleId': module.id},
    );
  }

  /// A field's value as text (null when unanswered). A ticked checkbox is
  /// its label.
  static String? describe(SearchLoadContext c, ModuleField f, Object? v) {
    if (FieldValues.isEmpty(v)) return null;
    final fmt = c.formatter;
    switch (f.type) {
      case FieldType.text:
        return FieldValues.text(v);
      case FieldType.number:
        final n = FieldValues.number(v);
        if (n == null) return FieldValues.text(v);
        return '${fmt.formatNumber(n, maxDecimals: f.decimals.clamp(0, 3))} ${f.unit ?? ''}'.trim();
      case FieldType.date:
        final d = FieldValues.date(v);
        return d == null ? FieldValues.text(v) : c.date(d);
      case FieldType.time:
        final t = FieldValues.time(v);
        return t == null ? null : fmt.localizeDigits(t);
      case FieldType.checkbox:
        return FieldValues.checkbox(v) == true ? f.label : null;
      case FieldType.singleSelect:
        final id = FieldValues.single(v);
        return id == null ? null : (f.option(id)?.label ?? id);
      case FieldType.multiSelect:
        final ids = FieldValues.multi(v);
        return ids.isEmpty ? null : ids.map((id) => f.option(id)?.label ?? id).join('، ');
      case FieldType.rating:
        final r = FieldValues.rating(v);
        return r == null ? null : fmt.localizeDigits('★ $r/${f.ratingMax}');
      case FieldType.currency:
        final Money? m = FieldValues.money(v, fallbackCurrency: f.currencyCode);
        return m == null ? null : c.money(m.milli, m.currency);
    }
  }
}

/// The parts of a `custom_modules` row the search needs.
class CustomModuleRowLike {
  const CustomModuleRowLike(this.id, this.name, this.planetKey, this.icon, this.color);

  final String id;
  final String name;
  final String? planetKey;
  final String icon;
  final int color;
}
