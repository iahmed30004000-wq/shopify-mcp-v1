/// Maps [RawRecord]s found by the locator to Drift companions: resolves
/// every column through the field aliases, assigns stable namespaced ids,
/// remaps references (reading → test, card → board, item → project,
/// entry → module …), infers custom modules for unknown lists and reports
/// every decision it had to make.
library;

import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import '../design/themes.dart' show PlanetPalettes;
import '../domain/budget_math.dart';
import '../domain/enums.dart';
import '../domain/money.dart';
import 'import_aliases.dart';
import 'import_labels.dart';
import 'import_locator.dart';
import 'import_models.dart';
import 'import_rows.dart';
import 'import_text.dart';
import 'import_values.dart';
import 'sha256.dart';

Value<T> _v<T>(T? x) => x == null ? const Value.absent() : Value(x);

/// Reads the fields of one record through alias lists and remembers which
/// keys were used, so leftovers can be reported.
class _Fields {
  _Fields(this.rec, this._mapper) {
    for (final k in rec.fields.keys) {
      _norm.putIfAbsent(ImportText.key(k), () => k);
    }
  }

  final RawRecord rec;
  final ImportMapper _mapper;
  final Map<String, String> _norm = {};
  final Set<String> used = {};

  String? keyOf(List<String> aliases) {
    for (final a in aliases) {
      final k = _norm[ImportText.key(a)];
      if (k != null && !rec.consumed.contains(k) && !used.contains(k)) return k;
    }
    return null;
  }

  bool has(List<String> aliases) => keyOf(aliases) != null;

  Object? raw(List<String> aliases) {
    final k = keyOf(aliases);
    if (k == null) return null;
    used.add(k);
    return rec.fields[k];
  }

  /// Peeks without consuming.
  Object? peek(List<String> aliases) {
    final k = keyOf(aliases);
    return k == null ? null : rec.fields[k];
  }

  String? path(List<String> aliases) {
    final k = keyOf(aliases);
    return k == null ? rec.path : '${rec.path}.$k';
  }

  String? str(List<String> aliases) => ImportValues.string(raw(aliases));

  double? number(List<String> aliases) {
    final p = path(aliases);
    final v = raw(aliases);
    final n = ImportValues.number(v);
    if (n == null && v != null && ImportValues.string(v) != null) {
      _mapper._issue(ImportIssueCode.unparsedNumber, rec.section, p, ImportValues.string(v));
    }
    return n;
  }

  int? integer(List<String> aliases) => number(aliases)?.round();

  bool? boolean(List<String> aliases) => ImportValues.boolean(raw(aliases));

  DateTime? date(List<String> aliases) {
    final p = path(aliases);
    final v = raw(aliases);
    if (v == null) return null;
    final d = ImportValues.date(v);
    if (d == null && ImportValues.string(v) != null) {
      _mapper._issue(ImportIssueCode.unparsedDate, rec.section, p, ImportValues.string(v));
    }
    return d;
  }

  List<String> strings(List<String> aliases) => ImportValues.strings(raw(aliases));

  T? enumOf<T>(List<String> aliases, Map<String, T> table) {
    final p = path(aliases);
    final v = raw(aliases);
    if (v == null) return null;
    final e = ImportValues.enumOf(v, table);
    if (e == null && ImportValues.string(v) != null) {
      _mapper._issue(ImportIssueCode.unknownValue, rec.section, p, ImportValues.string(v));
    }
    return e;
  }

  /// Money in [currency] unless the text names another one.
  Money? money(List<String> aliases, String currency) {
    final p = path(aliases);
    final v = raw(aliases);
    if (v == null) return null;
    final m = Money.tryParse(v, currency: currency);
    if (m == null && ImportValues.string(v) != null) {
      _mapper._issue(ImportIssueCode.unparsedAmount, rec.section, p, ImportValues.string(v));
    }
    return m;
  }

  /// An ISO currency code from a field (`"usd"`, `"دينار"`, `"$"`).
  String? currency() {
    final v = raw(ImportAliases.currency);
    return CurrencyCatalog.normalize(v);
  }

  /// Date + optional separate clock, falling back to the record's day.
  DateTime? at({List<String> aliases = ImportAliases.date, bool useDay = true}) {
    final dateKey = keyOf(aliases);
    DateTime? d;
    var hasClock = false;
    if (dateKey != null) {
      final v = rec.fields[dateKey];
      used.add(dateKey);
      d = ImportValues.date(v);
      if (d == null) {
        final clock = ImportValues.time(v);
        final day = rec.effectiveDay;
        if (clock != null && day != null) {
          d = _combine(day, clock);
          hasClock = true;
        } else if (ImportValues.string(v) != null) {
          _mapper._issue(ImportIssueCode.unparsedDate, rec.section, '${rec.path}.$dateKey', ImportValues.string(v));
        }
      } else {
        hasClock = d.hour != 0 || d.minute != 0;
      }
    }
    if (d == null && useDay) d = rec.effectiveDay;
    if (d != null && !hasClock) {
      final ck = keyOf(ImportAliases.clock);
      if (ck != null) {
        final t = ImportValues.time(rec.fields[ck]);
        if (t != null) {
          used.add(ck);
          d = _combine(d, t);
        }
      }
    }
    return d;
  }

  static DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// The group key injected by the locator (`{"morning": [meds…]}`).
  String? get group {
    final g = rec.fields[ImportLocator.groupKey];
    if (g == null) return null;
    used.add(ImportLocator.groupKey);
    return ImportValues.string(g);
  }

  Iterable<String> get unused sync* {
    for (final k in rec.fields.keys) {
      if (!used.contains(k) && !rec.consumed.contains(k)) yield k;
    }
  }
}

/// Mapper state and output of one analysis.
class ImportMapper {
  ImportMapper({
    required this.located,
    required this.labels,
    required this.defaultCurrency,
    required this.now,
  }) : baseCurrency = (located.settings['baseCurrency'] as String?) ?? defaultCurrency.toUpperCase(),
       fileDeclaresBase = located.settings['baseCurrency'] != null;

  final LocatedData located;
  final ImportLabels labels;
  final String defaultCurrency;
  final DateTime now;

  /// Currency of amounts without one.
  final String baseCurrency;
  final bool fileDeclaresBase;

  final List<ImportIssue> issues = [];
  final Map<ImportSection, ImportSectionReport> sections = {};
  final ImportRows rows = ImportRows();
  final List<ImportedModuleSummary> modules = [];
  final List<BudgetNode> budgetNodes = [];

  /// Currency codes used by any money row → rate from the file (or null).
  final Map<String, double?> currencies = {};
  final Map<String, ({int count, String path, String? preview})> _unmappedFields = {};

  final Set<String> _usedIds = {};
  final Map<ImportSection, Map<String, String>> _bySid = {};
  final Map<ImportSection, Map<String, String>> _byName = {};
  final Map<String, int> _sortCounters = {};
  final Map<String, String> _walletCurrency = {};
  final Map<String, String> _walletName = {};
  final Set<String> _createdWallets = {};
  final Map<String, ({Map<String, String> columns, String name})> _boardColumns = {};
  final Set<String> _habitDays = {};
  final Set<String> _prayerDays = {};

  // Post-pass state: wallet balances and goal "current" totals.
  final Map<String, ({RawRecord rec, int balanceMilli})> _walletBalances = {};
  final Map<String, int> _walletNet = {};
  final Map<String, ({RawRecord rec, double current})> _goalCurrent = {};
  final Map<String, double> _goalLogged = {};
  final Map<String, WalletsCompanion> _walletRows = {};
  final Map<String, LearningGoalsCompanion> _goalRows = {};

  ImportSectionReport _report(ImportSection s) => sections[s] ??= ImportSectionReport(s);

  void _issue(ImportIssueCode code, ImportSection? section, String? path, [String? detail, Map<String, Object?>? args]) {
    issues.add(ImportIssue(code, section: section, path: path, detail: detail, args: args ?? const {}));
  }

  void _skip(RawRecord r, String field) {
    _report(r.section).skipped++;
    _issue(ImportIssueCode.missingRequired, r.section, r.path, field);
  }

  int _order(ImportSection s, String? parentId) {
    final k = '${s.name}|${parentId ?? ''}';
    final n = _sortCounters[k] ?? 0;
    _sortCounters[k] = n + 1;
    return n;
  }

  // ---------------------------------------------------------------- run --

  /// Maps everything located.
  void run() {
    for (final r in located.allRecords) {
      _idOf(r);
    }
    for (final r in located.allRecords) {
      _index(r);
    }
    for (final section in _mapOrder) {
      for (final r in List.of(located.records[section] ?? const <RawRecord>[])) {
        _map(r);
      }
    }
    _finishWallets();
    _finishGoals();
    _finishBoards();
    for (final u in located.unknown) {
      _module(u);
    }
    _currencies();
    for (final t in rows.all) {
      if (t.rows.isNotEmpty) _report(t.section).planned = t.rows.length;
    }
    for (final r in located.allRecords) {
      if (r.id != null) _report(r.section).sourcePaths.add(_pattern(r.path));
    }
  }

  static const _mapOrder = [
    ImportSection.healthAlerts,
    ImportSection.conditions,
    ImportSection.medications,
    ImportSection.labTests,
    ImportSection.appointments,
    ImportSection.habits,
    ImportSection.worries,
    ImportSection.wallets,
    ImportSection.budgetItems,
    ImportSection.jars,
    ImportSection.debts,
    ImportSection.obligations,
    ImportSection.people,
    ImportSection.projects,
    ImportSection.boards,
    ImportSection.trips,
    ImportSection.travelDocuments,
    ImportSection.learningGoals,
    ImportSection.exercises,
    ImportSection.avoidItems,
    ImportSection.medDoses,
    ImportSection.labReadings,
    ImportSection.doctorQuestions,
    ImportSection.painEntries,
    ImportSection.moodEntries,
    ImportSection.habitLogs,
    ImportSection.transactions,
    ImportSection.jarDeposits,
    ImportSection.debtPayments,
    ImportSection.contactLogs,
    ImportSection.projectItems,
    ImportSection.boardCards,
    ImportSection.tripItems,
    ImportSection.goalLogs,
    ImportSection.workoutLogs,
    ImportSection.fastingSessions,
    ImportSection.waterLogs,
    ImportSection.prayerLogs,
    ImportSection.tasks,
  ];

  /// Report paths with list indexes collapsed (`meds[3]` → `meds[*]`).
  static String _pattern(String path) => path.replaceAll(RegExp(r'\[\d+\]'), '[*]');

  // ------------------------------------------------------------------ ids --

  static const _entitySections = {
    ImportSection.healthAlerts, ImportSection.conditions, ImportSection.medications, ImportSection.labTests, //
    ImportSection.habits, ImportSection.worries, ImportSection.wallets, ImportSection.budgetItems,
    ImportSection.jars, ImportSection.debts, ImportSection.obligations, ImportSection.people, ImportSection.projects,
    ImportSection.projectItems, ImportSection.boards, ImportSection.boardCards, ImportSection.trips,
    ImportSection.tripItems, ImportSection.travelDocuments, ImportSection.learningGoals, ImportSection.exercises,
    ImportSection.avoidItems, ImportSection.tasks, ImportSection.doctorQuestions,
  };

  static String _sanitize(String sid) {
    final s = sid.replaceAll(RegExp('[^A-Za-z0-9_\\-.:\u0600-\u06FF]'), '_');
    return s.length > 60 ? Sha256.ofString(sid).substring(0, 24) : s;
  }

