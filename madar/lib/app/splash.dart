import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/painters/painters.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/design/widgets/widgets.dart';
import '../core/i18n/gen/app_localizations.dart';
import '../core/motion/motion.dart';

/// The cinematic launch screen shown while the encrypted database opens: an
/// astrolabe assembles itself over the cosmos – the brass degree ring is
/// engraved in one sweep, the girih rete turns into place, the five prayer
/// lights fly into orbit and the central star ignites – then the name
/// rises. While the work continues the rete keeps turning slowly (ambient
/// motion only). Reduced motion shows the finished emblem with a fade.
class AstrolabeSplash extends StatefulWidget {
  const AstrolabeSplash({super.key, this.animateBackdrop = true});

  static const Duration assembly = Duration(milliseconds: 1300);

  final bool animateBackdrop;

  @override
  State<AstrolabeSplash> createState() => _AstrolabeSplashState();
}

class _AstrolabeSplashState extends State<AstrolabeSplash> with TickerProviderStateMixin {
  late final AnimationController _assemble = AnimationController(vsync: this, duration: AstrolabeSplash.assembly);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reducedMotion) {
      _assemble.value = 1;
    } else {
      _assemble.forward();
      if (AmbientMotion.enabled) _spin.repeat();
    }
  }

  @override
  void dispose() {
    _assemble.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final size = math.min(MediaQuery.sizeOf(context).shortestSide * 0.62, 260.0);
    return Semantics(
      label: l.shellSplashSemantics,
      liveRegion: true,
      child: ExcludeSemantics(
        child: CosmosBackdrop(
          animate: widget.animateBackdrop,
          seed: 0.2,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: _Emblem(assemble: _assemble, spin: _spin, size: size),
                ),
                const SizedBox(height: Space.xl),
                _Rise(
                  animation: CurvedAnimation(
                    parent: _assemble,
                    curve: const Interval(0.62, 1, curve: MadarMotion.decelerate),
                  ),
                  child: Text(
                    l.appName,
                    style: text.displayMedium!.copyWith(
                      color: t.gold,
                      shadows: [Shadow(color: t.accentGlow, blurRadius: 24)],
                    ),
                  ),
                ),
                const SizedBox(height: Space.s),
                _Rise(
                  animation: CurvedAnimation(
                    parent: _assemble,
                    curve: const Interval(0.75, 1, curve: MadarMotion.decelerate),
                  ),
                  child: Text(l.shellSplashAssembling, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rise extends AnimatedWidget {
  const _Rise({required Animation<double> animation, required this.child}) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as Animation<double>).value;
    return Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.assemble, required this.spin, required this.size});

  final AnimationController assemble;
  final AnimationController spin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final ring = CurvedAnimation(
      parent: assemble,
      curve: const Interval(0, 0.5, curve: MadarMotion.orbital),
    );
    final rete = CurvedAnimation(
      parent: assemble,
      curve: const Interval(0.2, 0.72, curve: MadarMotion.decelerate),
    );
    final lights = CurvedAnimation(
      parent: assemble,
      curve: const Interval(0.4, 0.9, curve: MadarMotion.emphasized),
    );
    final star = CurvedAnimation(
      parent: assemble,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOutBack),
    );

    // The ring and the rosette are painted once and cached; the animation
    // only changes clips, transforms and opacity.
    final ringLayer = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: AstrolabeTicksPainter(
          color: t.brass,
          majorColor: t.gold,
          numeralColor: t.gold,
          arabicIndic: arabic,
          fontFamily: MadarTypography.uiFamily,
        ),
      ),
    );
    final reteLayer = RepaintBoundary(child: GirihRosette(size: size * 0.62, folds: 8));

    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([assemble, spin]),
        builder: (context, _) {
          final r = ring.value;
          final q = rete.value;
          final s = star.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Halo.
              Opacity(
                opacity: (0.35 + 0.65 * q).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        t.accentGlow.withValues(alpha: t.accentGlow.a * 0.35),
                        t.accentGlow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: SizedBox.square(dimension: size * 1.1),
                ),
              ),
              // Brass ring engraved in one sweep.
              Opacity(
                opacity: r.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.9 + 0.1 * r,
                  child: r >= 0.999 ? ringLayer : ClipPath(clipper: _SectorClipper(r), child: ringLayer),
                ),
              ),
              // Girih rete turning into place, then drifting.
              Opacity(
                opacity: q.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: -0.9 * (1 - q) + spin.value * 2 * math.pi,
                  child: Transform.scale(scale: 0.72 + 0.28 * q, child: reteLayer),
                ),
              ),
              // Five prayer lights flying into their orbit.
              CustomPaint(
                size: Size.square(size),
                painter: _PrayerLightsPainter(
                  progress: lights.value,
                  spin: spin.value,
                  color: t.gold,
                  glow: t.accentGlow,
                  core: t.starTint,
                ),
              ),
              // The central star ignites.
              Transform.scale(
                scale: s.clamp(0.0, 1.3),
                child: Opacity(
                  opacity: s.clamp(0.0, 1.0),
                  child: IslamicStar(size: size * 0.16, glow: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectorClipper extends CustomClipper<Path> {
  const _SectorClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false)
      ..close();
  }

  @override
  bool shouldReclip(_SectorClipper old) => old.progress != progress;
}

class _PrayerLightsPainter extends CustomPainter {
  const _PrayerLightsPainter({
    required this.progress,
    required this.spin,
    required this.color,
    required this.glow,
    required this.core,
  });

  final double progress;
  final double spin;
  final Color color;
  final Color glow;
  final Color core;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    final orbit = size.width * 0.4;
    for (var i = 0; i < 5; i++) {
      // Each light starts slightly later and swings in from further out.
      final local = ((progress - i * 0.08) / 0.68).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final e = Curves.easeOutCubic.transform(local);
      final a = -math.pi / 2 + i * 2 * math.pi / 5 + spin * 2 * math.pi * 0.35 - (1 - e) * 1.4;
      final d = orbit * (1.45 - 0.45 * e);
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      final radius = size.width * 0.018;
      canvas.drawCircle(
        p,
        radius * 3,
        Paint()
          ..color = glow.withValues(alpha: glow.a * 0.7 * e)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2),
      );
      canvas.drawCircle(p, radius, Paint()..color = Color.lerp(color, core, 0.5)!.withValues(alpha: e));
    }
    // The orbit they settle on.
    canvas.drawCircle(
      c,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = color.withValues(alpha: 0.35 * progress),
    );
  }

  @override
  bool shouldRepaint(_PrayerLightsPainter old) =>
      old.progress != progress || old.spin != spin || old.color != color || old.glow != glow || old.core != core;
}
