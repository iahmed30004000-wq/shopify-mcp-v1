import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/foundation.dart';

import '../../../../core/motion/springs.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_pulse.dart';
import '../../domain/scene_math.dart';
import '../../domain/scene_snapshot.dart';
import 'living_state.dart';
import 'planet_body.dart';
import 'planet_frame.dart';
import 'planet_layout.dart';
import 'planet_style.dart';
import 'planet_uniforms.dart';

/// Told when a world pulses (a completion): the layer answers with particles
/// and a chime at the world's place on screen.
typedef PlanetPulseListener = void Function(PlanetPulse pulse);

class _MoonState {
  _MoonState(this.moon, {required double lane, required this.angle, required this.appear})
    : lane = SpringMotion(spring: LivingSprings.lane, value: lane, tolerance: MadarSprings.unit),
      frame = MoonFrame(moon);

  OrbitMoon moon;
  final SpringMotion lane;
  double angle;
  double appear;
  final MoonFrame frame;

  /// The turn a [PlanetSceneController.respread] adds (radians), and how
  /// much of it has been applied so far.
  double homeDelta = 0, homeApplied = 0;

  double get inclination => MoonLayout.inclinationOf(moon.seed);
  double get node => MoonLayout.nodeOf(moon.seed);
}

class _BodyState {
  _BodyState(this.body, {required double lane, required this.angle, required PlanetSystemLayout layout})
    : lane = SpringMotion(spring: LivingSprings.lane, value: lane, tolerance: MadarSprings.unit),
      frame = BodyFrame(body) {
    restyle(layout);
  }

  PlanetBody body;
  final SpringMotion lane;
  double angle;
  final BodyFrame frame;
  final Map<String, _MoonState> moons = {};

  /// The turn a [PlanetSceneController.respread] adds (radians), and how
  /// much of it has been applied so far.
  double homeDelta = 0, homeApplied = 0;

  late double inclination, node, tilt, spinPeriod, spinPhase, worldRadius;

  void restyle(PlanetSystemLayout layout) {
    final seed = body.seed;
    inclination = layout.inclinationOf(seed);
    node = layout.nodeOf(seed);
    tilt = PlanetStyle.axialTiltOf(body.archetype, seed);
    spinPeriod = PlanetStyle.spinPeriodOf(seed);
    spinPhase = 2 * math.pi * ((seed * 0.4142135) % 1);
    worldRadius = layout.bodyRadiusOf(body.archetype);
  }
}

/// The planet layer's living state, advanced by the scene's single ticker.
///
/// Inputs: the worlds ([setBodies] / [setPlanets]), the [camera], the
/// [selectedKey] (highlighted orbit), a fly-in [focusKey] + [focus]
/// progress, the [selectedMoonId] and completion [pulse]s. Every [advance]
/// moves the worlds along their orbits, spins them, springs their displayed
/// scores and fades labels, then notifies – painters listen, so nothing
/// rebuilds per frame. [frameFor] projects everything for a viewport (cached
/// until the next change) and answers hit tests.
///
/// Reduced motion freezes the clock (a static scene); score changes jump.
class PlanetSceneController extends ChangeNotifier {
  PlanetSceneController({
    this.layout = const PlanetSystemLayout(),
    double initialTime = 12,
    this._camera = PlanetSystemLayout.overviewCamera,
    this.star = V3.zero,
    this.coreRadius = 0.52,
  }) : _time = initialTime,
       _startTime = initialTime,
       _homeAt = initialTime,
       living = LivingStateAnimator(time: initialTime);

  final PlanetSystemLayout layout;

  /// World position of the core star (the light source).
  final V3 star;

  /// World radius of the astrolabe around the star (label occlusion).
  final double coreRadius;

  int _bodiesVersion = 0;

  /// Increments whenever the set of worlds or moons changes (renderers
  /// release shaders of bodies that are gone; semantics rebuild).
  int get bodiesVersion => _bodiesVersion;

  /// Displayed scores and pulses of every planet (`key`) and moon
  /// (`moon:<refTable>:<refId>`).
  final LivingStateAnimator living;

  /// Opacity of each planet's name label (painters set targets).
  final OpacityFader planetLabels = OpacityFader(timeConstant: 0.18);

  /// Opacity of each moon's name label.
  final OpacityFader moonLabels = OpacityFader(timeConstant: 0.22);

