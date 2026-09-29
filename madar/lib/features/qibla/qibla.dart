/// Qibla compass: a brass astrolabe that turns with the phone so its Kaaba
/// star-pointer and golden needle point to the qibla.
///
/// * Screens / widgets: [QiblaScreen], [QiblaCard], [QiblaDial].
/// * State: [QiblaCompassController] (plain Dart; sensors only while
///   running), [headingSourceProvider], [qiblaPlaceProvider],
///   [qiblaFixProvider], [qiblaClockProvider].
/// * Pure domain: [QiblaFix] / [QiblaPlace] (bearing + great-circle
///   distance for any coordinates), [TiltCompass], [HeadingEngine],
///   [CircularOneEuroFilter], [WorldMagneticModel] (WMM2025, pure Dart),
///   [CompassQualityMonitor], [SunGuide].
/// * Platform seam: [HeadingSource] ([SensorHeadingSource] over
///   sensors_plus through [MotionSensors]).
library;

export 'application/qibla_compass_controller.dart';
export 'application/qibla_providers.dart';
export 'data/sensor_heading_source.dart';
export 'domain/circular_filter.dart';
export 'domain/compass_math.dart';
export 'domain/compass_quality.dart';
export 'domain/heading.dart';
export 'domain/heading_engine.dart';
export 'domain/qibla_fix.dart';
export 'domain/sun_compass.dart';
export 'domain/tilt_compass.dart';
export 'domain/wmm.dart';
export 'presentation/qibla_card.dart';
export 'presentation/qibla_labels.dart';
export 'presentation/qibla_screen.dart';
export 'presentation/widgets/calibration_prompt.dart';
export 'presentation/widgets/qibla_dial.dart';
export 'presentation/widgets/qibla_dial_painter.dart';
