/// Prayer times, location, calculation settings and the Hijri date.
///
/// * Screens: [PrayerTimesScreen], [PrayerSettingsScreen]; sheets:
///   [showPrayerLocationSheet], [showCityPickerSheet], [showMethodSheet].
/// * State: [prayerSettingsControllerProvider] (writes KeyValues
///   `prayer.settings` through the orbit repository), [locationFlowProvider],
///   [cityDatabaseProvider], [prayerLiveScheduleProvider],
///   [prayerTimesDayProvider], [hijriDateProvider].
/// * Pure domain: [PrayerSchedule] / [PrayerSettings] / [PrayerMethod]
///   (lib/features/orbit/domain/prayer_schedule.dart), [PrayerTimesDay],
///   [HijriCalendarMath], [QiblaMath], [CityDatabase], [MadarTimeZones],
///   [PrayerClockFormat].
library;

export '../orbit/domain/prayer_schedule.dart';
export 'application/location_flow.dart';
export 'application/prayer_providers.dart';
export 'application/prayer_settings_controller.dart';
export 'data/device_location.dart';
export 'domain/cities.dart';
export 'domain/hijri.dart';
export 'domain/location.dart';
export 'domain/prayer_clock.dart';
export 'domain/prayer_day.dart';
export 'domain/qibla.dart';
export 'domain/settings_changes.dart';
export 'domain/time_zones.dart';
export 'presentation/adjustment_sheet.dart';
export 'presentation/location_sheet.dart';
export 'presentation/prayer_labels.dart';
export 'presentation/prayer_settings_screen.dart';
export 'presentation/prayer_times_screen.dart';
export 'presentation/widgets/prayer_widgets.dart';
