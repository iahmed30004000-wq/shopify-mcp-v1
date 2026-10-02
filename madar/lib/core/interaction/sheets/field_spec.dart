import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData, TimeOfDay;

import '../../domain/enums.dart';
import '../numbers.dart';

/// Kinds of fields the edit sheet can render.
enum FieldKind {
  text,
  multiline,
  number,
  currency,
  date,
  time,
  timeList,
  singleSelect,
  multiSelect,
  toggle,
  rating,
  slider,
  color,
  icon,
  prayerWindow,
}

/// An option of a select field.
@immutable
class SelectOption {
  const SelectOption({required this.id, required this.label, this.icon, this.color});

  final String id;
  final String label;
  final IconData? icon;

  /// Optional swatch (e.g. a planet's colour) shown as a dot on the chip.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is SelectOption && other.id == id && other.label == label && other.icon == icon && other.color == color;

  @override
  int get hashCode => Object.hash(id, label, icon, color);
}

/// An amount of money in milli-units (`amount × 1000`) and an ISO currency
/// code – the value of a [FieldKind.currency] field.
@immutable
class MoneyValue {
  const MoneyValue({required this.amountMilli, required this.currency});

  final int amountMilli;
  final String currency;

  double get amount => amountMilli / 1000;

  Map<String, Object?> toJson() => {'amountMilli': amountMilli, 'currency': currency};

  @override
  bool operator ==(Object other) =>
      other is MoneyValue && other.amountMilli == amountMilli && other.currency == currency;

  @override
  int get hashCode => Object.hash(amountMilli, currency);

  @override
  String toString() => 'MoneyValue(${LocalizedNumbers.formatMilli(amountMilli)} $currency)';
}

/// Why a field is invalid. The UI turns it into a localised message.
enum FieldIssueCode {
  required,
  invalidNumber,
  belowMin,
  aboveMax,
  tooManyDecimals,
  tooLong,
  selectAtLeast,
  selectAtMost,
  dateOutOfRange,
  custom,
}

@immutable
class FieldIssue {
  const FieldIssue(this.code, {this.limit, this.message});

  final FieldIssueCode code;

  /// The bound that was violated (min, max, decimals, count …).
  final num? limit;

  /// Message of a custom validator.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is FieldIssue && other.code == code && other.limit == limit && other.message == message;

  @override
  int get hashCode => Object.hash(code, limit, message);

  @override
  String toString() => 'FieldIssue($code${limit != null ? ', $limit' : ''}${message != null ? ', $message' : ''})';
}

/// Custom validation: return a localised error message, or null when valid.
/// [values] holds every field's current normalised value (cross-field rules).
typedef FieldValidator = String? Function(Object? value, Map<String, Object?> values);

/// The currencies Madar supports out of the box.
const List<String> kMadarCurrencies = ['JOD', 'USD', 'SYP', 'EGP', 'LYD'];

/// Declarative description of one edit-sheet field.
///
/// Result value types (what [showEditSheet] returns under [key]):
/// * text / multiline → `String?` (trimmed, null when empty)
/// * number → `int` when [decimals] is 0, else `double`; null when empty
/// * currency → [MoneyValue]? (null when the amount is empty)
/// * date → `DateTime?` (local midnight)
/// * time → `String?` `"HH:mm"`
/// * timeList → `List<String>` of `"HH:mm"`, sorted, unique
/// * singleSelect → `String?` option id
/// * multiSelect → `List<String>` option ids; options the user added inline
///   are returned as their label text (ids not present in [options])
/// * toggle → `bool`
/// * rating → `int?` (1..[max])
/// * slider → `int` ([min]..[max])
/// * color → `int?` ARGB32
/// * icon → `String?` key of [icons]
/// * prayerWindow → [PrayerWindow]?
@immutable
class FieldSpec {
  const FieldSpec._({
    required this.kind,
    required this.key,
    required this.label,
    this.required = false,
    this.hint,
    this.icon,
    this.validator,
    this.maxLength,
    this.autofocus = false,
    this.min,
    this.max,
    this.decimals = 0,
    this.unit,
    this.step,
    this.currencies = kMadarCurrencies,
    this.defaultCurrency,
    this.firstDate,
    this.lastDate,
    this.options = const [],
    this.allowAdd = false,
    this.minCount,
    this.maxCount,
    this.sliderLabels = const {},
    this.palette,
    this.icons,
    this.includeAnytime = true,
  });

