import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:flutter/animation.dart' show Animation;
import 'package:flutter/foundation.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/motion/motion.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_pulse.dart';
import '../../domain/scene_math.dart';
import '../../domain/scene_snapshot.dart';
import '../../render/astrolabe/astrolabe_controller.dart';
import '../../render/astrolabe/astrolabe_geometry.dart';
import '../../render/astrolabe/astrolabe_state.dart';
import '../../render/planets/planet_body.dart';
import '../../render/planets/planet_frame.dart';
import '../../render/planets/planet_scene_controller.dart';
import '../../render/sky/sky_controller.dart';
import '../../render/sky/sky_model.dart' show SkyObserver;
import '../../render/sky/sky_view.dart' show SkyComposition;
import 'adaptive_quality.dart';
import 'camera_rig.dart';
import 'flight.dart';
import 'gyro_parallax.dart';
import 'scene_composition.dart';
import 'scene_governor.dart';

/// What a touch on the orbit landed on.
enum SceneHitKind { planet, moon, prayer, core }

/// A hit on the orbit scene (scene-local coordinates).
@immutable
class SceneHit {
  const SceneHit.planet(String this.planetKey, this.rect) : kind = SceneHitKind.planet, moon = null, prayer = null;
  const SceneHit.moon(String this.planetKey, OrbitMoon this.moon, this.rect) : kind = SceneHitKind.moon, prayer = null;
  const SceneHit.prayer(Prayer this.prayer, this.rect) : kind = SceneHitKind.prayer, planetKey = null, moon = null;
  const SceneHit.core(this.rect) : kind = SceneHitKind.core, planetKey = null, moon = null, prayer = null;

  final SceneHitKind kind;
  final String? planetKey;
  final OrbitMoon? moon;
  final Prayer? prayer;

  /// Screen rect of what was hit (burst origin, zoom origin …).
  final Rect rect;

  @override
  bool operator ==(Object other) =>
      other is SceneHit &&
      other.kind == kind &&
      other.planetKey == planetKey &&
      other.moon?.id == moon?.id &&
      other.prayer == prayer;

  @override
  int get hashCode => Object.hash(kind, planetKey, moon?.id, prayer);

  @override
  String toString() => switch (kind) {
    SceneHitKind.planet => 'SceneHit(planet $planetKey)',
    SceneHitKind.moon => 'SceneHit(moon ${moon!.id} of $planetKey)',
    SceneHitKind.prayer => 'SceneHit(prayer ${prayer!.name})',
    SceneHitKind.core => 'SceneHit(core)',
  };
}

/// The Astrolabe Orbit's brain (no widgets, no ticker – unit-tested): it
/// owns the three render controllers (sky, planets, astrolabe), composes the
/// camera every frame (overview framing → user turn/tilt/pinch → drift and
/// gyro parallax → fly-in), places the astrolabe billboard on the core star,
/// derives the fly-in's depth of field / motion blur, and answers hit tests
/// with the correct depth order (a world behind the dial cannot be tapped
/// through the brass).
///
/// The scene widget calls [layout] with its size and the free band above
/// the glass panel, pushes data ([setPlanets], [setAstrolabeState]), binds
/// the route animation of a planet page ([bindFlight]) and calls [tick] from
/// its single ticker.
class SceneController extends ChangeNotifier {
  SceneController({
    this.composition = const OrbitComposition(),
    double initialTime = 12,
    DateTime? now,
    SkyObserver observer = SkyObserver.amman,
  }) : planets = PlanetSceneController(
         layout: composition.layout,
         initialTime: initialTime,
         coreRadius: composition.coreRadius,
       ),
       astrolabe = AstrolabeController(initialTime: initialTime),
       sky = SkyController(time: now ?? DateTime.now(), observer: observer, initialSeconds: initialTime);

  final OrbitComposition composition;
  final PlanetSceneController planets;
  final AstrolabeController astrolabe;
  final SkyController sky;

  final CameraRig rig = CameraRig();
  final GyroParallax gyro = GyroParallax();
  final SceneGovernor governor = SceneGovernor();
  final AdaptiveQuality quality = AdaptiveQuality();

