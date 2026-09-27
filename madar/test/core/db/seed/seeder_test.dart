import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/indexes.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/seed/defaults.dart';
import 'package:madar/core/db/seed/seeder.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

Future<Map<String, int>> counts(MadarDatabase db) async => {
  for (final t in db.allTables)
    t.actualTableName: (await db.customSelect('SELECT count(*) AS c FROM "${t.actualTableName}"').getSingle())
        .read<int>('c'),
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('a bare MadarDatabase is not seeded', () async {
    final db = MadarDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await counts(db)).values, everyElement(0));
  });

  group('default seed (Arabic)', () {
    late MadarDatabase db;

    setUp(() async => db = await openInMemoryMadarDatabase());
    tearDown(() => db.close());

    test('eight planets with palettes, archetypes, equal weights and sources', () async {
      final planets = await (db.select(db.planets)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(planets.map((p) => p.key), ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel']);
      expect(planets.map((p) => p.sortOrder), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(planets.map((p) => p.archetype), [
        PlanetArchetype.faith,
        PlanetArchetype.ocean,
        PlanetArchetype.terracotta,
        PlanetArchetype.industrial,
        PlanetArchetype.crystal,
        PlanetArchetype.verdant,
        PlanetArchetype.volcanic,
        PlanetArchetype.gasGiant,
      ]);
      for (final p in planets) {
        expect(p.color, PlanetPalettes.byKey[p.key]!.surface.toARGB32(), reason: p.key);
        expect(p.weight, 1.0);
        expect(p.hidden, isFalse);
        final total = p.sources.values.fold<double>(0, (s, v) => s + (v! as num).toDouble());
        expect(total, closeTo(1.0, 1e-9), reason: p.key);
      }
      expect(planets.first.nameAr, 'الإيمان');
      expect(planets.first.nameEn, 'Faith');
      expect(planets.last.nameAr, 'السفر');
      expect(planets.last.nameEn, 'Travel');
    });

    test('currencies: JOD base with 3 decimals, editable reference rates', () async {
      final currencies = await (db.select(db.currencies)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(currencies.map((c) => c.code), ['JOD', 'USD', 'SYP', 'EGP', 'LYD']);
      final jod = currencies.first;
      expect(jod.isBase, isTrue);
      expect(jod.decimals, 3);
      expect(jod.rateToBase, 1.0);
      expect(jod.nameAr, 'دينار أردني');
      expect(currencies.where((c) => c.isBase), hasLength(1));
      expect(currencies.firstWhere((c) => c.code == 'LYD').decimals, 3);
      expect(currencies.firstWhere((c) => c.code == 'USD').rateToBase, 0.709);
      for (final c in currencies) {
        expect(c.rateToBase, greaterThan(0));
        expect(c.symbol, isNotEmpty);
      }
      final flag = await (db.select(
        db.keyValues,
      )..where((t) => t.key.equals(SeedKeys.currencyRatesAreDefaults))).getSingle();
      expect(jsonDecode(flag.value), isTrue);
    });

    test('tag options and stress habits in Arabic', () async {
      final tags = await db.select(db.tagOptions).get();
      int countOf(TagKind k) => tags.where((t) => t.kind == k).length;
      expect(countOf(TagKind.painLocation), MadarDefaults.painLocations(_ar).length);
      expect(countOf(TagKind.painTrigger), greaterThan(5));
      expect(countOf(TagKind.moodFactor), greaterThan(5));
      expect(tags.map((t) => t.label), contains('الرأس'));

      final habits = await db.select(db.habits).get();
      expect(habits, hasLength(11));
      expect(habits.every((h) => h.category == 'stress' && h.active), isTrue);
      expect(habits.map((h) => h.name), contains('أذكار الصباح والمساء'));
      expect(habits.map((h) => h.planetKey).toSet(), containsAll(['health', 'faith', 'body', 'family']));
    });

    test('indexes are created', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'")
          .get();
      expect(rows, hasLength(madarIndexStatements.length));
    });

    test('seeding is idempotent and never re-seeds deleted defaults', () async {
      final before = await counts(db);
      expect(await MadarSeeder(db).seedIfNeeded(), isFalse);
      expect(await counts(db), before);

      await db.delete(db.habits).go();
      expect(await MadarSeeder(db).seedIfNeeded(), isFalse);
      expect(await db.select(db.habits).get(), isEmpty);

      // An explicit seed only adds what is missing.
      await MadarSeeder(db).seed();
      final after = await counts(db);
      expect(after['planets'], 8);
      expect(after['currencies'], 5);
      expect(after['tag_options'], before['tag_options']);
      expect(after['habits'], 11);
    });

    test('a user-chosen base currency survives a re-seed', () async {
      await (db.update(
        db.currencies,
      )..where((t) => t.code.equals('JOD'))).write(const CurrenciesCompanion(isBase: Value(false)));
      await (db.update(
        db.currencies,
      )..where((t) => t.code.equals('USD'))).write(const CurrenciesCompanion(isBase: Value(true)));
      await (db.delete(db.currencies)..where((t) => t.code.equals('SYP'))).go();
      await MadarSeeder(db).seed();
      final bases = await (db.select(db.currencies)..where((t) => t.isBase.equals(true))).get();
      expect(bases.single.code, 'USD');
      expect(await db.select(db.currencies).get(), hasLength(5));
    });
  });

  test('English seed stores English labels, planets stay bilingual', () async {
    final db = await openInMemoryMadarDatabase(seed: const SeedOptions(languageCode: 'en'));
    addTearDown(db.close);
    final habits = await db.select(db.habits).get();
    expect(habits.map((h) => h.name), contains('Morning and evening adhkar'));
    final tags = await db.select(db.tagOptions).get();
    expect(tags.map((t) => t.label), contains('Head'));
    final faith = await (db.select(db.planets)..where((t) => t.key.equals('faith'))).getSingle();
    expect(faith.nameAr, 'الإيمان');
    expect(faith.nameEn, 'Faith');
  });

  test('seed: null opens an empty database', () async {
    final db = await openInMemoryMadarDatabase(seed: null);
    addTearDown(db.close);
    expect((await counts(db)).values, everyElement(0));
  });
}

final _ar = lookupL10n(const Locale('ar'));
