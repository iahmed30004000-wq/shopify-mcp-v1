import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/motion/motion.dart';
import '../../domain/scene_math.dart';
import '../orbit_shaders.dart';
import 'planet_body.dart';
import 'planet_frame.dart';
import 'planet_painters.dart';
import 'planet_renderer.dart';
import 'planet_style.dart';
import 'planet_uniforms.dart';

/// Three-quarter studio light of a portrait (upper left, toward the viewer).
const V3 kPortraitLight = V3(-0.75, 0.35, 0.55);

/// Fills [frame] to draw [body] as a portrait: disc of [radius] at [center],
/// lit from [light] (view space, normalised here), with the style's tilt.
void preparePortraitFrame(
  BodyFrame frame, {
  required PlanetBody body,
  required Offset center,
  required double radius,
  double? score,
  double pulse = 0,
  double time = 12,
  V3 light = kPortraitLight,
  double? spin,
  double? detail,
}) {
  final l = light.normalized;
  frame
    ..body = body
    ..center = center
    ..radius = radius
    ..visible = radius > 0
    ..lightX = l.x
    ..lightY = l.y
    ..lightZ = l.z
    ..spin = spin ?? 0.8 + time * 2 * math.pi / PlanetStyle.spinPeriodOf(body.seed)
    ..tilt = PlanetStyle.axialTiltOf(body.archetype, body.seed)
    ..score = (score ?? body.score).clamp(0.0, 1.0)
    ..pulse = pulse
    ..detail = detail ?? PlanetViewMath.detailFor(radius)
    ..drawRect = Rect.fromCircle(center: center, radius: radius * body.haloFactor);
}

/// One world on its own, centred in its box and sized so its halo (and the
/// gas giant's rings) fit: the customise sheet's live preview, the module
/// header, a still. Uses the same renderer as the orbit.
///
/// [animate] turns the world slowly (while ambient motion is allowed and
/// motion is not reduced); otherwise it is a still at [time].
class PlanetPortrait extends StatefulWidget {
  const PlanetPortrait({
    super.key,
    required this.body,
    this.score,
    this.pulse = 0,
    this.time = 12,
    this.light = kPortraitLight,
    this.animate = false,
  });

  final PlanetBody body;

  /// Overrides the body's score (e.g. a thriving/neglected preview).
  final double? score;
  final double pulse;
  final double time;
  final V3 light;
  final bool animate;

  @override
  State<PlanetPortrait> createState() => _PlanetPortraitState();
}

class _PlanetPortraitState extends State<PlanetPortrait> with SingleTickerProviderStateMixin {
  PlanetRenderer? _renderer;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Ticker? _ticker;
  late BodyFrame _frame = BodyFrame(widget.body);

  @override
  void initState() {
    super.initState();
    _clock.value = widget.time;
    final ready = OrbitShaders.instance;
    if (ready != null) {
      _renderer = PlanetRenderer(ready);
    } else {
      unawaited(
        OrbitShaders.load().then((s) {
          if (mounted) setState(() => _renderer = PlanetRenderer(s));
        }, onError: (Object _) {}),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(PlanetPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body.key != widget.body.key) _frame = BodyFrame(widget.body);
    if (!widget.animate) _clock.value = widget.time;
    _syncTicker();
  }

  void _syncTicker() {
    final want = widget.animate && AmbientMotion.enabled && !context.reducedMotion;
    if (want && _ticker == null) {
      var last = Duration.zero;
      _ticker = createTicker((elapsed) {
        final dt = last == Duration.zero ? 0.0 : (elapsed - last).inMicroseconds / 1e6;
        last = elapsed;
        _clock.value += math.min(dt, 0.1);
      })..start();
    } else if (!want && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _renderer?.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _PortraitPainter(
        renderer: _renderer,
        frame: _frame,
        clock: _clock,
        body: widget.body,
        score: widget.score,
        pulse: widget.pulse,
        light: widget.light,
      ),
    ),
  );
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({
    required this.renderer,
    required this.frame,
    required this.clock,
    required this.body,
    required this.score,
    required this.pulse,
    required this.light,
  }) : super(repaint: clock);

  final PlanetRenderer? renderer;
  final BodyFrame frame;
  final ValueNotifier<double> clock;
  final PlanetBody body;
  final double? score;
  final double pulse;
  final V3 light;

  @override
  void paint(Canvas canvas, Size size) {
    final r = renderer;
    if (r == null || size.isEmpty) return;
    final radius = size.shortestSide / 2 / body.haloFactor * 0.98;
    preparePortraitFrame(
      frame,
      body: body,
      center: size.center(Offset.zero),
      radius: radius,
      score: score,
      pulse: pulse,
      time: clock.value,
      light: light,
    );
    if (r.canDraw(body)) {
      r.paintPlanet(canvas, size, frame, clock.value);
    } else {
      final palette = body.shaderPalette;
      PlanetBodiesPainter.fallbackSphere(canvas, frame.center, frame.radius, palette.surface, palette.deep, frame);
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.renderer != renderer ||
      !old.body.sameAs(body) ||
      old.score != score ||
      old.pulse != pulse ||
      old.light.x != light.x ||
      old.light.y != light.y ||
      old.light.z != light.z;
}