  /// Maximum depth-of-field blur (sigma, logical px) at the end of a fly-in.
  static const double maxBlur = 6;

  /// How far (fraction of the height) the sky's horizon sits above the
  /// bottom of the scene band (≈ the glass panel's top edge).
  static const double horizonAbovePanel = 0.045;

  SkyComposition _restSky = const SkyComposition();

  /// The sky's framing at rest: its horizon just above the glass panel
  /// (the dawn / dusk glow shows right over the panel, never under it).
  SkyComposition get restSky => _restSky;

  // ------------------------------------------------------------------ layout --

  Size _viewport = Size.zero;
  Rect _sceneRect = Rect.zero;
  List<LaneBody> _lanes = const [];
  OrbitCamera _base = SceneCameras.initial;
  bool _baseDirty = true;

  Size get viewport => _viewport;
  Rect get sceneRect => _sceneRect;

  /// The fitted overview camera (before the user's turn, drift and gyro).
  OrbitCamera get baseCamera {
    _ensureBase();
    return _base;
  }

  /// The scene's size and the band ([sceneRect], same coordinates) the
  /// system must fit in (between the header and the glass panel).
  void layout(Size viewport, Rect sceneRect) {
    if (viewport == _viewport && sceneRect == _sceneRect) return;
    _viewport = viewport;
    _sceneRect = sceneRect;
    // Labels live in the band too: never under the header, never within
    // 12 px of the glass panel's top edge.
    planets.labelArea = sceneRect.isEmpty
        ? null
        : Rect.fromLTRB(0, sceneRect.top, viewport.width, math.max(sceneRect.top + 1, sceneRect.bottom - 4));
    if (!viewport.isEmpty && !sceneRect.isEmpty) {
      final horizon = (sceneRect.bottom / viewport.height - SceneController.horizonAbovePanel).clamp(0.4, 0.62);
      _restSky = SkyComposition(restHorizonY: horizon, twilightHorizonY: horizon);
    }
    _baseDirty = true;
    _apply();
  }

  void _ensureBase() {
    if (!_baseDirty) return;
    _baseDirty = false;
    if (_viewport.isEmpty) return;
    final next = composition.overview(viewport: _viewport, sceneRect: _sceneRect, lanes: _lanes);
    // The first framing (and a new screen size) applies at once; a changed
    // set of worlds reframes smoothly (see [tick]).
    final ease = _baseShown != null && _baseViewport == _viewport && !_reducedMotion;
    _base = next;
    if (ease) {
      _reframeFrom = _shown;
      _reframeT = 0;
    } else {
      _shown = next;
      _reframeT = 1;
    }
    _baseShown = true;
    _baseViewport = _viewport;
    _baseCoreRadius = composition.corePixels(_base, _viewport);
  }

  /// The framing on screen, easing toward [_base] after the worlds change.
  OrbitCamera _shown = SceneCameras.initial;
  bool? _baseShown;
  Size _baseViewport = Size.zero;

  OrbitCamera _reframeFrom = SceneCameras.initial;
  double _reframeT = 1;

  /// Seconds a reframing takes.
  static const double reframeSeconds = 0.7;

  bool get _reframing => _reframeT < 1;

  double _baseCoreRadius = 0;

  // -------------------------------------------------------------------- data --

  /// Pushes the snapshot's worlds (morphing unless [animate] is false).
  void setPlanets(List<OrbitPlanet> worlds, {bool animate = true}) =>
      setBodies([for (final p in worlds) PlanetBody.fromOrbitPlanet(p)], animate: animate);

  /// Pushes render-ready worlds (lane order).
  void setBodies(List<PlanetBody> bodies, {bool animate = true}) {
    planets.setBodies(bodies, animate: animate);
    final lanes = [for (final b in planets.bodies) (archetype: b.archetype, seed: b.seed)];
    if (!_sameLanes(lanes, _lanes)) {
      _lanes = lanes;
      _baseDirty = true;
    }
    _apply();
  }

