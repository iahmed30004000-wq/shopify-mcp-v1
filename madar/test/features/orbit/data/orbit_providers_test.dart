import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_providers.dart' show homeClockProvider, prayerDayProvider;
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/domain/planet_pulse.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orbit_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MadarDatabase db;
  late ProviderContainer container;
  late List<SceneSnapshot> snapshots;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await openInMemoryMadarDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeClockProvider.overrideWithValue(() => fixtureNow),
        sceneSnapshotTimingProvider.overrideWithValue((
          debounce: const Duration(milliseconds: 30),
          maxWait: const Duration(milliseconds: 200),
          tick: null,
        )),
      ],
    );
    snapshots = [];
    container.listen<AsyncValue<SceneSnapshot>>(sceneSnapshotProvider, (_, next) {
      if (next case AsyncData(:final value)) snapshots.add(value);
    }, fireImmediately: true);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Repositories repos() => container.read(repositoriesProvider);

  /// Waits (real time) until [done] holds.
  Future<void> until(bool Function() done, {String what = 'condition'}) async {
    for (var i = 0; i < 100; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('timed out waiting for $what');
  }

  test('the live snapshot follows the database and the language', () async {
    await until(() => snapshots.isNotEmpty, what: 'first snapshot');
    expect(snapshots.last.planets.map((p) => p.name).first, 'الإيمان');
    expect(snapshots.last.planet('family')!.state, PlanetState.dormant);

    await repos().people.insert(
      PeopleCompanion.insert(
        name: 'أبي',
        rhythmDays: const Value(2),
        lastContact: Value(fixtureNow.subtract(const Duration(days: 5))),
      ),
    );
    await until(() => snapshots.last.planet('family')!.state == PlanetState.neglected, what: 'family neglected');
    expect(snapshots.last.radar.single.text, contains('متأخر ٣ أيام'));
    expect(snapshots.last.planet('family')!.moons.single.label, 'أبي');

    await container.read(appSettingsProvider.notifier).update((s) => s.copyWith(languageCode: 'en'));
    await until(() => snapshots.last.languageCode == 'en', what: 'English snapshot');
    expect(snapshots.last.planets.first.name, 'Faith');
    expect(snapshots.last.radar.single.text, contains('3 days overdue'));
  });

  test("home's prayer day gets the real schedule for the stored location", () async {
    final day = container.read(orbitPrayerDayProvider);
    expect(day.isPlaceholder, isFalse);
    final amman = PrayerSchedule(const PrayerSettings()).timesFor(fixtureNow);
    expect(day.fajr, prayerDayTimesOf(amman).fajr);
    expect(day.maghrib, prayerDayTimesOf(amman).maghrib);

    // Moving to Damascus re-times the dial and the scene.
    const damascus = PrayerSettings(latitude: 33.51, longitude: 36.29, cityName: 'Damascus');
    final sub = container.listen(prayerSettingsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(orbitRepositoryProvider).setPrayerSettings(damascus);
    await until(() => container.read(prayerSettingsProvider).value?.cityName == 'Damascus', what: 'settings');
    final moved = container.read(orbitPrayerDayProvider);
    expect(moved.maghrib, prayerDayTimesOf(PrayerSchedule(damascus).timesFor(fixtureNow)).maghrib);
    expect(moved.maghrib, isNot(day.maghrib));
    await until(() => snapshots.isNotEmpty && snapshots.last.prayer.settings.cityName == 'Damascus', what: 'scene');
    expect(snapshots.last.prayer.times.dhuhr, PrayerSchedule(damascus).timesFor(fixtureNow).dhuhr);
  });

  test("home's prayerDayProvider can be swapped for the real schedule (no cycle)", () async {
    final home = ProviderContainer(
      parent: container,
      overrides: [prayerDayProvider.overrideWith((ref) => ref.watch(orbitPrayerDayProvider))],
    );
    addTearDown(home.dispose);
    final day = home.read(prayerDayProvider);
    expect(day.isPlaceholder, isFalse);
    final amman = PrayerSchedule(const PrayerSettings()).timesFor(fixtureNow);
    expect(day.isha, prayerDayTimesOf(amman).isha);
    // Home's window arithmetic now agrees with the orbit's schedule.
    expect(day.windowAt(fixtureNow), PrayerSchedule(const PrayerSettings()).windowAt(fixtureNow).window);
  });

  test('an Isha after midnight (high-latitude summer) keeps the window order', () {
    final day = DateTime(2026, 6, 21);
    final times = prayerDayTimesOf(
      DayTimes(
        day: day,
        fajr: DateTime(2026, 6, 21, 2, 40),
        sunrise: DateTime(2026, 6, 21, 4, 43),
        dhuhr: DateTime(2026, 6, 21, 13, 2),
        asr: DateTime(2026, 6, 21, 17, 25),
        maghrib: DateTime(2026, 6, 21, 21, 22),
        isha: DateTime(2026, 6, 22, 0, 35),
      ),
    );
    expect(times.isha, const Duration(hours: 24, minutes: 35));
    expect(times.windowAt(DateTime(2026, 6, 21, 23, 10)), PrayerWindow.maghrib);
    expect(times.windowAt(DateTime(2026, 6, 22, 1, 30)), PrayerWindow.isha);
    expect(times.windowAt(DateTime(2026, 6, 21, 3, 0)), PrayerWindow.fajr);
    expect(times.endOn(PrayerWindow.maghrib, day), DateTime(2026, 6, 22, 0, 35));
  });

  test('a recorded completion pulses its planet and wakes it up', () async {
    final pulses = <PlanetPulse>[];
    final sub = container.listen<AsyncValue<PlanetPulse>>(planetPulsesProvider, (_, next) {
      if (next case AsyncData(:final value)) pulses.add(value);
    });
    addTearDown(sub.close);
    await until(() => snapshots.isNotEmpty, what: 'first snapshot');
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the hub reads its watermark

    // A custom planet with no data of its own: dormant until something is
    // done for it.
    await repos().planets.insert(
      PlanetsCompanion.insert(
        key: 'custom_garden',
        nameAr: 'الحديقة',
        nameEn: 'Garden',
        color: 0xFF6FCF97,
        archetype: PlanetArchetype.verdant,
      ),
    );
    await until(() => snapshots.last.planet('custom_garden') != null, what: 'new planet');
    expect(snapshots.last.planet('custom_garden')!.state, PlanetState.dormant);

    await container.read(orbitPulseHubProvider).recordCompletion('custom_garden', 'garden.watered', null, null);
    await until(() => pulses.isNotEmpty, what: 'pulse');
    expect(pulses.single.planetKey, 'custom_garden');
    expect(pulses.single.origin, PulseOrigin.recorded);
    await until(() => snapshots.last.planet('custom_garden')!.state == PlanetState.thriving, what: 'thriving');
    expect(pulses, hasLength(1)); // not pulsed a second time by the activity observer
  });
}
