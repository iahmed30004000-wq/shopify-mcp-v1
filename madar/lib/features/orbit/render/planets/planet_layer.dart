import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/motion/particles/celebration.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/neglect_text.dart' show planetStateLabel;
import '../../domain/orbit_moons.dart';
import '../../domain/planet_pulse.dart';
import '../../domain/scene_math.dart';
import '../orbit_shaders.dart';
import 'planet_body.dart';
import 'planet_frame.dart';
import 'planet_layout.dart';
import 'planet_painters.dart';
import 'planet_renderer.dart';
import 'planet_scene_controller.dart';

/// A world was tapped / long-pressed; [rect] is its disc on screen (local
/// to the layer) – e.g. the origin of a cosmic-zoom fly-in.
typedef PlanetTapCallback = void Function(String planetKey, Rect rect);

/// A data moon was tapped; open `moon.refTable` / `moon.refId`.
typedef MoonTapCallback = void Function(OrbitMoon moon, String planetKey, Rect rect);

/// A world pulsed; [center] is its disc centre in global coordinates.
typedef PlanetPulseFeedback = void Function(PlanetPulse pulse, Offset center, double radius);

// ------------------------------------------------------------ building blocks --

/// The orbit guides alone (one RepaintBoundary, repaints only when the camera,
/// lanes, selection or focus change).
class OrbitGuidesView extends StatefulWidget {
  const OrbitGuidesView({super.key, required this.controller, this.style});

  final PlanetSceneController controller;

  /// Defaults to the theme's tokens.
  final PlanetLayerStyle? style;

  @override
  State<OrbitGuidesView> createState() => _OrbitGuidesViewState();
}

class _OrbitGuidesViewState extends State<OrbitGuidesView> {
  final OrbitGuideCache _cache = OrbitGuideCache();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: OrbitGuidesPainter(
        controller: widget.controller,
        style: widget.style ?? PlanetLayerStyle.fromTokens(context.tokens),
        cache: _cache,
      ),
    ),
  );
}

/// The worlds and moons of one [pass] (e.g. those behind the astrolabe) in
/// their own RepaintBoundary. Shares [renderer] when given (several passes
/// → one set of shader instances); otherwise loads the orbit shaders and owns
/// a renderer (a lit-sphere fallback paints until they are ready).
class PlanetBodiesView extends StatefulWidget {
  const PlanetBodiesView({
    super.key,
    required this.controller,
    this.renderer,
    this.pass = PlanetPass.all,
    this.filter = PlanetFocusFilter.any,
    this.ghosts = false,
  });

  final PlanetSceneController controller;
  final PlanetRenderer? renderer;
  final PlanetPass pass;
  final PlanetFocusFilter filter;

  /// A [PlanetPass.frontOfCore] pass also draws the worlds hidden behind
  /// the dial as gold-rimmed ghosts over it.
  final bool ghosts;

  @override
  State<PlanetBodiesView> createState() => _PlanetBodiesViewState();
}

class _PlanetBodiesViewState extends State<PlanetBodiesView> {
  PlanetRenderer? _own;

  @override
  void initState() {
    super.initState();
    if (widget.renderer == null) _loadRenderer();
  }

  @override
  void didUpdateWidget(PlanetBodiesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.renderer != null && _own != null) {
      // A shared renderer arrived: drop the stand-in.
      _own!.dispose();
      _own = null;
    } else if (widget.renderer == null && _own == null) {
      _loadRenderer();
    }
  }

  void _loadRenderer() {
    final ready = OrbitShaders.instance;
    if (ready != null) {
      _own = PlanetRenderer(ready);
      return;
    }
    unawaited(
      OrbitShaders.load().then((s) {
        if (!mounted || _own != null || widget.renderer != null) return;
        setState(() => _own = PlanetRenderer(s));
      }, onError: (Object _) {}),
    );
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: PlanetBodiesPainter(
        controller: widget.controller,
        renderer: widget.renderer ?? _own,
        pass: widget.pass,
        filter: widget.filter,
        ghostRim: widget.ghosts ? context.tokens.gold : null,
        ghostShade: widget.ghosts ? context.tokens.space0 : null,
      ),
    ),
  );
}

/// Planet and moon name labels in their own RepaintBoundary.
class PlanetLabelsView extends StatefulWidget {
  const PlanetLabelsView({super.key, required this.controller, this.style, this.snap = false});

  final PlanetSceneController controller;
  final PlanetLayerStyle? style;

  /// Show labels at once (stills / tests), no fade.
  final bool snap;

  @override
  State<PlanetLabelsView> createState() => _PlanetLabelsViewState();
}

