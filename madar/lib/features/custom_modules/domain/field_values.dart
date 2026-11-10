/// Reading, validating and normalising custom-entry values.
///
/// Stored shapes (`custom_entries.entry_values`, field id → value):
/// * text → `String`
/// * number → `num` (int when the field has no decimals)
/// * date → `"yyyy-MM-dd"` (older/imported rows: any ISO date-time)
/// * time → `"HH:mm"`
/// * checkbox → `bool`
/// * singleSelect → option id; multiSelect → `List<String>` of option ids
/// * rating → `int` 1…max
/// * currency → `{"milli": int, "currency": "JOD"}` (integer milli-units)
///
/// Pure Dart.
library;

import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import 'module_schema.dart';

abstract final class FieldValues {
  static bool isEmpty(Object? v) => switch (v) {
    null => true,
    String s => s.trim().isEmpty,
    List l => l.isEmpty,
    Map m => m.isEmpty,
    _ => false,
  };

  static String? text(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    return '$v';
  }

  static final RegExp _noise = RegExp('[\\s\u00A0\u202F\u200E\u200F\u061C\u2066-\u2069\u202A-\u202E]');
  static final RegExp _numeric = RegExp(r'^[-+]?[\d.,]+$');

  /// A number from a number or a (localised) numeric string: any digit
  /// script, `٫` / `.` / `,` separators; nothing else ("12 pages" is not a
  /// number).
  static num? number(Object? v) {
    if (v is num) return v.isFinite ? v : null;
    if (v is String) {
      final folded = MoneyText.foldDigits(v).replaceAll(_noise, '').replaceAll('\u060C', ',');
      if (!_numeric.hasMatch(folded)) return null;
      final c = MoneyText.canonicalDecimal(folded);
      if (c == null) return null;
      final d = double.tryParse(c);
      if (d == null || !d.isFinite) return null;
      return d == d.roundToDouble() && !c.contains('.') ? d.round() : d;
    }
    if (v is Map && v['milli'] is num) return (v['milli'] as num) / Money.milliPerUnit;
    return null;
  }

  static bool? checkbox(Object? v) => switch (v) {
    bool b => b,
    num n => n != 0,
    String s when const {'true', '1', 'yes', 'y', 'نعم', '✓'}.contains(s.trim().toLowerCase()) => true,
    String s when const {'false', '0', 'no', 'n', 'لا', ''}.contains(s.trim().toLowerCase()) => false,
    _ => null,
  };

  static final RegExp _ymd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');

  /// A calendar day (local midnight).
  static DateTime? date(Object? v) {
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    if (v is String) {
      final s = MoneyText.foldDigits(v.trim());
      final m = _ymd.firstMatch(s);
      if (m == null) return null;
      final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
      if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
      final day = DateTime(y, mo, d);
      if (day.month != mo || day.day != d) return null;
      return day;
    }
    return null;
  }

  static String encodeDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static final RegExp _hm = RegExp(r'^(\d{1,2})[:.٫](\d{2})(?::\d{2})?$');

  /// `"HH:mm"`.
  static String? time(Object? v) {
    if (v is DateTime) return encodeTime(v.hour, v.minute);
    if (v is String) {
      final m = _hm.firstMatch(MoneyText.foldDigits(v.trim()));
      if (m == null) return null;
      final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
      if (h > 23 || mi > 59) return null;
      return encodeTime(h, mi);
    }
    return null;
  }

