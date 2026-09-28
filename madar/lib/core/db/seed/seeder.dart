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
  /// Cleared by `CurrencyRepository.setRate` and by an import that writes the
  /// file's rates over them.
  static const currencyRatesAreDefaults = 'money.currencyRatesAreDefaults';

  /// Language (`"ar"` / `"en"`) the single-language defaults (tag options,
  /// habits) were written in; see [MadarSeeder.relocalizeDefaults].
  static const language = 'madar.seed.language';
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
      final language = _language(options.languageCode);
      final local = language == 'en' ? en : ar;
      await _seedPlanets(ar, en);
      await _seedCurrencies(ar, en);
      await _seedTagOptions(local);
      await _seedHabits(local);
      await _put(SeedKeys.version, version);
      await _put(SeedKeys.language, language);
    });
  }

  static String _language(String code) => code == 'en' ? 'en' : 'ar';

  static const _languages = ['ar', 'en'];

  /// Rewrites the seeded tag options and habits into [languageCode] when they
  /// were seeded in another language – the database is seeded on first
  /// launch, before onboarding lets the user pick English. Only rows that
  /// still hold the untouched default of another language at the same
  /// position are changed; anything the user added, renamed or reordered is
  /// left alone. Returns how many rows were rewritten.
  Future<int> relocalizeDefaults(String languageCode) {
    return db.transaction(() async {
      final target = _language(languageCode);
      final stored = await (db.select(db.keyValues)..where((t) => t.key.equals(SeedKeys.language))).getSingleOrNull();
      if (stored != null && jsonDecode(stored.value) == target) return 0;
      if (await _storedVersion() == 0) return 0;
      final to = lookupL10n(Locale(target));
      final others = [for (final code in _languages) if (code != target) lookupL10n(Locale(code))];
      var changed = 0;

      List<List<String>> tagLists(L10n l) => [
        MadarDefaults.painLocations(l),
        MadarDefaults.painTriggers(l),
        MadarDefaults.moodFactors(l),
      ];
      const kinds = [TagKind.painLocation, TagKind.painTrigger, TagKind.moodFactor];
      final targetTags = tagLists(to);
      for (var k = 0; k < kinds.length; k++) {
        final rows = await (db.select(db.tagOptions)..where((t) => t.kind.equalsValue(kinds[k]))).get();
        for (final row in rows) {
          final i = row.sortOrder;
          if (i < 0 || i >= targetTags[k].length) continue;
          if (!others.any((o) => tagLists(o)[k][i] == row.label)) continue;
          await (db.update(db.tagOptions)..where((t) => t.id.equals(row.id)))
              .write(TagOptionsCompanion(label: Value(targetTags[k][i])));
          changed++;
        }
      }

      final targetHabits = MadarDefaults.stressHabits(to);
      for (final row in await db.select(db.habits).get()) {
        final i = row.sortOrder;
        if (i < 0 || i >= targetHabits.length) continue;
        if (!others.any((o) => MadarDefaults.stressHabits(o)[i].name == row.name)) continue;
        await (db.update(db.habits)..where((t) => t.id.equals(row.id))).write(HabitsCompanion(name: Value(targetHabits[i].name)));
        changed++;
      }

      await _put(SeedKeys.language, target);
      return changed;
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
