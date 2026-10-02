import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';

/// Entrance of the import screens' blocks: fade + rise from below, staggered
/// by [index] ([MadarMotion.staggerStep], capped at [MadarMotion.staggerCap]).
/// One controller, the delay folded into an [Interval] – no timers.
/// Reduced motion: a quick fade in place.
class ImportRise extends StatefulWidget {
  const ImportRise({super.key, required this.child, this.index = 0, this.distance = 18});

  final Widget child;
  final int index;
  final double distance;

  @override
  State<ImportRise> createState() => _ImportRiseState();
}

class _ImportRiseState extends State<ImportRise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _t;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = context.reducedMotion;
    final stagger = MadarMotion.staggerStep * widget.index;
    final delay = stagger > MadarMotion.staggerCap ? MadarMotion.staggerCap : stagger;
    final body = reduced ? MadarMotion.reduced : MadarMotion.long;
    final total = reduced ? body : delay + body;
    final start = total.inMicroseconds == 0 ? 0.0 : (reduced ? 0.0 : delay.inMicroseconds / total.inMicroseconds);
    _c.duration = total;
    _t = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: MadarMotion.decelerate));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: reduced ? child : Transform.translate(offset: Offset(0, (1 - v) * widget.distance), child: child),
        );
      },
    );
  }
}

/// A number that counts up from zero to [value] once shown (after the same
/// stagger as [ImportRise] with [index]). [format] owns digits / grouping.
class ImportCountUp extends StatelessWidget {
  const ImportCountUp({super.key, required this.value, required this.format, this.style, this.index = 0});

  final int value;
  final String Function(int value) format;
  final TextStyle? style;
  final int index;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    final stagger = MadarMotion.staggerStep * index;
    final delay = reduced ? Duration.zero : (stagger > MadarMotion.staggerCap ? MadarMotion.staggerCap : stagger);
    final body = reduced ? MadarMotion.reduced : MadarMotion.cinematic;
    final total = delay + body;
    final start = total.inMicroseconds == 0 ? 0.0 : delay.inMicroseconds / total.inMicroseconds;
    return Semantics(
      value: format(value),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: total,
          curve: Interval(start, 1, curve: MadarMotion.decelerate),
          builder: (context, v, _) => Text(
            format(v.round()),
            style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
  }
}
