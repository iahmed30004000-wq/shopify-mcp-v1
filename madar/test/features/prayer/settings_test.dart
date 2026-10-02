import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart' show repositoriesProvider;
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_providers.dart' show homeClockProvider;
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/application/location_flow.dart';
import 'package:madar/features/prayer/application/prayer_providers.dart';
import 'package:madar/features/prayer/application/prayer_settings_controller.dart';
import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/location.dart';
import 'package:madar/features/prayer/domain/settings_changes.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MadarTimeZones.ensure);

  group('PrayerSettings JSON', () {
    test('Phase 1 JSON decodes unchanged (Jordan preset, device zone)', () {
      final phase1 = {
        'latitude': 31.9539,
        'longitude': 35.9106,
        'cityName': null,
        'fajrAngle': 18,
        'ishaAngle': 18,
        'hanafiAsr': false,
        'adjustmentsMin': {'fajr': 2},
        'useJordanPreset': true,
      };
      final s = PrayerSettings.fromJson(phase1);
      expect(s.method, PrayerMethod.jordan);
      expect(s.useJordanPreset, isTrue);
      expect(s.timeZone, isNull);
      expect(s.adjustmentsMin, {'fajr': 2});
      expect(s.highLatitude, HighLatitudeMode.auto);
      expect(s.hijriOffsetDays, 0);
      expect(s.locationSource, PrayerLocationSource.defaultCity);
      expect(s.clock24h, isFalse);
    });

    test('Phase 1 custom angles keep their times (custom + Jordan Maghrib offset)', () {
      final s = PrayerSettings.fromJson({'fajrAngle': 17.5, 'ishaAngle': 18, 'useJordanPreset': true});
      expect(s.method, PrayerMethod.custom);
      expect(s.fajrAngle, 17.5);
      expect(s.adjustmentsMin['maghrib'], 5);
      final other = PrayerSettings.fromJson({'useJordanPreset': false, 'fajrAngle': 15, 'ishaAngle': 15});
      expect(other.method, PrayerMethod.custom);
    });

    test('an empty or broken JSON gives the defaults', () {
      final s = PrayerSettings.fromJson({'latitude': 'x', 'method': 'nope', 'hijriOffsetDays': 9, 'timeZone': ''});
      expect(s.latitude, const PrayerSettings().latitude);
      expect(s.method, PrayerMethod.jordan);
      expect(s.hijriOffsetDays, 2);
      expect(s.timeZone, isNull);
      expect(PrayerSettings.fromJson(const {}), const PrayerSettings());
    });

    test('every field round-trips', () {
      const s = PrayerSettings(
        latitude: 21.4225,
        longitude: 39.8262,
        fajrAngle: 18.5,
        ishaAngle: 17,
        hanafiAsr: true,
        adjustmentsMin: {'isha': -3, 'fajr': 1},
        method: PrayerMethod.ummAlQura,
        ishaIntervalMin: 95,
        highLatitude: HighLatitudeMode.twilightAngle,
        hijriOffsetDays: -1,
        hijriAtMaghrib: true,
        clock24h: true,
        timeZone: 'Asia/Riyadh',
        cityId: 'sa-makkah',
        cityNameAr: 'مكة المكرمة',
        cityNameEn: 'Makkah',
        countryCode: 'SA',
        locationSource: PrayerLocationSource.city,
      );
      final back = PrayerSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back, s);
      expect(back.hashCode, s.hashCode);
      expect(back.useJordanPreset, isFalse);
      expect(back.placeName('ar'), 'مكة المكرمة');
      expect(back.placeName('en'), 'Makkah');
    });

    test('customBase round-trips; older custom JSON has none', () {
      const s = PrayerSettings(method: PrayerMethod.custom, fajrAngle: 15, customBase: PrayerMethod.jordan);
      final back = PrayerSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back, s);
      expect(back.customBase, PrayerMethod.jordan);
      expect(back.hashCode, s.hashCode);
      expect(back == s.copyWith(customBase: null), isFalse);
      final old = PrayerSettings.fromJson({'method': 'custom', 'fajrAngle': 15, 'ishaAngle': 15});
      expect(old.customBase, isNull);
      expect(PrayerSettings.fromJson({'method': 'custom', 'customBase': 'custom'}).customBase, isNull);
    });

    test('copyWith can clear nullable fields', () {
      const s = PrayerSettings(timeZone: 'Asia/Amman', cityId: 'jo-amman', ishaIntervalMin: 90);
      final c = s.copyWith(timeZone: null, cityId: null, ishaIntervalMin: null);
      expect(c.timeZone, isNull);
      expect(c.cityId, isNull);
      expect(c.ishaIntervalMin, isNull);
      expect(s.copyWith().timeZone, 'Asia/Amman');
    });
  });

  group('PrayerSettingsChanges', () {
    test('switching to custom starts from the current method', () {
      final mwl = PrayerSettingsChanges.method(const PrayerSettings(), PrayerMethod.muslimWorldLeague);
      expect(mwl.method, PrayerMethod.muslimWorldLeague);
      expect((mwl.fajrAngle, mwl.ishaAngle), (18.0, 17.0));
      final custom = PrayerSettingsChanges.method(mwl, PrayerMethod.custom);
      expect(custom.method, PrayerMethod.custom);
      expect((custom.fajrAngle, custom.ishaAngle), (18.0, 17.0));
      final fromQatar = PrayerSettingsChanges.method(
        PrayerSettingsChanges.method(const PrayerSettings(), PrayerMethod.qatar),
        PrayerMethod.custom,
      );
      expect(fromQatar.ishaIntervalMin, 90);
    });

    test('switching a preset to custom changes no time (offsets and Maghrib angle stay)', () {
      // Jordan's sunrise −7 / Maghrib +7, Tehran's Maghrib angle, Dubai's
      // and MWL's offsets: before this was kept, "custom" silently moved
      // Maghrib up to 18 minutes earlier.
      for (final m in PrayerMethod.values.where((m) => m != PrayerMethod.custom)) {
        final preset = PrayerSettings(timeZone: 'Asia/Amman', method: m);
        final custom = PrayerSettingsChanges.method(preset, PrayerMethod.custom);
        expect(custom.customBase, m);
        for (final day in [DateTime(2026, 3, 20), DateTime(2026, 9, 28), DateTime(2026, 12, 21)]) {
          final a = PrayerSchedule(preset).timesFor(day);
          final b = PrayerSchedule(custom).timesFor(day);
          if (m == PrayerMethod.moonsightingCommittee) {
            // Its seasonal twilight is a method of its own; only the offsets
            // and Maghrib are kept.
            expect((b.sunrise, b.dhuhr, b.asr, b.maghrib), (a.sunrise, a.dhuhr, a.asr, a.maghrib), reason: '$m');
            continue;
          }
          expect(
            [b.fajr, b.sunrise, b.dhuhr, b.asr, b.maghrib, b.isha],
            [a.fajr, a.sunrise, a.dhuhr, a.asr, a.maghrib, a.isha],
            reason: '$m $day',
          );
        }
      }
      // Editing an angle from Jordan keeps the Ministry's Maghrib.
      const jordan = PrayerSettings(timeZone: 'Asia/Amman');
      final edited = PrayerSettingsChanges.fajrAngle(jordan, 15);
      final a = PrayerSchedule(jordan).timesFor(DateTime(2026, 9, 28));
      final b = PrayerSchedule(edited).timesFor(DateTime(2026, 9, 28));
      expect(b.maghrib, a.maghrib);
      expect(b.sunrise, a.sunrise);
      expect(b.fajr.isAfter(a.fajr), isTrue);
      // Back to a preset drops the base.
      expect(PrayerSettingsChanges.method(edited, PrayerMethod.jordan).customBase, isNull);
    });

    test('editing an angle makes the method custom; angles are clamped', () {
      final s = PrayerSettingsChanges.fajrAngle(const PrayerSettings(), 19.5);
      expect(s.method, PrayerMethod.custom);
      expect(s.fajrAngle, 19.5);
      expect(PrayerSettingsChanges.fajrAngle(s, 40).fajrAngle, PrayerSettingsChanges.maxAngle);
      expect(PrayerSettingsChanges.ishaAngle(s, 2).ishaAngle, PrayerSettingsChanges.minAngle);
      final interval = PrayerSettingsChanges.ishaInterval(s, 500);
      expect(interval.ishaIntervalMin, PrayerSettingsChanges.maxIshaInterval);
      expect(PrayerSettingsChanges.ishaAngle(interval, 17).ishaIntervalMin, isNull);
      expect(PrayerSettingsChanges.ishaInterval(interval, null).ishaIntervalMin, isNull);
    });

    test('adjustments are clamped, zero removes, unknown keys are ignored', () {
      var s = PrayerSettingsChanges.adjustment(const PrayerSettings(), 'fajr', 3);
      s = PrayerSettingsChanges.adjustment(s, 'maghrib', -99);
      expect(s.adjustmentsMin, {'fajr': 3, 'maghrib': -30});
      s = PrayerSettingsChanges.adjustment(s, 'fajr', 0);
      expect(s.adjustmentsMin, {'maghrib': -30});
      expect(PrayerSettingsChanges.adjustment(s, 'witr', 5), same(s));
      expect(PrayerSettingsChanges.resetAdjustments(s).adjustmentsMin, isEmpty);
    });

    test('Hijri offset −2…+2, rollover and clock', () {
      expect(PrayerSettingsChanges.hijriOffset(const PrayerSettings(), -5).hijriOffsetDays, -2);
      expect(PrayerSettingsChanges.hijriAtMaghrib(const PrayerSettings(), true).hijriAtMaghrib, isTrue);
      expect(PrayerSettingsChanges.clock24h(const PrayerSettings(), true).clock24h, isTrue);
      expect(PrayerSettingsChanges.hanafiAsr(const PrayerSettings(), true).hanafiAsr, isTrue);
      expect(
        PrayerSettingsChanges.highLatitude(const PrayerSettings(), HighLatitudeMode.seventhOfTheNight).highLatitude,
        HighLatitudeMode.seventhOfTheNight,
      );
    });

    test('picking a city stores its coordinates, names, country and zone', () {
      const makkah = City(
        id: 'sa-makkah',
        nameAr: 'مكة المكرمة',
        nameEn: 'Makkah',
        latitude: 21.432,
        longitude: 39.8181,
        timeZone: 'Asia/Riyadh',
        countryCode: 'SA',
      );
      final s = PrayerLocationChanges.pickCity(const PrayerSettings(cityName: 'old'), makkah);
      expect((s.latitude, s.longitude), (21.432, 39.8181));
      expect(s.timeZone, 'Asia/Riyadh');
      expect(s.cityId, 'sa-makkah');
      expect(s.cityName, isNull);
      expect(s.countryCode, 'SA');
      expect(s.locationSource, PrayerLocationSource.city);
      final back = PrayerLocationChanges.resetToDefault(s);
      expect(back.locationSource, PrayerLocationSource.defaultCity);
      expect(back.timeZone, isNull);
      expect(back.latitude, const PrayerSettings().latitude);
    });

    test('a GPS fix uses the device zone, else the nearest city\'s', () {
      const fix = GeoFix(latitude: 31.991234567, longitude: 35.871234567);
      const amman = City(
        id: 'jo-amman',
        nameAr: 'عمّان',
        nameEn: 'Amman',
        latitude: 31.952,
        longitude: 35.9314,
        timeZone: 'Asia/Amman',
        countryCode: 'JO',
      );
      final nearest = (city: amman, distanceKm: 7.0);
      final a = PrayerLocationChanges.applyFix(const PrayerSettings(), fix, nearest: nearest, deviceZone: 'Asia/Amman');
      expect(a.latitude, 31.9912);
      expect(a.longitude, 35.8712);
      expect(a.timeZone, 'Asia/Amman');
      expect(a.cityNameAr, 'عمّان');
      expect(a.locationSource, PrayerLocationSource.gps);
      final b = PrayerLocationChanges.applyFix(const PrayerSettings(), fix, nearest: nearest, deviceZone: 'Bogus/Zone');
      expect(b.timeZone, 'Asia/Amman');
      final c = PrayerLocationChanges.applyFix(const PrayerSettings(), fix);
      expect(c.timeZone, isNull);
      expect(c.cityId, isNull);
    });
  });

  group('persistence through the orbit repository', () {
    late MadarDatabase db;
    late SharedPreferences prefs;
    late ProviderContainer container;

    ProviderContainer make({LocationSource? source, DeviceTimeZoneSource? zones}) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeClockProvider.overrideWithValue(() => DateTime(2026, 9, 28, 14)),
          cityDatabaseProvider.overrideWith(
            (ref) async => CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync()),
          ),
          locationSourceProvider.overrideWithValue(source ?? FakeLocationSource()),
          deviceTimeZoneProvider.overrideWithValue(zones ?? FakeDeviceTimeZone(null)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = await openInMemoryMadarDatabase();
      container = make();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('controller writes KeyValues prayer.settings; the orbit schedule follows', () async {
      container.listen(prayerSettingsControllerProvider, (_, _) {});
      container.listen(prayerScheduleProvider, (_, _) {});
      await settle();
      final c = container.read(prayerSettingsControllerProvider.notifier);
      await c.setMethod(PrayerMethod.egyptian);
      await c.setHanafiAsr(true);
      await c.setAdjustment('isha', 4);
      await c.setHijriOffset(1);
      await settle();

      final stored = await container.read(orbitRepositoryProvider).prayerSettings();
      expect(stored.method, PrayerMethod.egyptian);
      expect(stored.hanafiAsr, isTrue);
      expect(stored.adjustmentsMin, {'isha': 4});
      expect(stored.hijriOffsetDays, 1);
      final raw = await container
          .read(orbitRepositoryProvider)
          .repos
          .keyValues
          .getJson(OrbitRepository.prayerSettingsKey);
      expect((raw as Map)['method'], 'egyptian');
      expect(container.read(prayerScheduleProvider).settings.method, PrayerMethod.egyptian);
      expect(container.read(prayerSettingsControllerProvider), stored);
    });

    test('fast successive edits never lose a step', () async {
      container.listen(prayerSettingsControllerProvider, (_, _) {});
      await settle();
      final c = container.read(prayerSettingsControllerProvider.notifier);
      final futures = [
        for (var i = 1; i <= 5; i++)
          c.update((s) => PrayerSettingsChanges.adjustment(s, 'fajr', (s.adjustmentsMin['fajr'] ?? 0) + 1)),
      ];
      await Future.wait(futures);
      await settle();
      expect(container.read(prayerSettingsControllerProvider).adjustmentsMin['fajr'], 5);
      expect((await container.read(orbitRepositoryProvider).prayerSettings()).adjustmentsMin['fajr'], 5);
    });

    test('a failed write does not leave an unsaved change on screen', () async {
      final failing = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeClockProvider.overrideWithValue(() => DateTime(2026, 9, 28, 14)),
          orbitRepositoryProvider.overrideWith((ref) => _FailingOrbitRepository(ref.watch(repositoriesProvider))),
        ],
      );
      addTearDown(failing.dispose);
      failing.listen(prayerSettingsControllerProvider, (_, _) {});
      await settle();
      final c = failing.read(prayerSettingsControllerProvider.notifier);
      await expectLater(c.setClock24h(true), throwsA(isA<StateError>()));
      expect(failing.read(prayerSettingsControllerProvider).clock24h, isFalse);
    });

    test('restore() undoes a change', () async {
      container.listen(prayerSettingsControllerProvider, (_, _) {});
      await settle();
      final c = container.read(prayerSettingsControllerProvider.notifier);
      final before = await c.setClock24h(true);
      expect(container.read(prayerSettingsControllerProvider).clock24h, isTrue);
      await c.restore(before);
      await settle();
      expect((await container.read(orbitRepositoryProvider).prayerSettings()).clock24h, isFalse);
    });

    test('location flow: granted → located, named after the nearest city', () async {
      final source = FakeLocationSource(fix: const GeoFix(latitude: 32.07, longitude: 36.09));
      final zones = FakeDeviceTimeZone('Asia/Amman');
      final c = make(source: source, zones: zones);
      c.listen(locationFlowProvider, (_, _) {});
      c.listen(prayerSettingsControllerProvider, (_, _) {});
      await settle();
      await c.read(locationFlowProvider.notifier).start();
      final state = c.read(locationFlowProvider);
      expect(state.stage, LocationFlowStage.located);
      expect(state.nearest?.city.id, 'jo-zarqa');
      await settle();
      final stored = await c.read(orbitRepositoryProvider).prayerSettings();
      expect(stored.locationSource, PrayerLocationSource.gps);
      expect(stored.cityId, 'jo-zarqa');
      expect(stored.timeZone, 'Asia/Amman');
      expect(source.requests, 0, reason: 'already granted: no dialog');
    });

    test('location flow: rationale → request denied → deniedForever → settings → granted', () async {
      final source = FakeLocationSource(
        access: LocationAccess.denied,
        afterRequest: LocationAccess.denied,
        fix: const GeoFix(latitude: 21.42, longitude: 39.83),
      );
      final c = make(source: source);
      c.listen(locationFlowProvider, (_, _) {});
      c.listen(prayerSettingsControllerProvider, (_, _) {});
      final flow = c.read(locationFlowProvider.notifier);
      await flow.start();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.rationale);
      await flow.allow();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.denied);
      expect(source.requests, 1);

      source.afterRequest = LocationAccess.deniedForever;
      await flow.allow();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.deniedForever);
      await flow.openAppSettings();
      expect(source.openedAppSettings, 1);

      // The user grants it in the system settings and comes back.
      source.access = LocationAccess.granted;
      await flow.recheck();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.located);
      await settle();
      final stored = await c.read(orbitRepositoryProvider).prayerSettings();
      expect(stored.cityId, 'sa-makkah');
      expect(stored.timeZone, 'Asia/Riyadh', reason: 'no device zone: the nearest city\'s');
    });

    test('clock-keyed providers are released: no entry per rebuild', () async {
      // The settings screen and HijriDateText key hijriDateProvider by the
      // clock at build time; a kept-alive family would grow on every rebuild.
      container.listen(prayerSettingsControllerProvider, (_, _) {});
      await settle();
      final base = DateTime.utc(2026, 9, 28, 11);
      for (var i = 0; i < 30; i++) {
        final at = base.add(Duration(seconds: i));
        final sub = container.listen(hijriDateProvider(at), (_, _) {});
        final day = container.listen(prayerTimesDayProvider(DateTime(2026, 9, 1 + i)), (_, _) {});
        expect(sub.read().month, 4);
        sub.close();
        day.close();
      }
      await settle();
      for (var i = 0; i < 30; i++) {
        expect(container.exists(hijriDateProvider(base.add(Duration(seconds: i)))), isFalse);
        expect(container.exists(prayerTimesDayProvider(DateTime(2026, 9, 1 + i))), isFalse);
      }
    });

    test('location flow: services off, unsupported and failures', () async {
      final source = FakeLocationSource(access: LocationAccess.serviceDisabled);
      final c = make(source: source);
      c.listen(locationFlowProvider, (_, _) {});
      final flow = c.read(locationFlowProvider.notifier);
      await flow.start();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.serviceDisabled);
      await flow.openLocationSettings();
      expect(source.openedLocationSettings, 1);

      source.access = LocationAccess.unsupported;
      flow.reset();
      await flow.start();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.unsupported);

      source
        ..access = LocationAccess.granted
        ..failure = const LocationFailure(null, 'timeout');
      flow.reset();
      await flow.start();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.failed);

      source.failure = const LocationFailure(LocationAccess.serviceDisabled);
      flow.reset();
      await flow.start();
      expect(c.read(locationFlowProvider).stage, LocationFlowStage.serviceDisabled);
    });
  });
}

class _FailingOrbitRepository extends OrbitRepository {
  _FailingOrbitRepository(super.repos);

  @override
  Future<void> setPrayerSettings(PrayerSettings settings) async => throw StateError('disk full');
}
