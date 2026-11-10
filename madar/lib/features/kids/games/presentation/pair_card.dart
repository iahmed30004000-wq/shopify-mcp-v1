import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';
import 'package:madar/core/motion/motion.dart';

import '../../rewards/presentation/play_kit.dart';
import 'pair_symbols.dart';

const PatternSpec _backSpec = PatternSpec(family: PatternFamily.square4, lineWidth: 1.1, repeat: 3);

/// The back of a card: indigo to teal, with the khatam lattice on it.
class PairCardBack extends StatelessWidget {
  const PairCardBack({super.key, this.radius = 18});

  final double radius;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [KidsColors.night500, KidsColors.teal500],
        ),
        border: Border.all(color: KidsColors.night900.withValues(alpha: .55), width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: CustomPaint(
          painter: GeometryPatternPainter(spec: _backSpec, color: Colors.white, opacity: .5),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// The face of a card.
class PairCardFace extends StatelessWidget {
  const PairCardFace({super.key, required this.symbol, this.matched = false, this.radius = 18});

  final int symbol;
  final bool matched;
  final double radius;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: matched ? KidsColors.sun500 : KidsColors.sand2, width: matched ? 4 : 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CustomPaint(painter: PairSymbolPainter(symbol), child: const SizedBox.expand()),
      ),
    ),
  );
}

/// A card that turns over around its vertical axis. With reduced motion it
/// swaps at once.
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.faceUp, required this.symbol, required this.matched, this.duration});

  final bool faceUp;
  final int symbol;
  final bool matched;

  /// Overrides the default turn time (tests use zero).
  final Duration? duration;

  static const Duration turn = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final d = duration ?? (context.reducedMotion ? Duration.zero : turn);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: faceUp ? 1 : 0),
      duration: d,
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final showFace = t >= 0.5;
        final angle = t * math.pi;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(showFace ? angle - math.pi : angle);
        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: showFace ? PairCardFace(symbol: symbol, matched: matched) : const PairCardBack(),
        );
      },
    );
  }
}
