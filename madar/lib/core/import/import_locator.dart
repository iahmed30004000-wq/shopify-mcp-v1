/// Walks a prototype export and collects raw records per section, wherever
/// they live: `data.*`, `logs.*`, nested domains (`data.health.meds`),
/// id-keyed maps, day-keyed logs, typed event lists, budget trees written
/// as nested maps and kanban boards keyed by country. Anything no section
/// claims is kept: lists of objects become [UnknownList]s (→ custom modules),
/// everything else is recorded as a leftover.
library;

import '../domain/enums.dart';
import 'import_aliases.dart';
import 'import_models.dart';
import 'import_text.dart';
import 'import_values.dart';

/// One record found in the file, before mapping.
class RawRecord {
  RawRecord({
    required this.section,
    required this.fields,
    required this.path,
    this.sourceId,
    this.parent,
    this.day,
    this.hint,
    this.column,
    this.window,
    this.domain,
    this.inLogs = false,
  });

  final ImportSection section;
  final Map<String, Object?> fields;
  final String path;

  /// The record's own id in the source (field `id`/`_id`/… or its map key).
  final String? sourceId;

  /// The record this one was nested in (lab test of a reading …).
  final RawRecord? parent;

  /// Day of a day-keyed log this record came from.
  final DateTime? day;

  /// Section alias hint (`stress`, `income`, `supplement`, `windows` …).
  final String? hint;

  /// Kanban column the card was listed under.
  final String? column;

  /// Prayer window the task was listed under.
  final PrayerWindow? window;

  /// Planet key of the domain the record was nested in.
  final String? domain;
  final bool inLogs;

  /// Keys holding nested children (not fields of this record).
  final Set<String> consumed = {};

  /// Kanban columns met while reading a board (`id` → label).
  final Map<String, String> columns = {};

  /// Assigned by the mapper.
  String? id;

  DateTime? get effectiveDay => day ?? parent?.effectiveDay;

  @override
  String toString() => 'RawRecord(${section.name} $path $fields)';
}

/// A list of objects under a key no section claims (→ custom module).
class UnknownList {
  UnknownList({required this.key, required this.path, this.domain});

  final String key;
  final String path;
  final String? domain;
  final List<Map<String, Object?>> items = [];
  final List<String?> sourceIds = [];
  final List<DateTime?> days = [];
}

class _Ctx {
  const _Ctx({this.logs = false, this.day, this.parent, this.column, this.window, this.domain});

  final bool logs;
  final DateTime? day;
  final RawRecord? parent;
  final String? column;
  final PrayerWindow? window;
  final String? domain;

  _Ctx copy({bool? logs, DateTime? day, RawRecord? parent, String? column, PrayerWindow? window, String? domain}) =>
      _Ctx(
        logs: logs ?? this.logs,
        day: day ?? this.day,
        parent: parent ?? this.parent,
        column: column ?? this.column,
        window: window ?? this.window,
        domain: domain ?? this.domain,
      );

  /// Context for records nested inside [p] (keeps the day, drops column).
  _Ctx child(RawRecord p) => _Ctx(logs: false, day: day, parent: p, domain: domain);
}

/// Result of [ImportLocator.locate].
class LocatedData {
  final Map<ImportSection, List<RawRecord>> records = {};
  final List<UnknownList> unknown = [];

  /// Values nothing maps to (path → value); kept in the archive.
  final Map<String, Object?> leftovers = {};
  final Map<String, Object?> settings = {};
  final Map<String, Object?> meta = {};
  final Set<String> domains = {};
  bool dayKeyed = false;
  bool typedEvents = false;
  bool idKeyed = false;
  ImportContainer container = ImportContainer.flat;
  int _arabicKeys = 0, _snakeKeys = 0, _camelKeys = 0, _plainKeys = 0;

  Iterable<RawRecord> get allRecords => records.values.expand((l) => l);

  void _add(RawRecord r) => (records[r.section] ??= []).add(r);

  void _countKey(String k) {
    if (ImportText.isArabic(k)) {
      _arabicKeys++;
    } else if (ImportText.isSnake(k)) {
      _snakeKeys++;
    } else if (ImportText.isCamel(k)) {
      _camelKeys++;
    } else {
      _plainKeys++;
    }
  }

