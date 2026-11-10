/// Safe schema changes for a module that already has entries.
///
/// Rules:
/// * Fields are matched by **id**: renaming a field keeps its id, so its
///   values stay attached.
/// * A removed field whose values some entry still holds is **hidden**, not
///   destroyed (appended at the end with `hidden: true`, restorable, still
///   exported). A removed field with no values is dropped.
/// * A removed select option that entries use is kept **hidden** too.
/// * A type change converts every existing value or is **blocked** (nothing
///   is ever silently lost). Converting to a select creates the options the
///   old values need.
/// * New bounds / a new "required" never touch data: they are reported as
///   warnings (existing values stay as they are).
///
/// Pure Dart.
library;

import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import 'field_values.dart';
import 'module_schema.dart';

enum MigrationIssueKind {
  /// Blocking: some values cannot be converted to the new type.
  typeChangeBlocked,

  /// Blocking: a rating's new scale is below stars already given.
  ratingScaleBlocked,

  /// A removed field still has values: it is kept hidden.
  fieldHidden,

  /// A removed option is still used: it is kept hidden.
  optionHidden,

  /// Values were converted to the field's new type.
  valuesConverted,

  /// Values lie outside the new min / max (kept as they are).
  outOfRange,

  /// Entries lack a value for a field that is now required.
  newlyRequired,
}

class MigrationIssue {
  const MigrationIssue({
    required this.kind,
    required this.fieldId,
    required this.fieldLabel,
    required this.count,
    this.from,
    this.to,
  });

  final MigrationIssueKind kind;
  final String fieldId;
  final String fieldLabel;

  /// Entries (or, for [MigrationIssueKind.optionHidden], options) concerned.
  final int count;
  final FieldType? from;
  final FieldType? to;

  bool get blocking => kind == MigrationIssueKind.typeChangeBlocked || kind == MigrationIssueKind.ratingScaleBlocked;

  @override
  String toString() => 'MigrationIssue(${kind.name}, $fieldId, $count)';
}

/// An entry's id and values (the planner's input).
typedef EntryValuesRow = ({String id, Map<String, Object?> values});

class FieldMigrationPlan {
  const FieldMigrationPlan({required this.fields, required this.entryUpdates, required this.issues});

  /// The schema to store (hidden fields included).
  final List<ModuleField> fields;

  /// Entry id → its complete new values (only entries that change).
  final Map<String, Map<String, Object?>> entryUpdates;
  final List<MigrationIssue> issues;

  bool get canApply => !issues.any((i) => i.blocking);
  List<MigrationIssue> get blocking => [
    for (final i in issues)
      if (i.blocking) i,
  ];
  List<MigrationIssue> get warnings => [
    for (final i in issues)
      if (!i.blocking) i,
  ];
}

/// The result of converting one value.
sealed class Converted {
  const Converted();
}

final class ConvertedValue extends Converted {
  const ConvertedValue(this.value);
  final Object? value;
}

final class ConversionFailed extends Converted {
  const ConversionFailed();
}

