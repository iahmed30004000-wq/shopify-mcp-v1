import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../motion/motion.dart';
import '../../sound/sound_api.dart';

/// Minimal pressable for the interaction kit: spring press-scale, sound +
/// haptic via [Fx], semantics and keyboard activation. Self-contained so the
/// kit never depends on widgets that are still being built elsewhere.
class KitPressable extends StatefulWidget {
  const KitPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.sfx = Sfx.tap,
    this.semanticLabel,
    this.tooltip,
    this.pressScale = MadarMotion.pressScale,
    this.enabled = true,
    this.selected,
    this.excludeSemantics = false,
    this.behavior = HitTestBehavior.opaque,
    this.onDisabledTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Sound fired on tap (null = silent, e.g. when the callback fires its own).
  final Sfx? sfx;
  final String? semanticLabel;
  final String? tooltip;
  final double pressScale;
  final bool enabled;
  final bool? selected;
  final bool excludeSemantics;
  final HitTestBehavior behavior;

  /// Called when tapped while disabled (e.g. to reveal validation errors).
  final VoidCallback? onDisabledTap;

  @override
  State<KitPressable> createState() => _KitPressableState();
}

class _KitPressableState extends State<KitPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(vsync: this, value: 0);

  bool get _active => widget.enabled && widget.onTap != null;

  void _to(double target) {
    if (context.reducedMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(SpringSimulation(MadarMotion.snappy, _press.value, target, _press.velocity));
  }

  void _handleTap() {
    if (!_active) {
      widget.onDisabledTap?.call();
      return;
    }
    final sfx = widget.sfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onTap!();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleDelta = 1 - widget.pressScale;
    Widget child = AnimatedBuilder(
      animation: _press,
      builder: (context, child) => Transform.scale(scale: 1 - scaleDelta * _press.value, child: child),
      child: widget.child,
    );
    child = GestureDetector(
      behavior: widget.behavior,
      onTapDown: _active ? (_) => _to(1) : null,
      onTapUp: _active ? (_) => _to(0) : null,
      onTapCancel: _active ? () => _to(0) : null,
      onTap: (_active || widget.onDisabledTap != null) ? _handleTap : null,
      child: child,
    );
    child = FocusableActionDetector(
      enabled: _active,
      mouseCursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: child,
    );
    child = Semantics(
      button: true,
      enabled: _active,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      onTap: _active ? _handleTap : null,
      child: child,
    );
    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, child: child);
    return child;
  }
}
