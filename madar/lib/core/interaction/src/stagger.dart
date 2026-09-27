import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';

/// Local staggered entrance (fade + rise) so the kit does not depend on the
/// motion package's widgets. Delay = index × [MadarMotion.staggerStep],
/// capped at [MadarMotion.staggerCap]; collapses under reduced motion.
class KitStaggerIn extends StatefulWidget {
  const KitStaggerIn({super.key, required this.index, required this.child, this.offset = 14, this.enabled = true});

  final int index;
  final Widget child;
  final double offset;
  final bool enabled;

  @override
  State<KitStaggerIn> createState() => _KitStaggerInState();
}

class _KitStaggerInState extends State<KitStaggerIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _a;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || !widget.enabled) return;
    final reduced = context.reducedMotion;
    var delay = MadarMotion.staggerStep * widget.index;
    if (delay > MadarMotion.staggerCap) delay = MadarMotion.staggerCap;
    if (reduced) delay = Duration.zero;
    final body = reduced ? MadarMotion.reduced : MadarMotion.long;
    final total = delay + body;
    final c = AnimationController(vsync: this, duration: total);
    _c = c;
    _a = c.drive(CurveTween(curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: MadarMotion.decelerate)));
    c.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return widget.child;
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) {
        final v = a.value;
        if (v >= 1) return child!;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - v) * widget.offset), child: child),
        );
      },
      child: widget.child,
    );
  }
}
