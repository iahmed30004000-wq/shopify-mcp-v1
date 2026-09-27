import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/db/seed/defaults.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/planet_archetypes.dart';
import '../domain/score_sources.dart';

/// Restores the state before a customisation (wrap it in an undo toast).
typedef OrbitUndo = Future<void> Function();

/// Why a customisation was refused.
class PlanetCustomizationException implements Exception {
  const PlanetCustomizationException(this.message);
  final String message;
  @override
  String toString() => 'PlanetCustomizationException: $message';
}

/// Everything the long-press "customise planet" sheet can do – rename,
/// recolour, restyle, reorder, hide/show, weight and per-source weights, add
/// and delete custom planets, reset a built-in – each returning an
/// [OrbitUndo] that restores the exact previous state.
///
/// Planets are addressed by their stable `key`.
class PlanetCustomizationService {
  PlanetCustomizationService(this.repos);

  final Repositories repos;

  MadarDatabase get _db => repos.db;
  EntityRepository<$PlanetsTable, PlanetRow> get _planets => repos.planets;

  /// Heaviest weight a planet can have in the overall balance.
  static const maxWeight = 3.0;

  /// Sources a new custom planet starts with (its own tasks and habits; its
  /// custom modules always count).
  static const defaultCustomSources = <String, double>{ScoreSources.tasks: 1.0, ScoreSources.habits: 0.5};

  Future<PlanetRow> _row(String key) async {
    final rows = await _planets.getAll(where: (p) => p.key.equals(key));
    if (rows.isEmpty) throw PlanetCustomizationException('No planet "$key"');
    return rows.single;
  }

  /// Undo that writes [before] back (every column but sort order).
  OrbitUndo _restore(PlanetRow before) => () => _planets.update(before);

  /// Renames the planet in [languageCode]. When both names were the same
  /// (a custom planet named once), both follow.
  Future<OrbitUndo> rename(String key, String name, {required String languageCode}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const PlanetCustomizationException('A planet needs a name');
    final row = await _row(key);
    final english = languageCode == 'en';
    final current = english ? row.nameEn : row.nameAr;
    final other = english ? row.nameAr : row.nameEn;
    await _planets.setColumns(row.id, {
      english ? 'nameEn' : 'nameAr': trimmed,
      if (other == current) (english ? 'nameAr' : 'nameEn'): trimmed,
    });
    return _restore(row);
  }

  /// Sets the planet's colour (the palette is derived from it; a built-in
  /// planet back on its signature colour gets its curated palette again).
  Future<OrbitUndo> recolor(String key, Color color) async {
    final row = await _row(key);
    await _planets.setColumn(row.id, 'color', color.toARGB32());
    return _restore(row);
  }

  /// Dresses the planet in another world style.
  Future<OrbitUndo> setArchetype(String key, PlanetArchetype archetype) async {
    final row = await _row(key);
    await _planets.setColumn(row.id, 'archetype', archetype);
    return _restore(row);
  }

  Future<OrbitUndo> setIcon(String key, String icon) async {
    final row = await _row(key);
    await _planets.setColumn(row.id, 'icon', icon);
    return _restore(row);
  }

  /// Hides the planet from the orbit (its data stays) or shows it again.
  Future<OrbitUndo> setHidden(String key, bool hidden) async {
    final row = await _row(key);
    await _planets.setColumn(row.id, 'hidden', hidden);
    return _restore(row);
  }

  /// Importance in the overall balance, 0 (not counted) … [maxWeight].
  Future<OrbitUndo> setWeight(String key, double weight) async {
    final row = await _row(key);
    final w = weight.isFinite ? weight.clamp(0.0, maxWeight) : 1.0;
    await _planets.setColumn(row.id, 'weight', w);
    return _restore(row);
  }

  /// Sets one source's weight (0 switches the source off, including its
  /// neglect reasons). Aliases (`medications`) are stored under their
  /// canonical key.
  Future<OrbitUndo> setSourceWeight(String key, String source, double weight) async {
    final row = await _row(key);
    final canonical = ScoreSources.canonical(source);
    if (!ScoreSources.isKnown(canonical)) throw PlanetCustomizationException('Unknown source "$source"');
    final sources = <String, Object?>{};
    for (final e in row.sources.entries) {
      final k = ScoreSources.canonical(e.key);
      if (k == canonical) continue;
      sources[k] = e.value;
    }
    sources[canonical] = weight.isFinite ? weight.clamp(0.0, 10.0) : 0.0;
    await _planets.setColumn(row.id, 'sources', sources);
    return _restore(row);
  }

  /// Replaces every source weight at once.
  Future<OrbitUndo> setSources(String key, Map<String, double> sources) async {
    final row = await _row(key);
    for (final s in sources.keys) {
      if (!ScoreSources.isKnown(s)) throw PlanetCustomizationException('Unknown source "$s"');
    }
    await _planets.setColumn(row.id, 'sources', ScoreSources.canonicalWeights(sources));
    return _restore(row);
  }