  String _claim(String base, {ImportSection? section, String? path, bool reportDuplicate = false}) {
    var id = base;
    var n = 2;
    while (!_usedIds.add(id)) {
      if (reportDuplicate && n == 2) _issue(ImportIssueCode.duplicateSourceId, section, path, base);
      id = '$base~${n++}';
    }
    return id;
  }

  /// Stable id: `imp.<table>.<source id>` when the source has one, else a
  /// fingerprint of the record (name + parent for entities, content for
  /// logs), so re-importing the same file yields the same ids.
  String _idOf(RawRecord r) {
    final existing = r.id;
    if (existing != null) return existing;
    final parentId = r.parent == null ? null : _idOf(r.parent!);
    final table = r.section.name;
    String id;
    final sid = r.sourceId;
    if (sid != null) {
      final global = 'imp.$table.${_sanitize(sid)}';
      if (!_usedIds.contains(global) || parentId == null) {
        id = _claim(global, section: r.section, path: r.path, reportDuplicate: true);
      } else {
        id = _claim('$parentId/${_sanitize(sid)}');
      }
    } else {
      final name = _entitySections.contains(r.section) ? _nameOf(r) : null;
      final day = r.effectiveDay == null ? '' : ImportValues.dayKey(r.effectiveDay!);
      final seed = name != null
          ? '$table|${parentId ?? ''}|${ImportText.words(name)}'
          : '$table|${parentId ?? ''}|$day|${r.column ?? ''}|${r.window?.name ?? ''}|${Sha256.canonicalJson(r.fields)}';
      id = _claim('imp.$table.${Sha256.ofString(seed).substring(0, 20)}');
    }
    return r.id = id;
  }

  static const _nameAliases = <ImportSection, List<String>>{
    ImportSection.trips: ['destination', 'place', 'city', 'to', 'name', 'title', 'وجهة', 'مدينة', 'اسم'],
    ImportSection.debts: ['person', 'name', 'who', 'with', 'counterparty', 'شخص', 'اسم', 'مع'],
    ImportSection.boards: ['name', 'title', 'country', 'label', 'board', 'اسم', 'دولة', 'بلد'],
    ImportSection.healthAlerts: ['body', 'text', 'message', 'alert', 'name', 'title', 'نص', 'تنبيه'],
    ImportSection.worries: ['body', 'text', 'worry', 'name', 'title', 'نص', 'قلق'],
    ImportSection.avoidItems: ['body', 'text', 'item', 'name', 'title', 'what', 'نص', 'اسم'],
    ImportSection.boardCards: ['title', 'name', 'text', 'task', 'label', 'عنوان', 'مهمة', 'اسم'],
    ImportSection.tasks: ['title', 'name', 'text', 'task', 'label', 'body', 'عنوان', 'مهمة', 'اسم'],
    ImportSection.doctorQuestions: ['question', 'text', 'q', 'title', 'body', 'سؤال'],
    ImportSection.projectItems: ['body', 'text', 'title', 'name', 'item', 'task', 'label', 'نص', 'اسم'],
    ImportSection.tripItems: ['body', 'text', 'title', 'name', 'item', 'label', 'نص', 'اسم'],
    ImportSection.appointments: ['title', 'name', 'reason', 'purpose', 'subject', 'عنوان', 'سبب'],
    ImportSection.travelDocuments: ['name', 'type', 'document', 'title', 'kind', 'اسم', 'نوع'],
  };

  static List<String> _namesFor(ImportSection s) => _nameAliases[s] ?? ImportAliases.name;

  static String? _nameOf(RawRecord r) {
    final aliases = _namesFor(r.section);
    for (final a in aliases) {
      final n = ImportText.key(a);
      for (final e in r.fields.entries) {
        if (ImportText.key(e.key) == n) {
          final s = ImportValues.string(e.value);
          if (s != null) return s;
        }
      }
    }
    return null;
  }

  void _index(RawRecord r) {
    final id = r.id!;
    final sids = _bySid[r.section] ??= {};
    final sid = r.sourceId;
    if (sid != null) {
      sids.putIfAbsent(sid, () => id);
      sids.putIfAbsent(ImportText.key(sid), () => id);
    }
    final name = _nameOf(r);
    if (name != null) (_byName[r.section] ??= {}).putIfAbsent(ImportText.words(name), () => id);
    if (r.section == ImportSection.boards) {
      final country = ImportValues.string(r.fields['country']);
      if (country != null) _byName[r.section]!.putIfAbsent(ImportText.words(country), () => id);
    }
  }

  /// Resolves a reference (id, name, or an object with either) in [target].
  String? _ref(ImportSection target, Object? value) {
    if (value == null) return null;
    if (value is Map) {
      final fields = {for (final e in value.entries) '${e.key}': e.value};
      for (final a in ImportAliases.id) {
        final v = fields.entries.where((e) => ImportText.key(e.key) == ImportText.key(a)).firstOrNull?.value;
        final hit = _ref(target, v);
        if (hit != null) return hit;
      }
      for (final a in ImportAliases.name) {
        final v = fields.entries.where((e) => ImportText.key(e.key) == ImportText.key(a)).firstOrNull?.value;
        final hit = _ref(target, v);
        if (hit != null) return hit;
      }
      return null;
    }
    final s = ImportValues.string(value);
    if (s == null) return null;
    return _bySid[target]?[s] ?? _bySid[target]?[ImportText.key(s)] ?? _byName[target]?[ImportText.words(s)];
  }

  /// Resolves [value] in [target] or creates the target by name.
  String? _refOrCreate(ImportSection target, Object? value, RawRecord from, {Map<String, Object?> extra = const {}}) {
    final hit = _ref(target, value);
    if (hit != null) return hit;
    final name = value is Map ? ImportValues.string(value['name'] ?? value['title']) : ImportValues.string(value);
    if (name == null) return null;
    final key = _namesFor(target).first;
    final created = RawRecord(
      section: target,
      fields: {key: name, ...extra},
      path: '${from.path} → ${target.name}',
      domain: from.domain,
    );
    _idOf(created);
    _index(created);
    (located.records[target] ??= []).add(created);
    _issue(ImportIssueCode.createdReference, target, from.path, name);
    _map(created);
    return created.id;
  }

  String? _parentIdIf(RawRecord r, ImportSection section) {
    var p = r.parent;
    while (p != null) {
      if (p.section == section) return p.id;
      p = p.parent;
    }
    return null;
  }

  void _finishFields(_Fields f) {
    for (final k in f.unused) {
      final key = '${_pattern(f.rec.path)}.$k';
      final prev = _unmappedFields[key];
      final v = f.rec.fields[k];
      final preview = v is Map || v is List ? null : ImportValues.string(v);
      _unmappedFields[key] = (count: (prev?.count ?? 0) + 1, path: key, preview: prev?.preview ?? preview);
    }
  }

  /// Unmapped record fields, for the report.
  List<UnmappedEntry> get unmappedFields => [
    for (final e in _unmappedFields.values)
      UnmappedEntry(path: e.path, kind: 'field', count: e.count, preview: e.preview),
  ];

  // ------------------------------------------------------------ mapping --

  void _map(RawRecord r) {
    final f = _Fields(r, this);
    for (final a in ImportAliases.id) {
      if (f.has([a])) {
        f.raw([a]);
        break;
      }
    }
    switch (r.section) {
      case ImportSection.healthAlerts:
        _healthAlert(r, f);
      case ImportSection.conditions:
        _condition(r, f);
      case ImportSection.medications:
        _medication(r, f);
      case ImportSection.medDoses:
        _dose(r, f);
      case ImportSection.labTests:
        _labTest(r, f);
      case ImportSection.labReadings:
        _labReading(r, f);
      case ImportSection.appointments:
        _appointment(r, f);
      case ImportSection.doctorQuestions:
        _question(r, f);
      case ImportSection.painEntries:
        _pain(r, f);
      case ImportSection.moodEntries:
        _mood(r, f);
      case ImportSection.habits:
        _habit(r, f);
      case ImportSection.habitLogs:
        _habitLog(r, f);
      case ImportSection.worries:
        _worry(r, f);
      case ImportSection.wallets:
        _wallet(r, f);
      case ImportSection.budgetItems:
        _budgetItem(r, f);
      case ImportSection.transactions:
        _transaction(r, f);
      case ImportSection.jars:
        _jar(r, f);
      case ImportSection.jarDeposits:
        _jarDeposit(r, f);
      case ImportSection.debts:
        _debt(r, f);
      case ImportSection.debtPayments:
        _debtPayment(r, f);
      case ImportSection.obligations:
        _obligation(r, f);
      case ImportSection.people:
        _person(r, f);
      case ImportSection.contactLogs:
        _contactLog(r, f);
      case ImportSection.projects:
        _project(r, f);
      case ImportSection.projectItems:
        _projectItem(r, f);
      case ImportSection.boards:
        _board(r, f);
      case ImportSection.boardCards:
        _card(r, f);
      case ImportSection.trips:
        _trip(r, f);
      case ImportSection.tripItems:
        _tripItem(r, f);
      case ImportSection.travelDocuments:
        _document(r, f);
      case ImportSection.learningGoals:
        _goal(r, f);
      case ImportSection.goalLogs:
        _goalLog(r, f);
      case ImportSection.exercises:
        _exercise(r, f);
      case ImportSection.workoutLogs:
        _workoutLog(r, f);
      case ImportSection.avoidItems:
        _avoid(r, f);
      case ImportSection.fastingSessions:
        _fasting(r, f);
      case ImportSection.waterLogs:
        _water(r, f);
      case ImportSection.prayerLogs:
        _prayer(r, f);
      case ImportSection.tasks:
        _task(r, f);
      case ImportSection.currencies || ImportSection.customModules || ImportSection.customEntries:
        break;
    }
    _finishFields(f);
  }

  // Shared alias lists.
  static const _bodyish = ['body', 'text', 'message', 'content', 'alert', 'نص', 'المحتوى', 'رسالة'];
  static const _resolved = ['resolved', 'cured', 'healed', 'solved', 'closed', 'شفي', 'انتهى', 'محلول'];
  static const _colorKeys = ['color', 'colour', 'لون'];
  static const _iconKeys = ['icon', 'emoji', 'أيقونة'];

  int? _color(_Fields f) {
    final v = f.raw(_colorKeys);
    if (v is int) return v;
    final s = ImportValues.string(v);
    if (s == null) return null;
    final hex = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(s.trim());
    if (hex == null) return null;
    final h = hex[1]!;
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }

  bool? _activeFlag(_Fields f) {
    final a = f.boolean(ImportAliases.active);
    if (a != null) return a;
    final i = f.boolean(ImportAliases.inactive);
    return i == null ? null : !i;
  }

  String? _planet(Object? v) {
    final s = ImportValues.string(v);
    if (s == null) return null;
    return ImportAliases.domainFor(s);
  }