abstract final class FieldMigration {
  /// Plans the change of a module's fields from [before] to [after] given
  /// its [entries]. [after] is what the builder produced (visible fields in
  /// order, plus hidden ones the user kept).
  static FieldMigrationPlan plan({
    required List<ModuleField> before,
    required List<ModuleField> after,
    required List<EntryValuesRow> entries,
  }) {
    final beforeById = {for (final f in before) f.id: f};
    final afterIds = {for (final f in after) f.id};
    final updates = <String, Map<String, Object?>>{};
    final issues = <MigrationIssue>[];
    final fields = <ModuleField>[];

    Map<String, Object?> working(EntryValuesRow e) => updates[e.id] ??= Map<String, Object?>.of(e.values);

    for (var a in after) {
      final b = beforeById[a.id];
      if (b == null) {
        fields.add(a);
        continue;
      }
      final used = [
        for (final e in entries)
          if (!FieldValues.isEmpty(e.values[a.id])) e,
      ];

      // Type change: convert every value or block.
      if (a.type != b.type && used.isNotEmpty) {
        if (a.isSelect) a = _withOptionsFor(b, a, [for (final e in used) e.values[a.id]]);
        final converted = <String, Object?>{};
        var failed = 0;
        for (final e in used) {
          switch (convert(b, a, e.values[a.id])) {
            case ConvertedValue(:final value):
              converted[e.id] = value;
            case ConversionFailed():
              failed++;
          }
        }
        if (failed > 0) {
          issues.add(
            MigrationIssue(
              kind: MigrationIssueKind.typeChangeBlocked,
              fieldId: a.id,
              fieldLabel: a.label,
              count: failed,
              from: b.type,
              to: a.type,
            ),
          );
        } else {
          for (final e in used) {
            final v = converted[e.id];
            final values = working(e);
            if (v == null) {
              values.remove(a.id);
            } else {
              values[a.id] = v;
            }
          }
          issues.add(
            MigrationIssue(
              kind: MigrationIssueKind.valuesConverted,
              fieldId: a.id,
              fieldLabel: a.label,
              count: used.length,
              from: b.type,
              to: a.type,
            ),
          );
        }
      }

      // Removed options still in use stay hidden.
      if (a.type == b.type && a.isSelect) {
        final keptIds = {for (final o in a.options) o.id};
        final usedIds = <String>{
          for (final e in used)
            ...(a.type == FieldType.multiSelect
                ? FieldValues.multi(e.values[a.id])
                : [?FieldValues.single(e.values[a.id])]),
        };
        final revived = [
          for (final o in b.options)
            if (!keptIds.contains(o.id) && usedIds.contains(o.id)) o.copyWith(hidden: true),
        ];
        if (revived.isNotEmpty) {
          a = a.copyWith(options: [...a.options, ...revived]);
          issues.add(
            MigrationIssue(
              kind: MigrationIssueKind.optionHidden,
              fieldId: a.id,
              fieldLabel: a.label,
              count: revived.length,
            ),
          );
        }
      }

      // A smaller rating scale than stars already given.
      if (a.type == FieldType.rating && b.type == FieldType.rating) {
        final over = used.where((e) => (FieldValues.rating(e.values[a.id]) ?? 0) > a.ratingMax).length;
        if (over > 0) {
          issues.add(
            MigrationIssue(
              kind: MigrationIssueKind.ratingScaleBlocked,
              fieldId: a.id,
              fieldLabel: a.label,
              count: over,
            ),
          );
        }
      }

      // Bounds: report, never touch.
      if ((a.type == FieldType.number || a.type == FieldType.currency) && (a.min != null || a.max != null)) {
        var out = 0;
        for (final e in used) {
          final v = FieldValues.numeric(a, updates[e.id]?[a.id] ?? e.values[a.id]);
          if (v == null) continue;
          if ((a.min != null && v < a.min!) || (a.max != null && v > a.max!)) out++;
        }
        if (out > 0) {
          issues.add(
            MigrationIssue(kind: MigrationIssueKind.outOfRange, fieldId: a.id, fieldLabel: a.label, count: out),
          );
        }
      }

      // Newly required.
      if (a.isRequired && !b.isRequired && !a.hidden) {
        final missing = entries.length - used.length;
        if (missing > 0) {
          issues.add(
            MigrationIssue(
              kind: MigrationIssueKind.newlyRequired,
              fieldId: a.id,
              fieldLabel: a.label,
              count: missing,
            ),
          );
        }
      }
      fields.add(a);
    }

    // Removed fields: hidden while entries hold values, else dropped.
    for (final b in before) {
      if (afterIds.contains(b.id)) continue;
      final count = entries.where((e) => !FieldValues.isEmpty(e.values[b.id])).length;
      if (count == 0) continue;
      fields.add(b.copyWith(hidden: true));
      if (!b.hidden) {
        issues.add(
          MigrationIssue(kind: MigrationIssueKind.fieldHidden, fieldId: b.id, fieldLabel: b.label, count: count),
        );
      }
    }

    // Only entries whose values really change.
    updates.removeWhere((id, values) {
      final original = entries.firstWhere((e) => e.id == id).values;
      return _sameValues(original, values);
    });
    return FieldMigrationPlan(fields: fields, entryUpdates: updates, issues: issues);
  }

