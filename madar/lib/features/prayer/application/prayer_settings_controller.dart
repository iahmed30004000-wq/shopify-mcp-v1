import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orbit/data/orbit_providers.dart' show orbitRepositoryProvider, prayerSettingsProvider;
import '../../orbit/domain/prayer_schedule.dart';
import '../domain/cities.dart';
import '../domain/location.dart';
import '../domain/settings_changes.dart';

/// Reads and writes the prayer settings (KeyValues `prayer.settings`,
/// encrypted) through the orbit repository – the same path
/// `prayerSettingsProvider` / `prayerScheduleProvider` watch, so the orbit,
/// home, tracker and adhan follow every change.
///
/// The state updates at once (optimistically) and stream updates from the
/// database are ignored while writes are in flight, so quick successive
/// edits (a stepper tapped fast) never lose a step.
class PrayerSettingsController extends Notifier<PrayerSettings> {
  int _pending = 0;

  @override
  PrayerSettings build() {
    ref.listen<AsyncValue<PrayerSettings>>(prayerSettingsProvider, (_, next) {
      final v = next.value;
      if (v != null && _pending == 0 && v != state) state = v;
    });
    return ref.read(prayerSettingsProvider).value ?? const PrayerSettings();
  }

  /// Applies [change] and persists the result. Returns the settings before
  /// the change (for undo).
  Future<PrayerSettings> update(PrayerSettings Function(PrayerSettings s) change) async {
    final before = state;
    final next = change(before);
    if (next == before) return before;
    state = next;
    _pending++;
    try {
      await ref.read(orbitRepositoryProvider).setPrayerSettings(next);
    } catch (_) {
      // Not saved: show what is stored again rather than a change that
      // would vanish on the next launch.
      if (ref.mounted && state == next) state = before;
      rethrow;
    } finally {
      _pending--;
    }
    return before;
  }

  /// Restores [previous] (undo).
  Future<void> restore(PrayerSettings previous) => update((_) => previous);

  Future<PrayerSettings> setMethod(PrayerMethod method) => update((s) => PrayerSettingsChanges.method(s, method));

  Future<PrayerSettings> setFajrAngle(double degrees) => update((s) => PrayerSettingsChanges.fajrAngle(s, degrees));

  Future<PrayerSettings> setIshaAngle(double degrees) => update((s) => PrayerSettingsChanges.ishaAngle(s, degrees));

  Future<PrayerSettings> setIshaInterval(int? minutes) => update((s) => PrayerSettingsChanges.ishaInterval(s, minutes));

  Future<PrayerSettings> setHanafiAsr(bool hanafi) => update((s) => PrayerSettingsChanges.hanafiAsr(s, hanafi));

  Future<PrayerSettings> setHighLatitude(HighLatitudeMode mode) =>
      update((s) => PrayerSettingsChanges.highLatitude(s, mode));

  Future<PrayerSettings> setAdjustment(String key, int minutes) =>
      update((s) => PrayerSettingsChanges.adjustment(s, key, minutes));

  Future<PrayerSettings> resetAdjustments() => update(PrayerSettingsChanges.resetAdjustments);

  Future<PrayerSettings> setHijriOffset(int days) => update((s) => PrayerSettingsChanges.hijriOffset(s, days));

  Future<PrayerSettings> setHijriAtMaghrib(bool value) => update((s) => PrayerSettingsChanges.hijriAtMaghrib(s, value));

  Future<PrayerSettings> setClock24h(bool value) => update((s) => PrayerSettingsChanges.clock24h(s, value));

  /// Uses [city] of the offline list (its coordinates, names and zone).
  Future<PrayerSettings> setCity(City city) => update((s) => PrayerLocationChanges.pickCity(s, city));

  /// Uses a GPS [fix], named after [nearest], in [deviceZone] (or the
  /// nearest city's zone).
  Future<PrayerSettings> setFix(GeoFix fix, {NearestCity? nearest, String? deviceZone}) =>
      update((s) => PrayerLocationChanges.applyFix(s, fix, nearest: nearest, deviceZone: deviceZone));
}

/// The editable prayer settings (see [PrayerSettingsController]).
final prayerSettingsControllerProvider = NotifierProvider<PrayerSettingsController, PrayerSettings>(
  PrayerSettingsController.new,
);