  final List<_BodyState> _bodies = [];
  final _Signal _guides = _Signal();
  final List<PlanetPulseListener> _pulseListeners = [];

  /// Repaint signal for the orbit guides (camera, lanes, selection, focus).
  Listenable get guides => _guides;

  static String moonKey(String moonId) => 'moon:$moonId';

  static const _tau = 2 * math.pi;

  // ---------------------------------------------------------------- inputs --

  /// The worlds, in lane order.
  List<PlanetBody> get bodies => [for (final b in _bodies) b.body];

  /// Replaces the worlds. New worlds appear in place; known worlds keep
  /// their position, move lanes on a spring when the order changed, and
  /// morph to their new score (all at once when [animate] is false).
  void setBodies(List<PlanetBody> next, {bool animate = true}) {
    final firstFill = _bodies.isEmpty;
    final byKey = {for (final b in _bodies) b.body.key: b};
    final count = next.length;
    final ordered = <_BodyState>[];
    var changed = _bodies.length != count;
    for (var i = 0; i < count; i++) {
      final body = next[i];
      final laneTarget = layout.laneRadius(i, count);
      var st = byKey.remove(body.key);
      if (st == null) {
        // The line of nodes turns the orbit, so start at golden angle +
        // node: the worlds' apparent longitudes are then evenly spread.
        st = _BodyState(
          body,
          lane: laneTarget,
          angle: layout.initialAngle(i) + layout.nodeOf(body.seed) + layout.angularSpeedFor(laneTarget) * _time,
          layout: layout,
        );
        changed = true;
      } else {
        if (!st.body.sameAs(body)) changed = true;
        final restyle = st.body.archetype != body.archetype || st.body.seed != body.seed;
        st.body = body;
        st.frame.body = body;
        if (restyle) st.restyle(layout);
        if (st.lane.target != laneTarget) {
          changed = true;
          if (animate && !_reducedMotion) {
            st.lane.retarget(laneTarget, time: _time);
          } else {
            st.lane.jumpTo(laneTarget);
          }
        }
      }
      if (_bodies.length <= i || !identical(_bodies[i], st)) changed = true;
      living.setScore(body.key, body.score, animate: animate && !firstFill);
      _syncMoons(st, animate: animate && !firstFill);
      ordered.add(st);
    }
    _bodies
      ..clear()
      ..addAll(ordered);
    final keep = <String>{
      for (final b in _bodies) ...[b.body.key, for (final m in b.moons.keys) moonKey(m)],
    };
    living.retain(keep);
    planetLabels.retain({for (final b in _bodies) b.body.key});
    moonLabels.retain({for (final b in _bodies) ...b.moons.keys});
    if (changed) {
      _bodiesVersion++;
      _dirty = true;
      _guides.ping();
      notifyListeners();
    }
  }

  /// Every planet key and moon id currently in the scene.
  ({Set<String> planets, Set<String> moons}) get liveIds =>
      (planets: {for (final b in _bodies) b.body.key}, moons: {for (final b in _bodies) ...b.moons.keys});

  /// [setBodies] from the scene snapshot's planets.
  void setPlanets(List<OrbitPlanet> planets, {bool animate = true}) =>
      setBodies([for (final p in planets) PlanetBody.fromOrbitPlanet(p)], animate: animate);

  void _syncMoons(_BodyState st, {required bool animate}) {
    final moons = st.body.moons;
    final count = moons.length;
    final old = Map.of(st.moons);
    st.moons.clear();
    for (var j = 0; j < count; j++) {
      final m = moons[j];
      final lane = MoonLayout.laneOf(j, count, st.body.archetype);
      var ms = old.remove(m.id);
      if (ms == null) {
        ms = _MoonState(
          m,
          lane: lane,
          angle: MoonLayout.initialAngle(j, count, m.seed) + 2 * math.pi * _time / MoonLayout.periodOf(lane),
          appear: animate && !_reducedMotion ? 0 : 1,
        );
      } else {
        ms.moon = m;
        ms.frame.moon = m;
        if (ms.lane.target != lane) {
          if (animate && !_reducedMotion) {
            ms.lane.retarget(lane, time: _time);
          } else {
            ms.lane.jumpTo(lane);
          }
        }
      }
      st.moons[m.id] = ms;
      living.setScore(moonKey(m.id), m.score, animate: animate);
    }
  }