  ImportKeyStyle get keyStyle {
    final total = _arabicKeys + _snakeKeys + _camelKeys;
    if (total == 0) return ImportKeyStyle.plain;
    final top = [_arabicKeys, _snakeKeys, _camelKeys].reduce((a, b) => a > b ? a : b);
    if (top < total * 0.6) return ImportKeyStyle.mixed;
    if (top == _arabicKeys) return ImportKeyStyle.arabic;
    if (top == _snakeKeys) return ImportKeyStyle.snakeCase;
    return _plainKeys > _camelKeys * 4 ? ImportKeyStyle.plain : ImportKeyStyle.camelCase;
  }
}

class ImportLocator {
  ImportLocator._();

  /// Walks [root] (decoded JSON).
  static LocatedData locate(Object? root) {
    final l = ImportLocator._();
    final out = l._out;
    if (root is List) {
      out.container = ImportContainer.list;
      l._list('records', root, 'records', const _Ctx());
    } else if (root is Map) {
      var hasData = false, hasLogs = false, other = false;
      for (final e in root.entries) {
        final k = ImportText.key('${e.key}');
        if (ImportAliases.dataContainers.contains(k) && e.value is Map) {
          hasData = true;
        } else if (ImportAliases.logContainers.contains(k) && (e.value is Map || e.value is List)) {
          hasLogs = true;
        } else if (!ImportAliases.metaKeys.contains(k)) {
          other = true;
        }
      }
      out.container = hasData && hasLogs
          ? ImportContainer.wrapped
          : hasData
          ? ImportContainer.dataOnly
          : hasLogs && !other
          ? ImportContainer.logsOnly
          : ImportContainer.flat;
      l._walk(root, '', const _Ctx());
    }
    return out;
  }

  final LocatedData _out = LocatedData();

  /// Field injected into records listed under a group key
  /// (`{"morning": [meds…]}` → `_group: "morning"`).
  static const groupKey = '_group';

  /// Sections where `{"<name>": [...]}` means a parent named `<name>` with
  /// its children (unless the list holds this section's own records).
  static const _groupedAsParent = {
    ImportSection.boards,
    ImportSection.budgetItems,
    ImportSection.projects,
    ImportSection.trips,
    ImportSection.labTests,
    ImportSection.habits,
    ImportSection.learningGoals,
    ImportSection.exercises,
    ImportSection.jars,
    ImportSection.debts,
  };

  /// Whether [list] holds named, undated records (a group of this
  /// section's own items rather than children of a parent).
  static bool _looksLikeOwnRecords(List list) {
    final maps = list.whereType<Map>().toList();
    if (maps.isEmpty || maps.length != list.length) return false;
    return maps.every((m) {
      final f = _fields(m);
      return _hasAny(f, ImportAliases.name) && !_hasAny(f, const ['date', 'at', 'day', 'تاريخ']);
    });
  }

  static String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

  // ------------------------------------------------------------ helpers --

  static bool _isScalar(Object? v) => v == null || v is String || v is num || v is bool;

  static bool _isDayKeyed(Map m) {
    if (m.isEmpty) return false;
    var dates = 0;
    for (final k in m.keys) {
      if (ImportValues.isDateKey('$k')) dates++;
    }
    return dates >= m.length * 0.8 && dates > 0;
  }

  /// `{"<id or name>": {...}, …}` – every value an object.
  static bool _isKeyedObjects(Map m) {
    if (m.isEmpty) return false;
    for (final e in m.entries) {
      if (e.value is! Map) return false;
      if (ImportAliases.genericContainers.contains(ImportText.key('${e.key}'))) return false;
    }
    return true;
  }

  /// Whether some key of [m] names a section, a domain or a log container.
  static bool _isContainer(Map m) {
    for (final k in m.keys) {
      final s = '$k';
      final n = ImportText.key(s);
      if (ImportAliases.logContainers.contains(n) || ImportAliases.dataContainers.contains(n)) return true;
      final v = m[k];
      if (v is! List && v is! Map) continue;
      if (ImportAliases.sectionFor(s) != null || ImportAliases.domainFor(s) != null) return true;
    }
    return false;
  }

  static String? _idOf(Map m) {
    for (final a in ImportAliases.id) {
      for (final e in m.entries) {
        if (ImportText.key('${e.key}') == ImportText.key(a)) {
          final v = e.value;
          if (v is String && v.trim().isNotEmpty) return v.trim();
          if (v is num) return v is int || v == v.roundToDouble() ? '${v.toInt()}' : '$v';
        }
      }
    }
    return null;
  }

  static Map<String, Object?> _fields(Map m) => {for (final e in m.entries) '${e.key}': e.value};