  static String encodeTime(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Minutes after midnight of a `"HH:mm"` value.
  static int? minutesOf(Object? v) {
    final t = time(v);
    if (t == null) return null;
    return int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3));
  }

  static String? single(Object? v) => switch (v) {
    String s when s.trim().isNotEmpty => s,
    num n => '$n',
    List l when l.isNotEmpty => '${l.first}',
    _ => null,
  };

  static List<String> multi(Object? v) => switch (v) {
    List l => [
      for (final x in l)
        if (x != null && '$x'.trim().isNotEmpty) '$x',
    ],
    String s when s.trim().isNotEmpty => [s],
    _ => const [],
  };

  static int? rating(Object? v) {
    final n = number(v);
    if (n == null) return null;
    final r = n.round();
    return r <= 0 ? null : r;
  }

  /// An amount (stored `{"milli","currency"}`; a bare number counts as units
  /// of [fallbackCurrency]).
  static Money? money(Object? v, {String fallbackCurrency = ModuleField.defaultCurrency}) {
    if (v is Money) return v;
    if (v is Map) {
      final milli = v['milli'];
      final cur = v['currency'];
      if (milli is num) return Money(milli.round(), cur is String && cur.isNotEmpty ? cur : fallbackCurrency);
      final amount = v['amount'];
      if (amount is num) return Money.fromUnits(amount, cur is String && cur.isNotEmpty ? cur : fallbackCurrency);
      return null;
    }
    if (v is num) return Money.fromUnits(v, fallbackCurrency);
    if (v is String) return Money.tryParse(v, fallbackCurrency: fallbackCurrency);
    return null;
  }

  /// The value of [f] as a number for charts: numbers and amounts as they
  /// are (amounts in units), ratings as stars, a ticked checkbox as 1.
  static double? numeric(ModuleField f, Object? v) => switch (f.type) {
    FieldType.number => number(v)?.toDouble(),
    FieldType.rating => rating(v)?.toDouble(),
    FieldType.checkbox => switch (checkbox(v)) {
      true => 1,
      false => 0,
      null => null,
    },
    FieldType.currency => money(v, fallbackCurrency: f.currencyCode)?.units,
    _ => null,
  };

  /// The canonical stored form of an already-typed value, or null when it
  /// is empty or does not fit the type.
  static Object? normalize(ModuleField f, Object? v) {
    if (isEmpty(v)) return null;
    switch (f.type) {
      case FieldType.text:
        return text(v);
      case FieldType.number:
        final n = number(v);
        if (n == null) return null;
        return f.decimals == 0 && n == n.roundToDouble() ? n.round() : n.toDouble();
      case FieldType.date:
        final d = date(v);
        return d == null ? null : encodeDate(d);
      case FieldType.time:
        return time(v);
      case FieldType.checkbox:
        return checkbox(v);
      case FieldType.singleSelect:
        return single(v);
      case FieldType.multiSelect:
        final l = multi(v);
        return l.isEmpty ? null : l;
      case FieldType.rating:
        return rating(v);
      case FieldType.currency:
        return money(v, fallbackCurrency: f.currencyCode)?.toJson();
    }
  }
}

// --------------------------------------------------------------- validation --

/// Why a value was refused.
enum EntryIssue {
  /// A required field is empty.
  required,

  /// Not a number (or amount).
  notANumber,

  /// A whole number was expected.
  notWhole,

  /// More decimals than the field allows.
  tooPrecise,

  /// Below the field's minimum.
  belowMin,

  /// Above the field's maximum.
  aboveMax,

  invalidDate,
  invalidTime,

  /// An option that does not exist (any more).
  unknownOption,

  /// A rating outside 1…max.
  outOfScale,

  /// Longer than [EntryValidator.maxTextLength].
  tooLong,
}

/// The outcome of checking one field: the value to store (null = empty) or
/// the [issue] (with the offending [bound] for min / max / decimals).
class FieldCheck {
  const FieldCheck.ok(this.value) : issue = null, bound = null;
  const FieldCheck.fail(EntryIssue this.issue, {this.bound}) : value = null;

  final Object? value;
  final EntryIssue? issue;
  final num? bound;

  bool get ok => issue == null;

  @override
  String toString() => ok ? 'ok($value)' : 'fail(${issue!.name}${bound == null ? '' : ' $bound'})';
}

/// The outcome of checking a whole entry form.
class EntryCheck {
  const EntryCheck(this.values, this.issues);

  /// Field id → value to store (empty fields left out).
  final Map<String, Object?> values;

  /// Field id → problem.
  final Map<String, FieldCheck> issues;

  bool get ok => issues.isEmpty;
}

/// Turns what the user typed or picked into stored values, per field type.
///
/// Inputs: text fields give the raw `String` (any digit script, `٫`, grouping
/// separators); pickers give typed values (`DateTime`, `"HH:mm"`, `bool`,
/// option id(s), `int` stars, [Money] or an amount string for currency).
abstract final class EntryValidator {
  static const int maxTextLength = 4000;