  OrbitCamera _camera;
  OrbitCamera get camera => _camera;
  set camera(OrbitCamera value) {
    if (_sameCamera(value, _camera)) return;
    _camera = value;
    _dirty = true;
    _guides.ping();
    notifyListeners();
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

  String? _selectedKey;

  /// The highlighted world (its orbit guide glows, its label leads).
  String? get selectedKey => _selectedKey;
  set selectedKey(String? value) {
    if (value == _selectedKey) return;
    _selectedKey = value;
    _dirty = true;
    _guides.ping();
    notifyListeners();
  }

  String? _selectedMoonId;

  /// The moon wearing the selection ring (`data_moon.frag` uExtra.y).
  String? get selectedMoonId => _selectedMoonId;
  set selectedMoonId(String? value) {
    if (value == _selectedMoonId) return;
    _selectedMoonId = value;
    _dirty = true;
    notifyListeners();
  }

  Rect? _labelArea;

  /// Where name labels may sit (layer coordinates; null = the whole
  /// viewport): the band between the header and the glass panel.
  Rect? get labelArea => _labelArea;
  set labelArea(Rect? value) {
    if (value == _labelArea) return;
    _labelArea = value;
    notifyListeners();
  }

  List<Rect> _labelKeepOut = const [];

  /// Rects no label may cover (on-scene buttons).
  List<Rect> get labelKeepOut => _labelKeepOut;
  set labelKeepOut(List<Rect> value) {
    if (listEquals(value, _labelKeepOut)) return;
    _labelKeepOut = value;
    notifyListeners();
  }

  String? _labelCluster;

  /// Zoomed in: only this world's label and its moons' names show (the
  /// rest fade); an empty key keeps every world's label down (zoomed into
  /// the dial). Null: every label.
  String? get labelCluster => _labelCluster;
  set labelCluster(String? value) {
    if (value == _labelCluster) return;
    _labelCluster = value;
    _dirty = true;
    notifyListeners();
  }

  String? _focusKey;
  double _focus = 0;
  double _labelsOut = 0;

  /// How far the other worlds' labels have faded for a fly-in (0..1; they
  /// leave early, before the camera really moves).
  double get labelsOut => _labelsOut;

  /// The world a fly-in is heading to, and the fly-in progress 0..1: the
  /// other worlds' labels, moon labels and orbit guides fade out as it
  /// rises; the focused world's moons show their names.
  String? get focusKey => _focusKey;
  double get focus => _focus;

  void setFocus(String? key, double progress, {double? labelsOut}) {
    final p = key == null ? 0.0 : progress.clamp(0.0, 1.0);
    final l = key == null ? 0.0 : (labelsOut ?? p).clamp(0.0, 1.0);
    if (key == _focusKey && p == _focus && l == _labelsOut) return;
    _focusKey = key;
    _focus = p;
    _labelsOut = l;
    _dirty = true;
    _guides.ping();
    notifyListeners();
  }

  bool _reducedMotion = false;

  /// Reduced motion: a static scene – the clock stops, springs and fades
  /// jump, pulses do not flare.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    living.reducedMotion = value;
    if (value) {
      for (final b in _bodies) {
        b.lane.jumpTo(b.lane.target);
        for (final m in b.moons.values) {
          m.lane.jumpTo(m.lane.target);
          m.appear = 1;
        }
      }
      // A glide home in progress lands at once (the clock stops).
      if (respreading) _stepHome(1);
      planetLabels.settle();
      moonLabels.settle();
    }
    _dirty = true;
    _guides.ping();
    notifyListeners();
  }

  // ------------------------------------------------------------- animation --

  double _time;

  /// The clock when the scene started: the worlds' "home" positions (a
  /// golden angle apart) are where they stood then.
  final double _startTime;

  /// Shader clock in seconds (frozen under reduced motion).
  double get time => _time;

  // ------------------------------------------------------------------ home --

  /// Seconds a [respread] glide takes.
  static const double respreadSeconds = 1.1;

  static const Curve _respreadCurve = Curves.easeInOutCubic;

  double _respreadT = 1;
  double _homeAt;

  /// Worlds are gliding home ([respread]).
  bool get respreading => _respreadT < 1;

  int _labelLayoutEpoch = 0;

  /// Bumped by [relayoutLabels]: the label painters then forget the spots
  /// their labels held (hysteresis) and place every label afresh.
  int get labelLayoutEpoch => _labelLayoutEpoch;

