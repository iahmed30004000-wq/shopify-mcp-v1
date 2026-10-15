import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../core/design/tokens.dart';
import '../../../core/motion/motion.dart';

/// The lock screen opening like a double door into the app: a still of the
/// lock screen is split down the middle through the astrolabe, both halves
/// swing inwards on hinges at the screen edges while the camera flies
/// through the doorway, and a seam of light floods out.
///
/// [progress] runs 0 → 1. Without a [snapshot] (or under reduced motion)
/// the live [fallback] simply fades.
class LockDoor extends StatelessWidget {
  const LockDoor({super.key, required this.progress, this.snapshot, required this.fallback, this.reduced = false});

  final Animation<double> progress;
  final ui.Image? snapshot;
  final Widget fallback;
  final bool reduced;

  /// How far each door has swung at [t] (radians).
  static double swing(double t) => MadarMotion.orbital.transform(t.clamp(0.0, 1.0)) * 1.42;

  /// The camera's zoom through the doorway at [t].
  static double zoom(double t) => 1 + 0.55 * Curves.easeInCubic.transform(t.clamp(0.0, 1.0));

  /// The doors' opacity at [t] (they dissolve as they pass the camera).
  static double opacity(double t) => 1 - Curves.easeIn.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final image = snapshot;
    if (image == null || reduced) {
      return FadeTransition(
        opacity: ReverseAnimation(progress),
        child: IgnorePointer(child: fallback),
      );
    }
    final t = context.tokens;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final v = progress.value;
          final angle = swing(v);
          final z = zoom(v);
          final a = opacity(v);
          final seam = math.sin(math.pi * v.clamp(0.0, 1.0));
          return LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              Widget door(bool left) {
                final m = Matrix4.identity()
                  ..setEntry(3, 2, 0.9 / w)
                  ..rotateY(left ? -angle : angle);
                return Positioned.fill(
                  child: Transform(
                    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
                    transform: m,
                    child: ClipRect(
                      clipper: _HalfClipper(left: left),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(image: image, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                          // Each leaf darkens as it turns away from the light.
                          ColoredBox(color: t.space0.withValues(alpha: 0.55 * math.sin(angle).clamp(0.0, 1.0))),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Transform.scale(
                scale: z,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Light pouring through the opening seam.
                    Center(
                      child: Container(
                        width: w * (0.2 + 1.2 * v),
                        height: box.maxHeight * 0.9,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.5,
                            colors: [
                              t.starTint.withValues(alpha: 0.5 * seam),
                              t.gold.withValues(alpha: 0.22 * seam),
                              t.accentGlow.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.35, 1],
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: a,
                      child: Stack(fit: StackFit.expand, children: [door(true), door(false)]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  const _HalfClipper({required this.left});

  final bool left;

  @override
  Rect getClip(Size size) => left
      ? Rect.fromLTWH(0, 0, size.width / 2, size.height)
      : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_HalfClipper old) => old.left != left;
}
