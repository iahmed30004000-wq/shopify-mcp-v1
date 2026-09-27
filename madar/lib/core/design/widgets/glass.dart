import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';
import '../tokens.dart';
import 'ambient_motion.dart';
import 'pressable.dart';
import 'shader_cache.dart';

/// Packs the uniforms of `shaders/glass.frag` (pure, unit-tested).
abstract final class GlassUniforms {
  static const double period = 60;
  static const int length = 12;

  static List<double> pack({
    required Size size,
    required double time,
    required Color highlight,
    required double grain,
    required bool light,
    required double seed,
    required double specular,
    required TextDirection direction,
  }) => [
    size.width,
    size.height,
    time % period,
    highlight.r,
    highlight.g,
    highlight.b,
    highlight.a,
    grain,
    light ? 1 : 0,
    seed,
    specular.clamp(0.0, 1.0),
    direction == TextDirection.rtl ? -1 : 1,
  ];
}

/// The signature Madar surface for sheets, dialogs and hero panels: one
/// backdrop blur ([MadarTokens.blurSigma]) + tinted fill + gradient hairline
/// border (bright at the top edge) + soft outer glow + a slowly drifting
/// specular sheen and paper-fine grain from `shaders/glass.frag`.
///
/// Uses [BackdropFilter.grouped], so wrapping many panels in a
/// [BackdropGroup] (MadarScaffold does) shares one backdrop capture.
/// For list rows use [GlassCard] – never put a BackdropFilter in a list row.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(Space.l),
    this.borderRadius,
    this.blurSigma,
    this.tint,
    this.borderColor,
    this.glow = true,
    this.glowColor,
    this.animateSheen = true,
    this.shareBackdrop = true,
    this.seed = 0,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to [MadarTokens.radiusL].
  final BorderRadiusGeometry? borderRadius;

  /// Defaults to [MadarTokens.blurSigma].
  final double? blurSigma;

  /// Overrides [MadarTokens.glassFill].
  final Color? tint;

  /// Overrides the base colour of the hairline border.
  final Color? borderColor;
  final bool glow;

  /// Overrides [MadarTokens.glassShadow] (e.g. an accent glow for a
  /// highlighted panel).
  final Color? glowColor;

  /// Drift the specular sheen (paused under reduced motion / TickerMode off).
  final bool animateSheen;

  /// Join the nearest [BackdropGroup]. Turn off for a panel that overlaps
  /// another grouped panel (e.g. a sheet over a panel).
  final bool shareBackdrop;

  /// Desynchronises the sheen/grain between neighbouring panels.
  final double seed;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dir = Directionality.of(context);
    final radius = (borderRadius ?? BorderRadius.circular(t.radiusL)).resolve(dir);
    final sigma = blurSigma ?? t.blurSigma;
    final filter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror);
    final surface = _GlassSurface(
      radius: radius,
      fill: GlassFillStyle.panel(t, tint: tint),
      animate: animateSheen,
      seed: seed,
      child: Padding(padding: padding, child: child),
    );
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: glow
            ? GlassGlowPainter(radius: radius, color: glowColor ?? t.glassShadow, sigma: 16, offset: const Offset(0, 5))
            : null,
        foregroundPainter: GlassBorderPainter(
          radius: radius,
          highlight: t.glassHighlight,
          border: borderColor ?? t.glassBorder,
          direction: dir,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: shareBackdrop
              ? BackdropFilter.grouped(filter: filter, child: surface)
              : BackdropFilter(filter: filter, child: surface),
        ),
      ),
    );
  }
}

/// Faux-glass card for list rows and grids: the same hairline, glow and
/// grain as [GlassPanel] but NO BackdropFilter – a frosted gradient instead,
/// so hundreds of rows scroll at full frame rate.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(Space.l),
    this.borderRadius,
    this.tint,
    this.borderColor,
    this.glow = true,
    this.glowColor,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.seed = 0,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to [MadarTokens.radiusM].
  final BorderRadiusGeometry? borderRadius;
  final Color? tint;
  final Color? borderColor;
  final bool glow;
  final Color? glowColor;

  /// Makes the card pressable (spring scale + Sfx.tap).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double seed;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dir = Directionality.of(context);
    final radius = (borderRadius ?? BorderRadius.circular(t.radiusM)).resolve(dir);
    Widget card = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: glow
            ? GlassGlowPainter(radius: radius, color: glowColor ?? t.glassShadow, sigma: 9, offset: const Offset(0, 3))
            : null,
        foregroundPainter: GlassBorderPainter(
          radius: radius,
          highlight: t.glassHighlight,
          border: borderColor ?? t.glassBorder,
          direction: dir,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: _GlassSurface(
            radius: radius,
            fill: GlassFillStyle.card(t, tint: tint),
            animate: false,
            seed: seed,
            specular: 0.35,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (onTap != null || onLongPress != null) {
      card = MadarPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: semanticLabel,
        excludeChildSemantics: semanticLabel != null,
        focusRadius: radius,
        child: card,
      );
    }
    return card;
  }
}

