import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import '../../domain/scene_math.dart';
import 'sky_flare.dart';
import 'sky_model.dart';
import 'sky_view.dart';
import 'star_field.dart';

/// Per-viewport derived values of the sky (camera, moon and sun on screen),
/// cached by [SkyController.frameFor].
class SkyFrame {
  SkyFrame._({
    required this.size,
    required this.camera,
    required this.moonCenter,
    required this.moonRadius,
    required this.moonLight,
    required this.moonVisibility,
    required this.sunScreen,
  });

  final Size size;
  final SkyCamera camera;

  /// Moon disc centre (logical px) when above the horizon and in view.
  final Offset? moonCenter;
  final double moonRadius;

  /// moon.frag light vector (x right, y up, z toward the viewer).
  final V3 moonLight;

  /// 0..1 fade of the moon near the horizon.
  final double moonVisibility;

  /// Sun screen position (may be off screen), null behind the camera.
  final Offset? sunScreen;
}

/// The living sky's animated state, advanced by the scene's single ticker
/// ([advance]); painters listen to it, so nothing rebuilds per frame.
///
/// Inputs: [time] (real instant), [observer], [tone] (theme), the orbit
/// [camera] (its azimuth drives a slow 0.12× parallax rotation), [zoom]
/// (fly-in progress), [gyro] (degrees of yaw / pitch parallax), [coreStar]
/// and [pulse] for the lens flare.
///
/// Three repaint signals:
/// * the controller itself – every [advance] (twinkle, flare);
/// * [backdrop] – only when the sky's basis turns by more than 0.05°, the
///   sky state changes (≥ 1 s of sky time), or a still capture is due.
class SkyController extends ChangeNotifier {
  SkyController({
    DateTime? time,
    this._observer = SkyObserver.amman,
    this._tone,
    this._camera = const OrbitCamera(),
    this._composition = const SkyComposition(),
    this.clock,
    this.clockStep = const Duration(seconds: 10),
    this._showStarNames = true,
    double initialSeconds = 0,
  }) : _time = time ?? clock?.call() ?? DateTime.now(),
       _seconds = initialSeconds {
    final t = _tone;
    if (t != null) stars.tint = t.starTint;
    _recompute();
  }

  /// When set, [advance] follows this clock every [clockStep].
  final DateTime Function()? clock;
  final Duration clockStep;

  /// The catalogue prepared for the atlas (shared by the star painter).
  final StarField stars = StarField();

  /// Star-name label placement.
  final StarNames names = StarNames();

  final _Signal _backdrop = _Signal();

  /// Repaint signal of the backdrop (sky pass, moon, star names).
  Listenable get backdrop => _backdrop;

  // --- inputs -----------------------------------------------------------------

  DateTime _time;
  DateTime get time => _time;
  set time(DateTime value) {
    if (value == _time) return;
    final big = (value.difference(_stateTime).inMilliseconds).abs() >= 1000;
    _time = value;
    if (big) _recompute();
  }

  SkyObserver _observer;
  SkyObserver get observer => _observer;
  set observer(SkyObserver value) {
    if (value == _observer) return;
    _observer = value;
    _recompute();
  }

  SkyTone? _tone;
  SkyTone? get tone => _tone;
  set tone(SkyTone? value) {
    if (value == _tone) return;
    _tone = value;
    if (value != null) stars.tint = value.starTint;
    _recompute();
  }

  OrbitCamera _camera;
  OrbitCamera get camera => _camera;
  set camera(OrbitCamera value) {
    if (_sameCamera(value, _camera)) return;
    _camera = value;
    _inputsChanged();
  }

  static bool _sameCamera(OrbitCamera a, OrbitCamera b) =>
      identical(a, b) ||
      (a.azimuth == b.azimuth &&
          a.elevation == b.elevation &&
          a.roll == b.roll &&
          a.distance == b.distance &&
          a.fovY == b.fovY &&
          a.principal == b.principal &&
          a.target.x == b.target.x &&
          a.target.y == b.target.y &&
          a.target.z == b.target.z);

  double _zoom = 0;

