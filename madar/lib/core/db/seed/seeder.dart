import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../domain/enums.dart';
import '../../i18n/gen/app_localizations.dart';
import '../database.dart';
import 'defaults.dart';

/// How a new database is seeded.
///
/// Tag options and habits have a single text column, so they are stored in
/// the user's language at first run ([languageCode], Arabic by default); they
/// are the user's own editable lists from then on. Planets and currencies
/// have bilingual columns and always receive both Arabic and English names.
class SeedOptions {
  const SeedOptions({this.languageCode = 'ar'});

  /// `ar` (default) or `en`; anything else falls back to Arabic.
  final String languageCode;
}

/// Key/value entries written by the seeder.
abstract final class SeedKeys {
  /// Seed version applied to this database (JSON int).
  static const version = 'madar.seed.version';

  /// JSON `true` while the currency rates are still the generic defaults.
  /// Cleared by `CurrencyRepository.setRate`.
  static const currencyRatesAreDefaults = 'money.currencyRatesAreDefaults';
}

/// Seeds the generic first-run content exactly once per database.
///
/// A version marker in `key_values` makes seeding idempotent and prevents
/// re-seeding after the user deletes the defaults. Each section only adds
/// what is missing (planets by key, currencies by code, tag options per kind,
/// habits when there are none), so a future seed version can add content.
class MadarSeeder {
  MadarSeeder(this.db, {this.options = const SeedOptions()});

  /// Bump when new default content is added.
  static const version = 1;

  final MadarDatabase db;
  final SeedOptions options;

  /// Seeds when this database has not been seeded with [version] yet.
  /// Returns whether anything was done.
  Future<bool> seedIfNeeded() {
    return db.transaction(() async {
      if (await _storedVersion() >= version) return false;
      await seed();
      return true;
    });
  }

  /// Seeds unconditionally (still only adds what is missing) and stamps the
  /// version marker.
  Future<void> seed() {
    return db.transaction(() async {
      final ar = lookupL10n(const Locale('ar'));
      final en = lookupL10n(const Locale('en'));
      final local = options.languageCode == 'en' ? en : ar;
      await _seedPlanets(ar, en);
      await _seedCurrencies(ar, en);
      await _seedTagOptions(local);
      await _seedHabits(local);
      await _put(SeedKeys.version, version);
    });
  }

  Future<int> _storedVersion() async {
    final row = await (db.select(db.keyValues)..where((t) => t.key.equals(SeedKeys.version))).getSingleOrNull();
    if (row == null) return 0;
    final decoded = jsonDecode(row.value);
    return decoded is int ? decoded : 0;
  }

  Future<void> _put(String key, Object? value) {
    return db
        .into(db.keyValues)
        .insertOnConflictUpdate(
          KeyValuesCompanion.insert(key: key, value: jsonEncode(value), updatedAt: Value(DateTime.now())),
        );
  }

  Future<void> _seedPlanets(L10n ar, L10n en) async {
    final existing = (await db.select(db.planets).get()).map((p) => p.key).toSet();
    var order = existing.length;
    await db.batch((b) {
      for (final p in MadarDefaults.planets) {
        if (existing.contains(p.key)) continue;
        b.insert(
          db.planets,
          PlanetsCompanion.insert(
            key: p.key,
            nameAr: p.nameIn(ar),
            nameEn: p.nameIn(en),
            color: p.color,
            archetype: p.archetype,
            icon: Value(p.icon),
            weight: const Value(1.0),
            sources: Value(Map<String, Object?>.of(p.sources)),
            sortOrder: Value(order++),
          ),
        );
      }
    });
  }

  Future<void> _seedCurrencies(L10n ar, L10n en) async {
    final rows = await db.select(db.currencies).get();
    final existing = rows.map((c) => c.code).toSet();
    final hasBase = rows.any((c) => c.isBase);
    var order = rows.length;
    var added = false;
    await db.batch((b) {
      for (final c in MadarDefaults.currencies) {
        if (existing.contains(c.code)) continue;
        added = true;
        b.insert(
          db.currencies,
          CurrenciesCompanion.insert(
            code: c.code,
            nameAr: c.nameIn(ar),
            nameEn: c.nameIn(en),
            symbol: c.symbol,
            decimals: Value(c.decimals),
            rateToBase: Value(c.rateToBase),
            isBase: Value(c.isBase && !hasBase),
            sortOrder: Value(order++),
          ),
        );
      }
    });
    if (added && !hasBase) await _put(SeedKeys.currencyRatesAreDefaults, true);
  }

  Future<void> _seedTagOptions(L10n l) async {
    final kinds = (await db.select(db.tagOptions).get()).map((t) => t.kind).toSet();
    final lists = <TagKind, List<String>>{
      TagKind.painLocation: MadarDefaults.painLocations(l),
      TagKind.painTrigger: MadarDefaults.painTriggers(l),
      TagKind.moodFactor: MadarDefaults.moodFactors(l),
    };
    await db.batch((b) {
      for (final MapEntry(key: kind, value: labels) in lists.entries) {
        if (kinds.contains(kind)) continue;
        for (var i = 0; i < labels.length; i++) {
          b.insert(db.tagOptions, TagOptionsCompanion.insert(kind: kind, label: labels[i], sortOrder: Value(i)));
        }
      }
    });
  }

  Future<void> _seedHabits(L10n l) async {
    final count = await db.habits.count().getSingle();
    if (count > 0) return;
    final habits = MadarDefaults.stressHabits(l);
    await db.batch((b) {
      for (var i = 0; i < habits.length; i++) {
        final h = habits[i];
        b.insert(
          db.habits,
          HabitsCompanion.insert(
            name: h.name,
            category: Value(h.category),
            planetKey: Value(h.planetKey),
            sortOrder: Value(i),
          ),
        );
      }
    });
  }
}