  bool _setting(String key, Object? v) {
    final n = ImportText.key(key);
    if (ImportAliases.weeksPerMonth.any((a) => ImportText.key(a) == n)) {
      final w = ImportValues.number(v);
      if (w != null && w > 0) {
        _out.settings['weeksPerMonth'] = w;
        return true;
      }
    }
    if (v is String && ImportAliases.baseCurrency.any((a) => ImportText.key(a) == n)) {
      final code = v.trim().toUpperCase();
      if (RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
        _out.settings['baseCurrency'] = code;
        return true;
      }
    }
    return false;
  }

  void _leftover(String path, Object? v) {
    _out.leftovers[path] = v;
  }

  // -------------------------------------------------------------- walk --

  void _walk(Map map, String path, _Ctx ctx) {
    if (_isDayKeyed(map)) {
      _out.dayKeyed = true;
      for (final e in map.entries) {
        final day = ImportValues.date('${e.key}');
        final p = _join(path, '${e.key}');
        final v = e.value;
        if (v is Map) {
          _walkDay(v, p, ctx.copy(day: day, logs: true));
        } else {
          _leftover(p, v);
        }
      }
      return;
    }
    for (final e in map.entries) {
      final k = '${e.key}';
      final v = e.value;
      final p = _join(path, k);
      final n = ImportText.key(k);
      _out._countKey(k);
      if (ImportAliases.metaKeys.contains(n) && _isScalar(v)) {
        _out.meta[k] = v;
        continue;
      }
      if (ImportAliases.dataContainers.contains(n) && v is Map) {
        _walk(v, p, ctx);
        continue;
      }
      if (ImportAliases.logContainers.contains(n) && (v is Map || v is List)) {
        if (v is Map) {
          _walk(v, p, ctx.copy(logs: true));
        } else {
          _list(k, v as List, p, ctx.copy(logs: true));
        }
        continue;
      }
      if (_isScalar(v)) {
        if (!_setting(k, v)) _leftover(p, v);
        continue;
      }
      final match = ImportAliases.sectionFor(k);
      final domain = ImportAliases.domainFor(k);
      if (v is Map && _isContainer(v) && (match == null || domain != null || !_looksLikeSection(match.section, v))) {
        if (domain != null) _out.domains.add(domain);
        _walk(v, p, ctx.copy(domain: domain));
        continue;
      }
      if (match != null) {
        _section(match, v, p, ctx);
        continue;
      }
      if (v is Map) {
        _walk(v, p, ctx.copy(domain: domain));
      } else {
        _list(k, v as List, p, ctx);
      }
    }
  }

  /// A map under a section key that is really that section's data (records,
  /// keyed records, a budget tree) rather than a domain container.
  static bool _looksLikeSection(ImportSection s, Map v) {
    if (s == ImportSection.budgetItems) return _looksLikeBudget(v);
    for (final k in v.keys) {
      final m = ImportAliases.sectionFor('$k');
      if (m != null && m.section != s && ImportAliases.childFor(s, '$k') == null) return false;
    }
    return true;
  }

  /// Budget category names often collide with section aliases (`Savings`,
  /// `Bills`, `ادخار`, `فواتير`, `علاج`, `سفر` …), so a budget map is only a
  /// money container (`{"budget": {"wallets": [...], "transactions": [...]}}`)
  /// when it has no plain category key and every non-scalar key names
  /// another section.
  static bool _looksLikeBudget(Map v) {
    var foreignOnly = true;
    for (final e in v.entries) {
      final k = '${e.key}';
      final n = ImportText.key(k);
      final m = ImportAliases.sectionFor(k);
      final foreign = m != null && m.section != ImportSection.budgetItems && ImportAliases.childFor(ImportSection.budgetItems, k) == null;
      if (_isBudgetCategoryKey(k, n, m) || (foreign && _isBudgetLine(e.value))) return true;
      if (!_isScalar(e.value) && !foreign) foreignOnly = false;
    }
    return !foreignOnly;
  }

  /// A key that can only be a budget category: no section, domain, meta,
  /// setting, container or reserved budget field.
  static bool _isBudgetCategoryKey(String k, String n, SectionMatch? m) =>
      n.isNotEmpty &&
      m == null &&
      ImportAliases.domainFor(k) == null &&
      !ImportAliases.metaKeys.contains(n) &&
      !ImportAliases.dataContainers.contains(n) &&
      !ImportAliases.logContainers.contains(n) &&
      !ImportAliases.genericContainers.contains(n) &&
      !_budgetReserved.contains(n) &&
      !ImportAliases.weeksPerMonth.any((a) => ImportText.key(a) == n) &&
      !ImportAliases.baseCurrency.any((a) => ImportText.key(a) == n) &&
      n != 'rates';