  static bool _sameLanes(List<LaneBody> a, List<LaneBody> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].archetype != b[i].archetype || a[i].seed != b[i].seed) return false;
    }
    return true;
  }

  AstrolabeState? _astrolabeState;

  /// The dial's current state (the scene widget hands the same object to the
  /// astrolabe layer, so a rebuild never pushes a stale one).
  AstrolabeState? get astrolabeState => _astrolabeState;

  /// Pushes a new dial state (newly logged prayers ignite unless [animate]
  /// is false).
  void setAstrolabeState(AstrolabeState state, {bool animate = true}) {
    if (identical(state, _astrolabeState)) return;
    _astrolabeState = state;
    astrolabe.update(state, animate: animate);
  }

  // ---------------------------------------------------------------- settings --

  bool _reducedMotion = false;

  /// Reduced motion: a static scene (no drift, no parallax, frozen orbits),
  /// still fully interactive.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    planets.reducedMotion = value;
    astrolabe.reducedMotion = value;
    sky.reducedMotion = value;
    if (value) gyro.reset();
    _apply();
  }

  bool _gyroEnabled = true;

  /// Gyroscope parallax (off under reduced motion regardless).
  bool get gyroEnabled => _gyroEnabled && !_reducedMotion;
  set gyroEnabled(bool value) {
    _gyroEnabled = value;
    if (!gyroEnabled) gyro.reset();
  }

  // ------------------------------------------------------------------ flight --

  String? _flightKey;
  Animation<double>? _flight;
  int? _flightSide;
  double _flightT = 0;

  /// The world a planet page is open on (or flying to / from).
  String? get flightKey => _flightKey;

  /// Raw fly-in progress (the planet route's animation value).
  double get flightProgress => _flightT;

  /// A planet page opened on [key] (its route [animation] drives the fly-in
  /// forwards and the fly-out backwards); null ends the flight.
  void bindFlight(String? key, Animation<double>? animation) {
    if (key == _flightKey && identical(animation, _flight)) return;
    _flight = animation;
    if (key == null || animation == null) {
      _flightKey = null;
      _flightSide = null;
      _flightT = 0;
      planets.setFocus(null, 0);
      _apply();
      return;
    }
    if (key != _flightKey) {
      _flightKey = key;
      _flightSide = _sideFor(key, _userCamera());
    }
    _flightT = animation.value;
    _apply();
  }

  /// The route animation is running (full frame rate).
  bool get flightMoving => _flight?.isAnimating ?? false;

  int? _sideFor(String key, OrbitCamera from) {
    if (_viewport.isEmpty) return null;
    final framed = planets.framingCamera(key, from: from, viewport: _viewport, fill: composition.heroFill);
    final w = planets.worldOf(key);
    if (framed == null || w == null) return null;
    final plus = PlanetFraming.cameraFor(
      from: from,
      target: w.$1,
      worldRadius: w.$2,
      viewport: _viewport,
      fill: composition.heroFill,
      side: 1,
    );
    return (framed.azimuth - plus.azimuth).abs() < 1e-6 ? 1 : -1;
  }

  /// The camera at the end of a fly-in to [key], seen from [from]: the world
  /// fills most of the width, lit three-quarter, centred high on the screen
  /// (the module page rises below it). Tracks the world as it orbits.
  OrbitCamera? heroCamera(String key, {required OrbitCamera from}) {
    final w = planets.worldOf(key);
    if (w == null || _viewport.isEmpty) return null;
    _flightSide ??= key == _flightKey ? _sideFor(key, from) : null;
    return PlanetFraming.cameraFor(
      from: from.copyWith(principal: composition.heroPrincipalFor(_viewport)),
      target: w.$1,
      worldRadius: w.$2,
      viewport: _viewport,
      fill: composition.heroFill,
      side: key == _flightKey ? _flightSide : null,
    );
  }

  // ------------------------------------------------------------------ camera --

  OrbitCamera _camera = SceneCameras.initial;
  int? _zoomSide;
  String? _zoomSideKey;

  /// The camera rendered this frame.
  OrbitCamera get camera => _camera;

  OrbitCamera _userCamera() {
    _ensureBase();
    final gy = gyroEnabled ? gyro.yaw : 0.0, gp = gyroEnabled ? gyro.pitch : 0.0;
    return rig.user(_shown, gyroYaw: gy, gyroPitch: gp, drift: !_reducedMotion);
  }

  /// The pinch-zoom end camera for the rig's target, seen from [from].
  OrbitCamera? zoomCamera(OrbitCamera from) {
    final key = rig.zoomKey;
    if (key == null) {
      return from.copyWith(distance: from.distance / composition.coreZoomScale);
    }
    final w = planets.worldOf(key);
    if (w == null) return null;
    if (_zoomSideKey != key) {
      _zoomSideKey = key;
      final framed = planets.framingCamera(key, from: from, viewport: _viewport, fill: composition.zoomFill);
      final plus = PlanetFraming.cameraFor(
        from: from,
        target: w.$1,
        worldRadius: w.$2,
        viewport: _viewport,
        fill: composition.zoomFill,
        side: 1,
      );
      _zoomSide = framed == null ? null : ((framed.azimuth - plus.azimuth).abs() < 1e-6 ? 1 : -1);
    }
    return PlanetFraming.cameraFor(
      from: from.copyWith(principal: composition.zoomPrincipal),
      target: w.$1,
      worldRadius: w.$2,
      viewport: _viewport,
      fill: composition.zoomFill,
      side: _zoomSide,
    );
  }

  OrbitCamera _compose() {
    var cam = _userCamera();
    if (rig.zoom > 0) {
      final z = zoomCamera(cam);
      final key = rig.zoomKey;
      if (z != null) cam = key == null ? CameraPath.lerp(cam, z, rig.zoomEased) : _glide(cam, z, rig.zoomEased, key);
    } else {
      _zoomSideKey = null;
    }
    final key = _flightKey;
    // Reduced motion: the scene stays put (the page cross-fades over it).
    if (key != null && _flightT > 0 && !_reducedMotion) {
      final hero = heroCamera(key, from: cam) ?? _lastHero;
      if (hero != null) {
        _lastHero = hero;
        final c = FlightTiming.camera(_flightT);
        cam = _glide(cam, hero, c, key, lift: FlightTiming.arcLift(c));
      }
    } else if (key == null) {
      _lastHero = null;
    }
    return cam;
  }

  /// The last hero camera of the open flight: a world hidden while its page
  /// is open still flies out from where it was (no snap).
  OrbitCamera? _lastHero;

  /// [CameraPath.lerp] from [from] to [to] by [t] – raised by [lift]
  /// radians of elevation (the arc over the system) – with the lens shifted
  /// so the world [key] glides along a straight screen path from where it
  /// was to where it lands (it never swings out of frame on the way).
  OrbitCamera _glide(OrbitCamera from, OrbitCamera to, double t, String key, {double lift = 0}) {
    var cam = CameraPath.lerp(from, to, t);
    if (lift != 0 && t > 0 && t < 1) cam = cam.copyWith(elevation: cam.elevation + lift);
    if (t <= 0 || t >= 1 || _viewport.isEmpty) return cam;
    final w = planets.worldOf(key);
    if (w == null) return cam;
    final p0 = from.project(w.$1, _viewport), p1 = to.project(w.$1, _viewport), p = cam.project(w.$1, _viewport);
    if (!p0.visible || !p1.visible || !p.visible) return cam;
    final shift = Offset.lerp(p0.offset, p1.offset, t)! - p.offset;
    return cam.copyWith(principal: cam.principal + Offset(shift.dx / _viewport.width, shift.dy / _viewport.height));
  }

  // --------------------------------------------------------------- compositing --

  final _Signal _compositing = _Signal();

  /// Fires when the astrolabe box, its opacity / blur, the background blur
  /// or the motion blur change (the compositing render objects listen).
  Listenable get compositing => _compositing;

  Rect _coreRect = Rect.zero;
  Offset _coreCenter = Offset.zero;
  double _coreRadius = 0, _coreOpacity = 1, _coreBlur = 0, _backgroundBlur = 0, _motionBlur = 0;
  Offset? _motionCenter;

  /// The astrolabe's paint box (scene coordinates): centred on the core
  /// star, sized so its limb radius matches the projected dial.
  Rect get coreRect => _coreRect;

  double _coreLayoutSide = 0;

  /// Side the dial is laid out (and its engraving recorded) at: the paint
  /// box's own side, except during a flight, where it stays at its
  /// take-off size and [CoreAnchor] scales it to [coreRect].
  double get coreLayoutSide => _coreLayoutSide <= 0 ? _coreRect.width : _coreLayoutSide;
  Offset get coreCenter => _coreCenter;

  /// Limb radius of the astrolabe on screen (px).
  double get coreRadius => _coreRadius;

  /// The dial fades as a fly-in leaves it.
  double get coreOpacity => _coreOpacity;

  /// Blur (sigma) of the dial and of the background layers (depth of
  /// field while a world is in focus).
  double get coreBlur => _coreBlur;
  double get backgroundBlur => _backgroundBlur;

  /// Radial motion blur strength 0..1 around [motionCenter] (fly-ins).
  double get motionBlur => _motionBlur;
  Offset? get motionCenter => _motionCenter;

  void _apply() {
    if (_viewport.isEmpty) return;
    _ensureBase();
    final t = _flightKey == null ? 0.0 : _flightT;
    planets.setFocus(
      _flightKey,
      _flightKey == null ? 0 : FlightTiming.camera(t),
      labelsOut: _flightKey == null ? 0 : FlightTiming.labelsOut(t),
    );
    final selected = _flightKey ?? (rig.zoom > 0.05 ? rig.zoomKey : null);
    planets.selectedKey = selected;
    // Zoomed in: only the focused cluster keeps its names.
    planets.labelCluster = _flightKey == null && rig.zoom > 0.3 ? (rig.zoomKey ?? '') : null;
    final cam = _compose();
    _camera = cam;
    planets.camera = cam;

    final f = planets.frameFor(_viewport);
    // In a flight the dial may sweep past big in the foreground (it is
    // blurred and fading); otherwise it never outgrows the screen.
    final maxR = _viewport.width * (t > 0 ? 2.4 : 0.62);
    final r = math.min(f.coreRadius, maxR);
    final side = 2 * r * AstrolabeRadii.halo;
    final core = f.coreCenter;
    final rect = Rect.fromCenter(center: core, width: side, height: side);
    // The dial's paint box keeps the size it had when the flight began
    // (scaled on the GPU): no engraving is re-recorded mid-flight.
    if (t <= 0) {
      _coreLayoutSide = side;
    } else if (_coreLayoutSide <= 0) {
      _coreLayoutSide = side;
    }
    final dof = quality.depthOfField ? FlightTiming.depthOfField(t) : 0.0;
    final opacity = FlightTiming.astrolabe(t) * (f.coreRadius > 0 ? 1 : 0);
    final blur = maxBlur * dof;
    final motion = quality.motionBlur && !_reducedMotion ? FlightTiming.motionBlur(t) * 0.55 : 0.0;
    Offset? motionCenter;
    if (motion > 0 && _flightKey != null) motionCenter = f.body(_flightKey!)?.center;

    final changed =
        (rect.left - _coreRect.left).abs() > 0.05 ||
        (rect.top - _coreRect.top).abs() > 0.05 ||
        (rect.width - _coreRect.width).abs() > 0.05 ||
        (opacity - _coreOpacity).abs() > 0.002 ||
        (blur - _backgroundBlur).abs() > 0.01 ||
        (motion - _motionBlur).abs() > 0.002 ||
        motionCenter != _motionCenter;
    _coreRect = rect;
    _coreCenter = core;
    _coreRadius = r;
    _coreOpacity = opacity;
    _coreBlur = blur;
    _backgroundBlur = blur;
    _motionBlur = motion;
    _motionCenter = motionCenter;

    planets.coreOpacity = opacity;

    final skyPalette = sky.state?.palette;
    planets.skyAmbient = skyPalette == null ? null : Color.lerp(skyPalette.horizon, skyPalette.zenith, 0.45);

    final lift = FlightTiming.horizonLift(t);
    sky
      ..composition = lift <= 0
          ? _restSky
          : SkyComposition(
              restHorizonY: _restSky.restHorizonY + lift,
              twilightHorizonY: _restSky.twilightHorizonY + lift,
              moonAnchor: _restSky.moonAnchor,
            )
      ..camera = cam
      ..zoom = FlightTiming.camera(t) * 0.9 + rig.zoomEased * 0.35
      ..gyro = gyroEnabled ? gyro.degrees : Offset.zero
      ..coreStar = opacity > 0.05 ? core : null
      ..pulse = astrolabe.pulse
      ..labelKeepOut = _systemBounds(f, rect)
      ..showStarNames = quality.starNames && t < 0.5;
    if (changed) _compositing.ping();
  }

  Rect _keepOut = Rect.zero;

  /// The whole system on screen (dial + every visible world with its halo,
  /// quantised to 8 px so the drift does not re-place the star names every
  /// frame): the sky's star names stay out of it.
  Rect _systemBounds(PlanetFrame f, Rect dial) {
    var r = dial;
    for (final b in f.bodies) {
      if (b.visible) r = r.expandToInclude(b.drawRect);
    }
    r = r.inflate(10);
    Rect q(Rect x) => Rect.fromLTRB(
      (x.left / 8).floorToDouble() * 8,
      (x.top / 8).floorToDouble() * 8,
      (x.right / 8).ceilToDouble() * 8,
      (x.bottom / 8).ceilToDouble() * 8,
    );
    final next = q(r);
    if (next != _keepOut) _keepOut = next;
    return _keepOut;
  }

  // -------------------------------------------------------------------- tick --

  /// Something animates (fly-in/out, rig spring or spin, morph, pulse,
  /// ignition, label fade, a visible gyro swing) – tick at full rate. The
  /// gyro's slow easing renders fine at the idle cadence.
  bool get isAnimating =>
      _reframing ||
      flightMoving ||
      rig.isMoving ||
      planets.isAnimating ||
      astrolabe.isAnimating ||
      (gyroEnabled && gyro.isMovingVisibly);

  /// Advances the whole scene by [dt] seconds.
  void tick(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    rig.advance(dt, drift: !_reducedMotion);
    if (_reframing) {
      _reframeT = _reducedMotion ? 1 : math.min(1, _reframeT + dt / reframeSeconds);
      _shown = CameraPath.lerp(_reframeFrom, _base, MadarMotion.standard.transform(_reframeT));
    }
    if (gyroEnabled) gyro.advance(dt);
    final anim = _flight;
    if (anim != null) _flightT = anim.value.clamp(0.0, 1.0);
    // The worlds move first: the camera (which follows a world in flight)
    // and the frame painted this vsync then agree on where it is – no
    // one-frame lag, no jitter on the hero.
    planets.advanceSeconds(dt);
    astrolabe.advanceSeconds(dt);
    sky.advanceSeconds(dt);
    _apply();
    notifyListeners();
  }

  /// Re-reads the flight and camera without advancing time (a still frame).
  void refresh() {
    final anim = _flight;
    if (anim != null) _flightT = anim.value.clamp(0.0, 1.0);
    _apply();
  }

  // ---------------------------------------------------------------- pulses --

  /// A completion: the world flares (and its moons), the core star flares
  /// softly. Returns whether the world is shown.
  bool pulse(PlanetPulse p) {
    final shown = planets.pulse(p);
    astrolabe.celebrate(strength: p.isPrayer ? 0.8 : 0.45);
    return shown;
  }

  // ------------------------------------------------------------ hit testing --

  /// Touch target of a prayer pointer (scene coordinates), or null.
  Rect? prayerRect(Prayer prayer) {
    final s = _astrolabeState;
    if (s == null || _coreRadius <= 0 || _coreOpacity < 0.5) return null;
    final c = _coreRect.center;
    var p = AstrolabeGeometry.pointerCenter(c, _coreRadius, s.fractionOf(prayer));
    final tilt = astrolabe.tilt;
    if (!tilt.isFlat) p = AstrolabeGeometry.project(AstrolabeGeometry.tiltMatrix(c, _coreRadius, tilt), p);
    final r = math.max(_coreRadius * 0.075, 22.0);
    return Rect.fromCircle(center: p, radius: r);
  }

  Prayer? _prayerAt(Offset p) {
    final s = _astrolabeState;
    if (s == null || _coreRadius <= 0 || _coreOpacity < 0.5) return null;
    return AstrolabeGeometry.hitTestPrayer(
      p - _coreRect.topLeft,
      size: _coreRect.size,
      fractions: s.fractions,
      tilt: astrolabe.tilt,
    );
  }

  bool _inDial(Offset p) =>
      _coreOpacity >= 0.5 && _coreRadius > 0 && (p - _coreRect.center).distance <= _coreRadius * 1.0;

  /// What a touch at [p] (scene coordinates) lands on: a world or moon in
  /// front of the dial, a prayer pointer, a world or moon behind the dial
  /// (only where the brass does not cover it), the core, or nothing.
  SceneHit? hitTest(Offset p) {
    if (_viewport.isEmpty) return null;
    final f = planets.frameFor(_viewport);
    final hit = f.hitTest(p);
    final prayer = _prayerAt(p);
    final inDial = _inDial(p);
    if (hit != null) {
      final exact = _exact(f, hit, p);
      final behind = _behindCore(f, hit);
      // A world ghosted over the dial is drawn there, so it takes the touch.
      final ghost = hit.moon == null && (f.body(hit.planetKey)?.ghosted ?? false);
      if (exact && (!(behind && inDial) || ghost)) return _wrap(hit);
      if (prayer != null) return SceneHit.prayer(prayer, prayerRect(prayer) ?? Rect.fromCircle(center: p, radius: 22));
      if (!inDial) return _wrap(hit);
    } else if (prayer != null) {
      return SceneHit.prayer(prayer, prayerRect(prayer) ?? Rect.fromCircle(center: p, radius: 22));
    }
    return inDial ? SceneHit.core(_coreRect) : null;
  }

  static SceneHit _wrap(OrbitHit h) =>
      h.moon == null ? SceneHit.planet(h.planetKey, h.rect) : SceneHit.moon(h.planetKey, h.moon!, h.rect);

  static bool _exact(PlanetFrame f, OrbitHit h, Offset p) {
    final b = f.body(h.planetKey);
    if (b == null) return false;
    final moon = h.moon;
    if (moon == null) return (p - b.center).distance <= b.radius * 1.02;
    final m = f.moon(moon.id);
    return m != null && (p - m.center).distance <= math.max(m.radius * 1.1, 3);
  }

  /// Whether what was hit is drawn under the dial: a moon is drawn in its
  /// world's layer, so it follows its world (not its own depth).
  static bool _behindCore(PlanetFrame f, OrbitHit h) => f.body(h.planetKey)?.behindCore ?? false;

  /// Screen centre and radius of a world now (for bursts), or null.
  (Offset, double)? planetDisc(String key) {
    if (_viewport.isEmpty) return null;
    final b = planets.frameFor(_viewport).body(key);
    if (b == null || !b.visible) return null;
    return (b.center, b.radius);
  }

  /// The astrolabe's limb radius at the overview (px).
  double get overviewCoreRadius {
    _ensureBase();
    return _baseCoreRadius;
  }

  @override
  void dispose() {
    _compositing.dispose();
    planets.dispose();
    astrolabe.dispose();
    sky.dispose();
    super.dispose();
  }
}

/// Cameras of the scene before its first layout.
abstract final class SceneCameras {
  /// Where the camera starts before the system has been framed.
  static const initial = OrbitCamera(elevation: 0.6, distance: 7.8, principal: Offset(0.5, 0.34));
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
