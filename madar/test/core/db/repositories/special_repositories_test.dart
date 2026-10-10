import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/seed/seeder.dart';
import 'package:madar/core/providers.dart';

class PrayerConfig {
  const PrayerConfig(this.method, this.offsets);
  final String method;
  final Map<String, int> offsets;
}

final prayerConfigKey = KvKey.json<PrayerConfig>(
  'prayer.config',
  fromJson: (j) {
    final m = (j as Map).cast<String, Object?>();
    return PrayerConfig(m['method'] as String, (m['offsets'] as Map).cast<String, int>());
  },
  toJson: (c) => {'method': c.method, 'offsets': c.offsets},
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
  });

  tearDown(() => db.close());

  group('KeyValueRepository', () {
    test('typed get/set/watch', () async {
      final kv = repos.keyValues;
      final city = KvKey.string('location.city');
      final count = KvKey.integer('counter');
      final on = KvKey.boolean('flag');
      final ratio = KvKey.number('ratio');
      final map = KvKey.map('map');

      expect(await kv.get(city), isNull);
      final seen = <String?>[];
      final sub = kv.watch(city).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await kv.set(city, 'مدينة');
      await kv.set(count, 3);
      await kv.set(on, true);
      await kv.set(ratio, 4);
      await kv.set(map, {
        'a': 1,
        'b': [true, null],
      });
      await kv.set(prayerConfigKey, const PrayerConfig('mwl', {'fajr': 2}));
      await pumpEventQueue();

      expect(await kv.get(city), 'مدينة');
      expect(await kv.get(count), 3);
      expect(await kv.get(on), isTrue);
      expect(await kv.get(ratio), 4.0);
      expect(await kv.get(map), {
        'a': 1,
        'b': [true, null],
      });
      final config = (await kv.get(prayerConfigKey))!;
      expect(config.method, 'mwl');
      expect(config.offsets, {'fajr': 2});
      expect(await kv.getJson('counter'), 3);
      expect(await kv.contains('counter'), isTrue);

      await kv.remove('location.city');
      await pumpEventQueue();
      expect(seen, [null, 'مدينة', null]);
    });

    test('a value that no longer fits its key reads as null', () async {
      await repos.keyValues.setJson('counter', 'not a number');
      expect(await repos.keyValues.get(KvKey.integer('counter')), isNull);
    });

    test('the seed marker is readable through the repository', () async {
      expect(await repos.keyValues.get(KvKey.integer(SeedKeys.version)), MadarSeeder.version);
    });
  });

  group('ActivityRepository', () {
    test('log, query, last-by-planet and undo', () async {
      final a = repos.activity;
      final base = DateTime(2026, 9, 27, 8);
      await a.log(planetKey: 'work', kind: 'task.done', refTable: 'tasks', refId: 't1', at: base);
      await a.log(planetKey: 'work', kind: 'card.done', at: base.add(const Duration(hours: 2)), value: 2);
      await a.log(
        planetKey: 'faith',
        kind: 'prayer',
        at: base.subtract(const Duration(days: 2)),
        payload: {'prayer': 'fajr'},
      );

      final recent = await a.since(base.subtract(const Duration(hours: 1)));
      expect(recent.map((r) => r.kind), ['card.done', 'task.done']);
      expect(await a.since(DateTime(2000), planetKey: 'faith'), hasLength(1));
      expect((await a.since(DateTime(2000), kind: 'prayer')).single.payload, {'prayer': 'fajr'});

      final last = await a.watchLastByPlanet().first;
      expect(last.keys.toSet(), {'work', 'faith'});
      expect(last['work']!.isAtSameMomentAs(base.add(const Duration(hours: 2))), isTrue);

      final removed = await a.removeFor(refTable: 'tasks', refId: 't1');
      expect(removed.single.kind, 'task.done');
      expect(await a.since(DateTime(2000), planetKey: 'work'), hasLength(1));
      await repos.activityLog.restoreAll(removed);
      expect(await a.since(DateTime(2000), planetKey: 'work'), hasLength(2));
    });

    test('instants compare correctly across time-zone offsets', () async {
      final utc = DateTime.utc(2026, 9, 27, 12);
      await repos.activity.log(planetKey: 'travel', kind: 'a', at: utc);
      await repos.activity.log(planetKey: 'travel', kind: 'b', at: utc.add(const Duration(minutes: 1)).toLocal());
      final rows = await repos.activity.since(utc.subtract(const Duration(seconds: 1)));
      expect(rows.map((r) => r.kind), ['b', 'a']);
    });
  });

  group('CurrencyRepository', () {
    test('rates, base switch and undo', () async {
      final c = repos.currencies;
      expect((await c.base())!.code, 'JOD');
      expect((await c.getAll()).first.code, 'JOD');

      await c.setRate('USD', 0.71);
      expect((await c.byCode('USD'))!.rateToBase, 0.71);
      expect(await repos.keyValues.contains(SeedKeys.currencyRatesAreDefaults), isFalse);

      await c.setBase('USD');
      final usd = (await c.byCode('USD'))!;
      final jod = (await c.byCode('JOD'))!;
      expect(usd.isBase, isTrue);
      expect(usd.rateToBase, 1.0);
      expect(jod.isBase, isFalse);
      expect(jod.rateToBase, closeTo(1 / 0.71, 1e-12));
      expect((await c.watchBase().first)!.code, 'USD');

      await c.upsert(
        CurrenciesCompanion.insert(
          code: 'EUR',
          nameAr: 'يورو',
          nameEn: 'Euro',
          symbol: '€',
          rateToBase: const Value(1.1),
        ),
      );
      final all = await c.getAll();
      expect(all.first.code, 'USD');
      expect(all.last.code, 'EUR');

      expect(() => c.delete('USD'), throwsStateError);
      final removed = (await c.delete('EUR'))!;
      expect(await c.byCode('EUR'), isNull);
      await c.restore(removed);
      expect((await c.byCode('EUR'))!.rateToBase, 1.1);

      await c.reorder(['LYD', 'EGP', 'SYP', 'JOD', 'EUR', 'USD']);
      expect((await c.getAll()).map((r) => r.code), ['USD', 'LYD', 'EGP', 'SYP', 'JOD', 'EUR']);
    });
  });

  test('repositoriesProvider reads databaseProvider', () async {
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final r = container.read(repositoriesProvider);
    expect(r.db, same(db));
    expect(await r.planets.count(), 8);
  });
}
