import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kDoubleTapSlop, kDoubleTapTimeout;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/motion/particles/celebration.dart';
import '../../../../core/providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/orbit_providers.dart';
import '../../domain/orbit_labels.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_pulse.dart';
import '../../domain/scene_snapshot.dart';
import '../../render/astrolabe/astrolabe.dart';
import '../../render/orbit_shaders.dart';
import '../../render/planets/planets.dart';
import '../../render/sky/sky.dart';
import '../orbit_ui_providers.dart';
import 'flight.dart';
import 'orbit_flight.dart';
import 'scene_compositing.dart';
import 'scene_controller.dart';
import 'scene_governor.dart';

/// A world was tapped / long-pressed ([rect] in global coordinates).
typedef ScenePlanetCallback = void Function(String planetKey, Rect rect);

/// A data moon was tapped ([rect] in global coordinates).
typedef SceneMoonCallback = void Function(OrbitMoon moon, String planetKey, Rect rect);

/// The Astrolabe Orbit: the living sky, the worlds and their data moons
/// around the brass astrolabe with the user's core star, as one scene.
///
/// Layers, back to front: sky (backdrop + stars) → orbit guides → worlds
/// behind the dial → the astrolabe (billboard on the core star) → worlds in
/// front of it → labels → lens flares; each in its own RepaintBoundary, all
/// driven by one [Ticker] through the [SceneController] (painters listen –
/// nothing rebuilds per frame). A [SceneGovernor] runs it at full rate while
/// touched or animating, 30 fps when idle, not at all when hidden; battery
/// saver shows a captured still refreshed once a minute; reduced motion
/// keeps it static but interactive.
///
/// Gestures: drag turns the system (with inertia), vertical drag tilts it,
/// pinch zooms into a world (released past 90 % it opens) or into the dial;
/// tap a world → [onPlanetTap] (the fly-in is driven by the planet route,
/// see [OrbitFlight]); long-press → [onPlanetLongPress]; tap a moon →
/// [onMoonTap]; tap a prayer pointer → [onPrayerTap]. A "reset view" pill
/// shows whenever the view differs from the default overview (the camera
/// moved, or the worlds drifted into each other); it – or a double tap on
/// empty sky – puts everything back as on a fresh start
/// ([SceneController.resetView]).
class OrbitScene extends ConsumerStatefulWidget {
  const OrbitScene({
    super.key,
    this.sceneInsets = EdgeInsets.zero,
    this.onPlanetTap,
    this.onPlanetLongPress,
    this.onMoonTap,
    this.onPrayerTap,
    this.initialTime,
    this.resetInset = 12,
  });

  /// The band the system is framed in: the scene's box minus these insets
  /// (the header above, the glass panel below).
  final EdgeInsets sceneInsets;

  final ScenePlanetCallback? onPlanetTap;
  final ScenePlanetCallback? onPlanetLongPress;
  final SceneMoonCallback? onMoonTap;
  final ValueChanged<Prayer>? onPrayerTap;

  /// Scene clock at start (seconds): where the worlds stand on their orbits
  /// when home opens (the default spreads them a golden angle apart).
  final double? initialTime;

  /// Gap between the "reset view" pill and the band's top (it sits in the
  /// band's top end corner, clear of the worlds crowding the zoomed dial's
  /// lower half and of the panel).
  final double resetInset;

  @override
  ConsumerState<OrbitScene> createState() => OrbitSceneState();
}

class OrbitSceneState extends ConsumerState<OrbitScene> with SingleTickerProviderStateMixin {
  late final SceneController _c;
  late final OrbitFlight _flight;
  late final Ticker _ticker;
  final SceneClock _clock = SceneClock();
  final GlobalKey _sceneKey = GlobalKey();
  final GlobalKey _liveKey = GlobalKey();
  final GlobalKey _resetKey = GlobalKey();

  /// The "reset view" pill is offered ([SceneController.resetCue]).
  final ValueNotifier<bool> _cue = ValueNotifier(false);

  /// Ticks once a minute (screen-reader text of the dial).
  final ValueNotifier<int> _minute = ValueNotifier(0);

  PlanetRenderer? _renderer;
  StreamSubscription<PlanetPulse>? _pulses;
  StreamSubscription<GyroSample>? _gyroSub;
  Duration? _lastGyro;
  Timer? _second;
  Timer? _stillTimer;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _tickerVisible = true;
  bool _syncScheduled = false;
  bool _firstSnapshot = true;
  SceneSnapshot? _snapshot;
  AstrolabeLabels? _labels;
  DateTime _lastNow = DateTime(0);
  bool _pinch = false;
  ProviderSubscription<AsyncValue<SceneSnapshot>>? _snapshotSub;