  factory FieldSpec.text(
    String key,
    String label, {
    bool required = false,
    String? hint,
    IconData? icon,
    int? maxLength,
    bool autofocus = false,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.text,
    key: key,
    label: label,
    required: required,
    hint: hint,
    icon: icon,
    maxLength: maxLength,
    autofocus: autofocus,
    validator: validator,
  );

  factory FieldSpec.multiline(
    String key,
    String label, {
    bool required = false,
    String? hint,
    IconData? icon,
    int? maxLength,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.multiline,
    key: key,
    label: label,
    required: required,
    hint: hint,
    icon: icon,
    maxLength: maxLength,
    validator: validator,
  );

  /// Numeric input accepting Western, Arabic-Indic and Persian digits.
  factory FieldSpec.number(
    String key,
    String label, {
    bool required = false,
    num? min,
    num? max,
    int decimals = 0,
    String? unit,
    num? step,
    String? hint,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.number,
    key: key,
    label: label,
    required: required,
    min: min,
    max: max,
    decimals: decimals,
    unit: unit,
    step: step,
    hint: hint,
    icon: icon,
    validator: validator,
  );

  /// Amount + currency picker. Amounts allow up to [decimals] (3 = fils).
  factory FieldSpec.currency(
    String key,
    String label, {
    bool required = false,
    List<String> currencies = kMadarCurrencies,
    String? defaultCurrency,
    num? min,
    num? max,
    int decimals = 3,
    String? hint,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.currency,
    key: key,
    label: label,
    required: required,
    currencies: currencies,
    defaultCurrency: defaultCurrency,
    min: min,
    max: max,
    decimals: decimals,
    hint: hint,
    icon: icon,
    validator: validator,
  );

  factory FieldSpec.date(
    String key,
    String label, {
    bool required = false,
    DateTime? firstDate,
    DateTime? lastDate,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.date,
    key: key,
    label: label,
    required: required,
    firstDate: firstDate,
    lastDate: lastDate,
    icon: icon,
    validator: validator,
  );

  factory FieldSpec.time(
    String key,
    String label, {
    bool required = false,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(kind: FieldKind.time, key: key, label: label, required: required, icon: icon, validator: validator);

  /// Any number of `HH:mm` times (e.g. medication times).
  factory FieldSpec.timeList(
    String key,
    String label, {
    bool required = false,
    int? minCount,
    int? maxCount,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.timeList,
    key: key,
    label: label,
    required: required,
    minCount: minCount,
    maxCount: maxCount,
    icon: icon,
    validator: validator,
  );

  factory FieldSpec.singleSelect(
    String key,
    String label, {
    required List<SelectOption> options,
    bool required = false,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.singleSelect,
    key: key,
    label: label,
    options: options,
    required: required,
    icon: icon,
    validator: validator,
  );

  /// Chips; with [allowAdd] the user can type a new option inline.
  factory FieldSpec.multiSelect(
    String key,
    String label, {
    required List<SelectOption> options,
    bool allowAdd = false,
    bool required = false,
    int? minCount,
    int? maxCount,
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.multiSelect,
    key: key,
    label: label,
    options: options,
    allowAdd: allowAdd,
    required: required,
    minCount: minCount,
    maxCount: maxCount,
    icon: icon,
    validator: validator,
  );

  /// A switch; [hint] is shown as its description.
  factory FieldSpec.toggle(String key, String label, {String? hint, bool required = false, IconData? icon}) =>
      FieldSpec._(kind: FieldKind.toggle, key: key, label: label, hint: hint, required: required, icon: icon);

  /// 1..[max] stars.
  factory FieldSpec.rating(String key, String label, {int max = 5, bool required = false, IconData? icon}) =>
      FieldSpec._(kind: FieldKind.rating, key: key, label: label, max: max, required: required, icon: icon);

  /// Integer slider [min]..[max] (default 0–10); [labels] annotate values
  /// (e.g. `{0: 'None', 10: 'Worst'}`).
  factory FieldSpec.slider(
    String key,
    String label, {
    int min = 0,
    int max = 10,
    Map<int, String> labels = const {},
    IconData? icon,
    FieldValidator? validator,
  }) => FieldSpec._(
    kind: FieldKind.slider,
    key: key,
    label: label,
    min: min,
    max: max,
    sliderLabels: labels,
    icon: icon,
    validator: validator,
  );

  /// Swatches from [palette] (defaults to the curated planet palette).
  factory FieldSpec.color(String key, String label, {List<Color>? palette, bool required = false, IconData? icon}) =>
      FieldSpec._(kind: FieldKind.color, key: key, label: label, palette: palette, required: required, icon: icon);

  /// Icon grid from [icons] (defaults to the curated icon set).
  factory FieldSpec.icon(String key, String label, {Map<String, IconData>? icons, bool required = false}) =>
      FieldSpec._(kind: FieldKind.icon, key: key, label: label, icons: icons, required: required);

  /// The six prayer windows (+ "anytime" unless [includeAnytime] is false).
  factory FieldSpec.prayerWindow(
    String key,
    String label, {
    bool includeAnytime = true,
    bool required = false,
    IconData? icon,
  }) => FieldSpec._(
    kind: FieldKind.prayerWindow,
    key: key,
    label: label,
    includeAnytime: includeAnytime,
    required: required,
    icon: icon,
  );

  final FieldKind kind;
  final String key;
  final String label;
  final bool required;
  final String? hint;
  final IconData? icon;
  final FieldValidator? validator;
  final int? maxLength;
  final bool autofocus;
  final num? min;
  final num? max;
  final int decimals;
  final String? unit;
  final num? step;
  final List<String> currencies;
  final String? defaultCurrency;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final List<SelectOption> options;
  final bool allowAdd;
  final int? minCount;
  final int? maxCount;
  final Map<int, String> sliderLabels;
  final List<Color>? palette;
  final Map<String, IconData>? icons;
  final bool includeAnytime;

  /// Whether the value is edited as free text (raw text is kept separately).
  bool get isTextEntry =>
      kind == FieldKind.text || kind == FieldKind.multiline || kind == FieldKind.number || kind == FieldKind.currency;

  String get currencyFallback => defaultCurrency ?? (currencies.isEmpty ? 'JOD' : currencies.first);

  /// Converts any reasonable initial value into this field's canonical value
  /// type (see the class docs). Unknown shapes become null.
  Object? coerce(Object? raw) {
    switch (kind) {
      case FieldKind.text:
      case FieldKind.multiline:
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      case FieldKind.number:
        final n = raw is num ? raw : (raw is String ? LocalizedNumbers.parse(raw) : null);
        if (n == null) return null;
        return decimals == 0 ? (n is int ? n : (n == n.roundToDouble() ? n.toInt() : n)) : n.toDouble();
      case FieldKind.currency:
        if (raw is MoneyValue) return raw;
        if (raw is Map) {
          final cur = raw['currency'] is String ? raw['currency'] as String : currencyFallback;
          final milli = raw['amountMilli'];
          if (milli is num) return MoneyValue(amountMilli: milli.round(), currency: cur);
          final amount = raw['amount'];
          final n = amount is num ? amount : (amount is String ? LocalizedNumbers.parse(amount) : null);
          return n == null ? null : MoneyValue(amountMilli: LocalizedNumbers.toMilli(n), currency: cur);
        }
        if (raw is num) return MoneyValue(amountMilli: LocalizedNumbers.toMilli(raw), currency: currencyFallback);
        if (raw is String) {
          final n = LocalizedNumbers.parse(raw);
          return n == null ? null : MoneyValue(amountMilli: LocalizedNumbers.toMilli(n), currency: currencyFallback);
        }
        return null;
      case FieldKind.date:
        final d = raw is DateTime
            ? raw
            : (raw is String ? DateTime.tryParse(LocalizedNumbers.normalizeDigits(raw)) : null);
        return d == null ? null : DateTime(d.year, d.month, d.day);
      case FieldKind.time:
        return ClockTime.normalize(raw);
      case FieldKind.timeList:
        if (raw is! Iterable) return const <String>[];
        return ClockTime.sortUnique(raw.map(ClockTime.normalize).nonNulls);
      case FieldKind.singleSelect:
        if (raw == null) return null;
        final id = raw.toString();
        return options.any((o) => o.id == id) ? id : null;
      case FieldKind.multiSelect:
        if (raw is! Iterable) return const <String>[];
        final seen = <String>{};
        return [
          for (final v in raw)
            if (v != null && (allowAdd || options.any((o) => o.id == v.toString())) && seen.add(v.toString()))
              v.toString(),
        ];
      case FieldKind.toggle:
        return raw == true;
      case FieldKind.rating:
        final n = raw is num ? raw.round() : (raw is String ? LocalizedNumbers.parse(raw)?.round() : null);
        if (n == null || n < 1) return null;
        return n > (max ?? 5) ? (max ?? 5).toInt() : n;
      case FieldKind.slider:
        final lo = (min ?? 0).toInt();
        final hi = (max ?? 10).toInt();
        final n = raw is num ? raw.round() : (raw is String ? LocalizedNumbers.parse(raw)?.round() : null);
        return (n ?? lo).clamp(lo, hi);
      case FieldKind.color:
        if (raw is Color) return raw.toARGB32();
        if (raw is int) return raw;
        return null;
      case FieldKind.icon:
        if (raw is! String) return null;
        final set = icons;
        return set == null || set.containsKey(raw) ? raw : null;
      case FieldKind.prayerWindow:
        if (raw is PrayerWindow) return includeAnytime || raw != PrayerWindow.anytime ? raw : null;
        if (raw is String) {
          final w = PrayerWindow.values.firstWhereOrNull((w) => w.name == raw);
          return w == null || (!includeAnytime && w == PrayerWindow.anytime) ? null : w;
        }
        return null;
    }
  }

  /// Text shown in an input for an initial [value] (text-entry kinds).
  String initialText(Object? value) {
    return switch (kind) {
      FieldKind.text || FieldKind.multiline => (value as String?) ?? '',
      FieldKind.number => value is num ? LocalizedNumbers.formatNum(value) : '',
      FieldKind.currency => value is MoneyValue ? LocalizedNumbers.formatMilli(value.amountMilli) : '',
      _ => '',
    };
  }
}

/// `HH:mm` helpers.
abstract final class ClockTime {
  static final RegExp _re = RegExp(r'^\s*(\d{1,2})\s*[:٫.]\s*(\d{1,2})\s*$');

  /// Normalises `"8:5"`, `"٨:٣٠"`, [TimeOfDay] or [DateTime] to `"HH:mm"`.
  static String? normalize(Object? raw) {
    if (raw is TimeOfDay) return format(raw.hour, raw.minute);
    if (raw is DateTime) return format(raw.hour, raw.minute);
    if (raw is! String) return null;
    final m = _re.firstMatch(LocalizedNumbers.normalizeDigits(raw));
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return format(h, min);
  }

  static String format(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// (hour, minute) of a normalised time.
  static (int, int) parts(String hhmm) {
    final p = hhmm.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  static List<String> sortUnique(Iterable<String> times) => (times.toSet().toList()..sort());
}

/// State of an edit form: normalised values, raw text of text inputs,
/// touched fields and validation. Pure logic – the sheet only renders it.
class EditFormModel extends ChangeNotifier {
  EditFormModel(this.fields, [Map<String, Object?> initial = const {}]) {
    for (final f in fields) {
      final v = f.coerce(initial[f.key]);
      _values[f.key] = v;
      if (f.isTextEntry) _text[f.key] = f.initialText(v);
      if (f.kind == FieldKind.currency) _currency[f.key] = (v as MoneyValue?)?.currency ?? f.currencyFallback;
    }
    _initial = result();
  }

  final List<FieldSpec> fields;
  final Map<String, Object?> _values = {};
  final Map<String, String> _text = {};
  final Map<String, String> _currency = {};
  final Set<String> _touched = {};
  final Map<String, List<SelectOption>> _added = {};
  bool _revealed = false;
  late final Map<String, Object?> _initial;

  static const _eq = DeepCollectionEquality();

  FieldSpec spec(String key) => fields.firstWhere((f) => f.key == key);

  Object? valueOf(String key) => _values[key];
  String textOf(String key) => _text[key] ?? '';
  String currencyOf(String key) => _currency[key] ?? spec(key).currencyFallback;

  /// Options the user added inline to a multi-select field.
  List<SelectOption> addedOptions(String key) => List.unmodifiable(_added[key] ?? const <SelectOption>[]);

  bool get revealed => _revealed;

  /// Updates a text-entry field from what the user typed.
  void setText(String key, String text) {
    final f = spec(key);
    _text[key] = text;
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.multiline:
        _values[key] = f.coerce(text);
      case FieldKind.number:
        _values[key] = text.trim().isEmpty ? null : f.coerce(LocalizedNumbers.parse(text));
      case FieldKind.currency:
        final n = LocalizedNumbers.parse(text);
        _values[key] = n == null
            ? null
            : MoneyValue(amountMilli: LocalizedNumbers.toMilli(n), currency: currencyOf(key));
      default:
        break;
    }
    _touched.add(key);
    notifyListeners();
  }

  void setCurrency(String key, String currency) {
    _currency[key] = currency;
    final v = _values[key];
    if (v is MoneyValue) _values[key] = MoneyValue(amountMilli: v.amountMilli, currency: currency);
    _touched.add(key);
    notifyListeners();
  }

  /// Sets a non-text value (already in the canonical type, or coercible).
  void setValue(String key, Object? value) {
    final f = spec(key);
    _values[key] = f.kind == FieldKind.multiSelect && value is Iterable
        ? [for (final v in value) v.toString()]
        : f.coerce(value);
    _touched.add(key);
    notifyListeners();
  }

  /// Adds a new option to a multi-select field and selects it.
  bool addOption(String key, String label) {
    final f = spec(key);
    final text = label.trim();
    if (f.kind != FieldKind.multiSelect || !f.allowAdd || text.isEmpty) return false;
    final existing = [
      ...f.options,
      ...addedOptions(key),
    ].firstWhereOrNull((o) => o.label.trim() == text || o.id == text);
    final id = existing?.id ?? text;
    if (existing == null) (_added[key] ??= []).add(SelectOption(id: text, label: text));
    final current = List<String>.of((_values[key] as List<String>?) ?? const []);
    if (!current.contains(id)) current.add(id);
    _values[key] = current;
    _touched.add(key);
    notifyListeners();
    return true;
  }

  void touch(String key) {
    if (_touched.add(key)) notifyListeners();
  }

  /// Shows every field's issue (after an attempt to save an invalid form).
  void revealAll() {
    _revealed = true;
    notifyListeners();
  }

  Map<String, Object?> get _snapshot => {for (final f in fields) f.key: _values[f.key]};

  /// The issue of [key], whether or not it is visible yet.
  FieldIssue? issueOf(String key) {
    final f = spec(key);
    final v = _values[key];
    final text = _text[key] ?? '';
    FieldIssue? builtIn() {
      switch (f.kind) {
        case FieldKind.text:
        case FieldKind.multiline:
          if (v == null) return f.required ? const FieldIssue(FieldIssueCode.required) : null;
          if (f.maxLength != null && (v as String).length > f.maxLength!) {
            return FieldIssue(FieldIssueCode.tooLong, limit: f.maxLength);
          }
          return null;
        case FieldKind.number:
        case FieldKind.currency:
          if (text.trim().isEmpty) return f.required ? const FieldIssue(FieldIssueCode.required) : null;
          final n = LocalizedNumbers.parse(text);
          if (n == null) return const FieldIssue(FieldIssueCode.invalidNumber);
          if (LocalizedNumbers.decimalPlaces(text) > f.decimals) {
            return FieldIssue(FieldIssueCode.tooManyDecimals, limit: f.decimals);
          }
          if (f.min != null && n < f.min!) return FieldIssue(FieldIssueCode.belowMin, limit: f.min);
          if (f.max != null && n > f.max!) return FieldIssue(FieldIssueCode.aboveMax, limit: f.max);
          return null;
        case FieldKind.date:
          if (v == null) return f.required ? const FieldIssue(FieldIssueCode.required) : null;
          final d = v as DateTime;
          final first = f.firstDate;
          final last = f.lastDate;
          if (first != null && d.isBefore(DateTime(first.year, first.month, first.day)) ||
              last != null && d.isAfter(DateTime(last.year, last.month, last.day))) {
            return const FieldIssue(FieldIssueCode.dateOutOfRange);
          }
          return null;
        case FieldKind.timeList:
        case FieldKind.multiSelect:
          final list = (v as List?) ?? const [];
          final minCount = f.minCount ?? (f.required ? 1 : 0);
          if (list.isEmpty && f.required && minCount <= 1) return const FieldIssue(FieldIssueCode.required);
          if (list.length < minCount) return FieldIssue(FieldIssueCode.selectAtLeast, limit: minCount);
          if (f.maxCount != null && list.length > f.maxCount!) {
            return FieldIssue(FieldIssueCode.selectAtMost, limit: f.maxCount);
          }
          return null;
        case FieldKind.toggle:
          return f.required && v != true ? const FieldIssue(FieldIssueCode.required) : null;
        case FieldKind.slider:
          return null;
        case FieldKind.time:
        case FieldKind.singleSelect:
        case FieldKind.rating:
        case FieldKind.color:
        case FieldKind.icon:
        case FieldKind.prayerWindow:
          return v == null && f.required ? const FieldIssue(FieldIssueCode.required) : null;
      }
    }

    final issue = builtIn();
    if (issue != null) return issue;
    final message = f.validator?.call(v, _snapshot);
    return message == null ? null : FieldIssue(FieldIssueCode.custom, message: message);
  }

  /// The issue to display now (only once the field was touched or after
  /// [revealAll]).
  FieldIssue? visibleIssueOf(String key) => (_revealed || _touched.contains(key)) ? issueOf(key) : null;

  bool get isValid => fields.every((f) => issueOf(f.key) == null);

  bool get isDirty => !_eq.equals(result(), _initial);

  /// First field with an issue (to scroll / focus to).
  String? get firstInvalidKey => fields.firstWhereOrNull((f) => issueOf(f.key) != null)?.key;

  /// Normalised values keyed by [FieldSpec.key].
  Map<String, Object?> result() {
    return {
      for (final f in fields)
        f.key: switch (f.kind) {
          FieldKind.timeList => List<String>.unmodifiable(
            ClockTime.sortUnique((_values[f.key] as List<String>?) ?? const []),
          ),
          FieldKind.multiSelect => List<String>.unmodifiable((_values[f.key] as List<String>?) ?? const []),
          FieldKind.toggle => _values[f.key] == true,
          _ => _values[f.key],
        },
    };
  }
}
