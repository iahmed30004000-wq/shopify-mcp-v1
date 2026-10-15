import 'package:flutter/material.dart';

import '../../motion/motion.dart';

/// Shows one of [children] – the selected one only – and cross-fades when
/// [index] changes. Every tabbed screen in Madar switches its bodies with
/// this one widget.
///
/// Why not a stack of faded-out tabs: the old hand-rolled version kept every
/// visited tab mounted and hid the others with `AnimatedOpacity(opacity: 0)`
/// under a muted [TickerMode]. A muted ticker never advances the fade, so the
/// tab being left stayed at opacity 1 for ever and the bodies piled up on the
/// screen (APK #15, B1). Building only the selected subtree cannot fail that
/// way: a tab that is not selected is not in the tree at all.
///
/// The tab that leaves is not hit-testable and is hidden from TalkBack while
/// it fades out, so taps and the screen reader only ever see the tab that
/// arrived.
class MadarFadeStack extends StatelessWidget {
  const MadarFadeStack({super.key, required this.index, required this.children, this.duration});

  /// Which child to show (clamped).
  final int index;
  final List<Widget> children;

  /// Defaults to [MadarMotion.medium] (reduced-motion aware).
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    assert(children.isNotEmpty, 'MadarFadeStack needs at least one child');
    final i = index.clamp(0, children.length - 1);
    final d = duration ?? context.motion(MadarMotion.medium);
    return AnimatedSwitcher(
      duration: d,
      // The body leaving goes a little quicker than the one arriving, so the
      // two never share the screen at full strength.
      reverseDuration: d * 0.65,
      switchInCurve: MadarMotion.decelerate,
      switchOutCurve: MadarMotion.accelerate,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final gone in previous) IgnorePointer(child: ExcludeSemantics(child: gone)),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).chain(CurveTween(curve: MadarMotion.decelerate)),
          ),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<int>(i), child: children[i]),
    );
  }
}