class _PlanetLabelsViewState extends State<PlanetLabelsView> {
  final PlanetLabelCache _cache = PlanetLabelCache();

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: PlanetLabelsPainter(
        controller: widget.controller,
        style:
            widget.style ??
            PlanetLayerStyle.fromTokens(context.tokens, textScale: MediaQuery.textScalerOf(context).scale(1)),
        cache: _cache,
        textDirection: Directionality.of(context),
        snap: widget.snap,
      ),
    ),
  );
}

/// Depth of field for a fly-in: blurs [child] (the unfocused worlds, e.g. a
/// [PlanetBodiesView] with [PlanetFocusFilter.unfocusedOnly]) as the
/// controller's focus rises, up to [maxSigma]. It rebuilds only when the
/// blur changes by a visible step (≤ 1/20 of the range), never per tick.
class PlanetFocusBlur extends StatefulWidget {
  const PlanetFocusBlur({super.key, required this.controller, required this.child, this.maxSigma = 5});

  final PlanetSceneController controller;
  final Widget child;
  final double maxSigma;

  @override
  State<PlanetFocusBlur> createState() => _PlanetFocusBlurState();
}

class _PlanetFocusBlurState extends State<PlanetFocusBlur> {
  int _step = 0;

  static const _steps = 20;

  int get _target => widget.controller.focusKey == null ? 0 : (widget.controller.focus * _steps).round();

  @override
  void initState() {
    super.initState();
    _step = _target;
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(PlanetFocusBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _step = _target;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final t = _target;
    if (t != _step && mounted) setState(() => _step = t);
  }

  @override
  Widget build(BuildContext context) {
    final sigma = widget.maxSigma * _step / _steps;
    // Same tree shape whether blurred or not, so the child keeps its state.
    return ImageFiltered(
      enabled: sigma >= 0.3,
      imageFilter: ImageFilter.blur(sigmaX: math.max(sigma, 0.01), sigmaY: math.max(sigma, 0.01)),
      child: widget.child,
    );
  }
}

/// Makes the worlds and moons tappable – and nothing else: taps and drags
/// on empty sky fall through to the scene underneath (rotate, pinch …).
///
/// Taps fire `Sfx.navigate` (a world: fly-in) or `Sfx.tap` (a moon: open
/// the item); a long press on a world fires `Sfx.pickUp` (customise).
class PlanetHitRegion extends StatelessWidget {
  const PlanetHitRegion({
    super.key,
    required this.controller,
    this.onPlanetTap,
    this.onPlanetLongPress,
    this.onMoonTap,
  });

  final PlanetSceneController controller;
  final PlanetTapCallback? onPlanetTap;
  final PlanetTapCallback? onPlanetLongPress;
  final MoonTapCallback? onMoonTap;

  bool _handles(OrbitHit hit) => hit.isMoon ? onMoonTap != null : (onPlanetTap != null || onPlanetLongPress != null);

  @override
  Widget build(BuildContext context) {
    OrbitHit? pending;
    return _HitRegion(
      controller: controller,
      accepts: _handles,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => pending = controller.hitTest(d.localPosition, controller.lastFrame.viewport),
        onTapCancel: () => pending = null,
        onTapUp: (d) {
          final hit = pending ?? controller.hitTest(d.localPosition, controller.lastFrame.viewport);
          pending = null;
          if (hit == null) return;
          final moon = hit.moon;
          final onMoon = onMoonTap, onPlanet = onPlanetTap;
          if (moon != null && onMoon != null) {
            Fx.fire(Sfx.tap);
            onMoon(moon, hit.planetKey, hit.rect);
          } else if (moon == null && onPlanet != null) {
            Fx.fire(Sfx.navigate);
            onPlanet(hit.planetKey, hit.rect);
          }
        },
        onLongPressStart: onPlanetLongPress == null
            ? null
            : (d) {
                final hit = controller.hitTest(d.localPosition, controller.lastFrame.viewport);
                if (hit == null) return;
                Fx.fire(Sfx.pickUp);
                final rect = controller.lastFrame.planetRect(hit.planetKey) ?? hit.rect;
                onPlanetLongPress!(hit.planetKey, rect);
              },
      ),
    );
  }
}

class _HitRegion extends SingleChildRenderObjectWidget {
  const _HitRegion({required this.controller, required this.accepts, super.child});

  final PlanetSceneController controller;
  final bool Function(OrbitHit hit) accepts;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitRegion(controller, accepts);

  @override
  void updateRenderObject(BuildContext context, _RenderHitRegion renderObject) => renderObject
    ..controller = controller
    ..accepts = accepts;
}

