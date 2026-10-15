/// The shape of a user-built module (Custom Modules Builder): its fields,
/// chart and the typed view of a `custom_modules` row.
///
/// Pure Dart – parsing is tolerant (imported modules, older rows) and keeps
/// every key it does not understand, so a round trip never loses data.
library;

import '../../../core/domain/enums.dart';

// ------------------------------------------------------------------ options --

/// One choice of a single / multi select field. Removed options that entries
/// still use stay [hidden] (their label keeps showing on old entries, but
/// they cannot be picked any more).
class FieldOption {
  const FieldOption({required this.id, required this.label, this.hidden = false});

  final String id;
  final String label;
  final bool hidden;

  FieldOption copyWith({String? label, bool? hidden}) =>
      FieldOption(id: id, label: label ?? this.label, hidden: hidden ?? this.hidden);

  Map<String, Object?> toJson() => {'id': id, 'label': label, if (hidden) 'hidden': true};

  /// A plain string (imported modules) is its own id and label.
  static FieldOption? fromJson(Object? raw) {
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : FieldOption(id: s, label: s);
    }
    if (raw is num) return FieldOption(id: '$raw', label: '$raw');
    if (raw is Map) {
      final id = raw['id'];
      final label = raw['label'] ?? raw['name'] ?? id;
      if (id == null && label == null) return null;
      final idS = '${id ?? label}'.trim();
      if (idS.isEmpty) return null;
      return FieldOption(id: idS, label: '${label ?? idS}', hidden: raw['hidden'] == true);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FieldOption && other.id == id && other.label == label && other.hidden == hidden;

  @override
  int get hashCode => Object.hash(id, label, hidden);

  @override
  String toString() => 'FieldOption($id, $label${hidden ? ', hidden' : ''})';
}

// ------------------------------------------------------------------- fields --

/// One field of a module: `{"id","label","type","unit","required","options",
/// "min","max","decimals","currency","multiline","hidden"}`.
///
/// * number – [unit], [min] / [max] bounds, [decimals] (0–3).
/// * rating – [max] is the scale (2–10, default 5).
/// * currency – [currency] code; values are integer milli-units.
/// * single / multi select – [options].
/// * text – [multiline].
/// * [hidden] – removed from the module while entries still hold values for
///   it: never shown in forms, still exported, restorable.
class ModuleField {
  const ModuleField({
    required this.id,
    required this.label,
    required this.type,
    this.unit,
    this.required = false,
    this.options = const [],
    this.min,
    this.max,
    this.decimals = 0,
    this.currency,
    this.multiline = false,
    this.hidden = false,
    this.extra = const {},
  });

  final String id;
  final String label;
  final FieldType type;
  final String? unit;
  final bool required;
  final List<FieldOption> options;
  final num? min;
  final num? max;
  final int decimals;
  final String? currency;
  final bool multiline;
  final bool hidden;

  /// Keys this version does not know (e.g. the importer's `sourceKey`),
  /// written back untouched.
  final Map<String, Object?> extra;

  static const int defaultRatingMax = 5;
  static const int minRatingMax = 2;
  static const int maxRatingMax = 10;
  static const int maxDecimals = 3;
  static const String defaultCurrency = 'JOD';

  static const Set<String> _known = {
    'id',
    'label',
    'type',
    'unit',
    'required',
    'options',
    'min',
    'max',
    'decimals',
    'currency',
    'multiline',
    'hidden',
  };

  /// The rating scale (stars).
  int get ratingMax {
    final m = max;
    if (m == null) return defaultRatingMax;
    return m.round().clamp(minRatingMax, maxRatingMax);
  }

  String get currencyCode => (currency == null || currency!.trim().isEmpty) ? defaultCurrency : currency!.toUpperCase();

  /// Options the user can pick.
  List<FieldOption> get visibleOptions => [
    for (final o in options)
      if (!o.hidden) o,
  ];

  FieldOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  bool get isSelect => type == FieldType.singleSelect || type == FieldType.multiSelect;

  /// Can be plotted (numbers, ratings, check-ins, amounts).
  bool get isChartable =>
      type == FieldType.number || type == FieldType.rating || type == FieldType.checkbox || type == FieldType.currency;

