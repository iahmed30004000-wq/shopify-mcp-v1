import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';

void main() {
  test('database opens in memory and stores a planet', () async {
    final db = MadarDatabase(NativeDatabase.memory());
    await db.into(db.planets).insert(PlanetsCompanion.insert(
          key: 'faith',
          nameAr: 'الإيمان',
          nameEn: 'Faith',
          color: 0xFFF2C14E,
          archetype: PlanetArchetype.faith,
        ));
    final rows = await db.select(db.planets).get();
    expect(rows.single.key, 'faith');
    expect(rows.single.sources, isEmpty);
    await db.close();
  });
}