  /// `{"amount": 50}` / `{"نسبة": 10}` – a single budget line (only scalar
  /// fields, one of them an amount or percent), not a list of records.
  static bool _isBudgetLine(Object? v) {
    if (v is! Map || v.isEmpty || !v.values.every(_isScalar)) return false;
    final f = _fields(v);
    return _hasAny(f, ImportAliases.amount) || _hasAny(f, ImportAliases.percent);
  }

  /// A list under a key that is not a section: typed events or unknown.
  void _list(String key, List v, String path, _Ctx ctx) {
    if (v.isEmpty) return _leftover(path, v);
    if (_typedEvents(v, path, ctx)) return;
    final maps = v.whereType<Map>().toList();
    if (maps.length == v.length) {
      final u = UnknownList(key: key, path: path, domain: ctx.domain);
      for (final m in maps) {
        u.items.add(_fields(m));
        u.sourceIds.add(_idOf(m));
        u.days.add(ctx.day);
      }
      _out.unknown.add(u);
      return;
    }
    _leftover(path, v);
  }

  static const _typeKeys = ['type', 'kind', 'section', 'event', 'module', 'entity', 'table', 'نوع', 'النوع'];

  bool _typedEvents(List v, String path, _Ctx ctx) {
    final matches = <SectionMatch?>[];
    final typeKeys = <String?>[];
    var hits = 0;
    for (final item in v) {
      SectionMatch? m;
      String? tk;
      if (item is Map) {
        for (final e in item.entries) {
          if (_typeKeys.contains(ImportText.key('${e.key}')) && e.value is String) {
            m = ImportAliases.sectionFor(e.value as String);
            if (m != null) {
              tk = '${e.key}';
              break;
            }
          }
        }
      }
      if (m != null) hits++;
      matches.add(m);
      typeKeys.add(tk);
    }
    if (hits == 0 || hits < v.length * 0.6) return false;
    _out.typedEvents = true;
    for (var i = 0; i < v.length; i++) {
      final m = matches[i];
      final item = v[i];
      final p = '$path[$i]';
      if (m == null || item is! Map) {
        _leftover(p, item);
        continue;
      }
      final fields = _fields(item)..remove(typeKeys[i]);
      final section = ctx.logs || ctx.day != null ? m.section.logVariant : m.section;
      _item(section, fields, p, ctx, hint: m.hint);
    }
    return true;
  }

  /// One day of a day-keyed log: `{"pain": 3, "mood": 4, "prayers": {...}}`.
  void _walkDay(Map dayMap, String path, _Ctx ctx) {
    final mood = <String, Object?>{};
    for (final e in dayMap.entries) {
      final k = '${e.key}';
      final v = e.value;
      final p = _join(path, k);
      _out._countKey(k);
      final prayer = ImportValues.enumOf(k, ImportAliases.prayer);
      if (prayer != null && ImportText.words(k).split(' ').length <= 2 && _isScalar(v)) {
        _item(ImportSection.prayerLogs, {'prayer': k, 'status': v}, p, ctx);
        continue;
      }
      final match = ImportAliases.sectionFor(k);
      if (match == null) {
        if (v is List) {
          _list(k, v, p, ctx);
        } else if (v is Map) {
          _walkDay(v, p, ctx);
        } else {
          // Day notes etc. join the day's mood entry when there is one.
          final nk = ImportText.key(k);
          if (ImportAliases.notes.any((a) => ImportText.key(a) == nk)) {
            mood[k] = v;
          } else {
            _leftover(p, v);
          }
        }
        continue;
      }
      if (match.section == ImportSection.moodEntries && _isScalar(v)) {
        mood[match.hint ?? k] = v;
        continue;
      }
      _section(match, v, p, ctx);
    }
    final hasMood = mood.keys.any((k) => !ImportAliases.notes.any((a) => ImportText.key(a) == ImportText.key(k)));
    if (hasMood) {
      _item(ImportSection.moodEntries, mood, path, ctx);
    } else {
      mood.forEach((k, v) => _leftover(_join(path, k), v));
    }
  }

  // ----------------------------------------------------------- sections --