  static FieldCheck check(ModuleField f, Object? input) {
    if (FieldValues.isEmpty(input) || (f.type == FieldType.rating && input is num && input <= 0)) {
      if (f.type == FieldType.checkbox) return const FieldCheck.ok(false);
      return f.isRequired ? const FieldCheck.fail(EntryIssue.required) : const FieldCheck.ok(null);
    }
    switch (f.type) {
      case FieldType.text:
        final s = FieldValues.text(input)!;
        if (s.length > maxTextLength) return const FieldCheck.fail(EntryIssue.tooLong, bound: maxTextLength);
        return FieldCheck.ok(s);

      case FieldType.number:
        final n = FieldValues.number(input);
        if (n == null) return const FieldCheck.fail(EntryIssue.notANumber);
        if (f.decimals == 0 && n != n.roundToDouble()) return const FieldCheck.fail(EntryIssue.notWhole);
        if (f.decimals > 0 && !_fitsDecimals(n, f.decimals)) {
          return FieldCheck.fail(EntryIssue.tooPrecise, bound: f.decimals);
        }
        if (f.min != null && n < f.min!) return FieldCheck.fail(EntryIssue.belowMin, bound: f.min);
        if (f.max != null && n > f.max!) return FieldCheck.fail(EntryIssue.aboveMax, bound: f.max);
        return FieldCheck.ok(f.decimals == 0 ? n.round() : n.toDouble());

      case FieldType.currency:
        final Money? m;
        if (input is String) {
          final milli = FieldValues.number(input) == null ? null : MoneyText.parseMilli(input);
          m = milli == null ? null : Money(milli, f.currencyCode);
          if (m != null && !_fitsDecimals(m.milli / Money.milliPerUnit, CurrencyCatalog.decimalsFor(m.currency))) {
            return FieldCheck.fail(EntryIssue.tooPrecise, bound: CurrencyCatalog.decimalsFor(m.currency));
          }
        } else {
          m = FieldValues.money(input, fallbackCurrency: f.currencyCode);
        }
        if (m == null) return const FieldCheck.fail(EntryIssue.notANumber);
        final units = m.milli / Money.milliPerUnit;
        final min = f.min ?? 0;
        if (units < min) return FieldCheck.fail(EntryIssue.belowMin, bound: min);
        if (f.max != null && units > f.max!) return FieldCheck.fail(EntryIssue.aboveMax, bound: f.max);
        return FieldCheck.ok(m.toJson());

      case FieldType.date:
        final d = FieldValues.date(input);
        return d == null ? const FieldCheck.fail(EntryIssue.invalidDate) : FieldCheck.ok(FieldValues.encodeDate(d));

      case FieldType.time:
        final t = FieldValues.time(input);
        return t == null ? const FieldCheck.fail(EntryIssue.invalidTime) : FieldCheck.ok(t);

      case FieldType.checkbox:
        final b = FieldValues.checkbox(input);
        return b == null ? const FieldCheck.fail(EntryIssue.unknownOption) : FieldCheck.ok(b);

      case FieldType.singleSelect:
        final id = FieldValues.single(input);
        if (id == null || f.option(id) == null) return const FieldCheck.fail(EntryIssue.unknownOption);
        return FieldCheck.ok(id);

      case FieldType.multiSelect:
        final ids = FieldValues.multi(input).toSet().toList();
        if (ids.any((id) => f.option(id) == null)) return const FieldCheck.fail(EntryIssue.unknownOption);
        if (ids.isEmpty) return f.isRequired ? const FieldCheck.fail(EntryIssue.required) : const FieldCheck.ok(null);
        // Stored in the field's option order.
        final order = {for (var i = 0; i < f.options.length; i++) f.options[i].id: i};
        ids.sort((a, b) => order[a]!.compareTo(order[b]!));
        return FieldCheck.ok(ids);

      case FieldType.rating:
        final n = FieldValues.number(input);
        if (n == null || n != n.roundToDouble()) return const FieldCheck.fail(EntryIssue.outOfScale);
        final r = n.round();
        if (r < 1 || r > f.ratingMax) return FieldCheck.fail(EntryIssue.outOfScale, bound: f.ratingMax);
        return FieldCheck.ok(r);
    }
  }

  /// Checks every visible field of [fields]; values of hidden fields in
  /// [keep] (the entry being edited) are carried over untouched.
  static EntryCheck checkAll(
    List<ModuleField> fields,
    Map<String, Object?> inputs, {
    Map<String, Object?> keep = const {},
  }) {
    final values = <String, Object?>{};
    final issues = <String, FieldCheck>{};
    for (final f in fields) {
      if (f.hidden) {
        final old = keep[f.id];
        if (!FieldValues.isEmpty(old)) values[f.id] = old;
        continue;
      }
      final c = check(f, inputs[f.id]);
      if (!c.ok) {
        issues[f.id] = c;
      } else if (c.value != null) {
        values[f.id] = c.value;
      }
    }
    // Values for ids the schema does not know (never lose data).
    for (final e in keep.entries) {
      if (!fields.any((f) => f.id == e.key) && !FieldValues.isEmpty(e.value)) values[e.key] = e.value;
    }
    return EntryCheck(values, issues);
  }

  static bool _fitsDecimals(num n, int decimals) {
    final scaled = n * _pow10(decimals);
    return (scaled - scaled.roundToDouble()).abs() < 1e-6;
  }

  static num _pow10(int n) {
    var p = 1;
    for (var i = 0; i < n; i++) {
      p *= 10;
    }
    return p;
  }
}
