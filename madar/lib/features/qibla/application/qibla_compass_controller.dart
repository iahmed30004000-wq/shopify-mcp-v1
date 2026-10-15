import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/compass_math.dart';
import '../domain/compass_quality.dart';
import '../domain/heading.dart';
import '../domain/qibla_fix.dart';
import '../domain/sun_compass.dart';
import '../domain/wmm.dart';

/// How the qibla is being shown.
enum QiblaMode {
  /// Waiting for the first compass reading.
  starting,

  /// Live compass (magnetometer + accelerometer, true north via the WMM).
  compass,

  /// Sun compass: point the phone at the sun.
  sun,

  /// Static bearing diagram (north up) with instructions.
  diagram,
}

/// The coarse state of the qibla compass (texts, modes, prompts). The dial
/// follows [QiblaCompassController.live] instead, which updates at the
/// sensor rate.
@immutable
class QiblaCompassState {
  const QiblaCompassState({
    required this.mode,
    required this.fix,
    required this.field,
    required this.sun,
    this.heading,
    this.quality = CompassQuality.unknown,
    this.unavailable,
    this.aligned = false,
    this.alignCount = 0,
    this.calibrationDismissed = false,
    this.calibratedCount = 0,
    this.holdFlat = false,
  });

  final QiblaMode mode;
  final QiblaFix fix;

  /// The World Magnetic Model at the place (declination, expected field).
  final GeomagneticField field;
  final SunGuide sun;

  /// True heading of the screen's forward direction (compass mode; whole
  /// degrees – the dial uses the live value).
  final double? heading;
  final CompassQuality quality;

  /// Why the compass is not in use (null when it works or the user chose
  /// another mode).
  final HeadingUnavailableReason? unavailable;

  /// Facing the qibla (±3°, released beyond ±5°).
  final bool aligned;

  /// Bumped each time an alignment should chime.
  final int alignCount;
  final bool calibrationDismissed;

  /// Bumped each time a calibration prompt resolves by itself.
  final int calibratedCount;

  /// The phone's top points at the ground: the heading is poorly defined.
  final bool holdFlat;

  double get declination => field.declination;

  /// The true bearing at the top of the screen: the heading, the sun (the
  /// user points at it) or north (the diagram).
  double? get facing => switch (mode) {
    QiblaMode.compass => heading,
    QiblaMode.sun => sun.azimuth,
    QiblaMode.starting || QiblaMode.diagram => null,
  };

  /// Signed turn to the qibla (degrees, positive = to the right); null when
  /// there is no reference direction.
  double? get turn {
    final f = facing;
    return f == null ? null : fix.turnFrom(f);
  }

  bool get showCalibration => mode == QiblaMode.compass && quality.needsCalibration && !calibrationDismissed;

  QiblaCompassState copyWith({
    QiblaMode? mode,
    QiblaFix? fix,
    GeomagneticField? field,
    SunGuide? sun,
    double? Function()? heading,
    CompassQuality? quality,
    HeadingUnavailableReason? Function()? unavailable,
    bool? aligned,
    int? alignCount,
    bool? calibrationDismissed,
    int? calibratedCount,
    bool? holdFlat,
  }) => QiblaCompassState(
    mode: mode ?? this.mode,
    fix: fix ?? this.fix,
    field: field ?? this.field,
    sun: sun ?? this.sun,
    heading: heading == null ? this.heading : heading(),
    quality: quality ?? this.quality,
    unavailable: unavailable == null ? this.unavailable : unavailable(),
    aligned: aligned ?? this.aligned,
    alignCount: alignCount ?? this.alignCount,
    calibrationDismissed: calibrationDismissed ?? this.calibrationDismissed,
    calibratedCount: calibratedCount ?? this.calibratedCount,
    holdFlat: holdFlat ?? this.holdFlat,
  );

  @override
  bool operator ==(Object other) =>
      other is QiblaCompassState &&
      other.mode == mode &&
      other.fix == fix &&
      other.field.declination == field.declination &&
      other.sun == sun &&
      other.heading == heading &&
      other.quality.accuracy == quality.accuracy &&
      other.quality.errorDeg.round() == quality.errorDeg.round() &&
      other.quality.needsCalibration == quality.needsCalibration &&
      other.quality.interference == quality.interference &&
      other.unavailable == unavailable &&
      other.aligned == aligned &&
      other.alignCount == alignCount &&
      other.calibrationDismissed == calibrationDismissed &&
      other.calibratedCount == calibratedCount &&
      other.holdFlat == holdFlat;

  @override
  int get hashCode => Object.hash(mode, fix, sun, heading, quality.accuracy, unavailable, aligned, alignCount);
}

/// The live pose for the dial (sensor rate).
@immutable
class QiblaLive {
  const QiblaLive({this.facing, this.pitch = 0, this.roll = 0});

  /// True bearing at the top of the screen, null = north up (diagram).
  final double? facing;
  final double pitch, roll;

  @override
  bool operator ==(Object other) =>
      other is QiblaLive && other.facing == facing && other.pitch == pitch && other.roll == roll;