  /// Whether "required" means anything for this type (a checkbox is always
  /// answered: unticked is an answer).
  bool get canBeRequired => type != FieldType.checkbox;

  bool get isRequired => required && canBeRequired;

  ModuleField copyWith({
    String? label,
    FieldType? type,
    String? unit,
    bool clearUnit = false,
    bool? required,
    List<FieldOption>? options,
    num? min,
    bool clearMin = false,
    num? max,
    bool clearMax = false,
    int? decimals,
    String? currency,
    bool? multiline,
    bool? hidden,
  }) => ModuleField(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    unit: clearUnit ? null : (unit ?? this.unit),
    required: required ?? this.required,
    options: options ?? this.options,
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
    decimals: decimals ?? this.decimals,
    currency: currency ?? this.currency,
    multiline: multiline ?? this.multiline,
    hidden: hidden ?? this.hidden,
    extra: extra,
  );

  /// The same field under a new [id] (duplicating a field).
  ModuleField withId(String id) => ModuleField(
    id: id,
    label: label,
    type: type,
    unit: unit,
    required: required,
    options: options,
    min: min,
    max: max,
    decimals: decimals,
    currency: currency,
    multiline: multiline,
    hidden: hidden,
    extra: const {},
  );

  Map<String, Object?> toJson() {
    final unitS = unit?.trim();
    return {
      ...extra,
      'id': id,
      'label': label,
      'type': type.name,
      if (unitS != null && unitS.isNotEmpty) 'unit': unitS,
      'required': required,
      'options': [for (final o in options) o.toJson()],
      'min': ?min,
      'max': ?max,
      if (type == FieldType.number && decimals > 0) 'decimals': decimals,
      if (type == FieldType.currency) 'currency': currencyCode,
      if (multiline) 'multiline': true,
      if (hidden) 'hidden': true,
    };
  }