/// Hit-testable only over a body that has a handler.
class _RenderHitRegion extends RenderProxyBox {
  _RenderHitRegion(this.controller, this.accepts);

  PlanetSceneController controller;
  bool Function(OrbitHit hit) accepts;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final hit = controller.hitTest(position, size);
    if (hit == null || !accepts(hit)) return false;
    return super.hitTest(result, position: position);
  }
}

/// Screen-reader nodes for the worlds and moons (rebuilt when the bodies
/// change and every couple of seconds as they drift – never per frame).
class PlanetSemanticsView extends StatefulWidget {
  const PlanetSemanticsView({
    super.key,
    required this.controller,
    this.onPlanetTap,
    this.onPlanetLongPress,
    this.onMoonTap,
  });

  final PlanetSceneController controller;
  final PlanetTapCallback? onPlanetTap;
  final PlanetTapCallback? onPlanetLongPress;
  final MoonTapCallback? onMoonTap;

  @override
  State<PlanetSemanticsView> createState() => _PlanetSemanticsViewState();
}

class _PlanetSemanticsViewState extends State<PlanetSemanticsView> {
  int _epoch = 0;
  int _version = -1;
  double _lastTime = -1e9;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    widget.controller.guides.addListener(_onCamera);
  }

  @override
  void didUpdateWidget(PlanetSemanticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      oldWidget.controller.guides.removeListener(_onCamera);
      widget.controller.addListener(_onTick);
      widget.controller.guides.addListener(_onCamera);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    widget.controller.guides.removeListener(_onCamera);
    super.dispose();
  }

  bool _cameraPending = false;

  /// The camera moved while the scene clock stands still (reduced motion:
  /// a drag turns the system but no time passes): the rects follow, at
  /// most once a frame.
  void _onCamera() {
    if (!widget.controller.reducedMotion || _cameraPending || !mounted) return;
    _cameraPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _cameraPending = false;
      if (mounted) setState(() => _epoch++);
    });
  }

  void _onTick() {
    final c = widget.controller;
    if (c.bodiesVersion != _version || (c.time - _lastTime).abs() >= 2) {
      _version = c.bodiesVersion;
      _lastTime = c.time;
      if (mounted) setState(() => _epoch++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = context.formatter;
    final count = widget.controller.bodies.length;
    return Semantics(
      container: true,
      label: l10n.planetsSystemSemantics(count, fmt.formatInt(count)),
      child: CustomPaint(
        size: Size.infinite,
        painter: _PlanetSemanticsPainter(
          controller: widget.controller,
          epoch: _epoch,
          l10n: l10n,
          formatter: fmt,
          textDirection: Directionality.of(context),
          onPlanetTap: widget.onPlanetTap,
          onPlanetLongPress: widget.onPlanetLongPress,
          onMoonTap: widget.onMoonTap,
        ),
      ),
    );
  }
}

class _PlanetSemanticsPainter extends CustomPainter {
  _PlanetSemanticsPainter({
    required this.controller,
    required this.epoch,
    required this.l10n,
    required this.formatter,
    required this.textDirection,
    this.onPlanetTap,
    this.onPlanetLongPress,
    this.onMoonTap,
  });

  final PlanetSceneController controller;
  final int epoch;
  final L10n l10n;
  final MadarFormatter formatter;
  final TextDirection textDirection;
  final PlanetTapCallback? onPlanetTap;
  final PlanetTapCallback? onPlanetLongPress;
  final MoonTapCallback? onMoonTap;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final f = controller.frameFor(size);
    final nodes = <CustomPainterSemantics>[];
    for (final b in f.bodies) {
      if (!b.visible) continue;
      final body = b.body;
      final name = formatter.isolate(body.name.trim());
      final moons = body.moons.isEmpty
          ? null
          : l10n.planetsMoonsCount(body.moons.length, formatter.formatInt(body.moons.length));
      final rect = Rect.fromCircle(center: b.center, radius: math.max(b.radius, 12));
      nodes.add(
        CustomPainterSemantics(
          key: ValueKey('planet:${body.key}'),
          rect: rect,
          properties: SemanticsProperties(
            label: l10n.orbitPlanetSemantics(
              name,
              planetStateLabel(l10n, body.state),
              formatter.formatPercent(body.score),
            ),
            value: moons,
            button: true,
            textDirection: textDirection,
            hintOverrides: SemanticsHintOverrides(
              onTapHint: l10n.planetsOpenHint,
              onLongPressHint: onPlanetLongPress == null ? null : l10n.planetsCustomizeHint,
            ),
            onTap: onPlanetTap == null ? null : () => onPlanetTap!(body.key, b.discRect),
            onLongPress: onPlanetLongPress == null ? null : () => onPlanetLongPress!(body.key, b.discRect),
          ),
        ),
      );
      for (final m in b.moons) {
        if (!m.visible || m.radius < MoonHitTest.minTappableMoonRadius) continue;
        nodes.add(
          CustomPainterSemantics(
            key: ValueKey('moon:${m.id}'),
            rect: m.hitRect,
            properties: SemanticsProperties(
              label: l10n.orbitMoonSemantics(formatter.isolate(m.moon.label.trim()), name),
              button: true,
              textDirection: textDirection,
              hintOverrides: SemanticsHintOverrides(onTapHint: l10n.planetsMoonOpenHint),
              onTap: onMoonTap == null ? null : () => onMoonTap!(m.moon, body.key, m.hitRect),
            ),
          ),
        );
      }
    }
    return nodes;
  };

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PlanetSemanticsPainter old) => false;

  @override
  bool shouldRebuildSemantics(_PlanetSemanticsPainter old) =>
      old.epoch != epoch || old.controller != controller || old.l10n != l10n || old.textDirection != textDirection;
}