  /// Converts one non-empty value of [from] to the type of [to].
  static Converted convert(ModuleField from, ModuleField to, Object? v) {
    if (FieldValues.isEmpty(v)) return const ConvertedValue(null);
    if (from.type == to.type) return ConvertedValue(v);
    const fail = ConversionFailed();
    final asText = plainText(from, v);
    switch (to.type) {
      case FieldType.text:
        if (from.type == FieldType.checkbox) return fail;
        return asText == null ? fail : ConvertedValue(asText);

      case FieldType.number:
        final n = switch (from.type) {
          FieldType.rating => FieldValues.rating(v),
          FieldType.checkbox => switch (FieldValues.checkbox(v)) {
            true => 1,
            false => 0,
            null => null,
          },
          FieldType.currency => FieldValues.money(v, fallbackCurrency: from.currencyCode)?.units,
          FieldType.text || FieldType.singleSelect => asText == null ? null : FieldValues.number(asText),
          _ => null,
        };
        if (n == null) return fail;
        return ConvertedValue(to.decimals == 0 && n == n.roundToDouble() ? n.round() : n.toDouble());

      case FieldType.rating:
        final n = switch (from.type) {
          FieldType.number => FieldValues.number(v),
          FieldType.text || FieldType.singleSelect => asText == null ? null : FieldValues.number(asText),
          _ => null,
        };
        if (n == null || n != n.roundToDouble() || n < 1 || n > to.ratingMax) return fail;
        return ConvertedValue(n.round());

      case FieldType.currency:
        final n = switch (from.type) {
          FieldType.number => FieldValues.number(v),
          FieldType.text => asText == null ? null : FieldValues.number(asText),
          _ => null,
        };
        if (n == null) return fail;
        return ConvertedValue(Money.fromUnits(n, to.currencyCode).toJson());

      case FieldType.date:
        if (from.type != FieldType.text) return fail;
        final d = FieldValues.date(asText);
        return d == null ? fail : ConvertedValue(FieldValues.encodeDate(d));

      case FieldType.time:
        if (from.type != FieldType.text) return fail;
        final t = FieldValues.time(asText);
        return t == null ? fail : ConvertedValue(t);

      case FieldType.checkbox:
        final b = switch (from.type) {
          FieldType.number => switch (FieldValues.number(v)) {
            0 => false,
            1 => true,
            _ => null,
          },
          FieldType.text => FieldValues.checkbox(asText),
          _ => null,
        };
        return b == null ? fail : ConvertedValue(b);

      case FieldType.singleSelect:
        if (from.type == FieldType.multiSelect) {
          final ids = FieldValues.multi(v);
          if (ids.length > 1) return fail;
          return ids.isEmpty ? const ConvertedValue(null) : ConvertedValue(ids.single);
        }
        if (from.type == FieldType.checkbox || from.type == FieldType.currency || asText == null) return fail;
        final o = _optionByLabel(to, asText);
        return o == null ? fail : ConvertedValue(o.id);

      case FieldType.multiSelect:
        if (from.type == FieldType.singleSelect) {
          final id = FieldValues.single(v);
          return id == null ? fail : ConvertedValue([id]);
        }
        if (from.type == FieldType.checkbox || from.type == FieldType.currency || asText == null) return fail;
        final o = _optionByLabel(to, asText);
        return o == null ? fail : ConvertedValue([o.id]);
    }
  }

  /// A value as neutral text (Western digits, ISO dates, option labels):
  /// what a conversion to text stores, and what CSV export writes.
  static String? plainText(ModuleField f, Object? v) {
    if (FieldValues.isEmpty(v)) return null;
    switch (f.type) {
      case FieldType.text:
        return FieldValues.text(v);
      case FieldType.number:
        final n = FieldValues.number(v);
        return n == null ? null : plainNumber(n);
      case FieldType.rating:
        return FieldValues.rating(v)?.toString();
      case FieldType.date:
        final d = FieldValues.date(v);
        return d == null ? null : FieldValues.encodeDate(d);
      case FieldType.time:
        return FieldValues.time(v);
      case FieldType.checkbox:
        return switch (FieldValues.checkbox(v)) {
          true => 'true',
          false => 'false',
          null => null,
        };
      case FieldType.singleSelect:
        final id = FieldValues.single(v);
        return id == null ? null : (f.option(id)?.label ?? id);
      case FieldType.multiSelect:
        final ids = FieldValues.multi(v);
        return ids.isEmpty ? null : ids.map((id) => f.option(id)?.label ?? id).join(', ');
      case FieldType.currency:
        final m = FieldValues.money(v, fallbackCurrency: f.currencyCode);
        if (m == null) return null;
        return '${m.formatAmount(locale: 'en', digits: MoneyDigits.western).replaceAll(',', '')} ${m.currency}';
    }
  }

  /// `12`, `12.5`, `0.25` – no trailing zeros, no grouping.
  static String plainNumber(num n) {
    if (n is int || n == n.roundToDouble()) return n.round().toString();
    var s = n.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  /// [to] with options for every old value it has no option for yet
  /// (converting text / numbers / another select into a select).
  static ModuleField _withOptionsFor(ModuleField from, ModuleField to, List<Object?> values) {
    final options = [...to.options];
    // A select → select change keeps the old options (same ids).
    if (from.isSelect) {
      for (final o in from.options) {
        if (!options.any((x) => x.id == o.id)) options.add(o);
      }
      return to.copyWith(options: options);
    }
    if (from.type == FieldType.checkbox || from.type == FieldType.currency) return to;
    for (final v in values) {
      final label = plainText(from, v);
      if (label == null) continue;
      if (_optionByLabelIn(options, label) != null) continue;
      options.add(FieldOption(id: ModuleIds.nextOptionId(options.map((o) => o.id)), label: label));
    }
    return to.copyWith(options: options);
  }

  static FieldOption? _optionByLabel(ModuleField f, String label) =>
      f.option(label) ?? _optionByLabelIn(f.options, label);

  static FieldOption? _optionByLabelIn(List<FieldOption> options, String label) {
    final key = label.trim().toLowerCase();
    for (final o in options) {
      if (o.label.trim().toLowerCase() == key) return o;
    }
    return null;
  }

  static bool _sameValues(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !_deepEq(e.value, b[e.key])) return false;
    }
    return true;
  }

  static bool _deepEq(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    return a == b;
  }
}