  void _section(SectionMatch match, Object? v, String path, _Ctx ctx) {
    final base = match.section;
    final section = ctx.logs || ctx.day != null ? base.logVariant : base;
    final hint = match.hint;
    if (v is List) {
      for (var i = 0; i < v.length; i++) {
        _item(section, v[i], '$path[$i]', ctx, hint: hint);
      }
      return;
    }
    if (v is! Map) {
      if (ctx.day != null) {
        _item(section, {'value': v}, path, ctx, hint: hint);
      } else if (!_setting(path.split('.').last, v)) {
        _leftover(path, v);
      }
      return;
    }
    if (v.isEmpty) return;

    if (base == ImportSection.currencies) return _rates(v, path);

    if (_isDayKeyed(v)) {
      _out.dayKeyed = true;
      final logSection = base.logVariant;
      for (final e in v.entries) {
        final day = ImportValues.date('${e.key}');
        _dayValue(logSection, e.value, _join(path, '${e.key}'), ctx.copy(day: day), hint);
      }
      return;
    }

    // {"items": [...], "weeksPerMonth": 4}
    final containers = {
      for (final e in v.entries)
        if (ImportAliases.genericContainers.contains(ImportText.key('${e.key}')) && e.value is List) e.key,
    };
    if (containers.isNotEmpty) {
      for (final e in v.entries) {
        final p = _join(path, '${e.key}');
        if (containers.contains(e.key)) {
          _section(match, e.value, p, ctx);
        } else if (e.value is Map && ImportAliases.sectionFor('${e.key}') == match) {
          _section(match, e.value, p, ctx);
        } else if (base == ImportSection.currencies || ImportText.key('${e.key}') == 'rates') {
          if (e.value is Map) _rates(e.value as Map, p);
        } else if (!_setting('${e.key}', e.value)) {
          _leftover(p, e.value);
        }
      }
      return;
    }

    // Boards keyed by country / business: {"Jordan": [cards…], "Egypt": {"todo": [...]}}.
    // Runs before the all-lists branch: a list under a board key is always
    // that board's cards, never a group of boards.
    if (section == ImportSection.boards && v.values.every((x) => x is List || x is Map)) {
      for (final e in v.entries) {
        final key = '${e.key}';
        final p = _join(path, key);
        final val = e.value;
        if (val is List) {
          final rec = _item(section, <String, Object?>{'name': key, 'country': key}, p, ctx, sourceId: key);
          if (rec != null) _section((section: ImportSection.boardCards, hint: null), val, p, ctx.child(rec));
        } else {
          final fields = _fields(val as Map);
          if (!_hasAny(fields, ImportAliases.name)) {
            fields['name'] = key;
            fields['country'] = key;
          }
          _item(section, fields, p, ctx, sourceId: _idOf(fields) ?? key);
        }
      }
      return;
    }

    // Window lists / named groups / parents with children: {"morning": [...]}.
    if (v.values.every((x) => x is List)) {
      if (section == ImportSection.tasks) {
        for (final e in v.entries) {
          final w = ImportValues.enumOf('${e.key}', ImportAliases.prayerWindow);
          final list = e.value as List;
          for (var i = 0; i < list.length; i++) {
            _item(section, list[i], '${_join(path, '${e.key}')}[$i]', w == null ? ctx : ctx.copy(window: w), hint: hint);
          }
        }
        return;
      }
      final child = _groupedAsParent.contains(section) ? ImportAliases.childAliases[section]?.$1 : null;
      for (final e in v.entries) {
        final p = _join(path, '${e.key}');
        final list = e.value as List;
        if (child != null && !_looksLikeOwnRecords(list)) {
          // {"HbA1c": [readings…]}, {"Home": [lines…]} – key = parent name.
          final rec = _item(section, <String, Object?>{'name': '${e.key}'}, p, ctx, hint: hint, sourceId: '${e.key}');
          if (rec == null) continue;
          _section((section: child, hint: null), list, p, ctx.child(rec));
        } else {
          // {"morning": [meds…]}, {"family": [people…]} – key = a group.
          for (var i = 0; i < list.length; i++) {
            final item = list[i];
            final primary = _primaryField(section);
            final grouped = item is Map
                ? {..._fields(item), groupKey: '${e.key}'}
                : primary != null && item != null && _isScalar(item)
                ? <String, Object?>{primary: item, groupKey: '${e.key}'}
                : item;
            _item(section, grouped, '$p[$i]', ctx, hint: hint, sourceId: item is Map ? _idOf(item) : null);
          }
        }
      }
      return;
    }

    if (_isKeyedObjects(v)) {
      _out.idKeyed = true;
      for (final e in v.entries) {
        final fields = _fields(e.value as Map);
        final name = _primaryField(section);
        if (!_hasAny(fields, ImportAliases.name) && name != null && !_hasKey(fields, name)) {
          fields[name] = '${e.key}';
        }
        _item(section, fields, _join(path, '${e.key}'), ctx, hint: hint, sourceId: _idOf(fields) ?? '${e.key}');
      }
      return;
    }

    if (section == ImportSection.budgetItems) return _budgetMap(v, path, ctx);

    if (_keyedScalars(section, v)) {
      for (final e in v.entries) {
        _item(section, _refFields(section, '${e.key}', e.value), _join(path, '${e.key}'), ctx, hint: hint);
      }
      return;
    }
    _item(section, v, path, ctx, hint: hint);
  }