/// Fill recipe of a glass surface.
@immutable
class GlassFillStyle {
  const GlassFillStyle({
    required this.base,
    required this.top,
    required this.bottom,
    required this.sheen,
    required this.highlight,
    required this.light,
    required this.grain,
  });

  /// Translucent fill for real (blurred) glass.
  factory GlassFillStyle.panel(MadarTokens t, {Color? tint}) {
    final base = tint ?? t.glassFill;
    return GlassFillStyle(
      base: base,
      top: t.glassHighlight.withValues(alpha: t.glassHighlight.a * (t.isDark ? 0.12 : 0.25)),
      bottom: t.glassShadow.withValues(alpha: t.glassShadow.a * (t.isDark ? 0.18 : 0.08)),
      sheen: t.glassHighlight.withValues(alpha: t.glassHighlight.a * 0.10),
      highlight: t.glassHighlight,
      light: !t.isDark,
      grain: t.grainOpacity * (t.isDark ? 0.75 : 0.45),
    );
  }

  /// Denser frosted gradient that reads as glass without a backdrop blur.
  factory GlassFillStyle.card(MadarTokens t, {Color? tint}) {
    final glass = tint ?? t.glassFill;
    final frost = t.isDark ? 0.62 : 0.5;
    return GlassFillStyle(
      base: Color.alphaBlend(glass, t.space2.withValues(alpha: frost)),
      top: t.glassHighlight.withValues(alpha: t.glassHighlight.a * (t.isDark ? 0.14 : 0.3)),
      bottom: Color.alphaBlend(glass, t.space1.withValues(alpha: frost * 0.9)).withValues(alpha: 0.35),
      sheen: t.glassHighlight.withValues(alpha: t.glassHighlight.a * 0.14),
      highlight: t.glassHighlight,
      light: !t.isDark,
      grain: t.grainOpacity * (t.isDark ? 0.7 : 0.4),
    );
  }

  final Color base, top, bottom, sheen, highlight;
  final bool light;
  final double grain;

  @override
  bool operator ==(Object other) =>
      other is GlassFillStyle &&
      other.base == base &&
      other.top == top &&
      other.bottom == bottom &&
      other.sheen == sheen &&
      other.highlight == highlight &&
      other.light == light &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(base, top, bottom, sheen, highlight, light, grain);
}

/// Fill + shader finish below the content. Owns the FragmentShader and the
/// (optional, throttled) sheen ticker.
class _GlassSurface extends StatefulWidget {
  const _GlassSurface({
    required this.radius,
    required this.fill,
    required this.animate,
    required this.seed,
    required this.child,
    this.specular = 1,
  });

  final BorderRadius radius;
  final GlassFillStyle fill;
  final bool animate;
  final double seed;
  final double specular;
  final Widget child;

