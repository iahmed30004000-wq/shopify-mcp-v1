import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'orbit_fixtures.dart';

void main() {
  for (final thriving in [true, false]) {
    test('smoke $thriving', () async {
      final db = await openInMemoryMadarDatabase();
      final repos = Repositories(db);
      await seedLivedIn(repos, thriving: thriving);
      final repo = OrbitRepository(repos, clock: () => fixtureNow);
      final snap = await repo.snapshot();
      for (final p in snap.planets) {
        print('${p.key} ${p.score.score.toStringAsFixed(2)} ${p.state.name} ${p.score.sources.map((k, v) => MapEntry(k, v.toStringAsFixed(2)))} moons ${p.moons.map((m) => '${m.label}:${m.kind.name}:${m.score.toStringAsFixed(2)}:${m.size.toStringAsFixed(2)}').toList()} extras ${p.extras}');
        for (final r in p.score.reasons) print('   $r');
      }
      print('balance ${snap.balance.toStringAsFixed(3)}');
      print(snap.radar.map((r) => r.text).toList());
      print('${snap.prayer.window.window} lit ${snap.prayer.lit} day ${snap.prayer.prayerDay}');
      final en = await repo.snapshot(languageCode: 'en');
      print(en.radar.map((r) => r.text).toList());
      await db.close();
    });
  }
}