  void _dayValue(ImportSection section, Object? val, String path, _Ctx ctx, String? hint) {
    if (val is List) {
      for (var i = 0; i < val.length; i++) {
        _item(section, val[i], '$path[$i]', ctx, hint: hint);
      }
    } else if (val is Map) {
      if (_keyedScalars(section, val)) {
        for (final e in val.entries) {
          _item(section, _refFields(section, '${e.key}', e.value), _join(path, '${e.key}'), ctx, hint: hint);
        }
      } else if (_isKeyedObjects(val) && section != ImportSection.moodEntries && section != ImportSection.painEntries) {
        for (final e in val.entries) {
          _item(
            section,
            _refFields(section, '${e.key}', e.value),
            _join(path, '${e.key}'),
            ctx,
            hint: hint,
            sourceId: _idOf(e.value as Map),
          );
        }
      } else {
        _item(section, val, path, ctx, hint: hint);
      }
    } else if (val != null) {
      _item(section, {'value': val}, path, ctx, hint: hint);
    }
  }

  /// Sections whose map keys name the thing logged (`{"vitD": true}`).
  static const _refKeyed = {
    ImportSection.prayerLogs: 'prayer',
    ImportSection.medDoses: 'med',
    ImportSection.habitLogs: 'habit',
    ImportSection.labReadings: 'test',
    ImportSection.goalLogs: 'goal',
    ImportSection.jarDeposits: 'jar',
    ImportSection.debtPayments: 'debt',
    ImportSection.contactLogs: 'person',
    ImportSection.workoutLogs: 'exercise',
  };

  static const _recordFieldHints = [
    'date', 'at', 'day', 'time', 'value', 'status', 'taken', 'done', 'amount', 'note', 'notes', 'score', //
    'med', 'medId', 'medication', 'habit', 'habitId', 'test', 'testId', 'prayer', 'goal', 'jar', 'debt', 'person',
    'exercise', 'name', 'title', 'تاريخ', 'قيمة', 'حالة',
  ];

  static bool _keyedScalars(ImportSection section, Map m) {
    if (!_refKeyed.containsKey(section) || m.isEmpty) return false;
    if (section == ImportSection.prayerLogs) {
      return m.keys.any((k) => ImportValues.enumOf('$k', ImportAliases.prayer) != null) &&
          m.values.every((v) => _isScalar(v) || v is Map);
    }
    final hints = {for (final h in _recordFieldHints) ImportText.key(h)};
    if (m.keys.any((k) => hints.contains(ImportText.key('$k')))) return false;
    return m.values.every((v) => _isScalar(v) || v is Map);
  }

  static Map<String, Object?> _refFields(ImportSection section, String key, Object? v) {
    final ref = _refKeyed[section] ?? 'name';
    if (v is Map) return {ref: key, ..._fields(v)};
    return switch (section) {
      ImportSection.prayerLogs => {'prayer': key, 'status': v},
      ImportSection.medDoses => {'med': key, 'status': v},
      ImportSection.habitLogs => {'habit': key, 'done': v},
      ImportSection.contactLogs => {'person': key, if (v is! bool) 'channel': v},
      _ => {ref: key, 'value': v},
    };
  }

  /// `{"USD": 0.709, "EGP": 0.0145}` or `[{"code": "USD", "rate": 0.709}]`.
  void _rates(Map v, String path) {
    final rates = (_out.settings['rates'] as Map<String, num>?) ?? <String, num>{};
    for (final e in v.entries) {
      final k = '${e.key}';
      final p = _join(path, k);
      if (_setting(k, e.value)) continue;
      if (ImportText.key(k) == 'rates' && e.value is Map) {
        _rates(e.value as Map, p);
        continue;
      }
      final code = k.trim().toUpperCase();
      final val = e.value;
      final rate = val is Map ? ImportValues.number(val['rate'] ?? val['rateToBase'] ?? val['value']) : ImportValues.number(val);
      if (RegExp(r'^[A-Z]{3}$').hasMatch(code) && rate != null && rate > 0) {
        rates[code] = rate;
      } else {
        _leftover(p, val);
      }
    }
    if (rates.isNotEmpty) _out.settings['rates'] = rates;
  }