  @override
  State<_GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<_GlassSurface> with SingleTickerProviderStateMixin {
  static const _frameInterval = 1 / 20;

  late final ValueListenable<ui.FragmentProgram?> _program = MadarShaders.glass;
  ui.FragmentShader? _shader;
  Ticker? _ticker;
  late final ValueNotifier<double> _time = ValueNotifier<double>(7 + widget.seed * 11);
  double _base = 0;
  double _last = -1;

  @override
  void initState() {
    super.initState();
    _base = _time.value;
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
    _syncTicker();
  }

  @override
  void didUpdateWidget(_GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncTicker();
  }

  void _syncTicker() {
    final run = widget.animate && AmbientMotion.enabled && !context.reducedMotion;
    if (run) {
      final ticker = _ticker ??= createTicker(_onTick);
      if (!ticker.isActive) {
        _last = -1;
        ticker.start();
      }
    } else if (_ticker?.isActive ?? false) {
      _base = _time.value;
      _ticker!.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final t = _base + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_last >= 0 && t - _last < _frameInterval) return;
    _last = t;
    _time.value = t % GlassUniforms.period;
  }

  @override
  void dispose() {
    _program.removeListener(_onProgram);
    _ticker?.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // passthrough: the content receives the card's own constraints, so a
    // stretched card lays its content out across the full width.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: GlassSurfacePainter(
                shader: _shader,
                fill: widget.fill,
                time: _time,
                seed: widget.seed,
                specular: widget.specular,
                direction: Directionality.of(context),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Paints the tinted fill, lighting gradient and shader finish.
class GlassSurfacePainter extends CustomPainter {
  GlassSurfacePainter({
    required this.shader,
    required this.fill,
    required this.time,
    required this.seed,
    required this.direction,
    this.specular = 1,
  }) : super(repaint: time);

  final ui.FragmentShader? shader;
  final GlassFillStyle fill;
  final ValueListenable<double> time;
  final double seed;
  final double specular;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = fill.base);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [fill.top, fill.top.withValues(alpha: 0), fill.bottom.withValues(alpha: 0), fill.bottom],
          const [0, 0.35, 0.6, 1],
        ),
    );
    final start = direction == TextDirection.rtl ? rect.topRight : rect.topLeft;
    final r = size.longestSide * 0.9;
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.radial(start, r, [fill.sheen, fill.sheen.withValues(alpha: 0)]),
    );
    final s = shader;
    if (s == null) return;
    final u = GlassUniforms.pack(
      size: size,
      time: time.value,
      highlight: fill.highlight,
      grain: fill.grain,
      light: fill.light,
      seed: seed,
      specular: specular,
      direction: direction,
    );
    for (var i = 0; i < u.length; i++) {
      s.setFloat(i, u[i]);
    }
    canvas.drawRect(rect, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(GlassSurfacePainter old) =>
      old.shader != shader ||
      old.fill != fill ||
      old.time != time ||
      old.seed != seed ||
      old.specular != specular ||
      old.direction != direction;
}

/// Gradient hairline: bright glass highlight along the top(-start) edge,
/// fading into the theme's glass border down the sides.
class GlassBorderPainter extends CustomPainter {
  const GlassBorderPainter({
    required this.radius,
    required this.highlight,
    required this.border,
    required this.direction,
    this.width = 1,
  });

  final BorderRadius radius;
  final Color highlight;
  final Color border;
  final TextDirection direction;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(width / 2);
    final rrect = radius.toRRect(rect);
    final rtl = direction == TextDirection.rtl;
    final from = rtl ? rect.topRight : rect.topLeft;
    final to = rtl ? rect.bottomLeft : rect.bottomRight;
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = ui.Gradient.linear(
          from,
          to,
          [highlight, border, border.withValues(alpha: border.a * 0.35), border],
          const [0, 0.28, 0.62, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(GlassBorderPainter old) =>
      old.radius != radius ||
      old.highlight != highlight ||
      old.border != border ||
      old.direction != direction ||
      old.width != width;
}

/// Paints a soft glow strictly outside [rrect] (never tints the surface
/// itself). Uses a normal blur clipped to the outside of the shape – robust
/// on every backend (unlike `BlurStyle.outer`).
void paintOuterGlow(Canvas canvas, RRect rrect, Color color, double sigma, {Offset offset = Offset.zero}) {
  if (color.a == 0 || sigma <= 0) return;
  final outside = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(rrect.outerRect.inflate(sigma * 3 + offset.distance))
    ..addRRect(rrect);
  canvas.save();
  canvas.clipPath(outside);
  canvas.drawRRect(
    rrect.shift(offset),
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
  );
  canvas.restore();
}

/// Soft glow strictly outside the surface (never darkens the glass itself).
class GlassGlowPainter extends CustomPainter {
  const GlassGlowPainter({required this.radius, required this.color, this.sigma = 16, this.offset = Offset.zero});

  final BorderRadius radius;
  final Color color;
  final double sigma;

  /// Drop offset (a little downward lift reads as elevation).
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    paintOuterGlow(canvas, radius.toRRect(Offset.zero & size), color, sigma, offset: offset);
  }

  @override
  bool shouldRepaint(GlassGlowPainter old) =>
      old.radius != radius || old.color != color || old.sigma != sigma || old.offset != offset;
}