  /// Lets every name label choose its spot anew – as on a fresh start –
  /// rather than keep the side an earlier view gave it.
  void relayoutLabels() {
    _labelLayoutEpoch++;
    notifyListeners();
  }

  /// Seconds of orbit since the worlds last stood at home (the start, or
  /// the end of the last [respread]).
  double get secondsSinceHome => math.max(0, _time - _homeAt);

  /// The angle the [index]-th of [count] worlds (of [seed]) stands at when
  /// the scene starts: [PlanetSystemLayout.initialAngle] turned by its line
  /// of nodes, so the worlds' apparent longitudes are evenly spread and no
  /// two of them overlap.
  double homeAngleOf(int index, int count, double seed) =>
      layout.initialAngle(index) +
      layout.nodeOf(seed) +
      layout.angularSpeedFor(layout.laneRadius(index, count)) * _startTime;

  /// Glides every world – and every moon around it – along its orbit, the
  /// short way round, back to where it stood when the scene started: the
  /// even, non-overlapping layout of a fresh start (the worlds orbit at
  /// different speeds, so over minutes they drift into each other). They
  /// keep orbiting meanwhile, so afterwards the system is exactly what a
  /// fresh start shows [respreadSeconds] later. Without [animate] (or under
  /// reduced motion) they jump.
  void respread({bool animate = true}) {
    final count = _bodies.length;
    for (var i = 0; i < count; i++) {
      final st = _bodies[i];
      st
        ..homeDelta = _arc(st.angle, homeAngleOf(i, count, st.body.seed))
        ..homeApplied = 0;
      final moons = st.moons.values.toList();
      for (var j = 0; j < moons.length; j++) {
        final ms = moons[j];
        final lane = MoonLayout.laneOf(j, moons.length, st.body.archetype);
        final home =
            MoonLayout.initialAngle(j, moons.length, ms.moon.seed) + _tau * _startTime / MoonLayout.periodOf(lane);
        ms
          ..homeDelta = _arc(ms.angle, home)
          ..homeApplied = 0;
      }
    }
    _homeAt = _time;
    _respreadT = 0;
    if (!animate || _reducedMotion) _stepHome(1);
    _dirty = true;
    _guides.ping();
    notifyListeners();
  }

  /// Moves the glide home on to progress [t] (0..1).
  void _stepHome(double t) {
    _respreadT = t.clamp(0.0, 1.0);
    final e = _respreadT >= 1 ? 1.0 : _respreadCurve.transform(_respreadT);
    for (final b in _bodies) {
      final want = b.homeDelta * e;
      b.angle = (b.angle + want - b.homeApplied) % _tau;
      b.homeApplied = want;
      for (final m in b.moons.values) {
        final w = m.homeDelta * e;
        m.angle = (m.angle + w - m.homeApplied) % _tau;
        m.homeApplied = w;
      }
    }
    if (_respreadT >= 1) {
      _homeAt = _time;
      for (final b in _bodies) {
        b.homeDelta = b.homeApplied = 0;
        for (final m in b.moons.values) {
          m.homeDelta = m.homeApplied = 0;
        }
      }
    }
  }

  /// Signed shortest turn from [from] to [to] (radians, −π … π).
  static double _arc(double from, double to) {
    var d = (to - from) % _tau;
    if (d > math.pi) d -= _tau;
    return d;
  }

  /// Whether two worlds on screen overlap by more than [overlap] px – their
  /// orbits have carried them in front of each other (a fresh start never
  /// shows that).
  bool crowded(Size viewport, {double overlap = 4}) {
    if (viewport.isEmpty) return false;
    final bodies = frameFor(viewport).bodies;
    for (var i = 0; i < bodies.length; i++) {
      final a = bodies[i];
      if (!a.visible) continue;
      for (var j = i + 1; j < bodies.length; j++) {
        final b = bodies[j];
        if (!b.visible) continue;
        if ((a.center - b.center).distance < a.radius + b.radius - overlap) return true;
      }
    }
    return false;
  }

  /// A spring, pulse, arrival or fade is running – tick at full rate; when
  /// false the scene may idle at 30 fps (the orbits still drift).
  bool get isAnimating {
    if (respreading || living.isAnimating || planetLabels.isAnimating || moonLabels.isAnimating) return true;
    for (final b in _bodies) {
      if (!b.lane.isAtRest) return true;
      for (final m in b.moons.values) {
        if (!m.lane.isAtRest || m.appear < 1) return true;
      }
    }
    return false;
  }