  /// Budget written as a map of name → amount / object / children.
  void _budgetMap(Map v, String path, _Ctx ctx) {
    for (final e in v.entries) {
      final k = '${e.key}';
      final p = _join(path, k);
      if (_setting(k, e.value)) continue;
      final val = e.value;
      if (val is List) {
        final rec = _item(ImportSection.budgetItems, <String, Object?>{'name': k}, p, ctx, sourceId: k);
        if (rec != null) _section((section: ImportSection.budgetItems, hint: null), val, p, ctx.child(rec));
      } else if (val is Map) {
        final fields = _fields(val);
        if (!_hasAny(fields, ImportAliases.name)) fields['name'] = k;
        _item(ImportSection.budgetItems, fields, p, ctx, sourceId: _idOf(fields) ?? k);
      } else {
        _item(ImportSection.budgetItems, <String, Object?>{'name': k, 'amount': val}, p, ctx, sourceId: k);
      }
    }
  }

  static bool _hasKey(Map<String, Object?> m, String key) => m.keys.any((k) => ImportText.key(k) == ImportText.key(key));
  static bool _hasAny(Map<String, Object?> m, List<String> aliases) => aliases.any((a) => _hasKey(m, a));

  /// Field that receives a bare string item (`"avoid": ["sugar"]`).
  static String? _primaryField(ImportSection s) => switch (s) {
    ImportSection.healthAlerts || ImportSection.worries || ImportSection.avoidItems => 'body',
    ImportSection.doctorQuestions => 'question',
    ImportSection.projectItems || ImportSection.tripItems => 'body',
    ImportSection.boardCards || ImportSection.tasks || ImportSection.appointments => 'title',
    ImportSection.trips => 'destination',
    ImportSection.habitLogs => 'day',
    ImportSection.waterLogs => 'ml',
    ImportSection.painEntries => 'score',
    ImportSection.moodEntries => 'mood',
    ImportSection.labReadings || ImportSection.goalLogs => 'value',
    ImportSection.contactLogs || ImportSection.fastingSessions => 'date',
    ImportSection.medDoses => 'med',
    ImportSection.prayerLogs => 'prayer',
    ImportSection.customModules || ImportSection.customEntries => null,
    _ => 'name',
  };

  // --------------------------------------------------------------- item --

  static final _budgetReserved = {
    for (final k in const [
      'spent', 'used', 'actual', 'remaining', 'balance', 'left', 'color', 'colour', 'icon', 'emoji', 'order', //
      'sort', 'sortOrder', 'index', 'position', 'type', 'kind', 'mode', 'category', 'goal', 'target', 'created',
      'updated', 'createdAt', 'updatedAt', 'percentOf', 'of', 'base', 'weekly', 'monthly', 'isWeekly', 'unit',
      'مصروف', 'المصروف', 'متبقي', 'لون', 'أيقونة', 'ترتيب',
    ])
      ImportText.key(k),
    for (final list in [
      ImportAliases.id,
      ImportAliases.name,
      ImportAliases.notes,
      ImportAliases.amount,
      ImportAliases.percent,
      ImportAliases.currency,
      ImportAliases.parent,
      ImportAliases.period,
    ])
      for (final k in list) ImportText.key(k),
  };

  RawRecord? _item(
    ImportSection section,
    Object? item,
    String path,
    _Ctx ctx, {
    String? hint,
    String? sourceId,
  }) {
    if (item == null) return null;
    if (item is List) {
      if (item.length == 2 && _isScalar(item[1]) && ImportValues.date(item[0]) != null) {
        return _item(section, {'date': item[0], 'value': item[1]}, path, ctx, hint: hint, sourceId: sourceId);
      }
      for (var i = 0; i < item.length; i++) {
        _item(section, item[i], '$path[$i]', ctx, hint: hint);
      }
      return null;
    }
    final Map<String, Object?> fields;
    if (item is Map) {
      fields = _fields(item);
      for (final k in fields.keys) {
        _out._countKey(k);
      }
    } else {
      final primary = _primaryField(section);
      if (primary == null) {
        _leftover(path, item);
        return null;
      }
      fields = {primary: item};
    }
    final rec = RawRecord(
      section: section,
      fields: fields,
      path: path,
      sourceId: sourceId ?? (item is Map ? _idOf(item) : null),
      parent: ctx.parent,
      day: ctx.day,
      hint: hint,
      column: ctx.column,
      window: ctx.window,
      domain: ctx.domain,
      inLogs: ctx.logs,
    );
    _out._add(rec);
    if (item is! Map) return rec;

    // Nested children.
    final childCtx = ctx.child(rec);
    if (section == ImportSection.labTests) _labHistoryFields(rec, childCtx);
    for (final e in fields.entries.toList()) {
      final k = e.key;
      final v = e.value;
      if (v is! List && v is! Map) continue;
      final p = _join(path, k);
      final child = ImportAliases.childFor(section, k);
      if (child != null) {
        rec.consumed.add(k);
        _section((section: child, hint: null), v, p, childCtx);
        continue;
      }
      if (section == ImportSection.boards) {
        if (_boardColumns(rec, k, v, p, childCtx)) continue;
      }
    }
    if (section == ImportSection.budgetItems) _budgetChildren(rec, childCtx);
    return rec;
  }