  @override
  int get hashCode => Object.hash(facing, pitch, roll);
}

/// Drives the qibla compass: listens to a [HeadingSource] only while
/// running, applies the World Magnetic Model's declination, estimates the
/// accuracy, detects alignment with hysteresis and falls back to the sun
/// (or a static diagram) when there is no usable compass.
class QiblaCompassController {
  QiblaCompassController({
    required HeadingSource source,
    required QiblaPlace place,
    required DateTime Function() clock,
    WorldMagneticModel? model,
    this.firstReadingTimeout = const Duration(seconds: 3),
    this.sunRefresh = const Duration(seconds: 30),
    bool batterySaver = false,
    bool landscape = false,
  }) : _headingSource = source,
       _now = clock,
       _model = model ?? WorldMagneticModel.wmm2025,
       _saver = batterySaver,
       _isLandscape = landscape {
    final fix = QiblaFix.of(place);
    final field = _fieldAt(place);
    _monitor = CompassQualityMonitor(expected: field);
    state = ValueNotifier(QiblaCompassState(mode: QiblaMode.starting, fix: fix, field: field, sun: _sunAt(place)));
  }

  /// Alignment enters within ±[alignEnter]° and releases beyond ±[alignExit]°.
  static const double alignEnter = 3;
  static const double alignExit = 5;

  /// Minimum time between two alignment chimes.
  static const Duration chimeGap = Duration(milliseconds: 1500);

  /// Minimum sensor time between two heading-only state updates.
  static const Duration headingPublishGap = Duration(milliseconds: 80);

  final HeadingSource _headingSource;
  final DateTime Function() _now;
  final WorldMagneticModel _model;
  final Duration firstReadingTimeout;
  final Duration sunRefresh;
  bool _saver;
  bool _isLandscape;

  late final ValueNotifier<QiblaCompassState> state;
  final ValueNotifier<QiblaLive> live = ValueNotifier(const QiblaLive());
  late CompassQualityMonitor _monitor;

  StreamSubscription<HeadingReading>? _sub;
  Timer? _watchdog;
  Timer? _sunTimer;
  bool _running = false;
  bool _userChoseOther = false;
  bool _gotReading = false;
  DateTime? _lastChime;
  Duration? _lastHeadingPublish;
  bool _disposed = false;

  QiblaCompassState get value => state.value;

  GeomagneticField _fieldAt(QiblaPlace p) => _model.fieldAt(p.latitude, p.longitude, _now(), altitudeKm: p.altitudeKm);

  SunGuide _sunAt(QiblaPlace p) => SunGuide.at(_now(), latitude: p.latitude, longitude: p.longitude);

  /// Starts (or restarts) listening and the sun clock.
  void start() {
    if (_disposed || _running) return;
    _running = true;
    _sunTimer = Timer.periodic(sunRefresh, (_) => _refreshSun());
    _refreshSun();
    if (!_userChoseOther && value.unavailable == null) _subscribe();
    if (_userChoseOther || value.unavailable != null) _publishLive();
  }

  /// Stops the sensors and timers (app in the background, route covered).
  void pause() {
    if (!_running) return;
    _running = false;
    _unsubscribe();
    _sunTimer?.cancel();
    _sunTimer = null;
  }

  /// Moves the compass to another place (prayer location changed, or a
  /// travel destination).
  void setPlace(QiblaPlace place) {
    final old = value.fix.place;
    if (place == old) return;
    if (place.latitude == old.latitude && place.longitude == old.longitude && place.altitudeKm == old.altitudeKm) {
      // Only the name changed (e.g. the city names arriving from storage).
      state.value = value.copyWith(fix: QiblaFix.of(place));
      return;
    }
    final field = _fieldAt(place);
    _monitor = CompassQualityMonitor(expected: field);
    // Alignment is re-evaluated on the next reading.
    state.value = value.copyWith(fix: QiblaFix.of(place), field: field, sun: _sunAt(place), aligned: false);
    _publishLive();
  }

  /// Battery saver lowers the sensor rate.
  void setBatterySaver(bool on) {
    if (on == _saver) return;
    _saver = on;
    _resubscribe();
  }

  /// The display rotation changed.
  void setLandscape(bool landscape) {
    if (landscape == _isLandscape) return;
    _isLandscape = landscape;
    _resubscribe();
  }

  /// Switches to the sun compass (or the diagram when the sun is down).
  void useSun() {
    _userChoseOther = true;
    _unsubscribe();
    final sun = _sunAt(value.fix.place);
    state.value = value.copyWith(
      mode: sun.usable ? QiblaMode.sun : QiblaMode.diagram,
      sun: sun,
      heading: () => null,
      aligned: false,
    );
    _publishLive();
  }

  /// Back to (or retry) the live compass.
  void useCompass() {
    _userChoseOther = false;
    state.value = value.copyWith(
      mode: QiblaMode.starting,
      unavailable: () => null,
      heading: () => null,
      aligned: false,
      calibrationDismissed: false,
    );
    _monitor.reset();
    _publishLive();
    if (_running) _subscribe();
  }

