import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayer/application/prayer_providers.dart' show prayerClockProvider;
import '../../prayer/application/prayer_settings_controller.dart';
import '../data/sensor_heading_source.dart';
import '../domain/heading.dart';
import '../domain/qibla_fix.dart';

/// The live compass (sensors_plus). Override with a fake in tests.
final headingSourceProvider = Provider<HeadingSource>((ref) => SensorHeadingSource());

/// "Now" for the sun compass and the magnetic model's epoch.
final qiblaClockProvider = Provider<DateTime Function()>((ref) => ref.watch(prayerClockProvider));

/// The prayer location as a [QiblaPlace] (follows every location change).
final qiblaPlaceProvider = Provider<QiblaPlace>((ref) {
  final s = ref.watch(prayerSettingsControllerProvider);
  return QiblaPlace(
    latitude: s.latitude,
    longitude: s.longitude,
    nameAr: s.cityNameAr ?? s.cityName,
    nameEn: s.cityNameEn ?? s.cityName,
  );
});

/// The qibla from the prayer location (bearing, distance) – for cards and
/// summaries that need no sensors.
final qiblaFixProvider = Provider<QiblaFix>((ref) => QiblaFix.of(ref.watch(qiblaPlaceProvider)));