  // Battery-saver stills.
  ui.Image? _still;
  ui.Image? _fadingStill;
  bool _stillLive = true;
  bool _capturing = false;
  int _stillEpoch = 0;

  /// The scene's controller (tests, the planet page's hero hit tests).
  SceneController get controller => _c;

  /// Whether the scene's ticker is running and whether it is muted between
  /// idle steps (tests: an idle scene schedules no frames of its own).
  @visibleForTesting
  ({bool active, bool muted}) get debugTicker => (active: _ticker.isActive, muted: _ticker.muted);

  DateTime Function() get _now => ref.read(orbitClockProvider);

  @override
  void initState() {
    super.initState();
    final now = _now();
    final settings = ref.read(prayerScheduleProvider).settings;
    _c = SceneController(
      initialTime: widget.initialTime ?? 12,
      now: now,
      observer: SkyObserver.fromPrayerSettings(settings),
    );
    _flight = ref.read(orbitFlightProvider)
      ..scene = _c
      ..globalToScene = globalToScene;
    _flight.addListener(_onFlight);
    _ticker = createTicker(_onTick);
    _c.planets.addListener(_wake);
    _c.astrolabe.addListener(_wake);
    _c.planets.addPulseListener(_onPlanetPulse);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    final ready = OrbitShaders.instance;
    if (ready != null) {
      _renderer = PlanetRenderer(ready);
    } else {
      unawaited(
        OrbitShaders.load().then((s) {
          if (mounted && _renderer == null) setState(() => _renderer = PlanetRenderer(s));
        }, onError: (Object _) {}),
      );
    }
    _pulses = ref.read(orbitPulseHubProvider).pulses.listen(_onPulse, onError: (Object _) {});
    _snapshotSub = ref.listenManual(sceneSnapshotProvider, (_, next) {
      final s = next.value;
      if (s != null) _onSnapshot(s);
    }, fireImmediately: true);
    // Battery saver switched while home is on screen: stills at once.
    ref.listenManual(appSettingsProvider.select((s) => s.powerMode), (_, _) => _sync());
    ref.listenManual(prayerScheduleProvider, (_, schedule) {
      _c.sky.observer = SkyObserver.fromPrayerSettings(schedule.settings);
      if (_snapshot == null) _rebuildAstrolabe();
    });
    _onFlight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.reducedMotion = context.reducedMotion;
    _tickerVisible = TickerMode.valuesOf(context).enabled;
    // Hidden (the app lock came down, a page covers home) mid-touch.
    if (!_tickerVisible) _dropGesture();
    final labels = AstrolabeLabels.of(context);
    if (labels != _labels) {
      _labels = labels;
      _rebuildAstrolabe(animate: false);
    }
    try {
      _c.quality.refreshRate = View.of(context).display.refreshRate;
    } catch (_) {}
    _sync();
  }