  /// Shows the figure-eight prompt again (after [dismissCalibration]).
  void requestCalibration() {
    if (!value.calibrationDismissed) return;
    state.value = value.copyWith(calibrationDismissed: false);
  }

  /// Hides the figure-eight prompt until the next calibration episode.
  void dismissCalibration() {
    if (value.calibrationDismissed) return;
    state.value = value.copyWith(calibrationDismissed: true);
  }

  void dispose() {
    _disposed = true;
    pause();
    state.dispose();
    live.dispose();
  }

  // ------------------------------------------------------------ internals

  void _resubscribe() {
    if (_sub == null) return;
    _unsubscribe();
    _subscribe();
  }

  void _subscribe() {
    _unsubscribe();
    _gotReading = false;
    _watchdog = Timer(firstReadingTimeout, _onTimeout);
    _sub = _headingSource
        .readings(landscape: _isLandscape, batterySaver: _saver)
        .listen(_onReading, onError: _onError, onDone: () => _sub = null);
  }

  void _unsubscribe() {
    _watchdog?.cancel();
    _watchdog = null;
    final s = _sub;
    _sub = null;
    if (s != null) unawaited(s.cancel());
  }

  void _onTimeout() {
    _watchdog = null;
    if (_gotReading || _disposed) return;
    // Keep listening: a late first reading switches back to the compass.
    _fallBack(HeadingUnavailableReason.noReadings);
  }

  void _onError(Object error) {
    if (_disposed) return;
    _unsubscribe();
    _fallBack(error is HeadingUnavailable ? error.reason : HeadingUnavailableReason.sensorError);
  }

  void _fallBack(HeadingUnavailableReason reason) {
    final sun = _sunAt(value.fix.place);
    state.value = value.copyWith(
      mode: sun.usable ? QiblaMode.sun : QiblaMode.diagram,
      sun: sun,
      unavailable: () => reason,
      heading: () => null,
      aligned: false,
    );
    _publishLive();
  }

  void _refreshSun() {
    if (_disposed) return;
    final sun = _sunAt(value.fix.place);
    var mode = value.mode;
    // The fallback follows the sun rising and setting.
    if (mode == QiblaMode.sun && !sun.usable) mode = QiblaMode.diagram;
    if (mode == QiblaMode.diagram && sun.usable) mode = QiblaMode.sun;
    state.value = value.copyWith(sun: sun, mode: mode);
    if (mode != QiblaMode.compass) _publishLive();
  }

  void _onReading(HeadingReading r) {
    if (_disposed) return;
    _gotReading = true;
    _watchdog?.cancel();
    _watchdog = null;
    final s = value;
    final heading = CircularMath.wrap360(r.heading + s.declination);
    final quality = _monitor.update(r);
    live.value = QiblaLive(facing: heading, pitch: r.pitch, roll: r.roll);

    final turn = s.fix.turnFrom(heading).abs();
    var aligned = s.aligned;
    var alignCount = s.alignCount;
    final canAlign = !s.fix.atKaaba && quality.accuracy != CompassAccuracy.unreliable;
    if (!aligned && canAlign && turn <= alignEnter) {
      aligned = true;
      final now = _now();
      if (_lastChime == null || now.difference(_lastChime!).abs() >= chimeGap) {
        _lastChime = now;
        alignCount++;
      }
    } else if (aligned && (turn > alignExit || !canAlign)) {
      aligned = false;
    }

    final wasNeeding = s.quality.needsCalibration;
    var dismissed = s.calibrationDismissed;
    var calibrated = s.calibratedCount;
    if (!wasNeeding && quality.needsCalibration) dismissed = false;
    if (wasNeeding && !quality.needsCalibration && s.mode == QiblaMode.compass) calibrated++;

    final next = s.copyWith(
      mode: QiblaMode.compass,
      unavailable: () => null,
      heading: () => heading.roundToDouble() % 360,
      quality: quality,
      aligned: aligned,
      alignCount: alignCount,
      calibrationDismissed: dismissed,
      calibratedCount: calibrated,
      // With hysteresis: on below 0.45, off above 0.6.
      holdFlat: s.holdFlat ? r.pointing < 0.6 : r.pointing < 0.45,
    );
    // The texts need the heading only a dozen times a second (the dial
    // follows [live] at the sensor rate); every other change goes out at
    // once.
    if (next.heading != s.heading && next == s.copyWith(heading: () => next.heading)) {
      final last = _lastHeadingPublish;
      final t = r.timestamp;
      if (last != null && t >= last && t - last < headingPublishGap) return;
      _lastHeadingPublish = t;
    }
    state.value = next;
  }

  /// Publishes the dial pose for the modes without sensor readings (the
  /// compass publishes its own from each reading).
  void _publishLive() {
    final s = value;
    if (s.mode == QiblaMode.compass) return;
    live.value = QiblaLive(facing: s.mode == QiblaMode.sun ? s.sun.azimuth : null);
  }
}
