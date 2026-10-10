import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/data/planet_customization_service.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';

import 'orbit_fixtures.dart';

void main() {
  final now = DateTime(2026, 9, 27, 12, 30);

  PrayerState state(PrayerSettings settings, {Map<Prayer, PrayerStatus> logged = const {}, DateTime? at}) {
    final schedule = PrayerSchedule(settings);
    final t = at ?? now;
    return PrayerState(
      settings: settings,
      times: schedule.timesFor(t),
      window: schedule.windowAt(t),
      prayerDay: DateTime(t.year, t.month, t.day),
      logged: logged,
    );
  }

  test('equal prayer states hash equal (the watcher skips an unchanged scene)', () {
    expect(state(const PrayerSettings()).contentHash, state(const PrayerSettings()).contentHash);
    expect(
      state(const PrayerSettings(adjustmentsMin: {'asr': 2, 'isha': -3})).contentHash,
      state(const PrayerSettings(adjustmentsMin: {'isha': -3, 'asr': 2})).contentHash,
      reason: 'map order does not matter',
    );
  });

  test('a new Asr madhab, adjustment, location or log reaches the dial', () {
    final base = state(const PrayerSettings()).contentHash;
    expect(state(const PrayerSettings(hanafiAsr: true)).contentHash, isNot(base));
    expect(state(const PrayerSettings(adjustmentsMin: {'asr': 2})).contentHash, isNot(base));
    expect(state(const PrayerSettings(latitude: 32.55)).contentHash, isNot(base));
    expect(state(const PrayerSettings(fajrAngle: 19.5)).contentHash, isNot(base));
    expect(state(const PrayerSettings(), logged: const {Prayer.dhuhr: PrayerStatus.prayed}).contentHash, isNot(base));
    expect(
      state(const PrayerSettings(), logged: const {Prayer.dhuhr: PrayerStatus.prayed}).contentHash,
      isNot(state(const PrayerSettings(), logged: const {Prayer.dhuhr: PrayerStatus.late}).contentHash),
    );
  });

  test('a new window changes the hash; a minute inside the same window does not', () {
    final base = state(const PrayerSettings()).contentHash;
    expect(state(const PrayerSettings(), at: now.add(const Duration(minutes: 1))).contentHash, base);
    expect(state(const PrayerSettings(), at: DateTime(2026, 9, 27, 16, 30)).contentHash, isNot(base));
  });

  test('a weight change alone reaches the planet page (the snapshot hash changes)', () async {
    final db = await openInMemoryMadarDatabase();
    addTearDown(db.close);
    final repos = Repositories(db);
    final repo = OrbitRepository(repos, clock: () => fixtureNow);
    final a = await repo.snapshot();
    await PlanetCustomizationService(repos).setWeight('faith', 3);
    final b = await repo.snapshot();
    expect(b.planet('faith')!.weight, 3);
    expect(b.planet('faith')!.contentHash, isNot(a.planet('faith')!.contentHash));
    expect(b.contentHash, isNot(a.contentHash));
  });

  test('a custom module feeding a planet is listed by its name, never by its id', () async {
    final db = await openInMemoryMadarDatabase();
    addTearDown(db.close);
    final repos = Repositories(db);
    await repos.customModules.insert(
      CustomModulesCompanion.insert(name: 'Reading log', color: 0xFF55AA88, planetKey: const Value('growth')),
    );
    final snap = await OrbitRepository(repos, clock: () => fixtureNow).snapshot();
    final rows = snap.planet('growth')!.sourceRows(lookupL10n(const Locale('ar')));
    expect(rows.where((r) => r.key.startsWith('module:')).map((r) => r.label), ['Reading log']);
    expect(rows.any((r) => r.label.startsWith('module:')), isFalse);
  });
}