  @override
  void dispose() {
    _snapshotSub?.close();
    _flight.removeListener(_onFlight);
    if (identical(_flight.scene, _c)) {
      _flight
        ..scene = null
        ..globalToScene = null;
    }
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _lifecycle?.dispose();
    _second?.cancel();
    _idleWake?.cancel();
    _stillTimer?.cancel();
    _gyroSlowdown?.cancel();
    _skyTap?.cancel();
    _flightRoute?.removeStatusListener(_onFlightStatus);
    _flightRoute = null;
    unawaited(_pulses?.cancel());
    unawaited(_gyroSub?.cancel());
    _ticker.dispose();
    _c.planets
      ..removeListener(_wake)
      ..removePulseListener(_onPlanetPulse);
    _c.astrolabe.removeListener(_wake);
    _renderer?.dispose();
    _still?.dispose();
    _fadingStill?.dispose();
    _cue.dispose();
    _minute.dispose();
    _c.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data --

  void _onSnapshot(SceneSnapshot s) {
    _snapshot = s;
    _c.setPlanets(s.planets, animate: !_firstSnapshot);
    _firstSnapshot = false;
    _rebuildAstrolabe();
    _refreshStillSoon();
    if (mounted) setState(() {});
  }

  void _rebuildAstrolabe({bool animate = true}) {
    final labels = _labels;
    if (labels == null) return;
    final now = _now();
    _lastNow = now;
    final s = _snapshot;
    final AstrolabeState state;
    if (s != null) {
      state = AstrolabeState.fromPrayerState(s.prayer, now: now, labels: labels, balance: s.balance);
    } else {
      state = AstrolabeState.fromSchedule(schedule: ref.read(prayerScheduleProvider), now: now, labels: labels);
    }
    _c.setAstrolabeState(state, animate: animate && _c.astrolabeState != null);
    _c.sky.time = now;
  }

  void _onSecond() {
    // Stills refresh once a minute; hidden scenes not at all.
    if (!mounted || !_visible || _c.governor.mode == SceneMode.still) return;
    final now = _now();
    if (now.difference(_lastNow).inMilliseconds.abs() < 500) return;
    final state = _c.astrolabeState;
    if (state == null) return;
    final refreshSky = now.difference(_lastSky).inSeconds.abs() >= 10;
    if (now.minute != _lastNow.minute || now.difference(_lastNow).inMinutes.abs() >= 1) _minute.value++;
    _lastNow = now;
    if (refreshSky) _lastSky = now;
    final settings = _snapshot?.prayer.settings ?? ref.read(prayerScheduleProvider).settings;
    _c.setAstrolabeState(
      state.copyWith(
        now: now,
        sky: refreshSky ? AstrolabeSky.at(now, latitude: settings.latitude, longitude: settings.longitude) : null,
      ),
    );
    if (refreshSky) _c.sky.time = now;
  }

  DateTime _lastSky = DateTime(0);

  // -------------------------------------------------------------- flight --

  Animation<double>? _flightRoute;

  void _onFlight() {
    final route = _flight.route;
    if (!identical(route, _flightRoute)) {
      _flightRoute?.removeStatusListener(_onFlightStatus);
      _flightRoute = route;
      route?.addStatusListener(_onFlightStatus);
      if (route != null && route.status == AnimationStatus.forward) _swell(FlightTiming.swellIn);
    }
    _c.bindFlight(_flight.key, route);
    _c.planets.selectedMoonId = _flight.active ? _flight.item : null;
    _c.refresh();
    _syncCue();
    _sync();
  }

  void _onFlightStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) _swell(FlightTiming.swellIn);
    if (status == AnimationStatus.reverse) _swell(FlightTiming.swellOut);
    _sync();
  }

  void _swell(double amount) {
    if (context.reducedMotion) return;
    try {
      ref.read(soundServiceProvider).swell(amount);
    } catch (_) {}
  }

  // --------------------------------------------------------------- pulses --

  void _onPulse(PlanetPulse p) {
    if (!mounted) return;
    _c.pulse(p);
    _sync();
  }

  void _onPlanetPulse(PlanetPulse p) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final disc = _c.planetDisc(p.planetKey);
      final box = _sceneKey.currentContext?.findRenderObject();
      if (disc == null || box is! RenderBox || !box.attached) {
        Fx.fire(p.origin == PulseOrigin.recorded ? Sfx.complete : Sfx.sparkle);
        return;
      }
      final body = _c.planets.bodies.where((b) => b.key == p.planetKey).firstOrNull;
      // ~40 additive particles in the world's glow colour (the shader adds
      // a soft shockwave swelling out of its limb) and the chime.
      Celebrate.burst(
        context,
        box.localToGlobal(disc.$1),
        kind: CelebrationKind.stardust,
        color: body?.palette.glow,
        intensity: 0.87,
        radius: disc.$2 * 1.5 + 12,
        sfx: p.origin == PulseOrigin.recorded ? Sfx.complete : Sfx.sparkle,
      );
    });
  }

  // ---------------------------------------------------------------- power --

  bool get _visible => _tickerVisible && _foreground;

  /// A planet page is open over the scene and its fly-in has landed.
  bool get _pageOpen => _c.flightKey != null && !_c.flightMoving && _c.flightProgress >= 0.999;

  void _onLifecycle(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed && !_foreground;
    _foreground = state == AppLifecycleState.resumed;
    // Really left mid-touch: the gesture's end may never come.
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) _dropGesture();
    _sync();
    // Back from the background: the dial jumps to now at once (not on the
    // next 1 Hz tick).
    if (resumed) _onSecond();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_c.governor.wantsTicker) return;
    // The panel may switch to its high refresh rate after the first frame.
    if (mounted) {
      try {
        _c.quality.refreshRate = View.of(context).display.refreshRate;
      } catch (_) {}
    }
    var changed = false;
    for (final t in timings) {
      changed |= _c.quality.addFrame(
        rasterMs: t.rasterDuration.inMicroseconds / 1000,
        buildMs: t.buildDuration.inMicroseconds / 1000,
      );
    }
    if (changed && mounted) {
      _c.refresh();
      setState(() {});
    }
  }

  void _wake() {
    if ((_ticker.isActive && !_ticker.muted) || _syncScheduled || !mounted) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  /// Re-evaluates the governor and starts / stops the ticker, the gyro and
  /// the still capture accordingly.
  void _sync() {
    if (!mounted) return;
    final settings = ref.read(appSettingsProvider);
    final inputs = SceneInputs(
      visible: _visible,
      interacting: _c.rig.interacting,
      animating: _c.isAnimating,
      batterySaver: settings.powerMode == PowerMode.batterySaver,
      reducedMotion: _c.reducedMotion,
      ambient: AmbientMotion.enabled,
      pageOpen: _pageOpen,
    );
    final g = _c.governor;
    g.update(inputs);
    if (g.wantsTicker && !_ticker.isActive) {
      _clock.restart();
      g.reset();
      _ticker.start();
    } else if (!g.wantsTicker && _ticker.isActive) {
      _ticker.stop();
    }
    if (g.mode != SceneMode.idle && g.mode != SceneMode.backdrop) _unmute();
    _c.sky.still = !g.wantsTicker || !_c.quality.twinkle;
    _syncGyro(g.mode == SceneMode.live || g.mode == SceneMode.idle, fast: g.mode == SceneMode.live);
    _syncStill(g.mode == SceneMode.still);
    // The 1 Hz clock only matters while the scene is on screen.
    if (_visible && g.mode != SceneMode.paused) {
      _second ??= Timer.periodic(const Duration(seconds: 1), (_) => _onSecond());
    } else {
      _second?.cancel();
      _second = null;
    }
  }

  Timer? _idleWake;

  /// Idle: after each admitted 30 fps step the ticker is muted – no frame
  /// is scheduled (so nothing is recomposited) – until the next step is due.
  void _muteUntilNextIdleStep() {
    if (_ticker.muted || !_ticker.isActive) return;
    _ticker.muted = true;
    _idleWake?.cancel();
    // A few ms early: the vsync after unmuting lands on the step.
    final us = (1e6 / _c.governor.stepFps - 6000).round();
    _idleWake = Timer(Duration(microseconds: us), _unmute);
  }

  void _unmute() {
    _idleWake?.cancel();
    _idleWake = null;
    if (mounted && _ticker.isActive && _ticker.muted) _ticker.muted = false;
  }

  bool _gyroFast = false;

  /// How long the scene stays idle before the gyro drops to its slow rate
  /// (live ↔ idle flips with every touch – no resubscribe churn).
  static const Duration gyroSlowdownDelay = Duration(seconds: 3);

  Timer? _gyroSlowdown;

  void _syncGyro(bool on, {required bool fast}) {
    final want = on && _c.gyroEnabled;
    if (!want) {
      _gyroSlowdown?.cancel();
      _gyroSlowdown = null;
      unawaited(_gyroSub?.cancel());
      _gyroSub = null;
      return;
    }
    if (_gyroSub == null) {
      _subscribeGyro(fast: fast);
    } else if (fast == _gyroFast || fast) {
      // Same rate, or live again: at once (a slow → fast upgrade).
      _gyroSlowdown?.cancel();
      _gyroSlowdown = null;
      if (fast != _gyroFast) _subscribeGyro(fast: true);
    } else {
      // Idle: slow down only once it stays idle.
      _gyroSlowdown ??= Timer(gyroSlowdownDelay, () {
        _gyroSlowdown = null;
        if (mounted && _gyroSub != null && _gyroFast && _c.governor.mode == SceneMode.idle) {
          _subscribeGyro(fast: false);
        }
      });
    }
  }

  void _subscribeGyro({required bool fast}) {
    unawaited(_gyroSub?.cancel());
    _gyroSub = null;
    final stream = ref.read(orbitGyroProvider)(fast: fast);
    if (stream == null) return;
    _gyroFast = fast;
    _lastGyro = null;
    _gyroSub = stream.listen((s) {
      final last = _lastGyro;
      _lastGyro = s.at;
      if (last == null) return;
      _c.gyro.addRates(s.pitchRate, s.yawRate, (s.at - last).inMicroseconds / 1e6);
    }, onError: (Object _) {});
  }

  void _onTick(Duration elapsed) {
    final dt = _clock.tick(elapsed);
    final step = _c.governor.admit(dt);
    if (step != null) {
      _c.tick(step);
      _clock.advanced(step);
      _syncCue();
    }
    final g = _c.governor;
    final before = g.mode;
    _syncLight();
    if (g.mode != before || !g.wantsTicker) {
      _wakeSync();
    } else if ((g.mode == SceneMode.idle || g.mode == SceneMode.backdrop) && step != null) {
      _muteUntilNextIdleStep();
    }
  }

  /// Cheap per-frame governor refresh (no gyro / still work).
  void _syncLight() {
    final g = _c.governor;
    g.update(g.inputs.copyWith(interacting: _c.rig.interacting, animating: _c.isAnimating, pageOpen: _pageOpen));
  }

  void _wakeSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  // --------------------------------------------------------------- stills --

  void _syncStill(bool still) {
    if (!still) {
      _stillTimer?.cancel();
      _stillTimer = null;
      _setStillLive(true);
      return;
    }
    _stillTimer ??= Timer.periodic(const Duration(minutes: 1), (_) => _refreshStill());
    // A fresh still is due when none exists yet or the live scene is showing
    // again (a refresh, the end of an interaction or animation).
    if ((_still == null || _stillLive) && !_capturing) _captureSoon();
  }

  void _setStillLive(bool live) {
    if (_stillLive == live) return;
    _stillLive = live;
    _markDirty();
  }

  /// setState, deferred to after the frame when called while building.
  void _markDirty() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _refreshStillSoon() {
    if (_c.governor.mode != SceneMode.still) return;
    _refreshStill(advance: false);
  }

  void _refreshStill({bool advance = true}) {
    if (!mounted || _c.governor.mode != SceneMode.still) return;
    if (advance) {
      _rebuildAstrolabe(animate: false);
      // The worlds move on by the minute that passed (no ticker ran).
      _c.planets.advanceSeconds(60);
      _c.refresh();
    }
    _setStillLive(true);
    _captureSoon();
  }

  void _captureSoon() {
    _capturing = true;
    final epoch = ++_stillEpoch;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _stillEpoch) return;
      _capturing = false;
      if (_c.governor.mode != SceneMode.still) return;
      final boundary = _liveKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize || !boundary.attached) return;
      ui.Image image;
      try {
        image = boundary.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      } catch (_) {
        return;
      }
      setState(() {
        _fadingStill?.dispose();
        _fadingStill = _still;
        _still = image;
        _stillLive = false;
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  // ------------------------------------------------------------- gestures --

  Size get _size => _c.viewport;

  void _onTapUp(TapUpDetails d) {
    final hit = _c.hitTest(d.localPosition);
    if (hit == null) return _onSkyTap(d.localPosition);
    _skyTap?.cancel();
    _skyTap = null;
    final rect = _global(hit.rect);
    switch (hit.kind) {
      case SceneHitKind.planet:
        if (widget.onPlanetTap == null) return;
        Fx.fire(Sfx.navigate);
        widget.onPlanetTap!(hit.planetKey!, rect);
      case SceneHitKind.moon:
        if (widget.onMoonTap == null) return;
        Fx.fire(Sfx.tap);
        widget.onMoonTap!(hit.moon!, hit.planetKey!, rect);
      case SceneHitKind.prayer:
        if (widget.onPrayerTap == null) return;
        Fx.fire(Sfx.tap);
        widget.onPrayerTap!(hit.prayer!);
      case SceneHitKind.core:
        _c.astrolabe.celebrate(strength: 0.35);
        Fx.fire(Sfx.sparkle);
        _sync();
    }
  }

  void _onLongPress(LongPressStartDetails d) {
    final hit = _c.hitTest(d.localPosition);
    if (hit == null) return;
    if (hit.kind == SceneHitKind.planet || hit.kind == SceneHitKind.moon) {
      if (widget.onPlanetLongPress == null) return;
      Fx.fire(Sfx.pickUp);
      final disc = _c.planetDisc(hit.planetKey!);
      final rect = disc == null ? hit.rect : Rect.fromCircle(center: disc.$1, radius: disc.$2);
      widget.onPlanetLongPress!(hit.planetKey!, _global(rect));
    } else if (hit.kind == SceneHitKind.prayer && widget.onPrayerTap != null) {
      Fx.fire(Sfx.pickUp);
      widget.onPrayerTap!(hit.prayer!);
    }
  }

  /// A global position in the scene's own coordinates (hit tests from
  /// routes above it).
  Offset globalToScene(Offset global) {
    final box = _sceneKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return global;
    return box.globalToLocal(global);
  }

  Rect _global(Rect local) {
    final box = _sceneKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return local;
    final o = box.localToGlobal(Offset.zero);
    return local.shift(o);
  }

  String? _zoomTargetAt(Offset focal) {
    final f = _c.planets.frameFor(_size);
    String? best;
    var bestD = 110.0;
    for (final b in f.drawOrder) {
      final d = (b.center - focal).distance - b.radius;
      if (d < bestD) {
        bestD = d;
        best = b.key;
      }
    }
    // Pinching on the dial zooms into the astrolabe.
    if ((focal - _c.coreCenter).distance < _c.coreRadius * 0.9 && bestD > 0) return null;
    return best;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gesture = true;
    _pinch = d.pointerCount > 1;
    _c.rig.begin(pinch: _pinch, zoomKey: _pinch ? _zoomTargetAt(d.localFocalPoint) : null);
    _stillLiveNow();
    _sync();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // A gesture dropped when the app left: the rest of it is ignored.
    if (!_gesture) return;
    if (d.pointerCount > 1) {
      if (!_pinch) {
        _pinch = true;
        _c.rig.startPinch(zoomKey: _zoomTargetAt(d.localFocalPoint));
      }
      _c.rig.pinchTo(d.scale);
    } else if (!_pinch) {
      _c.rig.dragBy(d.focalPointDelta, _size, baseElevation: _c.baseCamera.elevation);
    }
    if (!_ticker.isActive || _ticker.muted) _sync();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    // Dropped already (see [_dropGesture]): no late fling, no page opening
    // behind the owner's back.
    if (!_gesture) return;
    _gesture = false;
    final wasPinch = _pinch;
    _pinch = false;
    final key = _c.rig.zoomKey;
    final zoom = _c.rig.zoom;
    _c.rig.end(velocity: d.velocity.pixelsPerSecond, viewport: _size);
    if (wasPinch && key != null && zoom > SceneController.pinchOpenZoom && widget.onPlanetTap != null) {
      Fx.fire(Sfx.navigate);
      final disc = _c.planetDisc(key);
      final rect = disc == null ? Rect.zero : Rect.fromCircle(center: disc.$1, radius: disc.$2);
      widget.onPlanetTap!(key, _global(rect));
    }
    _sync();
  }

  /// A drag or pinch is in progress (between its start and its end).
  bool _gesture = false;

  /// The touch was cut off without its end – the app left the foreground,
  /// or the lock (or a page) hid the scene mid-gesture: let go of it where
  /// the camera is, and spring an unreleased pinch back out, so the owner
  /// never comes back to a scene stuck mid-zoom (a late end is ignored).
  void _dropGesture() {
    if (!_gesture) return;
    _gesture = false;
    _pinch = false;
    _c.rig.cancelGesture();
    _c.refresh();
    _syncCue();
    _sync();
  }

  void _stillLiveNow() => _setStillLive(true);

  // ----------------------------------------------------------- reset view --

  Timer? _skyTap;
  Offset _skyTapAt = Offset.zero;

  /// Empty sky: a second tap there within the double-tap time resets the
  /// view. Detected by hand, so taps on worlds never wait for a possible
  /// double tap.
  void _onSkyTap(Offset p) {
    final pending = _skyTap;
    if (pending != null && pending.isActive && (p - _skyTapAt).distance <= kDoubleTapSlop) {
      pending.cancel();
      _skyTap = null;
      _resetView();
      return;
    }
    _skyTapAt = p;
    pending?.cancel();
    _skyTap = Timer(kDoubleTapTimeout, () => _skyTap = null);
  }

  /// Everything back as on a fresh start (a spring; a cut under reduced
  /// motion). [sound]: the pill already made its own.
  void _resetView({bool sound = true}) {
    if (_c.flightKey != null) return;
    if (sound) Fx.fire(Sfx.navigate);
    _stillLiveNow();
    _c.resetView(animate: !context.reducedMotion);
    _syncCue();
    _sync();
  }

  void _syncCue() {
    final cue = _c.resetCue;
    if (cue == _cue.value) return;
    _cue.value = cue;
    _syncKeepOut();
  }

  /// Where the reset pill sits (scene coordinates; measured after layout).
  Rect _resetRect = Rect.zero;

  void _measureReset() {
    if (!mounted) return;
    final button = _resetKey.currentContext?.findRenderObject();
    final scene = _sceneKey.currentContext?.findRenderObject();
    if (button is! RenderBox || scene is! RenderBox || !button.hasSize || !button.attached || !scene.attached) return;
    final rect = MatrixUtils.transformRect(button.getTransformTo(scene), Offset.zero & button.size);
    if (rect == _resetRect) return;
    _resetRect = rect;
    _syncKeepOut();
  }

  /// Labels keep clear of the reset pill while it shows.
  void _syncKeepOut() {
    _c.planets.labelKeepOut = _cue.value && !_resetRect.isEmpty ? [_resetRect.inflate(6)] : const [];
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tokens = context.tokens;
    final snapshot = _snapshot;
    final astro = _c.astrolabeState;
    final quality = _c.quality;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final band = Rect.fromLTRB(
          widget.sceneInsets.left,
          widget.sceneInsets.top,
          size.width - widget.sceneInsets.right,
          size.height - widget.sceneInsets.bottom,
        );
        _c.layout(size, band);
        // The pill's place follows the band, the text direction and the
        // label's width: re-measured after every layout of the scene.
        SchedulerBinding.instance.addPostFrameCallback((_) => _measureReset());
        final live = RepaintBoundary(
          key: _liveKey,
          child: ColoredBox(
            color: tokens.space0,
            child: ZoomBlur(
              controller: _c,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Depth of field in two passes (a mid-range GPU affords
                  // two full-screen blurs, not five): everything behind the
                  // dial, then the unfocused worlds in front of it with the
                  // labels. The focused world and the dial (its own small
                  // blur) stay out of them.
                  SceneBlur(
                    controller: _c,
                    sigma: (c) => c.backgroundBlur,
                    tileMode: TileMode.clamp,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SkyLayer(controller: _c.sky),
                        OrbitGuidesView(controller: _c.planets),
                        PlanetBodiesView(
                          controller: _c.planets,
                          renderer: _renderer,
                          pass: PlanetPass.behindCore,
                          filter: PlanetFocusFilter.unfocusedOnly,
                        ),
                      ],
                    ),
                  ),
                  PlanetBodiesView(
                    controller: _c.planets,
                    renderer: _renderer,
                    pass: PlanetPass.behindCore,
                    filter: PlanetFocusFilter.focusedOnly,
                  ),
                  if (astro != null)
                    CoreAnchor(
                      controller: _c,
                      // The scene announces the dial and its prayers itself
                      // (with correct depth order for taps).
                      child: ExcludeSemantics(
                        child: AstrolabeLayer(
                          state: astro,
                          controller: _c.astrolabe,
                          celebrate: true,
                          showMakersMark: true,
                        ),
                      ),
                    ),
                  SceneBlur(
                    controller: _c,
                    sigma: (c) => c.backgroundBlur,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlanetBodiesView(
                          controller: _c.planets,
                          renderer: _renderer,
                          pass: PlanetPass.frontOfCore,
                          filter: PlanetFocusFilter.unfocusedOnly,
                          ghosts: true,
                        ),
                        // Labels fade themselves: out early in a fly-in, down
                        // to the focused cluster when zoomed in.
                        PlanetLabelsView(controller: _c.planets),
                      ],
                    ),
                  ),
                  PlanetBodiesView(
                    controller: _c.planets,
                    renderer: _renderer,
                    pass: PlanetPass.frontOfCore,
                    filter: PlanetFocusFilter.focusedOnly,
                  ),
                  if (quality.lensFlare) SkyFlareLayer(controller: _c.sky),
                ],
              ),
            ),
          ),
        );
        final still = _still;
        final showStill = still != null && !_stillLive;
        return Semantics(
          container: true,
          label: snapshot == null ? null : balanceSemanticsLabel(l10n, fmt, snapshot),
          hint: l10n.orbitUiSceneHint,
          child: GestureDetector(
            key: _sceneKey,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: _onTapUp,
            onLongPressStart: _onLongPress,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Visibility(
                  visible: !showStill,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: live,
                ),
                if (still != null)
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: _StillView(
                        key: ValueKey(still),
                        image: still,
                        previous: _fadingStill,
                        visible: showStill,
                        fade: !context.reducedMotion,
                        onFaded: () {
                          if (!mounted) return;
                          setState(() {
                            _fadingStill?.dispose();
                            _fadingStill = null;
                          });
                        },
                      ),
                    ),
                  ),
                // Re-read every minute (the spoken countdown, the pointers'
                // statuses), not only when the snapshot changes.
                if (astro != null)
                  ValueListenableBuilder<int>(
                    valueListenable: _minute,
                    builder: (context, _, _) =>
                        _PrayerSemantics(controller: _c, state: _c.astrolabeState ?? astro, onTap: widget.onPrayerTap),
                  ),
                PlanetSemanticsView(
                  controller: _c.planets,
                  onPlanetTap: widget.onPlanetTap == null
                      ? null
                      : (key, rect) => widget.onPlanetTap!(key, _global(rect)),
                  onPlanetLongPress: widget.onPlanetLongPress == null
                      ? null
                      : (key, rect) => widget.onPlanetLongPress!(key, _global(rect)),
                  onMoonTap: widget.onMoonTap == null
                      ? null
                      : (moon, key, rect) => widget.onMoonTap!(moon, key, _global(rect)),
                ),
                PositionedDirectional(
                  end: Space.gutter,
                  top: widget.sceneInsets.top + widget.resetInset,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _cue,
                    builder: (context, shown, child) => AnimatedOpacity(
                      opacity: shown ? 1 : 0,
                      duration: context.motion(MadarMotion.medium),
                      curve: MadarMotion.standard,
                      child: IgnorePointer(
                        ignoring: !shown,
                        // Screen readers only meet it while it is offered;
                        // then as its own node, never merged into the
                        // scene's (whose double tap would otherwise reset
                        // the view).
                        child: ExcludeSemantics(
                          excluding: !shown,
                          child: Semantics(container: true, child: child),
                        ),
                      ),
                    ),
                    // A labelled glass pill, 48 dp tall (a full touch
                    // target you can see): what it does is written on it.
                    child: MadarButton(
                      key: _resetKey,
                      label: l10n.orbitUiRecenter,
                      icon: Icons.restart_alt_rounded,
                      variant: MadarButtonVariant.secondary,
                      size: MadarButtonSize.medium,
                      // The same sound as a double tap on the sky.
                      sfx: Sfx.navigate,
                      onPressed: () => _resetView(sound: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A captured still of the scene, cross-fading in over the previous one.
class _StillView extends StatefulWidget {
  const _StillView({
    super.key,
    required this.image,
    required this.previous,
    required this.visible,
    required this.fade,
    required this.onFaded,
  });

  final ui.Image image;
  final ui.Image? previous;
  final bool visible;
  final bool fade;
  final VoidCallback onFaded;

  @override
  State<_StillView> createState() => _StillViewState();
}

class _StillViewState extends State<_StillView> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (!widget.fade || widget.previous == null) {
      _shown = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final previous = widget.previous;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (previous != null) RawImage(image: previous, fit: BoxFit.fill),
        AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: widget.fade ? const Duration(milliseconds: 900) : Duration.zero,
          curve: MadarMotion.standard,
          onEnd: widget.onFaded,
          child: RawImage(image: widget.image, fit: BoxFit.fill),
        ),
      ],
    );
  }
}