  void advance(Duration dt) => advanceSeconds(dt.inMicroseconds / 1e6);

  /// Moves everything on by [dt] seconds and repaints.
  void advanceSeconds(double dt) {
    if (dt <= 0) return;
    if (_reducedMotion) {
      planetLabels.settle();
      moonLabels.settle();
      _dirty = true;
      notifyListeners();
      return;
    }
    _time += dt;
    for (final b in _bodies) {
      if (!b.lane.isAtRest) {
        b.lane.advanceTo(_time);
      }
      b.angle = (b.angle + layout.angularSpeedFor(b.lane.value) * dt) % _tau;
      for (final m in b.moons.values) {
        if (!m.lane.isAtRest) m.lane.advanceTo(_time);
        m.angle = (m.angle + _tau * dt / MoonLayout.periodOf(m.lane.value)) % _tau;
        if (m.appear < 1) m.appear = math.min(1, m.appear + dt / 0.5);
      }
    }
    // The glide home rides on top of the orbits.
    if (respreading) _stepHome(_respreadT + dt / respreadSeconds);
    living.advance(dt);
    planetLabels.advance(dt);
    moonLabels.advance(dt);
    _dirty = true;
    // The worlds moved: their orbit wakes follow them.
    _guides.ping();
    notifyListeners();
  }

  // ---------------------------------------------------------------- pulses --

  void addPulseListener(PlanetPulseListener l) => _pulseListeners.add(l);
  void removePulseListener(PlanetPulseListener l) => _pulseListeners.remove(l);

  /// A completion for [PlanetPulse.planetKey]: the world flares (0 → 1 → 0
  /// over 1.5 s); a moon whose record the pulse names flares fully, the
  /// others sympathise softly. Pulse listeners are told (particles, chime).
  /// Returns whether the world is shown.
  bool pulse(PlanetPulse p) {
    final st = _state(p.planetKey);
    if (st == null) return false;
    final strength = math.min(1.0, 0.85 + 0.075 * (p.count - 1));
    living.pulse(p.planetKey, strength: strength);
    final named = p.refTable != null && p.refId != null ? '${p.refTable}:${p.refId}' : null;
    for (final id in st.moons.keys) {
      living.pulse(moonKey(id), strength: id == named ? 1 : 0.35);
    }
    _dirty = true;
    notifyListeners();
    for (final l in List<PlanetPulseListener>.of(_pulseListeners)) {
      l(p);
    }
    return true;
  }

  // ----------------------------------------------------------------- frame --

  final PlanetFrame _frame = PlanetFrame();
  final ScreenProjector _projector = ScreenProjector();
  bool _dirty = true;
  int _frameId = 0;

  /// Everything projected for [viewport] (cached until the next change).
  PlanetFrame frameFor(Size viewport) {
    if (!_dirty && _frame.viewport == viewport && _frame.id != 0) return _frame;
    _build(viewport);
    _dirty = false;
    return _frame;
  }

  /// The last built frame (for hit tests between paints).
  PlanetFrame get lastFrame => _frame;

  /// What a tap at [local] (layer coordinates) hits.
  OrbitHit? hitTest(Offset local, Size viewport) => frameFor(viewport).hitTest(local);

  /// World position and disc radius of a planet now (camera fly-in target).
  (V3, double)? worldOf(String key) {
    final st = _state(key);
    if (st == null) return null;
    return (
      PlanetSystemLayout.orbitPoint(st.lane.value, st.angle, inclination: st.inclination, node: st.node),
      st.worldRadius,
    );
  }

  /// A camera that frames [key] so its disc radius is [fill] × half the
  /// viewport's shorter side, at a three-quarter angle to the star (see
  /// [PlanetFraming.cameraFor]) – the fly-in's end camera.
  OrbitCamera? framingCamera(
    String key, {
    required OrbitCamera from,
    required Size viewport,
    double fill = 0.42,
    bool aroundStar = true,
  }) {
    final w = worldOf(key);
    if (w == null) return null;
    OrbitCamera frame({int? side}) => PlanetFraming.cameraFor(
      from: from,
      target: w.$1,
      worldRadius: w.$2,
      viewport: viewport,
      fill: fill,
      star: star,
      aroundStar: aroundStar,
      side: side,
    );
    final preferred = frame();
    if (!aroundStar || !_occluded(key, preferred, viewport)) return preferred;
    // The short way round looks through a neighbour: try the other side.
    final a = frame(side: 1), b = frame(side: -1);
    final other = _sameCamera(a, preferred) ? b : a;
    return _occluded(key, other, viewport) ? preferred : other;
  }