// ----------------------------------------------------------------- composite --

/// The planet & moon layer of the Astrolabe Orbit: orbit guides, the
/// procedural worlds with their data moons, name labels, touch targets and
/// screen-reader nodes, over a transparent background (the sky and the
/// astrolabe belong to sibling layers).
///
/// Integration: pass the scene's [controller] (advanced by the scene's
/// single ticker; `controller.isAnimating` asks for full rate, otherwise 30
/// fps is plenty) and push `snapshot.planets` with
/// `controller.setPlanets(...)`. To sandwich the astrolabe, compose the
/// building blocks instead: [OrbitGuidesView] + [PlanetBodiesView]
/// (`PlanetPass.behindCore`) under it and [PlanetBodiesView]
/// (`frontOfCore`) + [PlanetLabelsView] + [PlanetHitRegion] +
/// [PlanetSemanticsView] over it, sharing one [PlanetRenderer].
///
/// Standalone (no [controller]): the layer owns a controller fed from
/// [bodies] / [camera] and ticks it itself while ambient motion is allowed
/// (30 fps when idle, full rate while something animates, paused when
/// hidden by TickerMode, static under reduced motion).
///
/// A completion ([PlanetSceneController.pulse]) makes the world flare; the
/// default feedback is a stardust burst in the world's glow colour and a
/// soft chime (`Sfx.sparkle`), replaceable with [onPulse].
class PlanetLayer extends StatefulWidget {
  const PlanetLayer({
    super.key,
    this.controller,
    this.bodies,
    this.camera,
    this.selectedKey,
    this.pass = PlanetPass.all,
    this.showGuides = true,
    this.showLabels = true,
    this.interactive = true,
    this.onPlanetTap,
    this.onPlanetLongPress,
    this.onMoonTap,
    this.onPulse,
    this.celebrate = true,
    this.tick,
    this.snapLabels = false,
    this.style,
    this.depthOfField = 5,
  });

  /// The scene's controller; null → the layer owns one.
  final PlanetSceneController? controller;

  /// Worlds pushed into the controller when they change (identity).
  final List<PlanetBody>? bodies;

  /// Camera pushed into the controller when given.
  final OrbitCamera? camera;

  /// Highlighted world (pushed when the layer owns the controller).
  final String? selectedKey;

  final PlanetPass pass;
  final bool showGuides;
  final bool showLabels;
  final bool interactive;
  final PlanetTapCallback? onPlanetTap;
  final PlanetTapCallback? onPlanetLongPress;
  final MoonTapCallback? onMoonTap;

  /// Replaces the default pulse feedback (see the class docs).
  final PlanetPulseFeedback? onPulse;

  /// Default pulse feedback (particles + chime) when [onPulse] is null.
  final bool celebrate;

  /// Whether the layer ticks the controller itself (default: only when it
  /// owns the controller).
  final bool? tick;

  /// Labels appear without fading (stills, tests).
  final bool snapLabels;

  final PlanetLayerStyle? style;

  /// Blur (sigma) of the other worlds at the end of a fly-in to one world
  /// (`controller.setFocus`); 0 turns depth of field off.
  final double depthOfField;

  @override
  State<PlanetLayer> createState() => _PlanetLayerState();
}

class _PlanetLayerState extends State<PlanetLayer> with SingleTickerProviderStateMixin {
  late PlanetSceneController _controller;
  bool _owns = false;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _idleAccumulator = 0;
  final GlobalKey _key = GlobalKey();

  bool get _ticks => widget.tick ?? _owns;