  /// Persists a new orbit order (keys of the visible planets, or all).
  Future<OrbitUndo> reorder(List<String> keysInOrder) async {
    final before = await _planets.getAll();
    final idByKey = {for (final p in before) p.key: p.id};
    await _planets.reorder([
      for (final k in keysInOrder)
        if (idByKey[k] case final String id) id,
    ]);
    final previous = [for (final p in before) p.id];
    return () => _planets.reorder(previous);
  }

  /// Adds a user planet at the end of the orbit. Its name is used for both
  /// languages until renamed in one of them. Returns the new row.
  Future<(PlanetRow, OrbitUndo)> addPlanet({
    required String name,
    required PlanetArchetype archetype,
    Color? color,
    String icon = 'star',
    double weight = 1,
    Map<String, double>? sources,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const PlanetCustomizationException('A planet needs a name');
    final existing = {for (final p in await _planets.getAll()) p.key};
    var key = 'custom_${newId().replaceAll('-', '').substring(0, 10)}';
    while (existing.contains(key)) {
      key = 'custom_${newId().replaceAll('-', '').substring(0, 10)}';
    }
    final row = await _planets.insert(PlanetsCompanion.insert(
      key: key,
      nameAr: trimmed,
      nameEn: trimmed,
      color: (color ?? OrbitArchetypes.defaultColor(archetype)).toARGB32(),
      archetype: archetype,
      icon: Value(icon),
      weight: Value(weight.isFinite ? weight.clamp(0.0, maxWeight) : 1.0),
      sources: Value(ScoreSources.canonicalWeights(sources ?? defaultCustomSources)),
    ));
    return (row, () async => _planets.delete(row.id).then((_) {}));
  }

  /// Deletes a user planet. Records attached to it (tasks, habits, projects,
  /// custom modules) are kept and detached; undo re-attaches them. Built-in
  /// planets can only be hidden.
  Future<OrbitUndo> deletePlanet(String key) async {
    final row = await _row(key);
    if (!isCustomKey(row.key)) throw PlanetCustomizationException('Built-in planet "$key" can only be hidden');
    late final List<String> tasks, habits, projects, modules;
    await _db.transaction(() async {
      tasks = await _detach(_db.tasks, _db.tasks.id, _db.tasks.planetKey, key);
      habits = await _detach(_db.habits, _db.habits.id, _db.habits.planetKey, key);
      projects = await _detach(_db.projects, _db.projects.id, _db.projects.planetKey, key);
      modules = await _detach(_db.customModules, _db.customModules.id, _db.customModules.planetKey, key);
      await _planets.delete(row.id);
    });
    return () => _db.transaction(() async {
      await _planets.restore(row);
      await _attach(_db.tasks, _db.tasks.id, _db.tasks.planetKey, key, tasks);
      await _attach(_db.habits, _db.habits.id, _db.habits.planetKey, key, habits);
      await _attach(_db.projects, _db.projects.id, _db.projects.planetKey, key, projects);
      await _attach(_db.customModules, _db.customModules.id, _db.customModules.planetKey, key, modules);
    });
  }

  /// Puts a built-in planet back to its seeded name, colour, style, icon,
  /// sources and weight (and shows it).
  Future<OrbitUndo> resetToDefaults(String key) async {
    final row = await _row(key);
    final def = MadarDefaults.planets.where((p) => p.key == key).firstOrNull;
    if (def == null) throw PlanetCustomizationException('Planet "$key" has no defaults');
    await _planets.setColumns(row.id, {
      'nameAr': def.nameIn(lookupL10n(const Locale('ar'))),
      'nameEn': def.nameIn(lookupL10n(const Locale('en'))),
      'color': def.color,
      'archetype': def.archetype,
      'icon': def.icon,
      'sources': def.sources,
      'weight': 1.0,
      'hidden': false,
    });
    return _restore(row);
  }

  /// Whether [key] names a user-added planet.
  static bool isCustomKey(String key) => !MadarDefaults.planets.any((p) => p.key == key);

  Future<List<String>> _detach(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> id,
    GeneratedColumn<String> planetKey,
    String key,
  ) async {
    final ids = await (_db.selectOnly(table)
          ..addColumns([id])
          ..where(planetKey.equals(key)))
        .map((r) => r.read(id)!)
        .get();
    if (ids.isNotEmpty) {
      await _db.customUpdate(
        'UPDATE ${table.actualTableName} SET ${planetKey.name} = NULL WHERE ${planetKey.name} = ?',
        variables: [Variable<String>(key)],
        updates: {table},
      );
    }
    return ids;
  }

  Future<void> _attach(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> id,
    GeneratedColumn<String> planetKey,
    String key,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;
    await _db.customUpdate(
      'UPDATE ${table.actualTableName} SET ${planetKey.name} = ? WHERE ${id.name} IN (${List.filled(ids.length, '?').join(', ')})',
      variables: [Variable<String>(key), for (final i in ids) Variable<String>(i)],
      updates: {table},
    );
  }
}