  /// Whether another world (or its moon band) would sit in front of [key]
  /// seen through [camera].
  bool _occluded(String key, OrbitCamera camera, Size viewport) {
    final target = _state(key);
    if (target == null) return false;
    final pr = ScreenProjector()..configure(camera, viewport);
    final tw = PlanetSystemLayout.orbitPoint(
      target.lane.value,
      target.angle,
      inclination: target.inclination,
      node: target.node,
    );
    if (!pr.project(tw.x, tw.y, tw.z)) return false;
    final tc = Offset(pr.x, pr.y), td = pr.depth, tr = target.worldRadius * pr.scale;
    for (final st in _bodies) {
      if (identical(st, target)) continue;
      final p = PlanetSystemLayout.orbitPoint(st.lane.value, st.angle, inclination: st.inclination, node: st.node);
      if (!pr.project(p.x, p.y, p.z) || pr.depth >= td) continue;
      final reach = tr * 1.1 + st.worldRadius * pr.scale * (st.moons.isEmpty ? st.body.haloFactor : 3.2);
      if ((Offset(pr.x, pr.y) - tc).distance < reach) return true;
    }
    return false;
  }

  _BodyState? _state(String key) {
    for (final b in _bodies) {
      if (b.body.key == key) return b;
    }
    return null;
  }

  void _build(Size viewport) {
    final f = _frame;
    final pr = _projector..configure(_camera, viewport);
    f
      ..viewport = viewport
      ..camera = _camera
      ..id = ++_frameId;
    pr.project(star.x, star.y, star.z);
    f
      ..coreCenter = Offset(pr.x, pr.y)
      ..coreDepth = pr.depth
      ..coreRadius = pr.depth > 0.05 ? coreRadius * pr.scale : 0;
    f.bodies.clear();
    f.drawOrder.clear();
    final focusKey = _focusKey;
    for (var i = 0; i < _bodies.length; i++) {
      final st = _bodies[i];
      final b = st.frame
        ..body = st.body
        ..index = i;
      final world = PlanetSystemLayout.orbitPoint(st.lane.value, st.angle, inclination: st.inclination, node: st.node);
      final inFront = pr.project(world.x, world.y, world.z);
      b
        ..world = world
        ..worldRadius = st.worldRadius
        ..lane = st.lane.value
        ..inclination = st.inclination
        ..node = st.node
        ..angle = st.angle
        ..center = Offset(pr.x, pr.y)
        ..depth = pr.depth
        ..radius = inFront ? st.worldRadius * pr.scale : 0
        ..behindCore = pr.depth > f.coreDepth;
      final halo = st.body.haloFactor;
      b.drawRect = Rect.fromCircle(center: b.center, radius: b.radius * halo);
      b.visible =
          inFront &&
          pr.depth > st.worldRadius + 0.02 &&
          b.radius >= 0.5 &&
          PlanetViewMath.onScreen(b.drawRect, viewport);
      b.coreOcclusion = b.behindCore && b.visible
          ? PlanetViewGhost.occlusion(b.center, b.radius, f.coreCenter, f.coreRadius)
          : 0;
      final (lx, ly, lz) = PlanetViewMath.lightInView(world, star, pr.right, pr.up, pr.forward);
      b
        ..lightX = lx
        ..lightY = ly
        ..lightZ = lz
        // Angles are wrapped in double precision before they become float32
        // uniforms (hours-long sessions stay exact).
        ..spin = (st.spinPhase + _tau * _time / st.spinPeriod) % _tau
        ..tilt = st.tilt
        ..score = living.score(st.body.key)
        ..pulse = living.pulseOf(st.body.key)
        ..detail = PlanetViewMath.detailFor(b.radius);
      final cluster = _labelCluster == null || _labelCluster == st.body.key ? 1.0 : 0.0;
      final focusFactor = (focusKey == null || focusKey == st.body.key ? 1.0 : 1 - _labelsOut) * cluster;
      // Every name leaves early in a fly-in (the page's header names the
      // world); its moons' names come back as it fills the screen.
      final labelFactor = (focusKey == null ? 1.0 : 1 - _labelsOut) * cluster;
      b.labelTarget = b.visible
          ? PlanetViewMath.smoothstep(6, 11, b.radius) *
                (1 - PlanetViewMath.smoothstep(130, 180, b.radius)) *
                labelFactor
          : 0;
      b.guideOpacity = focusKey == null ? 1 : (focusKey == st.body.key ? 1 - 0.6 * _focus : 1 - _focus);
      _buildMoons(st, b, pr, viewport, focusFactor);
      f.bodies.add(b);
      if (b.visible || _anyMoonVisible(b)) f.drawOrder.add(b);
    }
    f.drawOrder.sort(_farFirst);
    _fadeOccluders(f);
    _hazeByDepth(f);
  }