  /// Fly-in progress 0 (whole system) … 1 (a world fills the screen).
  double get zoom => _zoom;
  set zoom(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v == _zoom) return;
    _zoom = v;
    _inputsChanged();
  }

  Offset _gyro = Offset.zero;

  /// Gyroscope parallax in degrees (yaw, pitch); clamped to a few degrees.
  Offset get gyro => _gyro;
  set gyro(Offset value) {
    if (value == _gyro) return;
    _gyro = value;
    _inputsChanged();
  }

  SkyComposition _composition;
  SkyComposition get composition => _composition;
  set composition(SkyComposition value) {
    if (value == _composition) return;
    _composition = value;
    _inputsChanged();
  }

  bool _showStarNames;

  /// Engraved star names (brightest stars, at night, zoomed out).
  bool get showStarNames => _showStarNames;
  set showStarNames(bool value) {
    if (value == _showStarNames) return;
    _showStarNames = value;
    _inputsChanged(force: true);
  }

  bool _arabicNames = true;

  /// Arabic (default) or English star names.
  bool get arabicNames => _arabicNames;
  set arabicNames(bool value) {
    if (value == _arabicNames) return;
    _arabicNames = value;
    _inputsChanged(force: true);
  }

  Rect? _labelKeepOut;

  /// Star names never sit inside this rect (the astrolabe), local px.
  Rect? get labelKeepOut => _labelKeepOut;
  set labelKeepOut(Rect? value) {
    if (value == _labelKeepOut) return;
    _labelKeepOut = value;
    _inputsChanged(force: true);
  }

  bool _reducedMotion = false;

  /// Reduced motion: no twinkle, the sky holds still.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    notifyListeners();
  }

  bool _still = false;

  /// Nothing animates the sky (no ticker: battery saver, reduced motion,
  /// tests): the backdrop is captured into an image on its first paint and
  /// stars stop twinkling.
  bool get still => _still;
  set still(bool value) {
    if (value == _still) return;
    _still = value;
    _backdrop.fire();
    notifyListeners();
  }

  Offset? _coreStar;

  /// Lens-flare source: the core star centre in the flare layer's local
  /// coordinates (provided by the integrator), or null for none.
  Offset? get coreStar => _coreStar;
  set coreStar(Offset? value) {
    if (value == _coreStar) return;
    _coreStar = value;
    notifyListeners();
  }

  double _pulse = 0;

  /// Core star celebration flare 0..1 (brightens the lens flare).
  double get pulse => _pulse;
  set pulse(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v == _pulse) return;
    _pulse = v;
    notifyListeners();
  }

  // --- derived ------------------------------------------------------------------

  SkyState? _state;
  DateTime _stateTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _stateVersion = 0;

  /// The sky at [time] (null until a [tone] is known).
  SkyState? get state => _state;

  /// Bumped whenever [state] is recomputed.
  int get stateVersion => _stateVersion;

  int _inputsVersion = 0;

  /// Bumped when anything that moves the sky on screen changes.
  int get inputsVersion => _inputsVersion;

  double _seconds;

  /// Shader clock (seconds) – twinkle phase; frozen under reduced motion.
  double get seconds => _seconds;

  /// Whether stars twinkle now.
  bool get twinkling => !_reducedMotion && !_still;

  double _angularSpeed = 0;

  /// Smoothed orbit-camera rotation speed (rad/s).
  double get angularSpeed => _angularSpeed;

  OrbitCamera? _lastCamera;

  /// Core-star flare strength now.
  double get coreFlareIntensity {
    final s = _state;
    if (_coreStar == null || s == null) return 0;
    return SkyFlares.coreIntensity(
      elevation: _camera.elevation,
      angularSpeed: _angularSpeed,
      pulse: _pulse,
      daylight: s.daylight,
      dark: s.dark,
      zoom: _zoom,
    );
  }

  Color _coreTint = const Color(0xFFFFD9A0);
  Color _sunTint = const Color(0xFFFFF0D2);

  /// Lens-flare tints (cached per theme / sky state).
  Color get coreFlareTint => _coreTint;
  Color get sunFlareTint => _sunTint;

  void _recompute() {
    final tone = _tone;
    if (tone == null) return;
    _state = SkyModel.compute(_time, observer: _observer, tone: tone);
    _coreTint = SkyFlares.coreTint(tone);
    _sunTint = SkyFlares.sunTint(_state!.sun.altitude);
    _stateTime = _time;
    _stateVersion++;
    _inputsChanged(force: true);
  }

  void _inputsChanged({bool force = false}) {
    _inputsVersion++;
    _frame = null;
    _checkBackdrop(force: force);
    notifyListeners();
  }

  // --- frame cache ----------------------------------------------------------

  SkyFrame? _frame;
  int _frameVersion = -1;

  /// Camera, moon and sun for the sky layer's viewport (cached until the
  /// inputs change). The size also becomes the viewport against which
  /// camera changes are measured for backdrop repaints.
  SkyFrame? frameFor(Size size) {
    final f = _frame;
    if (f != null && f.size == size && _frameVersion == _inputsVersion) return f;
    final frame = _computeFrame(size);
    if (frame == null) return null;
    _viewport = size;
    _frame = frame;
    _frameVersion = _inputsVersion;
    return frame;
  }

  /// Like [frameFor] for another layer's viewport (the flare layer): uses the
  /// cached frame when the size matches, otherwise computes one without
  /// caching it.
  SkyFrame? peekFrame(Size size) {
    final f = _frame;
    if (f != null && f.size == size && _frameVersion == _inputsVersion) return f;
    return _computeFrame(size);
  }

  SkyFrame? _computeFrame(Size size) {
    final s = _state;
    if (s == null || size.isEmpty) return null;
    final cam = SkyView.camera(s, size, orbit: _camera, zoom: _zoom, gyro: _gyro, composition: _composition);
    Offset? moonC;
    var vis = 0.0;
    final moonR = moonRadiusFor(size);
    var light = const V3(0, 0, 1);
    if (s.moon.altitude > -1.2) {
      final p = cam.project(s.moonDir);
      if (p != null && (Offset.zero & size).inflate(moonR * 3).contains(p)) {
        moonC = p;
        vis = SkyModel.smoothstep(-1.2, 1.5, s.moon.altitude);
        light = SkyView.moonLight(s.moonPhaseAngle, SkyView.brightLimbDirection(cam, s.moonDir, s.sunDir));
      }
    }
    return SkyFrame._(
      size: size,
      camera: cam,
      moonCenter: moonC,
      moonRadius: moonR,
      moonLight: light,
      moonVisibility: vis,
      sunScreen: cam.project(s.sunDir),
    );
  }

  /// Apparent moon radius (artistic; the real 0.25° would be ~2 px).
  static double moonRadiusFor(Size size) => (size.shortestSide * 0.042).clamp(11.0, 34.0);

  // --- backdrop repaint / still capture ---------------------------------------

  Size? _viewport;
  SkyCamera? _paintedCamera;
  int _paintedState = -1;
  int _paintedInputs = -1;
  double _sinceChange = 0;
  bool _captureDue = false;
  int _captureEpoch = 0;

  /// Bumped when the backdrop has been steady long enough to be captured
  /// into an image (the painter then draws that image instead of running
  /// the sky shader every frame).
  int get captureEpoch => _captureEpoch;

  /// Called by the backdrop painter after painting with [frame].
  void notePaintedBackdrop(SkyFrame frame) {
    _paintedCamera = frame.camera;
    _paintedState = _stateVersion;
    _paintedInputs = _inputsVersion;
  }

  /// Whether the last painted backdrop still matches (within 0.05°).
  bool backdropMatches(SkyFrame frame) {
    if (_paintedState != _stateVersion) return false;
    final painted = _paintedCamera;
    if (painted == null) return false;
    return !frame.camera.differsFrom(painted, degrees: StarField.reprojectDegrees);
  }

  void _checkBackdrop({bool force = false}) {
    final size = _viewport;
    var changed = force || size == null || _paintedCamera == null || _paintedState != _stateVersion;
    if (!changed) {
      final f = _computeFrame(size);
      changed = f == null || f.camera.differsFrom(_paintedCamera, degrees: StarField.reprojectDegrees);
      if (f != null) {
        _frame = f;
        _frameVersion = _inputsVersion;
      }
    }
    if (changed && _paintedInputs != _inputsVersion) {
      _sinceChange = 0;
      _captureDue = true;
      _backdrop.fire();
    }
  }

  /// Advances the shader clock, follows [clock], tracks camera speed and
  /// schedules still captures; repaints listeners.
  void advance(Duration dt) => advanceSeconds(dt.inMicroseconds / 1e6);

  void advanceSeconds(double dt) {
    if (dt <= 0) return;
    if (!_reducedMotion && !_still) _seconds += dt;
    final c = clock;
    if (c != null) {
      _clockAcc += dt;
      if (_clockAcc >= clockStep.inMicroseconds / 1e6) {
        _clockAcc = 0;
        time = c();
      }
    }
    final last = _lastCamera;
    if (last != null) {
      var dAz = (_camera.azimuth - last.azimuth) % (2 * math.pi);
      if (dAz > math.pi) dAz -= 2 * math.pi;
      if (dAz < -math.pi) dAz += 2 * math.pi;
      final speed = (dAz.abs() + (_camera.elevation - last.elevation).abs()) / dt;
      final k = 1 - math.exp(-dt / 0.18);
      _angularSpeed += (speed - _angularSpeed) * k;
    }
    _lastCamera = _camera;
    _sinceChange += dt;
    if (_captureDue && _sinceChange >= 0.25) {
      _captureDue = false;
      _captureEpoch++;
      _backdrop.fire();
    }
    notifyListeners();
  }

  double _clockAcc = 0;

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