  void _healthAlert(RawRecord r, _Fields f) {
    final body = f.str([..._bodyish, ..._namesFor(r.section)]);
    if (body == null) return _skip(r, 'body');
    rows.healthAlerts.rows.add(
      HealthAlertsCompanion.insert(
        id: Value(r.id!),
        body: body,
        severity: _v(f.enumOf(['severity', 'level', 'priority', 'type', 'importance', 'خطورة', 'درجة', 'أهمية'], ImportAliases.severity)),
        pinned: _v(f.boolean(['pinned', 'pin', 'sticky', 'مثبت'])),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _condition(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final since = f.date(['since', 'start', 'diagnosed', 'diagnosedAt', 'diagnosedOn', 'from', 'منذ', 'تاريخ التشخيص']);
    final resolved = f.boolean(_resolved);
    rows.conditions.rows.add(
      ConditionsCompanion.insert(
        id: Value(r.id!),
        name: name,
        notes: _v(f.str(ImportAliases.notes)),
        since: _v(since),
        active: _v(_activeFlag(f) ?? (resolved == null ? null : !resolved)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  // ------------------------------------------------------------ health --

  static const _timesKeys = [
    'times', 'time', 'schedule', 'hours', 'at', 'when', 'slots', 'clock', 'doseTimes', 'مواعيد', 'أوقات', 'الوقت', //
    'وقت', 'الأوقات',
  ];
  static const _takenWithKeys = [
    'takenWith', 'with', 'timing', 'take', 'instructions', 'instruction', 'meal', 'food', 'relation', 'how', //
    'مع', 'التوقيت', 'طريقة', 'طريقة الأخذ', 'تعليمات',
  ];

  void _medication(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final kind = f.enumOf(['kind', 'type', 'category', 'form', 'نوع', 'فئة'], ImportAliases.medKind) ??
        (r.hint == 'supplement' ? MedKind.supplement : null);
    final dose = f.str(['dose', 'dosage', 'strength', 'amount', 'جرعة', 'الجرعة', 'عيار', 'كمية']);
    var doseAmount = f.number(['doseAmount', 'doseValue', 'quantity', 'qty']);
    var doseUnit = f.str(['doseUnit', 'unit', 'units', 'وحدة']);
    if (dose != null && (doseAmount == null || doseUnit == null)) {
      final m = RegExp(r'^\s*([\d.,]+)\s*(.*)$').firstMatch(MoneyText.foldDigits(dose));
      if (m != null) {
        doseAmount ??= MoneyText.parseNumber(m[1]!);
        final unit = m[2]!.trim();
        if (unit.isNotEmpty) doseUnit ??= unit;
      }
    }
    // Times: every clock value; words left over may describe the meal.
    final timesPath = f.path(_timesKeys);
    final parsed = ImportValues.times(f.raw(_timesKeys));
    final times = [...parsed.times];
    for (final w in parsed.inferred) {
      _issue(ImportIssueCode.inferredTime, r.section, timesPath, w);
    }
    final withPath = f.path(_takenWithKeys);
    final withRaw = f.raw(_takenWithKeys);
    var takenWith = ImportValues.enumOf(withRaw, ImportAliases.takenWith);
    String? takenWithNote;
    final withText = ImportValues.string(withRaw);
    if (withText != null) {
      final exact = ImportAliases.takenWith[ImportText.words(withText)];
      if (exact == null) takenWithNote = withText;
      if (takenWith == null) _issue(ImportIssueCode.unknownValue, r.section, withPath, withText);
    }
    for (final token in parsed.rejected) {
      final tw = ImportValues.enumOf(token, ImportAliases.takenWith);
      if (tw != null) {
        takenWith ??= tw;
      } else {
        _issue(ImportIssueCode.unparsedTime, r.section, timesPath, token);
      }
    }
    final group = f.group;
    if (group != null) {
      takenWith ??= ImportValues.enumOf(group, ImportAliases.takenWith);
      if (times.isEmpty) times.addAll(ImportValues.times(group).times);
    }
    final active = _activeFlag(f);
    rows.medications.rows.add(
      MedicationsCompanion.insert(
        id: Value(r.id!),
        name: name,
        kind: _v(kind),
        dose: _v(dose),
        doseAmount: _v(doseAmount),
        doseUnit: _v(doseUnit),
        times: Value(times),
        takenWith: _v(takenWith),
        takenWithNote: _v(takenWithNote),
        notes: _v(f.str(ImportAliases.notes)),
        active: _v(active),
        stock: _v(f.integer(['stock', 'count', 'remaining', 'left', 'pills', 'pillsLeft', 'inventory', 'المتبقي', 'المخزون'])),
        refillAt: _v(f.integer(['refillAt', 'refill', 'refillThreshold', 'reorder', 'reorderAt', 'minStock'])),
        color: _v(_color(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _dose(RawRecord r, _Fields f) {
    final refRaw = f.raw(['med', 'medId', 'medication', 'medicationId', 'medicine', 'drug', 'pill', 'name', 'دواء']);
    final medId = _parentIdIf(r, ImportSection.medications) ?? _refOrCreate(ImportSection.medications, refRaw, r);
    if (medId == null) return _skip(r, 'medication');
    final statusRaw = f.raw(['status', 'taken', 'done', 'state', 'result', 'value', 'حالة', 'تم']);
    final b = ImportValues.boolean(statusRaw);
    final status = b != null
        ? (b ? DoseStatus.taken : DoseStatus.missed)
        : ImportValues.enumOf(statusRaw, ImportAliases.doseStatus) ?? DoseStatus.taken;
    final scheduled = f.at(aliases: const ['scheduledAt', 'scheduled', 'due', 'plannedAt', 'slot'], useDay: false);
    final taken = f.at(aliases: const ['takenAt', 'at', 'date', 'timestamp', 'when', 'day', 'time', 'تاريخ', 'وقت']);
    if (scheduled == null && taken == null) return _skip(r, 'date');
    rows.medDoses.rows.add(
      MedDosesCompanion.insert(
        id: Value(r.id!),
        medicationId: medId,
        status: status,
        scheduledAt: _v(scheduled ?? (status == DoseStatus.taken ? null : taken)),
        takenAt: _v(status == DoseStatus.taken ? (taken ?? scheduled) : null),
        dose: _v(f.str(['dose', 'dosage', 'amount', 'جرعة'])),
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  static const _lowKeys = ['low', 'min', 'refLow', 'lower', 'normalLow', 'rangeLow', 'minimum', 'lowerLimit', 'الأدنى', 'حد أدنى', 'من'];
  static const _highKeys = ['high', 'max', 'refHigh', 'upper', 'normalHigh', 'rangeHigh', 'maximum', 'upperLimit', 'الأعلى', 'حد أعلى', 'إلى'];
  static const _rangeKeys = ['range', 'ref', 'reference', 'normal', 'refRange', 'normalRange', 'referenceRange', 'المعدل', 'المدى', 'الطبيعي', 'المعدل الطبيعي'];
  static const _valueKeys = ['value', 'result', 'reading', 'val', 'level', 'amount', 'قيمة', 'القيمة', 'النتيجة', 'نتيجة'];

  (double?, double?) _range(Object? v) {
    if (v is List && v.length == 2) return (ImportValues.number(v[0]), ImportValues.number(v[1]));
    if (v is Map) {
      double? pick(List<String> keys) {
        for (final e in v.entries) {
          if (keys.any((k) => ImportText.key(k) == ImportText.key('${e.key}'))) return ImportValues.number(e.value);
        }
        return null;
      }

      return (pick(_lowKeys), pick(_highKeys));
    }
    final s = ImportValues.string(v);
    if (s == null) return (null, null);
    final t = MoneyText.foldDigits(s).replaceAll('–', '-').replaceAll('—', '-');
    final between = RegExp(r'(-?[\d.]+)\s*(?:-|to|~|الى|إلى)\s*(-?[\d.]+)').firstMatch(t);
    if (between != null) return (double.tryParse(between[1]!), double.tryParse(between[2]!));
    final lt = RegExp(r'^\s*(?:<|≤|<=|below|under|أقل من)\s*([\d.]+)').firstMatch(t);
    if (lt != null) return (null, double.tryParse(lt[1]!));
    final gt = RegExp(r'^\s*(?:>|≥|>=|above|over|أكثر من)\s*([\d.]+)').firstMatch(t);
    if (gt != null) return (double.tryParse(gt[1]!), null);
    return (null, null);
  }

  void _labTest(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    var low = f.number(_lowKeys);
    var high = f.number(_highKeys);
    final rangePath = f.path(_rangeKeys);
    final range = f.raw(_rangeKeys);
    if (range != null) {
      final (lo, hi) = _range(range);
      if (lo == null && hi == null) {
        _issue(ImportIssueCode.unparsedNumber, r.section, rangePath, ImportValues.string(range));
      }
      low ??= lo;
      high ??= hi;
    }
    rows.labTests.rows.add(
      LabTestsCompanion.insert(
        id: Value(r.id!),
        name: name,
        unit: _v(f.str(['unit', 'units', 'uom', 'وحدة', 'الوحدة'])),
        low: _v(low),
        high: _v(high),
        category: _v(f.str(['category', 'group', 'panel', 'type', 'فئة', 'مجموعة']) ?? f.group),
        notes: _v(f.str(ImportAliases.notes)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
    // A test carrying a single current value (+ date) → one reading.
    if (f.has(_valueKeys)) {
      final reading = RawRecord(
        section: ImportSection.labReadings,
        fields: {
          'value': f.raw(_valueKeys),
          if (f.has(ImportAliases.date)) 'date': f.raw(ImportAliases.date),
        },
        path: r.path,
        parent: r,
        day: r.day,
      );
      _idOf(reading);
      (located.records[ImportSection.labReadings] ??= []).add(reading);
      _map(reading);
    }
  }

  void _labReading(RawRecord r, _Fields f) {
    var testId = _parentIdIf(r, ImportSection.labTests);
    if (testId == null) {
      final refKeys = ['test', 'testId', 'testName', 'lab', 'labId', 'analysis', 'marker', 'name', 'تحليل', 'التحليل', 'فحص'];
      // A panel: {"date": …, "values": {"HbA1c": 5.4, "LDL": 120}}.
      if (!f.has(refKeys)) {
        final panelKey = f.keyOf(['values', 'results', 'tests', 'readings', 'panel', 'نتائج', 'قيم']);
        final panel = panelKey == null ? null : r.fields[panelKey];
        if (panel is Map) {
          f.used.add(panelKey!);
          final date = f.raw(ImportAliases.date);
          for (final e in panel.entries) {
            final child = RawRecord(
              section: ImportSection.labReadings,
              fields: {'test': '${e.key}', if (e.value is Map) ...{for (final x in (e.value as Map).entries) '${x.key}': x.value} else 'value': e.value, 'date': ?date},
              path: '${r.path}.$panelKey.${e.key}',
              day: r.day,
            );
            _idOf(child);
            (located.records[ImportSection.labReadings] ??= []).add(child);
            _map(child);
          }
          return;
        }
      }
      testId = _refOrCreate(ImportSection.labTests, f.raw(refKeys), r);
    }
    if (testId == null) return _skip(r, 'test');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    final valuePath = f.path(_valueKeys);
    final raw = f.raw(_valueKeys);
    final number = ImportValues.number(raw);
    final text = number == null ? ImportValues.string(raw) : null;
    if (raw != null && number == null && text == null) {
      _issue(ImportIssueCode.unparsedNumber, r.section, valuePath);
    }
    rows.labReadings.rows.add(
      LabReadingsCompanion.insert(
        id: Value(r.id!),
        testId: testId,
        date: at,
        value: _v(number),
        valueText: _v(text),
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  void _appointment(RawRecord r, _Fields f) {
    final doctor = f.str(['doctor', 'dr', 'physician', 'specialist', 'طبيب', 'الطبيب', 'دكتور']);
    final place = f.str(['place', 'location', 'clinic', 'hospital', 'where', 'address', 'مكان', 'عيادة', 'مستشفى']);
    final title = f.str(_namesFor(r.section)) ?? doctor ?? place;
    if (title == null) return _skip(r, 'title');
    final at = f.at(aliases: const ['at', 'date', 'datetime', 'when', 'on', 'time', 'موعد', 'تاريخ', 'وقت']);
    if (at == null) return _skip(r, 'date');
    rows.appointments.rows.add(
      AppointmentsCompanion.insert(
        id: Value(r.id!),
        title: title,
        doctor: _v(doctor),
        place: _v(place),
        at: at,
        notes: _v(f.str(ImportAliases.notes)),
        done: _v(f.boolean(['done', 'completed', 'attended', 'past', 'تم', 'حضرت'])),
      ),
    );
  }

  void _question(RawRecord r, _Fields f) {
    final q = f.str(_namesFor(r.section));
    if (q == null) return _skip(r, 'question');
    final answer = f.str(['answer', 'reply', 'response', 'جواب', 'الإجابة', 'إجابة']);
    final apptId = _parentIdIf(r, ImportSection.appointments) ??
        _ref(ImportSection.appointments, f.raw(['appointment', 'appointmentId', 'visit', 'موعد']));
    final parentId = apptId;
    rows.doctorQuestions.rows.add(
      DoctorQuestionsCompanion.insert(
        id: Value(r.id!),
        question: q,
        appointmentId: _v(apptId),
        answered: _v(f.boolean(['answered', 'done', 'resolved', 'asked', 'تمت الإجابة', 'تم']) ?? (answer != null ? true : null)),
        answer: _v(answer),
        sortOrder: Value(_order(r.section, parentId)),
      ),
    );
  }

  void _pain(RawRecord r, _Fields f) {
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    final score = f.number(['score', 'pain', 'level', 'value', 'intensity', 'severity', 'rating', 'شدة', 'درجة', 'مستوى', 'الألم', 'ألم']);
    if (score == null) return _skip(r, 'score');
    final pts = f.raw(['bodyPoints', 'points', 'bodyMap', 'map']);
    rows.painEntries.rows.add(
      PainEntriesCompanion.insert(
        id: Value(r.id!),
        at: at,
        score: score.round().clamp(0, 10),
        locations: Value(f.strings(['locations', 'location', 'where', 'area', 'areas', 'site', 'sites', 'part', 'bodyPart', 'bodyParts', 'مكان', 'أماكن', 'موضع', 'المنطقة', 'مواضع'])),
        triggers: Value(f.strings(['triggers', 'trigger', 'cause', 'causes', 'reason', 'reasons', 'محفز', 'محفزات', 'سبب', 'أسباب'])),
        bodyPoints: pts is List ? Value(pts.cast<Object?>()) : const Value.absent(),
        notes: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  int? _scale(double? v, int min, int max) => v?.round().clamp(min, max);

  void _mood(RawRecord r, _Fields f) {
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    final hint = r.hint;
    List<String> withValue(String h, List<String> keys) =>
        hint == h ? [...keys, 'value', 'score', 'level', 'rating', 'قيمة', 'درجة'] : keys;
    // Mood 1..5: number or word.
    final moodRaw = f.raw(withValue('mood', ['mood', 'moodScore', 'feeling', 'feel', 'مزاج', 'المزاج', 'شعور']) +
        (hint == null ? const ['value', 'score', 'rating'] : const []));
    int? mood;
    final moodNumber = ImportValues.number(moodRaw);
    if (moodNumber != null) {
      mood = moodNumber > 5 && moodNumber <= 10 ? (moodNumber / 2).round() : moodNumber.round();
      mood = mood.clamp(1, 5);
    } else if (moodRaw != null) {
      mood = ImportValues.enumOf(moodRaw, ImportAliases.moodWords);
      if (mood == null) _issue(ImportIssueCode.unknownValue, r.section, r.path, ImportValues.string(moodRaw));
    }
    final stress = _scale(f.number(withValue('stress', ['stress', 'stressLevel', 'توتر', 'ضغط', 'التوتر'])), 0, 10);
    final anxiety = _scale(f.number(withValue('anxiety', ['anxiety', 'anxious', 'قلق'])), 0, 10);
    final energy = _scale(f.number(withValue('energy', ['energy', 'طاقة', 'الطاقة'])), 0, 10);
    final sleep = f.number(withValue('sleep', ['sleep', 'sleepHours', 'hoursSlept', 'hours', 'نوم', 'ساعات النوم']));
    final caffeine = f.integer(withValue('caffeine', ['caffeine', 'coffee', 'cups', 'caffeineCups', 'قهوة', 'كافيين']));
    final factors = f.strings(['factors', 'tags', 'reasons', 'causes', 'triggers', 'عوامل', 'وسوم', 'أسباب']);
    final notes = f.str(ImportAliases.notes);
    if ([mood, stress, anxiety, energy, sleep, caffeine, notes].every((x) => x == null) && factors.isEmpty) {
      return _skip(r, 'mood');
    }
    rows.moodEntries.rows.add(
      MoodEntriesCompanion.insert(
        id: Value(r.id!),
        at: at,
        mood: _v(mood),
        stress: _v(stress),
        anxiety: _v(anxiety),
        energy: _v(energy),
        sleepHours: _v(sleep),
        caffeineCups: _v(caffeine),
        factors: Value(factors),
        notes: _v(notes),
      ),
    );
  }

  void _habit(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    rows.habits.rows.add(
      HabitsCompanion.insert(
        id: Value(r.id!),
        name: name,
        category: _v(f.str(['category', 'group', 'type', 'فئة', 'تصنيف']) ?? f.group),
        planetKey: _v(_planet(f.raw(['planet', 'area', 'domain'])) ?? r.domain),
        active: _v(_activeFlag(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _habitLog(RawRecord r, _Fields f) {
    final habitId = _parentIdIf(r, ImportSection.habits) ??
        _refOrCreate(ImportSection.habits, f.raw(['habit', 'habitId', 'name', 'عادة']), r);
    if (habitId == null) return _skip(r, 'habit');
    final dayRaw = f.raw(['day', 'date', 'at', 'on', 'يوم', 'تاريخ']);
    final day = ImportValues.day(dayRaw) ?? (r.effectiveDay == null ? null : ImportValues.dayKey(r.effectiveDay!));
    if (day == null) return _skip(r, 'day');
    final doneRaw = f.raw(['done', 'value', 'completed', 'status', 'checked', 'تم', 'منجز']);
    final done = ImportValues.boolean(doneRaw) ?? (ImportValues.number(doneRaw) != null ? ImportValues.number(doneRaw)! > 0 : true);
    if (!_habitDays.add('$habitId|$day')) {
      _report(r.section).skipped++;
      return;
    }
    rows.habitLogs.rows.add(HabitLogsCompanion.insert(id: Value(r.id!), habitId: habitId, day: day, done: Value(done)));
  }

  void _worry(RawRecord r, _Fields f) {
    final body = f.str([..._bodyish, ..._namesFor(r.section)]);
    if (body == null) return _skip(r, 'body');
    rows.worries.rows.add(
      WorriesCompanion.insert(
        id: Value(r.id!),
        body: body,
        resolved: _v(f.boolean([..._resolved, 'done', 'تم'])),
        reflection: _v(f.str(['reflection', 'outcome', 'answer', 'result', 'تأمل', 'النتيجة', 'الخلاصة'])),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  // ------------------------------------------------------------- money --

  String _useCurrency(String code) {
    final c = code.toUpperCase();
    currencies.putIfAbsent(c, () => _fileRate(c));
    return c;
  }

  double? _fileRate(String code) {
    final rates = located.settings['rates'];
    if (rates is Map) {
      final r = rates[code];
      if (r is num) return r.toDouble();
    }
    return null;
  }

  void _wallet(RawRecord r, _Fields f) {
    final currency = _useCurrency(f.currency() ?? CurrencyCatalog.normalize(f.group) ?? baseCurrency);
    final name = f.str(_namesFor(r.section)) ?? currency;
    final opening = f.money(['opening', 'openingBalance', 'initial', 'initialBalance', 'start', 'startBalance', 'رصيد افتتاحي', 'الرصيد الافتتاحي'], currency);
    final balance = opening == null ? f.money(['balance', 'amount', 'current', 'total', 'رصيد', 'الرصيد', 'المبلغ'], currency) : null;
    _walletCurrency[r.id!] = currency;
    _walletName[r.id!] = name;
    if (balance != null) _walletBalances[r.id!] = (rec: r, balanceMilli: balance.milli);
    _walletRows[r.id!] = WalletsCompanion.insert(
      id: Value(r.id!),
      name: name,
      currency: currency,
      openingMilli: _v(opening?.milli ?? balance?.milli),
      kind: _v(f.enumOf(['kind', 'type', 'نوع'], ImportAliases.walletKind)),
      color: _v(_color(f)),
      icon: _v(f.str(_iconKeys)),
      archived: _v(f.boolean(ImportAliases.inactive)),
      sortOrder: Value(_order(r.section, null)),
    );
  }

  /// A wallet's balance field means "after its transactions": opening =
  /// balance − net of the imported transactions.
  void _finishWallets() {
    for (final e in _walletRows.entries) {
      var row = e.value;
      final bal = _walletBalances[e.key];
      final net = _walletNet[e.key] ?? 0;
      if (bal != null && net != 0) row = row.copyWith(openingMilli: Value(bal.balanceMilli - net));
      rows.wallets.rows.add(row);
    }
  }

  String _walletFor(String? walletId, String currency) {
    if (walletId != null) {
      final wc = _walletCurrency[walletId];
      if (wc == null || wc == currency) return walletId;
      // A companion wallet in the transaction's currency.
      final id = '$walletId.$currency';
      if (_createdWallets.add(id)) {
        final name = '${_walletName[walletId] ?? labels.defaultWallet} · $currency';
        _walletCurrency[id] = currency;
        _walletName[id] = name;
        _walletRows[id] = WalletsCompanion.insert(id: Value(id), name: name, currency: currency, sortOrder: Value(_order(ImportSection.wallets, null)));
        _issue(ImportIssueCode.currencyWallet, ImportSection.wallets, null, name);
      }
      return id;
    }
    final id = 'imp.wallets.default.$currency';
    if (_createdWallets.add(id)) {
      final name = currency == baseCurrency ? labels.defaultWallet : '${labels.defaultWallet} · $currency';
      _walletCurrency[id] = currency;
      _walletName[id] = name;
      _walletRows[id] = WalletsCompanion.insert(id: Value(id), name: name, currency: currency, sortOrder: Value(_order(ImportSection.wallets, null)));
    }
    return id;
  }

  static final _weeklyText = RegExp(r'/\s*(w|wk|week)\b|per\s*week|weekly|أسبوع|اسبوع|بالأسبوع|/\s*أ', caseSensitive: false);

  void _budgetItem(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    String? parentId = r.parent?.section == ImportSection.budgetItems ? r.parent!.id : null;
    if (parentId == null) {
      final pPath = f.path(ImportAliases.parent);
      final pRaw = f.raw(ImportAliases.parent);
      if (pRaw != null) {
        parentId = _ref(ImportSection.budgetItems, pRaw);
        if (parentId == null) _issue(ImportIssueCode.unresolvedReference, r.section, pPath, ImportValues.string(pRaw));
        if (parentId == r.id) parentId = null;
      }
    }
    var currency = f.currency();
    final amountPath = f.path(ImportAliases.amount);
    final amountRaw = f.raw(ImportAliases.amount);
    final pctRaw = f.raw(ImportAliases.percent);
    final modeRaw = ImportValues.string(f.raw(['mode', 'by', 'setBy', 'طريقة']));
    var percent = ImportValues.number(pctRaw);
    int? amountMilli;
    final amountText = ImportValues.string(amountRaw);
    if (amountRaw != null) {
      if (amountText != null && (amountText.contains('%') || amountText.contains('٪'))) {
        percent ??= ImportValues.number(amountText.replaceAll('%', '').replaceAll('٪', ''));
      } else {
        final m = Money.tryParse(amountRaw, currency: currency ?? baseCurrency);
        if (m == null) {
          _issue(ImportIssueCode.unparsedAmount, r.section, amountPath, amountText);
        } else {
          amountMilli = m.milli;
          if (amountText != null && CurrencyCatalog.detect(amountText) != null) currency ??= m.currency;
        }
      }
    }
    final periodRaw = f.raw(ImportAliases.period);
    var period = ImportValues.enumOf(periodRaw, ImportAliases.budgetPeriod);
    if (period == null && periodRaw != null) {
      _issue(ImportIssueCode.unknownValue, r.section, r.path, ImportValues.string(periodRaw));
    }
    if (period == null && amountText != null && _weeklyText.hasMatch(amountText)) period = BudgetPeriod.weekly;
    if (period == null && (f.boolean(['weekly', 'isWeekly', 'أسبوعي']) ?? false)) period = BudgetPeriod.weekly;
    period ??= BudgetPeriod.monthly;
    final explicitMode = modeRaw == null
        ? null
        : ImportText.words(modeRaw).contains('percent') || modeRaw.contains('%') || ImportText.words(modeRaw).contains('نسب')
        ? BudgetMode.percent
        : BudgetMode.amount;
    final mode = explicitMode ?? (amountMilli == null && percent != null ? BudgetMode.percent : BudgetMode.amount);
    final percentOf = f.enumOf(['percentOf', 'of', 'base', 'relativeTo', 'من'], ImportAliases.percentBase) ??
        (parentId == null ? PercentBase.total : PercentBase.parent);
    final itemCurrency = currency == null ? (fileDeclaresBase ? baseCurrency : null) : _useCurrency(currency);
    if (itemCurrency != null) _useCurrency(itemCurrency);
    final order = _order(r.section, parentId);
    rows.budgetItems.rows.add(
      BudgetItemsCompanion.insert(
        id: Value(r.id!),
        parentId: _v(parentId),
        name: name,
        mode: Value(mode),
        amountMilli: _v(amountMilli),
        percent: _v(percent),
        percentOf: Value(percentOf),
        period: Value(period),
        currency: _v(itemCurrency),
        color: _v(_color(f)),
        icon: _v(f.str(_iconKeys)),
        sortOrder: Value(order),
      ),
    );
    budgetNodes.add(
      BudgetNode(
        id: r.id!,
        name: name,
        parentId: parentId,
        mode: mode,
        amountMilli: amountMilli,
        percent: percent,
        percentOf: percentOf,
        period: period,
        currency: itemCurrency,
        sortOrder: order,
      ),
    );
  }

  bool? _signedLedger;

  /// A ledger without kinds whose amounts carry signs: negative = expense,
  /// positive = income.
  bool get _isSignedLedger => _signedLedger ??= (located.records[ImportSection.transactions] ?? const <RawRecord>[]).any((t) {
    final f = _Fields(t, this);
    if (f.has(['type', 'kind', 'direction', 'flow', 'نوع'])) return false;
    final a = ImportValues.number(f.peek(ImportAliases.amount));
    return a != null && a < 0;
  });

  void _transaction(RawRecord r, _Fields f) {
    final kindRaw = f.raw(['type', 'kind', 'direction', 'flow', 'نوع']);
    var kind = ImportValues.enumOf(kindRaw, ImportAliases.txKind);
    if (kind == null && kindRaw != null) _issue(ImportIssueCode.unknownValue, r.section, r.path, ImportValues.string(kindRaw));
    final walletRef = _parentIdIf(r, ImportSection.wallets) ??
        _ref(ImportSection.wallets, f.raw(['wallet', 'walletId', 'account', 'accountId', 'from', 'source', 'محفظة', 'حساب', 'من']));
    final explicit = f.currency();
    final walletCurrency = walletRef == null ? null : _walletCurrency[walletRef];
    final amount = f.money(['amount', 'value', 'sum', 'total', 'price', 'cost', 'مبلغ', 'قيمة', 'المبلغ'], explicit ?? walletCurrency ?? baseCurrency);
    if (amount == null) return _skip(r, 'amount');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    kind ??= switch (r.hint) {
      'income' => TxKind.income,
      'expense' => TxKind.expense,
      _ => amount.isNegative ? TxKind.expense : (_isSignedLedger ? TxKind.income : TxKind.expense),
    };
    final currency = _useCurrency(explicit ?? amount.currency);
    final walletId = _walletFor(walletRef, currency);
    final toWallet = _ref(ImportSection.wallets, f.raw(['toWallet', 'toWalletId', 'to', 'toAccount', 'destination', 'إلى']));
    final toAmount = f.money(['toAmount', 'received', 'amountTo', 'المبلغ المستلم'], toWallet == null ? currency : (_walletCurrency[toWallet] ?? currency));
    final tags = [...f.strings(['tags', 'labels', 'وسوم'])];
    final catPath = f.path(['category', 'categoryId', 'budget', 'budgetItem', 'budgetItemId', 'budgetId', 'envelope', 'item', 'بند', 'فئة', 'التصنيف', 'الفئة']);
    final catRaw = f.raw(['category', 'categoryId', 'budget', 'budgetItem', 'budgetItemId', 'budgetId', 'envelope', 'item', 'بند', 'فئة', 'التصنيف', 'الفئة']);
    final budgetItemId = _ref(ImportSection.budgetItems, catRaw);
    if (catRaw != null && budgetItemId == null) {
      final label = ImportValues.string(catRaw);
      if (label != null && !tags.contains(label)) tags.add(label);
      _issue(ImportIssueCode.unresolvedReference, r.section, catPath, label);
    }
    final milli = amount.milli.abs();
    final signed = switch (kind) {
      TxKind.income => milli,
      TxKind.expense => -milli,
      TxKind.transfer => -milli,
      TxKind.adjustment => amount.milli,
    };
    _walletNet[walletId] = (_walletNet[walletId] ?? 0) + signed;
    if (kind == TxKind.transfer && toWallet != null) {
      _walletNet[toWallet] = (_walletNet[toWallet] ?? 0) + (toAmount?.milli.abs() ?? milli);
    }
    rows.transactions.rows.add(
      TransactionsCompanion.insert(
        id: Value(r.id!),
        walletId: walletId,
        kind: kind,
        amountMilli: milli,
        date: at,
        budgetItemId: _v(budgetItemId),
        toWalletId: _v(toWallet),
        toAmountMilli: _v(toAmount?.milli.abs()),
        note: _v(f.str(['note', 'notes', 'description', 'desc', 'memo', 'title', 'name', 'details', 'payee', 'merchant', 'ملاحظة', 'وصف', 'البيان', 'بيان'])),
        tags: Value(tags),
      ),
    );
  }

  void _jar(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final currency = _useCurrency(f.currency() ?? baseCurrency);
    final target = f.money(['target', 'goal', 'targetAmount', 'amount', 'هدف', 'الهدف', 'المبلغ المستهدف'], currency);
    final saved = f.money(['saved', 'current', 'balance', 'progress', 'amountSaved', 'collected', 'المدخر', 'الحالي', 'رصيد'], currency);
    rows.jars.rows.add(
      JarsCompanion.insert(
        id: Value(r.id!),
        name: name,
        targetMilli: target?.milli ?? 0,
        currency: currency,
        deadline: _v(f.date(['deadline', 'due', 'by', 'until', 'targetDate', 'موعد', 'الموعد النهائي'])),
        color: _v(_color(f)),
        icon: _v(f.str(_iconKeys)),
        archived: _v(f.boolean(ImportAliases.inactive)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
    final hasDeposits = (located.records[ImportSection.jarDeposits] ?? const <RawRecord>[]).any((d) => d.parent == r);
    if (saved != null && saved.milli != 0 && !hasDeposits) {
      final exported = ImportValues.date(located.meta.entries.where((e) => ImportText.key(e.key).contains('export')).firstOrNull?.value);
      rows.jarDeposits.rows.add(
        JarDepositsCompanion.insert(
          id: Value(_claim('${r.id}.opening')),
          jarId: r.id!,
          amountMilli: saved.milli,
          date: exported ?? DateTime(now.year, now.month, now.day),
          note: Value(labels.openingBalance),
        ),
      );
    }
  }

  void _jarDeposit(RawRecord r, _Fields f) {
    final jarId = _parentIdIf(r, ImportSection.jars) ??
        _refOrCreate(ImportSection.jars, f.raw(['jar', 'jarId', 'fund', 'حصالة', 'name']), r);
    if (jarId == null) return _skip(r, 'jar');
    final amount = f.money(['amount', 'value', 'sum', 'deposit', 'مبلغ', 'قيمة'], baseCurrency);
    if (amount == null) return _skip(r, 'amount');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    final type = ImportText.words(ImportValues.string(f.raw(['type', 'kind', 'نوع'])) ?? '');
    final withdraw = type.contains('withdraw') || type.contains('سحب') || type.contains('out');
    rows.jarDeposits.rows.add(
      JarDepositsCompanion.insert(
        id: Value(r.id!),
        jarId: jarId,
        amountMilli: withdraw ? -amount.milli.abs() : amount.milli,
        date: at,
        walletId: _v(_ref(ImportSection.wallets, f.raw(['wallet', 'walletId', 'account', 'محفظة']))),
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  void _debt(RawRecord r, _Fields f) {
    final person = f.str(_namesFor(r.section));
    if (person == null) return _skip(r, 'person');
    final currency = _useCurrency(f.currency() ?? baseCurrency);
    final amount = f.money(['amount', 'value', 'sum', 'total', 'مبلغ', 'قيمة', 'المبلغ'], currency);
    if (amount == null) return _skip(r, 'amount');
    final direction = f.enumOf(['direction', 'type', 'kind', 'side', 'owe', 'اتجاه', 'نوع'], ImportAliases.debtDirection) ??
        (amount.isNegative ? DebtDirection.iOwe : DebtDirection.iOwe);
    final settled = f.boolean(['settled', 'paid', 'closed', 'done', 'repaid', 'مسدد', 'تم', 'مدفوع']);
    rows.debts.rows.add(
      DebtsCompanion.insert(
        id: Value(r.id!),
        direction: direction,
        person: person,
        amountMilli: amount.milli.abs(),
        currency: _useCurrency(amount.currency),
        dueDate: _v(f.date(['dueDate', 'due', 'deadline', 'until', 'استحقاق', 'موعد'])),
        note: _v(f.str(ImportAliases.notes)),
        settledAt: _v(f.date(['settledAt', 'paidAt', 'closedAt', 'تاريخ السداد']) ??
            (settled == true ? DateTime(now.year, now.month, now.day) : null)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _debtPayment(RawRecord r, _Fields f) {
    final debtId = _parentIdIf(r, ImportSection.debts) ?? _ref(ImportSection.debts, f.raw(['debt', 'debtId', 'دين', 'name']));
    if (debtId == null) return _skip(r, 'debt');
    final amount = f.money(['amount', 'value', 'sum', 'paid', 'مبلغ', 'قيمة'], baseCurrency);
    if (amount == null) return _skip(r, 'amount');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    rows.debtPayments.rows.add(
      DebtPaymentsCompanion.insert(
        id: Value(r.id!),
        debtId: debtId,
        amountMilli: amount.milli.abs(),
        date: at,
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  DateTime _nextMonthlyDay(int day) {
    final d = day.clamp(1, 28);
    final thisMonth = DateTime(now.year, now.month, d);
    return thisMonth.isBefore(DateTime(now.year, now.month, now.day)) ? DateTime(now.year, now.month + 1, d) : thisMonth;
  }

  void _obligation(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final currency = _useCurrency(f.currency() ?? baseCurrency);
    final amount = f.money(['amount', 'value', 'sum', 'cost', 'price', 'مبلغ', 'قيمة', 'المبلغ'], currency);
    if (amount == null) return _skip(r, 'amount');
    final freqRaw = f.raw(['frequency', 'period', 'every', 'recurrence', 'cycle', 'repeat', 'تكرار', 'دورة']);
    final frequency = ImportValues.enumOf(freqRaw, ImportAliases.recurrence);
    if (frequency == null && freqRaw != null) _issue(ImportIssueCode.unknownValue, r.section, r.path, ImportValues.string(freqRaw));
    var nextDue = f.date(['nextDue', 'next', 'due', 'dueDate', 'nextDate', 'date', 'الاستحقاق', 'موعد', 'تاريخ']);
    if (nextDue == null) {
      final dom = f.integer(['dayOfMonth', 'day', 'dueDay', 'يوم', 'يوم الاستحقاق']);
      nextDue = dom != null && dom >= 1 && dom <= 31 ? _nextMonthlyDay(dom) : DateTime(now.year, now.month, now.day);
      _issue(ImportIssueCode.assumedDate, r.section, r.path, ImportValues.dayKey(nextDue));
    }
    rows.obligations.rows.add(
      ObligationsCompanion.insert(
        id: Value(r.id!),
        name: name,
        amountMilli: amount.milli.abs(),
        currency: _useCurrency(amount.currency),
        walletId: _v(_ref(ImportSection.wallets, f.raw(['wallet', 'walletId', 'account', 'محفظة']))),
        budgetItemId: _v(_ref(ImportSection.budgetItems, f.raw(['category', 'budget', 'budgetItem', 'budgetItemId', 'بند', 'فئة']))),
        frequency: frequency ?? Recurrence.monthly,
        interval: _v(f.integer(['interval', 'everyN', 'كل'])),
        nextDue: nextDue,
        note: _v(f.str(ImportAliases.notes)),
        active: _v(_activeFlag(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  // ------------------------------------------------------------ people --

  int? _rhythm(Object? v) {
    final n = ImportValues.number(v);
    if (n != null) return n.round();
    final w = ImportText.words(ImportValues.string(v) ?? '');
    if (w.isEmpty) return null;
    if (w.contains('daily') || w.contains('يومي')) return 1;
    if (w.contains('biweekly') || w.contains('fortnight') || w.contains('اسبوعين')) return 14;
    if (w.contains('weekly') || w.contains('week') || w.contains('اسبوع')) return 7;
    if (w.contains('monthly') || w.contains('month') || w.contains('شهر')) return 30;
    if (w.contains('yearly') || w.contains('year') || w.contains('سنه') || w.contains('سنوي')) return 365;
    return null;
  }

  void _person(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final rhythmPath = f.path(['rhythmDays', 'rhythm', 'every', 'everyDays', 'frequencyDays', 'contactEvery', 'cadence', 'frequency', 'كل', 'التواصل كل']);
    final rhythmRaw = f.raw(['rhythmDays', 'rhythm', 'every', 'everyDays', 'frequencyDays', 'contactEvery', 'cadence', 'frequency', 'كل', 'التواصل كل']);
    final rhythm = _rhythm(rhythmRaw);
    if (rhythmRaw != null && rhythm == null) _issue(ImportIssueCode.unknownValue, r.section, rhythmPath, ImportValues.string(rhythmRaw));
    rows.people.rows.add(
      PeopleCompanion.insert(
        id: Value(r.id!),
        name: name,
        relation: _v(f.str(['relation', 'relationship', 'role', 'kinship', 'type', 'صلة', 'القرابة', 'العلاقة', 'صلة القرابة']) ?? f.group),
        rhythmDays: _v(rhythm),
        lastContact: _v(f.date(['lastContact', 'lastContacted', 'last', 'lastCall', 'lastSeen', 'آخر تواصل', 'آخر اتصال'])),
        phone: _v(f.str(['phone', 'mobile', 'tel', 'number', 'whatsapp', 'هاتف', 'جوال', 'رقم', 'موبايل'])),
        birthday: _v(f.date(['birthday', 'birthDate', 'dob', 'born', 'عيد ميلاد', 'تاريخ الميلاد', 'الميلاد'])),
        notes: _v(f.str(ImportAliases.notes)),
        color: _v(_color(f)),
        showAsMoon: _v(f.boolean(['showAsMoon', 'moon', 'favorite', 'favourite', 'star', 'مفضل'])),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _contactLog(RawRecord r, _Fields f) {
    final personId = _parentIdIf(r, ImportSection.people) ??
        _refOrCreate(ImportSection.people, f.raw(['person', 'personId', 'who', 'contact', 'name', 'شخص', 'مع']), r);
    if (personId == null) return _skip(r, 'person');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    rows.contactLogs.rows.add(
      ContactLogsCompanion.insert(
        id: Value(r.id!),
        personId: personId,
        at: at,
        channel: _v(f.enumOf(['channel', 'type', 'via', 'how', 'method', 'kind', 'طريقة', 'نوع', 'وسيلة'], ImportAliases.contactChannel)),
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  // ------------------------------------------------------ work, growth --

  void _project(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final done = f.boolean(['done', 'completed', 'finished', 'منجز']);
    rows.projects.rows.add(
      ProjectsCompanion.insert(
        id: Value(r.id!),
        name: name,
        description: _v(f.str([...ImportAliases.notes, 'summary', 'goal', 'ملخص'])),
        deadline: _v(f.date(['deadline', 'due', 'dueDate', 'end', 'endDate', 'الموعد', 'الموعد النهائي'])),
        status: _v(f.enumOf(['status', 'state', 'حالة', 'الحالة'], ImportAliases.projectStatus) ?? (done == true ? ProjectStatus.done : null)),
        planetKey: _v(_planet(f.raw(['planet', 'area', 'domain', 'planetKey', 'مجال'])) ?? r.domain),
        color: _v(_color(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _projectItem(RawRecord r, _Fields f) {
    final projectId = _parentIdIf(r, ImportSection.projects) ??
        _refOrCreate(ImportSection.projects, f.raw(['project', 'projectId', 'مشروع']), r);
    if (projectId == null) return _skip(r, 'project');
    final body = f.str(_namesFor(r.section));
    if (body == null) return _skip(r, 'body');
    rows.projectItems.rows.add(
      ProjectItemsCompanion.insert(
        id: Value(r.id!),
        projectId: projectId,
        body: body,
        done: _v(f.boolean(ImportAliases.done)),
        dueDate: _v(f.date(['dueDate', 'due', 'deadline', 'date', 'الموعد', 'تاريخ'])),
        sortOrder: Value(_order(r.section, projectId)),
      ),
    );
  }

  void _board(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final country = f.str(['country', 'countryCode', 'دولة', 'البلد']);
    _boardColumns[r.id!] = (columns: {...r.columns}, name: name);
    rows.boards.rows.add(
      BoardsCompanion.insert(
        id: Value(r.id!),
        name: name,
        country: _v(country),
        color: _v(_color(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  String _defaultBoard() {
    const id = 'imp.boards.default';
    if (!_boardColumns.containsKey(id)) {
      _usedIds.add(id);
      _boardColumns[id] = (columns: <String, String>{}, name: labels.defaultBoard);
      rows.boards.rows.add(
        BoardsCompanion.insert(id: const Value(id), name: labels.defaultBoard, sortOrder: Value(_order(ImportSection.boards, null))),
      );
    }
    return id;
  }

  /// Boards whose cards use columns beyond to-do / doing / done get the
  /// full column list (known ones localised, others as written).
  void _finishBoards() {
    for (var i = 0; i < rows.boards.rows.length; i++) {
      final row = rows.boards.rows[i] as BoardsCompanion;
      final info = _boardColumns[row.id.value];
      if (info == null) continue;
      final extra = info.columns.keys.where((c) => c != 'todo' && c != 'doing' && c != 'done').toList();
      if (extra.isEmpty) continue;
      final columns = <Object?>[
        for (final id in const ['todo', 'doing', 'done']) {'id': id, 'label': labels.column(id)},
        for (final id in extra) {'id': id, 'label': info.columns[id]},
      ];
      rows.boards.rows[i] = row.copyWith(columns: Value(columns));
    }
  }

  void _card(RawRecord r, _Fields f) {
    final refRaw = f.raw(['board', 'boardId', 'country', 'business', 'لوحة', 'الدولة', 'دولة']);
    final boardId = _parentIdIf(r, ImportSection.boards) ??
        (refRaw == null ? _defaultBoard() : _refOrCreate(ImportSection.boards, refRaw, r, extra: {'country': ImportValues.string(refRaw)}));
    if (boardId == null) return _skip(r, 'board');
    final title = f.str(_namesFor(r.section));
    if (title == null) return _skip(r, 'title');
    var column = r.column;
    if (column == null) {
      final raw = ImportValues.string(f.raw(['column', 'columnId', 'status', 'stage', 'list', 'state', 'lane', 'عمود', 'حالة', 'المرحلة']));
      if (raw != null) {
        column = ImportAliases.knownColumn(raw) ?? ImportText.slug(raw);
        _boardColumns[boardId]?.columns.putIfAbsent(column, () => raw);
      }
    }
    column ??= (f.boolean(['done', 'completed', 'منجز']) ?? false) ? 'done' : 'todo';
    rows.boardCards.rows.add(
      BoardCardsCompanion.insert(
        id: Value(r.id!),
        boardId: boardId,
        columnId: Value(column),
        title: title,
        notes: _v(f.str(ImportAliases.notes)),
        assignee: _v(f.str(['assignee', 'owner', 'assignedTo', 'who', 'person', 'المسؤول', 'مسؤول'])),
        dueDate: _v(f.date(['dueDate', 'due', 'deadline', 'date', 'الموعد', 'تاريخ'])),
        isTop3: _v(f.boolean(['isTop3', 'top3', 'top', 'focus', 'important', 'مهم', 'أولوية قصوى'])),
        window: _v(f.enumOf(['window', 'prayerWindow', 'slot', 'after', 'وقت', 'بعد'], ImportAliases.prayerWindow)),
        sortOrder: Value(_order(r.section, '$boardId|$column')),
      ),
    );
  }

  void _trip(RawRecord r, _Fields f) {
    final destination = f.str(_namesFor(r.section));
    if (destination == null) return _skip(r, 'destination');
    final start = f.date(['startDate', 'start', 'from', 'departure', 'depart', 'leave', 'ذهاب', 'البداية', 'المغادرة']);
    final end = f.date(['endDate', 'end', 'return', 'back', 'until', 'عودة', 'النهاية', 'العودة']);
    var status = f.enumOf(['status', 'state', 'حالة'], ImportAliases.tripStatus);
    if (status == null) {
      final today = DateTime(now.year, now.month, now.day);
      if (end != null && end.isBefore(today)) {
        status = TripStatus.done;
      } else if (start != null && !start.isAfter(today) && (end == null || !end.isBefore(today))) {
        status = TripStatus.active;
      }
    }
    rows.trips.rows.add(
      TripsCompanion.insert(
        id: Value(r.id!),
        destination: destination,
        country: _v(f.str(['country', 'countryCode', 'دولة', 'البلد'])),
        latitude: _v(f.number(['lat', 'latitude', 'خط العرض'])),
        longitude: _v(f.number(['lng', 'lon', 'long', 'longitude', 'خط الطول'])),
        startDate: _v(start),
        endDate: _v(end),
        status: _v(status),
        notes: _v(f.str(ImportAliases.notes)),
        color: _v(_color(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _tripItem(RawRecord r, _Fields f) {
    final tripId = _parentIdIf(r, ImportSection.trips) ?? _refOrCreate(ImportSection.trips, f.raw(['trip', 'tripId', 'رحلة']), r);
    if (tripId == null) return _skip(r, 'trip');
    final body = f.str(_namesFor(r.section));
    if (body == null) return _skip(r, 'body');
    rows.tripItems.rows.add(
      TripItemsCompanion.insert(
        id: Value(r.id!),
        tripId: tripId,
        body: body,
        category: _v(f.str(['category', 'type', 'group', 'فئة', 'نوع']) ?? f.group),
        packed: _v(f.boolean(['packed', 'done', 'checked', 'ready', 'تم', 'جاهز'])),
        sortOrder: Value(_order(r.section, tripId)),
      ),
    );
  }

  void _document(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    rows.travelDocuments.rows.add(
      TravelDocumentsCompanion.insert(
        id: Value(r.id!),
        name: name,
        holder: _v(f.str(['holder', 'owner', 'person', 'for', 'صاحب', 'لـ'])),
        number: _v(f.str(['number', 'no', 'documentNumber', 'passportNumber', 'رقم'])),
        expiry: _v(f.date(['expiry', 'expires', 'expiryDate', 'expiration', 'validUntil', 'until', 'انتهاء', 'تاريخ الانتهاء', 'صالح حتى'])),
        remindDaysBefore: _v(f.integer(['remindDaysBefore', 'remind', 'reminderDays', 'alertDays', 'تذكير قبل'])),
        notes: _v(f.str(ImportAliases.notes)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _goal(RawRecord r, _Fields f) {
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    final initial = f.number(['initial', 'start', 'startValue', 'startingPoint', 'بداية', 'البداية']);
    final current = initial == null ? f.number(['current', 'progress', 'done', 'completed', 'value', 'الحالي', 'المنجز', 'التقدم']) : null;
    var target = f.number(['target', 'goal', 'total', 'targetAmount', 'of', 'هدف', 'الهدف', 'المجموع']);
    if (target == null || target <= 0) {
      target = (current != null && current > 0) ? current : 1;
      _issue(ImportIssueCode.assumedValue, r.section, r.path, 'target=${ImportValues.string(target)}');
    }
    if (current != null) _goalCurrent[r.id!] = (rec: r, current: current);
    _goalRows[r.id!] = LearningGoalsCompanion.insert(
      id: Value(r.id!),
      name: name,
      unit: _v(f.str(['unit', 'units', 'measure', 'وحدة'])),
      target: target,
      initial: _v(initial ?? current),
      deadline: _v(f.date(['deadline', 'due', 'by', 'until', 'endDate', 'الموعد'])),
      color: _v(_color(f)),
      active: _v(_activeFlag(f)),
      sortOrder: Value(_order(r.section, null)),
    );
  }

  /// A goal's "current" total includes its logs: initial = current − Σ logs.
  void _finishGoals() {
    for (final e in _goalRows.entries) {
      var row = e.value;
      final cur = _goalCurrent[e.key];
      final logged = _goalLogged[e.key] ?? 0;
      if (cur != null && logged != 0) {
        final initial = cur.current - logged;
        row = row.copyWith(initial: Value(initial < 0 ? 0 : initial));
      }
      rows.learningGoals.rows.add(row);
    }
  }

  void _goalLog(RawRecord r, _Fields f) {
    final goalId = _parentIdIf(r, ImportSection.learningGoals) ??
        _refOrCreate(ImportSection.learningGoals, f.raw(['goal', 'goalId', 'name', 'هدف']), r);
    if (goalId == null) return _skip(r, 'goal');
    final amount = f.number(['amount', 'value', 'progress', 'count', 'pages', 'minutes', 'done', 'كمية', 'قيمة', 'صفحات', 'دقائق']);
    if (amount == null) return _skip(r, 'amount');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    _goalLogged[goalId] = (_goalLogged[goalId] ?? 0) + amount;
    rows.goalLogs.rows.add(
      GoalLogsCompanion.insert(id: Value(r.id!), goalId: goalId, amount: amount, at: at, note: _v(f.str(ImportAliases.notes))),
    );
  }

  // --------------------------------------------------------------- body --

  static const _durationKeys = ['durationMin', 'duration', 'minutes', 'mins', 'length', 'مدة', 'المدة', 'دقائق'];

  void _exercise(RawRecord r, _Fields f) {
    // A dated record under "workouts" is a log, not a plan.
    if (f.has(const ['date', 'at', 'day', 'when', 'تاريخ']) && ImportValues.date(f.peek(const ['date', 'at', 'day', 'when', 'تاريخ'])) != null) {
      final name = f.str(_namesFor(r.section));
      final exId = name == null ? null : _refOrCreate(ImportSection.exercises, name, r);
      final log = RawRecord(
        section: ImportSection.workoutLogs,
        fields: {...r.fields, 'exercise': ?exId},
        path: r.path,
        day: r.day,
        domain: r.domain,
      )..id = r.id;
      (located.records[ImportSection.workoutLogs] ??= []).add(log);
      f.used.addAll(r.fields.keys);
      _map(log);
      return;
    }
    final name = f.str(_namesFor(r.section));
    if (name == null) return _skip(r, 'name');
    rows.exercises.rows.add(
      ExercisesCompanion.insert(
        id: Value(r.id!),
        name: name,
        weekdays: Value(ImportValues.weekdays(f.raw(['weekdays', 'days', 'schedule', 'on', 'أيام', 'الأيام']))),
        sets: _v(f.integer(['sets', 'مجموعات', 'جولات'])),
        reps: _v(f.integer(['reps', 'repetitions', 'تكرارات', 'عدات'])),
        durationMin: _v(f.integer(_durationKeys)),
        weight: _v(f.number(['weight', 'kg', 'load', 'وزن'])),
        notes: _v(f.str(ImportAliases.notes)),
        active: _v(_activeFlag(f)),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _workoutLog(RawRecord r, _Fields f) {
    final refRaw = f.raw(['exercise', 'exerciseId', 'تمرين']);
    final nameRaw = f.str(ImportAliases.name);
    final exerciseId = _parentIdIf(r, ImportSection.exercises) ??
        _ref(ImportSection.exercises, refRaw) ??
        (nameRaw == null ? null : _refOrCreate(ImportSection.exercises, nameRaw, r));
    final parentName = r.parent?.section == ImportSection.exercises ? _nameOf(r.parent!) : null;
    final name = nameRaw ?? parentName ?? ImportValues.string(refRaw);
    if (name == null) return _skip(r, 'name');
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    rows.workoutLogs.rows.add(
      WorkoutLogsCompanion.insert(
        id: Value(r.id!),
        exerciseId: _v(exerciseId),
        name: name,
        at: at,
        sets: _v(f.integer(['sets', 'مجموعات'])),
        reps: _v(f.integer(['reps', 'repetitions', 'تكرارات'])),
        weight: _v(f.number(['weight', 'kg', 'load', 'وزن'])),
        durationMin: _v(f.integer(_durationKeys)),
        notes: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  void _avoid(RawRecord r, _Fields f) {
    final body = f.str(_namesFor(r.section));
    if (body == null) return _skip(r, 'body');
    rows.avoidItems.rows.add(
      AvoidItemsCompanion.insert(
        id: Value(r.id!),
        body: body,
        reason: _v(f.str(['reason', 'why', 'because', 'note', 'notes', 'سبب', 'السبب', 'لماذا'])),
        sortOrder: Value(_order(r.section, null)),
      ),
    );
  }

  void _fasting(RawRecord r, _Fields f) {
    final start = f.at(aliases: const ['start', 'startedAt', 'from', 'begin', 'date', 'day', 'at', 'بداية', 'من', 'تاريخ']);
    if (start == null) return _skip(r, 'start');
    final end = f.date(['end', 'endedAt', 'to', 'finish', 'until', 'stop', 'نهاية', 'إلى']);
    final valueRaw = f.peek(const ['value']);
    var target = f.number(['targetHours', 'target', 'goal', 'hours', 'plannedHours', 'الهدف', 'ساعات']) ??
        (valueRaw is num ? f.number(const ['value']) : null);
    if (valueRaw is bool) f.raw(const ['value']);
    if (target == null) {
      target = end != null && end.isAfter(start) ? end.difference(start).inMinutes / 60 : 16;
      _issue(ImportIssueCode.assumedFastingTarget, r.section, r.path, ImportValues.string(target));
    }
    rows.fastingSessions.rows.add(
      FastingSessionsCompanion.insert(
        id: Value(r.id!),
        start: start,
        end: _v(end),
        targetHours: target,
        note: _v(f.str(ImportAliases.notes)),
      ),
    );
  }

  void _water(RawRecord r, _Fields f) {
    final at = f.at();
    if (at == null) return _skip(r, 'date');
    int? ml;
    final glasses = f.number(['glasses', 'cups', 'أكواب', 'كاسات', 'كوب']);
    final liters = f.number(['liters', 'litres', 'l', 'لتر', 'لترات']);
    if (glasses != null) {
      ml = (glasses * 250).round();
    } else if (liters != null) {
      ml = (liters * 1000).round();
    } else {
      final raw = f.raw(['ml', 'amount', 'volume', 'value', 'water', 'quantity', 'كمية', 'مل', 'ماء']);
      final words = ImportText.words(ImportValues.string(raw) ?? '').split(' ').toSet();
      final n = ImportValues.number(raw);
      if (n != null) {
        final isMl = words.contains('ml') || words.contains('مل');
        if (!isMl && words.any(const {'l', 'liter', 'liters', 'litre', 'litres', 'لتر', 'لترات', 'لترا'}.contains)) {
          ml = (n * 1000).round();
        } else if (words.any(const {'glass', 'glasses', 'cup', 'cups', 'كوب', 'اكواب', 'كاس', 'كاسات'}.contains)) {
          ml = (n * 250).round();
        } else if (n <= 20 && !isMl) {
          ml = (n * 250).round();
          _issue(ImportIssueCode.assumedGlasses, r.section, r.path, ImportValues.string(raw));
        } else {
          ml = n.round();
        }
      }
    }
    if (ml == null || ml <= 0) return _skip(r, 'ml');
    rows.waterLogs.rows.add(WaterLogsCompanion.insert(id: Value(r.id!), at: at, ml: ml));
  }

  // -------------------------------------------------------------- faith --

  void _prayer(RawRecord r, _Fields f) {
    final prayerKey = f.keyOf(['prayer', 'name', 'salah', 'salat', 'صلاة', 'الصلاة']);
    if (prayerKey == null) {
      // {"date": …, "fajr": true, "dhuhr": "late", …} → one row per prayer.
      final prayerKeys = [
        for (final k in r.fields.keys)
          if (!f.used.contains(k) && ImportValues.enumOf(k, ImportAliases.prayer) != null && ImportText.words(k).split(' ').length <= 2) k,
      ];
      if (prayerKeys.isEmpty) return _skip(r, 'prayer');
      final date = f.raw(['day', 'date', 'at', 'on', 'تاريخ', 'يوم']);
      for (final k in prayerKeys) {
        f.used.add(k);
        final child = RawRecord(
          section: ImportSection.prayerLogs,
          fields: {'prayer': k, 'status': r.fields[k], 'date': ?date},
          path: '${r.path}.$k',
          day: r.day,
          parent: r.parent,
        );
        _idOf(child);
        (located.records[ImportSection.prayerLogs] ??= []).add(child);
        _map(child);
      }
      return;
    }
    final prayer = f.enumOf([prayerKey], ImportAliases.prayer);
    if (prayer == null) return _skip(r, 'prayer');
    final dayRaw = f.raw(['day', 'date', 'at', 'on', 'تاريخ', 'يوم']);
    final day = ImportValues.day(dayRaw) ?? (r.effectiveDay == null ? null : ImportValues.dayKey(r.effectiveDay!));
    if (day == null) return _skip(r, 'day');
    final statusRaw = f.raw(['status', 'done', 'prayed', 'value', 'state', 'حالة']);
    final statusWords = ImportText.words(ImportValues.string(statusRaw) ?? '');
    final b = ImportValues.boolean(statusRaw);
    final status = b != null
        ? (b ? PrayerStatus.prayed : PrayerStatus.missed)
        : ImportValues.enumOf(statusRaw, ImportAliases.prayerStatus) ??
              (statusWords.contains('jama') || statusWords.contains('جماع') || statusWords.contains('mosque') || statusWords.contains('مسجد')
                  ? PrayerStatus.prayed
                  : null);
    if (status == null && statusRaw != null) _issue(ImportIssueCode.unknownValue, r.section, r.path, ImportValues.string(statusRaw));
    final jamaah = f.boolean(['inJamaah', 'jamaah', 'jamaa', 'jamaat', 'congregation', 'group', 'جماعة']) ??
        (statusWords.contains('jama') || statusWords.contains('جماع') ? true : null);
    final mosque = f.boolean(['atMosque', 'mosque', 'masjid', 'مسجد']) ??
        (statusWords.contains('mosque') || statusWords.contains('مسجد') ? true : null);
    if (!_prayerDays.add('$day|${prayer.name}')) {
      _report(r.section).skipped++;
      return;
    }
    rows.prayerLogs.rows.add(
      PrayerLogsCompanion.insert(
        id: Value(r.id!),
        day: day,
        prayer: prayer,
        status: _v(status),
        inJamaah: _v(jamaah),
        atMosque: _v(mosque),
      ),
    );
  }

  void _task(RawRecord r, _Fields f) {
    final title = f.str(_namesFor(r.section));
    if (title == null) return _skip(r, 'title');
    final window = r.window ??
        f.enumOf(['window', 'prayerWindow', 'slot', 'after', 'period', 'وقت', 'بعد', 'الفترة'], ImportAliases.prayerWindow) ??
        ImportValues.enumOf(f.group, ImportAliases.prayerWindow);
    final prioRaw = f.raw(['priority', 'prio', 'importance', 'أولوية']);
    final prio = ImportValues.integer(prioRaw) ??
        switch (ImportText.words(ImportValues.string(prioRaw) ?? '')) {
          'high' || 'عاليه' || 'عالي' || 'urgent' => 2,
          'medium' || 'normal' || 'متوسطه' || 'متوسط' => 1,
          'low' || 'منخفضه' || 'منخفض' => 0,
          _ => null,
        };
    final date = f.date(['date', 'day', 'dueDate', 'due', 'on', 'تاريخ', 'يوم']) ?? r.effectiveDay;
    rows.tasks.rows.add(
      TasksCompanion.insert(
        id: Value(r.id!),
        title: title,
        notes: _v(f.str(ImportAliases.notes)),
        window: _v(window),
        date: _v(date),
        done: _v(f.boolean(['done', 'completed', 'checked', 'finished', 'isDone', 'تم', 'منجز'])),
        doneAt: _v(f.date(['doneAt', 'completedAt', 'finishedAt'])),
        planetKey: _v(_planet(f.raw(['planet', 'area', 'domain', 'planetKey', 'مجال'])) ?? r.domain),
        priority: _v(prio),
        isTop3: _v(f.boolean(['isTop3', 'top3', 'top', 'focus', 'أهم ثلاث', 'مهم'])),
        projectId: _v(_ref(ImportSection.projects, f.raw(['project', 'projectId', 'مشروع']))),
        cardId: _v(_ref(ImportSection.boardCards, f.raw(['card', 'cardId', 'بطاقة']))),
        sortOrder: Value(_order(r.section, window?.name)),
      ),
    );
  }

  // ------------------------------------------------------ custom modules --

  static const _ratingHints = ['rating', 'rate', 'stars', 'score', 'تقييم', 'نجوم', 'درجة'];
  static final _clockOnly = RegExp(r'^\s*\d{1,2}:\d{2}\s*$');

  /// Turns an unknown list of objects into a module with inferred fields.
  void _module(UnknownList u) {
    final idSeed = 'module|${_pattern(u.path)}';
    final moduleId = _claim('imp.customModules.${Sha256.ofString(idSeed).substring(0, 20)}');
    final keys = <String>[];
    for (final item in u.items) {
      for (final k in item.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    final idKeys = {for (final a in ImportAliases.id) ImportText.key(a)};
    String? dateKey;
    String? doneKey;
    final dateAliasKeys = {for (final a in ImportAliases.date) ImportText.key(a)};
    for (final k in keys) {
      final values = u.items.map((i) => i[k]).where((v) => v != null).toList();
      if (values.isEmpty) continue;
      if (dateKey == null && dateAliasKeys.contains(ImportText.key(k)) && values.every((v) => ImportValues.date(v) != null)) {
        dateKey = k;
      }
      if (doneKey == null &&
          ['done', 'completed', 'checked', 'finished', 'read', 'تم', 'منجز', 'مقروء'].any((a) => ImportText.key(a) == ImportText.key(k)) &&
          values.every((v) => v is bool)) {
        doneKey = k;
      }
    }
    final fields = <Map<String, Object?>>[];
    final fieldIdByKey = <String, String>{};
    final fieldTypes = <String, String>{};
    var n = 0;
    for (final k in keys) {
      if (k == dateKey || k == doneKey || idKeys.contains(ImportText.key(k))) continue;
      final values = u.items.map((i) => i[k]).where((v) => v != null).toList();
      final type = _inferType(k, values);
      final id = 'f${++n}';
      fieldIdByKey[k] = id;
      final label = ImportText.humanize(k);
      fieldTypes[label] = type.name;
      fields.add({
        'id': id,
        'label': label,
        'type': type.name,
        'sourceKey': k,
        if (type == FieldType.multiSelect)
          'options': {for (final v in values) ...ImportValues.strings(v)}.toList(),
        if (type == FieldType.rating) 'max': values.map((v) => ImportValues.number(v) ?? 0).fold<double>(0, (a, b) => b > a ? b : a) > 5 ? 10 : 5,
      });
    }
    final planet = u.domain ?? 'growth';
    final color = (PlanetPalettes.byKey[planet] ?? PlanetPalettes.growth).surface.toARGB32();
    final firstNumber = fields.where((x) => x['type'] == FieldType.number.name || x['type'] == FieldType.rating.name).firstOrNull;
    final name = ImportText.humanize(u.key);
    rows.customModules.rows.add(
      CustomModulesCompanion.insert(
        id: Value(moduleId),
        name: name,
        kind: Value(dateKey != null ? CustomModuleKind.tracker : CustomModuleKind.list),
        color: color,
        planetKey: Value(planet),
        fields: Value(fields),
        chart: dateKey != null && firstNumber != null ? Value({'type': 'line', 'fieldId': firstNumber['id'], 'range': 30}) : const Value.absent(),
        sortOrder: Value(_order(ImportSection.customModules, null)),
      ),
    );
    for (var i = 0; i < u.items.length; i++) {
      final item = u.items[i];
      final values = <String, Object?>{};
      for (final e in fieldIdByKey.entries) {
        final v = item[e.key];
        if (v == null) continue;
        final type = fields.firstWhere((x) => x['id'] == e.value)['type'];
        values[e.value] = _entryValue(type as String, v);
      }
      final sid = u.sourceIds[i];
      final entryId = sid != null
          ? _claim('$moduleId/${_sanitize(sid)}')
          : _claim('$moduleId/${Sha256.ofString(Sha256.canonicalJson(item)).substring(0, 16)}');
      final at = dateKey == null ? u.days[i] : ImportValues.date(item[dateKey]);
      rows.customEntries.rows.add(
        CustomEntriesCompanion.insert(
          id: Value(entryId),
          moduleId: moduleId,
          at: _v(at),
          entryValues: Value(values),
          done: _v(doneKey == null ? null : item[doneKey] as bool?),
          sortOrder: Value(i),
        ),
      );
    }
    modules.add(
      ImportedModuleSummary(id: moduleId, name: name, sourcePath: u.path, entries: u.items.length, fieldTypes: fieldTypes),
    );
  }

  static FieldType _inferType(String key, List<Object?> values) {
    if (values.isEmpty) return FieldType.text;
    if (values.every((v) => v is bool || (v is String && ImportValues.boolean(v) != null && !RegExp(r'^\d+$').hasMatch(v)))) {
      return FieldType.checkbox;
    }
    if (values.every((v) => v is num)) {
      final ints = values.every((v) => v is int || (v as num) == v.roundToDouble());
      final rating = _ratingHints.any((h) => ImportText.key(key).contains(ImportText.key(h)));
      final inRange = values.every((v) => (v as num) >= 0 && v <= 10);
      return ints && rating && inRange ? FieldType.rating : FieldType.number;
    }
    if (values.every((v) => v is String && _clockOnly.hasMatch(MoneyText.foldDigits(v)))) return FieldType.time;
    if (values.every((v) => v is String && ImportValues.date(v) != null && RegExp(r'\d{4}|[/.\-]').hasMatch(v))) {
      return FieldType.date;
    }
    if (values.every((v) => v is String && ImportValues.number(v) != null && RegExp(r'^[\s\d.,٠-٩٫٬+-]+$').hasMatch(v))) {
      return FieldType.number;
    }
    if (values.every((v) => v is List && v.every((e) => e is String || e is num))) return FieldType.multiSelect;
    return FieldType.text;
  }

  static Object? _entryValue(String type, Object? v) {
    if (type == FieldType.checkbox.name) return ImportValues.boolean(v);
    if (type == FieldType.number.name) return ImportValues.number(v);
    if (type == FieldType.rating.name) return ImportValues.integer(v);
    if (type == FieldType.date.name) {
      final d = ImportValues.date(v);
      return d == null ? ImportValues.string(v) : d.toIso8601String();
    }
    if (type == FieldType.time.name) return ImportValues.time(v);
    if (type == FieldType.multiSelect.name) return ImportValues.strings(v);
    if (v is Map || v is List) return Sha256.canonicalJson(v);
    return ImportValues.string(v) ?? '$v';
  }

  // ---------------------------------------------------------- currencies --

  /// Currencies the rows use; `commit` inserts the missing ones.
  void _currencies() {
    final base = baseCurrency;
    final fileRates = located.settings['rates'];
    if (fileRates is Map) {
      for (final e in fileRates.entries) {
        currencies.putIfAbsent('${e.key}', () => (e.value as num).toDouble());
      }
    }
    currencies.putIfAbsent(base, () => 1.0);
    for (final e in currencies.entries) {
      final code = e.key;
      rows.currencies.rows.add(
        CurrenciesCompanion.insert(
          code: code,
          nameAr: code,
          nameEn: code,
          symbol: CurrencyCatalog.symbolFor(code, arabic: true),
          decimals: Value(CurrencyCatalog.decimalsFor(code)),
          rateToBase: Value(code == base ? 1.0 : (e.value ?? 1.0)),
        ),
      );
    }
  }
}
