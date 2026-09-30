import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../domain/field_migration.dart';
import '../domain/field_values.dart';
import '../domain/module_builder_rules.dart';
import '../domain/module_export.dart';
import '../domain/module_reminders.dart';
import '../domain/module_schema.dart';

/// Restores the state before a write (for the undo toast).
typedef CustomUndo = Future<void> Function();

/// Logs an activity for a planet (and pulses it): the orbit's pulse hub in
/// the app, a plain `activity_log` insert by default.
typedef CustomActivityRecorder =
    Future<void> Function({
      required String planetKey,
      required String kind,
      required String refTable,
      required String refId,
      required DateTime at,
      Map<String, Object?> payload,
    });

/// Thrown by [CustomModulesService.updateModule] when the schema change
/// would lose data (see [FieldMigrationPlan.blocking]).
class MigrationBlockedException implements Exception {
  const MigrationBlockedException(this.plan);
  final FieldMigrationPlan plan;

  @override
  String toString() => 'MigrationBlockedException(${plan.blocking})';
}

extension CustomModuleRowView on CustomModuleRow {
  ModuleDefinition toDefinition() => ModuleDefinition(
    id: id,
    name: name,
    kind: kind,
    iconKey: icon,
    colorArgb: color,
    planetKey: planetKey,
    window: window,
    fields: ModuleDefinition.parseFields(fields),
    chart: ModuleChartConfig.fromJson(chart),
    archived: archived,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );
}

extension CustomEntryRowView on CustomEntryRow {
  ModuleEntry toEntry() =>
      ModuleEntry(id: id, moduleId: moduleId, at: at, values: entryValues, done: done, sortOrder: sortOrder);
}