  /// Tolerant parse; null for anything without an id.
  static ModuleField? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id == null || '$id'.trim().isEmpty) return null;
    final typeName = raw['type'];
    final type = FieldType.values.where((t) => t.name == typeName).firstOrNull ?? FieldType.text;
    final optionsRaw = raw['options'];
    final options = <FieldOption>[];
    if (optionsRaw is List) {
      final seen = <String>{};
      for (final o in optionsRaw) {
        final opt = FieldOption.fromJson(o);
        if (opt != null && seen.add(opt.id)) options.add(opt);
      }
    }
    num? n(Object? v) => v is num ? v : (v is String ? num.tryParse(v) : null);
    final decimals = n(raw['decimals'])?.round() ?? 0;
    final unit = raw['unit'];
    final currency = raw['currency'];
    return ModuleField(
      id: '$id',
      label: '${raw['label'] ?? raw['name'] ?? id}',
      type: type,
      unit: unit is String && unit.trim().isNotEmpty ? unit.trim() : null,
      required: raw['required'] == true,
      options: options,
      min: n(raw['min']),
      max: n(raw['max']),
      decimals: decimals.clamp(0, maxDecimals),
      currency: currency is String && currency.trim().isNotEmpty ? currency.trim().toUpperCase() : null,
      multiline: raw['multiline'] == true,
      hidden: raw['hidden'] == true,
      extra: {
        for (final e in raw.entries)
          if (!_known.contains('${e.key}')) '${e.key}': e.value,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModuleField &&
      other.id == id &&
      other.label == label &&
      other.type == type &&
      other.unit == unit &&
      other.required == required &&
      _listEq(other.options, options) &&
      other.min == min &&
      other.max == max &&
      other.decimals == decimals &&
      other.currency == currency &&
      other.multiline == multiline &&
      other.hidden == hidden;

  @override
  int get hashCode =>
      Object.hash(id, label, type, unit, required, Object.hashAll(options), min, max, decimals, currency, multiline, hidden);

  @override
  String toString() => 'ModuleField($id, $label, ${type.name}${hidden ? ', hidden' : ''})';
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// -------------------------------------------------------------------- chart --

enum ModuleChartType { line, bar, heat, streak }

/// `{"type":"line","fieldId":"f1","range":30}`; a null [fieldId] plots the
/// number of entries per day.
class ModuleChartConfig {
  const ModuleChartConfig({this.type = ModuleChartType.bar, this.fieldId, this.range = 30});

  final ModuleChartType type;
  final String? fieldId;
  final int range;

  static const List<int> ranges = [7, 30, 90];

  ModuleChartConfig copyWith({ModuleChartType? type, String? fieldId, bool clearField = false, int? range}) =>
      ModuleChartConfig(
        type: type ?? this.type,
        fieldId: clearField ? null : (fieldId ?? this.fieldId),
        range: range ?? this.range,
      );

  Map<String, Object?> toJson() => {'type': type.name, 'fieldId': fieldId, 'range': range};

  static ModuleChartConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final type = ModuleChartType.values.where((t) => t.name == raw['type']).firstOrNull;
    if (type == null) return null;
    final r = raw['range'];
    final range = r is num ? r.round() : 30;
    final f = raw['fieldId'];
    return ModuleChartConfig(
      type: type,
      fieldId: f is String && f.isNotEmpty ? f : null,
      range: ranges.contains(range) ? range : (range <= 7 ? 7 : (range <= 30 ? 30 : 90)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModuleChartConfig && other.type == type && other.fieldId == fieldId && other.range == range;

  @override
  int get hashCode => Object.hash(type, fieldId, range);
}

// ------------------------------------------------------------------- module --

/// The typed view of a `custom_modules` row.
class ModuleDefinition {
  const ModuleDefinition({
    required this.id,
    required this.name,
    this.kind = CustomModuleKind.tracker,
    this.iconKey = 'star',
    required this.colorArgb,
    this.planetKey,
    this.window,
    this.fields = const [],
    this.chart,
    this.archived = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final CustomModuleKind kind;
  final String iconKey;
  final int colorArgb;
  final String? planetKey;
  final PrayerWindow? window;

  /// Every field, hidden ones included (in their order).
  final List<ModuleField> fields;
  final ModuleChartConfig? chart;
  final bool archived;
  final int sortOrder;
  final DateTime? createdAt;

  bool get isTracker => kind == CustomModuleKind.tracker;
  bool get isList => kind == CustomModuleKind.list;

  /// Fields shown in forms and lists.
  List<ModuleField> get visibleFields => [
    for (final f in fields)
      if (!f.hidden) f,
  ];

  List<ModuleField> get hiddenFields => [
    for (final f in fields)
      if (f.hidden) f,
  ];

  List<ModuleField> get chartableFields => [
    for (final f in visibleFields)
      if (f.isChartable) f,
  ];

  ModuleField? field(String? id) {
    if (id == null) return null;
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The first visible text field: an entry's title in lists and search.
  ModuleField? get titleField {
    for (final f in visibleFields) {
      if (f.type == FieldType.text) return f;
    }
    return null;
  }

  /// The chart to draw: the stored one when it still points at a visible
  /// chartable field (or at "entries"), else a sensible default.
  ModuleChartConfig get effectiveChart {
    final c = chart;
    if (c != null && (c.fieldId == null || chartableFields.any((f) => f.id == c.fieldId))) return c;
    final first = chartableFields.firstOrNull;
    if (first == null) return ModuleChartConfig(type: ModuleChartType.bar, range: c?.range ?? 30);
    return ModuleChartConfig(
      type: first.type == FieldType.checkbox ? ModuleChartType.streak : ModuleChartType.bar,
      fieldId: first.id,
      range: c?.range ?? 30,
    );
  }

  /// How a tracker can be logged with one tap (null: open the entry form).
  QuickEntry? get quickEntry => QuickEntry.of(this);

  ModuleDefinition copyWith({
    String? name,
    CustomModuleKind? kind,
    String? iconKey,
    int? colorArgb,
    String? planetKey,
    bool clearPlanet = false,
    PrayerWindow? window,
    bool clearWindow = false,
    List<ModuleField>? fields,
    ModuleChartConfig? chart,
    bool clearChart = false,
    bool? archived,
  }) => ModuleDefinition(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    iconKey: iconKey ?? this.iconKey,
    colorArgb: colorArgb ?? this.colorArgb,
    planetKey: clearPlanet ? null : (planetKey ?? this.planetKey),
    window: clearWindow ? null : (window ?? this.window),
    fields: fields ?? this.fields,
    chart: clearChart ? null : (chart ?? this.chart),
    archived: archived ?? this.archived,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );

  static List<ModuleField> parseFields(Object? raw) {
    if (raw is! List) return const [];
    final out = <ModuleField>[];
    final seen = <String>{};
    for (final f in raw) {
      final field = ModuleField.fromJson(f);
      if (field != null && seen.add(field.id)) out.add(field);
    }
    return out;
  }

  static List<Map<String, Object?>> encodeFields(List<ModuleField> fields) => [for (final f in fields) f.toJson()];
}

/// One-tap logging of a tracker.
sealed class QuickEntry {
  const QuickEntry();

  /// * A tracker with a checkbox and no other required field: tap = "done
  ///   today" (the checkbox ticked).
  /// * With a rating and no other required field: tap a star.
  /// * With no visible field at all: a plain counter (tap = one entry).
  /// * Anything else (and lists) opens the entry form.
  static QuickEntry? of(ModuleDefinition m) {
    if (!m.isTracker) return null;
    final visible = m.visibleFields;
    if (visible.isEmpty) return const QuickCount();
    for (final f in visible) {
      if (f.type != FieldType.checkbox) continue;
      if (visible.every((o) => o.id == f.id || !o.isRequired)) return QuickCheck(f.id);
    }
    for (final f in visible) {
      if (f.type != FieldType.rating) continue;
      if (visible.every((o) => o.id == f.id || !o.isRequired)) return QuickRate(f.id, f.ratingMax);
    }
    return null;
  }
}

final class QuickCheck extends QuickEntry {
  const QuickCheck(this.fieldId);
  final String fieldId;

  @override
  bool operator ==(Object other) => other is QuickCheck && other.fieldId == fieldId;

  @override
  int get hashCode => fieldId.hashCode;
}

final class QuickRate extends QuickEntry {
  const QuickRate(this.fieldId, this.max);
  final String fieldId;
  final int max;

  @override
  bool operator ==(Object other) => other is QuickRate && other.fieldId == fieldId && other.max == max;

  @override
  int get hashCode => Object.hash(fieldId, max);
}

final class QuickCount extends QuickEntry {
  const QuickCount();

  @override
  bool operator ==(Object other) => other is QuickCount;

  @override
  int get hashCode => 0;
}

// -------------------------------------------------------------------- entry --

/// The typed view of a `custom_entries` row.
class ModuleEntry {
  const ModuleEntry({
    required this.id,
    required this.moduleId,
    required this.at,
    this.values = const {},
    this.done = false,
    this.sortOrder = 0,
  });

  final String id;
  final String moduleId;
  final DateTime at;

  /// Field id → stored value (see `FieldValues`).
  final Map<String, Object?> values;
  final bool done;
  final int sortOrder;

  ModuleEntry copyWith({DateTime? at, Map<String, Object?>? values, bool? done}) => ModuleEntry(
    id: id,
    moduleId: moduleId,
    at: at ?? this.at,
    values: values ?? this.values,
    done: done ?? this.done,
    sortOrder: sortOrder,
  );
}

// ------------------------------------------------------------------ ids -----

abstract final class ModuleIds {
  static final RegExp _fieldId = RegExp(r'^f(\d+)$');
  static final RegExp _optionId = RegExp(r'^o(\d+)$');

  /// The next free field id (`f1`, `f2` …) – never reuses the id of a
  /// hidden field, so old values can never attach to a new field.
  static String nextFieldId(Iterable<String> taken) => _next(taken, _fieldId, 'f');

  /// The next free option id of a select field.
  static String nextOptionId(Iterable<String> taken) => _next(taken, _optionId, 'o');

  static String _next(Iterable<String> taken, RegExp pattern, String prefix) {
    var max = 0;
    final set = taken.toSet();
    for (final id in set) {
      final m = pattern.firstMatch(id);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n > max) max = n;
      }
    }
    var n = max + 1;
    while (set.contains('$prefix$n')) {
      n++;
    }
    return '$prefix$n';
  }
}