/// Screen-reader nodes of the astrolabe: the dial (current window, next
/// prayer countdown, prayers done) and its five prayer pointers (tap = log).
class _PrayerSemantics extends StatelessWidget {
  const _PrayerSemantics({required this.controller, required this.state, this.onTap});

  final SceneController controller;
  final AstrolabeState state;
  final ValueChanged<Prayer>? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _PrayerSemanticsPainter(
        controller: controller,
        state: state,
        l10n: l10n,
        textDirection: Directionality.of(context),
        onTap: onTap,
      ),
    );
  }
}

class _PrayerSemanticsPainter extends CustomPainter {
  _PrayerSemanticsPainter({
    required this.controller,
    required this.state,
    required this.l10n,
    required this.textDirection,
    this.onTap,
  });

  final SceneController controller;
  final AstrolabeState state;
  final L10n l10n;
  final TextDirection textDirection;
  final ValueChanged<Prayer>? onTap;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool? hitTest(Offset position) => false;

  String _label(Prayer p) {
    final name = state.labels.prayerName(p);
    return switch (state.statusOf(p)) {
      AstrolabePrayerStatus.prayed => l10n.astrolabePrayerPrayed(name),
      AstrolabePrayerStatus.due => l10n.astrolabePrayerDue(name),
      AstrolabePrayerStatus.missed => l10n.astrolabePrayerMissed(name),
      AstrolabePrayerStatus.upcoming => l10n.astrolabePrayerUpcoming(name, state.labels.time(state.timeOf(p))),
    };
  }