/// Everything the Custom Modules Builder writes: modules (with safe schema
/// migration), entries (logging the module's planet activity), and the
/// module reminders in the shared `reminders` table.
///
/// Every write returns a [CustomUndo] that restores the exact prior state.
class CustomModulesService {
  CustomModulesService(this.repos, {DateTime Function()? clock, this.recorder}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  /// Logs activity (the orbit pulse hub in the app); null = a plain
  /// `activity_log` insert.
  final CustomActivityRecorder? recorder;

  /// `reminders.owner_table` of module reminders.
  static const String ownerTable = 'custom_modules';

  /// `activity_log.ref_table` of entries.
  static const String entriesTable = 'custom_entries';

  /// Activity kinds: a tracker entry logged / a list item checked off.
  static const String kindEntry = 'custom.entry';
  static const String kindDone = 'custom.done';

  MadarDatabase get _db => repos.db;

  // -------------------------------------------------------------- modules --

  /// Every module in the user's order (archived ones included).
  Stream<List<ModuleDefinition>> watchModules() =>
      repos.customModules.watchAll().map((rows) => [for (final r in rows) r.toDefinition()]);

  Future<List<ModuleDefinition>> modules() async => [for (final r in await repos.customModules.getAll()) r.toDefinition()];

  Stream<ModuleDefinition?> watchModule(String id) => repos.customModules.watchById(id).map((r) => r?.toDefinition());

  Future<ModuleDefinition?> module(String id) async => (await repos.customModules.byId(id))?.toDefinition();

  /// Saves a new module built from [draft] (its id is ignored).
  Future<ModuleDefinition> createModule(ModuleDefinition draft) async {
    final problems = ModuleBuilderRules.check(draft);
    if (problems.isNotEmpty) throw ArgumentError.value(problems, 'draft', 'Module is not valid');
    final chart = ModuleBuilderRules.reconcileChart(draft);
    final row = await repos.customModules.insert(
      CustomModulesCompanion.insert(
        name: draft.name.trim(),
        kind: Value(draft.kind),
        icon: Value(draft.iconKey),
        color: draft.colorArgb,
        planetKey: Value(draft.planetKey),
        window: Value(draft.window),
        fields: Value(ModuleDefinition.encodeFields(draft.fields)),
        chart: Value(chart?.toJson()),
      ),
    );
    return row.toDefinition();
  }

  /// What saving [draft] over the stored module would do to its entries.
  Future<FieldMigrationPlan> planUpdate(ModuleDefinition draft) async {
    final stored = await module(draft.id);
    if (stored == null) throw StateError('Module ${draft.id} not found');
    final entries = await repos.customEntries.getAll(where: (t) => t.moduleId.equals(draft.id));
    return FieldMigration.plan(
      before: stored.fields,
      after: draft.fields,
      entries: [for (final e in entries) (id: e.id, values: e.entryValues)],
    );
  }

  /// Saves [draft] over the stored module, migrating its entries in one
  /// transaction. Throws [MigrationBlockedException] (nothing written) when
  /// a change would lose data. Returns the applied plan.
  Future<(FieldMigrationPlan, CustomUndo)> updateModule(ModuleDefinition draft) async {
    final problems = ModuleBuilderRules.check(draft);
    if (problems.isNotEmpty) throw ArgumentError.value(problems, 'draft', 'Module is not valid');
    final plan = await planUpdate(draft);
    if (!plan.canApply) throw MigrationBlockedException(plan);
    final before = (await repos.customModules.byId(draft.id))!;
    final touched = [
      for (final id in plan.entryUpdates.keys)
        if (await repos.customEntries.byId(id) case final CustomEntryRow row) row,
    ];
    final migrated = draft.copyWith(fields: plan.fields);
    final chart = ModuleBuilderRules.reconcileChart(migrated);
    await _db.transaction(() async {
      await repos.customModules.update(
        CustomModulesCompanion(
          id: Value(draft.id),
          name: Value(draft.name.trim()),
          kind: Value(draft.kind),
          icon: Value(draft.iconKey),
          color: Value(draft.colorArgb),
          planetKey: Value(draft.planetKey),
          window: Value(draft.window),
          fields: Value(ModuleDefinition.encodeFields(plan.fields)),
          chart: Value(chart?.toJson()),
        ),
      );
      for (final e in plan.entryUpdates.entries) {
        await repos.customEntries.setColumns(e.key, {'entryValues': e.value});
      }
    });
    return (
      plan,
      () async {
        await _db.transaction(() async {
          await repos.customModules.update(before);
          for (final row in touched) {
            await repos.customEntries.update(row);
          }
        });
      },
    );
  }

  /// Stores a chart choice (type / field / range) made on the module page.
  Future<void> setChart(String id, ModuleChartConfig chart) =>
      repos.customModules.setColumns(id, {'chart': chart.toJson()});

  Future<CustomUndo> setArchived(String id, bool archived) async {
    final before = await repos.customModules.byId(id);
    await repos.customModules.setColumns(id, {'archived': archived});
    return () async {
      if (before != null) await repos.customModules.setColumns(id, {'archived': before.archived});
    };
  }

  /// Deletes a module with its entries and reminders (undo restores all).
  Future<CustomUndo> deleteModule(String id) async {
    late final CustomModuleRow? module;
    late final List<CustomEntryRow> entries;
    late final List<ReminderRow> reminders;
    await _db.transaction(() async {
      entries = await repos.customEntries.deleteWhere((t) => t.moduleId.equals(id));
      reminders = await repos.reminders.deleteWhere((t) => t.ownerTable.equals(ownerTable) & t.ownerId.equals(id));
      module = await repos.customModules.delete(id);
    });
    return () async {
      await _db.transaction(() async {
        if (module != null) await repos.customModules.restore(module!);
        await repos.customEntries.restoreAll(entries);
        await repos.reminders.restoreAll(reminders);
      });
    };
  }

  /// A copy of the module's structure (no entries, no reminders), right
  /// after the original.
  Future<(ModuleDefinition, CustomUndo)> duplicateModule(String id, {required String name}) async {
    final copy = await repos.customModules.duplicate(id, overrides: {'name': name});
    return (
      copy.toDefinition(),
      () async {
        await repos.customModules.delete(copy.id);
      },
    );
  }

  Future<void> reorderModules(List<String> ids) => repos.customModules.reorder(ids);

  // -------------------------------------------------------------- entries --

  /// A module's entries (list order; trackers sort by time in the UI).
  Stream<List<ModuleEntry>> watchEntries(String moduleId) => repos.customEntries
      .watchAll(where: (t) => t.moduleId.equals(moduleId))
      .map((rows) => [for (final r in rows) r.toEntry()]);

  Future<List<ModuleEntry>> entries(String moduleId) async => [
    for (final r in await repos.customEntries.getAll(where: (t) => t.moduleId.equals(moduleId))) r.toEntry(),
  ];

  /// Every entry of every module, grouped by module id.
  Stream<Map<String, List<ModuleEntry>>> watchAllEntries() => repos.customEntries.watchAll().map((rows) {
    final out = <String, List<ModuleEntry>>{};
    for (final r in rows) {
      (out[r.moduleId] ??= []).add(r.toEntry());
    }
    return out;
  });

  /// Adds an entry with already-validated [values] (see `EntryValidator`).
  /// A tracker entry (and a list item added as done) logs an activity for
  /// the module's planet so the planet reacts.
  Future<(ModuleEntry, CustomUndo)> addEntry(
    String moduleId,
    Map<String, Object?> values, {
    DateTime? at,
    bool done = false,
  }) async {
    final m = await module(moduleId);
    if (m == null) throw StateError('Module $moduleId not found');
    final when = at ?? _clock();
    final row = await repos.customEntries.insert(
      CustomEntriesCompanion.insert(
        moduleId: moduleId,
        at: Value(when),
        entryValues: Value(values),
        done: Value(done),
      ),
    );
    if (m.isTracker) {
      await _log(m, kindEntry, row.id, when);
    } else if (done) {
      await _log(m, kindDone, row.id, _clock());
    }
    return (
      row.toEntry(),
      () async {
        await repos.customEntries.delete(row.id);
        await repos.activity.removeFor(refTable: entriesTable, refId: row.id);
      },
    );
  }

  /// Rewrites an entry's values / time (the entry form's "Save").
  Future<CustomUndo> updateEntry(String entryId, Map<String, Object?> values, {DateTime? at}) async {
    final before = await repos.customEntries.byId(entryId);
    if (before == null) return () async {};
    await repos.customEntries.setColumns(entryId, {'entryValues': values, 'at': ?at});
    return () => repos.customEntries.update(before);
  }

  Future<CustomUndo> deleteEntry(String entryId) async {
    final row = await repos.customEntries.delete(entryId);
    if (row == null) return () async {};
    final activity = await repos.activity.removeFor(refTable: entriesTable, refId: entryId);
    return () async {
      await repos.customEntries.restore(row);
      await repos.activityLog.restoreAll(activity);
    };
  }

  /// A copy of an entry (lists: right after it; trackers: stamped now).
  Future<(ModuleEntry, CustomUndo)> duplicateEntry(String entryId) async {
    final src = await repos.customEntries.byId(entryId);
    if (src == null) throw StateError('Entry $entryId not found');
    final m = await module(src.moduleId);
    if (m != null && m.isTracker) return addEntry(src.moduleId, src.entryValues);
    final copy = await repos.customEntries.duplicate(entryId, overrides: {'done': false});
    return (
      copy.toEntry(),
      () async {
        await repos.customEntries.delete(copy.id);
      },
    );
  }

  /// Checks a list item off (logging the planet activity) or on again.
  Future<CustomUndo> setDone(String entryId, bool done) async {
    final before = await repos.customEntries.byId(entryId);
    if (before == null || before.done == done) return () async {};
    await repos.customEntries.setColumns(entryId, {'done': done});
    final m = await module(before.moduleId);
    List<ActivityRow> removed = const [];
    if (done) {
      if (m != null) await _log(m, kindDone, entryId, _clock());
    } else {
      removed = await repos.activity.removeFor(refTable: entriesTable, refId: entryId, kind: kindDone);
    }
    return () async {
      await repos.customEntries.setColumns(entryId, {'done': before.done});
      if (done) {
        await repos.activity.removeFor(refTable: entriesTable, refId: entryId, kind: kindDone);
      } else {
        await repos.activityLog.restoreAll(removed);
      }
    };
  }

  Future<void> reorderEntries(List<String> ids) => repos.customEntries.reorder(ids);

  /// Removes every checked-off item of a list.
  Future<CustomUndo> clearDone(String moduleId) async {
    final rows = await repos.customEntries.deleteWhere((t) => t.moduleId.equals(moduleId) & t.done.equals(true));
    return () => repos.customEntries.restoreAll(rows);
  }

  /// One-tap logging of a tracker (see [QuickEntry]):
  /// * check-in: ticks today – or, when today is already ticked, removes
  ///   today's check-in (a toggle);
  /// * rating: logs [rating] stars;
  /// * counter: logs one entry.
  /// Returns null when the module cannot be logged with one tap.
  Future<({bool added, CustomUndo undo})?> quickLog(String moduleId, {int? rating}) async {
    final m = await module(moduleId);
    final quick = m?.quickEntry;
    if (m == null || quick == null) return null;
    switch (quick) {
      case QuickCheck(:final fieldId):
        final now = _clock();
        final today = await _entriesOn(moduleId, now);
        final ticked = today.where((e) => FieldValues.checkbox(e.entryValues[fieldId]) == true).toList();
        if (ticked.isNotEmpty) {
          final undos = [for (final e in ticked) await deleteEntry(e.id)];
          return (
            added: false,
            undo: () async {
              for (final u in undos.reversed) {
                await u();
              }
            },
          );
        }
        final (_, undo) = await addEntry(moduleId, {fieldId: true});
        return (added: true, undo: undo);
      case QuickRate(:final fieldId, :final max):
        final r = rating ?? max;
        if (r < 1 || r > max) return null;
        final (_, undo) = await addEntry(moduleId, {fieldId: r});
        return (added: true, undo: undo);
      case QuickCount():
        final (_, undo) = await addEntry(moduleId, const {});
        return (added: true, undo: undo);
    }
  }

  Future<List<CustomEntryRow>> _entriesOn(String moduleId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return repos.customEntries.getAll(
      where: (t) =>
          t.moduleId.equals(moduleId) & t.at.isBiggerOrEqualValue(start) & t.at.isSmallerThanValue(end),
    );
  }

  Future<void> _log(ModuleDefinition m, String kind, String entryId, DateTime at) async {
    final planet = m.planetKey;
    if (planet == null || planet.isEmpty) return;
    final payload = <String, Object?>{'moduleId': m.id};
    final recorder = this.recorder;
    if (recorder != null) {
      await recorder(planetKey: planet, kind: kind, refTable: entriesTable, refId: entryId, at: at, payload: payload);
    } else {
      await repos.activity.log(
        planetKey: planet,
        kind: kind,
        refTable: entriesTable,
        refId: entryId,
        at: at,
        payload: payload,
      );
    }
  }

  // ------------------------------------------------------------ reminders --

  Stream<List<ReminderRow>> watchReminders(String moduleId) => repos.reminders.watchAll(
    where: (t) => t.ownerTable.equals(ownerTable) & t.ownerId.equals(moduleId),
  );

  Stream<List<ReminderRow>> watchAllReminders() =>
      repos.reminders.watchAll(where: (t) => t.ownerTable.equals(ownerTable));

  Future<List<ReminderRow>> allReminders() =>
      repos.reminders.getAll(where: (t) => t.ownerTable.equals(ownerTable));

  Future<(ReminderRow, CustomUndo)> addReminder(String moduleId, Map<String, Object?> rule, {String? title}) async {
    final row = await repos.reminders.insert(
      RemindersCompanion.insert(ownerTable: ownerTable, ownerId: moduleId, title: Value(title), rule: rule),
    );
    return (
      row,
      () async {
        await repos.reminders.delete(row.id);
      },
    );
  }

  Future<CustomUndo> updateReminder(String id, Map<String, Object?> rule) async {
    final before = await repos.reminders.byId(id);
    await repos.reminders.setColumns(id, {'rule': rule});
    return () async {
      if (before != null) await repos.reminders.update(before);
    };
  }

  Future<CustomUndo> setReminderEnabled(String id, bool enabled) async {
    final before = await repos.reminders.byId(id);
    await repos.reminders.setColumns(id, {'enabled': enabled});
    return () async {
      if (before != null) await repos.reminders.setColumns(id, {'enabled': before.enabled});
    };
  }

  Future<CustomUndo> deleteReminder(String id) async {
    final row = await repos.reminders.delete(id);
    return () async {
      if (row != null) await repos.reminders.restore(row);
    };
  }

  /// The planner's input: enabled reminders of live (not archived) modules.
  Future<List<ModuleReminderInput>> reminderInputs() async {
    final mods = {for (final m in await modules()) m.id: m};
    return [
      for (final r in await allReminders())
        if (mods[r.ownerId] case final ModuleDefinition m when !m.archived)
          ModuleReminderInput(
            reminderId: r.id,
            moduleId: m.id,
            moduleName: m.name,
            kind: m.kind,
            rule: r.rule,
            enabled: r.enabled,
            note: r.title,
          ),
    ];
  }

  // ------------------------------------------------ search / export / AI --

  /// Searchable records of every live module and its entries.
  Future<List<ModuleSearchRecord>> searchRecords({
    ModuleValueFormatter fmt = const PlainValueFormatter(),
    ModuleExportTexts texts = const EnglishModuleExportTexts(),
  }) async {
    final all = await repos.customEntries.getAll();
    final byModule = <String, List<ModuleEntry>>{};
    for (final r in all) {
      (byModule[r.moduleId] ??= []).add(r.toEntry());
    }
    return [
      for (final m in await modules())
        if (!m.archived) ...ModuleExport.searchRecords(m, byModule[m.id] ?? const [], fmt: fmt, texts: texts),
    ];
  }

  /// One module as CSV text (null when it does not exist).
  Future<String?> csv(String moduleId, {ModuleExportTexts texts = const EnglishModuleExportTexts()}) async {
    final m = await module(moduleId);
    if (m == null) return null;
    return ModuleExport.csv(ModuleExport.csvRows(m, await entries(moduleId), texts: texts));
  }

  /// One module as a Markdown summary (null when it does not exist).
  Future<String?> markdown(
    String moduleId, {
    ModuleExportTexts texts = const EnglishModuleExportTexts(),
    ModuleValueFormatter fmt = const PlainValueFormatter(),
  }) async {
    final m = await module(moduleId);
    if (m == null) return null;
    return ModuleExport.markdown(m, await entries(moduleId), today: _clock(), texts: texts, fmt: fmt);
  }

  /// Every module the kind [kind] (all when null), for pickers.
  Future<List<ModuleDefinition>> modulesOf({CustomModuleKind? kind}) async => [
    for (final m in await modules())
      if (kind == null || m.kind == kind) m,
  ];
}