  /// A lab test written with its readings as day keys:
  /// `{"name": "LDL", "unit": "mg/dL", "2026-01-01": 120, "2026-02-01": 110}`
  /// – the dated values are read like a `history` map of readings.
  void _labHistoryFields(RawRecord test, _Ctx ctx) {
    final history = <String, Object?>{
      for (final e in test.fields.entries)
        if (ImportValues.isDateKey(e.key) && _isScalar(e.value) && e.value != null) e.key: e.value,
    };
    if (history.isEmpty) return;
    test.consumed.addAll(history.keys);
    _section((section: ImportSection.labReadings, hint: null), history, test.path, ctx);
  }

  /// Kanban columns inside a board: `"todo": [...]` or
  /// `"columns": [{"id": "doing", "label": "Doing", "cards": [...]}]`.
  bool _boardColumns(RawRecord board, String key, Object? v, String path, _Ctx ctx) {
    final known = ImportAliases.knownColumn(key);
    if (known != null && v is List) {
      board.consumed.add(key);
      board.columns[known] = key;
      for (var i = 0; i < v.length; i++) {
        _item(ImportSection.boardCards, v[i], '$path[$i]', ctx.copy(column: known));
      }
      return true;
    }
    if (ImportText.key(key) == 'columns' || ImportText.key(key) == 'lists' || ImportText.key(key) == 'اعمده') {
      if (v is! List) return false;
      board.consumed.add(key);
      for (var i = 0; i < v.length; i++) {
        final col = v[i];
        if (col is! Map) {
          final label = ImportValues.string(col);
          if (label != null) board.columns[ImportAliases.knownColumn(label) ?? ImportText.slug(label)] = label;
          continue;
        }
        final label = ImportValues.string(col['label'] ?? col['name'] ?? col['title'] ?? col['id']) ?? 'column${i + 1}';
        final id = ImportAliases.knownColumn(label) ??
            ImportAliases.knownColumn(ImportValues.string(col['id']) ?? '') ??
            ImportText.slug(ImportValues.string(col['id']) ?? label);
        board.columns[id] = label;
        final cards = col['cards'] ?? col['tasks'] ?? col['items'];
        if (cards is List) {
          for (var j = 0; j < cards.length; j++) {
            _item(ImportSection.boardCards, cards[j], '$path[$i].cards[$j]', ctx.copy(column: id));
          }
        }
      }
      return true;
    }
    return false;
  }

  /// Budget items written as `{"name": "Home food", "Proteins": 100, …}`:
  /// unknown keys with an amount / percent / object value are children.
  void _budgetChildren(RawRecord rec, _Ctx ctx) {
    if (rec.consumed.isNotEmpty) return; // explicit children list wins
    for (final e in rec.fields.entries.toList()) {
      final k = e.key;
      final n = ImportText.key(k);
      if (_budgetReserved.contains(n) || ImportAliases.childFor(ImportSection.budgetItems, k) != null) continue;
      final v = e.value;
      final isAmount = (v is num) || (v is String && (ImportValues.number(v) != null));
      if (!isAmount && v is! Map) continue;
      rec.consumed.add(k);
      final p = _join(rec.path, k);
      if (v is Map) {
        final fields = _fields(v);
        if (!_hasAny(fields, ImportAliases.name)) fields['name'] = k;
        _item(ImportSection.budgetItems, fields, p, ctx, sourceId: _idOf(fields) ?? k);
      } else {
        _item(ImportSection.budgetItems, <String, Object?>{'name': k, 'amount': v}, p, ctx, sourceId: k);
      }
    }
  }
}