  /// Opacity of the astrolabe (it fades in a fly-in): the ghosts of the
  /// worlds behind it fade with it. Set by the scene before each frame.
  double coreOpacity = 1;

  Color? _skyAmbient;

  /// The sky's colour: every world's night side takes a little of it (a
  /// world never goes pure black on a daylit sky) and far worlds sink into
  /// it (aerial perspective). Null: no sky light.
  Color? get skyAmbient => _skyAmbient;
  set skyAmbient(Color? value) {
    if (value == _skyAmbient) return;
    _skyAmbient = value;
    _skyDark = value != null && value.computeLuminance() < skyDarkLuminance;
    notifyListeners();
  }

  /// Below this relative luminance the sky counts as dark (labels and
  /// guides take their night ink on a light theme).
  static const double skyDarkLuminance = 0.06;

  bool _skyDark = false;

  /// Whether the sky behind the worlds is dark ([skyAmbient]).
  bool get skyDark => _skyDark;

  /// Depth order → [BodyFrame.haze] (the fly-in's world stays clear).
  void _hazeByDepth(PlanetFrame f) {
    var lo = double.infinity, hi = -double.infinity;
    for (final b in f.bodies) {
      if (!b.visible) continue;
      lo = math.min(lo, b.depth);
      hi = math.max(hi, b.depth);
    }
    final span = hi - lo;
    for (final b in f.bodies) {
      b.haze = !b.visible || span < 1e-6 || b.key == _focusKey ? 0 : ((b.depth - lo) / span).clamp(0.0, 1.0);
    }
  }

  /// During a fly-in, worlds (and their moons) between the camera and the
  /// focused world fade out so they never hide it.
  void _fadeOccluders(PlanetFrame f) {
    for (final b in f.bodies) {
      b.opacity = 1;
      for (final m in b.moons) {
        m.opacity = 1;
      }
    }
    final key = _focusKey;
    if (key == null || _focus <= 0) return;
    final target = f.body(key);
    if (target == null) return;
    final fade = 1 - PlanetViewMath.smoothstep(0.15, 0.7, _focus);
    for (final b in f.bodies) {
      if (identical(b, target) || b.depth >= target.depth) continue;
      final reach = target.radius * 1.1 + b.radius * b.body.haloFactor;
      final hides = (b.center - target.center).distance < reach;
      var moonsHide = false;
      for (final m in b.moons) {
        if ((m.center - target.center).distance < target.radius * 1.1 + m.radius * 1.6) moonsHide = true;
      }
      if (!hides && !moonsHide) continue;
      b.opacity = fade;
      for (final m in b.moons) {
        m.opacity = fade;
      }
    }
  }

  static int _farFirst(BodyFrame a, BodyFrame b) => b.depth.compareTo(a.depth);

  static bool _anyMoonVisible(BodyFrame b) {
    for (final m in b.moons) {
      if (m.visible) return true;
    }
    return false;
  }

