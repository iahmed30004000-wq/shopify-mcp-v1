import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';

/// The single press behaviour of every tappable Madar surface: spring scale
/// to [MadarMotion.pressScale], synced sound + haptic via [Fx.fire], keyboard
/// activation (Enter/Space), focus, and button semantics.
///
/// Under reduced motion the scale is skipped entirely.
class MadarPressable extends StatefulWidget {
  const MadarPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.sfx = Sfx.tap,
    this.longPressSfx = Sfx.pickUp,
    this.pressScale = MadarMotion.pressScale,
    this.semanticLabel,
    this.button = true,
    this.selected,
    this.toggled,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
    this.onPressedChanged,
    this.focusNode,
    this.autofocus = false,
    this.excludeChildSemantics = false,
    this.focusRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Sound (+ its synced haptic) fired on tap. `null` = silent (the caller
  /// fires its own feedback, e.g. a switch choosing toggleOn/toggleOff).
  final Sfx? sfx;
  final Sfx? longPressSfx;
  final double pressScale;
  final String? semanticLabel;
  final bool button;
  final bool? selected;
  final bool? toggled;
  final bool enabled;
  final HitTestBehavior behavior;

  /// Reports press-down / release so the caller can light up its surface.
  final ValueChanged<bool>? onPressedChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool excludeChildSemantics;

  /// Corner radius of the keyboard-focus ring (defaults to a pill).
  final BorderRadius? focusRadius;

  bool get _interactive => enabled && (onTap != null || onLongPress != null);

  @override
  State<MadarPressable> createState() => _MadarPressableState();
}

class _MadarPressableState extends State<MadarPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _pressed = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _handleTap()),
  };

  void _springTo(double target, SpringDescription spring) {
    if (context.reducedMotion) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(SpringSimulation(spring, _scale.value, target, _scale.velocity));
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    widget.onPressedChanged?.call(value);
    _springTo(value ? widget.pressScale : 1, value ? MadarMotion.snappy : MadarMotion.bouncy);
  }

  void _handleTap() {
    if (!widget._interactive || widget.onTap == null) return;
    final sfx = widget.sfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (!widget._interactive || widget.onLongPress == null) return;
    _setPressed(false);
    final sfx = widget.longPressSfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onLongPress!();
  }

  @override
  void didUpdateWidget(MadarPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget._interactive && _pressed) _setPressed(false);
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget._interactive;
    Widget child = ScaleTransition(scale: _scale, child: widget.child);
    if (_focused) {
      child = _FocusRing(radius: widget.focusRadius, child: child);
    }
    return Semantics(
      button: widget.button,
      enabled: interactive,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: interactive && widget.onTap != null ? _handleTap : null,
      onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
      child: FocusableActionDetector(
        enabled: interactive,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        actions: _actions,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: widget.behavior,
          excludeFromSemantics: true,
          onTapDown: interactive ? (_) => _setPressed(true) : null,
          onTapUp: interactive ? (_) => _setPressed(false) : null,
          onTapCancel: interactive ? () => _setPressed(false) : null,
          onTap: interactive && widget.onTap != null ? _handleTap : null,
          onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
          dragStartBehavior: DragStartBehavior.down,
          child: child,
        ),
      ),
    );
  }
}

/// Keyboard focus indication (hardware keyboards / accessibility switches).
class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.child, this.radius});

  final Widget child;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(999),
        border: Border.all(color: context.tokens.accent, width: 1.5),
      ),
      child: child,
    );
  }
}
