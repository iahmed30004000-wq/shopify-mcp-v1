import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'ambient_motion.dart';
import 'shader_cache.dart';

/// Packs the uniforms of `shaders/cosmos_backdrop.frag` (pure, unit-tested).
abstract final class CosmosUniforms {
  /// Loop period of every animated term in the shader, in seconds.
  static const double period = 240;

  /// Number of float uniforms the shader declares.
  static const int length = 31;

  /// Time used for the single static frame (reduced motion / paused).
  static const double staticTime = 42;

  static List<double> pack({
    required Size size,
    required double time,
    required MadarTokens tokens,
    double intensity = 1,
    double seed = 0,
  }) {
    List<double> c(Color color) => [color.r, color.g, color.b, color.a];
    return [
      size.width,
      size.height,
      time % period,
      ...c(tokens.space0),
      ...c(tokens.space1),
      ...c(tokens.nebulaA),
      ...c(tokens.nebulaB),
      ...c(tokens.starTint),
      ...c(tokens.dust),
      intensity.clamp(0.0, 2.0),
      tokens.isDark ? 0 : 1,
      tokens.grainOpacity * (tokens.isDark ? 0.55 : 0.35),
      seed,
    ];
  }
}

/// Full-screen living cosmos behind every non-home screen.
///
/// Rendered by `shaders/cosmos_backdrop.frag`: deep-space gradient, two
/// drifting nebulae, a twinkling starfield, dust and film grain – or, in the
/// light Pearl theme, a soft mother-of-pearl haze. Drifts on the shared
/// [AmbientClock] at ~30 fps: frames are only requested when the clock
/// ticks (a running Ticker would request one every vsync, 90/120 Hz, and
/// re-run the full-screen shader and every blur above it each time). It
/// pauses when [TickerMode] is off and renders one static frame under
/// reduced motion or battery saver ([AmbientMotionScope]). Falls back to a
/// painted gradient while (or if) the shader is unavailable.
class CosmosBackdrop extends StatefulWidget {
  const CosmosBackdrop({super.key, this.intensity = 1, this.animate = true, this.seed = 0, this.child});

  /// Nebula strength (0 = bare sky, 1 = default, up to 2).
  final double intensity;

  /// Set false for one static frame (no clock subscription).
  final bool animate;

  /// Varies the nebula layout so neighbouring screens don't look identical.
  final double seed;

  /// Optional content painted above the backdrop.
  final Widget? child;

  @override
  State<CosmosBackdrop> createState() => _CosmosBackdropState();
}

class _CosmosBackdropState extends State<CosmosBackdrop> {
  final ValueNotifier<double> _time = ValueNotifier<double>(CosmosUniforms.staticTime);
  late final ValueListenable<ui.FragmentProgram?> _program = MadarShaders.cosmos;
  ui.FragmentShader? _shader;

  /// Backdrop time minus clock time while subscribed.
  double _base = CosmosUniforms.staticTime;
  bool _subscribed = false;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _shader = _program.value?.fragmentShader();
    _program.addListener(_onProgram);
  }

  void _onProgram() {
    final program = _program.value;
    if (program == null || _shader != null || !mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CosmosBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    final run = widget.animate && context.ambientMotion && TickerMode.valuesOf(context).enabled;
    final clock = AmbientClock.instance;
    if (run && !_subscribed) {
      _base = _time.value - clock.seconds;
      clock.addListener(_onTick);
      _subscribed = true;
    } else if (!run && _subscribed) {
      clock.removeListener(_onTick);
      _subscribed = false;
    }
    _animating = run;
  }

  void _onTick() => _time.value = (_base + AmbientClock.instance.seconds) % CosmosUniforms.period;

  @override
  void dispose() {
    if (_subscribed) AmbientClock.instance.removeListener(_onTick);
    _program.removeListener(_onProgram);
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: _animating,
        painter: CosmosBackdropPainter(
          shader: _shader,
          tokens: context.tokens,
          time: _time,
          intensity: widget.intensity,
          seed: widget.seed,
        ),
        child: const SizedBox.expand(),
      ),
    );
    final child = widget.child;
    if (child == null) return backdrop;
    return Stack(fit: StackFit.expand, children: [backdrop, child]);
  }
}

/// Paints the cosmos (shader when available, gradient fallback otherwise).
class CosmosBackdropPainter extends CustomPainter {
  CosmosBackdropPainter({
    required this.shader,
    required this.tokens,
    required this.time,
    this.intensity = 1,
    this.seed = 0,
  }) : super(repaint: time);

  final ui.FragmentShader? shader;
  final MadarTokens tokens;
  final ValueListenable<double> time;
  final double intensity;
  final double seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final s = shader;
    if (s != null) {
      final u = CosmosUniforms.pack(size: size, time: time.value, tokens: tokens, intensity: intensity, seed: seed);
      for (var i = 0; i < u.length; i++) {
        s.setFloat(i, u[i]);
      }
      canvas.drawRect(rect, Paint()..shader = s);
      return;
    }
    _paintFallback(canvas, size);
  }

  void _paintFallback(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dark = tokens.isDark;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          dark ? [tokens.space1, tokens.space0] : [tokens.space0, tokens.space1],
        ),
    );
    void cloud(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            color.withValues(alpha: alpha * intensity.clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ]),
      );
    }

    final d = size.shortestSide;
    cloud(Offset(size.width * 0.22, size.height * 0.16), d * 0.9, tokens.nebulaA, dark ? 0.42 : 0.55);
    cloud(Offset(size.width * 0.86, size.height * 0.82), d * 1.0, tokens.nebulaB, dark ? 0.36 : 0.6);

    final stars = Paint()..color = tokens.starTint;
    for (final star in _fallbackStars) {
      stars.color = tokens.starTint.withValues(alpha: (dark ? 0.85 : 0.5) * star.$3);
      canvas.drawCircle(Offset(star.$1 * size.width, star.$2 * size.height), 0.4 + star.$3 * 0.9, stars);
    }
  }

  static final List<(double, double, double)> _fallbackStars = () {
    final r = math.Random(7);
    return List.generate(110, (_) => (r.nextDouble(), r.nextDouble(), r.nextDouble()));
  }();

  @override
  bool shouldRepaint(CosmosBackdropPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.tokens != tokens ||
      oldDelegate.intensity != intensity ||
      oldDelegate.seed != seed ||
      oldDelegate.time != time;
}