  /// One renderer for every bodies view of the layer (one shader instance
  /// per body, whichever view draws it).
  PlanetRenderer? _renderer;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
    _push(initial: true);
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
  }

  void _attach(PlanetSceneController? external) {
    _owns = external == null;
    _controller = external ?? PlanetSceneController(camera: widget.camera ?? PlanetSystemLayout.overviewCamera);
    _controller
      ..addPulseListener(_onPulse)
      ..addListener(_onControllerChanged);
  }

  void _detach() {
    _controller
      ..removePulseListener(_onPulse)
      ..removeListener(_onControllerChanged);
    if (_owns) _controller.dispose();
  }

  void _push({bool initial = false}) {
    final bodies = widget.bodies;
    if (bodies != null) _controller.setBodies(bodies, animate: !initial);
    final camera = widget.camera;
    if (camera != null) _controller.camera = camera;
    if (_owns) _controller.selectedKey = widget.selectedKey;
  }

  @override
  void didUpdateWidget(PlanetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
      _push(initial: true);
    } else {
      if (!identical(oldWidget.bodies, widget.bodies) ||
          oldWidget.camera != widget.camera ||
          oldWidget.selectedKey != widget.selectedKey) {
        _push();
      }
    }
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reducedMotion = context.reducedMotion;
    _syncTicker();
  }

  bool get _wantsTicker {
    if (!_ticks) return false;
    if (_controller.reducedMotion) return false;
    return AmbientMotion.enabled || _controller.isAnimating;
  }

  void _syncTicker() {
    final want = _wantsTicker;
    if (want && _ticker == null) {
      _last = Duration.zero;
      _ticker = createTicker(_onFrame)..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  void _onControllerChanged() {
    // A pulse or morph started on a layer that idles without ambient
    // motion: tick until it settles.
    if (_ticker == null && _wantsTicker) _syncTicker();
  }

  void _onFrame(Duration elapsed) {
    final dtSeconds = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dtSeconds <= 0) return;
    final dt = math.min(dtSeconds, 0.1);
    if (_controller.isAnimating) {
      _idleAccumulator = 0;
      _controller.advanceSeconds(dt);
    } else {
      // Idle: 30 fps is plenty for the slow drift.
      _idleAccumulator += dt;
      if (_idleAccumulator >= 1 / 30 - 1e-4) {
        _controller.advanceSeconds(_idleAccumulator);
        _idleAccumulator = 0;
      }
    }
    if (!_wantsTicker) {
      // Ambient motion off and nothing left to animate.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTicker();
      });
    }
  }

  void _onPulse(PlanetPulse p) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final b = _controller.frameFor(box.size).body(p.planetKey);
      if (b == null || !b.visible) return;
      final global = box.localToGlobal(b.center);
      final feedback = widget.onPulse;
      if (feedback != null) {
        feedback(p, global, b.radius);
      } else if (widget.celebrate) {
        Celebrate.burst(
          context,
          global,
          kind: CelebrationKind.stardust,
          color: b.body.palette.glow,
          intensity: 0.75,
          radius: b.radius * 1.5 + 12,
          sfx: Sfx.sparkle,
        );
      }
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _detach();
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? PlanetLayerStyle.fromTokens(context.tokens);
    return Stack(
      key: _key,
      fit: StackFit.expand,
      children: [
        if (widget.showGuides) OrbitGuidesView(controller: _controller, style: style),
        if (widget.depthOfField > 0) ...[
          PlanetFocusBlur(
            controller: _controller,
            maxSigma: widget.depthOfField,
            child: PlanetBodiesView(
              controller: _controller,
              renderer: _renderer,
              pass: widget.pass,
              filter: PlanetFocusFilter.unfocusedOnly,
            ),
          ),
          PlanetBodiesView(
            controller: _controller,
            renderer: _renderer,
            pass: widget.pass,
            filter: PlanetFocusFilter.focusedOnly,
          ),
        ] else
          PlanetBodiesView(controller: _controller, renderer: _renderer, pass: widget.pass),
        if (widget.showLabels) PlanetLabelsView(controller: _controller, style: style, snap: widget.snapLabels),
        if (widget.interactive)
          PlanetHitRegion(
            controller: _controller,
            onPlanetTap: widget.onPlanetTap,
            onPlanetLongPress: widget.onPlanetLongPress,
            onMoonTap: widget.onMoonTap,
          ),
        if (widget.interactive)
          PlanetSemanticsView(
            controller: _controller,
            onPlanetTap: widget.onPlanetTap,
            onPlanetLongPress: widget.onPlanetLongPress,
            onMoonTap: widget.onMoonTap,
          ),
      ],
    );
  }
}