  void _buildMoons(_BodyState st, BodyFrame b, ScreenProjector pr, Size viewport, double focusFactor) {
    b.moons.clear();
    if (st.moons.isEmpty) return;
    // Moon names appear once the world is big enough to tell its moons
    // apart, and then read clearly (never fainter than 70 %).
    final zoomIn = PlanetViewMath.smoothstep(34, 46, b.radius);
    final labelZoom = zoomIn <= 0.02 ? 0.0 : 0.7 + 0.3 * zoomIn;
    final moonSelected = _selectedMoonId;
    for (final ms in st.moons.values) {
      final m = ms.frame..moon = ms.moon;
      final rel = PlanetSystemLayout.orbitPoint(
        ms.lane.value * st.worldRadius,
        ms.angle,
        inclination: ms.inclination,
        node: ms.node,
      );
      final w = b.world + rel;
      final inFront = pr.project(w.x, w.y, w.z);
      final grow = ms.appear >= 1 ? 1.0 : OrbitEasing.easeOutBack(ms.appear);
      m
        ..world = w
        ..worldRadius = st.worldRadius * MoonStyle.radiusFactor(ms.moon.size, parentPx: b.radius) * grow
        ..center = Offset(pr.x, pr.y)
        ..depth = pr.depth
        ..front = pr.depth < b.depth;
      m.radius = inFront ? m.worldRadius * pr.scale : 0;
      m.drawRect = Rect.fromCircle(center: m.center, radius: m.radius * 1.6);
      m.visible = inFront && m.radius >= 0.6 && PlanetViewMath.onScreen(m.drawRect, viewport);
      final (lx, ly, lz) = PlanetViewMath.lightInView(w, star, pr.right, pr.up, pr.forward);
      final key = moonKey(ms.moon.id);
      m
        ..lightX = lx
        ..lightY = ly
        ..lightZ = lz
        ..spin = (_tau * ((ms.moon.seed * 0.37) % 1) + _time * 0.09) % _tau
        ..tilt = 0.3
        ..score = living.score(key)
        ..pulse = living.pulseOf(key)
        ..detail = (m.radius / 60).clamp(0.05, 1.0)
        ..selected = ms.moon.id == moonSelected ? 1 : 0
        ..appear = ms.appear;
      m.labelTarget = m.visible ? labelZoom * focusFactor * PlanetViewMath.smoothstep(0.3, 1, ms.appear) : 0;
      b.moons.add(m);
    }
  }

  @override
  void dispose() {
    _pulseListeners.clear();
    _guides.dispose();
    super.dispose();
  }
}

/// Camera framing for a fly-in to one world (pure).
abstract final class PlanetFraming {
  /// Angle between the view and the light at the end of a fly-in: the world
  /// shows a three-quarter lit face and the astrolabe stays out of frame.
  static const threeQuarter = 1.05;

  /// Highest camera elevation of a close-up (a lower, more cinematic view
  /// than the overview's).
  static const maxElevation = 0.42;

  /// A camera looking at [target] at the distance where a sphere of
  /// [worldRadius] shows a disc of [fill] × half the viewport's shorter
  /// side.
  ///
  /// With [aroundStar] (the default) the camera also swings to a
  /// three-quarter angle off the line from the world to the [star] – on the
  /// side nearer [from]'s azimuth (so a fly-in turns the short way) unless
  /// [side] (+1 / −1) picks one – so it never looks at the world through
  /// the astrolabe nor from its night side. Otherwise [from]'s angles are
  /// kept.
  static OrbitCamera cameraFor({
    required OrbitCamera from,
    required V3 target,
    required double worldRadius,
    required Size viewport,
    double fill = 0.42,
    V3 star = V3.zero,
    bool aroundStar = true,
    int? side,
  }) {
    final px = fill * math.min(viewport.width, viewport.height) / 2;
    final distance = from.focalPx(viewport) * worldRadius / math.max(px, 1);
    if (!aroundStar) return from.copyWith(target: target, distance: distance);
    final dx = star.x - target.x, dz = star.z - target.z;
    if (dx * dx + dz * dz < 1e-9) return from.copyWith(target: target, distance: distance);
    // Azimuth of the direction from the world toward the star.
    final toStar = math.atan2(dx, dz);
    final a = toStar + threeQuarter, b = toStar - threeQuarter;
    final azimuth = side == null
        ? (_arc(from.azimuth, a).abs() <= _arc(from.azimuth, b).abs() ? a : b)
        : (side >= 0 ? a : b);
    return from.copyWith(
      target: target,
      distance: distance,
      azimuth: from.azimuth + _arc(from.azimuth, azimuth),
      elevation: math.min(from.elevation, maxElevation),
    );
  }

  /// Signed shortest arc from [a] to [b].
  static double _arc(double a, double b) {
    var d = (b - a) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    return d;
  }
}

/// Tiny easing helpers (no allocation).
abstract final class OrbitEasing {
  /// Overshooting ease-out for a moon popping into its lane.
  static double easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final x = t - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
