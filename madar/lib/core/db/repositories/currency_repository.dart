import 'package:drift/drift.dart';

import '../database.dart';
import '../seed/seeder.dart' show SeedKeys;

/// Currencies with manual exchange rates (the `currencies` table is keyed by
/// ISO code, so it is not an `EntityRepository`).
class CurrencyRepository {
  CurrencyRepository(this.db);

  final MadarDatabase db;

  /// All currencies, base first, then by `sort_order`.
  Stream<List<CurrencyRow>> watchAll() => _all().watch();

  Future<List<CurrencyRow>> getAll() => _all().get();

  Future<CurrencyRow?> byCode(String code) =>
      (db.select(db.currencies)..where((t) => t.code.equals(code))).getSingleOrNull();

  /// The base currency (null only in an unseeded database).
  Future<CurrencyRow?> base() => (db.select(db.currencies)..where((t) => t.isBase.equals(true))).getSingleOrNull();

  /// Live base currency.
  Stream<CurrencyRow?> watchBase() =>
      (db.select(db.currencies)..where((t) => t.isBase.equals(true))).watchSingleOrNull();

  /// Inserts or replaces a currency. New currencies go last unless
  /// `sortOrder` is given. Use [setBase] to change the base.
  Future<void> upsert(CurrenciesCompanion currency) async {
    await db.transaction(() async {
      var row = currency.copyWith(isBase: const Value.absent());
      final exists = await byCode(currency.code.value) != null;
      if (!exists && !row.sortOrder.present) {
        final max = db.currencies.sortOrder.max();
        final last = await (db.selectOnly(db.currencies)..addColumns([max])).map((r) => r.read(max)).getSingle();
        row = row.copyWith(sortOrder: Value((last ?? -1) + 1));
      }
      await db.into(db.currencies).insertOnConflictUpdate(row);
    });
  }

  /// Updates the manual rate (1 unit of [code] in base units) and clears the
  /// "rates are still defaults" flag.
  Future<void> setRate(String code, double rateToBase) async {
    await db.transaction(() async {
      await (db.update(
        db.currencies,
      )..where((t) => t.code.equals(code))).write(CurrenciesCompanion(rateToBase: Value(rateToBase)));
      await (db.delete(db.keyValues)..where((t) => t.key.equals(SeedKeys.currencyRatesAreDefaults))).go();
    });
  }

  /// Makes [code] the base currency and re-expresses every rate against it
  /// (`rate' = rate / rate(new base)`), so converted amounts are unchanged.
  Future<void> setBase(String code) async {
    await db.transaction(() async {
      final target = await byCode(code);
      if (target == null) throw StateError('Unknown currency $code');
      if (target.isBase) return;
      final pivot = target.rateToBase;
      if (pivot <= 0) throw StateError('Currency $code has no usable rate');
      final rows = await getAll();
      await db.batch((b) {
        for (final c in rows) {
          b.update(
            db.currencies,
            CurrenciesCompanion(
              rateToBase: Value(c.code == code ? 1.0 : c.rateToBase / pivot),
              isBase: Value(c.code == code),
            ),
            where: (t) => t.code.equals(c.code),
          );
        }
      });
    });
  }

  /// Deletes a currency and returns it for undo. The base currency cannot be
  /// deleted.
  Future<CurrencyRow?> delete(String code) {
    return db.transaction(() async {
      final row = await byCode(code);
      if (row == null) return null;
      if (row.isBase) throw StateError('The base currency cannot be deleted');
      await (db.delete(db.currencies)..where((t) => t.code.equals(code))).go();
      return row;
    });
  }

  /// Re-inserts a deleted currency exactly.
  Future<void> restore(CurrencyRow row) => db.into(db.currencies).insert(row, mode: InsertMode.insertOrReplace);

  /// Persists a drag-and-drop order of currency codes.
  Future<void> reorder(List<String> codesInOrder) {
    return db.batch((b) {
      for (var i = 0; i < codesInOrder.length; i++) {
        final code = codesInOrder[i];
        b.update(db.currencies, CurrenciesCompanion(sortOrder: Value(i)), where: (t) => t.code.equals(code));
      }
    });
  }

  SimpleSelectStatement<$CurrenciesTable, CurrencyRow> _all() => db.select(db.currencies)
    ..orderBy([
      (t) => OrderingTerm.desc(t.isBase),
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.code),
    ]);
}