  String get _summary {
    final labels = state.labels;
    return l10n.astrolabeSemantics(
      l10n.astrolabeWindowNow(labels.windowName(state.window.window)),
      state.spokenCountdown,
      labels.formatter.formatInt(state.prayedCount),
      labels.formatter.formatInt(AstrolabeGeometry.prayers.length),
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final nodes = <CustomPainterSemantics>[];
    if (controller.coreOpacity >= 0.5 && !controller.coreRect.isEmpty) {
      nodes.add(
        CustomPainterSemantics(
          key: const ValueKey('astrolabe'),
          rect: controller.coreRect,
          properties: SemanticsProperties(label: _summary, textDirection: textDirection),
        ),
      );
    }
    final tap = onTap;
    for (final p in AstrolabeGeometry.prayers) {
      final rect = controller.prayerRect(p);
      if (rect == null) continue;
      nodes.add(
        CustomPainterSemantics(
          key: ValueKey('prayer:${p.name}'),
          rect: rect,
          properties: SemanticsProperties(
            label: _label(p),
            button: tap != null,
            textDirection: textDirection,
            hintOverrides: tap == null ? null : SemanticsHintOverrides(onTapHint: l10n.orbitUiPrayerHint),
            onTap: tap == null ? null : () => tap(p),
          ),
        ),
      );
    }
    return nodes;
  };

  @override
  bool shouldRepaint(_PrayerSemanticsPainter old) => false;

  @override
  bool shouldRebuildSemantics(_PrayerSemanticsPainter old) =>
      !identical(old.state, state) || old.l10n != l10n || old.textDirection != textDirection;
}
